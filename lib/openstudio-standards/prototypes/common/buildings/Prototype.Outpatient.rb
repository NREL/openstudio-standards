
# Custom changes for the Outpatient prototype.
# These are changes that are inconsistent with other prototype
# building types.
module Outpatient
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')

    system_to_space_map = define_hvac_system_map(building_type, climate_zone)

    # add elevator for the elevator pump room (the fan&lights are already added via standard spreadsheet)
    add_extra_equip_elevator_pump_room(model)
    # adjust cooling setpoint at vintages 1B,2B,3B
    adjust_clg_setpoint(climate_zone, model)
    # Get the hot water loop
    hot_water_loop = nil
    model.getPlantLoops.sort.each do |loop|
      # If it has a boiler:hotwater, it is the correct loop
      unless loop.supplyComponents('OS:Boiler:HotWater'.to_IddObjectType).empty?
        hot_water_loop = loop
      end
    end
    # add humidifier to AHU1 (contains operating room 1)
    if hot_water_loop
      add_humidifier(hot_water_loop, model)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Could not find hot water loop to attach humidifier to.')
    end

    # adjust minimum damper positions
    model_adjust_vav_minimum_damper(model)
    # adjust infiltration for vintages 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
    adjust_infiltration(model)
    # add door infiltration for vertibule
    add_door_infiltration(climate_zone, model)
    # reset boiler sizing factor to 0.3 (default 1)
    reset_boiler_sizing_factor(model)
    # assign the minimum total air changes to the cooling minimum air flow in Sizing:Zone
    apply_minimum_total_ach(building_type, model)

    # set coil sizing
    if template == '90.1-2004' || template == '90.1-2007'
      model.getCoilHeatingWaters.each do |coil|
        if coil.name.to_s == 'PVAV Outpatient F1 Main Htg Coil' || coil.name.to_s == 'PVAV Outpatient F2 F3 Main Htg Coil'
          coil.setRatedOutletAirTemperature(50.0)
        end
      end
    end

    # Some exceptions for the Outpatient
    # TODO Refactor: not sure if this is actually enabled in the original code
    #     if system_name.include? 'PVAV Outpatient F1'
    #       # Outpatient two AHU1 and AHU2 have different HVAC schedule
    #       hvac_op_sch = model_add_schedule(model, 'OutPatientHealthCare AHU1-Fan_Pre2004')
    #       # Outpatient has different temperature settings for sizing
    #       clg_sa_temp_f = 52 # for AHU1 in Outpatient, SAT is 52F
    #       sys_dsn_clg_sa_temp_f = if template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
    #                                 52
    #                               else
    #                                 45
    #                               end
    #       zn_dsn_clg_sa_temp_f = 52 # zone cooling design SAT
    #       zn_dsn_htg_sa_temp_f = 104 # zone heating design SAT
    #     elsif system_name.include? 'PVAV Outpatient F2 F3'
    #       hvac_op_sch = model_add_schedule(model, 'OutPatientHealthCare AHU2-Fan_Pre2004')
    #       clg_sa_temp_f = 55 # for AHU2 in Outpatient, SAT is 55F
    #       sys_dsn_clg_sa_temp_f = 52
    #       zn_dsn_clg_sa_temp_f = 55 # zone cooling design SAT
    #       zn_dsn_htg_sa_temp_f = 104 # zone heating design SAT
    #     end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')

    return true
  end

  def add_extra_equip_elevator_pump_room(model)
    elevator_pump_room = model.getSpaceByName('Floor 1 Elevator Pump Room').get
    elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def.setName('Elevator Pump Room Electric Equipment Definition')
    elec_equip_def.setFractionLatent(0)
    elec_equip_def.setFractionRadiant(0.1)
    elec_equip_def.setFractionLost(0.9)
    elec_equip_def.setDesignLevel(48_165)
    elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
    elec_equip.setName('Elevator Pump Room Elevator Equipment')
    elec_equip.setSpace(elevator_pump_room)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip.setSchedule(model_add_schedule(model, 'OutPatientHealthCare BLDG_ELEVATORS'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip.setSchedule(model_add_schedule(model, 'OutPatientHealthCare BLDG_ELEVATORS_Pre2004'))
    end
    return true
  end

  def adjust_clg_setpoint(climate_zone, model)
    model.getSpaceTypes.sort.each do |space_type|
      space_type_name = space_type.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010'
          case climate_zone
            when 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-3B'
              thermostat.setCoolingSetpointTemperatureSchedule(model_add_schedule(model, 'OutPatientHealthCare CLGSETP_SCH_YES_OPTIMUM'))
          end
      end
    end
    return true
  end

  def adjust_infiltration(model)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getSpaces.sort.each do |space|
          space_type = space.spaceType.get
          # Skip interior spaces
          next if space_exterior_wall_and_window_area(space) <= 0
          # Skip spaces that have no infiltration objects to adjust
          next if space_type.spaceInfiltrationDesignFlowRates.size <= 0

          # get the infiltration information from the space type infiltration
          infiltration_space_type = space_type.spaceInfiltrationDesignFlowRates[0]
          infil_sch = infiltration_space_type.schedule.get
          infil_rate = nil
          infil_ach = nil
          if infiltration_space_type.flowperExteriorWallArea.is_initialized
            infil_rate = infiltration_space_type.flowperExteriorWallArea.get
          elsif infiltration_space_type.airChangesperHour.is_initialized
            infil_ach = infiltration_space_type.airChangesperHour.get
          end
          # Create an infiltration rate object for this space
          infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
          infiltration.setName("#{space.name} Infiltration")
          infiltration.setFlowperExteriorSurfaceArea(infil_rate) unless infil_rate.nil? || infil_rate.to_f.zero?
          infiltration.setAirChangesperHour(infil_ach) unless infil_ach.nil? || infil_ach.to_f.zero?
          infiltration.setSchedule(infil_sch)
          infiltration.setSpace(space)
        end
        model.getSpaceTypes.sort.each do |space_type|
          space_type.spaceInfiltrationDesignFlowRates.each(&:remove)
        end
      else
        return true
    end
  end

  def add_door_infiltration(climate_zone, model)
    # add extra infiltration for vestibule door
    case template
      when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
        return true
      else
        vestibule_space = model.getSpaceByName('Floor 1 Vestibule').get
        infiltration_vestibule_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_vestibule_door.setName('Vestibule door Infiltration')
        infiltration_rate_vestibule_door = 0
        case template
          when '90.1-2004'
            infiltration_rate_vestibule_door = 1.186002811
            infiltration_vestibule_door.setSchedule(model_add_schedule(model, 'OutPatientHealthCare INFIL_Door_Opening_SCH_0.144'))
          when '90.1-2007', '90.1-2010', '90.1-2013'
            case climate_zone
              when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
                infiltration_rate_vestibule_door = 1.186002811
                infiltration_vestibule_door.setSchedule(model_add_schedule(model, 'OutPatientHealthCare INFIL_Door_Opening_SCH_0.144'))
              else
                infiltration_rate_vestibule_door = 0.776824762
                infiltration_vestibule_door.setSchedule(model_add_schedule(model, 'OutPatientHealthCare INFIL_Door_Opening_SCH_0.131'))
            end
        end
        infiltration_vestibule_door.setDesignFlowRate(infiltration_rate_vestibule_door)
        infiltration_vestibule_door.setSpace(vestibule_space)
    end
  end

  def update_waterheater_loss_coefficient(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          if water_heater.name.to_s.include?('Booster')
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
          else
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(9.643286505)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(9.643286505)
          end
        end
    end
  end

  # add humidifier to AHU1 (contains operating room1)
  def add_humidifier(hot_water_loop, model)
    operatingroom1_space = model.getSpaceByName('Floor 1 Operating Room 1').get
    operatingroom1_zone = operatingroom1_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'OutPatientHealthCare MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'OutPatientHealthCare MaxRelHumSetSch'))
    operatingroom1_zone.setZoneControlHumidistat(humidistat)
    model.getAirLoopHVACs.sort.each do |air_loop|
      if air_loop.thermalZones.include? operatingroom1_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100_000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject.get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
        case template
          when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
            create_coil_heating_electric(model,
                                         air_loop_node: supply_outlet_node,
                                         name: 'AHU1 extra Electric Htg Coil')
            create_coil_heating_water(model,
                                      hot_water_loop,
                                      air_loop_node: supply_outlet_node,
                                      name: 'AHU1 extra Water Htg Coil')
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)
        humidity_spm.setControlZone(operatingroom1_zone)
      end
    end
  end

  # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
  # AHU1 doesn't have economizer
  def model_modify_oa_controller(model)
    model.getAirLoopHVACs.sort.each do |air_loop|
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      # AHU1 OA doesn't have controller:mechanicalventilation
      if air_loop.name.to_s.include? 'Outpatient F1'
        controller_mv.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
        # add minimum fraction of outdoor air schedule to AHU1
        controller_oa.setMinimumFractionofOutdoorAirSchedule(model_add_schedule(model, 'OutPatientHealthCare AHU-1_OAminOAFracSchedule'))
        # for AHU2, at vintages '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', the minimum OA schedule is not the same as
        # airloop availability schedule, but separately assigned.
      elsif template == '90.1-2004' || template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013'
        controller_oa.setMinimumOutdoorAirSchedule(model_add_schedule(model, 'OutPatientHealthCare BLDG_OA_SCH'))
        # add minimum fraction of outdoor air schedule to AHU2
        controller_oa.setMinimumFractionofOutdoorAirSchedule(model_add_schedule(model, 'OutPatientHealthCare BLDG_OA_FRAC_SCH'))
      end
    end
  end

  # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
  def model_adjust_vav_minimum_damper(model)
    model.getThermalZones.each do |zone|
      air_terminal = zone.airLoopHVACTerminal
      if air_terminal.is_initialized
        air_terminal = air_terminal.get
        if air_terminal.to_AirTerminalSingleDuctVAVReheat.is_initialized
          air_terminal = air_terminal.to_AirTerminalSingleDuctVAVReheat.get
          vav_name = air_terminal.name.get
          # High OA zones
          # Determine whether or not to use the high minimum guess.
          # Cutoff was determined by correlating apparent minimum guesses
          # to OA rates in prototypes since not well documented in papers.
          zone_oa_per_area = thermal_zone_outdoor_airflow_rate_per_area(zone)
          case template
          when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
            air_terminal.setConstantMinimumAirFlowFraction(1.0) if vav_name.include?('Floor 1')
          when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
            air_terminal.setConstantMinimumAirFlowFraction(1.0) if zone_oa_per_area > 0.001 # 0.001 m^3/s*m^2 = .196 cfm/ft2
           end
        end
      end
    end
  end

  # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
  # This is NOT called in model_custom_hvac_tweaks,
  # instead it is called by model_reset_or_room_vav_minimum_damper AFTER the sizing run,
  # so that the system is sized at a constant airflow fraction of 1.0,
  # not 0.3 as defaulted in the zone sizing object
  def model_reset_or_room_vav_minimum_damper(prototype_input, model)
    case template
    when '90.1-2010', '90.1-2013'
      model.getAirTerminalSingleDuctVAVReheats.sort.each do |air_terminal|
        air_terminal_name = air_terminal.name.get
        if air_terminal_name.include?('Floor 1 Operating Room 1') || air_terminal_name.include?('Floor 1 Operating Room 2')
          air_terminal.setZoneMinimumAirFlowMethod('Scheduled')
          air_terminal.setMinimumAirFlowFractionSchedule(model_add_schedule(model, 'OutPatientHealthCare OR_MinSA_Sched'))
        end
      end
    else
      return true
    end
  end

  def reset_boiler_sizing_factor(model)
    model.getBoilerHotWaters.sort.each do |boiler|
      boiler.setSizingFactor(0.3)
    end
  end

  def model_update_exhaust_fan_efficiency(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          fan_name = exhaust_fan.name.to_s
          if (fan_name.include? 'X-Ray') || (fan_name.include? 'MRI Room')
            exhaust_fan.setFanEfficiency(0.16)
            exhaust_fan.setPressureRise(125)
          else
            exhaust_fan.setFanEfficiency(0.31)
            exhaust_fan.setPressureRise(249)
          end
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.338)
          exhaust_fan.setPressureRise(125)
        end
    end
  end

  # assign the minimum total air changes to the cooling minimum air flow in Sizing:Zone
  def apply_minimum_total_ach(building_type, model)
    model.getSpaces.sort.each do |space|
      space_type_name = space.spaceType.get.standardsSpaceType.get
      search_criteria = {
          'template' => template,
          'building_type' => building_type,
          'space_type' => space_type_name
      }
      data = model_find_object(standards_data['space_types'], search_criteria)

      if data.nil? ###
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Could not find data for #{search_criteria}")
        next
      end

      # skip space type without minimum total air changes
      next if data['minimum_total_air_changes'].nil?

      # calculate the minimum total air flow
      minimum_total_ach = data['minimum_total_air_changes'].to_f
      space_volume = space.volume
      space_area = space.floorArea
      minimum_airflow_per_zone = minimum_total_ach * space_volume / 3600
      minimum_airflow_per_zone_floor_area = minimum_airflow_per_zone / space_area
      # add minimum total air flow limit to sizing:zone
      zone = space.thermalZone.get
      sizingzone = zone.sizingZone
      sizingzone.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
      case template
        when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
          sizingzone.setCoolingMinimumAirFlow(minimum_airflow_per_zone)
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          sizingzone.setCoolingMinimumAirFlowperZoneFloorArea(minimum_airflow_per_zone_floor_area)
      end
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(model)

    return true
  end
end

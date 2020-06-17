
# Custom changes for the LargeHotel prototype.
# These are changes that are inconsistent with other prototype
# building types.
module LargeHotel
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add transformer
    case template
    when '90.1-2004', '90.1-2007'
      transformer_efficiency = 0.971
    when '90.1-2010', '90.1-2013'
      transformer_efficiency = 0.983
    end

    model_add_transformer(model,
                          wired_lighting_frac: 0.0352,
                          transformer_size: 150000,
                          transformer_efficiency: transformer_efficiency)

    # add extra equipment for kitchen
    add_extra_equip_kitchen(model)

    # Add Exhaust Fan
    space_type_map = define_space_type_map(building_type, climate_zone)
    exhaust_fan_space_types = []
    case template
      when '90.1-2004', '90.1-2007'
        exhaust_fan_space_types = ['Kitchen', 'Laundry']
      else
        exhaust_fan_space_types = ['Banquet', 'Kitchen', 'Laundry']
    end

    exhaust_fan_space_types.each do |space_type_name|
      space_type_data = standards_lookup_table_first(table_name: 'space_types', search_criteria:{'template' => template,
                                                                                                 'building_type' => building_type,
                                                                                                 'space_type' => space_type_name})
      if space_type_data.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find space type #{template}-#{building_type}-#{space_type_name}")
        return false
      end

      exhaust_schedule = model_add_schedule(model, space_type_data['exhaust_availability_schedule'])
      unless exhaust_schedule
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find Exhaust Schedule for space type #{template}-#{building_type}-#{space_type_name}")
        return false
      end

      balanced_exhaust_schedule = model_add_schedule(model, space_type_data['balanced_exhaust_fraction_schedule'])

      space_names = space_type_map[space_type_name]
      space_names.each do |space_name|
        space = model.getSpaceByName(space_name).get
        thermal_zone = space.thermalZone.get

        zone_exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(model)
        zone_exhaust_fan.setName(space.name.to_s + ' Exhaust Fan')
        zone_exhaust_fan.setAvailabilitySchedule(exhaust_schedule)
        zone_exhaust_fan.setFanEfficiency(space_type_data['exhaust_fan_efficiency'])
        zone_exhaust_fan.setPressureRise(space_type_data['exhaust_fan_pressure_rise'])
        maximum_flow_rate = OpenStudio.convert(space_type_data['exhaust_fan_maximum_flow_rate'], 'cfm', 'm^3/s').get

        zone_exhaust_fan.setMaximumFlowRate(maximum_flow_rate)
        if balanced_exhaust_schedule.class.to_s != 'NilClass'
          zone_exhaust_fan.setBalancedExhaustFractionSchedule(balanced_exhaust_schedule)
        end
        zone_exhaust_fan.setEndUseSubcategory('Zone Exhaust Fans')
        zone_exhaust_fan.addToThermalZone(thermal_zone)

        if !space_type_data['exhaust_fan_power'].nil? && space_type_data['exhaust_fan_power'].to_f.nonzero?
          # Create the electric equipment definition
          exhaust_fan_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
          exhaust_fan_equip_def.setName("#{space_name} Electric Equipment Definition")
          exhaust_fan_equip_def.setDesignLevel(space_type_data['exhaust_fan_power'].to_f)
          exhaust_fan_equip_def.setFractionLatent(0)
          exhaust_fan_equip_def.setFractionRadiant(0)
          exhaust_fan_equip_def.setFractionLost(1)

          # Create the electric equipment instance and hook it up to the space type
          exhaust_fan_elec_equip = OpenStudio::Model::ElectricEquipment.new(exhaust_fan_equip_def)
          exhaust_fan_elec_equip.setName("#{space_name} Exhaust Fan Equipment")
          exhaust_fan_elec_equip.setSchedule(exhaust_schedule)
          exhaust_fan_elec_equip.setSpaceType(space.spaceType.get)
        end
      end
    end

    # adjust VAV system sizing
    model.getAirLoopHVACs.each do |air_loop|
      if air_loop.name.to_s.include? 'VAV WITH REHEAT'
        # economizer type
        oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
        oa_intake_controller = oa_system.getControllerOutdoorAir
        oa_intake_controller.setEconomizerControlType('DifferentialEnthalpy')

        # zone sizing
        rht_sa_temp_c = OpenStudio.convert(90.0, 'F', 'C').get
        air_loop.thermalZones.each do |zone|
          air_terminal = zone.airLoopHVACTerminal
          if air_terminal.is_initialized
            air_terminal = air_terminal.get
            if air_terminal.to_AirTerminalSingleDuctVAVReheat.is_initialized
              air_terminal = air_terminal.to_AirTerminalSingleDuctVAVReheat.get
              air_terminal.setMaximumReheatAirTemperature(rht_sa_temp_c)
              reheat_coil = air_terminal.reheatCoil
              reheat_coil = reheat_coil.to_CoilHeatingWater.get
              reheat_coil.setRatedOutletAirTemperature(rht_sa_temp_c)
            end
          end
        end
      end
    end

    # Update Sizing Zone
    zone_sizing = model.getSpaceByName('Kitchen_Flr_6').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlowFraction(0.7)

    zone_sizing = model.getSpaceByName('Laundry_Flr_1').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlow(0.23567919336)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # add hvac

  # add extra equipment for kitchen
  def add_extra_equip_kitchen(model)
    kitchen_space = model.getSpaceByName('Kitchen_Flr_6')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(457.7)
          elec_equip_def2.setDesignLevel(285)
        else
          elec_equip_def1.setDesignLevel(457.7)
          elec_equip_def2.setDesignLevel(285)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model_add_schedule(model, 'HotelLarge ALWAYS_ON'))
        elec_equip2.setSchedule(model_add_schedule(model, 'HotelLarge ALWAYS_ON'))
      # elec_equip2.setSchedule(model.alwaysOnDiscreteSchedule)
      # elec_equip2.setSchedule(model.alwaysOffDiscreteSchedule)
    end
  end

  # Add the daylighting controls for lobby, cafe, dinning and banquet
  def model_add_daylighting_controls(model)
    space_names = ['Banquet_Flr_6', 'Dining_Flr_6', 'Cafe_Flr_1', 'Lobby_Flr_1']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      space_add_daylighting_controls(space, false, false)
    end
  end

  def update_waterheater_ambient_parameters(model)
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('300gal')
        water_heater.resetAmbientTemperatureSchedule
        water_heater.setAmbientTemperatureIndicator('ThermalZone')		
        water_heater.setAmbientTemperatureThermalZone(model.getThermalZoneByName('Basement ZN').get)
      elsif water_heater.name.to_s.include?('6.0gal')
        water_heater.resetAmbientTemperatureSchedule
        water_heater.setAmbientTemperatureIndicator('ThermalZone')		
        water_heater.setAmbientTemperatureThermalZone(model.getThermalZoneByName('Kitchen_Flr_6 ZN').get)
      end
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    update_waterheater_ambient_parameters(model)

    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)

    return true
  end

  def air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(air_terminal_single_duct_vav_reheat, zone_oa_per_area)
    min_damper_position = template == '90.1-2010' || template == '90.1-2013' ? 0.2 : 0.3

    # Set the minimum flow fraction
    air_terminal_single_duct_vav_reheat.setConstantMinimumAirFlowFraction(min_damper_position)

    return true
  end
end

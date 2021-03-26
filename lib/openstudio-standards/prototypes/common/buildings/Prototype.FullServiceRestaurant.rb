# Custom changes for the FullServiceRestaurant prototype.
# These are changes that are inconsistent with other prototype
# building types.
module FullServiceRestaurant
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add extra equipment for kitchen
    add_extra_equip_kitchen(model)
    # add extra infiltration for dining room door and attic
    add_door_infiltration(climate_zone, model)
    # add zone_mixing between kitchen and dining
    add_zone_mixing(model)
    # Update Sizing Zone
    update_sizing_zone(model)
    # adjust the cooling setpoint
    adjust_clg_setpoint(climate_zone, model)
    # reset the design OA of kitchen
    reset_kitchen_oa(model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def model_custom_daylighting_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting daylight sensor positions and fractions')

    adjustments = [
      { '90.1-2010' => { 'Dining' => { 'sensor_1_frac' => 0.135,
                                       'sensor_2_frac' => 0.135,
                                       'sensor_1_xyz' => [1.9812, 1.9812, 0.762],
                                       'sensor_2_xyz' => [20.574, 1.9812, 0.762] } },
        '90.1-2013' => { 'Dining' => { 'sensor_1_frac' => 0.25,
                                       'sensor_2_frac' => 0.25,
                                       'sensor_1_xyz' => [2.6548, 2.6548, 0.762],
                                       'sensor_2_xyz' => [19.9539, 2.6548, 0.762] } },
        '90.1-2016' => { 'Dining' => { 'sensor_1_frac' => 0.25,
                                       'sensor_2_frac' => 0.25,
                                       'sensor_1_xyz' => [2.6548, 2.6548, 0.762],
                                       'sensor_2_xyz' => [19.9539, 2.6548, 0.762] } },
        '90.1-2019' => { 'Dining' => { 'sensor_1_frac' => 0.25,
                                       'sensor_2_frac' => 0.25,
                                       'sensor_1_xyz' => [2.6548, 2.6548, 0.762],
                                       'sensor_2_xyz' => [19.9539, 2.6548, 0.762] } } }
    ]

    # Adjust daylight sensors in each space
    model.getSpaces.each do |space|
      if adjustments[0].keys.include?(template)
        if adjustments[0][template].keys.include?(space.name.to_s)
          adj = adjustments[0][template][space.name.to_s]
          next if space.thermalZone.empty?

          zone = space.thermalZone.get
          next if space.spaceType.empty?

          spc_type = space.spaceType.get
          next if spc_type.standardsSpaceType.empty?

          stds_spc_type = spc_type.standardsSpaceType.get
          # Adjust the primary sensor
          if adj['sensor_1_frac'] && zone.primaryDaylightingControl.is_initialized
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{zone.name}: Adjusting primary daylight sensor to control #{adj['sensor_1_frac']} of the lighting.")
            zone.setFractionofZoneControlledbyPrimaryDaylightingControl(adj['sensor_1_frac'])
            pri_ctrl = zone.primaryDaylightingControl.get
            if adj['sensor_1_xyz']
              x = adj['sensor_1_xyz'][0]
              y = adj['sensor_1_xyz'][1]
              z = adj['sensor_1_xyz'][2]
              OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{zone.name}: Adjusting primary daylight sensor position to [#{x}, #{y}, #{z}].")
              pri_ctrl.setPositionXCoordinate(x)
              pri_ctrl.setPositionYCoordinate(y)
              pri_ctrl.setPositionZCoordinate(z)
            end
          end
          # Adjust the secondary sensor
          if adj['sensor_2_frac'] && zone.secondaryDaylightingControl.is_initialized
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{zone.name}: Adjusting secondary daylight sensor to control #{adj['sensor_2_frac']} of the lighting.")
            zone.setFractionofZoneControlledbySecondaryDaylightingControl(adj['sensor_2_frac'])
            sec_ctrl = zone.secondaryDaylightingControl.get
            if adj['sensor_2_xyz']
              x = adj['sensor_2_xyz'][0]
              y = adj['sensor_2_xyz'][1]
              z = adj['sensor_2_xyz'][2]
              OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "For #{zone.name}: Adjusting secondary daylight sensor position to [#{x}, #{y}, #{z}].")
              sec_ctrl.setPositionXCoordinate(x)
              sec_ctrl.setPositionYCoordinate(y)
              sec_ctrl.setPositionZCoordinate(z)
            end
          end
        end
      end
    end

    return true
  end

  # add hvac

  def add_door_infiltration(climate_zone, model)
    # add extra infiltration for dining room door and attic (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980' || template == 'NECB2011'
      dining_space = model.getSpaceByName('Dining').get
      attic_space = model.getSpaceByName('Attic').get
      infiltration_diningdoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_attic = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_diningdoor.setName('Dining door Infiltration')
      infiltration_per_zone_diningdoor = 0
      infiltration_per_zone_attic = 0.2378
      if template == '90.1-2004'
        infiltration_per_zone_diningdoor = 0.614474994
        infiltration_diningdoor.setSchedule(model_add_schedule(model, 'RestaurantSitDown DOOR_INFIL_SCH'))
      elsif template == '90.1-2007'
        case climate_zone
          when 'ASHRAE 169-2006-0A',
               'ASHRAE 169-2006-1A',
               'ASHRAE 169-2006-2A',
               'ASHRAE 169-2006-2B',
               'ASHRAE 169-2006-3A',
               'ASHRAE 169-2006-3B',
               'ASHRAE 169-2006-3C',
               'ASHRAE 169-2006-4A',
               'ASHRAE 169-2006-4B',
               'ASHRAE 169-2006-4C',
               'ASHRAE 169-2013-0A',
               'ASHRAE 169-2013-1A',
               'ASHRAE 169-2013-2A',
               'ASHRAE 169-2013-2B',
               'ASHRAE 169-2013-3A',
               'ASHRAE 169-2013-3B',
               'ASHRAE 169-2013-3C',
               'ASHRAE 169-2013-4A',
               'ASHRAE 169-2013-4B',
               'ASHRAE 169-2013-4C'
            infiltration_per_zone_diningdoor = 0.614474994
            infiltration_diningdoor.setSchedule(model_add_schedule(model, 'RestaurantSitDown DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.389828222
            infiltration_diningdoor.setSchedule(model_add_schedule(model, 'RestaurantSitDown VESTIBULE_DOOR_INFIL_SCH'))
        end
      elsif template == '90.1-2010' || template == '90.1-2013' || template == '90.1-2016' || template == '90.1-2019'
        case climate_zone
          when 'ASHRAE 169-2006-0A',
               'ASHRAE 169-2006-1A',
               'ASHRAE 169-2006-2A',
               'ASHRAE 169-2006-2B',
               'ASHRAE 169-2006-3A',
               'ASHRAE 169-2006-3B',
               'ASHRAE 169-2006-3C',
               'ASHRAE 169-2013-0A',
               'ASHRAE 169-2013-1A',
               'ASHRAE 169-2013-2A',
               'ASHRAE 169-2013-2B',
               'ASHRAE 169-2013-3A',
               'ASHRAE 169-2013-3B',
               'ASHRAE 169-2013-3C'
            infiltration_per_zone_diningdoor = 0.614474994
            infiltration_diningdoor.setSchedule(model_add_schedule(model, 'RestaurantSitDown DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.389828222
            infiltration_diningdoor.setSchedule(model_add_schedule(model, 'RestaurantSitDown VESTIBULE_DOOR_INFIL_SCH'))
        end
      end
      infiltration_diningdoor.setDesignFlowRate(infiltration_per_zone_diningdoor)
      infiltration_diningdoor.setSpace(dining_space)
      infiltration_attic.setDesignFlowRate(infiltration_per_zone_attic)
      infiltration_attic.setSchedule(model_add_schedule(model, 'Always On'))
      infiltration_attic.setSpace(attic_space)
    end
  end

  def model_update_exhaust_fan_efficiency(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          fan_name = exhaust_fan.name.to_s
          if fan_name.include? 'Dining'
            exhaust_fan.setFanEfficiency(1)
            exhaust_fan.setPressureRise(0)
          end
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(1)
          exhaust_fan.setPressureRise(0.000001)
        end
    end
  end

  def add_zone_mixing(model)
    # add zone_mixing between kitchen and dining
    # TODO: remove zone mixing objects,
    # transfer air is the should be the same for
    # all stds, exhaust flow varies
    space_kitchen = model.getSpaceByName('Kitchen').get
    zone_kitchen = space_kitchen.thermalZone.get
    space_dining = model.getSpaceByName('Dining').get
    zone_dining = space_dining.thermalZone.get
    zone_mixing_kitchen = OpenStudio::Model::ZoneMixing.new(zone_kitchen)
    zone_mixing_kitchen.setSchedule(model_add_schedule(model, 'RestaurantSitDown Hours_of_operation'))
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        zone_mixing_kitchen.setDesignFlowRate(1.828)
      when '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        zone_mixing_kitchen.setDesignFlowRate(1.33143208)
      when '90.1-2004'
        zone_mixing_kitchen.setDesignFlowRate(2.64397817)
    end
    zone_mixing_kitchen.setSourceZone(zone_dining)
    zone_mixing_kitchen.setDeltaTemperature(0)
  end

  # add extra equipment for kitchen
  def add_extra_equip_kitchen(model)
    kitchen_space = model.getSpaceByName('Kitchen')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013' || template == '90.1-2016' || template == '90.1-2019'
          elec_equip_def1.setDesignLevel(457.5)
          elec_equip_def2.setDesignLevel(570)
        else
          elec_equip_def1.setDesignLevel(515.917)
          elec_equip_def2.setDesignLevel(851.67)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model_add_schedule(model, 'RestaurantSitDown ALWAYS_ON'))
        elec_equip2.setSchedule(model_add_schedule(model, 'RestaurantSitDown ALWAYS_ON'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip_def1.setDesignLevel(699)
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(1)
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip1.setName('Kitchen_ExhFan_Equip')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model_add_schedule(model, 'RestaurantSitDown Kitchen_Exhaust_SCH'))
    end
  end

  def update_sizing_zone(model)
    case template
      when '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.003581176)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
      when '90.1-2004'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.007111554)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
    end
  end

  def adjust_clg_setpoint(climate_zone, model)
    ['Dining', 'Kitchen'].each do |space_name|
      space_type_name = model.getSpaceByName(space_name).get.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010'
          case climate_zone
          when 'ASHRAE 169-2006-0B',
               'ASHRAE 169-2006-1B',
               'ASHRAE 169-2006-2B',
               'ASHRAE 169-2006-3B',
               'ASHRAE 169-2013-0B',
               'ASHRAE 169-2013-1B',
               'ASHRAE 169-2013-2B',
               'ASHRAE 169-2013-3B'
            case space_name
              when 'Dining'
                thermostat.setCoolingSetpointTemperatureSchedule(model_add_schedule(model, 'RestaurantSitDown CLGSETP_SCH_NO_OPTIMUM'))
              when 'Kitchen'
                thermostat.setCoolingSetpointTemperatureSchedule(model_add_schedule(model, 'RestaurantSitDown CLGSETP_KITCHEN_SCH_NO_OPTIMUM'))
            end
          end
      end
    end
  end

  # In order to provide sufficient OSA to replace exhaust flow through kitchen hoods (3,300 cfm),
  # modeled OSA to kitchen is different from OSA determined based on ASHRAE  62.1.
  # It takes into account the available OSA in dining as transfer air.
  def reset_kitchen_oa(model)
    space_kitchen = model.getSpaceByName('Kitchen').get
    ventilation = space_kitchen.designSpecificationOutdoorAir.get
    ventilation.setOutdoorAirFlowperPerson(0)
    ventilation.setOutdoorAirFlowperFloorArea(0)
    case template
      when '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        ventilation.setOutdoorAirFlowRate(1.21708392)
      when '90.1-2007'
        ventilation.setOutdoorAirFlowRate(1.50025792)
      when '90.1-2004'
        ventilation.setOutdoorAirFlowRate(1.87711831)
    end
  end

  def update_waterheater_ambient_parameters(model)
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        water_heater.resetAmbientTemperatureSchedule
        water_heater.setAmbientTemperatureIndicator('ThermalZone')
        water_heater.setAmbientTemperatureThermalZone(model.getThermalZoneByName('Kitchen ZN').get)
      end
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    update_waterheater_ambient_parameters(model)

    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)
    # Set original building North axis
    model_set_building_north_axis(model, 0.0)

    return true
  end
end

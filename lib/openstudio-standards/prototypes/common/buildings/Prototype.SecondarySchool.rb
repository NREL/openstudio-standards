
# Custom changes for the SecondarySchool prototype.
# These are changes that are inconsistent with other prototype
# building types.
module SecondarySchool
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add transformer
    case template
    when '90.1-2004', '90.1-2007'
      transformer_efficiency = 0.974
    when '90.1-2010', '90.1-2013'
      transformer_efficiency = 0.985
    end

    model_add_transformer(model,
                          wired_lighting_frac: 0.0194,
                          transformer_size: 225000,
                          transformer_efficiency: transformer_efficiency,
                          excluded_interiorequip_key: '2 Elevator Lift Motors',
                          excluded_interiorequip_meter: 'Electric Equipment Electric Energy')

    # add extra equipment for kitchen
    add_extra_equip_kitchen(model)

    model.getSpaces.sort.each do |space|
      if space.name.get.to_s == 'Mech_ZN_1_FLR_1'
        model_add_elevator(model,
                           space,
                           prototype_input['number_of_elevators'],
                           prototype_input['elevator_type'],
                           prototype_input['elevator_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           building_type)
      end
    end

    # change sizing method for zone
    model.getThermalZones.each do |zone|
      air_terminal = zone.airLoopHVACTerminal
      if air_terminal.is_initialized
        air_terminal = air_terminal.get
        if air_terminal.to_AirTerminalSingleDuctVAVReheat.is_initialized
          sizing_zone = zone.sizingZone
          sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
        end
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # add extra equipment for kitchen
  def add_extra_equip_kitchen(model)
    kitchen_space = model.getSpaceByName('Kitchen_ZN_1_FLR_1')
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
          elec_equip_def1.setDesignLevel(915)
          elec_equip_def2.setDesignLevel(570)
        else
          elec_equip_def1.setDesignLevel(1032)
          elec_equip_def2.setDesignLevel(852)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model_add_schedule(model, 'SchoolSecondary ALWAYS_ON'))
        elec_equip2.setSchedule(model_add_schedule(model, 'SchoolSecondary ALWAYS_ON'))
    end
  end

  def update_waterheater_ambient_parameters(model)
    model.getWaterHeaterMixeds.sort.each do |water_heater|
      if water_heater.name.to_s.include?('Booster')
        water_heater.resetAmbientTemperatureSchedule
        water_heater.setAmbientTemperatureIndicator('ThermalZone')		
        water_heater.setAmbientTemperatureThermalZone(model.getThermalZoneByName('Kitchen_ZN_1_FLR_1 ZN').get)
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

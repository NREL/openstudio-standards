# Custom changes for the SecondarySchool prototype.
# These are changes that are inconsistent with other prototype
# building types.
module SecondarySchool
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific HVAC adjustments')

    # add transformer
    # efficiency based on a 225 kVA transformer
    case template
    when '90.1-2004', '90.1-2007'
      transformer_efficiency = 0.974
    when '90.1-2010', '90.1-2013'
      transformer_efficiency = 0.985
    when '90.1-2016', '90.1-2019'
      transformer_efficiency = 0.989
    else
      transformer_efficiency = nil
    end
    return true unless !transformer_efficiency.nil?

    # Change to output variable name in E+ 9.4 (OS 3.1.0)
    excluded_interiorequip_variable = if model.version < OpenStudio::VersionString.new('3.1.0')
                                        'Electric Equipment Electric Energy'
                                      else
                                        'Electric Equipment Electricity Energy'
                                      end

    model_add_transformer(model,
                          wired_lighting_frac: 0.0194,
                          transformer_size: 225000,
                          transformer_efficiency: transformer_efficiency,
                          excluded_interiorequip_key: '2 Elevator Lift Motors',
                          excluded_interiorequip_meter: excluded_interiorequip_variable)

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
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013' || template == '90.1-2016' || template == '90.1-2019'
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

  def model_custom_daylighting_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Adjusting daylight sensor positions and fractions')

    adjustments = [
      { '90.1-2010' => { 'Auditorium_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.125,
                                                         'sensor_2_frac' => 0.125,
                                                         'sensor_1_xyz' => [9.5006, 21.7328, 0.762],
                                                         'sensor_2_xyz' => [28.5004, 21.7328, 0.762] },
                         'Aux_Gym_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.5,
                                                      'sensor_2_frac' => 0.5,
                                                      'sensor_1_xyz' => [12, 24, 0],
                                                      'sensor_2_xyz' => [2, 24, 0] },
                         'Cafeteria_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.095,
                                                        'sensor_2_frac' => 0.095,
                                                        'sensor_1_xyz' => [22.3236, 13, 0.762],
                                                        'sensor_2_xyz' => [12, 24.3236, 0.762] },
                         'Corner_Class_1_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_1_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_1_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_1_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_1_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_1_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_2_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_2_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_2_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_2_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_2_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Corner_Class_2_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.22,
                                                                   'sensor_2_frac' => 0.22,
                                                                   'sensor_1_xyz' => [1.6764, 4.5, 0.762],
                                                                   'sensor_2_xyz' => [5.5, 1.6764, 0.762] },
                         'Gym_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.5,
                                                  'sensor_2_frac' => 0.5,
                                                  'sensor_1_xyz' => [19, 24, 0],
                                                  'sensor_2_xyz' => [2, 24, 0] },
                         'LIBRARY_MEDIA_CENTER_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.085,
                                                                   'sensor_2_frac' => 0.085,
                                                                   'sensor_1_xyz' => [22.3236, 17.5, 0.762],
                                                                   'sensor_2_xyz' => [12, 33.3236, 0.762] },
                         'Lobby_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.09,
                                                    'sensor_2_frac' => 0.09,
                                                    'sensor_1_xyz' => [3.7338, 1.6764, 0.762],
                                                    'sensor_2_xyz' => [11.2014, 1.6764, 0.762] },
                         'Lobby_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.09,
                                                    'sensor_2_frac' => 0.09,
                                                    'sensor_1_xyz' => [3.7338, 1.6764, 0.762],
                                                    'sensor_2_xyz' => [11.2014, 1.6764, 0.762] },
                         'Mult_Class_1_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_1_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_2_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_2_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_1_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_1_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_2_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_2_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_1_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_1_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_2_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Mult_Class_2_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.14,
                                                                 'sensor_2_frac' => 0.14,
                                                                 'sensor_1_xyz' => [13.2588, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [39.7764, 1.6764, 0.762] },
                         'Offices_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.115,
                                                      'sensor_2_frac' => 0.115,
                                                      'sensor_1_xyz' => [18.9982, 1.6764, 0.762],
                                                      'sensor_2_xyz' => [36.3322, 7.0104, 0.762] },
                         'Offices_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.115,
                                                      'sensor_2_frac' => 0.115,
                                                      'sensor_1_xyz' => [18.9982, 1.6764, 0.762],
                                                      'sensor_2_xyz' => [36.3322, 7.0104, 0.762] } },
        '90.1-2013' => { 'Auditorium_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.125,
                                                         'sensor_2_frac' => 0.125,
                                                         'sensor_1_xyz' => [9.5006, 21.7328, 0.762],
                                                         'sensor_2_xyz' => [28.5004, 21.7328, 0.762] },
                         'Aux_Gym_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.5,
                                                      'sensor_2_frac' => 0.5,
                                                      'sensor_1_xyz' => [12, 24, 0],
                                                      'sensor_2_xyz' => [2, 24, 0] },
                         'Cafeteria_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.21,
                                                        'sensor_2_frac' => 0.15,
                                                        'sensor_1_xyz' => [20.6472, 13, 0.762],
                                                        'sensor_2_xyz' => [12, 22.6472, 0.762] },
                         'Corner_Class_1_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Gym_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.5,
                                                  'sensor_2_frac' => 0.5,
                                                  'sensor_1_xyz' => [19, 24, 0],
                                                  'sensor_2_xyz' => [2, 24, 0] },
                         'LIBRARY_MEDIA_CENTER_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.21,
                                                                   'sensor_2_frac' => 0.11,
                                                                   'sensor_1_xyz' => [20.6472, 17.5, 0.762],
                                                                   'sensor_2_xyz' => [12, 31.6472, 0.762] },
                         'Lobby_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.18,
                                                    'sensor_2_frac' => 0.18,
                                                    'sensor_1_xyz' => [7.5, 1.6764, 0.762],
                                                    'sensor_2_xyz' => [7.5, 3.3528, 0.762] },
                         'Lobby_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.18,
                                                    'sensor_2_frac' => 0.18,
                                                    'sensor_1_xyz' => [7.5, 1.6764, 0.762],
                                                    'sensor_2_xyz' => [7.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Offices_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.36,
                                                      'sensor_2_frac' => 0.08,
                                                      'sensor_1_xyz' => [34.6472, 7.0104, 0.762],
                                                      'sensor_2_xyz' => [18.9982, 3.3528, 0.762] },
                         'Offices_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.36,
                                                      'sensor_2_frac' => 0.08,
                                                      'sensor_1_xyz' => [34.6472, 7.0104, 0.762],
                                                      'sensor_2_xyz' => [18.9982, 3.3528, 0.762] } },
        '90.1-2016' => { 'Auditorium_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.125,
                                                         'sensor_2_frac' => 0.125,
                                                         'sensor_1_xyz' => [9.5006, 21.7328, 0.762],
                                                         'sensor_2_xyz' => [28.5004, 21.7328, 0.762] },
                         'Aux_Gym_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.5,
                                                      'sensor_2_frac' => 0.5,
                                                      'sensor_1_xyz' => [12, 24, 0],
                                                      'sensor_2_xyz' => [2, 24, 0] },
                         'Cafeteria_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.21,
                                                        'sensor_2_frac' => 0.15,
                                                        'sensor_1_xyz' => [20.6472, 13, 0.762],
                                                        'sensor_2_xyz' => [12, 22.6472, 0.762] },
                         'Corner_Class_1_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Gym_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.5,
                                                  'sensor_2_frac' => 0.5,
                                                  'sensor_1_xyz' => [19, 24, 0],
                                                  'sensor_2_xyz' => [2, 24, 0] },
                         'LIBRARY_MEDIA_CENTER_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.21,
                                                                   'sensor_2_frac' => 0.11,
                                                                   'sensor_1_xyz' => [20.6472, 17.5, 0.762],
                                                                   'sensor_2_xyz' => [12, 31.6472, 0.762] },
                         'Lobby_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.18,
                                                    'sensor_2_frac' => 0.18,
                                                    'sensor_1_xyz' => [7.5, 1.6764, 0.762],
                                                    'sensor_2_xyz' => [7.5, 3.3528, 0.762] },
                         'Lobby_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.18,
                                                    'sensor_2_frac' => 0.18,
                                                    'sensor_1_xyz' => [7.5, 1.6764, 0.762],
                                                    'sensor_2_xyz' => [7.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Offices_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.36,
                                                      'sensor_2_frac' => 0.08,
                                                      'sensor_1_xyz' => [34.6472, 7.0104, 0.762],
                                                      'sensor_2_xyz' => [18.9982, 3.3528, 0.762] },
                         'Offices_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.36,
                                                      'sensor_2_frac' => 0.08,
                                                      'sensor_1_xyz' => [34.6472, 7.0104, 0.762],
                                                      'sensor_2_xyz' => [18.9982, 3.3528, 0.762] } },
        '90.1-2019' => { 'Auditorium_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.125,
                                                         'sensor_2_frac' => 0.125,
                                                         'sensor_1_xyz' => [9.5006, 21.7328, 0.762],
                                                         'sensor_2_xyz' => [28.5004, 21.7328, 0.762] },
                         'Aux_Gym_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.5,
                                                      'sensor_2_frac' => 0.5,
                                                      'sensor_1_xyz' => [12, 24, 0],
                                                      'sensor_2_xyz' => [2, 24, 0] },
                         'Cafeteria_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.21,
                                                        'sensor_2_frac' => 0.15,
                                                        'sensor_1_xyz' => [20.6472, 13, 0.762],
                                                        'sensor_2_xyz' => [12, 22.6472, 0.762] },
                         'Corner_Class_1_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_1_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Corner_Class_2_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.56,
                                                                   'sensor_2_frac' => 0.2,
                                                                   'sensor_1_xyz' => [7.6198, 3.3711, 0.762],
                                                                   'sensor_2_xyz' => [3.3711, 6.0313, 0.762] },
                         'Gym_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.5,
                                                  'sensor_2_frac' => 0.5,
                                                  'sensor_1_xyz' => [19, 24, 0],
                                                  'sensor_2_xyz' => [2, 24, 0] },
                         'LIBRARY_MEDIA_CENTER_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.21,
                                                                   'sensor_2_frac' => 0.11,
                                                                   'sensor_1_xyz' => [20.6472, 17.5, 0.762],
                                                                   'sensor_2_xyz' => [12, 31.6472, 0.762] },
                         'Lobby_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.18,
                                                    'sensor_2_frac' => 0.18,
                                                    'sensor_1_xyz' => [7.5, 1.6764, 0.762],
                                                    'sensor_2_xyz' => [7.5, 3.3528, 0.762] },
                         'Lobby_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.18,
                                                    'sensor_2_frac' => 0.18,
                                                    'sensor_1_xyz' => [7.5, 1.6764, 0.762],
                                                    'sensor_2_xyz' => [7.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_1_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_1_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_2_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_2_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_1_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_3_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Mult_Class_2_Pod_3_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.28,
                                                                 'sensor_2_frac' => 0.28,
                                                                 'sensor_1_xyz' => [26.5, 1.6764, 0.762],
                                                                 'sensor_2_xyz' => [26.5, 3.3528, 0.762] },
                         'Offices_ZN_1_FLR_1 ZN' => { 'sensor_1_frac' => 0.36,
                                                      'sensor_2_frac' => 0.08,
                                                      'sensor_1_xyz' => [34.6472, 7.0104, 0.762],
                                                      'sensor_2_xyz' => [18.9982, 3.3528, 0.762] },
                         'Offices_ZN_1_FLR_2 ZN' => { 'sensor_1_frac' => 0.36,
                                                      'sensor_2_frac' => 0.08,
                                                      'sensor_1_xyz' => [34.6472, 7.0104, 0.762],
                                                      'sensor_2_xyz' => [18.9982, 3.3528, 0.762] } } }
    ]

    # Adjust daylight sensors in each space
    model.getSpaces.each do |space|
      if adjustments[0].keys.include?(template)
        if adjustments[0][template].keys.include?(space.name.to_s + ' ZN')
          adj = adjustments[0][template][space.name.to_s + ' ZN']
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

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)
    # Set original building North axis
    model_set_building_north_axis(model, 0.0)

    return true
  end

  def air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(air_terminal_single_duct_vav_reheat, zone_oa_per_area)
    min_damper_position = template == '90.1-2010' || template == '90.1-2013' || template == '90.1-2016' || template == '90.1-2019' ? 0.2 : 0.3

    # Set the minimum flow fraction
    air_terminal_single_duct_vav_reheat.setConstantMinimumAirFlowFraction(min_damper_position)

    return true
  end

  # Type of SAT reset for this building type
  #
  # @param air_loop_hvac [OpenStudio::model::AirLoopHVAC] Airloop
  # @return [String] Returns type of SAT reset
  def air_loop_hvac_supply_air_temperature_reset_type(air_loop_hvac)
    return 'oa'
  end

  # List transfer air target and source zones, and air aflow (cfm)
  #
  # code_sections [90.1-2019_6.5.7.1], [90.1-2016_6.5.7.1]
  # @return [Hash] target zones (key) and source zones (value) and air flow (value)
  def model_transfer_air_target_and_source_zones(model)
    model_transfer_air_target_and_source_zones_hash = {
      'Bathrooms_ZN_1_FLR_1 ZN' => ['Main_Corridor_ZN_1_FLR_1 ZN', 600.0],
      'Bathrooms_ZN_1_FLR_2 ZN' => ['Main_Corridor_ZN_1_FLR_2 ZN', 600.0]
    }
    return model_transfer_air_target_and_source_zones_hash
  end
end

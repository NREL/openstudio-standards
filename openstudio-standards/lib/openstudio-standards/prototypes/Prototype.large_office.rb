# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model

  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {
      'WholeBuilding - Lg Office' => [
        'Basement', 'Core_bottom', 'Core_mid', 'Core_top', #'GroundFloor_Plenum', 'MidFloor_Plenum', 'TopFloor_Plenum',
        'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4',
        'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4',
        'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4',
        'DataCenter_basement_ZN_6', 'DataCenter_bot_ZN_6', 'DataCenter_mid_ZN_6', 'DataCenter_top_ZN_6'
      ]
    }
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)

    case building_vintage
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
    system_to_space_map = [
      {
          'type' => 'VAV',
          'name' => 'VAV_1',
          'space_names' =>
          [
              'Perimeter_bot_ZN_1',
              'Perimeter_bot_ZN_2',
              'Perimeter_bot_ZN_3',
              'Perimeter_bot_ZN_4',
              'Core_bottom'
          ]
      },
      {
          'type' => 'VAV',
          'name' => 'VAV_2',
          'space_names' =>
          [
              'Perimeter_mid_ZN_1',
              'Perimeter_mid_ZN_2',
              'Perimeter_mid_ZN_3',
              'Perimeter_mid_ZN_4',
              'Core_mid'
          ]
      },
      {
          'type' => 'VAV',
          'name' => 'VAV_3',
          'space_names' =>
          [
              'Perimeter_top_ZN_1',
              'Perimeter_top_ZN_2',
              'Perimeter_top_ZN_3',
              'Perimeter_top_ZN_4',
              'Core_top'
          ]
      },
      {
          'type' => 'VAV',
          'name' => 'VAV_5',
          'space_names' =>
          [
              'Basement'
          ]
      }
    ]
    when '90.1-2004','90.1-2007','90.1-2010','90.1-2013'
    system_to_space_map = [
      {
          'type' => 'VAV',
          'name' => 'VAV_bot WITH REHEAT',
          'space_names' =>
          [
              'Perimeter_bot_ZN_1',
              'Perimeter_bot_ZN_2',
              'Perimeter_bot_ZN_3',
              'Perimeter_bot_ZN_4',
              'Core_bottom'
          ]
      },
      {
          'type' => 'VAV',
          'name' => 'VAV_mid WITH REHEAT',
          'space_names' =>
          [
              'Perimeter_mid_ZN_1',
              'Perimeter_mid_ZN_2',
              'Perimeter_mid_ZN_3',
              'Perimeter_mid_ZN_4',
              'Core_mid'
          ]
      },
      {
          'type' => 'VAV',
          'name' => 'VAV_top WITH REHEAT',
          'space_names' =>
          [
              'Perimeter_top_ZN_1',
              'Perimeter_top_ZN_2',
              'Perimeter_top_ZN_3',
              'Perimeter_top_ZN_4',
              'Core_top'
          ]
      },
      {
          'type' => 'CAV',
          'name' => 'CAV_bas',
          'space_names' =>
          [
              'Basement'
          ]
      },
      {
          'type' => 'DC',
          'space_names' =>
          [
              'DataCenter_basement_ZN_6'
          ],
          'load' => 484.423246742185,
          'main_data_center' => true
      },
      {
          'type' => 'DC',
          'space_names' =>
          [
              'DataCenter_bot_ZN_6'
          ],
          'load' => 215.299220774304,
          'main_data_center' => false
      },
      {
          'type' => 'DC',
          'space_names' =>
          [
              'DataCenter_mid_ZN_6'
          ],
          'load' => 215.299220774304,
          'main_data_center' => false
      },
      {
          'type' => 'DC',
          'space_names' =>
          [
              'DataCenter_top_ZN_6'
          ],
          'load' => 215.299220774304,
          'main_data_center' => false
      }
    ]
    end

    return system_to_space_map
    
  end

  def define_space_multiplier
    # This map define the multipliers for spaces with multipliers not equals to 1
    space_multiplier_map = {
        'Perimeter_mid_ZN_1' => 10,
        'Perimeter_mid_ZN_2'=> 10,
        'Perimeter_mid_ZN_3'=> 10,
        'Perimeter_mid_ZN_4'=> 10,
        'Core_mid'=> 10
    }
    return space_multiplier_map
  end
  
  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    return true

  end

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
    water_heaters = main_swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)

    water_heaters.each do |water_heater|
      water_heater = water_heater.to_WaterHeaterMixed.get
      # water_heater.setAmbientTemperatureIndicator('Zone')
      # water_heater.setAmbientTemperatureThermalZone(default_water_heater_ambient_temp_sch)
      water_heater.setOffCycleParasiticFuelConsumptionRate(2771)
      water_heater.setOnCycleParasiticFuelConsumptionRate(2771)
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(11.25413987)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(11.25413987)
    end

    # spaces = define_space_type_map(building_type, building_vintage, climate_zone)['WholeBuilding - Lg Office']

    # spaces.each do |space|
    #   self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    # end

    for i in 0..2
      self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    end
    # self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")

    return true

  end #add swh

end


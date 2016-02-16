# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model

  def define_space_type_map(building_type, building_vintage, climate_zone)
    case building_vintage
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      space_type_map = {
      'WholeBuilding - Lg Office' => [
        'Basement', 'Core_bottom', 'Core_mid', 'Core_top', #'GroundFloor_Plenum', 'MidFloor_Plenum', 'TopFloor_Plenum',
        'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4',
        'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4',
        'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4'
      ]
    }
    when '90.1-2004','90.1-2007','90.1-2010','90.1-2013'
      space_type_map = {
      'WholeBuilding - Lg Office' => [
        'Basement', 'Core_bottom', 'Core_mid', 'Core_top', #'GroundFloor_Plenum', 'MidFloor_Plenum', 'TopFloor_Plenum',
        'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4',
        'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4',
        'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4'
      ],
      'OfficeLarge Data Center' => [
        'DataCenter_bot_ZN_6', 'DataCenter_mid_ZN_6', 'DataCenter_top_ZN_6'
      ],
      'OfficeLarge Main Data Center' => [
        'DataCenter_basement_ZN_6'
      ]
    }
    end
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
            ],
            'return_plenum' => 'GroundFloor_Plenum'
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
            ],
            'return_plenum' => 'MidFloor_Plenum'
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
            ],
            'return_plenum' => 'TopFloor_Plenum'
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
          ],
          'return_plenum' => 'GroundFloor_Plenum'
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
          ],
          'return_plenum' => 'MidFloor_Plenum'
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
          ],
          'return_plenum' => 'TopFloor_Plenum'
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
      'DataCenter_mid_ZN_6' => 10,
      'Perimeter_mid_ZN_1' => 10,
      'Perimeter_mid_ZN_2' => 10,
      'Perimeter_mid_ZN_3' => 10,
      'Perimeter_mid_ZN_4' => 10,
      'Core_mid' => 10,
      'MidFloor_Plenum' => 10
    }
    return space_multiplier_map
  end

  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)


    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    system_to_space_map.each do |system|

      #find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = self.getSpaceByName(space_name)
        if space.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
          return false
        end
        thermal_zones << zone.get
      end

      return_plenum = nil
      unless system['return_plenum'].nil?
        return_plenum_space = self.getSpaceByName(system['return_plenum'])
        if return_plenum_space.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model")
          return false
        end
        return_plenum_space = return_plenum_space.get
        return_plenum = return_plenum_space.thermalZone
        if return_plenum.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{system['return_plenum']}")
          return false
        end
        return_plenum = return_plenum.get
      end

    end

    return true

  end

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
    water_heaters = main_swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)

    water_heaters.each do |water_heater|
      water_heater = water_heater.to_WaterHeaterMixed.get
      # water_heater.setAmbientTemperatureIndicator('Zone')
      # water_heater.setAmbientTemperatureThermalZone()
      water_heater.setOffCycleParasiticFuelConsumptionRate(2771)
      water_heater.setOnCycleParasiticFuelConsumptionRate(2771)
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(11.25413987)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(11.25413987)
    end

    # spaces = define_space_type_map(building_type, building_vintage, climate_zone)['WholeBuilding - Lg Office']

    ['Core_bottom', 'Core_mid', 'Core_top'].each do |space_name|
      self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main', space_name)
    end

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")

    return true

  end #add swh

end

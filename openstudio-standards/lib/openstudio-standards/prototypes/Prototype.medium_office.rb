
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {
      'WholeBuilding - Md Office' => [
        'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom',
        'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid',
        'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'
      ]
    }
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    case building_vintage
    when 'DOE Ref Pre-1980'
      system_to_space_map = [
      {
          'type' => 'PSZ-AC',
          'space_names' =>
          [
              'Perimeter_bot_ZN_1',
              'Perimeter_bot_ZN_2',
              'Perimeter_bot_ZN_3',
              'Perimeter_bot_ZN_4',
              'Core_bottom',
              'Perimeter_mid_ZN_1',
              'Perimeter_mid_ZN_2',
              'Perimeter_mid_ZN_3',
              'Perimeter_mid_ZN_4',
              'Core_mid',
              'Perimeter_top_ZN_1',
              'Perimeter_top_ZN_2',
              'Perimeter_top_ZN_3',
              'Perimeter_top_ZN_4',
              'Core_top'
          ]
      }
    ]
    else
      system_to_space_map = [
        {
            'type' => 'PVAV',
            'space_names' =>
            [
                'Perimeter_bot_ZN_1',
                'Perimeter_bot_ZN_2',
                'Perimeter_bot_ZN_3',
                'Perimeter_bot_ZN_4',
                'Core_bottom'
            ],
            'return_plenum' => 'FirstFloor_Plenum'
        },
        {
            'type' => 'PVAV',
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
            'type' => 'PVAV',
            'space_names' =>
            [
                'Perimeter_top_ZN_1',
                'Perimeter_top_ZN_2',
                'Perimeter_top_ZN_3',
                'Perimeter_top_ZN_4',
                'Core_top'
            ],
            'return_plenum' => 'TopFloor_Plenum'
        }
      ]
    end
    return system_to_space_map
  end
     
  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')
    
    self.getSpaces.each do |space|
    
      if space.name.get.to_s == "Core_bottom"
        self.add_elevator(building_vintage,
                         space,
                         prototype_input['number_of_elevators'],
                         prototype_input['elevator_type'],
                         prototype_input['elevator_schedule'],
                         prototype_input['elevator_fan_schedule'],
                         prototype_input['elevator_fan_schedule'],
                         building_type)
      end    
    
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')
    
    return true
    
  end #add hvac

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main', nil, building_type)
    water_heaters = main_swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)

    unless building_vintage == 'DOE Ref 1980-2004' or building_vintage == 'DOE Ref Pre-1980'
      water_heaters.each do |water_heater|
        water_heater = water_heater.to_WaterHeaterMixed.get
        # water_heater.setAmbientTemperatureIndicator('Zone')
        # water_heater.setAmbientTemperatureThermalZone(default_water_heater_ambient_temp_sch)
        water_heater.setOffCycleParasiticFuelConsumptionRate(1277)
        water_heater.setOnCycleParasiticFuelConsumptionRate(1277)
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
      end
    end

    # spaces = define_space_type_map(building_type, building_vintage, climate_zone)['WholeBuilding - Md Office']

    space_type_map.each do |space_type_name, space_names|
      space_names.each do |space_name|
          if building_vintage == 'DOE Ref 1980-2004' or building_vintage == 'DOE Ref Pre-1980'
            if space_name == 'Core_bottom' || space_name == 'Core_mid' || space_name == 'Core_top'
              self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
            end
          else
            self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
          end
        end
    end

    # spaces.each do |space|
    #   self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    # end

    # for i in 0..13
    #   self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    # end
    # self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh

end

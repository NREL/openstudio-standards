
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
          'type' => 'PSZ',
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
     
  def add_hvac(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    # hot_water_loop = self.add_hw_loop(prototype_input, hvac_standards)
    
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
    		if space_name == "Core_bottom"
    			self.add_elevator(prototype_input, hvac_standards, space)
    		end
        thermal_zones << zone.get
      end

      unless system['return_plenum'].nil?
        return_plenum_space = self.getSpaceByName(system['return_plenum'])
        if return_plenum_space.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model")
          return false
        end
        return_plenum_space = return_plenum_space.get
        return_plenum_zone = return_plenum_space.thermalZone
        if return_plenum_zone.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{system['return_plenum']}")
          return false
        end
      end

      case system['type']
      when 'PVAV'
        self.add_pvav(prototype_input, hvac_standards, system['name'], thermal_zones, nil, nil)
      when 'PSZ'
        self.add_psz_ac(prototype_input, hvac_standards, system['name'], thermal_zones)
      end

    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    
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
        # puts "#{building_type}, blah #{building_vintage}, blah2 #{climate_zone}, blah3 #{space_type_name}, blah4 #{space_name}"
          # self.add_swh_end_uses_by_space(building_type, building_vintage, climate_zone, main_swh_loop, space_type_name, space_name)
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


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
          'type' => 'DC_main',
          'space_names' =>
          [
              'DataCenter_basement_ZN_6'
          ]
      },
      {
          'type' => 'DC',
          'space_names' =>
          [
              'DataCenter_bot_ZN_6'
          ]
      },
      {
          'type' => 'DC',
          'space_names' =>
          [
              'DataCenter_mid_ZN_6'
          ]
      },
      {
          'type' => 'DC',
          'space_names' =>
          [
              'DataCenter_top_ZN_6'
          ]
      }
    ]
    return system_to_space_map
  end
     
  def add_hvac(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    condenser_water_loop = self.add_cw_loop(prototype_input, hvac_standards, 2)
    
    chilled_water_loop = self.add_chw_loop(prototype_input, hvac_standards, condenser_water_loop)

    hot_water_loop = self.add_hw_loop(prototype_input, hvac_standards)
    
    heat_pump_loop = self.add_hp_loop(prototype_input, hvac_standards)
    
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

      case system['type']
      when 'VAV'
        if hot_water_loop && chilled_water_loop
          self.add_vav(prototype_input, hvac_standards, system['name'], hot_water_loop, chilled_water_loop, thermal_zones)
        else
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water and chilled water plant loops in model')
          return false
        end
      when 'CAV'
        if hot_water_loop && chilled_water_loop
          self.add_psz_ac(prototype_input, hvac_standards, system['name'], thermal_zones, 'DrawThrough', hot_water_loop, chilled_water_loop)
        else
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water and chilled water plant loops in model')
          return false
        end
      when 'DC_main'
        if hot_water_loop && chilled_water_loop
          self.add_data_center_hvac(prototype_input, hvac_standards, thermal_zones, hot_water_loop, heat_pump_loop, true)
        else
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water and chilled water plant loops in model')
          return false
        end
      when 'DC'
        if hot_water_loop && chilled_water_loop
          self.add_data_center_hvac(prototype_input, hvac_standards, thermal_zones, hot_water_loop, heat_pump_loop)
        else
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water and chilled water plant loops in model')
          return false
        end
      end

    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    
    return true
    
  end #add hvac

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
  
  def add_refrigeration(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
       
    return false
    
  end #add refrigeration
  
end

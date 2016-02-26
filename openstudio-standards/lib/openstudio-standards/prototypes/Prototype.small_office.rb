
# Extend the class to add Small Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = nil
    
    case building_vintage
    when 'NECB 2011'
      space_type_map ={
        "- undefined -" => ["Attic"],
        "Office - enclosed" => ["Core_ZN", "Perimeter_ZN_1", "Perimeter_ZN_2", "Perimeter_ZN_3", "Perimeter_ZN_4"]
      }
    else
      space_type_map = {
        'WholeBuilding - Sm Office' => ['Perimeter_ZN_1', 'Perimeter_ZN_2', 'Perimeter_ZN_3', 'Perimeter_ZN_4', 'Core_ZN'],
        'Attic' => ['Attic']
      }
    end
    return space_type_map

  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)

    system_to_space_map = [
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-2',
        'space_names' =>
          [
          'Perimeter_ZN_1'
        ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-3',
        'space_names' =>
          [
          'Perimeter_ZN_2'
        ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-4',
        'space_names' =>
          [
          'Perimeter_ZN_3'
        ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-5',
        'space_names' =>
          [
          'Perimeter_ZN_4'
        ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC-1',
        'space_names' =>
          [
          'Core_ZN'
        ]
      }
    ]

    return system_to_space_map

  end

  def add_hvac(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    
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
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Space #{space_name} is not assigned to a thermal zone.")
          return false
        end
        thermal_zones << zone.get
      end

      case system['type']
      when 'PSZ-AC'
        self.add_psz_ac(prototype_input, hvac_standards, system['name'], thermal_zones)
      end

    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    
    return true
    
  end #add hvac

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
    
    case building_vintage
    when 'NECB 2011'
        space_type_map.each do |space_type_name, space_names|
        space_names.each do |space_name|
          space = self.getSpaceByName(space_name).get
          space_multiplier = space.multiplier
          self.add_swh_end_uses_by_space('Space Function', building_vintage, climate_zone, main_swh_loop, space_type_name, space_name, space_multiplier)
        end   
      end    
    else  
      self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    end
    
    
    
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh
  
end


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

  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)
   
    return true
    
  end

  def custom_swh_tweaks(building_type, building_vintage, climate_zone, prototype_input)
   
    return true
    
  end
  
end

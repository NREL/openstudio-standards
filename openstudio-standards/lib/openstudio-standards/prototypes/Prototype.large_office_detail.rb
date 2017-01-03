# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
  def define_space_type_map(building_type, template, climate_zone)
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      space_type_map = {
        'WholeBuilding - Lg Office' => [
          'Basement', 'Core_bottom', 'Core_mid', 'Core_top', # 'GroundFloor_Plenum', 'MidFloor_Plenum', 'TopFloor_Plenum',
          'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4',
          'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4',
          'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4'
        ]
      }
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      space_type_map = {
        'OpenOffice' => [
          'OpenOffice_Basement_ZN_1', 'OpenOffice_Basement_ZN_2', 'OpenOffice_Bot_ZN_1','OpenOffice_Bot_ZN_2','OpenOffice_Bot_ZN_3', 
			'OpenOffice_Mid_ZN_1','OpenOffice_Mid_ZN_2','OpenOffice_Mid_ZN_3','OpenOffice_Mid_ZN_4','OpenOffice_Top_ZN_1','OpenOffice_Top_ZN_2','OpenOffice_Top_ZN_3','OpenOffice_Top_ZN_4'],
        'ClosedOffice' => [
		 'EnclosedOffice_Basement_ZN_1','EnclosedOffice_Basement_ZN_2','EnclosedOffice_Basement_ZN_3','EnclosedOffice_Bot_ZN_1','EnclosedOffice_Bot_ZN_2','EnclosedOffice_Bot_ZN_3',
		 'EnclosedOffice_Bot_ZN_4','EnclosedOffice_Bot_ZN_5','EnclosedOffice_Bot_ZN_6','EnclosedOffice_Mid_ZN_1','EnclosedOffice_Mid_ZN_2','EnclosedOffice_Mid_ZN_3',
		 'EnclosedOffice_Mid_ZN_4','EnclosedOffice_Mid_ZN_5','EnclosedOffice_Mid_ZN_6','EnclosedOffice_Mid_ZN_7','EnclosedOffice_Mid_ZN_8','EnclosedOffice_Top_ZN_1','EnclosedOffice_Top_ZN_2','EnclosedOffice_Top_ZN_3',
		 'EnclosedOffice_Top_ZN_4','EnclosedOffice_Top_ZN_5','EnclosedOffice_Top_ZN_6','EnclosedOffice_Top_ZN_7','EnclosedOffice_Top_ZN_8'],
		'Elec/MechRoom'=> ['Mechanical_Basement_ZN_1','Mechanical_Basement_ZN_2','Mechanical_Bot_ZN_1','Mechanical_Bot_ZN_2','Mechanical_Mid_ZN_1','Mechanical_Mid_ZN_2','Mechanical_Top_ZN_1','Mechanical_Top_ZN_2'],
		'Corridor' => ['Corridor_Basement_ZN_1','Corridor_Basement_ZN_2','Corridor_Basement_ZN_3','Corridor_Bot_ZN_1','Corridor_Bot_ZN_2','Corridor_Mid_ZN_1','Corridor_Mid_ZN_2','Corridor_Top_ZN_1','Corridor_Top_ZN_2'],
		'Restroom' => ['Restroom_Basement_ZN','Restroom_Bot_ZN','Restroom_Mid_ZN','Restroom_Top_ZN'],
		'Lobby' => ['Lobby_Basement_ZN','Lobby_Bot_ZN_1','Lobby_Bot_ZN_2','Lobby_Mid_ZN','Lobby_Top_ZN','Atrium_Bot_ZN'],
		'Stair' => ['Stair_Basement_ZN_1','Stair_Basement_ZN_2','Stair_Bot_ZN_1','Stair_Bot_ZN_2','Stair_Mid_ZN_1','Stair_Mid_ZN_2','Stair_Top_ZN_1','Stair_Top_ZN_2'],
		'Dining' => ['Dining_Basement_ZN', 'Dining_Bot_ZN','Dining_Mid_ZN','Dining_Top_ZN'],
		'Conference' => ['ConfRoom_Basement_ZN','ConfRoom_Bot_ZN_1','ConfRoom_Bot_ZN_2','ConfRoom_Mid_ZN_1','ConfRoom_Mid_ZN_2','ConfRoom_Top_ZN_1','ConfRoom_Top_ZN_2'],
		'Storage' => ['ActiveStorage_Basement_ZN','ActiveStorage_Bot_ZN','ActiveStorage_Mid_ZN','ActiveStorage_Top_ZN'],
		'Classroom' => ['Classroom_Basement_ZN','Classroom_Bot_ZN','Classroom_Mid_ZN','Classroom_Top_ZN'],
		'BreakRoom' => ['Lounge_Bot_ZN','Workshop_Basement_ZN','FoodPrep_Basement_ZN','Locker_Basement_ZN'],
		'OfficeLarge Data Center' => ['DataCenter_Bot_ZN', 'DataCenter_Mid_ZN', 'DataCenter_Top_ZN'],
        'OfficeLarge Main Data Center' => ['DataCenter_Basement_ZN']
      } 
    when 'NECB 2011'
      # Dom is A
      space_type_map = {
        'Electrical/Mechanical' => ['Basement'],

        'Office - open plan' => ['Core_bottom', 'Core_mid', 'Core_top', 'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'DataCenter_basement_ZN_6', 'DataCenter_bot_ZN_6', 'DataCenter_mid_ZN_6', 'DataCenter_top_ZN_6'],
        '- undefined -' => ['GroundFloor_Plenum', 'TopFloor_Plenum', 'MidFloor_Plenum']
      }
    end
    return space_type_map
  end

  def define_hvac_system_map(building_type, template, climate_zone)
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      system_to_space_map = [
        {
          'type' => 'VAV',
          'name' => 'VAV_1',
          'space_names' =>
            ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom'],
          'return_plenum' => 'GroundFloor_Plenum'
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_2',
          'space_names' =>
            ['Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid'],
          'return_plenum' => 'MidFloor_Plenum'
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_3',
          'space_names' =>
            ['Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'],
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
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      system_to_space_map = [
        {
          'type' => 'VAV',
          'name' => 'VAV_bot WITH REHEAT',
          'space_names' =>
          ['OpenOffice_Bot_ZN_1','OpenOffice_Bot_ZN_2','OpenOffice_Bot_ZN_3','EnclosedOffice_Bot_ZN_1','EnclosedOffice_Bot_ZN_2','EnclosedOffice_Bot_ZN_3',
		 'EnclosedOffice_Bot_ZN_4','EnclosedOffice_Bot_ZN_5','EnclosedOffice_Bot_ZN_6','Mechanical_Bot_ZN_1','Mechanical_Bot_ZN_2',
		 'Corridor_Bot_ZN_1','Corridor_Bot_ZN_2','Restroom_Bot_ZN','Lobby_Bot_ZN_1','Lobby_Bot_ZN_2','Stair_Bot_ZN_1','Stair_Bot_ZN_2','Dining_Bot_ZN',
		 'ConfRoom_Bot_ZN_1','ConfRoom_Bot_ZN_2','ActiveStorage_Bot_ZN','Atrium_Bot_ZN','Classroom_Bot_ZN','Lounge_Bot_ZN'],
          'return_plenum' => 'BotFloor_Plenum'
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_mid WITH REHEAT',
          'space_names' =>
            ['OpenOffice_Mid_ZN_1','OpenOffice_Mid_ZN_2','OpenOffice_Mid_ZN_3','OpenOffice_Mid_ZN_4','EnclosedOffice_Mid_ZN_1','EnclosedOffice_Mid_ZN_2','EnclosedOffice_Mid_ZN_3',
		 'EnclosedOffice_Mid_ZN_4','EnclosedOffice_Mid_ZN_5','EnclosedOffice_Mid_ZN_6','EnclosedOffice_Mid_ZN_7','EnclosedOffice_Mid_ZN_8','Mechanical_Mid_ZN_1','Mechanical_Mid_ZN_2',
		 'Corridor_Mid_ZN_1','Corridor_Mid_ZN_2','Restroom_Mid_ZN','Lobby_Mid_ZN','Stair_Mid_ZN_1','Stair_Mid_ZN_2','Dining_Mid_ZN',
		 'ConfRoom_Mid_ZN_1','ConfRoom_Mid_ZN_2','ActiveStorage_Mid_ZN','Classroom_Mid_ZN'],
          'return_plenum' => 'MidFloor_Plenum'
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_top WITH REHEAT',
          'space_names' =>
            ['OpenOffice_Top_ZN_1','OpenOffice_Top_ZN_2','OpenOffice_Top_ZN_3','OpenOffice_Top_ZN_4','EnclosedOffice_Top_ZN_1','EnclosedOffice_Top_ZN_2','EnclosedOffice_Top_ZN_3',
		 'EnclosedOffice_Top_ZN_4','EnclosedOffice_Top_ZN_5','EnclosedOffice_Top_ZN_6','EnclosedOffice_Top_ZN_7','EnclosedOffice_Top_ZN_8','Mechanical_Top_ZN_1','Mechanical_Top_ZN_2',
		 'Corridor_Top_ZN_1','Corridor_Top_ZN_2','Restroom_Top_ZN','Lobby_Top_ZN','Stair_Top_ZN_1','Stair_Top_ZN_2','Dining_Top_ZN',
		 'ConfRoom_Top_ZN_1','ConfRoom_Top_ZN_2','ActiveStorage_Top_ZN','Classroom_Top_ZN'],
          'return_plenum' => 'TopFloor_Plenum'
        },
        {

          'type' => 'VAV',
          'name' => 'VAV_bas',
          'space_names' =>
          ['OpenOffice_Basement_ZN_1','OpenOffice_Basement_ZN_2','EnclosedOffice_Basement_ZN_1','EnclosedOffice_Basement_ZN_2','EnclosedOffice_Basement_ZN_3',
		 'Mechanical_Basement_ZN_1','Mechanical_Basement_ZN_2', 'Corridor_Basement_ZN_1','Corridor_Basement_ZN_2','Corridor_Basement_ZN_3','Restroom_Basement_ZN','Lobby_Basement_ZN','Stair_Basement_ZN_1','Stair_Basement_ZN_2','Dining_Basement_ZN',
		 'ConfRoom_Basement_ZN','ActiveStorage_Basement_ZN','Classroom_Basement_ZN','Workshop_Basement_ZN','FoodPrep_Basement_ZN','Locker_Basement_ZN'
               ]
        },
        {
          'type' => 'DC',
          'space_names' =>
            [
              'DataCenter_Basement_ZN'
            ],
          'load' => 484.423246742185,
          'main_data_center' => true
        },
        {
          'type' => 'DC',
          'space_names' =>
            [
              'DataCenter_Bot_ZN'
            ],
          'load' => 215.299220774304,
          'main_data_center' => false
        },
        {
          'type' => 'DC',
          'space_names' =>
            [
              'DataCenter_Mid_ZN'
            ],
          'load' => 215.299220774304,
          'main_data_center' => false
        },
        {
          'type' => 'DC',
          'space_names' =>
            [
              'DataCenter_Top_ZN'
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
      'OpenOffice_Mid_ZN_1' => 10,
	  'OpenOffice_Mid_ZN_2' => 10,
	  'OpenOffice_Mid_ZN_3' => 10,
	  'OpenOffice_Mid_ZN_4' => 10,
	  'EnclosedOffice_Mid_ZN_1' => 10,
	  'EnclosedOffice_Mid_ZN_2' => 10,
	  'EnclosedOffice_Mid_ZN_3' => 10,
	  'EnclosedOffice_Mid_ZN_4' => 10,
	  'EnclosedOffice_Mid_ZN_5' => 10,
	  'EnclosedOffice_Mid_ZN_6' => 10,
	  'EnclosedOffice_Mid_ZN_7' => 10,
	  'EnclosedOffice_Mid_ZN_8' => 10,
      'Mechanical_Mid_ZN_1' => 10,
	  'Mechanical_Mid_ZN_2' => 10,
	  'Corridor_Mid_ZN_1' => 10,
	  'Corridor_Mid_ZN_2' => 10,
	  'Restroom_Mid_ZN' => 10,
	  'Lobby_Mid_ZN' => 10,
	  'Stair_Mid_ZN_1' => 10,
	  'Stair_Mid_ZN_2' => 10,
	  'Dining_Mid_ZN' => 10,
	  'ConfRoom_Mid_ZN_1' => 10,
	  'ConfRoom_Mid_ZN_2' => 10,
	  'ActiveStorage_Mid_ZN' => 10,
	  'Classroom_Mid_ZN' => 10,
      'MidFloor_Plenum' => 10,
	  'DataCenter_Mid_ZN' => 10
    }
    return space_multiplier_map
  end

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input)
    system_to_space_map = define_hvac_system_map(building_type, template, climate_zone)

    system_to_space_map.each do |system|
      # find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = getSpaceByName(space_name)
        if space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
          return false
        end
        thermal_zones << zone.get
      end

      return_plenum = nil
      unless system['return_plenum'].nil?
        return_plenum_space = getSpaceByName(system['return_plenum'])
        if return_plenum_space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model")
          return false
        end
        return_plenum_space = return_plenum_space.get
        return_plenum = return_plenum_space.thermalZone
        if return_plenum.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{system['return_plenum']}")
          return false
        end
        return_plenum = return_plenum.get
      end
    end

    return true
  end

  def update_waterheater_loss_coefficient(template)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(11.25413987)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(11.25413987)
      end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(template)
    return true
  end
end

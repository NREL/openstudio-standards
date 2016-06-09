
# Extend the class to add Secondary School specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)


    space_type_map = nil
  
    case building_vintage
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'  
      space_type_map = {
        'Office' => ['Offices_ZN_1_FLR_1', 'Offices_ZN_1_FLR_2'],
        'Lobby' => ['Lobby_ZN_1_FLR_2', 'Lobby_ZN_1_FLR_1'],
        'Gym' => ['Gym_ZN_1_FLR_1'],
        'Gym - audience' => ['Aux_Gym_ZN_1_FLR_1'],
        'Mechanical' => ['Mech_ZN_1_FLR_2', 'Mech_ZN_1_FLR_1'],
        'Cafeteria' => ['Cafeteria_ZN_1_FLR_1'],
        'Kitchen' => ['Kitchen_ZN_1_FLR_1'],
        'Restroom' => ['Bathrooms_ZN_1_FLR_2', 'Bathrooms_ZN_1_FLR_1'],
        'Auditorium' => ['Auditorium_ZN_1_FLR_1'],
        'Library' => ['LIBRARY_MEDIA_CENTER_ZN_1_FLR_2'],
        'Corridor' => ['Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_2',
          'Main_Corridor_ZN_1_FLR_2', 'Main_Corridor_ZN_1_FLR_1',
          'Corridor_Pod_3_ZN_1_FLR_1', 'Corridor_Pod_1_ZN_1_FLR_2',
          'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_2'],
        'Classroom' => [
          'Mult_Class_2_Pod_2_ZN_1_FLR_2',
          'Mult_Class_2_Pod_3_ZN_1_FLR_1',
          'Corner_Class_2_Pod_1_ZN_1_FLR_1',
          'Mult_Class_2_Pod_1_ZN_1_FLR_2',
          'Corner_Class_1_Pod_1_ZN_1_FLR_1',
          'Corner_Class_2_Pod_1_ZN_1_FLR_2',
          'Corner_Class_1_Pod_2_ZN_1_FLR_2',
          'Mult_Class_1_Pod_1_ZN_1_FLR_2',
          'Corner_Class_2_Pod_2_ZN_1_FLR_2',
          'Mult_Class_2_Pod_2_ZN_1_FLR_1',
          'Mult_Class_2_Pod_3_ZN_1_FLR_2',
          'Corner_Class_1_Pod_3_ZN_1_FLR_1',
          'Mult_Class_1_Pod_1_ZN_1_FLR_1',
          'Mult_Class_1_Pod_2_ZN_1_FLR_2',
          'Mult_Class_1_Pod_2_ZN_1_FLR_1',
          'Mult_Class_2_Pod_1_ZN_1_FLR_1',
          'Mult_Class_1_Pod_3_ZN_1_FLR_1',
          'Corner_Class_1_Pod_1_ZN_1_FLR_2',
          'Corner_Class_1_Pod_2_ZN_1_FLR_1',
          'Corner_Class_2_Pod_2_ZN_1_FLR_1',
          'Corner_Class_1_Pod_3_ZN_1_FLR_2',
          'Mult_Class_1_Pod_3_ZN_1_FLR_2',
          'Corner_Class_2_Pod_3_ZN_1_FLR_1',
          'Corner_Class_2_Pod_3_ZN_1_FLR_2'
        ]
      }
    when 'NECB 2011'
      space_type_map ={
        "Audience - auditorium" => ["Auditorium_ZN_1_FLR_1"],
        "Gym - play" => ["Aux_Gym_ZN_1_FLR_1", "Gym_ZN_1_FLR_1"],
        "Washroom" => ["Bathrooms_ZN_1_FLR_1", "Bathrooms_ZN_1_FLR_2"],
        "Conf./meet./multi-purpose" => ["Cafeteria_ZN_1_FLR_1"],
        "Classroom/lecture/training" => ["Corner_Class_1_Pod_1_ZN_1_FLR_1", "Corner_Class_1_Pod_1_ZN_1_FLR_2", "Corner_Class_1_Pod_2_ZN_1_FLR_1", "Corner_Class_1_Pod_2_ZN_1_FLR_2", "Corner_Class_1_Pod_3_ZN_1_FLR_1", "Corner_Class_1_Pod_3_ZN_1_FLR_2", "Corner_Class_2_Pod_1_ZN_1_FLR_1", "Corner_Class_2_Pod_1_ZN_1_FLR_2", "Corner_Class_2_Pod_2_ZN_1_FLR_1", "Corner_Class_2_Pod_2_ZN_1_FLR_2", "Corner_Class_2_Pod_3_ZN_1_FLR_1", "Corner_Class_2_Pod_3_ZN_1_FLR_2", "Mult_Class_1_Pod_1_ZN_1_FLR_1", "Mult_Class_1_Pod_1_ZN_1_FLR_2", "Mult_Class_1_Pod_2_ZN_1_FLR_1", "Mult_Class_1_Pod_2_ZN_1_FLR_2", "Mult_Class_1_Pod_3_ZN_1_FLR_1", "Mult_Class_1_Pod_3_ZN_1_FLR_2", "Mult_Class_2_Pod_1_ZN_1_FLR_1", "Mult_Class_2_Pod_1_ZN_1_FLR_2", "Mult_Class_2_Pod_2_ZN_1_FLR_1", "Mult_Class_2_Pod_2_ZN_1_FLR_2", "Mult_Class_2_Pod_3_ZN_1_FLR_1", "Mult_Class_2_Pod_3_ZN_1_FLR_2"],
        "Corr. >= 2.4m wide" => ["Corridor_Pod_1_ZN_1_FLR_1", "Corridor_Pod_1_ZN_1_FLR_2", "Corridor_Pod_2_ZN_1_FLR_1", "Corridor_Pod_2_ZN_1_FLR_2", "Corridor_Pod_3_ZN_1_FLR_1", "Corridor_Pod_3_ZN_1_FLR_2", "Main_Corridor_ZN_1_FLR_1", "Main_Corridor_ZN_1_FLR_2"],
        "Food preparation" => ["Kitchen_ZN_1_FLR_1"],
        "Library - reading" => ["LIBRARY_MEDIA_CENTER_ZN_1_FLR_2"],
        "Lobby - elevator" => ["Lobby_ZN_1_FLR_1", "Lobby_ZN_1_FLR_2"],
        "Electrical/Mechanical" => ["Mech_ZN_1_FLR_1", "Mech_ZN_1_FLR_2"],
        "Office - enclosed" => ["Offices_ZN_1_FLR_1", "Offices_ZN_1_FLR_2"]
      }
    else
      space_type_map = {
        'Office' => ['Offices_ZN_1_FLR_1', 'Offices_ZN_1_FLR_2'],
        'Lobby' => ['Lobby_ZN_1_FLR_2', 'Lobby_ZN_1_FLR_1'],
        'Gym' => ['Gym_ZN_1_FLR_1', 'Aux_Gym_ZN_1_FLR_1'],
        'Mechanical' => ['Mech_ZN_1_FLR_2', 'Mech_ZN_1_FLR_1'],
        'Cafeteria' => ['Cafeteria_ZN_1_FLR_1'],
        'Kitchen' => ['Kitchen_ZN_1_FLR_1'],
        'Restroom' => ['Bathrooms_ZN_1_FLR_2', 'Bathrooms_ZN_1_FLR_1'],
        'Auditorium' => ['Auditorium_ZN_1_FLR_1'],
        'Library' => ['LIBRARY_MEDIA_CENTER_ZN_1_FLR_2'],
        'Corridor' => ['Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_2',
          'Main_Corridor_ZN_1_FLR_2', 'Main_Corridor_ZN_1_FLR_1',
          'Corridor_Pod_3_ZN_1_FLR_1', 'Corridor_Pod_1_ZN_1_FLR_2',
          'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_2'],
        'Classroom' => [
          'Mult_Class_2_Pod_2_ZN_1_FLR_2',
          'Mult_Class_2_Pod_3_ZN_1_FLR_1',
          'Corner_Class_2_Pod_1_ZN_1_FLR_1',
          'Mult_Class_2_Pod_1_ZN_1_FLR_2',
          'Corner_Class_1_Pod_1_ZN_1_FLR_1',
          'Corner_Class_2_Pod_1_ZN_1_FLR_2',
          'Corner_Class_1_Pod_2_ZN_1_FLR_2',
          'Mult_Class_1_Pod_1_ZN_1_FLR_2',
          'Corner_Class_2_Pod_2_ZN_1_FLR_2',
          'Mult_Class_2_Pod_2_ZN_1_FLR_1',
          'Mult_Class_2_Pod_3_ZN_1_FLR_2',
          'Corner_Class_1_Pod_3_ZN_1_FLR_1',
          'Mult_Class_1_Pod_1_ZN_1_FLR_1',
          'Mult_Class_1_Pod_2_ZN_1_FLR_2',
          'Mult_Class_1_Pod_2_ZN_1_FLR_1',
          'Mult_Class_2_Pod_1_ZN_1_FLR_1',
          'Mult_Class_1_Pod_3_ZN_1_FLR_1',
          'Corner_Class_1_Pod_1_ZN_1_FLR_2',
          'Corner_Class_1_Pod_2_ZN_1_FLR_1',
          'Corner_Class_2_Pod_2_ZN_1_FLR_1',
          'Corner_Class_1_Pod_3_ZN_1_FLR_2',
          'Mult_Class_1_Pod_3_ZN_1_FLR_2',
          'Corner_Class_2_Pod_3_ZN_1_FLR_1',
          'Corner_Class_2_Pod_3_ZN_1_FLR_2'
        ]
      }    
    end
 

    return space_type_map

  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)

    system_to_space_map = nil
  
    case building_vintage
    when 'DOE Ref Pre-1980'
      system_to_space_map = [
        {
          'type' => 'CAV',
          'name' => 'CAV_POD_1',
          'space_names' =>
            [
            'Corner_Class_1_Pod_1_ZN_1_FLR_1',
            'Corner_Class_1_Pod_1_ZN_1_FLR_2',
            'Mult_Class_1_Pod_1_ZN_1_FLR_1',
            'Mult_Class_1_Pod_1_ZN_1_FLR_2',
            'Corridor_Pod_1_ZN_1_FLR_1',
            'Corridor_Pod_1_ZN_1_FLR_2',
            'Corner_Class_2_Pod_1_ZN_1_FLR_1',
            'Corner_Class_2_Pod_1_ZN_1_FLR_2',
            'Mult_Class_2_Pod_1_ZN_1_FLR_1',
            'Mult_Class_2_Pod_1_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'CAV',
          'name' => 'CAV_POD_2',
          'space_names' =>
            [
            'Corner_Class_1_Pod_2_ZN_1_FLR_1',
            'Corner_Class_1_Pod_2_ZN_1_FLR_2',
            'Mult_Class_1_Pod_2_ZN_1_FLR_1',
            'Mult_Class_1_Pod_2_ZN_1_FLR_2',
            'Corridor_Pod_2_ZN_1_FLR_1',
            'Corridor_Pod_2_ZN_1_FLR_2',
            'Corner_Class_2_Pod_2_ZN_1_FLR_1',
            'Corner_Class_2_Pod_2_ZN_1_FLR_2',
            'Mult_Class_2_Pod_2_ZN_1_FLR_1',
            'Mult_Class_2_Pod_2_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'CAV',
          'name' => 'CAV_POD_3',
          'space_names' =>
            [
            'Corner_Class_1_Pod_3_ZN_1_FLR_1',
            'Corner_Class_1_Pod_3_ZN_1_FLR_2',
            'Mult_Class_1_Pod_3_ZN_1_FLR_1',
            'Mult_Class_1_Pod_3_ZN_1_FLR_2',
            'Corridor_Pod_3_ZN_1_FLR_1',
            'Corridor_Pod_3_ZN_1_FLR_2',
            'Corner_Class_2_Pod_3_ZN_1_FLR_1',
            'Corner_Class_2_Pod_3_ZN_1_FLR_2',
            'Mult_Class_2_Pod_3_ZN_1_FLR_1',
            'Mult_Class_2_Pod_3_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'CAV',
          'name' => 'CAV_OTHER',
          'space_names' =>
            [
            'Main_Corridor_ZN_1_FLR_1',
            'Main_Corridor_ZN_1_FLR_2',
            'Lobby_ZN_1_FLR_1',
            'Lobby_ZN_1_FLR_2',
            'Bathrooms_ZN_1_FLR_1',
            'Bathrooms_ZN_1_FLR_2',
            'Offices_ZN_1_FLR_1',
            'Offices_ZN_1_FLR_2',
            'LIBRARY_MEDIA_CENTER_ZN_1_FLR_2',
            'Mech_ZN_1_FLR_1',
            'Mech_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_1-5',
          'space_names' =>
            [
            'Gym_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_2-6',
          'space_names' =>
            [
            'Aux_Gym_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_3-7',
          'space_names' =>
            [
            'Auditorium_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_4-8',
          'space_names' =>
            [
            'Kitchen_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_5-9',
          'space_names' =>
            [
            'Cafeteria_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Kitchen Exhaust Fan',
          'availability_sch_name' => 'SchoolSecondary Kitchen_Exhaust_SCH',
          'flow_rate' => OpenStudio.convert(5400,'cfm','m^3/s').get,
          'flow_fraction_schedule_name' => 'SchoolSecondary Kitchen_Exhaust_SCH_DCV',
          'balanced_exhaust_fraction_schedule_name' => 'SchoolSecondary Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule',
          'space_names' =>
            [
            'Kitchen_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Bathrooms_ZN_1_FLR_1',
          'availability_sch_name' => 'SchoolSecondary Hours_of_operation',
          'flow_rate' => OpenStudio.convert(600,'cfm','m^3/s').get,
          'space_names' =>
            [
            'Bathrooms_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Bathrooms_ZN_1_FLR_2',
          'availability_sch_name' => 'SchoolSecondary Hours_of_operation',
          'flow_rate' => OpenStudio.convert(600,'cfm','m^3/s').get,
          'space_names' =>
            [
            'Bathrooms_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'Refrigeration',
          'case_type' => 'Walkin Freezer',
          'cooling_capacity_per_length' => 734.0,
          'length' => 7.32,
          'evaporator_fan_pwr_per_length' => 68.3,
          'lighting_per_length' => 33.0,
          'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
          'defrost_pwr_per_length' => 410.0,
          'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
          'cop' => 1.5,
          'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
          'condenser_fan_pwr' => 750.0,
          'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
          'space_names' =>
            [
            'Kitchen_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'Refrigeration',
          'case_type' => 'Display Case',
          'cooling_capacity_per_length' => 734.0,
          'length' => 7.32,
          'evaporator_fan_pwr_per_length' => 55.0,
          'lighting_per_length' => 33.0,
          'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
          'defrost_pwr_per_length' => 0.0,
          'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
          'cop' => 3.0,
          'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
          'condenser_fan_pwr' => 750.0,
          'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
          'space_names' =>
            [
            'Kitchen_ZN_1_FLR_1'
          ]
        }
      ]
    else
      system_to_space_map = [
        {
          'type' => 'VAV',
          'name' => 'VAV_POD_1',
          'space_names' =>
            [
            'Corner_Class_1_Pod_1_ZN_1_FLR_1',
            'Corner_Class_1_Pod_1_ZN_1_FLR_2',
            'Mult_Class_1_Pod_1_ZN_1_FLR_1',
            'Mult_Class_1_Pod_1_ZN_1_FLR_2',
            'Corridor_Pod_1_ZN_1_FLR_1',
            'Corridor_Pod_1_ZN_1_FLR_2',
            'Corner_Class_2_Pod_1_ZN_1_FLR_1',
            'Corner_Class_2_Pod_1_ZN_1_FLR_2',
            'Mult_Class_2_Pod_1_ZN_1_FLR_1',
            'Mult_Class_2_Pod_1_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_POD_2',
          'space_names' =>
            [
            'Corner_Class_1_Pod_2_ZN_1_FLR_1',
            'Corner_Class_1_Pod_2_ZN_1_FLR_2',
            'Mult_Class_1_Pod_2_ZN_1_FLR_1',
            'Mult_Class_1_Pod_2_ZN_1_FLR_2',
            'Corridor_Pod_2_ZN_1_FLR_1',
            'Corridor_Pod_2_ZN_1_FLR_2',
            'Corner_Class_2_Pod_2_ZN_1_FLR_1',
            'Corner_Class_2_Pod_2_ZN_1_FLR_2',
            'Mult_Class_2_Pod_2_ZN_1_FLR_1',
            'Mult_Class_2_Pod_2_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_POD_3',
          'space_names' =>
            [
            'Corner_Class_1_Pod_3_ZN_1_FLR_1',
            'Corner_Class_1_Pod_3_ZN_1_FLR_2',
            'Mult_Class_1_Pod_3_ZN_1_FLR_1',
            'Mult_Class_1_Pod_3_ZN_1_FLR_2',
            'Corridor_Pod_3_ZN_1_FLR_1',
            'Corridor_Pod_3_ZN_1_FLR_2',
            'Corner_Class_2_Pod_3_ZN_1_FLR_1',
            'Corner_Class_2_Pod_3_ZN_1_FLR_2',
            'Mult_Class_2_Pod_3_ZN_1_FLR_1',
            'Mult_Class_2_Pod_3_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'VAV',
          'name' => 'VAV_OTHER',
          'space_names' =>
            [
            'Main_Corridor_ZN_1_FLR_1',
            'Main_Corridor_ZN_1_FLR_2',
            'Lobby_ZN_1_FLR_1',
            'Lobby_ZN_1_FLR_2',
            'Bathrooms_ZN_1_FLR_1',
            'Bathrooms_ZN_1_FLR_2',
            'Offices_ZN_1_FLR_1',
            'Offices_ZN_1_FLR_2',
            'LIBRARY_MEDIA_CENTER_ZN_1_FLR_2',
            'Mech_ZN_1_FLR_1',
            'Mech_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_1-5',
          'space_names' =>
            [
            'Gym_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_2-6',
          'space_names' =>
            [
            'Aux_Gym_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_3-7',
          'space_names' =>
            [
            'Auditorium_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_4-8',
          'space_names' =>
            [
            'Kitchen_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'PSZ-AC_5-9',
          'space_names' =>
            [
            'Cafeteria_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Kitchen Exhaust Fan',
          'availability_sch_name' => 'SchoolSecondary Kitchen_Exhaust_SCH',
          'flow_rate' => OpenStudio.convert(5400,'cfm','m^3/s').get,
          'flow_fraction_schedule_name' => 'SchoolSecondary Kitchen_Exhaust_SCH_DCV',
          'balanced_exhaust_fraction_schedule_name' => 'SchoolSecondary Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule',
          'space_names' =>
            [
            'Kitchen_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Bathrooms_ZN_1_FLR_1',
          'availability_sch_name' => 'SchoolSecondary Hours_of_operation',
          'flow_rate' => OpenStudio.convert(600,'cfm','m^3/s').get,
          'space_names' =>
            [
            'Bathrooms_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Bathrooms_ZN_1_FLR_2',
          'availability_sch_name' => 'SchoolSecondary Hours_of_operation',
          'flow_rate' => OpenStudio.convert(600,'cfm','m^3/s').get,
          'space_names' =>
            [
            'Bathrooms_ZN_1_FLR_2'
          ]
        },
        {
          'type' => 'Refrigeration',
          'case_type' => 'Walkin Freezer',
          'cooling_capacity_per_length' => 734.0,
          'length' => 7.32,
          'evaporator_fan_pwr_per_length' => 68.3,
          'lighting_per_length' => 33.0,
          'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
          'defrost_pwr_per_length' => 410.0,
          'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
          'cop' => 1.5,
          'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
          'condenser_fan_pwr' => 750.0,
          'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
          'space_names' =>
            [
            'Kitchen_ZN_1_FLR_1'
          ]
        },
        {
          'type' => 'Refrigeration',
          'case_type' => 'Display Case',
          'cooling_capacity_per_length' => 734.0,
          'length' => 7.32,
          'evaporator_fan_pwr_per_length' => 55.0,
          'lighting_per_length' => 33.0,
          'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
          'defrost_pwr_per_length' => 0.0,
          'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
          'cop' => 3.0,
          'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
          'condenser_fan_pwr' => 750.0,
          'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
          'space_names' =>
            [
            'Kitchen_ZN_1_FLR_1'
          ]
        }
      ]
    end
    
    return system_to_space_map

  end

  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)  
  
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')  
  
    self.getSpaces.each do |space|
    
      if space.name.get.to_s == "Mech_ZN_1_FLR_1"
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
  
  end
  
  def custom_swh_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    return true
    
  end
  
end


# Modules for building-type specific methods
module PrototypeBuilding
module PrimarySchool
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
    when 'NECB 2011'
      sch = 'D'
      space_type_map = {
        "Washroom-sch-#{sch}" => ['Bath_ZN_1_FLR_1'],
        'Conf./meet./multi-purpose' => ['Cafeteria_ZN_1_FLR_1'],
        'Classroom/lecture/training' => ['Computer_Class_ZN_1_FLR_1','Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Corner_Class_1_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_1'],
        "Corr. >= 2.4m wide-sch-#{sch}" => ['Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_1', 'Main_Corridor_ZN_1_FLR_1'],
        'Gym - play' => ['Gym_ZN_1_FLR_1'],
        'Food preparation' => ['Kitchen_ZN_1_FLR_1'],
        'Library - reading' => ['Library_Media_Center_ZN_1_FLR_1'],
        'Lobby - elevator' => ['Lobby_ZN_1_FLR_1'],
        "Electrical/Mechanical-sch-#{sch}" => ['Mech_ZN_1_FLR_1'],
        'Office - enclosed' => ['Offices_ZN_1_FLR_1']
      }
    else
      space_type_map = {
        'Office' => ['Offices_ZN_1_FLR_1'],
        'Lobby' => ['Lobby_ZN_1_FLR_1'],
        'Gym' => ['Gym_ZN_1_FLR_1'],
        'Mechanical' => ['Mech_ZN_1_FLR_1'],
        'Cafeteria' => ['Cafeteria_ZN_1_FLR_1'],
        'Kitchen' => ['Kitchen_ZN_1_FLR_1'],
        'Restroom' => ['Bath_ZN_1_FLR_1', 'Bathrooms_ZN_1_FLR_1'],
        'Corridor' => ['Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_1', 'Main_Corridor_ZN_1_FLR_1'],
        'Classroom' => ['Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Corner_Class_1_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_1'],
        'ComputerRoom' => ['Computer_Class_ZN_1_FLR_1'],
        'Library' => ['Library_Media_Center_ZN_1_FLR_1']
      }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = nil

    system_to_space_map = [
      {
        'type' => 'PVAV',
        'name' => 'PVAV_POD_1',
        'space_names' =>
          ['Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_1']
      },
      {
        'type' => 'PVAV',
        'name' => 'PVAV_POD_2',
        'space_names' =>
          ['Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_2_ZN_1_FLR_1']
      },
      {
        'type' => 'PVAV',
        'name' => 'PVAV_POD_3',
        'space_names' =>
          ['Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_1']
      },
      {
        'type' => 'PVAV',
        'name' => 'PVAV_OTHER',
        'space_names' =>
          ['Computer_Class_ZN_1_FLR_1', 'Main_Corridor_ZN_1_FLR_1', 'Lobby_ZN_1_FLR_1', 'Mech_ZN_1_FLR_1', 'Bath_ZN_1_FLR_1', 'Offices_ZN_1_FLR_1', 'Library_Media_Center_ZN_1_FLR_1']
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_1-6',
        'space_names' =>
          [
            'Kitchen_ZN_1_FLR_1'
          ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_2-5',
        'space_names' =>
          [
            'Gym_ZN_1_FLR_1'
          ]
      },
      {
        'type' => 'PSZ-AC',
        'name' => 'PSZ-AC_2-7',
        'space_names' =>
          [
            'Cafeteria_ZN_1_FLR_1'
          ]
      },
      {
        'type' => 'Exhaust Fan',
        'name' => 'Kitchen Exhaust Fan',
        'availability_sch_name' => 'SchoolPrimary Kitchen_Exhaust_SCH',
        'flow_rate' => OpenStudio.convert(4500, 'cfm', 'm^3/s').get,
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
        'availability_sch_name' => 'SchoolPrimary Hours_of_operation',
        'flow_rate' => OpenStudio.convert(600, 'cfm', 'm^3/s').get,
        'space_names' =>
          [
            'Bath_ZN_1_FLR_1'
          ]
      },
      {
        'type' => 'Refrigeration',
        'case_type' => 'Walkin Freezer',
        'cooling_capacity_per_length' => 734.0,
        'length' => 3.66,
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
        'length' => 3.66,
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

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # 
    # add extra equipment for kitchen
    PrototypeBuilding::PrimarySchool.add_extra_equip_kitchen(template, model)  
    return true
  end

  
  # add extra equipment for kitchen
  def self.add_extra_equip_kitchen(template, model)
    kitchen_space = model.getSpaceByName('Kitchen_ZN_1_FLR_1')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      elec_equip_def1.setFractionLatent(0)
      elec_equip_def1.setFractionRadiant(0.25)
      elec_equip_def1.setFractionLost(0)
      elec_equip_def2.setFractionLatent(0)
      elec_equip_def2.setFractionRadiant(0.25)
      elec_equip_def2.setFractionLost(0)
      if template == '90.1-2013'
        elec_equip_def1.setDesignLevel(915)
        elec_equip_def2.setDesignLevel(570)
      else
        elec_equip_def1.setDesignLevel(99999.88)
        elec_equip_def2.setDesignLevel(99999.99)
      end
      # Create the electric equipment instance and hook it up to the space type
      elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
      elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
      elec_equip1.setName('Kitchen_Reach-in-Freezer')
      elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
      elec_equip1.setSpaceType(kitchen_space_type)
      elec_equip2.setSpaceType(kitchen_space_type)
      elec_equip1.setSchedule(model.add_schedule('SchoolPrimary ALWAYS_ON'))
      elec_equip2.setSchedule(model.add_schedule('SchoolPrimary ALWAYS_ON'))
    end
  end  

  
  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end
end

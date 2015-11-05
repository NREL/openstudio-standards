
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = nil
    case building_vintage
    when 'DOE Ref Pre-1980'
      space_type_map = {
        'Dining' => ['Dining'],
        'Kitchen' => ['Kitchen']
      }
    when 'DOE Ref 1980-2004','90.1-2010','90.1-2007','90.1-2004','90.1-2013'
      space_type_map = {
        'Dining' => ['Dining'],
        'Kitchen' => ['Kitchen'],
        'Attic' => ['attic']
      }
    end
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)

    case building_vintage
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      system_to_space_map = [
        {
            'type' => 'PSZ-AC',
            'space_names' => ['Dining', 'Kitchen']
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Dining Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 1.828,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Dining'
            ]
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Kitchen Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 0.06,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Walkin Freezer',
            'cooling_capacity_per_length' => 688,
            'length' => 2.44,
            'evaporator_fan_pwr_per_length' => 74,
            'lighting_per_length' => 33,
            'lighting_sch_name' => 'FullServiceRestaurant Bldg Light',
            'defrost_pwr_per_length' => 820,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
            'cop' => 1.5,
            'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Display Case',
            'cooling_capacity_per_length' => 734.0,
            'length' => 3.05,
            'evaporator_fan_pwr_per_length' => 66,
            'lighting_per_length' => 33.0,
            'lighting_sch_name' => 'FullServiceRestaurant Bldg Light',
            'defrost_pwr_per_length' => 0.0,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
            'cop' => 3.0,
            'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        }
      ]
    when '90.1-2004'
      system_to_space_map = [
        {
            'type' => 'PSZ-AC',
            'space_names' => ['Dining', 'Kitchen']
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Dining Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 2.644,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Dining'
            ]
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Kitchen Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 2.83169,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Walkin Freezer',
            'cooling_capacity_per_length' => 688,
            'length' => 2.44,
            'evaporator_fan_pwr_per_length' => 74,
            'lighting_per_length' => 33,
            'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
            'defrost_pwr_per_length' => 820,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
            'cop' => 1.5,
            'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Display Case',
            'cooling_capacity_per_length' => 734.0,
            'length' => 3.05,
            'evaporator_fan_pwr_per_length' => 66,
            'lighting_per_length' => 33.0,
            'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
            'defrost_pwr_per_length' => 0.0,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
            'cop' => 3.0,
            'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        }
      ]
    when '90.1-2007'
      system_to_space_map = [
        {
            'type' => 'PSZ-AC',
            'space_names' => ['Dining', 'Kitchen']
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Dining Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 1.331432,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Dining'
            ]
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Kitchen Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 2.83169,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Walkin Freezer',
            'cooling_capacity_per_length' => 688,
            'length' => 2.44,
            'evaporator_fan_pwr_per_length' => 74,
            'lighting_per_length' => 33,
            'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
            'defrost_pwr_per_length' => 820,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
            'cop' => 1.5,
            'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Display Case',
            'cooling_capacity_per_length' => 734.0,
            'length' => 3.05,
            'evaporator_fan_pwr_per_length' => 66,
            'lighting_per_length' => 33.0,
            'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
            'defrost_pwr_per_length' => 0.0,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
            'cop' => 3.0,
            'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        }
      ]
    when '90.1-2007'
      system_to_space_map = [
        {
            'type' => 'PSZ-AC',
            'space_names' => ['Dining', 'Kitchen']
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Dining Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 1.331432,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Dining'
            ]
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Kitchen Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 2.83169,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Walkin Freezer',
            'cooling_capacity_per_length' => 688,
            'length' => 2.44,
            'evaporator_fan_pwr_per_length' => 74,
            'lighting_per_length' => 33,
            'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
            'defrost_pwr_per_length' => 820,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
            'cop' => 1.5,
            'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Display Case',
            'cooling_capacity_per_length' => 734.0,
            'length' => 3.05,
            'evaporator_fan_pwr_per_length' => 66,
            'lighting_per_length' => 33.0,
            'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
            'defrost_pwr_per_length' => 0.0,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
            'cop' => 3.0,
            'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        }
      ]
    when '90.1-2010'
      system_to_space_map = [
        {
            'type' => 'PSZ-AC',
            'space_names' => ['Dining', 'Kitchen']
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Dining Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 1.331432,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Dining'
            ]
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Kitchen Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 2.548516,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Walkin Freezer',
            'cooling_capacity_per_length' => 688,
            'length' => 2.44,
            'evaporator_fan_pwr_per_length' => 74,
            'lighting_per_length' => 33,
            'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
            'defrost_pwr_per_length' => 820,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
            'cop' => 1.5,
            'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Display Case',
            'cooling_capacity_per_length' => 734.0,
            'length' => 3.05,
            'evaporator_fan_pwr_per_length' => 66,
            'lighting_per_length' => 33.0,
            'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
            'defrost_pwr_per_length' => 0.0,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
            'cop' => 3.0,
            'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        }
      ]
    when '90.1-2013'
      system_to_space_map = [
        {
            'type' => 'PSZ-AC',
            'space_names' => ['Dining', 'Kitchen']
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Dining Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 1.331432,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Dining'
            ]
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Kitchen Exhaust Fan',
            'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
            'flow_rate' => 2.548516,
            'flow_fraction_schedule_name' => nil,
            'balanced_exhaust_fraction_schedule_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Walkin Freezer',
            'cooling_capacity_per_length' => 688,
            'length' => 2.44,
            'evaporator_fan_pwr_per_length' => 21.14286,
            'lighting_per_length' => 33,
            'lighting_sch_name' => 'RestaurantSitDown walkin_occ_lght_SCH',
            'defrost_pwr_per_length' => 820,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
            'cop' => 1.5,
            'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
            [
                'Kitchen'
            ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Display Case',
            'cooling_capacity_per_length' => 734.0,
            'length' => 3.05,
            'evaporator_fan_pwr_per_length' => 18.85714,
            'lighting_per_length' => 33.0,
            'lighting_sch_name' => 'RestaurantSitDown walkin_occ_lght_SCH',
            'defrost_pwr_per_length' => 0.0,
            'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
            'cop' => 3.0,
            'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
            'condenser_fan_pwr' => 330,
            'condenser_fan_pwr_curve_name' => nil,
            'space_names' =>
            [
                'Kitchen'
            ]
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
        thermal_zones << zone.get
      end

      case system['type']
      when 'PSZ-AC'
        self.add_psz_ac(prototype_input, hvac_standards, system['name'], thermal_zones)
      when 'Exhaust Fan'
        self.add_exhaust_fan(prototype_input,
                            standards,
                            system['availability_sch_name'],
                            system['flow_rate'],
                            system['flow_fraction_schedule_name'],
                            system['balanced_exhaust_fraction_schedule_name'],
                            thermal_zones)
      when 'Refrigeration'
        self.add_refrigeration(prototype_input,
                              standards,
                              system['case_type'],
                              system['cooling_capacity_per_length'],
                              system['length'],
                              system['evaporator_fan_pwr_per_length'],
                              system['lighting_per_length'],
                              system['lighting_sch_name'],
                              system['defrost_pwr_per_length'],
                              system['restocking_sch_name'],
                              system['cop'],
                              system['cop_f_of_t_curve_name'],
                              system['condenser_fan_pwr'],
                              system['condenser_fan_pwr_curve_name'],
                              thermal_zones[0])
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Undefined HVAC system type called #{system['type']}")
        return false  
      end

    end
    
    # add extra equipment for kitchen
    self.add_extra_equip_kitchen(building_vintage)
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    
    return true
    
  end #add hvac

  def update_exhaust_fan_efficiency(building_vintage)
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      self.getFanZoneExhausts.sort.each do |exhaust_fan|
        fan_name = exhaust_fan.name.to_s
        if fan_name.include? "Dining"
          exhaust_fan.setFanEfficiency(1)
          exhaust_fan.setPressureRise(0)
        end
      end
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      self.getFanZoneExhausts.sort.each do |exhaust_fan|
        exhaust_fan.setFanEfficiency(1)
        exhaust_fan.setPressureRise(0.000001)
      end
    end
  end

  # add extra equipment for kitchen
  def add_extra_equip_kitchen(building_vintage)
    kitchen_space = self.getSpaceByName('Kitchen')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
    elec_equip_def1.setName("Kitchen Electric Equipment Definition1")
    elec_equip_def2.setName("Kitchen Electric Equipment Definition2")
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      elec_equip_def1.setFractionLatent(0)
      elec_equip_def1.setFractionRadiant(0.25)
      elec_equip_def1.setFractionLost(0)
      elec_equip_def2.setFractionLatent(0)
      elec_equip_def2.setFractionRadiant(0.25)
      elec_equip_def2.setFractionLost(0)
      if building_vintage == '90.1-2013'
        elec_equip_def1.setDesignLevel(457.5)
        elec_equip_def2.setDesignLevel(570)
      else
        elec_equip_def1.setDesignLevel(515.917)
        elec_equip_def2.setDesignLevel(851.67)
      end
      # Create the electric equipment instance and hook it up to the space type
      elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
      elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
      elec_equip1.setName("Kitchen_Reach-in-Freezer")
      elec_equip2.setName("Kitchen_Reach-in-Refrigerator")
      elec_equip1.setSpaceType(kitchen_space_type)
      elec_equip2.setSpaceType(kitchen_space_type)
      elec_equip1.setSchedule(add_schedule("RestaurantSitDown ALWAYS_ON"))
      elec_equip2.setSchedule(add_schedule("RestaurantSitDown ALWAYS_ON"))
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      elec_equip_def1.setDesignLevel(699)
      elec_equip_def1.setFractionLatent(0)
      elec_equip_def1.setFractionRadiant(0)
      elec_equip_def1.setFractionLost(1)
      # Create the electric equipment instance and hook it up to the space type
      elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
      elec_equip1.setName("Kitchen_ExhFan_Equip")
      elec_equip1.setSpaceType(kitchen_space_type)
      elec_equip1.setSchedule(add_schedule("RestaurantSitDown Kitchen_Exhaust_SCH"))
    end
  end
  
  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
    water_heaters = main_swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)
    
    water_heaters.each do |water_heater|
      water_heater = water_heater.to_WaterHeaterMixed.get
      # water_heater.setAmbientTemperatureIndicator('Zone')
      # water_heater.setAmbientTemperatureThermalZone(default_water_heater_ambient_temp_sch)
      water_heater.setOffCycleParasiticFuelConsumptionRate(720)
      water_heater.setOnCycleParasiticFuelConsumptionRate(720)
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
    end

    self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')

    case building_vintage
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004' 
      # No dishwasher booster water heaters
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      booster_water_heater_space_name = "Kitchen"
      booster_water_heater_thermal_zone = self.getSpaceByName(booster_water_heater_space_name).get.thermalZone.get
      # self.add_swh_booster_no_loop(prototype_input, hvac_standards, main_swh_loop, booster_water_heater_thermal_zone)
      swh_booster_loop = self.add_swh_booster(prototype_input, hvac_standards, main_swh_loop, booster_water_heater_thermal_zone)
      self.add_booster_swh_end_uses(prototype_input, hvac_standards, swh_booster_loop)
    end
    
        
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh    

=begin  
  def add_refrigeration(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding Refrigeration System")

    #Schedule Ruleset
    defrost_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    defrost_sch.setName("Refrigeration Defrost Schedule")
    #All other days
    defrost_sch.defaultDaySchedule.setName("Refrigeration Defrost Schedule Default")
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,4,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,4,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,8,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,8,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,12,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,12,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,16,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,16,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,20,0,0), 0)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,20,45,0), 1)
    defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 0)

    space = self.getSpaceByName('Kitchen')
    if space.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called Kitchen was found in the model")
      return false
    end
    space = space.get
    thermal_zone = space.thermalZone
    if thermal_zone.empty?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
      return false
    end
    thermal_zone = thermal_zone.get

    ref_sys1 = OpenStudio::Model::RefrigerationSystem.new(self)
    ref_sys1.addCompressor(OpenStudio::Model::RefrigerationCompressor.new(self))
    condenser1 = OpenStudio::Model::RefrigerationCondenserAirCooled.new(self)

    condenser1.setRatedFanPower(330)

    ref_case1 = OpenStudio::Model::RefrigerationCase.new(self, defrost_sch)
    ref_case1.setThermalZone(thermal_zone)
    ref_case1.setRatedTotalCoolingCapacityperUnitLength(688.0)
    ref_case1.setCaseLength(2.4400)
    ref_case1.setCaseOperatingTemperature(-23.0)
    ref_case1.setStandardCaseFanPowerperUnitLength(74)
    ref_case1.setOperatingCaseFanPowerperUnitLength(74)
    ref_case1.setCaseLightingSchedule(self.add_schedule('RestaurantSitDown BLDG_LIGHT_SCH'))
    ref_case1.setHumidityatZeroAntiSweatHeaterEnergy(0)
    ref_case1.setCaseDefrostPowerperUnitLength(820.0)
    ref_case1.setCaseDefrostType('Electric')
    ref_case1.setDesignEvaporatorTemperatureorBrineInletTemperature(-24.0)

    ref_sys1.addCase(ref_case1)

    ref_sys1.setRefrigerationCondenser(condenser1)
    ref_sys1.setSuctionPipingZone(thermal_zone)

    ref_sys2 = OpenStudio::Model::RefrigerationSystem.new(self)
    ref_sys2.addCompressor(OpenStudio::Model::RefrigerationCompressor.new(self))
    condenser2 = OpenStudio::Model::RefrigerationCondenserAirCooled.new(self)

    condenser2.setRatedFanPower(330)

    ref_case2 = OpenStudio::Model::RefrigerationCase.new(self, defrost_sch)
    ref_case2.setThermalZone(thermal_zone)
    ref_case2.setRatedTotalCoolingCapacityperUnitLength(734.0)
    ref_case2.setCaseLength(3.05)
    ref_case2.setCaseOperatingTemperature(2.0)
    ref_case2.setStandardCaseFanPowerperUnitLength(66)
    ref_case2.setOperatingCaseFanPowerperUnitLength(66)
    ref_case2.setCaseLightingSchedule(self.add_schedule('RestaurantSitDown BLDG_LIGHT_SCH'))
    ref_case2.setHumidityatZeroAntiSweatHeaterEnergy(0)
    ref_case2.setCaseDefrostType('None')

    ref_sys2.addCase(ref_case2)

    ref_sys2.setRefrigerationCondenser(condenser2)
    ref_sys2.setSuctionPipingZone(thermal_zone)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding Refrigeration System")
       
    return true
    
  end #add refrigeration
=end
  
end

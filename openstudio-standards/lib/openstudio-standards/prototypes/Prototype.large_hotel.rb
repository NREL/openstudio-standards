
# Extend the class to add Large Hotel specific stuff
class OpenStudio::Model::Model

  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = nil
    case building_vintage
    when 'NECB 2011'
      space_type_map ={
        "Hotel/Motel - dining" => ["Banquet_Flr_6", "Dining_Flr_6"],
        "Storage area" => ["Basement", "Storage_Flr_1"],
        "Retail - mall concourse" => ["Cafe_Flr_1"],
        "Corr. >= 2.4m wide" => ["Corridor_Flr_3", "Corridor_Flr_6"],
        "Food preparation" => ["Kitchen_Flr_6"],
        "Hospital - laundry/washing" => ["Laundry_Flr_1"],
        "Hotel/Motel - lobby" => ["Lobby_Flr_1"],
        "Electrical/Mechanical" => ["Mech_Flr_1"],
        "Retail - sales" => ["Retail_1_Flr_1", "Retail_2_Flr_1"],
        "Hotel/Motel - rooms" => ["Room_1_Flr_3", "Room_1_Flr_6", "Room_2_Flr_3", "Room_2_Flr_6", "Room_3_Mult19_Flr_3", "Room_3_Mult9_Flr_6", "Room_4_Mult19_Flr_3", "Room_5_Flr_3", "Room_6_Flr_3"]
      }
    else
      space_type_map = {
        'Banquet' => ['Banquet_Flr_6','Dining_Flr_6'],
        'Basement'=>['Basement'],
        'Cafe' => ['Cafe_Flr_1'],
        'Corridor'=> ['Corridor_Flr_6'],
        'Corridor2'=> ['Corridor_Flr_3'],
        'GuestRoom'=> ['Room_1_Flr_3','Room_2_Flr_3','Room_5_Flr_3','Room_6_Flr_3'],
        'GuestRoom2'=> ['Room_3_Mult19_Flr_3','Room_4_Mult19_Flr_3'],
        'GuestRoom3'=> ['Room_1_Flr_6','Room_2_Flr_6'],
        'GuestRoom4'=> ['Room_3_Mult9_Flr_6'],
        'Kitchen'=> ['Kitchen_Flr_6'],
        'Laundry'=> ['Laundry_Flr_1'],
        'Lobby'=> ['Lobby_Flr_1'],
        'Mechanical'=> ['Mech_Flr_1'],
        'Retail'=> ['Retail_1_Flr_1'],
        'Retail2'=> ['Retail_2_Flr_1'],
        'Storage'=> ['Storage_Flr_1']
      }
    end
    
    


    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    system_to_space_map = [
      {
        'type' => 'VAV',
        'name' => 'VAV WITH REHEAT',
        'space_names' =>
          [
          'Basement',
          'Retail_1_Flr_1',
          'Retail_2_Flr_1',
          'Mech_Flr_1',
          'Storage_Flr_1',
          'Laundry_Flr_1',
          'Cafe_Flr_1',
          'Lobby_Flr_1',
          'Corridor_Flr_3',
          'Banquet_Flr_6',
          'Dining_Flr_6',
          'Corridor_Flr_6',
          'Kitchen_Flr_6'
        ]
      },
      {
        'type' => 'DOAS',
        'space_names' =>
          [
          'Room_1_Flr_3','Room_2_Flr_3','Room_3_Mult19_Flr_3','Room_4_Mult19_Flr_3','Room_5_Flr_3','Room_6_Flr_3','Room_1_Flr_6','Room_2_Flr_6','Room_3_Mult9_Flr_6'
        ]
      },
      {
        'type' => 'Refrigeration',
        'case_type' => 'Walkin Freezer',
        'cooling_capacity_per_length' => 367.0,
        'length' => 7.32,
        'evaporator_fan_pwr_per_length' => 34.0,
        'lighting_per_length' => 16.4,
        'lighting_sch_name' => 'HotelLarge BLDG_LIGHT_SCH',
        'defrost_pwr_per_length' => 273.0,
        'restocking_sch_name' => 'HotelLarge Kitchen_Flr_6_Case:1_WALKINFREEZER_WalkInStockingSched',
        'cop' => 1.5,
        'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
        'condenser_fan_pwr' => 350.0,
        'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
        'space_names' =>
          [
          'Kitchen_Flr_6'
        ]
      },
      {
        'type' => 'Refrigeration',
        'case_type' => 'Display Case',
        'cooling_capacity_per_length' => 734.0,
        'length' => 3.66,
        'evaporator_fan_pwr_per_length' => 55.0,
        'lighting_per_length' => 33.0,
        'lighting_sch_name' => 'HotelLarge BLDG_LIGHT_SCH',
        'defrost_pwr_per_length' => 0.0,
        'restocking_sch_name' => 'HotelLarge Kitchen_Flr_6_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
        'cop' => 3.0,
        'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
        'condenser_fan_pwr' => 750.0,
        'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
        'space_names' =>
          [
          'Kitchen_Flr_6'
        ]
      }
    ]
    return system_to_space_map
  end

  def define_space_multiplier
    # This map define the multipliers for spaces with multipliers not equals to 1
    space_multiplier_map = {
      'Room_1_Flr_3' => 4,
      'Room_2_Flr_3' => 4,
      'Room_3_Mult19_Flr_3' => 76,
      'Room_4_Mult19_Flr_3' => 76,
      'Room_5_Flr_3' => 4,
      'Room_6_Flr_3' => 4,
      'Corridor_Flr_3' => 4,
      'Room_3_Mult9_Flr_6' => 9
    }
    return space_multiplier_map
  end

<<<<<<< HEAD
  def add_hvac(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
    #simulation_control =  self.getSimulationControl
    #simulation_control.setLoadsConvergenceToleranceValue(0.4)
    #simulation_control.setTemperatureConvergenceToleranceValue(0.5)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    #VAV system; hot water reheat, water-cooled chiller
    chilled_water_loop = self.add_chw_loop(prototype_input, hvac_standards, nil, building_type)
    hot_water_loop = self.add_hw_loop(prototype_input, hvac_standards, building_type)

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
          self.add_vav(prototype_input, hvac_standards, system['name'], hot_water_loop, chilled_water_loop, thermal_zones, building_type)
        else
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water and chilled water plant loops in model')
          return false
        end
      when 'DOAS'
        self.add_doas(prototype_input, hvac_standards, hot_water_loop, chilled_water_loop, thermal_zones, building_type, building_vintage, climate_zone)
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

=======
  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')    
    
>>>>>>> remotes/origin/master
    # Add Exhaust Fan
    space_type_map = define_space_type_map(building_type, building_vintage, climate_zone)
    exhaust_fan_space_types = []
    case building_vintage
    when '90.1-2004','90.1-2007'
      exhaust_fan_space_types =['Kitchen','Laundry']
    else
      exhaust_fan_space_types =['Banquet', 'Kitchen','Laundry']
    end

    exhaust_fan_space_types.each do |space_type_name|
      space_type_data = self.find_object($os_standards['space_types'], {'template'=>building_vintage, 'building_type'=>building_type, 'space_type'=>space_type_name})
      if space_type_data == nil
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find space type #{building_vintage}-#{building_type}-#{space_type_name}")
        return false
      end

      exhaust_schedule = add_schedule(space_type_data['exhaust_schedule'])
      if exhaust_schedule.class.to_s == "NilClass"
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find Exhaust Schedule for space type #{building_vintage}-#{building_type}-#{space_type_name}")
        return false
      end

      balanced_exhaust_schedule = add_schedule(space_type_data['balanced_exhaust_fraction_schedule'])

      space_names = space_type_map[space_type_name]
      space_names.each do |space_name|
        space = self.getSpaceByName(space_name).get
        thermal_zone = space.thermalZone.get

        zone_exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(self)
        zone_exhaust_fan.setName(space.name.to_s + " Exhaust Fan")
        zone_exhaust_fan.setAvailabilitySchedule(exhaust_schedule)
        zone_exhaust_fan.setFanEfficiency(space_type_data['exhaust_fan_efficiency'])
        zone_exhaust_fan.setPressureRise(space_type_data['exhaust_fan_pressure_rise'])
        maximum_flow_rate = OpenStudio.convert(space_type_data['exhaust_fan_maximum_flow_rate'], 'cfm', 'm^3/s').get

        zone_exhaust_fan.setMaximumFlowRate(maximum_flow_rate)
        if balanced_exhaust_schedule.class.to_s != "NilClass"
          zone_exhaust_fan.setBalancedExhaustFractionSchedule(balanced_exhaust_schedule)
        end
        zone_exhaust_fan.setEndUseSubcategory("Zone Exhaust Fans")
        zone_exhaust_fan.addToThermalZone(thermal_zone)

        if space_type_data['exhaust_fan_power'] != nil and space_type_data['exhaust_fan_power'].to_f != 0
          # Create the electric equipment definition
          exhaust_fan_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
          exhaust_fan_equip_def.setName("#{space_name} Electric Equipment Definition")
          exhaust_fan_equip_def.setDesignLevel(space_type_data['exhaust_fan_power'].to_f)
          exhaust_fan_equip_def.setFractionLatent(0)
          exhaust_fan_equip_def.setFractionRadiant(0)
          exhaust_fan_equip_def.setFractionLost(1)

          # Create the electric equipment instance and hook it up to the space type
          exhaust_fan_elec_equip = OpenStudio::Model::ElectricEquipment.new(exhaust_fan_equip_def)
          exhaust_fan_elec_equip.setName("#{space_name} Exhaust Fan Equipment")
          exhaust_fan_elec_equip.setSchedule(exhaust_schedule)
          exhaust_fan_elec_equip.setSpaceType(space.spaceType.get)
        end
      end
    end

    # Update Sizing Zone
    zone_sizing = self.getSpaceByName('Kitchen_Flr_6').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlowFraction(0.7)

    zone_sizing = self.getSpaceByName('Laundry_Flr_1').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlow(0.23567919336)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')
    
    return true
    
  end #add hvac

  # Add the daylighting controls for lobby, cafe, dinning and banquet
  def add_daylighting_controls(building_vintage)
    space_names = ['Banquet_Flr_6','Dining_Flr_6','Cafe_Flr_1','Lobby_Flr_1']
    space_names.each do |space_name|
      space = self.getSpaceByName(space_name).get
      space.addDaylightingControls(building_vintage, false, false)
    end
  end

<<<<<<< HEAD
  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    # Add the main service hot water loop
    
    if building_vintage == 'NECB 2011'
      # TO DO: define space where swh equipment located
      swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')        
    else
      swh_space_name = "Basement"
      swh_thermal_zone = self.getSpaceByName(swh_space_name).get.thermalZone.get
      swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main',swh_thermal_zone)
    end
    
    

    unless building_vintage == 'NECB 2011'
    
      guess_room_water_use_schedule = "HotelLarge GuestRoom_SWH_Sch"
      kitchen_water_use_schedule = "HotelLarge BLDG_SWH_SCH"

      water_end_uses = []
      space_type_map = define_space_type_map(building_type, building_vintage, climate_zone)
      space_multipliers = define_space_multiplier

      # Add the water use equipment

      kitchen_space_types = ['Kitchen']
      kitchen_space_use_rate = 2.22 # gal/min, from PNNL prototype building

      guess_room_water_use_rate = 0.020833333 # gal/min, Reference: NREL Reference building report 5.1.6

      if building_vintage == "90.1-2004" or building_vintage == "90.1-2007" or building_vintage == "90.1-2010" or building_vintage == "90.1-2013"
        guess_room_space_types =['GuestRoom','GuestRoom2','GuestRoom3','GuestRoom4']
      else
        guess_room_space_types =['GuestRoom','GuestRoom3']
        guess_room_space_types1 = ['GuestRoom2']
        guess_room_space_types2 = ['GuestRoom4']
        guess_room_water_use_rate1 = 0.395761032 # gal/min, Reference building
        guess_room_water_use_rate2 = 0.187465752 # gal/min, Reference building

        laundry_water_use_schedule = "HotelLarge LaundryRoom_Eqp_Elec_Sch"
        laundry_space_types = ['Laundry']
        laundry_room_water_use_rate = 2.6108244 # gal/min, Reference building

        guess_room_space_types1.each do |space_type|
          space_names = space_type_map[space_type]
          space_names.each do |space_name|
            space_multiplier = 1
            space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
            water_end_uses.push([space_name, guess_room_water_use_rate1 * space_multiplier,guess_room_water_use_schedule])
          end
        end

        guess_room_space_types2.each do |space_type|
          space_names = space_type_map[space_type]
          space_names.each do |space_name|
            space_multiplier = 1
            space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
            water_end_uses.push([space_name, guess_room_water_use_rate2 * space_multiplier,guess_room_water_use_schedule])
          end
        end

        laundry_space_types.each do |space_type|
          space_names = space_type_map[space_type]
          space_names.each do |space_name|
            space_multiplier = 1
            space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
            water_end_uses.push([space_name, laundry_room_water_use_rate * space_multiplier,laundry_water_use_schedule])
          end
        end
      end

      guess_room_space_types.each do |space_type|
        space_names = space_type_map[space_type]
        space_names.each do |space_name|
          space_multiplier = 1
          space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
          water_end_uses.push([space_name, guess_room_water_use_rate * space_multiplier,guess_room_water_use_schedule])
        end
      end

      kitchen_space_types.each do |space_type|
        space_names = space_type_map[space_type]
        space_names.each do |space_name|
          space_multiplier = 1
          space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
          water_end_uses.push([space_name, kitchen_space_use_rate * space_multiplier,kitchen_water_use_schedule])
        end
      end

      self.add_large_hotel_swh_end_uses(prototype_input, hvac_standards, swh_loop, 'main', water_end_uses)

      if building_vintage == "90.1-2004" or building_vintage == "90.1-2007" or building_vintage == "90.1-2010" or building_vintage == "90.1-2013"
        # Add the laundry water heater
        laundry_water_heater_space_name = "Basement"
        laundry_water_heater_thermal_zone = self.getSpaceByName(laundry_water_heater_space_name).get.thermalZone.get
        laundry_water_heater_loop = self.add_swh_loop(prototype_input, hvac_standards, 'laundry', laundry_water_heater_thermal_zone)
        self.add_swh_end_uses(prototype_input, hvac_standards, laundry_water_heater_loop,'laundry')

        booster_water_heater_space_name = "KITCHEN_FLR_6"
        booster_water_heater_thermal_zone = self.getSpaceByName(booster_water_heater_space_name).get.thermalZone.get
        swh_booster_loop = self.add_swh_booster(prototype_input, hvac_standards, swh_loop, booster_water_heater_thermal_zone)
        self.add_booster_swh_end_uses(prototype_input, hvac_standards, swh_booster_loop)
      end

    end

    if building_vintage == 'NECB 2011'  
      space_type_map.each do |space_type_name, space_names|
        space_names.each do |space_name|
          space = self.getSpaceByName(space_name).get
          space_multiplier = space.multiplier
          self.add_swh_end_uses_by_space('Space Function', building_vintage, climate_zone, swh_loop, space_type_name, space_name, space_multiplier)
        end   
      end
    end
    
    
    
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
=======
  def custom_swh_tweaks(building_type, building_vintage, climate_zone, prototype_input)

>>>>>>> remotes/origin/master
    return true
    
  end

end

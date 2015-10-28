
# Extend the class to add Large Hotel specific stuff
class OpenStudio::Model::Model

  def define_space_type_map(building_type, building_vintage, climate_zone)
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

    # Add Exhaust Fan
    space_type_map = define_space_type_map(building_type, building_vintage, climate_zone)
    case building_vintage
      when '90.1-2004','90.1-2007'
        exhaust_fan_space_types =['Kitchen','Laundry']
      else
        exhaust_fan_space_types =['Banquet', 'Kitchen','Laundry']
    end

    exhaust_fan_space_types.each do |space_type_name|
      space_type_data = self.find_object(self.standards['space_types'], {'template'=>building_vintage, 'building_type'=>building_type, 'space_type'=>space_type_name})
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

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
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

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    # Add the main service hot water loop
    swh_space_name = "Basement"
    swh_thermal_zone = self.getSpaceByName(swh_space_name).get.thermalZone.get
    swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main',swh_thermal_zone)

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

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    return true
  end #add swh

  def add_large_hotel_swh_end_uses(prototype_input, standards, swh_loop, type, water_end_uses)
    puts "Adding water uses type = '#{type}'"
    water_end_uses.each do |water_end_use|
      space_name = water_end_use[0]
      use_rate = water_end_use[1] # in gal/min

      # Water use connection
      swh_connection = OpenStudio::Model::WaterUseConnections.new(self)
      swh_connection.setName(space_name + "Water Use Connections")
      # Water fixture definition
      water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(self)
      rated_flow_rate_m3_per_s = OpenStudio.convert(use_rate,'gal/min','m^3/s').get
      water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
      water_fixture_def.setName("#{space_name} Service Water Use Def #{use_rate.round(2)}gal/min")

      sensible_fraction = 0.2
      latent_fraction = 0.05

      # Target mixed water temperature
      mixed_water_temp_f = prototype_input["#{type}_water_use_temperature"]
      mixed_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      mixed_water_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),OpenStudio.convert(mixed_water_temp_f,'F','C').get)
      water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

      sensible_fraction_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      sensible_fraction_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),sensible_fraction)
      water_fixture_def.setSensibleFractionSchedule(sensible_fraction_sch)

      latent_fraction_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      latent_fraction_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0),latent_fraction)
      water_fixture_def.setSensibleFractionSchedule(latent_fraction_sch)

      # Water use equipment
      water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
      schedule = self.add_schedule(water_end_use[2])
      water_fixture.setFlowRateFractionSchedule(schedule)
      water_fixture.setName("#{space_name} Service Water Use #{use_rate.round(2)}gal/min")
      swh_connection.addWaterUseEquipment(water_fixture)

      # Connect the water use connection to the SWH loop
      swh_loop.addDemandBranchForComponent(swh_connection)
    end
  end


end

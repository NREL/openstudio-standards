
# Modules for building-type specific methods
module PrototypeBuilding
module LargeHotel
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
    when 'NECB 2011'
      # Building Schedule
      sch = 'E'
      space_type_map = {
        'Hotel/Motel - dining' => ['Banquet_Flr_6', 'Dining_Flr_6'],
        'Storage area' => ['Basement', 'Storage_Flr_1'],
        'Retail - mall concourse' => ['Cafe_Flr_1'],
        "Corr. >= 2.4m wide-sch-#{sch}" => ['Corridor_Flr_3', 'Corridor_Flr_6'],
        'Food preparation' => ['Kitchen_Flr_6'],
        'Hospital - laundry/washing' => ['Laundry_Flr_1'],
        'Hotel/Motel - lobby' => ['Lobby_Flr_1'],
        "Electrical/Mechanical-sch-#{sch}" => ['Mech_Flr_1'],
        'Retail - sales' => ['Retail_1_Flr_1', 'Retail_2_Flr_1'],
        'Hotel/Motel - rooms' => ['Room_1_Flr_3', 'Room_1_Flr_6', 'Room_2_Flr_3', 'Room_2_Flr_6', 'Room_3_Mult19_Flr_3', 'Room_3_Mult9_Flr_6', 'Room_4_Mult19_Flr_3', 'Room_5_Flr_3', 'Room_6_Flr_3']
      }
    else
      space_type_map = {
        'Banquet' => ['Banquet_Flr_6', 'Dining_Flr_6'],
        'Basement' => ['Basement'],
        'Cafe' => ['Cafe_Flr_1'],
        'Corridor' => ['Corridor_Flr_6'],
        'Corridor2' => ['Corridor_Flr_3'],
        'GuestRoom' => ['Room_1_Flr_3', 'Room_2_Flr_3', 'Room_5_Flr_3', 'Room_6_Flr_3'],
        'GuestRoom2' => ['Room_3_Mult19_Flr_3', 'Room_4_Mult19_Flr_3'],
        'GuestRoom3' => ['Room_1_Flr_6', 'Room_2_Flr_6'],
        'GuestRoom4' => ['Room_3_Mult9_Flr_6'],
        'Kitchen' => ['Kitchen_Flr_6'],
        'Laundry' => ['Laundry_Flr_1'],
        'Lobby' => ['Lobby_Flr_1'],
        'Mechanical' => ['Mech_Flr_1'],
        'Retail' => ['Retail_1_Flr_1'],
        'Retail2' => ['Retail_2_Flr_1'],
        'Storage' => ['Storage_Flr_1']
      }
    end

    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
      {
        'type' => 'VAV',
        'name' => 'VAV WITH REHEAT',
        'space_names' =>
          ['Basement', 'Retail_1_Flr_1', 'Retail_2_Flr_1', 'Mech_Flr_1', 'Storage_Flr_1', 'Laundry_Flr_1', 'Cafe_Flr_1', 'Lobby_Flr_1', 'Corridor_Flr_3', 'Banquet_Flr_6', 'Dining_Flr_6', 'Corridor_Flr_6', 'Kitchen_Flr_6']
      },
      {
        'type' => 'DOAS',
        'space_names' =>
          ['Room_1_Flr_3', 'Room_2_Flr_3', 'Room_3_Mult19_Flr_3', 'Room_4_Mult19_Flr_3', 'Room_5_Flr_3', 'Room_6_Flr_3', 'Room_1_Flr_6', 'Room_2_Flr_6', 'Room_3_Mult9_Flr_6']
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

  def self.define_space_multiplier
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

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # Add Exhaust Fan
    space_type_map = define_space_type_map(building_type, template, climate_zone)
    exhaust_fan_space_types = []
    case template
    when '90.1-2004', '90.1-2007'
      exhaust_fan_space_types = ['Kitchen', 'Laundry']
    else
      exhaust_fan_space_types = ['Banquet', 'Kitchen', 'Laundry']
    end

    exhaust_fan_space_types.each do |space_type_name|
      space_type_data = model.find_object($os_standards['space_types'], 'template' => template, 'building_type' => building_type, 'space_type' => space_type_name)
      if space_type_data.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find space type #{template}-#{building_type}-#{space_type_name}")
        return false
      end

      exhaust_schedule = model.add_schedule(space_type_data['exhaust_schedule'])
      if exhaust_schedule.class.to_s == 'NilClass'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find Exhaust Schedule for space type #{template}-#{building_type}-#{space_type_name}")
        return false
      end

      balanced_exhaust_schedule = model.add_schedule(space_type_data['balanced_exhaust_fraction_schedule'])

      space_names = space_type_map[space_type_name]
      space_names.each do |space_name|
        space = model.getSpaceByName(space_name).get
        thermal_zone = space.thermalZone.get

        zone_exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(model)
        zone_exhaust_fan.setName(space.name.to_s + ' Exhaust Fan')
        zone_exhaust_fan.setAvailabilitySchedule(exhaust_schedule)
        zone_exhaust_fan.setFanEfficiency(space_type_data['exhaust_fan_efficiency'])
        zone_exhaust_fan.setPressureRise(space_type_data['exhaust_fan_pressure_rise'])
        maximum_flow_rate = OpenStudio.convert(space_type_data['exhaust_fan_maximum_flow_rate'], 'cfm', 'm^3/s').get

        zone_exhaust_fan.setMaximumFlowRate(maximum_flow_rate)
        if balanced_exhaust_schedule.class.to_s != 'NilClass'
          zone_exhaust_fan.setBalancedExhaustFractionSchedule(balanced_exhaust_schedule)
        end
        zone_exhaust_fan.setEndUseSubcategory('Zone Exhaust Fans')
        zone_exhaust_fan.addToThermalZone(thermal_zone)

        if !space_type_data['exhaust_fan_power'].nil? && space_type_data['exhaust_fan_power'].to_f.nonzero?
          # Create the electric equipment definition
          exhaust_fan_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
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
    zone_sizing = model.getSpaceByName('Kitchen_Flr_6').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlowFraction(0.7)

    zone_sizing = model.getSpaceByName('Laundry_Flr_1').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlow(0.23567919336)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end # add hvac

  # Add the daylighting controls for lobby, cafe, dinning and banquet
  def self.large_hotel_add_daylighting_controls(template, model)
    space_names = ['Banquet_Flr_6', 'Dining_Flr_6', 'Cafe_Flr_1', 'Lobby_Flr_1']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      space.add_daylighting_controls(template, false, false)
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end
end

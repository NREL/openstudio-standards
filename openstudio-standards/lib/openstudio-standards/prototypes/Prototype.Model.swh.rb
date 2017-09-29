
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model
  def add_swh(building_type, template, climate_zone, prototype_input)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Service Water Heating')

    # Add the main service water heating loop, if specified
    unless prototype_input['main_water_heater_volume'].nil?

      # Add the main service water loop
      main_swh_loop = add_swh_loop(template,
                                   'Main Service Water Loop',
                                   nil,
                                   OpenStudio.convert(prototype_input['main_service_water_temperature'], 'F', 'C').get,
                                   prototype_input['main_service_water_pump_head'],
                                   prototype_input['main_service_water_pump_motor_efficiency'],
                                   OpenStudio.convert(prototype_input['main_water_heater_capacity'], 'Btu/hr', 'W').get,
                                   OpenStudio.convert(prototype_input['main_water_heater_volume'], 'gal', 'm^3').get,
                                   prototype_input['main_water_heater_fuel'],
                                   OpenStudio.convert(prototype_input['main_service_water_parasitic_fuel_consumption_rate'], 'Btu/hr', 'W').get,
                                   building_type) unless building_type == 'RetailStripmall' && template != 'NECB 2011'

      # Attach the end uses if specified in prototype inputs
      # TODO remove special logic for large office SWH end uses
      # TODO remove special logic for stripmall SWH end uses and service water loops
      # TODO remove special logic for large hotel SWH end uses
      if building_type == 'LargeOffice' && template != 'NECB 2011'

        # Only the core spaces have service water
        ['Core_bottom', 'Core_mid', 'Core_top'].each do |space_name|
          add_swh_end_uses(template,
                           'Main',
                           main_swh_loop,
                           OpenStudio.convert(prototype_input['main_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                           prototype_input['main_service_water_flowrate_schedule'],
                           OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                           space_name,
                           building_type)
        end

      elsif building_type == 'RetailStripmall' && template != 'NECB 2011'

        return true if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'

        # Create a separate hot water loop & water heater for each space in the list
        swh_space_names = ['LGstore1', 'SMstore1', 'SMstore2', 'SMstore3', 'LGstore2', 'SMstore5', 'SMstore6']
        swh_sch_names = ['RetailStripmall Type1_SWH_SCH', 'RetailStripmall Type1_SWH_SCH', 'RetailStripmall Type2_SWH_SCH',
                         'RetailStripmall Type2_SWH_SCH', 'RetailStripmall Type3_SWH_SCH', 'RetailStripmall Type3_SWH_SCH',
                         'RetailStripmall Type3_SWH_SCH']
        rated_use_rate_gal_per_min = 0.03 # in gal/min
        rated_flow_rate_m3_per_s = OpenStudio.convert(rated_use_rate_gal_per_min, 'gal/min', 'm^3/s').get

        # Loop through all spaces
        swh_space_names.zip(swh_sch_names).each do |swh_space_name, swh_sch_name|
          swh_thermal_zone = getSpaceByName(swh_space_name).get.thermalZone.get
          main_swh_loop = add_swh_loop(template,
                                       "#{swh_thermal_zone.name} Service Water Loop",
                                       swh_thermal_zone,
                                       OpenStudio.convert(prototype_input['main_service_water_temperature'], 'F', 'C').get,
                                       prototype_input['main_service_water_pump_head'],
                                       prototype_input['main_service_water_pump_motor_efficiency'],
                                       OpenStudio.convert(prototype_input['main_water_heater_capacity'], 'Btu/hr', 'W').get,
                                       OpenStudio.convert(prototype_input['main_water_heater_volume'], 'gal', 'm^3').get,
                                       prototype_input['main_water_heater_fuel'],
                                       OpenStudio.convert(prototype_input['main_service_water_parasitic_fuel_consumption_rate'], 'Btu/hr', 'W').get,
                                       building_type)

          add_swh_end_uses(template,
                           'Main',
                           main_swh_loop,
                           rated_flow_rate_m3_per_s,
                           swh_sch_name,
                           OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                           swh_space_name,
                           building_type)
        end

      #
      #       elsif building_type == 'LargeHotel'
      #
      #         # Add water use equipment to each space
      #         guess_room_water_use_schedule = "HotelLarge GuestRoom_SWH_Sch"
      #         kitchen_water_use_schedule = "HotelLarge BLDG_SWH_SCH"
      #
      #         water_end_uses = []
      #         space_type_map = self.define_space_type_map(building_type, template, climate_zone)
      #         space_multipliers = define_space_multiplier
      #
      #         kitchen_space_types = ['Kitchen']
      #         kitchen_space_use_rate = 2.22 # gal/min, from PNNL prototype building
      #
      #         guess_room_water_use_rate = 0.020833333 # gal/min, Reference: NREL Reference building report 5.1.6
      #
      #         # Create a list of water use rates and associated room multipliers
      #         case template
      #         when "90.1-2004", "90.1-2007", "90.1-2010", "90.1-2013"
      #           guess_room_space_types =['GuestRoom','GuestRoom2','GuestRoom3','GuestRoom4']
      #         else
      #           guess_room_space_types =['GuestRoom','GuestRoom3']
      #           guess_room_space_types1 = ['GuestRoom2']
      #           guess_room_space_types2 = ['GuestRoom4']
      #           guess_room_water_use_rate1 = 0.395761032 # gal/min, Reference building
      #           guess_room_water_use_rate2 = 0.187465752 # gal/min, Reference building
      #
      #           laundry_water_use_schedule = "HotelLarge LaundryRoom_Eqp_Elec_Sch"
      #           laundry_space_types = ['Laundry']
      #           laundry_room_water_use_rate = 2.6108244 # gal/min, Reference building
      #
      #           guess_room_space_types1.each do |space_type|
      #             space_names = space_type_map[space_type]
      #             space_names.each do |space_name|
      #               space_multiplier = 1
      #               space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
      #               water_end_uses.push([space_name, guess_room_water_use_rate1 * space_multiplier,guess_room_water_use_schedule])
      #             end
      #           end
      #
      #           guess_room_space_types2.each do |space_type|
      #             space_names = space_type_map[space_type]
      #             space_names.each do |space_name|
      #               space_multiplier = 1
      #               space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
      #               water_end_uses.push([space_name, guess_room_water_use_rate2 * space_multiplier,guess_room_water_use_schedule])
      #             end
      #           end
      #
      #           laundry_space_types.each do |space_type|
      #             space_names = space_type_map[space_type]
      #             space_names.each do |space_name|
      #               space_multiplier = 1
      #               space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
      #               water_end_uses.push([space_name, laundry_room_water_use_rate * space_multiplier,laundry_water_use_schedule])
      #             end
      #           end
      #         end
      #
      #         guess_room_space_types.each do |space_type|
      #           space_names = space_type_map[space_type]
      #           space_names.each do |space_name|
      #             space_multiplier = 1
      #             space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
      #             water_end_uses.push([space_name, guess_room_water_use_rate * space_multiplier,guess_room_water_use_schedule])
      #           end
      #         end
      #
      #         kitchen_space_types.each do |space_type|
      #           space_names = space_type_map[space_type]
      #           space_names.each do |space_name|
      #             space_multiplier = 1
      #             space_multiplier= space_multipliers[space_name].to_i if space_multipliers[space_name] != nil
      #             water_end_uses.push([space_name, kitchen_space_use_rate * space_multiplier,kitchen_water_use_schedule])
      #           end
      #         end
      #
      #         # Connect the water use equipment to the loop
      #         water_end_uses.each do |water_end_use|
      #           space_name = water_end_use[0]
      #           use_rate = water_end_use[1] # in gal/min
      #           use_schedule = water_end_use[2]
      #
      #           self.add_swh_end_uses(template,
      #                               'Main',
      #                               main_swh_loop,
      #                               OpenStudio.convert(use_rate,'gal/min','m^3/s').get,
      #                               use_schedule,
      #                               OpenStudio.convert(prototype_input['main_water_use_temperature'],'F','C').get,
      #                               space_name,
      #                               building_type)
      #         end

      elsif prototype_input['main_service_water_peak_flowrate']

        # Attaches the end uses if specified as a lump value in the prototype_input
        add_swh_end_uses(template,
                         'Main',
                         main_swh_loop,
                         OpenStudio.convert(prototype_input['main_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                         prototype_input['main_service_water_flowrate_schedule'],
                         OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                         nil,
                         building_type)

      else

        # Attaches the end uses if specified by space type
        space_type_map = define_space_type_map(building_type, template, climate_zone)

        if template == 'NECB 2011'
          building_type = 'Space Function'
        end

        space_type_map.each do |space_type_name, space_names|
          search_criteria = {
            'template' => template,
            'building_type' => get_lookup_name(building_type),
            'space_type' => space_type_name
          }
          data = find_object($os_standards['space_types'], search_criteria)

          # Skip space types with no data
          next if data.nil?

          # Skip space types with no water use, unless it is a NECB archetype (these do not have peak flow rates defined)
          next unless template == 'NECB 2011' || !data['service_water_heating_peak_flow_rate'].nil?

          # Add a service water use for each space
          space_names.each do |space_name|
            space = getSpaceByName(space_name).get
            space_multiplier = space.multiplier
            add_swh_end_uses_by_space(get_lookup_name(building_type),
                                      template,
                                      climate_zone,
                                      main_swh_loop,
                                      space_type_name,
                                      space_name,
                                      space_multiplier)
          end
        end

      end

    end

    # Add the booster water heater, if specified
    unless prototype_input['booster_water_heater_volume'].nil?

      # Add the booster water loop
      swh_booster_loop = add_swh_booster(template,
                                         main_swh_loop,
                                         OpenStudio.convert(prototype_input['booster_water_heater_capacity'], 'Btu/hr', 'W').get,
                                         OpenStudio.convert(prototype_input['booster_water_heater_volume'], 'gal', 'm^3').get,
                                         prototype_input['booster_water_heater_fuel'],
                                         OpenStudio.convert(prototype_input['booster_water_temperature'], 'F', 'C').get,
                                         0,
                                         nil,
                                         building_type)

      # Attach the end uses
      add_booster_swh_end_uses(template,
                               swh_booster_loop,
                               OpenStudio.convert(prototype_input['booster_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                               prototype_input['booster_service_water_flowrate_schedule'],
                               OpenStudio.convert(prototype_input['booster_water_use_temperature'], 'F', 'C').get,
                               building_type)

    end

    # Add the laundry water heater, if specified
    unless prototype_input['laundry_water_heater_volume'].nil?

      # Add the laundry service water heating loop
      laundry_swh_loop = add_swh_loop(template,
                                      'Laundry Service Water Loop',
                                      nil,
                                      OpenStudio.convert(prototype_input['laundry_service_water_temperature'], 'F', 'C').get,
                                      prototype_input['laundry_service_water_pump_head'],
                                      prototype_input['laundry_service_water_pump_motor_efficiency'],
                                      OpenStudio.convert(prototype_input['laundry_water_heater_capacity'], 'Btu/hr', 'W').get,
                                      OpenStudio.convert(prototype_input['laundry_water_heater_volume'], 'gal', 'm^3').get,
                                      prototype_input['laundry_water_heater_fuel'],
                                      OpenStudio.convert(prototype_input['laundry_service_water_parasitic_fuel_consumption_rate'], 'Btu/hr', 'W').get,
                                      building_type)

      # Attach the end uses if specified in prototype inputs
      add_swh_end_uses(template,
                       'Laundry',
                       laundry_swh_loop,
                       OpenStudio.convert(prototype_input['laundry_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                       prototype_input['laundry_service_water_flowrate_schedule'],
                       OpenStudio.convert(prototype_input['laundry_water_use_temperature'], 'F', 'C').get,
                       nil,
                       building_type)

    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding Service Water Heating')

    return true
  end # add swh

  # add typical swh demand and supply to model
  #
  # @param [String] template
  # @param [Bool] trust_effective_num_spaces
  # @param [String] fuel (gas, electric, nil) nil is smart
  # @param [Double] pipe_insul_in
  # @param [String] circulating, (circulating, noncirculating, nil) nil is smart
  # @return [Array] hot water loops
  # @todo - add in losses from tank and pipe insulation, etc.
  def add_typical_swh(template, trust_effective_num_spaces = false, fuel = nil, pipe_insul_in = nil, circulating = nil)

    # array of hot water loops
    swh_systems = []

    # hash of general water use equipment awaiting loop
    water_use_equipment_hash = {} # key is standards building type value is array of water use equipment

    # create space type hash (need num_units for MidriseApartment and RetailStripmall)
    space_type_hash = self.create_space_type_hash(template,trust_effective_num_spaces = false)

    # add temperate schedules to hash so they can be shared across water use equipment
    water_use_def_schedules = {} # key is temp C value is schedule

    # loop through space types adding demand side of swh
    self.getSpaceTypes.each do |space_type|
      next if not space_type.standardsBuildingType.is_initialized
      next if not space_type.standardsSpaceType.is_initialized
      next if not space_type_hash.has_key?(space_type) # this is used for space types without any floor area
      stds_bldg_type = space_type.standardsBuildingType.get
      stds_space_type = space_type.standardsSpaceType.get

      # lookup space_type_properties
      space_type_properties = space_type.get_standards_data(template)
      gal_hr_per_area = space_type_properties['service_water_heating_peak_flow_per_area']
      gal_hr_peak_flow_rate = space_type_properties['service_water_heating_peak_flow_rate']
      flow_rate_fraction_schedule = self.add_schedule(space_type_properties['service_water_heating_schedule'])
      service_water_temperature_si = space_type_properties['service_water_heating_target_temperature']
      service_water_fraction_sensible = space_type_properties['service_water_heating_fraction_sensible']
      service_water_fraction_latent = space_type_properties['service_water_heating_fraction_latent']
      floor_area_si = space_type_hash[space_type][:floor_area]
      floor_area_ip = OpenStudio::convert(floor_area_si,"m^2","ft^2").get

      # next if no service water heating demand
      next if not (gal_hr_per_area.to_f > 0.0 || gal_hr_peak_flow_rate.to_f > 0.0)

      if (stds_bldg_type == "MidriseApartment" && stds_space_type.include?("Apartment")) || stds_bldg_type == "StripMall"
        num_units = space_type_hash[space_type][:num_units].round
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding dedicated water heating fpr #{num_units} #{space_type.name} units, each with max flow rate of #{gal_hr_peak_flow_rate} gal/hr per.")

        # add water use equipment definition
        water_use_equip_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(self)
        water_use_equip_def.setName("#{space_type.name} SWH def")
        peak_flow_rate_si = OpenStudio::convert(gal_hr_peak_flow_rate,"gal/hr","m^3/s").get
        water_use_equip_def.setPeakFlowRate(peak_flow_rate_si)
        target_temp = service_water_temperature_si # in spreadsheet in si, no conversion needed unless that changes
        name = "#{target_temp} C"
        if water_use_def_schedules.has_key?(name)
          target_temperature_sch = water_use_def_schedules[name]
        else
          target_temperature_sch = self.add_constant_schedule_ruleset(target_temp,name)
          water_use_def_schedules[name] = target_temperature_sch
        end
        water_use_equip_def.setTargetTemperatureSchedule(target_temperature_sch)
        name = "#{service_water_fraction_sensible} Fraction"
        if water_use_def_schedules.has_key?(name)
          service_water_fraction_sensible_sch = water_use_def_schedules[name]
        else
          service_water_fraction_sensible_sch = self.add_constant_schedule_ruleset(service_water_fraction_sensible,name)
          water_use_def_schedules[name] = service_water_fraction_sensible_sch
        end
        water_use_equip_def.setSensibleFractionSchedule(service_water_fraction_sensible_sch)
        name = "#{service_water_fraction_latent} Fraction"
        if water_use_def_schedules.has_key?(name)
          service_water_fraction_latent_sch = water_use_def_schedules[name]
        else
          service_water_fraction_latent_sch = self.add_constant_schedule_ruleset(service_water_fraction_sensible,name)
          water_use_def_schedules[name] = service_water_fraction_latent_sch
        end
        water_use_equip_def.setLatentFractionSchedule(service_water_fraction_latent_sch)

        # add water use equipment, connection, and loop for each unit
        num_units.times do |i|

          # add water use equipment
          water_use_equip = OpenStudio::Model::WaterUseEquipment.new(water_use_equip_def)
          water_use_equip.setFlowRateFractionSchedule(flow_rate_fraction_schedule)
          water_use_equip.setName("#{space_type.name} SWH #{i+1}")

          # add water use connection
          water_use_connection = OpenStudio::Model::WaterUseConnections.new(self)
          water_use_connection.addWaterUseEquipment(water_use_equip)
          water_use_connection.setName("#{space_type.name} WUC #{i+1}")

          # gather inputs for add_swh_loop
          # default fuel, capacity, and volume from Table A.1. Water Heating Equipment Enhancements to ASHRAE Standard 90.1 Prototype Building Models
          # temperature, pump head, motor efficiency, and parasitic load from Prototype Inputs
          sys_name = "#{space_type.name} Service Water Loop #{i+1}"
          water_heater_thermal_zone = nil
          service_water_temperature = service_water_temperature_si
          service_water_pump_head = 0.01
          service_water_pump_motor_efficiency = 1.0
          if fuel.nil?
            water_heater_fuel = "Electric"
          else
            water_heater_fuel = fuel
          end
          if stds_bldg_type == "MidriseApartment"
            water_heater_capacity = OpenStudio::convert(15.0,"kBtu/hr","W").get
            water_heater_volume = OpenStudio::convert(50.0,"gal","m^3").get
            parasitic_fuel_consumption_rate = 0.0 # Prototype inputs has 87.75W but prototype IDF's use 0
          else # StripMall
            water_heater_capacity = OpenStudio::convert(12.0,"kBtu/hr","W").get
            water_heater_volume = OpenStudio::convert(40.0,"gal","m^3").get
            parasitic_fuel_consumption_rate = 173.0
          end

          # make loop for each unit and add on water use equipment
          unit_hot_water_loop = add_swh_loop(template,
                                                   sys_name,
                                                   water_heater_thermal_zone,
                                                   service_water_temperature,
                                                   service_water_pump_head,
                                                   service_water_pump_motor_efficiency,
                                                   water_heater_capacity,
                                                   water_heater_volume,
                                                   water_heater_fuel,
                                                   parasitic_fuel_consumption_rate,
                                                stds_bldg_type)

          # Connect the water use connection to the SWH loop
          unit_hot_water_loop.addDemandBranchForComponent(water_use_connection)

          # apply efficiency to hot water heater
          unit_hot_water_loop.supplyComponents.each do |component|
            next if not component.to_WaterHeaterMixed.is_initialized
            component = component.to_WaterHeaterMixed.get
            component.apply_efficiency(template)
          end

          # add to list of systems
          swh_systems << unit_hot_water_loop

        end

      elsif stds_space_type.include?("Kitchen") || stds_space_type.include?("Laundry")
        gal_hr_peak_flow_rate = gal_hr_per_area * floor_area_ip
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding dedicated water heating for #{space_type.name} space type with max flow rate of #{gal_hr_peak_flow_rate} gal/hr.")

        # add water use equipment definition
        water_use_equip_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(self)
        water_use_equip_def.setName("#{space_type.name} SWH def")
        peak_flow_rate_si = OpenStudio::convert(gal_hr_peak_flow_rate,"gal/hr","m^3/s").get
        water_use_equip_def.setPeakFlowRate(peak_flow_rate_si)
        target_temp = service_water_temperature_si # in spreadsheet in si, no conversion needed unless that changes
        name = "#{target_temp} C"
        if water_use_def_schedules.has_key?(name)
          target_temperature_sch = water_use_def_schedules[name]
        else
          target_temperature_sch = self.add_constant_schedule_ruleset(target_temp,name)
          water_use_def_schedules[name] = target_temperature_sch
        end
        water_use_equip_def.setTargetTemperatureSchedule(target_temperature_sch)
        name = "#{service_water_fraction_sensible} Fraction"
        if water_use_def_schedules.has_key?(name)
          service_water_fraction_sensible_sch = water_use_def_schedules[name]
        else
          service_water_fraction_sensible_sch = self.add_constant_schedule_ruleset(service_water_fraction_sensible,name)
          water_use_def_schedules[name] = service_water_fraction_sensible_sch
        end
        water_use_equip_def.setSensibleFractionSchedule(service_water_fraction_sensible_sch)
        name = "#{service_water_fraction_latent} Fraction"
        if water_use_def_schedules.has_key?(name)
          service_water_fraction_latent_sch = water_use_def_schedules[name]
        else
          service_water_fraction_latent_sch = self.add_constant_schedule_ruleset(service_water_fraction_sensible,name)
          water_use_def_schedules[name] = service_water_fraction_latent_sch
        end
        water_use_equip_def.setLatentFractionSchedule(service_water_fraction_latent_sch)

        # add water use equipment
        water_use_equip = OpenStudio::Model::WaterUseEquipment.new(water_use_equip_def)
        water_use_equip.setFlowRateFractionSchedule(flow_rate_fraction_schedule)
        water_use_equip.setName("#{space_type.name} SWH")

        # add water use connection
        water_use_connection = OpenStudio::Model::WaterUseConnections.new(self)
        water_use_connection.addWaterUseEquipment(water_use_equip)
        water_use_connection.setName("#{space_type.name} WUC")

        # gather inputs for add_swh_loop
        sys_name = "#{space_type.name} Service Water Loop"
        water_heater_thermal_zone = nil
        water_heater_temp_si = 60.0 # C
        service_water_pump_head = 0.01
        service_water_pump_motor_efficiency = 1.0
        if fuel.nil?
          water_heater_fuel = "Gas"
        else
          water_heater_fuel = fuel
        end

        # find_water_heater_capacity_volume_and_parasitic
        water_use_equipment_array = [water_use_equip]
        water_heater_sizing = find_water_heater_capacity_volume_and_parasitic(water_use_equipment_array)
        water_heater_capacity = water_heater_sizing[:water_heater_capacity]
        water_heater_volume = water_heater_sizing[:water_heater_volume]
        parasitic_fuel_consumption_rate = water_heater_sizing[:parasitic_fuel_consumption_rate]

        # make loop for each unit and add on water use equipment
        dedicated_hot_water_loop = add_swh_loop(template,
                                              sys_name,
                                              water_heater_thermal_zone,
                                              water_heater_temp_si,
                                              service_water_pump_head,
                                              service_water_pump_motor_efficiency,
                                              water_heater_capacity,
                                              water_heater_volume,
                                              water_heater_fuel,
                                              parasitic_fuel_consumption_rate,
                                              stds_bldg_type)

        # Connect the water use connection to the SWH loop
        dedicated_hot_water_loop.addDemandBranchForComponent(water_use_connection)

        # find water heater
        dedicated_hot_water_loop.supplyComponents.each do |component|
          next if not component.to_WaterHeaterMixed.is_initialized
          water_heater = component.to_WaterHeaterMixed.get

          # apply efficiency to hot water heater
          water_heater.apply_efficiency(template)
        end

        # add to list of systems
        swh_systems << dedicated_hot_water_loop

        # add booster to all kitchens except for QuickServiceRestaurant (QuickServiceRestaurant assumed to use chemicals instead of hotter water)
        # boosters are all 6 gal elec but heating capacity varies from 3 to 19 (kBtu/hr) for prototype buildings
        if stds_space_type.include?("Kitchen") && stds_bldg_type != "QuickServiceRestaurant"

          # find_water_heater_capacity_volume_and_parasitic
          water_use_equipment_array = [water_use_equip]
          inlet_temp_ip = OpenStudio::convert(service_water_temperature_si,"C","F").get # pre-booster temp
          outlet_temp_ip = inlet_temp_ip + 40.0
          peak_flow_fraction = 0.6 # assume 60% of peak for dish washing
          water_heater_sizing = find_water_heater_capacity_volume_and_parasitic(water_use_equipment_array,pipe_hash = {},1.0,1.0,inlet_temp_ip,outlet_temp_ip,peak_flow_fraction)
          water_heater_capacity = water_heater_sizing[:water_heater_capacity]

          # gather additional inputs for add_swh_booster
          water_heater_volume = OpenStudio::convert(6,"gal",'m^3').get
          water_heater_fuel = "Electric"
          booster_water_temperature = 82.22 # C
          parasitic_fuel_consumption_rate = 0.0
          booster_water_heater_thermal_zone = nil

          # add_swh_booster
          booster_service_water_loop = add_swh_booster(template,
                                                       dedicated_hot_water_loop,
                                                      water_heater_capacity,
                                                      water_heater_volume,
                                                      water_heater_fuel,
                                                      booster_water_temperature,
                                                      parasitic_fuel_consumption_rate,
                                                      booster_water_heater_thermal_zone,
                                                      stds_bldg_type)


          # find water heater
          booster_service_water_loop.supplyComponents.each do |component|
            next if not component.to_WaterHeaterMixed.is_initialized
            water_heater = component.to_WaterHeaterMixed.get

            # apply efficiency to hot water heater
            water_heater.apply_efficiency(template)
          end

          # rename booster loop
          booster_service_water_loop.setName("#{space_type.name} Booster Service Water Loop")
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding Electric Booster water heater for #{space_type.name} on a loop named #{booster_service_water_loop.name}.")

        end

      else # store water use equip by building type in hash so can add general building type hot water loop

        gal_hr_peak_flow_rate = gal_hr_per_area * floor_area_ip
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding water heating for #{space_type.name} space type with max flow rate of #{gal_hr_peak_flow_rate} gal/hr on a shared loop.")

        # add water use equipment definition
        water_use_equip_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(self)
        water_use_equip_def.setName("#{space_type.name} SWH def")
        peak_flow_rate_si = OpenStudio::convert(gal_hr_peak_flow_rate,"gal/hr","m^3/s").get
        water_use_equip_def.setPeakFlowRate(peak_flow_rate_si)
        target_temp = service_water_temperature_si # in spreadsheet in si, no conversion needed unless that changes
        name = "#{target_temp} C"
        if water_use_def_schedules.has_key?(name)
          target_temperature_sch = water_use_def_schedules[name]
        else
          target_temperature_sch = self.add_constant_schedule_ruleset(target_temp,name)
          water_use_def_schedules[name] = target_temperature_sch
        end
        water_use_equip_def.setTargetTemperatureSchedule(target_temperature_sch)
        name = "#{service_water_fraction_sensible} Fraction"
        if water_use_def_schedules.has_key?(name)
          service_water_fraction_sensible_sch = water_use_def_schedules[name]
        else
          service_water_fraction_sensible_sch = self.add_constant_schedule_ruleset(service_water_fraction_sensible,name)
          water_use_def_schedules[name] = service_water_fraction_sensible_sch
        end
        water_use_equip_def.setSensibleFractionSchedule(service_water_fraction_sensible_sch)
        name = "#{service_water_fraction_latent} Fraction"
        if water_use_def_schedules.has_key?(name)
          service_water_fraction_latent_sch = water_use_def_schedules[name]
        else
          service_water_fraction_latent_sch = self.add_constant_schedule_ruleset(service_water_fraction_sensible,name)
          water_use_def_schedules[name] = service_water_fraction_latent_sch
        end
        water_use_equip_def.setLatentFractionSchedule(service_water_fraction_latent_sch)

        # add water use equipment
        water_use_equip = OpenStudio::Model::WaterUseEquipment.new(water_use_equip_def)
        water_use_equip.setFlowRateFractionSchedule(flow_rate_fraction_schedule)
        water_use_equip.setName("#{space_type.name} SWH")
        
        if water_use_equipment_hash.has_key?(stds_bldg_type)
          water_use_equipment_hash[stds_bldg_type] << water_use_equip
        else
          water_use_equipment_hash[stds_bldg_type] = [water_use_equip]
        end

      end

    end

    # get building floor area and effective number of stories
    bldg_floor_area = self.getBuilding.floorArea
    bldg_effective_num_stories_hash = self.effective_num_stories
    bldg_effective_num_stories = bldg_effective_num_stories_hash[:below_grade] + bldg_effective_num_stories_hash[:above_grade]

    # add non-dedicated system(s) here. Separate systems for water use equipment from different building types
    water_use_equipment_hash.each do |stds_bldg_type,water_use_equipment_array|

      # gather inputs for add_swh_loop
      sys_name = "#{stds_bldg_type} Shared Service Water Loop"
      water_heater_thermal_zone = nil
      water_heater_temp_si = 60.0

      # find pump values
      # Table A.2 in PrototypeModelEnhancements_2014_0.pdf shows 10ft on everything except SecondarySchool which has 11.4ft
      # todo - if SmallOffice then shouldn't have circulating pump
      if ["Office","PrimarySchool","Outpatient","Hospital","SmallHotel","LargeHotel","FullServiceRestaurant","HighriseApartment"].include?(stds_bldg_type)
        service_water_pump_head = OpenStudio::convert(10.0,"ftH_{2}O","Pa").get
        service_water_pump_motor_efficiency = 0.3
        if circulating.nil? then irculating = true end
        if pipe_insul_in.nil? then pipe_insul_in = 0.5 end
      elsif ["SecondarySchool"].include?(stds_bldg_type)
        service_water_pump_head = OpenStudio::convert(11.4,"ftH_{2}O","Pa").get
        service_water_pump_motor_efficiency = 0.3
        if circulating.nil? then irculating = true end
        if pipe_insul_in.nil? then pipe_insul_in = 0.5 end
      else # values for non-circulating pump
        service_water_pump_head = 0.01
        service_water_pump_motor_efficiency = 1.0
        if circulating.nil? then irculating = false end
        if pipe_insul_in.nil? then pipe_insul_in = 0.0 end
      end

      # todo - add building type or sice specific logic or just assume Gas? (SmallOffice and Warehouse are only non unit prototypes with Electric heating)
      if fuel.nil?
        water_heater_fuel = "Gas"
      else
        water_heater_fuel = fuel
      end

      bldg_type_floor_area = 0.0
      space_type_hash.each do |space_type,hash|
        next if not hash[:stds_bldg_type] == stds_bldg_type
        bldg_type_floor_area += hash[:floor_area]
      end

      # inputs for find_water_heater_capacity_volume_and_parasitic
      pipe_hash = {}
      pipe_hash[:floor_area] = bldg_type_floor_area
      pipe_hash[:effective_num_stories] = bldg_effective_num_stories * (bldg_type_floor_area/bldg_floor_area)
      pipe_hash[:circulating] = circulating
      pipe_hash[:insulation_thickness] = pipe_insul_in

      # find_water_heater_capacity_volume_and_parasitic
      water_heater_sizing = find_water_heater_capacity_volume_and_parasitic(water_use_equipment_array, pipe_hash)
      water_heater_capacity = water_heater_sizing[:water_heater_capacity]
      water_heater_volume = water_heater_sizing[:water_heater_volume]
      parasitic_fuel_consumption_rate = water_heater_sizing[:parasitic_fuel_consumption_rate]
      if parasitic_fuel_consumption_rate > 0
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding parasitic loss for #{stds_bldg_type} loopo of #{parasitic_fuel_consumption_rate.round} Btu/hr.")
      end

      # make loop for each unit and add on water use equipment
      shared_hot_water_loop = add_swh_loop(template,
                                              sys_name,
                                              water_heater_thermal_zone,
                                              water_heater_temp_si,
                                              service_water_pump_head,
                                              service_water_pump_motor_efficiency,
                                              water_heater_capacity,
                                              water_heater_volume,
                                              water_heater_fuel,
                                              parasitic_fuel_consumption_rate,
                                              stds_bldg_type)

      # find water heater
      shared_hot_water_loop.supplyComponents.each do |component|
        next if not component.to_WaterHeaterMixed.is_initialized
        water_heater = component.to_WaterHeaterMixed.get

        # apply efficiency to hot water heater
        water_heater.apply_efficiency(template)
      end

      # loop through water use equipment
      water_use_equipment_array.each do |water_use_equip|
        # add water use connection
        water_use_connection = OpenStudio::Model::WaterUseConnections.new(self)
        water_use_connection.addWaterUseEquipment(water_use_equip)
        water_use_connection.setName(water_use_equip.name.get.gsub("SWH","WUC"))

        # Connect the water use connection to the SWH loop
        shared_hot_water_loop.addDemandBranchForComponent(water_use_connection)
      end

      # add to list of systems
      swh_systems << shared_hot_water_loop

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding shared water heating loop for #{stds_bldg_type}.")

    end

    return swh_systems

  end

  # set capacity, volume, and parasitic
  #
  # @param [Array] array of water use equipment objects that will be using this water heater
  # @param [Double] storage_to_cap_ratio gal of storage to kBtu/hr of capacitiy
  # @param [Double] htg_eff fraction
  # @param [Double] cld_wtr_temp_ip cold water temperature F
  # @param [Double] target_temp F
  # @return [Hash] hash with values needed to size water heater made with downstream method
  def find_water_heater_capacity_volume_and_parasitic(water_use_equipment_array, pipe_hash = {}, storage_to_cap_ratio = 1.0,htg_eff = 0.8,inlet_temp_ip = 40.0,target_temp_ip = 140.0,peak_flow_fraction = 1.0)

    # A.1.4 Total Storage Volume and Water Heater Capacity of PrototypeModelEnhancements_2014_0.pdf shows 1 gallon of storage to 1 kBtu/h of capacity

    water_heater_sizing = {}

    # get water use equipment
    max_flow_rate_array = [] # gallons per hour
    water_use_equipment_array.each do |water_use_equip|
      water_use_equip_sch = water_use_equip.flowRateFractionSchedule
      next if not water_use_equip_sch.is_initialized and water_use_equip_sch.get.to_ScheduleRuleset.is_initialized
      water_use_equip_sch = water_use_equip_sch.get.to_ScheduleRuleset.get
      max_sch_value = water_use_equip_sch.annual_min_max_value['max']

      # get water_use_equip_def to get max flow rate
      water_use_equip_def = water_use_equip.waterUseEquipmentDefinition
      peak_flow_rate = water_use_equip_def.peakFlowRate

      # calculate adjusted flow rate
      adjusted_peak_flow_rate_si = max_sch_value * peak_flow_rate
      adjusted_peak_flow_rate_ip = OpenStudio::convert(adjusted_peak_flow_rate_si,"m^3/s","gal/min").get
      max_flow_rate_array << adjusted_peak_flow_rate_ip * 60.0 # min per hour
    end

    # warn if max_flow_rate_array size doesn't match equipment size (one or more didn't have ruleset schedule)
    if max_flow_rate_array.size != water_use_equipment_array.size
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "One or more Water Use Equipment Fraction Flow Rate Scheules were not Schedule Rulestes and were excluding from Water Heating Sizing.")
    end

    # sum gpm values from water use equipment to use in formula
    adjusted_flow_rate_sum = max_flow_rate_array.inject(:+)

    # use formula to calculate volume and capacity based on analysis of combined water use equipment maximum flow rates and schedules
    # Max gal/hr * 8.4 lb/gal * 1 Btu/lb F * (120F - 40F)/0.8 = Btu/hr
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Capacity is #{peak_flow_fraction} * #{adjusted_flow_rate_sum} gal/hr * 8.4 * 1.0 * (#{target_temp_ip} - #{inlet_temp_ip}/ #{htg_eff}).")
    water_heater_capacity_ip = peak_flow_fraction * adjusted_flow_rate_sum * 8.4 * 1.0 * (target_temp_ip - inlet_temp_ip) / htg_eff
    water_heater_capacity_si = OpenStudio::convert(water_heater_capacity_ip,"Btu/hr","W").get
    water_heater_volume_ip = OpenStudio::convert(water_heater_capacity_ip,"Btu/hr","kBtu/hr").get
    # increase tank size to 40 galons if calculated value is smaller
    if water_heater_volume_ip < 40.0 # gal
      water_heater_volume_ip = 40.0
    end
    water_heater_volume_si = OpenStudio::convert(water_heater_volume_ip,"gal","m^3").get

    # populate return hash
    water_heater_sizing[:water_heater_capacity] = water_heater_capacity_si
    water_heater_sizing[:water_heater_volume] = water_heater_volume_si

    # get pipe length (formula from A.3.1 PrototypeModelEnhancements_2014_0.pdf)
    if pipe_hash.size > 0

      pipe_length = 2.0  * (Math.sqrt(pipe_hash[:floor_area]/pipe_hash[:effective_num_stories]) + (10.0 * (pipe_hash[:effective_num_stories]-1.0)))
      pipe_length_ip = OpenStudio::convert(pipe_length,"m","ft").get

      # calculate pipe dump (from A.4.1)
      pipe_dump = pipe_length_ip * 0.689 # Btu/hr

      if pipe_hash[:circulating]
        if pipe_hash[:insulation_thickness] >= 1.0
          pipe_loss_per_foot = 16.10
        elsif pipe_hash[:insulation_thickness] >= 0.5
          pipe_loss_per_foot = 17.5
        else
          pipe_loss_per_foot = 30.8
        end
      else
        if pipe_hash[:insulation_thickness] >= 1.0
          pipe_loss_per_foot = 11.27
        elsif pipe_hash[:insulation_thickness] >= 0.5
          pipe_loss_per_foot = 12.25
        else
          pipe_loss_per_foot = 28.07
        end
      end

      # calculate pipe loss (from Table A.3 in section A.4.2)
      pipe_loss = pipe_length * pipe_loss_per_foot # Btu/hr

      # calculate parasitic loss
      water_heater_sizing[:parasitic_fuel_consumption_rate] = pipe_dump + pipe_loss
    else
      water_heater_sizing[:parasitic_fuel_consumption_rate] = 0.0
    end

    return water_heater_sizing

  end

end

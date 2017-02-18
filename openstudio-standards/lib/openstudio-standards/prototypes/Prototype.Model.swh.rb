
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
  # @return [Hash] :water_use_equipment, :water_heater, :hot_water_loop
  def add_typical_swh(template, trust_effective_num_spaces = false, fuel = nil, pipe_insul_in = 0.0, circulating = nil)

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
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding dedicated water heating to #{num_units} #{space_type.name} units, each with max flow rate of #{gal_hr_peak_flow_rate} gal/hr per.")

        # add water use equipment definition
        water_use_equip_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(self)
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

        # add water use equipment for each def
        num_units.times do |i|
          water_use_equip = OpenStudio::Model::WaterUseEquipment.new(water_use_equip_def)
          water_use_equip.setFlowRateFractionSchedule(flow_rate_fraction_schedule)

          # add water use connection
          water_use_connection = OpenStudio::Model::WaterUseConnections.new(self)
          water_use_connection.addWaterUseEquipment(water_use_equip)

          # gather inputs for add_swh_loop
          # default fuel, capacity, and volume from Table A.1. Water Heating Equipment Enhancements to ASHRAE Standard 90.1 Prototype Building Models
          # temperature, pump head, motor efficency, and parasitic load from Prototype Inputs
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
          midrise_hot_water_loop = add_swh_loop(template,
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

          # apply efficiency to hot water heater
          midrise_hot_water_loop.supplyComponents.each do |component|
            next if not component.to_WaterHeaterMixed.is_initialized
            component = component.to_WaterHeaterMixed.get
            component.apply_efficiency(template)
          end

          # add to list of systems
          swh_systems << midrise_hot_water_loop

        end

      elsif stds_space_type.include?("Kitchen") || stds_space_type.include?("Laundry")
        puts "testing #{space_type.name}, it has and area of #{floor_area_ip.round} ft^2 and a max flow rate of #{gal_hr_per_area} gal/hr per ft^2."
        puts " * #{stds_space_type} should be on dedicated hot water heater"

        # todo - use water_heater_mixed.set_capacity_and_volume to size water heater

        # todo - add booster to all kitchens except for QuickServiceRestaurant
        # todo - boosters are all 6 gal elec but heating capacity varies from 3 to 19 kW (kBtu/hr)

        # todo - set system efficiencies

      else
        puts "testing #{space_type.name}, it has and area of #{floor_area_ip.round} ft^2 and a max flow rate of #{gal_hr_per_area} gal/hr per ft^2."
        # todo - store water use equip by building type in array so can add general building type hot water loop
      end

    end

    # todo - add rest of inputs to make swervice water heating loop
    if fuel.nil?
      water_heater_fuel = "Electric"
    else
      water_heater_fuel = fuel
    end

    # todo - add non-dedicated system(s) here. Separate systems for water use equipment from different building types

    # todo - add in losses from tank and pipe insulation, parasitic, etc.

    # todo - set system efficiencies

    return swh_systems

  end

end

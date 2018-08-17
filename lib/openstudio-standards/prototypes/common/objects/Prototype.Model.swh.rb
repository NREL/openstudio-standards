class Standard
  def model_add_swh(model, building_type, climate_zone, prototype_input, epw_file)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Service Water Heating')

    # Add the main service water heating loop, if specified
    unless prototype_input['main_water_heater_volume'].nil?
      # Get the thermal zone for the water heater, if specified
      water_heater_zone = nil
      if prototype_input['main_water_heater_space_name']
        wh_space_name = prototype_input['main_water_heater_space_name']
        wh_space = model.getSpaceByName(wh_space_name)
        if wh_space.empty?
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', "Cannot find a space called #{wh_space_name} in the model, water heater will not be placed in a zone.")
        else
          wh_zone = wh_space.get.thermalZone
          if wh_zone.empty?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', "Cannot find a zone that contains the space #{wh_space_name} in the model, water heater will not be placed in a zone.")
          else
            water_heater_zone = wh_zone.get
          end
        end
      end

      swh_fueltype = prototype_input['main_water_heater_fuel']
      # Add the main service water loop
      unless building_type == 'RetailStripmall' && template != 'NECB2011'
        main_swh_loop = model_add_swh_loop(model,
                                           'Main Service Water Loop',
                                           water_heater_zone,
                                           OpenStudio.convert(prototype_input['main_service_water_temperature'], 'F', 'C').get,
                                           prototype_input['main_service_water_pump_head'],
                                           prototype_input['main_service_water_pump_motor_efficiency'],
                                           OpenStudio.convert(prototype_input['main_water_heater_capacity'], 'Btu/hr', 'W').get,
                                           OpenStudio.convert(prototype_input['main_water_heater_volume'], 'gal', 'm^3').get,
                                           swh_fueltype,
                                           OpenStudio.convert(prototype_input['main_service_water_parasitic_fuel_consumption_rate'], 'Btu/hr', 'W').get,
                                           building_type)
      end

      # Attach the end uses if specified in prototype inputs
      # TODO remove special logic for large office SWH end uses
      # TODO remove special logic for stripmall SWH end uses and service water loops
      # TODO remove special logic for large hotel SWH end uses
      if building_type == 'LargeOffice' && template != 'NECB2011'

        # Only the core spaces have service water
        ['Core_bottom', 'Core_mid', 'Core_top'].sort.each do |space_name|
          # ['Mechanical_Bot_ZN_1','Mechanical_Mid_ZN_1','Mechanical_Top_ZN_1'].each do |space_name| # for new space type large office
          model_add_swh_end_uses(model,
                                 'Main',
                                 main_swh_loop,
                                 OpenStudio.convert(prototype_input['main_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                                 prototype_input['main_service_water_flowrate_schedule'],
                                 OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                                 space_name,
                                 building_type)
        end
      elsif building_type == 'LargeOfficeDetail' && template != 'NECB2011'

        # Only mechanical rooms have service water
        ['Mechanical_Bot_ZN_1', 'Mechanical_Mid_ZN_1', 'Mechanical_Top_ZN_1'].sort.each do |space_name| # for new space type large office
          model_add_swh_end_uses(model,
                                 'Main',
                                 main_swh_loop,
                                 OpenStudio.convert(prototype_input['main_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                                 prototype_input['main_service_water_flowrate_schedule'],
                                 OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                                 space_name,
                                 building_type)
        end
      elsif building_type == 'RetailStripmall' && template != 'NECB2011'

        return true if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'

        # Create a separate hot water loop & water heater for each space in the list
        swh_space_names = ['LGstore1', 'SMstore1', 'SMstore2', 'SMstore3', 'LGstore2', 'SMstore5', 'SMstore6']
        swh_sch_names = ['RetailStripmall Type1_SWH_SCH', 'RetailStripmall Type1_SWH_SCH', 'RetailStripmall Type2_SWH_SCH',
                         'RetailStripmall Type2_SWH_SCH', 'RetailStripmall Type3_SWH_SCH', 'RetailStripmall Type3_SWH_SCH',
                         'RetailStripmall Type3_SWH_SCH']
        rated_use_rate_gal_per_min = 0.03 # in gal/min
        rated_flow_rate_m3_per_s = OpenStudio.convert(rated_use_rate_gal_per_min, 'gal/min', 'm^3/s').get

        # Loop through all spaces
        swh_space_names.zip(swh_sch_names).sort.each do |swh_space_name, swh_sch_name|
          swh_thermal_zone = model.getSpaceByName(swh_space_name).get.thermalZone.get
          main_swh_loop = model_add_swh_loop(model,
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

          model_add_swh_end_uses(model,
                                 'Main',
                                 main_swh_loop,
                                 rated_flow_rate_m3_per_s,
                                 swh_sch_name,
                                 OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                                 swh_space_name,
                                 building_type)
        end

      elsif prototype_input['main_service_water_peak_flowrate']
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', 'Adding shw by main_service_water_peak_flowrate')

        # Attaches the end uses if specified as a lump value in the prototype_input
        model_add_swh_end_uses(model,
                               'Main',
                               main_swh_loop,
                               OpenStudio.convert(prototype_input['main_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                               prototype_input['main_service_water_flowrate_schedule'],
                               OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                               nil,
                               building_type)

      else
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Model', 'Adding shw by space_type_map')

        # Attaches the end uses if specified by space type
        space_type_map = @space_type_map

        if template == 'NECB2011'
          building_type = 'Space Function'
        end

        # Log how many water fixtures are added
        water_fixtures = []

        # Loop through spaces types and add service hot water if specified
        space_type_map.sort.each do |space_type_name, space_names|
          search_criteria = {
              'template' => template,
              'building_type' => model_get_lookup_name(building_type),
              'space_type' => space_type_name
          }
          data = model_find_object(standards_data['space_types'], search_criteria)

          # Skip space types with no data
          next if data.nil?

          # Skip space types with no water use, unless it is a NECB archetype (these do not have peak flow rates defined)
          next unless template == 'NECB2011' || !data['service_water_heating_peak_flow_rate'].nil? || !data['service_water_heating_peak_flow_per_area'].nil?

          # Add a service water use for each space
          space_names.sort.each do |space_name|
            space = model.getSpaceByName(space_name).get
            space_multiplier = nil
            space_multiplier = case template
                                 when 'NECB2011'
                                   # Added this to prevent double counting of zone multipliers.. space multipliers are never used in NECB archtypes.
                                   1
                                 else
                                   space.multiplier
                               end

            water_fixture = model_add_swh_end_uses_by_space(model, model_get_lookup_name(building_type),
                                            climate_zone,
                                            main_swh_loop,
                                            space_type_name,
                                            space_name,
                                            space_multiplier)
            unless water_fixture.nil?
              water_fixtures << water_fixture
            end
          end
        end

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{water_fixtures.size} water fixtures to model")

      end

    end

    # Add the booster water heater, if specified
    unless prototype_input['booster_water_heater_volume'].nil?

      # Add the booster water loop
      swh_booster_loop = model_add_swh_booster(model,
                                               main_swh_loop,
                                               OpenStudio.convert(prototype_input['booster_water_heater_capacity'], 'Btu/hr', 'W').get,
                                               OpenStudio.convert(prototype_input['booster_water_heater_volume'], 'gal', 'm^3').get,
                                               prototype_input['booster_water_heater_fuel'],
                                               OpenStudio.convert(prototype_input['booster_water_temperature'], 'F', 'C').get,
                                               0,
                                               nil,
                                               building_type)

      # Attach the end uses
      model_add_booster_swh_end_uses(model,
                                     swh_booster_loop,
                                     OpenStudio.convert(prototype_input['booster_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                                     prototype_input['booster_service_water_flowrate_schedule'],
                                     OpenStudio.convert(prototype_input['booster_water_use_temperature'], 'F', 'C').get,
                                     building_type)

    end

    # Add the laundry water heater, if specified
    unless prototype_input['laundry_water_heater_volume'].nil?

      # Add the laundry service water heating loop
      laundry_swh_loop = model_add_swh_loop(model,
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
      model_add_swh_end_uses(model,
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
  end

  # add swh

  # add typical swh demand and supply to model
  #
  # @param trust_effective_num_spaces [Bool]
  # @param fuel [String] (gas, electric, nil) nil is smart
  # @param pipe_insul_in [Double]
  # @param circulating [String] (circulating, noncirculating, nil) nil is smart
  # @return [Array] hot water loops
  # @todo - add in losses from tank and pipe insulation, etc.
  def model_add_typical_swh(model, trust_effective_num_spaces = false, fuel = nil, pipe_insul_in = nil, circulating = nil)
    # array of hot water loops
    swh_systems = []

    # hash of general water use equipment awaiting loop
    water_use_equipment_hash = {} # key is standards building type value is array of water use equipment

    # create space type hash (need num_units for MidriseApartment and RetailStripmall)
    space_type_hash = model_create_space_type_hash(model, trust_effective_num_spaces = false)

    # add temperate schedules to hash so they can be shared across water use equipment
    water_use_def_schedules = {} # key is temp C value is schedule

    # loop through space types adding demand side of swh
    model.getSpaceTypes.sort.each do |space_type|
      next unless space_type.standardsBuildingType.is_initialized
      next unless space_type.standardsSpaceType.is_initialized
      next unless space_type_hash.key?(space_type) # this is used for space types without any floor area
      stds_bldg_type = space_type.standardsBuildingType.get
      stds_space_type = space_type.standardsSpaceType.get

      # lookup space_type_properties
      space_type_properties = space_type_get_standards_data(space_type)
      gal_hr_per_area = space_type_properties['service_water_heating_peak_flow_per_area']
      gal_hr_peak_flow_rate = space_type_properties['service_water_heating_peak_flow_rate']
      flow_rate_fraction_schedule = model_add_schedule(model, space_type_properties['service_water_heating_schedule'])
      service_water_temperature_si = space_type_properties['service_water_heating_target_temperature']
      service_water_fraction_sensible = space_type_properties['service_water_heating_fraction_sensible']
      service_water_fraction_latent = space_type_properties['service_water_heating_fraction_latent']
      floor_area_si = space_type_hash[space_type][:floor_area]
      floor_area_ip = OpenStudio.convert(floor_area_si, 'm^2', 'ft^2').get

      # next if no service water heating demand
      next unless gal_hr_per_area.to_f > 0.0 || gal_hr_peak_flow_rate.to_f > 0.0

      # If there is no SWH schedule specified, assume
      # that there should be no SWH consumption for this space type.
      unless flow_rate_fraction_schedule
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "No service water heating schedule was specified for #{space_type.name}, an always off schedule will be used and no water will be used.")
        flow_rate_fraction_schedule = model.alwaysOffDiscreteSchedule
      end

      if (stds_bldg_type == 'MidriseApartment' && stds_space_type.include?('Apartment')) || stds_bldg_type == 'StripMall'
        num_units = space_type_hash[space_type][:num_units].round
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding dedicated water heating fpr #{num_units} #{space_type.name} units, each with max flow rate of #{gal_hr_peak_flow_rate} gal/hr per.")

        # add water use equipment definition
        water_use_equip_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
        water_use_equip_def.setName("#{space_type.name} SWH def")
        peak_flow_rate_si = OpenStudio.convert(gal_hr_peak_flow_rate, 'gal/hr', 'm^3/s').get
        water_use_equip_def.setPeakFlowRate(peak_flow_rate_si)
        target_temp = service_water_temperature_si # in spreadsheet in si, no conversion needed unless that changes
        name = "#{target_temp} C"
        if water_use_def_schedules.key?(name)
          target_temperature_sch = water_use_def_schedules[name]
        else
          target_temperature_sch = model_add_constant_schedule_ruleset(model, target_temp, name)
          water_use_def_schedules[name] = target_temperature_sch
        end
        water_use_equip_def.setTargetTemperatureSchedule(target_temperature_sch)
        name = "#{service_water_fraction_sensible} Fraction"
        if water_use_def_schedules.key?(name)
          service_water_fraction_sensible_sch = water_use_def_schedules[name]
        else
          service_water_fraction_sensible_sch = model_add_constant_schedule_ruleset(model, service_water_fraction_sensible, name)
          water_use_def_schedules[name] = service_water_fraction_sensible_sch
        end
        water_use_equip_def.setSensibleFractionSchedule(service_water_fraction_sensible_sch)
        name = "#{service_water_fraction_latent} Fraction"
        if water_use_def_schedules.key?(name)
          service_water_fraction_latent_sch = water_use_def_schedules[name]
        else
          service_water_fraction_latent_sch = model_add_constant_schedule_ruleset(model, service_water_fraction_sensible, name)
          water_use_def_schedules[name] = service_water_fraction_latent_sch
        end
        water_use_equip_def.setLatentFractionSchedule(service_water_fraction_latent_sch)

        # add water use equipment, connection, and loop for each unit
        num_units.times do |i|
          # add water use equipment
          water_use_equip = OpenStudio::Model::WaterUseEquipment.new(water_use_equip_def)
          water_use_equip.setFlowRateFractionSchedule(flow_rate_fraction_schedule)
          water_use_equip.setName("#{space_type.name} SWH #{i + 1}")

          # add water use connection
          water_use_connection = OpenStudio::Model::WaterUseConnections.new(model)
          water_use_connection.addWaterUseEquipment(water_use_equip)
          water_use_connection.setName("#{space_type.name} WUC #{i + 1}")

          # gather inputs for add_swh_loop
          # default fuel, capacity, and volume from Table A.1. Water Heating Equipment Enhancements to ASHRAE Standard 90.1 Prototype Building Models
          # temperature, pump head, motor efficiency, and parasitic load from Prototype Inputs
          system_name = "#{space_type.name} Service Water Loop #{i + 1}"
          water_heater_thermal_zone = nil
          service_water_temperature = service_water_temperature_si
          service_water_pump_head = 0.01
          service_water_pump_motor_efficiency = 1.0
          water_heater_fuel = if fuel.nil?
                                'Electric'
                              else
                                fuel
                              end
          if stds_bldg_type == 'MidriseApartment'
            water_heater_capacity = OpenStudio.convert(15.0, 'kBtu/hr', 'W').get
            water_heater_volume = OpenStudio.convert(50.0, 'gal', 'm^3').get
            parasitic_fuel_consumption_rate = 0.0 # Prototype inputs has 87.75W but prototype IDF's use 0
          else # StripMall
            water_heater_capacity = OpenStudio.convert(12.0, 'kBtu/hr', 'W').get
            water_heater_volume = OpenStudio.convert(40.0, 'gal', 'm^3').get
            parasitic_fuel_consumption_rate = 173.0
          end

          # make loop for each unit and add on water use equipment
          unit_hot_water_loop = model_add_swh_loop(model,
                                                   system_name,
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
          unit_hot_water_loop.supplyComponents.sort.each do |component|
            next if component.to_WaterHeaterMixed.empty?
            component = component.to_WaterHeaterMixed.get
            water_heater_mixed_apply_efficiency(component)
          end

          # add to list of systems
          swh_systems << unit_hot_water_loop
        end

      elsif stds_space_type.include?('Kitchen') || stds_space_type.include?('Laundry')
        gal_hr_peak_flow_rate = gal_hr_per_area * floor_area_ip
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding dedicated water heating for #{space_type.name} space type with max flow rate of #{gal_hr_peak_flow_rate.round} gal/hr.")

        # add water use equipment definition
        water_use_equip_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
        water_use_equip_def.setName("#{space_type.name} SWH def")
        peak_flow_rate_si = OpenStudio.convert(gal_hr_peak_flow_rate, 'gal/hr', 'm^3/s').get
        water_use_equip_def.setPeakFlowRate(peak_flow_rate_si)
        target_temp = service_water_temperature_si # in spreadsheet in si, no conversion needed unless that changes
        name = "#{target_temp} C"
        if water_use_def_schedules.key?(name)
          target_temperature_sch = water_use_def_schedules[name]
        else
          target_temperature_sch = model_add_constant_schedule_ruleset(model, target_temp, name)
          water_use_def_schedules[name] = target_temperature_sch
        end
        water_use_equip_def.setTargetTemperatureSchedule(target_temperature_sch)
        name = "#{service_water_fraction_sensible} Fraction"
        if water_use_def_schedules.key?(name)
          service_water_fraction_sensible_sch = water_use_def_schedules[name]
        else
          service_water_fraction_sensible_sch = model_add_constant_schedule_ruleset(model, service_water_fraction_sensible, name)
          water_use_def_schedules[name] = service_water_fraction_sensible_sch
        end
        water_use_equip_def.setSensibleFractionSchedule(service_water_fraction_sensible_sch)
        name = "#{service_water_fraction_latent} Fraction"
        if water_use_def_schedules.key?(name)
          service_water_fraction_latent_sch = water_use_def_schedules[name]
        else
          service_water_fraction_latent_sch = model_add_constant_schedule_ruleset(model, service_water_fraction_sensible, name)
          water_use_def_schedules[name] = service_water_fraction_latent_sch
        end
        water_use_equip_def.setLatentFractionSchedule(service_water_fraction_latent_sch)

        # add water use equipment
        water_use_equip = OpenStudio::Model::WaterUseEquipment.new(water_use_equip_def)
        water_use_equip.setFlowRateFractionSchedule(flow_rate_fraction_schedule)
        water_use_equip.setName("#{space_type.name} SWH")

        # add water use connection
        water_use_connection = OpenStudio::Model::WaterUseConnections.new(model)
        water_use_connection.addWaterUseEquipment(water_use_equip)
        water_use_connection.setName("#{space_type.name} WUC")

        # gather inputs for add_swh_loop
        system_name = "#{space_type.name} Service Water Loop"
        water_heater_thermal_zone = nil
        water_heater_temp_si = 60.0 # C
        service_water_pump_head = 0.01
        service_water_pump_motor_efficiency = 1.0
        water_heater_fuel = if fuel.nil?
                              'Gas'
                            else
                              fuel
                            end

        # find_water_heater_capacity_volume_and_parasitic
        water_use_equipment_array = [water_use_equip]
        water_heater_sizing = model_find_water_heater_capacity_volume_and_parasitic(model, water_use_equipment_array)
        water_heater_capacity = water_heater_sizing[:water_heater_capacity]
        water_heater_volume = water_heater_sizing[:water_heater_volume]
        parasitic_fuel_consumption_rate = water_heater_sizing[:parasitic_fuel_consumption_rate]

        # make loop for each unit and add on water use equipment
        dedicated_hot_water_loop = model_add_swh_loop(model,
                                                      system_name,
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
        dedicated_hot_water_loop.supplyComponents.sort.each do |component|
          next if component.to_WaterHeaterMixed.empty?
          water_heater = component.to_WaterHeaterMixed.get

          # apply efficiency to hot water heater
          water_heater_mixed_apply_efficiency(water_heater)
        end

        # add to list of systems
        swh_systems << dedicated_hot_water_loop

        # add booster to all kitchens except for QuickServiceRestaurant (QuickServiceRestaurant assumed to use chemicals instead of hotter water)
        # boosters are all 6 gal elec but heating capacity varies from 3 to 19 (kBtu/hr) for prototype buildings
        if stds_space_type.include?('Kitchen') && stds_bldg_type != 'QuickServiceRestaurant'

          # find_water_heater_capacity_volume_and_parasitic
          water_use_equipment_array = [water_use_equip]
          inlet_temp_ip = OpenStudio.convert(service_water_temperature_si, 'C', 'F').get # pre-booster temp
          outlet_temp_ip = inlet_temp_ip + 40.0
          peak_flow_fraction = 0.6 # assume 60% of peak for dish washing
          water_heater_sizing = model_find_water_heater_capacity_volume_and_parasitic(model, water_use_equipment_array, pipe_hash = {}, 1.0, 1.0, inlet_temp_ip, outlet_temp_ip, peak_flow_fraction)
          water_heater_capacity = water_heater_sizing[:water_heater_capacity]

          # gather additional inputs for add_swh_booster
          water_heater_volume = OpenStudio.convert(6, 'gal', 'm^3').get
          water_heater_fuel = 'Electric'
          booster_water_temperature = 82.22 # C
          parasitic_fuel_consumption_rate = 0.0
          booster_water_heater_thermal_zone = nil

          # add_swh_booster
          booster_service_water_loop = model_add_swh_booster(model,
                                                             dedicated_hot_water_loop,
                                                             water_heater_capacity,
                                                             water_heater_volume,
                                                             water_heater_fuel,
                                                             booster_water_temperature,
                                                             parasitic_fuel_consumption_rate,
                                                             booster_water_heater_thermal_zone,
                                                             stds_bldg_type)

          # find water heater
          booster_service_water_loop.supplyComponents.sort.each do |component|
            next if component.to_WaterHeaterMixed.empty?
            water_heater = component.to_WaterHeaterMixed.get

            # apply efficiency to hot water heater
            water_heater_mixed_apply_efficiency(water_heater)
          end

          # rename booster loop
          booster_service_water_loop.setName("#{space_type.name} Booster Service Water Loop")
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding Electric Booster water heater for #{space_type.name} on a loop named #{booster_service_water_loop.name}.")

        end

      else # store water use equip by building type in hash so can add general building type hot water loop

        gal_hr_peak_flow_rate = gal_hr_per_area * floor_area_ip
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding water heating for #{space_type.name} space type with max flow rate of #{gal_hr_peak_flow_rate.round} gal/hr on a shared loop.")

        # add water use equipment definition
        water_use_equip_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
        water_use_equip_def.setName("#{space_type.name} SWH def")
        peak_flow_rate_si = OpenStudio.convert(gal_hr_peak_flow_rate, 'gal/hr', 'm^3/s').get
        water_use_equip_def.setPeakFlowRate(peak_flow_rate_si)
        target_temp = service_water_temperature_si # in spreadsheet in si, no conversion needed unless that changes
        name = "#{target_temp} C"
        if water_use_def_schedules.key?(name)
          target_temperature_sch = water_use_def_schedules[name]
        else
          target_temperature_sch = model_add_constant_schedule_ruleset(model, target_temp, name)
          water_use_def_schedules[name] = target_temperature_sch
        end
        water_use_equip_def.setTargetTemperatureSchedule(target_temperature_sch)
        name = "#{service_water_fraction_sensible} Fraction"
        if water_use_def_schedules.key?(name)
          service_water_fraction_sensible_sch = water_use_def_schedules[name]
        else
          service_water_fraction_sensible_sch = model_add_constant_schedule_ruleset(model, service_water_fraction_sensible, name)
          water_use_def_schedules[name] = service_water_fraction_sensible_sch
        end
        water_use_equip_def.setSensibleFractionSchedule(service_water_fraction_sensible_sch)
        name = "#{service_water_fraction_latent} Fraction"
        if water_use_def_schedules.key?(name)
          service_water_fraction_latent_sch = water_use_def_schedules[name]
        else
          service_water_fraction_latent_sch = model_add_constant_schedule_ruleset(model, service_water_fraction_sensible, name)
          water_use_def_schedules[name] = service_water_fraction_latent_sch
        end
        water_use_equip_def.setLatentFractionSchedule(service_water_fraction_latent_sch)

        # add water use equipment
        water_use_equip = OpenStudio::Model::WaterUseEquipment.new(water_use_equip_def)
        water_use_equip.setFlowRateFractionSchedule(flow_rate_fraction_schedule)
        water_use_equip.setName("#{space_type.name} SWH")

        if water_use_equipment_hash.key?(stds_bldg_type)
          water_use_equipment_hash[stds_bldg_type] << water_use_equip
        else
          water_use_equipment_hash[stds_bldg_type] = [water_use_equip]
        end

      end
    end

    # get building floor area and effective number of stories
    bldg_floor_area = model.getBuilding.floorArea
    bldg_effective_num_stories_hash = model_effective_num_stories(model)
    bldg_effective_num_stories = bldg_effective_num_stories_hash[:below_grade] + bldg_effective_num_stories_hash[:above_grade]

    # add non-dedicated system(s) here. Separate systems for water use equipment from different building types
    water_use_equipment_hash.sort.each do |stds_bldg_type, water_use_equipment_array|
      # gather inputs for add_swh_loop
      system_name = "#{stds_bldg_type} Shared Service Water Loop"
      water_heater_thermal_zone = nil
      water_heater_temp_si = 60.0

      # find pump values
      # Table A.2 in PrototypeModelEnhancements_2014_0.pdf shows 10ft on everything except SecondarySchool which has 11.4ft
      # todo - if SmallOffice then shouldn't have circulating pump
      if ['Office', 'PrimarySchool', 'Outpatient', 'Hospital', 'SmallHotel', 'LargeHotel', 'FullServiceRestaurant', 'HighriseApartment'].include?(stds_bldg_type)
        service_water_pump_head = OpenStudio.convert(10.0, 'ftH_{2}O', 'Pa').get
        service_water_pump_motor_efficiency = 0.3
        if circulating.nil? then
          irculating = true
        end
        if pipe_insul_in.nil? then
          pipe_insul_in = 0.5
        end
      elsif ['SecondarySchool'].include?(stds_bldg_type)
        service_water_pump_head = OpenStudio.convert(11.4, 'ftH_{2}O', 'Pa').get
        service_water_pump_motor_efficiency = 0.3
        if circulating.nil? then
          irculating = true
        end
        if pipe_insul_in.nil? then
          pipe_insul_in = 0.5
        end
      else # values for non-circulating pump
        service_water_pump_head = 0.01
        service_water_pump_motor_efficiency = 1.0
        if circulating.nil? then
          irculating = false
        end
        if pipe_insul_in.nil? then
          pipe_insul_in = 0.0
        end
      end

      # TODO: - add building type or sice specific logic or just assume Gas? (SmallOffice and Warehouse are only non unit prototypes with Electric heating)
      water_heater_fuel = if fuel.nil?
                            'Gas'
                          else
                            fuel
                          end

      bldg_type_floor_area = 0.0
      space_type_hash.sort.each do |space_type, hash|
        next if hash[:stds_bldg_type] != stds_bldg_type
        bldg_type_floor_area += hash[:floor_area]
      end

      # inputs for find_water_heater_capacity_volume_and_parasitic
      pipe_hash = {}
      pipe_hash[:floor_area] = bldg_type_floor_area
      pipe_hash[:effective_num_stories] = bldg_effective_num_stories * (bldg_type_floor_area / bldg_floor_area)
      pipe_hash[:circulating] = circulating
      pipe_hash[:insulation_thickness] = pipe_insul_in

      # find_water_heater_capacity_volume_and_parasitic
      water_heater_sizing = model_find_water_heater_capacity_volume_and_parasitic(model, water_use_equipment_array, pipe_hash)
      water_heater_capacity = water_heater_sizing[:water_heater_capacity]
      water_heater_volume = water_heater_sizing[:water_heater_volume]
      parasitic_fuel_consumption_rate = water_heater_sizing[:parasitic_fuel_consumption_rate]
      if parasitic_fuel_consumption_rate > 0
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding parasitic loss for #{stds_bldg_type} loop of #{parasitic_fuel_consumption_rate.round} Btu/hr.")
      end

      # make loop for each unit and add on water use equipment
      shared_hot_water_loop = model_add_swh_loop(model,
                                                 system_name,
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
      shared_hot_water_loop.supplyComponents.sort.each do |component|
        next if component.to_WaterHeaterMixed.empty?
        water_heater = component.to_WaterHeaterMixed.get

        # apply efficiency to hot water heater
        water_heater_mixed_apply_efficiency(water_heater)
      end

      # loop through water use equipment
      water_use_equipment_array.sort.each do |water_use_equip|
        # add water use connection
        water_use_connection = OpenStudio::Model::WaterUseConnections.new(model)
        water_use_connection.addWaterUseEquipment(water_use_equip)
        water_use_connection.setName(water_use_equip.name.get.gsub('SWH', 'WUC'))

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
  # @param water_use_equipment_array [Array] array of water use equipment objects that will be using this water heater
  # @param storage_to_cap_ratio [Double]  gal of storage to kBtu/hr of capacitiy
  # @param htg_eff [Double] fraction
  # @param inlet_temp_ip [Double] cold water temperature F
  # @param target_temp_ip [Double] F
  # @return [Hash] hash with values needed to size water heater made with downstream method
  def model_find_water_heater_capacity_volume_and_parasitic(model, water_use_equipment_array, pipe_hash = {}, storage_to_cap_ratio = 1.0, htg_eff = 0.8, inlet_temp_ip = 40.0, target_temp_ip = 140.0, peak_flow_fraction = 1.0)
    # A.1.4 Total Storage Volume and Water Heater Capacity of PrototypeModelEnhancements_2014_0.pdf shows 1 gallon of storage to 1 kBtu/h of capacity

    water_heater_sizing = {}

    # get water use equipment
    max_flow_rate_array = [] # gallons per hour
    water_use_equipment_array.sort.each do |water_use_equip|
      water_use_equip_sch = water_use_equip.flowRateFractionSchedule
      next if water_use_equip_sch.empty?
      water_use_equip_sch = water_use_equip_sch.get
      if water_use_equip_sch.to_ScheduleRuleset.is_initialized
        water_use_equip_sch = water_use_equip_sch.to_ScheduleRuleset.get
        max_sch_value = schedule_ruleset_annual_min_max_value(water_use_equip_sch)['max']
      elsif water_use_equip_sch.to_ScheduleConstant.is_initialized
        water_use_equip_sch = water_use_equip_sch.to_ScheduleConstant.get
        max_sch_value = schedule_constant_annual_min_max_value(water_use_equip_sch)['max']
      elsif water_use_equip_sch.to_ScheduleCompact.is_initialized
        water_use_equip_sch = water_use_equip_sch.to_ScheduleCompact.get
        max_sch_value = schedule_compact_annual_min_max_value(water_use_equip_sch)['max']
      end

      # get water_use_equip_def to get max flow rate
      water_use_equip_def = water_use_equip.waterUseEquipmentDefinition
      peak_flow_rate = water_use_equip_def.peakFlowRate

      # calculate adjusted flow rate
      adjusted_peak_flow_rate_si = max_sch_value * peak_flow_rate
      adjusted_peak_flow_rate_ip = OpenStudio.convert(adjusted_peak_flow_rate_si, 'm^3/s', 'gal/min').get
      max_flow_rate_array << adjusted_peak_flow_rate_ip * 60.0 # min per hour
    end

    # warn if max_flow_rate_array size doesn't match equipment size (one or more didn't have ruleset schedule)
    if max_flow_rate_array.size != water_use_equipment_array.size
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'One or more Water Use Equipment Fraction Flow Rate Scheules were not Schedule Rulestes and were excluding from Water Heating Sizing.')
    end

    # sum gpm values from water use equipment to use in formula
    adjusted_flow_rate_sum = max_flow_rate_array.inject(:+)

    # use formula to calculate volume and capacity based on analysis of combined water use equipment maximum flow rates and schedules
    # Max gal/hr * 8.4 lb/gal * 1 Btu/lb F * (120F - 40F)/0.8 = Btu/hr
    water_heater_capacity_ip = peak_flow_fraction * adjusted_flow_rate_sum * 8.4 * 1.0 * (target_temp_ip - inlet_temp_ip) / htg_eff
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Capacity of #{water_heater_capacity_ip} Btu/hr = #{peak_flow_fraction} peak fraction * #{adjusted_flow_rate_sum.round} gal/hr * 8.4 lb/gal * 1.0 Btu/lb F * (#{target_temp_ip.round} - #{inlet_temp_ip.round} deltaF / #{htg_eff} htg eff).")
    water_heater_capacity_si = OpenStudio.convert(water_heater_capacity_ip, 'Btu/hr', 'W').get
    # Assume 1 gal of volume per 1 kBtu/hr of heating capacity
    water_heater_volume_ip = OpenStudio.convert(water_heater_capacity_ip, 'Btu/hr', 'kBtu/hr').get
    # increase tank size to 40 galons if calculated value is smaller
    if water_heater_volume_ip < 40.0 # gal
      water_heater_volume_ip = 40.0
    end
    water_heater_volume_si = OpenStudio.convert(water_heater_volume_ip, 'gal', 'm^3').get

    # populate return hash
    water_heater_sizing[:water_heater_capacity] = water_heater_capacity_si
    water_heater_sizing[:water_heater_volume] = water_heater_volume_si

    # get pipe length (formula from A.3.1 PrototypeModelEnhancements_2014_0.pdf)
    if !pipe_hash.empty?

      pipe_length = 2.0 * (Math.sqrt(pipe_hash[:floor_area] / pipe_hash[:effective_num_stories]) + (10.0 * (pipe_hash[:effective_num_stories] - 1.0)))
      pipe_length_ip = OpenStudio.convert(pipe_length, 'm', 'ft').get

      # calculate pipe dump (from A.4.1)
      pipe_dump = pipe_length_ip * 0.689 # Btu/hr

      pipe_loss_per_foot = if pipe_hash[:circulating]
                             if pipe_hash[:insulation_thickness] >= 1.0
                               16.10
                             elsif pipe_hash[:insulation_thickness] >= 0.5
                               17.5
                             else
                               30.8
                             end
                           else
                             if pipe_hash[:insulation_thickness] >= 1.0
                               11.27
                             elsif pipe_hash[:insulation_thickness] >= 0.5
                               12.25
                             else
                               28.07
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

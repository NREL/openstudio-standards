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
                                           prototype_input['main_service_water_pump_head'].to_f,
                                           prototype_input['main_service_water_pump_motor_efficiency'],
                                           OpenStudio.convert(prototype_input['main_water_heater_capacity'], 'Btu/hr', 'W').get,
                                           OpenStudio.convert(prototype_input['main_water_heater_volume'], 'gal', 'm^3').get,
                                           swh_fueltype,
                                           OpenStudio.convert(prototype_input['main_service_water_parasitic_fuel_consumption_rate'], 'Btu/hr', 'W').get)
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
                                 space_name)
        end
      elsif building_type == 'LargeOfficeDetailed' && template != 'NECB2011'

        # Only mechanical rooms have service water
        ['Mechanical_Bot_ZN_1', 'Mechanical_Mid_ZN_1', 'Mechanical_Top_ZN_1'].sort.each do |space_name| # for new space type large office
          model_add_swh_end_uses(model,
                                 'Main',
                                 main_swh_loop,
                                 OpenStudio.convert(prototype_input['main_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                                 prototype_input['main_service_water_flowrate_schedule'],
                                 OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                                 space_name)
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
                                             prototype_input['main_service_water_pump_head'].to_f,
                                             prototype_input['main_service_water_pump_motor_efficiency'],
                                             OpenStudio.convert(prototype_input['main_water_heater_capacity'], 'Btu/hr', 'W').get,
                                             OpenStudio.convert(prototype_input['main_water_heater_volume'], 'gal', 'm^3').get,
                                             prototype_input['main_water_heater_fuel'],
                                             OpenStudio.convert(prototype_input['main_service_water_parasitic_fuel_consumption_rate'], 'Btu/hr', 'W').get)

          model_add_swh_end_uses(model,
                                 'Main',
                                 main_swh_loop,
                                 rated_flow_rate_m3_per_s,
                                 swh_sch_name,
                                 OpenStudio.convert(prototype_input['main_water_use_temperature'], 'F', 'C').get,
                                 swh_space_name)
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
                               nil)

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
          data = standards_lookup_table_first(table_name: 'space_types', search_criteria: search_criteria)

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

            water_fixture = model_add_swh_end_uses_by_space(model,
                                            main_swh_loop,
                                            space,
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
                                               nil)

      # Attach the end uses
      model_add_booster_swh_end_uses(model,
                                     swh_booster_loop,
                                     OpenStudio.convert(prototype_input['booster_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                                     prototype_input['booster_service_water_flowrate_schedule'],
                                     OpenStudio.convert(prototype_input['booster_water_use_temperature'], 'F', 'C').get)

    end

    # Add the laundry water heater, if specified
    unless prototype_input['laundry_water_heater_volume'].nil?

      # Add the laundry service water heating loop
      laundry_swh_loop = model_add_swh_loop(model,
                                            'Laundry Service Water Loop',
                                            nil,
                                            OpenStudio.convert(prototype_input['laundry_service_water_temperature'], 'F', 'C').get,
                                            prototype_input['laundry_service_water_pump_head'].to_f,
                                            prototype_input['laundry_service_water_pump_motor_efficiency'],
                                            OpenStudio.convert(prototype_input['laundry_water_heater_capacity'], 'Btu/hr', 'W').get,
                                            OpenStudio.convert(prototype_input['laundry_water_heater_volume'], 'gal', 'm^3').get,
                                            prototype_input['laundry_water_heater_fuel'],
                                            OpenStudio.convert(prototype_input['laundry_service_water_parasitic_fuel_consumption_rate'], 'Btu/hr', 'W').get)

      # Attach the end uses if specified in prototype inputs
      model_add_swh_end_uses(model,
                             'Laundry',
                             laundry_swh_loop,
                             OpenStudio.convert(prototype_input['laundry_service_water_peak_flowrate'], 'gal/min', 'm^3/s').get,
                             prototype_input['laundry_service_water_flowrate_schedule'],
                             OpenStudio.convert(prototype_input['laundry_water_use_temperature'], 'F', 'C').get,
                             nil)

    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding Service Water Heating')

    return true
  end

  # add typical swh demand and supply to model
  #
  # @param water_heater_fuel [String] water heater fuel. Valid choices are NaturalGas, Electricity, and HeatPump.
  #   If not supplied, a smart default will be determined based on building type.
  # @param pipe_insul_in [Double] thickness of the pipe insulation, in inches.
  # @param circulating [String] whether the (circulating, noncirculating, nil) nil is smart
  # @return [Array] hot water loops
  # @todo - add in losses from tank and pipe insulation, etc.
  def model_add_typical_swh(model,
                            water_heater_fuel: nil,
                            pipe_insul_in: nil,
                            circulating: nil)
    # array of hot water loops
    swh_systems = []

    # hash of general water use equipment awaiting loop
    water_use_equipment_hash = {} # key is standards building type value is array of water use equipment

    # create space type hash (need num_units for MidriseApartment and RetailStripmall)
    space_type_hash = model_create_space_type_hash(model, trust_effective_num_spaces = false)

    # loop through space types adding demand side of swh
    model.getSpaceTypes.sort.each do |space_type|
      next unless space_type.standardsBuildingType.is_initialized
      next unless space_type_hash.key?(space_type) # this is used for space types without any floor area
      stds_bldg_type = space_type.standardsBuildingType.get

      # lookup space_type_properties
      space_type_properties = space_type_get_standards_data(space_type)
      peak_flow_rate_gal_per_hr_per_ft2 = space_type_properties['service_water_heating_peak_flow_per_area'].to_f
      peak_flow_rate_gal_per_hr = space_type_properties['service_water_heating_peak_flow_rate'].to_f
      swh_system_type = space_type_properties['service_water_heating_system_type']
      flow_rate_fraction_schedule = model_add_schedule(model, space_type_properties['service_water_heating_schedule'])
      service_water_temperature_f = space_type_properties['service_water_heating_target_temperature'].to_f
      service_water_temperature_c = OpenStudio.convert(service_water_temperature_f, 'F', 'C').get
      booster_water_temperature_f = space_type_properties['booster_water_heating_target_temperature'].to_f
      booster_water_temperature_c = OpenStudio.convert(booster_water_temperature_f, 'F', 'C').get
      booster_water_heater_fraction = space_type_properties['booster_water_heater_fraction'].to_f
      service_water_fraction_sensible = space_type_properties['service_water_heating_fraction_sensible']
      service_water_fraction_latent = space_type_properties['service_water_heating_fraction_latent']
      floor_area_m2 = space_type_hash[space_type][:floor_area]
      floor_area_ft2 = OpenStudio.convert(floor_area_m2, 'm^2', 'ft^2').get

      # next if no service water heating demand
      next unless peak_flow_rate_gal_per_hr_per_ft2 > 0.0 || peak_flow_rate_gal_per_hr > 0.0

      # If there is no SWH schedule specified, assume
      # that there should be no SWH consumption for this space type.
      unless flow_rate_fraction_schedule
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "No service water heating schedule was specified for #{space_type.name}, an always off schedule will be used and no water will be used.")
        flow_rate_fraction_schedule = model.alwaysOffDiscreteSchedule
      end

      # Determine flow rate
      case swh_system_type
      when 'One Per Unit'
        water_heater_fuel = 'Electricity' if water_heater_fuel.nil?
        num_units = space_type_hash[space_type][:num_units].round # First try number of units
        num_units = space_type_hash[space_type][:effective_num_spaces].round if num_units.zero? # Fall back on number of spaces
        peak_flow_rate_gal_per_hr = num_units * peak_flow_rate_gal_per_hr
        peak_flow_rate_m3_per_s = OpenStudio.convert(peak_flow_rate_gal_per_hr, 'gal/hr', 'm^3/s').get
        use_name = "#{space_type.name} #{num_units} units"
      else
        # TODO: - add building type or sice specific logic or just assume Gas? (SmallOffice and Warehouse are only non unit prototypes with Electric heating)
        water_heater_fuel = 'NaturalGas' if water_heater_fuel.nil?
        num_units = 1
        peak_flow_rate_gal_per_hr = peak_flow_rate_gal_per_hr_per_ft2 * floor_area_ft2
        peak_flow_rate_m3_per_s = OpenStudio.convert(peak_flow_rate_gal_per_hr, 'gal/hr', 'm^3/s').get
        use_name = "#{space_type.name}"
      end

      # Split flow rate between main and booster uses if specified
      booster_water_use_equip = nil
      if booster_water_heater_fraction > 0.0
        booster_peak_flow_rate_m3_per_s = peak_flow_rate_m3_per_s * booster_water_heater_fraction
        peak_flow_rate_m3_per_s -= booster_peak_flow_rate_m3_per_s

        # Add booster water heater equipment and connections
        booster_water_use_equip = model_add_swh_end_uses(model,
                                                         "Booster #{use_name}",
                                                         loop=nil,
                                                         booster_peak_flow_rate_m3_per_s,
                                                         flow_rate_fraction_schedule.name.get,
                                                         booster_water_temperature_c,
                                                         space_name=nil,
                                                         frac_sensible: service_water_fraction_sensible,
                                                         frac_latent: service_water_fraction_latent)
      end

      # Add water use equipment and connections
      water_use_equip = model_add_swh_end_uses(model,
                                               use_name,
                                               swh_loop=nil,
                                               peak_flow_rate_m3_per_s,
                                               flow_rate_fraction_schedule.name.get,
                                               service_water_temperature_c,
                                               space_name=nil,
                                               frac_sensible: service_water_fraction_sensible,
                                               frac_latent: service_water_fraction_latent)

      # Water heater sizing
      case swh_system_type
      when 'One Per Unit'
        water_heater_capacity_w = num_units * OpenStudio.convert(20.0, 'kBtu/hr', 'W').get
        water_heater_volume_m3 = num_units * OpenStudio.convert(50.0, 'gal', 'm^3').get
        num_water_heaters = num_units
      else
        water_use_equips = [water_use_equip]
        water_use_equips << booster_water_use_equip unless booster_water_use_equip.nil? # Include booster in sizing since flows will be preheated by main water heater
        water_heater_sizing = model_find_water_heater_capacity_volume_and_parasitic(model, water_use_equips)
        water_heater_capacity_w = water_heater_sizing[:water_heater_capacity]
        water_heater_volume_m3 = water_heater_sizing[:water_heater_volume]
        num_water_heaters = 1
      end

      # Add either a dedicated SWH loop or save to add to shared SWH loop
      case swh_system_type
      when 'Shared'

        # Store water use equip by building type to add to shared building hot water loop
        if water_use_equipment_hash.key?(stds_bldg_type)
          water_use_equipment_hash[stds_bldg_type] << water_use_equip
        else
          water_use_equipment_hash[stds_bldg_type] = [water_use_equip]
        end

      when 'One Per Unit', 'Dedicated'
        pipe_insul_in = 0.0 if pipe_insul_in.nil?

        # Add service water loop with water heater
        swh_loop = model_add_swh_loop(model,
                                      system_name="#{space_type.name} Service Water Loop",
                                      water_heater_thermal_zone=nil,
                                      service_water_temperature_c,
                                      service_water_pump_head=0.01,
                                      service_water_pump_motor_efficiency=1.0,
                                      water_heater_capacity_w,
                                      water_heater_volume_m3,
                                      water_heater_fuel,
                                      parasitic_fuel_consumption_rate_w=0,
                                      add_pipe_losses=true,
                                      floor_area_served=OpenStudio.convert(950, 'ft^2', 'm^2').get,
                                      number_of_stories=1,
                                      pipe_insulation_thickness=OpenStudio.convert(pipe_insul_in, 'in', 'm').get,
                                      num_water_heaters)
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', "In model_add_typical, num_water_heaters = #{num_water_heaters}")
        # Add loop to list
        swh_systems << swh_loop

        # Attach water use equipment to the loop
        swh_connection = water_use_equip.waterUseConnections
        swh_loop.addDemandBranchForComponent(swh_connection.get) if swh_connection.is_initialized

        # If a booster fraction is specified, some percentage of the water
        # is assumed to be heated beyond the normal temperature by a separate
        # booster water heater.  This booster water heater is fed by the
        # main water heater, so the booster is responsible for a smaller delta-T.
        if booster_water_heater_fraction > 0
          # find_water_heater_capacity_volume_and_parasitic
          booster_water_heater_sizing = model_find_water_heater_capacity_volume_and_parasitic(model,
                                                                                              [booster_water_use_equip],
                                                                                              htg_eff: 1.0,
                                                                                              inlet_temp_f: service_water_temperature_f,
                                                                                              target_temp_f: booster_water_temperature_f)

          # Add service water booster loop with water heater
          # Note that booster water heaters are always assumed to be electric resistance
          swh_booster_loop = model_add_swh_booster(model,
                                                   swh_loop,
                                                   booster_water_heater_sizing[:water_heater_capacity],
                                                   water_heater_volume_m3=OpenStudio.convert(6, 'gal', 'm^3').get,
                                                   water_heater_fuel='Electricity',
                                                   booster_water_temperature_c,
                                                   parasitic_fuel_consumption_rate_w=0.0,
                                                   booster_water_heater_thermal_zone=nil)

          # Rename the service water booster loop
          swh_booster_loop.setName("#{space_type.name} Service Water Booster Loop")

          # Attach booster water use equipment to the booster loop
          booster_swh_connection = booster_water_use_equip.waterUseConnections
          swh_booster_loop.addDemandBranchForComponent(booster_swh_connection.get) if booster_swh_connection.is_initialized
        end

      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "'#{swh_system_type}' is not a valid Service Water Heating System Type, cannot add SWH to #{space_type.name}.  Valid choices are One Per Unit, Dedicated, and Shared.")
      end
    end

    # get building floor area and effective number of stories
    bldg_floor_area_m2 = model.getBuilding.floorArea
    bldg_effective_num_stories_hash = model_effective_num_stories(model)
    bldg_effective_num_stories = bldg_effective_num_stories_hash[:below_grade] + bldg_effective_num_stories_hash[:above_grade]

    # add non-dedicated system(s) here. Separate systems for water use equipment from different building types
    water_use_equipment_hash.sort.each do |stds_bldg_type, water_use_equipment_array|
      # TODO: find the water use equipment with the highest temperature
      water_heater_temp_f = 140.0
      water_heater_temp_c = OpenStudio.convert(water_heater_temp_f, 'F', 'C').get

      # find pump values
      # Table A.2 in PrototypeModelEnhancements_2014_0.pdf shows 10ft on everything except SecondarySchool which has 11.4ft
      # TODO: Remove hard-coded building-type-based lookups for circulating vs. non-circulating SWH systems
      circulating_bldg_types = [
        # DOE building types
        'Office',
        'PrimarySchool',
        'Outpatient',
        'Hospital',
        'SmallHotel',
        'LargeHotel',
        'FullServiceRestaurant',
        'HighriseApartment',
        # DEER building types
        'Asm', # 'Assembly'
        'ECC', # 'Education - Community College'
        'EPr', # 'Education - Primary School'
        'ERC', # 'Education - Relocatable Classroom'
        'ESe', # 'Education - Secondary School'
        'EUn', # 'Education - University'
        'Gro', # 'Grocery'
        'Hsp', # 'Health/Medical - Hospital'
        'Htl', # 'Lodging - Hotel'
        'MBT', # 'Manufacturing Biotech'
        'MFm', # 'Residential Multi-family'
        'Mtl', # 'Lodging - Motel'
        'Nrs', # 'Health/Medical - Nursing Home'
        'OfL', # 'Office - Large'
        # 'RFF', # 'Restaurant - Fast-Food'
        'RSD' # 'Restaurant - Sit-Down'
      ]
      if circulating_bldg_types.include?(stds_bldg_type)
        service_water_pump_head_pa = OpenStudio.convert(10.0, 'ftH_{2}O', 'Pa').get
        service_water_pump_motor_efficiency = 0.3
        circulating = true if circulating.nil?
        pipe_insul_in = 0.5 if pipe_insul_in.nil?
      else # values for non-circulating pump
        service_water_pump_head_pa = 0.01
        service_water_pump_motor_efficiency = 1.0
        circulating = false if circulating.nil?
        pipe_insul_in = 0.0 if pipe_insul_in.nil?
      end

      bldg_type_floor_area_m2 = 0.0
      space_type_hash.sort.each do |space_type, space_type_props|
        bldg_type_floor_area_m2 += space_type_props[:floor_area] if space_type_props[:stds_bldg_type] == stds_bldg_type
      end

      # Calculate the number of stories covered by this building type
      num_stories = bldg_effective_num_stories * (bldg_type_floor_area_m2 / bldg_floor_area_m2)

      # Water heater sizing
      water_heater_sizing = model_find_water_heater_capacity_volume_and_parasitic(model, water_use_equipment_array)
      water_heater_capacity_w = water_heater_sizing[:water_heater_capacity]
      water_heater_volume_m3 = water_heater_sizing[:water_heater_volume]

      # Add a shared service water heating loop with water heater
      shared_swh_loop = model_add_swh_loop(model,
                                           "#{stds_bldg_type} Shared Service Water Loop",
                                           water_heater_thermal_zone=nil,
                                           water_heater_temp_c,
                                           service_water_pump_head_pa,
                                           service_water_pump_motor_efficiency,
                                           water_heater_capacity_w,
                                           water_heater_volume_m3,
                                           water_heater_fuel,
                                           parasitic_fuel_consumption_rate_w=0,
                                           add_pipe_losses=true,
                                           floor_area_served=bldg_type_floor_area_m2,
                                           number_of_stories=num_stories,
                                           pipe_insulation_thickness=OpenStudio.convert(pipe_insul_in, 'in', 'm').get)

      # Attach all water use equipment to the shared loop
      water_use_equipment_array.sort.each do |water_use_equip|
        swh_connection = water_use_equip.waterUseConnections
        shared_swh_loop.addDemandBranchForComponent(swh_connection.get) if swh_connection.is_initialized
      end

      # add to list of systems
      swh_systems << shared_swh_loop

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Adding shared water heating loop for #{stds_bldg_type}.")
    end

    return swh_systems
  end

  # Use rules from DOE Prototype Building documentation to determine water heater capacity,
  # volume, pipe dump losses, and pipe thermal losses.
  #
  # @param water_use_equipment_array [Array] array of water use equipment objects that will be using this water heater
  # @param storage_to_cap_ratio_gal_to_kbtu_per_hr [Double] storage volume gal to kBtu/hr of capacity
  # @param htg_eff [Double] water heater thermal efficiency, fraction
  # @param inlet_temp_f [Double] inlet cold water temperature, degrees Fahrenheit
  # @param target_temp_f [Double] target supply water temperatre from the tank, degrees Fahrenheit
  # @return [Hash] hash with values needed to size water heater made with downstream method
  def model_find_water_heater_capacity_volume_and_parasitic(model,
                                                            water_use_equipment_array,
                                                            storage_to_cap_ratio_gal_to_kbtu_per_hr: 1.0,
                                                            htg_eff: 0.8,
                                                            inlet_temp_f: 40.0,
                                                            target_temp_f: 140.0,
                                                            peak_flow_fraction: 1.0)
    # A.1.4 Total Storage Volume and Water Heater Capacity of PrototypeModelEnhancements_2014_0.pdf shows 1 gallon of storage to 1 kBtu/h of capacity

    water_heater_sizing = {}

    # Get the maximum flow rates for all pieces of water use equipment
    adjusted_max_flow_rates_gal_per_hr = [] # gallons per hour
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
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "The peak flow rate fraction for #{water_use_equip_sch.name} could not be determined, assuming 1 for water heater sizing purposes.")
        max_sch_value = 1.0
      end

      # Get peak flow rate from water use equipment definition
      peak_flow_rate_m3_per_s = water_use_equip.waterUseEquipmentDefinition.peakFlowRate

      # Calculate adjusted flow rate based on the peak fraction found in the flow rate fraction schedule
      adjusted_peak_flow_rate_m3_per_s = max_sch_value * peak_flow_rate_m3_per_s
      adjusted_max_flow_rates_gal_per_hr << OpenStudio.convert(adjusted_peak_flow_rate_m3_per_s, 'm^3/s', 'gal/hr').get
    end

    # Sum gph values from water use equipment to use in formula
    total_adjusted_flow_rate_gal_per_hr = adjusted_max_flow_rates_gal_per_hr.inject(:+)

    # Calculate capacity based on analysis of combined water use equipment maximum flow rates and schedules
    # Max gal/hr * 8.4 lb/gal * 1 Btu/lb F * (120F - 40F)/0.8 = Btu/hr
    water_heater_capacity_btu_per_hr = peak_flow_fraction * total_adjusted_flow_rate_gal_per_hr * 8.4 * 1.0 * (target_temp_f - inlet_temp_f) / htg_eff
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Capacity of #{water_heater_capacity_btu_per_hr.round} Btu/hr = #{peak_flow_fraction} peak fraction * #{total_adjusted_flow_rate_gal_per_hr.round} gal/hr * 8.4 lb/gal * 1.0 Btu/lb F * (#{target_temp_f.round} - #{inlet_temp_f.round} deltaF / #{htg_eff} htg eff).")
    water_heater_capacity_m3_per_s = OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'W').get

    # Calculate volume based on capacity
    # Default assumption is 1 gal of volume per 1 kBtu/hr of heating capacity
    water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'kBtu/hr').get
    water_heater_volume_gal = water_heater_capacity_kbtu_per_hr * storage_to_cap_ratio_gal_to_kbtu_per_hr
    # increase tank size to 40 galons if calculated value is smaller
    water_heater_volume_gal = 40.0 if water_heater_volume_gal < 40.0 # gal
    water_heater_volume_m3 = OpenStudio.convert(water_heater_volume_gal, 'gal', 'm^3').get

    # Populate return hash
    water_heater_sizing[:water_heater_capacity] = water_heater_capacity_m3_per_s
    water_heater_sizing[:water_heater_volume] = water_heater_volume_m3

    return water_heater_sizing
  end
end

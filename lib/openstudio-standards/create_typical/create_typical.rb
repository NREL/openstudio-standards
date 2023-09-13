# Methods to create typical models
module OpenstudioStandards
  module CreateTypical
    # @!group CreateTypical

    # create typical building from model
    # creates a complete energy model from model with defined geometry and standards space type assignments
    #
    # @return [Boolean] returns true if successful, false if not
    def self.typical_building_from_model(model, runner, user_arguments)
      # assign the user inputs to variables
      args = OsLib_HelperMethods.createRunVariables(runner, model, user_arguments, arguments(model))
      if !args then return false end

      # lookup and replace argument values from upstream measures
      if args['use_upstream_args'] == true
        args.each do |arg, value|
          next if arg == 'use_upstream_args' # this argument should not be changed
          value_from_osw = OsLib_HelperMethods.check_upstream_measure_for_arg(runner, arg)
          if !value_from_osw.empty?
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Replacing argument named #{arg} from current measure with a value of #{value_from_osw[:value]} from #{value_from_osw[:measure_name]}.")
            new_val = value_from_osw[:value]
            # TODO: - make code to handle non strings more robust. check_upstream_measure_for_arg coudl pass bakc the argument type
            if arg == 'total_bldg_floor_area'
              args[arg] = new_val.to_f
            elsif arg == 'num_stories_above_grade'
              args[arg] = new_val.to_f
            elsif arg == 'zipcode'
              args[arg] = new_val.to_i
            else
              args[arg] = new_val
            end
          end
        end
      end

      # validate fraction parking
      fraction = OsLib_HelperMethods.checkDoubleAndIntegerArguments(runner, user_arguments, 'min' => 0.0, 'max' => 1.0, 'min_eq_bool' => true, 'max_eq_bool' => true, 'arg_array' => ['onsite_parking_fraction'])
      if !fraction then return false end

      # validate unmet hours tolerance
      unmet_hours_tolerance_valid = OsLib_HelperMethods.checkDoubleAndIntegerArguments(runner, user_arguments, 'min' => 0.0, 'max' => 5.0, 'min_eq_bool' => true, 'max_eq_bool' => true, 'arg_array' => ['unmet_hours_tolerance'])
      if !unmet_hours_tolerance_valid then return false end

      # validate weekday hours of operation
      wkdy_op_hrs_start_time_hr = nil
      wkdy_op_hrs_start_time_min = nil
      wkdy_op_hrs_duration_hr = nil
      wkdy_op_hrs_duration_min = nil
      if args['modify_wkdy_op_hrs']
        # weekday start time hr
        wkdy_op_hrs_start_time_hr = args['wkdy_op_hrs_start_time'].floor
        if wkdy_op_hrs_start_time_hr < 0 || wkdy_op_hrs_start_time_hr > 24
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Weekday operating hours start time hrs must be between 0 and 24.  #{args['wkdy_op_hrs_start_time']} was entered.")
          return false
        end

        # weekday start time min
        wkdy_op_hrs_start_time_min = (60.0 * (args['wkdy_op_hrs_start_time'] - args['wkdy_op_hrs_start_time'].floor)).floor
        if wkdy_op_hrs_start_time_min < 0 || wkdy_op_hrs_start_time_min > 59
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Weekday operating hours start time mins must be between 0 and 59.  #{args['wkdy_op_hrs_start_time']} was entered.")
          return false
        end

        # weekday duration hr
        wkdy_op_hrs_duration_hr = args['wkdy_op_hrs_duration'].floor
        if wkdy_op_hrs_duration_hr < 0 || wkdy_op_hrs_duration_hr > 24
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Weekday operating hours duration hrs must be between 0 and 24.  #{args['wkdy_op_hrs_duration']} was entered.")
          return false
        end

        # weekday duration min
        wkdy_op_hrs_duration_min = (60.0 * (args['wkdy_op_hrs_duration'] - args['wkdy_op_hrs_duration'].floor)).floor
        if wkdy_op_hrs_duration_min < 0 || wkdy_op_hrs_duration_min > 59
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Weekday operating hours duration mins must be between 0 and 59.  #{args['wkdy_op_hrs_duration']} was entered.")
          return false
        end

        # check that weekday start time plus duration does not exceed 24 hrs
        if (wkdy_op_hrs_start_time_hr + wkdy_op_hrs_duration_hr + (wkdy_op_hrs_start_time_min + wkdy_op_hrs_duration_min) / 60.0) > 24.0
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Weekday start time of #{args['wkdy_op_hrs_start']} plus duration of #{args['wkdy_op_hrs_duration']} is more than 24 hrs, hours of operation overlap midnight.")
        end
      end

      # validate weekend hours of operation
      wknd_op_hrs_start_time_hr = nil
      wknd_op_hrs_start_time_min = nil
      wknd_op_hrs_duration_hr = nil
      wknd_op_hrs_duration_min = nil
      if args['modify_wknd_op_hrs']
        # weekend start time hr
        wknd_op_hrs_start_time_hr = args['wknd_op_hrs_start_time'].floor
        if wknd_op_hrs_start_time_hr < 0 || wknd_op_hrs_start_time_hr > 24
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Weekend operating hours start time hrs must be between 0 and 24.  #{args['wknd_op_hrs_start_time_change']} was entered.")
          return false
        end

        # weekend start time min
        wknd_op_hrs_start_time_min = (60.0 * (args['wknd_op_hrs_start_time'] - args['wknd_op_hrs_start_time'].floor)).floor
        if wknd_op_hrs_start_time_min < 0 || wknd_op_hrs_start_time_min > 59
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Weekend operating hours start time mins must be between 0 and 59.  #{args['wknd_op_hrs_start_time_change']} was entered.")
          return false
        end

        # weekend duration hr
        wknd_op_hrs_duration_hr = args['wknd_op_hrs_duration'].floor
        if wknd_op_hrs_duration_hr < 0 || wknd_op_hrs_duration_hr > 24
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Weekend operating hours duration hrs must be between 0 and 24.  #{args['wknd_op_hrs_duration']} was entered.")
          return false
        end

        # weekend duration min
        wknd_op_hrs_duration_min = (60.0 * (args['wknd_op_hrs_duration'] - args['wknd_op_hrs_duration'].floor)).floor
        if wknd_op_hrs_duration_min < 0 || wknd_op_hrs_duration_min > 59
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Weekend operating hours duration min smust be between 0 and 59.  #{args['wknd_op_hrs_duration']} was entered.")
          return false
        end

        # check that weekend start time plus duration does not exceed 24 hrs
        if (wknd_op_hrs_start_time_hr + wknd_op_hrs_duration_hr + (wknd_op_hrs_start_time_min + wknd_op_hrs_duration_min) / 60.0) > 24.0
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Weekend start time of #{args['wknd_op_hrs_start']} plus duration of #{args['wknd_op_hrs_duration']} is more than 24 hrs, hours of operation overlap midnight.")
        end
      end

      # report initial condition of model
      initial_objects = model.getModelObjects.size
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "The building started with #{initial_objects} objects.")

      # open channel to log messages
      reset_log

      # Make the standard applier
      standard = Standard.build((args['template']).to_s)

      # validate climate zone
      if !args.key?('climate_zone') || args['climate_zone'] == 'Lookup From Model'
        climate_zone = standard.model_get_building_properties(model)['climate_zone']
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Using climate zone #{climate_zone} from model")
      else
        climate_zone = args['climate_zone']
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Using climate zone #{climate_zone} from user arguments")
      end
      if climate_zone == ''
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Could not determine climate zone from measure arguments or model.")
        return false
      end

      # if haystack_file used find the file
      # todo - may want to allow NA, empty string or some other value to skip so a measure can ake this optional witht using optional measure arguments
      if args['haystack_file']
        haystack_file = runner.workflow.findFile(args['haystack_file'])
        if haystack_file.is_initialized
          haystack_file = haystack_file.get.to_s

          # load JSON file
          json = nil
          File.open(haystack_file, 'r') do |file|
            json = file.read
            # uncomment to inspect haystack json
            # puts json
          end

        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Did not find #{args['haystack_file']} in paths described in OSW file.")
          return false
        end
      else
        haystack_file = nil
      end

      # make sure daylight savings is turned on up prior to any sizing runs being done.
      if args['enable_dst']
        start_date = '2nd Sunday in March'
        end_date = '1st Sunday in November'

        runperiodctrl_daylgtsaving = model.getRunPeriodControlDaylightSavingTime
        runperiodctrl_daylgtsaving.setStartDate(start_date)
        runperiodctrl_daylgtsaving.setEndDate(end_date)
      end

      # add internal loads to space types
      if args['add_space_type_loads']

        # remove internal loads
        if args['remove_objects']
          model.getSpaceLoads.sort.each do |instance|
            next if instance.name.to_s.include?('Elevator') # most prototype building types model exterior elevators with name Elevator
            next if instance.to_InternalMass.is_initialized
            next if instance.to_WaterUseEquipment.is_initialized
            instance.remove
          end
          model.getDesignSpecificationOutdoorAirs.each(&:remove)
          model.getDefaultScheduleSets.each(&:remove)
        end

        model.getSpaceTypes.sort.each do |space_type|
          # Don't add infiltration here; will be added later in the script
          test = standard.space_type_apply_internal_loads(space_type, true, true, true, true, true, false)
          if test == false
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Could not add loads for #{space_type.name}. Not expected for #{args['template']}")
            next
          end

          # apply internal load schedules
          # the last bool test it to make thermostat schedules. They are now added in HVAC section instead of here
          standard.space_type_apply_internal_load_schedules(space_type, true, true, true, true, true, true, false)

          # extend space type name to include the args['template']. Consider this as well for load defs
          space_type.setName("#{space_type.name} - #{args['template']}")
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Adding loads to space type named #{space_type.name}")
        end

        # warn if spaces in model without space type
        spaces_without_space_types = []
        model.getSpaces.sort.each do |space|
          next if space.spaceType.is_initialized
          spaces_without_space_types << space
        end
        if !spaces_without_space_types.empty?
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "#{spaces_without_space_types.size} spaces do not have space types assigned, and wont' receive internal loads from standards space type lookups.")
        end
      end

      # identify primary building type (used for construction, and ideally HVAC as well)
      building_types = {}
      model.getSpaceTypes.sort.each do |space_type|
        # populate hash of building types
        if space_type.standardsBuildingType.is_initialized
          bldg_type = space_type.standardsBuildingType.get
          if !building_types.key?(bldg_type)
            building_types[bldg_type] = space_type.floorArea
          else
            building_types[bldg_type] += space_type.floorArea
          end
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Can't identify building type for #{space_type.name}")
        end
      end
      primary_bldg_type = building_types.key(building_types.values.max) # TODO: - this fails if no space types, or maybe just no space types with standards
      lookup_building_type = standard.model_get_lookup_name(primary_bldg_type) # Used for some lookups in the standards gem
      model.getBuilding.setStandardsBuildingType(primary_bldg_type)

      # make construction set and apply to building
      if args['add_constructions']

        # remove default construction sets
        if args['remove_objects']
          model.getDefaultConstructionSets.each(&:remove)
        end

        # TODO: - allow building type and space type specific constructions set selection.
        if ['SmallHotel', 'LargeHotel', 'MidriseApartment', 'HighriseApartment'].include?(primary_bldg_type)
          is_residential = 'Yes'
          occ_type = 'Residential'
        else
          is_residential = 'No'
          occ_type = 'Nonresidential'
        end
        bldg_def_const_set = standard.model_add_construction_set(model, climate_zone, lookup_building_type, nil, is_residential)
        if bldg_def_const_set.is_initialized
          bldg_def_const_set = bldg_def_const_set.get
          if is_residential then bldg_def_const_set.setName("Res #{bldg_def_const_set.name}") end
          model.getBuilding.setDefaultConstructionSet(bldg_def_const_set)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Adding default construction set named #{bldg_def_const_set.name}")
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "Could not create default construction set for the building type #{lookup_building_type} in climate zone #{climate_zone}.")
          log_messages_to_runner(runner, debug = true)
          return false
        end

        # Replace the construction of any outdoor-facing "AtticFloor" surfaces
        # with the "ExteriorRoof" - "IEAD" construction for the specific climate zone and template.
        # This prevents creation of buildings where the DOE Prototype building construction set
        # assumes an attic but the supplied geometry used does not have an attic.
        new_construction = nil
        climate_zone_set = standard.model_find_climate_zone_set(model, climate_zone)
        model.getSurfaces.sort.each do |surf|
          next unless surf.outsideBoundaryCondition == 'Outdoors'
          next unless surf.surfaceType == 'RoofCeiling'
          next if surf.construction.empty?
          construction = surf.construction.get
          standards_info = construction.standardsInformation
          next if standards_info.intendedSurfaceType.empty?
          next unless standards_info.intendedSurfaceType.get == 'AtticFloor'
          if new_construction.nil?
            new_construction = standard.model_find_and_add_construction(model,
                                                                        climate_zone_set,
                                                                        'ExteriorRoof',
                                                                        'IEAD',
                                                                        occ_type)
          end
          surf.setConstruction(new_construction)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Changed the construction for #{surf.name} from #{construction.name} to #{new_construction.name} to avoid outdoor-facing attic floor constructions in buildings with no attic space.")
        end

        # address any adiabatic surfaces that don't have hard assigned constructions
        model.getSurfaces.sort.each do |surface|
          next if surface.outsideBoundaryCondition != 'Adiabatic'
          next if surface.construction.is_initialized
          surface.setAdjacentSurface(surface)
          surface.setConstruction(surface.construction.get)
          surface.setOutsideBoundaryCondition('Adiabatic')
        end

        # modify the infiltration rates
        if args['remove_objects']
          model.getSpaceInfiltrationDesignFlowRates.each(&:remove)
        end
        standard.model_apply_infiltration_standard(model)
        standard.model_modify_infiltration_coefficients(model, primary_bldg_type, climate_zone)

        # set ground temperatures from DOE prototype buildings
        standard.model_add_ground_temperatures(model, primary_bldg_type, climate_zone)

      end

      # add elevators (returns ElectricEquipment object)
      if args['add_elevators']

        # remove elevators as spaceLoads or exteriorLights
        model.getSpaceLoads.sort.each do |instance|
          next if !instance.name.to_s.include?('Elevator') # most prototype building types model exterior elevators with name Elevator
          instance.remove
        end
        model.getExteriorLightss.sort.each do |ext_light|
          next if !ext_light.name.to_s.include?('Fuel equipment') # some prototype building types model exterior elevators by this name
          ext_light.remove
        end

        elevators = standard.model_add_elevators(model)
        if elevators.nil?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', 'No elevators added to the building.')
        else
          elevator_def = elevators.electricEquipmentDefinition
          design_level = elevator_def.designLevel.get
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Adding #{elevators.multiplier.round(1)} elevators each with power of #{OpenStudio.toNeatString(design_level, 0, true)} (W), plus lights and fans.")
          elevator_def.setFractionLatent(0.0)
          elevator_def.setFractionRadiant(0.0)
          elevator_def.setFractionLost(1.0)
        end
      end

      # add exterior lights (returns a hash where key is lighting type and value is exteriorLights object)
      if args['add_exterior_lights']

        if args['remove_objects']
          model.getExteriorLightss.sort.each do |ext_light|
            next if ext_light.name.to_s.include?('Fuel equipment') # some prototype building types model exterior elevators by this name
            ext_light.remove
          end
        end

        exterior_lights = standard.model_add_typical_exterior_lights(model, args['exterior_lighting_zone'].chars[0].to_i, args['onsite_parking_fraction'])
        exterior_lights.each do |k, v|
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Adding Exterior Lights named #{v.exteriorLightsDefinition.name} with design level of #{v.exteriorLightsDefinition.designLevel} * #{OpenStudio.toNeatString(v.multiplier, 0, true)}.")
        end
      end

      # add_exhaust
      if args['add_exhaust']

        # remove exhaust objects
        if args['remove_objects']
          model.getFanZoneExhausts.each(&:remove)
        end

        zone_exhaust_fans = standard.model_add_exhaust(model, args['kitchen_makeup']) # second argument is strategy for finding makeup zones for exhaust zones
        zone_exhaust_fans.each do |k, v|
          max_flow_rate_ip = OpenStudio.convert(k.maximumFlowRate.get, 'm^3/s', 'cfm').get
          if v.key?(:zone_mixing)
            zone_mixing = v[:zone_mixing]
            mixing_source_zone_name = zone_mixing.sourceZone.get.name
            mixing_design_flow_rate_ip = OpenStudio.convert(zone_mixing.designFlowRate.get, 'm^3/s', 'cfm').get
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Adding #{OpenStudio.toNeatString(max_flow_rate_ip, 0, true)} (cfm) of exhaust to #{k.thermalZone.get.name}, with #{OpenStudio.toNeatString(mixing_design_flow_rate_ip, 0, true)} (cfm) of makeup air from #{mixing_source_zone_name}")
          else
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Adding #{OpenStudio.toNeatString(max_flow_rate_ip, 0, true)} (cfm) of exhaust to #{k.thermalZone.get.name}")
          end
        end
      end

      # add service water heating demand and supply
      if args['add_swh']

        # remove water use equipment and water use connections
        if args['remove_objects']
          # TODO: - remove plant loops used for service water heating
          model.getWaterUseEquipments.each(&:remove)
          model.getWaterUseConnectionss.each(&:remove)
        end

        # Infer the SWH type
        if args['swh_src'] == 'Inferred'
          if args['htg_src'] == 'NaturalGas' || args['htg_src'] == 'DistrictHeating'
            args['swh_src'] = 'NaturalGas' # If building has gas service, probably uses natural gas for SWH
          elsif args['htg_src'] == 'Electricity'
            args['swh_src'] = 'Electricity' # If building is doing space heating with electricity, probably used for SWH
          elsif args['htg_src'] == 'DistrictAmbient'
            args['swh_src'] = 'HeatPump' # If building has district ambient loop, it is fancy and probably uses HPs for SWH
          else
            args['swh_src'] = nil # Use inferences built into OpenStudio Standards for each building and space type
          end
        end

        typical_swh = standard.model_add_typical_swh(model, water_heater_fuel: args['swh_src'])
        midrise_swh_loops = []
        stripmall_swh_loops = []
        typical_swh.each do |loop|
          if loop.name.get.include?('MidriseApartment')
            midrise_swh_loops << loop
          elsif loop.name.get.include?('RetailStripmall')
            stripmall_swh_loops << loop
          else
            water_use_connections = []
            loop.demandComponents.each do |component|
              next if !component.to_WaterUseConnections.is_initialized
              water_use_connections << component
            end
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Adding #{loop.name} to the building. It has #{water_use_connections.size} water use connections.")
          end
        end
        if !midrise_swh_loops.empty?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Adding #{midrise_swh_loops.size} MidriseApartment service water heating loops.")
        end
        if !stripmall_swh_loops.empty?
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Adding #{stripmall_swh_loops.size} RetailStripmall service water heating loops.")
        end
      end

      # add_daylighting_controls (since outdated measure don't have this default to true if arg not found)
      if !args.has_key?('add_daylighting_controls')
        args['add_daylighting_controls'] = true
      end
      if args['add_daylighting_controls']
        # remove add_daylighting_controls objects
        if args['remove_objects']
          model.getDaylightingControls.each(&:remove)
        end

        # add daylight controls, need to perform a sizing run for 2010
        if args['template'] == '90.1-2010' || args['template'] == 'ComStock 90.1-2010'
          if standard.model_run_sizing_run(model, "#{Dir.pwd}/SRvt") == false
            log_messages_to_runner(runner, debug = true)
            return false
          end
        end
        standard.model_add_daylighting_controls(model)
      end

      # add refrigeration
      if args['add_refrigeration']

        # remove refrigeration equipment
        if args['remove_objects']
          model.getRefrigerationSystems.each(&:remove)
        end

        # Add refrigerated cases and walkins
        standard.model_add_typical_refrigeration(model, primary_bldg_type)
      end

      # add internal mass
      if args['add_internal_mass']

        if args['remove_objects']
          model.getSpaceLoads.sort.each do |instance|
            next unless instance.to_InternalMass.is_initialized
            instance.remove
          end
        end

        # add internal mass to conditioned spaces; needs to happen after thermostats are applied
        standard.model_add_internal_mass(model, primary_bldg_type)
      end

      # TODO: - add slab modeling and slab insulation

      # TODO: - fuel customization for cooking and laundry
      # works by switching some fraction of electric loads to gas if requested (assuming base load is electric)

      # add thermostats
      if args['add_thermostat']

        # remove thermostats
        if args['remove_objects']
          model.getThermostatSetpointDualSetpoints.each(&:remove)
        end

        model.getSpaceTypes.sort.each do |space_type|
          # create thermostat schedules
          # skip un-recognized space types
          next if standard.space_type_get_standards_data(space_type).empty?
          # the last bool test it to make thermostat schedules. They are added to the model but not assigned
          standard.space_type_apply_internal_load_schedules(space_type, false, false, false, false, false, false, true)

          # identify thermal thermostat and apply to zones (apply_internal_load_schedules names )
          model.getThermostatSetpointDualSetpoints.sort.each do |thermostat|
            next if thermostat.name.to_s != "#{space_type.name} Thermostat"
            next if !thermostat.coolingSetpointTemperatureSchedule.is_initialized
            next if !thermostat.heatingSetpointTemperatureSchedule.is_initialized
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Assigning #{thermostat.name} to thermal zones with #{space_type.name} assigned.")
            space_type.spaces.sort.each do |space|
              next if !space.thermalZone.is_initialized
              space.thermalZone.get.setThermostatSetpointDualSetpoint(thermostat)
            end
          end
        end
      end

      # add hvac system
      if args['add_hvac']

        # remove HVAC objects
        if args['remove_objects']
          standard.model_remove_prm_hvac(model)
        end

        case args['system_type']
        when 'Inferred'

          # Get the hvac delivery type enum
          hvac_delivery = case args['hvac_delivery_type']
                          when 'Forced Air'
                            'air'
                          when 'Hydronic'
                            'hydronic'
                          end

          # Group the zones by occupancy type.  Only split out non-dominant groups if their total area exceeds the limit.
          sys_groups = standard.model_group_zones_by_type(model, OpenStudio.convert(20_000, 'ft^2', 'm^2').get)

          # For each group, infer the HVAC system type.
          sys_groups.each do |sys_group|
            # Infer the primary system type
            # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "template = #{args['template']}, climate_zone = #{climate_zone}, occ_type = #{sys_group['type']}, hvac_delivery = #{hvac_delivery}, htg_src = #{args['htg_src']}, clg_src = #{args['clg_src']}, area_ft2 = #{sys_group['area_ft2']}, num_stories = #{sys_group['stories']}")
            sys_type, central_htg_fuel, zone_htg_fuel, clg_fuel = standard.model_typical_hvac_system_type(model,
                                                                                                          climate_zone,
                                                                                                          sys_group['type'],
                                                                                                          hvac_delivery,
                                                                                                          args['htg_src'],
                                                                                                          args['clg_src'],
                                                                                                          OpenStudio.convert(sys_group['area_ft2'], 'ft^2', 'm^2').get,
                                                                                                          sys_group['stories'])

            # Infer the secondary system type for multizone systems
            sec_sys_type = case sys_type
                          when 'PVAV Reheat', 'VAV Reheat'
                            'PSZ-AC'
                          when 'PVAV PFP Boxes', 'VAV PFP Boxes'
                            'PSZ-HP'
                          else
                            sys_type # same as primary system type
                          end

            # group zones
            if haystack_file.nil?
              # Group zones by story
              bldg_zone_lists = standard.model_group_zones_by_story(model, sys_group['zones'])
            else
              # todo - group zones using haystack file instead of building stories
              # todo - need to do something similar to use haystack to indentify secondary zones
              bldg_zone_lists = standard.model_group_zones_by_story(model, sys_group['zones'])
              OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "***This code will define which zones are on air loops for inferred system***")
            end

            # On each story, add the primary system to the primary zones
            # and add the secondary system to any zones that are different.
            bldg_zone_lists.each do |story_group|
              # Differentiate primary and secondary zones, based on
              # operating hours and internal loads (same as 90.1 PRM)
              pri_sec_zone_lists = standard.model_differentiate_primary_secondary_thermal_zones(model, story_group)
              system_zones = pri_sec_zone_lists['primary']

              # if the primary system type is PTAC, filter to cooled zones to prevent sizing error if no cooling
              if sys_type == 'PTAC'
                heated_and_cooled_zones = system_zones.select { |zone| standard.thermal_zone_heated?(zone) && standard.thermal_zone_cooled?(zone) }
                cooled_only_zones = system_zones.select { |zone| !standard.thermal_zone_heated?(zone) && standard.thermal_zone_cooled?(zone) }
                system_zones = heated_and_cooled_zones + cooled_only_zones
              end

              # Add the primary system to the primary zones
              unless standard.model_add_hvac_system(model, sys_type, central_htg_fuel, zone_htg_fuel, clg_fuel, system_zones)
                OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "HVAC system type '#{sys_type}' not recognized. Check input system type argument against Model.hvac.rb for valid hvac system type names.")
                return false
              end

              # Add the secondary system to the secondary zones (if any)
              if !pri_sec_zone_lists['secondary'].empty?
                system_zones = pri_sec_zone_lists['secondary']
                if (sec_sys_type == 'PTAC') || (sec_sys_type == 'PSZ-AC')
                  heated_and_cooled_zones = system_zones.select { |zone| standard.thermal_zone_heated?(zone) && standard.thermal_zone_cooled?(zone) }
                  cooled_only_zones = system_zones.select { |zone| !standard.thermal_zone_heated?(zone) && standard.thermal_zone_cooled?(zone) }
                  system_zones = heated_and_cooled_zones + cooled_only_zones
                end
                unless standard.model_add_hvac_system(model, sec_sys_type, central_htg_fuel, zone_htg_fuel, clg_fuel, system_zones)
                  OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "HVAC system type '#{sys_type}' not recognized. Check input system type argument against Model.hvac.rb for valid hvac system type names.")
                  return false
                end
              end
            end
          end

        else # HVAC system_type specified

          # Group the zones by occupancy type.  Only split out non-dominant groups if their total area exceeds the limit.
          sys_groups = standard.model_group_zones_by_type(model, OpenStudio.convert(20_000, 'ft^2', 'm^2').get)
          sys_groups.each do |sys_group|

            # group zones
            if haystack_file.nil?
              # Group zones by story
              bldg_zone_groups = standard.model_group_zones_by_story(model, sys_group['zones'])
            else
              # todo - group zones using haystack file instead of building stories
              # todo - need to do something similar to use haystack to indentify secondary zones
              bldg_zone_groups = standard.model_group_zones_by_story(model, sys_group['zones'])
              OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "***This code will define which zones are on air loops for user specified system***")
            end

            # Add the user specified HVAC system for each story.
            # Single-zone systems will get one per zone.
            bldg_zone_groups.each do |zones|
              unless model.add_cbecs_hvac_system(standard, args['system_type'], zones)
                OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "HVAC system type '#{args['system_type']}' not recognized. Check input system type argument against Model.hvac.rb for valid hvac system type names.")
                return false
              end
            end
          end
        end
      end

      # hours of operation
      if args['modify_wkdy_op_hrs'] || args['modify_wknd_op_hrs']
        # Infer the current hours of operation schedule for the building
        op_sch = standard.model_infer_hours_of_operation_building(model)

        # setup hoo_var_method (should be hours or fractional)
        if args.has_key?('hoo_var_method')
          hoo_var_method = args['hoo_var_method']
        else
          # support measures that don't supply this argument
          hoo_var_method = 'hours'
        end

        # Convert existing schedules in the model to parametric schedules based on current hours of operation
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Generating parametric schedules from ruleset schedules using #{hoo_var_method} variable method for hours of operation fromula.")
        standard.model_setup_parametric_schedules(model, hoo_var_method: hoo_var_method)

        # Create start and end times from start time and duration supplied
        wkdy_start_time = nil
        wkdy_end_time = nil
        wknd_start_time = nil
        wknd_end_time = nil
        # weekdays
        if args['modify_wkdy_op_hrs']
          wkdy_start_time = OpenStudio::Time.new(0, wkdy_op_hrs_start_time_hr, wkdy_op_hrs_start_time_min, 0)
          wkdy_end_time = wkdy_start_time + OpenStudio::Time.new(0, wkdy_op_hrs_duration_hr, wkdy_op_hrs_duration_min, 0)
        end
        # weekends
        if args['modify_wknd_op_hrs']
          wknd_start_time = OpenStudio::Time.new(0, wknd_op_hrs_start_time_hr, wknd_op_hrs_start_time_min, 0)
          wknd_end_time = wknd_start_time + OpenStudio::Time.new(0, wknd_op_hrs_duration_hr, wknd_op_hrs_duration_min, 0)
        end

        # Modify hours of operation, using weekdays values for all weekdays and weekend values for Saturday and Sunday
        standard.schedule_ruleset_set_hours_of_operation(op_sch,
                                                        wkdy_start_time: wkdy_start_time,
                                                        wkdy_end_time: wkdy_end_time,
                                                        sat_start_time: wknd_start_time,
                                                        sat_end_time: wknd_end_time,
                                                        sun_start_time: wknd_start_time,
                                                        sun_end_time: wknd_end_time)

        # Apply new operating hours to parametric schedules to make schedules in model reflect modified hours of operation
        parametric_schedules = standard.model_apply_parametric_schedules(model, error_on_out_of_order: false)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Updated #{parametric_schedules.size} schedules with new hours of operation.")
      end

      # set hvac controls and efficiencies (this should be last model articulation element)
      if args['add_hvac']
        # set additional properties for building
        props = model.getBuilding.additionalProperties
        props.setFeature('hvac_system_type', (args['system_type']).to_s)

        case args['system_type']
        when 'Ideal Air Loads'

        else
          # Set the heating and cooling sizing parameters
          standard.model_apply_prm_sizing_parameters(model)

          # Perform a sizing run
          if standard.model_run_sizing_run(model, "#{Dir.pwd}/SR1") == false
            log_messages_to_runner(runner, debug = true)
            return false
          end

          # If there are any multizone systems, reset damper positions
          # to achieve a 60% ventilation effectiveness minimum for the system
          # following the ventilation rate procedure from 62.1
          standard.model_apply_multizone_vav_outdoor_air_sizing(model)

          # Apply the prototype HVAC assumptions
          standard.model_apply_prototype_hvac_assumptions(model, primary_bldg_type, climate_zone)

          # Apply the HVAC efficiency standard
          standard.model_apply_hvac_efficiency_standard(model, climate_zone)
        end
      end

      # add internal mass
      if args['add_internal_mass']

        if args['remove_objects']
          model.getSpaceLoads.sort.each do |instance|
            next unless instance.to_InternalMass.is_initialized
            instance.remove
          end
        end

        # add internal mass to conditioned spaces; needs to happen after thermostats are applied
        standard.model_add_internal_mass(model, primary_bldg_type)
      end

      # set unmet hours tolerance
      unmet_hrs_tol_r = args['unmet_hours_tolerance']
      unmet_hrs_tol_k = OpenStudio.convert(unmet_hrs_tol_r, 'R', 'K').get
      tolerances = model.getOutputControlReportingTolerances
      tolerances.setToleranceforTimeHeatingSetpointNotMet(unmet_hrs_tol_k)
      tolerances.setToleranceforTimeCoolingSetpointNotMet(unmet_hrs_tol_k)

      # remove everything but spaces, zones, and stub space types (extend as needed for additional objects, may make bool arg for this)
      if args['remove_objects']
        model.purgeUnusedResourceObjects
        objects_after_cleanup = initial_objects - model.getModelObjects.size
        if objects_after_cleanup > 0
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Removing #{objects_after_cleanup} objects from model")
        end
      end

      # change night cycling control to "Thermostat" cycling and increase thermostat tolerance to 1.99999
      manager_night_cycles = model.getAvailabilityManagerNightCycles
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Changing thermostat tollerance to 1.99999 for #{manager_night_cycles.size} night cycle manager objects.")

      manager_night_cycles.each do |night_cycle|
        night_cycle.setThermostatTolerance(1.9999)
        night_cycle.setCyclingRunTimeControlType("Thermostat")
      end

      # report final condition of model
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "The building finished with #{model.getModelObjects.size} objects.")

      # log messages to info messages
      log_messages_to_runner(runner, debug = false)

      return true
    end

    # creates spaces types and construction objects in the model for the given
    # building type, template, and climate zone
    #
    # @param building_type [String] standard building type
    # @param template [String] standard template
    # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
    # @param create_space_types [Boolean] Create space types 
    # @param create_construction_set [Boolean] Create the construction set
    # @param set_building_defaults [Boolean] Set the climate zone, newly generated construction set,
    #   and first newly generated space type as the building default
    # @return [Boolean] returns true if successful, false if not
    def self.create_space_types_and_constructions(model,
                                                  building_type,
                                                  template,
                                                  climate_zone,
                                                  create_space_types: true,
                                                  create_construction_set: true,
                                                  set_building_defaults: true)
      # reporting initial condition of model
      starting_spaceTypes = model.getSpaceTypes.sort
      starting_constructionSets = model.getDefaultConstructionSets.sort
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "The building started with #{starting_spaceTypes.size} space types and #{starting_constructionSets.size} construction sets.")

      # lookup space types for specified building type (false indicates not to use whole building type only)
      space_type_hash = get_space_types_from_building_type(building_type, template, false)
      if space_type_hash == false
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', "#{building_type} is an unexpected building type.")
        return false
      end

      # create space_type_map from array
      space_type_map = {}
      default_space_type_name = nil
      space_type_hash.each do |space_type_name, hash|
        next if hash[:space_type_gen] == false # space types like undeveloped and basement are skipped.
        space_type_map[space_type_name] = [] # no spaces to pass in
        if hash[:default]
          default_space_type_name = space_type_name
        end
      end

      # Make the standard applier
      standard = Standard.build(template)

      # mapping building_type name is needed for a few methods
      lookup_building_type = standard.model_get_lookup_name(building_type)

      # get array of new space types
      space_types_new = []

      # create_space_types
      if create_space_types

        # array of starting space types
        space_types_starting = model.getSpaceTypes.sort

        # create stub space types
        space_type_hash.each do |space_type_name, hash|
          next if hash[:space_type_gen] == false # space types like undeveloped and basement are skipped.

          # create space type
          space_type = OpenStudio::Model::SpaceType.new(model)
          space_type.setStandardsBuildingType(lookup_building_type)
          space_type.setStandardsSpaceType(space_type_name)
          space_type.setName("#{lookup_building_type} #{space_type_name}")

          # add to array of new space types
          space_types_new << space_type

          # add internal loads (the nil check isn't necessary, but I will keep it in as a warning instad of an error)
          test = standard.space_type_apply_internal_loads(space_type, true, true, true, true, true, true)
          if test.nil?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CreateTypical', "Could not add loads for #{space_type.name}. Not expected for #{template} #{lookup_building_type}")
          end

          # the last bool test it to make thermostat schedules. They are added to the model but not assigned
          standard.space_type_apply_internal_load_schedules(space_type, true, true, true, true, true, true, true)

          # assign colors
          standard.space_type_apply_rendering_color(space_type)

          # exend space type name to include the template. Consider this as well for load defs
          space_type.setName("#{space_type.name} - #{template}")
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Added space type named #{space_type.name}")
        end

      end

      # add construction sets
      bldg_def_const_set = nil
      if create_construction_set

        # Make the default construction set for the building
        is_residential = 'No' # default is nonresidential for building level
        bldg_def_const_set = standard.model_add_construction_set(model, climate_zone, lookup_building_type, nil, is_residential)
        if bldg_def_const_set.is_initialized
          bldg_def_const_set = bldg_def_const_set.get
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Added default construction set named #{bldg_def_const_set.name}")
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', 'Could not create default construction set for the building.')
          return false
        end

        # make residential construction set as unused resource
        if ['SmallHotel', 'LargeHotel', 'MidriseApartment', 'HighriseApartment'].include?(building_type)
          res_const_set = standard.model_add_construction_set(model, climate_zone, lookup_building_type, nil, 'Yes')
          if res_const_set.is_initialized
            res_const_set = res_const_set.get
            res_const_set.setName("#{bldg_def_const_set.name} - Residential ")
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Added residential construction set named #{res_const_set.name}")
          else
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CreateTypical', 'Could not create residential construction set for the building.')
            return false
          end
        end

      end

      # set_building_defaults
      if set_building_defaults

        # identify default space type
        space_type_standards_info_hash = OsLib_HelperMethods.getSpaceTypeStandardsInformation(space_types_new)
        default_space_type = nil
        space_type_standards_info_hash.each do |space_type, standards_array|
          standards_space_type = standards_array[1]
          if default_space_type_name == standards_space_type
            default_space_type = space_type
          end
        end

        # set default space type
        building = model.getBuilding
        if !default_space_type.nil?
          building.setSpaceType(default_space_type)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Setting default Space Type for building to #{building.spaceType.get.name}")
        end

        # default construction
        if !bldg_def_const_set.nil?
          building.setDefaultConstructionSet(bldg_def_const_set)
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Setting default Construction Set for building to #{building.defaultConstructionSet.get.name}")
        end

        # set climate zone
        os_climate_zone = climate_zone.gsub('ASHRAE 169-2013-', '')
        # trim off letter from climate zone 7 or 8
        if (os_climate_zone[0] == '7') || (os_climate_zone[0] == '8')
          os_climate_zone = os_climate_zone[0]
        end
        climate_zone = model.getClimateZones.setClimateZone('ASHRAE', os_climate_zone)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Setting #{climate_zone.institution} Climate Zone to #{climate_zone.value}")

        # set building type
        # use lookup_building_type so spaces like MediumOffice will map to Office (Supports baseline automation)
        building.setStandardsBuildingType(lookup_building_type)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Setting Standards Building Type to #{building.standardsBuildingType}")

        # rename building if it is named "Building 1"
        if model.getBuilding.name.to_s == 'Building 1'
          model.getBuilding.setName("#{building_type} #{template} #{os_climate_zone}")
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "Renaming building to #{model.getBuilding.name}")
        end

      end

      # reporting final condition of model
      finishing_spaceTypes = model.getSpaceTypes.sort
      finishing_constructionSets = model.getDefaultConstructionSets.sort
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CreateTypical', "The building finished with #{finishing_spaceTypes.size} space types and #{finishing_constructionSets.size} construction sets.")

      return true
    end
  end
end
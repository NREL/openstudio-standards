class ACM179dASHRAE9012007
  def __model_get_primary_building_type(model)
    building_types = {}

    building = model.getBuilding
    building_level_bt = nil
    if building.standardsBuildingType.is_initialized
      building_level_bt = building.standardsBuildingType.get
      # Turns "SmallOffice" in "Office"
      building_level_bt = model_get_lookup_name(building_level_bt)
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "found Building level standardsBuildingType = '#{building_level_bt}'")
    end

    model.getSpaceTypes.sort.each do |space_type|
      # populate hash of building types
      if !space_type.standardsBuildingType.is_initialized
        next
      end

      bldg_type_ori = space_type.standardsBuildingType.get
      # Turns "SmallOffice" in "Office". To ensure we aggregate properly
      bldg_type = model_get_lookup_name(bldg_type_ori)
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "found building type for Space Type '#{space_type.name}' = '#{bldg_type}'")
      if bldg_type_ori != bldg_type
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Model', "Space Type '#{space_type.name}' has actual Building Type '#{bldg_type_ori}' but sanitizing as '#{bldg_type}' for aggregation")
      end
      if building_types.key?(bldg_type)
        building_types[bldg_type] += space_type.floorArea
      else
        building_types[bldg_type] = space_type.floorArea
      end
    end

    if building_types.empty?
      if building_level_bt.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Cannot identify a single building type in model, none of your #{model.getSpaceTypes.size} SpaceTypes have a standardsBuildingType assigned and neither does the Building")
        raise 'No Primary Building Type found'
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "No area determination based on space types found, using Building level standardsBuildingType = '#{building_level_bt}'")
        return building_level_bt
      end
    end

    space_type_level_bt = building_types.max_by { |_, v| v }.first
    if !building_level_bt.nil?
      if building_level_bt != space_type_level_bt
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Model', "The Building has standardsBuildingType '#{building_level_bt}' while the area determination based on space types has '#{space_type_level_bt}'. Preferring the Space Type one")
      end
      return space_type_level_bt
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Building doesn't have a standardsBuildingType, using the area determination based on space types = '#{space_type_level_bt}'")
    return space_type_level_bt
  end

  # This starts by always using model_get_lookup_name to sanitize the names
  # Meaning 'RetailStripmall' is changed to 'StripMall' for eg
  # If remap_office is false, even if you have 'SmallOffice' it returns
  # 'Office'
  # It remap_office is true, it returns 'SmallOffice', 'MediumOffice' or 'LargeOffice'
  def model_get_primary_building_type(model, remap_office: false, remap_retail: false)
    # Maybe this is a premature optimization, but memoize the computation
    @primary_building_types_memoized ||= {}
    # TODO: this will work if you pass the same model. But if you do sp.model
    # then it changes everytime. Need to figure out a way to check if it points
    # to the same model or not, or remove the memoization
    @primary_building_types_memoized[model] ||= __model_get_primary_building_type(model)

    building_type = @primary_building_types_memoized[model]
    if remap_office && building_type == 'Office'
      floor_area_m2 = model.getBuilding.floorArea
      building_type = model_remap_office(model, floor_area_m2)
    end
    if remap_retail
      if building_type == 'StripMall'
        return 'RetailStripmall'
      elsif building_type == 'Retail'
        return 'RetailStandalone'
      end
    end
    return building_type
  end

  # **NOTE**: Patched to check also number of floors
  # remap office to one of the prototype buildings
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param floor_area [Double] floor area (m^2)
  # @return [String] SmallOffice, MediumOffice, LargeOffice
  def model_remap_office(model, floor_area)
    floor_area_sqft = OpenStudio.convert(floor_area, 'm^2', 'ft^2').get
    num_floors = model.getBuilding.buildingStories.size
    if floor_area_sqft < 25_000
      if num_floors <= 3
        return 'SmallOffice'
      else
        return 'MediumOffice'
      end
    elsif floor_area_sqft < 150_000
      if num_floors <= 5
        return 'MediumOffice'
      else
        return 'LargeOffice'
      end
    else
      return 'LargeOffice'
    end
  end

  # Patched to prefer the space area method above instead of just relying on
  # Building object
  def model_get_building_properties(model, remap_office = true)
    # get climate zone from model
    climate_zone = model_standards_climate_zone(model)

    # get building type from model
    building_type = model_get_primary_building_type(model, remap_office: remap_office)

    # get standards template
    if model.getBuilding.standardsTemplate.is_initialized
      standards_template = model.getBuilding.standardsTemplate.get
    end

    results = {}
    results['climate_zone'] = climate_zone
    results['building_type'] = building_type
    results['standards_template'] = standards_template

    return results
  end

  def model_prm_baseline_system_number(_model, _climate_zone, area_type, _fuel_type, area_ft2, num_stories, custom)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.prm', '179d: Heat Storage area applied as 90.1-2007 with addenda dn')
    sys_num = nil

    # Set the area limit
    limit_ft2 = 25_000

    # Customization for Xcel EDA.
    # No special retail category
    # for regular 90.1-2010.
    if custom != 'Xcel Energy CO EDA' && (area_type == 'retail')
      area_type = 'nonresidential'
    end

    case area_type
    when 'residential'
      sys_num = '1_or_2'
    when 'nonresidential'
      # nonresidential and 3 floors or less and <25,000 ft2
      if num_stories <= 3 && area_ft2 < limit_ft2
        sys_num = '3_or_4'
      # nonresidential and 4 or 5 floors or 5 floors or less and 25,000 ft2 to 150,000 ft2
      elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < limit_ft2) || (num_stories <= 5 && (area_ft2 >= limit_ft2 && area_ft2 <= 150_000))
        sys_num = '5_or_6'
      # nonresidential and more than 5 floors or >150,000 ft2
      elsif num_stories >= 5 || area_ft2 > 150_000
        sys_num = '7_or_8'
      end
    when 'heatedonly'
      sys_num = '9_or_10'
    when 'retail'
      # Should only be hit by Xcel EDA
      sys_num = '3_or_4'
    end

    return sys_num
  end

  # Returns standards data for selected model
  # This will check the building primary type instead
  #
  # @param model [OpenStudio::Model::Model] the model
  # @return [hash] hash of internal loads for different load types
  def model_get_standards_data(model, throw_if_not_found: false)
    # This returns 'Office' for eg
    standards_building_type = model_get_primary_building_type(model, remap_office: false)

    # populate search hash
    search_criteria = {
      'template' => template,
      'building_type' => standards_building_type,
      'space_type' => whole_building_space_type_name(model, standards_building_type)
    }

    # lookup space type properties
    space_type_properties = model_find_object(standards_data['space_types'], search_criteria)

    if space_type_properties.nil?
      msg = "Space type properties lookup failed: #{search_criteria}."
      if throw_if_not_found
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.SpaceType', msg)
        raise msg
      end
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.SpaceType', msg)
      space_type_properties = {}
    end

    return space_type_properties
  end

  HVAC_AVAILABILITY_SCHEDULE_MAP = {
    # This is a map of HVAC Type to An array of methods
    # Type => [[:getter, :setter], [:getter, :setter]]
    'AirLoopHVAC' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACBaseboardConvectiveElectric' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACBaseboardConvectiveWater' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACBaseboardRadiantConvectiveElectric' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACBaseboardRadiantConvectiveWater' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACCoolingPanelRadiantConvectiveWater' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACDehumidifierDX' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACEnergyRecoveryVentilator' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACFourPipeFanCoil' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACHighTemperatureRadiant' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACIdealLoadsAirSystem' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACLowTemperatureRadiantElectric' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACLowTempRadiantConstFlow' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACLowTempRadiantVarFlow' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACPackagedTerminalAirConditioner' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACPackagedTerminalHeatPump' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACUnitHeater' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACUnitVentilator' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'ZoneHVACWaterToAirHeatPump' => [[:availabilitySchedule, :setAvailabilitySchedule]],
    'AirLoopHVACUnitarySystem' => [
      # TODO
      # [:availabilitySchedule, :setAvailabilitySchedule],
      [:supplyAirFanOperatingModeSchedule, :setSupplyAirFanOperatingModeSchedule]
    ]
  }.freeze

  def model_apply_acm_hvac_availability_schedule(model)
    data = model_get_standards_data(model, throw_if_not_found: true)
    acm_fan_sch_name = data['hvac_operation_schedule']
    acm_fan_sch = nil

    count_availability = 0
    HVAC_AVAILABILITY_SCHEDULE_MAP.each do |hvac_type, methods|
      objects = model.send("get#{hvac_type}s")
      next if objects.empty?

      if acm_fan_sch.nil?
        acm_fan_sch = model_add_schedule(model, acm_fan_sch_name)
        model.getBuilding.additionalProperties.setFeature('acm_fan_sch', acm_fan_sch_name)
      end

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model_apply_acm_hvac_availability_schedule', "HVAC - found #{objects.size} #{hvac_type} object(s)")
      objects.each do |obj|
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model_apply_acm_hvac_availability_schedule', "HVAC - overriding availability schedule in '#{obj.nameString}' to #{acm_fan_sch.nameString}")
        methods.each do |_getter, setter|
          raise "HVAC_AVAILABILITY_SCHEDULE_MAP is out of date, #{obj.briefDescription} does not respond to #{setter}" unless obj.respond_to?(setter)

          ret = obj.send(setter, acm_fan_sch)
          if !ret
            OpenStudio.logFree(OpenStudio::Warning, 'openstudio.model_apply_acm_hvac_availability_schedule', "Failed to apply availability schedule via #{setter} for #{obj.briefDescription}")
          end
        end
        count_availability += 1
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model_apply_acm_hvac_availability_schedule', "Applied availablity schedule '#{acm_fan_sch_name}' to #{count_availability} objects.")
    return count_availability > 0
  end

  # This function checks whether it is required to adjust the window to wall ratio based on the model WWR and wwr limit.
  # @param wwr_limit [Float] return wwr_limit
  # @param wwr_list [Array] list of wwr of zone conditioning category in a building area type category - residential, nonresidential and semiheated
  # @return require_adjustment [Boolean] True, require adjustment, false not require adjustment.
  # NOTE: 179D override so that we adjust the WWR DOWN TO 40%, which is the opposite of the base method (ashrae_90_1_prm.Model.rb does both, returns always true)
  def model_does_require_wwr_adjustment?(wwr_limit, wwr_list)
    require_adjustment = false
    wwr_list.each do |wwr|
      require_adjustment = true if wwr > wwr_limit
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR check:#{wwr} - wwr_limit#{wwr_limit} - require_adjustment: #{require_adjustment}")
    end
    return require_adjustment
  end

  # Creates a Performance Rating Method (aka Appendix G aka LEED) baseline building model
  # Method used for 90.1-2013 and prior
  # @param user_model [OpenStudio::model::Model] User specified OpenStudio model
  # @param building_type [String] the building type
  # @param climate_zone [String] the climate zone
  # @param custom [String] the custom logic that will be applied during baseline creation.  Valid choices are 'Xcel Energy CO EDA' or '90.1-2007 with addenda dn'.
  #   If nothing is specified, no custom logic will be applied; the process will follow the template logic explicitly.
  # @param sizing_run_dir [String] the directory where the sizing runs will be performed
  # @param debug [Boolean] If true, will report out more detailed debugging output
  # @param baseline_179d [Boolean] NOTE: 179D addition, True for the baseline, false for the proposed
  def model_create_prm_baseline_building(model, building_type, climate_zone, custom = nil, sizing_run_dir = Dir.pwd, debug = false, baseline_179d = true)
    model_create_prm_any_baseline_building(model, building_type, climate_zone, 'All others', 'All others', 'All others', false, custom, sizing_run_dir, false, false, debug, baseline_179d)
  end

  # Creates a Performance Rating Method (aka Appendix G aka LEED) baseline building model
  # based on the inputs currently in the model.
  #
  # @note Per 90.1, the Performance Rating Method "does NOT offer an alternative compliance path for minimum standard compliance."
  # This means you can't use this method for code compliance to get a permit.
  # @param user_model [OpenStudio::model::Model] User specified OpenStudio model
  # @param building_type [String] the building type
  # @param climate_zone [String] the climate zone
  # @param hvac_building_type [String] the building type for baseline HVAC system determination (90.1-2016 and onward)
  # @param wwr_building_type [String] the building type for baseline WWR determination (90.1-2016 and onward)
  # @param swh_building_type [String] the building type for baseline SWH determination (90.1-2016 and onward)
  # @param model_deep_copy [Boolean] indicate if the baseline model is created based on a deep copy of the user specified model
  # @param custom [String] the custom logic that will be applied during baseline creation.  Valid choices are 'Xcel Energy CO EDA' or '90.1-2007 with addenda dn'.
  #   If nothing is specified, no custom logic will be applied; the process will follow the template logic explicitly.
  # @param sizing_run_dir [String] the directory where the sizing runs will be performed
  # @param run_all_orients [Boolean] indicate weather a baseline model should be created for all 4 orientations: same as user model, +90 deg, +180 deg, +270 deg
  # @param debug [Boolean] If true, will report out more detailed debugging output
  # @return [Bool] returns true if successful, false if not
  def model_create_prm_any_baseline_building(user_model, building_type, climate_zone, hvac_building_type = 'All others', wwr_building_type = 'All others', swh_building_type = 'All others', model_deep_copy = false, custom = nil, sizing_run_dir = Dir.pwd, run_all_orients = false, unmet_load_hours_check = true, debug = false, baseline_179d = true)
    args = {
      # "user_model"   => user_model,
      'building_type' => building_type,
      'climate_zone' => climate_zone,
      'hvac_building_type' => hvac_building_type,
      'wwr_building_type' => wwr_building_type,
      'swh_building_type' => swh_building_type,
      'model_deep_copy' => model_deep_copy,
      'custom' => custom,
      'sizing_run_dir' => sizing_run_dir,
      'run_all_orients' => run_all_orients,
      'unmet_load_hours_check' => unmet_load_hours_check,
      'debug' => debug,
      'baseline_179d' => baseline_179d,
    }
    if debug
      args.each { |k, v| OpenStudio.logFree(OpenStudio::Info, 'openstudio.prm.179d', "179d - model_create_prm_any_baseline_building inputs: #{k} - #{v}") }
    end
    # system_type string
    prm_system_types = []

    # Check proposed model unmet load hours
    if unmet_load_hours_check
      # Run proposed model; need annual simulation to get unmet load hours
      if model_run_simulation_and_log_errors(user_model, run_dir = "#{sizing_run_dir}/PROP")
        umlh = model_get_unmet_load_hours(user_model)
        if umlh > 300
          OpenStudio.logFree(OpenStudio::Error, 'prm.log', "Proposed model unmet load hours exceed 300. Baseline model(s) won't be created.")
          raise "Proposed model unmet load hours exceed 300. Baseline model(s) won't be created."
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'prm.log', 'Simulation failed. Check the model to make sure no severe errors.')
        raise 'Simulation on proposed model failed. Baseline generation is stopped.'
      end
    end

    # User data process
    # bldg_type_hvac_zone_hash could be an empty hash if all zones in the models are unconditioned
    bldg_type_hvac_zone_hash = {}
    ## Note for 179: replace from local to prm methods
    handle_user_input_data(user_model, climate_zone, hvac_building_type, wwr_building_type, swh_building_type, bldg_type_hvac_zone_hash)
    # Define different orientation from original orientation
    # for each individual baseline models
    # Need to run proposed model sizing simulation if no sql data is available
    if debug
      pp "179d - bldg_type_hvac_zone_hash after handle_user_input_data: #{bldg_type_hvac_zone_hash.map { |k, v| "Key #{k} - Value: #{v}" }}"
    end

    degs_from_org = run_all_orientations(run_all_orients, user_model) ? [0, 90, 180, 270] : [0]

    # Create baseline model for each orientation
    degs_from_org.each do |degs|
      # New baseline model:
      # Starting point is the original proposed model
      # Create a deep copy of the user model if requested
      model = model_deep_copy ? BTAP::FileIO.deep_copy(user_model) : user_model
      model.getBuilding.setName("#{template}-#{building_type}-#{climate_zone} PRM baseline created: #{Time.new}")

      # Rotate building if requested,
      # Site shading isn't rotated
      model_rotate(model, degs) unless degs == 0
      # Perform a sizing run of the proposed model.
      #
      # Among others, one of the goal is to get individual
      # space load to determine each space's conditioning
      # type: conditioned, unconditioned, semiheated.
      if model_create_prm_baseline_building_requires_proposed_model_sizing_run(model)
        # Set up some special reports to be used for baseline system selection later
        # Zone return air flows
        # ! no need for 90.1-2007
        node_list = []
        var_name = 'System Node Standard Density Volume Flow Rate'
        frequency = 'hourly'
        model.getThermalZones.each do |zone|
          port_list = zone.returnPortList
          port_list_objects = port_list.modelObjects
          port_list_objects.each do |node|
            node_name = node.nameString
            node_list << node_name
            output = OpenStudio::Model::OutputVariable.new(var_name, model)
            output.setKeyValue(node_name)
            output.setReportingFrequency(frequency)
          end
        end

        # air loop relief air flows
        var_name = 'System Node Standard Density Volume Flow Rate'
        frequency = 'hourly'
        model.getAirLoopHVACs.sort.each do |air_loop_hvac|
          relief_node = air_loop_hvac.reliefAirNode.get
          output = OpenStudio::Model::OutputVariable.new(var_name, model)
          output.setKeyValue(relief_node.nameString)
          output.setReportingFrequency(frequency)
        end

        # Run the sizing run
        if model_run_sizing_run(model, "#{sizing_run_dir}/SR_PROP#{degs}") == false
          return false
        end

        # Set baseline model space conditioning category based on proposed model
        model.getSpaces.each do |space|
          # Get conditioning category at the space level
          space_conditioning_category = space_conditioning_category(space)

          # Set space conditioning category
          space.additionalProperties.setFeature('space_conditioning_category', space_conditioning_category)
        end

        # The following should be done after a sizing run of the proposed model
        # because the proposed model zone design air flow is needed
        model_identify_return_air_type(model)
      end
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prm.179d', '***179d === All non-HVAC alteration will be disabled***')
      # # Remove external shading devices
      # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Removing External Shading Devices ***')
      if baseline_179d
        model_remove_external_shading_devices(model)
      end

      # Reduce the WWR and SRR, if necessary
      if baseline_179d
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Adjusting Window and Skylight Ratios ***')
        success, wwr_info = model_apply_prm_baseline_window_to_wall_ratio(model, climate_zone, wwr_building_type: wwr_building_type)
        model_apply_prm_baseline_skylight_to_roof_ratio(model)
      end

      # Assign building stories to spaces in the building where stories are not yet assigned.
      model_assign_spaces_to_stories(model)

      # Modify the internal loads in each space type, keeping user-defined schedules.
      if baseline_179d
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Changing Lighting Loads ***')
        model.getSpaceTypes.sort.each do |space_type|
          set_people = false
          set_lights = true
          set_electric_equipment = false
          set_gas_equipment = false
          set_ventilation = false
          set_infiltration = false
          # For PRM, it only applies lights for now.
          space_type_apply_internal_loads(space_type, set_people, set_lights, set_electric_equipment, set_gas_equipment, set_ventilation, set_infiltration)
        end
      end

      # # Modify the lighting schedule to handle lighting occupancy sensors
      # # Modify the upper limit value of fractional schedule to avoid the fatal error caused by schedule value higher than 1
      # NOTE: 179D Disable: No light schedule change as it fixed wth ACM schedules
      # space_type_light_sch_change(model)
      # NOTE: 179D Disable: No exterior lighting schedule required
      # model_apply_baseline_exterior_lighting(model)

      # # Modify the elevator motor peak power
      # NOTE: 179D Disable: no need for 90.1-2007
      # model_add_prm_elevators(model)

      # # Calculate infiltration as per 90.1 PRM rules
      # NOTE: 179D Disable: return True for 90.1-2007 template
      # model_baseline_apply_infiltration_standard(model, climate_zone)

      # If any of the lights are missing schedules, assign an always-off schedule to those lights.
      # This is assumed to be the user's intent in the proposed model.
      model.getLightss.sort.each do |lights|
        if lights.schedule.empty?
          lights.setSchedule(model.alwaysOffDiscreteSchedule)
        end
      end

      # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Adding Daylighting Controls ***')

      # Run a sizing run to calculate VLT for layer-by-layer windows.
      # TODO check if not required for 90.1-2007 full appendix (only required for 90.1-2010)
      if baseline_179d
        if model_create_prm_baseline_building_requires_vlt_sizing_run(model) && (model_run_sizing_run(model, "#{sizing_run_dir}/SRVLT") == false)
          return false
        end
      end

      # # Add or remove daylighting controls to each space
      # # Add daylighting controls for 90.1-2013 and prior
      # # Remove daylighting control for 90.1-PRM-2019 and onward
      # NOTE: check how daylighting required for 90.1-2007
      if baseline_179d
        model.getSpaces.sort.each do |space|
          space_set_baseline_daylighting_controls(space, false, false)
        end
      end

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Applying Baseline Constructions ***')

      # Modify some of the construction types as necessary
      if baseline_179d
        model_apply_prm_construction_types(model)
      end

      # Get the groups of zones that define the baseline HVAC systems for later use.
      # This must be done before removing the HVAC systems because it requires knowledge of proposed HVAC fuels.
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Grouping Zones by Fuel Type and Occupancy Type ***')

      # 179d using local method with 90.1-2010
      # TODO test with warehouse and aparment midrise
      sys_groups = model_prm_baseline_system_groups(model, custom, bldg_type_hvac_zone_hash)

      # Also get hash of zoneName:boolean to record which zones have district heating, if any
      district_heat_zones = model_get_district_heating_zones(model)

      # Store occupancy and fan operation schedules for each zone before deleting HVAC objects
      # NOTE: 179D get ACM schedules directly without care
      zone_fan_scheds = get_fan_schedule_for_each_zone(model)

      # Set the construction properties of all the surfaces in the model
      if baseline_179d
        model_apply_constructions(model, climate_zone, wwr_building_type, wwr_info)
      end

      # Update ground temperature profile (for F/C-factor construction objects)
      if baseline_179d
        model_update_ground_temperature_profile(model, climate_zone)
      end

      # Identify non-mechanically cooled systems if necessary
      model_identify_non_mechanically_cooled_systems(model)

      # Get supply, return, relief fan power for each air loop
      if model_get_fan_power_breakdown
        model.getAirLoopHVACs.sort.each do |air_loop|
          supply_fan_w = air_loop_hvac_get_supply_fan_power(air_loop)
          return_fan_w = air_loop_hvac_get_return_fan_power(air_loop)
          relief_fan_w = air_loop_hvac_get_relief_fan_power(air_loop)

          # Save fan power at the zone to determining
          # baseline fan power
          air_loop.thermalZones.sort.each do |zone|
            zone.additionalProperties.setFeature('supply_fan_w', supply_fan_w.to_f)
            zone.additionalProperties.setFeature('return_fan_w', return_fan_w.to_f)
            zone.additionalProperties.setFeature('relief_fan_w', relief_fan_w.to_f)
          end
        end
      end

      # Compute and marke DCV related information before deleting proposed model HVAC systems
      if baseline_179d
        model_mark_zone_dcv_existence(model)
        model_add_dcv_user_exception_properties(model)
        model_add_dcv_requirement_properties(model)
        model_add_apxg_dcv_properties(model)
        model_raise_user_model_dcv_errors(model)
      end

      # Remove all HVAC from model, excluding service water heating
      if baseline_179d
        model_remove_prm_hvac(model)
      end

      # Remove all EMS objects from the model
      model_remove_prm_ems_objects(model)
      # remove orphan object from DOE prototype
      if model.getMeterCustomDecrementByName('WIRED_INT_EQUIP').is_initialized
        model.getMeterCustomDecrementByName('WIRED_INT_EQUIP').get.remove
        pp 'Removed MeterCustomDecrement:WIRED_INT_EQUIP'
      end
      if model.getMeterCustomByName('Wired_LTG').is_initialized
        model.getMeterCustomByName('Wired_LTG').get.remove
        pp 'Removed MeterCustom:Wired_LTG'
      end
      model.getElectricLoadCenterTransformers.each do |ob|
        ob.remove
        pp "Removed Transformer #{ob.nameString}"
      end

      # Modify the service water heating loops per the baseline rules
      if baseline_179d
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Cleaning up Service Water Heating Loops ***')
        model_apply_baseline_swh_loops(model, building_type)
      end

      # Determine the baseline HVAC system type for each of the groups of zones and add that system type.
      if baseline_179d
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Adding Baseline HVAC Systems ***')

        air_loop_name_array = []
        sys_groups.each_with_index do |sys_group, i|
          ## add data
          sys_group.each do |k, v|
            if k == 'zones'
              pp "179d - system_group #{i}: #{k} - #{v.map(&:nameString).join(':')}"
            else
              pp "179d - system_group #{i}: #{k} - #{v}"
            end
          end
          # Determine the primary baseline system type
          system_type = model_prm_baseline_system_type(model, climate_zone, sys_group, custom, hvac_building_type, district_heat_zones)
          # system_type --> ["PSZ_AC", "NaturalGas", nil, "Electricity"]
          # system_type[0] = "PTHP" ## force system type
          # system_type[0] = "PVAV_Reheat" ## force system type
          # system_type[0] = "VAV_PFP_Boxes" ## force system type
          # system_type[0] = "Gas_Furnace" ## force system type
          # system_type[0] = "Electric_Furnace" ## force system type
          prm_system_types << system_type
          system_str = system_type.zip(['type', 'central_heating_fuel', 'zone_heating_fuel', 'cooling_fuel']).map { |v, k| "#{k} => #{v}" }.join("\n")
          pp "179d - system_type: #{system_str}"

          sys_group['zones'].sort.each_slice(5) do |zone_list|
            zone_names = []
            zone_list.each do |zone|
              zone_names << zone.name.get.to_s
            end
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{zone_names.join(', ')}")
          end

          # Add system type reference to zone
          sys_group['zones'].sort.each do |zone|
            zone.additionalProperties.setFeature('baseline_system_type', system_type[0])
          end

          # Add the system type for these zones
          model_add_prm_baseline_system(model,
                                        system_type[0],
                                        system_type[1],
                                        system_type[2],
                                        system_type[3],
                                        sys_group['zones'],
                                        zone_fan_scheds)

          if baseline_179d && ['Gas_Furnace', 'Electric_Furnace'].include?(system_type[0])
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "179D - For Unit Heater, adding a ZoneVentilationDesignFlowRate for outside air requirements")
            model_add_equivalent_zone_ventilation_for_heated_only_zones_with_dsoa(model, sys_group['zones'], ventilation_type: 'Natural')
          end

          model.getAirLoopHVACs.each do |air_loop|
            air_loop_name = air_loop.name.get
            unless air_loop_name_array.include?(air_loop_name)
              air_loop.additionalProperties.setFeature('zone_group_type', sys_group['zone_group_type'] || 'None')
              air_loop.additionalProperties.setFeature('sys_group_occ', sys_group['occ'] || 'None')
              #  assign hvac_schedule directly not find from anywhere with air_loop_hvac_enable_unoccupied_fan_shutoff
              #  NOTE: 179D override!
              if !zone_fan_scheds.values.empty? && (zone_fan_scheds.values[0].is_a? String)
                air_loop.additionalProperties.setFeature('fan_sched_name', zone_fan_scheds.values[0])
              end

              air_loop_name_array << air_loop_name
            end

            # Determine return air type
            plenum, return_air_type = model_determine_baseline_return_air_type(model, system_type[0], air_loop.thermalZones)
            air_loop.thermalZones.sort.each do |zone|
              # Set up return air plenum
              zone.setReturnPlenum(model.getThermalZoneByName(plenum).get) if return_air_type == 'return_plenum'
            end
          end
        end
      end

      # Add system type reference to all air loops
      model.getAirLoopHVACs.sort.each do |air_loop|
        if air_loop.thermalZones[0].additionalProperties.hasFeature('baseline_system_type')
          sys_type = air_loop.thermalZones[0].additionalProperties.getFeatureAsString('baseline_system_type').get
          air_loop.additionalProperties.setFeature('baseline_system_type', sys_type)
        else
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Thermal zone #{air_loop.thermalZones[0].name} is not associated to a particular system type.")
        end
      end

      # Set the zone sizing SAT for each zone in the model
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Applying Baseline HVAC System Sizing Settings ***')
      model.getThermalZones.each do |zone|
        thermal_zone_apply_prm_baseline_supply_temperatures(zone)
      end

      # Set the system sizing properties based on the zone sizing information
      model.getAirLoopHVACs.each do |air_loop|
        air_loop_hvac_apply_prm_sizing_temperatures(air_loop)
      end

      # Set internal load sizing run schedules
      # ! no need for 90.1-2007
      model_apply_prm_baseline_sizing_schedule(model)

      # Set the heating and cooling sizing parameters
      model_apply_prm_sizing_parameters(model)

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Applying Baseline HVAC System Controls ***')

      # SAT reset, economizers
      model.getAirLoopHVACs.sort.each do |air_loop|
        air_loop_hvac_apply_prm_baseline_controls(air_loop, climate_zone)
      end

      # Apply the baseline system water loop temperature reset control
      model.getPlantLoops.sort.each do |plant_loop|
        # Skip the SWH loops
        next if plant_loop_swh_loop?(plant_loop)

        plant_loop_apply_prm_baseline_temperatures(plant_loop)
      end

      # Run sizing run with the HVAC equipment
      if model_run_sizing_run(model, "#{sizing_run_dir}/SR1") == false
        return false
      end

      # Apply the minimum damper positions, assuming no DDC control of VAV terminals
      model.getAirLoopHVACs.sort.each do |air_loop|
        air_loop_hvac_apply_minimum_vav_damper_positions(air_loop, false)
      end

      # If there are any multi-zone systems, reset damper positions to achieve a 60% ventilation effectiveness minimum for the system
      # following the ventilation rate procedure from 62.1
      model_apply_multizone_vav_outdoor_air_sizing(model)

      # Set the baseline fan power for all air loops
      model.getAirLoopHVACs.sort.each do |air_loop|
        air_loop_hvac_apply_prm_baseline_fan_power(air_loop)
      end

      # Set the baseline fan power for all zone HVAC
      model.getZoneHVACComponents.sort.each do |zone_hvac|
        zone_hvac_component_apply_prm_baseline_fan_power(zone_hvac)
      end

      # Set the baseline number of boilers and chillers
      model.getPlantLoops.sort.each do |plant_loop|
        # Skip the SWH loops
        next if plant_loop_swh_loop?(plant_loop)

        plant_loop_apply_prm_number_of_boilers(plant_loop)
        plant_loop_apply_prm_number_of_chillers(plant_loop, sizing_run_dir)
      end

      # Set the baseline number of cooling towers
      # Must be done after all chillers are added
      model.getPlantLoops.sort.each do |plant_loop|
        # Skip the SWH loops
        next if plant_loop_swh_loop?(plant_loop)

        if baseline_179d
          plant_loop_apply_prm_number_of_cooling_towers(plant_loop)
        end
      end

      # Run sizing run with the new chillers, boilers, and cooling towers to determine capacities
      if model_run_sizing_run(model, "#{sizing_run_dir}/SR2") == false
        return false
      end

      # Set the pumping control strategy and power
      # Must be done after sizing components
      model.getPlantLoops.sort.each do |plant_loop|
        # Skip the SWH loops
        next if plant_loop_swh_loop?(plant_loop)

        if baseline_179d
          plant_loop_apply_prm_baseline_pump_power(plant_loop)
        end
        plant_loop_apply_prm_baseline_pumping_type(plant_loop)
      end

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', '*** Applying Prescriptive HVAC Controls and Equipment Efficiencies ***')

      # Apply the HVAC efficiency standard -- !179D notes: autofan_turn_off apply to this one (both airLoop and ZoneHVAC)
      model_apply_hvac_efficiency_standard(model, climate_zone)

      # NOTE: 179D Set the ACM schedule
      model_apply_acm_hvac_availability_schedule(model)

      # Set baseline DCV system
      model_set_baseline_demand_control_ventilation(model, climate_zone)

      # Final sizing run and adjustements to values that need refinement
      model_refine_size_dependent_values(model, sizing_run_dir)

      # Fix EMS references.
      # Temporary workaround for OS issue #2598
      model_temp_fix_ems_references(model)

      # Delete all the unused resource objects
      model_remove_unused_resource_objects(model)

      # Add reporting tolerances
      model_add_reporting_tolerances(model)

      # @todo: turn off self shading
      # Set Solar Distribution to MinimalShadowing... problem is when you also have detached shading such as surrounding buildings etc
      # It won't be taken into account, while it should: only self shading from the building itself should be turned off but to my knowledge there isn't a way to do this in E+

      model_status = degs > 0 ? "final_#{degs}" : 'final'
      model.save(OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.osm"), true)

      # Translate to IDF and save for debugging
      forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
      idf = forward_translator.translateModel(model)
      idf_path = OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.idf")
      idf.save(idf_path, true)

      prm_system_type_str = prm_system_types.uniq.map { |x| x[0] }.uniq.join('***')
      model.getBuilding.additionalProperties.setFeature('prm_baseline_system_type', prm_system_type_str)

      # Check unmet load hours # disable for 179d
      if unmet_load_hours_check
        nb_adjustments = 0
        loop do
          model_run_simulation_and_log_errors(model, "#{sizing_run_dir}/final#{degs}") == false
          # If UMLH are greater than the threshold allowed by Appendix G,
          # increase zone air flow and load as per the recommendation in
          # the PRM-RM; Note that the PRM-RM only suggest to increase
          # air zone air flow, but the zone sizing factor in EnergyPlus
          # increase both air flow and load.
          if model_get_unmet_load_hours(model) > 300
            # Limit the number of zone sizing factor adjustment to 8
            unless nb_adjustments < 8
              OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "After 8 rounds of zone sizing factor adjustments the unmet load hours for the baseline model (#{degs} degree of rotation) still exceed 300 hours. Please open an issue on GitHub (https://github.com/NREL/openstudio-standards/issues) and share your user model with the developers.")
              break
            end
            model.getThermalZones.each do |thermal_zone|
              # Cooling adjustments
              clg_umlh = thermal_zone_get_unmet_load_hours(thermal_zone, 'Cooling')
              if clg_umlh > 50
                # Get zone cooling sizing factor
                if thermal_zone.sizingZone.zoneCoolingSizingFactor.is_initialized
                  sizing_factor = thermal_zone.sizingZone.zoneCoolingSizingFactor.get
                else
                  sizing_factor = 1.0
                end

                # Make adjustment to zone cooling sizing factor
                # Do not adjust factors greater or equal to 2
                if sizing_factor < 2.0
                  if clg_umlh > 150
                    sizing_factor *= 1.1
                  elsif clg_umlh > 50
                    sizing_factor *= 1.05
                  end
                  thermal_zone.sizingZone.setZoneCoolingSizingFactor(sizing_factor)
                end
              end

              # Heating adjustments
              htg_umlh = thermal_zone_get_unmet_load_hours(thermal_zone, 'Heating')
              if htg_umlh > 50
                # Get zone cooling sizing factor
                if thermal_zone.sizingZone.zoneHeatingSizingFactor.is_initialized
                  sizing_factor = thermal_zone.sizingZone.zoneHeatingSizingFactor.get
                else
                  sizing_factor = 1.0
                end

                # Make adjustment to zone heating sizing factor
                # Do not adjust factors greater or equal to 2
                if sizing_factor < 2.0
                  if htg_umlh > 150
                    sizing_factor *= 1.1
                  elsif htg_umlh > 50
                    sizing_factor *= 1.05
                  end
                  thermal_zone.sizingZone.setZoneHeatingSizingFactor(sizing_factor)
                end
              end
            end
          else
            break
          end
        end
      end
    end

    if debug
      generate_baseline_log(sizing_run_dir)
    end

    return true
  end


  # For Heated Only Zones, System 9 or 10, there will be zero outside air
  # actually brought in, because the ZoneHVACUnitHeater does add OA.
  # While this has very little effect in most of the building types (heated
  # only zones are small), this is problematic for the Warehouse in particular
  # This method will look on such zones, and for each zone it will find the
  # DesignSpecificationOutdoorAir objects for the spaces and compute an
  # equivalent OA flow rate, and create a ZoneVentilationDesignFlowRate object
  # to match it.
  # @param ventilation_type [String] one of:
  #   * 'Natural', 'Intake' (Supply Fanfloor area (m^2)
  #   * 'Intake': System 9 and 10 supply fan, 0.3 W/CFM
  #   * 'Exahsut': System 9 and 10 non-mechanical cooling, 0.054 W/CFM
  def model_add_equivalent_zone_ventilation_for_heated_only_zones_with_dsoa(model, zones, ventilation_type: 'Natural')
    zones.sort.each do |zone|
      total_oa_m3_per_s = thermal_zone_outdoor_airflow_rate(zone)

      total_oa_m3_per_m2s = total_oa_m3_per_s / zone.floorArea

      next unless total_oa_m3_per_s > 0

      # ventilation = model_add_zone_ventilation(model, sys_group['zones'], ventilation_type: 'Natural', flow_rate: total_oa_m3_per_s).first

      tot_oa_cfm = OpenStudio.convert(total_oa_m3_per_s, 'm^3/s', 'cfm').get.round(2)
      total_oa_cfm_per_sqft = OpenStudio.convert(total_oa_m3_per_m2s, 'm^3/m^2*s', 'cfm/ft^2').get.round(4)

      OpenStudio.logFree(
        OpenStudio::Info, 'openstudio.179D.Model',
        "Adding zone ventilation fan for #{zone.name} - #{tot_oa_cfm} CFM total - #{total_oa_cfm_per_sqft} CFM/ft^2"
      )

      ventilation = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
      ventilation.setName("#{zone.name} Ventilation")
      ventilation.setSchedule(model.alwaysOnDiscreteSchedule)

      # Per Flow Area is clearer in intent, because that's what we
      # mostly have in our standards data
      # ventilation.setDesignFlowRate(total_oa_m3_per_s)
      ventilation.setFlowRateperZoneFloorArea(total_oa_m3_per_m2s)

      # Make it run all the time, with the design flow rate
      ventilation.setConstantTermCoefficient(1.0)
      ventilation.setVelocityTermCoefficient(0.0)
      ventilation.setTemperatureTermCoefficient(0.0)
      ventilation.setMinimumIndoorTemperature(-73.3333352760033)
      ventilation.setMaximumIndoorTemperature(100.0)
      ventilation.setDeltaTemperature(-100.0)

      if ventilation_type == 'Natural'
        # No fan power
        pressure_rise_pa = 0.0
        fan_total_eff = 1.0
      elsif ventilation_type == 'Intake'
        # System Type 9 and 10 (supply fan): Pfan = CFM * 0.3
        target_w_per_m3_per_s = OpenStudio.convert(0.3, 'W/CFM', 'W*s/m^3').get()
        fan_total_eff = 0.6
        pressure_rise_pa = fan_total_eff * target_w_per_m3_per_s
      elsif ventilation_type == 'Exhaust'
        # System Type 9 and 10 (non-mechanical cooling fan
        # if required by Section G3.1.2.8.2): Pfan = CFM * 0.054
        target_w_per_m3_per_s = OpenStudio.convert(0.054, 'W/CFM', 'W*s/m^3').get()
        fan_total_eff = 0.6
        pressure_rise_pa = fan_total_eff * target_w_per_m3_per_s
      else
        raise "ventilation_type must be one of ['Natural', 'Intake', 'Exhaust']"
      end

      ventilation.setVentilationType(ventilation_type)
      ventilation.setFanPressureRise(pressure_rise_pa)
      ventilation.setFanTotalEfficiency(fan_total_eff)

      ventilation.addToThermalZone(zone)
    end
  end

  # Store fan operation schedule for each zone before deleting HVAC objects
  # NOTE: 179D overrides it to get the hvac_operation_schedule from ACM data
  # @param model [object]
  # @return [hash] of zoneName:STRING fan sch name! (Override)
  def get_fan_schedule_for_each_zone(model)
    data = model_get_standards_data(model, throw_if_not_found: true)
    acm_fan_sch_name = data['hvac_operation_schedule']
    acm_fan_sch = model_add_schedule(model, acm_fan_sch_name)
    model.getBuilding.additionalProperties.setFeature('acm_fan_sch', acm_fan_sch_name)

    # NOTE: 179D override, we set it to a String
    # fan_schedule_8760 = get_8760_values_from_schedule(model, acm_fan_sch)

    fan_sch_names = {}
    model.getThermalZones.sort.each do |zone|
      fan_sch_names[zone.name.get] = acm_fan_sch_name # fan_schedule_8760
    end

    return fan_sch_names
  end

end

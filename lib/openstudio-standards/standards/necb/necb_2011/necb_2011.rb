class NECB_2011_Model < StandardsModel
  @@template = 'NECB 2011'
  register_standard (@@template)
  attr_reader :instvartemplate

  def initialize
    super()
    @instvartemplate = @@template
    @standards_data = self.load_standards_database()

    #NECB Values
    @standards_data["climate_zone_sets"] = [
        {"name" => "NECB-CNEB ClimatZone 4-8", "climate_zones" => ["NECB HDD Method"]}
    ]
    @standards_data["occupancy_sensors"] = [
        {"standard_space_type_name " => 'Storage area', "max_floor_area" => 100.0},
        {"standard_space_type_name " => 'Storage area - refrigerated', "max_floor_area" => 100.0},
        {"standard_space_type_name " => 'Hospital - medical supply', "max_floor_area" => 100.0},
        {"standard_space_type_name " => 'Office - enclosed', "max_floor_area" => 25.0}
    ]

    @standards_data["climate_zone_info"] = [
        {"template" => 'NECB 2011', "climate_zone_name" => "NECB_2011_Zone 4", "max_hdd" => 2999.0},
        {"template" => 'NECB 2011', "climate_zone_name" => "NECB_2011_Zone 5", "max_hdd" => 3999.0},
        {"template" => 'NECB 2011', "climate_zone_name" => "NECB_2011_Zone 6", "max_hdd" => 4999.0},
        {"template" => 'NECB 2011', "climate_zone_name" => "NECB_2011_Zone 7a", "max_hdd" => 5999.0},
        {"template" => 'NECB 2011', "climate_zone_name" => "NECB_2011_Zone 7a", "max_hdd" => 6999.0},
        {"template" => 'NECB 2011', "climate_zone_name" => "NECB_2011_Zone 8", "max_hdd" => 9999.0}
    ]
    # NECB_2011_S_3_2_1_4
    # This is the formula that will be used in a ruby eval given the hdd variable.
    @standards_data["fdwr_formula"] = "(hdd < 4000.0) ? 0.4 : (hdd >= 4000.0 and hdd < 7000.0 ) ? ( (2000.0 - 0.2* hdd) / 3000.00) : 0.2"
    @standards_data["coolingSizingFactor"] = 1.3
    @standards_data["heatingSizingFactor"] = 1.3

    @standards_data["conductances"] = [
        {"surface" => "ground_wall", "thermal_transmittance" => 0.568, "hdd" => 3000},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.379, "hdd" => 3999},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.284, "hdd" => 4999},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.284, "hdd" => 5999},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.284, "hdd" => 6999},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.210, "hdd" => 999999},


        {"surface" => "wall", "thermal_transmittance" => 0.315, "hdd" => 3000},
        {"surface" => "wall", "thermal_transmittance" => 0.278, "hdd" => 3999},
        {"surface" => "wall", "thermal_transmittance" => 0.247, "hdd" => 4999},
        {"surface" => "wall", "thermal_transmittance" => 0.210, "hdd" => 5999},
        {"surface" => "wall", "thermal_transmittance" => 0.210, "hdd" => 6999},
        {"surface" => "wall", "thermal_transmittance" => 0.183, "hdd" => 999999},
        {"surface" => "roof", "thermal_transmittance" => 0.227, "hdd" => 3000},
        {"surface" => "roof", "thermal_transmittance" => 0.183, "hdd" => 3999},
        {"surface" => "roof", "thermal_transmittance" => 0.183, "hdd" => 4999},
        {"surface" => "roof", "thermal_transmittance" => 0.162, "hdd" => 5999},
        {"surface" => "roof", "thermal_transmittance" => 0.162, "hdd" => 6999},
        {"surface" => "roof", "thermal_transmittance" => 0.142, "hdd" => 999999},
        {"surface" => "floor", "thermal_transmittance" => 0.227, "hdd" => 3000},
        {"surface" => "floor", "thermal_transmittance" => 0.183, "hdd" => 3999},
        {"surface" => "floor", "thermal_transmittance" => 0.183, "hdd" => 4999},
        {"surface" => "floor", "thermal_transmittance" => 0.162, "hdd" => 5999},
        {"surface" => "floor", "thermal_transmittance" => 0.162, "hdd" => 6999},
        {"surface" => "floor", "thermal_transmittance" => 0.142, "hdd" => 999999},
        {"surface" => "window", "thermal_transmittance" => 2.400, "hdd" => 3000},
        {"surface" => "window", "thermal_transmittance" => 2.200, "hdd" => 3999},
        {"surface" => "window", "thermal_transmittance" => 2.200, "hdd" => 4999},
        {"surface" => "window", "thermal_transmittance" => 2.200, "hdd" => 5999},
        {"surface" => "window", "thermal_transmittance" => 2.200, "hdd" => 6999},
        {"surface" => "window", "thermal_transmittance" => 1.600, "hdd" => 999999},
        {"surface" => "door", "thermal_transmittance" => 2.400, "hdd" => 3000},
        {"surface" => "door", "thermal_transmittance" => 2.200, "hdd" => 3999},
        {"surface" => "door", "thermal_transmittance" => 2.200, "hdd" => 4999},
        {"surface" => "door", "thermal_transmittance" => 2.200, "hdd" => 5999},
        {"surface" => "door", "thermal_transmittance" => 2.200, "hdd" => 6999},
        {"surface" => "door", "thermal_transmittance" => 1.600, "hdd" => 999999},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.568, "hdd" => 3000},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.379, "hdd" => 3999},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.284, "hdd" => 4999},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.284, "hdd" => 5999},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.284, "hdd" => 6999},
        {"surface" => "ground_wall", "thermal_transmittance" => 0.210, "hdd" => 999999},
        {"surface" => "ground_roof", "thermal_transmittance" => 0.568, "hdd" => 3000},
        {"surface" => "ground_roof", "thermal_transmittance" => 0.379, "hdd" => 3999},
        {"surface" => "ground_roof", "thermal_transmittance" => 0.284, "hdd" => 4999},
        {"surface" => "ground_roof", "thermal_transmittance" => 0.284, "hdd" => 5999},
        {"surface" => "ground_roof", "thermal_transmittance" => 0.284, "hdd" => 6999},
        {"surface" => "ground_roof", "thermal_transmittance" => 0.210, "hdd" => 999999},
        {"surface" => "ground_floor", "thermal_transmittance" => 0.757, "hdd" => 3000},
        {"surface" => "ground_floor", "thermal_transmittance" => 0.757, "hdd" => 3999},
        {"surface" => "ground_floor", "thermal_transmittance" => 0.757, "hdd" => 4999},
        {"surface" => "ground_floor", "thermal_transmittance" => 0.757, "hdd" => 5999},
        {"surface" => "ground_floor", "thermal_transmittance" => 0.757, "hdd" => 6999},
        {"surface" => "ground_floor", "thermal_transmittance" => 0.379, "hdd" => 999999}]

    @standards_data["fan_variable_volume_pressure_rise"] = 1458.33
    @standards_data["fan_constant_volume_pressure_rise"] = 640.00
    # NECB Infiltration rate information for standard.
    @standards_data["infiltration"] = {}
    @standards_data["infiltration"]["rate_m3_per_s_per_m2"] = 0.25 * 0.001 # m3/s/m2
    @standards_data["infiltration"]["constant_term_coefficient"] = 0.0
    @standards_data["infiltration"]["temperature_term_coefficient"] = 0.0
    @standards_data["infiltration"]["velocity_term_coefficient"] = 0.224
    @standards_data["infiltration"]["velocity_squared_term_coefficient"] = 0.0
    @standards_data["skylight_to_roof_ratio"] = 0.05
    @standards_data['necb_hvac_system_selection_type'] = [
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => '- undefined -', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 0, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Assembly Area', "min_stories" => 0, "max_stories" => 4, "max_cooling_capacity_kw" => 99999, "system_type" => 3, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Assembly Area', "min_stories" => 4, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 6, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Automotive Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 4, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Data Processing Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 19.999, "system_type" => 1, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Data Processing Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 2, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'General Area', "min_stories" => 2, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 3, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'General Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 6, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Historical Collections Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 2, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Hospital Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 3, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Indoor Arena', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 7, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Industrial Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 3, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Residential/Accomodation Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 1, "dwelling" => true},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Sleeping Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 3, "dwelling" => true},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Supermarket/Food Services Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 3, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Supermarket/Food Services Area - vented', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 4, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Warehouse Area', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 4, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Warehouse Area - refrigerated', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => 5, "dwelling" => false},
        {'template' => "NECB 2011", 'necb_hvac_system_selection_type' => 'Wildcard', "min_stories" => 0, "max_stories" => 99999, "max_cooling_capacity_kw" => 99999, "system_type" => nil, "dwelling" => false}
    ]
    @standards_data['fan_motors'] = [
        {"template" => "NECB 2011", "fan_type" => "CONSTANT", "number_of_poles" => 4.0, "type" => "Enclosed", "synchronous_speed" => 1800.0, "minimum_capacity" => 0.0, "maximum_capacity" => 9999.0, "nominal_full_load_efficiency" => 0.615, "notes" => "To get total fan efficiency of 40% (0.4/0.65)"},
        {"template" => "NECB 2011", "fan_type" => "VARIABLE", "number_of_poles" => 4.0, "type" => "Enclosed", "synchronous_speed" => 1800.0, "minimum_capacity" => 0.0, "maximum_capacity" => 9999.0, "nominal_full_load_efficiency" => 0.8461, "notes" => "To get total fan efficiency of 55% (0.55/0.65)"}
    ]
    # @standards_data['schedules'] = $os_standards['schedules'].select {|s| s['name'].to_s.match(/NECB.*/)}

  end


  def model_create_prototype_model(climate_zone, epw_file, sizing_run_dir = Dir.pwd, debug = false)
    building_type = @instvarbuilding_type
    raise ("no building_type!") if @instvarbuilding_type.nil?
    model = nil
    #prototype generation.
    model = load_initial_osm(@geometry_file) #standard candidate
    model.getThermostatSetpointDualSetpoints(&:remove)
    model.yearDescription.get.setDayofWeekforStartDay('Sunday')
    model_add_design_days_and_weather_file(model, climate_zone, epw_file) #Standards
    model_add_ground_temperatures(model, @instvarbuilding_type, climate_zone, instvartemplate) #prototype candidate
    model.getBuilding.setName(self.class.to_s)
    model.getBuilding.setName("#{}-#{@instvarbuilding_type}-#{climate_zone}-#{epw_file} created: #{Time.new}")
    self.set_occ_sensor_spacetypes(model, @space_type_map)
    model_add_loads(model) #standards candidate
    model_apply_infiltration_standard(model) #standards candidate
    model_modify_surface_convection_algorithm(model) #standards
    model_add_constructions(model, @instvarbuilding_type, climate_zone) #prototype candidate
    apply_standard_construction_properties(model) #standards candidate
    apply_standard_window_to_wall_ratio(model) #standards candidate
    apply_standard_skylight_to_roof_ratio(model) #standards candidate
    model_create_thermal_zones(model, @space_multiplier_map) #standards candidate
    # For some building types, stories are defined explicitly

    return false if model_run_sizing_run(model, "#{sizing_run_dir}/SR0") == false
    #Create Reference HVAC Systems.
    model_add_hvac(model, epw_file) #standards for NECB Prototype for NREL candidate
    model_add_swh(model, @instvarbuilding_type, climate_zone, @prototype_input, epw_file)
    model_apply_sizing_parameters(model)


    #set a larger tolerance for unmet hours from default 0.2 to 1.0C
    model.getOutputControlReportingTolerances.setToleranceforTimeHeatingSetpointNotMet(1.0)
    model.getOutputControlReportingTolerances.setToleranceforTimeCoolingSetpointNotMet(1.0)
    return false if model_run_sizing_run(model, "#{sizing_run_dir}/SR1") == false
    # This is needed for NECB 2011 as a workaround for sizing the reheat boxes
    model.getAirTerminalSingleDuctVAVReheats.each {|iobj| air_terminal_single_duct_vav_reheat_set_heating_cap(iobj)}
    # Apply the prototype HVAC assumptions
    # which include sizing the fan pressure rises based
    # on the flow rate of the system.
    model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
    # AHU1 doesn't have economizer
    model_modify_oa_controller(model)
    # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
    model_reset_or_room_vav_minimum_damper(@prototype_input, model)
    model_modify_oa_controller(model)
    # Apply the HVAC efficiency standard
    model_apply_hvac_efficiency_standard(model, climate_zone)
    # Fix EMS references.
    # Temporary workaround for OS issue #2598
    model_temp_fix_ems_references(model)
    # Add daylighting controls per standard
    # only four zones in large hotel have daylighting controls
    # todo: YXC to merge to the main function
    model_add_daylighting_controls(model) # to be removed after refactor.
    # Add output variables for debugging
    model_request_timeseries_outputs(model) if debug
    return model
  end


  def set_wildcard_schedules_to_dominant_building_schedule(model, runner = nil)

    new_sched_ruleset = OpenStudio::Model::DefaultScheduleSet.new(model) #initialize
    BTAP::runner_register("Info", "set_wildcard_schedules_to_dominant_building_schedule", runner)
    #Set wildcard schedules based on dominant schedule type in building.
    dominant_sched_type = self.determine_dominant_necb_schedule_type(model)
    #puts "dominant_sched_type = #{dominant_sched_type}"
    # find schedule set that corresponds to dominant schedule type
    model.getDefaultScheduleSets.sort.each do |sched_ruleset|
      # just check people schedule
      # TO DO: should make this smarter: check all schedules
      people_sched = sched_ruleset.numberofPeopleSchedule
      people_sched_name = people_sched.get.name.to_s unless people_sched.empty?

      search_string = "NECB-#{dominant_sched_type}"

      if people_sched.empty? == false
        if people_sched_name.include? search_string
          new_sched_ruleset = sched_ruleset
        end
      end
    end

    # replace the default schedule set for the space type with * to schedule ruleset with dominant schedule type

    model.getSpaces.sort.each do |space|
      #check to see if space space type has a "*" wildcard schedule.
      spacetype_name = space.spaceType.get.name.to_s unless space.spaceType.empty?
      if determine_necb_schedule_type(space).to_s == "*".to_s
        new_sched = (spacetype_name).to_s
        optional_spacetype = model.getSpaceTypeByName(new_sched)
        if optional_spacetype.empty?
          BTAP::runner_register("Error", "Cannot find NECB spacetype #{new_sched}", runner)
        else
          BTAP::runner_register("Info", "Setting wildcard spacetype #{spacetype_name} default schedule set to #{new_sched_ruleset.name}", runner)
          optional_spacetype.get.setDefaultScheduleSet(new_sched_ruleset) #this works!
        end
      end
    end # end of do |space|

    return true
  end

  #This model determines the dominant NECB schedule type
  #@param model [OpenStudio::model::Model] A model object
  #return s.each [String]
  def determine_dominant_necb_schedule_type(model)
    # lookup necb space type properties
    space_type_properties = @standards_data["space_types"]

    # Here is a hash to keep track of the m2 running total of spacetypes for each
    # sched type.
    s = Hash[
        "A", 0,
        "B", 0,
        "C", 0,
        "D", 0,
        "E", 0,
        "F", 0,
        "G", 0,
        "H", 0,
        "I", 0
    ]
    #iterate through spaces in building.
    wildcard_spaces = 0
    model.getSpaces.sort.each do |space|
      found_space_type = false
      #iterate through the NECB spacetype property table
      space_type_properties.each do |spacetype|
        unless space.spaceType.empty?
          if space.spaceType.get.standardsSpaceType.empty? || space.spaceType.get.standardsBuildingType.empty?
            OpenStudio::logFree(OpenStudio::Error, "openstudio.Standards.Model", "Space #{space.name} does not have a standardSpaceType defined")
            found_space_type = false
          elsif space.spaceType.get.standardsSpaceType.get == spacetype['space_type'] && space.spaceType.get.standardsBuildingType.get == spacetype['building_type']
            if "*" == spacetype['necb_schedule_type']
              wildcard_spaces =+1
            else
              s[spacetype['necb_schedule_type']] = s[spacetype['necb_schedule_type']] + space.floorArea() if "*" != spacetype['necb_schedule_type'] and "- undefined -" != spacetype['necb_schedule_type']
            end
            #puts "Found #{space.spaceType.get.name} schedule #{spacetype[2]} match with floor area of #{space.floorArea()}"
            found_space_type = true
          elsif "*" != spacetype['necb_schedule_type']
            #found wildcard..will not count to total.
            found_space_type = true
          end
        end
      end
      raise ("Did not find #{space.spaceType.get.name} in NECB space types.") if found_space_type == false
    end
    #finds max value and returns NECB schedule letter.
    raise("Only wildcard spaces in model. You need to define the actual spaces. ") if wildcard_spaces == model.getSpaces.size
    dominant_schedule = s.each {|k, v| return k.to_s if v == s.values.max}
    return dominant_schedule
  end

  #This method determines the spacetype schedule type. This will re
  #@author phylroy.lopez@nrcan.gc.ca
  #@param space [String]
  #@return [String]:["A","B","C","D","E","F","G","H","I"] spacetype
  def determine_necb_schedule_type(space)
    raise ("Undefined spacetype for space #{space.get.name}) if space.spaceType.empty?") if space.spaceType.empty?
    raise ("Undefined standardsSpaceType or StandardsBuildingType for space #{space.spaceType.get.name}) if space.spaceType.empty?") if space.spaceType.get.standardsSpaceType.empty? | space.spaceType.get.standardsBuildingType.empty?
    space_type_properties = @standards_data["space_types"].detect {|st| st["space_type"] == space.spaceType.get.standardsSpaceType.get and st["building_type"] == space.spaceType.get.standardsBuildingType.get}
    return space_type_properties['necb_schedule_type'].strip
  end

  # Determine whether or not water fixtures are attached to spaces
  def model_attach_water_fixtures_to_spaces?(model)
    return true
  end

  # Set the infiltration rate for this space to include
  # the impact of air leakage requirements in the standard.
  #
  # @return [Double] true if successful, false if not
  # @todo handle doors and vestibules
  def space_apply_infiltration_rate(space)
    # Remove infiltration rates set at the space type.
    infiltration_data = @standards_data["infiltration"]
    unless space.spaceType.empty?
      space.spaceType.get.spaceInfiltrationDesignFlowRates.each(&:remove)
    end
    # Remove infiltration rates set at the space object.
    space.spaceInfiltrationDesignFlowRates.each(&:remove)


    exterior_wall_and_roof_and_subsurface_area = space_exterior_wall_and_roof_and_subsurface_area(space) # To do
    # Don't create an object if there is no exterior wall area
    if exterior_wall_and_roof_and_subsurface_area <= 0.0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.Model', "For #{instvartemplate}, no exterior wall area was found, no infiltration will be added.")
      return true
    end
    # Calculate the total infiltration, assuming
    # that it only occurs through exterior walls and roofs (not floors as
    # explicit stated in the NECB 2011 so overhang/cantilevered floors will
    # have no effective infiltration)
    tot_infil_m3_per_s = infiltration_data["rate_m3_per_s_per_m2"] * exterior_wall_and_roof_and_subsurface_area
    # Now spread the total infiltration rate over all
    # exterior surface area (for the E+ input field) this will include the exterior floor if present.
    all_ext_infil_m3_per_s_per_m2 = tot_infil_m3_per_s / space.exteriorArea

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Space', "For #{space.name}, adj infil = #{all_ext_infil_m3_per_s_per_m2.round(8)} m^3/s*m^2.")

    # Get any infiltration schedule already assigned to this space or its space type
    # If not, the always on schedule will be applied.
    infil_sch = nil
    unless space.spaceInfiltrationDesignFlowRates.empty?
      old_infil = space.spaceInfiltrationDesignFlowRates[0]
      if old_infil.schedule.is_initialized
        infil_sch = old_infil.schedule.get
      end
    end

    if infil_sch.nil? && space.spaceType.is_initialized
      space_type = space.spaceType.get
      unless space_type.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
        if old_infil.schedule.is_initialized
          infil_sch = old_infil.schedule.get
        end
      end
    end

    if infil_sch.nil?
      infil_sch = space.model.alwaysOnDiscreteSchedule
    end

    # Create an infiltration rate object for this space
    infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(space.model)
    infiltration.setName("#{space.name} Infiltration")
    infiltration.setFlowperExteriorSurfaceArea(all_ext_infil_m3_per_s_per_m2)
    infiltration.setSchedule(infil_sch)
    infiltration.setConstantTermCoefficient(infiltration_data["constant_term_coefficient"])
    infiltration.setTemperatureTermCoefficient(infiltration_data["constant_term_coefficient"])
    infiltration.setVelocityTermCoefficient(infiltration_data["velocity_term_coefficient"])
    infiltration.setVelocitySquaredTermCoefficient(infiltration_data["velocity_squared_term_coefficient"])
    infiltration.setSpace(space)


    return true
  end

  # @return [Bool] returns true if successful, false if not
  def set_occ_sensor_spacetypes(model, space_type_map)
    building_type = 'Space Function'
    space_type_map.each do |space_type_name, space_names|
      space_names.sort.each do |space_name|
        space = model.getSpaceByName(space_name)
        next if space.empty?
        space = space.get
        occsensSpaceTypeUsed = false

        # Check if space type for this space matches NECB 2011 specific space type
        # for occupancy sensor that is area dependent. Note: space.floorArea in m2.

        if ((space_type_name=='Storage area' && space.floorArea < 100) ||
            (space_type_name=='Storage area - refrigerated' && space.floorArea < 100) ||
            (space_type_name=='Hospital - medical supply' && space.floorArea < 100) ||
            (space_type_name=='Office - enclosed' && space.floorArea < 25))
          # If there is only one space assigned to this space type, then reassign this stub
          # to the @@template duplicate with appendage " - occsens", otherwise create a new stub
          # for this space. Required to use reduced LPD by NECB 2011 0.9 factor.
          space_type_name_occsens = space_type_name + " - occsens"
          stub_space_type_occsens = model.getSpaceTypeByName("#{building_type} #{space_type_name_occsens}")

          if stub_space_type_occsens.empty?
            # create a new space type just once for space_type_name appended with " - occsens"
            stub_space_type_occsens = OpenStudio::Model::SpaceType.new(model)
            stub_space_type_occsens.setStandardsBuildingType(building_type)
            stub_space_type_occsens.setStandardsSpaceType(space_type_name_occsens)
            stub_space_type_occsens.setName("#{building_type} #{space_type_name_occsens}")
            space_type_apply_rendering_color(stub_space_type_occsens)
            space.setSpaceType(stub_space_type_occsens)
          else
            # reassign occsens space type stub already created...
            stub_space_type_occsens = stub_space_type_occsens.get
            space.setSpaceType(stub_space_type_occsens)
          end
        end
      end
    end
    return true
  end

end

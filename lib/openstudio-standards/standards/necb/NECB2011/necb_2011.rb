# This class holds methods that apply NECB2011 rules.
# @ref [References::NECB2011]
class NECB2011 < Standard
  @template = self.new.class.name # rubocop:disable Style/ClassVars
  register_standard(@template)
  attr_reader :template
  attr_accessor :standards_data
  attr_accessor :space_type_map
  attr_accessor :space_multiplier_map

  def get_standards_table(table_name:)
    if @standards_data["tables"][table_name].nil?
      message = "Could not find table #{table_name} in database."
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Standards.NECB', message)
    end
    @standards_data["tables"][table_name]
  end

  def get_standard_constant_value(constant_name: )
     puts "do nothing"
  end


  # Combine the data from the JSON files into a single hash
  # Load JSON files differently depending on whether loading from
  # the OpenStudio CLI embedded filesystem or from typical gem installation
  def load_standards_database_new()
    @standards_data = {}
    @standards_data["tables"] = {}

    if __dir__[0] == ':' # Running from OpenStudio CLI
      embedded_files_relative('../common', /.*\.json/).each do |file|
        data = JSON.parse(EmbeddedScripting.getFileAsString(file))
        if not data["tables"].nil? and data["tables"].first["data_type"] == "table"
          @standards_data["tables"] << data["tables"].first
        else
          @standards_data[data.keys.first] = data[data.keys.first]
        end
      end
    else
      path = "#{File.dirname(__FILE__)}/../common/"
      raise ('Could not find common folder') unless Dir.exist?(path)
      files = Dir.glob("#{path}/*.json").select {|e| File.file? e}
      files.each do |file|
        data = JSON.parse(File.read(file))
        if not data["tables"].nil?
          @standards_data["tables"] = [*@standards_data["tables"], *data["tables"]].to_h
        else
          @standards_data[data.keys.first] = data[data.keys.first]
        end
      end
    end


    if __dir__[0] == ':' # Running from OpenStudio CLI
      embedded_files_relative('data/', /.*\.json/).each do |file|
        data = JSON.parse(EmbeddedScripting.getFileAsString(file))
        if not data["tables"].nil? and data["tables"].first["data_type"] == "table"
          @standards_data["tables"] << data["tables"].first
        else
          @standards_data[data.keys.first] = data[data.keys.first]
        end
      end
    else
      files = Dir.glob("#{File.dirname(__FILE__)}/data/*.json").select {|e| File.file? e}
      files.each do |file|
        data = JSON.parse(File.read(file))
        if not data["tables"].nil?
          @standards_data["tables"] = [*@standards_data["tables"], *data["tables"]].to_h
        else
          @standards_data[data.keys.first] = data[data.keys.first]
        end
      end
    end
    # Write database to file.
    # File.open(File.join(File.dirname(__FILE__), '..', 'NECB2011.json'), 'w') {|f| f.write(JSON.pretty_generate(@standards_data))}

    return @standards_data
  end

  # Create a schedule from the openstudio standards dataset and
  # add it to the model.
  #
  # @param schedule_name [String} name of the schedule
  # @return [ScheduleRuleset] the resulting schedule ruleset
  # @todo make return an OptionalScheduleRuleset
  def model_add_schedule(model, schedule_name)

    super(model, schedule_name)
  end

  def get_standards_constant(name)
    object = @standards_data['constants'][name]

    if object.nil? or object['value'].nil?
      raise("could not find #{name} in standards constants database. ")
    end

    return object['value']
  end

  def get_standards_formula(name)
    object = @standards_data['formulas'][name]
    raise("could not find #{name} in standards formual database. ") if object.nil? or object['value'].nil?
    return object['value']
  end


  def initialize
    super()
    @template = self.class.name
    @standards_data = self.load_standards_database_new()
    #puts "loaded these tables..."
    #puts @standards_data.keys.size
    #raise("tables not all loaded in parent #{}") if @standards_data.keys.size < 24
  end

  def get_all_spacetype_names
    return standards_lookup_table_many(table_name: 'space_types').map {|space_types| [space_types['building_type'], space_types['space_type']]}
  end

  # Enter in [latitude, longitude] for each loc and this method will return the distance.
  def distance(loc1, loc2)
    rad_per_deg = Math::PI / 180 # PI / 180
    rkm = 6371 # Earth radius in kilometers
    rm = rkm * 1000 # Radius in meters

    dlat_rad = (loc2[0] - loc1[0]) * rad_per_deg # Delta, converted to rad
    dlon_rad = (loc2[1] - loc1[1]) * rad_per_deg

    lat1_rad, lon1_rad = loc1.map {|i| i * rad_per_deg}
    lat2_rad, lon2_rad = loc2.map {|i| i * rad_per_deg}

    a = Math.sin(dlat_rad / 2) ** 2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2) ** 2
    c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1 - a))
    rm * c # Delta in meters
  end

  # this method returns the default system fuel types by epw_file.
  def get_canadian_system_defaults_by_weatherfile_name(model)
    #get models weather object to get the province. Then use that to look up the province.
    epw = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get)
    fuel_sources = standards_lookup_table_many(table_name: 'regional_fuel_use').detect {|fuel_sources| fuel_sources['state_province_regions'].include?(epw.state_province_region)}
    raise("Could not find fuel sources for weather file, make sure it is a Canadian weather file.") if fuel_sources.nil? #this should never happen since we are using only canadian weather files.
    return fuel_sources
  end

  def get_necb_hdd18(model)
    max_distance_tolerance = 500000
    min_distance = 100000000000000.0
    necb_closest = nil
    epw = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get)
    #this extracts the table from the json database.
    necb_2015_table_c1 = @standards_data['tables']['necb_2015_table_c1']['table']
    necb_2015_table_c1.each do |necb|
      next if necb['lat_long'].nil? #Need this until Tyson cleans up table.
      dist = distance([epw.latitude.to_f, epw.longitude.to_f], necb['lat_long'])
      if min_distance > dist
        min_distance = dist
        necb_closest = necb
      end
    end
    if (min_distance / 1000.0) > max_distance_tolerance and not epw.hdd18.nil?
      puts "Could not find close NECB HDD from Table C1 < #{max_distance_tolerance}km. Closest city is #{min_distance / 1000.0}km away. Using epw hdd18 instead."
      return epw.hdd18.to_f
    else
      puts "INFO:NECB HDD18 of #{necb_closest['degree_days_below_18_c'].to_f}  at nearest city #{necb_closest['city']},#{necb_closest['province']}, at a distance of #{'%.2f' % (min_distance / 1000.0)}km from epw location. Ref:necb_2015_table_c1"
      return necb_closest['degree_days_below_18_c'].to_f
    end
  end


  # This method is a wrapper to create the 16 archetypes easily.
  def model_create_prototype_model(template:,
                                   building_type:,
                                   epw_file:,
                                   debug: false,
                                   sizing_run_dir: Dir.pwd,
                                   x_scale: 1.0,
                                   y_scale: 1.0,
                                   z_scale: 1.0,
                                   fdwr_set: 'MAXIMIZE',
                                   ssr_set: 'MAXIMIZE'
  )
    osm_model_path = File.absolute_path(File.join(__FILE__, '..', '..', '..', "necb/NECB2011/data/geometry/#{building_type}.osm"))
    model = BTAP::FileIO::load_osm(osm_model_path)
    model.getBuilding.setName("#{File.basename(osm_model_path, '.osm')}-#{epw_file} created: #{Time.new}")

    return model_apply_standard(model: model,
                                epw_file: epw_file,
                                x_scale: x_scale,
                                y_scale: y_scale,
                                z_scale: z_scale,
                                sizing_run_dir: sizing_run_dir,
                                fdwr_set: fdwr_set,
                                ssr_set: ssr_set)
  end


  # Created this method so that additional methods can be addded for bulding the prototype model in later
  # code versions without modifying the build_protoype_model method or copying it wholesale for a few changes.
  def model_apply_standard(model:,
                           epw_file:,
                           debug: false,
                           sizing_run_dir: Dir.pwd,
                           x_scale: 1.0,
                           y_scale: 1.0,
                           z_scale: 1.0,
                           fdwr_set: 'MAXIMIZE',
                           ssr_set: 'MAXIMIZE'
  )
    building_type =  model.getBuilding.standardsBuildingType.empty? ? "unknown" : model.getBuilding.standardsBuildingType.get
    model.getBuilding.setStandardsBuildingType("#{self.class.name}_#{building_type}")
    climate_zone = 'NECB HDD Method'

    # prototype generation.I'm current
    scale_model_geometry(model, x_scale, y_scale, z_scale) if x_scale != 1.0 || y_scale != 1.0 || z_scale != 1.0
    #validate that model has information required.
    puts 'Old SPace types'
    model.getSpaceTypes.each do |spacetype|
      puts spacetype.name
    end

    return false unless validate_initial_model(model)

    #Ensure that the space types names match the space types names in the code.
    return false unless validate_space_types(model)

    #puts Old SPace types
    puts 'new spacetypes'
    model.getSpaceTypes.each do |spacetype|
      puts spacetype.name
    end

    #Get rid of any existing Thermostats. We will only use the code schedules.
    model.getThermostatSetpointDualSetpoints(&:remove)

    #Set simulation start day to be consistent.
    model.yearDescription.get.setDayofWeekforStartDay('Sunday')

    #Set climate data.
    model_add_design_days_and_weather_file(model, climate_zone, epw_file) # Standards
    model_add_ground_temperatures(model, nil, climate_zone) # prototype candidate

    #Add Occ sensor schedule adjustments where needed.
    set_occ_sensor_spacetypes(model, @space_type_map)

    #Set Loads/Schedules
    model_add_loads(model)

    #Add Infiltration
    model_apply_infiltration_standard(model)

    #Modify_surface_convection_algorithm
    model.getInsideSurfaceConvectionAlgorithm.setAlgorithm('TARP')
    model.getOutsideSurfaceConvectionAlgorithm.setAlgorithm('TARP')

    #Add default constructions
    model_add_constructions(model)
    apply_standard_construction_properties(model)

    #Set up thermal zones for initial sizing run.
    model_create_thermal_zones(model, @space_multiplier_map)

    # Set FDWR and SSR.  Do this after the thermal zones are set because the methods need to know what walls and roofs
    # are adjacent to conditioned spaces.
    apply_standard_window_to_wall_ratio(model, fdwr_set: fdwr_set)
    apply_standard_skylight_to_roof_ratio(model, ssr_set: ssr_set)

    #Do a sizing run for HVAC now that all the loads have been defined.
    if model_run_sizing_run(model, "#{sizing_run_dir}/SR0") == false
      raise("sizing run 0 failed!")
    end

    # Create Reference HVAC Systems.
    model_add_hvac(model: model) # standards for NECB Prototype for NREL candidate
    model_add_swh(model)
    model_apply_sizing_parameters(model)

    # set a larger tolerance for unmet hours from default 0.2 to 1.0C
    model.getOutputControlReportingTolerances.setToleranceforTimeHeatingSetpointNotMet(1.0)
    model.getOutputControlReportingTolerances.setToleranceforTimeCoolingSetpointNotMet(1.0)

    #Do a second sizing run for the plant and loops.
    if model_run_sizing_run(model, "#{sizing_run_dir}/SR1") == false
      raise("sizing run 1 failed!")
    end

    # This is needed for NECB2011 as a workaround for sizing the reheat boxes
    model.getAirTerminalSingleDuctVAVReheats.each {|iobj| air_terminal_single_duct_vav_reheat_set_heating_cap(iobj)}
    # Apply the prototype HVAC assumptions
    # which include sizing the fan pressure rises based
    # on the flow rate of the system.
    model_apply_prototype_hvac_assumptions(model, nil, climate_zone)

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
    # Remove duplicate materials and constructions (currently commented out).
    # Commented out because it consumes a significant portion of the btap run time (30% - 50%).  The line below should
    # be uncommented when the flie clarity it affords is desired.
    # model = BTAP::FileIO::remove_duplicate_materials_and_constructions(model)
    return model
  end

  #this method will determine the vintage of NECB spacetypes the model contains. It will return nil if it can't
  # determine it.
  def determine_spacetype_vintage(model)
    #this code is the list of available vintages
    space_type_vintage_list = ['NECB2011', 'NECB2015', 'NECB2017']
    #this reorders the list to do the current class first.
    space_type_vintage_list.insert(0, space_type_vintage_list.delete(self.class.name))
    #Set the space_type
    space_type_vintage = nil
    # get list of space types used in model and a mapped string.
    model_space_type_names = model.getSpaceTypes.map do |spacetype|
      [spacetype.standardsBuildingType.get.to_s + '-' + spacetype.standardsSpaceType.get.to_s]
    end
    #Now iterate though each vintage
    space_type_vintage_list.each do |template|
      #Create the standard object and get a list of all the spacetypes available for that vintage.
      standard_space_type_list = Standard.build(template).get_all_spacetype_names.map {|spacetype| [spacetype[0].to_s + '-' + spacetype[1].to_s]}
      # set array to contain unknown spacetypes.
      unknown_spacetypes = []
      # iterate though all space types that the model is using
      model_space_type_names.each do |space_type_name|
        # push unknown spacetypes into the array.
        unknown_spacetypes << space_type_name unless standard_space_type_list.include?(space_type_name)
      end
      if unknown_spacetypes.empty?
        #No unknowns, so return the template and don't bother looking for others.
        return template
      end
    end
    return space_type_vintage
  end

  # This method will validate that the space types in the model are indeed the correct NECB spacetypes names.
  def validate_space_types(model)
    space_type_vintage = determine_spacetype_vintage(model)
    if space_type_vintage.nil?
      message = "These some of the spacetypes in the model are not part of any necb standard.\n  Please ensure all spacetype in model are correct."
      puts "Error: #{message}"
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Standards.NECB', message)
      return false
    elsif space_type_vintage == self.class.name
      # the spacetype in the model match the version we are trying to create.
      # no translation neccesary.
      return true
    else
      #Need to translate to current vintage.
      no_errors = true
      st_model_vintage_string = "#{space_type_vintage}_space_type"
      bt_model_vintage_string = "#{space_type_vintage}_building_type"
      st_target_vintage_string = "#{self.class.name}_space_type"
      bt_target_vintage_string = "#{self.class.name}_building_type"
      space_type_upgrade_map = standards_lookup_table_many(table_name: 'space_type_upgrade_map')
      model.getSpaceTypes.sort.each do |st|
        space_type_map = space_type_upgrade_map.detect {|row| (row[st_model_vintage_string] == st.standardsSpaceType.get.to_s) && (row[bt_model_vintage_string] == st.standardsBuildingType.get.to_s)}
        st.setStandardsBuildingType(space_type_map[bt_target_vintage_string].to_s.strip)
        raise('could not set buildingtype') unless st.setStandardsBuildingType(space_type_map[bt_target_vintage_string].to_s.strip)
        raise('could not set this') unless st.setStandardsSpaceType(space_type_map[st_target_vintage_string].to_s.strip)
        #Set name of spacetype to new name.
        st.setName("#{st.standardsBuildingType.get.to_s} #{st.standardsSpaceType.get.to_s}")
      end
      return no_errors
    end
  end

  def set_wildcard_schedules_to_dominant_building_schedule(model, runner = nil)
    new_sched_ruleset = OpenStudio::Model::DefaultScheduleSet.new(model) # initialize
    BTAP.runner_register('Info', 'set_wildcard_schedules_to_dominant_building_schedule', runner)
    # Set wildcard schedules based on dominant schedule type in building.
    dominant_sched_type = determine_dominant_necb_schedule_type(model)
    # puts "dominant_sched_type = #{dominant_sched_type}"
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
      # check to see if space space type has a "*" wildcard schedule.
      spacetype_name = space.spaceType.get.name.to_s unless space.spaceType.empty?
      if determine_necb_schedule_type(space).to_s == '*'.to_s
        new_sched = spacetype_name.to_s
        optional_spacetype = model.getSpaceTypeByName(new_sched)
        if optional_spacetype.empty?
          BTAP.runner_register('Error', "Cannot find NECB spacetype #{new_sched}", runner)
        else
          BTAP.runner_register('Info', "Setting wildcard spacetype #{spacetype_name} default schedule set to #{new_sched_ruleset.name}", runner)
          optional_spacetype.get.setDefaultScheduleSet(new_sched_ruleset) # this works!
        end
      end
    end # end of do |space|

    return true
  end

  # This model determines the dominant NECB schedule type
  # @param model [OpenStudio::model::Model] A model object
  # return s.each [String]
  def determine_dominant_necb_schedule_type(model)
    # lookup necb space type properties
    space_type_properties = @standards_data['space_types']

    # Here is a hash to keep track of the m2 running total of spacetypes for each
    # sched type.
    # 2018-04-11:  Not sure if this is still used but the list was expanded to incorporate additional existing or potential
    # future schedules.
    s = Hash[
        'A', 0,
        'B', 0,
        'C', 0,
        'D', 0,
        'E', 0,
        'F', 0,
        'G', 0,
        'H', 0,
        'I', 0,
        'J', 0,
        'K', 0,
        'L', 0,
        'M', 0,
        'N', 0,
        'O', 0,
        'P', 0,
        'Q', 0
    ]
    # iterate through spaces in building.
    wildcard_spaces = 0
    model.getSpaces.sort.each do |space|
      found_space_type = false
      # iterate through the NECB spacetype property table
      space_type_properties.each do |spacetype|
        unless space.spaceType.empty?
          if space.spaceType.get.standardsSpaceType.empty? || space.spaceType.get.standardsBuildingType.empty?
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.Standards.Model', "Space #{space.name} does not have a standardSpaceType defined")
            found_space_type = false
          elsif space.spaceType.get.standardsSpaceType.get == spacetype['space_type'] && space.spaceType.get.standardsBuildingType.get == spacetype['building_type']
            if spacetype['necb_schedule_type'] == '*'
              wildcard_spaces = +1
            else
              s[spacetype['necb_schedule_type']] = s[spacetype['necb_schedule_type']] + space.floorArea if (spacetype['necb_schedule_type'] != '*') && (spacetype['necb_schedule_type'] != '- undefined -')
            end
            # puts "Found #{space.spaceType.get.name} schedule #{spacetype[2]} match with floor area of #{space.floorArea()}"
            found_space_type = true
          elsif spacetype['necb_schedule_type'] != '*'
            # found wildcard..will not count to total.
            found_space_type = true
          end
        end
      end
      raise "Did not find #{space.spaceType.get.name} in NECB space types." if found_space_type == false
    end
    # finds max value and returns NECB schedule letter.
    raise('Only wildcard spaces in model. You need to define the actual spaces. ') if wildcard_spaces == model.getSpaces.size
    dominant_schedule = s.each {|k, v| return k.to_s if v == s.values.max}
    return dominant_schedule
  end

  # This method determines the spacetype schedule type. This will re
  # @author phylroy.lopez@nrcan.gc.ca
  # @param space [String]
  # @return [String]:["A","B","C","D","E","F","G","H","I"] spacetype
  def determine_necb_schedule_type(space)
    spacetype_data = standards_lookup_table_many(table_name: 'space_types')
    raise "Spacetype not defined for space #{space.get.name}) if space.spaceType.empty?" if space.spaceType.empty?
    raise "Undefined standardsSpaceType or StandardsBuildingType for space #{space.spaceType.get.name}) if space.spaceType.empty?" if space.spaceType.get.standardsSpaceType.empty? | space.spaceType.get.standardsBuildingType.empty?
    space_type_properties = spacetype_data.detect {|st| (st['space_type'] == space.spaceType.get.standardsSpaceType.get) && (st['building_type'] == space.spaceType.get.standardsBuildingType.get)}
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
    infiltration_data = @standards_data['infiltration']
    unless space.spaceType.empty?
      space.spaceType.get.spaceInfiltrationDesignFlowRates.each(&:remove)
    end
    # Remove infiltration rates set at the space object.
    space.spaceInfiltrationDesignFlowRates.each(&:remove)

    exterior_wall_and_roof_and_subsurface_area = space_exterior_wall_and_roof_and_subsurface_area(space) # To do
    # Don't create an object if there is no exterior wall area
    if exterior_wall_and_roof_and_subsurface_area <= 0.0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.Model', "For #{template}, no exterior wall area was found, no infiltration will be added.")
      return true
    end
    # Calculate the total infiltration, assuming
    # that it only occurs through exterior walls and roofs (not floors as
    # explicit stated in the NECB2011 so overhang/cantilevered floors will
    # have no effective infiltration)
    tot_infil_m3_per_s = self.get_standards_constant('infiltration_rate_m3_per_s_per_m2') * exterior_wall_and_roof_and_subsurface_area
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
    infiltration.setConstantTermCoefficient(self.get_standards_constant('infiltration_constant_term_coefficient'))
    infiltration.setTemperatureTermCoefficient(self.get_standards_constant('infiltration_constant_term_coefficient'))
    infiltration.setVelocityTermCoefficient(self.get_standards_constant('infiltration_velocity_term_coefficient'))
    infiltration.setVelocitySquaredTermCoefficient(self.get_standards_constant('infiltration_velocity_squared_term_coefficient'))
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

        # Check if space type for this space matches NECB2011 specific space type
        # for occupancy sensor that is area dependent. Note: space.floorArea in m2.

        #Evaluate the formula in the database.
        standard_space_type_name = space_type_name
        floor_area = space.floorArea
        if eval(@standards_data['formulas']['occupancy_sensors_space_types_formula']['value'])
          # If there is only one space assigned to this space type, then reassign this stub
          # to the @@template duplicate with appendage " - occsens", otherwise create a new stub
          # for this space. Required to use reduced LPD by NECB2011 0.9 factor.
          space_type_name_occsens = space_type_name + ' - occsens'
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

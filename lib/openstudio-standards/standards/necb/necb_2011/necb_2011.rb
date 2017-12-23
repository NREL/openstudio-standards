# This class holds methods that apply NECB 2011 rules.
# @ref [References::NECB2011]
require 'rubyXL'
class NECB2011 < Standard
  @@template = 'NECB 2011' # rubocop:disable Style/ClassVars
  register_standard @@template
  attr_reader :template

  def initialize
    super()
    @template = @@template
    load_standards_database
    @necb_standards_data = Hash.new

    # Load NECB data files.
    ['necb_2015_table_c1.json',
     'regional_fuel_use.json',
     'surface_thermal_transmittance.json'
    ].each do |file|
      file = "#{File.dirname(__FILE__)}/data/#{file}"
      @necb_standards_data = @necb_standards_data.merge (JSON.parse(File.read(file)))
    end


    @necb_standards_data['fdwr_formula'] = {
        'data_type' => 'formula',
        'refs' => ['NECB2011_S_3.2.1.4(1)'],
        'formula_variable_ranges' => {
            'hdd' => [0.0, 10000.0]
        },
        'formula' => "( hdd < 4000.0) ? 0.4 : ( hdd >= 4000.0 and hdd < 7000.0 ) ? ( (2000.0 - 0.2 * hdd) / 3000.00) : 0.2;",
        'units' => 'ratio',
        'notes' => 'Requires hdd to be defined to be evaluated in code.'
    }

    @necb_standards_data['skylight_to_roof_ratio_max_value'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_3.2.1.4(2)'],
        'value' => 0.05,
        'units' => 'ratio'
    }

    @necb_standards_data['sizing_factor_max_cooling'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_8.4.4.9(1)'],
        'unit' => 'ratio',
        'value' => 1.10
    }

    @necb_standards_data['sizing_factor_max_heating'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_8.4.4.9(2)'],
        'unit' => 'ratio',
        'value' => 1.30
    }


    @necb_standards_data['occupancy_sensors_space_types_formula'] = {
        'data_type' => 'formula',
        'refs' => ['NECB2011_S_8.4.4.6(3)'],
        'formula_variable_ranges' => {
            'standard_space_type_name' => ["String"],
            'floor_area' => [0.0, 9999999999.9]
        },
        'formula' => " ( [ 'Storage area','Storage area - refrigerated','Hospital - medical supply'].include?(standard_space_type_name) and floor_area < 100.0) or ( 'Office - enclosed' == standard_space_type_name and floor_area < 25.0) ? true : false ",
        'units' => 'bool',
        'notes' => ''
    }

    #Fan Information
    @necb_standards_data['fan_constant_volume_pressure_rise_value'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_5.Assumption'],
        'value' => 640.00,
        'units' => 'Pa'
    }

    @necb_standards_data['fan_variable_volume_pressure_rise_value'] = {
        'data_type' => 'value',
        'ref' => ['NECB2011_S_5.Assumption'],
        'value' => 1458.33,
        'units' => 'Pa',
        'notes' => 'Sets the fan pressure rise based on the Prototype buildings inputs which are governed by the flow rate coming through the fan and whether the fan lives inside a unit heater, PTAC, etc. 1000 Pa for supply fan and 458.33 Pa for return fan (accounts for efficiency differences between two fans)'
    }


    # NECB Infiltration rate information for standard.
    @necb_standards_data['infiltration_rate_m3_per_s_per_m2'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_5.Assumption'],
        'value' => 0.25 * 0.001, # m3/s/m2,
        'units' => 'm3/s/m2',
        'notes' => ''
    }

    @necb_standards_data['infiltration_constant_term_coefficient'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_5.Assumption'],
        'value' => 0.00,
        'units' => '',
        'notes' => ''
    }
    @necb_standards_data['infiltration_temperature_term_coefficient'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_5.Assumption'],
        'value' => 0.00,
        'units' => '',
        'notes' => ''
    }
    @necb_standards_data['infiltration_velocity_term_coefficient'] = {
        'data_type' => 'value',
        'refs' => ['Assumption'],
        'value' => 0.224,
        'units' => '',
        'notes' => ''
    }
    @necb_standards_data['infiltration_velocity_squared_term_coefficient'] = {
        'data_type' => 'value',
        'refs' => ['Assumption'],
        'value' => 0.00,
        'units' => '',
        'notes' => ''
    }

    @necb_standards_data['skylight_to_roof_ratio'] = {
        'data_type' => 'value',
        'refs' => ['NECB2011_S_3.2.1.4(2)'],
        'value' => 0.05,
        'units' => '',
        'notes' => ''
    }

    @necb_standards_data['necb_hvac_system_selection_type'] = {
        'data_type' => 'table',
        'table' => [
            {'necb_hvac_system_selection_type' => '- undefined -', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 0, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Assembly Area', 'min_stories' => 0, 'max_stories' => 4, 'max_cooling_capacity_kw' => 99999, 'system_type' => 3, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Assembly Area', 'min_stories' => 4, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 6, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Automotive Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 4, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Data Processing Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 19.999, 'system_type' => 1, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Data Processing Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 2, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'General Area', 'min_stories' => 2, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 3, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'General Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 6, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Historical Collections Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 2, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Hospital Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 3, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Indoor Arena', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 7, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Industrial Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 3, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Residential/Accomodation Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 1, 'dwelling' => true},
            {'necb_hvac_system_selection_type' => 'Sleeping Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 3, 'dwelling' => true},
            {'necb_hvac_system_selection_type' => 'Supermarket/Food Services Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 3, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Supermarket/Food Services Area - vented', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 4, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Warehouse Area', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 4, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Warehouse Area - refrigerated', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => 5, 'dwelling' => false},
            {'necb_hvac_system_selection_type' => 'Wildcard', 'min_stories' => 0, 'max_stories' => 99999, 'max_cooling_capacity_kw' => 99999, 'system_type' => nil, 'dwelling' => false}
        ]
    }




    @necb_standards_data['schedules'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['schedules'].select {|s| s['name'].to_s.match(/NECB.*/)}
    }

    @necb_standards_data['schedules']['table'] << JSON.parse('{
        "name": "Always On",
        "category": "Unknown",
        "units": null,
        "day_types": "Default",
        "start_date": "2014-01-01T00:00:00+00:00",
        "end_date": "2014-12-31T00:00:00+00:00",
        "type": "Constant",
        "notes": null,
        "values": [
            1.0
        ]
    }')



    @necb_standards_data['materials'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['materials']
    }
    @necb_standards_data['constructions'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['constructions']
    }

    @necb_standards_data['construction_sets'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['construction_sets'].select {|s| s['template'].to_s.match(/NECB.*/)}
    }

    @necb_standards_data['constructions'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['constructions']
    }

    @necb_standards_data['construction_properties'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['construction_properties'].select {|s| s['template'].to_s.match(/NECB.*/)}
    }


    @necb_standards_data['space_types'] ={
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['space_types'].select {|s| s['template'].to_s.match(/NECB.*/)}
    }



    @necb_standards_data['boilers'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['boilers'].select {|s| s['template'].to_s.match(/NECB.*/)}
    }


    @necb_standards_data['chillers'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['chillers'].select {|s| s['template'].to_s.match(/NECB.*/)}
    }




    @necb_standards_data['heat_pumps'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['heat_pumps'].select {|s| s['template'].to_s.match(/NECB.*/)}
    }

    @necb_standards_data['heat_pumps_heating'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['heat_pumps_heating'].select {|s| s['template'].to_s.match(/NECB.*/)}
    }

    #Need to trim this one
    @necb_standards_data['heat_rejection'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['heat_rejection']
    }

    @necb_standards_data['unitary_acs'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['unitary_acs'].select {|s| s['template'].to_s.match(/NECB.*/)}
    }



    @necb_standards_data['motors'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['motors'].select {|s| s['template'].to_s.match(/NECB.*/)}
    }

    @necb_standards_data['curves'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['curves'].select {|s| s['name'].to_s.match(/NECB.*/)}
    }
    @necb_standards_data['prototype_inputs'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['prototype_inputs']
    }

    @necb_standards_data['ground_temperatures'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['ground_temperatures']
    }

    @necb_standards_data['climate_zone_sets'] = {
        'data_type' => 'table',
        'refs' => ["assumption"],
        'table' => @standards_data['climate_zone_sets'].select {|s| s['name'].to_s.match(/NECB.*/)}
    }


    @standards_data = @necb_standards_data

    #File.write('/home/osdev/openstudio-standards/data/necb.json',(JSON.pretty_generate(@necb_standards_data)))
  end


  # Enter in [latitude, longitude] for each loc and this method will return the distance.
  def distance(loc1, loc2)
    rad_per_deg = Math::PI/180 # PI / 180
    rkm = 6371 # Earth radius in kilometers
    rm = rkm * 1000 # Radius in meters

    dlat_rad = (loc2[0]-loc1[0]) * rad_per_deg # Delta, converted to rad
    dlon_rad = (loc2[1]-loc1[1]) * rad_per_deg

    lat1_rad, lon1_rad = loc1.map {|i| i * rad_per_deg}
    lat2_rad, lon2_rad = loc2.map {|i| i * rad_per_deg}

    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math::atan2(Math::sqrt(a), Math::sqrt(1-a))
    rm * c # Delta in meters
  end

  # this method returns the default system fuel types by epw_file.
  def get_canadian_system_defaults_by_weatherfile_name(model)
    #get models weather object to get the province. Then use that to look up the province.
    epw = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get)
    fuel_sources = @standards_data["regional_fuel_use"]["table"].detect {|fuel_sources| fuel_sources['state_province_regions'].include?(epw.state_province_region)}
    raise() if fuel_sources.nil? #this should never happen since we are using only canadian weather files.
    return fuel_sources
  end

  def get_necb_hdd18(model)
    max_distance_tolerance = 500000
    min_distance = 100000000000000.0
    necb_closest = nil
    epw = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get)
    @standards_data['necb_2015_table_c1']['table'].each do |necb|
      next if necb['lat_long'].nil? #Need this until Tyson cleans up table.
      dist = distance([epw.latitude.to_f, epw.longitude.to_f], necb['lat_long'])
      if min_distance > dist
        min_distance = dist
        necb_closest = necb
      end
    end
    if (min_distance / 1000.0) > max_distance_tolerance and not epw.hdd18.nil?
      puts "Could not find close NECB HDD from Table C1 < #{max_distance_tolerance}km. Closest city is #{min_distance/1000.0}km away. Using epw hdd18 instead."
      return epw.hdd18.to_f
    else
      puts "INFO:NECB HDD18 of #{necb_closest['degree_days_below_18_c'].to_f}  at nearest city #{necb_closest['city']},#{necb_closest['province']}, at a distance of #{'%.2f' % (min_distance/1000.0)}km from epw location. Ref:necb_2015_table_c1"
      return necb_closest['degree_days_below_18_c'].to_f
    end
  end


  def model_create_prototype_model(climate_zone, epw_file, sizing_run_dir = Dir.pwd, debug = false, measure_model = nil)
    building_type = @instvarbuilding_type
    raise 'no building_type!' if @instvarbuilding_type.nil?
    model = nil
    # prototype generation.
    model = load_initial_osm(@geometry_file) # standard candidate
    model.getThermostatSetpointDualSetpoints(&:remove)
    model.yearDescription.get.setDayofWeekforStartDay('Sunday')
    model_add_design_days_and_weather_file(model, climate_zone, epw_file) # Standards
    model_add_ground_temperatures(model, @instvarbuilding_type, climate_zone) # prototype candidate
    model.getBuilding.setName(self.class.to_s)
    model.getBuilding.setName("-#{@instvarbuilding_type}-#{climate_zone}-#{epw_file} created: #{Time.new}")
    set_occ_sensor_spacetypes(model, @space_type_map)
    model_add_loads(model) # standards candidate
    model_apply_infiltration_standard(model) # standards candidate
    model_modify_surface_convection_algorithm(model) # standards
    model_add_constructions(model, @instvarbuilding_type, climate_zone) # prototype candidate
    apply_standard_construction_properties(model) # standards candidate
    apply_standard_window_to_wall_ratio(model) # standards candidate
    apply_standard_skylight_to_roof_ratio(model) # standards candidate
    model_create_thermal_zones(model, @space_multiplier_map) # standards candidate
    # For some building types, stories are defined explicitly

    if model_run_sizing_run(model, "#{sizing_run_dir}/SR0") == false
      raise( "sizing run 0 failed!")
    end
    # Create Reference HVAC Systems.
    model_add_hvac(model, epw_file) # standards for NECB Prototype for NREL candidate
    model_add_swh(model, @instvarbuilding_type, climate_zone, @prototype_input, epw_file)
    model_apply_sizing_parameters(model)

    # set a larger tolerance for unmet hours from default 0.2 to 1.0C
    model.getOutputControlReportingTolerances.setToleranceforTimeHeatingSetpointNotMet(1.0)
    model.getOutputControlReportingTolerances.setToleranceforTimeCoolingSetpointNotMet(1.0)
    if model_run_sizing_run(model, "#{sizing_run_dir}/SR1") == false
      raise( "sizing run 1 failed!")
    end

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
    # If measure model is passed, then replace measure model with new model created here.
    if measure_model.nil?
      return model
    else
      model_replace_model(measure_model, model)
      return measure_model
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
    s = Hash[
        'A', 0,
        'B', 0,
        'C', 0,
        'D', 0,
        'E', 0,
        'F', 0,
        'G', 0,
        'H', 0,
        'I', 0
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
    spacetype_data = nil
    if @standards_data['space_types'].is_a?(Hash) == true
      spacetype_data = @standards_data['space_types']['table']
    else
      spacetype_data = @standards_data['space_types']
    end
    raise "Undefined spacetype for space #{space.get.name}) if space.spaceType.empty?" if space.spaceType.empty?
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
    # explicit stated in the NECB 2011 so overhang/cantilevered floors will
    # have no effective infiltration)
    tot_infil_m3_per_s = @standards_data['infiltration_rate_m3_per_s_per_m2']['value'] * exterior_wall_and_roof_and_subsurface_area
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
    infiltration.setConstantTermCoefficient(@standards_data['infiltration_constant_term_coefficient']['value'])
    infiltration.setTemperatureTermCoefficient(@standards_data['infiltration_constant_term_coefficient']['value'])
    infiltration.setVelocityTermCoefficient(@standards_data['infiltration_velocity_term_coefficient']['value'])
    infiltration.setVelocitySquaredTermCoefficient(@standards_data['infiltration_velocity_squared_term_coefficient']['value'])
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

        # Check if space type for this space matches NECB 2011 specific space type
        # for occupancy sensor that is area dependent. Note: space.floorArea in m2.

        if (space_type_name == 'Storage area' && space.floorArea < 100) ||
            (space_type_name == 'Storage area - refrigerated' && space.floorArea < 100) ||
            (space_type_name == 'Hospital - medical supply' && space.floorArea < 100) ||
            (space_type_name == 'Office - enclosed' && space.floorArea < 25)
          # If there is only one space assigned to this space type, then reassign this stub
          # to the @@template duplicate with appendage " - occsens", otherwise create a new stub
          # for this space. Required to use reduced LPD by NECB 2011 0.9 factor.
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

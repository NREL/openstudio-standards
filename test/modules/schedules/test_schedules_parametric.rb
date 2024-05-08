require_relative '../../helpers/minitest_helper'

class TestSchedulesParametric < Minitest::Test

  def setup
    # setup test output dirs
    @test_dir = File.expand_path("#{__dir__}/output/")
    if !Dir.exist?(@test_dir)
      Dir.mkdir(@test_dir)
    end

    # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Debug)
    # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Info)
    OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Warn)

    # initialize namespace members
    @weather = OpenstudioStandards::Weather
    @sch = OpenstudioStandards::Schedules
    @spaces = OpenstudioStandards::Space
  end

  def get_additional_properties(props)
    # puts "Additional property for object #{props.modelObject.name.get}"
    prop_strings = []
    props.featureNames.each do |name|
      if props.hasFeature(name)
        feature_type = props.getFeatureDataType(name).to_s
        feature = nil
        case feature_type
        when 'Integer'
          feature = props.getFeatureAsInteger(name).get
        when 'Double'
          feature = props.getFeatureAsDouble(name).get
        when 'String'
          feature = props.getFeatureAsString(name).get
        when 'Boolean'
          feature = props.getFeatureAsBoolean(name).get
        end
        prop_strings << "Object: #{props.modelObject.name.get} - Property: #{name} - Value: #{feature.to_s}"
      else
        # puts "No value found for property: #{name}"
      end
    end
    return prop_strings
  end

  def test_model_infer_building_hours_of_operation
    # create model
    model = OpenStudio::Model::Model.new
    model.getYearDescription.setCalendarYear(2018)

    # make schedules with gaps
    sch1_opts = {
      'name' => 'People Schedule 1',
      'default_time_value_pairs' => { 8.0 => 0, 12.0 => 0.8, 13.0 => 0.0, 18.0 => 0.8, 24.0 => 0.0}
    }
    ppl_sch1 = @sch.create_simple_schedule(model, sch1_opts)
    # puts OpenStudio::Model.getRecursiveChildren(ppl_sch1)
    # create space and people loads
    space1 = OpenStudio::Model::Space.new(model)
    ppl_def1 = OpenStudio::Model::PeopleDefinition.new(model)
    ppl_def1.setNumberofPeople(10)
    ppl1 = OpenStudio::Model::People.new(ppl_def1)
    ppl1.setNumberofPeopleSchedule(ppl_sch1)
    ppl1.setSpace(space1)

    # hoo_sch = @spaces.spaces_get_occupancy_schedule([space1], sch_name: 'test occupancy daily', occupied_percentage_threshold: 0.25, threshold_calc_method: 'normalized_daily_range' )
    # puts OpenStudio::Model.getRecursiveChildren(hoo_sch)

    hours_of_operation_schedule = @sch.model_infer_hours_of_operation_building(model)
    # puts OpenStudio::Model.getRecursiveChildren(hours_of_operation_schedule)

    hoo_default_vals = @sch.schedule_day_get_hourly_values(hours_of_operation_schedule.defaultDaySchedule)
    p hoo_default_vals
    assert_equal(8, hoo_default_vals.index(1.0))
    assert_equal(17, hoo_default_vals.rindex(1.0))
    assert_equal(10, hoo_default_vals.sum)
    assert_equal(model.getBuilding.defaultScheduleSet.get.hoursofOperationSchedule.get, hours_of_operation_schedule)
  end

  def test_schedule_ruleset_get_parametric_inputs
    model = OpenStudio::Model::Model.new
    model.getYearDescription.setCalendarYear(2018)

    sch_opts = {
      'name' => 'People Schedule',
      'default_day' => ['default', [8.0, 0], [18.0, 0.8], [24.0, 0.0]],
      'rules' => [['weekends', '1/1-12/31', 'Sat/Sun',  [24.0, 0]]]
    }
    ppl_sch = @sch.create_complex_schedule(model, sch_opts)
    space = OpenStudio::Model::Space.new(model)
    ppl_def = OpenStudio::Model::PeopleDefinition.new(model)
    ppl_def.setNumberofPeople(10)
    ppl = OpenStudio::Model::People.new(ppl_def)
    ppl.setNumberofPeopleSchedule(ppl_sch)
    ppl.setSpace(space)

    # test schedule w/ matching rules
    lgt_opts = {
      'name' => 'Lighting Schedule',
      'default_day' => ['default', [8.0, 0.1], [10.0, 0.3], [12.0, 0.8], [16.0, 1.0], [22.0, 0.7], [24.0, 0.1]],
      'rules' => [['weekends', '1/1-12/31', 'Sat/Sun',  [24.0, 0.2]]]
    }
    lght_sch = @sch.create_complex_schedule(model, lgt_opts)
    lght_def = OpenStudio::Model::LightsDefinition.new(model)
    lght_def.setLightingLevel(1000)
    lght = OpenStudio::Model::Lights.new(lght_def)
    lght.setSchedule(lght_sch)

    # test schedule rules not match
    clg_opts = {
      'name' => 'Cooling',
      'default_time_value_pairs' => { 8.0 => 23.3, 18.0 => 21.1, 24.0 => 23.3}
    }
    clg_sch = @sch.create_simple_schedule(model, clg_opts)

    @sch.model_infer_hours_of_operation_building(model)
    hours_of_operation = @spaces.spaces_hours_of_operation(model.getSpaces)

    parametric_inputs = @sch.schedule_ruleset_get_parametric_inputs(lght_sch, lght, {}, hours_of_operation, ramp:true, min_ramp_dur_hr: 2.0, gather_data_only: false, hoo_var_method: 'hours')

    parametric_inputs = @sch.schedule_ruleset_get_parametric_inputs(clg_sch, nil, {}, hours_of_operation, ramp: true, min_ramp_dur_hr: 2.0, gather_data_only: false, hoo_var_method: 'hours')

    # collect additional properties
    props = get_additional_properties(lght_sch.defaultDaySchedule.additionalProperties)
    lght_sch.scheduleRules.each {|obj| props += get_additional_properties(obj.daySchedule.additionalProperties)}

    # test formulas individually
    lght_def_prop = get_additional_properties(lght_sch.defaultDaySchedule.additionalProperties)
    def_param_profile = lght_def_prop.select { |prop| prop.include?('param_day_profile') }.first
    assert(def_param_profile.include?('hoo_start'), "#{lght_sch.defaultDaySchedule.name.get} missing hoo_start: #{lght_def_prop}")
    assert(def_param_profile.include?('hoo_end'), "#{lght_sch.defaultDaySchedule.name.get} missing hoo_end: #{lght_def_prop}")
    lght_wknd_prop = get_additional_properties(lght_sch.scheduleRules.first.daySchedule.additionalProperties)
    wkdn_param_profile = lght_wknd_prop.select { |prop| prop.include?('param_day_profile') }.first
    assert(wkdn_param_profile.include?('hoo_start'), "#{lght_sch.scheduleRules.first.daySchedule.name.get} missing hoo_start: #{lght_def_prop}")

    props += get_additional_properties(clg_sch.defaultDaySchedule.additionalProperties)
    clg_sch.scheduleRules.each {|obj| props += get_additional_properties(obj.daySchedule.additionalProperties)}

    # test formulas individually
    clg_def_prop = get_additional_properties(clg_sch.defaultDaySchedule.additionalProperties)
    def_param_profile = clg_def_prop.select { |prop| prop.include?('param_day_profile') }.first
    assert(def_param_profile.include?('hoo_start'), "#{clg_sch.defaultDaySchedule.name.get} missing hoo_start: #{clg_def_prop}")
    assert(def_param_profile.include?('hoo_end'), "#{clg_sch.defaultDaySchedule.name.get} missing hoo_end: #{clg_def_prop}")
    clg_wknd_prop = get_additional_properties(clg_sch.scheduleRules.first.daySchedule.additionalProperties)
    wknd_param_profile = clg_wknd_prop.select { |prop| prop.include? ('param_day_profile' ) }.first
    assert(wknd_param_profile.include?('hoo_start +'), "#{clg_sch.scheduleRules.first.daySchedule.name.get} missing hoo_start: #{clg_wknd_prop}")
    assert(wknd_param_profile.include?('hoo_start -'), "#{clg_sch.scheduleRules.first.daySchedule.name.get} missing hoo_end: #{clg_wknd_prop}")
  end

  def test_schedule_ruleset_apply_parametric_inputs
    model = OpenStudio::Model::Model.new
    model.getYearDescription.setCalendarYear(2018)

    sch_opts = {
      'name' => 'People Schedule',
      'default_day' => ['default', [8.0, 0], [18.0, 0.8], [24.0, 0.0]],
      'rules' => [['weekends', '1/1-12/31', 'Sat/Sun',  [12.0, 0], [14.0, 1], [24.0, 0]]]
    }
    ppl_sch = @sch.create_complex_schedule(model, sch_opts)
    space = OpenStudio::Model::Space.new(model)
    ppl_def = OpenStudio::Model::PeopleDefinition.new(model)
    ppl_def.setNumberofPeople(10)
    ppl = OpenStudio::Model::People.new(ppl_def)
    ppl.setNumberofPeopleSchedule(ppl_sch)
    ppl.setSpace(space)

    op_sch = @sch.model_infer_hours_of_operation_building(model)

    @sch.model_setup_parametric_schedules(model, hoo_var_method: 'hours')

    wkdy_start_time = OpenStudio::Time.new(0,7,0,0)
    wkdy_end_time = OpenStudio::Time.new(0,20,0,0)
    wknd_start_time = OpenStudio::Time.new(0,10,0,0)
    wknd_end_time = OpenStudio::Time.new(0,14,0,0)
    hours_of_operation_schedule = OpenStudio::Model::ScheduleRuleset.new(model)
    wknd_rule = OpenStudio::Model::ScheduleRule.new(hours_of_operation_schedule)
    wknd_rule.setApplyWeekends(true)

    @sch.schedule_ruleset_set_hours_of_operation(op_sch,
                                                 wkdy_start_time: wkdy_start_time,
                                                 wkdy_end_time: wkdy_end_time,
                                                 sat_start_time: wknd_start_time,
                                                 sat_end_time: wknd_end_time,
                                                 sun_start_time: wknd_start_time,
                                                 sun_end_time: wknd_end_time)

    parametric_inputs = @sch.model_setup_parametric_schedules(model, gather_data_only: true)

    ramp_frequency = 1.0 / 4
    infer_hoo_for_non_assigned_objects = true
    error_on_out_of_order = false
    ppl_sch = @sch.schedule_ruleset_apply_parametric_inputs(ppl_sch, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order, parametric_inputs)

    default_vals = @sch.schedule_day_get_hourly_values(ppl_sch.defaultDaySchedule)
    assert_equal(7, default_vals.index(0.8))
    assert_equal(19, default_vals.rindex(0.8))
    weekend_vals = @sch.schedule_day_get_hourly_values(ppl_sch.scheduleRules.first.daySchedule)
    assert_equal(10, weekend_vals.index(1))
    assert_equal(13, weekend_vals.rindex(1))
  end

  def create_simple_comstock_model_with_schedule_mod(type, wkdy_start, wkdy_dur, wknd_start, wknd_dur)
    puts "-------------------------------------------------------------"
    puts type

    template = 'ComStock DOE Ref 1980-2004'
    climate_zone = 'ASHRAE 169-2013-5B'

    # create_bar
    bar_args = {
      climate_zone: climate_zone,
      bldg_type_a: type,
      bldg_subtype_a: 'largeoffice_default',
      bldg_type_a_num_units: 1,
      bldg_type_b: 'SecondarySchool',
      bldg_subtype_b: 'NA',
      bldg_type_b_fract_bldg_area: 0,
      bldg_type_b_num_units: 1,
      bldg_type_c: 'SecondarySchool',
      bldg_subtype_c: 'NA',
      bldg_type_c_fract_bldg_area: 0,
      bldg_type_c_num_units: 1,
      bldg_type_d: 'SecondarySchool',
      bldg_subtype_d: 'NA',
      bldg_type_d_fract_bldg_area: 0,
      bldg_type_d_num_units: 1,
      num_stories_below_grade: 0,
      num_stories_above_grade: 1,
      story_multiplier: 'None',
      bar_division_method: 'Multiple Space Types - Individual Stories Sliced',
      bottom_story_ground_exposed_floor: true,
      top_story_exterior_exposed_roof: true,
      make_mid_story_surfaces_adiabatic: true,
      total_bldg_floor_area: 15000,
      wwr: 0.38,
      ns_to_ew_ratio: 3,
      perim_mult: 0.0,
      bar_width: 0.0,
      bar_sep_dist_mult: 10.0,
      building_rotation: 0.0,
      template: template,
      custom_height_bar: true,
      floor_height: 0.0,
      party_wall_fraction: 0.0,
      party_wall_stories_north: 0,
      party_wall_stories_south: 0,
      party_wall_stories_east: 0,
      party_wall_stories_west: 0,
      double_loaded_corridor: 'Primary Space Type',
      space_type_sort_logic: 'Building Type > Size',
      single_floor_area: 0
    }
    @model = OpenStudio::Model::Model.new
    OpenstudioStandards::Geometry.create_bar_from_building_type_ratios(@model, bar_args)

    # simulation settings
    dst_control = @model.getRunPeriodControlDaylightSavingTime
    dst_control.setStartDate('2nd Sunday in March')
    dst_control.setEndDate('1st Sunday in November')

    # set timestep
    timestep = @model.getTimestep
    timestep.setNumberOfTimestepsPerHour(4)

    # run period
    run_period = @model.getRunPeriod
    run_period.setBeginMonth(1)
    run_period.setBeginDayOfMonth(1)
    run_period.setEndMonth(12)
    run_period.setEndDayOfMonth(31)

    # calendar year
    yr_desc = @model.getYearDescription
    yr_desc.setCalendarYear(2018)

    # weather file
    weather_file_name = "USA_ID_Boise.Air.Terminal.726810_TMY3.epw"
    weather_file_path = @weather.get_standards_weather_file_path(weather_file_name)
    @weather.model_set_building_location(@model, weather_file_path: weather_file_path, ddy_list: nil)

    orig_dir = Dir.pwd
    Dir.chdir(File.join((__dir__), '/output'))

    # create_typical with schedule modification, no hvac
    OpenstudioStandards::CreateTypical.create_typical_building_from_model(@model,
                                                                          template,
                                                                          climate_zone: climate_zone,
                                                                          wkdy_op_hrs_start_time: wkdy_start,
                                                                          wkdy_op_hrs_duration: wkdy_dur,
                                                                          wknd_op_hrs_start_time: wknd_start,
                                                                          wknd_op_hrs_duration: wknd_dur,
                                                                          modify_wkdy_op_hrs: true,
                                                                          modify_wknd_op_hrs: true,
                                                                          add_hvac: false,
                                                                          add_elevators: false
                                                                          )

    Dir.chdir(orig_dir)
  end

  def test_comstock_schedule_mod
    puts "\n######\nTEST:#{__method__}\n######\n"

    run_dir = "#{@test_dir}/schedules_modified"

    types = []
    types << 'SecondarySchool'
    types << 'PrimarySchool'
    types << 'SmallOffice'
    types << 'MediumOffice'
    types << 'LargeOffice'
    types << 'SmallHotel'
    types << 'LargeHotel'
    types << 'Warehouse'
    types << 'RetailStandalone'
    types << 'RetailStripmall'
    types << 'QuickServiceRestaurant'
    types << 'FullServiceRestaurant'
    types << 'Hospital'
    types << 'Outpatient'

    types.each do |type|
      create_simple_comstock_model_with_schedule_mod(type, 8.0, 12.0, 10.0, 6.0)

      osm_path = "#{run_dir}/#{type}_modified.osm"
      # assert(@model.save(osm_path, true))

      # get thermostat schedules
      tstat_schedules = []
      @model.getThermostatSetpointDualSetpoints.each do |tstat|
        next if tstat.coolingSetpointTemperatureSchedule.empty? || tstat.heatingSetpointTemperatureSchedule.empty?
        clg_sch = tstat.coolingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get
        htg_sch = tstat.heatingSetpointTemperatureSchedule.get.to_ScheduleRuleset.get
        tstat_schedules << clg_sch unless tstat_schedules.include?(clg_sch)
        tstat_schedules << htg_sch unless tstat_schedules.include?(clg_sch)
      end

      day_schedules = []
      tstat_schedules.each do |sch_rule|
        day_schedules << sch_rule.defaultDaySchedule
      end

      # building hour of operation schedule
      default_op_sch = @model.getBuilding.getDefaultSchedule(OpenStudio::Model::DefaultScheduleType.new('HoursofOperationSchedule')).get.to_ScheduleRuleset.get
      op_times = default_op_sch.defaultDaySchedule.times.map(&:to_s)

      # only test that default days match
      day_schedules.each do |day_sch|
        times = day_sch.times.map(&:to_s)
        assert(op_times.to_set.superset?(times.to_set), "For #{type}, expected #{op_times} to include times from thermostat schedule #{day_sch.name.get}: #{times}")
      end
    end
  end
end



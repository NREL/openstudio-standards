require_relative '../../helpers/minitest_helper'

class TestSchedulesParametric < Minitest::Test

  def setup
    # setup test output dirs
    @test_dir = File.expand_path("#{__dir__}/output/")
    if !Dir.exists?(@test_dir)
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
    puts OpenStudio::Model.getRecursiveChildren(hours_of_operation_schedule)

    hoo_default_vals = @sch.schedule_day_get_hourly_values(hours_of_operation_schedule.defaultDaySchedule)
    p hoo_default_vals
    assert_equal(hoo_default_vals.index(1.0), 8)
    assert_equal(hoo_default_vals.rindex(1.0), 17)
    assert_equal(hoo_default_vals.sum, 10)
    assert_equal(model.getBuilding.defaultScheduleSet.get.hoursofOperationSchedule.get, hours_of_operation_schedule)

  end

  def test_gather_inputs_parametric_schedules
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

    parametric_inputs = @sch.gather_inputs_parametric_schedules(lght_sch, lght, {}, hours_of_operation, ramp:true, min_ramp_dur_hr: 2.0, gather_data_only: false, hoo_var_method: 'hours')

    # this will create additional properties which do not pass the assertions
    # fixme: refactor method so that schedules with rules that don't match hours_of_operation will pass
    # parametric_inputs = @sch.gather_inputs_parametric_schedules(clg_sch, nil, {}, hours_of_operation, ramp: true, min_ramp_dur_hr: 2.0, gather_data_only: false, hoo_var_method: 'hours')

    # collect additional properties
    props = get_additional_properties(lght_sch.defaultDaySchedule.additionalProperties)
    lght_sch.scheduleRules.each {|obj| props + get_additional_properties(obj.daySchedule.additionalProperties)}
    props + get_additional_properties(clg_sch.defaultDaySchedule.additionalProperties)
    clg_sch.scheduleRules.each {|obj| props + get_additional_properties(obj.daySchedule.additionalProperties)}

    # test that add'props have tags to modify the schedules
    props.select{|p| p.include? 'param_day_profile'}.each do |formula|
      assert(formula.include?('hoo_start'), "missing hoo_start: #{formula}")
      assert(formula.include?('hoo_end'), "missing hoo_end: #{formula}")
    end
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
    assert_equal(default_vals.index(0.8), 7)
    assert_equal(default_vals.rindex(0.8), 19)
    weekend_vals = @sch.schedule_day_get_hourly_values(ppl_sch.scheduleRules.first.daySchedule)
    assert_equal(weekend_vals.index(1), 10)
    assert_equal(weekend_vals.rindex(1), 13)
  end

end



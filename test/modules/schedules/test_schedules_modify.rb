require_relative '../../helpers/minitest_helper'

class TestSchedulesModify < Minitest::Test
  def setup
    @sch = OpenstudioStandards::Schedules
  end

  def test_schedule_day_multiply_by_value
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'default_time_value_pairs' => { 8.0 => 0.05, 16.0 => 0.9, 24.0 => 0.05 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    @sch.schedule_day_multiply_by_value(schedule.defaultDaySchedule, 1.1)
    schedule_min_max = @sch.schedule_ruleset_get_min_max(schedule)
    assert(schedule_min_max['min'] == 0.055)
    assert(schedule_min_max['max'] == 0.99)
    schedule.remove

    schedule = @sch.create_simple_schedule(model, test_options)
    @sch.schedule_day_multiply_by_value(schedule.defaultDaySchedule, 1.1, lower_apply_limit: 0.1)
    schedule_min_max = @sch.schedule_ruleset_get_min_max(schedule)
    assert(schedule_min_max['min'] == 0.05)
    assert(schedule_min_max['max'] == 0.99)
  end

  def test_schedule_day_set_hours_of_operation
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'default_time_value_pairs' => { 7.0 => 0.0, 16.0 => 2.0, 24 => 0.0}
    }
    schedule_day = @sch.create_simple_schedule(model, test_options).defaultDaySchedule
    start_time = OpenStudio::Time.new(0,9,0,0)
    end_time = OpenStudio::Time.new(0,18,0,0)
    @sch.schedule_day_set_hours_of_operation(schedule_day, start_time, end_time)
    hourly_values = @sch.schedule_day_get_hourly_values(schedule_day)
    assert_equal(hourly_values.index(1.0), 9)
    assert_equal(hourly_values.rindex(1.0), 18-1)
    # test fromprevious day
    start_time = OpenStudio::Time.new(0,9,0,0)
    end_time = OpenStudio::Time.new(0,28,0,0)
    @sch.schedule_day_set_hours_of_operation(schedule_day, start_time, end_time)
    hourly_values = @sch.schedule_day_get_hourly_values(schedule_day)
    assert_equal(hourly_values.index(0.0), 28-24)
    assert_equal(hourly_values.rindex(0.0), 9-1)
  end

  def test_schedule_ruleset_add_rule
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'default_time_value_pairs' => { 8.0 => 0.0, 16.0 => 1.0, 24.0 => 0.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    values = Array.new(8, 0.25) + Array.new(8, 0.75) + Array.new(8, 0.25)
    start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, 2009)
    end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, 2009)
    @sch.schedule_ruleset_add_rule(schedule, values,
                                   start_date: start_date,
                                   end_date: end_date,
                                   day_names: ['Wednesday'],
                                   rule_name: 'Wednesdays')
    # Jan 7, 2009 is a Wednesday
    start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 7, 2009)
    end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 7, 2009)
    day_schs = schedule.getDaySchedules(start_date, end_date)
    hourly_values = @sch.schedule_day_get_hourly_values(day_schs[0])
    assert(hourly_values.min == 0.25)
    assert(hourly_values.max == 0.75)
  end

  def test_schedule_ruleset_simple_value_adjust
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'default_time_value_pairs' => { 8.0 => 0.0, 16.0 => 3.0, 24.0 => 0.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    @sch.schedule_ruleset_simple_value_adjust(schedule, 0.5)
    assert(schedule.to_ScheduleRuleset.is_initialized)
    schedule_max = @sch.schedule_ruleset_get_min_max(schedule)['max']
    assert(schedule_max == 1.5)

    @sch.schedule_ruleset_simple_value_adjust(schedule, 0.5, 'Sum')
    assert(schedule.to_ScheduleRuleset.is_initialized)
    schedule_max = @sch.schedule_ruleset_get_min_max(schedule)['max']
    assert(schedule_max == 2.0)

    # Test case when schedule type limits put constraint on the adjustment values
    schedule_type_limits = @sch.create_schedule_type_limits(model,
                                                            name: 'Fraction Schedule Type',
                                                            lower_limit_value: 0.0,
                                                            upper_limit_value: 2.0,
                                                            numeric_type: 'Continuous',
                                                            unit_type: 'Dimensionless')
    schedule.setScheduleTypeLimits(schedule_type_limits)
    @sch.schedule_ruleset_simple_value_adjust(schedule, 50)
    assert(schedule.to_ScheduleRuleset.is_initialized)
    schedule_max = @sch.schedule_ruleset_get_min_max(schedule)['max']
    assert(schedule_max == 2.0)
  end

  def test_schedule_ruleset_conditional_adjust_value
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'default_time_value_pairs' => { 8.0 => 0.0, 12 => 2.0, 16.0 => 4.0, 24.0 => 0.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    test_value = 3.0
    pass_value = 1.5
    fail_value = 2.0
    floor_value = 0.1
    @sch.schedule_ruleset_conditional_adjust_value(schedule, test_value, pass_value, fail_value, floor_value)
    schedule_max = @sch.schedule_ruleset_get_min_max(schedule)['max']
    assert(schedule_max == 8.0)
  end

  def test_schedule_ruleset_time_conditional_adjust_value
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'default_time_value_pairs' => { 8.0 => 0.0, 16.0 => 3.0, 24.0 => 0.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    hhmm_before = 1400
    hhmm_after = 2030
    inside_value = 2.0
    outside_value = 1.0
    @sch.schedule_ruleset_time_conditional_adjust_value(schedule, hhmm_before, hhmm_after, inside_value, outside_value)
  end

  def test_schedule_ruleset_adjust_hours_of_operation
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'default_time_value_pairs' => { 8.0 => 0.0, 16.0 => 3.0, 24.0 => 0.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    basic_shift = { 'shift_hoo' => 2.0 }
    schedule = @sch.schedule_ruleset_adjust_hours_of_operation(schedule, basic_shift)
    hourly_values = @sch.schedule_day_get_hourly_values(schedule.defaultDaySchedule)
    assert_equal(hourly_values.index(3.0), 8+2)
  end

  def test_schedule_ruleset_cleanup_profiles
    model = OpenStudio::Model::Model.new

    # create a complex schedule to cleanup
    rules = []
    rules << ['All Days', '1/1-12/31', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [8, 0.1], [12, 0.4], [16, 0.8], [24, 0.1]]
    rules << ['All Days in March and April', '3/1-4/30', 'Mon/Tue/Wed/Thu/Fri/Sat/Sun', [8, 0.2], [12, 0.4], [16, 0.7], [24, 0.2]]
    test_options = {
      'name' => 'Test Create Complex',
      'winter_design_day' => [[24, 0]],
      'summer_design_day' => [[24, 1]],
      'default_day' => ['Test Create Complex Default', [8, 0.0], [12, 0.4], [16, 0.9], [24, 0.0]],
      'rules' => rules
    }
    schedule = @sch.create_complex_schedule(model, test_options)

    # check to see that the default schedule was replaced
    result_schedule = @sch.schedule_ruleset_cleanup_profiles(schedule)
    day_min_max = @sch.schedule_day_get_min_max(result_schedule.defaultDaySchedule)
    assert(day_min_max['min'] == 0.1)
    assert(day_min_max['max'] == 0.8)
  end
end
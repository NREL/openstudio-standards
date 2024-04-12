require_relative '../../helpers/minitest_helper'
require 'date'

class TestSchedulesInformation < Minitest::Test
  def setup
    @sch = OpenstudioStandards::Schedules
  end

  def test_schedule_get_min_max
    model = OpenStudio::Model::Model.new

    # test ScheduleConstant
    schedule = OpenStudio::Model::ScheduleConstant.new(model)
    schedule.setValue(42.0)
    result = @sch.schedule_get_min_max(schedule)
    assert(result['min'] == 42.0)
    assert(result['max'] == 42.0)

    # test ScheduleCompact
    schedule = OpenStudio::Model::ScheduleCompact.new(model)
    schedule.setString(3, 'Through: 12/31')
    schedule.setString(4, 'For: AllDays')
    schedule.setString(5, 'Until: 14:00')
    schedule.setString(6, '21.0')
    schedule.setString(7, 'Until: 24:00')
    schedule.setString(8, '42.0')
    result = @sch.schedule_get_min_max(schedule)
    assert(result['min'] == 21.0)
    assert(result['max'] == 42.0)

    # test ScheduleRuleset
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 4.0, 16.0 => 12.0, 24.0 => 5.0 },
      'summer_time_value_pairs' => { 8.0 => 2.0, 16.0 => 10.0, 24.0 => 3.0 },
      'default_time_value_pairs' => { 8.0 => 6.0, 16.0 => 14.0, 24.0 => 7.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_get_min_max(schedule)
    assert(result['min'] == 6.0)
    assert(result['max'] == 14.0)
  end

  def test_schedule_get_design_day_min_max
    model = OpenStudio::Model::Model.new

    # test ScheduleConstant
    schedule = OpenStudio::Model::ScheduleConstant.new(model)
    schedule.setValue(42.0)
    result = @sch.schedule_get_design_day_min_max(schedule, 'summer')
    assert(result['min'] == 42.0)
    assert(result['max'] == 42.0)

    # test ScheduleCompact
    schedule = OpenStudio::Model::ScheduleCompact.new(model)
    schedule.setString(3, 'Through: 12/31')
    schedule.setString(4, 'For: Weekdays SummerDesignDay')
    schedule.setString(5, 'Until: 07:00')
    schedule.setString(6, '0.42')
    schedule.setString(7, 'Until: 22:00')
    schedule.setString(8, '0.84')
    schedule.setString(9, 'Until: 24:00')
    schedule.setString(10, '0.42')
    schedule.setString(11, 'For: Saturday WinterDesignDay')
    schedule.setString(12, 'Until: 07:00')
    schedule.setString(13, '0.21')
    schedule.setString(14, 'Until: 18:00')
    schedule.setString(15, '0.42')
    schedule.setString(16, 'Until: 24:00')
    schedule.setString(17, '0.21')
    schedule.setString(18, 'For: AllOtherDays')
    schedule.setString(19, 'Until: 24:00')
    schedule.setString(20, '0.12')
    result = @sch.schedule_get_design_day_min_max(schedule, 'summer')
    assert(result['min'] == 0.42)
    assert(result['max'] == 0.84)

    # test ScheduleRuleset
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 4.0, 16.0 => 12.0, 24.0 => 5.0 },
      'summer_time_value_pairs' => { 8.0 => 2.0, 16.0 => 10.0, 24.0 => 3.0 },
      'default_time_value_pairs' => { 8.0 => 6.0, 16.0 => 14.0, 24.0 => 7.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_get_design_day_min_max(schedule, 'summer')
    assert(result['min'] == 2)
    assert(result['max'] == 10.0)
  end

  def test_schedule_get_equivalent_full_load_hours
    model = OpenStudio::Model::Model.new

    # test ScheduleConstant
    schedule = OpenStudio::Model::ScheduleConstant.new(model)
    schedule.setValue(42.0)
    result = @sch.schedule_get_equivalent_full_load_hours(schedule)
    assert(result == 42.0 * 8760)

    # test ScheduleRuleset
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 0.2, 16.0 => 1.0, 24.0 => 0.5 },
      'summer_time_value_pairs' => { 8.0 => 0.1, 16.0 => 0.9, 24.0 => 0.3 },
      'default_time_value_pairs' => { 8.0 => 0.6, 16.0 => 0.8, 24.0 => 0.4 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_get_equivalent_full_load_hours(schedule)
    assert(result.round(0) == 5256)
  end

  def test_schedule_get_hourly_values
    model = OpenStudio::Model::Model.new

    # test ScheduleConstant
    schedule = OpenStudio::Model::ScheduleConstant.new(model)
    schedule.setValue(42.0)
    result = @sch.schedule_get_hourly_values(schedule)
    assert(result.class.to_s == 'Array')
    assert(result.size == 8760, "Expected result size to be 8760, but size is #{result.size}.")
    assert(result.sum == 8760 * 42.0)

    # test ScheduleCompact
    schedule = OpenStudio::Model::ScheduleCompact.new(model)
    schedule.setString(3, 'Through: 12/31')
    schedule.setString(4, 'For: AllDays')
    schedule.setString(5, 'Until: 14:00')
    schedule.setString(6, '21.0')
    schedule.setString(7, 'Until: 24:00')
    schedule.setString(8, '42.0')
    expected_sum = 365 * (14 * 21.0 +10 * 42.0)
    schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
    schedule.setScheduleTypeLimits(schedule_type_limits)
    result = @sch.schedule_get_hourly_values(schedule)
    assert(result.class.to_s == 'Array')
    assert(result.size == 8760, "Hourly array size #{result.size} does not match expected size of 8760.")
    assert(result.sum == expected_sum, "Sum of hourly values #{result.sum} does not match expected sum #{expected_sum}.")

    # test ScheduleRuleset
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 4.0, 16.0 => 12.0, 24.0 => 5.0 },
      'summer_time_value_pairs' => { 8.0 => 2.0, 16.0 => 10.0, 24.0 => 3.0 },
      'default_time_value_pairs' => { 8.0 => 6.0, 16.0 => 14.0, 24.0 => 7.0 }
    }
    expected_sum = 365 * (8 * 6.0 + 8 * 14.0 + 8 * 7.0)
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_get_hourly_values(schedule)
    assert(result.class.to_s == 'Array')
    assert(result.size == 8760, "Hourly array size #{result.size} does not match expected size of 8760.")
    assert(result.sum == expected_sum, "Sum of hourly values #{result.sum} does not match expected sum #{expected_sum}.")
  end

  def test_schedule_constant_get_min_max
    model = OpenStudio::Model::Model.new
    schedule = OpenStudio::Model::ScheduleConstant.new(model)
    schedule.setValue(42.0)
    result = @sch.schedule_constant_get_min_max(schedule)
    assert(result['min'] == 42.0)
    assert(result['max'] == 42.0)
  end

  def test_schedule_constant_get_equivalent_full_load_hours
    model = OpenStudio::Model::Model.new
    schedule = OpenStudio::Model::ScheduleConstant.new(model)
    schedule.setValue(42.0)
    result = @sch.schedule_constant_get_equivalent_full_load_hours(schedule)
    assert(result == 42.0 * 8760)

    model.getYearDescription.setCalendarYear(2020)
    result = @sch.schedule_constant_get_equivalent_full_load_hours(schedule)
    assert(result == 42.0 * 8784)
  end

  def test_schedule_constant_get_hourly_values
    model = OpenStudio::Model::Model.new
    schedule = OpenStudio::Model::ScheduleConstant.new(model)
    schedule.setValue(42.0)
    result = @sch.schedule_constant_get_hourly_values(schedule)
    assert(result.class.to_s == 'Array')
    assert(result.size == 8760)

    model.getYearDescription.setCalendarYear(2020)
    result = @sch.schedule_constant_get_hourly_values(schedule)
    assert(result.class.to_s == 'Array')
    assert(result.size == 8784)
  end

  def test_schedule_compact_get_min_max
    model = OpenStudio::Model::Model.new
    schedule = OpenStudio::Model::ScheduleCompact.new(model)
    schedule.setString(3, 'Through: 12/31')
    schedule.setString(4, 'For: AllDays')
    schedule.setString(5, 'Until: 14:00')
    schedule.setString(6, '21.0')
    schedule.setString(7, 'Until: 24:00')
    schedule.setString(8, '42.0')
    result = @sch.schedule_compact_get_min_max(schedule)
    assert(result['min'] == 21.0)
    assert(result['max'] == 42.0)
  end

  def test_schedule_compact_get_design_day_min_max
    model = OpenStudio::Model::Model.new
    schedule = OpenStudio::Model::ScheduleCompact.new(model)
    schedule.setString(3, 'Through: 12/31')
    schedule.setString(4, 'For: Weekdays SummerDesignDay')
    schedule.setString(5, 'Until: 07:00')
    schedule.setString(6, '0.42')
    schedule.setString(7, 'Until: 22:00')
    schedule.setString(8, '0.84')
    schedule.setString(9, 'Until: 24:00')
    schedule.setString(10, '0.42')
    schedule.setString(11, 'For: Saturday WinterDesignDay')
    schedule.setString(12, 'Until: 07:00')
    schedule.setString(13, '0.21')
    schedule.setString(14, 'Until: 18:00')
    schedule.setString(15, '0.42')
    schedule.setString(16, 'Until: 24:00')
    schedule.setString(17, '0.21')
    schedule.setString(18, 'For: AllOtherDays')
    schedule.setString(19, 'Until: 24:00')
    schedule.setString(20, '0.12')
    result = @sch.schedule_compact_get_design_day_min_max(schedule, 'summer')
    assert(result['min'] == 0.42)
    assert(result['max'] == 0.84)
    result = @sch.schedule_compact_get_design_day_min_max(schedule, 'winter')
    assert(result['min'] == 0.21)
    assert(result['max'] == 0.42)
  end

  def test_schedule_day_get_min_max
    model = OpenStudio::Model::Model.new
    schedule_day = OpenStudio::Model::ScheduleDay.new(model)
    schedule_day.addValue(OpenStudio::Time.new(0, 9, 0, 0), 0.6)
    schedule_day.addValue(OpenStudio::Time.new(0, 11, 0, 0), 0.8)
    schedule_day.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
    result = @sch.schedule_day_get_min_max(schedule_day)
    assert(result['min'] == 0.2)
    assert(result['max'] == 0.8)
  end

  def test_schedule_day_get_equivalent_full_load_hours
    model = OpenStudio::Model::Model.new
    schedule_day = OpenStudio::Model::ScheduleDay.new(model)
    schedule_day.addValue(OpenStudio::Time.new(0, 9, 0, 0), 0.6)
    schedule_day.addValue(OpenStudio::Time.new(0, 11, 0, 0), 0.8)
    schedule_day.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
    result = @sch.schedule_day_get_equivalent_full_load_hours(schedule_day)
    assert(result == 9.6)
  end

  def test_schedule_day_get_hourly_values
    model = OpenStudio::Model::Model.new
    schedule_day = OpenStudio::Model::ScheduleDay.new(model)
    schedule_day.addValue(OpenStudio::Time.new(0, 9, 0, 0), 1.0)
    schedule_day.addValue(OpenStudio::Time.new(0, 9, 6, 0), 0.2)
    schedule_day.addValue(OpenStudio::Time.new(0, 9, 36, 0), 0.8)
    schedule_day.addValue(OpenStudio::Time.new(0, 11, 0, 0), 0.6)
    schedule_day.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)
    result = @sch.schedule_day_get_hourly_values(schedule_day)
    expected_array = Array.new(8, 1.0).concat([0.66, 0.6]).concat(Array.new(14, 1.0))
    assert(expected_array.difference(result).empty?)
  end

  def test_schedule_ruleset_get_min_max
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 4.0, 16.0 => 12.0, 24.0 => 5.0 },
      'summer_time_value_pairs' => { 8.0 => 2.0, 16.0 => 10.0, 24.0 => 3.0 },
      'default_time_value_pairs' => { 8.0 => 6.0, 16.0 => 14.0, 24.0 => 7.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_ruleset_get_min_max(schedule)
    assert(result['min'] == 6.0)
    assert(result['max'] == 14.0)

    # create a complex schedule for testing variants
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

    # default operation, all values in schedule
    result = @sch.schedule_ruleset_get_min_max(schedule)
    assert(result['min'] == 0.0)
    assert(result['max'] == 0.9)

    # values only during run period
    result = @sch.schedule_ruleset_get_min_max(schedule, only_run_period_values: true)
    assert(result['min'] == 0.1)
    assert(result['max'] == 0.8)

    # test complex schedule that doesn't use default day and limited run period
    run_period = model.getRunPeriod
    run_period.setBeginMonth(3)
    run_period.setBeginDayOfMonth(7)
    run_period.setEndMonth(4)
    run_period.setEndDayOfMonth(14)
    result = @sch.schedule_ruleset_get_min_max(schedule, only_run_period_values: true)
    assert(result['min'] == 0.2)
    assert(result['max'] == 0.7)
  end

  def test_schedule_ruleset_get_design_day_min_max
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 4.0, 16.0 => 12.0, 24.0 => 5.0 },
      'summer_time_value_pairs' => { 8.0 => 2.0, 16.0 => 10.0, 24.0 => 3.0 },
      'default_time_value_pairs' => { 8.0 => 6.0, 16.0 => 14.0, 24.0 => 7.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_ruleset_get_design_day_min_max(schedule, 'summer')
    assert(result['min'] == 2.0)
    assert(result['max'] == 10.0)
    result = @sch.schedule_ruleset_get_design_day_min_max(schedule, 'winter')
    assert(result['min'] == 4.0)
    assert(result['max'] == 12.0)
  end

  def test_schedule_ruleset_get_equivalent_full_load_hours
    model = OpenStudio::Model::Model.new
    # test ScheduleRuleset
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 0.2, 16.0 => 1.0, 24.0 => 0.5 },
      'summer_time_value_pairs' => { 8.0 => 0.1, 16.0 => 0.9, 24.0 => 0.3 },
      'default_time_value_pairs' => { 8.0 => 0.6, 16.0 => 0.8, 24.0 => 0.4 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_get_equivalent_full_load_hours(schedule)
    assert(result.round(2) == 5256.0)

    model.getYearDescription.setCalendarYear(2020)
    result = @sch.schedule_get_equivalent_full_load_hours(schedule)
    assert(result.round(2) == 5270.4)
  end

  def test_schedule_ruleset_get_hourly_values
    model = OpenStudio::Model::Model.new
    rules = []
    rules << ['Tuesdays and Thursdays', '1/1-12/31', 'Tue/Thu', [4, 0], [4.33, 1], [18, 0], [18.66, 1], [24, 0]]
    rules << ['Wednesdays and Fridays', '1/1-12/31', 'Wed/Fri', [6, 0], [6.33, 1], [16, 0], [16.66, 1], [24, 0]]
    test_options = {
      'name' => 'Test Create Complex',
      'winter_design_day' => [[24, 0]],
      'summer_design_day' => [[24, 1]],
      'default_day' => ['Test Create Complex Default', [11, 0], [11.33, 1], [23, 0], [23.33, 1], [24, 0]],
      'rules' => rules
    }
    schedule = @sch.create_complex_schedule(model, test_options)
    result = @sch.schedule_ruleset_get_hourly_values(schedule)
    assert(result.class.to_s == 'Array')
    assert(result.size == 8760, "Hourly array size #{result.size} does not match expected size of 8760.")

    model.getYearDescription.setCalendarYear(2020)
    result = @sch.schedule_ruleset_get_hourly_values(schedule)
    assert(result.class.to_s == 'Array')
    assert(result.size == 8784, "Hourly array size #{result.size} does not match expected size of 8784.")
  end

  def test_schedule_ruleset_get_hours_above_value
    model = OpenStudio::Model::Model.new
    # test ScheduleRuleset
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 0.2, 16.0 => 1.0, 24.0 => 0.5 },
      'summer_time_value_pairs' => { 8.0 => 0.1, 16.0 => 0.9, 24.0 => 0.3 },
      'default_time_value_pairs' => { 8.0 => 0.6, 16.0 => 0.8, 24.0 => 0.4 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_ruleset_get_hours_above_value(schedule, 0.7)
    assert(result.round(2) == 2920.0)

    model.getYearDescription.setCalendarYear(2020)
    result = @sch.schedule_ruleset_get_hours_above_value(schedule, 0.7)
    assert(result.round(2) == 2928.0)
  end

  def test_schedule_ruleset_get_start_and_end_times
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 4.0, 16.0 => 12.0, 24.0 => 5.0 },
      'summer_time_value_pairs' => { 8.0 => 2.0, 16.0 => 10.0, 24.0 => 3.0 },
      'default_time_value_pairs' => { 8.0 => 6.0, 16.0 => 14.0, 24.0 => 7.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_ruleset_get_start_and_end_times(schedule)
    assert(result['start_time'].hours == 8)
    assert(result['end_time'].hours == 16)
  end

  def test_schedule_ruleset_get_timeseries
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 4.0, 16.0 => 12.0, 24.0 => 5.0 },
      'summer_time_value_pairs' => { 8.0 => 2.0, 16.0 => 10.0, 24.0 => 3.0 },
      'default_time_value_pairs' => { 8.0 => 6.0, 16.0 => 14.0, 24.0 => 7.0 }
    }
    schedule = @sch.create_simple_schedule(model, test_options)
    result = @sch.schedule_ruleset_get_timeseries(schedule)
    assert(result.class.to_s == 'OpenStudio::TimeSeries')
    assert(result.values.length == (8760*2 - 365))
  end

  def test_schedule_ruleset_get_annual_days_used
    model = OpenStudio::Model::Model.new
    model.getYearDescription.setCalendarYear(2018) # starts on a Monday
    rules = []
    rules << ['SpringWeekends', '1/1-5/31', 'Sat/Sun', [10, 0], [18, 1], [24, 0]]
    rules << ['SummmerWeekday', '6/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [9, 0], [14, 1], [24, 0]]
    rules << ['SummerWeekend', '6/1-8/31', 'Sat/Sun', [24, 0]]
    rules << ['FallWeekends', '9/1-12/31', 'Sat/Sun', [10, 0], [18, 1], [24, 0]]

    test_options = {
      'name' => 'Test Complex',
      'winter_design_day' => [[24, 0]],
      'summer_design_day' => [[24, 1]],
      'default_day' => ['Test Complex Default', [8, 0], [16, 1], [24, 0]],
      'rules' => rules
    }

    schedule_ruleset = @sch.create_complex_schedule(model, test_options)
    annual_days_used = @sch.schedule_ruleset_get_annual_days_used(schedule_ruleset)
    assert_equal(5, annual_days_used.keys.size)

    springfall_weekdays = []
    spring_weekends = []
    summer_weekdays = []
    summer_weekends = []
    fall_weekends = []

    (Date.new(2018,1,1)..Date.new(2018,5,31)).each do |day|
      if [0,6].include? day.wday
        spring_weekends << day.yday
      else
        springfall_weekdays << day.yday
      end
    end

    (Date.new(2018,6,1)..Date.new(2018,8,31)).each do |day|
      if [0,6].include? day.wday
        summer_weekends << day.yday
      else
        summer_weekdays << day.yday
      end
    end

    (Date.new(2018,9,1)..Date.new(2018,12,31)).each do |day|
      if [0,6].include? day.wday
        fall_weekends << day.yday
      else
        springfall_weekdays << day.yday
      end
    end

    assert_equal(springfall_weekdays, annual_days_used[-1])
    assert_equal(spring_weekends, annual_days_used[3])
    assert_equal(summer_weekdays, annual_days_used[2])
    assert_equal(summer_weekends, annual_days_used[1])
    assert_equal(fall_weekends, annual_days_used[0])
  end

  def test_schedule_ruleset_get_schedule_day_rule_indices
    model = OpenStudio::Model::Model.new
    model.getYearDescription.setCalendarYear(2018) # starts on a Monday
    rules = []
    rules << ['SpringWeekends', '1/1-5/31', 'Sat/Sun', [10, 0], [18, 1], [24, 0]]
    rules << ['SummmerWeekday', '6/1-8/31', 'Mon/Tue/Wed/Thu/Fri', [9, 0], [14, 1], [24, 0]]
    rules << ['SummerWeekend', '6/1-8/31', 'Sat/Sun', [24, 0]]
    rules << ['FallWeekends', '9/1-12/31', 'Sat/Sun', [10, 0], [18, 1], [24, 0]]

    test_options = {
      'name' => 'Test Complex',
      'winter_design_day' => [[24, 0]],
      'summer_design_day' => [[24, 1]],
      'default_day' => ['Test Complex Default', [8, 0], [16, 1], [24, 0]],
      'rules' => rules
    }
    schedule_ruleset = @sch.create_complex_schedule(model, test_options)
    rule_index_hash = @sch.schedule_ruleset_get_schedule_day_rule_indices(schedule_ruleset)

    assert_equal(5, rule_index_hash.size)
    rule_index_hash.keys.each { |k| assert(k.is_a?(OpenStudio::Model::ScheduleDay))}
    assert_equal(-1, rule_index_hash[schedule_ruleset.defaultDaySchedule])
    assert_equal(2, rule_index_hash[model.getScheduleDayByName('Test Complex SummmerWeekday').get])
  end

end
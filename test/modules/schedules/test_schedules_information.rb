require_relative '../../helpers/minitest_helper'

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
end
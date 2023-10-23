require_relative '../../helpers/minitest_helper'

class TestSchedulesModify < Minitest::Test
  def setup
    @sch = OpenstudioStandards::Schedules
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
    @sch.schedule_ruleset_adjust_hours_of_operation(schedule, basic_shift)
  end
end
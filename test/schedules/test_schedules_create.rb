require_relative '../helpers/minitest_helper'

class TestSchedulesCreate < Minitest::Test
  def setup
    @sch = OpenstudioStandards::Schedules
  end

  def test_model_create_simple_schedule
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Test Create Simple',
      'winterTimeValuePairs' => { 8.0 => 0.0, 16.0 => 1.0, 24.0 => 0.0 },
      'summerTimeValuePairs' => { 8.0 => 0.0, 16.0 => 1.0, 24.0 => 0.0 },
      'defaultTimeValuePairs' => { 8.0 => 0.0, 16.0 => 1.0, 24.0 => 0.0 }
    }
    schedule = @sch.model_create_simple_schedule(model, test_options)
    assert(schedule.to_ScheduleRuleset.is_initialized)
    assert(schedule.name.to_s == 'Test Create Simple')
  end

  def test_model_create_complex_schedule
    model = OpenStudio::Model::Model.new
    rules = []
    rules << ['Tuesdays and Thursdays', '1/1-12/31', 'Tue/Thu', [4, 0], [4.33, 1], [18, 0], [18.66, 1], [24, 0]]
    test_options = {
      'name' => 'Test Create Complex',
      'winter_design_day' => [[24, 0]],
      'summer_design_day' => [[24, 1]],
      'default_day' => ['Test Create Complex Default', [11, 0], [11.33, 1], [23, 0], [23.33, 1], [24, 0]],
      'rules' => rules
    }
    schedule = @sch.model_create_complex_schedule(model, test_options)
    assert(schedule.to_ScheduleRuleset.is_initialized)
    assert(schedule.name.to_s == 'Test Create Complex')
  end

  def test_model_create_schedule_from_rate_of_change
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Test Create Rate Of Change',
      'defaultTimeValuePairs' => { 4.0 => 0.0, 6.0 => 6.0, 8.0 => 15.0, 16 => 7.0, 24 => 0.0 }
    }
    input_schedule = @sch.model_create_simple_schedule(model, test_options)
    output_schedule = @sch.model_create_schedule_from_rate_of_change(model, input_schedule)
    assert(output_schedule.to_ScheduleRuleset.is_initialized)
  end

  def test_model_create_weighted_merge_schedules
    model = OpenStudio::Model::Model.new
    schedule1_options = {
      'name' => 'Schedule1',
      'defaultTimeValuePairs' => { 8.0 => 0.0, 16.0 => 10.0, 24.0 => 0.0 }
    }
    schedule1 = @sch.model_create_simple_schedule(model, schedule1_options)

    schedule2_options = {
      'name' => 'Schedule2',
      'defaultTimeValuePairs' => { 8.0 => 0.0, 16.0 => 20.0, 24.0 => 0.0 }
    }
    schedule2 = @sch.model_create_simple_schedule(model, schedule2_options)

    schedule_weights_hash = {}
    schedule_weights_hash[schedule1] = 2
    schedule_weights_hash[schedule2] = 8

    schedule = @sch.model_create_weighted_merge_schedules(model, schedule_weights_hash)
    assert(schedule['mergedSchedule'].to_ScheduleRuleset.is_initialized)
    assert(schedule['mergedSchedule'].name.to_s == 'Merged Schedule')
    assert(schedule['denominator'] == 10.0)
  end
end
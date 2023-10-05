require_relative '../../helpers/minitest_helper'

class TestSchedulesModify < Minitest::Test
  def setup
    @sch = OpenstudioStandards::Schedules
  end
  
  def test_schedule_ruleset_get_min_max
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 4.0, 16.0 => 12.0, 24.0 => 5.0 },
      'summer_time_value_pairs' => { 8.0 => 2.0, 16.0 => 10.0, 24.0 => 3.0 },
      'default_time_value_pairs' => { 8.0 => 6.0, 16.0 => 14.0, 24.0 => 7.0 }
    }
    schedule = @sch.model_create_simple_schedule(model, test_options)
    result = @sch.schedule_ruleset_get_min_max(schedule)
    assert(result['min'] == 6.0)
    assert(result['max'] == 14.0)
  end

  def test_schedule_ruleset_get_timeseries
    model = OpenStudio::Model::Model.new
    test_options = {
      'name' => 'Simple Schedule',
      'winter_time_value_pairs' => { 8.0 => 4.0, 16.0 => 12.0, 24.0 => 5.0 },
      'summer_time_value_pairs' => { 8.0 => 2.0, 16.0 => 10.0, 24.0 => 3.0 },
      'default_time_value_pairs' => { 8.0 => 6.0, 16.0 => 14.0, 24.0 => 7.0 }
    }
    schedule = @sch.model_create_simple_schedule(model, test_options)
    result = @sch.schedule_ruleset_get_timeseries(schedule)
    assert(result.class.to_s == 'OpenStudio::TimeSeries')
    assert(result.values.length == (8760*2 - 365))
  end
end
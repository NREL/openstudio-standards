require_relative '../helpers/minitest_helper'

class TestAnnualMinMaxValue < Minitest::Test

  def test_annual_min_max_value

    # make an empty model
    model = OpenStudio::Model::Model.new

    # make ruleset schedule
    schedule_ruleset = model.add_schedule('Office Bldg Light')

    # make constant schedule
    schedule_constant = OpenStudio::Model::ScheduleConstant.new(model)
    schedule_constant.setValue(1.0)

    # get annual_equivalent_full_load_hrs for both schedules
    annual_min_max_value_ruleset = schedule_ruleset.annual_min_max_value
    annual_min_max_value_constant = schedule_constant.annual_min_max_value

    # test ruleset and constant schedule
    assert(annual_min_max_value_ruleset['min'] == 0.05)
    assert(annual_min_max_value_ruleset['max'] == 0.9)
    assert(annual_min_max_value_constant['min'] == 1.0)
    assert(annual_min_max_value_constant['max'] == 1.0)

  end

end

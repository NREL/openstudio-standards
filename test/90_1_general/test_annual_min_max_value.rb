require_relative '../helpers/minitest_helper'

class TestAnnualMinMaxValue < Minitest::Test

  def test_annual_min_max_value

    # make an empty model
    model = OpenStudio::Model::Model.new

    template = '90.1-2010'
    standard = StandardsModel.get_standard_model(template)
    
    # make ruleset schedule
    schedule_ruleset = standard.model_add_schedule(model, 'Office Bldg Light')
    
    # make constant schedule
    schedule_constant = OpenStudio::Model::ScheduleConstant.new(model)
    schedule_constant.setValue(1.0)

    # get min and max for both schedules
    annual_min_max_value_ruleset = standard.schedule_ruleset_annual_min_max_value(schedule_ruleset)
    annual_min_max_value_constant = standard.schedule_constant_annual_min_max_value(schedule_constant)

    # test ruleset and constant schedule
    assert(annual_min_max_value_ruleset['min'] == 0.05)
    assert(annual_min_max_value_ruleset['max'] == 0.9)
    assert(annual_min_max_value_constant['min'] == 1.0)
    assert(annual_min_max_value_constant['max'] == 1.0)

  end

end

require_relative 'minitest_helper'

class TestAnnualEquivalentFullLoadHrs < Minitest::Test

  def test_annual_equivalent_full_load_hrs

    # make an empty model
    model = OpenStudio::Model::Model.new

    # make ruleset schedule
    schedule_ruleset = model.add_schedule('Office Bldg Light')

    # make constant schedule
    schedule_constant = OpenStudio::Model::ScheduleConstant.new(model)
    schedule_constant.setValue(1.0)

    # get annual_equivalent_full_load_hrs for both schedules
    ann_eqiv_ruleset = schedule_ruleset.annual_equivalent_full_load_hrs
    ann_eqiv_constant = schedule_constant.annual_equivalent_full_load_hrs

    # test ruleset and constant schedule
    assert(ann_eqiv_ruleset == 2948.5)
    assert(ann_eqiv_constant == 8760)

  end

end

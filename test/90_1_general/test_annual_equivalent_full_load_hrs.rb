require_relative '../helpers/minitest_helper'

class TestAnnualEquivalentFullLoadHrs < Minitest::Test

  def test_annual_equivalent_full_load_hrs

    # make an empty model
    model = OpenStudio::Model::Model.new

    template = '90.1-2010'
    standard = StandardsModel.get_standard_model(template)
    
    # make ruleset schedule
    schedule_ruleset = standard.model_add_schedule(model, 'Office Bldg Light')

    # make constant schedule
    schedule_constant = OpenStudio::Model::ScheduleConstant.new(model)
    schedule_constant.setValue(1.0)

    # get annual_equivalent_full_load_hrs for both schedules
    ann_eqiv_ruleset = standard.schedule_ruleset_annual_equivalent_full_load_hrs(schedule_ruleset) 
    ann_eqiv_constant = standard.schedule_constant_annual_equivalent_full_load_hrs(schedule_constant) 

    # test ruleset and constant schedule
    assert(ann_eqiv_ruleset == 2948.5)
    assert(ann_eqiv_constant == 8760)

  end

end

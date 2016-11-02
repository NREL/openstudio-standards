require_relative 'minitest_helper'

class TestBoilerHotWater < Minitest::Test

  def test_boiler_hot_water

    template = '90.1-2013'

    # make an empty model
    model = OpenStudio::Model::Model.new

    # make ruleset schedule
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    target_cap_btu_per_h = 500000
    target_cap_btu_per_watts = OpenStudio.convert(target_cap_btu_per_h,"Btu/h","W").get
    boiler.setNominalCapacity(target_cap_btu_per_watts)

    # run standard_minimum_cop
    min_thermal_eff = boiler.standard_minimum_thermal_efficiency(template)

    # Minimum thermal efficiency = 0.8
    correct_thermal_eff = 0.8

    # Check the lookup against the truth
    assert_in_delta(min_thermal_eff, correct_thermal_eff, 0.1, "Expected #{correct_thermal_eff} eff.  Got #{min_thermal_eff} eff.")

  end

end

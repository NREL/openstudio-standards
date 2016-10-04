require_relative 'minitest_helper'

class TestBoilerHotWater < Minitest::Test

  def test_boiler_hot_water

    # get method inputs
    template = '90.1-2013'
    standards = 'TBD' #not sure what I'm looking for here

    # make an empty model
    model = OpenStudio::Model::Model.new

    # make ruleset schedule
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    target_cap_btu_per_h = 500000
    target_cap_btu_per_watts = OpenStudio.convert(target_cap_btu_per_h,"Btu/h","W").get
    boiler.setNominalCapacity(target_cap_btu_per_watts)
    puts boiler

    # run standard_minimum_cop
    min_full_load_eff = boiler.standard_minimum_thermal_efficiency(template, standards)

    # todo - check that it returns the correct value
    assert(min_full_load_eff > 0.0)
    
  end

end

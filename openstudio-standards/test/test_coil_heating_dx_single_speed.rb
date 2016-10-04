require_relative 'minitest_helper'

class TestCoilHeatingDxSingleSpeed < Minitest::Test

  def test_coil_heating_dx_single_speed

    # get method inputs
    template = '90.1-2013'
    standards = 'TBD' #not sure what I'm looking for here

    # make an empty model
    model = OpenStudio::Model::Model.new

    # make ruleset schedule
    coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model)
    puts coil

    # run standard_minimum_cop
    min_cop = coil.standard_minimum_cop(template, standards)

    # todo - check that it returns the correct value
    assert(min_cop > 0.0)

  end

end

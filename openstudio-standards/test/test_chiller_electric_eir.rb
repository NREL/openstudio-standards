require_relative 'minitest_helper'

class TestChillerElectricEir < Minitest::Test

  def test_chiller_electric_eir

    # get method inputs
    template = '90.1-2013'
    standards = 'TBD' #not sure what I'm looking for here

    # make an empty model
    model = OpenStudio::Model::Model.new

    # make ruleset schedule
    chiller = OpenStudio::Model::ChillerElectricEIR.new(model)
    target_cap_tons = 75
    target_cap_watts = OpenStudio.convert(target_cap_tons,"ton","W").get
    chiller.setReferenceCapacity(target_cap_watts)
    puts chiller

    # run standard_minimum_cop
    min_full_load_eff = chiller.standard_minimum_full_load_efficiency(template, standards)

    # todo - check that it returns the correct value
    assert(min_full_load_eff > 0.0)

  end

end

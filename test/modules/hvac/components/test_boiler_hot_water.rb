require_relative '../../../helpers/minitest_helper'

class TestHVACBoilerHotWater < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
  end

  def test_create_boiler_hot_water
    model = OpenStudio::Model::Model.new

    boiler = @hvac.create_boiler_hot_water(model)
    assert(boiler.is_a?(OpenStudio::Model::BoilerHotWater), 'Expected boiler to be a BoilerHotWater object')
    assert_equal('Boiler', boiler.name.to_s, 'Expected boiler name to be Boiler')
    assert_equal('NaturalGas', boiler.fuelType.to_s, 'Expected boiler fuel type to be NaturalGas')
    assert_in_delta(0.8, boiler.nominalThermalEfficiency, 0.01, 'Expected boiler nominal thermal efficiency to be 0.8')
    assert_equal('LeavingBoiler', boiler.efficiencyCurveTemperatureEvaluationVariable.to_s, 'Expected boiler efficiency curve temperature evaluation variable to be LeavingBoiler')
    assert_equal('LeavingSetpointModulated', boiler.boilerFlowMode.to_s, 'Expected boiler flow mode to be LeavingSetpointModulated')
    assert_in_delta(OpenStudio.convert(203.0, 'F', 'C').get, boiler.waterOutletUpperTemperatureLimit, 0.1, 'Expected boiler design water outlet temperature to be 180.0 F')
    assert_in_delta(0.0, boiler.minimumPartLoadRatio, 0.01, 'Expected boiler minimum load to be 0.0')
    assert_in_delta(1.2, boiler.maximumPartLoadRatio, 0.01, 'Expected boiler maximum load to be 1.2')
    assert_in_delta(1.0, boiler.optimumPartLoadRatio, 0.01, 'Expected boiler optimal load to be 1.0')
    assert_in_delta(1.0, boiler.sizingFactor, 0.01, 'Expected boiler sizing factor to be 1.0')
  end
end

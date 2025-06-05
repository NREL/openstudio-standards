require_relative '../../../helpers/minitest_helper'

class TestHVACCoilHeatingGas < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
  end

  def test_create_coil_heating_gas
    model = OpenStudio::Model::Model.new

    coil = @hvac.create_coil_heating_gas(model)
    assert(coil.is_a?(OpenStudio::Model::CoilHeatingGas), 'Expected coil to be a CoilHeatingGas object')
  end
end

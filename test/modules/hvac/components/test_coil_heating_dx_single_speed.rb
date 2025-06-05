require_relative '../../../helpers/minitest_helper'

class TestHVACCoilHeatingDXSingleSpeed < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
  end

  def test_create_coil_heating_dx_single_speed
    model = OpenStudio::Model::Model.new

    coil = @hvac.create_coil_heating_dx_single_speed(model)
    assert(coil.is_a?(OpenStudio::Model::CoilHeatingDXSingleSpeed), 'Expected coil to be a CoilHeatingDXSingleSpeed object')
  end
end

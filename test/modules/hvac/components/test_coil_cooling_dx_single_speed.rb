require_relative '../../../helpers/minitest_helper'

class TestHVACCoilCoolingDXSingleSpeed < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
  end

  def test_create_coil_cooling_dx_single_speed
    model = OpenStudio::Model::Model.new

    coil = @hvac.create_coil_cooling_dx_single_speed(model)
    assert(coil.is_a?(OpenStudio::Model::CoilCoolingDXSingleSpeed), 'Expected coil to be a CoilCoolingDXSingleSpeed object')
  end
end

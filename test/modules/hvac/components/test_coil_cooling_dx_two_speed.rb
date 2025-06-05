require_relative '../../../helpers/minitest_helper'

class TestHVACCoilCoolingDXTwoSpeed < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
  end

  def test_create_coil_cooling_dx_two_speed
    model = OpenStudio::Model::Model.new

    coil = @hvac.create_coil_cooling_dx_two_speed(model)
    assert(coil.is_a?(OpenStudio::Model::CoilCoolingDXTwoSpeed), 'Expected coil to be a CoilCoolingDXTwoSpeed object')
  end
end


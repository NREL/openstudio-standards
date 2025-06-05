require_relative '../../../helpers/minitest_helper'

class TestHVACCoilHeatingGasMultiStage < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
  end
end

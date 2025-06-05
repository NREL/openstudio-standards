require_relative '../../../helpers/minitest_helper'

class TestHVACCoil < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
  end
end

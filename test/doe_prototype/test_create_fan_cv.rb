require_relative '../helpers/minitest_helper'

class FanCVTest < Minitest::Test

  def test_create_fan_cv

    # Create OpenStudio Model and standard
    model = OpenStudio::Model::Model.new
    standard = Standard.build('90.1-2013')
    motor_eff = 0.95
    fan = standard.model_create_fan_cv_from_json(model, 'default', motor_efficiency: motor_eff)

    # check recommendation
    assert_in_delta(motor_eff, fan.motorEfficiency, 0.001, "Expected ~#{motor_eff} elevators, but got #{fan.motorEfficiency}.}")
  end
end
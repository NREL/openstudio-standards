require_relative '../../helpers/minitest_helper'

class TestWeatherInformation < Minitest::Test
  def setup
    @weather = OpenstudioStandards::Weather
  end

  def test_model_get_ashrae_climate_zone_number
    model = OpenStudio::Model::Model.new
    std = Standard.build('90.1-2013')
    std.model_set_climate_zone(model, 'ASHRAE 169-2013-4A')

    result = @weather.model_get_ashrae_climate_zone_number(model)
    assert_equal(result, 4)
  end
end

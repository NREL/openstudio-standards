require_relative '../../helpers/minitest_helper'

class TestServiceWaterHeatingComponent < Minitest::Test
  def setup
    @swh = OpenstudioStandards::ServiceWaterHeating
  end

  def test_model_add_water_heater
    model = OpenStudio::Model::Model.new

    # default water heater
    water_heater1 = @swh.model_add_water_heater(model)

    # custom inputs
    volume = OpenStudio.convert(100.0, 'gal', 'm^3').get
    capacity =  OpenStudio.convert(200.0, 'kBtu/hr', 'W').get
    water_heater2 = @swh.model_add_water_heater(model,
                                                water_heater_capacity: volume,
                                                water_heater_volume: capacity)
  end
end

require_relative '../../helpers/minitest_helper'

class TestExteriorLightingCreate < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
    @ext = OpenstudioStandards::ExteriorLighting
  end

  def test_model_create_exterior_lights
    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    model = std.safe_load_model("#{__dir__}/../../../data/geometry/ASHRAEPrimarySchool.osm")
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: climate_zone)

    @ext.model_create_exterior_lights(model,
                                      name: 'Parking Areas and Drives',
                                      power: 0.04,
                                      units: 'W/ft^2',
                                      multiplier: 10000.0)
    lights = model.getExteriorLightsByName('Parking Areas and Drives').get
    assert_in_delta(10000.0, lights.multiplier, 1.0)
    ext_lights_def = lights.exteriorLightsDefinition
    assert_in_delta(0.04, ext_lights_def.designLevel, 0.001)

    @ext.model_create_exterior_lights(model,
                                      name: 'Base Site Allowance',
                                      power: 1000.0)
    lights = model.getExteriorLightsByName('Base Site Allowance').get
    assert_in_delta(1.0, lights.multiplier, 0.001)
    ext_lights_def = lights.exteriorLightsDefinition
    assert_in_delta(1000.0, ext_lights_def.designLevel, 0.001)
  end
end

require_relative 'minitest_helper'

class TestAddExteriorLights < Minitest::Test

  def test_add_exterior_lights

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/example_model_multipliers.osm")
    model = translator.loadModel(path)
    model = model.get

    # gather inputs
    template = '90.1-2013'
    exterior_lighting_zone_number = 3

    # add lights
    exterior_lights = model.add_typical_exterior_lights(template,exterior_lighting_zone_number)

    # check results
    #assert_in_delta(lighting_per_area.to_f, 0.91)

  end

end

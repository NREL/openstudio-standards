require_relative 'minitest_helper'

class TestAddExteriorLights < Minitest::Test

  def test_add_exterior_lights

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/example_model_multipliers.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    template = '90.1-2013'
    exterior_lighting_zone_number = 3

    # add lights
    exterior_lights = model.add_typical_exterior_lights(template,exterior_lighting_zone_number)
    exterior_lights.each do |key,ext_light|
      puts key
      puts ext_light
    end

    # check results
    assert(exterior_lights.size == 4)
    assert(exterior_lights.has_key?("Parking Areas and Drives"))
    assert(exterior_lights.has_key?("Building Facades"))
    assert(exterior_lights.has_key?("Main Entries"))
    assert(exterior_lights.has_key?("Other Doors"))
    assert(exterior_lights["Parking Areas and Drives"].exteriorLightsDefinition.designLevel == 0.1)
    assert(exterior_lights["Parking Areas and Drives"].multiplier == 93150.0)
  end

end

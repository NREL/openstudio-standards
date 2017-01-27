require_relative 'minitest_helper'

class TestAddElevators < Minitest::Test


  def test_add_elevators

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/example_model_multipliers.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2013'
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier > 1.0)
  end

end

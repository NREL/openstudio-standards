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

    # check results
    assert(exterior_lights.size == 4)
    assert(exterior_lights.has_key?("Parking Areas and Drives"))
    assert(exterior_lights.has_key?("Building Facades"))
    assert(exterior_lights.has_key?("Main Entries"))
    assert(exterior_lights.has_key?("Other Doors"))
    assert(exterior_lights["Parking Areas and Drives"].exteriorLightsDefinition.designLevel == 0.1)
    assert(exterior_lights["Parking Areas and Drives"].multiplier == 93150.0)
  end

  def test_add_exterior_lights_small_hotel

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/SmallHotel_5B_2004.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    template = '90.1-2004'
    exterior_lighting_zone_number = 4

    # add lights
    exterior_lights = model.add_typical_exterior_lights(template,exterior_lighting_zone_number)
    #exterior_lights.each do |key,light|
    #  puts light
    #  puts light.exteriorLightsDefinition
    #end

    # check results
    assert(exterior_lights.size == 5)
    assert(exterior_lights.has_key?("Parking Areas and Drives"))
    assert(exterior_lights.has_key?("Building Facades"))
    assert(exterior_lights.has_key?("Main Entries"))
    assert(exterior_lights.has_key?("Other Doors"))
    assert(exterior_lights["Parking Areas and Drives"].exteriorLightsDefinition.designLevel == 0.15)
    assert_in_delta(31185.0,exterior_lights["Parking Areas and Drives"].multiplier,100.0) # 405 ft^2 per spot * 77 rooms * 1 unit per spot
    assert_in_delta(69.0,exterior_lights["Main Entries"].multiplier,1.0) #  8 ft per entry * 2 entries per * 43,202 ft^2  / 10,000 ft^2
    assert_in_delta(499.6,exterior_lights["Other Doors"].multiplier,1.0) #  4 ft per entry * 28.91 entries per * 43,202 ft^2  / 10,000 ft^2
    assert(exterior_lights["Entry Canopies"].multiplier == 720.0)
    assert(exterior_lights["Entry Canopies"].exteriorLightsDefinition.designLevel == 1.25)

  end

  def test_add_exterior_lights_hospital

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/Hospital_4B_Pre1980.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    template = 'DOE Ref Pre-1980'
    exterior_lighting_zone_number = 4

    # add lights
    exterior_lights = model.add_typical_exterior_lights(template,exterior_lighting_zone_number)
    #exterior_lights.each do |key,light|
    #  puts light
    #  puts light.exteriorLightsDefinition
    #end

    # check results
    assert(exterior_lights.size == 5)
    assert(exterior_lights.has_key?("Parking Areas and Drives"))
    assert(exterior_lights.has_key?("Building Facades"))
    assert(exterior_lights.has_key?("Main Entries"))
    assert(exterior_lights.has_key?("Other Doors"))
    assert(exterior_lights["Parking Areas and Drives"].exteriorLightsDefinition.designLevel == 0.18)
    assert_in_delta(122000.0,exterior_lights["Parking Areas and Drives"].multiplier,1000.0) # 405 ft^2 per spot * 250 beds / 0.83 beds per spot
    assert(exterior_lights["Emergency Canopies"].multiplier == 720.0)
    assert(exterior_lights["Emergency Canopies"].exteriorLightsDefinition.designLevel == 4.0)

  end

  def test_add_exterior_lights_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/SecondarySchool_6A_1980-2004.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    template = 'DOE Ref 1980-2004'
    exterior_lighting_zone_number = 2

    # add lights
    exterior_lights = model.add_typical_exterior_lights(template,exterior_lighting_zone_number)
    #exterior_lights.each do |key,light|
    #  puts light
    #  puts light.exteriorLightsDefinition
    #end

    # check results
    assert(exterior_lights.size == 4)
    assert(exterior_lights.has_key?("Parking Areas and Drives"))
    assert(exterior_lights.has_key?("Building Facades"))
    assert(exterior_lights.has_key?("Main Entries"))
    assert(exterior_lights.has_key?("Other Doors"))
    assert(exterior_lights["Parking Areas and Drives"].exteriorLightsDefinition.designLevel == 0.18)
    assert_in_delta(83075.0,exterior_lights["Parking Areas and Drives"].multiplier,100.0) # 405 ft^2 per spot * 1641 students / 8.0

  end

  def test_add_exterior_lights_quick_service

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/QuickServiceRestaurant_2A_2010.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    template = '90.1-2010'
    exterior_lighting_zone_number = 1

    # add lights
    exterior_lights = model.add_typical_exterior_lights(template,exterior_lighting_zone_number)
    #exterior_lights.each do |key,light|
    #  puts light
    #  puts light.exteriorLightsDefinition
    #end

    # check results
    assert(exterior_lights.size == 5)
    assert(exterior_lights.has_key?("Parking Areas and Drives"))
    assert(exterior_lights.has_key?("Building Facades"))
    assert(exterior_lights.has_key?("Main Entries"))
    assert(exterior_lights.has_key?("Other Doors"))
    assert(exterior_lights.has_key?("Drive Through Windows"))
    assert(exterior_lights["Parking Areas and Drives"].exteriorLightsDefinition.designLevel == 0.04)
    assert_in_delta(1.0,exterior_lights["Drive Through Windows"].multiplier,0.001) # 2501 ft^2 / drive through per 2501

  end

end

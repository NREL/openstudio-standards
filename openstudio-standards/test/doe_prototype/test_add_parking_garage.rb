require_relative '../helpers/minitest_helper'

class TestAddParkingGarage < Minitest::Test

  def test_add_parking_garage_4_story

    @msg_log = OpenStudio::StringStreamLogSink.new

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/ParkingGarage_4story.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    #template = '90.1-2013'

    # add lights
    parking_garage = model.add_typical_parking_garage

    # check results
    assert(parking_garage.size == 3)
    assert(parking_garage[:lights].size == 1)
    assert(parking_garage[:elec_equip].size > 2) # one for general assigned to space type, and charging for each space type
    assert(parking_garage[:ext_lights].size == 2) # one for rooftop ext lights, the other for rooftop charging

    @msg_log.logMessages.each do |msg|
      next if msg.logMessage.include?("Adding object with handle")
      next if msg.logMessage.include?("objectImplPtr")
      next if msg.logMessage.include?("idfObject")
      puts msg.logMessage
    end

  end

  def test_add_parking_surface

    @msg_log = OpenStudio::StringStreamLogSink.new

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/ParkingSurface.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    #template = '90.1-2013'

    # add lights
    parking_garage = model.add_typical_parking_garage

    # check results
    assert(parking_garage.size == 3)
    assert(parking_garage[:lights].size == 0)
    assert(parking_garage[:elec_equip].size == 0)
    assert(parking_garage[:ext_lights].size == 2) # one for surface ext lights, the other for surface charging

    @msg_log.logMessages.each do |msg|
      next if msg.logMessage.include?("Adding object with handle")
      next if msg.logMessage.include?("objectImplPtr")
      next if msg.logMessage.include?("idfObject")
      puts msg.logMessage
    end

  end

end

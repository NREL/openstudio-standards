require_relative 'minitest_helper'

class TestAddSwh < Minitest::Test

  def test_add_swh_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/SecondarySchool_6A_1980-2004.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    template = 'DOE Ref 1980-2004'

    # add_typical_swh
    typical_swh = model.add_typical_swh(template)
    typical_swh.each do |loop|
      puts loop.name
    end

    # check results
    assert(typical_swh.size == 2)

  end

  def test_add_swh_midrise

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/MidriseApartment_2A_2013.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    template = '90.1-2013'

    # add_typical_swh
    typical_swh = model.add_typical_swh(template)
    typical_swh.each do |loop|
      puts loop.name
    end

    # check results
    assert(typical_swh.size == 31)

  end

  def test_add_swh_stripmall

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/RetailStripmall_2A_2004.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    template = '90.1-2004'

    model.getPlantLoops.each do |loop|
      loop.remove
    end

    # add_typical_swh
    typical_swh = model.add_typical_swh(template)
    typical_swh.each do |loop|
      puts loop.name
    end

    # check results
    assert(typical_swh.size == 11)

  end

  def test_add_swh_multiuse

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/Multiuse_Office_LargeHotel.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio::convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    # gather inputs
    template = '90.1-2010'

    model.getPlantLoops.each do |loop|
      loop.remove
    end

    # add_typical_swh
    typical_swh = model.add_typical_swh(template)
    typical_swh.each do |loop|
      puts loop.name
    end

    # check results
    assert(typical_swh.size == 2)

  end

end

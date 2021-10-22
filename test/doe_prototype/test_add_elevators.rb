require_relative '../helpers/minitest_helper'

class TestAddElevators < Minitest::Test


  def test_add_elevators_office

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/example_model_multipliers.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2013'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 3.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/Office.osm", true)
  end

  def test_add_elevators_small_hotel

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/SmallHotel_5B_2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2004'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 2.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/SmallHotel.osm", true)
  end

  def test_add_elevators_large_hotel

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/LargeHotel_3A_2010.osm")
    model = translator.loadModel(path)
    model = model.get
    # create story hash
    template = '90.1-2010'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 6.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/LargeHotel.osm", true)
  end

  def test_add_elevators_midrise

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MidriseApartment_2A_2013.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2013'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 1.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/Midrise.osm", true)
  end

  def test_add_elevators_hospital

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/Hospital_4B_Pre1980.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref Pre-1980'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 8.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    assert(elevators.definition.to_ElectricEquipmentDefinition.get.fractionLost == 1.0)
    model.save("output/Hospital.osm", true)
  end

  def test_add_elevators_outpatient

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/Outpatient_7A_2010.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2010'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 3.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/Outpatient.osm", true)
  end

  def test_add_elevators_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/SecondarySchool_6A_1980-2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 3.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/SecondarySchool.osm", true)
  end

  def test_add_elevators_multi_story_retail

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryRetail.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 3.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/Retail.osm", true)
  end

  def test_add_elevators_multi_story_warehouse

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryWarehouse.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 3.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/Warehouse.osm", true)
  end

end

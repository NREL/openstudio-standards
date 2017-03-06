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
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier > 1.0)
  end

  def test_add_elevators_small_hotel

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/SmallHotel_5B_2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2004'
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier > 1.0)
  end

  def test_add_elevators_large_hotel

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/LargeHotel_3A_2010.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2010'
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier > 1.0)
  end

  def test_add_elevators_midrise

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MidriseApartment_2A_2013.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2013'
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier >= 1.0)
  end

  def test_add_elevators_hospital

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/Hospital_4B_Pre1980.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref Pre-1980'
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier >= 6.5)
    assert(elevators.definition.to_ElectricEquipmentDefinition.get.fractionLost == 1.0)
  end

  def test_add_elevators_outpatient

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/Outpatient_7A_2010.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = '90.1-2010'
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier == 0.0)
  end

  def test_add_elevators_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/SecondarySchool_6A_1980-2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier >= 1.0)
  end

  def test_add_elevators_multi_story_retail

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryRetail.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier >= 1.0)
  end

  def test_add_elevators_multi_story_warehouse

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryWarehouse.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'
    elevators = model.add_elevators(template)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    assert(elevators.multiplier >= 1.0)
  end

end

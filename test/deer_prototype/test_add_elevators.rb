require_relative '../helpers/minitest_helper'

class TestAddElevators < Minitest::Test


  def test_add_elevators_office

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/ofl_test.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DEER 2007'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 5.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/ofL.osm", true)
  end

  def test_add_elevators_hotel

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/htl_test.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DEER 1985'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 9.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/Htl.osm", true)
  end

  def test_add_elevators_university

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/eun_test.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DEER 2011'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 5.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/EUn.osm", true)
  end

  def test_add_elevators_multifamily

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/mfm_test.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DEER 1996'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 1.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/MFm.osm", true)
  end

  def test_add_elevators_hospital

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/hsp_test.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DEER 2025'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 7.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    assert(elevators.definition.to_ElectricEquipmentDefinition.get.fractionLost == 1.0)
    model.save("output/Hsp.osm", true)
  end

  def test_add_elevators_nursing

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/nrs_test.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DEER 2017'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 3.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/Nrs.osm", true)
  end

  def test_add_elevators_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/ese_test.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DEER 2045'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 1.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/ESe.osm", true)
  end

  def test_add_elevators_multi_story_retail

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/rt3_test.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DEER 2065'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 3.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/rt3.osm", true)
  end

  def test_add_elevators_multi_story_warehouse

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/wrf_test.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DEER Pre-1975'
    standard = Standard.build(template)
    elevators = standard.model_add_elevators(model)

    puts "Building floor area is #{OpenStudio.convert(model.getBuilding.floorArea,'m^2','ft^2')}"
    puts elevators

    # check recommendation
    expected_elev = 0.0
    assert_in_delta(expected_elev, elevators.multiplier, 0.5, "Expected ~#{expected_elev} elevators, but got #{elevators.multiplier}.}")
    model.save("output/WRf.osm", true)
  end

end
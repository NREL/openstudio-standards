require_relative '../helpers/minitest_helper'

class TestAddRefrigeration < Minitest::Test

  def test_add_refrigeration_case
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryRetail.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio.convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    template = 'DEER 2014'
    standard = Standard.build(template)

    add_case = standard.model_add_refrigeration_case(model, model.getThermalZones[0], "Prepared Foods Cases", ">50k ft2")

    # Check case length
    assert_equal(OpenStudio.convert(56,"ft","m").get, add_case.caseLength)
    # Check case operating temperature
    assert_in_epsilon(add_case.caseOperatingTemperature,OpenStudio.convert(27,"F","C").get,0.5) # kBtu/hr
  end

  def test_add_refrigeration_walkin
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryRetail.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio.convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    template = 'DEER 1996'
    standard = Standard.build(template)
    add_walkin = standard.model_add_refrigeration_walkin(model, model.getThermalZones[0], "<35k ft2", "Beer Cooler")

    # Check case length
    assert_equal(238.6, add_walkin.ratedTotalLightingPower)
    # Check case operating temperature
    assert_in_epsilon(add_walkin.operatingTemperature,OpenStudio.convert(35,"F","C").get,0.5) # kBtu/hr
  end

  def test_add_refrigeration_compressor
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryRetail.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio.convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    template = 'DEER 1996'
    standard = Standard.build(template)
    assert(standard.model_add_refrigeration_compressor(model, "LT compressor_SmallandOld"))
  end

  def test_add_typical_refrigeration
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryRetail.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio.convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."

    reset_log

    template = 'DEER 1996'
    standard = Standard.build(template)
    standard.model_add_typical_refrigeration(model, 'Gro')

    # Log the messages
    # log_messages_to_file("#{__dir__}/output/test_add_typical_refrigeration_openstudio-standards.log", debug=false)

    mt_system = model.getRefrigerationSystemByName('Medium Temperature').get

    # check ref system refrigerant
    assert_equal('R404a', mt_system.refrigerationSystemWorkingFluidType)

    # check compressors
    assert_equal(11, mt_system.compressors.size)

    # check fan power
    assert_equal(2, model.getRefrigerationCondenserAirCooleds.size)
    # assert(mt_system.refrigerationCondenser.ratedFanPower

    # check cases
    assert_equal(14, mt_system.cases.size)

    # check walkins
    assert_equal(8, mt_system.walkins.size)

    lt_system = model.getRefrigerationSystemByName('Low Temperature').get

    # check compressors
    assert_equal(9, lt_system.compressors.size)

    # check cases
    assert_equal(3, lt_system.cases.size)

    # check walkins
    assert_equal(2, lt_system.walkins.size)
  end
end

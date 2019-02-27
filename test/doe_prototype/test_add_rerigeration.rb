require_relative '../helpers/minitest_helper'

class TestAddRefrigeration < Minitest::Test

  def test_add_refrigeration_case

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryRetail.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio.convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."
    puts "Thermal zones are: "
    tz = []
    model.getThermalZones.each do |zone|
      tz = zone
    end

    template = 'DEER 2014'
    standard = Standard.build(template)
    # add_case =
    # puts tz)

    add_case = standard.model_add_refrigeration_case(model, tz, "Prepared Foods Cases", ">50k ft2")

    puts add_case.caseLength
    # Check case length
    assert(add_case.caseLength == OpenStudio.convert(56,"ft","m").get)
    # Check case operating temperature
    assert_in_epsilon(add_case.caseOperatingTemperature,OpenStudio.convert(27,"F","C").get,0.5) # kBtu/hr
    #
  end


  def test_add_refrigeration_walkin
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/MultiStoryRetail.osm")
    model = translator.loadModel(path)
    model = model.get
    puts "Test building area is #{OpenStudio.convert(model.getBuilding.floorArea,"m^2","ft^2").get.round} ft^2."
    puts "Thermal zones are: "
    tz = []
    model.getThermalZones.each do |zone|
      tz = zone
    end

    template = 'DEER 1996'
    standard = Standard.build(template)
    add_walkin = standard.model_add_refrigeration_walkin(model, tz, "<35k ft2", "Beer Cooler")

    # Check case length
    assert(add_walkin.ratedTotalLightingPower == 238.6)
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
    # puts "Thermal zones are: "
    tz = []
    model.getThermalZones.each do |zone|
      tz = zone
    end

    template = 'DEER 1996'
    standard = Standard.build(template)
    standard.model_add_typical_refrigeration(model, '5A' , tz, tz)
    mt_system = model.getRefrigerationSystemByName('Medium Temperature').get
    #check ref system refrigerant
    assert(mt_system.refrigerationSystemWorkingFluidType == 'R404a')
    # check compressors
    assert (mt_system.compressors.size == 22)
    # check fan power
    assert(model.getRefrigerationCondenserAirCooleds.size==2)
    # assert(mt_system.refrigerationCondenser.ratedFanPower
    # check cases
    assert (mt_system.cases.size == 14)
    #check walkins
    assert (mt_system.walkins.size == 8)


    # template = 'DEER 2011'
    # standard = Standard.build(template)
    # standard.model_add_typical_refrigeration(model, '5A' , tz, tz)
    lt_system = model.getRefrigerationSystemByName('Low Temperature').get
    # check compressors
    assert (lt_system.compressors.size == 18)
    # check cases
    assert (lt_system.cases.size == 3)
    #check walkins
    assert (lt_system.walkins.size == 2)


  end


end

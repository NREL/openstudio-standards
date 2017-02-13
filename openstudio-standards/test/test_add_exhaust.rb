require_relative 'minitest_helper'

class TestAddExhaust < Minitest::Test


  def test_zone_add_exhaust_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/SecondarySchool_6A_1980-2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'

    zone_exhaust_fans = {}

    # loop through thermal zones and add exhaust where needed
    model.getThermalZones.each do |thermal_zone|
      zone_exhaust_hash = thermal_zone.add_exhaust(template)

      # pouplate zone_exhaust_fans
      zone_exhaust_fans.merge!(zone_exhaust_hash)

      # assert values
      object = zone_exhaust_hash.keys.first
      if thermal_zone.name.to_s.include?("Kitchen")
        assert_in_delta(0.768096,object.maximumFlowRate.get,0.01)
        assert_in_delta(0.16,object.fanEfficiency,0.1)
        assert_in_delta(124.5,object.pressureRise,0.1)
      elsif thermal_zone.name.to_s.include?("Bathrooms")
        assert_in_delta(0.300,object.maximumFlowRate.get,0.01)
      end

    end

    # check results
    assert(zone_exhaust_fans.size == 3) # two bathrooms and a kitchen
  end

  def test_model_add_exhaust_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/SecondarySchool_6A_1980-2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'

    # add exhaust
    zone_exhaust_fans = model.add_exhaust(template,"None")

    #zone_exhaust_fans.each do |zone_exhaust_fan,hash|
    #  puts zone_exhaust_fan
    #end

    # check results
    assert(zone_exhaust_fans.size == 3) # two bathrooms and a kitchen

  end

  def test_model_add_exhaust_secondary_largest_zone_makup

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/SecondarySchoolSlicedBar.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'

    # add exhaust
    zone_exhaust_fans = model.add_exhaust(template,"Largest Zone")

    zone_exhaust_fans.each do |zone_exhaust_fan,hash|

      puts zone_exhaust_fan

      # assert values
      if zone_exhaust_fan.name.to_s.include?("Kitchen")
        # custom floor area for three kitchen zones 2200 ft^2 * 0.7 cfm per ft^2 = 1540 cfm = 0.7268 m^3/s
        assert_in_delta(0.7268,zone_exhaust_fan.maximumFlowRate.get,0.01)

        # assert that these objects were made
        assert(hash.has_key?(:zone_mixing))
        assert(hash.has_key?(:transfer_air_source_zone_exhaust))
        assert_in_delta(0.7268 * 0.746,hash[:zone_mixing].designFlowRate.get,0.01)

        puts hash[:zone_mixing]
        puts hash[:transfer_air_source_zone_exhaust]

      end
    end

    # check results
    assert(zone_exhaust_fans.size == 4) # three bathrooms and a kitchen

  end

  def test_model_add_exhaust_secondary_largest_zone_makup_missing_source

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/ExhaustMissingMakeUpTest.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'

    # add exhaust
    zone_exhaust_fans = model.add_exhaust(template,"Largest Zone")

    #zone_exhaust_fans.each do |zone_exhaust_fan,hash|
    #  puts zone_exhaust_fan
    #end

    # check results
    assert(zone_exhaust_fans.size == 1) # kitchen

  end

  # todo - add test with multiple space types in zone where both zones needs exhaust


end

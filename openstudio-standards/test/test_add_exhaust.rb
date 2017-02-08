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


  # todo - add test with multiple space types in zone where one zone needs exhaust


  # todo - add test with multiple space types in zone where both zones needs exhaust


  def test_model_add_exhaust_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/SecondarySchool_6A_1980-2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'

    # add exhaust
    zone_exhaust_fans = model.add_exhaust(template)

    zone_exhaust_fans.each do |zone_exhaust_fan,hash|
      puts zone_exhaust_fan
    end

    # check results
    assert(zone_exhaust_fans.size == 3) # two bathrooms and a kitchen

  end

end

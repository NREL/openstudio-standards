require_relative 'minitest_helper'

class TestAddExhaust < Minitest::Test


  def test_add_exhaust_secondary

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/SecondarySchool_6A_1980-2004.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    template = 'DOE Ref 1980-2004'

    zones_with_exhaust = []

    # loop through thermal zones and add exhaust where needed
    model.getThermalZones.each do |thermal_zone|
      puts "Adding exhaust to #{thermal_zone.name}"
      exhaust = thermal_zone.add_exhaust(template)
      if exhaust.size > 0
        zones_with_exhaust << exhaust
      end

      # assert values
      if thermal_zone.name.to_s.include?("Kitchen")
        object = exhaust.first
        assert_in_delta(0.768096,object.maximumFlowRate.get,0.01)
      elsif thermal_zone.name.to_s.include?("Bathrooms")
        object = exhaust.first
        assert_in_delta(0.300,object.maximumFlowRate.get,0.01)
      end

      puts exhaust
    end

    # check recommendation
    assert(zones_with_exhaust.size == 3) # two bathrooms and a kitchen
  end

  # todo - add test with multiple space types in zone where one zone needs exhaust

  # todo - add test with multiple space types in zone where both zones needs exhaust


end

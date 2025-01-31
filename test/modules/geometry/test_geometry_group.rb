require_relative '../../helpers/minitest_helper'

class TestGeometryGroup < Minitest::Test
  def setup
    @geo = OpenstudioStandards::Geometry

    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    @model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAESecondarySchool.osm")
  end

  def test_model_group_thermal_zones_by_building_story
    result = @geo.model_group_thermal_zones_by_building_story(@model, @model.getThermalZones)
    assert(2, result.size)
  end

  def test_model_group_thermal_zones_by_occupancy_type
    result = @geo.model_group_thermal_zones_by_occupancy_type(@model)
    assert(1, result.size)
  end

  def test_model_group_thermal_zones_by_building_type
    result = @geo.model_group_thermal_zones_by_building_type(@model)
    assert(1, result.size)
  end
end
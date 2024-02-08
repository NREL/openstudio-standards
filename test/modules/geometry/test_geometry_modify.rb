require_relative '../../helpers/minitest_helper'

class TestGeometryModify < Minitest::Test
  def setup
    @geo = OpenstudioStandards::Geometry

    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    @model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAESecondarySchool.osm")
  end

  def test_model_set_building_north_axis
    result = @geo.model_set_building_north_axis(@model, 45.0)
    assert(result)
    assert(45.0, @model.getBuilding.northAxis)
  end

  def test_model_assign_spaces_to_building_stories
    result = @geo.model_assign_spaces_to_building_stories(@model)
    assert(result)
  end
end
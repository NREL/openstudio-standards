require_relative '../../helpers/minitest_helper'

class TestGeometryCreate < Minitest::Test
  def setup
    @geo = OpenstudioStandards::Geometry

    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    @model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAEPrimarySchool.osm")
  end

  def test_space_create_point_at_center_of_floor
    space = @model.getSpaces[0]
    result = @geo.space_create_point_at_center_of_floor(space, 2.0)
    assert_equal(2.0, result.z)
  end

  def test_sub_surface_create_point_at_specific_height
    # result = @geo.sub_surface_create_point_at_specific_height(sub_surface, reference_floor, distance_from_window_m, height_above_subsurface_bottom_m)
    # assert(result)
  end
end
require_relative '../helpers/minitest_helper'

class TestGeometryInformation < Minitest::Test
  def setup
    @geo = OpenstudioStandards::Geometry

    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    @model = std.safe_load_model("#{File.dirname(__FILE__)}/../../data/geometry/ASHRAEPrimarySchool.osm")
  end

  def test_aspect_ratio
    result = @geo.aspect_ratio(400.0, 80.0)
    assert_equal(result, 1.0)

    result = @geo.aspect_ratio(400.0, 160.0)
    assert_equal(result.round(2), 13.93)
  end

  def test_surfaces_get_z_values
    surfaces = @model.getSurfaces.select { |s| s.outsideBoundaryCondition == 'Ground' }
    result = @geo.surfaces_get_z_values(surfaces)
    assert(result.size > 10)
    assert(result.max, 0)
  end

  def test_surfaces_contain_point?
    surfaces = @model.getSurfaces.select { |s| s.outsideBoundaryCondition == 'Ground' }
    point = OpenStudio::Point3d.new(2.0, 4.0, 0.0)
    result = @geo.surfaces_contain_point?(surfaces, point)
    assert(result)

    point = OpenStudio::Point3d.new(-2.0, 4.0, 0.0)
    result = @geo.surfaces_contain_point?(surfaces, point)
    assert_equal(result, false)
  end

  def test_spaces_get_floor_area
    result = @geo.spaces_get_floor_area(@model.getSpaces)
    assert_equal(result.round(0), 6871)
  end

  def test_spaces_get_exterior_wall_area
    result = @geo.spaces_get_exterior_wall_area(@model.getSpaces)
    assert_equal(result.round(0), 2512)
  end

  def test_spaces_get_exterior_area
    result = @geo.spaces_get_exterior_area(@model.getSpaces)
    assert_equal(result.round(0), 9383)
  end

  def test_story_get_exterior_wall_perimeter
    story = @model.getBuildingStorys[0]
    result = @geo.story_get_exterior_wall_perimeter(story)
    assert_equal(result[:perimeter].round(0), 619)
  end

  def test_model_get_exterior_window_to_wall_ratio
    result = @geo.model_get_exterior_window_to_wall_ratio(@model, spaces: [])
    assert_equal(result.round(2), 0.37)
  end

  def test_model_get_exterior_window_and_wall_area_by_orientation
    result = @geo.model_get_exterior_window_and_wall_area_by_orientation(@model, spaces: [])
    assert_equal(result['north_wall'].round(0), 928)
    assert_equal(result['north_window'].round(0), 344)
    assert_equal(result['east_wall'].round(0), 328)
    assert_equal(result['east_window'].round(0), 121)
  end

  def test_model_get_perimeter_length
    result = @geo.model_get_perimeter_length(@model)
    assert_equal(result.round(0), 619)
  end
end
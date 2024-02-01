require_relative '../../helpers/minitest_helper'

class TestGeometryInformation < Minitest::Test
  def setup
    @geo = OpenstudioStandards::Geometry

    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    @model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAESecondarySchool.osm")
  end

  # Information:Calculations

  def test_aspect_ratio
    result = @geo.aspect_ratio(400.0, 80.0)
    assert_equal(result, 1.0)

    result = @geo.aspect_ratio(400.0, 160.0)
    assert_equal(result.round(2), 13.93)
  end

  def test_wall_and_floor_intersection_length

    wall_surface = @model.getSurfaceByName('Aux_Gym_ZN_1_FLR_1_Wall_1').get
    floor_surface = @model.getSurfaceByName('Aux_Gym_ZN_1_FLR_1_Floor').get
    result = @geo.wall_and_floor_intersection_length(wall_surface, floor_surface)
    assert_equal(24, result.round(0))
  end

  # Information:Surface

  def test_surface_get_edges
    floor_surface = @model.getSurfaceByName('Aux_Gym_ZN_1_FLR_1_Floor').get
    result = @geo.surface_get_edges(floor_surface)
    assert_equal(4, result.size)
  end

  # Information:Surfaces

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

  # Information:Space

  # def test_space_get_envelope_area
  #   space = @model.getSpaceByName('Aux_Gym_ZN_1_FLR_1').get
  #   result = @geo.space_get_envelope_area(space)
  # end

  def test_space_get_exterior_wall_and_subsurface_area
    space = @model.getSpaceByName('Aux_Gym_ZN_1_FLR_1').get
    result = @geo.space_get_exterior_wall_and_subsurface_area(space)
    assert_equal(608, result.round(0))
  end

  def test_space_get_exterior_wall_and_subsurface_and_roof_area
    space = @model.getSpaceByName('Aux_Gym_ZN_1_FLR_1').get
    result = @geo.space_get_exterior_wall_and_subsurface_and_roof_area(space)
    assert_equal(1856, result.round(0))
  end

  def test_space_get_adjacent_spaces_with_shared_wall_areas
    space = @model.getSpaceByName('Aux_Gym_ZN_1_FLR_1').get
    result = @geo.space_get_adjacent_spaces_with_shared_wall_areas(space)
    assert_equal('Gym_ZN_1_FLR_1', result[0][0].name.get)
    assert_equal(416, result[0][1].round(0))
  end

  def test_space_get_adjacent_space_with_most_shared_wall_area
    space = @model.getSpaceByName('Aux_Gym_ZN_1_FLR_1').get
    result = @geo.space_get_adjacent_space_with_most_shared_wall_area(space)
    assert_equal('Gym_ZN_1_FLR_1', result.name.get)
  end

  def test_space_get_below_grade_wall_height
    space = @model.getSpaceByName('Aux_Gym_ZN_1_FLR_1').get
    result = @geo.space_get_below_grade_wall_height(space)
    assert_nil(result)
  end

  def test_space_get_f_floor_perimeter
    space = @model.getSpaceByName('Aux_Gym_ZN_1_FLR_1').get
    result = @geo.space_get_f_floor_perimeter(space)
    assert_equal(76.0, result.round(0))
  end

  def test_space_get_f_floor_area
    space = @model.getSpaceByName('Aux_Gym_ZN_1_FLR_1').get
    result = @geo.space_get_f_floor_area(space)
    assert_equal(1248, result.round(0))
  end

  # Information:Spaces

  def test_spaces_get_floor_area
    result = @geo.spaces_get_floor_area(@model.getSpaces)
    assert_equal(19592, result.round(0))
  end

  def test_spaces_get_exterior_wall_area
    result = @geo.spaces_get_exterior_wall_area(@model.getSpaces)
    assert_equal(5968, result.round(0))
  end

  def test_spaces_get_exterior_area
    result = @geo.spaces_get_exterior_area(@model.getSpaces)
    assert_equal(17870, result.round(0))
  end

  # Information:ThermalZone
  def test_thermal_zone_get_adjacent_zones_with_shared_walls
    thermal_zone = story = @model.getThermalZones[0]
    result = @geo.thermal_zone_get_adjacent_zones_with_shared_walls(thermal_zone)
    assert_equal(2, result.size)
    assert_equal('OpenStudio::Model::ThermalZone', result[0].class.to_s)
  end

  # Information:Story

  def test_building_story_get_exterior_wall_perimeter
    story = @model.getBuildingStorys[0]
    result = @geo.building_story_get_exterior_wall_perimeter(story)
    assert_equal(708, result[:perimeter].round(0))
  end

  def test_building_story_get_floor_multiplier
    story = @model.getBuildingStorys[0]
    result = @geo.building_story_get_floor_multiplier(story)
    assert_equal(1, result)
  end

  def test_building_story_get_minimum_height
    story = @model.getBuildingStorys.sort[1]
    result = @geo.building_story_get_minimum_height(story)
    assert_equal(4.0, result)
  end

  def test_building_story_get_thermal_zones
    story = @model.getBuildingStorys.sort[1]
    result = @geo.building_story_get_thermal_zones(story)
    assert_equal(21, result.size)
  end

  # Information:Model

  def test_model_get_building_story_for_nominal_height
    story = @model.getBuildingStorys.sort[1]
    result = @geo.model_get_building_story_for_nominal_height(@model, 4.1)
    assert_equal('Building Story 2', result.name.to_s)
  end

  def test_model_get_building_stories_above_ground
    result = @geo.model_get_building_stories_above_ground(@model)
    assert_equal(2, result.size)
  end

  def test_model_get_building_stories_below_ground
    result = @geo.model_get_building_stories_below_ground(@model)
    assert_equal(0, result.size)
  end

  def test_model_get_exterior_window_to_wall_ratio
    result = @geo.model_get_exterior_window_to_wall_ratio(@model, spaces: [])
    assert_equal(0.36, result.round(2))
  end

  def test_model_get_exterior_window_and_wall_area_by_orientation
    result = @geo.model_get_exterior_window_and_wall_area_by_orientation(@model, spaces: [])
    assert_equal(2152, result['north_wall'].round(0))
    assert_equal(777, result['north_window'].round(0))
    assert_equal(832, result['east_wall'].round(0))
    assert_equal(299, result['east_window'].round(0))
  end

  def test_model_get_perimeter_length
    result = @geo.model_get_perimeter_length(@model)
    assert_equal(708, result.round(0))
  end
end
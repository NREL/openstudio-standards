require_relative '../../helpers/minitest_helper'

class TestInfiltration < Minitest::Test
  def setup
    @infiltration = OpenstudioStandards::Infiltration

    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    @model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAESecondarySchool.osm")
  end

  def test_adjust_infiltration_to_new_pressure
    result = @infiltration.adjust_infiltration_to_new_pressure(15.0)
    assert_in_delta(2.2317, result, 0.001)

    result = @infiltration.adjust_infiltration_to_new_pressure(10.0, final_pressure: 10.0)
    assert_in_delta(2.699, result, 0.001)

    result = @infiltration.adjust_infiltration_to_new_pressure(5.0, initial_pressure: 50.0, final_pressure: 2.0)
    assert_in_delta(0.617, result, 0.001)
  end

  def test_adjust_infiltration_to_prototype_building_conditions
    result = @infiltration.adjust_infiltration_to_prototype_building_conditions(15.0)
    assert_in_delta(1.6818, result, 0.001)

    result = @infiltration.adjust_infiltration_to_prototype_building_conditions(10.0)
    assert_in_delta(1.1212, result, 0.001)

    result = @infiltration.adjust_infiltration_to_prototype_building_conditions(5.0, initial_pressure: 50.0)
    assert_in_delta(0.72965, result, 0.001)
  end

  def test_surface_component_infiltration_rate
    roof = @model.getSurfaceByName('Aux_Gym_ZN_1_FLR_2_Ceiling').get
    wall = @model.getSurfaceByName('Aux_Gym_ZN_1_FLR_1_Wall_1').get
    floor = @model.getSurfaceByName('Aux_Gym_ZN_1_FLR_1_Floor').get
    indoor_wall = @model.getSurfaceByName('Aux_Gym_ZN_1_FLR_1_Wall_3').get

    result = @infiltration.surface_component_infiltration_rate(roof)
    expected_result = OpenStudio.convert(0.12 * OpenStudio.convert(roof.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.surface_component_infiltration_rate(roof, type: 'advanced')
    expected_result = OpenStudio.convert(0.04 * OpenStudio.convert(roof.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.surface_component_infiltration_rate(wall)
    expected_result = OpenStudio.convert(0.12 * OpenStudio.convert(wall.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.surface_component_infiltration_rate(wall, type: 'advanced')
    expected_result = OpenStudio.convert(0.04 * OpenStudio.convert(wall.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.surface_component_infiltration_rate(floor)
    expected_result = OpenStudio.convert(0.12 * OpenStudio.convert(floor.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.surface_component_infiltration_rate(floor, type: 'advanced')
    expected_result = OpenStudio.convert(0.04 * OpenStudio.convert(floor.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.surface_component_infiltration_rate(indoor_wall)
    assert(0.0, result)
  end

  def test_sub_surface_component_infiltration_rate
    skylight = @model.getSubSurfaceByName('Aux_Gym_ZN_1_FLR_2_skylight_1').get
    window = @model.getSubSurfaceByName('Aux_Gym_ZN_1_FLR_1_Wall_2_window_1').get
    door = @model.getSubSurfaceByName('Aux_Gym_ZN_1_FLR_1_Wall_2_Door1').get

    result = @infiltration.sub_surface_component_infiltration_rate(skylight)
    expected_result = OpenStudio.convert(0.40 * OpenStudio.convert(skylight.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.sub_surface_component_infiltration_rate(skylight, type: 'advanced')
    expected_result = OpenStudio.convert(0.20 * OpenStudio.convert(skylight.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.sub_surface_component_infiltration_rate(window)
    expected_result = OpenStudio.convert(0.40 * OpenStudio.convert(window.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.sub_surface_component_infiltration_rate(window, type: 'advanced')
    expected_result = OpenStudio.convert(0.20 * OpenStudio.convert(window.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.sub_surface_component_infiltration_rate(door)
    expected_result = OpenStudio.convert(0.40 * OpenStudio.convert(door.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")

    result = @infiltration.sub_surface_component_infiltration_rate(door, type: 'advanced')
    expected_result = OpenStudio.convert(0.20 * OpenStudio.convert(door.netArea, 'm^2', 'ft^2').get, 'cfm', 'm^3/s').get
    assert_in_delta(expected_result, result, 0.01, "Expected #{expected_result} m^3/s but got #{result} m^3/s")
  end
end
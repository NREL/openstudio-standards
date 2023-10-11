require_relative '../../helpers/minitest_helper'

class TestDaylighting < Minitest::Test
  def setup
    @daylight = OpenstudioStandards::Daylighting
  end

  def test_space_add_daylight_sensor
    model = OpenStudio::Model::Model.new
    polygon = OpenStudio::Point3dVector.new
    origin = OpenStudio::Point3d.new(0.0, 0.0, 0.0)
    polygon << origin
    polygon << origin + OpenStudio::Vector3d.new(0.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 5.0, 0.0)
    polygon << origin + OpenStudio::Vector3d.new(5.0, 0.0, 0.0)
    space = OpenStudio::Model::Space.fromFloorPrint(polygon, 3.0, model).get

    result = @daylight.space_add_daylight_sensor(space)
    assert(result.class.to_s == 'OpenStudio::Model::DaylightingControl')
  end
end

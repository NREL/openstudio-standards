require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestDaylightingControls < Minitest::Test
  def test_remove_daylighting_controls
    # Load model
    std = Standard.build('90.1-2019')
    model = std.safe_load_model("#{File.dirname(__FILE__)}/../90_1_prm/models/bldg_11.osm")

    model.getSpaces.each do |space|
      std.space_set_baseline_daylighting_controls(space, true, false)
    end
  end

  def test_add_space_daylighting_controls
    std = Standard.build('90.1-2019')
    model = std.safe_load_model("#{File.dirname(__FILE__)}/models/test_school.osm")
   
    model.getSpaces.each do |space|
      std.space_add_daylighting_controls(space, true)
    end
  end
end

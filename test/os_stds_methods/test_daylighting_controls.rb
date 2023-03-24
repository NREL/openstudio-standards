require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestDaylightingControls < Minitest::Test
  def test_remove_daylighting_controls
    # Load model
    std = Standard.build('90.1-2019')
    osm_path = OpenStudio::Path.new('../90_1_prm/models/bldg_11.osm')
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(osm_path)
    model = model.get

    model.getSpaces.each do |space|
      std.space_set_baseline_daylighting_controls(space, true, false)
    end
  end
end

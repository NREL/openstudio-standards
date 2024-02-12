require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_RemoveDuplicateModelObjects_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  def test_remove_duplicate_model_objects

    # Load test model.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"fsr.osm"))

    old_number_of_objects = model.getModelObjects.length
    new_model = BTAP::FileIO::remove_duplicate_materials_and_constructions(model)
    new_number_of_objects = new_model.getModelObjects.length

    diff = old_number_of_objects - new_number_of_objects
    assert_equal(17, diff, "test_remove_duplicate_model_objects: expected to remove 17 objects, removed #{diff}.")
  end
end

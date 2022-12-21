require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_RemoveDuplicateModelObjects_Tests < MiniTest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  def test_remove_duplicate_model_objects
    # read a sample model called fsr model present within the test/necb/models/fsr.osm
    translator = OpenStudio::OSVersion::VersionTranslator.new
    osm_path = File.join(@resources_folder, 'fsr.osm')
    path = OpenStudio::Path.new(osm_path)
    model = translator.loadModel(path)
    model = model.get

    old_number_of_objects = model.getModelObjects.length
    new_model = BTAP::FileIO::remove_duplicate_materials_and_constructions(model)
    new_number_of_objects = new_model.getModelObjects.length

    puts "Number of objects removed: #{old_number_of_objects - new_number_of_objects}"
    assert((old_number_of_objects - new_number_of_objects > 0))
  end
end

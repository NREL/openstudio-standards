require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'


class NECB_RemoveDuplicateModelObjects_Tests < CreateDOEPrototypeBuildingTest

  def setup()
    @file_folder = __dir__
    @test_folder = File.join(@file_folder, '..')
    @root_folder = File.join(@test_folder, '../../../')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = "#{@test_folder}/output/"
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

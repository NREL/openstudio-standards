require_relative '../helpers/minitest_helper'

class TestEffectiveNumStories < Minitest::Test

  # todo - add test for empty model

  # todo - add test for model that has story with spaces that have no surfaces (can't get min_z)

  # todo - test for model with plenum or attic (space not including in building area)

  def test_model_create_story_hash

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/example_model_multipliers.osm")
    model = translator.loadModel(path)
    model = model.get

    test_story_a = nil
    test_story_b = nil
    model.getBuildingStorys.each do |story|
      if story.name.to_s == "Building Story 3"
        test_story_a = story
      elsif story.name.to_s == "Building Story 1"
        test_story_b = story
      end
    end

    # create story hash
    story_hash = model.create_story_hash

    # check recommendation
    assert(story_hash.size == 5)
    assert(story_hash[test_story_a][:multipliers].min == 9)
    assert(story_hash[test_story_a][:part_of_floor_area].size > 0)
    assert(story_hash[test_story_a][:not_part_of_floor_area].size == 0)
    assert(story_hash[test_story_a][:ext_wall_area] > 0)
    assert(story_hash[test_story_b][:ground_wall_area] > 0)

  end

  def test_effective_num_stories

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/example_model_multipliers.osm")
    model = translator.loadModel(path)
    model = model.get

    # create story hash
    effective_num_stories = model.effective_num_stories

    # check recommendation
    assert(effective_num_stories[:below_grade] == 1)
    assert(effective_num_stories[:above_grade] == 12)

  end

end

require_relative '../helpers/minitest_helper'

class TestModelCreateSpaceTypeHash < Minitest::Test

  def test_model_create_space_type_hash

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/models/example_model_multipliers.osm")
    model = translator.loadModel(path)
    model = model.get

    test_space_type_a = nil
    test_space_type_b = nil
    model.getSpaceTypes.each do |space_type|
      if space_type.name.to_s == "189.1-2009 - Office - OpenOffice - CZ4-8 1"
        test_space_type_a = space_type
      elsif space_type.name.to_s == "189.1-2009 - Office - Lobby - CZ4-8"
        test_space_type_b = space_type
      end
    end

    # create story hash
    template = '90.1-2013'
    space_type_hash = model.create_space_type_hash(template)
    puts space_type_hash.size
    space_type_hash.each do |k,v|
      puts k.name
      puts v
    end

    # check recommendation
    assert(space_type_hash.size == 3)
    assert(space_type_hash[test_space_type_a][:effective_num_spaces] == 88)
    assert(space_type_hash[test_space_type_b][:num_people] > 12)

  end

end

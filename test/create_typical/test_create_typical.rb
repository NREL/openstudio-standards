require_relative '../helpers/minitest_helper'

class TestCreateTypical < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
  end

  def test_typical_building_from_model
    std = Standard.build('90.1-2013')
    model = std.safe_load_model("#{File.dirname(__FILE__)}/../../data/geometry/ASHRAEPrimarySchool.osm")
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    starting_size = model.getModelObjects.size
    result = @create.typical_building_from_model(model, '90.1-2013', climate_zone: climate_zone)
    ending_size = model.getModelObjects.size
    assert(result)
    assert(starting_size < ending_size)
  end

  def test_create_space_types_and_constructions
    model = OpenStudio::Model::Model.new
    building_type = 'PrimarySchool'
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    result = @create.create_space_types_and_constructions(model, building_type, template, climate_zone)
    assert(result)
    assert(model.getSpaceTypes.size > 0)
    assert(model.getDefaultConstructionSets.size > 0)
  end
end
require_relative '../../helpers/minitest_helper'

class TestCreateTypical < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
  end

  def test_create_typical_building_from_model
    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAEPrimarySchool.osm")
    std.model_add_design_days_and_weather_file(model, climate_zone)

    # apply create typical
    starting_size = model.getModelObjects.size
    result = @create.create_typical_building_from_model(model, template, climate_zone: climate_zone)
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
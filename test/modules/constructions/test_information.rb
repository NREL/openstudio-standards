require_relative '../../helpers/minitest_helper'

class TestConstructionsInformation < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
    @constructions = OpenstudioStandards::Constructions
  end

  def test_construction_get_solar_reflectance_index
    model = OpenStudio::Model::Model.new
    layers = OpenStudio::Model::MaterialVector.new
    layers << OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.0889, 2.31, 2322, 832)
    construction = OpenStudio::Model::Construction.new(model)
    construction.setLayers(layers)
    sri = @constructions.construction_get_solar_reflectance_index(construction)
    assert(sri  > 0)
  end

  def test_construction_set_get_constructions
    model = OpenStudio::Model::Model.new
    building_type = 'PrimarySchool'
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    @create.create_space_types_and_constructions(model, building_type, template, climate_zone)
    default_construction_set = model.getDefaultConstructionSets[0]
    construction_array = @constructions.construction_set_get_constructions(default_construction_set)
    assert(construction_array.size > 2)
  end

  def test_construction_simple_glazing?
    model = OpenStudio::Model::Model.new
    simple_glazing = OpenStudio::Model::SimpleGlazing.new(model)
    construction = OpenStudio::Model::Construction.new(model)
    construction.setLayers([simple_glazing])
    assert(@constructions.construction_simple_glazing?(construction))

    op_mat = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    construction.setLayers([op_mat])
    assert(!@constructions.construction_simple_glazing?(construction))
  end
end
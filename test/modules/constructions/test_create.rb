require_relative '../../helpers/minitest_helper'

class TestConstructionsCreate < Minitest::Test
  def setup
    @constructions = OpenstudioStandards::Constructions
  end

  def test_construction_deep_copy
    model = OpenStudio::Model::Model.new
    mat1 = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.2, 1.729, 2243, 837)
    mat1.setName('Concrete')
    insulation = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'Smooth', 0.068, 0.0432, 91, 837)
    insulation.setName('Insulation')
    mat2 = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.0127, 0.16, 785, 830)
    mat2.setName('Drywall')
    construction = OpenStudio::Model::Construction.new(model)
    construction.setLayers([mat1, insulation, mat2])
    new_construction = @constructions.construction_deep_copy(construction)
    assert_equal(2, model.getConstructions.size)
    assert_equal(6, model.getMaterials.size)
  end

  def test_model_get_adiabatic_floor_construction
    model = OpenStudio::Model::Model.new
    @constructions.model_get_adiabatic_floor_construction(model)
    assert(model.getConstructionByName('Adiabatic floor construction').is_initialized)
  end

  def test_model_get_adiabatic_wall_construction
    model = OpenStudio::Model::Model.new
    @constructions.model_get_adiabatic_wall_construction(model)
    assert(model.getConstructionByName('Adiabatic wall construction').is_initialized)
  end
end
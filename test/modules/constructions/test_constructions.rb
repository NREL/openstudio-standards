require_relative '../helpers/minitest_helper'

class TestConstructions < Minitest::Test
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

  def test_construction_add_new_opaque_material
    model = OpenStudio::Model::Model.new
    layers = OpenStudio::Model::MaterialVector.new
    layers << OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.0889, 2.31, 2322, 832)
    construction = OpenStudio::Model::Construction.new(model)
    construction.setLayers(layers)
    result = @constructions.construction_add_new_opaque_material(construction,
                                                                 layer_index: 0,
                                                                 name: nil,
                                                                 roughness: 'MediumRough',
                                                                 thickness: 0.3,
                                                                 conductivity: 0.16,
                                                                 density: 400.0,
                                                                 specific_heat: 600.0,
                                                                 thermal_absorptance: 0.7,
                                                                 solar_absorptance: 0.4,
                                                                 visible_absorptance: 0.5)
    assert(result)
  end

  def test_construction_set_surface_properties
    model = OpenStudio::Model::Model.new
    layers = OpenStudio::Model::MaterialVector.new
    layers << OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.0889, 2.31, 2322, 832)
    construction = OpenStudio::Model::Construction.new(model)
    construction.setLayers(layers)
    result = @constructions.construction_set_surface_properties(construction,
                                                                roughness: 'VerySmooth',
                                                                thermal_absorptance: 0.8,
                                                                solar_absorptance: 0.6,
                                                                visible_absorptance: 0.6)
    assert(result)
  end
end
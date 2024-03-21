require_relative '../../helpers/minitest_helper'

class TestConstructions < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
    @constructions = OpenstudioStandards::Constructions
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

  def test_construction_find_and_set_insulation_layer
    model = OpenStudio::Model::Model.new
    mat1 = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.2, 1.729, 2243, 837)
    mat1.setName('Material 1')
    insulation = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'Smooth', 0.068, 0.0432, 91, 837)
    insulation.setName('Insulation')
    mat2 = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.0127, 0.16, 785, 830)
    mat2.setName('Material 2')
    construction = OpenStudio::Model::Construction.new(model)
    construction.setLayers([mat1, insulation, mat2])
    insulation_layer = @constructions.construction_find_and_set_insulation_layer(construction)
    assert('Insulation', insulation_layer.name.get)
  end

  def test_construction_set_u_value
    model = OpenStudio::Model::Model.new
    mat1 = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.2, 1.729, 2243, 837)
    mat1.setName('Material 1')
    insulation = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'Smooth', 0.068, 0.0432, 91, 837)
    insulation.setName('Insulation')
    mat2 = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.0127, 0.16, 785, 830)
    mat2.setName('Material 2')
    construction = OpenStudio::Model::Construction.new(model)
    construction.setLayers([mat1, insulation, mat2])

    # set to U-0.025 Btu/ft^2*hr*R (R-40)
    @constructions.construction_set_u_value(construction, 0.025,
                                            target_includes_interior_film_coefficients: false,
                                            target_includes_exterior_film_coefficients: false)
    u_value_si = @constructions.construction_get_conductance(construction)
    u_value_ip = OpenStudio.convert(u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get
    r_value_ip = 1.0 / u_value_ip
    assert_in_delta(40.0, r_value_ip, 0.01)

    # include film coefficients
    @constructions.construction_set_u_value(construction, 0.025, intended_surface_type: 'ExteriorWall')
    u_value_si = @constructions.construction_get_conductance(construction)
    u_value_ip = OpenStudio.convert(u_value_si, 'W/m^2*K', 'Btu/ft^2*hr*R').get
    r_value_ip = 1.0 / u_value_ip
    assert_in_delta(40.0 - 0.17 - 0.68, r_value_ip, 0.01)
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
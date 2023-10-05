require_relative '../../helpers/minitest_helper'

class TestConstructions < Minitest::Test
  def setup
    @materials = OpenstudioStandards::Constructions::Materials
  end

  def test_opaque_material_set_thermal_resistance_standard
    model = OpenStudio::Model::Model.new
    material = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.0889, 2.31, 2322, 832)
    result = @materials.opaque_material_set_thermal_resistance(material, 0.9)
    assert(result) 
  end

  def test_opaque_material_set_thermal_resistance_massless
    model = OpenStudio::Model::Model.new
    material = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
    result = @materials.opaque_material_set_thermal_resistance(material, 0.5)
    assert(result) 
  end

  def test_opaque_material_set_thermal_resistance_airgap
    model = OpenStudio::Model::Model.new
    material = OpenStudio::Model::AirGap.new(model)
    result = @materials.opaque_material_set_thermal_resistance(material, 0.2)
    assert(result) 
  end

  def test_opaque_material_set_surface_properties
    model = OpenStudio::Model::Model.new
    material = OpenStudio::Model::StandardOpaqueMaterial.new(model, 'MediumRough', 0.0889, 2.31, 2322, 832)
    result = @materials.opaque_material_set_surface_properties(material,
                                                               roughness: 'VerySmooth',
                                                               thermal_absorptance: 0.8,
                                                               solar_absorptance: 0.6,
                                                               visible_absorptance: 0.6)
    assert(result)
  end
end
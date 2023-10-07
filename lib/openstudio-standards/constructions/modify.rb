# Methods to modify construction properties
module OpenstudioStandards
  module Constructions
    # @!group Modify

    # add new material layer to a construction
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object
    # @param layer_index [Integer] the layer index, default is 0
    # @param name [String] name of the new material layer
    # @param roughness [String] surface roughness of the new material layer.
    #   Options are 'VeryRough', 'Rough', 'MediumRough', 'MediumSmooth', 'Smooth', and 'VerySmooth'
    # @param thickness [Double] thickness of the new material layer in meters
    # @param conductivity [Double] conductivity of new material layer in W/m*K
    # @param density [Double] density of the new material layer in kg/m^3
    # @param specific_heat [Double] specific heat of the new material layer in J/kg*K
    # @param thermal_absorptance [Double] target thermal absorptance
    # @param solar_absorptance [Double] target solar absorptance
    # @param visible_absorptance [Double] target visible absorptance
    # @return [OpenStudio::Model::StandardOpaqueMaterial] The new material layer, a OpenStudio StandardOpaqueMaterial object
    def self.construction_add_new_opaque_material(construction,
                                                  layer_index: 0,
                                                  name: nil,
                                                  roughness: nil,
                                                  thickness: nil,
                                                  conductivity: nil,
                                                  density: nil,
                                                  specific_heat: nil,
                                                  thermal_absorptance: nil,
                                                  solar_absorptance: nil,
                                                  visible_absorptance: nil)

      # make new material
      new_material = OpenStudio::Model::StandardOpaqueMaterial.new(construction.model)
      if name.nil?
        new_material.setName("#{construction.name} New Material")
      else
        new_material.setName(name)
      end

      # set requested material properties
      new_material.setRoughness(roughness) unless roughness.nil?
      new_material.setThickness(thickness) unless thickness.nil?
      new_material.setConductivity(conductivity) unless conductivity.nil?
      new_material.setDensity(density) unless density.nil?
      new_material.setSpecificHeat(specific_heat) unless specific_heat.nil?
      new_material.setThermalAbsorptance(thermal_absorptance) unless thermal_absorptance.nil?
      new_material.setSolarAbsorptance(solar_absorptance) unless solar_absorptance.nil?
      new_material.setVisibleAbsorptance(visible_absorptance) unless visible_absorptance.nil?

      # add material to construction
      construction.insertLayer(layer_index, new_material)

      return new_material
    end

    # set construction surface properties
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object
    # @param roughness [String] surface roughness
    # @param thermal_absorptance [Double] target thermal absorptance
    # @param solar_absorptance [Double] target solar absorptance
    # @param visible_absorptance [Double] target visible absorptance
    # @return [OpenStudio::Model::OpaqueMaterial] OpenStudio OpaqueMaterial object
    def self.construction_set_surface_properties(construction,
                                                 roughness: nil,
                                                 thermal_absorptance: nil,
                                                 solar_absorptance: nil,
                                                 visible_absorptance: nil)

      surface_material = construction.to_LayeredConstruction.get.getLayer(0)
      new_material = OpenstudioStandards::Constructions::Materials.opaque_material_set_surface_properties(surface_material,
                                                                                                          roughness: roughness,
                                                                                                          thermal_absorptance: thermal_absorptance,
                                                                                                          solar_absorptance: solar_absorptance,
                                                                                                          visible_absorptance: visible_absorptance)
      return new_material
    end
  end
end

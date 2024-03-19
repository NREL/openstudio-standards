module OpenstudioStandards
  # The Constructions module provides methods create, modify, and get information about model Constructions
  module Constructions
    # @!group Modify
    # Methods to modify Constructions

    # add new material layer to a construction
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object
    # @param layer_index [Integer] the layer index, default is 0
    # @param name [String] name of the new material layer
    # @param roughness [String] surface roughness of the new material layer.
    #   Options are 'VeryRough', 'Rough', 'MediumRough', 'MediumSmooth', 'Smooth', and 'VerySmooth'
    # @param thickness [Double] thickness of the new material layer in meters
    # @param conductivity [Double] thermal conductivity of new material layer in W/m*K
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

    # Find and set the insulation layer for a layered construction
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object
    # @return [OpenStudio::Model::OpaqueMaterial] OpenStudio OpaqueMaterial representing the insulation layer
    def self.construction_find_and_set_insulation_layer(construction)
      # skip and return the insulation layer if already set
      return construction.insulation.get if construction.insulation.is_initialized

      # loop through construction layers to find insulation layer
      min_conductance = 100.0
      insulation_material = nil
      construction.layers.each do |layer|
        # skip layers that aren't an OpaqueMaterial
        next unless layer.to_OpaqueMaterial.is_initialized

        material = layer.to_OpaqueMaterial.get
        material_conductance = OpenstudioStandards::Constructions::Materials.material_get_conductance(material)
        if material_conductance < min_conductance
          min_conductance = material_conductance
          insulation_material = material
        end
      end
      construction.setInsulation(insulation_material) unless insulation_material.nil?

      if construction.isOpaque && !construction.insulation.is_initialized
        OpenStudio.logFree(OpenStudio::Error, 'OpenstudioStandards::Constructions', "Unable to determine the insulation layer for construction #{construction.name.get}.")
        return nil
      end

      return construction.insulation.get
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

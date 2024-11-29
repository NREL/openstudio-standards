module OpenstudioStandards
  # The Constructions module provides methods create, modify, and get information about model Constructions
  module Constructions
    # The Materials module provides methods create, modify, and get information about Materials
    module Materials
      # @!group Modify
      # Methods to modify Materials

      # change thermal resistance of opaque materials by increasing material thickness,
      # or setting thermal resistance directly for massless or airgap materials.
      #
      # @param opaque_material [OpenStudio::Model::OpaqueMaterial] OpenStudio OpaqueMaterial object
      # @param thermal_resistance [Double] Target thermal resistance of the material in m^2*K/W
      # @return [OpenStudio::Model::OpaqueMaterial] OpenStudio OpaqueMaterial object
      def self.opaque_material_set_thermal_resistance(opaque_material, thermal_resistance)
        unless opaque_material.to_OpaqueMaterial.is_initialized
          OpenStudio.logFree(OpenStudio::Error, 'OpenstudioStandards::Construction::Materials', "Object #{opaque_material} cannot be cast as an OpaqueMaterial object.")
          return false
        end

        # edit insulation material
        material = opaque_material.to_OpaqueMaterial.get
        if material.to_MasslessOpaqueMaterial.is_initialized
          material = material.to_MasslessOpaqueMaterial.get
          material.setThermalResistance(thermal_resistance)
        elsif material.to_AirGap.is_initialized
          material = material.to_AirGap.get
          material.setThermalResistance(thermal_resistance)
        else
          starting_thickness = material.thickness
          target_thickness = starting_thickness * thermal_resistance / material.thermalResistance
          material.setThickness(target_thickness)
        end

        return material.to_OpaqueMaterial.get
      end

      # set material surface properties
      #
      # @param opaque_material [OpenStudio::Model::OpaqueMaterial] OpenStudio OpaqueMaterial object
      # @param roughness [String] surface roughness. Options are 'VeryRough', 'Rough', 'MediumRough',
      #   'MediumSmooth', 'Smooth', and 'VerySmooth'
      # @param thermal_absorptance [Double] target thermal absorptance
      # @param solar_absorptance [Double] target solar absorptance
      # @param visible_absorptance [Double] target visible absorptance
      # @return [OpenStudio::Model::OpaqueMaterial] OpenStudio OpaqueMaterial object
      def self.opaque_material_set_surface_properties(opaque_material,
                                                      roughness: nil,
                                                      thermal_absorptance: nil,
                                                      solar_absorptance: nil,
                                                      visible_absorptance: nil)
        unless opaque_material.to_OpaqueMaterial.is_initialized
          OpenStudio.logFree(OpenStudio::Error, 'OpenstudioStandards::Construction::Materials', "Object #{opaque_material} cannot be cast as an OpaqueMaterial object.")
          return false
        end

        # set requested material properties
        material = opaque_material.to_OpaqueMaterial.get
        if material.to_StandardOpaqueMaterial.is_initialized
          material = material.to_StandardOpaqueMaterial.get
          material.setRoughness(roughness) unless roughness.nil?
        elsif material.to_MasslessOpaqueMaterial.is_initialized
          material = material.to_MasslessOpaqueMaterial.get
          material.setRoughness(roughness) unless roughness.nil?
        end
        material.setThermalAbsorptance(thermal_absorptance) unless thermal_absorptance.nil?
        material.setSolarAbsorptance(solar_absorptance) unless solar_absorptance.nil?
        material.setVisibleAbsorptance(visible_absorptance) unless visible_absorptance.nil?

        return material.to_OpaqueMaterial.get
      end
    end
  end
end

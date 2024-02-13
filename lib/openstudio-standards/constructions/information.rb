module OpenstudioStandards
  # The Constructions module provides methods create, modify, and get information about model Constructions
  module Constructions
    # @!group Information
    # Methods to get information about Constructions

    # Returns the solar reflectance index of an exposed surface.
    # On a scale of 0 to 100, standard black is 0, and standard white is 100.
    # The calculation derived from ASTM E1980 assuming medium wind speed.
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object
    # @return [Double] The solar reflectance value
    def self.construction_get_solar_reflectance_index(construction)
      exposed_material = construction.to_LayeredConstruction.get.getLayer(0)
      solar_absorptance = exposed_material.to_OpaqueMaterial.get.solarAbsorptance
      thermal_emissivity = exposed_material.to_OpaqueMaterial.get.thermalAbsorptance
      x = (20.797 * solar_absorptance - 0.603 * thermal_emissivity) / (9.5205 * thermal_emissivity + 12.0)
      sri = 123.97 - 141.35 * x + 9.6555 * x * x

      return sri
    end

    # report names of constructions in a construction set
    #
    # @param default_construction_set [OpenStudio::Model::Defaultdefault_construction_set] OpenStudio Defaultdefault_construction_set object
    # @return [Array<OpenStudio::Model::Construction>] Array of OpenStudio Construction objects
    def self.construction_set_get_constructions(default_construction_set)
      construction_array = []

      # populate exterior surfaces
      if default_construction_set.defaultExteriorSurfaceConstructions.is_initialized
        default_surface_constructions = default_construction_set.defaultExteriorSurfaceConstructions.get
        construction_array << default_surface_constructions.floorConstruction.get if default_surface_constructions.floorConstruction.is_initialized
        construction_array << default_surface_constructions.wallConstruction.get if default_surface_constructions.wallConstruction.is_initialized
        construction_array << default_surface_constructions.roofCeilingConstruction.get if default_surface_constructions.roofCeilingConstruction.is_initialized
      end
      # populate interior surfaces
      if default_construction_set.defaultInteriorSurfaceConstructions.is_initialized
        default_surface_constructions = default_construction_set.defaultInteriorSurfaceConstructions.get
        construction_array << default_surface_constructions.floorConstruction.get if default_surface_constructions.floorConstruction.is_initialized
        construction_array << default_surface_constructions.wallConstruction.get if default_surface_constructions.wallConstruction.is_initialized
        construction_array << default_surface_constructions.roofCeilingConstruction.get if default_surface_constructions.roofCeilingConstruction.is_initialized
      end
      # populate ground surfaces
      if default_construction_set.defaultGroundContactSurfaceConstructions.is_initialized
        default_surface_constructions = default_construction_set.defaultGroundContactSurfaceConstructions.get
        construction_array << default_surface_constructions.floorConstruction.get if default_surface_constructions.floorConstruction.is_initialized
        construction_array << default_surface_constructions.wallConstruction.get if default_surface_constructions.wallConstruction.is_initialized
        construction_array << default_surface_constructions.roofCeilingConstruction.get if default_surface_constructions.roofCeilingConstruction.is_initialized
      end
      # populate exterior sub-surfaces
      if default_construction_set.defaultExteriorSubSurfaceConstructions.is_initialized
        default_subsurface_constructions = default_construction_set.defaultExteriorSubSurfaceConstructions.get
        construction_array << default_subsurface_constructions.fixedWindowConstruction.get if default_subsurface_constructions.fixedWindowConstruction.is_initialized
        construction_array << default_subsurface_constructions.operableWindowConstruction.get if default_subsurface_constructions.operableWindowConstruction.is_initialized
        construction_array << default_subsurface_constructions.doorConstruction.get if default_subsurface_constructions.doorConstruction.is_initialized
        construction_array << default_subsurface_constructions.glassDoorConstruction.get if default_subsurface_constructions.glassDoorConstruction.is_initialized
        construction_array << default_subsurface_constructions.overheadDoorConstruction.get if default_subsurface_constructions.overheadDoorConstruction.is_initialized
        construction_array << default_subsurface_constructions.skylightConstruction.get if default_subsurface_constructions.skylightConstruction.is_initialized
        construction_array << default_subsurface_constructions.tubularDaylightDomeConstruction.get if default_subsurface_constructions.tubularDaylightDomeConstruction.is_initialized
        construction_array << default_subsurface_constructions.tubularDaylightDiffuserConstruction.get if default_subsurface_constructions.tubularDaylightDiffuserConstruction.is_initialized
      end
      # populate interior sub-surfaces
      if default_construction_set.defaultInteriorSubSurfaceConstructions.is_initialized
        default_subsurface_constructions = default_construction_set.defaultInteriorSubSurfaceConstructions.get
        construction_array << default_subsurface_constructions.fixedWindowConstruction.get if default_subsurface_constructions.fixedWindowConstruction.is_initialized
        construction_array << default_subsurface_constructions.operableWindowConstruction.get if default_subsurface_constructions.operableWindowConstruction.is_initialized
        construction_array << default_subsurface_constructions.doorConstruction.get if default_subsurface_constructions.doorConstruction.is_initialized
        construction_array << default_subsurface_constructions.glassDoorConstruction.get if default_subsurface_constructions.glassDoorConstruction.is_initialized
        construction_array << default_subsurface_constructions.overheadDoorConstruction.get if default_subsurface_constructions.overheadDoorConstruction.is_initialized
        construction_array << default_subsurface_constructions.skylightConstruction.get if default_subsurface_constructions.skylightConstruction.is_initialized
        construction_array << default_subsurface_constructions.tubularDaylightDomeConstruction.get if default_subsurface_constructions.tubularDaylightDomeConstruction.is_initialized
        construction_array << default_subsurface_constructions.tubularDaylightDiffuserConstruction.get if default_subsurface_constructions.tubularDaylightDiffuserConstruction.is_initialized
      end
      # populate misc surfaces
      construction_array << default_construction_set.interiorPartitionConstruction.get if default_construction_set.interiorPartitionConstruction.is_initialized
      construction_array << default_construction_set.spaceShadingConstruction.get if default_construction_set.spaceShadingConstruction.is_initialized
      construction_array << default_construction_set.buildingShadingConstruction.get if default_construction_set.buildingShadingConstruction.is_initialized
      construction_array << default_construction_set.siteShadingConstruction.get if default_construction_set.siteShadingConstruction.is_initialized

      return construction_array
    end
  end
end

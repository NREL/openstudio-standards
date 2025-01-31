module OpenstudioStandards
  # The Constructions module provides methods create, modify, and get information about model Constructions
  module Constructions
    # @!group Information
    # Methods to get information about Constructions

    # Gives the total R-value of the interior and exterior (if applicable) film coefficients for a particular type of surface.
    # @ref [References::ASHRAE9012010] A9.4.1 Air Films
    #
    # @param intended_surface_type [String]
    #   Valid choices:  'AtticFloor', 'AtticWall', 'AtticRoof', 'DemisingFloor', 'InteriorFloor', 'InteriorCeiling',
    #   'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor', 'DemisingRoof',
    #   'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser', 'ExteriorFloor',
    #   'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor', 'GroundContactFloor',
    #   'GroundContactWall', 'GroundContactRoof'
    # @param int_film [Boolean] if true, interior film coefficient will be included in result
    # @param ext_film [Boolean] if true, exterior film coefficient will be included in result
    # @return [Double] Returns the R-Value of the film coefficients [m^2*K/W]
    def self.film_coefficients_r_value(intended_surface_type, int_film, ext_film)
      # Return zero if both interior and exterior are false
      return 0.0 if !int_film && !ext_film

      # Film values from 90.1-2010 A9.4.1 Air Films
      film_ext_surf_r_ip = 0.17
      film_semi_ext_surf_r_ip = 0.46
      film_int_surf_ht_flow_up_r_ip = 0.61
      film_int_surf_ht_flow_dwn_r_ip = 0.92
      fil_int_surf_vertical_r_ip = 0.68

      film_ext_surf_r_si = OpenStudio.convert(film_ext_surf_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
      film_semi_ext_surf_r_si = OpenStudio.convert(film_semi_ext_surf_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
      film_int_surf_ht_flow_up_r_si = OpenStudio.convert(film_int_surf_ht_flow_up_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
      film_int_surf_ht_flow_dwn_r_si = OpenStudio.convert(film_int_surf_ht_flow_dwn_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get
      fil_int_surf_vertical_r_si = OpenStudio.convert(fil_int_surf_vertical_r_ip, 'ft^2*hr*R/Btu', 'm^2*K/W').get

      film_r_si = 0.0
      case intended_surface_type
      when 'AtticFloor'
        film_r_si += film_int_surf_ht_flow_up_r_si if ext_film # Outside
        film_r_si += film_semi_ext_surf_r_si if int_film # Inside @todo: this is only true if the attic is ventilated, interior film should be used otheriwse
      when 'AtticWall', 'AtticRoof'
        film_r_si += film_ext_surf_r_si if ext_film # Outside
        film_r_si += film_semi_ext_surf_r_si if int_film # Inside @todo: this is only true if the attic is ventilated, interior film should be used otherwise
      when 'DemisingFloor', 'InteriorFloor'
        film_r_si += film_int_surf_ht_flow_up_r_si if ext_film # Outside
        film_r_si += film_int_surf_ht_flow_dwn_r_si if int_film # Inside
      when 'InteriorCeiling'
        film_r_si += film_int_surf_ht_flow_dwn_r_si if ext_film # Outside
        film_r_si += film_int_surf_ht_flow_up_r_si if int_film # Inside
      when 'DemisingWall', 'InteriorWall', 'InteriorPartition', 'InteriorWindow', 'InteriorDoor'
        film_r_si += fil_int_surf_vertical_r_si if ext_film # Outside
        film_r_si += fil_int_surf_vertical_r_si if int_film # Inside
      when 'DemisingRoof', 'ExteriorRoof', 'Skylight', 'TubularDaylightDome', 'TubularDaylightDiffuser'
        film_r_si += film_ext_surf_r_si if ext_film # Outside
        film_r_si += film_int_surf_ht_flow_up_r_si if int_film # Inside
      when 'ExteriorFloor'
        film_r_si += film_ext_surf_r_si if ext_film # Outside
        film_r_si += film_int_surf_ht_flow_dwn_r_si if int_film # Inside
      when 'ExteriorWall', 'ExteriorWindow', 'ExteriorDoor', 'GlassDoor', 'OverheadDoor'
        film_r_si += film_ext_surf_r_si if ext_film # Outside
        film_r_si += fil_int_surf_vertical_r_si if int_film # Inside
      when 'GroundContactFloor'
        film_r_si += film_int_surf_ht_flow_dwn_r_si if int_film # Inside
      when 'GroundContactWall'
        film_r_si += fil_int_surf_vertical_r_si if int_film # Inside
      when 'GroundContactRoof'
        film_r_si += film_int_surf_ht_flow_up_r_si if int_film # Inside
      end
      return film_r_si
    end

    # @!endgroup Information

    # @!group Information:Construction

    # Determines if the construction is a simple glazing construction,
    # as indicated by having a single layer of type SimpleGlazing.
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object
    # @return [Boolean] returns true if it is a simple glazing, false if not
    def self.construction_simple_glazing?(construction)
      # Not simple if more than 1 layer
      if construction.layers.length > 1
        return false
      end

      # Not simple unless the layer is a SimpleGlazing material
      # if construction.layers.first.to_SimpleGlazing.empty?
      if construction.layers.first.to_SimpleGlazing.empty?
        return false
      end

      # If here, must be simple glazing
      return true
    end

    # Return the thermal conductance for an OpenStudio Construction object
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object
    # @param temperature [Double] Temperature in Celsius, used for gas or gas mixture thermal conductance
    # @return [Double] thermal conductance in W/m^2*K
    def self.construction_get_conductance(construction, temperature: 0.0)
      # check to see if it can be cast as a layered construction, otherwise error
      unless construction.to_LayeredConstruction.is_initialized
        OpenStudio.logFree(OpenStudio::Error, 'OpenstudioStandards::Constructions', "Unable to determine conductance for construction #{construction.name} because it is not a LayeredConstruction.")
        return nil
      end
      construction = construction.to_LayeredConstruction.get

      total = 0.0
      construction.layers.each do |material|
        total += 1.0 / OpenstudioStandards::Constructions::Materials.material_get_conductance(material, temperature: temperature)
      end

      return 1.0 / total
    end

    # Get the total solar transmittance for a fenestration construction (SHGC)
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object
    # @return [Double] total solar transmittance, or 0.0 if not available
    def self.construction_get_solar_transmittance(construction)
      tsol = nil
      if construction.isFenestration
        tsol = 1.0
        construction.layers.each do |layer|
          # Use shgc for simple glazing
          tsol *= layer.to_SimpleGlazing.get.solarHeatGainCoefficient unless layer.to_SimpleGlazing.empty?
          # Use solar transmittance for standard glazing
          tsol *= layer.to_StandardGlazing.get.solarTransmittance unless layer.to_StandardGlazing.empty?
        end
      end

      if tsol.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'OpenstudioStandards::Constructions', "Unable to determine total solar transmittance for construction #{construction.name} because it is not considered Fenestration in the model. Returning a total solar transmittance of 0.0.")
        tsol = 0.0
      end

      return tsol
    end

    # Get the total visible transmittance for a fenestration construction
    #
    # @param construction [OpenStudio::Model::Construction] OpenStudio Construction object
    # @return [Double] total visible transmittance, or 0.0 if not available
    def self.construction_get_visible_transmittance(construction)
      tvis = nil
      if construction.isFenestration
        tvis = 1.0
        construction.layers.each do |layer|
          # Use visible transmittance for simple glazing if specified
          unless layer.to_SimpleGlazing.empty?
            val = layer.to_SimpleGlazing.get.visibleTransmittance
            tvis *= val.get unless val.empty?
          end
          # Use visible transmittance for standard glazing if specified
          unless layer.to_StandardGlazing.empty?
            val = layer.to_StandardGlazing.get.visibleTransmittanceatNormalIncidence
            tvis *= val.get unless val.empty?
          end
        end
      end

      if tvis.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'OpenstudioStandards::Constructions', "Unable to determine total visible transmittance for construction #{construction.name} because it is not considered Fenestration in the model. Returning a total visible transmittance of 0.0.")
        tvis = 0.0
      end

      return tvis
    end

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
      x = ((20.797 * solar_absorptance) - (0.603 * thermal_emissivity)) / ((9.5205 * thermal_emissivity) + 12.0)
      sri = 123.97 - (141.35 * x) + (9.6555 * x * x)

      return sri
    end

    # @!endgroup Information:Construction

    # @!group Information:Surfaces

    # Determine the weighted average conductance for a set of planar surfaces (surfaces or sub surfaces)
    #
    # @param surfaces [Array<OpenStudio::Model::PlanarSurface>] Array of OpenStudio PlanarSurface objects
    # @return [Double] thermal conductance in W/m^2*K, or nil if not available
    def self.surfaces_get_conductance(surfaces)
      return nil if surfaces.empty?

      total_area = 0.0
      temp = 0.0
      surfaces.each do |surface|
        next unless surface.construction.is_initialized

        surface_construction = surface.model.getConstructionByName(surface.construction.get.name.to_s).get
        surface_conductance = OpenstudioStandards::Constructions.construction_get_conductance(surface_construction)
        temp += surface.netArea * surface_conductance
        total_area += surface.netArea
      end
      return nil if temp.zero?

      average_conductance = total_area.zero? ? 0.0 : temp / total_area
      return average_conductance
    end

    # Determine the weighted average solar transmittance for a set of planar surfaces (surfaces or sub surfaces)
    #
    # @param surfaces [Array<OpenStudio::Model::PlanarSurface>] Array of OpenStudio PlanarSurface objects
    # @return [Double] total solar transmittance, or 1.0 if not available
    def self.surfaces_get_solar_transmittance(surfaces)
      total_area = 0.0
      temp = 0.0
      surfaces.each do |surface|
        next unless surface.construction.is_initialized

        surface_construction = surface.model.getConstructionByName(surface.construction.get.name.to_s).get
        surface_shgc = OpenstudioStandards::Constructions.construction_get_solar_transmittance(surface_construction)
        temp += surface.netArea * surface_shgc
        total_area += surface.netArea
      end
      ave_shgc = total_area.zero? ? 1.0 : temp / total_area
      return ave_shgc
    end

    # Determine the weighted average visible transmittance for a set of planar surfaces (surfaces or sub surfaces)
    #
    # @param surfaces [Array<OpenStudio::Model::PlanarSurface>] Array of OpenStudio PlanarSurface objects
    # @return [Double] total visible transmittance, or 1.0 if not available
    def self.surfaces_get_visible_transmittance(surfaces)
      total_area = 0.0
      temp = 0.0
      surfaces.each do |surface|
        next unless surface.construction.is_initialized

        surface_construction = surface.model.getConstructionByName(surface.construction.get.name.to_s).get
        surface_tvis = OpenstudioStandards::Constructions.construction_get_visible_transmittance(surface_construction)
        temp += surface.netArea * surface_tvis
        total_area += surface.netArea
      end
      ave_tvis = total_area.zero? ? 1.0 : temp / total_area
      return ave_tvis
    end

    # @!endgroup Information:Surfaces

    # @!group Information:DefaultConstructionSet

    # report names of constructions in a construction set
    #
    # @param default_construction_set [OpenStudio::Model::DefaultConstructionSet] OpenStudio DefaultConstructionSet object
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

    # @!endgroup Information:DefaultConstructionSet

    # @!group Information:Model

    # Get a unique list of constructions with a given boundary condition and surface type.
    # Pulls from both default construction sets and hard-assigned constructions.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param boundary_condition [String] Surface boundary condition. Valid options are:
    #   Adiabatic
    #   Surface
    #   Outdoors
    #   Ground
    # @param surface_type [String] Surface type to lookup. Valid options are:
    #   AtticFloor
    #   AtticWall
    #   AtticRoof
    #   DemisingFloor
    #   DemisingWall
    #   DemisingRoof
    #   ExteriorFloor
    #   ExteriorWall
    #   ExteriorRoof
    #   ExteriorWindow
    #   ExteriorDoor
    #   GlassDoor
    #   GroundContactFloor
    #   GroundContactWall
    #   GroundContactRoof
    #   InteriorFloor
    #   InteriorWall
    #   InteriorCeiling
    #   InteriorPartition
    #   InteriorWindow
    #   InteriorDoor
    #   OverheadDoor
    #   Skylight
    #   TubularDaylightDome
    #   TubularDaylightDiffuser
    # return [Array<OpenStudio::Model::ConstructionBase>] An array of all constructions matching the given boundary condition and surface type
    def self.model_get_constructions(model, boundary_condition, surface_type)
      constructions = []

      # From default construction sets
      model.getDefaultConstructionSets.sort.each do |const_set|
        ext_surfs = const_set.defaultExteriorSurfaceConstructions
        int_surfs = const_set.defaultInteriorSurfaceConstructions
        gnd_surfs = const_set.defaultGroundContactSurfaceConstructions
        ext_subsurfs = const_set.defaultExteriorSubSurfaceConstructions
        int_subsurfs = const_set.defaultInteriorSubSurfaceConstructions

        # Can't handle incomplete construction sets
        if ext_surfs.empty? ||
           int_surfs.empty? ||
           gnd_surfs.empty? ||
           ext_subsurfs.empty? ||
           int_subsurfs.empty?

          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Space', "Default construction set #{const_set.name} is incomplete; constructions from this set will not be reported.")
          next
        end

        ext_surfs = ext_surfs.get
        int_surfs = int_surfs.get
        gnd_surfs = gnd_surfs.get
        ext_subsurfs = ext_subsurfs.get
        int_subsurfs = int_subsurfs.get

        case surface_type
          # Exterior Surfaces
          when 'ExteriorWall', 'AtticWall'
            constructions << ext_surfs.wallConstruction
          when 'ExteriorFloor'
            constructions << ext_surfs.floorConstruction
          when 'ExteriorRoof', 'AtticRoof'
            constructions << ext_surfs.roofCeilingConstruction
          # Interior Surfaces
          when 'InteriorWall', 'DemisingWall', 'InteriorPartition'
            constructions << int_surfs.wallConstruction
          when 'InteriorFloor', 'AtticFloor', 'DemisingFloor'
            constructions << int_surfs.floorConstruction
          when 'InteriorCeiling', 'DemisingRoof'
            constructions << int_surfs.roofCeilingConstruction
          # Ground Contact Surfaces
          when 'GroundContactWall'
            constructions << gnd_surfs.wallConstruction
          when 'GroundContactFloor'
            constructions << gnd_surfs.floorConstruction
          when 'GroundContactRoof'
            constructions << gnd_surfs.roofCeilingConstruction
          # Exterior SubSurfaces
          when 'ExteriorWindow'
            constructions << ext_subsurfs.fixedWindowConstruction
            constructions << ext_subsurfs.operableWindowConstruction
          when 'ExteriorDoor'
            constructions << ext_subsurfs.doorConstruction
          when 'GlassDoor'
            constructions << ext_subsurfs.glassDoorConstruction
          when 'OverheadDoor'
            constructions << ext_subsurfs.overheadDoorConstruction
          when 'Skylight'
            constructions << ext_subsurfs.skylightConstruction
          when 'TubularDaylightDome'
            constructions << ext_subsurfs.tubularDaylightDomeConstruction
          when 'TubularDaylightDiffuser'
            constructions << ext_subsurfs.tubularDaylightDiffuserConstruction
          # Interior SubSurfaces
          when 'InteriorWindow'
            constructions << int_subsurfs.fixedWindowConstruction
            constructions << int_subsurfs.operableWindowConstruction
          when 'InteriorDoor'
            constructions << int_subsurfs.doorConstruction
        end
      end

      # Hard-assigned surfaces
      model.getSurfaces.sort.each do |surface|
        next unless surface.outsideBoundaryCondition == boundary_condition

        if surface.surfaceType == 'Floor' || surface.surfaceType == 'Wall'
          next unless surface_type.include?(surface.surfaceType)
        elsif surface.surfaceType == 'RoofCeiling'
          next unless surface_type.include?('Roof') || surface_type.include?('Ceiling')
        end
        constructions << surface.construction
      end

      # Hard-assigned subsurfaces
      model.getSubSurfaces.sort.each do |surface|
        next unless surface.outsideBoundaryCondition == boundary_condition

        case surface.subSurfaceType
        when 'FixedWindow', 'OperableWindow'
          next unless surface_type == 'ExteriorWindow'
        when 'Door'
          next unless surface_type.include?('Door')
        else
          next unless surface.subSurfaceType == surface_type
        end
        constructions << surface.construction
      end

      # Throw out the empty constructions
      all_constructions = []
      constructions.uniq.each do |construction|
        next if construction.empty?

        all_constructions << construction.get
      end

      # return unique sorted ConstructionBases
      all_constructions = all_constructions.uniq.sort

      return all_constructions
    end

    # @!endgroup Information:Model
  end
end

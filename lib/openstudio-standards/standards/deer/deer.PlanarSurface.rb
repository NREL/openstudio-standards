class DEER
  # @!group PlanarSurface

  # If construction properties can be found
  # based on the template,
  # the standards intended surface type,
  # the standards construction type,
  # the climate zone, and the occupancy type,
  # create a construction that meets those properties and
  # assign it to this surface.
  #
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param climate_zone [String] the climate zone
  # @param previous_construction_map [Hash] a hash where the keys are an array of inputs
  # [template, climate_zone, intended_surface_type, standards_construction_type, occ_type]
  # and the values are the constructions.  If supplied, constructions will be pulled
  # from this hash if already created to avoid creating duplicate constructions.
  # @return [Hash] returns a hash where the key is an array of inputs
  # [template, climate_zone, intended_surface_type, standards_construction_type, occ_type]
  # and the value is the newly created construction.  This can be
  # used to avoid creating duplicate constructions.
  # @todo Align the standard construction enumerations in the
  # spreadsheet with the enumerations in OpenStudio (follow CBECC-Com).
  def planar_surface_apply_standard_construction(planar_surface, climate_zone, previous_construction_map = {})
    # Skip surfaces not in a space
    return previous_construction_map if planar_surface.space.empty?
    space = planar_surface.space.get

    # Skip surfaces that don't have a construction
    return previous_construction_map if planar_surface.construction.empty?
    construction = planar_surface.construction.get

    # Determine if residential or nonresidential
    # based on the space type.
    occ_type = 'Nonresidential'
    if space_residential?(space)
      occ_type = 'HighriseResidential'
    end

    # Get the climate zone set
    climate_zone_set = model_find_climate_zone_set(planar_surface.model, climate_zone)

    # Get the intended surface type
    standards_info = construction.standardsInformation
    surf_type = standards_info.intendedSurfaceType
    if surf_type.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.PlanarSurface', "Could not determine the intended surface type for #{planar_surface.name} from #{construction.name}.  This surface will not have the standard applied.")
      return previous_construction_map
    end
    surf_type = surf_type.get

    # Get the standards type, which is based on different fields
    # if is intended for a window, a skylight, or something else.
    # Mapping is between standards-defined enumerations and the
    # enumerations available in OpenStudio.
    stds_type = nil
    # Windows
    if surf_type == 'ExteriorWindow'
      stds_type = standards_info.fenestrationFrameType
      if stds_type.is_initialized
        stds_type = stds_type.get
        case stds_type
        when 'Metal Framing', 'Metal Framing with Thermal Break'
          stds_type = 'Metal framing (all other)'
        when 'Non-Metal Framing'
          stds_type = 'Nonmetal framing (all)'
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.PlanarSurface', "The standards fenestration frame type #{stds_type} cannot be used on #{surf_type} in #{planar_surface.name}.  This surface will not have the standard applied.")
          return previous_construction_map
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.PlanarSurface', "Could not determine the standards fenestration frame type for #{planar_surface.name} from #{construction.name}.  This surface will not have the standard applied.")
        return previous_construction_map
      end
    # Skylights
    elsif surf_type == 'Skylight'
      stds_type = standards_info.fenestrationType
      if stds_type.is_initialized
        stds_type = stds_type.get
        case stds_type
        when 'Glass Skylight with Curb'
          stds_type = 'Glass with Curb'
        when 'Plastic Skylight with Curb'
          stds_type = 'Plastic with Curb'
        when 'Plastic Skylight without Curb', 'Glass Skylight without Curb'
          stds_type = 'Without Curb'
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.PlanarSurface', "The standards fenestration type #{stds_type} cannot be used on #{surf_type} in #{planar_surface.name}.  This surface will not have the standard applied.")
          return previous_construction_map
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.PlanarSurface', "Could not determine the standards fenestration type for #{planar_surface.name} from #{construction.name}.  This surface will not have the standard applied.")
        return previous_construction_map
      end
    # All other surface types
    else
      stds_type = standards_info.standardsConstructionType
      if stds_type.is_initialized
        stds_type = stds_type.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.PlanarSurface', "Could not determine the standards construction type for #{planar_surface.name}.  This surface will not have the standard applied.")
        return previous_construction_map
      end
    end

    # Check if the construction type was already created.
    # If yes, use that construction.  If no, make a new one.
    new_construction = nil
    type = [template, climate_zone, surf_type, stds_type, occ_type]
    if previous_construction_map[type]
      new_construction = previous_construction_map[type]
    else
      new_construction = model_find_and_add_construction(planar_surface.model,
                                                         climate_zone_set,
                                                         surf_type,
                                                         stds_type,
                                                         occ_type)
      if !new_construction == false
        previous_construction_map[type] = new_construction
      end
    end

    # Assign the new construction to the surface
    if new_construction
      planar_surface.setConstruction(new_construction)
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.PlanarSurface', "Set the construction for #{planar_surface.name} to #{new_construction.name}.")
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.PlanarSurface', "Could not generate a standard construction for #{planar_surface.name}.")
      return previous_construction_map
    end

    return previous_construction_map
  end
end

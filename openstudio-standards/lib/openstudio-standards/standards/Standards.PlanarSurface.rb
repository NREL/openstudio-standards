# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::PlanarSurface

  # If construction properties can be found 
  # based on the template, 
  # the standards intended surface type,
  # the standards construction type,
  # the climate zone, and the occupancy type,
  # create a construction that meets those properties and
  # assign it to this surface.
  #
  # @param template [String] valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @climate_zone [String]
  # @param previous_construction_map [Hash] a hash where the keys are an array of inputs
  # [template, climate_zone, intended_surface_type, standards_construction_type, occ_type]
  # and the values are the constructions.  If supplied, constructions will be pulled
  # from this hash if already created to avoid creating duplicate constructions.
  # @return [Hash] returns a hash where the key is an array of inputs
  # [template, climate_zone, intended_surface_type, standards_construction_type, occ_type]
  # and the value is the newly created construction.  This can be
  # used to avoid creating duplicate constructions.
  def apply_standard_construction(template, climate_zone, previous_construction_map = {})

    # Skip surfaces not in a space
    return previous_construction_map if self.space.empty?
    space = self.space.get
   
    # Skip surfaces that don't have a construction
    return previous_construction_map if self.construction.empty?
    construction = self.construction.get
    
    # Determine if residential or nonresidential
    # based on the space type.
    occ_type = 'Nonresidential'
    if space.spaceType.is_initialized
      space_type = space.spaceType.get
      space_type_props = space_type.get_standards_data(template)
      if space_type_props['is_residential']
        occ_type = 'Residential'
      end
    end
    
    # Get the climate zone set
    climate_zone_set = self.model.find_climate_zone_set(climate_zone, template)
    
    # Get the intended surface type
    standards_info = construction.standardsInformation
    intended_surface_type = standards_info.intendedSurfaceType
    standards_construction_type = standards_info.standardsConstructionType
    if intended_surface_type.empty?
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.PlanarSurface", "Could not determine the intended surface type for #{self.name}.  This surface will not have the standard applied.")
      return previous_construction_map
    end
    if standards_construction_type.empty?
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.PlanarSurface", "Could not determine the standards construction type for #{self.name}.  This surface will not have the standard applied.")
      return previous_construction_map
    end
    
    # Check if the construction type was already created.
    # If yes, use that construction.  If no, make a new one.
    new_construction = nil
    type = [template, climate_zone, intended_surface_type.get, standards_construction_type.get, occ_type]
    if previous_construction_map[type]
      new_construction = previous_construction_map[type]
    else
      new_construction = self.model.find_and_add_construction(template,
                                                  climate_zone_set,
                                                  intended_surface_type.get,
                                                  standards_construction_type.get,
                                                  occ_type)
      if !new_construction == false
        previous_construction_map[type] = new_construction
      end
    end
    
    # Assign the new construction to the surface
    if new_construction
      self.setConstruction(new_construction)
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.model.PlanarSurface", "Set the construction for #{self.name} to #{new_construction.name}.")
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.model.PlanarSurface", "Could not generate a standard construction for #{self.name}.")
      return previous_construction_map
    end
    
    return previous_construction_map 
 
  end

end

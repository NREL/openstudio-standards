# Methods to obtain information about model spaces
module OpenstudioStandards
  module Space
    # @!group Space

    # Determine if the space is a plenum.
    # Assume it is a plenum if it is a supply or return plenum for an AirLoop,
    # if it is not part of the total floor area,
    # or if the space type name contains the word plenum.
    #
    # @param space [OpenStudio::Model::Space] space object
    # return [Boolean] returns true if plenum, false if not
    def self.space_plenum?(space)
      plenum_status = false

      # Check if it is designated
      # as not part of the building
      # floor area.  This method internally
      # also checks to see if the space's zone
      # is a supply or return plenum
      unless space.partofTotalFloorArea
        plenum_status = true
        return plenum_status
      end

      # @todo update to check if it has internal loads

      # Check if the space type name
      # contains the word plenum.
      space_type = space.spaceType
      if space_type.is_initialized
        space_type = space_type.get
        if space_type.name.get.to_s.downcase.include?('plenum')
          plenum_status = true
          return plenum_status
        end
        if space_type.standardsSpaceType.is_initialized
          if space_type.standardsSpaceType.get.downcase.include?('plenum')
            plenum_status = true
            return plenum_status
          end
        end
      end

      return plenum_status
    end

    # Determine if the space is residential based on the space type properties for the space.
    # For spaces with no space type, assume nonresidential.
    # For spaces that are plenums, base the decision on the space
    # type of the space below the largest floor in the plenum.
    #
    # @param space [OpenStudio::Model::Space] space object
    # return [Boolean] true if residential, false if nonresidential
    def self.space_residential?(space)
      is_res = false

      space_to_check = space
  
      # If this space is a plenum, check the space type
      # of the space below the largest floor in the space
      if space_plenum?(space)
        # Find the largest floor
        largest_floor_area = 0.0
        largest_surface = nil
        space.surfaces.each do |surface|
          next unless surface.surfaceType == 'Floor' && surface.outsideBoundaryCondition == 'Surface'
  
          if surface.grossArea > largest_floor_area
            largest_floor_area = surface.grossArea
            largest_surface = surface
          end
        end
        if largest_surface.nil?
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} is a plenum, but could not find a floor with a space below it to determine if plenum should be  res or nonres.  Assuming nonresidential.")
          return is_res
        end
        # Get the space on the other side of this floor
        if largest_surface.adjacentSurface.is_initialized
          adj_surface = largest_surface.adjacentSurface.get
          if adj_surface.space.is_initialized
            space_to_check = adj_surface.space.get
          else
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} is a plenum, but could not find a space attached to the largest floor's adjacent surface #{adj_surface.name} to determine if plenum should be res or nonres.  Assuming nonresidential.")
            return is_res
          end
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} is a plenum, but could not find a floor with a space below it to determine if plenum should be  res or nonres.  Assuming nonresidential.")
          return is_res
        end
      end
  
      space_type = space_to_check.spaceType
      if space_type.is_initialized
        space_type = space_type.get
        # @todo need an alterante way of determining residential without standards data
        # Get the space type data
        if /prm/i !~ template
          # This is the PRM method for 2013 and prior
          space_type_properties = space_type_get_standards_data(space_type)
          if space_type_properties.nil?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "Could not find space type properties for #{space_to_check.name}, assuming nonresidential.")
            is_res = false
          else
            is_res = space_type_properties['is_residential'] == 'Yes'
          end
        else
          # This is the 2019 PRM method
          lighting_properties = interior_lighting_get_prm_data(space_type)
          if lighting_properties.empty?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "Could not find lighting properties for #{space_to_check.name}, assuming nonresidential.")
            is_res = false
          else
            is_res = lighting_properties['isresidential'].to_s == '1'
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "Could not find a space type for #{space_to_check.name}, assuming nonresidential.")
        is_res = false
      end
  
      return is_res
    end
  
  end
end
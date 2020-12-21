class Standard
  # @!group BuildingStory

  # Checks all spaces on this story that are part of the total
  # floor area to see if they have the same multiplier.
  # If they do, assume that the multipliers are being used
  # as a floor multiplier.
  #
  # @return [Integer] return the floor multiplier for this story,
  # returning 1 if no floor multiplier.
  def building_story_floor_multiplier(building_story)
    floor_multiplier = 1

    # Determine the multipliers for all spaces
    multipliers = []
    building_story.spaces.each do |space|
      # Ignore spaces that aren't part of the total floor area
      next unless space.partofTotalFloorArea

      multipliers << space.multiplier
    end

    # If there are no spaces on this story, assume
    # a multiplier of 1
    if multipliers.size.zero?
      return floor_multiplier
    end

    # Calculate the average multiplier and
    # then convert to integer.
    avg_multiplier = (multipliers.inject { |a, e| a + e }.to_f / multipliers.size).to_i

    # If the multiplier is greater than 1, report this
    if avg_multiplier > 1
      floor_multiplier = avg_multiplier
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BuildingStory', "Story #{building_story.name} has a multiplier of #{floor_multiplier}.")
    end

    return floor_multiplier
  end

  # Gets the minimum z-value of the story.
  # This is considered to be the minimum z value
  # of any vertex of any surface of any space on the
  # story, with the exception of plenum spaces.
  #
  # @return [Double] the minimum z-value, in m
  def building_story_minimum_z_value(building_story)
    z_heights = []
    building_story.spaces.each do |space|
      # Skip plenum spaces
      next if space_plenum?(space)

      # Get the z value of the space, which
      # vertices in space surfaces are relative to.
      z_origin = space.zOrigin

      # loop through space surfaces to find min z value
      space.surfaces.each do |surface|
        surface.vertices.each do |vertex|
          z_heights << vertex.z + z_origin
        end
      end
    end

    # Error if no z heights were found
    z = 999.9
    if !z_heights.empty?
      z = z_heights.min
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.BuildingStory', "For #{building_story.name} could not find the minimum_z_value, which means the story has no spaces assigned or the spaces have no surfaces.")
    end

    return z
  end
end

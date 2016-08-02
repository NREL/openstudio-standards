
# open the class to add methods to apply HVAC efficiency standards
class OpenStudio::Model::BuildingStory
  # Checks all spaces on this story that are part of the total
  # floor area to see if they have the same multiplier.
  # If they do, assume that the multipliers are being used
  # as a floor multiplier.
  #
  # @return [Integer] return the floor multiplier for this story,
  # returning 1 if no floor multiplier.
  def floor_multiplier
    floor_multiplier = 1

    # Determine the multipliers for all spaces
    multipliers = []
    spaces.each do |space|
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
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BuildingStory', "Story #{name} has a multiplier of #{floor_multiplier}.")
    end

    return floor_multiplier
  end
end

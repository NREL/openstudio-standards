class DEER
  # @!group Model

  # Determine which climate zone to use.
  # Uses the most specific climate zone set.
  def model_get_climate_zone_set_from_list(model, possible_climate_zone_sets)
    # OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "SpaceType #{space.spaceType.get.name} does not have a standardsSpaceType assigned.")
    climate_zone_set = possible_climate_zone_sets.max
    return climate_zone_set
  end
end

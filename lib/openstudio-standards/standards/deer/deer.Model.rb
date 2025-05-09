class DEER
  # @!group Model

  # Determine which climate zone to use.
  # Uses the most specific climate zone set.
  def model_get_climate_zone_set_from_list(model, possible_climate_zone_sets)
    # OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "SpaceType #{space.spaceType.get.name} does not have a standardsSpaceType assigned.")
    climate_zone_set = possible_climate_zone_sets.max
    return climate_zone_set
  end

  # Determines how ventilation for the standard is specified.
  # When 'Sum', all min OA flow rates are added up.  Commonly used by 90.1.
  # When 'Maximum', only the biggest OA flow rate.  Used by T24.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [String] the ventilation method, either Sum or Maximum
  def model_ventilation_method(model)
    ventilation_method = 'Maximum'
    return ventilation_method
  end
end

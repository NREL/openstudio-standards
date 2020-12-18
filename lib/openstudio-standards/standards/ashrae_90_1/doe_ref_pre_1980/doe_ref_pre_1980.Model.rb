class DOERefPre1980 < ASHRAE901
  # @!group Model

  # Apply the air leakage requirements to the model.
  # "For 'DOE Ref Pre-1980' and 'DOE Ref 1980-2004',
  # infiltration rates are not defined using this method,
  # no changes are actually made to the model.
  #
  # base infiltration rates off of.
  # @return [Bool] true if successful, false if not
  # @todo This infiltration method is not used by the Reference
  # buildings, fix this inconsistency.
  def model_apply_infiltration_standard(model)
    # Set the infiltration rate at each space
    model.getSpaces.sort.each do |space|
      space_apply_infiltration_rate(space)
    end

    return true
  end

  # Determine which climate zone to use.
  # For Pre-1980 and 1980-2004, use the most specific climate zone set.
  # For example, 2A and 2 both contain 2A, so use 2A.
  # The exceptions are climate zones 1, 7, and 8, which
  # combine 1A/1B, 7A/7B, and 8A/8B into 1, 7, and 8.
  def model_get_climate_zone_set_from_list(model, possible_climate_zone_sets)
    climate_zone_set = if possible_climate_zone_sets.include? 'ClimateZone 1'
                         possible_climate_zone_sets.min
                       elsif possible_climate_zone_sets.include? 'ClimateZone 7'
                         possible_climate_zone_sets.min
                       elsif possible_climate_zone_sets.include? 'ClimateZone 8'
                         possible_climate_zone_sets.min
                       else
                         possible_climate_zone_sets.max
                       end
    return climate_zone_set
  end
end

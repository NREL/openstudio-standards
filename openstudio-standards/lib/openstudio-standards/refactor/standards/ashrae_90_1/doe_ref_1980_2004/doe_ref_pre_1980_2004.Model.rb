class DOERefPre1980_Model < A90_1_Model
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
    getSpaces.sort.each do |space|
      space_apply_infiltration_rate(space)
    end

    return true
  end

  # Determine which climate zone to use.
  # For Pre-1980 and 1980-2004, use the most specific climate zone set.
  # For example, 2A and 2 both contain 2A, so use 2A.
  def model_get_climate_zone_set_from_list(model, possible_climate_zone_sets)
    climate_zone_set = possible_climate_zone_sets.sort.last
    return climate_zone_set
  end  
end

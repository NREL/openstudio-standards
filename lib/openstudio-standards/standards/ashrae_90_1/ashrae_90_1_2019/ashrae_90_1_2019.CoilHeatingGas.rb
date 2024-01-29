class ASHRAE9012019 < ASHRAE901
  # Applies the standard efficiency ratings to CoilHeatingGas.
  #
  # @param coil_heating_gas [OpenStudio::Model::CoilHeatingGas] coil heating gas object
  # @param search_criteria [Hash] search criteria for looking up furnace data
  # @return [Hash] updated search criteria
  def coil_heating_gas_additional_search_criteria(coil_heating_gas, search_criteria)
    search_criteria['subtype'] = 'Weatherized' # assumption; could be based on input
    return search_criteria
  end
end

class DOERefPre1980_Model < A90_1_Model
  # Updates the efficiency of some gas heating coils
  # per the prototype assumptions. Sets heating coils
  # inside PSZ-AC systems to 78% efficiency per
  # the older vintages.
  def coil_heating_gas_apply_prototype_efficiency(coil_heating_gas)
    return true unless coil_heating_gas.name.get.include?('PSZ-AC') # Only modify coils in PSZ-AC units
    coil_heating_gas.setGasBurnerEfficiency(0.78)
    return true
  end
end

class DOERefPre1980_Model < A90_1_Model
  # Updates the efficiency of some gas heating coils
  # per the prototype assumptions. Sets heating coils
  # inside PSZ-AC systems to 78% efficiency per
  # the older vintages.
  # @todo Refactor: remove inconsistency in logic; all coils should be lower efficiency
  def coil_heating_gas_apply_prototype_efficiency(coil_heating_gas)
    # Only modify coils in PSZ-AC units
    name_patterns = ['PSZ-AC Gas Htg Coil', 'ZN HVAC_', 'PSZ-AC_2-7 Gas Htg', 'PSZ-AC_2-5 Gas Htg', 'PSZ-AC_1-6 Gas Htg']
    name_patterns.each do |pattern|
      if coil_heating_gas.name.get.include?(pattern)
        coil_heating_gas.setGasBurnerEfficiency(0.78)
      end
    end

    return true
  end
end

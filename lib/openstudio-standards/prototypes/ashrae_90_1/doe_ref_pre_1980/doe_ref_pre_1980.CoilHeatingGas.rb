class DOERefPre1980 < ASHRAE901
  # @!group CoilHeatingGas

  # Updates the efficiency of some gas heating coils per the prototype assumptions.
  # Sets heating coils inside PSZ-AC systems to 78% efficiency per the older vintages.
  # @todo Refactor: remove inconsistency in logic; all coils should be lower efficiency
  #
  # @param coil_heating_gas [OpenStudio::Model::CoilHeatingGas] a gas heating coil
  # @return [Boolean] returns true if successful, false if not
  def coil_heating_gas_apply_prototype_efficiency(coil_heating_gas)
    # Only modify coils in PSZ-AC units
    name_patterns = ['PSZ-AC Gas Htg Coil',
                     'ZN HVAC_',
                     'PSZ-AC_2-7 Gas Htg',
                     'PSZ-AC_2-5 Gas Htg',
                     'PSZ-AC_1-6 Gas Htg',
                     'PSZ-AC-1 Gas Htg',
                     'PSZ-AC-2 Gas Htg',
                     'PSZ-AC-3 Gas Htg',
                     'PSZ-AC-4 Gas Htg',
                     'PSZ-AC-5 Gas Htg',
                     'PSZ-AC_3-7 Gas Htg',
                     'PSZ-AC_2-6 Gas Htg',
                     'PSZ-AC_5-9 Gas Htg',
                     'PSZ-AC_1-5 Gas Htg',
                     'PSZ-AC_4-8 Gas Htg',
                     'PSZ-AC_1 Gas Htg',
                     'PSZ-AC_2 Gas Htg',
                     'PSZ-AC_3 Gas Htg',
                     'PSZ-AC_4 Gas Htg',
                     'PSZ-AC_5 Gas Htg',
                     'PSZ-AC_6 Gas Htg',
                     'PSZ-AC_7 Gas Htg',
                     'PSZ-AC_8 Gas Htg',
                     'PSZ-AC_9 Gas Htg',
                     'PSZ-AC_10 Gas Htg']
    name_patterns.each do |pattern|
      if coil_heating_gas.name.get.include?(pattern)
        coil_heating_gas.setGasBurnerEfficiency(0.78)
      end
    end

    return true
  end
end

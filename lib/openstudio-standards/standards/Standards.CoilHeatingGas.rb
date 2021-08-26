class Standard
  # @!group CoilHeatingGas

  # Applies the standard efficiency ratings to CoilHeatingGas.
  #
  # @param coil_heating_gas [OpenStudio::Model::CoilHeatingGas] the object to modify
  # @return [Bool] true if successful, false if not
  def coil_heating_gas_apply_efficiency_and_curves(coil_heating_gas)
    successfully_set_all_properties = false

    # Initialize search criteria
    search_criteria = {}
    search_criteria['template'] = template

    # Get the capacity, but return false if not available
    capacity_w = coil_heating_gas_find_capacity(coil_heating_gas)

    # Return false if the coil does not have a heating capacity associated with it. Cannot apply the standard if without
    # it.
    return successfully_set_all_properties if capacity_w == false

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the boiler properties
    furnace_props = model_find_object(standards_data['furnaces'], search_criteria, capacity_btu_per_hr)
    unless furnace_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGas', "For #{coil_heating_gas.name}, cannot find furnace properties with search criteria #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Get the minimum efficiency standards
    thermal_eff = nil

    # If specified as thermal efficiency, this takes precedent
    if not furnace_props['minimum_thermal_efficiency'].nil?
      thermal_eff = furnace_props['minimum_thermal_efficiency']
      new_comp_name = "#{coil_heating_gas.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingGas', "For #{template}: #{coil_heating_gas.name}: = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")

    else # If not thermal efficiency, check other parameters

      # If specified as AFUE
      unless furnace_props['minimum_annual_fuel_utilization_efficiency'].nil?
        min_afue = furnace_props['minimum_annual_fuel_utilization_efficiency']
        thermal_eff = afue_to_thermal_eff(min_afue)
        new_comp_name = "#{coil_heating_gas.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE"
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingGas', "For #{template}: #{coil_heating_gas.name}: = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
      end

      # If specified as combustion efficiency
      unless furnace_props['minimum_combustion_efficiency'].nil?
        min_comb_eff = furnace_props['minimum_combustion_efficiency']
        thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
        new_comp_name = "#{coil_heating_gas.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingGas', "For #{template}: #{coil_heating_gas.name}: = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
      end

    end

    # Set the efficiency values
    unless thermal_eff.nil?

      # Set the name
      coil_heating_gas.setName(new_comp_name)
      coil_heating_gas.setGasBurnerEfficiency(thermal_eff)
      successfully_set_all_properties = true
    end

    return successfully_set_all_properties
  end

  # Retrieves the capacity of an OpenStudio::Model::CoilHeatingGas in watts
  #
  # @param coil_heating_gas [OpenStudio::Model::CoilHeatingGas] the gas heating coil
  # @return [Double, false] a double representing the capacity of the CoilHeatingGas object in watts. If unsuccessful in
  #   determining the capacity, this function returns false.
  def coil_heating_gas_find_capacity(coil_heating_gas)
    capacity_w = nil
    if coil_heating_gas.nominalCapacity.is_initialized
      capacity_w = coil_heating_gas.nominalCapacity.get
    elsif coil_heating_gas.autosizedNominalCapacity.is_initialized
      capacity_w = coil_heating_gas.autosizedNominalCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGas', "For #{coil_heating_gas.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    return capacity_w
  end
end

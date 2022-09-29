class ASHRAE901PRM < Standard
  # @!group BoilerHotWater

  # find search criteria
  #
  # @param coil_heating_gas [OpenStudio::Model::CoilHeatingGas] coil heating gas object
  # @param sys_type [String] HVAC system type
  # @return [Hash] used for standards_lookup_table(model)
  def coil_heating_gas_find_search_criteria(coil_heating_gas, sys_type)
    # Define the criteria to find the furnace properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['fuel_type'] = 'Gas'
    if sys_type == 'PSZ_AC'
      search_criteria['subcategory'] = 'Furnace'
    elsif sys_type == 'Gas_Furnace'
      search_criteria['subcategory'] = 'Unit Heater'
    else
      search_criteria['subcategory'] = 'Furnace'
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGas', "#{coil_heating_gas.name} is not for a PSZ-AC or Gas Furnace and cannot apply efficiency standard.")
    end

    return search_criteria
  end

  # find furnace capacity
  #
  # @param coil_heating_gas [OpenStudio::Model::CoilHeatingGas] coil heating gas object
  # @return [Double] capacity in W to be used for find object
  def coil_heating_gas_find_capacity(coil_heating_gas)
    # Get the coil capacity
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

  # Finds lookup object in standards and return minimum thermal efficiency
  #
  # @param coil_heating_gas [OpenStudio::Model::CoilHeatingGas] coil heating gas object
  # @param sys_type [String] HVAC system type
  # @param rename [Bool] if true, object will be renamed to include capacity and efficiency level
  # @return [Double] minimum thermal efficiency
  def coil_heating_gas_standard_minimum_thermal_efficiency(coil_heating_gas, sys_type, rename = false)
    # Get the coil properties
    search_criteria = coil_heating_gas_find_search_criteria(coil_heating_gas, sys_type)
    capacity_w = coil_heating_gas_find_capacity(coil_heating_gas)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the minimum efficiency standards
    thermal_eff = nil

    # Get the coil properties
    coil_table = @standards_data['furnaces']
    coil_props = model_find_object(coil_table, search_criteria, [capacity_btu_per_hr, 0.001].max)

    # Check to make sure properties were found
    if coil_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGas', "For #{coil_heating_gas.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # New name initial value
    new_comp_name = coil_heating_gas.name

    # If specified as thermal efficiency
    unless coil_props['minimum_thermal_efficiency'].nil?
      thermal_eff = coil_props['minimum_thermal_efficiency']
      new_comp_name = "#{coil_heating_gas.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingGas', "For #{template}: #{coil_heating_gas.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless coil_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = coil_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      new_comp_name = "#{coil_heating_gas.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingGas', "For #{template}: #{coil_heating_gas.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
    end

    unless thermal_eff
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGas', "For #{CoilHeatingGas.name}, cannot find coil efficiency, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Rename
    if rename
      coil_heating_gas.setName(new_comp_name)
    end

    return thermal_eff
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @param coil_heating_gas [OpenStudio::Model::CoilHeatingGas] coil heating gas object
  # @param sql_db_vars_map [Hash] hash map
  # @param sys_type [String] HVAC system type
  # @return [Hash] hash of coil objects
  def coil_heating_gas_apply_efficiency_and_curves(coil_heating_gas, sql_db_vars_map, sys_type)
    # Thermal efficiency
    thermal_eff = coil_heating_gas_standard_minimum_thermal_efficiency(coil_heating_gas, sys_type)

    # Set the efficiency values
    coil_heating_gas.setGasBurnerEfficiency(thermal_eff.to_f)

    return sql_db_vars_map
  end
end

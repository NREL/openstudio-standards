
class Standard
  # @!group CoilHeatingGas

  # find search criteria
  #
  # @return [Hash] used for standards_lookup_table(model)
  def coil_heating_gas_find_search_criteria
    # Define the criteria to find the furnace properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template

    return search_criteria
  end

  # find furnace capacity
  #
  # @return [Hash] used for standards_lookup_table(model)
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
  # @return [Double] minimum thermal efficiency
  def coil_heating_gas_standard_minimum_thermal_efficiency(coil_heating_gas, rename = false)

    # Get the coil properties
    search_criteria = coil_heating_gas_find_search_criteria
    capacity_w = coil_heating_gas_find_capacity(coil_heating_gas)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the minimum efficiency standards
    thermal_eff = nil

    # Get the coil properties
    coil_props = standards_lookup_table_first(table_name: 'furnaces',
                                             search_criteria: search_criteria,
                                             capacity: capacity_btu_per_hr)
    unless coil_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGas', "For #{CoilHeatingGas.name}, cannot find coil props, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # New name initial value
    new_comp_name = coil_heating_gas.name

    # If specified as AFUE
    unless coil_props['minimum_annual_fuel_utilization_efficiency'].nil?
      min_afue = coil_props['minimum_annual_fuel_utilization_efficiency']
      thermal_eff = afue_to_thermal_eff(min_afue)
      new_comp_name = "#{coil_heating_gas.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingGas', "For #{template}: #{coil_heating_gas.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end

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
  # @return [Bool] true if successful, false if not
  def coil_heating_gas_apply_efficiency_and_curves(coil_heating_gas)
    successfully_set_all_properties = true

    # Define the search criteria
    search_criteria = coil_heating_gas_find_search_criteria

    # Get the coil capacity
    capacity_w = coil_heating_gas_find_capacity(coil_heating_gas)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get

    # lookup properties
    coil_props = standards_lookup_table_first(table_name: 'furnaces',
                                                         search_criteria:  search_criteria,
                                                         capacity: capacity_btu_per_hr,
                                                         date: Date.today)
    # Check to make sure properties were found
    if coil_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGas', "For #{coil_heating_gas.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
    end

    # Make the plf vs plr curve
    plffplr_curve = model_add_curve(coil_heating_gas.model, coil_props['efffplr'])
    if plffplr_curve
      coil_heating_gas.setPartLoadFractionCorrelationCurve(plffplr_curve)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGas', "For #{coil_heating_gas.name}, cannot find plffplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Thermal efficiency
    thermal_eff = coil_heating_gas_standard_minimum_thermal_efficiency(coil_heating_gas)

    # Set the efficiency values
    coil_heating_gas.setGasBurnerEfficiency(thermal_eff)

    return successfully_set_all_properties

  end
end

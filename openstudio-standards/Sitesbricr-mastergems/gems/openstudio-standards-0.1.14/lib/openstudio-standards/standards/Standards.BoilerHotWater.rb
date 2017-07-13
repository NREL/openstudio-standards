
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::BoilerHotWater
  # find search criteria
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [Hash] used for find_object
  def find_search_criteria(template)
    # Define the criteria to find the boiler properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template

    # Get fuel type
    fuel_type = nil
    case fuelType
    when 'NaturalGas'
      fuel_type = 'Gas'
    when 'Electricity'
      fuel_type = 'Electric'
    when 'FuelOil#1', 'FuelOil#2'
      fuel_type = 'Oil'
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{name}, a fuel type of #{fuelType} is not yet supported.  Assuming 'Gas.'")
      fuel_type = 'Gas'
    end

    search_criteria['fuel_type'] = fuel_type

    # Get the fluid type
    fluid_type = 'Hot Water'
    search_criteria['fluid_type'] = fluid_type

    return search_criteria
  end

  # Find capacity in W
  #
  # @return [Double] capacity in W
  def find_capacity
    capacity_w = nil
    if nominalCapacity.is_initialized
      capacity_w = nominalCapacity.get
    elsif autosizedNominalCapacity.is_initialized
      capacity_w = autosizedNominalCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    return capacity_w
  end

  # Finds lookup object in standards and return minimum thermal efficiency
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Double] minimum thermal efficiency
  def standard_minimum_thermal_efficiency(template, rename=false)
    # Get the boiler properties
    search_criteria = find_search_criteria(template)
    capacity_w = find_capacity
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the minimum efficiency standards
    thermal_eff = nil

    # Get the boiler properties
    blr_props = model.find_object($os_standards['boilers'], search_criteria, capacity_btu_per_hr)
    unless blr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{name}, cannot find boiler properties, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    fuel_type = blr_props['fuel_type']
    fluid_type = blr_props['fluid_type']

    # If specified as AFUE
    unless blr_props['minimum_annual_fuel_utilization_efficiency'].nil?
      min_afue = blr_props['minimum_annual_fuel_utilization_efficiency']
      thermal_eff = afue_to_thermal_eff(min_afue)
      new_comp_name = "#{name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end

    # If specified as thermal efficiency
    unless blr_props['minimum_thermal_efficiency'].nil?
      thermal_eff = blr_props['minimum_thermal_efficiency']
      new_comp_name = "#{name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless blr_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = blr_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      new_comp_name = "#{name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
    end

    # Rename
    if rename
      setName(new_comp_name)
    end

    return thermal_eff
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB2011'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Bool] true if successful, false if not
  def apply_efficiency_and_curves(template)
    successfully_set_all_properties = false 

    # Define the criteria to find the boiler properties
    # in the hvac standards data set.
    search_criteria = find_search_criteria(template)
    fuel_type = search_criteria['fuel_type']
    fluid_type = search_criteria['fluid_type']

    # Get the capacity
    capacity_w = find_capacity

    # for NECB, check if secondary and/or modulating boiler required
    if template == 'NECB 2011'
      if capacity_w / 1000.0 >= 352.0
        if name.to_s.include?('Primary Boiler')
          boiler_capacity = capacity_w
          setBoilerFlowMode('LeavingSetpointModulated')
          setMinimumPartLoadRatio(0.25)
        elsif name.to_s.include?('Secondary Boiler')
          boiler_capacity = 0.001
        end
      elsif ((capacity_w / 1000.0) >= 176.0) && ((capacity_w / 1000.0) < 352.0)
        boiler_capacity = capacity_w / 2
      elsif (capacity_w / 1000.0) <= 176.0
        if name.to_s.include?('Primary Boiler')
          boiler_capacity = capacity_w
        elsif name.to_s.include?('Secondary Boiler')
          boiler_capacity = 0.001
        end
      end
      setNominalCapacity(boiler_capacity)
    end # NECB 2011

    # Convert capacity to Btu/hr
    if template == 'NECB 2011'
      capacity_btu_per_hr = OpenStudio.convert(boiler_capacity, 'W', 'Btu/hr').get
      capacity_kbtu_per_hr = OpenStudio.convert(boiler_capacity, 'W', 'kBtu/hr').get
    else
      capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
      capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get
    end

    # Get the boiler properties
    blr_props = model.find_object($os_standards['boilers'], search_criteria, capacity_btu_per_hr)
    unless blr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{name}, cannot find boiler properties, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the EFFFPLR curve
    eff_fplr = model.add_curve(blr_props['efffplr'])
    if eff_fplr
      setNormalizedBoilerEfficiencyCurve(eff_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{name}, cannot find eff_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Get the minimum efficiency standards
    thermal_eff = nil

    # If specified as AFUE
    unless blr_props['minimum_annual_fuel_utilization_efficiency'].nil?
      min_afue = blr_props['minimum_annual_fuel_utilization_efficiency']
      thermal_eff = afue_to_thermal_eff(min_afue)
      new_comp_name = "#{name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end

    # If specified as thermal efficiency
    unless blr_props['minimum_thermal_efficiency'].nil?
      thermal_eff = blr_props['minimum_thermal_efficiency']
      new_comp_name = "#{name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless blr_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = blr_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      new_comp_name = "#{name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
    end

    # Set the name
    setName(new_comp_name)

    # Set the efficiency values
    unless thermal_eff.nil?
      setNominalThermalEfficiency(thermal_eff)
    end

    return successfully_set_all_properties
  end
end

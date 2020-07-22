
class Standard
  # @!group BoilerHotWater

  # find search criteria
  #
  # @return [Hash] used for standards_lookup_table(model)
  def boiler_hot_water_find_search_criteria(boiler_hot_water)
    # Define the criteria to find the boiler properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template

    # Get fuel type
    fuel_type = nil
    case boiler_hot_water.fuelType
    when 'NaturalGas'
      fuel_type = 'Gas'
    when 'Electricity'
      fuel_type = 'Electric'
    when 'FuelOilNo1', 'FuelOilNo2'
      fuel_type = 'Oil'
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{boiler_hot_water.name}, a fuel type of #{fuelType} is not yet supported.  Assuming 'Gas.'")
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
  def boiler_hot_water_find_capacity(boiler_hot_water)
    capacity_w = nil
    if boiler_hot_water.nominalCapacity.is_initialized
      capacity_w = boiler_hot_water.nominalCapacity.get
    elsif boiler_hot_water.autosizedNominalCapacity.is_initialized
      capacity_w = boiler_hot_water.autosizedNominalCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{boiler_hot_water.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    return capacity_w
  end

  # Finds lookup object in standards and return minimum thermal efficiency
  #
  # @return [Double] minimum thermal efficiency
  def boiler_hot_water_standard_minimum_thermal_efficiency(boiler_hot_water, rename = false)
    # Get the boiler properties
    search_criteria = boiler_hot_water_find_search_criteria(boiler_hot_water)
    capacity_w = boiler_hot_water_find_capacity(boiler_hot_water)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the minimum efficiency standards
    thermal_eff = nil

    # Get the boiler properties
    blr_props = model_find_object(standards_data['boilers'], search_criteria, capacity_btu_per_hr)
    unless blr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{boiler_hot_water.name}, cannot find boiler properties, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    fuel_type = blr_props['fuel_type']
    fluid_type = blr_props['fluid_type']

    # If specified as AFUE
    unless blr_props['minimum_annual_fuel_utilization_efficiency'].nil?
      min_afue = blr_props['minimum_annual_fuel_utilization_efficiency']
      thermal_eff = afue_to_thermal_eff(min_afue)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end

    # If specified as thermal efficiency
    unless blr_props['minimum_thermal_efficiency'].nil?
      thermal_eff = blr_props['minimum_thermal_efficiency']
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless blr_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = blr_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
    end

    # Rename
    if rename
      boiler_hot_water.setName(new_comp_name)
    end

    return thermal_eff
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @param boiler_hot_water [OpenStudio::Model::BoilerHotWater] the object to modify
  # @return [Bool] true if successful, false if not
  def boiler_hot_water_apply_efficiency_and_curves(boiler_hot_water)
    successfully_set_all_properties = false

    # Define the criteria to find the boiler properties
    # in the hvac standards data set.
    search_criteria = boiler_hot_water_find_search_criteria(boiler_hot_water)
    fuel_type = search_criteria['fuel_type']
    fluid_type = search_criteria['fluid_type']

    # Get the capacity
    capacity_w = boiler_hot_water_find_capacity(boiler_hot_water)

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the boiler properties
    blr_props = model_find_object(standards_data['boilers'], search_criteria, capacity_btu_per_hr)
    unless blr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{boiler_hot_water.name}, cannot find boiler properties with search criteria #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the EFFFPLR curve (not all boilers will have one)
    if blr_props['efffplr']
      eff_fplr = model_add_curve(boiler_hot_water.model, blr_props['efffplr'])
      if eff_fplr
        boiler_hot_water.setNormalizedBoilerEfficiencyCurve(eff_fplr)
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{boiler_hot_water.name}, cannot find eff_fplr curve, will not be set.")
        successfully_set_all_properties = false
      end
    end

    # Get the minimum efficiency standards
    thermal_eff = nil

    # If specified as AFUE
    unless blr_props['minimum_annual_fuel_utilization_efficiency'].nil?
      min_afue = blr_props['minimum_annual_fuel_utilization_efficiency']
      thermal_eff = afue_to_thermal_eff(min_afue)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end

    # If specified as thermal efficiency
    unless blr_props['minimum_thermal_efficiency'].nil?
      thermal_eff = blr_props['minimum_thermal_efficiency']
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless blr_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = blr_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
    end

    # Set the name
    boiler_hot_water.setName(new_comp_name)

    # Set the efficiency values
    unless thermal_eff.nil?
      boiler_hot_water.setNominalThermalEfficiency(thermal_eff)
    end

    return successfully_set_all_properties
  end
end

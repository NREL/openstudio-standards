class ASHRAE901PRM < Standard
  # @!group BoilerHotWater

  # find search criteria
  #
  # @param boiler_hot_water [OpenStudio::Model::BoilerHotWater] hot water boiler object
  # @return [Hash] used for standards_lookup_table(model)
  def boiler_hot_water_find_search_criteria(boiler_hot_water)
    # Define the criteria to find the boiler properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template

    # Get fuel type
    search_criteria['fuel_type'] = 'Gas'

    # Get the fluid type
    search_criteria['fluid_type'] = 'Hot Water'

    return search_criteria
  end

  # Finds lookup object in standards and return minimum thermal efficiency
  #
  # @param boiler_hot_water [OpenStudio::Model::BoilerHotWater] hot water boiler object
  # @param rename [Bool] returns true if successful, false if not
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

    # If specified as AFUE
    unless blr_props['minimum_annual_fuel_utilization_efficiency'].nil?
      min_afue = blr_props['minimum_annual_fuel_utilization_efficiency']
      thermal_eff = afue_to_thermal_eff(min_afue)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: Gas Hot Water Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end

    # If specified as thermal efficiency
    unless blr_props['minimum_thermal_efficiency'].nil?
      thermal_eff = blr_props['minimum_thermal_efficiency']
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: Gas Hot Water Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless blr_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = blr_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: Gas Hot Water Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
    end

    # Rename
    if rename
      boiler_hot_water.setName(new_comp_name)
    end

    return thermal_eff
  end

  # Applies the standard efficiency ratings to this object.
  #
  # @param boiler_hot_water [OpenStudio::Model::BoilerHotWater] hot water boiler object
  # @return [Bool] true if successful, false if not
  def boiler_hot_water_apply_efficiency_and_curves(boiler_hot_water)
    # Get the minimum efficiency standards
    thermal_eff = boiler_hot_water_standard_minimum_thermal_efficiency(boiler_hot_water)

    # Set the efficiency values
    unless thermal_eff.nil?
      boiler_hot_water.setNominalThermalEfficiency(thermal_eff)
    end
    return true
  end
end

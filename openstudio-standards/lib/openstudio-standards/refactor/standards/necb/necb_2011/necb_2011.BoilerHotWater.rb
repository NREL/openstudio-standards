
class NECB_2011_Model < StandardsModel
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

    # Check if secondary and/or modulating boiler required
    if capacity_w / 1000.0 >= 352.0
      if boiler_hot_water.name.to_s.include?('Primary Boiler')
        boiler_capacity = capacity_w
        boiler_hot_water.setBoilerFlowMode('LeavingSetpointModulated')
        boiler_hot_water.setMinimumPartLoadRatio(0.25)
      elsif boiler_hot_water.name.to_s.include?('Secondary Boiler')
        boiler_capacity = 0.001
      end
    elsif ((capacity_w / 1000.0) >= 176.0) && ((capacity_w / 1000.0) < 352.0)
      boiler_capacity = capacity_w / 2
    elsif (capacity_w / 1000.0) <= 176.0
      if boiler_hot_water.name.to_s.include?('Primary Boiler')
        boiler_capacity = capacity_w
      elsif boiler_hot_water.name.to_s.include?('Secondary Boiler')
        boiler_capacity = 0.001
      end
    end
    boiler_hot_water.setNominalCapacity(boiler_capacity)

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(boiler_capacity, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(boiler_capacity, 'W', 'kBtu/hr').get

    # Get the boiler properties
    blr_props = model_find_object(boiler_hot_water.model, $os_standards['boilers'], search_criteria, capacity_btu_per_hr)
    unless blr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{boiler_hot_water.name}, cannot find boiler properties, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the EFFFPLR curve
    eff_fplr = model_add_curve(boiler_hot_water.model, blr_props['efffplr'])
    if eff_fplr
      boiler_hot_water.setNormalizedBoilerEfficiencyCurve(eff_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{boiler_hot_water.name}, cannot find eff_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Get the minimum efficiency standards
    thermal_eff = nil

    # If specified as AFUE
    unless blr_props['minimum_annual_fuel_utilization_efficiency'].nil?
      min_afue = blr_props['minimum_annual_fuel_utilization_efficiency']
      thermal_eff = afue_to_thermal_eff(min_afue)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{instvartemplate}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end

    # If specified as thermal efficiency
    unless blr_props['minimum_thermal_efficiency'].nil?
      thermal_eff = blr_props['minimum_thermal_efficiency']
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{instvartemplate}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless blr_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = blr_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{instvartemplate}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
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

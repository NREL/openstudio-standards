
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::BoilerHotWater

  # Applies the standard efficiency ratings and typical performance curves to this object.
  # 
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Bool] true if successful, false if not 
  def setStandardEfficiencyAndCurves(template, standards)
  
    successfully_set_all_properties = false
  
    boilers = standards['boilers']

    # Define the criteria to find the boiler properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template
    
    # Get fuel type
    fuel_type = nil
    case self.fuelType
    when  'NaturalGas'
      fuel_type = 'Gas'
    when 'Electricity'
      fuel_type = 'Electric'
    when 'FuelOil#1', 'FuelOil#2'
      fuel_type = 'Oil'
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{self.name}, a fuel type of #{self.fuelType} is not yet supported.  Assuming 'Gas.'")
      fuel_type = 'Gas'
    end
    
    
    
    search_criteria['fuel_type'] = fuel_type
    
    # Get the fluid type
    fluid_type = 'Hot Water'
    search_criteria['fluid_type'] = fluid_type

    # Get the capacity
    capacity_w = nil
    if self.nominalCapacity.is_initialized
      capacity_w = self.nominalCapacity.get
    elsif self.autosizedNominalCapacity.is_initialized
      capacity_w = self.autosizedNominalCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{self.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end
 
    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, "W", "Btu/hr").get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, "W", "kBtu/hr").get

    # Get the boiler properties
    blr_props = self.model.find_object(boilers, search_criteria, capacity_btu_per_hr)
    unless blr_props
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{self.name}, cannot find boiler properties, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end
    
    # Make the EFFFPLR curve
    eff_fplr = self.model.add_curve(blr_props['efffplr'], standards)
    if eff_fplr
      self.setNormalizedBoilerEfficiencyCurve(eff_fplr)
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{self.name}, cannot find eff_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end   

    # Get the minimum efficiency standards
    thermal_eff = nil
    
    # If specified as AFUE
    unless blr_props['minimum_annual_fuel_utilization_efficiency'].nil?
      min_afue = blr_props['minimum_annual_fuel_utilization_efficiency']
      thermal_eff = afue_to_thermal_eff(min_afue)
      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE")
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater',  "For #{template}: #{self.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end
    
    # If specified as thermal efficiency
    unless blr_props['minimum_thermal_efficiency'].nil?
      thermal_eff = blr_props['minimum_thermal_efficiency']
      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff")
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{self.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless blr_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = blr_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff")
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{self.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
    end    
    
    # Set the efficiency values
    unless thermal_eff.nil?
      self.setNominalThermalEfficiency(thermal_eff)
    end   
  
    #puts "capacity_w = #{capacity_w}"
    
   # for NECB, check if modulating boiler required
   # TO DO: logic for 2 stage boilers when heating cap > 176 kW and < 352 kW
   if template == 'NECB 2011'      
      if capacity_w >= 352000 
        self.setBoilerFlowMode('LeavingSetpointModulated')
        self.setMinimumPartLoadRatio(0.25)
      end
   end  # NECB 2011
  return successfully_set_all_properties
  end
  
end

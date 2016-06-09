
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

    return search_criteria

  end

  # find capacity
  #
  # @return [Double]  capacity_btu_per_hr - used for find_object
  def find_capacity()

    # Get the capacity
    capacity_w = nil
    capacity_btu_per_hr = nil
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

    return capacity_btu_per_hr

  end

  # Finds lookup object in standards and return minimum thermal efficiency
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Double] minimum thermal efficiency
  def standard_minimum_thermal_efficiency(template,standards)

    # Get the boiler properties
    search_criteria = self.find_search_criteria(template)
    capacity_kbtu_per_hr = self.find_capacity
    blr_props = self.model.find_object(standards['boilers'], search_criteria, capacity_kbtu_per_hr)

    fuel_type = blr_props["fuel_type"]
    fluid_type = blr_props["fluid_type"]

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

    return thermal_eff

  end


  # Applies the standard efficiency ratings and typical performance curves to this object.
  # 
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB2011'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Bool] true if successful, false if not 
  def setStandardEfficiencyAndCurves(template)
  
    successfully_set_all_properties = false
  
    boilers = $os_standards['boilers']

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
    
    # for NECB, check if secondary and/or modulating boiler required
    if (template == 'NECB 2011')      
      if (capacity_w/1000.0 >= 352.0)
        if (self.name.to_s.include?("Primary Boiler"))
          boiler_capacity = capacity_w
          self.setBoilerFlowMode('LeavingSetpointModulated')
          self.setMinimumPartLoadRatio(0.25)
        elsif (self.name.to_s.include?("Secondary Boiler"))
          boiler_capacity = 0.001
        end
      elsif ((capacity_w/1000.0) >= 176.0) && ((capacity_w/1000.0) < 352.0)
        boiler_capacity = capacity_w/2
      elsif ((capacity_w/1000.0) <= 176.0)
        if (self.name.to_s.include?("Primary Boiler"))
          boiler_capacity = capacity_w
        elsif (self.name.to_s.include?("Secondary Boiler"))
          boiler_capacity = 0.001
        end
      end
      self.setNominalCapacity(boiler_capacity)
    end  # NECB 2011

    # Convert capacity to Btu/hr
    if template == 'NECB 2011'
      capacity_btu_per_hr = OpenStudio.convert(boiler_capacity, "W", "Btu/hr").get
      capacity_kbtu_per_hr = OpenStudio.convert(boiler_capacity, "W", "kBtu/hr").get
    else
      capacity_btu_per_hr = OpenStudio.convert(capacity_w, "W", "Btu/hr").get
      capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, "W", "kBtu/hr").get
    end
      

    # Get the boiler properties
    blr_props = self.model.find_object(boilers, search_criteria, capacity_btu_per_hr)
    unless blr_props
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{self.name}, cannot find boiler properties, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the EFFFPLR curve
    eff_fplr = self.model.add_curve(blr_props['efffplr'])
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
  
    return successfully_set_all_properties
  end
  
end

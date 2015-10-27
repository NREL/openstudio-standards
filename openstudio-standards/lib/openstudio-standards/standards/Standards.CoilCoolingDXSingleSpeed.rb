
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::CoilCoolingDXSingleSpeed

  # Applies the standard efficiency ratings and typical performance curves to this object.
  # 
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Bool] true if successful, false if not 
  def setStandardEfficiencyAndCurves(template, standards, sql_db_vars_map)
  
    successfully_set_all_properties = true
  
    unitary_acs = standards['unitary_acs']
    heat_pumps = standards['heat_pumps']
  
    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template
    cooling_type = self.condenserType
    search_criteria['cooling_type'] = cooling_type
    
    # TODO Standards - add split system vs single package to model
    # For now, assume single package as default
    subcategory = 'Single Package'
    
    # Determine the heating type if unitary or zone hvac
    heat_pump = false
    heating_type = nil
    if self.airLoopHVAC.empty?
      if self.containingHVACComponent.is_initialized
        containing_comp = containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          heat_pump = true
          heating_type = 'Electric Resistance or None'
        end # TODO Add other unitary systems
      elsif self.containingZoneHVACComponent.is_initialized
        containing_comp = containingZoneHVACComponent.get
        if containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          subcategory = 'PTAC'
          htg_coil = containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.get.heatingCoil
          if htg_coil.to_CoilHeatingElectric.is_initialized
            heating_type = 'Electric Resistance or None'          
          elsif htg_coil.to_CoilHeatingWater.is_initialized || htg_coil.to_CoilHeatingGas.is_initialized
            heating_type = 'All Other'
          end 
        end # TODO Add other zone hvac systems
      end
    end

    # Determine the heating type if on an airloop
    if self.airLoopHVAC.is_initialized
      air_loop = self.airLoopHVAC.get
      if air_loop.supplyComponents('Coil:Heating:Electric'.to_IddObjectType).size > 0
        heating_type = 'Electric Resistance or None'
      elsif air_loop.supplyComponents('Coil:Heating:Gas'.to_IddObjectType).size > 0
        heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:Water'.to_IddObjectType).size > 0
        heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:DX:SingleSpeed'.to_IddObjectType).size > 0
        heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:Gas:MultiStage'.to_IddObjectType).size > 0
        heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:Desuperheater'.to_IddObjectType).size > 0
        heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:WaterToAirHeatPump:EquationFit'.to_IddObjectType).size > 0
        heating_type = 'All Other'  
      else
        heating_type = 'Electric Resistance or None'
      end
    end

    # Add the heating type to the search criteria
    unless heating_type.nil?
      search_criteria['heating_type'] = heating_type
    end

    search_criteria['subcategory'] = subcategory
    
    # Get the coil capacity
    capacity_w = nil
    if self.ratedTotalCoolingCapacity.is_initialized
      capacity_w = self.ratedTotalCoolingCapacity.get
    elsif self.autosizedRatedTotalCoolingCapacity.is_initialized
      capacity_w = self.autosizedRatedTotalCoolingCapacity.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{self.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end    

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, "W", "Btu/hr").get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, "W", "kBtu/hr").get
    
    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props = nil
    if heat_pump == true
      ac_props = self.model.find_object(heat_pumps, search_criteria, capacity_btu_per_hr)
    else
      ac_props = self.model.find_object(unitary_acs, search_criteria, capacity_btu_per_hr)
    end

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{self.name}, cannot find efficiency info, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the COOL-CAP-FT curve
    cool_cap_ft = self.model.add_curve(ac_props["cool_cap_ft"], standards)
    if cool_cap_ft
      self.setTotalCoolingCapacityFunctionOfTemperatureCurve(cool_cap_ft)
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{self.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FFLOW curve
    cool_cap_fflow = self.model.add_curve(ac_props["cool_cap_fflow"], standards)
    if cool_cap_fflow
      self.setTotalCoolingCapacityFunctionOfFlowFractionCurve(cool_cap_fflow)
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{self.name}, cannot find cool_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end
    
    # Make the COOL-EIR-FT curve
    cool_eir_ft = self.model.add_curve(ac_props["cool_eir_ft"], standards)
    if cool_eir_ft
      self.setEnergyInputRatioFunctionOfTemperatureCurve(cool_eir_ft)  
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{self.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FFLOW curve
    cool_eir_fflow = self.model.add_curve(ac_props["cool_eir_fflow"], standards)
    if cool_eir_fflow
      self.setEnergyInputRatioFunctionOfFlowFractionCurve(cool_eir_fflow)
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{self.name}, cannot find cool_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end
    
    # Make the COOL-PLF-FPLR curve
    cool_plf_fplr = self.model.add_curve(ac_props["cool_plf_fplr"], standards)
    if cool_plf_fplr
      self.setPartLoadFractionCorrelationCurve(cool_plf_fplr)
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{self.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end 
 
    # Get the minimum efficiency standards
    cop = nil
    
    if subcategory == 'PTAC'
      ptac_eer_coeff_1 = ac_props['ptac_eer_coefficient_1']
      ptac_eer_coeff_2 = ac_props['ptac_eer_coefficient_2']
      capacity_btu_per_hr = 7000 if capacity_btu_per_hr < 7000
      capacity_btu_per_hr = 15000 if capacity_btu_per_hr > 15000
      ptac_eer = ptac_eer_coeff_1 + (ptac_eer_coeff_2 * capacity_btu_per_hr)
      cop = eer_to_cop(ptac_eer)
      #self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER")
      new_comp_name = "#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER"
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed',  "For #{template}: #{self.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{ptac_eer}")      
    end
    
    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop(min_seer)
      new_comp_name = "#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
#      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed',  "For #{template}: #{self.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end
    
    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{self.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop(min_seer)
      new_comp_name = "#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
#      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed',  "For #{template}: #{self.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end
 
      # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{self.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end  
    
       
    sql_db_vars_map[new_comp_name] = self.name.to_s
    self.setName(new_comp_name)

    # Set the efficiency values
    unless cop.nil?
      self.setRatedCOP(OpenStudio::OptionalDouble.new(cop))
    end

    return sql_db_vars_map

  end

end

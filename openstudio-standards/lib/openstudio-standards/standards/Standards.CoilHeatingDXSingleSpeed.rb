
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilHeatingDXSingleSpeed

  def setStandardEfficiencyAndCurves(template, standards, sql_db_vars_map)

    successfully_set_all_properties = true
  
    unitary_hps = standards['heat_pumps']
    heat_pumps = standards['heat_pumps_heating']
 
    # Define the criteria to find the unitary properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template

    # Determine supplemental heating type if unitary
    heat_pump = false
    suppl_heating_type = nil
    if self.airLoopHVAC.empty?
      if self.containingHVACComponent.is_initialized
        containing_comp = containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          heat_pump = true
          htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.supplementalHeatingCoil
          if htg_coil.to_CoilHeatingElectric.is_initialized
            suppl_heating_type = 'Electric Resistance or None'
          else
            suppl_heating_type = 'All Other'
          end
        end # TODO Add other unitary systems
      end
    end

    # Determine the supplemetal heating type if on an airloop
    if self.airLoopHVAC.is_initialized
      air_loop = self.airLoopHVAC.get
      if air_loop.supplyComponents('Coil:Heating:Electric'.to_IddObjectType).size > 0
        suppl_heating_type = 'Electric Resistance or None'
      elsif air_loop.supplyComponents('Coil:Heating:Gas'.to_IddObjectType).size > 0
        suppl_heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:Water'.to_IddObjectType).size > 0
        suppl_heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:DX:SingleSpeed'.to_IddObjectType).size > 0
        suppl_heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:Gas:MultiStage'.to_IddObjectType).size > 0
        suppl_heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:Desuperheater'.to_IddObjectType).size > 0
        suppl_heating_type = 'All Other'
      elsif air_loop.supplyComponents('Coil:Heating:WaterToAirHeatPump:EquationFit'.to_IddObjectType).size > 0
        suppl_heating_type = 'All Other'  
      else
        suppl_heating_type = 'Electric Resistance or None'
      end
    end

    # TODO Standards - add split system vs single package to model
    # For now, assume single package
    subcategory = 'Single Package'
    search_criteria['subcategory'] = subcategory

    # Get the coil capacity
    capacity_w = nil
    if(heat_pump == true)
      containing_comp = self.containingHVACComponent.get
      heat_pump_comp = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
      ccoil = heat_pump_comp.coolingCoil
      dxcoil = ccoil.to_CoilCoolingDXSingleSpeed.get
      dxcoil_name = dxcoil.name.to_s
      if sql_db_vars_map
        if sql_db_vars_map[dxcoil_name]
          dxcoil.setName(sql_db_vars_map[dxcoil_name])
        end
      end
      if dxcoil.ratedTotalCoolingCapacity.is_initialized
        capacity_w = dxcoil.ratedTotalCoolingCapacity.get
      elsif dxcoil.autosizedRatedTotalCoolingCapacity.is_initialized
        capacity_w = dxcoil.autosizedRatedTotalCoolingCapacity.get
      else
        OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{self.name} capacity is not available, cannot apply efficiency standard.")
        successfully_set_all_properties = false
        return successfully_set_all_properties  
      end
      dxcoil.setName(dxcoil_name)
    else
      if self.ratedTotalHeatingCapacity.is_initialized
        capacity_w = self.ratedTotalHeatingCapacity.get
      elsif self.autosizedRatedTotalHeatingCapacity.is_initialized
        capacity_w = self.autosizedRatedTotalHeatingCapacity.get
      else
        OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{self.name} capacity is not available, cannot apply efficiency standard.")
        successfully_set_all_properties = false
        return successfully_set_all_properties
      end    
    end

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, "W", "Btu/hr").get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, "W", "kBtu/hr").get

    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props = nil
    if heat_pump == true
      ac_props = self.model.find_object(heat_pumps, search_criteria, capacity_btu_per_hr)
    else
      ac_props = self.model.find_object(unitary_hps, search_criteria, capacity_btu_per_hr)
    end

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{self.name}, cannot find efficiency info, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the HEAT-CAP-FT curve
    heat_cap_ft = self.model.add_curve(ac_props["heat_cap_ft"], standards)
    if heat_cap_ft
      self.setTotalHeatingCapacityFunctionofTemperatureCurve(heat_cap_ft)
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{self.name}, cannot find heat_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FFLOW curve
    heat_cap_fflow = self.model.add_curve(ac_props["heat_cap_fflow"], standards)
    if heat_cap_fflow
      self.setTotalHeatingCapacityFunctionofFlowFractionCurve(heat_cap_fflow)
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{self.name}, cannot find heat_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end
    
    # Make the HEAT-EIR-FT curve
    heat_eir_ft = self.model.add_curve(ac_props["heat_eir_ft"], standards)
    if heat_eir_ft
      self.setEnergyInputRatioFunctionofTemperatureCurve(heat_eir_ft)  
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{self.name}, cannot find heat_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FFLOW curve
    heat_eir_fflow = self.model.add_curve(ac_props["heat_eir_fflow"], standards)
    if heat_eir_fflow
      self.setEnergyInputRatioFunctionofFlowFractionCurve(heat_eir_fflow)
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{self.name}, cannot find heat_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end
    
    # Make the HEAT-PLF-FPLR curve
    heat_plf_fplr = self.model.add_curve(ac_props["heat_plf_fplr"], standards)
    if heat_plf_fplr
      self.setPartLoadFractionCorrelationCurve(heat_plf_fplr)
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{self.name}, cannot find heat_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end 
 
    # Get the minimum efficiency standards
    cop = nil
    
    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop(min_seer)
      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed',  "For #{template}: #{self.name}: #{suppl_heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end
    
    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER")
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{self.name}:  #{suppl_heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Set the efficiency values
    unless cop.nil?
      self.setRatedCOP(cop)
    end

    return sql_db_vars_map

  end

end

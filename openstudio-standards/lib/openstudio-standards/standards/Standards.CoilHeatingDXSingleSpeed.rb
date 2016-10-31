
# open the class to add methods to return sizing values
class OpenStudio::Model::CoilHeatingDXSingleSpeed
  # Finds the search criteria
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [hash] has for search criteria to be used for find object
  def find_search_criteria(template)
    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template

    # TODO: Standards - add split system vs single package to model
    # For now, assume single package
    subcategory = 'Single Package'
    search_criteria['subcategory'] = subcategory

    return search_criteria
  end

  # Finds capacity in Btu/hr
  #
  # @return [Double] capacity in Btu/hr to be used for find object
  def find_capacity
    # Get the coil capacity
    capacity_w = nil
    if ratedTotalHeatingCapacity.is_initialized
      capacity_w = ratedTotalHeatingCapacity.get
    elsif autosizedRatedTotalHeatingCapacity.is_initialized
      capacity_w = autosizedRatedTotalHeatingCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name} capacity is not available, cannot apply efficiency standard.")
      return false
    end

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get

    return capacity_btu_per_hr
  end

  # Finds lookup object in standards and return efficiency
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Double] full load efficiency (COP)
  def standard_minimum_cop(template, standards)
    # find ac properties
    search_criteria = find_search_criteria(template)
    subcategory = search_criteria['subcategory']
    capacity_btu_per_hr = find_capacity
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_btu_per_hr, 'Btu/hr', 'kBtu/hr').get

    # Determine supplemental heating type if unitary
    heat_pump = false
    if airLoopHVAC.empty?
      if containingHVACComponent.is_initialized
        containing_comp = containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          heat_pump = true
        end
      end
    end

    # find object
    ac_props = model.find_object(standards['heat_pumps_heating'], search_criteria, capacity_btu_per_hr)

    # Get the minimum efficiency standards
    cop = nil

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name}, cannot find efficiency info, cannot apply efficiency standard.")
      return cop # value of nil
    end

    # If specified as HSPF
    unless ac_props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = ac_props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_heating_no_fan(min_hspf)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{name}: #{suppl_heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; HSPF = #{min_hspf}")
    end

    # If specified as COPH
    unless ac_props['minimum_coefficient_of_performance_heating'].nil?
      min_coph = ac_props['minimum_coefficient_of_performance_heating']
      cop = cop_heating_to_cop_heating_no_fan(min_coph, OpenStudio.convert(capacity_kbtu_per_hr, 'kBtu/hr', 'W').get)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{name}: #{suppl_heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COPH = #{min_coph}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer, OpenStudio.convert(capacity_kbtu_per_hr, 'kBtu/hr', 'W').get)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{name}:  #{suppl_heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    return cop
  end

  def apply_efficiency_and_curves(template, sql_db_vars_map)
    successfully_set_all_properties = true

    heat_pumps = $os_standards['heat_pumps_heating']

    # Define the criteria to find the unitary properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template

    # TODO: Standards - add split system vs single package to model
    # For now, assume single package
    subcategory = 'Single Package'

    # Assume they are all aircooled for now
    search_criteria['cooling_type'] = 'AirCooled'

    # Determine supplemental heating type if unitary
    heat_pump = false
    suppl_heating_type = nil
    if airLoopHVAC.empty?
      if containingHVACComponent.is_initialized
        containing_comp = containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          heat_pump = true
          htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.supplementalHeatingCoil
          suppl_heating_type = if htg_coil.to_CoilHeatingElectric.is_initialized
                                 'Electric Resistance or None'
                               else
                                 'All Other'
                               end
        end # TODO: Add other unitary systems
      elsif containingZoneHVACComponent.is_initialized
        containing_comp = containingZoneHVACComponent.get
        # PTHP
        if containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          pthp = containing_comp.to_ZoneHVACPackagedTerminalHeatPump.get
          subcategory = 'PTHP'
          htg_coil = containing_comp.to_ZoneHVACPackagedTerminalHeatPump.get.supplementalHeatingCoil
          suppl_heating_type = if htg_coil.to_CoilHeatingElectric.is_initialized
                                 'Electric Resistance or None'
                               else
                                 'All Other'
                               end
        end
      end
    end

    # Add the subcategory to the search criteria
    search_criteria['subcategory'] = subcategory

    # Determine the supplemental heating type if on an airloop
    if airLoopHVAC.is_initialized
      air_loop = airLoopHVAC.get
      suppl_heating_type = if !air_loop.supplyComponents('OS:Coil:Heating:Electric'.to_IddObjectType).empty?
                             'Electric Resistance or None'
                           elsif !air_loop.supplyComponents('OS:Coil:Heating:Gas'.to_IddObjectType).empty?
                             'All Other'
                           elsif !air_loop.supplyComponents('OS:Coil:Heating:Water'.to_IddObjectType).empty?
                             'All Other'
                           elsif !air_loop.supplyComponents('OS:Coil:Heating:DX:SingleSpeed'.to_IddObjectType).empty?
                             'All Other'
                           elsif !air_loop.supplyComponents('OS:Coil:Heating:Gas:MultiStage'.to_IddObjectType).empty?
                             'All Other'
                           elsif !air_loop.supplyComponents('OS:Coil:Heating:Desuperheater'.to_IddObjectType).empty?
                             'All Other'
                           elsif !air_loop.supplyComponents('OS:Coil:Heating:WaterToAirHeatPump:EquationFit'.to_IddObjectType).empty?
                             'All Other'
                           else
                             'Electric Resistance or None'
                           end
    end

    # Add the heating type to the search criteria
    unless suppl_heating_type.nil?
      search_criteria['heating_type'] = suppl_heating_type
    end

    # Get the coil capacity
    capacity_w = nil
    if heat_pump
      containing_comp = containingHVACComponent.get
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
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name} capacity is not available, cannot apply efficiency standard.")
        successfully_set_all_properties = false
        return successfully_set_all_properties
      end
      dxcoil.setName(dxcoil_name)
    else
      if ratedTotalHeatingCapacity.is_initialized
        capacity_w = ratedTotalHeatingCapacity.get
      elsif autosizedRatedTotalHeatingCapacity.is_initialized
        capacity_w = autosizedRatedTotalHeatingCapacity.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name} capacity is not available, cannot apply efficiency standard.")
        successfully_set_all_properties = false
        return successfully_set_all_properties
      end
    end

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies depending on whether it is a unitary HP or a heat pump
    ac_props = nil
    ac_props = model.find_object(heat_pumps, search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name}, cannot find efficiency info, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the HEAT-CAP-FT curve
    heat_cap_ft = model.add_curve(ac_props['heat_cap_ft'])
    if heat_cap_ft
      setTotalHeatingCapacityFunctionofTemperatureCurve(heat_cap_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name}, cannot find heat_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FFLOW curve
    heat_cap_fflow = model.add_curve(ac_props['heat_cap_fflow'])
    if heat_cap_fflow
      setTotalHeatingCapacityFunctionofFlowFractionCurve(heat_cap_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name}, cannot find heat_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FT curve
    heat_eir_ft = model.add_curve(ac_props['heat_eir_ft'])
    if heat_eir_ft
      setEnergyInputRatioFunctionofTemperatureCurve(heat_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name}, cannot find heat_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FFLOW curve
    heat_eir_fflow = model.add_curve(ac_props['heat_eir_fflow'])
    if heat_eir_fflow
      setEnergyInputRatioFunctionofFlowFractionCurve(heat_eir_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name}, cannot find heat_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-PLF-FPLR curve
    heat_plf_fplr = model.add_curve(ac_props['heat_plf_fplr'])
    if heat_plf_fplr
      setPartLoadFractionCorrelationCurve(heat_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name}, cannot find heat_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Get the minimum efficiency standards
    cop = nil

    # If PTHP, use equations
    if subcategory == 'PTHP'
      pthp_cop_coeff_1 = ac_props['pthp_cop_coefficient_1']
      pthp_cop_coeff_2 = ac_props['pthp_cop_coefficient_2']
      # TABLE 6.8.1D
      # COP = pthp_cop_coeff_1 - (pthp_cop_coeff_2 * Cap / 1000)
      # Note c: Cap means the rated cooling capacity of the product in Btu/h.
      # If the unit's capacity is less than 7000 Btu/h, use 7000 Btu/h in the calculation.
      # If the unit's capacity is greater than 15,000 Btu/h, use 15,000 Btu/h in the calculation.
      capacity_btu_per_hr = 7000 if capacity_btu_per_hr < 7000
      capacity_btu_per_hr = 15_000 if capacity_btu_per_hr > 15_000
      cop = pthp_cop_coeff_1 - (pthp_cop_coeff_2 * capacity_btu_per_hr / 1000.0)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{name}: #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COPH = #{cop.round(2)}")
    end

    # If specified as HSPF
    unless ac_props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = ac_props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_heating_no_fan(min_hspf)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{name}: #{suppl_heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; HSPF = #{min_hspf}")
    end

    # If specified as COPH
    unless ac_props['minimum_coefficient_of_performance_heating'].nil?
      min_coph = ac_props['minimum_coefficient_of_performance_heating']
      cop = cop_heating_to_cop_heating_no_fan(min_coph, OpenStudio.convert(capacity_kbtu_per_hr, 'kBtu/hr', 'W').get)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{name}: #{suppl_heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COPH = #{min_coph}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer, OpenStudio.convert(capacity_kbtu_per_hr, 'kBtu/hr', 'W').get)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{name}:  #{suppl_heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Set the efficiency values
    unless cop.nil?
      setRatedCOP(cop)
    end

    return sql_db_vars_map
  end
end

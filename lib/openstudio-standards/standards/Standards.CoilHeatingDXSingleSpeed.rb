class Standard
  # @!group CoilHeatingDXSingleSpeed

  include CoilDX

  # Finds lookup object in standards and return efficiency
  #
  # @param coil_heating_dx_single_speed [OpenStudio::Model::CoilHeatingDXSingleSpeed] coil heating dx single speed object
  # @param rename [Boolean] if true, object will be renamed to include capacity and efficiency level
  # @param necb_ref_hp [Boolean] for compatability with NECB ruleset only.
  # @return [Double] full load efficiency (COP)
  def coil_heating_dx_single_speed_standard_minimum_cop(coil_heating_dx_single_speed, rename = false, necb_ref_hp = false)
    # find ac properties
    search_criteria = coil_dx_find_search_criteria(coil_heating_dx_single_speed, necb_ref_hp)
    sub_category = search_criteria['subcategory']
    suppl_heating_type = search_criteria['heating_type']
    capacity_w = OpenstudioStandards::HVAC.coil_heating_dx_get_paired_coil_cooling_dx_capacity(coil_heating_dx_single_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the minimum efficiency standards
    cop = nil

    # find object
    ac_props = model_find_object(standards_data['heat_pumps_heating'], search_criteria, capacity_btu_per_hr, Date.today)

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      return cop # value of nil
    end

    # If PTHP, use equations
    if sub_category == 'PTHP' && !ac_props['pthp_cop_coefficient_1'].nil? && !ac_props['pthp_cop_coefficient_2'].nil?
      pthp_cop_coeff_1 = ac_props['pthp_cop_coefficient_1']
      pthp_cop_coeff_2 = ac_props['pthp_cop_coefficient_2']
      # TABLE 6.8.1D
      # COP = pthp_cop_coeff_1 - (pthp_cop_coeff_2 * Cap / 1000)
      # Note c: Cap means the rated cooling capacity of the product in Btu/h.

      # If the unit's capacity is nil or less than 7000 Btu/h, use 7000 Btu/h in the calculation
      # If the unit's capacity is greater than 15,000 Btu/h, use 15,000 Btu/h in the calculation
      if capacity_btu_per_hr.nil?
        capacity_btu_per_hr = 7000.0
        capacity_kbtu_per_hr = capacity_btu_per_hr / 1000.0
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For PTHP units, 90.1 heating efficiency depends on paired cooling capacity. Cooling Capacity for #{coil_heating_dx_single_speed.name}: #{sub_category} is nil. This zone may not have heating. Using default equipment efficiency for a 7 kBtu/hr unit.")
      elsif capacity_btu_per_hr < 7000
        capacity_btu_per_hr = 7000.0
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For PTHP units, 90.1 heating efficiency depends on paired cooling capacity. Cooling Capacity for #{coil_heating_dx_single_speed.name}: #{sub_category} is #{capacity_btu_per_hr.round} Btu/hr, which is less than the typical minimum equipment size of 7 kBtu/hr. Using default equipment efficiency for a 7 kBtu/hr unit.")
      elsif capacity_btu_per_hr > 15_000
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For PTHP units, 90.1 heating efficiency depends on paired cooling capacity. Cooling Capacity for #{coil_heating_dx_single_speed.name}: #{sub_category} is #{capacity_btu_per_hr.round} Btu/hr, which is more than the typical maximum equipment size of 15 kBtu/hr. Using default equipment efficiency for a 15 kBtu/hr unit.")
        capacity_btu_per_hr = 15_000.0
      end

      min_coph = pthp_cop_coeff_1 - (pthp_cop_coeff_2 * capacity_btu_per_hr / 1000.0)
      cop = OpenstudioStandards::HVAC.cop_heating_to_cop_heating_no_fan(min_coph, OpenStudio.convert(capacity_btu_per_hr, 'Btu/hr', 'W').get)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round} Clg kBtu/hr #{min_coph.round(1)}COPH"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}: #{sub_category} Cooling Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COPH = #{min_coph.round(2)}")
    end

    # If specified as HSPF
    unless ac_props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = ac_props['minimum_heating_seasonal_performance_factor']
      cop = OpenstudioStandards::HVAC.hspf_to_cop_no_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round} Clg kBtu/hr #{min_hspf.round(1)}HSPF"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}: #{suppl_heating_type} #{sub_category} Cooling Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; HSPF = #{min_hspf}")
    end

    # If specified as COPH
    unless ac_props['minimum_coefficient_of_performance_heating'].nil?
      min_coph = ac_props['minimum_coefficient_of_performance_heating']
      cop = OpenstudioStandards::HVAC.cop_heating_to_cop_heating_no_fan(min_coph, OpenStudio.convert(capacity_kbtu_per_hr, 'kBtu/hr', 'W').get)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round} Clg kBtu/hr #{min_coph.round(1)}COPH"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}: #{suppl_heating_type} #{sub_category} Cooling Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COPH = #{min_coph}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = OpenstudioStandards::HVAC.eer_to_cop_no_fan(min_eer)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round} Clg kBtu/hr #{min_eer.round(1)}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}:  #{suppl_heating_type} #{sub_category} Cooling Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Rename
    if rename
      coil_heating_dx_single_speed.setName(new_comp_name)
    end

    return cop
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @param coil_heating_dx_single_speed [OpenStudio::Model::CoilHeatingDXSingleSpeed] coil heating dx single speed object
  # @param sql_db_vars_map [Hash] hash map
  # @param necb_ref_hp [Boolean] for compatability with NECB ruleset only.
  # @return [Hash] hash of coil objects
  def coil_heating_dx_single_speed_apply_efficiency_and_curves(coil_heating_dx_single_speed, sql_db_vars_map, necb_ref_hp = false)
    successfully_set_all_properties = true

    # Get the search criteria
    search_criteria = coil_dx_find_search_criteria(coil_heating_dx_single_speed, necb_ref_hp)

    # Get the capacity
    capacity_w = OpenstudioStandards::HVAC.coil_heating_dx_get_paired_coil_cooling_dx_capacity(coil_heating_dx_single_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies
    ac_props = model_find_object(standards_data['heat_pumps_heating'], search_criteria, capacity_btu_per_hr, Date.today)

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return sql_db_vars_map
    end

    # Make the HEAT-CAP-FT curve
    heat_cap_ft = model_add_curve(coil_heating_dx_single_speed.model, ac_props['heat_cap_ft'])
    if heat_cap_ft
      coil_heating_dx_single_speed.setTotalHeatingCapacityFunctionofTemperatureCurve(heat_cap_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FFLOW curve
    heat_cap_fflow = model_add_curve(coil_heating_dx_single_speed.model, ac_props['heat_cap_fflow'])
    if heat_cap_fflow
      coil_heating_dx_single_speed.setTotalHeatingCapacityFunctionofFlowFractionCurve(heat_cap_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FT curve
    heat_eir_ft = model_add_curve(coil_heating_dx_single_speed.model, ac_props['heat_eir_ft'])
    if heat_eir_ft
      coil_heating_dx_single_speed.setEnergyInputRatioFunctionofTemperatureCurve(heat_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FFLOW curve
    heat_eir_fflow = model_add_curve(coil_heating_dx_single_speed.model, ac_props['heat_eir_fflow'])
    if heat_eir_fflow
      coil_heating_dx_single_speed.setEnergyInputRatioFunctionofFlowFractionCurve(heat_eir_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-PLF-FPLR curve
    heat_plf_fplr = model_add_curve(coil_heating_dx_single_speed.model, ac_props['heat_plf_fplr'])
    if heat_plf_fplr
      coil_heating_dx_single_speed.setPartLoadFractionCorrelationCurve(heat_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Preserve the original name
    orig_name = coil_heating_dx_single_speed.name.to_s

    # Find the minimum COP and rename with efficiency rating
    cop = coil_heating_dx_single_speed_standard_minimum_cop(coil_heating_dx_single_speed, true, necb_ref_hp)

    # Map the original name to the new name
    sql_db_vars_map[coil_heating_dx_single_speed.name.to_s] = orig_name

    # Set the efficiency values
    unless cop.nil?
      coil_heating_dx_single_speed.setRatedCOP(cop)
    end

    return sql_db_vars_map
  end
end

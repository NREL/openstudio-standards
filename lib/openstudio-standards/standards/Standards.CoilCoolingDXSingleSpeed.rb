class Standard
  # @!group CoilCoolingDXSingleSpeed

  include CoilDX

  # Finds capacity in W
  #
  # @param coil_cooling_dx_single_speed [OpenStudio::Model::CoilCoolingDXSingleSpeed] coil cooling dx single speed object
  # @return [Double] capacity in W to be used for find object
  def coil_cooling_dx_single_speed_find_capacity(coil_cooling_dx_single_speed)
    capacity_w = nil
    if coil_cooling_dx_single_speed.ratedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_single_speed.ratedTotalCoolingCapacity.get
    elsif coil_cooling_dx_single_speed.autosizedRatedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_single_speed.autosizedRatedTotalCoolingCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name} capacity is not available, cannot apply efficiency standard.")
      return 0.0
    end

    # If it's a PTAC or PTHP System, we need to divide the capacity by the potential zone multiplier
    # because the COP is dependent on capacity, and the capacity should be the capacity of a single zone, not all the zones
    if ['PTAC', 'PTHP'].include?(coil_dx_subcategory(coil_cooling_dx_single_speed))
      mult = 1
      comp = coil_cooling_dx_single_speed.containingZoneHVACComponent
      if comp.is_initialized
        if comp.get.thermalZone.is_initialized
          mult = comp.get.thermalZone.get.multiplier
          if mult > 1
            total_cap = capacity_w
            capacity_w /= mult
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, total capacity of #{OpenStudio.convert(total_cap, 'W', 'kBtu/hr').get.round(2)}kBTU/hr was divided by the zone multiplier of #{mult} to give #{capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get.round(2)}kBTU/hr.")
          end
        end
      end
    end

    return capacity_w
  end

  # Finds lookup object in standards and return efficiency
  #
  # @param coil_cooling_dx_single_speed [OpenStudio::Model::CoilCoolingDXSingleSpeed] coil cooling dx single speed object
  # @param rename [Bool] if true, object will be renamed to include capacity and efficiency level
  # @return [Double] full load efficiency (COP)
  def coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed, rename = false)
    search_criteria = coil_dx_find_search_criteria(coil_cooling_dx_single_speed)
    cooling_type = search_criteria['cooling_type']
    heating_type = search_criteria['heating_type']
    sub_category = search_criteria['subcategory']
    capacity_w = coil_cooling_dx_single_speed_find_capacity(coil_cooling_dx_single_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props = nil
    ac_props = if coil_dx_heat_pump?(coil_cooling_dx_single_speed)
                 model_find_object(standards_data['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
               else
                 model_find_object(standards_data['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
               end

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Get the minimum efficiency standards
    cop = nil

    # If PTHP, use equations if coefficients are specified
    pthp_eer_coeff_1 = ac_props['pthp_eer_coefficient_1']
    pthp_eer_coeff_2 = ac_props['pthp_eer_coefficient_2']
    if sub_category == 'PTHP' && !pthp_eer_coeff_1.nil? && !pthp_eer_coeff_2.nil?
      # TABLE 6.8.1D
      # EER = pthp_eer_coeff_1 - (pthp_eer_coeff_2 * Cap / 1000)
      # Note c: Cap means the rated cooling capacity of the product in Btu/h.
      # If the unit's capacity is less than 7000 Btu/h, use 7000 Btu/h in the calculation.
      # If the unit's capacity is greater than 15,000 Btu/h, use 15,000 Btu/h in the calculation.
      eer_calc_cap_btu_per_hr = capacity_btu_per_hr
      eer_calc_cap_btu_per_hr = 7000 if capacity_btu_per_hr < 7000
      eer_calc_cap_btu_per_hr = 15_000 if capacity_btu_per_hr > 15_000
      pthp_eer = pthp_eer_coeff_1 - (pthp_eer_coeff_2 * eer_calc_cap_btu_per_hr / 1000.0)
      cop = eer_to_cop(pthp_eer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{pthp_eer.round(1)}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{pthp_eer.round(1)}")
    end

    # If PTAC, use equations if coefficients are specified
    ptac_eer_coeff_1 = ac_props['ptac_eer_coefficient_1']
    ptac_eer_coeff_2 = ac_props['ptac_eer_coefficient_2']
    if sub_category == 'PTAC' && !ptac_eer_coeff_1.nil? && !ptac_eer_coeff_2.nil?
      # TABLE 6.8.1D
      # EER = ptac_eer_coeff_1 - (ptac_eer_coeff_2 * Cap / 1000)
      # Note c: Cap means the rated cooling capacity of the product in Btu/h.
      # If the unit's capacity is less than 7000 Btu/h, use 7000 Btu/h in the calculation.
      # If the unit's capacity is greater than 15,000 Btu/h, use 15,000 Btu/h in the calculation.
      eer_calc_cap_btu_per_hr = capacity_btu_per_hr
      eer_calc_cap_btu_per_hr = 7000 if capacity_btu_per_hr < 7000
      eer_calc_cap_btu_per_hr = 15_000 if capacity_btu_per_hr > 15_000
      ptac_eer = ptac_eer_coeff_1 - (ptac_eer_coeff_2 * eer_calc_cap_btu_per_hr / 1000.0)
      cop = eer_to_cop(ptac_eer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer.round(1)}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{ptac_eer.round(1)}")
    end

    # If CRAC, use equations if coefficients are specified
    crac_minimum_scop = ac_props['minimum_scop']
    if sub_category == 'CRAC' && !crac_minimum_scop.nil?
      # TABLE 6.8.1K in 90.1-2010, TABLE 6.8.1-10 in 90.1-2019
      # cop = scop/sensible heat ratio
      if coil_cooling_dx_single_speed.ratedSensibleHeatRatio.is_initialized
        crac_sensible_heat_ratio = coil_cooling_dx_single_speed.ratedSensibleHeatRatio.get
      elsif coil_cooling_dx_single_speed.autosizedRatedSensibleHeatRatio.is_initialized
        # Though actual inlet temperature is very high (thus basically no dehumidification),
        # sensible heat ratio can't be pre-assigned as 1 because it should be the value at conditions defined in ASHRAE Standard 127 => 26.7 degC drybulb/19.4 degC wetbulb.
        crac_sensible_heat_ratio = coil_cooling_dx_single_speed.autosizedRatedSensibleHeatRatio.get
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.CoilCoolingDXSingleSpeed', 'Failed to get autosized sensible heat ratio')
      end
      cop = crac_minimum_scop / crac_sensible_heat_ratio
      cop = cop.round(2)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{crac_minimum_scop}SCOP #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SCOP = #{crac_minimum_scop}")
    end

    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{coil_cooling_dx_single_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{coil_cooling_dx_single_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{coil_cooling_dx_single_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{coil_cooling_dx_single_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Rename
    if rename
      coil_cooling_dx_single_speed.setName(new_comp_name)
    end

    return cop
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @param coil_cooling_dx_single_speed [OpenStudio::Model::CoilCoolingDXSingleSpeed] coil cooling dx single speed object
  # @param sql_db_vars_map [Hash] hash map
  # @return [Hash] hash of coil objects
  def coil_cooling_dx_single_speed_apply_efficiency_and_curves(coil_cooling_dx_single_speed, sql_db_vars_map)
    successfully_set_all_properties = true

    # Get the search criteria
    search_criteria = coil_dx_find_search_criteria(coil_cooling_dx_single_speed)

    # Get the capacity
    capacity_w = coil_cooling_dx_single_speed_find_capacity(coil_cooling_dx_single_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props = nil
    ac_props = if coil_dx_heat_pump?(coil_cooling_dx_single_speed)
                 model_find_object(standards_data['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
               else
                 model_find_object(standards_data['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
               end

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return sql_db_vars_map
    end

    # Make the COOL-CAP-FT curve
    cool_cap_ft = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_cap_ft'])
    if cool_cap_ft
      coil_cooling_dx_single_speed.setTotalCoolingCapacityFunctionOfTemperatureCurve(cool_cap_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FFLOW curve
    cool_cap_fflow = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_cap_fflow'])
    if cool_cap_fflow
      coil_cooling_dx_single_speed.setTotalCoolingCapacityFunctionOfFlowFractionCurve(cool_cap_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find cool_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FT curve
    cool_eir_ft = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_eir_ft'])
    if cool_eir_ft
      coil_cooling_dx_single_speed.setEnergyInputRatioFunctionOfTemperatureCurve(cool_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FFLOW curve
    cool_eir_fflow = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_eir_fflow'])
    if cool_eir_fflow
      coil_cooling_dx_single_speed.setEnergyInputRatioFunctionOfFlowFractionCurve(cool_eir_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find cool_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-PLF-FPLR curve
    cool_plf_fplr = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_plf_fplr'])
    if cool_plf_fplr
      coil_cooling_dx_single_speed.setPartLoadFractionCorrelationCurve(cool_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Preserve the original name
    orig_name = coil_cooling_dx_single_speed.name.to_s

    # Find the minimum COP and rename with efficiency rating
    cop = coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed, true)

    # Map the original name to the new name
    sql_db_vars_map[coil_cooling_dx_single_speed.name.to_s] = orig_name

    # Set the efficiency values
    unless cop.nil?
      coil_cooling_dx_single_speed.setRatedCOP(OpenStudio::OptionalDouble.new(cop))
    end

    return sql_db_vars_map
  end
end

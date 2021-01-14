class Standard
  # @!group CoilCoolingDXMultiSpeed

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @return [Bool] true if successful, false if not
  def coil_cooling_dx_multi_speed_apply_efficiency_and_curves(coil_cooling_dx_multi_speed, sql_db_vars_map)
    successfully_set_all_properties = true

    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template
    cooling_type = coil_cooling_dx_multi_speed.condenserType
    search_criteria['cooling_type'] = cooling_type

    # TODO: Standards - add split system vs single package to model
    # For now, assume single package as default
    sub_category = 'Single Package'

    # Determine the heating type if unitary or zone hvac
    heat_pump = false
    heating_type = nil
    containing_comp = nil
    if coil_cooling_dx_multi_speed.airLoopHVAC.empty?
      if coil_cooling_dx_multi_speed.containingHVACComponent.is_initialized
        containing_comp = coil_cooling_dx_multi_speed.containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized
          htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get.heatingCoil
          if htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized
            heat_pump = true
            heating_type = 'Electric Resistance or None'
          elsif htg_coil.to_CoilHeatingGasMultiStage.is_initialized
            heating_type = 'All Other'
          end
          # TODO: Add other unitary systems
        end
      elsif coil_cooling_dx_multi_speed.containingZoneHVACComponent.is_initialized
        containing_comp = coil_cooling_dx_multi_speed.containingZoneHVACComponent.get
        if containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          sub_category = 'PTAC'
          htg_coil = containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.get.heatingCoil
          if htg_coil.to_CoilHeatingElectric.is_initialized
            heating_type = 'Electric Resistance or None'
          elsif htg_coil.to_CoilHeatingWater.is_initialized || htg_coil.to_CoilHeatingGas.is_initialized || htg_col.to_CoilHeatingGasMultiStage
            heating_type = 'All Other'
          end
          # TODO: Add other zone hvac systems
        end
      end
    end

    # Add the heating type to the search criteria
    unless heating_type.nil?
      search_criteria['heating_type'] = heating_type
    end

    search_criteria['subcategory'] = sub_category

    # Get the coil capacity
    capacity_w = nil
    clg_stages = stages
    if clg_stages.last.grossRatedTotalCoolingCapacity.is_initialized
      capacity_w = clg_stages.last.grossRatedTotalCoolingCapacity.get
    elsif coil_cooling_dx_multi_speed.autosizedSpeed4GrossRatedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_multi_speed.autosizedSpeed4GrossRatedTotalCoolingCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Volume flow rate
    flow_rate4 = nil
    if clg_stages.last.ratedAirFlowRate.is_initialized
      flow_rate4 = clg_stages.last.ratedAirFlowRate.get
    elsif coil_cooling_dx_multi_speed.autosizedSpeed4RatedAirFlowRate.is_initialized
      flow_rate4 = coil_cooling_dx_multi_speed.autosizedSpeed4RatedAirFlowRate.get
    end

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props = nil
    ac_props = if heat_pump == true
                 model_find_object(standards_data['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
               else
                 model_find_object(standards_data['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
               end

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the COOL-CAP-FT curve
    cool_cap_ft = model_add_curve(model, ac_props['cool_cap_ft'], standards)
    if cool_cap_ft
      clg_stages.each do |stage|
        stage.setTotalCoolingCapacityFunctionofTemperatureCurve(cool_cap_ft)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FFLOW curve
    cool_cap_fflow = model_add_curve(model, ac_props['cool_cap_fflow'], standards)
    if cool_cap_fflow
      clg_stages.each do |stage|
        stage.setTotalCoolingCapacityFunctionofFlowFractionCurve(cool_cap_fflow)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FT curve
    cool_eir_ft = model_add_curve(model, ac_props['cool_eir_ft'], standards)
    if cool_eir_ft
      clg_stages.each do |stage|
        stage.setEnergyInputRatioFunctionofTemperatureCurve(cool_eir_ft)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FFLOW curve
    cool_eir_fflow = model_add_curve(model, ac_props['cool_eir_fflow'], standards)
    if cool_eir_fflow
      clg_stages.each do |stage|
        stage.setEnergyInputRatioFunctionofFlowFractionCurve(cool_eir_fflow)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-PLF-FPLR curve
    cool_plf_fplr = model_add_curve(model, ac_props['cool_plf_fplr'], standards)
    if cool_plf_fplr
      clg_stages.each do |stage|
        stage.setPartLoadFractionCorrelationCurve(cool_plf_fplr)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Get the minimum efficiency standards
    cop = nil

    if coil_dx_subcategory(coil_cooling_dx_multi_speed) == 'PTAC'
      ptac_eer_coeff_1 = ac_props['ptac_eer_coefficient_1']
      ptac_eer_coeff_2 = ac_props['ptac_eer_coefficient_2']
      capacity_btu_per_hr = 7000 if capacity_btu_per_hr < 7000
      capacity_btu_per_hr = 15_000 if capacity_btu_per_hr > 15_000
      ptac_eer = ptac_eer_coeff_1 + (ptac_eer_coeff_2 * capacity_btu_per_hr)
      cop = eer_to_cop(ptac_eer)
      # self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER")
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{ptac_eer}")
    end

    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    sql_db_vars_map[new_comp_name] = name.to_s
    coil_cooling_dx_multi_speed.setName(new_comp_name)

    # Set the efficiency values

    unless cop.nil?
      clg_stages.each do |istage|
        istage.setGrossRatedCoolingCOP(cop)
      end
    end

    return sql_db_vars_map
  end

  # Finds capacity in W
  #
  # @return [Double] capacity in W to be used for find object
  def coil_cooling_dx_multi_speed_find_capacity(coil_cooling_dx_multi_speed)
    capacity_w = nil
    clg_stages = coil_cooling_dx_multi_speed.stages
    if clg_stages.last.grossRatedTotalCoolingCapacity.is_initialized
      capacity_w = clg_stages.last.grossRatedTotalCoolingCapacity.get
    elsif (clg_stages.size == 1) && coil_cooling_dx_multi_speed.autosizedSpeed1GrossRatedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_multi_speed.autosizedSpeed1GrossRatedTotalCoolingCapacity.get
    elsif (clg_stages.size == 2) && coil_cooling_dx_multi_speed.autosizedSpeed2GrossRatedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_multi_speed.autosizedSpeed2GrossRatedTotalCoolingCapacity.get
    elsif (clg_stages.size == 3) && coil_cooling_dx_multi_speed.autosizedSpeed3GrossRatedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_multi_speed.autosizedSpeed3GrossRatedTotalCoolingCapacity.get
    elsif (clg_stages.size == 4) && coil_cooling_dx_multi_speed.autosizedSpeed4GrossRatedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_multi_speed.autosizedSpeed4GrossRatedTotalCoolingCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    return capacity_w
  end

  # Finds lookup object in standards and return efficiency
  #
  # @param rename [Bool] if true, object will be renamed to include capacity and efficiency level
  # @return [Double] full load efficiency (COP)
  def coil_cooling_dx_multi_speed_standard_minimum_cop(coil_cooling_dx_multi_speed)
    search_criteria = coil_dx_find_search_criteria(coil_cooling_dx_multi_speed)
    cooling_type = search_criteria['cooling_type']
    heating_type = search_criteria['heating_type']
    capacity_w = coil_cooling_dx_multi_speed_find_capacity(coil_cooling_dx_multi_speed)

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props = nil
    ac_props = if coil_dx_heat_pump?(coil_cooling_dx_multi_speed)
                 model_find_object(standards_data['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
               else
                 model_find_object(standards_data['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
               end

    # Get the minimum efficiency standards
    cop = nil

    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{coil_dx_subcategory(coil_cooling_dx_multi_speed)} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{coil_dx_subcategory(coil_cooling_dx_multi_speed)} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{coil_dx_subcategory(coil_cooling_dx_multi_speed)} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{coil_dx_subcategory(coil_cooling_dx_multi_speed)} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    return cop, new_comp_name
  end
end

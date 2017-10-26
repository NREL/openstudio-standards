
class NECB_2011_Model < StandardsModel
  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @return [Bool] true if successful, false if not
  def coil_cooling_dx_multi_speed_apply_efficiency_and_curves(coil_cooling_dx_multi_speed, sql_db_vars_map)
    successfully_set_all_properties = true

    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = instvartemplate
    cooling_type = condenserType
    search_criteria['cooling_type'] = cooling_type

    # TODO: Standards - add split system vs single package to model
    # For now, assume single package as default
    sub_category = 'Single Package'

    # Determine the heating type if unitary or zone hvac
    heat_pump = false
    heating_type = nil
    containing_comp = nil
    if airLoopHVAC.empty?
      if containingHVACComponent.is_initialized
        containing_comp = containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized
          htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get.heatingCoil
          if htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized
            heat_pump = true
            heating_type = 'Electric Resistance or None'
          elsif htg_coil.to_CoilHeatingGasMultiStage.is_initialized
            heating_type = 'All Other'
          end
        end # TODO: Add other unitary systems
      elsif containingZoneHVACComponent.is_initialized
        containing_comp = containingZoneHVACComponent.get
        if containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          sub_category = 'PTAC'
          htg_coil = containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.get.heatingCoil
          if htg_coil.to_CoilHeatingElectric.is_initialized
            heating_type = 'Electric Resistance or None'
          elsif htg_coil.to_CoilHeatingWater.is_initialized || htg_coil.to_CoilHeatingGas.is_initialized || htg_col.to_CoilHeatingGasMultiStage
            heating_type = 'All Other'
          end
        end # TODO: Add other zone hvac systems
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
    elsif autosizedSpeed4GrossRatedTotalCoolingCapacity.is_initialized
      capacity_w = autosizedSpeed4GrossRatedTotalCoolingCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Volume flow rate
    flow_rate4 = nil
    if clg_stages.last.ratedAirFlowRate.is_initialized
      flow_rate4 = clg_stages.last.ratedAirFlowRate.get
    elsif autosizedSpeed4RatedAirFlowRate.is_initialized
      flow_rate4 = autosizedSpeed4RatedAirFlowRate.get
    end

    # Set number of stages
    stage_cap = []
    num_stages = (capacity_w / (66.0 * 1000.0) + 0.5).round
    num_stages = [num_stages, 4].min
    if num_stages == 1
      stage_cap[0] = capacity_w / 2.0
      stage_cap[1] = 2.0 * stage_cap[0]
      stage_cap[2] = stage_cap[1] + 0.1
      stage_cap[3] = stage_cap[2] + 0.1
    else
      stage_cap[0] = 66.0 * 1000.0
      stage_cap[1] = 2.0 * stage_cap[0]
      if num_stages == 2
        stage_cap[2] = stage_cap[1] + 0.1
        stage_cap[3] = stage_cap[2] + 0.1
      elsif num_stages == 3
        stage_cap[2] = 3.0 * stage_cap[0]
        stage_cap[3] = stage_cap[2] + 0.1
      elsif num_stages == 4
        stage_cap[2] = 3.0 * stage_cap[0]
        stage_cap[3] = 4.0 * stage_cap[0]
      end
    end
    # set capacities, flow rates, and sensible heat ratio for stages
    (0..3).each do |istage|
      clg_stages[istage].setGrossRatedTotalCoolingCapacity(stage_cap[istage])
      clg_stages[istage].setRatedAirFlowRate(flow_rate4 * stage_cap[istage] / capacity_w)
    end

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props = nil
    ac_props = if heat_pump == true
                 model_find_object(model, $os_standards['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
               else
                 model_find_object(model, $os_standards['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
               end

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find efficiency info, cannot apply efficiency standard.")
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

    if coil_dx_subcategory(coil_cooling_dx_multi_speed)  == 'PTAC'
      ptac_eer_coeff_1 = ac_props['ptac_eer_coefficient_1']
      ptac_eer_coeff_2 = ac_props['ptac_eer_coefficient_2']
      capacity_btu_per_hr = 7000 if capacity_btu_per_hr < 7000
      capacity_btu_per_hr = 15_000 if capacity_btu_per_hr > 15_000
      ptac_eer = ptac_eer_coeff_1 + (ptac_eer_coeff_2 * capacity_btu_per_hr)
      cop = eer_to_cop(ptac_eer)
      # self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER")
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{ptac_eer}")
    end

    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    sql_db_vars_map[new_comp_name] = name.to_s
    setName(new_comp_name)

    # Set the efficiency values

    unless cop.nil?
      clg_stages.each do |istage|
        istage.setGrossRatedCoolingCOP(cop)
      end
    end

    return sql_db_vars_map
  end
end

class Standard
  # @!group CoilHeatingDXSingleSpeed

  include CoilDX

  # Finds capacity in W.  This is the cooling capacity of the paired DX cooling coil.
  #
  # @param coil_heating_dx_single_speed [OpenStudio::Model::CoilHeatingDXSingleSpeed] coil heating dx single speed object
  # @param necb_ref_hp [Boolean] for compatability with NECB ruleset only.
  # @return [Double] capacity in W to be used for find object
  def coil_heating_dx_single_speed_find_capacity(coil_heating_dx_single_speed, necb_ref_hp = false)
    capacity_w = nil

    # Get the paired cooling coil
    clg_coil = nil

    # Unitary and zone equipment
    if coil_heating_dx_single_speed.airLoopHVAC.empty?
      if coil_heating_dx_single_speed.containingHVACComponent.is_initialized
        containing_comp = coil_heating_dx_single_speed.containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          clg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.coolingCoil
        elsif containing_comp.to_AirLoopHVACUnitarySystem.is_initialized
          unitary = containing_comp.to_AirLoopHVACUnitarySystem.get
          if unitary.coolingCoil.is_initialized
            clg_coil = unitary.coolingCoil.get
          end
        end
        # @todo Add other unitary systems
      elsif coil_heating_dx_single_speed.containingZoneHVACComponent.is_initialized
        containing_comp = coil_heating_dx_single_speed.containingZoneHVACComponent.get
        # PTHP
        if containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          pthp = containing_comp.to_ZoneHVACPackagedTerminalHeatPump.get
          clg_coil = containing_comp.to_ZoneHVACPackagedTerminalHeatPump.get.coolingCoil
        end
      end
    end

    # On AirLoop directly
    if coil_heating_dx_single_speed.airLoopHVAC.is_initialized
      air_loop = coil_heating_dx_single_speed.airLoopHVAC.get
      # Check for the presence of any other type of cooling coil
      clg_types = ['OS:Coil:Cooling:DX:SingleSpeed',
                   'OS:Coil:Cooling:DX:TwoSpeed',
                   'OS:Coil:Cooling:DX:MultiSpeed']
      clg_types.each do |ct|
        coils = air_loop.supplyComponents(ct.to_IddObjectType)
        next if coils.empty?

        clg_coil = coils[0]
        break # Stop on first DX cooling coil found
      end
    end

    # If no paired cooling coil was found,
    # throw an error and fall back to the heating capacity
    # of the DX heating coil
    if clg_coil.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, the paired DX cooling coil could not be found to determine capacity. Efficiency will incorrectly be based on DX coil's heating capacity.")
      if coil_heating_dx_single_speed.ratedTotalHeatingCapacity.is_initialized
        capacity_w = coil_heating_dx_single_speed.ratedTotalHeatingCapacity.get
      elsif coil_heating_dx_single_speed.autosizedRatedTotalHeatingCapacity.is_initialized
        capacity_w = coil_heating_dx_single_speed.autosizedRatedTotalHeatingCapacity.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name} capacity is not available, cannot apply efficiency standard to paired DX heating coil.")
        return 0.0
      end
      return capacity_w
    end

    # If a coil was found, cast to the correct type
    if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
      clg_coil = clg_coil.to_CoilCoolingDXSingleSpeed.get
      capacity_w = coil_cooling_dx_single_speed_find_capacity(clg_coil)
    elsif clg_coil.to_CoilCoolingDXTwoSpeed.is_initialized
      clg_coil = clg_coil.to_CoilCoolingDXTwoSpeed.get
      capacity_w = coil_cooling_dx_two_speed_find_capacity(clg_coil)
    elsif clg_coil.to_CoilCoolingDXMultiSpeed.is_initialized
      clg_coil = clg_coil.to_CoilCoolingDXMultiSpeed.get
      capacity_w = coil_cooling_dx_multi_speed_find_capacity(clg_coil)
    end

    # If it's a PTAC or PTHP System, we need to divide the capacity by the potential zone multiplier
    # because the COP is dependent on capacity, and the capacity should be the capacity of a single zone, not all the zones
    if ['PTAC', 'PTHP'].include?(coil_dx_subcategory(coil_heating_dx_single_speed))
      mult = 1
      comp = coil_heating_dx_single_speed.containingZoneHVACComponent
      if comp.is_initialized && comp.get.thermalZone.is_initialized
        mult = comp.get.thermalZone.get.multiplier
        if mult > 1
          total_cap = capacity_w
          capacity_w /= mult
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, total capacity of #{OpenStudio.convert(total_cap, 'W', 'kBtu/hr').get.round(2)}kBTU/hr was divided by the zone multiplier of #{mult} to give #{capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get.round(2)}kBTU/hr.")
        end
      end
    end

    return capacity_w
  end

  # Finds lookup object in standards and return efficiency
  #
  # @param coil_heating_dx_single_speed [OpenStudio::Model::CoilHeatingDXSingleSpeed] coil heating dx single speed object
  # @param rename [Boolean] if true, object will be renamed to include capacity and efficiency level
  # @param necb_ref_hp [Boolean] for compatability with NECB ruleset only.
  # @return [Double] full load efficiency (COP)
  def coil_heating_dx_single_speed_standard_minimum_cop(coil_heating_dx_single_speed, rename = false, necb_ref_hp = false, equipment_type = false)
    coil_efficiency_data = standards_data['heat_pumps_heating']

    # Get the capacity
    capacity_w = coil_heating_dx_single_speed_find_capacity(coil_heating_dx_single_speed, necb_ref_hp)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the search criteria
    search_criteria = coil_dx_find_search_criteria(coil_heating_dx_single_speed, necb_ref_hp, equipment_type)
    equipment_type = coil_efficiency_data[0].keys.include?('equipment_type') ? true : false

    # Additional search criteria for new data format (from BESD)
    # NECB/BTAP use the old format
    # DEER CBES use the old format
    # 'equipment_type' is only included in data coming from the BESD
    if coil_efficiency_data[0].keys.include?('equipment_type') || ((template == 'NECB2011') || (template == 'NECB2015') || (template == 'NECB2017') || (template == 'NECB2020') || (template == 'BTAPPRE1980') ||
      (template == 'BTAP1980TO2010'))
      if search_criteria.keys.include?('equipment_type')
        equipment_type = search_criteria['equipment_type']
        if equipment_type == 'PTHP'
          search_criteria['application'] = coil_dx_packaged_terminal_application(coil_heating_dx_single_speed)
        end
      elsif !coil_dx_heat_pump?(coil_heating_dx_single_speed) # `coil_dx_heat_pump?` returns false when a DX heating coil is wrapped into a AirloopHVAC:UnitarySystem
        search_criteria['equipment_type'] = 'Heat Pumps'
      end
      unless (template == 'NECB2011') || (template == 'NECB2015') || (template == 'NECB2017') || (template == 'NECB2020') || (template == 'BTAPPRE1980') ||
             (template == 'BTAP1980TO2010')
        # Single Package/Split System is only used for units less than 65 kBtu/h
        if capacity_btu_per_hr >= 65000 && equipment_type != 'PTHP'
          search_criteria['rating_condition'] = '47F db/43F wb outdoor air'
          search_criteria['subcategory'] = nil
        else
          electric_power_phase = coil_dx_electric_power_phase(coil_heating_dx_single_speed)
          if !electric_power_phase.nil?
            search_criteria['electric_power_phase'] = electric_power_phase
          end
        end
      end
    end

    sub_category = search_criteria['subcategory']
    suppl_heating_type = search_criteria['heating_type']

    # find object
    hp_props = model_find_object(coil_efficiency_data, search_criteria, capacity_btu_per_hr, Date.today)

    # Check to make sure properties were found
    if hp_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      return false
    end

    cop = nil
    # If PTHP, use equations
    if equipment_type == 'PTHP' && !hp_props['pthp_cop_coefficient_1'].nil? && !hp_props['pthp_cop_coefficient_2'].nil?
      pthp_cop_coeff_1 = hp_props['pthp_cop_coefficient_1']
      pthp_cop_coeff_2 = hp_props['pthp_cop_coefficient_2']
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
      cop = cop_heating_to_cop_heating_no_fan(min_coph, OpenStudio.convert(capacity_btu_per_hr, 'Btu/hr', 'W').get)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round} Clg kBtu/hr #{min_coph.round(1)}COPH"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}: #{sub_category} Cooling Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COPH = #{min_coph.round(2)}")
    end

    # If specified as HSPF
    unless hp_props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = hp_props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_no_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round} Clg kBtu/hr #{min_hspf.round(1)}HSPF"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}: #{suppl_heating_type} #{sub_category} Cooling Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; HSPF = #{min_hspf}")
    end

    # If specified as HSPF2
    # TODO: assumed to be the same as HSPF for now
    unless hp_props['minimum_heating_seasonal_performance_factor_2'].nil?
      min_hspf = hp_props['minimum_heating_seasonal_performance_factor_2']
      cop = hspf_to_cop_no_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round} Clg kBtu/hr #{min_hspf.round(1)}HSPF2"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}: #{suppl_heating_type} #{sub_category} Cooling Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; HSPF = #{min_hspf}")
    end

    # If specified as COPH
    unless hp_props['minimum_coefficient_of_performance_heating'].nil?
      min_coph = hp_props['minimum_coefficient_of_performance_heating']
      cop = cop_heating_to_cop_heating_no_fan(min_coph, OpenStudio.convert(capacity_kbtu_per_hr, 'kBtu/hr', 'W').get)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round} Clg kBtu/hr #{min_coph.round(1)}COPH"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}: #{suppl_heating_type} #{sub_category} Cooling Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COPH = #{min_coph}")
    end

    # If specified as EER
    unless hp_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = hp_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop_no_fan(min_eer)
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
    # Get the search criteria
    search_criteria = coil_dx_find_search_criteria(coil_heating_dx_single_speed, necb_ref_hp)
    sub_category = search_criteria['subcategory']
    suppl_heating_type = search_criteria['heating_type']
    coil_efficiency_data = standards_data['heat_pumps_heating']
    equipment_type = coil_efficiency_data[0].keys.include?('equipment_type') ? true : false

    # Get the capacity
    capacity_w = coil_heating_dx_single_speed_find_capacity(coil_heating_dx_single_speed, necb_ref_hp)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Additional search criteria
    if coil_efficiency_data[0].keys.include?('equipment_type') || ((template == 'NECB2011') || (template == 'NECB2015') || (template == 'NECB2017') || (template == 'NECB2020') || (template == 'BTAPPRE1980') ||
      (template == 'BTAP1980TO2010'))
      if search_criteria.keys.include?('equipment_type')
        equipment_type = search_criteria['equipment_type']
        if ['PTHP'].include?(equipment_type)
          search_criteria['application'] = coil_dx_packaged_terminal_application(coil_heating_dx_single_speed)
        end
      elsif !coil_dx_heat_pump?(coil_heating_dx_single_speed) # `coil_dx_heat_pump?` returns false when a DX heating coil is wrapped into a AirloopHVAC:UnitarySystem
        search_criteria['equipment_type'] = 'Heat Pumps'
      end
      unless (template == 'NECB2011') || (template == 'NECB2015') || (template == 'NECB2017') || (template == 'NECB2020') || (template == 'BTAPPRE1980') ||
             (template == 'BTAP1980TO2010')
        # Single Package/Split System is only used for units less than 65 kBtu/h
        if capacity_btu_per_hr >= 65000
          search_criteria['rating_condition'] = '47F db/43F wb outdoor air'
          search_criteria['subcategory'] = nil
        else
          electric_power_phase = coil_dx_electric_power_phase(coil_heating_dx_single_speed)
          if !electric_power_phase.nil?
            search_criteria['electric_power_phase'] = electric_power_phase
          end
        end
      end
    end
    if coil_efficiency_data[0].keys.include?('region')
      search_criteria['region'] = nil # non-nil values are currently used for residential products
    end

    # Lookup efficiencies
    hp_props = model_find_object(standards_data['heat_pumps_heating'], search_criteria, capacity_btu_per_hr, Date.today)

    # Check to make sure properties were found
    if hp_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      return false
    end

    equipment_type_field = search_criteria['equipment_type']
    # Make the HEAT-CAP-FT curve
    heat_cap_ft = nil
    if hp_props['heat_cap_ft']
      heat_cap_ft = model_add_curve(coil_heating_dx_single_speed.model, hp_props['heat_cap_ft'])
    else
      heat_cap_ft_curve_name = coil_dx_cap_ft(coil_heating_dx_single_speed, equipment_type_field, heating = true)
      heat_cap_ft = model_add_curve(coil_heating_dx_single_speed.model, heat_cap_ft_curve_name)
    end
    if heat_cap_ft
      coil_heating_dx_single_speed.setTotalHeatingCapacityFunctionofTemperatureCurve(heat_cap_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_cap_ft curve, will not be set.")
    end

    # Make the HEAT-CAP-FFLOW curve
    heat_cap_fflow = nil
    if hp_props['heat_cap_fflow']
      heat_cap_fflow = model_add_curve(coil_heating_dx_single_speed.model, hp_props['heat_cap_fflow'])
    else
      heat_cap_fflow_curve_name = coil_dx_cap_fflow(coil_heating_dx_single_speed, equipment_type_field, heating = true)
      heat_cap_fflow = model_add_curve(coil_heating_dx_single_speed.model, heat_cap_fflow_curve_name)
    end
    if heat_cap_fflow
      coil_heating_dx_single_speed.setTotalHeatingCapacityFunctionofFlowFractionCurve(heat_cap_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_cap_fflow curve, will not be set.")
    end

    # Make the HEAT-EIR-FT curve
    heat_eir_ft = nil
    if hp_props['heat_eir_ft']
      heat_eir_ft = model_add_curve(coil_heating_dx_single_speed.model, hp_props['heat_eir_ft'])
    else
      heat_eir_ft_curve_name = coil_dx_eir_ft(coil_heating_dx_single_speed, equipment_type_field, heating = true)
      heat_eir_ft = model_add_curve(coil_heating_dx_single_speed.model, heat_eir_ft_curve_name)
    end
    if heat_eir_ft
      coil_heating_dx_single_speed.setEnergyInputRatioFunctionofTemperatureCurve(heat_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_eir_ft curve, will not be set.")
    end

    # Make the HEAT-EIR-FFLOW curve
    heat_eir_fflow = nil
    if hp_props['heat_eir_fflow']
      heat_eir_fflow = model_add_curve(coil_heating_dx_single_speed.model, hp_props['heat_eir_fflow'])
    else
      heat_eir_fflow_curve_name = coil_dx_eir_fflow(coil_heating_dx_single_speed, equipment_type_field, heating = true)
      heat_eir_fflow = model_add_curve(coil_heating_dx_single_speed.model, heat_eir_fflow_curve_name)
    end
    if heat_eir_fflow
      coil_heating_dx_single_speed.setEnergyInputRatioFunctionofFlowFractionCurve(heat_eir_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_eir_fflow curve, will not be set.")
    end

    # Make the HEAT-PLF-FPLR curve
    heat_plf_fplr = nil
    if hp_props['heat_plf_fplr']
      heat_plf_fplr = model_add_curve(coil_heating_dx_single_speed.model, hp_props['heat_plf_fplr'])
    else
      heat_plf_fplr_curve_name = coil_dx_plf_fplr(coil_heating_dx_single_speed, equipment_type_field, heating = true)
      heat_plf_fplr = model_add_curve(coil_heating_dx_single_speed.model, heat_plf_fplr_curve_name)
    end
    if heat_plf_fplr
      coil_heating_dx_single_speed.setPartLoadFractionCorrelationCurve(heat_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_plf_fplr curve, will not be set.")
    end

    # Preserve the original name
    orig_name = coil_heating_dx_single_speed.name.to_s

    # Find the minimum COP and rename with efficiency rating
    cop = coil_heating_dx_single_speed_standard_minimum_cop(coil_heating_dx_single_speed, true, necb_ref_hp, equipment_type)

    # Map the original name to the new name
    sql_db_vars_map[coil_heating_dx_single_speed.name.to_s] = orig_name

    # Set the efficiency values
    unless cop.nil?
      coil_heating_dx_single_speed.setRatedCOP(cop)
    end

    return sql_db_vars_map
  end
end

class ASHRAE901PRM < Standard
  # @!group AirLoopHVAC

  # Determine if the system is a multizone VAV system
  #
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_multizone_vav_system?(air_loop_hvac)
    return true if air_loop_hvac.name.to_s.include?('Sys5') || air_loop_hvac.name.to_s.include?('Sys6') || air_loop_hvac.name.to_s.include?('Sys7') || air_loop_hvac.name.to_s.include?('Sys8')

    return false
  end

  # Default occupancy fraction threshold for determining if the spaces on the air loop are occupied
  def air_loop_hvac_unoccupied_threshold
    return 0.05
  end

  # Determine the economizer type and limits for the the PRM
  # Defaults to 90.1-2007 logic.
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Array<Double>] [economizer_type, drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  def air_loop_hvac_prm_economizer_type_and_limits(air_loop_hvac, climate_zone)
    economizer_type = 'NoEconomizer'
    drybulb_limit_f = nil
    enthalpy_limit_btu_per_lb = nil
    dewpoint_limit_f = nil
    climate_zone_code = climate_zone.split('-')[-1]

    if ['0B', '1B', '2B', '3B', '3C', '4B', '4C', '5B', '5C', '6B', '7A', '7B', '8A', '8B'].include? climate_zone_code
      economizer_type = 'FixedDryBulb'
      drybulb_limit_f = 75
    elsif ['5A', '6A'].include? climate_zone_code
      economizer_type = 'FixedDryBulb'
      drybulb_limit_f = 70
    end

    return [economizer_type, drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  end

  # Determine if an economizer is required per the PRM.
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Bool] returns true if required, false if not
  def air_loop_hvac_prm_baseline_economizer_required?(air_loop_hvac, climate_zone)
    economizer_required = false
    baseline_system_type = air_loop_hvac.additionalProperties.getFeatureAsString('baseline_system_type').get
    climate_zone_code = climate_zone.split('-')[-1]
    # System type 3 through 8 and 11, 12 and 13
    if ['SZ_AC', 'PSZ_AC', 'PVAV_Reheat', 'VAV_Reheat', 'SZ_VAV', 'PSZ_HP', 'SZ_CV', 'PSZ_HP', 'PVAV_PFP_Boxes', 'VAV_PFP_Boxes'].include? baseline_system_type
      unless ['0A', '0B', '1A', '1B', '2A', '3A', '4A'].include? climate_zone_code
        economizer_required = true
      end
    end

    # System type 3 and 4 in computer rooms are subject to exceptions
    if baseline_system_type == 'PSZ_AC' || baseline_system_type == 'PSZ_HP'
      if air_loop_hvac.additionalProperties.hasFeature('zone_group_type')
        if air_loop_hvac.additionalProperties.getFeatureAsString('zone_group_type').get == 'computer_zones'
          economizer_required = false
        end
      end
    end

    # Check user_data in the zones
    gas_phase_exception = false
    open_refrigeration_exception = false
    air_loop_hvac.thermalZones.each do |thermal_zone|
      if thermal_zone.additionalProperties.hasFeature('economizer_exception_for_gas_phase_air_cleaning')
        gas_phase_exception = true
      end
      if thermal_zone.additionalProperties.hasFeature('economizer_exception_for_open_refrigerated_cases')
        open_refrigeration_exception = true
      end
    end
    if gas_phase_exception || open_refrigeration_exception
      economizer_required = false
    end
    return economizer_required
  end

  # Calculate and apply the performance rating method
  # baseline fan power to this air loop based on the
  # system type that it represents.
  #
  # Fan motor efficiency will be set, and then
  # fan pressure rise adjusted so that the
  # fan power is the maximum allowable.
  #
  # Also adjusts the fan power and flow rates
  # of any parallel PIU terminals on the system.
  #
  # return [Bool] true if successful, false if not.
  def air_loop_hvac_apply_prm_baseline_fan_power(air_loop_hvac)
    # Get system type associated with air loop
    system_type = air_loop_hvac.additionalProperties.getFeatureAsString('baseline_system_type').get

    # Find out if air loop represents a non mechanically cooled system
    is_nmc = false
    is_nmc = true if air_loop_hvac.additionalProperties.hasFeature('non_mechanically_cooled')

    # Get all air loop fans
    all_fans = air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac)

    allowable_fan_bhp = 0.0
    allowable_power_w = 0.0
    fan_efficacy_w_per_cfm = 0.0
    supply_fan_power_fraction = 0.0
    return_fan_power_fraction = 0.0
    relief_fan_power_fraction = 0.0
    if system_type == 'PSZ_AC' ||
       system_type == 'PSZ_HP' ||
       system_type == 'PVAV_Reheat' ||
       system_type == 'PVAV_PFP_Boxes' ||
       system_type == 'VAV_Reheat' ||
       system_type == 'VAV_PFP_Boxes' ||
       system_type == 'SZ_VAV' ||
       system_type == 'SZ_CV'

      # Calculate the allowable fan motor bhp for the air loop
      allowable_fan_bhp = air_loop_hvac_allowable_system_brake_horsepower(air_loop_hvac)

      # Divide the allowable power based
      # individual zone air flow
      air_loop_total_zone_design_airflow = 0
      air_loop_hvac.thermalZones.sort.each do |zone|
        zone_air_flow = zone.designAirFlowRate.to_f
        air_loop_total_zone_design_airflow += zone_air_flow
        # Fractions variables are actually power at that point
        supply_fan_power_fraction += zone_air_flow * zone.additionalProperties.getFeatureAsDouble('supply_fan_w').get
        return_fan_power_fraction += zone_air_flow * zone.additionalProperties.getFeatureAsDouble('return_fan_w').get
        relief_fan_power_fraction += zone_air_flow * zone.additionalProperties.getFeatureAsDouble('relief_fan_w').get
      end
      if air_loop_total_zone_design_airflow > 0
        # Get average power for each category of fan
        supply_fan_power_fraction /= air_loop_total_zone_design_airflow
        return_fan_power_fraction /= air_loop_total_zone_design_airflow
        relief_fan_power_fraction /= air_loop_total_zone_design_airflow
        # Convert to power fraction
        total_fan_avg_fan_w = (supply_fan_power_fraction + return_fan_power_fraction + relief_fan_power_fraction)
        supply_fan_power_fraction /= total_fan_avg_fan_w
        return_fan_power_fraction /= total_fan_avg_fan_w
        relief_fan_power_fraction /= total_fan_avg_fan_w
      else
        Openstudio.logFree(OpenStudio::Error, "Total zone design airflow for #{air_loop_hvac.name} is 0.")
      end
    elsif system_type == 'PTAC' ||
          system_type == 'PTHP' ||
          system_type == 'Gas_Furnace' ||
          system_type == 'Electric_Furnace'

      # Determine allowable fan power
      if !is_nmc
        fan_efficacy_w_per_cfm = 0.3
      else # is_nmc
        fan_efficacy_w_per_cfm = 0.054
      end

      # Configuration is supply fan only
      supply_fan_power_fraction = 1.0
    end

    supply_fan = air_loop_hvac_get_supply_fan(air_loop_hvac)
    if supply_fan.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.AirLoopHVAC', "Supply not found on #{airloop.name}.")
    end
    supply_fan_max_flow = if supply_fan.autosizedMaximumFlowRate.is_initialized
                            supply_fan.autosizedMaximumFlowRate.get
                          else
                            supply_fan.maximumFlowRate.get
                          end

    # Check that baseline system has the same
    # types of fans as the proposed model, if
    # not, create them. We assume that the
    # system has at least a supply fan.
    if return_fan_power_fraction > 0.0 && !air_loop_hvac.returnFan.is_initialized
      # Create return fan
      return_fan = supply_fan.clone(air_loop_hvac.model)
      if return_fan.to_FanConstantVolume.is_initialized
        return_fan = return_fan.to_FanConstantVolume.get
      elsif return_fan.to_FanVariableVolume.is_initialized
        return_fan = return_fan.to_FanVariableVolume.get
      elsif return_fan.to_FanOnOff.is_initialized
        return_fan = return_fan.to_FanOnOff.get
      elsif return_fan.to_FanSystemModel.is_initialized
        return_fan = return_fan.to_FanSystemModel.get
      end
      return_fan.setName("#{air_loop_hvac.name} Return Fan")
      return_fan.addToNode(air_loop_hvac.returnAirNode.get)
      return_fan.setMaximumFlowRate(supply_fan_max_flow)
    end
    if relief_fan_power_fraction > 0.0 && !air_loop_hvac.reliefFan.is_initialized
      # Create return fan
      relief_fan = supply_fan.clone(air_loop_hvac.model)
      if relief_fan.to_FanConstantVolume.is_initialized
        relief_fan = relief_fan.to_FanConstantVolume.get
      elsif relief_fan.to_FanVariableVolume.is_initialized
        relief_fan = relief_fan.to_FanVariableVolume.get
      elsif relief_fan.to_FanOnOff.is_initialized
        relief_fan = relief_fan.to_FanOnOff.get
      elsif relief_fan.to_FanSystemModel.is_initialized
        relief_fan = relief_fan.to_FanSystemModel.get
      end
      relief_fan.setName("#{air_loop_hvac.name} Relief Fan")
      relief_fan.addToNode(air_loop_hvac.reliefAirNode.get)
      relief_fan.setMaximumFlowRate(supply_fan_max_flow)
    end

    # Get all air loop fans
    all_fans = air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac)

    # Set the motor efficiencies
    # for all fans based on the calculated
    # allowed brake hp.  Then calculate the allowable
    # fan power for each fan and adjust
    # the fan pressure rise accordingly
    all_fans.each do |fan|
      # Efficacy requirement
      if fan_efficacy_w_per_cfm > 0
        # Convert efficacy to metric
        fan_efficacy_w_per_m3_per_s = OpenStudio.convert(fan_efficacy_w_per_cfm, 'm^3/s', 'cfm').get
        fan_change_impeller_efficiency(fan, fan_baseline_impeller_efficiency(fan))

        # Get fan BHP
        fan_bhp = fan_brake_horsepower(fan)

        # Set the motor efficiency, preserving the impeller efficiency.
        # For zone HVAC fans, a bhp lookup of 0.5bhp is always used because
        # they are assumed to represent a series of small fans in reality.
        fan_apply_standard_minimum_motor_efficiency(fan, fan_bhp)

        # Calculate a new pressure rise to hit the target W/cfm
        fan_tot_eff = fan.fanEfficiency
        fan_rise_new_pa = fan_efficacy_w_per_m3_per_s * fan_tot_eff
        fan.setPressureRise(fan_rise_new_pa)
      end

      # BHP requirements
      if allowable_fan_bhp > 0
        fan_apply_standard_minimum_motor_efficiency(fan, allowable_fan_bhp)
        allowable_power_w = allowable_fan_bhp * 746 / fan.motorEfficiency

        # Breakdown fan power based on fan type
        if supply_fan.name.to_s == fan.name.to_s
          allowable_power_w *= supply_fan_power_fraction
        elsif fan.airLoopHVAC.is_initialized
          if fan.airLoopHVAC.get.returnFan.is_initialized
            if fan.airLoopHVAC.get.returnFan.get.name.to_s == fan.name.to_s
              allowable_power_w *= return_fan_power_fraction
            end
          end
          if fan.airLoopHVAC.get.reliefFan.is_initialized
            if fan.airLoopHVAC.get.reliefFan.get.name.to_s == fan.name.to_s
              allowable_power_w *= relief_fan_power_fraction
            end
          end
        end
        fan_adjust_pressure_rise_to_meet_fan_power(fan, allowable_power_w)
      end
    end

    return true unless system_type == 'PVAV_PFP_Boxes' || system_type == 'VAV_PFP_Boxes'

    # Adjust fan powered terminal fans power
    air_loop_hvac.demandComponents.each do |dc|
      next if dc.to_AirTerminalSingleDuctParallelPIUReheat.empty?

      pfp_term = dc.to_AirTerminalSingleDuctParallelPIUReheat.get
      air_terminal_single_duct_parallel_piu_reheat_apply_prm_baseline_fan_power(pfp_term)
    end

    return true
  end

  # Determine the allowable fan system brake horsepower
  # Per Section G3.1.2.9
  #
  # @return [Double] allowable fan system brake horsepower
  #   units = horsepower
  def air_loop_hvac_allowable_system_brake_horsepower(air_loop_hvac)
    # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = 0
    dsn_air_flow_cfm = 0
    if air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_air_flow_m3_per_s = air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.ashrae_90_1_prm.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
    else
      dsn_air_flow_m3_per_s = air_loop_hvac.designSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.ashrae_90_1_prm.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = Hard sized Design Supply Air Flow Rate.")
    end

    # Get the fan limitation pressure drop adjustment bhp
    fan_pwr_adjustment_bhp = air_loop_hvac_fan_power_limitation_pressure_drop_adjustment_brake_horsepower(air_loop_hvac)

    # Get system type associated with air loop
    system_type = air_loop_hvac.additionalProperties.getFeatureAsString('baseline_system_type').get

    # Calculate the Allowable Fan System brake horsepower per Table G3.1.2.9
    allowable_fan_bhp = 0.0
    case system_type
      when 'PSZ_HP', 'PSZ_AC' # 3, 4
        allowable_fan_bhp = dsn_air_flow_cfm * 0.00094 + fan_pwr_adjustment_bhp
      when
           'PVAV_Reheat', 'PVAV_PFP_Boxes', # 5, 6
           'VAV_Reheat', 'VAV_PFP_Boxes', # 7, 8
           'SZ_VAV' # 11
        allowable_fan_bhp = dsn_air_flow_cfm * 0.0013 + fan_pwr_adjustment_bhp
      when
           'SZ_CV' # 12, 13
        allowable_fan_bhp = dsn_air_flow_cfm * 0.00094 + fan_pwr_adjustment_bhp
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.AirLoopHVAC', "Air loop #{air_loop_hvac.name} is not associated with a baseline system.")
    end

    return allowable_fan_bhp
  end

  # Set the minimum VAV damper positions.
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @param has_ddc [Bool] if true, will assume that there is DDC control of vav terminals.
  #   If false, assumes otherwise.
  # @return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_minimum_vav_damper_positions(air_loop_hvac, has_ddc = true)
    air_loop_hvac.thermalZones.each do |zone|
      zone.equipment.each do |equip|
        if equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
          zone_oa = thermal_zone_outdoor_airflow_rate(zone)
          vav_terminal = equip.to_AirTerminalSingleDuctVAVReheat.get
          air_terminal_single_duct_vav_reheat_apply_minimum_damper_position(vav_terminal, zone_oa, has_ddc)
        elsif equip.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized
          zone_oa = thermal_zone_outdoor_airflow_rate(zone)
          fp_vav_terminal = equip.to_AirTerminalSingleDuctParallelPIUReheat.get
          air_terminal_single_duct_parallel_piu_reheat_apply_minimum_primary_airflow_fraction(fp_vav_terminal, zone_oa)
        end
      end
    end

    return true
  end

  # Determine the fan power limitation pressure drop adjustment
  # Per Table 6.5.3.1-2 (90.1-2019)
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @return [Double] fan power limitation pressure drop adjustment, in units of horsepower
  def air_loop_hvac_fan_power_limitation_pressure_drop_adjustment_brake_horsepower(air_loop_hvac)
    # Calculate Fan Power Limitation Pressure Drop Adjustment
    fan_pwr_adjustment_bhp = 0

    # Retrieve climate zone
    climate_zone = air_loop_hvac.model.getClimateZones.getClimateZone(0)

    # Check if energy recovery is required
    is_energy_recovery_required = air_loop_hvac_energy_recovery_ventilator_required?(air_loop_hvac, climate_zone)

    system_type = ''
    # Get baseline system type if applicable
    if air_loop_hvac.additionalProperties.hasFeature('baseline_system_type')
      system_type = air_loop_hvac.additionalProperties.getFeatureAsString('baseline_system_type').to_s
    end

    air_loop_hvac.thermalZones.each do |zone|
      # Take fan power deductions into account;
      # Deductions are calculated based on the
      # baseline model design.
      # The only deduction that's applicable
      # is the "System with central electric
      # resistance heat" for system 6 and 8
      if system_type == 'PVAV_PFP_Boxes' || system_type == 'VAV_PFP_Boxes'
        if zone.additionalProperties.hasFeature('has_fan_power_deduction_system_with_central_electric_resistance_heat')
          current_value = zone.additionalProperties.getFeatureAsDouble('has_fan_power_deduction_system_with_central_electric_resistance_heat')
          zone.additionalProperties.setFeature('has_fan_power_deduction_system_with_central_electric_resistance_heat', current_value + 1.0)
        else
          zone.additionalProperties.setFeature('has_fan_power_deduction_system_with_central_electric_resistance_heat', 1.0)
        end
      end

      # Determine fan power adjustment
      fan_pwr_adjustment_bhp += thermal_zone_get_fan_power_limitations(zone, is_energy_recovery_required)
    end

    return fan_pwr_adjustment_bhp
  end
end

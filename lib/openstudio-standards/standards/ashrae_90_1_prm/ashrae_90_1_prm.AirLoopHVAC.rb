class ASHRAE901PRM < Standard
  # @!group AirLoopHVAC

  # Determine if the system is a multizone VAV system
  #
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_multizone_vav_system?(air_loop_hvac)
    return true if air_loop_hvac.name.to_s.include?('Sys5') || air_loop_hvac.name.to_s.include?('Sys6') || air_loop_hvac.name.to_s.include?('Sys7') || air_loop_hvac.name.to_s.include?('Sys8')

    return false
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
    if system_type == 'PSZ_AC' ||
       system_type == 'PSZ_HP' ||
       system_type == 'PVAV_Reheat'
      system_type == 'PVAV_PFP_Boxes' ||
        system_type == 'VAV_Reheat' ||
        system_type == 'VAV_PFP_Boxes' ||
        system_type == 'SZ_VAV' ||
        system_type == 'SZ_CAV'

      # Calculate the allowable fan motor bhp for the air loop
      allowable_fan_bhp = air_loop_hvac_allowable_system_brake_horsepower(air_loop_hvac)

      # Divide the allowable power evenly between the fans
      # on this air loop.
      # TODO: same proportions as proposed ?
      allowable_fan_bhp /= all_fans.size
    elsif system_type == 'PTAC' ||
          system_type == 'PTHP' ||
          (system_type == 'Gas_Furnace' && !is_nmc) ||
          (system_type == 'Electric_Furnace' && !is_nmc)
      # Determine allowable fan power
      allowable_power_w = 0.3
    elsif (system_type == 'Gas_Furnace' && is_nmc) ||
          (system_type == 'Electric_Furnace' && is_nmc)
      # Determine allowable fan power
      allowable_power_w = 0.054
    end

    # Set the motor efficiencies
    # for all fans based on the calculated
    # allowed brake hp.  Then calculate the allowable
    # fan power for each fan and adjust
    # the fan pressure rise accordingly
    all_fans.each do |fan|
      if allowable_fan_bhp > 0
        fan_apply_standard_minimum_motor_efficiency(fan, allowable_fan_bhp)
        allowable_power_w = allowable_fan_bhp * 746 / fan.motorEfficiency
      end
      fan_adjust_pressure_rise_to_meet_fan_power(fan, allowable_power_w)
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
      puts air_loop_hvac.is_initialized
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
           'SZ_CAV' # 12, 13
        allowable_fan_bhp = dsn_air_flow_cfm * 0.00094 + fan_pwr_adjustment_bhp
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.AirLoopHVAC', "Air loop #{air_loop_hvac.name} is not associated with a baseline system.")
    end

    return allowable_fan_bhp
  end
end

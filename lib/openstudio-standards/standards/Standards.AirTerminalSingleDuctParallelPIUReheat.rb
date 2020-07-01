class Standard
  # @!group AirTerminalSingleDuctParallelPIUReheat

  # Sets the fan power of a PIU fan based on the W/cfm
  # specified in the standard.
  #
  # @return [Bool] returns true if successful, false if not
  def air_terminal_single_duct_parallel_piu_reheat_apply_prm_baseline_fan_power(air_terminal_single_duct_parallel_piu_reheat)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirTerminalSingleDuctParallelPIUReheat', "Setting PIU fan power for #{air_terminal_single_duct_parallel_piu_reheat.name}.")

    # Determine the fan sizing flow rate, min flow rate,
    # and W/cfm
    sec_flow_frac = 0.5
    min_flow_frac = 0.3
    fan_efficacy_w_per_cfm = 0.35

    # Convert efficacy to metric
    # 1 cfm = 0.0004719 m^3/s
    fan_efficacy_w_per_m3_per_s = fan_efficacy_w_per_cfm / 0.0004719

    # Get the maximum flow rate through the terminal
    max_primary_air_flow_rate = nil
    if air_terminal_single_duct_parallel_piu_reheat.autosizedMaximumPrimaryAirFlowRate.is_initialized
      max_primary_air_flow_rate = air_terminal_single_duct_parallel_piu_reheat.autosizedMaximumPrimaryAirFlowRate.get
    elsif air_terminal_single_duct_parallel_piu_reheat.maximumPrimaryAirFlowRate.is_initialized
      max_primary_air_flow_rate = air_terminal_single_duct_parallel_piu_reheat.maximumPrimaryAirFlowRate.get
    end

    # Set the max secondary air flow rate
    max_sec_flow_rate_m3_per_s = max_primary_air_flow_rate * sec_flow_frac
    air_terminal_single_duct_parallel_piu_reheat.setMaximumSecondaryAirFlowRate(max_sec_flow_rate_m3_per_s)
    max_sec_flow_rate_cfm = OpenStudio.convert(max_sec_flow_rate_m3_per_s, 'm^3/s', 'ft^3/min').get

    # Set the minimum flow fraction
    # TODO Also compare to min OA requirement
    air_terminal_single_duct_parallel_piu_reheat.setMinimumPrimaryAirFlowFraction(min_flow_frac)

    # Get the fan
    fan = air_terminal_single_duct_parallel_piu_reheat.fan.to_FanConstantVolume.get

    # Set the impeller efficiency
    fan_change_impeller_efficiency(fan, fan_baseline_impeller_efficiency(fan))

    # Set the motor efficiency, preserving the impeller efficency.
    # For terminal fans, a bhp lookup of 0.5bhp is always used because
    # they are assumed to represent a series of small fans in reality.
    fan_apply_standard_minimum_motor_efficiency(fan, fan_brake_horsepower(fan))

    # Calculate a new pressure rise to hit the target W/cfm
    fan_tot_eff = fan.fanEfficiency
    fan_rise_new_pa = fan_efficacy_w_per_m3_per_s * fan_tot_eff
    fan.setPressureRise(fan_rise_new_pa)

    # Calculate the newly set efficacy
    fan_power_new_w = fan_rise_new_pa * max_sec_flow_rate_m3_per_s / fan_tot_eff
    fan_efficacy_new_w_per_cfm = fan_power_new_w / max_sec_flow_rate_cfm
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirTerminalSingleDuctParallelPIUReheat', "For #{air_terminal_single_duct_parallel_piu_reheat.name}: fan efficacy set to #{fan_efficacy_new_w_per_cfm.round(2)} W/cfm.")

    return true
  end
end

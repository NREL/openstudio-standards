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

    # Get the fan limitation pressure drop adjustment bhp
    fan_pwr_adjustment_bhp = air_loop_hvac_fan_power_limitation_pressure_drop_adjustment_brake_horsepower(air_loop_hvac)

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
      allowable_fan_bhp = air_loop_hvac_allowable_system_brake_horsepower(air_loop_hvac) + fan_pwr_adjustment_bhp

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
end

class ASHRAE901PRM < Standard
  # @!group ZoneHVACComponent

  def zone_hvac_component_fan_efficacy(system_type, nmc_flag)
    fan_efficacy_w_per_cfm = 0.0
    case system_type
    when 'PTAC', 'PTHP'
      fan_efficacy_w_per_cfm = 0.3
    when 'Gas_Furnace', 'Electric_furnace'
      if nmc_flag
        fan_efficacy_w_per_cfm = 0.054
      else
        fan_efficacy_w_per_cfm = 0.3
      end
      else OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.ZoneHVACComponent', 'Zone HVAC system fan power lookup missing.')
    end
    return fan_efficacy_w_per_cfm
  end

  # Sets the fan power of zone level HVAC equipment
  # (Fan coils, Unit Heaters, PTACs, PTHPs, VRF Terminals, WSHPs, ERVs)
  # based on the W/cfm specified in the standard.
  #
  # @return [Bool] returns true if successful, false if not
  def zone_hvac_component_apply_prm_baseline_fan_power(zone_hvac_component)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.ashrae_90_1_prm.ZoneHVACComponent', "Setting fan power for #{zone_hvac_component.name}.")

    # Convert this to the actual class type
    zone_hvac = if zone_hvac_component.to_ZoneHVACFourPipeFanCoil.is_initialized
                  zone_hvac_component.to_ZoneHVACFourPipeFanCoil.get
                elsif zone_hvac_component.to_ZoneHVACUnitHeater.is_initialized
                  zone_hvac_component.to_ZoneHVACUnitHeater.get
                elsif zone_hvac_component.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
                  zone_hvac_component.to_ZoneHVACPackagedTerminalAirConditioner.get
                elsif zone_hvac_component.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
                  zone_hvac_component.to_ZoneHVACPackagedTerminalHeatPump.get
                elsif zone_hvac_component.to_ZoneHVACTerminalUnitVariableRefrigerantFlow.is_initialized
                  zone_hvac_component.to_ZoneHVACTerminalUnitVariableRefrigerantFlow.get
                elsif zone_hvac_component.to_ZoneHVACWaterToAirHeatPump.is_initialized
                  zone_hvac_component.to_ZoneHVACWaterToAirHeatPump.get
                elsif zone_hvac_component.to_ZoneHVACEnergyRecoveryVentilator.is_initialized
                  zone_hvac_component.to_ZoneHVACEnergyRecoveryVentilator.get
                end

    # Do nothing for other types of zone HVAC equipment
    return false if zone_hvac.nil?

    # Do nothing if zone hav component isn't assigned to thermal zone
    return false unless zone_hvac.thermalZone.is_initialized

    # Get baseline system type
    system_type = zone_hvac.thermalZone.get.additionalProperties.getFeatureAsString('baseline_system_type').get

    # Get non-mechanically cooled flag
    if zone_hvac.thermalZone.get.additionalProperties.hasFeature('non_mechanically_cooled')
      nmc_flag = zone_hvac.thermalZone.additionalProperties.hasFeature('non_mechanically_cooled')
      else nmc_flag = false
    end

    # Determine the W/cfm
    fan_efficacy_w_per_cfm = zone_hvac_component_fan_efficacy(system_type, nmc_flag)

    # Convert efficacy to metric
    fan_efficacy_w_per_m3_per_s = OpenStudio.convert(fan_efficacy_w_per_cfm, 'm^3/s', 'cfm').get

    # Get the fan
    fan = if zone_hvac.supplyAirFan.to_FanConstantVolume.is_initialized
            zone_hvac.supplyAirFan.to_FanConstantVolume.get
          elsif zone_hvac.supplyAirFan.to_FanVariableVolume.is_initialized
            zone_hvac.supplyAirFan.to_FanVariableVolume.get
          elsif zone_hvac.supplyAirFan.to_FanOnOff.is_initialized
            zone_hvac.supplyAirFan.to_FanOnOff.get
          end

    # Get the maximum flow rate through the fan
    max_air_flow_rate = nil
    if fan.autosizedMaximumFlowRate.is_initialized
      max_air_flow_rate = fan.autosizedMaximumFlowRate.get
    elsif fan.maximumFlowRate.is_initialized
      max_air_flow_rate = fan.maximumFlowRate.get
    end
    max_air_flow_rate_cfm = OpenStudio.convert(max_air_flow_rate, 'm^3/s', 'ft^3/min').get

    # Set the impeller efficiency
    fan_change_impeller_efficiency(fan, fan_baseline_impeller_efficiency(fan))

    # Set the motor efficiency, preserving the impeller efficency.
    # For zone HVAC fans, a bhp lookup of 0.5bhp is always used because
    # they are assumed to represent a series of small fans in reality.
    fan_apply_standard_minimum_motor_efficiency(fan, fan_brake_horsepower(fan))

    # Calculate a new pressure rise to hit the target W/cfm
    fan_tot_eff = fan.fanEfficiency
    fan_rise_new_pa = fan_efficacy_w_per_m3_per_s * fan_tot_eff
    fan.setPressureRise(fan_rise_new_pa)

    # Calculate the newly set efficacy
    fan_power_new_w = fan_rise_new_pa * max_air_flow_rate / fan_tot_eff
    fan_efficacy_new_w_per_cfm = fan_power_new_w / max_air_flow_rate_cfm
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.ashrae_90_1_prm.ZoneHVACComponent', "For #{zone_hvac_component.name}: fan efficacy set to #{fan_efficacy_new_w_per_cfm.round(2)} W/cfm.")

    return true
  end


end

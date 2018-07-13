class NRELZNEReady2017 < ASHRAE901
  # @!group ZoneHVACComponent

  # Sets the fan power of zone level HVAC equipment
  # (PTACs, PTHPs, Fan Coils, and Unit Heaters)
  # based on the W/cfm specified in the standard.
  #
  # @return [Bool] returns true if successful, false if not
  def zone_hvac_component_apply_standard_fan_power(zone_hvac_component)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.ZoneHVACComponent', "Setting fan power for #{zone_hvac_component.name}.")

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
                end

    # Do nothing for other types of zone HVAC equipment
    if zone_hvac.nil?
      return false
    end

    # Determine the W/cfm
    fan_efficacy_w_per_cfm = 0.38

    # Convert efficacy to metric
    fan_efficacy_w_per_m3_per_s = fan_efficacy_w_per_cfm / OpenStudio.convert(1.0, 'ft^3/min', 'm^3/s').get

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

    # Set the motor efficiency, preserving the impeller efficiency.
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
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.ZoneHVACComponent', "For #{zone_hvac_component.name}: fan efficacy set to #{fan_efficacy_new_w_per_cfm.round(2)} W/cfm.")

    return true
  end
end

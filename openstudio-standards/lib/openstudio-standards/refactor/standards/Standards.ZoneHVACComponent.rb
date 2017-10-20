# open the class to add methods to apply HVAC efficiency standards
class StandardsModel < OpenStudio::Model::Model
  # Sets the fan power of zone level HVAC equipment 
  # (PTACs, PTHPs, Fan Coils, and Unit Heaters)
  # based on the W/cfm specified in the standard.
  #
  # @param template [String] the template base requirements on
  # @return [Bool] returns true if successful, false if not
  def zone_hvac_component_apply_prm_baseline_fan_power(zone_hvac_component, template)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.ZoneHVACComponent', "Setting fan power for #{name}.")

    # Convert this to the actual class type
    zone_hvac = if to_ZoneHVACFourPipeFanCoil.is_initialized
                  to_ZoneHVACFourPipeFanCoil.get
                elsif to_ZoneHVACUnitHeater.is_initialized
                  to_ZoneHVACUnitHeater.get
                elsif to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
                  to_ZoneHVACPackagedTerminalAirConditioner.get
                elsif to_ZoneHVACPackagedTerminalHeatPump.is_initialized
                  to_ZoneHVACPackagedTerminalHeatPump.get
                else
                  nil
                end

    # Do nothing for other types of zone HVAC equipment
    if zone_hvac.nil?
      return false
    end

    # Determine the W/cfm
    fan_efficacy_w_per_cfm = 0.3

    # Convert efficacy to metric
    # 1 cfm = 0.0004719 m^3/s
    fan_efficacy_w_per_m3_per_s = fan_efficacy_w_per_cfm / 0.0004719

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
    fan_change_impeller_efficiency(fan, fan.baseline_impeller_efficiency(template))

    # Set the motor efficiency, preserving the impeller efficency.
    # For zone HVAC fans, a bhp lookup of 0.5bhp is always used because
    # they are assumed to represent a series of small fans in reality.
    fan_apply_standard_minimum_motor_efficiency(fan, template, fan.brake_horsepower)

    # Calculate a new pressure rise to hit the target W/cfm
    fan_tot_eff = fan.fanEfficiency
    fan_rise_new_pa = fan_efficacy_w_per_m3_per_s * fan_tot_eff
    fan.setPressureRise(fan_rise_new_pa)

    # Calculate the newly set efficacy
    fan_power_new_w = fan_rise_new_pa * max_air_flow_rate / fan_tot_eff
    fan_efficacy_new_w_per_cfm = fan_power_new_w / max_air_flow_rate_cfm
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.ZoneHVACComponent', "For #{name}: fan efficacy set to #{fan_efficacy_new_w_per_cfm.round(2)} W/cfm.")

    return true
  end
end
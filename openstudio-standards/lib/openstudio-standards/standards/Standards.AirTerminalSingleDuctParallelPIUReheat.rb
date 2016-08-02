
# open the class to add methods to apply HVAC efficiency standards
class OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat
  # Sets the fan power of a PIU fan based on the W/cfm
  # specified in the standard.
  #
  # @param template [String] the template base requirements on
  # @return [Bool] returns true if successful, false if not
  def apply_prm_baseline_fan_power(template)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.AirTerminalSingleDuctParallelPIUReheat', "Setting PIU fan power for #{name}.")

    # Determine the fan sizing flow rate, min flow rate,
    # and W/cfm
    sec_flow_frac = 0.5
    min_flow_frac = 0.3
    fan_efficacy_w_per_cfm = 0.35
    # case template
    # when
    # else
    # end

    # Get the maximum flow rate through the terminal
    max_primary_air_flow_rate = nil
    if autosizedMaximumPrimaryAirFlowRate.is_initialized
      max_primary_air_flow_rate = autosizedMaximumPrimaryAirFlowRate.get
    elsif maximumPrimaryAirFlowRate.is_initialized
      max_primary_air_flow_rate = maximumPrimaryAirFlowRate.get
    end

    # Set the max secondary air flow rate
    max_sec_flow_rate_m3_per_s = max_primary_air_flow_rate * sec_flow_frac
    setMaximumSecondaryAirFlowRate(max_sec_flow_rate_m3_per_s)

    # Set the minimum flow fraction
    # TODO Also compare to min OA requirement
    setMinimumPrimaryAirFlowFraction(min_flow_frac)

    # Set the fan efficacy
    fan = self.fan.to_FanConstantVolume.get
    fan_rise_pa = fan.pressureRise
    fan_rise_in_wc = OpenStudio.convert(fan_rise_pa, 'Pa', 'inH_{2}O')
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.AirTerminalSingleDuctParallelPIUReheat', "=> Pressure Rise = #{fan_rise_pa} Pa")

    max_sec_flow_rate_cfm = OpenStudio.convert(max_sec_flow_rate_m3_per_s, 'm^3/s', 'ft^3/min').get
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.AirTerminalSingleDuctParallelPIUReheat', "=> Maximum Fan Flow Rate = #{max_sec_flow_rate_cfm} m3/s")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.AirTerminalSingleDuctParallelPIUReheat', "=> Maximum Secondary Air Flow Rate = #{maximumSecondaryAirFlowRate.get} m3/s")

    fan_efficiency = fan.fanEfficiency
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.AirTerminalSingleDuctParallelPIUReheat', "=> Fan Total Efficiency = #{fan_efficiency}")

    fan_power_w = fan_rise_pa * max_sec_flow_rate_m3_per_s / fan_efficiency
    fan_efficacy_calc = fan_power_w / max_sec_flow_rate_m3_per_s
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.AirTerminalSingleDuctParallelPIUReheat', "=> fan efficacy calculated = #{fan_efficacy_calc} W-s/m3")

    fan_efficacy_w_per_m3_per_s = fan_efficacy_w_per_cfm * OpenStudio.convert(1, 'm^3/s', 'cfm').get

    fan_rise_new_pa = fan_efficacy_w_per_m3_per_s * fan_efficiency
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.AirTerminalSingleDuctParallelPIUReheat', "=> fan pressure rise new = #{fan_rise_new_pa} Pa")
    fan.setPressureRise(fan_rise_new_pa)
    fan_power_new_w = fan_rise_new_pa * max_sec_flow_rate_cfm / fan_efficiency
    fan_efficacy_new_w_per_cfm = fan_power_new_w / max_sec_flow_rate_cfm

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.AirTerminalSingleDuctParallelPIUReheat', "For #{name}: fan efficacy set to #{fan_efficacy_new_w_per_cfm.round(2)} W/cfm, fan bhp = #{fan.brake_horsepower} hp, motor efficiency = #{fan.motorEfficiency}.")

    return true
  end
end

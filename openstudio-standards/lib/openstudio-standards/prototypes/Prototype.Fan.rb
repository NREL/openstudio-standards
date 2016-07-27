
# Prototype fan calculation methods that are the same regardless of fan type.
# These methods are available to FanConstantVolume, FanOnOff, FanVariableVolume, and FanZoneExhaust
module PrototypeFan
  # Sets the fan motor efficiency using the Prototype
  # model assumptions for fan impeller efficiency,
  # motor type, and a 10% safety factor on brake horsepower.
  #
  # @return [Bool] true if successful, false if not
  def set_prototype_fan_efficiency(template)
    # Get the max flow rate from the fan.
    maximum_flow_rate_m3_per_s = nil
    if maximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = maximumFlowRate.get
    elsif autosizedMaximumFlowRate.is_initialized
      maximum_flow_rate_m3_per_s = autosizedMaximumFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Fan', "For #{name} max flow rate is not hard sized, cannot apply efficiency standard.")
      return false
    end

    # Convert max flow rate to cfm
    maximum_flow_rate_cfm = OpenStudio.convert(maximum_flow_rate_m3_per_s, 'm^3/s', 'cfm').get

    # Get the pressure rise from the fan
    pressure_rise_pa = pressureRise
    pressure_rise_in_h2o = OpenStudio.convert(pressure_rise_pa, 'Pa', 'inH_{2}O').get

    # Get the default impeller efficiency
    fan_impeller_eff = baseline_impeller_efficiency(template)

    # Calculate the Brake Horsepower
    brake_hp = (pressure_rise_in_h2o * maximum_flow_rate_cfm) / (fan_impeller_eff * 6356)
    allowed_hp = brake_hp * 1.1 # Per PNNL document #TODO add reference
    if allowed_hp > 0.1
      allowed_hp = allowed_hp.round(2) + 0.0001
    elsif allowed_hp < 0.01
      allowed_hp = 0.01
    end

    # Minimum motor size for efficiency lookup
    # is 1 HP unless the motor serves an exhaust fan,
    # a powered VAV terminal, or a fan coil unit.
    unless is_small_fan
      if allowed_hp < 1.0
        allowed_hp = 1.01
      end
    end

    # Find the motor efficiency
    motor_eff, nominal_hp = standard_minimum_motor_efficiency_and_size(template, allowed_hp)

    # Calculate the total fan efficiency
    total_fan_eff = fan_impeller_eff * motor_eff

    # Set the total fan efficiency and the motor efficiency
    if to_FanZoneExhaust.is_initialized
      setFanEfficiency(total_fan_eff)
    else
      setFanEfficiency(total_fan_eff)
      setMotorEfficiency(motor_eff)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Fan', "For #{name}: allowed_hp = #{allowed_hp.round(2)}HP; motor eff = #{(motor_eff * 100).round(2)}%; total fan eff = #{(total_fan_eff * 100).round}% based on #{maximum_flow_rate_cfm.round} cfm.")

    return true
  end
end

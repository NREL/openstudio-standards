class ASHRAE9012016 < ASHRAE901
  # @!group elevators

  # Determines the percentage of the elevator cab
  # lighting that is incandescent.  The remainder
  # is assumed to be LED.  Defaults to 0% incandescent
  # (100% LED), representing newer elevators.
  def model_elevator_lighting_pct_incandescent(model)
    pct_incandescent = 0.0 # 100% LED
    return pct_incandescent
  end

  # Determines the power of the elevator ventilation fan.
  # 90.1-2016 has a requirement
  # for ventilation fan efficiency.
  # @return [Double] the ventilaton fan power (W)
  def model_elevator_fan_pwr(model, vent_rate_cfm)
    vent_pwr_per_flow_w_per_cfm = 0.33
    vent_pwr_w = vent_pwr_per_flow_w_per_cfm * vent_rate_cfm
    # addendum 90.1-2007 aj has requirement on efficiency
    vent_pwr_w = vent_pwr_w * 0.29 / 0.70

    return vent_pwr_w
  end
end

class ASHRAE9012010 < ASHRAE901
  # @!group elevators

  # Determines the percentage of the elevator cab
  # lighting that is incandescent.  The remainder
  # is assumed to be LED.  Defaults to 0% incandescent
  # (100% LED), representing newer elevators.
  def model_elevator_lighting_pct_incandescent(model)
    pct_incandescent = 0.0 # 100% LED
    return pct_incandescent
  end
end

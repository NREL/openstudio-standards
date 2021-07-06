class ZEAEDGMultifamily < ASHRAE901
  # @!group ZoneHVACComponent

  # default fan efficiency for small zone hvac fans, in watts per cfm
  #
  # @return [Double] fan efficiency in watts per cfm
  def zone_hvac_component_prm_baseline_fan_efficacy
    fan_efficacy_w_per_cfm = 0.65
    return fan_efficacy_w_per_cfm
  end
end

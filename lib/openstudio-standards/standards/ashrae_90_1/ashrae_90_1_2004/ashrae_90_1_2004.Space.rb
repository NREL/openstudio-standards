class ASHRAE9012004 < ASHRAE901
  # @!group Space

  # Baseline infiltration rate
  #
  # @return [Double] the baseline infiltration rate, in cfm/ft^2 exterior above grade wall area at 75 Pa
  def space_infiltration_rate_75_pa(space = nil)
    basic_infil_rate_cfm_per_ft2 = 1.8
    return basic_infil_rate_cfm_per_ft2
  end
end

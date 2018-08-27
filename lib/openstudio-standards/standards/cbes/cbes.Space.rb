class CBES < Standard
  # @!group Space

  # Determine the base infiltration rate at 75 PA.
  #
  # @return [Double] the baseline infiltration rate, in cfm/ft^2
  # defaults to no infiltration.
  def space_infiltration_rate_75_pa(space)
    basic_infil_rate_cfm_per_ft2 = 1.8
    return basic_infil_rate_cfm_per_ft2
  end
end

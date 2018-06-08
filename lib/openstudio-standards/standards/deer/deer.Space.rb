class DEER
  # @!group Space

  # Determine the base infiltration rate at 75 PA.
  # In the MASControl2 rules, there is BDL code which
  # states that the value is 0.038 cfm/ft2 of perimeter wall area
  # at typical building pressures.
  # This translates to 0.338921 cfm/ft2 of perimeter wall area at
  # 75Pa using the assumptions from the DOE Prototypes.
  #
  # @return [Double] the baseline infiltration rate, in cfm/ft^2
  # defaults to no infiltration.
  def space_infiltration_rate_75_pa(space)
    basic_infil_rate_cfm_per_ft2 = 0.338921
    return basic_infil_rate_cfm_per_ft2
  end
end
class DEER
  # @!group Space

  # Baseline infiltration rate
  #
  # In the MASControl2 database DEER_Rules_ProtoDB.db, table 'BDLRules',
  # 'SPACE:INF-FLOW/AREA' is:
  # "if (#L(rvVertWallArea) < 1 ) then 0.001 else if(#SN(#LSI(C-ZONE-TYPE)) = "CRAWL") then 0.075
  # else 0.038 * #L(rvVertWallArea) / #L(AREA) endif endif"
  # meaning the default DEER infiltation value is 0.038 cfm/ft2 per exterior wall area at typical building pressures.
  # Using the same PNNL prototype assumptions for natural pressure,
  # this correlates to a baseline infiltration rate of 0.3393 cfm/ft2 of exterior wall area at 75Pa.
  # *Note that this implies a baseline infiltration rate ~5 times lower than the PNNL modeling guideline.
  #
  # @return [Double] the baseline infiltration rate, in cfm/ft^2 exterior above grade wall area at 75 Pa
  def space_infiltration_rate_75_pa(space)
    basic_infil_rate_cfm_per_ft2 = 0.3393
    return basic_infil_rate_cfm_per_ft2
  end
end
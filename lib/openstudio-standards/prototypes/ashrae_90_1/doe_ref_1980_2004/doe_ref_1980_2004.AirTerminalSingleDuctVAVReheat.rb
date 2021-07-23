class DOERef1980to2004 < ASHRAE901
  # @!group AirTerminalSingleDuctVAVReheat
  # Set the initial minimum damper position based on OA rate of the space and the template.
  # Zones with low OA per area get lower initial guesses.
  # Final position will be adjusted upward as necessary by Standards.AirLoopHVAC.apply_minimum_vav_damper_positions
  #
  # @param zone_oa_per_area [Double] the zone outdoor air per area, m^3/s
  # @return [Bool] returns true if successful, false if not
  def air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(air_terminal_single_duct_vav_reheat, zone_oa_per_area)
    # Set the minimum flow fraction
    min_damper_position = 0.3
    air_terminal_single_duct_vav_reheat.setConstantMinimumAirFlowFraction(min_damper_position)

    return true
  end
end

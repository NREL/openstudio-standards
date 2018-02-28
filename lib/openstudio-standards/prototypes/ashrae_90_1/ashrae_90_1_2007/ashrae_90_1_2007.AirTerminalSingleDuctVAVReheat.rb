class ASHRAE9012007 < ASHRAE901
  # @!group AirTerminalSingleDuctVAVReheat

  # Set the initial minimum damper position based on OA
  # rate of the space and the template.
  # Zones with low OA per area get lower initial guesses.
  # Final position will be adjusted upward
  # as necessary by Standards.AirLoopHVAC.apply_minimum_vav_damper_positions
  # @param zone_oa_per_area [Double] the zone outdoor air per area, m^3/s
  # @return [Bool] returns true if successful, false if not
  def air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(air_terminal_single_duct_vav_reheat, building_type, zone_oa_per_area)
    vav_name = air_terminal_single_duct_vav_reheat.name.get
    min_damper_position = 0.3

    # High OA zones
    # Determine whether or not to use the high minimum guess.
    # Cutoff was determined by correlating apparent minimum guesses
    # to OA rates in prototypes since not well documented in papers.
    if zone_oa_per_area > 0.001 # 0.001 m^3/s*m^2 = .196 cfm/ft2

      min_damper_position = if building_type == 'Outpatient' || building_type == 'Hospital'
                              1.0
                            else
                              0.7
                            end
    end

    # Set the minimum flow fraction
    air_terminal_single_duct_vav_reheat.setConstantMinimumAirFlowFraction(min_damper_position)

    return true
  end
end

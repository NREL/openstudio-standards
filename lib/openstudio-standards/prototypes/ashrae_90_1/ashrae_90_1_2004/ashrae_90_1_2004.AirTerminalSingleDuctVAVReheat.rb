class ASHRAE9012004 < ASHRAE901
  # @!group AirTerminalSingleDuctVAVReheat
  # Set the initial minimum damper position based on OA rate of the space and the template.
  # Zones with low OA per area get lower initial guesses.
  # Final position will be adjusted upward as necessary by Standards.AirLoopHVAC.apply_minimum_vav_damper_positions
  #
  # @param zone_oa_per_area [Double] the zone outdoor air per area, m^3/s
  # @return [Bool] returns true if successful, false if not
  def air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(air_terminal_single_duct_vav_reheat, zone_oa_per_area)
    min_damper_position = 0.3

    # Minimum damper position for Outpatient prototype
    # Based on AIA 2001 ventilation requirements
    # See Section 5.2.2.16 in Thornton et al. 2010
    # https://www.energycodes.gov/sites/default/files/documents/BECP_Energy_Cost_Savings_STD2010_May2011_v00.pdf
    airlp = air_terminal_single_duct_vav_reheat.airLoopHVAC.get
    if airlp.name.to_s.include? "Outpatient"
      init_mdp = {
        "FLOOR 2 CONFERENCE TOILET"=> 1.0,
        "FLOOR 2 EXAM 1"=> 1.0,
        "FLOOR 2 EXAM 2"=> 1.0,
        "FLOOR 2 EXAM 3"=> 1.0,
        "FLOOR 2 EXAM 4"=> 1.0,
        "FLOOR 2 EXAM 5"=> 1.0,
        "FLOOR 2 EXAM 6"=> 1.0,
        "FLOOR 2 EXAM 7"=> 1.0,
        "FLOOR 2 EXAM 8"=> 1.0,
        "FLOOR 2 EXAM 9"=> 1.0,
        "FLOOR 2 RECEPTION TOILET"=> 1.0,
        "FLOOR 2 WORK TOILET"=> 1.0,
        "FLOOR 3 LOUNGE TOILET"=> 1.0,
        "FLOOR 3 OFFICE TOILET"=> 1.0,
        "FLOOR 3 PHYSICAL THERAPY 1"=> 1.0,
        "FLOOR 3 PHYSICAL THERAPY 2"=> 1.0,
        "FLOOR 3 PHYSICAL THERAPY TOILET"=> 1.0,
        "FLOOR 3 STORAGE 1"=> 1.0,
        "FLOOR 3 TREATMENT"=> 1.0,
      }
      init_mdp.each do |zn_name, mdp|
        if air_terminal_single_duct_vav_reheat.name.to_s.upcase.strip.include? zn_name.to_s.strip
          min_damper_position = mdp
        end
      end
    end

    # Set the minimum flow fraction
    air_terminal_single_duct_vav_reheat.setConstantMinimumAirFlowFraction(min_damper_position)

    return true
  end
end

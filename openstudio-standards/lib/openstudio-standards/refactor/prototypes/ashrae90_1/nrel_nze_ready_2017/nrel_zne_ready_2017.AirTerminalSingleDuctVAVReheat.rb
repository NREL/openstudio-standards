class NRELZNEReady2017_Model < A90_1_Model
  # Set the initial minimum damper position based on OA
  # rate of the space and the template.
  # Zones with low OA per area get lower initial guesses.
  # Final position will be adjusted upward
  # as necessary by Standards.AirLoopHVAC.apply_minimum_vav_damper_positions
  # @param template [String] the template
  # @param zone_oa_per_area [Double] the zone outdoor air per area, m^3/s
  # @return [Bool] returns true if successful, false if not
  def air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(air_terminal_single_duct_vav_reheat, building_type, zone_oa_per_area)

    vav_name = air_terminal_single_duct_vav_reheat.name.get
    min_damper_position = case air_terminal_single_duct_vav_reheat_reheat_type(air_terminal_single_duct_vav_reheat)
                          when 'HotWater'
                            0.2
                          when 'Electricity', 'NaturalGas'
                            0.3
                          end

    # High OA zones
    # Determine whether or not to use the high minimum guess.
    # Cutoff was determined by correlating apparent minimum guesses
    # to OA rates in prototypes since not well documented in papers.
    if zone_oa_per_area > 0.001 # 0.001 m^3/s*m^2 = .196 cfm/ft2
      if building_type == 'Outpatient'
        min_damper_position = 1.0
      elsif building_type == 'Hospital'
        if vav_name.include? 'PatRoom'
          min_damper_position = 0.5
        else
          min_damper_position = 1.0
          min_damper_position = 1.0
        end
      else
        min_damper_position = 0.7
      end
    end

    # Set the minimum flow fraction
    air_terminal_single_duct_vav_reheat.setConstantMinimumAirFlowFraction(min_damper_position)
    
    return true
  end
end

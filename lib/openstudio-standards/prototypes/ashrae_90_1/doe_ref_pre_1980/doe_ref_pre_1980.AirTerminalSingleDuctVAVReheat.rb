class DOERefPre1980 < ASHRAE901
  # Set the initial minimum damper position based on OA
  # rate of the space and the template.
  # Zones with low OA per area get lower initial guesses.
  # Final position will be adjusted upward
  # as necessary by Standards.AirLoopHVAC.apply_minimum_vav_damper_positions
  # @param zone_oa_per_area [Double] the zone outdoor air per area, m^3/s
  # @return [Bool] returns true if successful, false if not
  # @todo remove exception where older vintages don't have minimum positions adjusted.
  def air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(air_terminal_single_duct_vav_reheat, building_type, zone_oa_per_area)
    vav_name = air_terminal_single_duct_vav_reheat.name.get
    min_damper_position = if building_type == 'Outpatient' && vav_name.include?('Floor 1')
                            1
                          elsif building_type == 'Hospital' && vav_name.include?('PatRoom')
                            1
                          elsif building_type == 'Hospital' && vav_name.include?('OR')
                            1
                          elsif building_type == 'Hospital' && vav_name.include?('ICU')
                            1
                          elsif building_type == 'Hospital' && vav_name.include?('Lab')
                            1
                          elsif building_type == 'Hospital' && vav_name.include?('ER')
                            1
                          elsif building_type == 'Hospital' && vav_name.include?('Kitchen')
                            1
                          elsif building_type == 'Hospital' && vav_name.include?('NurseStn')
                            0.3
                          else
                            0.3
                          end

    air_terminal_single_duct_vav_reheat.setConstantMinimumAirFlowFraction(min_damper_position)

    return true
  end
end

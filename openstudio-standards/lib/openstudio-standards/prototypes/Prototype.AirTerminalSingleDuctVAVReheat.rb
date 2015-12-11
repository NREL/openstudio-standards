
class OpenStudio::Model::AirTerminalSingleDuctVAVReheat

  # Set the initial minimum damper position based on OA
  # rate of the space and the building vintage.
  # Zones with low OA per area get lower initial guesses. 
  # Final position will be adjusted upward
  # as necessary by Standards.AirLoopHVAC.set_minimum_vav_damper_positions
  # @param building_vintage [String] the building vintage
  # @param zone_oa_per_area [Double] the zone outdoor air per area, m^3/s
  # @return [Bool] returns true if successful, false if not
  # @todo remove exception where older vintages don't have minimum positions adjusted.
  def set_initial_prototype_damper_position(building_vintage, zone_oa_per_area)
 
    # Minimum damper position is based on prototype
    # assumptions, which are not clearly documented.
    min_damper_position = nil
    case prototype_input['template']       
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004'
      min_damper_position = 0.3
    when '90.1-2007'
      min_damper_position = 0.3
    when '90.1-2010', '90.1-2013'
      min_damper_position = 0.2
    end
    
    # TODO remove the template conditional; doesn't make sense
    # Determine whether or not to use the high minimum guess.
    # Cutoff was determined by correlating apparent minimum guesses
    # to OA rates in prototypes since not well documented in papers.
    if zone_oa_per_area > 0.001 # 0.001 m^3/s*m^2 = .196 cfm/ft2
      case prototype_input['template'] 
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        terminal.setConstantMinimumAirFlowFraction(min_damper_position)
      else
        # High OA zones
        terminal.setConstantMinimumAirFlowFraction(0.7)
      end
    else
      # Low OA zones
      terminal.setConstantMinimumAirFlowFraction(min_damper_position)
    end

    return true
  
  end

end

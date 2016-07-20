
class OpenStudio::Model::AirTerminalSingleDuctVAVReheat

  # Set the minimum damper position based on OA
  # rate of the space and the building vintage.
  # Zones with low OA per area get lower initial guesses. 
  # Final position will be adjusted upward
  # as necessary by Standards.AirLoopHVAC.adjust_minimum_vav_damper_positions
  # @param building_vintage [String] the building vintage
  # @param zone_min_oa [Double] the zone outdoor air flow rate, in m^3/s.
  # If supplied, this will be set as a minimum limit in addition to the minimum
  # damper position.  EnergyPlus will use the larger of the two values during sizing.
  # @param has_ddc [Bool] whether or not there is DDC control of the VAV terminal,
  # which impacts the minimum damper position requirement.
  # @return [Bool] returns true if successful, false if not
  # @todo remove exception where older vintages don't have minimum positions adjusted.
  def set_minimum_damper_position(building_vintage, zone_min_oa=nil, has_ddc = true)
 
    # Minimum damper position
    min_damper_position = nil
    case building_vintage       
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004'
      min_damper_position = 0.3
    when '90.1-2007'
      min_damper_position = 0.3
    when '90.1-2010', '90.1-2013'
      if has_ddc
        min_damper_position = 0.2
      else
        min_damper_position = 0.3
      end
    end
    self.setConstantMinimumAirFlowFraction(min_damper_position)
    
    # Minimum OA flow rate
    # If specified, will also add this limit
    # and the larger of the two will be used
    # for sizing.
    unless zone_min_oa.nil?
      self.setFixedMinimumAirFlowRate(zone_min_oa)
    end

    return true
  
  end

end

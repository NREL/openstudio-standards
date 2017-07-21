
class OpenStudio::Model::AirTerminalSingleDuctVAVReheat
  # Set the initial minimum damper position based on OA
  # rate of the space and the template.
  # Zones with low OA per area get lower initial guesses.
  # Final position will be adjusted upward
  # as necessary by Standards.AirLoopHVAC.apply_minimum_vav_damper_positions
  # @param template [String] the template
  # @param zone_oa_per_area [Double] the zone outdoor air per area, m^3/s
  # @return [Bool] returns true if successful, false if not
  # @todo remove exception where older vintages don't have minimum positions adjusted.
  def apply_initial_prototype_damper_position(building_type, template, zone_oa_per_area)
    # Minimum damper position is based on prototype
    # assumptions, which are not clearly documented.
    min_damper_position = nil
    vav_name = name.get
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
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
    when '90.1-2004', '90.1-2007'
      min_damper_position = 0.3
    when '90.1-2010', '90.1-2013', 'NREL ZNE Ready 2017'
      min_damper_position = 0.2
    end

    # TODO: remove the template conditional; doesn't make sense
    # Determine whether or not to use the high minimum guess.
    # Cutoff was determined by correlating apparent minimum guesses
    # to OA rates in prototypes since not well documented in papers.
    if zone_oa_per_area > 0.001 # 0.001 m^3/s*m^2 = .196 cfm/ft2
      case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        setConstantMinimumAirFlowFraction(min_damper_position)
      else
        # High OA zones
        if building_type == 'Outpatient'
          setConstantMinimumAirFlowFraction(1)
        elsif building_type == 'Hospital'
          case template
          when '90.1-2010', '90.1-2013'
            if vav_name.include? 'PatRoom'
              setConstantMinimumAirFlowFraction(0.5)
            else
              setConstantMinimumAirFlowFraction(1)
            end
          when '90.1-2004', '90.1-2007'
            setConstantMinimumAirFlowFraction(1)
          end
        else
          setConstantMinimumAirFlowFraction(0.7)
        end
      end
    else
      # Low OA zones
      setConstantMinimumAirFlowFraction(min_damper_position)
    end

    return true
  end
end

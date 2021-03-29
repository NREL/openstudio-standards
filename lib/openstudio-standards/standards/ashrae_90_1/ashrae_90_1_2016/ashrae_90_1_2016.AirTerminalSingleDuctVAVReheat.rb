class ASHRAE9012016 < ASHRAE901
  # @!group AirTerminalSingleDuctVAVReheat

  # Specifies the minimum damper position for VAV dampers.
  # For terminals with hot water heat and DDC, the minimum is 20%,
  # otherwise the minimum is 30%.
  #
  # @param has_ddc [Bool] whether or not there is DDC control of the VAV terminal in question
  def air_terminal_single_duct_vav_reheat_minimum_damper_position(air_terminal_single_duct_vav_reheat, has_ddc = false)
    min_damper_position = nil
    case air_terminal_single_duct_vav_reheat_reheat_type(air_terminal_single_duct_vav_reheat)
    when 'HotWater'
      min_damper_position = if has_ddc
                              0.2
                            else
                              0.3
                            end
    when 'Electricity', 'NaturalGas'
      min_damper_position = 0.3
    end

    return min_damper_position
  end
end

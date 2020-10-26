class DEER
  # @!group AirLoopHVAC

  # For LA100 calibration, default to systems being left on
  # Overwritten to be required for DEER2020 and beyond
  # @return [Bool] true if required, false if not
  def air_loop_hvac_unoccupied_fan_shutoff_required?(air_loop_hvac)
    shutoff_required = false

    return shutoff_required
  end

  # Check the economizer type currently specified in the ControllerOutdoorAir object on this air loop
  # is acceptable per the standard.  Based on the MASControl rules, it appears that
  # only NoEconomizer and FixedDryBulb are allowed.
  #
  # @return [Bool] Returns true if allowable, if the system has no economizer or no OA system.
  # Returns false if the economizer type is not allowable.
  def air_loop_hvac_economizer_type_allowable?(air_loop_hvac, climate_zone)
    # EnergyPlus economizer types
    # 'NoEconomizer'
    # 'FixedDryBulb'
    # 'FixedEnthalpy'
    # 'DifferentialDryBulb'
    # 'DifferentialEnthalpy'
    # 'FixedDewPointAndDryBulb'
    # 'ElectronicEnthalpy'
    # 'DifferentialDryBulbAndEnthalpy'

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return true # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType

    # Return true if one of the valid choices is used, false otherwise
    case economizer_type
      when 'NoEconomizer', 'FixedDryBulb'
        return true
      else
        return false
    end
  end

  # Determine the limits for the type of economizer present
  # on the AirLoopHVAC, if any.
  # @return [Array<Double>] [drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  def air_loop_hvac_economizer_limits(air_loop_hvac, climate_zone)
    drybulb_limit_f = nil
    enthalpy_limit_btu_per_lb = nil
    dewpoint_limit_f = nil

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return [nil, nil, nil] # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType

    case economizer_type
    when 'NoEconomizer'
      return [nil, nil, nil]
    when 'FixedDryBulb'
      enthalpy_limit_btu_per_lb = 28
      case climate_zone
      when 'CEC T24-CEC7'
        drybulb_limit_f = 69
      when 'CEC T24-CEC1',
        'CEC T24-CEC3',
        'CEC T24-CEC5'
      drybulb_limit_f = 70
      when 'CEC T24-CEC6',
        'CEC T24-CEC8',
        'CEC T24-CEC9'
        drybulb_limit_f = 71
      when 'CEC T24-CEC2',
        'CEC T24-CEC4',
        'CEC T24-CEC10',
        drybulb_limit_f = 73
      when 'CEC T24-CEC11',
        'CEC T24-CEC12',
        'CEC T24-CEC13',
        'CEC T24-CEC14',
        'CEC T24-CEC15',
        'CEC T24-CEC16'
        drybulb_limit_f = 75
      end
    end

    return [drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  end

end
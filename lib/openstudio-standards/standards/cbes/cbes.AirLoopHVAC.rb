class CBES < Standard
  # @!group AirLoopHVAC

  # Apply multizone vav outdoor air method and
  # adjust multizone VAV damper positions.  Does nothing for CBES.
  #
  # @return [Bool] returns true if successful, false if not
  # @todo enable damper position adjustment for legacy IDFS
  def air_loop_hvac_apply_multizone_vav_outdoor_air_sizing(air_loop_hvac)
    # Do nothing
    return true
  end

  # Determine if static pressure reset is required for this
  # system.  Not required by CBES.
  #
  # @param has_ddc [Bool] whether or not the system has DDC control
  # over VAV terminals.
  # return [Bool] returns true if static pressure reset is required, false if not
  def air_loop_hvac_static_pressure_reset_required?(air_loop_hvac, has_ddc)
    sp_reset_required = false
    return sp_reset_required
  end

  # Determine whether the VAV damper control is single maximum or
  # dual maximum control.  Single Maximum for CBES.
  #
  # @return [String] the damper control type: Single Maximum, Dual Maximum
  def air_loop_hvac_vav_damper_action(air_loop_hvac)
    damper_action = 'Single Maximum'
    return damper_action
  end

  # Determine if demand control ventilation (DCV) is
  # required for this air loop.  Not required for CBES.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_demand_control_ventilation_required?(air_loop_hvac, climate_zone)
    dcv_required = false
    return dcv_required
  end

  # Add code required single zone controls.  No controls required by CBES.
  #
  # @return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_single_zone_controls(air_loop_hvac, climate_zone)
    # Do nothing
    return true
  end
end

class DOERef1980to2004 < ASHRAE901
  # @!group AirLoopHVAC

  # Apply multizone vav outdoor air method and
  # adjust multizone VAV damper positions.  Currently
  # doesn't do anything for the DOE prototype buildings.
  #
  # @return [Bool] returns true if successful, false if not
  # @todo enable damper position adjustment for legacy IDFS
  def air_loop_hvac_apply_multizone_vav_outdoor_air_sizing(air_loop_hvac)
    # TODO: enable damper position adjustment for legacy IDFS
    OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', 'Damper positions not modified for DOE Ref Pre-1980 or DOE Ref 1980-2004 vintages.')
    return true
  end

  # Determine if static pressure reset is required for this
  # system.  Not required by DOE Ref 1980-2004.
  #
  # @todo Instead of requiring the input of whether a system
  #   has DDC control of VAV terminals or not, determine this
  #   from the system itself.  This may require additional information
  #   be added to the OpenStudio data model.
  # @param has_ddc [Bool] whether or not the system has DDC control
  # over VAV terminals.
  # return [Bool] returns true if static pressure reset is required, false if not
  def air_loop_hvac_static_pressure_reset_required?(air_loop_hvac, has_ddc)
    sp_reset_required = false
    return sp_reset_required
  end

  # Determines if optimum start control is required.
  # Not required by DOE Ref 1980-2004.
  def air_loop_hvac_optimum_start_required?(air_loop_hvac)
    opt_start_required = false
    return opt_start_required
  end

  # Determine whether the VAV damper control is single maximum or
  # dual maximum control.  Single Maximum for DOE Ref 1980-2004.
  #
  # @return [String] the damper control type: Single Maximum, Dual Maximum
  def air_loop_hvac_vav_damper_action(air_loop_hvac)
    damper_action = 'Single Maximum'
    return damper_action
  end
end

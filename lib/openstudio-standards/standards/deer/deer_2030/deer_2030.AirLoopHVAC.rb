class DEER2030 < DEER
  # @!group AirLoopHVAC

  # Determine if the system required supply air temperature (SAT) reset.
  # Defaults to true for DEER 2030.
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Bool] returns true if required, false if not
  def air_loop_hvac_supply_air_temperature_reset_required?(air_loop_hvac, climate_zone)
    is_sat_reset_required = true
    return is_sat_reset_required
  end

  # Determine if a system's fans must shut off when not required.
  # Per ASHRAE 90.1 section 6.4.3.3, HVAC systems are required to have off-hour controls
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @return [Bool] returns true if required, false if not
  def air_loop_hvac_unoccupied_fan_shutoff_required?(air_loop_hvac)
    shutoff_required = true
    return shutoff_required
  end

  # Determine if a motorized OA damper is required
  # Defaults to true for DEER 2030.
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Bool] returns true if required, false if not
  def air_loop_hvac_motorized_oa_damper_required?(air_loop_hvac, climate_zone)
    motorized_oa_damper_required = true
    return motorized_oa_damper_required
  end
end

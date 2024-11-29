class DEER2020 < DEER
  # @!group AirLoopHVAC

  # Determine if the system required supply air temperature (SAT) reset.
  # Defaults to true for DEER 2020.
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Boolean] returns true if required, false if not
  def air_loop_hvac_supply_air_temperature_reset_required?(air_loop_hvac, climate_zone)
    is_sat_reset_required = true
    return is_sat_reset_required
  end

  # Determine if a system's fans must shut off when not required.
  # Per ASHRAE 90.1 section 6.4.3.3, HVAC systems are required to have off-hour controls
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @return [Boolean] returns true if required, false if not
  def air_loop_hvac_unoccupied_fan_shutoff_required?(air_loop_hvac)
    shutoff_required = true
    return shutoff_required
  end

  # Determine if a motorized OA damper is required
  # Defaults to true for DEER 2020.
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @return [Boolean] returns true if required, false if not
  def air_loop_hvac_motorized_oa_damper_required?(air_loop_hvac, climate_zone)
    motorized_oa_damper_required = true
    return motorized_oa_damper_required
  end

  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # @return [Array<Double>] [min_oa_without_economizer_cfm, min_oa_with_economizer_cfm]
  def air_loop_hvac_demand_control_ventilation_limits(air_loop_hvac)
    min_oa_without_economizer_cfm = 3000
    min_oa_with_economizer_cfm = 0
    return [min_oa_without_economizer_cfm, min_oa_with_economizer_cfm]
  end

  # Determine if the standard has an exception for demand control ventilation
  # when an energy recovery device is present.
  # Unlike ASHRAE 90.1, Title 24 does not have an ERV exception to DCV.
  # This method is a copy of what is in Standards.AirLoopHVAC.rb and ensures
  # ERVs will not prevent DCV from being applied to DEER models.
  #
  # @param air_loop_hvac [OpenStudio::Model::AirLoopHVAC] air loop
  # return [Boolean] returns true if required, false if not
  def air_loop_hvac_dcv_required_when_erv(air_loop_hvac)
    dcv_required_when_erv_present = true
    return dcv_required_when_erv_present
  end
end

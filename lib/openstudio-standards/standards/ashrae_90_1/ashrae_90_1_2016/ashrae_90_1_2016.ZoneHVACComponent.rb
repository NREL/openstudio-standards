class ASHRAE9012016 < ASHRAE901
  # @!group ZoneHVACComponent

  # Determine if vestibule heating control is required.
  # Required for 90.1-2016 per 6.4.3.9.
  #
  # @ref [References::ASHRAE9012016] 6.4.3.9
  # @return [Bool] returns true if successful, false if not
  def zone_hvac_component_vestibule_heating_control_required?(zone_hvac_component)
    # Ensure that the equipment is assigned to a thermal zone
    if zone_hvac_component.thermalZone.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.ZoneHVACComponent', "For #{zone_hvac_component.name}: equipment is not assigned to a thermal zone, cannot apply vestibule heating control.")
      return false
    end

    # Only applies to equipment that is in vestibule zones
    return true if thermal_zone_vestibule?(zone_hvac_component.thermalZone.get)

    # If here, vestibule heating control not required
    return false
  end
end

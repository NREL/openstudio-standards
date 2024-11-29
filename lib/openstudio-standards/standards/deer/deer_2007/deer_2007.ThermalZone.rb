class DEER2007 < DEER
  # @!group ThermalZone

  # Determine the area and occupancy level limits for
  # demand control ventilation.
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone
  # @return [Array<Double>] the minimum area, in m^2
  # and the minimum occupancy density in m^2/person.  Returns nil
  # if there is no requirement.
  def thermal_zone_demand_control_ventilation_limits(thermal_zone)
    min_area_ft2 = nil # No minimum area
    min_ft2_per_occ = 40

    # Convert to SI
    min_area_m2 = min_area_ft2
    min_m2_per_occ = OpenStudio.convert(min_ft2_per_occ, 'ft^2', 'm^2').get

    return [min_area_m2, min_m2_per_occ]
  end
end

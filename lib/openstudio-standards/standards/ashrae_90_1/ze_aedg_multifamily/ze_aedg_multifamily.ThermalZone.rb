class ZEAEDGMultifamily < ASHRAE901
  # @!group ThermalZone

  # Determine the area and occupancy level limits for
  # demand control ventilation.
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone
  # @return [Array<Double>] the minimum area, in m^2
  # and the minimum occupancy density in m^2/person.  Returns nil
  # if there is no requirement.
  def thermal_zone_demand_control_ventilation_limits(thermal_zone)
    min_area_ft2 = 500
    min_occ_per_1000_ft2 = 12 # half of 90.1-2013

    # Convert to SI
    min_area_m2 = OpenStudio.convert(min_area_ft2, 'ft^2', 'm^2').get
    min_occ_per_ft2 = min_occ_per_1000_ft2 / 1000.0
    min_ft2_per_occ = 1.0 / min_occ_per_ft2
    min_m2_per_occ = OpenStudio.convert(min_ft2_per_occ, 'ft^2', 'm^2').get

    return [min_area_m2, min_m2_per_occ]
  end
end


class NECB_2011_Model < StandardsModel
  # Determine if demand control ventilation (DCV) is
  # required for this zone based on area and occupant density.
  # Does not account for System requirements like ERV, economizer, etc.
  # Those are accounted for in the AirLoopHVAC method of the same name.
  #
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for 90.1-2013
  #   for cells, sickrooms, labs, barbers, salons, and bowling alleys
  def thermal_zone_demand_control_ventilation_required?(thermal_zone, climate_zone)
    return false
  end

end

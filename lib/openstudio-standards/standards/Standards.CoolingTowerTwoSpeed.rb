class Standard
  # @!group CoolingTowerTwoSpeed

  include CoolingTower

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @return [Bool] true if successful, false if not
  def cooling_tower_two_speed_apply_efficiency_and_curves(cooling_tower_two_speed)
    cooling_tower_apply_minimum_power_per_flow(cooling_tower_two_speed)

    return true
  end
end

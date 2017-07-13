
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::CoolingTowerSingleSpeed
  include CoolingTower

  def apply_efficiency_and_curves(template)
    apply_minimum_power_per_flow(template)

    return true
  end
end

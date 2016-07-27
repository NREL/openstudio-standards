
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::CoolingTowerSingleSpeed
  include CoolingTower

  def setStandardEfficiencyAndCurves(standard)
    set_minimum_power_per_flow(standard)

    return true
  end
end

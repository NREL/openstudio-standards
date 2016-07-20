
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::CoolingTowerTwoSpeed

  include CoolingTower

  def setStandardEfficiencyAndCurves(standard)
    
    self.set_minimum_power_per_flow(standard)

    return true
    
  end

end

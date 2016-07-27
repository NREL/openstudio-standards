
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::CoolingTowerVariableSpeed
  include CoolingTower

  def setStandardEfficiencyAndCurves(standard)
    set_minimum_power_per_flow(standard)

    # 90.1-2013 6.5.2.2 Multicell heat rejection with VSD
    if standard == '90.1-2013'
      setCellControl('MaximalCell')
    end

    return true
  end
end


# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::CoolingTowerVariableSpeed
  include CoolingTower

  def apply_efficiency_and_curves(template)
    apply_minimum_power_per_flow(template)

    # 90.1-2013 6.5.2.2 Multicell heat rejection with VSD
    case template
    when '90.1-2013', 'NREL ZNE Ready 2017'
      setCellControl('MaximalCell')
    end

    return true
  end
end

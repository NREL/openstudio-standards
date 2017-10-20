
# Reopen the OpenStudio class to add methods to apply standards to this object
class StandardsModel < OpenStudio::Model::Model
  include CoolingTower

  def cooling_tower_variable_speed_apply_efficiency_and_curves(cooling_tower_variable_speed, template)
    cooling_tower_apply_minimum_power_per_flow(cooling_tower, template)

    # 90.1-2013 6.5.2.2 Multicell heat rejection with VSD
    case template
    when '90.1-2013', 'NREL ZNE Ready 2017'
      setCellControl('MaximalCell')
    end

    return true
  end
end

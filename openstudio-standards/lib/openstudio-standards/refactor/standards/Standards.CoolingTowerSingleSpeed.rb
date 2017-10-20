
# Reopen the OpenStudio class to add methods to apply standards to this object
class StandardsModel < OpenStudio::Model::Model
  include CoolingTower

  def cooling_tower_single_speed_apply_efficiency_and_curves(cooling_tower_single_speed, template)
    cooling_tower_apply_minimum_power_per_flow(cooling_tower, template)

    return true
  end
end

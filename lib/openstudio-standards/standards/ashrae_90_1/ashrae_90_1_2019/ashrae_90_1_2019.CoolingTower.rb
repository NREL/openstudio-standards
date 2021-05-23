# A variety of cooling tower methods that are the same regardless of type.
# These methods are available to CoolingTowerSingleSpeed, CoolingTowerTwoSpeed, and CoolingTowerVariableSpeed
module ASHRAE9012019CoolingTower
  # @!group CoolingTower

  # Above this point, centrifugal fan cooling towers must meet the limits
  # of propeller or axial cooling towers instead.
  # 90.1 6.5.5.3 Limit on Centrifugal Fan Open Circuit Cooling Towers.
  # is 1,100 gallons per minute.
  #
  # @param cooling_tower [OpenStudio::Model::CoolingTowerSingleSpeed,
  # OpenStudio::Model::CoolingTowerTwoSpeed,
  # OpenStudio::Model::CoolingTowerVariableSpeed] the cooling tower
  # @return [Double] the limit, in gallons per minute.  Return nil for no limit.
  def cooling_tower_apply_minimum_power_per_flow_gpm_limit(cooling_tower)
    gpm_limit = 1100
    return gpm_limit
  end
end

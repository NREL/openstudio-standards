class ASHRAE901PRM
  # @!group FanVariableVolume

  include ASHRAE901PRMFan

  # The threhold horsepower below which part load control is not required.
  # always required for stable baseline, so threshold is zero
  #
  # @param fan_variable_volume [OpenStudio::Model::FanVariableVolume] variable volume fan object
  # @return [Double] the limit, in horsepower. Return nil for no limit by default.
  # @todo AddRef
  def fan_variable_volume_part_load_fan_power_limitation_hp_limit(fan_variable_volume)
    hp_limit = 0
    return hp_limit
  end

  
end

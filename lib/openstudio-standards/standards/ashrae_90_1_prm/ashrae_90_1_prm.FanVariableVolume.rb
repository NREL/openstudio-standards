class ASHRAE901PRM
  # @!group FanVariableVolume

  include ASHRAE901PRMFan

  # Determines whether there is a requirement to have a VSD or some other method to reduce fan power at low part load ratios.
  # Required for all VAV fans for stable baseline
  # @param fan_variable_volume [OpenStudio::Model::FanVariableVolume] variable volume fan object
  # @return [Boolean] returns true if required, false if not
  def fan_variable_volume_part_load_fan_power_limitation?(fan_variable_volume)
    part_load_control_required = true
    return part_load_control_required
  end

  # The threhold horsepower below which part load control is not required.
  # always required for stable baseline, so threshold is zero
  #
  # @param fan_variable_volume [OpenStudio::Model::FanVariableVolume] variable volume fan object
  # @return [Double] the limit, in horsepower. Return zero for no limit by default.
  def fan_variable_volume_part_load_fan_power_limitation_hp_limit(fan_variable_volume)
    hp_limit = 0
    return hp_limit
  end
end

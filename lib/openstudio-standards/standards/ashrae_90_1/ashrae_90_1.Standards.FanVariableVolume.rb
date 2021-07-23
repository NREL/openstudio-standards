class ASHRAE901 < Standard
  # @!group FanVariableVolume

  # The threhold horsepower below which part load control is not required.
  #
  # @param fan_variable_volume [OpenStudio::Model::FanVariableVolume] the fan
  # @return [Double] the limit, in horsepower. Return nil for no limit by default.
  def fan_variable_volume_part_load_fan_power_limitation_hp_limit(fan_variable_volume)
    hp_limit = nil # No minimum limit
    return hp_limit
  end

  # The threhold capacity below which part load control is not required.
  #
  # @param fan_variable_volume [OpenStudio::Model::FanVariableVolume] the fan
  # @return [Double] the limit, in Btu/hr. Return nil for no limit by default.
  def fan_variable_volume_part_load_fan_power_limitation_capacity_limit(fan_variable_volume)
    cap_limit_btu_per_hr = nil # No minimum limit
    return cap_limit_btu_per_hr
  end
end


class NECB_2011_Model < StandardsModel
  include NECBFan

  # Determines whether there is a requirement to have a
  # VSD or some other method to reduce fan power
  # at low part load ratios.
  def fan_variable_volume_part_load_fan_power_limitation?(fan_variable_volume)
    part_load_control_required = false

    return part_load_control_required
  end
end

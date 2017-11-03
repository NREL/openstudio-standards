class NECB_2011_Model < StandardsModel
  # Sets the fan pressure rise based on the Prototype buildings inputs
  # which are governed by the flow rate coming through the fan
  # and whether the fan lives inside a unit heater, PTAC, etc.
  def fan_constant_volume_apply_prototype_fan_pressure_rise(fan_constant_volume, building_type, climate_zone)
    pressure_rise_pa = 640.0
    fan_constant_volume.setPressureRise(pressure_rise_pa)
    return true
  end
  
end

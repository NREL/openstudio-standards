
# Reopen the OpenStudio class to add methods to apply standards to this object
class Standard
  include PrototypeFan

  # Sets the fan pressure rise based on the Prototype buildings inputs
  def fan_zone_exhaust_apply_prototype_fan_pressure_rise(fan_zone_exhaust)
    # All exhaust fans are assumed to have a pressure rise of
    # 0.5 in w.c. in the prototype building models.
    pressure_rise_in_h2o = 0.5

    # Set the pressure rise
    pressure_rise_pa = OpenStudio.convert(pressure_rise_in_h2o, 'inH_{2}O', 'Pa').get
    fan_zone_exhaust.setPressureRise(pressure_rise_pa)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.FanZoneExhaust', "For Prototype: #{fan_zone_exhaust.name}: Pressure Rise = #{pressure_rise_in_h2o}in w.c.")

    return true
  end
end

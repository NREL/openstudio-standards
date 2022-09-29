# A variety of fan calculation methods that are the same regardless of fan type.
# These methods are available to FanConstantVolume, FanOnOff, FanVariableVolume, and FanZoneExhaust
module ASHRAE901PRMFan
  # Determines the minimum fan motor efficiency and nominal size for a given motor bhp.
  # This should be the total brake horsepower with any desired safety factor already included.
  # This method picks the next nominal motor catgory larger than the required brake horsepower,
  # and the efficiency is based on that size.
  # For example, if the bhp = 6.3, the nominal size will be 7.5HP and the efficiency
  # for 90.1-2010 will be 91.7% from Table 10.8B.
  # This method assumes 4-pole, 1800rpm totally-enclosed fan-cooled motors.
  #
  # @param fan [OpenStudio::Model::StraightComponent] fan object, allowable types:
  #   FanConstantVolume, FanOnOff, FanVariableVolume, and FanZoneExhaust
  # @param motor_bhp [Double] motor brake horsepower (hp)
  # @return [Array<Double>] minimum motor efficiency (0.0 to 1.0), nominal horsepower
  def fan_standard_minimum_motor_efficiency_and_size(fan, motor_bhp)
    fan_motor_eff = 0.85
    nominal_hp = motor_bhp

    # Don't attempt to look up motor efficiency
    # for zero-hp fans, which may occur when there is no
    # airflow required for a particular system, typically
    # heated-only spaces with high internal gains
    # and no OA requirements such as elevator shafts.
    return [fan_motor_eff, 0] if motor_bhp == 0.0

    # Lookup the minimum motor efficiency
    motors = standards_data['motors']

    # Assuming all fan motors are 4-pole ODP
    search_criteria = {
      'template' => template,
      'number_of_poles' => 4.0,
      'type' => 'Enclosed'
    }

    # Exception for small fans, including
    # zone exhaust, fan coil, and fan powered terminals.
    # In this case, use the 0.5 HP for the lookup.
    if fan_small_fan?(fan)
      nominal_hp = 0.5
    else
      motor_properties = model_find_object(motors, search_criteria, capacity = nil, date = nil, area = nil, num_floors = nil, fan_motor_bhp = motor_bhp)
      if motor_properties.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{fan.name}, could not find motor properties using search criteria: #{search_criteria}, motor_bhp = #{motor_bhp} hp.")
        return [fan_motor_eff, nominal_hp]
      end

      # If the biggest fan motor size is hit, use the highest category efficiency
      if nominal_hp == 9999.0
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Fan', "For #{fan.name}, there is no greater nominal HP.  Use the efficiency of the largest motor category.")
        nominal_hp = motor_bhp
      end

      # Round to nearest whole HP for niceness
      if nominal_hp >= 2
        nominal_hp = nominal_hp.round
      end
    end

    # Get the efficiency based on the nominal horsepower
    motor_properties = model_find_object(motors, search_criteria, fan_motor_bhp = motor_bhp)

    if motor_properties.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{fan.name}, could not find nominal motor properties using search criteria: #{search_criteria}, motor_hp = #{nominal_hp} hp.")
      return [fan_motor_eff, nominal_hp]
    end
    fan_motor_eff = motor_properties['nominal_full_load_efficiency']
    nominal_hp = motor_properties['maximum_capacity'].round(1)

    return [fan_motor_eff, nominal_hp]
  end
end

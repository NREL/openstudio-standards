# A variety of fan calculation methods that are the same regardless of fan type.
# These methods are available to FanConstantVolume, FanOnOff, FanVariableVolume, and FanZoneExhaust
module Fan
  # @!group Fan

  # Applies the minimum motor efficiency for this fan
  # based on the motor's brake horsepower.
  def fan_apply_standard_minimum_motor_efficiency(fan, allowed_bhp)
    # Find the motor efficiency
    motor_eff, nominal_hp = fan_standard_minimum_motor_efficiency_and_size(fan, allowed_bhp)

    # Change the motor efficiency
    # but preserve the existing fan impeller
    # efficiency.
    fan_change_motor_efficiency(fan, motor_eff)

    # Calculate the total motor HP
    motor_hp = fan_motor_horsepower(fan)

    # Exception for small fans, including
    # zone exhaust, fan coil, and fan powered terminals.
    # In this case, 0.5 HP is used for the lookup.
    if fan_small_fan?(fan)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Fan', "For #{fan.name}: motor eff = #{(motor_eff * 100).round(2)}%; assumed to represent several less than 1 HP motors.")
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Fan', "For #{fan.name}: motor nameplate = #{nominal_hp}HP, motor eff = #{(motor_eff * 100).round(2)}%.")
    end

    return true
  end

  # Adjust the fan pressure rise to hit the target fan power (W).
  # Keep the fan impeller and motor efficiencies static.
  #
  # @param target_fan_power [Double] the target fan power in W
  # @return [Bool] true if successful, false if not
  def fan_adjust_pressure_rise_to_meet_fan_power(fan, target_fan_power)
    # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = 0
    dsn_air_flow_m3_per_s = if fan.autosizedMaximumFlowRate.is_initialized
                              fan.autosizedMaximumFlowRate.get
                            else
                              fan.maximumFlowRate.get
                            end

    # Get the current fan power
    current_fan_power_w = fan_fanpower(fan)

    # Get the current pressure rise (Pa)
    pressure_rise_pa = fan.pressureRise

    # Get the total fan efficiency
    fan_total_eff = fan.fanEfficiency

    # Calculate the new fan pressure rise (Pa)
    new_pressure_rise_pa = target_fan_power * fan_total_eff / dsn_air_flow_m3_per_s
    new_pressure_rise_in_h2o = OpenStudio.convert(new_pressure_rise_pa, 'Pa', 'inH_{2}O').get

    # Set the new pressure rise
    fan.setPressureRise(new_pressure_rise_pa)

    # Calculate the new power
    new_power_w = fan_fanpower(fan)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Fan', "For #{fan.name}: pressure rise = #{new_pressure_rise_in_h2o.round(1)} in w.c., power = #{fan_motor_horsepower(fan).round(2)}HP.")

    return true
  end

  # Determines the fan power (W) based on
  # flow rate, pressure rise, and total fan efficiency(impeller eff * motor eff)
  #
  # @return [Double] fan power
  #   @units Watts (W)
  def fan_fanpower(fan)
    # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = if fan.to_FanZoneExhaust.empty?
                              if fan.maximumFlowRate.is_initialized
                                fan.maximumFlowRate.get
                              elsif fan.autosizedMaximumFlowRate.is_initialized
                                fan.autosizedMaximumFlowRate.get
                              else
                                OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "The maximum flow rate for fan '#{fan.name}' was neither specified nor set to Autosize.")
                              end
                            else
                              if fan.maximumFlowRate.is_initialized
                                fan.maximumFlowRate.get
                              else
                                OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "The maximum flow rate for exhaust fan '#{fan.name}' was not specified.")
                              end
                            end

    # Get the total fan efficiency,
    # which in E+ includes both motor and
    # impeller efficiency.
    fan_total_eff = fan.fanEfficiency

    # Get the pressure rise (Pa)
    pressure_rise_pa = fan.pressureRise

    # Calculate the fan power (W)
    fan_power_w = pressure_rise_pa * dsn_air_flow_m3_per_s / fan_total_eff

    return fan_power_w
  end

  # Determines the brake horsepower of the fan
  # based on fan power and fan motor efficiency.
  #
  # @return [Double] brake horsepower
  #   @units horsepower (hp)
  def fan_brake_horsepower(fan)
    # Get the fan motor efficiency
    existing_motor_eff = 0.7
    if fan.to_FanZoneExhaust.empty?
      existing_motor_eff = fan.motorEfficiency
    end

    # Get the fan power (W)
    fan_power_w = fan_fanpower(fan)

    # Calculate the brake horsepower (bhp)
    fan_bhp = fan_power_w * existing_motor_eff / 746

    return fan_bhp
  end

  # Determines the horsepower of the fan
  # motor, including motor efficiency and
  # fan impeller efficiency.
  #
  # @return [Double] horsepower
  def fan_motor_horsepower(fan)
    # Get the fan power
    fan_power_w = fan_fanpower(fan)

    # Convert to HP
    fan_hp = fan_power_w / 745.7 # 745.7 W/HP

    return fan_hp
  end

  # Changes the fan motor efficiency and also the fan total efficiency
  # at the same time, preserving the impeller efficiency.
  #
  # @param motor_eff [Double] motor efficiency (0.0 to 1.0)
  def fan_change_motor_efficiency(fan, motor_eff)
    # Calculate the existing impeller efficiency
    existing_motor_eff = 0.7
    if fan.to_FanZoneExhaust.empty?
      existing_motor_eff = fan.motorEfficiency
    end
    existing_total_eff = fan.fanEfficiency
    existing_impeller_eff = existing_total_eff / existing_motor_eff

    # Calculate the new total efficiency
    new_total_eff = motor_eff * existing_impeller_eff

    # Set the revised motor and total fan efficiencies
    if fan.to_FanZoneExhaust.is_initialized
      fan.setFanEfficiency(new_total_eff)
    else
      fan.setFanEfficiency(new_total_eff)
      fan.setMotorEfficiency(motor_eff)
    end
  end

  # Changes the fan impeller efficiency and also the fan total efficiency
  # at the same time, preserving the motor efficiency.
  #
  # @param impeller_eff [Double] impeller efficiency (0.0 to 1.0)
  def fan_change_impeller_efficiency(fan, impeller_eff)
    # Get the existing motor efficiency
    existing_motor_eff = 0.7
    if fan.to_FanZoneExhaust.empty?
      existing_motor_eff = fan.motorEfficiency
    end

    # Calculate the new total efficiency
    new_total_eff = existing_motor_eff * impeller_eff

    # Set the revised motor and total fan efficiencies
    fan.setFanEfficiency(new_total_eff)
  end

  # Determines the baseline fan impeller efficiency
  # based on the specified fan type.
  #
  # @return [Double] impeller efficiency (0.0 to 1.0)
  # @todo Add fan type to data model and modify this method
  def fan_baseline_impeller_efficiency(fan)
    # Assume that the fan efficiency is 65% for normal fans
    # and 55% for small fans (like exhaust fans).
    # TODO add fan type to fan data model
    # and infer impeller efficiency from that?
    # or do we always assume a certain type of
    # fan impeller for the baseline system?
    # TODO check COMNET and T24 ACM and PNNL 90.1 doc
    fan_impeller_eff = 0.65

    if fan_small_fan?(fan)
      fan_impeller_eff = 0.55
    end

    return fan_impeller_eff
  end

  # Determines the minimum fan motor efficiency and nominal size
  # for a given motor bhp.  This should be the total brake horsepower with
  # any desired safety factor already included.  This method picks
  # the next nominal motor catgory larger than the required brake
  # horsepower, and the efficiency is based on that size.  For example,
  # if the bhp = 6.3, the nominal size will be 7.5HP and the efficiency
  # for 90.1-2010 will be 91.7% from Table 10.8B.  This method assumes
  # 4-pole, 1800rpm totally-enclosed fan-cooled motors.
  #
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
      motor_properties = model_find_object(motors, search_criteria, motor_bhp)
      if motor_properties.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{fan.name}, could not find motor properties using search criteria: #{search_criteria}, motor_bhp = #{motor_bhp} hp.")
        return [fan_motor_eff, nominal_hp]
      end

      nominal_hp = motor_properties['maximum_capacity'].to_f.round(1)
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
    # Add 0.01 hp to avoid search errors.
    motor_properties = model_find_object(motors, search_criteria, nominal_hp + 0.01)

    if motor_properties.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{fan.name}, could not find nominal motor properties using search criteria: #{search_criteria}, motor_hp = #{nominal_hp} hp.")
      return [fan_motor_eff, nominal_hp]
    end
    fan_motor_eff = motor_properties['nominal_full_load_efficiency']

    return [fan_motor_eff, nominal_hp]
  end

  # Zone exhaust fans, fan coil unit fans,
  # and powered VAV terminal fans all count
  # as small fans and get different impeller efficiencies
  # and motor efficiencies than other fans
  # @return [Bool] returns true if it is a small fan, false if not
  def fan_small_fan?(fan)
    is_small = false

    # Exhaust fan
    if fan.to_FanZoneExhaust.is_initialized
      is_small = true
    # Fan coil unit, unit heater, PTAC, PTHP, VRF terminals, WSHP, ERV
    elsif fan.containingZoneHVACComponent.is_initialized
      zone_hvac = fan.containingZoneHVACComponent.get
      if zone_hvac.to_ZoneHVACFourPipeFanCoil.is_initialized
        is_small = true
      # elsif zone_hvac.to_ZoneHVACUnitHeater.is_initialized
      #   is_small = true
      elsif zone_hvac.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
        is_small = true
      elsif zone_hvac.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
        is_small = true
      elsif zone_hvac.to_ZoneHVACTerminalUnitVariableRefrigerantFlow.is_initialized
        is_small = true
      elsif zone_hvac.to_ZoneHVACWaterToAirHeatPump.is_initialized
        is_small = true
      elsif zone_hvac.to_ZoneHVACEnergyRecoveryVentilator.is_initialized
        is_small = true
      end
    # Powered VAV terminal
    elsif fan.containingHVACComponent.is_initialized
      zone_hvac = fan.containingHVACComponent.get
      if zone_hvac.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized || zone_hvac.to_AirTerminalSingleDuctSeriesPIUReheat.is_initialized
        is_small = true
      end
    end

    return is_small
  end

  # Find the actual rated fan power per flow (W/CFM)
  # by querying the sql file
  #
  # @return [Double] rated power consumption per flow
  #   @units Watts per CFM (W*min/ft^3)
  def fan_rated_w_per_cfm(fan)
    # Get design power (whether autosized or hard-sized)
    rated_power_w = fan.model.getAutosizedValueFromEquipmentSummary(fan, 'Fans', 'Rated Electric Power', 'W')
    if rated_power_w.is_initialized
      rated_power_w = rated_power_w.get
    else
      rated_power_w = fan_fanpower(fan)
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Fan', "For #{fan.name}, could not find rated fan power from Equipment Summary. Will calculate it based on current pressure rise and total fan efficiency")
    end

    if fan.autosizedMaximumFlowRate.is_initialized
      max_m3_per_s = fan.autosizedMaximumFlowRate.get
    elsif fan.maximumFlowRate.is_initialized
      max_m3_per_s = fan.ratedFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{fan.name}, could not find fan Maximum Flow Rate, cannot determine w per cfm correctly.")
      return false
    end

    rated_w_per_m3s = rated_power_w / max_m3_per_s

    rated_w_per_cfm = OpenStudio.convert(rated_w_per_m3s, 'W*s/m^3', 'W*min/ft^3').get

    return rated_w_per_cfm
  end
end

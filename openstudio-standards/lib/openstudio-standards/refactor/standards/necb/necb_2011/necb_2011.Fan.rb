
# A variety of fan calculation methods that are the same regardless of fan type.
# These methods are available to FanConstantVolume, FanOnOff, FanVariableVolume, and FanZoneExhaust
# open the class to add methods to return sizing values
NECB_2011_Model.class_eval do
  # Determines the baseline fan impeller efficiency
  # based on the specified fan type.
  #
  # @return [Double] impeller efficiency (0.0 to 1.0)
  # @todo Add fan type to data model and modify this method
  def fan_baseline_impeller_efficiency(fan)
    # Assume that the fan efficiency is 65% for normal fans
    # TODO add fan type to fan data model
    # and infer impeller efficiency from that?
    # or do we always assume a certain type of
    # fan impeller for the baseline system?
    # TODO check COMNET and T24 ACM and PNNL 90.1 doc
    fan_impeller_eff = 0.65

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
    motors = $os_standards['motors']

    # Assuming all fan motors are 4-pole ODP
    instvartemplate_mod = instvartemplate.dup
    if fan.class.name == 'OpenStudio::Model::FanConstantVolume'
      instvartemplate_mod += '-CONSTANT'
    elsif fan.class.name == 'OpenStudio::Model::FanVariableVolume'
      instvartemplate_mod += '-VARIABLE'
      # 0.909 corrects for 10% over sizing implemented upstream
      # 0.7457 is to convert from bhp to kW
      fan_power_kw = 0.909 * 0.7457 * motor_bhp
      power_vs_flow_curve_name = if fan_power_kw >= 25.0
                                   'VarVolFan-FCInletVanes-NECB2011-FPLR'
                                 elsif fan_power_kw >= 7.5 && fan_power_kw < 25
                                   'VarVolFan-AFBIInletVanes-NECB2011-FPLR'
                                 else
                                   'VarVolFan-AFBIFanCurve-NECB2011-FPLR'
                                 end
      power_vs_flow_curve = model_add_curve(fan.model, power_vs_flow_curve_name)
      fan.setFanPowerMinimumFlowRateInputMethod('Fraction')
      fan.setFanPowerCoefficient5(0.0)
      fan.setFanPowerMinimumFlowFraction(power_vs_flow_curve.minimumValueofx)
      fan.setFanPowerCoefficient1(power_vs_flow_curve.coefficient1Constant)
      fan.setFanPowerCoefficient2(power_vs_flow_curve.coefficient2x)
      fan.setFanPowerCoefficient3(power_vs_flow_curve.coefficient3xPOW2)
      fan.setFanPowerCoefficient4(power_vs_flow_curve.coefficient4xPOW3)
    else
      raise("")
    end

    search_criteria = {
      'template' => instvartemplate_mod,
      'number_of_poles' => 4.0,
      'type' => 'Enclosed'
    }

    # Exception for small fans, including
    # zone exhaust, fan coil, and fan powered terminals.
    # In this case, use the 0.5 HP for the lookup.
    if fan_small_fan?(fan) 
      nominal_hp = 0.5
    else
      motor_properties = model_find_object( motors, search_criteria, motor_bhp)
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
    motor_properties = model_find_object( motors, search_criteria, nominal_hp + 0.01)
    if motor_properties.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{fan.name}, could not find nominal motor properties using search criteria: #{search_criteria}, motor_hp = #{nominal_hp} hp.")
      return [fan_motor_eff, nominal_hp]
    end
    fan_motor_eff = motor_properties['nominal_full_load_efficiency']

    return [fan_motor_eff, nominal_hp]
  end
end

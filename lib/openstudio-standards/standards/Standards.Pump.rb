# A variety of pump calculation methods that are the same regardless of pump type.
# These methods are available to PumpConstantSpeed, PumpVariableSpeed
module Pump
  # @!group Pump

  # Set the pressure rise that cooresponds to the
  # target power per flow number, given the standard
  # pump efficiency and the default EnergyPlus pump impeller efficiency
  # of 0.78.
  #
  # @param target_w_per_gpm [Double] the target power per flow, in W/gpm
  # @return [Bool] return true if successful, false if not
  # @author jmarrec
  def pump_apply_prm_pressure_rise_and_motor_efficiency(pump, target_w_per_gpm)
    # Eplus assumes an impeller efficiency of 0.78 to determine the total efficiency
    # http://bigladdersoftware.com/epx/docs/8-4/engineering-reference/component-sizing.html#pump-sizing
    # Rated_Power_Use = Rated_Volume_Flow_Rate * Rated_Pump_Head / Total_Efficiency
    # Rated_Power_Use / Rated_Volume_Flow_Rate =  Rated_Pump_Head / Total_Efficiency
    # Total_Efficiency = Motor_Efficiency * Impeler_Efficiency
    impeller_efficiency = 0.78

    # Get flow rate (whether autosized or hard-sized)
    flow_m3_per_s = 0
    flow_m3_per_s = if pump.to_PumpVariableSpeed.is_initialized || pump.to_PumpConstantSpeed.is_initialized
                      if pump.autosizedRatedFlowRate.is_initialized
                        pump.autosizedRatedFlowRate.get
                      else
                        pump.ratedFlowRate.get
                      end
                    elsif pump.to_HeaderedPumpsVariableSpeed.is_initialized || pump.to_HeaderedPumpsConstantSpeed.is_initialized
                      if pump.autosizedTotalRatedFlowRate.is_initialized
                        pump.autosizedTotalRatedFlowRate.get / pump.numberofPumpsinBank
                      else
                        pump.totalRatedFlowRate.get / pump.numberofPumpsinBank
                      end
                    end

    flow_gpm = OpenStudio.convert(flow_m3_per_s, 'm^3/s', 'gal/min').get

    # Calculate the target total pump motor power consumption
    target_motor_power_cons_w = target_w_per_gpm * flow_gpm
    target_motor_power_cons_hp = target_motor_power_cons_w / 745.7 # 745.7 W/HP

    # Find the motor efficiency using total power consumption
    # Note that this hp is ~5-10% high because it is being looked
    # up based on the motor consumption, which is always actually higher
    # than the brake horsepower.  This will bound the possible motor efficiency
    # values.  If a motor is just above a nominal size, and the next size
    # down has a lower efficiency value, later motor efficiency setting
    # methods can mess up the W/gpm.  All this nonsense avoids that.
    mot_eff_hi_end, nom_hp_hi_end = pump_standard_minimum_motor_efficiency_and_size(pump, target_motor_power_cons_hp)

    # Calculate the actual brake horsepower using this efficiency
    target_motor_bhp = target_motor_power_cons_hp * mot_eff_hi_end

    # Find the motor efficiency using actual bhp
    mot_eff_lo_end, nom_hp_lo_end = pump_standard_minimum_motor_efficiency_and_size(pump, target_motor_bhp)

    # If the efficiency drops you down into a lower band with
    # a lower efficiency value, use that for the motor efficiency.
    motor_efficiency = [mot_eff_lo_end, mot_eff_hi_end].min
    nominal_hp = [nom_hp_lo_end, nom_hp_hi_end].min

    # Calculate the brake horsepower that was assumed
    target_brake_power_hp = target_motor_power_cons_hp * motor_efficiency

    # Change the motor efficiency
    pump.setMotorEfficiency(motor_efficiency)

    total_efficiency = impeller_efficiency * motor_efficiency

    desired_power_per_m3_s = OpenStudio.convert(target_w_per_gpm, 'W*min/gal', 'W*s/m^3').get

    pressure_rise_pa = desired_power_per_m3_s * total_efficiency
    pressure_rise_ft_h2o = OpenStudio.convert(pressure_rise_pa, 'Pa', 'ftH_{2}O').get

    # Change pressure rise
    pump.setRatedPumpHead(pressure_rise_pa)

    # Report
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "For #{pump.name}: motor nameplate = #{nominal_hp}HP, motor eff = #{(motor_efficiency * 100).round(2)}%; #{target_w_per_gpm.round} W/gpm translates to a pressure rise of #{pressure_rise_ft_h2o.round(2)} ftH2O.")

    # Calculate the W/gpm for verification
    calculated_w = pump_pumppower(pump)

    calculated_w_per_gpm = calculated_w / flow_gpm

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Pump', "For #{pump.name}: calculated W/gpm = #{calculated_w_per_gpm.round(1)}.")

    return true
  end

  # Applies the minimum motor efficiency for this pump
  # based on the motor's brake horsepower.
  def pump_apply_standard_minimum_motor_efficiency(pump)
    # Get the horsepower
    bhp = pump_brake_horsepower(pump)

    # Find the motor efficiency
    motor_eff, nominal_hp = pump_standard_minimum_motor_efficiency_and_size(pump, bhp)

    # Change the motor efficiency
    pump.setMotorEfficiency(motor_eff)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "For #{pump.name}: brake hp = #{bhp.round(2)}HP, motor nameplate = #{nominal_hp.round(2)}HP, motor eff = #{(motor_eff * 100).round(2)}%.")

    return true
  end

  # Determines the minimum pump motor efficiency and nominal size
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
  def pump_standard_minimum_motor_efficiency_and_size(pump, motor_bhp)
    motor_eff = 0.85
    nominal_hp = motor_bhp

    # Don't attempt to look up motor efficiency
    # for zero-hp pumps (required for circulation-pump-free
    # service water heating systems).
    return [1.0, 0] if motor_bhp == 0.0

    # Lookup the minimum motor efficiency
    motors = standards_data['motors']

    # Assuming all pump motors are 4-pole ODP
    search_criteria = {
      'template' => template,
      'number_of_poles' => 4.0,
      'type' => 'Enclosed'
    }

    motor_properties = model_find_object(motors, search_criteria, motor_bhp)
    if motor_properties.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Pump', "For #{pump.name}, could not find motor properties using search criteria: #{search_criteria}, motor_bhp = #{motor_bhp} hp.")
      return [motor_eff, nominal_hp]
    end

    motor_eff = motor_properties['nominal_full_load_efficiency']
    nominal_hp = motor_properties['maximum_capacity'].to_f.round(1)
    # Round to nearest whole HP for niceness
    if nominal_hp >= 2
      nominal_hp = nominal_hp.round
    end

    # Get the efficiency based on the nominal horsepower
    # Add 0.01 hp to avoid search errors.
    motor_properties = model_find_object(motors, search_criteria, nominal_hp + 0.01)
    if motor_properties.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{pump.name}, could not find nominal motor properties using search criteria: #{search_criteria}, motor_hp = #{nominal_hp} hp.")
      return [motor_eff, nominal_hp]
    end
    motor_eff = motor_properties['nominal_full_load_efficiency']

    return [motor_eff, nominal_hp]
  end

  # Determines the pump power (W) based on
  # flow rate, pressure rise, and total pump efficiency(impeller eff * motor eff).
  # Uses the E+ default assumption of 0.78 impeller efficiency.
  #
  # @return [Double] pump power
  #   @units Watts (W)
  def pump_pumppower(pump)
    # Get flow rate (whether autosized or hard-sized)
    flow_m3_per_s = 0
    flow_m3_per_s = if pump.to_PumpVariableSpeed.is_initialized || pump.to_PumpConstantSpeed.is_initialized
                      if pump.autosizedRatedFlowRate.is_initialized
                        pump.autosizedRatedFlowRate.get
                      else
                        pump.ratedFlowRate.get
                      end
                    elsif pump.to_HeaderedPumpsVariableSpeed.is_initialized || pump.to_HeaderedPumpsConstantSpeed.is_initialized
                      if pump.autosizedTotalRatedFlowRate.is_initialized
                        pump.autosizedTotalRatedFlowRate.get
                      else
                        pump.totalRatedFlowRate.get
                      end
                    end

    # E+ default impeller efficiency
    # http://bigladdersoftware.com/epx/docs/8-4/engineering-reference/component-sizing.html#pump-sizing
    impeller_eff = 0.78

    # Get the motor efficiency
    motor_eff = pump.motorEfficiency

    # Calculate the total efficiency
    # which includes both motor and
    # impeller efficiency.
    pump_total_eff = impeller_eff * motor_eff

    # Get the pressure rise (Pa)
    pressure_rise_pa = pump.ratedPumpHead

    # Calculate the pump power (W)
    pump_power_w = pressure_rise_pa * flow_m3_per_s / pump_total_eff

    return pump_power_w
  end

  # Determines the brake horsepower of the pump
  # based on flow rate, pressure rise, and impeller efficiency.
  #
  # @return [Double] brake horsepower
  #   @units horsepower (hp)
  def pump_brake_horsepower(pump)
    # Get flow rate (whether autosized or hard-sized)
    # Get flow rate (whether autosized or hard-sized)
    flow_m3_per_s = 0
    flow_m3_per_s = if pump.to_PumpVariableSpeed.is_initialized || pump.to_PumpConstantSpeed.is_initialized
                      if pump.autosizedRatedFlowRate.is_initialized
                        pump.autosizedRatedFlowRate.get
                      else
                        pump.ratedFlowRate.get
                      end
                    elsif pump.to_HeaderedPumpsVariableSpeed.is_initialized || pump.to_HeaderedPumpsConstantSpeed.is_initialized
                      if pump.autosizedTotalRatedFlowRate.is_initialized
                        pump.autosizedTotalRatedFlowRate.get
                      else
                        pump.totalRatedFlowRate.get
                      end
                    end

    # E+ default impeller efficiency
    # http://bigladdersoftware.com/epx/docs/8-4/engineering-reference/component-sizing.html#pump-sizing
    impeller_eff = 0.78

    # Get the pressure rise (Pa)
    pressure_rise_pa = pump.ratedPumpHead

    # Calculate the pump power (W)
    pump_power_w = pressure_rise_pa * flow_m3_per_s / impeller_eff

    # Convert to HP
    pump_power_hp = pump_power_w / 745.7 # 745.7 W/HP

    return pump_power_hp
  end

  # Determines the horsepower of the pump
  # motor, including motor efficiency and
  # pump impeller efficiency.
  #
  # @return [Double] horsepower
  def pump_motor_horsepower(pump)
    # Get the pump power
    pump_power_w = pump_pumppower(pump)

    # Convert to HP
    pump_hp = pump_power_w / 745.7 # 745.7 W/HP

    return pump_hp
  end

  # Determines the rated watts per GPM of the pump
  #
  # @return [Double] rated power consumption per flow
  #   @units Watts per GPM (W*min/gal)
  def pump_rated_w_per_gpm(pump)
    # Get design power (whether autosized or hard-sized)
    rated_power_w = 0
    if pump.autosizedRatedPowerConsumption.is_initialized
      rated_power_w = pump.autosizedRatedPowerConsumption.get
    elsif pump.ratedPowerConsumption.is_initialized
      rated_power_w = pump.ratedPowerConsumption.get
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Pump', "For #{pump.name}, could not find rated pump power consumption, cannot determine w per gpm correctly.")
      return 0.0
    end

    rated_m3_per_s = 0
    if pump.to_PumpVariableSpeed.is_initialized || pump.to_PumpConstantSpeed.is_initialized
      if pump.ratedFlowRate.is_initialized
        rated_m3_per_s = pump.ratedFlowRate.get
      elsif pump.autosizedRatedFlowRate.is_initialized
        rated_m3_per_s = pump.autosizedRatedFlowRate.get
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Pump', "For #{pump.name}, could not find rated pump Flow Rate, cannot determine w per gpm correctly.")
        return 0.0
      end
    elsif pump.to_HeaderedPumpsVariableSpeed.is_initialized || pump.to_HeaderedPumpsConstantSpeed.is_initialized
      if pump.totalRatedFlowRate.is_initialized
        rated_m3_per_s = pump.totalRatedFlowRate.get
      elsif pump.autosizedTotalRatedFlowRate.is_initialized
        rated_m3_per_s = pump.autosizedTotalRatedFlowRate.get
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Pump', "For #{pump.name}, could not find rated pump Flow Rate, cannot determine w per gpm correctly.")
        return 0.0
      end
    end

    rated_w_per_m3s = rated_power_w / rated_m3_per_s

    rated_w_per_gpm = OpenStudio.convert(rated_w_per_m3s, 'W*s/m^3', 'W*min/gal').get

    return rated_w_per_gpm
  end
end

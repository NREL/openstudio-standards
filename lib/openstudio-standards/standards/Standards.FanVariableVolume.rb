class Standard
  # @!group FanVariableVolume

  include Fan

  # Modify the fan curve coefficients to reflect a specific type of control.
  #
  # @param control_type [String] valid choices are:
  # Multi Zone VAV with discharge dampers,
  # Multi Zone VAV with VSD and SP Setpoint Reset,
  # Multi Zone VAV with AF or BI Riding Curve,
  # Multi Zone VAV with AF or BI with Inlet Vanes,
  # Multi Zone VAV with FC Riding Curve,
  # Multi Zone VAV with FC with Inlet Vanes,
  # Multi Zone VAV with Vane-axial with Variable Pitch Blades,
  # Multi Zone VAV with VSD and Fixed SP Setpoint,
  # Multi Zone VAV with VSD and Static Pressure Reset,
  # Single Zone VAV Fan
  def fan_variable_volume_set_control_type(fan_variable_volume, control_type)
    # Determine the coefficients
    coeff_a = nil
    coeff_b = nil
    coeff_c = nil
    coeff_d = nil
    min_pct_pwr = nil
    case control_type

    # add 'Multi Zone VAV with discharge dampers' and change the minimum fan power fraction of "Multi Zone VAV with VSD and Static Pressure Reset"
    when 'Multi Zone VAV with discharge dampers'
      coeff_a = 0.18984763
      coeff_b = 0.31447014
      coeff_c = 0.49568211
      coeff_d = 0.0
      min_pct_pwr = 0.25
    when 'Multi Zone VAV with VSD and SP Setpoint Reset'
      coeff_a = 0.04076
      coeff_b = 0.0881
      coeff_c = -0.0729
      coeff_d = 0.9437
      min_pct_pwr = 0.25
    when 'Multi Zone VAV with AF or BI Riding Curve'
      coeff_a = 0.1631
      coeff_b = 1.5901
      coeff_c = -0.8817
      coeff_d = 0.1281
      min_pct_pwr = 0.7
    when 'Multi Zone VAV with AF or BI with Inlet Vanes'
      coeff_a = 0.9977
      coeff_b = -0.659
      coeff_c = 0.9547
      coeff_d = -0.2936
      min_pct_pwr = 0.5
    when 'Multi Zone VAV with FC Riding Curve'
      coeff_a = 0.1224
      coeff_b = 0.612
      coeff_c = 0.5983
      coeff_d = -0.3334
      min_pct_pwr = 0.3
    when 'Multi Zone VAV with FC with Inlet Vanes'
      coeff_a = 0.3038
      coeff_b = -0.7608
      coeff_c = 2.2729
      coeff_d = -0.8169
      min_pct_pwr = 0.3
    when 'Multi Zone VAV with Vane-axial with Variable Pitch Blades'
      coeff_a = 0.1639
      coeff_b = -0.4016
      coeff_c = 1.9909
      coeff_d = -0.7541
      min_pct_pwr = 0.2
    when 'Multi Zone VAV with VSD and Fixed SP Setpoint'
      coeff_a = 0.0013
      coeff_b = 0.1470
      coeff_c = 0.9506
      coeff_d = -0.0998
      min_pct_pwr = 0.2
    when 'Multi Zone VAV with VSD and Static Pressure Reset'
      coeff_a = 0.04076
      coeff_b = 0.0881
      coeff_c = -0.0729
      coeff_d = 0.9437
      min_pct_pwr = 0.1
    when 'Single Zone VAV Fan'
      coeff_a = 0.027828
      coeff_b = 0.026583
      coeff_c = -0.087069
      coeff_d = 1.030920
      min_pct_pwr = 0.1
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.FanVariableVolume', "Fan control type '#{control_type}' not recognized, fan power coefficients will not be changed.")
      return false
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.FanVariableVolume', "For #{fan_variable_volume.name}: Set fan curve coefficients to reflect control type of '#{control_type}'.")

    # Set the coefficients
    fan_variable_volume.setFanPowerCoefficient1(coeff_a)
    fan_variable_volume.setFanPowerCoefficient2(coeff_b)
    fan_variable_volume.setFanPowerCoefficient3(coeff_c)
    fan_variable_volume.setFanPowerCoefficient4(coeff_d)

    # Set the fan minimum power
    fan_variable_volume.setFanPowerMinimumFlowRateInputMethod('Fraction')
    fan_variable_volume.setFanPowerMinimumFlowFraction(min_pct_pwr)

    # Append the control type to the fan name
    # self.setName("#{self.name} #{control_type}")
  end

  # Determines whether there is a requirement to have a
  # VSD or some other method to reduce fan power
  # at low part load ratios.
  def fan_variable_volume_part_load_fan_power_limitation?(fan_variable_volume)
    part_load_control_required = false

    # Check if the fan is on a multizone or single zone system.
    # If not on an AirLoop (for example, in unitary system or zone equipment), assumed to be a single zone fan
    mz_fan = false
    if fan_variable_volume.airLoopHVAC.is_initialized
      air_loop = fan_variable_volume.airLoopHVAC.get
      mz_fan = air_loop_hvac_multizone_vav_system?(air_loop)
    end

    # No part load fan power control is required for single zone VAV systems
    unless mz_fan
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.FanVariableVolume', "For #{fan_variable_volume.name}: No part load fan power control is required for single zone VAV systems.")
      return part_load_control_required
    end

    # Determine the motor and capacity size limits
    hp_limit = fan_variable_volume_part_load_fan_power_limitation_hp_limit(fan_variable_volume)
    cap_limit_btu_per_hr = fan_variable_volume_part_load_fan_power_limitation_capacity_limit(fan_variable_volume)

    # Check against limits
    if hp_limit && cap_limit_btu_per_hr
      air_loop = fan_variable_volume.airLoopHVAC
      unless air_loop.is_initialized
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.FanVariableVolume', "For #{fan_variable_volume.name}: Could not find the air loop to get cooling capacity for determining part load fan power control requirement.")
        return part_load_control_required
      end
      air_loop = air_loop.get
      clg_cap_w = air_loop_hvac_total_cooling_capacity(air_loop)
      clg_cap_btu_per_hr = OpenStudio.convert(clg_cap_w, 'W', 'Btu/hr').get
      fan_hp = fan_motor_horsepower(fan_variable_volume)
      if fan_hp >= hp_limit && clg_cap_btu_per_hr >= cap_limit_btu_per_hr
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.FanVariableVolume', "For #{fan_variable_volume.name}: part load fan power control is required for #{fan_hp.round(1)} HP fan, #{clg_cap_btu_per_hr.round} Btu/hr cooling capacity.")
        part_load_control_required = true
      end
    elsif hp_limit
      fan_hp = fan_motor_horsepower(fan_variable_volume)
      if fan_hp >= hp_limit
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.FanVariableVolume', "For #{fan_variable_volume.name}: Part load fan power control is required for #{fan_hp.round(1)} HP fan.")
        part_load_control_required = true
      end
    end

    return part_load_control_required
  end

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

  # Determine if the cooling system is DX, CHW, evaporative, or a mixture.
  # @return [String] the cooling system type.  Possible options are:
  # dx, chw, evaporative, mixed, unknown.
  def fan_variable_volume_cooling_system_type(fan_variable_volume)
    clg_sys_type = 'unknown'

    # Get the air loop this fan is connected to
    air_loop = fan_variable_volume.airLoopHVAC
    return clg_sys_type unless air_loop.is_initialized

    air_loop = air_loop.get

    # Check the types of coils on the AirLoopHVAC
    has_dx = false
    has_chw = false
    has_evap = false
    air_loop.supplyComponents.each do |sc|
      # CoilCoolingDXSingleSpeed
      if sc.to_CoilCoolingDXSingleSpeed.is_initialized
        has_dx = true
      # CoilCoolingDXTwoSpeed
      elsif sc.to_CoilCoolingDXTwoSpeed.is_initialized
        has_dx = true
      # CoilCoolingMultiSpeed
      elsif sc.to_CoilCoolingDXMultiSpeed.is_initialized
        has_dx = true
      # CoilCoolingWater
      elsif sc.to_CoilCoolingWater.is_initialized
        has_chw = true
      # CoilCoolingWaterToAirHeatPumpEquationFit
      elsif sc.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
        has_dx = true
      # UnitarySystem
      elsif sc.to_AirLoopHVACUnitarySystem.is_initialized
        unitary = sc.to_AirLoopHVACUnitarySystem.get
        if unitary.coolingCoil.is_initialized
          clg_coil = unitary.coolingCoil.get
          # CoilCoolingDXSingleSpeed
          if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
            has_dx = true
          # CoilCoolingDXTwoSpeed
          elsif clg_coil.to_CoilCoolingDXTwoSpeed.is_initialized
            has_dx = true
          # CoilCoolingWater
          elsif clg_coil.to_CoilCoolingWater.is_initialized
            has_chw = true
          # CoilCoolingWaterToAirHeatPumpEquationFit
          elsif clg_coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
            has_dx = true
          end
        end
      # UnitaryHeatPumpAirToAir
      elsif sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
        unitary = sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        clg_coil = unitary.coolingCoil
        # CoilCoolingDXSingleSpeed
        if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
          has_dx = true
        # CoilCoolingDXTwoSpeed
        elsif clg_coil.to_CoilCoolingDXTwoSpeed.is_initialized
          has_dx = true
        # CoilCoolingWater
        elsif clg_coil.to_CoilCoolingWater.is_initialized
          has_chw = true
        end
      # EvaporativeCoolerDirectResearchSpecial
      elsif sc.to_EvaporativeCoolerDirectResearchSpecial.is_initialized
        has_evap = true
      # EvaporativeCoolerIndirectResearchSpecial
      elsif sc.to_EvaporativeCoolerIndirectResearchSpecial.is_initialized
        has_evap = true
      elsif sc.to_CoilCoolingCooledBeam.is_initialized ||
            sc.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized ||
            sc.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized ||
            sc.to_AirLoopHVACUnitarySystem.is_initialized
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.FanVariableVolume', "#{air_loop.name} has a cooling coil named #{sc.name}, whose type is not yet covered by cooling system type checks.")
      end
    end

    # Determine the type
    if (has_chw && has_dx && has_evap) ||
       (has_chw && has_dx) ||
       (has_chw && has_evap) ||
       (has_dx && has_evap)
      clg_sys_type = 'mixed'
    elsif has_chw
      clg_sys_type = 'chw'
    elsif has_dx
      clg_sys_type = 'dx'
    elsif has_evap
      clg_sys_type = 'evap'
    end

    return clg_sys_type
  end
end

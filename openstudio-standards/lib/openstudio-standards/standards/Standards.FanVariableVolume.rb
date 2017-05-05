
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::FanVariableVolume
  include Fan

  def set_control_type(control_type)
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

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.FanVariableVolume', "For #{name}: Set fan curve coefficients to reflect control type of '#{control_type}'.")

    # Set the coefficients
    setFanPowerCoefficient1(coeff_a)
    setFanPowerCoefficient2(coeff_b)
    setFanPowerCoefficient3(coeff_c)
    setFanPowerCoefficient4(coeff_d)

    # Set the fan minimum power
    setFanPowerMinimumFlowRateInputMethod('Fraction')
    setFanPowerMinimumFlowFraction(min_pct_pwr)

    # Append the control type to the fan name
    # self.setName("#{self.name} #{control_type}")
  end

  # Determines whether there is a requirement to have a
  # VSD or some other method to reduce fan power
  # at low part load ratios.
  def part_load_fan_power_limitation?(template)
     part_load_control_required = false

    # Not required by the old vintages
    if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004' || template == 'NECB 2011'
      return part_load_control_required
    end

	# Check if the fan is on a multizone or single zone system.
	# If not on an AirLoop (for example, in unitary system or zone equipment), assumed to be a single zone fan
	mz_fan = false 
	if self.airLoopHVAC.is_initialized
	  air_loop = self.airLoopHVAC.get
      mz_fan = air_loop.multizone_vav_system?
	end
	OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.FanVariableVolume', "this fan is on a multizone vav system: #{mz_fan}.")
	 
	if mz_fan
		# Determine the motor size limit
		# for 15 | 10 nameplate HP threshold are equivalent to motors with input powers of 9.9 | 7.54  HP (TSD)	
		# for 90.1-2013, table 6.5.3.2.1: the cooling capacity threshold is 75000 instead of 110000 as of 1/1/2014 and the fan motor size for chiller-water and evalporative cooling is 0.25 hp as of 1/1/2014 instead of 5 hp
		hp_limit = nil # No minimum limit
		cap_limit_btu_per_hr = nil # No minimum limit
		case template
		when '90.1-2004'
		  hp_limit = 9.9
		when '90.1-2007', '90.1-2010'
		  hp_limit = 7.54
		when '90.1-2013'
		  case cooling_system_type
		  when 'dx'
			hp_limit = 0.0
			cap_limit_btu_per_hr = 110_000
		  when 'chw'
			hp_limit = 0.25
		  when 'evap'
			hp_limit = 0.25
		  else
			hp_limit = 9999.9 # No requirement
		  end
		end

		# Check against limits
		if hp_limit && cap_limit_btu_per_hr
		  air_loop = airLoopHVAC
		  unless air_loop.is_initialized
			OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{name}: Could not find the air loop to get cooling capacity for determining part load fan power control requirement.")
			return part_load_control_required
		  end
		  air_loop = air_loop.get
		  clg_cap_w = air_loop.total_cooling_capacity
		  clg_cap_btu_per_hr = OpenStudio.convert(clg_cap_w, 'W', 'Btu/hr').get
		  fan_hp = motor_horsepower
		  if fan_hp >= hp_limit && clg_cap_btu_per_hr >= cap_limit_btu_per_hr
			OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{name}: part load fan power control is required for #{fan_hp.round(1)} HP fan, #{clg_cap_btu_per_hr.round} Btu/hr cooling capacity.")
			part_load_control_required = true
		  end             
		elsif hp_limit
		  fan_hp = motor_horsepower
		  if fan_hp >= hp_limit
			OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{name}: Part load fan power control is required for #{fan_hp.round(1)} HP fan.")
			part_load_control_required = true
		  end
		end
    else
	     OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.FanVariableVolume', "Is this fan on a multizone vav system: #{mz_fan}: No Part load fan power control is required for single zone VAV")
	end
    return part_load_control_required
  end

  # Determine if the cooling system is DX, CHW, evaporative, or a mixture.
  # @return [String] the cooling system type.  Possible options are:
  # dx, chw, evaporative, mixed, unknown.
  def cooling_system_type
    clg_sys_type = 'unknown'

    # Get the air loop this fan is connected to
    air_loop = airLoopHVAC
    unless air_loop.is_initialized
      return clg_sys_type
    end
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
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "#{air_loop.name} has a cooling coil named #{sc.name}, whose type is not yet covered by cooling system type checks.")
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

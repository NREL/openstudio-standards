
class Standard
  # @!group AirLoopHVAC

  # Apply multizone vav outdoor air method and
  # adjust multizone VAV damper positions
  # to achieve a system minimum ventilation effectiveness
  # of 0.6 per PNNL.  Hard-size the resulting min OA
  # into the sizing:system object.
  #
  # return [Bool] returns true if successful, false if not
  # @todo move building-type-specific code to Prototype classes
  def air_loop_hvac_apply_multizone_vav_outdoor_air_sizing(air_loop_hvac)
    # First time adjustment:
    # Only applies to multi-zone vav systems
    # exclusion: for Outpatient: (1) both AHU1 and AHU2 in 'DOE Ref Pre-1980' and 'DOE Ref 1980-2004'
    # (2) AHU1 in 2004-2013
    # TODO refactor: move building-type-specific code to Prototype classes
    if air_loop_hvac_multizone_vav_system?(air_loop_hvac) && !(air_loop_hvac.name.to_s.include? 'Outpatient F1')
      air_loop_hvac_adjust_minimum_vav_damper_positions(air_loop_hvac)
    end

    return true
  end

  # Apply all standard required controls to the airloop
  #
  # @param (see #economizer_required?)
  # @return [Bool] returns true if successful, false if not
  # @todo optimum start
  # @todo night damper shutoff
  # @todo nightcycle control
  # @todo night fan shutoff
  def air_loop_hvac_apply_standard_controls(air_loop_hvac, climate_zone)
    # Energy Recovery Ventilation
    if air_loop_hvac_energy_recovery_ventilator_required?(air_loop_hvac, climate_zone)
      air_loop_hvac_apply_energy_recovery_ventilator(air_loop_hvac)
    end

    # Economizers
    air_loop_hvac_apply_economizer_limits(air_loop_hvac, climate_zone)
    air_loop_hvac_apply_economizer_integration(air_loop_hvac, climate_zone)

    # Multizone VAV Systems
    if air_loop_hvac_multizone_vav_system?(air_loop_hvac)

      # VAV Reheat Control
      air_loop_hvac_apply_vav_damper_action(air_loop_hvac)

      # Multizone VAV Optimization
      # This rule does not apply to two hospital and one outpatient systems (TODO add hospital two systems as exception)
      unless air_loop_hvac.name.to_s.include? 'Outpatient F1'
        if air_loop_hvac_multizone_vav_optimization_required?(air_loop_hvac, climate_zone)
          air_loop_hvac_enable_multizone_vav_optimization(air_loop_hvac)
        else
          air_loop_hvac_disable_multizone_vav_optimization(air_loop_hvac)
        end
      end

      # Static Pressure Reset
      # Per 5.2.2.16 (Halverson et al 2014), all multiple zone VAV systems are assumed to have DDC for all years of DOE 90.1 prototypes, so the has_ddc is not used any more.
      air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac).each do |fan|
        if fan.to_FanVariableVolume.is_initialized
          plr_req = fan_variable_volume_part_load_fan_power_limitation?(fan)
          # Part Load Fan Pressure Control
          if plr_req
            fan_variable_volume_set_control_type(fan, 'Multi Zone VAV with VSD and SP Setpoint Reset')
          # No Part Load Fan Pressure Control
          else
            fan_variable_volume_set_control_type(fan, 'Multi Zone VAV with discharge dampers')
          end
        else
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{fan}: This is not a multizone VAV fan system.")
        end
      end

      ## # Static Pressure Reset
      ## # assume no systems have DDC control of VAV terminals
      ## has_ddc = false
      ## spr_req = air_loop_hvac_static_pressure_reset_required?(air_loop_hvac, template, has_ddc)
      ## air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac).each do |fan|
      ##   if fan.to_FanVariableVolume.is_initialized
      ##     plr_req = fan_variable_volume_part_load_fan_power_limitation?(fan, template)
      ##     # Part Load Fan Pressure Control & Static Pressure Reset
      ##     if plr_req && spr_req
      ##       fan_variable_volume_set_control_type(fan, 'Multi Zone VAV with VSD and Static Pressure Reset')
      ##     # Part Load Fan Pressure Control only
      ##     elsif plr_req && !spr_req
      ##       fan_variable_volume_set_control_type(fan, 'Multi Zone VAV with VSD and Fixed SP Setpoint')
      ##     # Static Pressure Reset only
      ##     elsif !plr_req && spr_req
      ##       fan_variable_volume_set_control_type(fan, 'Multi Zone VAV with VSD and Fixed SP Setpoint')
      ##     # No Control Required
      ##     else
      ##       fan_variable_volume_set_control_type(fan, 'Multi Zone VAV with AF or BI Riding Curve')
      ##     end
      ##   else
      ##     OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.AirLoopHVAC', "For #{name}: there is a constant volume fan on a multizone vav system.  Cannot apply static pressure reset controls.")
      ##   end
      ## end
    end

    # Single zone systems
    if air_loop_hvac.thermalZones.size == 1
      air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac).each do |fan|
        if fan.to_FanVariableVolume.is_initialized
          fan_variable_volume_set_control_type(fan, 'Single Zone VAV Fan')
        end
      end
      air_loop_hvac_apply_single_zone_controls(air_loop_hvac, climate_zone)
    end

    # DCV
    if air_loop_hvac_demand_control_ventilation_required?(air_loop_hvac, climate_zone)
      air_loop_hvac_enable_demand_control_ventilation(air_loop_hvac, climate_zone)
      # For systems that require DCV,
      # all individual zones that require DCV preserve
      # both per-area and per-person OA requirements.
      # Other zones have OA requirements converted
      # to per-area values only so DCV performance is only
      # based on the subset of zones that required DCV.
      air_loop_hvac.thermalZones.sort.each do |zone|
        if thermal_zone_demand_control_ventilation_required?(zone, climate_zone)
          thermal_zone_convert_oa_req_to_per_area(zone)
        end
      end
    else
      # For systems that do not require DCV,
      # convert OA requirements to per-area values
      # so that other features such as
      # multizone VAV optimization do not
      # incorrectly take variable occupancy into account.
      air_loop_hvac.thermalZones.sort.each do |zone|
        thermal_zone_convert_oa_req_to_per_area(zone)
      end
    end

    # SAT reset
    # TODO Prototype buildings use OAT-based SAT reset,
    # but PRM RM suggests Warmest zone based SAT reset.
    if air_loop_hvac_supply_air_temperature_reset_required?(air_loop_hvac, climate_zone)
      air_loop_hvac_enable_supply_air_temperature_reset_warmest_zone(air_loop_hvac)
    end

    # Unoccupied shutdown
    if air_loop_hvac_unoccupied_fan_shutoff_required?(air_loop_hvac)
      occ_threshold = air_loop_hvac_unoccupied_threshold
      air_loop_hvac_enable_unoccupied_fan_shutoff(air_loop_hvac, min_occ_pct = occ_threshold)
    else
      air_loop_hvac.setAvailabilitySchedule(air_loop_hvac.model.alwaysOnDiscreteSchedule)
    end

    # Motorized OA damper
    if air_loop_hvac_motorized_oa_damper_required?(air_loop_hvac, climate_zone)
      # Assume that the availability schedule has already been
      # set to reflect occupancy and use this for the OA damper.
      air_loop_hvac_add_motorized_oa_damper(air_loop_hvac, 0.15, air_loop_hvac.availabilitySchedule)
    else
      air_loop_hvac_remove_motorized_oa_damper(air_loop_hvac)
    end

    # Zones that require DCV preserve
    # both per-area and per-person OA reqs.
    # Other zones have OA reqs converted
    # to per-area values only so that DCV
    air_loop_hvac.thermalZones.sort.each do |zone|
      if thermal_zone_demand_control_ventilation_required?(zone, climate_zone)
        thermal_zone_convert_oa_req_to_per_area(zone)
      end
    end

    # Optimum Start
    if air_loop_hvac_optimum_start_required?(air_loop_hvac)
      air_loop_hvac_enable_optimum_start(air_loop_hvac)
    end
  end

  # Apply all PRM baseline required controls to the airloop.
  # Only applies those controls that differ from the normal
  # prescriptive controls, which are added via
  # air_loop_hvac_apply_standard_controls(AirLoopHVAC)
  #
  # @param (see #economizer_required?)
  # @return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_prm_baseline_controls(air_loop_hvac, climate_zone)
    # Economizers
    if air_loop_hvac_prm_baseline_economizer_required?(air_loop_hvac, climate_zone)
      air_loop_hvac_apply_prm_baseline_economizer(air_loop_hvac, climate_zone)
    end

    # Multizone VAV Systems
    if air_loop_hvac_multizone_vav_system?(air_loop_hvac)

      # VSD no Static Pressure Reset on all VAV systems
      # per G3.1.3.15
      air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac).each do |fan|
        if fan.to_FanVariableVolume.is_initialized
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Setting fan part load curve per G3.1.3.15.")
          fan_variable_volume_set_control_type(fan, 'Multi Zone VAV with VSD and Fixed SP Setpoint')
        end
      end

      # SAT Reset
      # G3.1.3.12 SAT reset required for all Multizone VAV systems,
      # even if not required by prescriptive section.
      air_loop_hvac_enable_supply_air_temperature_reset_warmest_zone(air_loop_hvac)

    end

    # Unoccupied shutdown
    air_loop_hvac_enable_unoccupied_fan_shutoff(air_loop_hvac)

    return true
  end

  # Determines if optimum start control is required.
  # Defaults to 90.1-2004 logic, which requires
  # optimum start if > 10,000 cfm
  #
  def air_loop_hvac_optimum_start_required?(air_loop_hvac)
    opt_start_required = false

    # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = 0
    dsn_air_flow_cfm = 0
    if air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_air_flow_m3_per_s = air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
    else
      dsn_air_flow_m3_per_s = air_loop_hvac.designSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = Hard sized Design Supply Air Flow Rate.")
    end
    # Optimum start per 6.4.3.3.3, only required if > 10,000 cfm
    cfm_limit = 10_000
    if dsn_air_flow_cfm > cfm_limit
      opt_start_required = true
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Optimum start is required since design flow rate of #{dsn_air_flow_cfm.round} cfm exceeds the limit of #{cfm_limit} cfm.")
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Optimum start is not required since design flow rate of #{dsn_air_flow_cfm.round} cfm is below the limit of #{cfm_limit} cfm.")
    end

    return opt_start_required
  end

  # Adds optimum start control to the airloop.
  #
  def air_loop_hvac_enable_optimum_start(air_loop_hvac)
    # Get the heating and cooling setpoint schedules
    # for all zones on this airloop.
    htg_clg_schs = []
    air_loop_hvac.thermalZones.each do |zone|
      # Skip zones with no thermostat
      next if zone.thermostatSetpointDualSetpoint.empty?
      # Get the heating and cooling setpoint schedules
      tstat = zone.thermostatSetpointDualSetpoint.get
      htg_sch = nil
      if tstat.heatingSetpointTemperatureSchedule.is_initialized
        htg_sch = tstat.heatingSetpointTemperatureSchedule.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{zone.name}: Cannot find a heating setpoint schedule for this zone, cannot apply optimum start control.")
        next
      end
      clg_sch = nil
      if tstat.coolingSetpointTemperatureSchedule.is_initialized
        clg_sch = tstat.coolingSetpointTemperatureSchedule.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{zone.name}: Cannot find a cooling setpoint schedule for this zone, cannot apply optimum start control.")
        next
      end
      htg_clg_schs << [htg_sch, clg_sch]
    end

    # Clean name of airloop
    loop_name_clean = air_loop_hvac.name.get.to_s.gsub(/\W/, '').delete('_')
    # If the name starts with a number, prepend with a letter
    if loop_name_clean[0] =~ /[0-9]/
      loop_name_clean = "SYS#{loop_name_clean}"
    end

    # Sensors
    oat_db_c_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'Site Outdoor Air Drybulb Temperature')
    oat_db_c_sen.setName("OAT")
    oat_db_c_sen.setKeyName("Environment")

    # Make a program for each unique set of schedules.
    # For most air loops, all zones will have the same
    # pair of schedules.
    htg_clg_schs.uniq.each_with_index do |htg_clg_sch, i|
      htg_sch = htg_clg_sch[0]
      clg_sch = htg_clg_sch[1]

      # Actuators
      htg_sch_act = OpenStudio::Model::EnergyManagementSystemActuator.new(htg_sch, 'Schedule:Year', 'Schedule Value')
      htg_sch_act.setName("#{loop_name_clean}HtgSch#{i}")

      clg_sch_act = OpenStudio::Model::EnergyManagementSystemActuator.new(clg_sch, 'Schedule:Year', 'Schedule Value')
      clg_sch_act.setName("#{loop_name_clean}ClgSch#{i}")

      # Programs
      optstart_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(air_loop_hvac.model)
      optstart_prg.setName("#{loop_name_clean}OptimumStartProg#{i}")
      optstart_prg_body = <<-EMS
      IF DaylightSavings==0 && DayOfWeek>1 && Hour==5 && #{oat_db_c_sen.handle}<23.9 && #{oat_db_c_sen.handle}>1.7
        SET #{clg_sch_act.handle} = 29.4
        SET #{htg_sch_act.handle} = 15.6
      ELSEIF DaylightSavings==0 && DayOfWeek==1 && Hour==7 && #{oat_db_c_sen.handle}<23.9 && #{oat_db_c_sen.handle}>1.7
        SET #{clg_sch_act.handle} = 29.4
        SET #{htg_sch_act.handle} = 15.6
      ELSEIF DaylightSavings==1 && DayOfWeek>1 && Hour==4 && #{oat_db_c_sen.handle}<23.9 && #{oat_db_c_sen.handle}>1.7
        SET #{clg_sch_act.handle} = 29.4
        SET #{htg_sch_act.handle} = 15.6
      ELSEIF DaylightSavings==1 && DayOfWeek==1 && Hour==6 && #{oat_db_c_sen.handle}<23.9 && #{oat_db_c_sen.handle}>1.7
        SET #{clg_sch_act.handle} = 29.4
        SET #{htg_sch_act.handle} = 15.6
      ELSE
        SET #{clg_sch_act.handle} = NULL
        SET #{htg_sch_act.handle} = NULL
      ENDIF
      EMS
      optstart_prg.setBody(optstart_prg_body)

      # Program Calling Managers
      setup_mgr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(air_loop_hvac.model)
      setup_mgr.setName("#{loop_name_clean}OptimumStartCallingManager#{i}")
      setup_mgr.setCallingPoint('BeginTimestepBeforePredictor')
      setup_mgr.addProgram(optstart_prg)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Optimum start control enabled.")

    return true
  end

  # Calculate and apply the performance rating method
  # baseline fan power to this air loop.
  # Fan motor efficiency will be set, and then
  # fan pressure rise adjusted so that the
  # fan power is the maximum allowable.
  # Also adjusts the fan power and flow rates
  # of any parallel PIU terminals on the system.
  #
  # @todo Figure out how to split fan power between multiple fans
  # if the proposed model had multiple fans (supply, return, exhaust, etc.)
  # return [Bool] true if successful, false if not.
  def air_loop_hvac_apply_prm_baseline_fan_power(air_loop_hvac)
    # Main AHU fans

    # Calculate the allowable fan motor bhp
    # for the entire airloop.
    allowable_fan_bhp = air_loop_hvac_allowable_system_brake_horsepower(air_loop_hvac)

    # Divide the allowable power evenly between the fans
    # on this airloop.
    all_fans = air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac)
    allowable_fan_bhp /= all_fans.size

    # Set the motor efficiencies
    # for all fans based on the calculated
    # allowed brake hp.  Then calculate the allowable
    # fan power for each fan and adjust
    # the fan pressure rise accordingly
    all_fans.each do |fan|
      fan_apply_standard_minimum_motor_efficiency(fan, allowable_fan_bhp)
      allowable_power_w = allowable_fan_bhp * 746 / fan.motorEfficiency
      fan_adjust_pressure_rise_to_meet_fan_power(fan, allowable_power_w)
    end

    # Fan powered terminal fans

    # Adjust each terminal fan
    air_loop_hvac.demandComponents.each do |dc|
      next if dc.to_AirTerminalSingleDuctParallelPIUReheat.empty?
      pfp_term = dc.to_AirTerminalSingleDuctParallelPIUReheat.get
      air_terminal_single_duct_parallel_piu_reheat_apply_prm_baseline_fan_power(pfp_term)
    end

    return true
  end

  # Determine the fan power limitation pressure drop adjustment
  # Per Table 6.5.3.1.1B
  #
  # @return [Double] fan power limitation pressure drop adjustment
  #   units = horsepower
  # @todo Determine the presence of MERV filters and other stuff in Table 6.5.3.1.1B.  May need to extend AirLoopHVAC data model
  def air_loop_hvac_fan_power_limitation_pressure_drop_adjustment_brake_horsepower(air_loop_hvac)
    # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = 0
    dsn_air_flow_cfm = 0
    if air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_air_flow_m3_per_s = air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
    else
      dsn_air_flow_m3_per_s = air_loop_hvac.designSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = Hard sized Design Supply Air Flow Rate.")
    end

    # TODO: determine the presence of MERV filters and other stuff
    # in Table 6.5.3.1.1B
    # perhaps need to extend AirLoopHVAC data model
    has_fully_ducted_return_and_or_exhaust_air_systems = false

    # Calculate Fan Power Limitation Pressure Drop Adjustment (in wc)
    fan_pwr_adjustment_in_wc = 0

    # Fully ducted return and/or exhaust air systems
    if has_fully_ducted_return_and_or_exhaust_air_systems
      adj_in_wc = 0.5
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for Fully ducted return and/or exhaust air systems")
    end

    # Convert the pressure drop adjustment to brake horsepower (bhp)
    # assuming that all supply air passes through all devices
    fan_pwr_adjustment_bhp = fan_pwr_adjustment_in_wc * dsn_air_flow_cfm / 4131
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Fan Power Limitation Pressure Drop Adjustment = #{fan_pwr_adjustment_bhp.round(2)} bhp")

    return fan_pwr_adjustment_bhp
  end

  # Determine the allowable fan system brake horsepower
  # Per Table 6.5.3.1.1A
  #
  # @return [Double] allowable fan system brake horsepower
  #   units = horsepower
  def air_loop_hvac_allowable_system_brake_horsepower(air_loop_hvac)
    # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = 0
    dsn_air_flow_cfm = 0
    if air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_air_flow_m3_per_s = air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
    else
      dsn_air_flow_m3_per_s = air_loop_hvac.designSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = Hard sized Design Supply Air Flow Rate.")
    end

    # Get the fan limitation pressure drop adjustment bhp
    fan_pwr_adjustment_bhp = air_loop_hvac_fan_power_limitation_pressure_drop_adjustment_brake_horsepower(air_loop_hvac)

    # Determine the number of zones the system serves
    num_zones_served = air_loop_hvac.thermalZones.size

    # Get the supply air fan and determine whether VAV or CAV system.
    # Assume that supply air fan is fan closest to the demand outlet node.
    # The fan may be inside of a piece of unitary equipment.
    fan_pwr_limit_type = nil
    air_loop_hvac.supplyComponents.reverse.each do |comp|
      if comp.to_FanConstantVolume.is_initialized || comp.to_FanOnOff.is_initialized
        fan_pwr_limit_type = 'constant volume'
      elsif comp.to_FanVariableVolume.is_initialized
        fan_pwr_limit_type = 'variable volume'
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if fan.to_FanConstantVolume.is_initialized || comp.to_FanOnOff.is_initialized
          fan_pwr_limit_type = 'constant volume'
        elsif fan.to_FanVariableVolume.is_initialized
          fan_pwr_limit_type = 'variable volume'
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        if fan.to_FanConstantVolume.is_initialized || comp.to_FanOnOff.is_initialized
          fan_pwr_limit_type = 'constant volume'
        elsif fan.to_FanVariableVolume.is_initialized
          fan_pwr_limit_type = 'variable volume'
        end
      end
    end

    # For 90.1-2010, single-zone VAV systems use the
    # constant volume limitation per 6.5.3.1.1
    if template == 'ASHRAE 90.1-2010' && fan_pwr_limit_type == 'variable volume' && num_zones_served == 1
      fan_pwr_limit_type = 'constant volume'
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Using the constant volume limitation because single-zone VAV system.")
    end

    # Calculate the Allowable Fan System brake horsepower per Table G3.1.2.9
    allowable_fan_bhp = 0
    if fan_pwr_limit_type == 'constant volume'
      allowable_fan_bhp = dsn_air_flow_cfm * 0.00094 + fan_pwr_adjustment_bhp
    elsif fan_pwr_limit_type == 'variable volume'
      allowable_fan_bhp = dsn_air_flow_cfm * 0.0013 + fan_pwr_adjustment_bhp
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Allowable brake horsepower = #{allowable_fan_bhp.round(2)}HP based on #{dsn_air_flow_cfm.round} cfm and #{fan_pwr_adjustment_bhp.round(2)} bhp of adjustment.")

    # Calculate and report the total area for debugging/testing
    floor_area_served_m2 = air_loop_hvac_floor_area_served(air_loop_hvac)

    if floor_area_served_m2.zero?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "AirLoopHVAC #{air_loop_hvac.name} serves zero floor area. Check that it has thermal zones attached to it, and that they have non-zero floor area'.")
      return allowable_fan_bhp
    end

    floor_area_served_ft2 = OpenStudio.convert(floor_area_served_m2, 'm^2', 'ft^2').get
    cfm_per_ft2 = dsn_air_flow_cfm / floor_area_served_ft2
    cfm_per_hp = dsn_air_flow_cfm / allowable_fan_bhp
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: area served = #{floor_area_served_ft2.round} ft^2.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: flow per area = #{cfm_per_ft2.round} cfm/ft^2.")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: flow per hp = #{cfm_per_hp.round} cfm/hp.")

    return allowable_fan_bhp
  end

  # Get all of the supply, return, exhaust, and relief fans on this system
  #
  # @return [Array] an array of FanConstantVolume, FanVariableVolume, and FanOnOff objects
  def air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac)
    # Fans on the supply side of the airloop directly, or inside of unitary equipment.
    fans = []
    sup_and_oa_comps = air_loop_hvac.supplyComponents
    sup_and_oa_comps += air_loop_hvac.oaComponents
    sup_and_oa_comps.each do |comp|
      if comp.to_FanConstantVolume.is_initialized
        fans << comp.to_FanConstantVolume.get
      elsif comp.to_FanVariableVolume.is_initialized
        fans << comp.to_FanVariableVolume.get
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        sup_fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if sup_fan.to_FanConstantVolume.is_initialized
          fans << sup_fan.to_FanConstantVolume.get
        elsif sup_fan.to_FanOnOff.is_initialized
          fans << sup_fan.to_FanOnOff.get
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        sup_fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        next if sup_fan.empty?
        sup_fan = sup_fan.get
        if sup_fan.to_FanConstantVolume.is_initialized
          fans << sup_fan.to_FanConstantVolume.get
        elsif sup_fan.to_FanOnOff.is_initialized
          fans << sup_fan.to_FanOnOff.get
        elsif sup_fan.to_FanVariableVolume.is_initialized
          fans << sup_fan.to_FanVariableVolume.get
        end
      end
    end

    return fans
  end

  # Determine the total brake horsepower of the fans on the system
  # with or without the fans inside of fan powered terminals.
  #
  # @param include_terminal_fans [Bool] if true, power from fan powered terminals will be included
  # @return [Double] total brake horsepower of the fans on the system
  #   units = horsepower
  def air_loop_hvac_system_fan_brake_horsepower(air_loop_hvac, include_terminal_fans = true)
    # TODO: get the template from the parent model itself?
    # Or not because maybe you want to see the difference between two standards?
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name}-Determining #{template} allowable system fan power.")

    # Get all fans
    fans = []
    # Supply, exhaust, relief, and return fans
    fans += air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac)

    # Fans inside of fan-powered terminals
    if include_terminal_fans
      air_loop_hvac.demandComponents.each do |comp|
        if comp.to_AirTerminalSingleDuctSeriesPIUReheat.is_initialized
          term_fan = comp.to_AirTerminalSingleDuctSeriesPIUReheat.get.supplyAirFan
          if term_fan.to_FanConstantVolume.is_initialized
            fans << term_fan.to_FanConstantVolume.get
          end
        elsif comp.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized
          term_fan = comp.to_AirTerminalSingleDuctParallelPIUReheat.get.fan
          if term_fan.to_FanConstantVolume.is_initialized
            fans << term_fan.to_FanConstantVolume.get
          end
        end
      end
    end

    # Loop through all fans on the system and
    # sum up their brake horsepower values.
    sys_fan_bhp = 0
    fans.sort.each do |fan|
      sys_fan_bhp += fan_brake_horsepower(fan)
    end

    return sys_fan_bhp
  end

  # Set the fan pressure rises that will result in
  # the system hitting the baseline allowable fan power
  #
  def air_loop_hvac_apply_baseline_fan_pressure_rise(air_loop_hvac)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name}-Setting #{template} baseline fan power.")

    # Get the total system bhp from the proposed system, including terminal fans
    proposed_sys_bhp = air_loop_hvac_system_fan_brake_horsepower(air_loop_hvac, true)

    # Get the allowable fan brake horsepower
    allowable_fan_bhp = air_loop_hvac_allowable_system_brake_horsepower(air_loop_hvac)

    # Get the fan power limitation from proposed system
    fan_pwr_adjustment_bhp = air_loop_hvac_fan_power_limitation_pressure_drop_adjustment_brake_horsepower(air_loop_hvac)

    # Subtract the fan power adjustment
    allowable_fan_bhp -= fan_pwr_adjustment_bhp

    # Get all fans
    fans = air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac)

    # TODO: improve description
    # Loop through the fans, changing the pressure rise
    # until the fan bhp is the same percentage of the baseline allowable bhp
    # as it was on the proposed system.
    fans.each do |fan|
      # TODO: Yixing Check the model of the Fan Coil Unit
      next if fan.name.to_s.include?('Fan Coil fan')
      next if fan.name.to_s.include?('UnitHeater Fan')

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', fan.name.to_s)

      # Get the bhp of the fan on the proposed system
      proposed_fan_bhp = fan_brake_horsepower(fan)

      # Get the bhp of the fan on the proposed system
      proposed_fan_bhp_frac = proposed_fan_bhp / proposed_sys_bhp

      # Determine the target bhp of the fan on the baseline system
      baseline_fan_bhp = proposed_fan_bhp_frac * allowable_fan_bhp
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "* #{baseline_fan_bhp.round(1)} bhp = Baseline fan brake horsepower.")

      # Set the baseline impeller eff of the fan,
      # preserving the proposed motor eff.
      baseline_impeller_eff = fan_baseline_impeller_efficiency(fan)
      fan_change_impeller_efficiency(fan, baseline_impeller_eff)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "* #{(baseline_impeller_eff * 100).round(1)}% = Baseline fan impeller efficiency.")

      # Set the baseline motor efficiency for the specified bhp
      baseline_motor_eff = fan.standardMinimumMotorEfficiency(standards, allowable_fan_bhp)
      fan_change_motor_efficiency(fan, baseline_motor_eff)

      # Get design supply air flow rate (whether autosized or hard-sized)
      dsn_air_flow_m3_per_s = 0
      if fan.autosizedDesignSupplyAirFlowRate.is_initialized
        dsn_air_flow_m3_per_s = fan.autosizedDesignSupplyAirFlowRate.get
        dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
      else
        dsn_air_flow_m3_per_s = fan.designSupplyAirFlowRate.get
        dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, 'm^3/s', 'cfm').get
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "* #{dsn_air_flow_cfm.round} cfm = User entered Design Supply Air Flow Rate.")
      end

      # Determine the fan pressure rise that will result in the target bhp
      # pressure_rise_pa = fan_bhp*746 / fan_motor_eff*fan_total_eff / dsn_air_flow_m3_per_s
      baseline_pressure_rise_pa = baseline_fan_bhp * 746 / fan.motorEfficiency * fan.fanEfficiency / dsn_air_flow_m3_per_s
      baseline_pressure_rise_in_wc = OpenStudio.convert(fan_pressure_rise_pa, 'Pa', 'inH_{2}O').get
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "* #{fan_pressure_rise_in_wc.round(2)} in w.c. = Pressure drop to achieve allowable fan power.")

      # Calculate the bhp of the fan to make sure it matches
      calc_bhp = fan_brake_horsepower(fan)
      if ((calc_bhp - baseline_fan_bhp) / baseline_fan_bhp).abs > 0.02
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.AirLoopHVAC', "#{fan.name} baseline fan bhp supposed to be #{baseline_fan_bhp}, but is #{calc_bhp}.")
      end
    end

    # Calculate the total bhp of the system to make sure it matches the goal
    calc_sys_bhp = air_loop_hvac_system_fan_brake_horsepower(air_loop_hvac, false)
    if ((calc_sys_bhp - allowable_fan_bhp) / allowable_fan_bhp).abs > 0.02
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} baseline system bhp supposed to be #{allowable_fan_bhp}, but is #{calc_sys_bhp}.")
    end
  end

  # Get the total cooling capacity for the air loop
  #
  # @return [Double] total cooling capacity
  #   units = Watts (W)
  # @todo Change to pull water coil nominal capacity instead of design load; not a huge difference, but water coil nominal capacity not available in sizing table.
  # @todo Handle all additional cooling coil types.  Currently only handles CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, and CoilCoolingWater
  def air_loop_hvac_total_cooling_capacity(air_loop_hvac)
    # Sum the cooling capacity for all cooling components
    # on the airloop, which may be inside of unitary systems.
    total_cooling_capacity_w = 0
    air_loop_hvac.supplyComponents.each do |sc|
      # CoilCoolingDXSingleSpeed
      if sc.to_CoilCoolingDXSingleSpeed.is_initialized
        coil = sc.to_CoilCoolingDXSingleSpeed.get
        if coil.ratedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.ratedTotalCoolingCapacity.get
        elsif coil.autosizedRatedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.autosizedRatedTotalCoolingCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
        # CoilCoolingDXTwoSpeed
      elsif sc.to_CoilCoolingDXTwoSpeed.is_initialized
        coil = sc.to_CoilCoolingDXTwoSpeed.get
        if coil.ratedHighSpeedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.ratedHighSpeedTotalCoolingCapacity.get
        elsif coil.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.autosizedRatedHighSpeedTotalCoolingCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
        # CoilCoolingWater
      elsif sc.to_CoilCoolingWater.is_initialized
        coil = sc.to_CoilCoolingWater.get
        if coil.autosizedDesignCoilLoad.is_initialized # TODO: Change to pull water coil nominal capacity instead of design load
          total_cooling_capacity_w += coil.autosizedDesignCoilLoad.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
        # CoilCoolingWaterToAirHeatPumpEquationFit
      elsif sc.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
        coil = sc.to_CoilCoolingWaterToAirHeatPumpEquationFit.get
        if coil.ratedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.ratedTotalCoolingCapacity.get
        elsif coil.autosizedRatedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.autosizedRatedTotalCoolingCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
      elsif sc.to_AirLoopHVACUnitarySystem.is_initialized
        unitary = sc.to_AirLoopHVACUnitarySystem.get
        if unitary.coolingCoil.is_initialized
          clg_coil = unitary.coolingCoil.get
          # CoilCoolingDXSingleSpeed
          if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
            coil = clg_coil.to_CoilCoolingDXSingleSpeed.get
            if coil.ratedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.ratedTotalCoolingCapacity.get
            elsif coil.autosizedRatedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.autosizedRatedTotalCoolingCapacity.get
            else
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
            end
          # CoilCoolingDXTwoSpeed
          elsif clg_coil.to_CoilCoolingDXTwoSpeed.is_initialized
            coil = clg_coil.to_CoilCoolingDXTwoSpeed.get
            if coil.ratedHighSpeedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.ratedHighSpeedTotalCoolingCapacity.get
            elsif coil.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.autosizedRatedHighSpeedTotalCoolingCapacity.get
            else
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
            end
          # CoilCoolingWater
          elsif clg_coil.to_CoilCoolingWater.is_initialized
            coil = clg_coil.to_CoilCoolingWater.get
            if coil.autosizedDesignCoilLoad.is_initialized # TODO: Change to pull water coil nominal capacity instead of design load
              total_cooling_capacity_w += coil.autosizedDesignCoilLoad.get
            else
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
            end
          # CoilCoolingWaterToAirHeatPumpEquationFit
          elsif clg_coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
            coil = clg_coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.get
            if coil.ratedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.ratedTotalCoolingCapacity.get
            elsif coil.autosizedRatedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.autosizedRatedTotalCoolingCapacity.get
            else
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
            end
          end
        end
      elsif sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
        unitary = sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        clg_coil = unitary.coolingCoil
        # CoilCoolingDXSingleSpeed
        if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
          coil = clg_coil.to_CoilCoolingDXSingleSpeed.get
          if coil.ratedTotalCoolingCapacity.is_initialized
            total_cooling_capacity_w += coil.ratedTotalCoolingCapacity.get
          elsif coil.autosizedRatedTotalCoolingCapacity.is_initialized
            total_cooling_capacity_w += coil.autosizedRatedTotalCoolingCapacity.get
          else
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
          end
        # CoilCoolingDXTwoSpeed
        elsif clg_coil.to_CoilCoolingDXTwoSpeed.is_initialized
          coil = clg_coil.to_CoilCoolingDXTwoSpeed.get
          if coil.ratedHighSpeedTotalCoolingCapacity.is_initialized
            total_cooling_capacity_w += coil.ratedHighSpeedTotalCoolingCapacity.get
          elsif coil.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
            total_cooling_capacity_w += coil.autosizedRatedHighSpeedTotalCoolingCapacity.get
          else
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
          end
        # CoilCoolingWater
        elsif clg_coil.to_CoilCoolingWater.is_initialized
          coil = clg_coil.to_CoilCoolingWater.get
          if coil.autosizedDesignCoilLoad.is_initialized # TODO: Change to pull water coil nominal capacity instead of design load
            total_cooling_capacity_w += coil.autosizedDesignCoilLoad.get
          else
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
          end
        end
      elsif sc.to_CoilCoolingDXMultiSpeed.is_initialized ||
            sc.to_CoilCoolingCooledBeam.is_initialized ||
            sc.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized ||
            sc.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized ||
            sc.to_AirLoopHVACUnitarySystem.is_initialized
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} has a cooling coil named #{sc.name}, whose type is not yet covered by economizer checks.")
        # CoilCoolingDXMultiSpeed
        # CoilCoolingCooledBeam
        # CoilCoolingWaterToAirHeatPumpEquationFit
        # AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass
        # AirLoopHVACUnitaryHeatPumpAirToAir
        # AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed
        # AirLoopHVACUnitarySystem
      end
    end

    return total_cooling_capacity_w
  end

  # Determine whether or not this system
  # is required to have an economizer.
  #
  # @param climate_zone [String] valid choices: 'ASHRAE 169-2013-1A', 'ASHRAE 169-2013-1B', 'ASHRAE 169-2013-2A', 'ASHRAE 169-2013-2B',
  # 'ASHRAE 169-2013-3A', 'ASHRAE 169-2013-3B', 'ASHRAE 169-2013-3C', 'ASHRAE 169-2013-4A', 'ASHRAE 169-2013-4B', 'ASHRAE 169-2013-4C',
  # 'ASHRAE 169-2013-5A', 'ASHRAE 169-2013-5B', 'ASHRAE 169-2013-5C', 'ASHRAE 169-2013-6A', 'ASHRAE 169-2013-6B', 'ASHRAE 169-2013-7A',
  # 'ASHRAE 169-2013-7B', 'ASHRAE 169-2013-8A', 'ASHRAE 169-2013-8B'
  # @return [Bool] returns true if an economizer is required, false if not
  def air_loop_hvac_economizer_required?(air_loop_hvac, climate_zone)
    economizer_required = false

    return economizer_required if air_loop_hvac.name.to_s.include? 'Outpatient F1'

    # Determine if the airloop serves any computer rooms
    # / data centers, which changes the economizer.
    is_dc = false
    if air_loop_hvac_data_center_area_served(air_loop_hvac) > 0
      is_dc = true
    end

    # Retrieve economizer limits from JSON
    search_criteria = {
      'template' => template,
      'climate_zone' => climate_zone,
      'data_center' => is_dc
    }
    econ_limits = model_find_object(standards_data['economizers'], search_criteria)
    if econ_limits.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "Cannot find economizer limits for #{template}, #{climate_zone}, assuming no economizer required.")
      return economizer_required
    end

    # Determine the minimum capacity and whether or not it is a data center
    minimum_capacity_btu_per_hr = econ_limits['capacity_limit']

    # A big number of btu per hr as the minimum requirement if nil in spreadsheet
    infinity_btu_per_hr = 999_999_999_999
    minimum_capacity_btu_per_hr = infinity_btu_per_hr if minimum_capacity_btu_per_hr.nil?

    # Check whether the system requires an economizer by comparing
    # the system capacity to the minimum capacity.
    total_cooling_capacity_w = air_loop_hvac_total_cooling_capacity(air_loop_hvac)
    total_cooling_capacity_btu_per_hr = OpenStudio.convert(total_cooling_capacity_w, 'W', 'Btu/hr').get

    if total_cooling_capacity_btu_per_hr >= minimum_capacity_btu_per_hr
      if is_dc
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} requires an economizer because the total cooling capacity of #{total_cooling_capacity_btu_per_hr.round} Btu/hr exceeds the minimum capacity of #{minimum_capacity_btu_per_hr.round} Btu/hr for data centers.")
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} requires an economizer because the total cooling capacity of #{total_cooling_capacity_btu_per_hr.round} Btu/hr exceeds the minimum capacity of #{minimum_capacity_btu_per_hr.round} Btu/hr.")
      end
      economizer_required = true
    else
      if is_dc
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} does not require an economizer because the total cooling capacity of #{total_cooling_capacity_btu_per_hr.round} Btu/hr is less than the minimum capacity of #{minimum_capacity_btu_per_hr.round} Btu/hr for data centers.")
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} does not require an economizer because the total cooling capacity of #{total_cooling_capacity_btu_per_hr.round} Btu/hr is less than the minimum capacity of #{minimum_capacity_btu_per_hr.round} Btu/hr.")
      end
    end

    return economizer_required
  end

  # Set the economizer limits per the standard.  Limits are based on the economizer
  # type currently specified in the ControllerOutdoorAir object on this air loop.
  #
  # @param (see #economizer_required?)
  # @return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_economizer_limits(air_loop_hvac, climate_zone)
    # EnergyPlus economizer types
    # 'NoEconomizer'
    # 'FixedDryBulb'
    # 'FixedEnthalpy'
    # 'DifferentialDryBulb'
    # 'DifferentialEnthalpy'
    # 'FixedDewPointAndDryBulb'
    # 'ElectronicEnthalpy'
    # 'DifferentialDryBulbAndEnthalpy'

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType

    # Return false if no economizer is present
    if economizer_type == 'NoEconomizer'
      return false
    end

    # Reset the limits
    oa_control.resetEconomizerMaximumLimitDryBulbTemperature
    oa_control.resetEconomizerMaximumLimitEnthalpy
    oa_control.resetEconomizerMaximumLimitDewpointTemperature
    oa_control.resetEconomizerMinimumLimitDryBulbTemperature

    # Determine the limits
    drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f = air_loop_hvac_economizer_limits(air_loop_hvac, climate_zone)

    # Do nothing if no limits were specified
    if drybulb_limit_f.nil? && enthalpy_limit_btu_per_lb.nil? && dewpoint_limit_f.nil?
      return false
    end

    # Set the limits
    case economizer_type
    when 'FixedDryBulb'
      if drybulb_limit_f
        drybulb_limit_c = OpenStudio.convert(drybulb_limit_f, 'F', 'C').get
        oa_control.setEconomizerMaximumLimitDryBulbTemperature(drybulb_limit_c)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer type = #{economizer_type}, dry bulb limit = #{drybulb_limit_f}F")
      end
    when 'FixedEnthalpy'
      if enthalpy_limit_btu_per_lb
        enthalpy_limit_j_per_kg = OpenStudio.convert(enthalpy_limit_btu_per_lb, 'Btu/lb', 'J/kg').get
        oa_control.setEconomizerMaximumLimitEnthalpy(enthalpy_limit_j_per_kg)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer type = #{economizer_type}, enthalpy limit = #{enthalpy_limit_btu_per_lb}Btu/lb")
      end
    when 'FixedDewPointAndDryBulb'
      if drybulb_limit_f && dewpoint_limit_f
        drybulb_limit_c = OpenStudio.convert(drybulb_limit_f, 'F', 'C').get
        dewpoint_limit_c = OpenStudio.convert(dewpoint_limit_f, 'F', 'C').get
        oa_control.setEconomizerMaximumLimitDryBulbTemperature(drybulb_limit_c)
        oa_control.setEconomizerMaximumLimitDewpointTemperature(dewpoint_limit_c)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer type = #{economizer_type}, dry bulb limit = #{drybulb_limit_f}F, dew-point limit = #{dewpoint_limit_f}F")
      end
    end

    return true
  end

  # Determine the limits for the type of economizer present
  # on the AirLoopHVAC, if any.
  # @return [Array<Double>] [drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  def air_loop_hvac_economizer_limits(air_loop_hvac, climate_zone)
    drybulb_limit_f = nil
    enthalpy_limit_btu_per_lb = nil
    dewpoint_limit_f = nil

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return [nil, nil, nil] # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType

    case economizer_type
    when 'NoEconomizer'
      return [nil, nil, nil]
    when 'FixedDryBulb'
      case climate_zone
      when 'ASHRAE 169-2006-1B',
          'ASHRAE 169-2006-2B',
          'ASHRAE 169-2006-3B',
          'ASHRAE 169-2006-3C',
          'ASHRAE 169-2006-4B',
          'ASHRAE 169-2006-4C',
          'ASHRAE 169-2006-5B',
          'ASHRAE 169-2006-5C',
          'ASHRAE 169-2006-6B',
          'ASHRAE 169-2006-7B',
          'ASHRAE 169-2006-8A',
          'ASHRAE 169-2006-8B',
          'ASHRAE 169-2013-1B',
          'ASHRAE 169-2013-2B',
          'ASHRAE 169-2013-3B',
          'ASHRAE 169-2013-3C',
          'ASHRAE 169-2013-4B',
          'ASHRAE 169-2013-4C',
          'ASHRAE 169-2013-5B',
          'ASHRAE 169-2013-5C',
          'ASHRAE 169-2013-6B',
          'ASHRAE 169-2013-7B',
          'ASHRAE 169-2013-8A',
          'ASHRAE 169-2013-8B'
        drybulb_limit_f = 75
      when 'ASHRAE 169-2006-5A',
          'ASHRAE 169-2006-6A',
          'ASHRAE 169-2006-7A',
          'ASHRAE 169-2013-5A',
          'ASHRAE 169-2013-6A',
          'ASHRAE 169-2013-7A'
        drybulb_limit_f = 70
      when 'ASHRAE 169-2006-1A',
          'ASHRAE 169-2006-2A',
          'ASHRAE 169-2006-3A',
          'ASHRAE 169-2006-4A',
          'ASHRAE 169-2013-1A',
          'ASHRAE 169-2013-2A',
          'ASHRAE 169-2013-3A',
          'ASHRAE 169-2013-4A'
        drybulb_limit_f = 65
      end
    when 'FixedEnthalpy'
      enthalpy_limit_btu_per_lb = 28
    when 'FixedDewPointAndDryBulb'
      drybulb_limit_f = 75
      dewpoint_limit_f = 55
    end

    return [drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  end

  # For systems required to have an economizer, set the economizer
  # to integrated on non-integrated per the standard.
  #
  # @note this method assumes you previously checked that an economizer is required at all
  #   via #economizer_required?
  # @param (see #economizer_required?)
  # @return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_economizer_integration(air_loop_hvac, climate_zone)
    # Determine if an integrated economizer is required
    integrated_economizer_required = air_loop_hvac_integrated_economizer_required?(air_loop_hvac, climate_zone)

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir

    # Apply integrated or non-integrated economizer
    if integrated_economizer_required
      oa_control.setLockoutType('NoLockout')
    else
      oa_control.setLockoutType('LockoutWithCompressor')
    end

    return true
  end

  # Determine if the system economizer must be integrated or not.
  # Default logic is from 90.1-2004.
  def air_loop_hvac_integrated_economizer_required?(air_loop_hvac, climate_zone)
    # Determine if it is a VAV system
    is_vav = air_loop_hvac_vav_system?(air_loop_hvac)

    # Determine the number of zones the system serves
    num_zones_served = air_loop_hvac.thermalZones.size

    minimum_capacity_btu_per_hr = 65_000
    minimum_capacity_w = OpenStudio.convert(minimum_capacity_btu_per_hr, 'Btu/hr', 'W').get
    # 6.5.1.3 Integrated Economizer Control
    # Exception a, DX VAV systems
    if is_vav == true && num_zones_served > 1
      integrated_economizer_required = false
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: non-integrated economizer per 6.5.1.3 exception a, DX VAV system.")
      # Exception b, DX units less than 65,000 Btu/hr
    elsif air_loop_hvac_total_cooling_capacity(air_loop_hvac) < minimum_capacity_w
      integrated_economizer_required = false
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: non-integrated economizer per 6.5.1.3 exception b, DX system less than #{minimum_capacity_btu_per_hr}Btu/hr.")
    else
      # Exception c, Systems in climate zones 1,2,3a,4a,5a,5b,6,7,8
      case climate_zone
      when 'ASHRAE 169-2006-1A',
           'ASHRAE 169-2006-1B',
           'ASHRAE 169-2006-2A',
           'ASHRAE 169-2006-2B',
           'ASHRAE 169-2006-3A',
           'ASHRAE 169-2006-4A',
           'ASHRAE 169-2006-5A',
           'ASHRAE 169-2006-5B',
           'ASHRAE 169-2006-6A',
           'ASHRAE 169-2006-6B',
           'ASHRAE 169-2006-7A',
           'ASHRAE 169-2006-7B',
           'ASHRAE 169-2006-8A',
           'ASHRAE 169-2006-8B',
           'ASHRAE 169-2013-1A',
           'ASHRAE 169-2013-1B',
           'ASHRAE 169-2013-2A',
           'ASHRAE 169-2013-2B',
           'ASHRAE 169-2013-3A',
           'ASHRAE 169-2013-4A',
           'ASHRAE 169-2013-5A',
           'ASHRAE 169-2013-5B',
           'ASHRAE 169-2013-6A',
           'ASHRAE 169-2013-6B',
           'ASHRAE 169-2013-7A',
           'ASHRAE 169-2013-7B',
           'ASHRAE 169-2013-8A',
           'ASHRAE 169-2013-8B'
        integrated_economizer_required = false
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: non-integrated economizer per 6.5.1.3 exception c, climate zone #{climate_zone}.")
      when 'ASHRAE 169-2006-3B',
           'ASHRAE 169-2006-3C',
           'ASHRAE 169-2006-4B',
           'ASHRAE 169-2006-4C',
           'ASHRAE 169-2006-5C',
           'ASHRAE 169-2013-3B',
           'ASHRAE 169-2013-3C',
           'ASHRAE 169-2013-4B',
           'ASHRAE 169-2013-4C',
           'ASHRAE 169-2013-5C'
        integrated_economizer_required = true
      end
    end

    return integrated_economizer_required
  end

  # Determine if an economizer is required per the PRM.
  # Default logic from 90.1-2007
  #
  # @param (see #economizer_required?)
  # @return [Bool] returns true if required, false if not
  def air_loop_hvac_prm_baseline_economizer_required?(air_loop_hvac, climate_zone)
    economizer_required = false

    # A big number of ft2 as the minimum requirement
    infinity_ft2 = 999_999_999_999
    min_int_area_served_ft2 = infinity_ft2
    min_ext_area_served_ft2 = infinity_ft2

    # Determine the minimum capacity that requires an economizer
    case climate_zone
    when 'ASHRAE 169-2006-1A',
         'ASHRAE 169-2006-1B',
         'ASHRAE 169-2006-2A',
         'ASHRAE 169-2006-3A',
         'ASHRAE 169-2006-4A',
         'ASHRAE 169-2013-1A',
         'ASHRAE 169-2013-1B',
         'ASHRAE 169-2013-2A',
         'ASHRAE 169-2013-3A',
         'ASHRAE 169-2013-4A'
      min_int_area_served_ft2 = infinity_ft2 # No requirement
      min_ext_area_served_ft2 = infinity_ft2 # No requirement
    else
      min_int_area_served_ft2 = 0 # Always required
      min_ext_area_served_ft2 = 0 # Always required
    end

    # Check whether the system requires an economizer by comparing
    # the system capacity to the minimum capacity.
    min_int_area_served_m2 = OpenStudio.convert(min_int_area_served_ft2, 'ft^2', 'm^2').get
    min_ext_area_served_m2 = OpenStudio.convert(min_ext_area_served_ft2, 'ft^2', 'm^2').get

    # Get the interior and exterior area served
    int_area_served_m2 = air_loop_hvac_floor_area_served_interior_zones(air_loop_hvac)
    ext_area_served_m2 = air_loop_hvac_floor_area_served_exterior_zones(air_loop_hvac)

    # Check the floor area exception
    if int_area_served_m2 < min_int_area_served_m2 && ext_area_served_m2 < min_ext_area_served_m2
      if min_int_area_served_ft2 == infinity_ft2 && min_ext_area_served_ft2 == infinity_ft2
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer not required for climate zone #{climate_zone}.")
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer not required for because the interior area served of #{int_area_served_m2} ft2 < minimum of #{min_int_area_served_m2} and the perimeter area served of #{ext_area_served_m2} ft2 < minimum of #{min_ext_area_served_m2} for climate zone #{climate_zone}.")
      end
      return economizer_required
    end

    # If here, economizer required
    economizer_required = true
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer required for the performance rating method baseline.")

    return economizer_required
  end

  # Apply the PRM economizer type and set temperature limits
  #
  # @param (see #economizer_required?)
  # @return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_prm_baseline_economizer(air_loop_hvac, climate_zone)
    # EnergyPlus economizer types
    # 'NoEconomizer'
    # 'FixedDryBulb'
    # 'FixedEnthalpy'
    # 'DifferentialDryBulb'
    # 'DifferentialEnthalpy'
    # 'FixedDewPointAndDryBulb'
    # 'ElectronicEnthalpy'
    # 'DifferentialDryBulbAndEnthalpy'

    # Determine the type and limits
    economizer_type, drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f = air_loop_hvac_prm_economizer_type_and_limits(air_loop_hvac, climate_zone)

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir

    # Set the economizer type
    oa_control.setEconomizerControlType(economizer_type)

    # Reset the limits
    oa_control.resetEconomizerMaximumLimitDryBulbTemperature
    oa_control.resetEconomizerMaximumLimitEnthalpy
    oa_control.resetEconomizerMaximumLimitDewpointTemperature
    oa_control.resetEconomizerMinimumLimitDryBulbTemperature

    # Set the limits
    case economizer_type
    when 'FixedDryBulb'
      if drybulb_limit_f
        drybulb_limit_c = OpenStudio.convert(drybulb_limit_f, 'F', 'C').get
        oa_control.setEconomizerMaximumLimitDryBulbTemperature(drybulb_limit_c)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer type = #{economizer_type}, dry bulb limit = #{drybulb_limit_f}F")
      end
    when 'FixedEnthalpy'
      if enthalpy_limit_btu_per_lb
        enthalpy_limit_j_per_kg = OpenStudio.convert(enthalpy_limit_btu_per_lb, 'Btu/lb', 'J/kg').get
        oa_control.setEconomizerMaximumLimitEnthalpy(enthalpy_limit_j_per_kg)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer type = #{economizer_type}, enthalpy limit = #{enthalpy_limit_btu_per_lb}Btu/lb")
      end
    when 'FixedDewPointAndDryBulb'
      if drybulb_limit_f && dewpoint_limit_f
        drybulb_limit_c = OpenStudio.convert(drybulb_limit_f, 'F', 'C').get
        dewpoint_limit_c = OpenStudio.convert(dewpoint_limit_f, 'F', 'C').get
        oa_control.setEconomizerMaximumLimitDryBulbTemperature(drybulb_limit_c)
        oa_control.setEconomizerMaximumLimitDewpointTemperature(dewpoint_limit_c)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Economizer type = #{economizer_type}, dry bulb limit = #{drybulb_limit_f}F, dew-point limit = #{dewpoint_limit_f}F")
      end
    end

    return true
  end

  # Determine the economizer type and limits for the the PRM
  # Defaults to 90.1-2007 logic.
  # @return [Array<Double>] [economizer_type, drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  def air_loop_hvac_prm_economizer_type_and_limits(air_loop_hvac, climate_zone)
    economizer_type = 'NoEconomizer'
    drybulb_limit_f = nil
    enthalpy_limit_btu_per_lb = nil
    dewpoint_limit_f = nil

    case climate_zone
    when 'ASHRAE 169-2006-1B',
         'ASHRAE 169-2006-2B',
         'ASHRAE 169-2006-3B',
         'ASHRAE 169-2006-3C',
         'ASHRAE 169-2006-4B',
         'ASHRAE 169-2006-4C',
         'ASHRAE 169-2006-5B',
         'ASHRAE 169-2006-5C',
         'ASHRAE 169-2006-6B',
         'ASHRAE 169-2006-7B',
         'ASHRAE 169-2006-8A',
         'ASHRAE 169-2006-8B',
         'ASHRAE 169-2013-1B',
         'ASHRAE 169-2013-2B',
         'ASHRAE 169-2013-3B',
         'ASHRAE 169-2013-3C',
         'ASHRAE 169-2013-4B',
         'ASHRAE 169-2013-4C',
         'ASHRAE 169-2013-5B',
         'ASHRAE 169-2013-5C',
         'ASHRAE 169-2013-6B',
         'ASHRAE 169-2013-7B',
         'ASHRAE 169-2013-8A',
         'ASHRAE 169-2013-8B'
      economizer_type = 'FixedDryBulb'
      drybulb_limit_f = 75
    when 'ASHRAE 169-2006-5A',
         'ASHRAE 169-2006-6A',
         'ASHRAE 169-2006-7A',
         'ASHRAE 169-2013-5A',
         'ASHRAE 169-2013-6A',
         'ASHRAE 169-2013-7A'
      economizer_type = 'FixedDryBulb'
      drybulb_limit_f = 70
    else
      economizer_type = 'FixedDryBulb'
      drybulb_limit_f = 65
    end

    return [economizer_type, drybulb_limit_f, enthalpy_limit_btu_per_lb, dewpoint_limit_f]
  end

  # Check the economizer type currently specified in the ControllerOutdoorAir object on this air loop
  # is acceptable per the standard. Defaults to 90.1-2007 logic.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if allowable, if the system has no economizer or no OA system.
  # Returns false if the economizer type is not allowable.
  def air_loop_hvac_economizer_type_allowable?(air_loop_hvac, climate_zone)
    # EnergyPlus economizer types
    # 'NoEconomizer'
    # 'FixedDryBulb'
    # 'FixedEnthalpy'
    # 'DifferentialDryBulb'
    # 'DifferentialEnthalpy'
    # 'FixedDewPointAndDryBulb'
    # 'ElectronicEnthalpy'
    # 'DifferentialDryBulbAndEnthalpy'

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return true # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType

    # Return true if no economizer is present
    if economizer_type == 'NoEconomizer'
      return true
    end

    # Determine the prohibited types
    prohibited_types = []
    case climate_zone
    when 'ASHRAE 169-2006-1B',
         'ASHRAE 169-2006-2B',
         'ASHRAE 169-2006-3B',
         'ASHRAE 169-2006-3C',
         'ASHRAE 169-2006-4B',
         'ASHRAE 169-2006-4C',
         'ASHRAE 169-2006-5B',
         'ASHRAE 169-2006-6B',
         'ASHRAE 169-2006-7A',
         'ASHRAE 169-2006-7B',
         'ASHRAE 169-2006-8A',
         'ASHRAE 169-2006-8B',
         'ASHRAE 169-2013-1B',
         'ASHRAE 169-2013-2B',
         'ASHRAE 169-2013-3B',
         'ASHRAE 169-2013-3C',
         'ASHRAE 169-2013-4B',
         'ASHRAE 169-2013-4C',
         'ASHRAE 169-2013-5B',
         'ASHRAE 169-2013-6B',
         'ASHRAE 169-2013-7A',
         'ASHRAE 169-2013-7B',
         'ASHRAE 169-2013-8A',
         'ASHRAE 169-2013-8B'
      prohibited_types = ['FixedEnthalpy']
    when 'ASHRAE 169-2006-1A',
         'ASHRAE 169-2006-2A',
         'ASHRAE 169-2006-3A',
         'ASHRAE 169-2006-4A',
         'ASHRAE 169-2013-1A',
         'ASHRAE 169-2013-2A',
         'ASHRAE 169-2013-3A',
         'ASHRAE 169-2013-4A'
      prohibited_types = ['DifferentialDryBulb']
    when 'ASHRAE 169-2006-5A',
         'ASHRAE 169-2006-6A',
         'ASHRAE 169-2013-5A',
         'ASHRAE 169-2013-6A'
        prohibited_types = []
    end

    # Check if the specified type is allowed
    economizer_type_allowed = true
    if prohibited_types.include?(economizer_type)
      economizer_type_allowed = false
    end

    return economizer_type_allowed
  end

  # Check if ERV is required on this airloop.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def air_loop_hvac_energy_recovery_ventilator_required?(air_loop_hvac, climate_zone)
    # ERV Not Applicable for AHUs that serve
    # parking garage, warehouse, or multifamily
    # if space_types_served_names.include?('PNNL_Asset_Rating_Apartment_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_LowRiseApartment_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_ParkingGarage_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_Warehouse_Space_Type')
    # OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV not applicable because it because it serves parking garage, warehouse, or multifamily.")
    # return false
    # end

    erv_required = nil
    # ERV not applicable for medical AHUs (AHU1 in Outpatient), per AIA 2001 - 7.31.D2.
    # TODO refactor: move building type specific code
    if air_loop_hvac.name.to_s.include? 'Outpatient F1'
      erv_required = false
      return erv_required
    end

    # ERV not applicable for medical AHUs, per AIA 2001 - 7.31.D2.
    if air_loop_hvac.name.to_s.include? 'VAV_ER'
      erv_required = false
      return erv_required
    elsif air_loop_hvac.name.to_s.include? 'VAV_OR'
      erv_required = false
      return erv_required
    end
    case template
    when '90.1-2004', '90.1-2007' # TODO: Refactor figure out how to remove this.
      if air_loop_hvac.name.to_s.include? 'VAV_ICU'
        erv_required = false
        return erv_required
      elsif air_loop_hvac.name.to_s.include? 'VAV_PATRMS'
        erv_required = false
        return erv_required
      end
    end

    # ERV Not Applicable for AHUs that have DCV
    # or that have no OA intake.
    controller_oa = nil
    controller_mv = nil
    oa_system = nil
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      if controller_mv.demandControlledVentilation == true
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not applicable because DCV enabled.")
        return false
      end
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not applicable because it has no OA intake.")
      return false
    end

    # Get the AHU design supply air flow rate
    dsn_flow_m3_per_s = nil
    if air_loop_hvac.designSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = air_loop_hvac.designSupplyAirFlowRate.get
    elsif air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} design supply air flow rate is not available, cannot apply efficiency standard.")
      return false
    end
    dsn_flow_cfm = OpenStudio.convert(dsn_flow_m3_per_s, 'm^3/s', 'cfm').get

    # Get the minimum OA flow rate
    min_oa_flow_m3_per_s = nil
    if controller_oa.minimumOutdoorAirFlowRate.is_initialized
      min_oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
    elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
      min_oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{controller_oa.name}: minimum OA flow rate is not available, cannot apply efficiency standard.")
      return false
    end
    min_oa_flow_cfm = OpenStudio.convert(min_oa_flow_m3_per_s, 'm^3/s', 'cfm').get

    # Calculate the percent OA at design airflow
    pct_oa = min_oa_flow_m3_per_s / dsn_flow_m3_per_s

    # Determine the airflow limit
    erv_cfm = air_loop_hvac_energy_recovery_ventilator_flow_limit(air_loop_hvac, climate_zone, pct_oa)

    # Determine if an ERV is required
    if erv_cfm.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not required based on #{(pct_oa * 100).round}% OA flow, design supply air flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}.")
      erv_required = false
    elsif dsn_flow_cfm < erv_cfm
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not required based on #{(pct_oa * 100).round}% OA flow, design supply air flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}. Does not exceed minimum flow requirement of #{erv_cfm}cfm.")
      erv_required = false
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV required based on #{(pct_oa * 100).round}% OA flow, design supply air flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}. Exceeds minimum flow requirement of #{erv_cfm}cfm.")
      erv_required = true
    end

    return erv_required
  end

  # Determine the airflow limits that govern whether or not
  # an ERV is required.  Based on climate zone and % OA.
  # Defaults to DOE Ref Pre-1980, not required.
  # @return [Double] the flow rate above which an ERV is required.
  # if nil, ERV is never required.
  def air_loop_hvac_energy_recovery_ventilator_flow_limit(air_loop_hvac, climate_zone, pct_oa)
    erv_cfm = nil # Not required
    return erv_cfm
  end

  # Add an ERV to this airloop.
  # Will be a rotary-type HX
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def air_loop_hvac_apply_energy_recovery_ventilator(air_loop_hvac)
    # Get the oa system
    oa_system = nil
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV cannot be added because the system has no OA intake.")
      return false
    end

    # Create an ERV
    erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(air_loop_hvac.model)
    erv.setName("#{air_loop_hvac.name} ERV")
    erv.setSensibleEffectivenessat100HeatingAirFlow(0.7)
    erv.setLatentEffectivenessat100HeatingAirFlow(0.6)
    erv.setSensibleEffectivenessat75HeatingAirFlow(0.7)
    erv.setLatentEffectivenessat75HeatingAirFlow(0.6)
    erv.setSensibleEffectivenessat100CoolingAirFlow(0.75)
    erv.setLatentEffectivenessat100CoolingAirFlow(0.6)
    erv.setSensibleEffectivenessat75CoolingAirFlow(0.75)
    erv.setLatentEffectivenessat75CoolingAirFlow(0.6)
    erv.setSupplyAirOutletTemperatureControl(false)
    erv.setHeatExchangerType('Rotary')
    erv.setFrostControlType('ExhaustOnly')
    erv.setEconomizerLockout(true)
    erv.setThresholdTemperature(-23.3) # -10F
    erv.setInitialDefrostTimeFraction(0.167)
    erv.setRateofDefrostTimeFractionIncrease(1.44)

    # Add the ERV to the OA system
    erv.addToNode(oa_system.outboardOANode.get)

    # Add a setpoint manager OA pretreat
    # to control the ERV
    spm_oa_pretreat = OpenStudio::Model::SetpointManagerOutdoorAirPretreat.new(air_loop_hvac.model)
    spm_oa_pretreat.setMinimumSetpointTemperature(-99.0)
    spm_oa_pretreat.setMaximumSetpointTemperature(99.0)
    spm_oa_pretreat.setMinimumSetpointHumidityRatio(0.00001)
    spm_oa_pretreat.setMaximumSetpointHumidityRatio(1.0)
    # Reference setpoint node and
    # Mixed air stream node are outlet
    # node of the OA system
    mixed_air_node = oa_system.mixedAirModelObject.get.to_Node.get
    spm_oa_pretreat.setReferenceSetpointNode(mixed_air_node)
    spm_oa_pretreat.setMixedAirStreamNode(mixed_air_node)
    # Outdoor air node is
    # the outboard OA node of teh OA system
    spm_oa_pretreat.setOutdoorAirStreamNode(oa_system.outboardOANode.get)
    # Return air node is the inlet
    # node of the OA system
    return_air_node = oa_system.returnAirModelObject.get.to_Node.get
    spm_oa_pretreat.setReturnAirStreamNode(return_air_node)
    # Attach to the outlet of the ERV
    erv_outlet = erv.primaryAirOutletModelObject.get.to_Node.get
    spm_oa_pretreat.addToNode(erv_outlet)

    # Apply the prototype Heat Exchanger power assumptions.
    heat_exchanger_air_to_air_sensible_and_latent_apply_prototype_nominal_electric_power(erv)

    # Determine if the system is a DOAS based on
    # whether there is 100% OA in heating and cooling sizing.
    is_doas = false
    sizing_system = air_loop_hvac.sizingSystem
    if sizing_system.allOutdoorAirinCooling && sizing_system.allOutdoorAirinHeating
      is_doas = true
    end

    # Set the bypass control type
    # If DOAS system, BypassWhenWithinEconomizerLimits
    # to disable ERV during economizing.
    # Otherwise, BypassWhenOAFlowGreaterThanMinimum
    # to disable ERV during economizing and when OA
    # is also greater than minimum.
    bypass_ctrl_type = if is_doas
                         'BypassWhenWithinEconomizerLimits'
                       else
                         'BypassWhenOAFlowGreaterThanMinimum'
                       end
    oa_system.getControllerOutdoorAir.setHeatRecoveryBypassControlType(bypass_ctrl_type)

    return true
  end

  # Determine if multizone vav optimization is required.
  # Defaults to 90.1-2007 logic, where it is not required.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for
  #   systems with AIA healthcare ventilation requirements
  #   dual duct systems
  def air_loop_hvac_multizone_vav_optimization_required?(air_loop_hvac, climate_zone)
    multizone_opt_required = false
    return multizone_opt_required
  end

  # Enable multizone vav optimization by changing the Outdoor Air Method
  # in the Controller:MechanicalVentilation object to 'VentilationRateProcedure'
  #
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_enable_multizone_vav_optimization(air_loop_hvac)
    # Enable multizone vav optimization
    # at each timestep.
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')
      # Change the min flow rate in the controller outdoor air
      controller_oa.setMinimumOutdoorAirFlowRate(0.0)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, cannot enable multizone vav optimization because the system has no OA intake.")
      return false
    end
  end

  # Disable multizone vav optimization by changing the Outdoor Air Method
  # in the Controller:MechanicalVentilation object to 'ZoneSum'
  #
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_disable_multizone_vav_optimization(air_loop_hvac)
    # Disable multizone vav optimization
    # at each timestep.
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      controller_mv.setSystemOutdoorAirMethod('ZoneSum')
      controller_oa.autosizeMinimumOutdoorAirFlowRate
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, cannot disable multizone vav optimization because the system has no OA intake.")
      return false
    end
  end

  # Set the minimum VAV damper positions.
  #
  # @param has_ddc [Bool] if true, will assume that there
  # is DDC control of vav terminals.  If false, assumes otherwise.
  # @return [Bool] true if successful, false if not
  def air_loop_hvac_apply_minimum_vav_damper_positions(air_loop_hvac, has_ddc = true)
    air_loop_hvac.thermalZones.each do |zone|
      zone.equipment.each do |equip|
        if equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
          zone_oa = thermal_zone_outdoor_airflow_rate(zone)
          vav_terminal = equip.to_AirTerminalSingleDuctVAVReheat.get
          air_terminal_single_duct_vav_reheat_apply_minimum_damper_position(vav_terminal, zone_oa, has_ddc)
        end
      end
    end

    return true
  end

  # Adjust minimum VAV damper positions to the values
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def air_loop_hvac_adjust_minimum_vav_damper_positions(air_loop_hvac)
    # Total uncorrected outdoor airflow rate
    v_ou = 0.0
    air_loop_hvac.thermalZones.each do |zone|
      v_ou += thermal_zone_outdoor_airflow_rate(zone)
    end

    v_ou_cfm = OpenStudio.convert(v_ou, 'm^3/s', 'cfm').get

    # System primary airflow rate (whether autosized or hard-sized)
    v_ps = 0.0

    v_ps = if air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
             air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
           else
             air_loop_hvac.designSupplyAirFlowRate.get
           end
    v_ps_cfm = OpenStudio.convert(v_ps, 'm^3/s', 'cfm').get

    # Average outdoor air fraction
    x_s = v_ou / v_ps

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: v_ou = #{v_ou_cfm.round} cfm, v_ps = #{v_ps_cfm.round} cfm, x_s = #{x_s.round(2)}.")

    # Determine the zone ventilation effectiveness
    # for every zone on the system.
    # When ventilation effectiveness is too low,
    # increase the minimum damper position.
    e_vzs = []
    e_vzs_adj = []
    num_zones_adj = 0
    air_loop_hvac.thermalZones.sort.each do |zone|
      # Breathing zone airflow rate
      v_bz = thermal_zone_outdoor_airflow_rate(zone)

      # Zone air distribution, assumed 1 per PNNL
      e_z = 1.0

      # Zone airflow rate
      v_oz = v_bz / e_z

      # Primary design airflow rate
      # max of heating and cooling
      # design air flow rates
      v_pz = 0.0
      clg_dsn_flow = zone.autosizedCoolingDesignAirFlowRate
      if clg_dsn_flow.is_initialized
        clg_dsn_flow = clg_dsn_flow.get
        if clg_dsn_flow > v_pz
          v_pz = clg_dsn_flow
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: #{zone.name} clg_dsn_flow could not be found.")
      end
      htg_dsn_flow = zone.autosizedHeatingDesignAirFlowRate
      if htg_dsn_flow.is_initialized
        htg_dsn_flow = htg_dsn_flow.get
        if htg_dsn_flow > v_pz
          v_pz = htg_dsn_flow
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: #{zone.name} htg_dsn_flow could not be found.")
      end

      # Get the minimum damper position
      mdp_term = 1.0
      min_zn_flow = 0.0
      zone.equipment.each do |equip|
        if equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.get
          mdp_term = term.zoneMinimumAirFlowFraction
        elsif equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.get
          mdp_term = term.zoneMinimumAirFlowFraction
        elsif equip.to_AirTerminalSingleDuctVAVNoReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVNoReheat.get
          if term.constantMinimumAirFlowFraction.is_initialized
            mdp_term = term.constantMinimumAirFlowFraction.get
          end
        elsif equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVReheat.get
          if term.constantMinimumAirFlowFraction.is_initialized
            mdp_term = term.constantMinimumAirFlowFraction.get
          end
          if term.fixedMinimumAirFlowRate.is_initialized
            min_zn_flow = term.fixedMinimumAirFlowRate.get
          end
        end
      end

      # For VAV Reheat terminals, min flow is greater of mdp
      # and min flow rate / design flow rate.
      mdp = mdp_term
      mdp_oa = min_zn_flow / v_ps
      if min_zn_flow > 0.0
        mdp = [mdp_term, mdp_oa].max.round(2)
      end
      # OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Zone #{zone.name} mdp_term = #{mdp_term.round(2)}, mdp_oa = #{mdp_oa.round(2)}; mdp_final = #{mdp}")

      # Zone minimum discharge airflow rate
      v_dz = v_pz * mdp

      # Zone discharge air fraction
      z_d = v_oz / v_dz

      # Zone ventilation effectiveness  !!!
      e_vz = 1.0 + x_s - z_d

      # Store the ventilation effectiveness
      e_vzs << e_vz

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Zone #{zone.name} v_oz = #{v_oz.round(2)} m^3/s, v_pz = #{v_pz.round(2)} m^3/s, v_dz = #{v_dz.round(2)}, z_d = #{z_d.round(2)}.")

      # Check the ventilation effectiveness against
      # the minimum limit per PNNL and increase
      # as necessary.
      if e_vz < 0.6

        # Adjusted discharge air fraction
        z_d_adj = 1.0 + x_s - 0.6

        # Adjusted min discharge airflow rate
        v_dz_adj = v_oz / z_d_adj

        # Adjusted minimum damper position
        mdp_adj = v_dz_adj / v_pz

        # Don't allow values > 1
        if mdp_adj > 1.0
          mdp_adj = 1.0
        end

        # Zone ventilation effectiveness
        e_vz_adj = 1.0 + x_s - z_d_adj

        # Store the ventilation effectiveness
        e_vzs_adj << e_vz_adj

        # Round the minimum damper position to avoid nondeterministic results
        # at the ~13th decimal place, which can cause regression errors
        mdp_adj = mdp_adj.round(11)

        # Set the adjusted minimum damper position
        zone.equipment.each do |equip|
          if equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.get
            term.setZoneMinimumAirFlowFraction(mdp_adj)
          elsif equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.get
            term.setZoneMinimumAirFlowFraction(mdp_adj)
          elsif equip.to_AirTerminalSingleDuctVAVNoReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVNoReheat.get
            term.setConstantMinimumAirFlowFraction(mdp_adj)
          elsif equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVReheat.get
            term.setConstantMinimumAirFlowFraction(mdp_adj)
          end
        end

        num_zones_adj += 1

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Zone #{zone.name} has a ventilation effectiveness of #{e_vz.round(2)}.  Increasing to #{e_vz_adj.round(2)} by increasing minimum damper position from #{mdp.round(2)} to #{mdp_adj.round(2)}.")

      else
        # Store the unadjusted value
        e_vzs_adj << e_vz
      end
    end

    # Min system zone ventilation effectiveness
    e_v = e_vzs.min

    # Total system outdoor intake flow rate
    v_ot = v_ou / e_v
    v_ot_cfm = OpenStudio.convert(v_ot, 'm^3/s', 'cfm').get

    # Min system zone ventilation effectiveness
    e_v_adj = e_vzs_adj.min

    # Total system outdoor intake flow rate
    v_ot_adj = v_ou / e_v_adj
    v_ot_adj_cfm = OpenStudio.convert(v_ot_adj, 'm^3/s', 'cfm').get

    # Report out the results of the multizone calculations
    if num_zones_adj > 0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: the multizone outdoor air calculation method was applied.  A simple summation of the zone outdoor air requirements gives a value of #{v_ou_cfm.round} cfm.  Applying the multizone method gives a value of #{v_ot_cfm.round} cfm, with an original system ventilation effectiveness of #{e_v.round(2)}.  After increasing the minimum damper position in #{num_zones_adj} critical zones, the resulting requirement is #{v_ot_adj_cfm.round} cfm with a system ventilation effectiveness of #{e_v_adj.round(2)}.")
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: the multizone outdoor air calculation method was applied.  A simple summation of the zone requirements gives a value of #{v_ou_cfm.round} cfm.  However, applying the multizone method requires #{v_ot_adj_cfm.round} cfm based on the ventilation effectiveness of the system.")
    end

    # Hard-size the sizing:system
    # object with the calculated min OA flow rate
    sizing_system = air_loop_hvac.sizingSystem
    sizing_system.setDesignOutdoorAirFlowRate(v_ot_adj)

    return true
  end

  # For critical zones of Outpatient, if the minimum airflow rate required by the accreditation standard (AIA 2001) is significantly
  # less than the autosized peak design airflow in any of the three climate zones (Houston, Baltimore and Burlington), the minimum
  # airflow fraction of the terminal units is reduced to the value: "required minimum airflow rate / autosized peak design flow"
  # Reference: <Achieving the 30% Goal: Energy and Cost Savings Analysis of ASHRAE Standard 90.1-2010> Page109-111
  # For implementation purpose, since it is time-consuming to perform autosizing in three climate zones, just use
  # the results of the current climate zone
  def air_loop_hvac_adjust_minimum_vav_damper_positions_outpatient(air_loop_hvac)
    air_loop_hvac.model.getSpaces.sort.each do |space|
      zone = space.thermalZone.get
      sizing_zone = zone.sizingZone
      space_area = space.floorArea
      if sizing_zone.coolingDesignAirFlowMethod == 'DesignDay'
        next
      elsif sizing_zone.coolingDesignAirFlowMethod == 'DesignDayWithLimit'
        minimum_airflow_per_zone_floor_area = sizing_zone.coolingMinimumAirFlowperZoneFloorArea
        minimum_airflow_per_zone = minimum_airflow_per_zone_floor_area * space_area
        # get the autosized maximum air flow of the VAV terminal
        zone.equipment.each do |equip|
          if equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
            vav_terminal = equip.to_AirTerminalSingleDuctVAVReheat.get
            rated_maximum_flow_rate = vav_terminal.autosizedMaximumAirFlowRate.get
            # compare the VAV autosized maximum airflow with the minimum airflow rate required by the accreditation standard
            ratio = minimum_airflow_per_zone / rated_maximum_flow_rate
            if ratio >= 0.95
              vav_terminal.setConstantMinimumAirFlowFraction(1)
            elsif ratio < 0.95
              vav_terminal.setConstantMinimumAirFlowFraction(ratio)
            end
          end
        end
      end
    end
    return true
  end

  # Determine if demand control ventilation (DCV) is
  # required for this air loop.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for
  #   systems that serve multifamily, parking garage, warehouse
  def air_loop_hvac_demand_control_ventilation_required?(air_loop_hvac, climate_zone)
    dcv_required = false

    # OA flow limits
    min_oa_without_economizer_cfm, min_oa_with_economizer_cfm = air_loop_hvac_demand_control_ventilation_limits(air_loop_hvac)

    # If the limits are zero for both, DCV not required
    if min_oa_without_economizer_cfm.zero? && min_oa_with_economizer_cfm.zero?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{air_loop_hvac.name}: DCV is not required for any system.")
      return dcv_required
    end

    # Check if the system has an ERV
    if air_loop_hvac_energy_recovery?(air_loop_hvac)
      # May or may not be required for systems that have an ERV
      if air_loop_hvac_dcv_required_when_erv(air_loop_hvac)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: DCV may be required although the system has Energy Recovery.")
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: DCV is not required since the system has Energy Recovery.")
        return dcv_required
      end
    end

    # Get the min OA flow rate
    oa_flow_m3_per_s = 0
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      if controller_oa.minimumOutdoorAirFlowRate.is_initialized
        oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
      elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
        oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
      end
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, DCV not applicable because it has no OA intake.")
      return dcv_required
    end
    oa_flow_cfm = OpenStudio.convert(oa_flow_m3_per_s, 'm^3/s', 'cfm').get

    # Check for min OA without an economizer OR has economizer
    if oa_flow_cfm < min_oa_without_economizer_cfm && air_loop_hvac_economizer?(air_loop_hvac) == false
      # Message if doesn't pass OA limit
      if oa_flow_cfm < min_oa_without_economizer_cfm
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: DCV is not required since the system min oa flow is #{oa_flow_cfm.round} cfm, less than the minimum of #{min_oa_without_economizer_cfm.round} cfm.")
      end
      # Message if doesn't have economizer
      if air_loop_hvac_economizer?(air_loop_hvac) == false
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: DCV is not required since the system does not have an economizer.")
      end
      return dcv_required
    end

    # If has economizer, cfm limit is lower
    if oa_flow_cfm < min_oa_with_economizer_cfm && air_loop_hvac_economizer?(air_loop_hvac)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: DCV is not required since the system has an economizer, but the min oa flow is #{oa_flow_cfm.round} cfm, less than the minimum of #{min_oa_with_economizer_cfm.round} cfm for systems with an economizer.")
      return dcv_required
    end

    # Check area and density limits
    # for all of zones on the loop
    any_zones_req_dcv = false
    air_loop_hvac.thermalZones.sort.each do |zone|
      if thermal_zone_demand_control_ventilation_required?(zone, climate_zone)
        any_zones_req_dcv = true
        break
      end
    end
    unless any_zones_req_dcv
      return dcv_required
    end

    # If here, DCV is required
    dcv_required = true

    return dcv_required
  end

  # Determines the OA flow rates above which an economizer is required.
  # Two separate rates, one for systems with an economizer and another
  # for systems without.  Defaults to pre-1980 logic, where the limits
  # are zero for both types.
  # @return [Array<Double>] [min_oa_without_economizer_cfm, min_oa_with_economizer_cfm]
  def air_loop_hvac_demand_control_ventilation_limits(air_loop_hvac)
    min_oa_without_economizer_cfm = 0
    min_oa_with_economizer_cfm = 0
    return [min_oa_without_economizer_cfm, min_oa_with_economizer_cfm]
  end

  # Determine if the standard has an exception for demand control ventilation
  # when an energy recovery device is present.  Defaults to true.
  def air_loop_hvac_dcv_required_when_erv(air_loop_hvac)
    dcv_required_when_erv_present = false
    return dcv_required_when_erv_present
  end

  # Enable demand control ventilation (DCV) for this air loop.
  # Zones on this loop that require DCV preserve
  # both per-area and per-person OA reqs.
  # Other zones have OA reqs converted
  # to per-area values only so that DCV won't impact these zones.
  #
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_enable_demand_control_ventilation(air_loop_hvac, climate_zone)
    # Get the OA intake
    controller_oa = nil
    controller_mv = nil
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      if controller_mv.demandControlledVentilation == true
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: DCV was already enabled.")
        return true
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Could not enable DCV since the system has no OA intake.")
      return false
    end

    # Change the min flow rate in the controller outdoor air
    controller_oa.setMinimumOutdoorAirFlowRate(0.0)

    # Enable DCV in the controller mechanical ventilation
    controller_mv.setDemandControlledVentilation(true)

    return true
  end

  # Determine if the system required supply air temperature
  # (SAT) reset. Defaults to 90.1-2007, no SAT reset required.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_supply_air_temperature_reset_required?(air_loop_hvac, climate_zone)
    is_sat_reset_required = false
    return is_sat_reset_required
  end

  # Enable supply air temperature (SAT) reset based
  # on the cooling demand of the warmest zone.
  #
  # @return [Bool] Returns true if successful, false if not.
  def air_loop_hvac_enable_supply_air_temperature_reset_warmest_zone(air_loop_hvac)
    # Get the current setpoint and calculate
    # the new setpoint.
    sizing_system = air_loop_hvac.sizingSystem
    design_sat_c = sizing_system.centralCoolingDesignSupplyAirTemperature
    design_sat_f = OpenStudio.convert(design_sat_c, 'C', 'F').get

    # Get the SAT reset delta
    sat_reset_r = air_loop_hvac_enable_supply_air_temperature_reset_delta(air_loop_hvac)
    sat_reset_k = OpenStudio.convert(sat_reset_r, 'R', 'K').get

    max_sat_f = design_sat_f + sat_reset_r
    max_sat_c = design_sat_c + sat_reset_k

    # Create a setpoint manager
    sat_warmest_reset = OpenStudio::Model::SetpointManagerWarmest.new(air_loop_hvac.model)
    sat_warmest_reset.setName("#{air_loop_hvac.name} SAT Warmest Reset")
    sat_warmest_reset.setStrategy('MaximumTemperature')
    sat_warmest_reset.setMinimumSetpointTemperature(design_sat_c)
    sat_warmest_reset.setMaximumSetpointTemperature(max_sat_c)

    # Attach the setpoint manager to the
    # supply outlet node of the system.
    sat_warmest_reset.addToNode(air_loop_hvac.supplyOutletNode)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Supply air temperature reset was enabled using a SPM Warmest with a min SAT of #{design_sat_f.round}F and a max SAT of #{max_sat_f.round}F.")

    return true
  end

  # Determines supply air temperature (SAT) temperature.
  # Defaults to 90.1-2007, 5 delta-F (R)
  #
  # @return [Double] the SAT reset amount (R)
  def air_loop_hvac_enable_supply_air_temperature_reset_delta(air_loop_hvac)
    sat_reset_r = 5
    return sat_reset_r
  end

  # Enable supply air temperature (SAT) reset based
  # on outdoor air conditions.  SAT will be kept at the
  # current design temperature when outdoor air is above 70F,
  # increased by 5F when outdoor air is below 50F, and reset
  # linearly when outdoor air is between 50F and 70F.
  #
  # @return [Bool] Returns true if successful, false if not.

  def air_loop_hvac_enable_supply_air_temperature_reset_outdoor_temperature(air_loop_hvac)
    # for AHU1 in Outpatient, SAT is 52F constant, no reset
    return true if air_loop_hvac.name.get == 'PVAV Outpatient F1'

    # Get the current setpoint and calculate
    # the new setpoint.
    sizing_system = air_loop_hvac.sizingSystem
    sat_at_hi_oat_c = sizing_system.centralCoolingDesignSupplyAirTemperature
    sat_at_hi_oat_f = OpenStudio.convert(sat_at_hi_oat_c, 'C', 'F').get
    # 5F increase when it's cold outside,
    # and therefore less cooling capacity is likely required.
    increase_f = 5.0
    sat_at_lo_oat_f = sat_at_hi_oat_f + increase_f
    sat_at_lo_oat_c = OpenStudio.convert(sat_at_lo_oat_f, 'F', 'C').get

    # Define the high and low outdoor air temperatures
    lo_oat_f = 50
    lo_oat_c = OpenStudio.convert(lo_oat_f, 'F', 'C').get
    hi_oat_f = 70
    hi_oat_c = OpenStudio.convert(hi_oat_f, 'F', 'C').get

    # Create a setpoint manager
    sat_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(air_loop_hvac.model)
    sat_oa_reset.setName("#{air_loop_hvac.name} SAT Reset")
    sat_oa_reset.setControlVariable('Temperature')
    sat_oa_reset.setSetpointatOutdoorLowTemperature(sat_at_lo_oat_c)
    sat_oa_reset.setOutdoorLowTemperature(lo_oat_c)
    sat_oa_reset.setSetpointatOutdoorHighTemperature(sat_at_hi_oat_c)
    sat_oa_reset.setOutdoorHighTemperature(hi_oat_c)

    # Attach the setpoint manager to the
    # supply outlet node of the system.
    sat_oa_reset.addToNode(supplyOutletNode)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Supply air temperature reset was enabled.  When OAT > #{hi_oat_f.round}F, SAT is #{sat_at_hi_oat_f.round}F.  When OAT < #{lo_oat_f.round}F, SAT is #{sat_at_lo_oat_f.round}F.  It varies linearly in between these points.")

    return true
  end

  # Determine if the system has an economizer
  #
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_economizer?(air_loop_hvac)
    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType

    # Return false if no economizer is present
    if economizer_type == 'NoEconomizer'
      return false
    else
      return true
    end
  end

  # Determine if the system is a VAV system based on the fan
  # which may be inside of a unitary system.
  def air_loop_hvac_vav_system?(air_loop_hvac)
    is_vav = false
    air_loop_hvac.supplyComponents.reverse.each do |comp|
      if comp.to_FanVariableVolume.is_initialized
        is_vav = true
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if fan.to_FanVariableVolume.is_initialized
          is_vav = true
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        if fan.is_initialized
          if fan.get.to_FanVariableVolume.is_initialized
            is_vav = true
          end
        end
      end
    end

    return is_vav
  end

  # Determine if the system is a multizone VAV system
  #
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_multizone_vav_system?(air_loop_hvac)
    multizone_vav_system = false

    # Must serve more than 1 zone
    if air_loop_hvac.thermalZones.size < 2
      return multizone_vav_system
    end

    # Must be a variable volume system
    is_vav = air_loop_hvac_vav_system?(air_loop_hvac)
    if is_vav == false
      return multizone_vav_system
    end

    # If here, it's a multizone VAV system
    multizone_vav_system = true

    return multizone_vav_system
  end

  # Determine if the system has terminal reheat
  #
  # @return [Bool] returns true if has one or more reheat terminals, false if it doesn't.
  def air_loop_hvac_terminal_reheat?(air_loop_hvac)
    has_term_rht = false
    air_loop_hvac.demandComponents.each do |sc|
      if sc.to_AirTerminalSingleDuctConstantVolumeReheat.is_initialized ||
         sc.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized ||
         sc.to_AirTerminalSingleDuctSeriesPIUReheat.is_initialized ||
         sc.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.is_initialized ||
         sc.to_AirTerminalSingleDuctVAVReheat.is_initialized
        has_term_rht = true
        break
      end
    end

    return has_term_rht
  end

  # Determine if the system has energy recovery already
  #
  # @return [Bool] Returns true if an ERV is present, false if not.
  def air_loop_hvac_energy_recovery?(air_loop_hvac)
    has_erv = false

    # Get the OA system
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return has_erv # No OA system
    end

    # Find any ERV on the OA system
    oa_sys.oaComponents.each do |oa_comp|
      if oa_comp.to_HeatExchangerAirToAirSensibleAndLatent.is_initialized
        has_erv = true
      end
    end

    return has_erv
  end

  # Set the VAV damper control to single maximum or dual maximum control depending on the standard.
  #
  # @return [Bool] Returns true if successful, false if not
  # @todo see if this impacts the sizing run.
  def air_loop_hvac_apply_vav_damper_action(air_loop_hvac)
    damper_action = air_loop_hvac_vav_damper_action(air_loop_hvac)

    # Interpret this as an EnergyPlus input
    damper_action_eplus = nil
    if damper_action == 'Single Maximum'
      damper_action_eplus = 'Normal'
    elsif damper_action == 'Dual Maximum'
      # EnergyPlus 8.7 changed the meaning of 'Reverse'.
      # For versions of OpenStudio using E+ 8.6 or lower
      damper_action_eplus = if air_loop_hvac.model.version < OpenStudio::VersionString.new('2.0.5')
                              'Reverse'
                            # For versions of OpenStudio using E+ 8.7 or higher
                            else
                              'ReverseWithLimits'
                            end
    end

    # Set the control for any VAV reheat terminals on this airloop.
    control_type_set = false
    air_loop_hvac.demandComponents.each do |equip|
      if equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
        term = equip.to_AirTerminalSingleDuctVAVReheat.get
        # Dual maximum only applies to terminals with HW reheat coils
        if damper_action == 'Dual Maximum'
          if term.reheatCoil.to_CoilHeatingWater.is_initialized
            term.setDamperHeatingAction(damper_action_eplus)
            control_type_set = true
          end
        else
          term.setDamperHeatingAction(damper_action_eplus)
          control_type_set = true
          term.setMaximumFlowFractionDuringReheat(0.5)
        end
      end
    end

    if control_type_set
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: VAV damper action was set to #{damper_action} control.")
    end

    return true
  end

  # Determine whether the VAV damper control is single maximum or dual maximum control.
  # Defaults to 90.1-2007.
  #
  # @return [String] the damper control type: Single Maximum, Dual Maximum
  def air_loop_hvac_vav_damper_action(air_loop_hvac)
    damper_action = 'Dual Maximum'
    return damper_action
  end

  # Determine if a motorized OA damper is required
  def air_loop_hvac_motorized_oa_damper_required?(air_loop_hvac, climate_zone)
    motorized_oa_damper_required = false

    # TODO: refactor: Remove building type dependent logic
    if air_loop_hvac.name.to_s.include? 'Outpatient F1'
      motorized_oa_damper_required = true
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: always has a damper, the minimum OA schedule is the same as airloop availability schedule.")
      return motorized_oa_damper_required
    end

    # If the system has an economizer, it must have a motorized damper.
    if air_loop_hvac_economizer?(air_loop_hvac)
      motorized_oa_damper_required = true
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Because the system has an economizer, it requires a motorized OA damper.")
      return motorized_oa_damper_required
    end

    # Determine the exceptions based on
    # number of stories, climate zone, and
    # outdoor air intake rates.
    minimum_oa_flow_cfm, maximum_stories = air_loop_hvac_motorized_oa_damper_limits(air_loop_hvac, climate_zone)

    # Assuming that buildings not requiring this always
    # used backdraft gravity dampers
    if minimum_oa_flow_cfm.nil? && maximum_stories.nil?
      return motorized_oa_damper_required
    end

    # Get the number of stories
    num_stories = air_loop_hvac.model.getBuildingStorys.size

    # Check the number of stories exception,
    # which is climate-zone dependent.
    if num_stories < maximum_stories
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Motorized OA damper not required because the building has #{num_stories} stories, less than the minimum of #{maximum_stories} stories for climate zone #{climate_zone}.")
      return motorized_oa_damper_required
    end

    # Get the min OA flow rate
    oa_flow_m3_per_s = 0
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      if controller_oa.minimumOutdoorAirFlowRate.is_initialized
        oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
      elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
        oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Could not determine the minimum OA flow rate, cannot determine if a motorized OA damper is required.")
        return motorized_oa_damper_required
      end
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, Motorized OA damper not applicable because it has no OA intake.")
      return motorized_oa_damper_required
    end
    oa_flow_cfm = OpenStudio.convert(oa_flow_m3_per_s, 'm^3/s', 'cfm').get

    # Check the OA flow rate exception
    if oa_flow_cfm < minimum_oa_flow_cfm
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Motorized OA damper not required because the system OA intake of #{oa_flow_cfm.round} cfm is less than the minimum threshold of #{minimum_oa_flow_cfm} cfm.")
      return motorized_oa_damper_required
    end

    # If here, motorized damper is required
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Motorized OA damper is required because the building has #{num_stories} stories, >= the minimum of #{maximum_stories} stories for climate zone #{climate_zone}, and the system OA intake of #{oa_flow_cfm.round} cfm is >= the minimum threshold of #{minimum_oa_flow_cfm} cfm. ")
    motorized_oa_damper_required = true

    return motorized_oa_damper_required
  end

  # Determine the air flow and number of story limits
  # for whether motorized OA damper is required. Defaults
  # to DOE Ref Pre-1980 logic (never required).
  # @return [Array<Double>] [minimum_oa_flow_cfm, maximum_stories].
  # If both nil, never required
  def air_loop_hvac_motorized_oa_damper_limits(air_loop_hvac, climate_zone)
    minimum_oa_flow_cfm = nil
    maximum_stories = nil
    return [minimum_oa_flow_cfm, maximum_stories]
  end

  # Add a motorized damper by modifying the OA schedule
  # to require zero OA during unoccupied hours.  This means
  # that even during morning warmup or nightcyling, no OA will
  # be brought into the building, lowering heating/cooling load.
  # If no occupancy schedule is supplied, one will be created.
  # In this case, occupied is defined as the total percent
  # occupancy for the loop for all zones served.  If the OA schedule
  # is already other than Always On, will assume that this schedule
  # reflects a motorized OA damper and not change.
  #
  # @param min_occ_pct [Double] the fractional value below which
  # the system will be considered unoccupied.
  # @param occ_sch [OpenStudio::Model::Schedule] the occupancy schedule.
  # If not supplied, one will be created based on the supplied
  # occupancy threshold.
  # @return [Bool] true if successful, false if not
  def air_loop_hvac_add_motorized_oa_damper(air_loop_hvac, min_occ_pct = 0.05, occ_sch = nil)
    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir

    # Get the current min OA schedule and do nothing
    # if it is already set to something other than Always On
    if oa_control.minimumOutdoorAirSchedule.is_initialized
      min_oa_sch = oa_control.minimumOutdoorAirSchedule.get
      unless min_oa_sch == air_loop_hvac.model.alwaysOnDiscreteSchedule
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Min OA damper schedule is already set to #{min_oa_sch.name}, assume this includes correct motorized OA damper control.")
        return true
      end
    end

    # Get the airloop occupancy schedule if none supplied
    # or if the supplied availability schedule is Always On, implying
    # that the availability schedule does not reflect occupancy.
    if occ_sch.nil? || occ_sch == air_loop_hvac.model.alwaysOnDiscreteSchedule
      occ_sch = air_loop_hvac_get_occupancy_schedule(air_loop_hvac, occupied_percentage_threshold: min_occ_pct)
      flh = schedule_ruleset_annual_equivalent_full_load_hrs(occ_sch)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Annual occupied hours = #{flh.round} hr/yr, assuming a #{min_occ_pct} occupancy threshold.  This schedule will be used to close OA damper during unoccupied hours.")
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Setting motorized OA damper schedule to #{occ_sch.name}.")
    end

    # Set the minimum OA schedule to follow occupancy
    oa_control.setMinimumOutdoorAirSchedule(occ_sch)

    return true
  end

  # Remove a motorized OA damper by modifying the OA schedule
  # to require full OA at all times.  Whenever the fan operates,
  # the damper will be open and OA will be brought into the building.
  # This reflects the use of a backdraft gravity damper, and
  # increases building loads unnecessarily during unoccupied hours.
  def air_loop_hvac_remove_motorized_oa_damper(air_loop_hvac)
    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir

    # Set the minimum OA schedule to always 1 (100%)
    oa_control.setMinimumOutdoorAirSchedule(air_loop_hvac.model.alwaysOnDiscreteSchedule)

    return true
  end

  # This method creates a new discrete fractional schedule ruleset.
  # The value is set to one when occupancy across all zones
  # is greater than or equal to the occupied_percentage_threshold, and zero all other times.
  # This method is designed to use the total number of people on the airloop,
  # so if there is a zone that is continuously occupied by a few people,
  # but other zones that are intermittently occupied by many people,
  # the first zone doesn't drive the entire system.
  #
  # @param air_loop_hvac [<OpenStudio::Model::AirLoopHVAC>] air loop to create occupancy schedule
  # @param occupied_percentage_threshold [Double] the minimum fraction (0 to 1) that counts as occupied
  # @return [ScheduleRuleset] a ScheduleRuleset where 0 = unoccupied, 1 = occupied
  def air_loop_hvac_get_occupancy_schedule(air_loop_hvac, occupied_percentage_threshold: 0.05)
    # Create combined occupancy schedule of every space in every zone served by this airloop
    sch_ruleset = thermal_zones_get_occupancy_schedule(air_loop_hvac.thermalZones,
                                                       sch_name: "#{air_loop_hvac.name} Occ Sch",
                                                       occupied_percentage_threshold: occupied_percentage_threshold)
    return sch_ruleset
  end

  # Generate the EMS used to implement the economizer
  # and staging controls for packaged single zone units.
  #
  # @return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_single_zone_controls(air_loop_hvac, climate_zone)
    # These controls only apply to systems with DX cooling
    unless air_loop_hvac_dx_cooling?(air_loop_hvac)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Single zone controls not applicable because no DX cooling.")
      return true
    end

    # Number of stages is determined by the template
    num_stages = air_loop_hvac_single_zone_controls_num_stages(air_loop_hvac, climate_zone)

    # If zero stages, no special control is required
    if num_stages.zero?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: No special economizer controls were modeled.")
      return true
    end

    # Fan control program only used for systems with two-stage DX coils
    fan_control = if air_loop_hvac_multi_stage_dx_cooling?(air_loop_hvac)
                    true
                  else
                    false
                  end

    # Scrub special characters from the system name
    sn = air_loop_hvac.name.get.to_s
    snc = sn.gsub(/\W/, '').delete('_')
    # If the name starts with a number, prepend with a letter
    if snc[0] =~ /[0-9]/
      snc = "SYS#{snc}"
    end

    # Get the zone name
    zone = air_loop_hvac.thermalZones[0]
    zone_name = zone.name.get.to_s
    zn_name_clean = zone_name.gsub(/\W/, '_')

    # Zone air node
    zone_air_node = zone.zoneAirNode

    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    oa_node = oa_sys.outboardOANode.get

    # Get the name of the min oa schedule
    min_oa_sch = if oa_control.minimumOutdoorAirSchedule.is_initialized
                   oa_control.minimumOutdoorAirSchedule.get
                 else
                   air_loop_hvac.model.alwaysOnDiscreteSchedule
                 end

    # Get the supply fan
    if air_loop_hvac.supplyFan.empty?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: No supply fan found, cannot apply DX fan/economizer control.")
      return false
    end
    fan = air_loop_hvac.supplyFan.get

    # Supply outlet node
    sup_out_node = air_loop_hvac.supplyOutletNode

    # DX Cooling Coil
    dx_coil = nil
    air_loop_hvac.supplyComponents.each do |equip|
      if equip.to_CoilCoolingDXSingleSpeed.is_initialized
        dx_coil = equip.to_CoilCoolingDXSingleSpeed.get
      elsif equip.to_CoilCoolingDXTwoSpeed.is_initialized
        dx_coil = equip.to_CoilCoolingDXTwoSpeed.get
      end
    end
    if dx_coil.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: No DX cooling coil found, cannot apply DX fan/economizer control.")
      return false
    end

    # Heating Coil
    htg_coil = nil
    air_loop_hvac.supplyComponents.each do |equip|
      if equip.to_CoilHeatingGas.is_initialized
        htg_coil = equip.to_CoilHeatingGas.get
      elsif equip.to_CoilHeatingElectric.is_initialized
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: electric heating coil was found, cannot apply DX fan/economizer control.")
        return false
      elsif equip.to_CoilHeatingWater.is_initialized
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: hot water heating coil was found found, cannot apply DX fan/economizer control.")
        return false
      end
    end
    if htg_coil.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: No heating coil found, cannot apply DX fan/economizer control.")
      return false
    end

    # Create an economizer maximum OA fraction schedule with
    # a maximum of 70% to reflect damper leakage per PNNL
    max_oa_sch_name = "#{snc}maxOASch"
    max_oa_sch = OpenStudio::Model::ScheduleRuleset.new(air_loop_hvac.model)
    max_oa_sch.setName(max_oa_sch_name)
    max_oa_sch.defaultDaySchedule.setName("#{max_oa_sch_name}Default")
    max_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.7)
    oa_control.setMaximumFractionofOutdoorAirSchedule(max_oa_sch)

    ### EMS shared by both programs ###
    # Sensors
    oat_db_c_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'Site Outdoor Air Drybulb Temperature')
    oat_db_c_sen.setName('OATF')
    oat_db_c_sen.setKeyName('Environment')

    oat_wb_c_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'Site Outdoor Air Wetbulb Temperature')
    oat_wb_c_sen.setName('OAWBC')
    oat_wb_c_sen.setKeyName('Environment')

    oa_sch_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'Schedule Value')
    oa_sch_sen.setName("#{snc}OASch")
    oa_sch_sen.setKeyName(min_oa_sch.handle.to_s)

    oa_flow_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'System Node Mass Flow Rate')
    oa_flow_sen.setName("#{snc}OAFlowMass")
    oa_flow_sen.setKeyName(oa_node.handle.to_s)

    dat_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'System Node Setpoint Temperature')
    dat_sen.setName("#{snc}DATRqd")
    dat_sen.setKeyName(sup_out_node.handle.to_s)

    # Internal Variables
    oa_flow_var = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(air_loop_hvac.model, 'Outdoor Air Controller Minimum Mass Flow Rate')
    oa_flow_var.setName("#{snc}OADesignMass")
    oa_flow_var.setInternalDataIndexKeyName(oa_control.handle.to_s)

    # Global Variables
    gvar = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(air_loop_hvac.model, "#{snc}NumberofStages")

    # Programs
    num_stg_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(air_loop_hvac.model)
    num_stg_prg.setName("#{snc}SetNumberofStages")
    num_stg_prg_body = <<-EMS
      SET #{snc}NumberofStages = #{num_stages}
    EMS
    num_stg_prg.setBody(num_stg_prg_body)

    # Program Calling Managers
    setup_mgr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(air_loop_hvac.model)
    setup_mgr.setName("#{snc}SetNumberofStagesCallingManager")
    setup_mgr.setCallingPoint('BeginNewEnvironment')
    setup_mgr.addProgram(num_stg_prg)

    ### Fan Control ###
    if fan_control

      ### Economizer Control ###
      # Actuators
      econ_eff_act = OpenStudio::Model::EnergyManagementSystemActuator.new(max_oa_sch, 'Schedule:Year', 'Schedule Value')
      econ_eff_act.setName("#{snc}TimestepEconEff")

      # Programs
      econ_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(air_loop_hvac.model)
      econ_prg.setName("#{snc}EconomizerCTRLProg")
      econ_prg_body = <<-EMS
        SET #{econ_eff_act.handle} = 0.7
        SET MaxE = 0.7
        SET #{dat_sen.handle} = (#{dat_sen.handle}*1.8)+32
        SET OATF = (#{oat_db_c_sen.handle}*1.8)+32
        SET OAwbF = (#{oat_wb_c_sen.handle}*1.8)+32
        IF #{oa_flow_sen.handle} > (#{oa_flow_var.handle}*#{oa_sch_sen.handle})
          SET EconoActive = 1
        ELSE
          SET EconoActive = 0
        ENDIF
        SET dTNeeded = 75-#{dat_sen.handle}
        SET CoolDesdT = ((98*0.15)+(75*(1-0.15)))-55
        SET CoolLoad = dTNeeded/ CoolDesdT
        IF CoolLoad > 1
          SET CoolLoad = 1
        ELSEIF CoolLoad < 0
          SET CoolLoad = 0
        ENDIF
        IF EconoActive == 1
          SET Stage = #{snc}NumberofStages
          IF Stage == 2
            IF CoolLoad < 0.6
              SET #{econ_eff_act.handle} = MaxE
            ELSE
              SET ECOEff = 0-2.18919863612305
              SET ECOEff = ECOEff+(0-0.674461284910428*CoolLoad)
              SET ECOEff = ECOEff+(0.000459106275872404*(OATF^2))
              SET ECOEff = ECOEff+(0-0.00000484778537945252*(OATF^3))
              SET ECOEff = ECOEff+(0.182915713033586*OAwbF)
              SET ECOEff = ECOEff+(0-0.00382838660261133*(OAwbF^2))
              SET ECOEff = ECOEff+(0.0000255567460240583*(OAwbF^3))
              SET #{econ_eff_act.handle} = ECOEff
            ENDIF
          ELSE
            SET ECOEff = 2.36337942464462
            SET ECOEff = ECOEff+(0-0.409939515512619*CoolLoad)
            SET ECOEff = ECOEff+(0-0.0565205596792225*OAwbF)
            SET ECOEff = ECOEff+(0-0.0000632612294169389*(OATF^2))
            SET #{econ_eff_act.handle} = ECOEff+(0.000571724868775081*(OAwbF^2))
          ENDIF
          IF #{econ_eff_act.handle} > MaxE
            SET #{econ_eff_act.handle} = MaxE
          ELSEIF #{econ_eff_act.handle} < (#{oa_flow_var.handle}*#{oa_sch_sen.handle})
            SET #{econ_eff_act.handle} = (#{oa_flow_var.handle}*#{oa_sch_sen.handle})
          ENDIF
        ENDIF
      EMS
      econ_prg.setBody(econ_prg_body)

      # Program Calling Managers
      econ_mgr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(air_loop_hvac.model)
      econ_mgr.setName("#{snc}EcoManager")
      econ_mgr.setCallingPoint('InsideHVACSystemIterationLoop')
      econ_mgr.addProgram(econ_prg)

      # Sensors
      zn_temp_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'System Node Temperature')
      zn_temp_sen.setName("#{zn_name_clean}Temp")
      zn_temp_sen.setKeyName(zone_air_node.handle.to_s)

      htg_rtf_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'Heating Coil Runtime Fraction')
      htg_rtf_sen.setName("#{snc}HeatingRTF")
      htg_rtf_sen.setKeyName(htg_coil.handle.to_s)

      clg_rtf_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'Cooling Coil Runtime Fraction')
      clg_rtf_sen.setName("#{snc}RTF")
      clg_rtf_sen.setKeyName(dx_coil.handle.to_s)

      spd_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(air_loop_hvac.model, 'Coil System Compressor Speed Ratio')
      spd_sen.setName("#{snc}SpeedRatio")
      spd_sen.setKeyName("#{dx_coil.handle} CoilSystem")

      # Internal Variables
      fan_pres_var = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(air_loop_hvac.model, 'Fan Nominal Pressure Rise')
      fan_pres_var.setName("#{snc}FanDesignPressure")
      fan_pres_var.setInternalDataIndexKeyName(fan.handle.to_s)

      dsn_flow_var = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(air_loop_hvac.model, 'Outdoor Air Controller Maximum Mass Flow Rate')
      dsn_flow_var.setName("#{snc}DesignFlowMass")
      dsn_flow_var.setInternalDataIndexKeyName(oa_control.handle.to_s)

      # Actuators
      fan_pres_act = OpenStudio::Model::EnergyManagementSystemActuator.new(fan, 'Fan', 'Fan Pressure Rise')
      fan_pres_act.setName("#{snc}FanPressure")

      # Global Variables
      gvar = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(air_loop_hvac.model, "#{snc}FanPwrExp")
      gvar = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(air_loop_hvac.model, "#{snc}Stg1Spd")
      gvar = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(air_loop_hvac.model, "#{snc}Stg2Spd")
      gvar = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(air_loop_hvac.model, "#{snc}HeatSpeed")
      gvar = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(air_loop_hvac.model, "#{snc}VenSpeed")

      # Programs
      fan_par_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(air_loop_hvac.model)
      fan_par_prg.setName("#{snc}SetFanPar")
      fan_par_prg_body = <<-EMS
        IF #{snc}NumberofStages == 1
          Return
        ENDIF
        SET #{snc}FanPwrExp = 2.2
        SET OAFrac = #{oa_flow_sen.handle}/#{dsn_flow_var.handle}
        IF  OAFrac < 0.66
          SET #{snc}VenSpeed = 0.66
          SET #{snc}Stg1Spd = 0.66
        ELSE
          SET #{snc}VenSpeed = OAFrac
          SET #{snc}Stg1Spd = OAFrac
        ENDIF
        SET #{snc}Stg2Spd = 1.0
        SET #{snc}HeatSpeed = 1.0
      EMS
      fan_par_prg.setBody(fan_par_prg_body)

      fan_ctrl_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(air_loop_hvac.model)
      fan_ctrl_prg.setName("#{snc}FanControl")
      fan_ctrl_prg_body = <<-EMS
        IF #{snc}NumberofStages == 1
          Return
        ENDIF
        IF #{htg_rtf_sen.handle} > 0
          SET Heating = #{htg_rtf_sen.handle}
          SET Ven = 1-#{htg_rtf_sen.handle}
          SET Eco = 0
          SET Stage1 = 0
          SET Stage2 = 0
        ELSE
          SET Heating = 0
          SET EcoSpeed = #{snc}VenSpeed
          IF #{spd_sen.handle} == 0
            IF #{clg_rtf_sen.handle} > 0
              SET Stage1 = #{clg_rtf_sen.handle}
              SET Stage2 = 0
              SET Ven = 1-#{clg_rtf_sen.handle}
              SET Eco = 0
              IF #{oa_flow_sen.handle} > (#{oa_flow_var.handle}*#{oa_sch_sen.handle})
                SET #{snc}Stg1Spd = 1.0
              ENDIF
            ELSE
              SET Stage1 = 0
              SET Stage2 = 0
              IF #{oa_flow_sen.handle} > (#{oa_flow_var.handle}*#{oa_sch_sen.handle})
                SET Eco = 1.0
                SET Ven = 0
                !Calculate the expected discharge air temperature if the system runs at its low speed
                SET ExpDAT = #{dat_sen.handle}-(1-#{snc}VenSpeed)*#{zn_temp_sen.handle}
                SET ExpDAT = ExpDAT/#{snc}VenSpeed
                IF #{oat_db_c_sen.handle} > ExpDAT
                  SET EcoSpeed = #{snc}Stg2Spd
                ENDIF
              ELSE
                SET Eco = 0
                SET Ven = 1.0
              ENDIF
            ENDIF
          ELSE
            SET Stage1 = 1-#{spd_sen.handle}
            SET Stage2 = #{spd_sen.handle}
            SET Ven = 0
            SET Eco = 0
            IF #{oa_flow_sen.handle} > (#{oa_flow_var.handle}*#{oa_sch_sen.handle})
              SET #{snc}Stg1Spd = 1.0
            ENDIF
          ENDIF
        ENDIF
        ! For each mode (percent time in mode)*(fanSpeer^PwrExp) is the contribution to weighted fan power over time step
        SET FPR = Ven*(#{snc}VenSpeed ^ #{snc}FanPwrExp)
        SET FPR = FPR+Eco*(EcoSpeed^#{snc}FanPwrExp)
        SET FPR1 = Stage1*(#{snc}Stg1Spd^#{snc}FanPwrExp)
        SET FPR = FPR+FPR1
        SET FPR2 = Stage2*(#{snc}Stg2Spd^#{snc}FanPwrExp)
        SET FPR = FPR+FPR2
        SET FPR3 = Heating*(#{snc}HeatSpeed^#{snc}FanPwrExp)
        SET FanPwrRatio = FPR+ FPR3
        ! system fan power is directly proportional to static pressure so this change linearly adjusts fan energy for speed control
        SET #{fan_pres_act.handle} = #{fan_pres_var.handle}*FanPwrRatio
      EMS
      fan_ctrl_prg.setBody(fan_ctrl_prg_body)

      # Program Calling Managers
      # Note that num_stg_prg must be listed before fan_par_prg
      # because it initializes a variable used by fan_par_prg.
      setup_mgr.addProgram(fan_par_prg)

      fan_ctrl_mgr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(air_loop_hvac.model)
      fan_ctrl_mgr.setName("#{snc}FanMainManager")
      fan_ctrl_mgr.setCallingPoint('BeginTimestepBeforePredictor')
      fan_ctrl_mgr.addProgram(fan_ctrl_prg)

    end

    return true
  end

  # Determine the number of stages that should be used as controls
  # for single zone DX systems.  Defaults to zero, which means
  # that no special single zone control is required.
  #
  # @return [Integer] the number of stages: 0, 1, 2
  def air_loop_hvac_single_zone_controls_num_stages(air_loop_hvac, climate_zone)
    num_stages = 0
    return num_stages
  end

  # Determine if static pressure reset is required for this
  # system.  For 90.1, this determination needs information
  # about whether or not the system has DDC control over the
  # VAV terminals. Defaults to 90.1-2007 logic.
  #
  # @todo Instead of requiring the input of whether a system
  #   has DDC control of VAV terminals or not, determine this
  #   from the system itself.  This may require additional information
  #   be added to the OpenStudio data model.
  # @param has_ddc [Bool] whether or not the system has DDC control
  # over VAV terminals.
  # return [Bool] returns true if static pressure reset is required, false if not
  def air_loop_hvac_static_pressure_reset_required?(air_loop_hvac, has_ddc)
    sp_reset_required = false

    if has_ddc
      sp_reset_required = true
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Static pressure reset is required because the system has DDC control of VAV terminals.")
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Static pressure reset not required because the system does not have DDC control of VAV terminals.")
    end

    return sp_reset_required
  end

  # Determine if a system's fans must shut off when not required.
  # Per ASHRAE 90.1 section 6.4.3.3, HVAC systems are required to have off-hour controls
  # @return [Bool] true if required, false if not
  def air_loop_hvac_unoccupied_fan_shutoff_required?(air_loop_hvac)
    shutoff_required = true

    # Determine if the airloop serves any computer rooms or data centers, which default to always on.
    if air_loop_hvac_data_center_area_served(air_loop_hvac) > 0
      shutoff_required = false
    end

    return shutoff_required
  end

  # Default occupancy fraction threshold for determining if the spaces on the air loop are occupied
  def air_loop_hvac_unoccupied_threshold
    return 0.15
  end

  # Shut off the system during unoccupied periods.
  # During these times, systems will cycle on briefly
  # if temperature drifts below setpoint.  For systems
  # with fan-powered terminals, the whole system
  # (not just the terminal fans) will cycle on.
  # Terminal-only night cycling is not used because the terminals cannot
  # provide cooling, so terminal-only night cycling leads to excessive
  # unmet cooling hours during unoccupied periods.
  # If the system already has a schedule other than
  # Always-On, no change will be made.  If the system has
  # an Always-On schedule assigned, a new schedule will be created.
  # In this case, occupied is defined as the total percent
  # occupancy for the loop for all zones served.
  #
  # @param min_occ_pct [Double] the fractional value below which
  # the system will be considered unoccupied.
  # @return [Bool] true if successful, false if not
  def air_loop_hvac_enable_unoccupied_fan_shutoff(air_loop_hvac, min_occ_pct = 0.05)
    # Set the system to night cycle
    air_loop_hvac.setNightCycleControlType('CycleOnAny')

    # Check if already using a schedule other than always on
    avail_sch = air_loop_hvac.availabilitySchedule
    unless avail_sch == air_loop_hvac.model.alwaysOnDiscreteSchedule
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Availability schedule is already set to #{avail_sch.name}.  Will assume this includes unoccupied shut down; no changes will be made.")
      return true
    end

    # Get the airloop occupancy schedule
    loop_occ_sch = air_loop_hvac_get_occupancy_schedule(air_loop_hvac, occupied_percentage_threshold: min_occ_pct)
    flh = schedule_ruleset_annual_equivalent_full_load_hrs(loop_occ_sch)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Annual occupied hours = #{flh.round} hr/yr, assuming a #{min_occ_pct} occupancy threshold.  This schedule will be used as the HVAC operation schedule.")

    # Set HVAC availability schedule to follow occupancy
    air_loop_hvac.setAvailabilitySchedule(loop_occ_sch)

    return true
  end

  # Calculate the total floor area of all zones attached
  # to the air loop, in m^2.
  #
  # return [Double] the total floor area of all zones attached
  # to the air loop, in m^2.
  def air_loop_hvac_floor_area_served(air_loop_hvac)
    total_area = 0.0

    air_loop_hvac.thermalZones.each do |zone|
      total_area += zone.floorArea
    end

    return total_area
  end

  # Calculate the total floor area of all zones attached
  # to the air loop that have no exterior surfaces, in m^2.
  #
  # return [Double] the total floor area of all zones attached
  # to the air loop, in m^2.
  def air_loop_hvac_floor_area_served_interior_zones(air_loop_hvac)
    total_area = 0.0

    air_loop_hvac.thermalZones.each do |zone|
      # Skip zones that have exterior surface area
      next if zone.exteriorSurfaceArea > 0
      total_area += zone.floorArea
    end

    return total_area
  end

  # Calculate the total floor area of all zones attached
  # to the air loop that have at least one exterior surface, in m^2.
  #
  # return [Double] the total floor area of all zones attached
  # to the air loop, in m^2.
  def air_loop_hvac_floor_area_served_exterior_zones(air_loop_hvac)
    total_area = 0.0

    air_loop_hvac.thermalZones.each do |zone|
      # Skip zones that have no exterior surface area
      next if zone.exteriorSurfaceArea.zero?
      total_area += zone.floorArea
    end

    return total_area
  end

  # find design_supply_air_flow_rate
  #
  # @return [Double]  design_supply_air_flow_rate m^3/s
  def air_loop_hvac_find_design_supply_air_flow_rate(air_loop_hvac)
    # Get the design_supply_air_flow_rate
    design_supply_air_flow_rate = nil
    if air_loop_hvac.designSupplyAirFlowRate.is_initialized
      design_supply_air_flow_rate = air_loop_hvac.designSupplyAirFlowRate.get
    elsif air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
      design_supply_air_flow_rate = air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} design sypply air flow rate is not available.")
    end

    return design_supply_air_flow_rate
  end

  # Determine how much data center
  # area the airloop serves.
  #
  # @return [Double] the area of data center is served,
  # in m^2.
  # @todo Add an is_data_center field to the
  # standards space type spreadsheet instead
  # of relying on the standards space type name to
  # identify a data center.
  def air_loop_hvac_data_center_area_served(air_loop_hvac)
    dc_area_m2 = 0.0

    air_loop_hvac.thermalZones.each do |zone|
      zone.spaces.each do |space|
        # Skip spaces with no space type
        next if space.spaceType.empty?
        space_type = space.spaceType.get
        next if space_type.standardsSpaceType.empty?
        standards_space_type = space_type.standardsSpaceType.get
        # Counts as a data center if the name includes 'data'
        if standards_space_type.downcase.include?('data center') || standards_space_type.downcase.include?('datacenter')
          dc_area_m2 += space.floorArea
        end
        std_bldg_type = space.spaceType.get.standardsBuildingType.get
        if std_bldg_type.downcase.include?('datacenter') && standards_space_type.downcase.include?('computerroom')
          dc_area_m2 += space.floorArea
        end
      end
    end

    return dc_area_m2
  end

  # Sets the maximum reheat temperature to the specified
  # value for all reheat terminals (of any type) on the loop.
  #
  # @param max_reheat_c [Double] the maximum reheat temperature, in C
  # @return [Bool] returns true if successful, false if not.
  def air_loop_hvac_apply_maximum_reheat_temperature(air_loop_hvac, max_reheat_c)
    air_loop_hvac.demandComponents.each do |sc|
      if sc.to_AirTerminalSingleDuctConstantVolumeReheat.is_initialized
        term = sc.to_AirTerminalSingleDuctConstantVolumeReheat.get
        term.setMaximumReheatAirTemperature(max_reheat_c)
      elsif sc.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized
        # No control option available
      elsif sc.to_AirTerminalSingleDuctSeriesPIUReheat.is_initialized
        # No control option available
      elsif sc.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.is_initialized
        term = sc.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.get
        term.setMaximumReheatAirTemperature(max_reheat_c)
      elsif sc.to_AirTerminalSingleDuctVAVReheat.is_initialized
        term = sc.to_AirTerminalSingleDuctVAVReheat.get
        term.setMaximumReheatAirTemperature(max_reheat_c)
      end
    end

    max_reheat_f = OpenStudio.convert(max_reheat_c, 'C', 'F').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: reheat terminal maximum set to #{max_reheat_f.round} F.")

    return true
  end

  # Set the system sizing properties based on the zone sizing information
  #
  # @return [Bool] true if successful, false if not.
  def air_loop_hvac_apply_prm_sizing_temperatures(air_loop_hvac)
    # Get the design heating and cooling SAT information
    # for all zones served by the system.
    htg_setpts_c = []
    clg_setpts_c = []
    air_loop_hvac.thermalZones.each do |zone|
      sizing_zone = zone.sizingZone
      htg_setpts_c << sizing_zone.zoneHeatingDesignSupplyAirTemperature
      clg_setpts_c << sizing_zone.zoneCoolingDesignSupplyAirTemperature
    end

    # Cooling SAT set to minimum zone cooling design SAT
    clg_sat_c = clg_setpts_c.min

    # If the system has terminal reheat,
    # heating SAT is set to the same value as cooling SAT
    # and the terminals are expected to do the heating.
    # If not, heating SAT set to maximum zone heating design SAT.
    has_term_rht = air_loop_hvac_terminal_reheat?(air_loop_hvac)
    htg_sat_c = if has_term_rht
                  clg_sat_c
                else
                  htg_setpts_c.max
                end

    # Set the central SAT values
    sizing_system = air_loop_hvac.sizingSystem
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_sat_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_sat_c)

    clg_sat_f = OpenStudio.convert(clg_sat_c, 'C', 'F').get
    htg_sat_f = OpenStudio.convert(htg_sat_c, 'C', 'F').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: central heating SAT set to #{htg_sat_f.round} F, cooling SAT set to #{clg_sat_f.round} F.")

    # If it's a terminal reheat system, set the reheat terminal setpoints too
    if has_term_rht
      rht_c = htg_setpts_c.max
      air_loop_hvac_apply_maximum_reheat_temperature(air_loop_hvac, rht_c)
    end

    return true
  end

  # Determine if every zone on the system has an identical
  # multiplier.  If so, return this number.  If not, return 1.
  # @return [Integer] an integer representing the system multiplier.
  def air_loop_hvac_system_multiplier(air_loop_hvac)
    mult = 1

    # Get all the zone multipliers
    zn_mults = []
    air_loop_hvac.thermalZones.each do |zone|
      zn_mults << zone.multiplier
    end

    # Warn if there are different multipliers
    uniq_mults = zn_mults.uniq
    if uniq_mults.size > 1
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: not all zones on the system have an identical zone multiplier.  Multipliers are: #{uniq_mults.join(', ')}.")
    else
      mult = uniq_mults[0]
    end

    return mult
  end

  # Determine if this Air Loop uses DX cooling.
  #
  # @return [Bool] true if uses DX cooling, false if not.
  def air_loop_hvac_dx_cooling?(air_loop_hvac)
    dx_clg = false

    # Check for all DX coil types
    dx_types = [
      'OS_Coil_Cooling_DX_MultiSpeed',
      'OS_Coil_Cooling_DX_SingleSpeed',
      'OS_Coil_Cooling_DX_TwoSpeed',
      'OS_Coil_Cooling_DX_TwoStageWithHumidityControlMode',
      'OS_Coil_Cooling_DX_VariableRefrigerantFlow',
      'OS_Coil_Cooling_DX_VariableSpeed',
      'OS_CoilSystem_Cooling_DX_HeatExchangerAssisted'
    ]

    air_loop_hvac.supplyComponents.each do |component|
      # Get the object type, getting the internal coil
      # type if inside a unitary system.
      obj_type = component.iddObjectType.valueName.to_s
      case obj_type
      when 'OS_AirLoopHVAC_UnitaryHeatCool_VAVChangeoverBypass'
        component = component.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get
        obj_type = component.coolingCoil.iddObjectType.valueName.to_s
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        obj_type = component.coolingCoil.iddObjectType.valueName.to_s
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir_MultiSpeed'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get
        obj_type = component.coolingCoil.iddObjectType.valueName.to_s
      when 'OS_AirLoopHVAC_UnitarySystem'
        component = component.to_AirLoopHVACUnitarySystem.get
        if component.coolingCoil.is_initialized
          obj_type = component.coolingCoil.get.iddObjectType.valueName.to_s
        end
      end
      # See if the object type is a DX coil
      if dx_types.include?(obj_type)
        dx_clg = true
        break # Stop if find a DX coil
      end
    end

    return dx_clg
  end

  # Determine if this Air Loop uses multi-stage DX cooling.
  #
  # @return [Bool] true if uses multi-stage DX cooling, false if not.
  def air_loop_hvac_multi_stage_dx_cooling?(air_loop_hvac)
    dx_clg = false

    # Check for all DX coil types
    dx_types = [
      'OS_Coil_Cooling_DX_MultiSpeed',
      'OS_Coil_Cooling_DX_TwoSpeed',
      'OS_Coil_Cooling_DX_TwoStageWithHumidityControlMode'
    ]

    air_loop_hvac.supplyComponents.each do |component|
      # Get the object type, getting the internal coil
      # type if inside a unitary system.
      obj_type = component.iddObjectType.valueName.to_s
      case obj_type
      when 'OS_AirLoopHVAC_UnitaryHeatCool_VAVChangeoverBypass'
        component = component.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get
        obj_type = component.coolingCoil.iddObjectType.valueName.to_s
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        obj_type = component.coolingCoil.iddObjectType.valueName.to_s
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir_MultiSpeed'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get
        obj_type = component.coolingCoil.iddObjectType.valueName.to_s
      when 'OS_AirLoopHVAC_UnitarySystem'
        component = component.to_AirLoopHVACUnitarySystem.get
        if component.coolingCoil.is_initialized
          obj_type = component.coolingCoil.get.iddObjectType.valueName.to_s
        end
      end
      # See if the object type is a DX coil
      if dx_types.include?(obj_type)
        dx_clg = true
        break # Stop if find a DX coil
      end
    end

    return dx_clg
  end
end

class Standard
  # These EnergyPlus objects implement a proportional control for a single thermal zone with a radiant system.
  # @ref [References::CBERadiantSystems]
  # @param zone [OpenStudio::Model::ThermalZone>] zone to add radiant controls
  # @param radiant_loop [OpenStudio::Model::ZoneHVACLowTempRadiantVarFlow>] radiant loop in thermal zone
  # @param radiant_type [String] determines the surface of the radiant system for surface temperature output reporting
  #   options are 'floor' and 'ceiling'
  # @param model_occ_hr_start [Double] Starting hour of building occupancy
  # @param model_occ_hr_end [Double] Ending hour of building occupancy
  # @TODO model_occ_hr_start and model_occ_hr_end from zone occupancy schedules
  # @param proportional_gain [Double] Proportional gain constant (recommended 0.3 or less).
  # @param minimum_operation [Double] Minimum number of hours of operation for radiant system before it shuts off.
  # @param weekend_temperature_reset [Double] Weekend temperature reset for slab temperature setpoint in degree Celsius.
  # @param early_reset_out_arg [Double] Time at which the weekend temperature reset is removed.
  # @param switch_over_time [Double] Time limitation for when the system can switch between heating and cooling
  def model_add_radiant_proportional_controls(model, zone, radiant_loop,
                                              radiant_type: 'floor',
                                              model_occ_hr_start: 6.0,
                                              model_occ_hr_end: 18.0,
                                              proportional_gain: 0.3,
                                              minimum_operation: 1,
                                              weekend_temperature_reset: 2,
                                              early_reset_out_arg: 20,
                                              switch_over_time: 24.0)

    zone_name = zone.name.to_s.gsub(/[ +-.]/, '_')
    zone_timestep = model.getTimestep.numberOfTimestepsPerHour

    if model.version < OpenStudio::VersionString.new('3.1.1')
      coil_cooling_radiant = radiant_loop.coolingCoil.to_CoilCoolingLowTempRadiantVarFlow.get
      coil_heating_radiant = radiant_loop.heatingCoil.to_CoilHeatingLowTempRadiantVarFlow.get
    else
      coil_cooling_radiant = radiant_loop.coolingCoil.get.to_CoilCoolingLowTempRadiantVarFlow.get
      coil_heating_radiant = radiant_loop.heatingCoil.get.to_CoilHeatingLowTempRadiantVarFlow.get
    end

    #####
    # List of schedule objects used to hold calculation results
    ####

    # cold water control actuator
    # Command to turn ON/OFF the cold water through the radiant system. 0=ON and 100=OFF
    # Large temperatures are used to ensure that the radiant system valve will fully open and close
    sch_radiant_clgsetp = model_add_constant_schedule_ruleset(model,
                                                              0.0,
                                                              name = "#{zone_name}_Sch_Radiant_ClgSetP")
    coil_cooling_radiant.setCoolingControlTemperatureSchedule(sch_radiant_clgsetp)
    cmd_cold_water_ctrl = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_radiant_clgsetp,
                                                                                'Schedule:Year',
                                                                                'Schedule Value')
    cmd_cold_water_ctrl.setName("#{zone_name}_CMD_COLD_WATER_CTRL")

    # hot water control actuator
    # Command to turn ON/OFF the hot water through the radiant system. 60=ON and -60=OFF.
    # Large temperatures are used to to ensure that the radiant system valve will fully open and close
    sch_radiant_htgsetp = model_add_constant_schedule_ruleset(model,
                                                              -60.0,
                                                              name = "#{zone_name}_Sch_Radiant_HtgSetP")
    coil_heating_radiant.setHeatingControlTemperatureSchedule(sch_radiant_htgsetp)
    cmd_hot_water_ctrl = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_radiant_htgsetp,
                                                                               'Schedule:Year',
                                                                               'Schedule Value')
    cmd_hot_water_ctrl.setName("#{zone_name}_CMD_HOT_WATER_CTRL")

    # set schedule type limits for hot water control
    hot_water_schedule_type_limits = model.getScheduleTypeLimitsByName('Radiant_Hot_water_Ctrl_Temperature_Limits')
    if hot_water_schedule_type_limits.is_initialized
      hot_water_schedule_type_limits = hot_water_schedule_type_limits.get
    else
      hot_water_schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
      hot_water_schedule_type_limits.setName('Radiant_Hot_water_Ctrl_Temperature_Limits')
      hot_water_schedule_type_limits.setLowerLimitValue(-60.0)
      hot_water_schedule_type_limits.setUpperLimitValue(100.0)
      hot_water_schedule_type_limits.setNumericType('Continuous')
      hot_water_schedule_type_limits.setUnitType('Temperature')
    end
    sch_radiant_htgsetp.setScheduleTypeLimits(hot_water_schedule_type_limits)

    # Calculated active slab heating and cooling temperature setpoint. Default temperature is taken at the slab surface.
    sch_slab_sp = model_add_constant_schedule_ruleset(model,
                                                      21.0,
                                                      name = "#{zone_name}_Sch_Slab_SP")
    cmd_slab_sp = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_slab_sp,
                                                                        'Schedule:Year',
                                                                        'Schedule Value')
    cmd_slab_sp.setName("#{zone_name}_CMD_SLAB_SP")

    # add output variable for slab setpoint temperature
    var = OpenStudio::Model::OutputVariable.new('Schedule Value', model)
    var.setKeyValue("#{zone_name}_Sch_Slab_SP")
    var.setReportingFrequency('Timestep')

    # Calculated cooling setpoint error. Calculated from upper comfort limit minus setpoint offset and 'measured' controlled zone temperature.
    sch_csp_error = model_add_constant_schedule_ruleset(model,
                                                        0.0,
                                                        name = "#{zone_name}_Sch_CSP_Error")
    cmd_csp_error = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_csp_error,
                                                                          'Schedule:Year',
                                                                          'Schedule Value')
    cmd_csp_error.setName("#{zone_name}_CMD_CSP_ERROR")

    # Calculated heating setpoint error. Calculated from lower comfort limit plus setpoint offset and 'measured' controlled zone temperature.
    sch_hsp_error = model_add_constant_schedule_ruleset(model,
                                                        0.0,
                                                        name = "#{zone_name}_Sch_HSP_Error")
    cmd_hsp_error = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_hsp_error,
                                                                          'Schedule:Year',
                                                                          'Schedule Value')
    cmd_hsp_error.setName("#{zone_name}_CMD_HSP_ERROR")

    # Averaged radiant slab controlled temperature. Averaged over the last 24 hours.
    sch_avg_ctrl_temp = model_add_constant_schedule_ruleset(model,
                                                            20.0,
                                                            name = "#{zone_name}_Sch_Avg_Ctrl_Temp")
    cmd_ctrl_temp_running_mean = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_avg_ctrl_temp,
                                                                                       'Schedule:Year',
                                                                                       'Schedule Value')
    cmd_ctrl_temp_running_mean.setName("#{zone_name}_CMD_CTRL_TEMP_RUNNING_MEAN")

    # Averaged outdoor air temperature. Averaged over the last 24 hours.
    sch_oat_running_mean = model.getScheduleConstantByName('SCH_OAT_RUNNING_MEAN')
    if sch_oat_running_mean.is_initialized
      sch_oat_running_mean = sch_oat_running_mean.get
    else
      sch_oat_running_mean = model_add_constant_schedule_ruleset(model,
                                                                 20.0,
                                                                 name = 'SCH_OAT_RUNNING_MEAN')
    end

    cmd_oat_running_mean = model.getEnergyManagementSystemActuatorByName('CMD_OAT_RUNNING_MEAN')
    if cmd_oat_running_mean.is_initialized
      cmd_oat_running_mean = cmd_oat_running_mean.get
    else
      cmd_oat_running_mean = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_oat_running_mean,
                                                                                   'Schedule:Year',
                                                                                   'Schedule Value')
      cmd_oat_running_mean.setName('CMD_OAT_RUNNING_MEAN')
    end

    #####
    # List of global variables used in EMS scripts
    ####

    # Start of occupied time of zone. Valid from 1-24.
    occ_hr_start = model.getEnergyManagementSystemGlobalVariableByName('occ_hr_start')
    if occ_hr_start.is_initialized
      occ_hr_start = occ_hr_start.get
    else
      occ_hr_start = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'occ_hr_start')
    end

    # End of occupied time of zone. Valid from 1-24.
    occ_hr_end = model.getEnergyManagementSystemGlobalVariableByName('occ_hr_end')
    if occ_hr_end.is_initialized
      occ_hr_end = occ_hr_end.get
    else
      occ_hr_end = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'occ_hr_end')
    end

    # Proportional  gain constant (recommended 0.3 or less).
    prp_k = model.getEnergyManagementSystemGlobalVariableByName('prp_k')
    if prp_k.is_initialized
      prp_k = prp_k.get
    else
      prp_k = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'prp_k')
    end

    # mean outdoor dry-bulb air temperature
    mean_oat = model.getEnergyManagementSystemGlobalVariableByName('mean_oat')
    if mean_oat.is_initialized
      mean_oat = mean_oat.get
    else
      mean_oat = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'mean_oat')
    end

    # Is the day a weekend? 1=Weekend and 0=Not Weekend.
    weekend = model.getEnergyManagementSystemGlobalVariableByName('weekend')
    if weekend.is_initialized
      weekend = weekend.get
    else
      weekend = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'weekend')
    end

    # Is the building in unoccupied model? 1=Unoccupied and 0=Not Unoccupied.
    unoccupied = model.getEnergyManagementSystemGlobalVariableByName('unoccupied')
    if unoccupied.is_initialized
      unoccupied = unoccupied.get
    else
      unoccupied = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'unoccupied')
    end

    # Minimum number of hours of operation for radiant system before it shuts off.
    min_oper = model.getEnergyManagementSystemGlobalVariableByName('min_oper')
    if min_oper.is_initialized
      min_oper = min_oper.get
    else
      min_oper = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'min_oper')
    end

    # Weekend temperature reset for slab temperature setpoint in degree Celsius.
    wkend_temp_reset = model.getEnergyManagementSystemGlobalVariableByName('wkend_temp_reset')
    if wkend_temp_reset.is_initialized
      wkend_temp_reset = wkend_temp_reset.get
    else
      wkend_temp_reset = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'wkend_temp_reset')
    end

    # Time at which the weekend temperature reset is removed.
    early_reset_out = model.getEnergyManagementSystemGlobalVariableByName('early_reset_out')
    if early_reset_out.is_initialized
      early_reset_out = early_reset_out.get
    else
      early_reset_out = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'early_reset_out')
    end

    # Upper slab temperature setpoint limit
    upper_slab_sp_lim = model.getEnergyManagementSystemGlobalVariableByName('upper_slab_sp_lim')
    if upper_slab_sp_lim.is_initialized
      upper_slab_sp_lim = upper_slab_sp_lim.get
    else
      upper_slab_sp_lim = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'upper_slab_sp_lim')
    end

    # Lower slab temperature setpoint limit
    lower_slab_sp_lim = model.getEnergyManagementSystemGlobalVariableByName('lower_slab_sp_lim')
    if lower_slab_sp_lim.is_initialized
      lower_slab_sp_lim = lower_slab_sp_lim.get
    else
      lower_slab_sp_lim = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'lower_slab_sp_lim')
    end

    # Temperature offset used to modify.
    ctrl_temp_offset = model.getEnergyManagementSystemGlobalVariableByName('ctrl_temp_offset')
    if ctrl_temp_offset.is_initialized
      ctrl_temp_offset = ctrl_temp_offset.get
    else
      ctrl_temp_offset = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'ctrl_temp_offset')
    end

    # zone specific variables

    # Maximum 'measured' temperature in zone during occupied times. Default setup uses mean air temperature.
    # Other possible choices are operative and mean radiant temperature.
    zone_max_ctrl_temp = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_max_ctrl_temp")

    # Minimum 'measured' temperature in zone during occupied times. Default setup uses mean air temperature.
    # Other possible choices are operative and mean radiant temperature.
    zone_min_ctrl_temp = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_min_ctrl_temp")

    # mean temperature of control surface
    zone_mean_ctrl = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_mean_ctrl")

    # Continuous operation where there is no active hydronic heating or cooling in thermal zone in hours.
    zone_cont_neutral_oper = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_cont_neutral_oper")

    # Zone mode of thermal zone. -1=Heating, 1=Cooling, and 0=Neutral.
    zone_zone_mode = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_zone_mode")

    # Amount of hours that building needs to be in neutral mode in order to switch over from heating to cooling or from cooling to heating.
    zone_switch_over_time = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_switch_over_time")

    # Continuous operation when radiant system is active in hours.
    zone_cont_rad_oper = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_cont_rad_oper")

    # Total time the radiant system was in cooling mode in the last 24 hours.
    # Calculated at one timestep before the end of occupied time.
    zone_daily_cool_sum = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_daily_cool_sum")

    # Total time the radiant system was in heating mode in the last 24 hours.
    # Calculated at one timestep before the end of occupied time.
    zone_daily_heat_sum = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_daily_heat_sum")

    # Total time the radiant system was in cooling mode for the previous day.
    zone_daily_cool_sum_one = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_daily_cool_sum_one")

    # Total time the radiant system was in heating mode for the previous day.
    zone_daily_heat_sum_one = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_daily_heat_sum_one")

    #####
    # List of 'sensors' used in the EMS programs
    ####

    # Outdoor air temperature.
    oat = model.getEnergyManagementSystemSensorByName('OAT')
    if oat.is_initialized
      oat = oat.get
    else
      oat = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')
      oat.setName('OAT')
      oat.setKeyName('Environment')
    end

    # Number of timesteps to average control temperature. (Currently unused)
    # avg_window_n = model.getEnergyManagementSystemSensorByName('avg_window_n')
    # if avg_window_n.is_initialized
    #   avg_window_n = avg_window_n.get
    # else
    #   avg_window_n = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    #   avg_window_n.setName('avg_window_n')
    #   avg_window_n.setKeyName('Sch_Slab_Ctrl_Avg_Window_N')
    # end

    # Controlled zone temperature for the zone.
    zone_ctrl_temperature = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Air Temperature')
    zone_ctrl_temperature.setName("#{zone_name}_Ctrl_Temperature")
    zone_ctrl_temperature.setKeyName(zone.name.get)

    # Active surface slab temperature. # Use largest surface in zone.
    surface_type = radiant_type == 'floor' ? 'Floor' : 'RoofCeiling'
    surfaces = []
    zone.spaces.each do |space|
      space.surfaces.each do |surface|
        surfaces << surface if surface.surfaceType == surface_type
      end
    end
    if surfaces.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Zone #{zone.name} does not have floor surfaces; cannot add radiant system.")
      return false
    end
    zone_floor = surfaces.max_by(&:grossArea)
    zone_srf_temp = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Surface Inside Face Temperature')
    zone_srf_temp.setName("#{zone_name}_Srf_Temp")
    zone_srf_temp.setKeyName(zone_floor.name.get)

    # check for zone thermostats
    zone_thermostat = zone.thermostatSetpointDualSetpoint
    unless zone_thermostat.is_initialized
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Zone #{zone.name} does not have thermostats.")
      return false
    end
    zone_thermostat = zone.thermostatSetpointDualSetpoint.get
    zone_clg_thermostat = zone_thermostat.coolingSetpointTemperatureSchedule.get
    zone_htg_thermostat = zone_thermostat.heatingSetpointTemperatureSchedule.get

    # Upper comfort limit for the zone. Taken from existing thermostat schedules in the zone.
    zone_upper_comfort_limit = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    zone_upper_comfort_limit.setName("#{zone_name}_Upper_Comfort_Limit")
    zone_upper_comfort_limit.setKeyName(zone_clg_thermostat.name.get)

    # Lower comfort limit for the zone. Taken from existing thermostat schedules in the zone.
    zone_lower_comfort_limit = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    zone_lower_comfort_limit.setName("#{zone_name}_Lower_Comfort_Limit")
    zone_lower_comfort_limit.setKeyName(zone_htg_thermostat.name.get)

    # Radiant system water flow rate used to determine if there is active hydronic cooling in the radiant system.
    zone_rad_cool_operation = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'System Node Mass Flow Rate')
    zone_rad_cool_operation.setName("#{zone_name}_Rad_Cool_Operation")
    zone_rad_cool_operation.setKeyName(coil_cooling_radiant.to_StraightComponent.get.inletModelObject.get.name.get)

    # Radiant system water flow rate used to determine if there is active hydronic heating in the radiant system.
    zone_rad_heat_operation = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'System Node Mass Flow Rate')
    zone_rad_heat_operation.setName("#{zone_name}_Rad_Heat_Operation")
    zone_rad_heat_operation.setKeyName(coil_heating_radiant.to_StraightComponent.get.inletModelObject.get.name.get)

    # Last 24 hours trend for the outdoor air temperature.
    oat_trend = model.getEnergyManagementSystemTrendVariableByName('OAT_Trend')
    if oat_trend.is_initialized
      oat_trend = oat_trend.get
    else
      oat_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, oat)
      oat_trend.setName('OAT_Trend')
      oat_trend.setNumberOfTimestepsToBeLogged(zone_timestep * 24)
    end

    # Last 24 hours trend for active slab surface temperature.
    zone_srf_temp_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, zone_srf_temp)
    zone_srf_temp_trend.setName("#{zone_name}_Srf_Temp_Trend")
    zone_srf_temp_trend.setNumberOfTimestepsToBeLogged(zone_timestep * 24)

    # Last 24 hours trend for radiant system in cooling mode.
    zone_rad_cool_operation_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, zone_rad_cool_operation)
    zone_rad_cool_operation_trend.setName("#{zone_name}_Rad_Cool_Operation_Trend")
    zone_rad_cool_operation_trend.setNumberOfTimestepsToBeLogged(zone_timestep * 24)

    # Last 24 hours trend for radiant system in heating mode.
    zone_rad_heat_operation_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, zone_rad_heat_operation)
    zone_rad_heat_operation_trend.setName("#{zone_name}_Rad_Heat_Operation_Trend")
    zone_rad_heat_operation_trend.setNumberOfTimestepsToBeLogged(zone_timestep * 24)

    #####
    # List of EMS programs to implement the proportional control for the radiant system.
    ####

    # Initialize global constant values used in EMS programs.
    set_constant_values_prg = model.getEnergyManagementSystemTrendVariableByName('Set_Constant_Values')
    unless set_constant_values_prg.is_initialized
      set_constant_values_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      set_constant_values_prg.setName('Set_Constant_Values')
      set_constant_values_prg_body = <<-EMS
        SET occ_hr_start       = #{model_occ_hr_start},
        SET occ_hr_end         = #{model_occ_hr_end},
        SET prp_k              = #{proportional_gain},
        SET min_oper           = #{minimum_operation},
        SET ctrl_temp_offset   = 0.5,
        SET wkend_temp_reset   = #{weekend_temperature_reset},
        SET early_reset_out    = #{early_reset_out_arg},
        SET upper_slab_sp_lim  = 29,
        SET lower_slab_sp_lim  = 19
      EMS
      set_constant_values_prg.setBody(set_constant_values_prg_body)
    end

    # Determine if it is a weekend or not a weekend schedule for the building.
    determine_weekend_prg = model.getEnergyManagementSystemTrendVariableByName('Determine_Weekend')
    unless determine_weekend_prg.is_initialized
      determine_weekend_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      determine_weekend_prg.setName('Determine_Weekend')
      determine_weekend_prg_body = <<-EMS
        IF (DayOfWeek == 1) || (DayOfWeek == 7),
            SET weekend = 1,
        ELSEIF (DayOfWeek == 2) && (CurrentTime < occ_hr_start),
            SET weekend = 1,
        ELSEIF (DayOfWeek == 6) && (CurrentTime > occ_hr_end),
            SET weekend = 1,
        ELSE,
            SET weekend = 0,
        ENDIF
      EMS
      determine_weekend_prg.setBody(determine_weekend_prg_body)
    end

    # Determine if building is in unoccupied mode or not in unoccupied mode.
    determine_unoccupied_prg = model.getEnergyManagementSystemTrendVariableByName('Determine_Unoccupied')
    unless determine_unoccupied_prg.is_initialized
      determine_unoccupied_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      determine_unoccupied_prg.setName('Determine_Unoccupied')
      determine_unoccupied_prg_body = <<-EMS
        IF (DayOfWeek == 1) || (DayOfWeek == 7),
            SET unoccupied = 0,
        ELSEIF (CurrentTime > occ_hr_end) || (CurrentTime < occ_hr_start),
            IF (DayOfWeek == 2) && (CurrentTime < occ_hr_start),
                SET unoccupied = 0,
            ELSEIF (DayOfWeek == 6) && (CurrentTime > occ_hr_end),
                SET unoccupied = 0,
            ELSE,
                SET unoccupied = 1,
            ENDIF,
        ELSE,
            SET unoccupied = 0,
        ENDIF
      EMS
      determine_unoccupied_prg.setBody(determine_unoccupied_prg_body)
    end

    # Initialize zone specific constant values used in EMS programs.
    set_constant_zone_values_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    set_constant_zone_values_prg.setName("#{zone_name}_Set_Constant_Values")
    set_constant_zone_values_prg_body = <<-EMS
      SET #{zone_name}_max_ctrl_temp      = #{zone_name}_Lower_Comfort_Limit,
      SET #{zone_name}_min_ctrl_temp      = #{zone_name}_Upper_Comfort_Limit,
      SET #{zone_name}_cont_neutral_oper  = 0,
      SET #{zone_name}_zone_mode          = 0,
      SET #{zone_name}_switch_over_time   = #{switch_over_time},
      SET #{zone_name}_CMD_CSP_ERROR      = 0,
      SET #{zone_name}_CMD_HSP_ERROR      = 0,
      SET #{zone_name}_CMD_SLAB_SP        = #{zone_name}_Lower_Comfort_Limit,
      SET #{zone_name}_cont_rad_oper      = 0,
      SET #{zone_name}_daily_cool_sum     = 0,
      SET #{zone_name}_daily_heat_sum     = 0,
      SET #{zone_name}_daily_cool_sum_one = 0,
      SET #{zone_name}_daily_heat_sum_one = 0
    EMS
    set_constant_zone_values_prg.setBody(set_constant_zone_values_prg_body)

    # Calculate temperature averages.
    calculate_trends_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_trends_prg.setName("#{zone_name}_Calculate_Trends")
    calculate_trends_prg_body = <<-EMS
      SET mean_oat                                = @TrendAverage OAT_Trend 24/ZoneTimeStep,
      SET #{zone_name}_mean_ctrl                  = @TrendAverage #{zone_name}_Srf_Temp_Trend 24/ZoneTimeStep,
      SET CMD_OAT_RUNNING_MEAN                    = mean_oat + 0,
      SET #{zone_name}_CMD_CTRL_TEMP_RUNNING_MEAN = #{zone_name}_mean_ctrl + 0
    EMS
    calculate_trends_prg.setBody(calculate_trends_prg_body)

    # Calculate maximum and minimum 'measured' controlled temperature in the zone
    calculate_minmax_ctrl_temp_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_minmax_ctrl_temp_prg.setName("#{zone_name}_Calculate_Extremes_In_Zone")
    calculate_minmax_ctrl_temp_prg_body = <<-EMS
      IF ((CurrentTime >= occ_hr_start) && (CurrentTime <= occ_hr_end)),
          IF #{zone_name}_Ctrl_Temperature > #{zone_name}_max_ctrl_temp,
              SET #{zone_name}_max_ctrl_temp = #{zone_name}_Ctrl_Temperature,
          ENDIF,
          IF #{zone_name}_Ctrl_Temperature < #{zone_name}_min_ctrl_temp,
              SET #{zone_name}_min_ctrl_temp = #{zone_name}_Ctrl_Temperature,
          ENDIF,
      ELSE,
        SET #{zone_name}_max_ctrl_temp = #{zone_name}_Lower_Comfort_Limit,
        SET #{zone_name}_min_ctrl_temp = #{zone_name}_Upper_Comfort_Limit,
      ENDIF
    EMS
    calculate_minmax_ctrl_temp_prg.setBody(calculate_minmax_ctrl_temp_prg_body)

    # Calculate errors from comfort zone limits and 'measured' controlled temperature in the zone.
    calculate_errors_from_comfort_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_errors_from_comfort_prg.setName("#{zone_name}_Calculate_Errors_From_Comfort")
    calculate_errors_from_comfort_prg_body = <<-EMS
      IF (CurrentTime >= (occ_hr_end - ZoneTimeStep)) && (CurrentTime <= (occ_hr_end)),
          SET #{zone_name}_CMD_CSP_ERROR = (#{zone_name}_Upper_Comfort_Limit - ctrl_temp_offset) - #{zone_name}_max_ctrl_temp,
          SET #{zone_name}_CMD_HSP_ERROR = (#{zone_name}_Lower_Comfort_Limit + ctrl_temp_offset) - #{zone_name}_min_ctrl_temp,
      ENDIF
    EMS
    calculate_errors_from_comfort_prg.setBody(calculate_errors_from_comfort_prg_body)

    # Calculate time when there is no active hydronic heating or cooling.
    calculate_neutral_time_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_neutral_time_prg.setName("#{zone_name}_Calculate_Neutral_Time")
    calculate_neutral_time_prg_body = <<-EMS
      IF (#{zone_name}_Rad_Cool_Operation > 0) || (#{zone_name}_Rad_Heat_Operation > 0),
          SET #{zone_name}_cont_neutral_oper = 0,
      ELSE,
          SET #{zone_name}_cont_neutral_oper = #{zone_name}_cont_neutral_oper + ZoneTimeStep,
      ENDIF
    EMS
    calculate_neutral_time_prg.setBody(calculate_neutral_time_prg_body)

    # Calculate time when there is active hydronic heating or cooling in thermal zone.
    calculate_continuous_radiant_operation_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_continuous_radiant_operation_prg.setName("#{zone_name}_Calculate_Continuous_Radiant_Operation")
    calculate_continuous_radiant_operation_prg_body = <<-EMS
      IF (#{zone_name}_Rad_Cool_Operation > 0) || (#{zone_name}_Rad_Heat_Operation > 0),
          SET #{zone_name}_cont_rad_oper = #{zone_name}_cont_rad_oper + ZoneTimeStep,
      ELSE,
          SET #{zone_name}_cont_rad_oper = 0,
      ENDIF
    EMS
    calculate_continuous_radiant_operation_prg.setBody(calculate_continuous_radiant_operation_prg_body)

    # Determine if the zone is in cooling, heating, or neutral mode.
    determine_zone_mode_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    determine_zone_mode_prg.setName("#{zone_name}_Determine_Zone_Mode")
    determine_zone_mode_prg_body = <<-EMS
      SET #{zone_name}_cont_cool_oper = @TrendSum #{zone_name}_Rad_Cool_Operation_Trend 24/ZoneTimeStep,
      SET #{zone_name}_cont_heat_oper = @TrendSum #{zone_name}_Rad_Heat_Operation_Trend 24/ZoneTimeStep,
      IF (#{zone_name}_zone_mode <> 0) && (#{zone_name}_cont_neutral_oper > #{zone_name}_switch_over_time),
          SET #{zone_name}_zone_mode = 0,
      ELSEIF (#{zone_name}_cont_cool_oper > 0) && (#{zone_name}_zone_mode == 0),
          SET #{zone_name}_zone_mode = 1,
      ELSEIF (#{zone_name}_cont_heat_oper > 0) && (#{zone_name}_zone_mode == 0),
          SET #{zone_name}_zone_mode = -1,
      ELSE,
          SET #{zone_name}_zone_mode = #{zone_name}_zone_mode,
      ENDIF
    EMS
    determine_zone_mode_prg.setBody(determine_zone_mode_prg_body)

    # Calculate the cumulative time for active hydronic cooling and heating.
    calculate_cumulative_sum_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_cumulative_sum_prg.setName("#{zone_name}_Calculate_Cumulative_Sum")
    calculate_cumulative_sum_prg_body = <<-EMS
      IF (CurrentTime == (occ_hr_end - ZoneTimeStep)),
          SET #{zone_name}_daily_cool_sum_one = #{zone_name}_daily_cool_sum,
          SET #{zone_name}_daily_heat_sum_one = #{zone_name}_daily_heat_sum,
          SET #{zone_name}_daily_cool_sum = @TrendSum #{zone_name}_Rad_Cool_Operation_Trend 24/ZoneTimeStep,
          SET #{zone_name}_daily_heat_sum = @TrendSum #{zone_name}_Rad_Heat_Operation_Trend 24/ZoneTimeStep,
      ENDIF
    EMS
    calculate_cumulative_sum_prg.setBody(calculate_cumulative_sum_prg_body)

    # Calculate the new active slab temperature setpoint for heating and cooling
    calculate_slab_ctrl_setpoint_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_slab_ctrl_setpoint_prg.setName("#{zone_name}_Calculate_Slab_Ctrl_Setpoint")
    calculate_slab_ctrl_setpoint_prg_body = <<-EMS
      IF (#{zone_name}_zone_mode >= 0),
        SET #{zone_name}_cont_cool_oper = @TrendSum #{zone_name}_Rad_Cool_Operation_Trend 24/ZoneTimeStep,
        IF (#{zone_name}_cont_cool_oper > 0) && (CurrentTime == occ_hr_end),
          SET #{zone_name}_CMD_SLAB_SP = #{zone_name}_CMD_SLAB_SP + (#{zone_name}_CMD_CSP_ERROR*prp_k),
        ENDIF,
      ELSEIF (#{zone_name}_zone_mode <= 0),
        SET #{zone_name}_cont_heat_oper = @TrendSum #{zone_name}_Rad_Heat_Operation_Trend 24/ZoneTimeStep,
        IF (#{zone_name}_cont_heat_oper > 0) && (CurrentTime == occ_hr_end),
          SET #{zone_name}_CMD_SLAB_SP = #{zone_name}_CMD_SLAB_SP + (#{zone_name}_CMD_HSP_ERROR*prp_k),
        ENDIF,
      ENDIF,
      IF (#{zone_name}_CMD_SLAB_SP < lower_slab_sp_lim),
        SET #{zone_name}_CMD_SLAB_SP = lower_slab_sp_lim,
      ELSEIF (#{zone_name}_CMD_SLAB_SP > upper_slab_sp_lim),
        SET #{zone_name}_CMD_SLAB_SP = upper_slab_sp_lim,
      ENDIF,
    EMS
    calculate_slab_ctrl_setpoint_prg.setBody(calculate_slab_ctrl_setpoint_prg_body)

    # Apply a weekend setback at the start of a weekend and remove the reset at the defined time.
    implement_setback_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    implement_setback_prg.setName("#{zone_name}_Implement_setback")
    implement_setback_prg_body = <<-EMS
      IF early_reset_out > occ_hr_start,
          SET turn_on_day = 1,
          SET turn_on_hour = 24 - (early_reset_out - occ_hr_start),
      ELSE,
          SET turn_on_day = 2,
          SET turn_on_hour = occ_hr_start - early_reset_out,
      ENDIF,
      IF (CurrentTime == occ_hr_end) && (DayOfWeek == 6),
          SET #{zone_name}_CMD_SLAB_SP = #{zone_name}_CMD_SLAB_SP,
      ELSEIF (CurrentTime == turn_on_hour) && (DayOfWeek == turn_on_day),
          SET #{zone_name}_CMD_SLAB_SP = #{zone_name}_CMD_SLAB_SP,
      ENDIF
    EMS
    implement_setback_prg.setBody(implement_setback_prg_body)

    # Get design day size
    num_design_days = model.getDesignDays.size
    OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', "EMS code for radiant system operation depends on the number of design days being fixed. The model has #{num_design_days}.  Do not change design days now that the model has EMS code dependent on them. ")

    # Turn radiant system ON/OFF for cooling or heating based on calculated setpoints and building mode.
    determine_radiant_operation_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    determine_radiant_operation_prg.setName("#{zone_name}_Determine_Radiant_Operation")
    determine_radiant_operation_prg_body = <<-EMS
      IF (CurrentEnvironment) <= #{num_design_days} ! Operation during design days
          SET #{zone_name}_CMD_COLD_WATER_CTRL = 0,
          SET #{zone_name}_CMD_HOT_WATER_CTRL = -60,
      ELSE,                ! Operation during annual simulation
          IF (#{zone_name}_zone_mode >= 0) && (#{zone_name}_Srf_Temp > #{zone_name}_CMD_SLAB_SP),
              SET #{zone_name}_CMD_COLD_WATER_CTRL = 0,
              SET #{zone_name}_CMD_HOT_WATER_CTRL = -60,
          ELSEIF (#{zone_name}_zone_mode >= 0) && (#{zone_name}_Srf_Temp < #{zone_name}_CMD_SLAB_SP) && (min_oper > #{zone_name}_cont_rad_oper) && (#{zone_name}_cont_rad_oper <> 0),
              SET #{zone_name}_CMD_COLD_WATER_CTRL = 0,
              SET #{zone_name}_CMD_HOT_WATER_CTRL = -60,
          ELSEIF (#{zone_name}_zone_mode <= 0) && (#{zone_name}_Srf_Temp < #{zone_name}_CMD_SLAB_SP),
              SET #{zone_name}_CMD_COLD_WATER_CTRL = 100,
              SET #{zone_name}_CMD_HOT_WATER_CTRL = 60,
          ELSEIF (#{zone_name}_zone_mode <= 0) && (#{zone_name}_Srf_Temp > #{zone_name}_CMD_SLAB_SP) && (min_oper > #{zone_name}_cont_rad_oper) && (#{zone_name}_cont_rad_oper <> 0),
              SET #{zone_name}_CMD_COLD_WATER_CTRL = 100,
              SET #{zone_name}_CMD_HOT_WATER_CTRL = 60,
          ELSE,
              SET #{zone_name}_CMD_COLD_WATER_CTRL = 60,
              SET #{zone_name}_CMD_HOT_WATER_CTRL = -60,
          ENDIF,
      ENDIF
    EMS
    determine_radiant_operation_prg.setBody(determine_radiant_operation_prg_body)

    #####
    # List of EMS program manager objects
    ####
    initialize_constant_parameters = model.getEnergyManagementSystemProgramCallingManagerByName('Set_Constant_Values')
    if initialize_constant_parameters.is_initialized
      initialize_constant_parameters = initialize_constant_parameters.get
    else
      initialize_constant_parameters = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      initialize_constant_parameters.setName('Initialize_Constant_Parameters')
      initialize_constant_parameters.setCallingPoint('BeginNewEnvironment')
      initialize_constant_parameters.addProgram(set_constant_values_prg)
    end

    initialize_constant_parameters_after_warmup = model.getEnergyManagementSystemProgramCallingManagerByName('Set_Constant_Values')
    if initialize_constant_parameters_after_warmup.is_initialized
      initialize_constant_parameters_after_warmup = initialize_constant_parameters_after_warmup.get
    else
      initialize_constant_parameters_after_warmup = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
      initialize_constant_parameters_after_warmup.setName('Initialize_Constant_Parameters_After_Warmup')
      initialize_constant_parameters_after_warmup.setCallingPoint('BeginNewEnvironment')
      initialize_constant_parameters_after_warmup.addProgram(set_constant_values_prg)
    end

    zone_initialize_constant_parameters = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    zone_initialize_constant_parameters.setName("#{zone_name}_Initialize_Constant_Parameters")
    zone_initialize_constant_parameters.setCallingPoint('BeginNewEnvironment')
    zone_initialize_constant_parameters.addProgram(set_constant_zone_values_prg)

    zone_initialize_constant_parameters_after_warmup = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    zone_initialize_constant_parameters_after_warmup.setName("#{zone_name}_Initialize_Constant_Parameters_After_Warmup")
    zone_initialize_constant_parameters_after_warmup.setCallingPoint('BeginNewEnvironment')
    zone_initialize_constant_parameters_after_warmup.addProgram(set_constant_zone_values_prg)

    average_building_temperature = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    average_building_temperature.setName("#{zone_name}_Average_Building_Temperature")
    average_building_temperature.setCallingPoint('EndOfZoneTimestepAfterZoneReporting')
    average_building_temperature.addProgram(calculate_minmax_ctrl_temp_prg)
    average_building_temperature.addProgram(calculate_errors_from_comfort_prg)
    average_building_temperature.addProgram(calculate_neutral_time_prg)
    average_building_temperature.addProgram(determine_zone_mode_prg)
    average_building_temperature.addProgram(calculate_trends_prg)
    average_building_temperature.addProgram(calculate_continuous_radiant_operation_prg)
    average_building_temperature.addProgram(calculate_cumulative_sum_prg)

    programs_at_beginning_of_timestep = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    programs_at_beginning_of_timestep.setName("#{zone_name}_Programs_At_Beginning_Of_Timestep")
    programs_at_beginning_of_timestep.setCallingPoint('BeginTimestepBeforePredictor')
    programs_at_beginning_of_timestep.addProgram(determine_weekend_prg)
    programs_at_beginning_of_timestep.addProgram(determine_unoccupied_prg)
    programs_at_beginning_of_timestep.addProgram(determine_zone_mode_prg)
    programs_at_beginning_of_timestep.addProgram(implement_setback_prg)
    programs_at_beginning_of_timestep.addProgram(calculate_slab_ctrl_setpoint_prg)
    programs_at_beginning_of_timestep.addProgram(determine_radiant_operation_prg)

    #####
    # List of variables for output.
    ####
    zone_max_ctrl_temp_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_max_ctrl_temp)
    zone_max_ctrl_temp_output.setName("#{zone_name} Maximum occupied temperature in zone")
    zone_min_ctrl_temp_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_min_ctrl_temp)
    zone_min_ctrl_temp_output.setName("#{zone_name} Minimum occupied temperature in zone")
    zone_zone_mode_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_zone_mode)
    zone_zone_mode_output.setName("#{zone_name} Zone Mode of Operation")
    zone_cont_neutral_oper_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_cont_neutral_oper)
    zone_cont_neutral_oper_output.setName("#{zone_name} Number of Hours in Neutral Operation")
    zone_cont_rad_oper_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_cont_rad_oper)
    zone_cont_rad_oper_output.setName("#{zone_name} Number of Hours in Continuous Operation")
    zone_daily_cool_sum_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_daily_cool_sum)
    zone_daily_cool_sum_output.setName("#{zone_name} Daily Building Cool Operation")
    zone_daily_heat_sum_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_daily_heat_sum)
    zone_daily_heat_sum_output.setName("#{zone_name} Daily Building Heat Operation")
    zone_daily_cool_sum_one_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_daily_cool_sum_one)
    zone_daily_cool_sum_one_output.setName("#{zone_name} Daily Building Cool Operation One")
    zone_daily_heat_sum_one_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_daily_heat_sum_one)
    zone_daily_heat_sum_one_output.setName("#{zone_name} Daily Building Heat Operation One")
  end
end

class Standard
  # These EnergyPlus objects implement a proportional control for a single thermal zone with a radiant system.
  # @ref [References::CBERadiantSystems]
  # @param zone [OpenStudio::Model::ThermalZone>] zone to add radiant controls
  # @param radiant_loop [OpenStudio::Model::ZoneHVACLowTempRadiantVarFlow>] radiant loop in thermal zone
  # @param radiant_temperature_control_type [String] determines the controlled temperature for the radiant system
  #   options are 'SurfaceFaceTemperature', 'SurfaceInteriorTemperature'
  # @param model_occ_hr_start [Double] Starting hour of building occupancy
  # @param model_occ_hr_end [Double] Ending hour of building occupancy
  # @todo model_occ_hr_start and model_occ_hr_end from zone occupancy schedules
  # @param proportional_gain [Double] Proportional gain constant (recommended 0.3 or less).
  # @param switch_over_time [Double] Time limitation for when the system can switch between heating and cooling
  def model_add_radiant_proportional_controls(model, zone, radiant_loop,
                                              radiant_temperature_control_type: 'SurfaceFaceTemperature',
                                              model_occ_hr_start: 6.0,
                                              model_occ_hr_end: 18.0,
                                              proportional_gain: 0.3,
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
    # Define radiant system parameters
    ####
    # set radiant system temperature and setpoint control type
    unless ['surfacefacetemperature', 'surfaceinteriortemperature'].include? radiant_temperature_control_type.downcase
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model',
        "Control sequences not compatible with '#{radiant_temperature_control_type}' radiant system control. Defaulting to 'SurfaceFaceTemperature'.")
      radiant_temperature_control_type = "SurfaceFaceTemperature"
    end

    radiant_loop.setTemperatureControlType(radiant_temperature_control_type)

    #####
    # List of schedule objects used to hold calculation results
    ####

    # get existing switchover time schedule or create one if needed
    sch_radiant_switchover = model.getScheduleRulesetByName("Radiant System Switchover")
    if sch_radiant_switchover.is_initialized
      sch_radiant_switchover = sch_radiant_switchover.get
    else
      sch_radiant_switchover = model_add_constant_schedule_ruleset(model,
                                                                   switch_over_time,
                                                                   name = "Radiant System Switchover",
                                                                   sch_type_limit: "Dimensionless")
    end

    # set radiant system switchover schedule
    radiant_loop.setChangeoverDelayTimePeriodSchedule(sch_radiant_switchover.to_Schedule.get)
    
    # Calculated active slab heating and cooling temperature setpoint.
    # radiant system cooling control actuator
    sch_radiant_clgsetp = model_add_constant_schedule_ruleset(model,
                                                              26.0,
                                                              name = "#{zone_name}_Sch_Radiant_ClgSetP")
    coil_cooling_radiant.setCoolingControlTemperatureSchedule(sch_radiant_clgsetp)
    cmd_cold_water_ctrl = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_radiant_clgsetp,
                                                                                'Schedule:Year',
                                                                                'Schedule Value')
    cmd_cold_water_ctrl.setName("#{zone_name}_cmd_cold_water_ctrl")

    # radiant system heating control actuator
    sch_radiant_htgsetp = model_add_constant_schedule_ruleset(model,
                                                              20.0,
                                                              name = "#{zone_name}_Sch_Radiant_HtgSetP")
    coil_heating_radiant.setHeatingControlTemperatureSchedule(sch_radiant_htgsetp)
    cmd_hot_water_ctrl = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_radiant_htgsetp,
                                                                               'Schedule:Year',
                                                                               'Schedule Value')
    cmd_hot_water_ctrl.setName("#{zone_name}_cmd_hot_water_ctrl")

    # Calculated cooling setpoint error. Calculated from upper comfort limit minus setpoint offset and 'measured' controlled zone temperature.
    sch_csp_error = model_add_constant_schedule_ruleset(model,
                                                        0.0,
                                                        name = "#{zone_name}_Sch_CSP_Error")
    cmd_csp_error = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_csp_error,
                                                                          'Schedule:Year',
                                                                          'Schedule Value')
    cmd_csp_error.setName("#{zone_name}_cmd_csp_error")

    # Calculated heating setpoint error. Calculated from lower comfort limit plus setpoint offset and 'measured' controlled zone temperature.
    sch_hsp_error = model_add_constant_schedule_ruleset(model,
                                                        0.0,
                                                        name = "#{zone_name}_Sch_HSP_Error")
    cmd_hsp_error = OpenStudio::Model::EnergyManagementSystemActuator.new(sch_hsp_error,
                                                                          'Schedule:Year',
                                                                          'Schedule Value')
    cmd_hsp_error.setName("#{zone_name}_cmd_hsp_error")


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

    # Upper slab temperature setpoint limit (recommended no higher than 29C (84F))
    upper_slab_sp_lim = model.getEnergyManagementSystemGlobalVariableByName('upper_slab_sp_lim')
    if upper_slab_sp_lim.is_initialized
      upper_slab_sp_lim = upper_slab_sp_lim.get
    else
      upper_slab_sp_lim = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'upper_slab_sp_lim')
    end

    # Lower slab temperature setpoint limit (recommended no lower than 19C (66F))
    lower_slab_sp_lim = model.getEnergyManagementSystemGlobalVariableByName('lower_slab_sp_lim')
    if lower_slab_sp_lim.is_initialized
      lower_slab_sp_lim = lower_slab_sp_lim.get
    else
      lower_slab_sp_lim = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'lower_slab_sp_lim')
    end

    # Temperature offset used as a safety factor for thermal control (recommend 0.5C (1F)).
    ctrl_temp_offset = model.getEnergyManagementSystemGlobalVariableByName('ctrl_temp_offset')
    if ctrl_temp_offset.is_initialized
      ctrl_temp_offset = ctrl_temp_offset.get
    else
      ctrl_temp_offset = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, 'ctrl_temp_offset')
    end

    #####
    # List of zone specific variables used in EMS scripts
    ####

    # Maximum 'measured' temperature in zone during occupied times. Default setup uses mean air temperature.
    # Other possible choices are operative and mean radiant temperature.
    zone_max_ctrl_temp = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_max_ctrl_temp")

    # Minimum 'measured' temperature in zone during occupied times. Default setup uses mean air temperature.
    # Other possible choices are operative and mean radiant temperature.
    zone_min_ctrl_temp = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "#{zone_name}_min_ctrl_temp")

    #####
    # List of 'sensors' used in the EMS programs
    ####

    # Controlled zone temperature for the zone.
    zone_ctrl_temperature = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Air Temperature')
    zone_ctrl_temperature.setName("#{zone_name}_ctrl_temperature")
    zone_ctrl_temperature.setKeyName(zone.name.get)

    # check for zone thermostat and replace heat/cool schedules for radiant system control
    # if there is no zone thermostat, then create one
    zone_thermostat = zone.thermostatSetpointDualSetpoint

    if zone_thermostat.is_initialized
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Replacing thermostat schedules in zone #{zone.name} for radiant system control.")
      zone_thermostat = zone.thermostatSetpointDualSetpoint.get
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Zone #{zone.name} does not have a thermostat. Creating a thermostat for radiant system control.")
      zone_thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
      zone_thermostat.setName("#{zone_name}_Thermostat_DualSetpoint")
    end

    # create new heating and cooling schedules to be used with all radiant systems
    zone_htg_thermostat = model.getScheduleRulesetByName("Radiant System Heating Setpoint")
    if zone_htg_thermostat.is_initialized
      zone_htg_thermostat = zone_htg_thermostat.get
    else
      zone_htg_thermostat = model_add_constant_schedule_ruleset(model,
                                                                20.0,
                                                                name = "Radiant System Heating Setpoint",
                                                                sch_type_limit: "Temperature")
    end

    zone_clg_thermostat = model.getScheduleRulesetByName("Radiant System Cooling Setpoint")
    if zone_clg_thermostat.is_initialized
      zone_clg_thermostat = zone_clg_thermostat.get
    else
      zone_clg_thermostat = model_add_constant_schedule_ruleset(model,
                                                                26.0,
                                                                name = "Radiant System Cooling Setpoint",
                                                                sch_type_limit: "Temperature")
    end

    # implement new heating and cooling schedules
    zone_thermostat.setHeatingSetpointTemperatureSchedule(zone_htg_thermostat)
    zone_thermostat.setCoolingSetpointTemperatureSchedule(zone_clg_thermostat)

    # Upper comfort limit for the zone. Taken from existing thermostat schedules in the zone.
    zone_upper_comfort_limit = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    zone_upper_comfort_limit.setName("#{zone_name}_upper_comfort_limit")
    zone_upper_comfort_limit.setKeyName(zone_clg_thermostat.name.get)

    # Lower comfort limit for the zone. Taken from existing thermostat schedules in the zone.
    zone_lower_comfort_limit = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
    zone_lower_comfort_limit.setName("#{zone_name}_lower_comfort_limit")
    zone_lower_comfort_limit.setKeyName(zone_htg_thermostat.name.get)

    # Radiant system water flow rate used to determine if there is active hydronic cooling in the radiant system.
    zone_rad_cool_operation = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'System Node Mass Flow Rate')
    zone_rad_cool_operation.setName("#{zone_name}_rad_cool_operation")
    zone_rad_cool_operation.setKeyName(coil_cooling_radiant.to_StraightComponent.get.inletModelObject.get.name.get)

    # Radiant system water flow rate used to determine if there is active hydronic heating in the radiant system.
    zone_rad_heat_operation = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'System Node Mass Flow Rate')
    zone_rad_heat_operation.setName("#{zone_name}_rad_heat_operation")
    zone_rad_heat_operation.setKeyName(coil_heating_radiant.to_StraightComponent.get.inletModelObject.get.name.get)

    # Radiant system switchover delay time period schedule 
    # used to determine if there is active hydronic cooling/heating in the radiant system.
    zone_rad_switch_over = model.getEnergyManagementSystemSensorByName("radiant_switch_over_time")

    unless zone_rad_switch_over.is_initialized
      zone_rad_switch_over = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
      zone_rad_switch_over.setName("radiant_switch_over_time")
      zone_rad_switch_over.setKeyName(sch_radiant_switchover.name.get)
    end

    # Last 24 hours trend for radiant system in cooling mode.
    zone_rad_cool_operation_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, zone_rad_cool_operation)
    zone_rad_cool_operation_trend.setName("#{zone_name}_rad_cool_operation_trend")
    zone_rad_cool_operation_trend.setNumberOfTimestepsToBeLogged(zone_timestep * 48)

    # Last 24 hours trend for radiant system in heating mode.
    zone_rad_heat_operation_trend = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, zone_rad_heat_operation)
    zone_rad_heat_operation_trend.setName("#{zone_name}_rad_heat_operation_trend")
    zone_rad_heat_operation_trend.setNumberOfTimestepsToBeLogged(zone_timestep * 48)

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
        SET ctrl_temp_offset   = 0.5,
        SET upper_slab_sp_lim  = 29,
        SET lower_slab_sp_lim  = 19
      EMS
      set_constant_values_prg.setBody(set_constant_values_prg_body)
    end

    # Initialize zone specific constant values used in EMS programs.
    set_constant_zone_values_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    set_constant_zone_values_prg.setName("#{zone_name}_Set_Constant_Values")
    set_constant_zone_values_prg_body = <<-EMS
      SET #{zone_name}_max_ctrl_temp      = #{zone_name}_lower_comfort_limit,
      SET #{zone_name}_min_ctrl_temp      = #{zone_name}_upper_comfort_limit,
      SET #{zone_name}_cmd_csp_error      = 0,
      SET #{zone_name}_cmd_hsp_error      = 0,
      SET #{zone_name}_cmd_cold_water_ctrl = #{zone_name}_upper_comfort_limit,
      SET #{zone_name}_cmd_hot_water_ctrl  = #{zone_name}_lower_comfort_limit
    EMS
    set_constant_zone_values_prg.setBody(set_constant_zone_values_prg_body)

    # Calculate maximum and minimum 'measured' controlled temperature in the zone
    calculate_minmax_ctrl_temp_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_minmax_ctrl_temp_prg.setName("#{zone_name}_Calculate_Extremes_In_Zone")
    calculate_minmax_ctrl_temp_prg_body = <<-EMS
      IF ((CurrentTime >= occ_hr_start) && (CurrentTime <= occ_hr_end)),
          IF #{zone_name}_ctrl_temperature > #{zone_name}_max_ctrl_temp,
              SET #{zone_name}_max_ctrl_temp = #{zone_name}_ctrl_temperature,
          ENDIF,
          IF #{zone_name}_ctrl_temperature < #{zone_name}_min_ctrl_temp,
              SET #{zone_name}_min_ctrl_temp = #{zone_name}_ctrl_temperature,
          ENDIF,
      ELSE,
        SET #{zone_name}_max_ctrl_temp = #{zone_name}_lower_comfort_limit,
        SET #{zone_name}_min_ctrl_temp = #{zone_name}_upper_comfort_limit,
      ENDIF
    EMS
    calculate_minmax_ctrl_temp_prg.setBody(calculate_minmax_ctrl_temp_prg_body)

    # Calculate errors from comfort zone limits and 'measured' controlled temperature in the zone.
    calculate_errors_from_comfort_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_errors_from_comfort_prg.setName("#{zone_name}_Calculate_Errors_From_Comfort")
    calculate_errors_from_comfort_prg_body = <<-EMS
      IF (CurrentTime >= (occ_hr_end - ZoneTimeStep)) && (CurrentTime <= (occ_hr_end)),
          SET #{zone_name}_cmd_csp_error = (#{zone_name}_upper_comfort_limit - ctrl_temp_offset) - #{zone_name}_max_ctrl_temp,
          SET #{zone_name}_cmd_hsp_error = (#{zone_name}_lower_comfort_limit + ctrl_temp_offset) - #{zone_name}_min_ctrl_temp,
      ENDIF
    EMS
    calculate_errors_from_comfort_prg.setBody(calculate_errors_from_comfort_prg_body)

    # Calculate the new active slab temperature setpoint for heating and cooling
    calculate_slab_ctrl_setpoint_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    calculate_slab_ctrl_setpoint_prg.setName("#{zone_name}_Calculate_Slab_Ctrl_Setpoint")
    calculate_slab_ctrl_setpoint_prg_body = <<-EMS
      SET #{zone_name}_cont_cool_oper = @TrendSum #{zone_name}_rad_cool_operation_trend radiant_switch_over_time/ZoneTimeStep,
      SET #{zone_name}_cont_heat_oper = @TrendSum #{zone_name}_rad_heat_operation_trend radiant_switch_over_time/ZoneTimeStep,
      IF (#{zone_name}_cont_cool_oper > 0) && (CurrentTime == occ_hr_end),
        SET #{zone_name}_cmd_hot_water_ctrl = #{zone_name}_cmd_hot_water_ctrl + (#{zone_name}_cmd_csp_error*prp_k),
      ELSEIF (#{zone_name}_cont_heat_oper > 0) && (CurrentTime == occ_hr_end),
        SET #{zone_name}_cmd_hot_water_ctrl = #{zone_name}_cmd_hot_water_ctrl + (#{zone_name}_cmd_hsp_error*prp_k),
      ELSE,
        SET #{zone_name}_cmd_hot_water_ctrl = #{zone_name}_cmd_hot_water_ctrl,
      ENDIF,
      IF (#{zone_name}_cmd_hot_water_ctrl < lower_slab_sp_lim),
        SET #{zone_name}_cmd_hot_water_ctrl = lower_slab_sp_lim,
      ELSEIF (#{zone_name}_cmd_hot_water_ctrl > upper_slab_sp_lim),
        SET #{zone_name}_cmd_hot_water_ctrl = upper_slab_sp_lim,
      ENDIF,
      SET #{zone_name}_cmd_cold_water_ctrl = #{zone_name}_cmd_hot_water_ctrl + 0.01
    EMS
    calculate_slab_ctrl_setpoint_prg.setBody(calculate_slab_ctrl_setpoint_prg_body)

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
      initialize_constant_parameters_after_warmup.setCallingPoint('AfterNewEnvironmentWarmUpIsComplete')
      initialize_constant_parameters_after_warmup.addProgram(set_constant_values_prg)
    end

    zone_initialize_constant_parameters = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    zone_initialize_constant_parameters.setName("#{zone_name}_Initialize_Constant_Parameters")
    zone_initialize_constant_parameters.setCallingPoint('BeginNewEnvironment')
    zone_initialize_constant_parameters.addProgram(set_constant_zone_values_prg)

    zone_initialize_constant_parameters_after_warmup = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    zone_initialize_constant_parameters_after_warmup.setName("#{zone_name}_Initialize_Constant_Parameters_After_Warmup")
    zone_initialize_constant_parameters_after_warmup.setCallingPoint('AfterNewEnvironmentWarmUpIsComplete')
    zone_initialize_constant_parameters_after_warmup.addProgram(set_constant_zone_values_prg)

    average_building_temperature = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    average_building_temperature.setName("#{zone_name}_Average_Building_Temperature")
    average_building_temperature.setCallingPoint('EndOfZoneTimestepAfterZoneReporting')
    average_building_temperature.addProgram(calculate_minmax_ctrl_temp_prg)
    average_building_temperature.addProgram(calculate_errors_from_comfort_prg)

    programs_at_beginning_of_timestep = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    programs_at_beginning_of_timestep.setName("#{zone_name}_Programs_At_Beginning_Of_Timestep")
    programs_at_beginning_of_timestep.setCallingPoint('BeginTimestepBeforePredictor')
    programs_at_beginning_of_timestep.addProgram(calculate_slab_ctrl_setpoint_prg)

    #####
    # List of variables for output.
    ####

    zone_max_ctrl_temp_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_max_ctrl_temp)
    zone_max_ctrl_temp_output.setName("#{zone_name} Maximum occupied temperature in zone")
    zone_min_ctrl_temp_output = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, zone_min_ctrl_temp)
    zone_min_ctrl_temp_output.setName("#{zone_name} Minimum occupied temperature in zone")

  end

  # Native EnergyPlus objects implement a control for a single thermal zone with a radiant system.
  # @param zone [OpenStudio::Model::ThermalZone>] zone to add radiant controls
  # @param radiant_loop [OpenStudio::Model::ZoneHVACLowTempRadiantVarFlow>] radiant loop in thermal zone
  # @param radiant_temperature_control_type [String] determines the controlled temperature for the radiant system
  #   options are 'SurfaceFaceTemperature', 'SurfaceInteriorTemperature'
  # @param switch_over_time [Double] Time limitation for when the system can switch between heating and cooling
  def model_add_radiant_basic_controls(model, zone, radiant_loop,
                                       radiant_temperature_control_type: 'SurfaceFaceTemperature',
                                       slab_setpoint_oa_control: false,
                                       switch_over_time: 24.0)

    zone_name = zone.name.to_s.gsub(/[ +-.]/, '_')

    if model.version < OpenStudio::VersionString.new('3.1.1')
      coil_cooling_radiant = radiant_loop.coolingCoil.to_CoilCoolingLowTempRadiantVarFlow.get
      coil_heating_radiant = radiant_loop.heatingCoil.to_CoilHeatingLowTempRadiantVarFlow.get
    else
      coil_cooling_radiant = radiant_loop.coolingCoil.get.to_CoilCoolingLowTempRadiantVarFlow.get
      coil_heating_radiant = radiant_loop.heatingCoil.get.to_CoilHeatingLowTempRadiantVarFlow.get
    end

    #####
    # Define radiant system parameters
    ####
    # set radiant system temperature and setpoint control type
    unless ['surfacefacetemperature', 'surfaceinteriortemperature'].include? radiant_temperature_control_type.downcase
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model',
        "Control sequences not compatible with '#{radiant_temperature_control_type}' radiant system control. Defaulting to 'SurfaceFaceTemperature'.")
      radiant_temperature_control_type = "SurfaceFaceTemperature"
    end

    radiant_loop.setTemperatureControlType(radiant_temperature_control_type)

    # get existing switchover time schedule or create one if needed
    sch_radiant_switchover = model.getScheduleRulesetByName("Radiant System Switchover")
    if sch_radiant_switchover.is_initialized
      sch_radiant_switchover = sch_radiant_switchover.get
    else
      sch_radiant_switchover = model_add_constant_schedule_ruleset(model,
                                                                  switch_over_time,
                                                                  name = "Radiant System Switchover",
                                                                  sch_type_limit: "Dimensionless")
    end

    # set radiant system switchover schedule
    radiant_loop.setChangeoverDelayTimePeriodSchedule(sch_radiant_switchover.to_Schedule.get)

    # radiant system cooling control setpoint
    slab_setpoint = 22
    sch_radiant_clgsetp = model_add_constant_schedule_ruleset(model,
                                                              slab_setpoint + 0.1,
                                                              name = "#{zone_name}_Sch_Radiant_ClgSetP")
    coil_cooling_radiant.setCoolingControlTemperatureSchedule(sch_radiant_clgsetp)

    # radiant system heating control setpoint
    sch_radiant_htgsetp = model_add_constant_schedule_ruleset(model,
                                                              slab_setpoint,
                                                              name = "#{zone_name}_Sch_Radiant_HtgSetP")
    coil_heating_radiant.setHeatingControlTemperatureSchedule(sch_radiant_htgsetp)
  end

end

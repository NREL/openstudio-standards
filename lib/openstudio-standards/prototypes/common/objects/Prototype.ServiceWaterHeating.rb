class Standard
  # @!group ServiceWaterHeating

  # Creates a service water heating loop.
  #
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param water_heater_thermal_zone [OpenStudio::Model::ThermalZone]
  # zones to place water heater in.  If nil, will be assumed in 70F air for heat loss.
  # @param service_water_temperature [Double] service water temperature, in C
  # @param service_water_pump_head [Double] service water pump head, in Pa
  # @param service_water_pump_motor_efficiency [Double]
  # service water pump motor efficiency, as decimal.
  # @param water_heater_capacity [Double] water heater heating capacity, in W
  # @param water_heater_volume [Double] water heater volume, in m^3
  # @param water_heater_fuel [String] water heater fuel.
  # Valid choices are Natural Gas, Electricity
  # @param parasitic_fuel_consumption_rate [Double] the parasitic fuel consumption
  # rate of the water heater, in W
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::PlantLoop]
  # the resulting service water loop.
  def model_add_swh_loop(model,
                         system_name,
                         water_heater_thermal_zone,
                         service_water_temperature,
                         service_water_pump_head,
                         service_water_pump_motor_efficiency,
                         water_heater_capacity,
                         water_heater_volume,
                         water_heater_fuel,
                         parasitic_fuel_consumption_rate,
                         building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding service water loop')

    # Service water heating loop
    service_water_loop = OpenStudio::Model::PlantLoop.new(model)
    service_water_loop.setMinimumLoopTemperature(10)
    service_water_loop.setMaximumLoopTemperature(60)

    if system_name.nil?
      service_water_loop.setName('Service Water Loop')
    else
      service_water_loop.setName(system_name)
    end

    # Temperature schedule type limits
    temp_sch_type_limits =  model_add_schedule_type_limits(model,
                                                           name: "Temperature Schedule Type Limits",
                                                           lower_limit_value: 0.0,
                                                           upper_limit_value: 100.0,
                                                           numeric_type: "Continuous",
                                                           unit_type: "Temperature")

    # Service water heating loop controls
    swh_temp_c = service_water_temperature
    swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
    swh_delta_t_r = 9 # 9F delta-T
    swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
    swh_temp_sch = model_add_constant_schedule_ruleset(model,
                                                       swh_temp_c,
                                                       name = "Service Water Loop Temp - #{swh_temp_f.round}F")
    swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
    swh_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, swh_temp_sch)
    swh_stpt_manager.setName('Service hot water setpoint manager')
    swh_stpt_manager.addToNode(service_water_loop.supplyOutletNode)
    sizing_plant = service_water_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(swh_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(swh_delta_t_k)

    # Service water heating pump
    swh_pump_head_press_pa = service_water_pump_head
    swh_pump_motor_efficiency = service_water_pump_motor_efficiency
    if swh_pump_head_press_pa.nil?
      # As if there is no circulation pump
      swh_pump_head_press_pa = 0.001
      swh_pump_motor_efficiency = 1
    end

    swh_pump = case model_swh_pump_type(model, building_type)
               when 'ConstantSpeed'
                 OpenStudio::Model::PumpConstantSpeed.new(model)
               when 'VariableSpeed'
                 OpenStudio::Model::PumpVariableSpeed.new(model)
               end
    swh_pump.setName('Service Water Loop Pump')
    swh_pump.setRatedPumpHead(swh_pump_head_press_pa.to_f)
    swh_pump.setMotorEfficiency(swh_pump_motor_efficiency)
    swh_pump.setPumpControlType('Intermittent')
    swh_pump.addToNode(service_water_loop.supplyInletNode)

    water_heater = model_add_water_heater(model,
                                          water_heater_capacity,
                                          water_heater_volume,
                                          water_heater_fuel,
                                          service_water_temperature,
                                          parasitic_fuel_consumption_rate,
                                          swh_temp_sch,
                                          false,
                                          0.0,
                                          nil,
                                          water_heater_thermal_zone)

    service_water_loop.addSupplyBranchForComponent(water_heater)

    # Service water heating loop bypass pipes
    water_heater_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    service_water_loop.addSupplyBranchForComponent(water_heater_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    service_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.addToNode(service_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.addToNode(service_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.addToNode(service_water_loop.demandOutletNode)

    return service_water_loop
  end

  # Determine the type of SWH pump that a model will have.  Defaults to ConstantSpeed.
  # @return [String] the SWH pump type: ConstantSpeed, VariableSpeed
  def model_swh_pump_type(model, building_type)
    swh_pump_type = 'ConstantSpeed'
    return swh_pump_type
  end

  # Creates a water heater and attaches it to the supplied service water heating loop.
  #
  # @param water_heater_capacity [Double] water heater capacity, in W
  # @param water_heater_volume [Double] water heater volume, in m^3
  # @param water_heater_fuel [Double] valid choices are
  # Natural Gas, Electricity
  # @param service_water_temperature [Double] water heater temperature, in C
  # @param parasitic_fuel_consumption_rate [Double] water heater parasitic
  # fuel consumption rate, in W
  # @param swh_temp_sch [OpenStudio::Model::Schedule] the service water heating
  # schedule. If nil, will be defaulted.
  # @param set_peak_use_flowrate [Bool] if true, the peak flow rate
  # and flow rate schedule will be set.
  # @param peak_flowrate [Double] in m^3/s
  # @param flowrate_schedule [String] name of the flow rate schedule
  # @param water_heater_thermal_zone [OpenStudio::Model::ThermalZone]
  # zones to place water heater in.  If nil, will be assumed in 70F air for heat loss.
  # @return [OpenStudio::Model::WaterHeaterMixed]
  # the resulting water heater.
  def model_add_water_heater(model,
                             water_heater_capacity,
                             water_heater_volume,
                             water_heater_fuel,
                             service_water_temperature,
                             parasitic_fuel_consumption_rate,
                             swh_temp_sch,
                             set_peak_use_flowrate,
                             peak_flowrate,
                             flowrate_schedule,
                             water_heater_thermal_zone)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding water heater')

    # Water heater
    # TODO Standards - Change water heater methodology to follow
    # 'Model Enhancements Appendix A.'
    water_heater_capacity_btu_per_hr = OpenStudio.convert(water_heater_capacity, 'W', 'Btu/hr').get
    water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'kBtu/hr').get
    water_heater_vol_gal = OpenStudio.convert(water_heater_volume, 'm^3', 'gal').get

    # Temperature schedule type limits
    temp_sch_type_limits =  model_add_schedule_type_limits(model,
                                                           name: "Temperature Schedule Type Limits",
                                                           lower_limit_value: 0.0,
                                                           upper_limit_value: 100.0,
                                                           numeric_type: "Continuous",
                                                           unit_type: "Temperature")

    if swh_temp_sch.nil?
      # Service water heating loop controls
      swh_temp_c = service_water_temperature
      swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
      swh_delta_t_r = 9 # 9F delta-T
      swh_temp_c = OpenStudio.convert(swh_temp_f, 'F', 'C').get
      swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
      swh_temp_sch = model_add_constant_schedule_ruleset(model,
                                                         swh_temp_c,
                                                         name = "Service Water Loop Temp - #{swh_temp_f.round}F")
      swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
    end

    # Water heater depends on the fuel type
    water_heater = OpenStudio::Model::WaterHeaterMixed.new(model)
    water_heater.setName("#{water_heater_vol_gal.round}gal #{water_heater_fuel} Water Heater - #{water_heater_capacity_kbtu_per_hr.round}kBtu/hr")
    water_heater.setTankVolume(OpenStudio.convert(water_heater_vol_gal, 'gal', 'm^3').get)
    water_heater.setSetpointTemperatureSchedule(swh_temp_sch)

    if water_heater_thermal_zone.nil?
      # Assume the water heater is indoors at 70F for now
      default_water_heater_ambient_temp_sch = model_add_constant_schedule_ruleset(model,
                                                                                  OpenStudio.convert(70.0, 'F', 'C').get,
                                                                                  name = 'Water Heater Ambient Temp Schedule - 70F')
      default_water_heater_ambient_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
      water_heater.setAmbientTemperatureIndicator('Schedule')
      water_heater.setAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
      water_heater.resetAmbientTemperatureThermalZone
    else
      water_heater.setAmbientTemperatureIndicator('ThermalZone')
      water_heater.setAmbientTemperatureThermalZone(water_heater_thermal_zone)
      water_heater.resetAmbientTemperatureSchedule
    end

    water_heater.setMaximumTemperatureLimit(OpenStudio.convert(180, 'F', 'C').get)
    water_heater.setDeadbandTemperatureDifference(OpenStudio.convert(3.6, 'R', 'K').get)
    water_heater.setHeaterControlType('Cycle')
    water_heater.setHeaterMaximumCapacity(OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'W').get)
    water_heater.setOffCycleParasiticHeatFractiontoTank(0.8)
    water_heater.setIndirectWaterHeatingRecoveryTime(1.5) # 1.5hrs
    if water_heater_fuel == 'Electricity'
      water_heater.setHeaterFuelType('Electricity')
      water_heater.setHeaterThermalEfficiency(1.0)
      water_heater.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOffCycleParasiticFuelType('Electricity')
      water_heater.setOnCycleParasiticFuelType('Electricity')
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053)
    elsif water_heater_fuel == 'Natural Gas'
      water_heater.setHeaterFuelType('Gas')
      water_heater.setHeaterThermalEfficiency(0.78)
      water_heater.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOffCycleParasiticFuelType('Gas')
      water_heater.setOnCycleParasiticFuelType('Gas')
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(6.0)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(6.0)
    end

    if set_peak_use_flowrate
      rated_flow_rate_m3_per_s = peak_flowrate
      rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get
      water_heater.setPeakUseFlowRate(rated_flow_rate_m3_per_s)

      schedule = model_add_schedule(model, flowrate_schedule)
      water_heater.setUseFlowRateFractionSchedule(schedule)
    end

    return water_heater
  end

  # Creates a booster water heater and attaches it
  # to the supplied service water heating loop.
  #
  # @param main_service_water_loop [OpenStudio::Model::PlantLoop]
  # the main service water loop that this booster assists.
  # @param water_heater_capacity [Double] water heater capacity, in W
  # @param water_heater_volume [Double] water heater volume, in m^3
  # @param water_heater_fuel [Double] valid choices are
  # Gas, Electric
  # @param booster_water_temperature [Double] water heater temperature, in C
  # @param parasitic_fuel_consumption_rate [Double] water heater parasitic
  # fuel consumption rate, in W
  # @param booster_water_heater_thermal_zone [OpenStudio::Model::ThermalZone]
  # zones to place water heater in.  If nil, will be assumed in 70F air for heat loss.
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::PlantLoop]
  # the resulting booster water loop.
  def model_add_swh_booster(model,
                            main_service_water_loop,
                            water_heater_capacity,
                            water_heater_volume,
                            water_heater_fuel,
                            booster_water_temperature,
                            parasitic_fuel_consumption_rate,
                            booster_water_heater_thermal_zone,
                            building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding booster water heater to #{main_service_water_loop.name}")

    # Booster water heating loop
    booster_service_water_loop = OpenStudio::Model::PlantLoop.new(model)
    booster_service_water_loop.setName('Service Water Loop')

    # Temperature schedule type limits
    temp_sch_type_limits =  model_add_schedule_type_limits(model,
                                                           name: "Temperature Schedule Type Limits",
                                                           lower_limit_value: 0.0,
                                                           upper_limit_value: 100.0,
                                                           numeric_type: "Continuous",
                                                           unit_type: "Temperature")

    # Service water heating loop controls
    swh_temp_c = booster_water_temperature
    swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
    swh_delta_t_r = 9 # 9F delta-T
    swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
    swh_temp_sch = model_add_constant_schedule_ruleset(model,
                                                       swh_temp_c,
                                                       name = "Service Water Booster Temp - #{swh_temp_f}F")
    swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
    swh_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, swh_temp_sch)
    swh_stpt_manager.setName('Hot water booster setpoint manager')
    swh_stpt_manager.addToNode(booster_service_water_loop.supplyOutletNode)
    sizing_plant = booster_service_water_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(swh_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(swh_delta_t_k)

    # Booster water heating pump
    swh_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    swh_pump.setName('Booster Water Loop Pump')
    swh_pump_head_press_pa = 0.0 # As if there is no circulation pump
    swh_pump.setRatedPumpHead(swh_pump_head_press_pa)
    swh_pump.setMotorEfficiency(1)
    swh_pump.setPumpControlType('Intermittent')
    swh_pump.addToNode(booster_service_water_loop.supplyInletNode)

    # Water heater
    # TODO Standards - Change water heater methodology to follow
    # 'Model Enhancements Appendix A.'
    water_heater_capacity_btu_per_hr = OpenStudio.convert(water_heater_capacity, 'W', 'Btu/hr').get
    water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'kBtu/hr').get
    water_heater_vol_gal = OpenStudio.convert(water_heater_volume, 'm^3', 'gal').get

    # Water heater depends on the fuel type
    water_heater = OpenStudio::Model::WaterHeaterMixed.new(model)
    water_heater.setName("#{water_heater_vol_gal}gal #{water_heater_fuel} Booster Water Heater - #{water_heater_capacity_kbtu_per_hr.round}kBtu/hr")
    water_heater.setTankVolume(OpenStudio.convert(water_heater_vol_gal, 'gal', 'm^3').get)
    water_heater.setSetpointTemperatureSchedule(swh_temp_sch)

    if booster_water_heater_thermal_zone.nil?
      # Assume the water heater is indoors at 70F for now
      default_water_heater_ambient_temp_sch = model_add_constant_schedule_ruleset(model,
                                                                                  OpenStudio.convert(70.0, 'F', 'C').get,
                                                                                  name = 'Water Heater Ambient Temp Schedule - 70F')
      default_water_heater_ambient_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
      water_heater.setAmbientTemperatureIndicator('Schedule')
      water_heater.setAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
      water_heater.resetAmbientTemperatureThermalZone
    else
      water_heater.setAmbientTemperatureIndicator('ThermalZone')
      water_heater.setAmbientTemperatureThermalZone(booster_water_heater_thermal_zone)
      water_heater.resetAmbientTemperatureSchedule
    end

    water_heater.setMaximumTemperatureLimit(OpenStudio.convert(180, 'F', 'C').get)
    water_heater.setDeadbandTemperatureDifference(OpenStudio.convert(3.6, 'R', 'K').get)
    water_heater.setHeaterControlType('Cycle')
    water_heater.setHeaterMaximumCapacity(OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'W').get)
    water_heater.setOffCycleParasiticHeatFractiontoTank(0.8)
    water_heater.setIndirectWaterHeatingRecoveryTime(1.5) # 1.5hrs
    if water_heater_fuel == 'Electricity'
      water_heater.setHeaterFuelType('Electricity')
      water_heater.setHeaterThermalEfficiency(1.0)
      water_heater.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOffCycleParasiticFuelType('Electricity')
      water_heater.setOnCycleParasiticFuelType('Electricity')
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053)
    elsif water_heater_fuel == 'Natural Gas'
      water_heater.setHeaterFuelType('Gas')
      water_heater.setHeaterThermalEfficiency(0.8)
      water_heater.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOffCycleParasiticFuelType('Gas')
      water_heater.setOnCycleParasiticFuelType('Gas')
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(6.0)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(6.0)
    end

    if water_heater_fuel == 'Electricity'
      water_heater.setHeaterFuelType('Electricity')
      water_heater.setOffCycleParasiticFuelType('Electricity')
      water_heater.setOnCycleParasiticFuelType('Electricity')
    elsif water_heater_fuel == 'Natural Gas'
      water_heater.setHeaterFuelType('Gas')
      water_heater.setOffCycleParasiticFuelType('Gas')
      water_heater.setOnCycleParasiticFuelType('Gas')
    end
    booster_service_water_loop.addSupplyBranchForComponent(water_heater)

    # Service water heating loop bypass pipes
    water_heater_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    booster_service_water_loop.addSupplyBranchForComponent(water_heater_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    booster_service_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.addToNode(booster_service_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.addToNode(booster_service_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.addToNode(booster_service_water_loop.demandOutletNode)

    # Heat exchanger to supply the booster water heater
    # with normal hot water from the main service water loop.
    hx = OpenStudio::Model::HeatExchangerFluidToFluid.new(model)
    hx.setName('HX for Booster Water Heating')
    hx.setHeatExchangeModelType('Ideal')
    hx.setControlType('UncontrolledOn')
    hx.setHeatTransferMeteringEndUseType('LoopToLoop')

    # Add the HX to the supply side of the booster loop
    hx.addToNode(booster_service_water_loop.supplyInletNode)

    # Add the HX to the demand side of
    # the main service water loop.
    main_service_water_loop.addDemandBranchForComponent(hx)

    return booster_service_water_loop
  end

  # Creates water fixtures and attaches them
  # to the supplied service water loop.
  #
  # @param use_name [String] The name that will be assigned
  # to the newly created fixture.
  # @param swh_loop [OpenStudio::Model::PlantLoop]
  # the main service water loop to add water fixtures to.
  # @param peak_flowrate [Double] in m^3/s
  # @param flowrate_schedule [String] name of the flow rate schedule
  # @param water_use_temperature [Double] mixed water use temperature, in C
  # @param space_name [String] the name of the space to add the water fixture to,
  # or nil, in which case it will not be assigned to any particular space.
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::WaterUseEquipment]
  # the resulting water fixture.
  def model_add_swh_end_uses(model,
                             use_name,
                             swh_loop,
                             peak_flowrate,
                             flowrate_schedule,
                             water_use_temperature,
                             space_name,
                             building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding water fixture to #{swh_loop.name}.")

    # Water use connection
    swh_connection = OpenStudio::Model::WaterUseConnections.new(model)

    # Water fixture definition
    water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
    rated_flow_rate_m3_per_s = peak_flowrate
    rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get
    frac_sensible = 0.2
    frac_latent = 0.05
    water_use_sensible_frac_sch = model_add_constant_schedule_ruleset(model,
                                                                      frac_sensible,
                                                                      name = "Fraction Sensible - #{frac_sensible}",
                                                                      sch_type_limit: 'Fractional')
    water_use_latent_frac_sch = model_add_constant_schedule_ruleset(model,
                                                                    frac_latent,
                                                                    name = "Fraction Latent - #{frac_latent}",
                                                                    sch_type_limit: 'Fractional')
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    water_fixture_def.setName("#{use_name.capitalize} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    # Target mixed water temperature
    mixed_water_temp_f = OpenStudio.convert(water_use_temperature, 'C', 'F').get
    mixed_water_temp_sch = model_add_constant_schedule_ruleset(model,
                                                               OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get,
                                                               name = "Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F")
    water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

    # Water use equipment
    water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
    schedule = model_add_schedule(model, flowrate_schedule)
    water_fixture.setFlowRateFractionSchedule(schedule)

    if space_name.nil?
      water_fixture.setName("#{use_name.capitalize} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    else
      water_fixture.setName("#{space_name.capitalize} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    end

    unless space_name.nil?
      space = model.getSpaceByName(space_name)
      space = space.get
      water_fixture.setSpace(space)
    end

    swh_connection.addWaterUseEquipment(water_fixture)

    # Connect the water use connection to the SWH loop
    swh_loop.addDemandBranchForComponent(swh_connection)

    return water_fixture
  end

  # This method will add an swh water fixture to the model for the space.
  # if the it will return a water fixture object, or NIL if there is no water load at all.
  def model_add_swh_end_uses_by_space(model, building_type, climate_zone, swh_loop, space_type_name, space_name, space_multiplier = nil, is_flow_per_area = true)
    # find the specific space_type properties from standard.json
    search_criteria = {
        'template' => template,
        'building_type' => building_type,
        'space_type' => space_type_name
    }
    data = model_find_object(standards_data['space_types'], search_criteria)
    if data.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find space type for: #{search_criteria}.")
      return nil
    end
    space = model.getSpaceByName(space_name)
    space = space.get
    space_area = OpenStudio.convert(space.floorArea, 'm^2', 'ft^2').get # ft2
    if space_multiplier.nil?
      space_multiplier = 1
    end

    # If there is no service hot water load.. Don't bother adding anything.
    if data['service_water_heating_peak_flow_per_area'].to_f == 0.0 &&
        data['service_water_heating_peak_flow_rate'].to_f == 0.0
      return nil
    end

    # Water use connection
    swh_connection = OpenStudio::Model::WaterUseConnections.new(model)

    # Water fixture definition
    water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
    rated_flow_rate_per_area = data['service_water_heating_peak_flow_per_area'].to_f # gal/h.ft2
    rated_flow_rate_gal_per_hour = if is_flow_per_area
                                     rated_flow_rate_per_area * space_area * space_multiplier # gal/h
                                   else
                                     data['service_water_heating_peak_flow_rate'].to_f
                                   end
    rated_flow_rate_gal_per_min = rated_flow_rate_gal_per_hour / 60 # gal/h to gal/min
    rated_flow_rate_m3_per_s = OpenStudio.convert(rated_flow_rate_gal_per_min, 'gal/min', 'm^3/s').get
    water_use_sensible_frac_sch = model_add_constant_schedule_ruleset(model,
                                                                      0.2,
                                                                      name = 'Fraction Sensible - 0.2',
                                                                      sch_type_limit: 'Fractional')
    water_use_latent_frac_sch = model_add_constant_schedule_ruleset(model,
                                                                    0.05,
                                                                    name = 'Fraction Latent - 0.05',
                                                                    sch_type_limit: 'Fractional')
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    water_fixture_def.setName("#{space_name.capitalize} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    # Target mixed water temperature
    mixed_water_temp_c = data['service_water_heating_target_temperature']
    mixed_water_temp_f = OpenStudio.convert(mixed_water_temp_c, 'C', 'F').get
    mixed_water_temp_sch = model_add_constant_schedule_ruleset(model,
                                                               mixed_water_temp_c,
                                                               name = "Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F")
    water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

    # Water use equipment
    water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
    schedule = model_add_schedule(model, data['service_water_heating_schedule'])
    water_fixture.setFlowRateFractionSchedule(schedule)
    water_fixture.setName("#{space_name.capitalize} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    swh_connection.addWaterUseEquipment(water_fixture)
    # Assign water fixture to a space
    water_fixture.setSpace(space) if model_attach_water_fixtures_to_spaces?(model)

    # Connect the water use connection to the SWH loop
    swh_loop.addDemandBranchForComponent(swh_connection)
    return water_fixture
  end

  # Determine whether or not water fixtures are attached to spaces
  def model_attach_water_fixtures_to_spaces?(model)
    return false
  end

  # Creates water fixtures and attaches them
  # to the supplied booster water loop.
  #
  # @param swh_booster_loop [OpenStudio::Model::PlantLoop]
  # the booster water loop to add water fixtures to.
  # @param peak_flowrate [Double] in m^3/s
  # @param flowrate_schedule [String] name of the flow rate schedule
  # @param water_use_temperature [Double] mixed water use temperature, in C
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::WaterUseEquipment]
  # the resulting water fixture.
  def model_add_booster_swh_end_uses(model,
                                     swh_booster_loop,
                                     peak_flowrate,
                                     flowrate_schedule,
                                     water_use_temperature,
                                     building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding water fixture to #{swh_booster_loop.name}.")

    # Water use connection
    swh_connection = OpenStudio::Model::WaterUseConnections.new(model)

    # Water fixture definition
    water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
    rated_flow_rate_m3_per_s = peak_flowrate
    rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get
    water_fixture_def.setName("Water Fixture Def - #{rated_flow_rate_gal_per_min} gal/min")
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    # Target mixed water temperature
    mixed_water_temp_f = OpenStudio.convert(water_use_temperature, 'F', 'C').get
    mixed_water_temp_sch = model_add_constant_schedule_ruleset(model,
                                                               OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get,
                                                               name = "Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F")
    water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

    # Water use equipment
    water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
    water_fixture.setName("Booster Water Fixture - #{rated_flow_rate_gal_per_min} gal/min at #{mixed_water_temp_f}F")
    schedule = model_add_schedule(model, flowrate_schedule)
    water_fixture.setFlowRateFractionSchedule(schedule)
    swh_connection.addWaterUseEquipment(water_fixture)

    # Connect the water use connection to the SWH loop
    swh_booster_loop.addDemandBranchForComponent(swh_connection)

    return water_fixture
  end

end
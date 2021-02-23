class Standard
  # @!group ServiceWaterHeating

  # Creates a service water heating loop.
  #
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param water_heater_thermal_zone [OpenStudio::Model::ThermalZone]
  #   zones to place water heater in.  If nil, will be assumed in 70F air for heat loss.
  # @param service_water_temperature [Double] service water temperature, in C
  # @param service_water_pump_head [Double] service water pump head, in Pa
  # @param service_water_pump_motor_efficiency [Double] service water pump motor efficiency, as decimal.
  # @param water_heater_capacity [Double] water heater heating capacity, in W
  # @param water_heater_volume [Double] water heater volume, in m^3
  # @param water_heater_fuel [String] water heater fuel. Valid choices are NaturalGas, Electricity
  # @param parasitic_fuel_consumption_rate [Double] the parasitic fuel consumption rate of the water heater, in W
  # @param add_pipe_losses [Bool] if true, add piping and associated heat losses to system.  If false, add no pipe heat losses
  # @param floor_area_served [Double] area served by the SWH loop, in m^2.  Used for pipe loss piping length estimation
  # @param number_of_stories [Integer] number of stories served by the SWH loop.  Used for pipe loss piping length estimation
  # @param pipe_insulation_thickness [Double] thickness of the fiberglass batt pipe insulation, in m.  Use 0 for uninsulated pipes
  # @param number_water_heaters [Double] the number of water heaters represented by the capacity and volume inputs.
  # Used to modify efficiencies for water heaters based on individual component size while avoiding having to model
  # lots of individual water heaters (for runtime sake).
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
                         add_pipe_losses = false,
                         floor_area_served = 465,
                         number_of_stories = 1,
                         pipe_insulation_thickness = 0.0127, # 1/2in
                         number_water_heaters = 1)
    # Service water heating loop
    service_water_loop = OpenStudio::Model::PlantLoop.new(model)
    service_water_loop.setMinimumLoopTemperature(10.0)
    service_water_loop.setMaximumLoopTemperature(60.0)

    if system_name.nil?
      service_water_loop.setName('Service Water Loop')
    else
      service_water_loop.setName(system_name)
    end

    # Temperature schedule type limits
    temp_sch_type_limits = model_add_schedule_type_limits(model,
                                                          name: 'Temperature Schedule Type Limits',
                                                          lower_limit_value: 0.0,
                                                          upper_limit_value: 100.0,
                                                          numeric_type: 'Continuous',
                                                          unit_type: 'Temperature')

    # Service water heating loop controls
    swh_temp_c = service_water_temperature
    swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
    swh_delta_t_r = 9.0 # 9F delta-T
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

    # Determine if circulating or non-circulating based on supplied head pressure
    swh_pump_head_press_pa = service_water_pump_head
    circulating = true
    if swh_pump_head_press_pa.nil? || swh_pump_head_press_pa <= 1
      # As if there is no circulation pump
      swh_pump_head_press_pa = 0.001
      service_water_pump_motor_efficiency = 1
      circulating = false
    end

    # Service water heating pump
    if circulating
      swh_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
      swh_pump.setName("#{service_water_loop.name} Circulator Pump")
      swh_pump.setPumpControlType('Intermittent')
    else
      swh_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      swh_pump.setName("#{service_water_loop.name} Water Mains Pressure Driven")
      swh_pump.setPumpControlType('Continuous')
    end
    swh_pump.setRatedPumpHead(swh_pump_head_press_pa.to_f)
    swh_pump.setMotorEfficiency(service_water_pump_motor_efficiency)
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
                                          water_heater_thermal_zone,
                                          number_water_heaters)

    service_water_loop.addSupplyBranchForComponent(water_heater)

    # Pipe losses
    if add_pipe_losses
      model_add_piping_losses_to_swh_system(model,
                                            service_water_loop,
                                            circulating,
                                            pipe_insulation_thickness: pipe_insulation_thickness,
                                            floor_area_served: floor_area_served,
                                            number_of_stories: number_of_stories)
    end

    # Service water heating loop bypass pipes
    water_heater_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    service_water_loop.addSupplyBranchForComponent(water_heater_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    service_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.addToNode(service_water_loop.supplyOutletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.addToNode(service_water_loop.demandOutletNode)

    if circulating
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Added circulating SWH loop called #{service_water_loop.name}")
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Added non-circulating SWH loop called #{service_water_loop.name}")
    end

    return service_water_loop
  end

  # Creates a water heater and attaches it to the supplied service water heating loop.
  #
  # @param water_heater_capacity [Double] water heater capacity, in W
  # @param water_heater_volume [Double] water heater volume, in m^3
  # @param water_heater_fuel [Double] valid choices are NaturalGas, Electricity
  # @param service_water_temperature [Double] water heater temperature, in C
  # @param parasitic_fuel_consumption_rate [Double] water heater parasitic fuel consumption rate, in W
  # @param swh_temp_sch [OpenStudio::Model::Schedule] the service water heating schedule. If nil, will be defaulted.
  # @param set_peak_use_flowrate [Bool] if true, the peak flow rate and flow rate schedule will be set.
  # @param peak_flowrate [Double] in m^3/s
  # @param flowrate_schedule [String] name of the flow rate schedule
  # @param water_heater_thermal_zone [OpenStudio::Model::ThermalZone] zone to place water heater in.
  #   If nil, will be assumed in 70F air for heat loss.
  # @param number_water_heaters [Double] the number of water heaters represented by the capacity and volume inputs.
  # Used to modify efficiencies for water heaters based on individual component size while avoiding having to model
  # lots of individual water heaters (for runtime sake).
  # @return [OpenStudio::Model::WaterHeaterMixed] the resulting water heater
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
                             water_heater_thermal_zone,
                             number_water_heaters)
    # Water heater
    # TODO Standards - Change water heater methodology to follow
    # 'Model Enhancements Appendix A.'
    water_heater_capacity_btu_per_hr = OpenStudio.convert(water_heater_capacity, 'W', 'Btu/hr').get
    water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'kBtu/hr').get
    water_heater_vol_gal = OpenStudio.convert(water_heater_volume, 'm^3', 'gal').get

    # Temperature schedule type limits
    temp_sch_type_limits = model_add_schedule_type_limits(model,
                                                          name: 'Temperature Schedule Type Limits',
                                                          lower_limit_value: 0.0,
                                                          upper_limit_value: 100.0,
                                                          numeric_type: 'Continuous',
                                                          unit_type: 'Temperature')

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

    # Assign a quantity to the water heater if it represents multiple water heaters
    if number_water_heaters > 1
      water_heater.setName("#{number_water_heaters}X #{(water_heater_vol_gal / number_water_heaters).round}gal #{water_heater_fuel} Water Heater - #{(water_heater_capacity_kbtu_per_hr / number_water_heaters).round}kBtu/hr")
      water_heater.set_component_quantity(number_water_heaters)
    else
      water_heater.setName("#{water_heater_vol_gal.round}gal #{water_heater_fuel} Water Heater - #{water_heater_capacity_kbtu_per_hr.round}kBtu/hr")
    end

    water_heater.setTankVolume(OpenStudio.convert(water_heater_vol_gal, 'gal', 'm^3').get)
    water_heater.setSetpointTemperatureSchedule(swh_temp_sch)
    water_heater.setDeadbandTemperatureDifference(2.0)

    if water_heater_thermal_zone.nil?
      # Assume the water heater is indoors at 70F or 72F
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
          indoor_temp = 71.6
        else
          indoor_temp = 70.0
        end
      default_water_heater_ambient_temp_sch = model_add_constant_schedule_ruleset(model,
                                                                                  OpenStudio.convert(indoor_temp, 'F', 'C').get,
                                                                                  name = 'Water Heater Ambient Temp Schedule - ' + indoor_temp.to_s + 'f')
      default_water_heater_ambient_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
      water_heater.setAmbientTemperatureIndicator('Schedule')
      water_heater.setAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
      water_heater.resetAmbientTemperatureThermalZone
    else
      water_heater.setAmbientTemperatureIndicator('ThermalZone')
      water_heater.setAmbientTemperatureThermalZone(water_heater_thermal_zone)
      water_heater.resetAmbientTemperatureSchedule
    end

    water_heater.setMaximumTemperatureLimit(service_water_temperature)
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
    elsif water_heater_fuel == 'Natural Gas' || water_heater_fuel == 'NaturalGas'
      water_heater.setHeaterFuelType('Gas')
      water_heater.setHeaterThermalEfficiency(0.78)
      water_heater.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOffCycleParasiticFuelType('Gas')
      water_heater.setOnCycleParasiticFuelType('Gas')
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(6.0)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(6.0)
    elsif water_heater_fuel == 'HeatPump'
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', 'Simple workaround to represent heat pump water heaters without incurring significant runtime penalty associated with using correct objects.')
      # Make a part-load efficiency modifier curve with a value above 1, which
      # is multiplied by the nominal efficiency of 100% to represent
      # the COP of a HPWH.
      # TODO could make this workaround better by using EMS
      # to modify this curve output in realtime based on
      # the OA temperature.
      hpwh_cop = 2.8
      eff_f_of_plr = OpenStudio::Model::CurveCubic.new(model)
      eff_f_of_plr.setName("HPWH_COP_#{hpwh_cop}")
      eff_f_of_plr.setCoefficient1Constant(hpwh_cop)
      eff_f_of_plr.setCoefficient2x(0.0)
      eff_f_of_plr.setCoefficient3xPOW2(0.0)
      eff_f_of_plr.setCoefficient4xPOW3(0.0)
      eff_f_of_plr.setMinimumValueofx(0.0)
      eff_f_of_plr.setMaximumValueofx(1.0)
      water_heater.setHeaterFuelType('Electricity')
      water_heater.setHeaterThermalEfficiency(1.0)
      water_heater.setPartLoadFactorCurve(eff_f_of_plr)
      water_heater.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOffCycleParasiticFuelType('Electricity')
      water_heater.setOnCycleParasiticFuelType('Electricity')
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "#{water_heater_fuel} is not a valid water heater fuel.  Valid choices are Electricity, NaturalGas, and HeatPump.")
    end

    if set_peak_use_flowrate
      rated_flow_rate_m3_per_s = peak_flowrate
      rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get
      water_heater.setPeakUseFlowRate(rated_flow_rate_m3_per_s)

      schedule = model_add_schedule(model, flowrate_schedule)
      water_heater.setUseFlowRateFractionSchedule(schedule)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Added water heater called #{water_heater.name}")

    return water_heater
  end

  # Creates a heatpump water heater and attaches it to the supplied service water heating loop.
  #
  # @param water_heater_capacity [Double] water heater capacity, in W
  # @param water_heater_volume [Double] water heater volume, in m^3
  # @param service_water_temperature [Double] water heater temperature, in C
  # @param parasitic_fuel_consumption_rate [Double] water heater parasitic fuel consumption rate, in W
  # @param swh_temp_sch [OpenStudio::Model::Schedule] the service water heating schedule. If nil, will be defaulted.
  # @param set_peak_use_flowrate [Bool] if true, the peak flow rate and flow rate schedule will be set.
  # @param peak_flowrate [Double] in m^3/s
  # @param flowrate_schedule [String] name of the flow rate schedule
  # @param water_heater_thermal_zone [OpenStudio::Model::ThermalZone] zone to place water heater in.
  #   If nil, will be assumed in 70F air for heat loss.
  # @return [OpenStudio::Model::WaterHeaterMixed] the resulting water heater
  def model_add_heatpump_water_heater(model,
                                      type: 'PumpedCondenser',
                                      water_heater_capacity: 500,
                                      electric_backup_capacity: 4500,
                                      water_heater_volume: OpenStudio.convert(80.0, 'gal', 'm^3').get,
                                      service_water_temperature: OpenStudio.convert(125.0, 'F', 'C').get,
                                      parasitic_fuel_consumption_rate: 3.0,
                                      swh_temp_sch: nil,
                                      cop: 2.8,
                                      shr: 0.88,
                                      tank_ua: 3.9,
                                      set_peak_use_flowrate: false,
                                      peak_flowrate: 0.0,
                                      flowrate_schedule: nil,
                                      water_heater_thermal_zone: nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding heat pump water heater')

    # create heat pump water heater
    if type == 'WrappedCondenser'
      hpwh = OpenStudio::Model::WaterHeaterHeatPumpWrappedCondenser.new(model)
    elsif type == 'PumpedCondenser'
      hpwh = OpenStudio::Model::WaterHeaterHeatPump.new(model)
    end

    # calculate tank height and radius
    water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity, 'W', 'kBtu/hr').get
    hpwh_vol_gal = OpenStudio.convert(water_heater_volume, 'm^3', 'gal').get
    tank_height = 0.0188 * hpwh_vol_gal + 0.0935 # linear relationship that gets GE height at 50 gal and AO Smith height at 80 gal
    tank_radius = (0.9 * water_heater_volume / (Math::PI * tank_height))**0.5
    tank_surface_area = 2.0 * Math::PI * tank_radius * (tank_radius + tank_height)
    u_tank = (5.678 * tank_ua) / OpenStudio.convert(tank_surface_area, 'm^2', 'ft^2').get
    hpwh.setName("#{hpwh_vol_gal.round}gal Heat Pump Water Heater - #{water_heater_capacity_kbtu_per_hr.round(0)}kBtu/hr")

    if type == 'WrappedCondenser'
      hpwh.setMinimumInletAirTemperatureforCompressorOperation(OpenStudio.convert(45.0, 'F', 'C').get)
      hpwh.setMaximumInletAirTemperatureforCompressorOperation(OpenStudio.convert(120.0, 'F', 'C').get)
      # set sensor heights
      if hpwh_vol_gal <= 50.0
        hpwh.setDeadBandTemperatureDifference(0.5)
        h_ue = (1 - (3.5 / 12.0)) * tank_height # in the 4th node of the tank (counting from top)
        h_le = (1 - (10.5 / 12.0)) * tank_height # in the 11th node of the tank (counting from top)
        h_condtop = (1 - (5.5 / 12.0)) * tank_height # in the 6th node of the tank (counting from top)
        h_condbot = (1 - (10.99 / 12.0)) * tank_height # in the 11th node of the tank
        h_hpctrl = (1 - (2.5 / 12.0)) * tank_height # in the 3rd node of the tank
        hpwh.setControlSensor1HeightInStratifiedTank(h_hpctrl)
        hpwh.setControlSensor1Weight(1.0)
        hpwh.setControlSensor2HeightInStratifiedTank(h_hpctrl)
      else
        hpwh.setDeadBandTemperatureDifference(3.89)
        h_ue = (1 - (3.5 / 12.0)) * tank_height # in the 3rd node of the tank (counting from top)
        h_le = (1 - (9.5 / 12.0)) * tank_height # in the 10th node of the tank (counting from top)
        h_condtop = (1 - (5.5 / 12.0)) * tank_height # in the 6th node of the tank (counting from top)
        h_condbot = 0.01 # bottom node
        h_hpctrl_up = (1 - (2.5 / 12.0)) * tank_height # in the 3rd node of the tank
        h_hpctrl_low = (1 - (8.5 / 12.0)) * tank_height # in the 9th node of the tank
        hpwh.setControlSensor1HeightInStratifiedTank(h_hpctrl_up)
        hpwh.setControlSensor1Weight(0.75)
        hpwh.setControlSensor2HeightInStratifiedTank(h_hpctrl_low)
      end
      hpwh.setCondenserBottomLocation(h_condbot)
      hpwh.setCondenserTopLocation(h_condtop)
      hpwh.setTankElementControlLogic('MutuallyExclusive')
    elsif type == 'PumpedCondenser'
      hpwh.setDeadBandTemperatureDifference(3.89)
    end

    # set heat pump water heater properties
    hpwh.setEvaporatorAirFlowRate(OpenStudio.convert(181.0, 'ft^3/min', 'm^3/s').get)
    hpwh.setFanPlacement('DrawThrough')
    hpwh.setOnCycleParasiticElectricLoad(0.0)
    hpwh.setOffCycleParasiticElectricLoad(0.0)
    hpwh.setParasiticHeatRejectionLocation('Outdoors')

    # set temperature setpoint schedule
    if swh_temp_sch.nil?
      # temperature schedule type limits
      temp_sch_type_limits = model_add_schedule_type_limits(model,
                                                            name: 'Temperature Schedule Type Limits',
                                                            lower_limit_value: 0.0,
                                                            upper_limit_value: 100.0,
                                                            numeric_type: 'Continuous',
                                                            unit_type: 'Temperature')
      # service water heating loop controls
      swh_temp_c = service_water_temperature
      swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
      swh_delta_t_r = 9.0 # 9F delta-T
      swh_temp_c = OpenStudio.convert(swh_temp_f, 'F', 'C').get
      swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
      swh_temp_sch = model_add_constant_schedule_ruleset(model,
                                                         swh_temp_c,
                                                         name = "Heat Pump Water Heater Temp - #{swh_temp_f.round}F")
      swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
    end
    hpwh.setCompressorSetpointTemperatureSchedule(swh_temp_sch)

    # coil curves
    hpwh_cap = OpenStudio::Model::CurveBiquadratic.new(model)
    hpwh_cap.setName('HPWH-Cap-fT')
    hpwh_cap.setCoefficient1Constant(0.563)
    hpwh_cap.setCoefficient2x(0.0437)
    hpwh_cap.setCoefficient3xPOW2(0.000039)
    hpwh_cap.setCoefficient4y(0.0055)
    hpwh_cap.setCoefficient5yPOW2(-0.000148)
    hpwh_cap.setCoefficient6xTIMESY(-0.000145)
    hpwh_cap.setMinimumValueofx(0.0)
    hpwh_cap.setMaximumValueofx(100.0)
    hpwh_cap.setMinimumValueofy(0.0)
    hpwh_cap.setMaximumValueofy(100.0)

    hpwh_cop = OpenStudio::Model::CurveBiquadratic.new(model)
    hpwh_cop.setName('HPWH-COP-fT')
    hpwh_cop.setCoefficient1Constant(1.1332)
    hpwh_cop.setCoefficient2x(0.063)
    hpwh_cop.setCoefficient3xPOW2(-0.0000979)
    hpwh_cop.setCoefficient4y(-0.00972)
    hpwh_cop.setCoefficient5yPOW2(-0.0000214)
    hpwh_cop.setCoefficient6xTIMESY(-0.000686)
    hpwh_cop.setMinimumValueofx(0.0)
    hpwh_cop.setMaximumValueofx(100.0)
    hpwh_cop.setMinimumValueofy(0.0)
    hpwh_cop.setMaximumValueofy(100.0)

    # create DX coil object
    if type == 'WrappedCondenser'
      coil = hpwh.dXCoil.to_CoilWaterHeatingAirToWaterHeatPumpWrapped.get
      coil.setRatedCondenserWaterTemperature(48.89)
    elsif type == 'PumpedCondenser'
      coil = OpenStudio::Model::CoilWaterHeatingAirToWaterHeatPump.new(model)
      hpwh.setDXCoil(coil)
    end

    # set coil properties
    coil.setName("#{hpwh.name} Coil")
    coil.setRatedHeatingCapacity(water_heater_capacity * cop)
    coil.setRatedCOP(cop)
    coil.setRatedSensibleHeatRatio(shr)
    coil.setRatedEvaporatorInletAirDryBulbTemperature(OpenStudio.convert(67.5, 'F', 'C').get)
    coil.setRatedEvaporatorInletAirWetBulbTemperature(OpenStudio.convert(56.426, 'F', 'C').get)
    coil.setRatedEvaporatorAirFlowRate(OpenStudio.convert(181.0, 'ft^3/min', 'm^3/s').get)
    coil.setEvaporatorFanPowerIncludedinRatedCOP(true)
    coil.setEvaporatorAirTemperatureTypeforCurveObjects('WetBulbTemperature')
    coil.setHeatingCapacityFunctionofTemperatureCurve(hpwh_cap)
    coil.setHeatingCOPFunctionofTemperatureCurve(hpwh_cop)
    coil.setMaximumAmbientTemperatureforCrankcaseHeaterOperation(0.0)

    # set tank properties
    if type == 'WrappedCondenser'
      tank = hpwh.tank.to_WaterHeaterStratified.get
      tank.setTankHeight(tank_height)
      tank.setHeaterPriorityControl('MasterSlave')
      if hpwh_vol_gal <= 50.0
        tank.setHeater1DeadbandTemperatureDifference(25.0)
        tank.setHeater2DeadbandTemperatureDifference(30.0)
      else
        tank.setHeater1DeadbandTemperatureDifference(18.5)
        tank.setHeater2DeadbandTemperatureDifference(3.89)
      end
      hpwh_bottom_element_sp = OpenStudio::Model::ScheduleConstant.new(model)
      hpwh_bottom_element_sp.setName("#{hpwh.name} BottomElementSetpoint")
      hpwh_top_element_sp = OpenStudio::Model::ScheduleConstant.new(model)
      hpwh_top_element_sp.setName("#{hpwh.name} TopElementSetpoint")
      tank.setHeater1Capacity(electric_backup_capacity)
      tank.setHeater1Height(h_ue)
      tank.setHeater1SetpointTemperatureSchedule(hpwh_top_element_sp) # Overwritten later by EMS
      tank.setHeater2Capacity(electric_backup_capacity)
      tank.setHeater2Height(h_le)
      tank.setHeater2SetpointTemperatureSchedule(hpwh_bottom_element_sp)
      tank.setUniformSkinLossCoefficientperUnitAreatoAmbientTemperature(u_tank)
      tank.setNumberofNodes(12)
      tank.setAdditionalDestratificationConductivity(0)
      tank.setNode1AdditionalLossCoefficient(0)
      tank.setNode2AdditionalLossCoefficient(0)
      tank.setNode3AdditionalLossCoefficient(0)
      tank.setNode4AdditionalLossCoefficient(0)
      tank.setNode5AdditionalLossCoefficient(0)
      tank.setNode6AdditionalLossCoefficient(0)
      tank.setNode7AdditionalLossCoefficient(0)
      tank.setNode8AdditionalLossCoefficient(0)
      tank.setNode9AdditionalLossCoefficient(0)
      tank.setNode10AdditionalLossCoefficient(0)
      tank.setNode11AdditionalLossCoefficient(0)
      tank.setNode12AdditionalLossCoefficient(0)
      tank.setUseSideDesignFlowRate(0.9 * water_heater_volume / 60.1)
      tank.setSourceSideDesignFlowRate(0)
      tank.setSourceSideFlowControlMode('')
      tank.setSourceSideInletHeight(0)
      tank.setSourceSideOutletHeight(0)
    elsif type == 'PumpedCondenser'
      tank = OpenStudio::Model::WaterHeaterMixed.new(model)
      hpwh.setTank(tank)
      tank.setDeadbandTemperatureDifference(3.89)
      tank.setHeaterControlType('Cycle')
      tank.setHeaterMaximumCapacity(electric_backup_capacity)
    end
    tank.setName("#{hpwh.name} Tank")
    tank.setEndUseSubcategory('Service Hot Water')
    tank.setTankVolume(0.9 * water_heater_volume)
    tank.setMaximumTemperatureLimit(90.0)
    tank.setHeaterFuelType('Electricity')
    tank.setHeaterThermalEfficiency(1.0)
    tank.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
    tank.setOffCycleParasiticFuelType('Electricity')
    tank.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
    tank.setOnCycleParasiticFuelType('Electricity')

    # set fan properties
    fan = hpwh.fan.to_FanOnOff.get
    fan.setName("#{hpwh.name} Fan")
    fan_power = 0.0462 # watts per cfm
    if hpwh_vol_gal <= 50.0
      fan.setFanEfficiency(23.0 / fan_power * OpenStudio.convert(1.0, 'ft^3/min', 'm^3/s').get)
      fan.setPressureRise(23.0)
    else
      fan.setFanEfficiency(65.0 / fan_power * OpenStudio.convert(1.0, 'ft^3/min', 'm^3/s').get)
      fan.setPressureRise(65.0)
    end
    fan.setMaximumFlowRate(OpenStudio.convert(181.0, 'ft^3/min', 'm^3/s').get)
    fan.setMotorEfficiency(1.0)
    fan.setMotorInAirstreamFraction(1.0)
    fan.setEndUseSubcategory('Service Hot Water')

    if water_heater_thermal_zone.nil?
      # add in schedules for Tamb, RHamb, and the compressor
      # assume the water heater is indoors at 70F for now
      default_water_heater_ambient_temp_sch = model_add_constant_schedule_ruleset(model,
                                                                                  OpenStudio.convert(70.0, 'F', 'C').get,
                                                                                  name = 'Water Heater Ambient Temp Schedule - 70F')
      default_water_heater_ambient_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
      tank.setAmbientTemperatureIndicator('Schedule')
      tank.setAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
      tank.resetAmbientTemperatureThermalZone
      hpwh_rhamb = OpenStudio::Model::ScheduleConstant.new(model)
      hpwh_rhamb.setName("#{hpwh.name} Ambient Humidity Schedule")
      hpwh_rhamb.setValue(0.5)
      hpwh.setInletAirConfiguration('Schedule')
      hpwh.setInletAirTemperatureSchedule(default_water_heater_ambient_temp_sch)
      hpwh.setInletAirHumiditySchedule(hpwh_rhamb)
      hpwh.setCompressorLocation('Schedule')
      hpwh.setCompressorAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
    else
      hpwh.addToThermalZone(water_heater_thermal_zone)
      hpwh.setInletAirConfiguration('ZoneAirOnly')
      hpwh.setCompressorLocation('Zone')
      tank.setAmbientTemperatureIndicator('ThermalZone')
      tank.setAmbientTemperatureThermalZone(water_heater_thermal_zone)
      tank.resetAmbientTemperatureSchedule
    end

    if set_peak_use_flowrate
      rated_flow_rate_m3_per_s = peak_flowrate
      rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get
      tank.setPeakUseFlowRate(rated_flow_rate_m3_per_s)
      schedule = model_add_schedule(model, flowrate_schedule)
      tank.setUseFlowRateFractionSchedule(schedule)
    end

    return hpwh
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
  # @return [OpenStudio::Model::PlantLoop]
  # the resulting booster water loop.
  def model_add_swh_booster(model,
                            main_service_water_loop,
                            water_heater_capacity,
                            water_heater_volume,
                            water_heater_fuel,
                            booster_water_temperature,
                            parasitic_fuel_consumption_rate,
                            booster_water_heater_thermal_zone)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding booster water heater to #{main_service_water_loop.name}")

    # Booster water heating loop
    booster_service_water_loop = OpenStudio::Model::PlantLoop.new(model)
    booster_service_water_loop.setName('Service Water Loop')

    # Temperature schedule type limits
    temp_sch_type_limits = model_add_schedule_type_limits(model,
                                                          name: 'Temperature Schedule Type Limits',
                                                          lower_limit_value: 0.0,
                                                          upper_limit_value: 100.0,
                                                          numeric_type: 'Continuous',
                                                          unit_type: 'Temperature')

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
    swh_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    swh_pump.setName('Booster Water Loop Pump')
    swh_pump.setRatedPumpHead(0.0) # As if there is no circulation pump
    swh_pump.setRatedPowerConsumption(0.0) # As if there is no circulation pump
    swh_pump.setMotorEfficiency(1)
    swh_pump.setPumpControlType('Continuous')
    swh_pump.setMinimumFlowRate(0.0)
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
    water_heater.setDeadbandTemperatureDifference(2.0)
    water_heater.setEndUseSubcategory('Booster')

    if booster_water_heater_thermal_zone.nil?
      # Assume the water heater is indoors at 70F or 72F
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
          indoor_temp = 71.6
        else
          indoor_temp = 70.0
        end
      default_water_heater_ambient_temp_sch = model_add_constant_schedule_ruleset(model,
                                                                                  OpenStudio.convert(indoor_temp, 'F', 'C').get,
                                                                                  name = 'Water Heater Ambient Temp Schedule - ' + indoor_temp.to_s)
      default_water_heater_ambient_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
      water_heater.setAmbientTemperatureIndicator('Schedule')
      water_heater.setAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
      water_heater.resetAmbientTemperatureThermalZone
    else
      water_heater.setAmbientTemperatureIndicator('ThermalZone')
      water_heater.setAmbientTemperatureThermalZone(booster_water_heater_thermal_zone)
      water_heater.resetAmbientTemperatureSchedule
    end

    water_heater.setMaximumTemperatureLimit(swh_temp_c)
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
    elsif water_heater_fuel == 'Natural Gas' || water_heater_fuel == 'NaturalGas'
      water_heater.setHeaterFuelType('Gas')
      water_heater.setHeaterThermalEfficiency(0.8)
      water_heater.setOffCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOnCycleParasiticFuelConsumptionRate(parasitic_fuel_consumption_rate)
      water_heater.setOffCycleParasiticFuelType('Gas')
      water_heater.setOnCycleParasiticFuelType('Gas')
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(6.0)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(6.0)
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

    # Add a plant component temperature source to the demand outlet
    # of the HX to represent the fact that the water used by the booster
    # would in reality be at the mains temperature.
    mains_src = OpenStudio::Model::PlantComponentTemperatureSource.new(model)
    mains_src.setName('Mains Water Makeup for SWH Booster')
    mains_src.addToNode(hx.demandOutletModelObject.get.to_Node.get)

    # Mains water temperature sensor
    mains_water_temp_sen = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Mains Water Temperature')
    mains_water_temp_sen.setName('Mains_Water_Temp_Sen')
    mains_water_temp_sen.setKeyName('Environment')

    # Schedule to actuate
    water_mains_temp_sch = OpenStudio::Model::ScheduleConstant.new(model)
    water_mains_temp_sch.setName('Mains Water Temperature')
    water_mains_temp_sch.setValue(OpenStudio.convert(50, 'F', 'C').get)

    # Actuator for mains water temperature schedule
    mains_water_temp_sch_act = OpenStudio::Model::EnergyManagementSystemActuator.new(water_mains_temp_sch, 'Schedule:Constant', 'Schedule Value')
    mains_water_temp_sch_act.setName('Mains_Water_Temp_Act')

    # Program
    mains_prg = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    mains_prg.setName('Mains_Water_Prg')
    mains_prg_body = "SET #{mains_water_temp_sch_act.handle} = #{mains_water_temp_sen.handle}"
    mains_prg.setBody(mains_prg_body)

    # Program Calling Manager
    mains_mgr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    mains_mgr.setName('Mains_Water_Prg_Mgr')
    mains_mgr.setCallingPoint('BeginTimestepBeforePredictor')
    mains_mgr.addProgram(mains_prg)

    # Make the plant component use the actuated schedule
    mains_src.setTemperatureSpecificationType('Scheduled')
    mains_src.setSourceTemperatureSchedule(water_mains_temp_sch)

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
  # @return [OpenStudio::Model::WaterUseEquipment]
  # the resulting water fixture.
  def model_add_swh_end_uses(model,
                             use_name,
                             swh_loop,
                             peak_flowrate,
                             flowrate_schedule,
                             water_use_temperature,
                             space_name,
                             frac_sensible: 0.2,
                             frac_latent: 0.05)
    # Water use connection
    swh_connection = OpenStudio::Model::WaterUseConnections.new(model)

    # Water fixture definition
    water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
    rated_flow_rate_m3_per_s = peak_flowrate
    rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get

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
    water_fixture_def.setName("#{use_name} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gpm")
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
      water_fixture.setName("#{use_name} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gpm at #{mixed_water_temp_f.round}F")
      swh_connection.setName("#{use_name} WUC #{rated_flow_rate_gal_per_min.round(2)}gpm at #{mixed_water_temp_f.round}F")
    else
      water_fixture.setName("#{space_name} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gpm at #{mixed_water_temp_f.round}F")
      swh_connection.setName("#{space_name} WUC #{rated_flow_rate_gal_per_min.round(2)}gpm at #{mixed_water_temp_f.round}F")
    end

    unless space_name.nil?
      space = model.getSpaceByName(space_name)
      space = space.get
      water_fixture.setSpace(space)
    end

    swh_connection.addWaterUseEquipment(water_fixture)

    # Connect the water use connection to the SWH loop
    unless swh_loop.nil?
      swh_loop.addDemandBranchForComponent(swh_connection)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding water fixture to #{swh_loop.name}.")
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{water_fixture.name}.")

    return water_fixture
  end

  # This method will add a swh water fixture to the model for the space.
  # It will return a water fixture object, or NIL if there is no water load at all.
  #
  # Adds a WaterUseEquipment object representing the SWH loads of the supplied Space.
  # Attaches this WaterUseEquipment to the supplied PlantLoop via a new WaterUseConnections object.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param swh_loop [OpenStudio::Model::PlantLoop] the SWH loop to connect the WaterUseEquipment to
  # @space [OpenStudio::Model::Space] the Space to add a WaterUseEquipment for
  # @space_multiplier [Double] the multiplier to use if the supplied Space actually represents
  #   more area than is shown in the model.
  # @param is_flow_per_area [Bool] if true, use the value in the 'service_water_heating_peak_flow_per_area'
  #   field of the space_types JSON.  If false, use the value in the 'service_water_heating_peak_flow_rate' field.
  # @return [OpenStudio::Model::WaterUseEquipment] the WaterUseEquipment for the
  def model_add_swh_end_uses_by_space(model,
                                      swh_loop,
                                      space,
                                      space_multiplier = 1.0,
                                      is_flow_per_area = true)
    # SpaceType
    if space.spaceType.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Space #{space.name} does not have a Space Type assigned, cannot add SWH end uses.")
      return nil
    end
    space_type = space.spaceType.get

    # Standards Building Type
    if space_type.standardsBuildingType.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Space #{space.name}'s Space Type does not have a Standards Building Type assigned, cannot add SWH end uses.")
      return nil
    end
    stds_bldg_type = space_type.standardsBuildingType.get
    building_type = model_get_lookup_name(stds_bldg_type)

    # Standards Space Type
    if space_type.standardsSpaceType.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Space #{space.name}'s Space Type does not have a Standards Space Type assigned, cannot add SWH end uses.")
      return nil
    end
    stds_spc_type = space_type.standardsSpaceType.get

    # find the specific space_type properties from standard.json
    search_criteria = {
      'template' => template,
      'building_type' => building_type,
      'space_type' => stds_spc_type
    }
    data = standards_lookup_table_first(table_name: 'space_types', search_criteria: search_criteria)
    if data.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Could not find space type for: #{search_criteria}.")
      return nil
    end
    space_area = OpenStudio.convert(space.floorArea, 'm^2', 'ft^2').get # ft2

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
    water_fixture_def.setName("#{space.name.get} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gpm")
    # Target mixed water temperature
    mixed_water_temp_f = data['service_water_heating_target_temperature']
    mixed_water_temp_c = OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get
    mixed_water_temp_sch = model_add_constant_schedule_ruleset(model,
                                                               mixed_water_temp_c,
                                                               name = "Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F")
    water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

    # Water use equipment
    water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
    schedule = model_add_schedule(model, data['service_water_heating_schedule'])
    water_fixture.setFlowRateFractionSchedule(schedule)
    water_fixture.setName("#{space.name.get} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gpm")
    swh_connection.addWaterUseEquipment(water_fixture)
    # Assign water fixture to a space
    water_fixture.setSpace(space) if model_attach_water_fixtures_to_spaces?(model)

    # Connect the water use connection to the SWH loop
    swh_loop.addDemandBranchForComponent(swh_connection)
    return water_fixture
  end

  # Determine whether or not water fixtures are attached to spaces
  def model_attach_water_fixtures_to_spaces?(model)
    # TODO: For hotels and apartments, add the water fixture at the space level
    # if building_type!=nil && ((building_type.downcase.include?"hotel") || (building_type.downcase.include?"apartment"))
    #   return true
    # end
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
  # @return [OpenStudio::Model::WaterUseEquipment]
  # the resulting water fixture.
  def model_add_booster_swh_end_uses(model,
                                     swh_booster_loop,
                                     peak_flowrate,
                                     flowrate_schedule,
                                     water_use_temperature)

    # Water use connection
    swh_connection = OpenStudio::Model::WaterUseConnections.new(model)

    # Water fixture definition
    water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)
    rated_flow_rate_m3_per_s = peak_flowrate
    rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get
    water_fixture_def.setName("Booster Water Fixture Def - #{rated_flow_rate_gal_per_min.round(2)} gpm")
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    # Target mixed water temperature
    mixed_water_temp_f = OpenStudio.convert(water_use_temperature, 'C', 'F').get
    mixed_water_temp_sch = model_add_constant_schedule_ruleset(model,
                                                               OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get,
                                                               name = "Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F")
    water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

    # Water use equipment
    water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
    water_fixture.setName("Booster Water Fixture - #{rated_flow_rate_gal_per_min.round(2)} gpm at #{mixed_water_temp_f.round}F")
    schedule = model_add_schedule(model, flowrate_schedule)
    water_fixture.setFlowRateFractionSchedule(schedule)
    swh_connection.addWaterUseEquipment(water_fixture)

    # Connect the water use connection to the SWH loop
    unless swh_booster_loop.nil?
      swh_booster_loop.addDemandBranchForComponent(swh_connection)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding water fixture to #{swh_booster_loop.name}.")
    end

    return water_fixture
  end

  # Adds insulated 0.75in copper piping to the model.
  # For circulating systems, assume length of piping is proportional
  # to the area and number of stories in the building.
  # For non-circulating systems, assume that the water heaters
  # are close to the point of use.
  # Assume that piping is located in a zone
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param swh_loop [OpenStudio::Model::PlantLoop] the service water heating loop
  # @param floor_area_served [Double] the area of building served by the service water heating loop, in m^2
  # @param number_of_stories [Integer] the number of stories served by the service water heating loop
  # @param pipe_insulation_thickness [Double] the thickness of the pipe insulation, in m.  Use 0 for no insulation
  # @param circulating [Bool] use true for circulating systems, false for non-circulating systems
  # @param air_temp_surrounding_piping [Double] the temperature of the air surrounding the piping, in C.
  def model_add_piping_losses_to_swh_system(model,
                                            swh_loop,
                                            circulating,
                                            pipe_insulation_thickness: 0,
                                            floor_area_served: 465,
                                            number_of_stories: 1,
                                            air_temp_surrounding_piping: 21.1111)

    # Estimate pipe length
    if circulating
      # For circulating systems, get pipe length based on the size of the building.
      # Formula from A.3.1 PrototypeModelEnhancements_2014_0.pdf
      floor_area_ft2 = OpenStudio.convert(floor_area_served, 'm^2', 'ft^2').get
      pipe_length_ft = 2.0 * (Math.sqrt(floor_area_ft2 / number_of_stories) + (10.0 * (number_of_stories - 1.0)))
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Pipe length #{pipe_length_ft.round}ft = 2.0 * ( (#{floor_area_ft2.round}ft2 / #{number_of_stories} stories)^0.5 + (10.0ft * (#{number_of_stories} stories - 1.0) ) )")
    else
      # For non-circulating systems, assume water heater is close to point of use
      pipe_length_ft = 20.0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Pipe length #{pipe_length_ft.round}ft. For non-circulating systems, assume water heater is close to point of use.")
    end

    # For systems whose water heater object represents multiple pieces
    # of equipment, multiply the piping length by the number of pieces of equipment.
    swh_loop.supplyComponents('OS_WaterHeater_Mixed'.to_IddObjectType).each do |sc|
      next unless sc.to_WaterHeaterMixed.is_initialized

      water_heater = sc.to_WaterHeaterMixed.get
      comp_qty = water_heater.component_quantity
      if comp_qty > 1
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Piping length has been multiplied by #{comp_qty}X because #{water_heater.name} represents #{comp_qty} pieces of equipment.")
        pipe_length_ft *= comp_qty
        break
      end
    end

    # Service water heating piping heat loss scheduled air temperature
    swh_piping_air_temp_c = air_temp_surrounding_piping
    swh_piping_air_temp_f = OpenStudio.convert(swh_piping_air_temp_c, 'C', 'F').get
    swh_piping_air_temp_sch = model_add_constant_schedule_ruleset(model,
                                                                  swh_piping_air_temp_c,
                                                                  name = "#{swh_loop.name} Piping Air Temp - #{swh_piping_air_temp_f.round}F")

    # Service water heating piping heat loss scheduled air velocity
    swh_piping_air_velocity_m_per_s = 0.3
    swh_piping_air_velocity_mph = OpenStudio.convert(swh_piping_air_velocity_m_per_s, 'm/s', 'mile/hr').get
    swh_piping_air_velocity_sch = model_add_constant_schedule_ruleset(model,
                                                                      swh_piping_air_velocity_m_per_s,
                                                                      name = "#{swh_loop.name} Piping Air Velocity - #{swh_piping_air_velocity_mph.round(2)}mph")

    # Material for 3/4in type L (heavy duty) copper pipe
    copper_pipe = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    copper_pipe.setName('Copper pipe 0.75in type L')
    copper_pipe.setRoughness('Smooth')
    copper_pipe.setThickness(OpenStudio.convert(0.045, 'in', 'm').get)
    copper_pipe.setThermalConductivity(386.0)
    copper_pipe.setDensity(OpenStudio.convert(556, 'lb/ft^3', 'kg/m^3').get)
    copper_pipe.setSpecificHeat(OpenStudio.convert(0.092, 'Btu/lb*R', 'J/kg*K').get)
    copper_pipe.setThermalAbsorptance(0.9) # TODO: find reference for property
    copper_pipe.setSolarAbsorptance(0.7) # TODO: find reference for property
    copper_pipe.setVisibleAbsorptance(0.7) # TODO: find reference for property

    # Construction for pipe
    pipe_construction = OpenStudio::Model::Construction.new(model)

    # Add insulation material to insulated pipe
    if pipe_insulation_thickness > 0
      # Material for fiberglass insulation
      # R-value from Owens-Corning 1/2in fiberglass pipe insulation
      # https://www.grainger.com/product/OWENS-CORNING-1-2-Thick-40PP22
      # but modified until simulated heat loss = 17.7 Btu/hr/ft of pipe with 140F water and 70F air
      pipe_insulation_thickness_in = OpenStudio.convert(pipe_insulation_thickness, 'm', 'in').get
      insulation = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      insulation.setName("Fiberglass batt #{pipe_insulation_thickness_in.round(2)}in")
      insulation.setRoughness('Smooth')
      insulation.setThickness(OpenStudio.convert(pipe_insulation_thickness_in, 'in', 'm').get)
      insulation.setThermalConductivity(OpenStudio.convert(0.46, 'Btu*in/hr*ft^2*R', 'W/m*K').get)
      insulation.setDensity(OpenStudio.convert(0.7, 'lb/ft^3', 'kg/m^3').get)
      insulation.setSpecificHeat(OpenStudio.convert(0.2, 'Btu/lb*R', 'J/kg*K').get)
      insulation.setThermalAbsorptance(0.9) # Irrelevant for Pipe:Indoor; no radiation model is used
      insulation.setSolarAbsorptance(0.7) # Irrelevant for Pipe:Indoor; no radiation model is used
      insulation.setVisibleAbsorptance(0.7) # Irrelevant for Pipe:Indoor; no radiation model is used

      pipe_construction.setName("Copper pipe 0.75in type L with #{pipe_insulation_thickness_in.round(2)}in fiberglass batt")
      pipe_construction.setLayers([insulation, copper_pipe])
    else
      pipe_construction.setName('Uninsulated copper pipe 0.75in type L')
      pipe_construction.setLayers([copper_pipe])
    end

    heat_loss_pipe = OpenStudio::Model::PipeIndoor.new(model)
    heat_loss_pipe.setName("#{swh_loop.name} Pipe #{pipe_length_ft}ft")
    heat_loss_pipe.setEnvironmentType('Schedule')
    # heat_loss_pipe.setAmbientTemperatureSchedule(swh_piping_air_temp_sch) # TODO: schedule type registry error for this setter
    heat_loss_pipe.setPointer(7, swh_piping_air_temp_sch.handle)
    # heat_loss_pipe.setAmbientAirVelocitySchedule(model.alwaysOffDiscreteSchedule) # TODO: schedule type registry error for this setter
    heat_loss_pipe.setPointer(8, swh_piping_air_velocity_sch.handle)
    heat_loss_pipe.setConstruction(pipe_construction)
    heat_loss_pipe.setPipeInsideDiameter(OpenStudio.convert(0.785, 'in', 'm').get)
    heat_loss_pipe.setPipeLength(OpenStudio.convert(pipe_length_ft, 'ft', 'm').get)

    heat_loss_pipe.addToNode(swh_loop.demandInletNode)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{pipe_length_ft.round}ft of #{pipe_construction.name} losing heat to #{swh_piping_air_temp_f.round}F air to #{swh_loop.name}.")
    return true
  end
end

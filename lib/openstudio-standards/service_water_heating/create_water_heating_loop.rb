module OpenstudioStandards
  # The ServiceWaterHeating module provides methods to create, modify, and get information about service water heating
  module ServiceWaterHeating
    # @!group Create Loop
    # Methods to add service water heating loops

    # Creates a booster water heater on its own loop and attaches it to the main service water heating loop.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param water_heater_capacity [Double] water heater capacity, in W. Defaults to 8 kW / 27.283 kBtu/hr
    # @param water_heater_volume [Double] water heater volume, in m^3. Defaults to 0.0227 m^3 / 6 gal
    # @param water_heater_fuel [String] water heating fuel. Valid choices are 'NaturalGas', 'Electricity'.
    # @param on_cycle_parasitic_fuel_consumption_rate [Double] water heater on cycle parasitic fuel consumption rate, in W
    # @param off_cycle_parasitic_fuel_consumption_rate [Double] water heater off cycle parasitic fuel consumption rate, in W
    # @param service_water_temperature [Double] water heater temperature, in degrees C. Default is 82.2 C / 180 F.
    # @param service_water_temperature_schedule [OpenStudio::Model::Schedule] the service water heating schedule.
    #   If nil, will be defaulted to a constant temperature schedule based on the service_water_temperature
    # @param water_heater_thermal_zone [OpenStudio::Model::ThermalZone] Thermal zone for ambient heat loss.
    #   If nil, will assume 71.6 F / 22 C ambient air temperature.
    # @param service_water_loop [OpenStudio::Model::PlantLoop] if provided, add the water heater to this loop
    # @return [OpenStudio::Model::PlantLoop] The booster water loop OpenStudio PlantLoop object
    def self.create_booster_water_heating_loop(model,
                                               water_heater_capacity: 8000.0,
                                               water_heater_volume: OpenStudio.convert(6.0, 'gal', 'm^3').get,
                                               water_heater_fuel: 'Electricity',
                                               on_cycle_parasitic_fuel_consumption_rate: 0.0,
                                               off_cycle_parasitic_fuel_consumption_rate: 0.0,
                                               service_water_temperature: 82.2,
                                               service_water_temperature_schedule: nil,
                                               water_heater_thermal_zone: nil,
                                               service_water_loop: nil)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding booster water heater to #{service_water_loop.name}")

      water_heater_volume_gal = OpenStudio.convert(water_heater_volume, 'm^3', 'gal').get
      water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity, 'W', 'kBtu/hr').get

      # Booster water heating loop
      booster_service_water_loop = OpenStudio::Model::PlantLoop.new(model)
      booster_service_water_loop.setName('Booster Service Water Loop')

      # create and add booster water heater to loop
      booster_water_heater = OpenstudioStandards::ServiceWaterHeating.create_water_heater(model,
                                                                                          water_heater_capacity: water_heater_capacity,
                                                                                          water_heater_volume: water_heater_volume,
                                                                                          water_heater_fuel: water_heater_fuel,
                                                                                          on_cycle_parasitic_fuel_consumption_rate: on_cycle_parasitic_fuel_consumption_rate,
                                                                                          off_cycle_parasitic_fuel_consumption_rate: off_cycle_parasitic_fuel_consumption_rate,
                                                                                          service_water_temperature: service_water_temperature,
                                                                                          service_water_temperature_schedule: service_water_temperature_schedule,
                                                                                          water_heater_thermal_zone: water_heater_thermal_zone,
                                                                                          service_water_loop: booster_service_water_loop)
      booster_water_heater.setName("#{water_heater_volume_gal}gal #{water_heater_fuel} Booster Water Heater - #{water_heater_capacity_kbtu_per_hr.round}kBtu/hr")
      booster_water_heater.setEndUseSubcategory('Booster')

      # Temperature schedule type limits
      temp_sch_type_limits = OpenstudioStandards::Schedules.create_schedule_type_limits(model,
                                                                                        name: 'Temperature Schedule Type Limits',
                                                                                        lower_limit_value: 0.0,
                                                                                        upper_limit_value: 100.0,
                                                                                        numeric_type: 'Continuous',
                                                                                        unit_type: 'Temperature')

      # Service water heating loop controls
      swh_temp_f = OpenStudio.convert(service_water_temperature, 'C', 'F').get
      swh_delta_t_r = 9 # 9F delta-T
      swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
      swh_temp_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                     service_water_temperature,
                                                                                     name: "Service Water Booster Temp - #{swh_temp_f.round(0)}F",
                                                                                     schedule_type_limit: 'Temperature')
      swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
      swh_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, swh_temp_sch)
      swh_stpt_manager.setName('Hot water booster setpoint manager')
      swh_stpt_manager.addToNode(booster_service_water_loop.supplyOutletNode)
      sizing_plant = booster_service_water_loop.sizingPlant
      sizing_plant.setLoopType('Heating')
      sizing_plant.setDesignLoopExitTemperature(service_water_temperature)
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

      # Heat exchanger to supply the booster water heater with normal hot water from the main service water loop
      hx = OpenStudio::Model::HeatExchangerFluidToFluid.new(model)
      hx.setName('Booster Water Heating Heat Exchanger')
      hx.setHeatExchangeModelType('Ideal')
      hx.setControlType('UncontrolledOn')
      hx.setHeatTransferMeteringEndUseType('LoopToLoop')

      # Add the HX to the supply side of the booster loop
      hx.addToNode(booster_service_water_loop.supplyInletNode)

      # Add the HX to the demand side of the main service water loop
      service_water_loop.addDemandBranchForComponent(hx)

      # Add a plant component temperature source to the demand outlet
      # of the HX to represent the fact that the water used by the booster
      # would in reality be at the mains temperature.
      mains_src = OpenStudio::Model::PlantComponentTemperatureSource.new(model)
      mains_src.setName('Mains Water Makeup for SWH Booster')
      mains_src.addToNode(hx.demandOutletModelObject.get.to_Node.get)

      # use the site water mains temperature schedule if available,
      # otherwise use the annual average outdoor air temperature
      site_water_mains = model.getSiteWaterMainsTemperature
      if site_water_mains.temperatureSchedule.is_initialized
        water_mains_temp_sch = site_water_mains.temperatureSchedule.get
      elsif site_water_mains.annualAverageOutdoorAirTemperature.is_initialized
        mains_src_temp_c = site_water_mains.annualAverageOutdoorAirTemperature.get
        mains_src.setSourceTemperature(mains_src_temp_c)
        water_mains_temp_sch = OpenStudio::Model::ScheduleConstant.new(model)
        water_mains_temp_sch.setName('Booster Water Makeup Temperature')
        water_mains_temp_sch.setValue(mains_src_temp_c)
      else # assume 50F
        mains_src_temp_c = OpenStudio.convert(50.0, 'F', 'C').get
        mains_src.setSourceTemperature(mains_src_temp_c)
        water_mains_temp_sch = OpenStudio::Model::ScheduleConstant.new(model)
        water_mains_temp_sch.setName('Booster Water Makeup Temperature')
        water_mains_temp_sch.setValue(mains_src_temp_c)
      end
      mains_src.setTemperatureSpecificationType('Scheduled')
      mains_src.setSourceTemperatureSchedule(water_mains_temp_sch)

      return booster_service_water_loop
    end

    # @!endgroup Create Loop
  end
end

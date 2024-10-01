class Standard
  # @!group ServiceWaterHeating

  # Creates a service water heating loop.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
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
  # @param add_pipe_losses [Boolean] if true, add piping and associated heat losses to system.  If false, add no pipe heat losses
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
    temp_sch_type_limits = OpenstudioStandards::Schedules.create_schedule_type_limits(model,
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
    swh_temp_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                   swh_temp_c,
                                                                                   name: "Service Water Loop Temp - #{swh_temp_f.round}F",
                                                                                   schedule_type_limit: 'Temperature')
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

    water_heater = OpenstudioStandards::ServiceWaterHeating.create_water_heater(model,
                                                                                water_heater_capacity: water_heater_capacity,
                                                                                water_heater_volume: water_heater_volume,
                                                                                water_heater_fuel: water_heater_fuel,
                                                                                on_cycle_parasitic_fuel_consumption_rate: parasitic_fuel_consumption_rate,
                                                                                off_cycle_parasitic_fuel_consumption_rate: parasitic_fuel_consumption_rate,
                                                                                service_water_temperature: service_water_temperature,
                                                                                service_water_temperature_schedule: swh_temp_sch,
                                                                                set_peak_use_flowrate: false,
                                                                                peak_flowrate: 0.0,
                                                                                flowrate_schedule: nil,
                                                                                water_heater_thermal_zone: water_heater_thermal_zone,
                                                                                number_water_heaters: number_water_heaters)
    service_water_loop.addSupplyBranchForComponent(water_heater)

    # Pipe losses
    if add_pipe_losses
      OpenstudioStandards::ServiceWaterHeating.create_service_water_heating_piping_losses(model,
                                                                                          service_water_loop,
                                                                                          circulating: circulating,
                                                                                          pipe_insulation_thickness: pipe_insulation_thickness,
                                                                                          floor_area: floor_area_served,
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

  # This method will add a swh water fixture to the model for the space.
  # It will return a water fixture object, or NIL if there is no water load at all.
  #
  # Adds a WaterUseEquipment object representing the SWH loads of the supplied Space.
  # Attaches this WaterUseEquipment to the supplied PlantLoop via a new WaterUseConnections object.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param swh_loop [OpenStudio::Model::PlantLoop] the SWH loop to connect the WaterUseEquipment to
  # @param space [OpenStudio::Model::Space] the Space to add a WaterUseEquipment for
  # @param is_flow_per_area [Boolean] if true, use the value in the 'service_water_heating_peak_flow_per_area'
  #   field of the space_types JSON.  If false, use the value in the 'service_water_heating_peak_flow_rate' field.
  # @return [OpenStudio::Model::WaterUseEquipment] the WaterUseEquipment for the
  def model_add_swh_end_uses_by_space(model,
                                      swh_loop,
                                      space,
                                      is_flow_per_area: true)
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
    if data['service_water_heating_peak_flow_per_area'].to_f < 0.00001 && data['service_water_heating_peak_flow_rate'].to_f < 0.00001
      return nil
    end

    # rated flow rate
    rated_flow_rate_per_area = data['service_water_heating_peak_flow_per_area'].to_f # gal/h.ft2
    rated_flow_rate_gal_per_hour = if is_flow_per_area
                                     rated_flow_rate_per_area * space_area * space.multiplier # gal/h
                                   else
                                     data['service_water_heating_peak_flow_rate'].to_f
                                   end
    rated_flow_rate_gal_per_min = rated_flow_rate_gal_per_hour / 60 # gal/h to gal/min
    rated_flow_rate_m3_per_s = OpenStudio.convert(rated_flow_rate_gal_per_min, 'gal/min', 'm^3/s').get

    # target mixed water temperature
    mixed_water_temp_f = data['service_water_heating_target_temperature']
    mixed_water_temp_c = OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get

    # flow rate fraction schedule
    flow_rate_fraction_schedule = model_add_schedule(model, data['service_water_heating_schedule'])

    # create water use
    water_fixture = OpenstudioStandards::ServiceWaterHeating.create_water_use(model,
                                                                              name: "#{space.name}",
                                                                              flow_rate: rated_flow_rate_m3_per_s,
                                                                              flow_rate_fraction_schedule: flow_rate_fraction_schedule,
                                                                              water_use_temperature: mixed_water_temp_c,
                                                                              service_water_loop: swh_loop)

    return water_fixture
  end
end

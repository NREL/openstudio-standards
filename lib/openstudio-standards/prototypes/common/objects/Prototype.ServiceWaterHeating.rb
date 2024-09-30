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

  # Creates water fixtures and attaches them
  # to the supplied service water loop.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
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

    water_use_sensible_frac_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                                  frac_sensible,
                                                                                                  name: "Fraction Sensible - #{frac_sensible}",
                                                                                                  schedule_type_limit: 'Fractional')
    water_use_latent_frac_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                                frac_latent,
                                                                                                name: "Fraction Latent - #{frac_latent}",
                                                                                                schedule_type_limit: 'Fractional')
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    water_fixture_def.setName("#{use_name} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gpm")
    # Target mixed water temperature
    mixed_water_temp_f = OpenStudio.convert(water_use_temperature, 'C', 'F').get
    mixed_water_temp_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                           OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get,
                                                                                           name: "Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F",
                                                                                           schedule_type_limit: 'Temperature')
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
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param swh_loop [OpenStudio::Model::PlantLoop] the SWH loop to connect the WaterUseEquipment to
  # @param space [OpenStudio::Model::Space] the Space to add a WaterUseEquipment for
  # @param space_multiplier [Double] the multiplier to use if the supplied Space actually represents
  #   more area than is shown in the model.
  # @param is_flow_per_area [Boolean] if true, use the value in the 'service_water_heating_peak_flow_per_area'
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
    if data['service_water_heating_peak_flow_per_area'].to_f < 0.00001 && data['service_water_heating_peak_flow_rate'].to_f < 0.00001
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
    water_use_sensible_frac_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                                  0.2,
                                                                                                  name: 'Fraction Sensible - 0.2',
                                                                                                  schedule_type_limit: 'Fractional')
    water_use_latent_frac_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                                0.05,
                                                                                                name: 'Fraction Latent - 0.05',
                                                                                                schedule_type_limit: 'Fractional')
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    water_fixture_def.setName("#{space.name.get} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gpm")
    # Target mixed water temperature
    mixed_water_temp_f = data['service_water_heating_target_temperature']
    mixed_water_temp_c = OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get
    mixed_water_temp_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                           mixed_water_temp_c,
                                                                                           name: "Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F",
                                                                                           schedule_type_limit: 'Temperature')
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
  # @todo For hotels and apartments, add the water fixture at the space level
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] returns true if successful, false if not
  def model_attach_water_fixtures_to_spaces?(model)
    # if building_type!=nil && ((building_type.downcase.include?"hotel") || (building_type.downcase.include?"apartment"))
    #   return true
    # end
    return false
  end

  # Creates water fixtures and attaches them to the supplied booster water loop.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param swh_booster_loop [OpenStudio::Model::PlantLoop]
  # the booster water loop to add water fixtures to.
  # @param peak_flowrate [Double] in m^3/s
  # @param flowrate_schedule [String] name of the flow rate schedule
  # @param water_use_temperature [Double] mixed water use temperature, in C
  # @return [OpenStudio::Model::WaterUseEquipment] the resulting water fixture
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
    mixed_water_temp_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                           OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get,
                                                                                           name: "Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F",
                                                                                           schedule_type_limit: 'Temperature')
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
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param swh_loop [OpenStudio::Model::PlantLoop] the service water heating loop
  # @param floor_area_served [Double] the area of building served by the service water heating loop, in m^2
  # @param number_of_stories [Integer] the number of stories served by the service water heating loop
  # @param pipe_insulation_thickness [Double] the thickness of the pipe insulation, in m.  Use 0 for no insulation
  # @param circulating [Boolean] use true for circulating systems, false for non-circulating systems
  # @param air_temp_surrounding_piping [Double] the temperature of the air surrounding the piping, in C.
  # @return [Boolean] returns true if successful, false if not
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

      # get number of water heaters
      if water_heater.additionalProperties.getFeatureAsInteger('component_quantity').is_initialized
        comp_qty = water_heater.additionalProperties.getFeatureAsInteger('component_quantity').get
      else
        comp_qty = 1
      end

      if comp_qty > 1
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Piping length has been multiplied by #{comp_qty}X because #{water_heater.name} represents #{comp_qty} pieces of equipment.")
        pipe_length_ft *= comp_qty
        break
      end
    end

    # Service water heating piping heat loss scheduled air temperature
    swh_piping_air_temp_c = air_temp_surrounding_piping
    swh_piping_air_temp_f = OpenStudio.convert(swh_piping_air_temp_c, 'C', 'F').get
    swh_piping_air_temp_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                              swh_piping_air_temp_c,
                                                                                              name: "#{swh_loop.name} Piping Air Temp - #{swh_piping_air_temp_f.round}F",
                                                                                              schedule_type_limit: 'Temperature')

    # Service water heating piping heat loss scheduled air velocity
    swh_piping_air_velocity_m_per_s = 0.3
    swh_piping_air_velocity_mph = OpenStudio.convert(swh_piping_air_velocity_m_per_s, 'm/s', 'mile/hr').get
    swh_piping_air_velocity_sch = OpenstudioStandards::Schedules.create_constant_schedule_ruleset(model,
                                                                                                  swh_piping_air_velocity_m_per_s,
                                                                                                  name: "#{swh_loop.name} Piping Air Velocity - #{swh_piping_air_velocity_mph.round(2)}mph",
                                                                                                  schedule_type_limit: 'Dimensionless')

    # Material for 3/4in type L (heavy duty) copper pipe
    copper_pipe = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    copper_pipe.setName('Copper pipe 0.75in type L')
    copper_pipe.setRoughness('Smooth')
    copper_pipe.setThickness(OpenStudio.convert(0.045, 'in', 'm').get)
    copper_pipe.setThermalConductivity(386.0)
    copper_pipe.setDensity(OpenStudio.convert(556, 'lb/ft^3', 'kg/m^3').get)
    copper_pipe.setSpecificHeat(OpenStudio.convert(0.092, 'Btu/lb*R', 'J/kg*K').get)
    copper_pipe.setThermalAbsorptance(0.9) # @todo find reference for property
    copper_pipe.setSolarAbsorptance(0.7) # @todo find reference for property
    copper_pipe.setVisibleAbsorptance(0.7) # @todo find reference for property

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
    # @todoschedule type registry error for this setter
    # heat_loss_pipe.setAmbientTemperatureSchedule(swh_piping_air_temp_sch)
    heat_loss_pipe.setPointer(7, swh_piping_air_temp_sch.handle)
    # @todo schedule type registry error for this setter
    # heat_loss_pipe.setAmbientAirVelocitySchedule(model.alwaysOffDiscreteSchedule)
    heat_loss_pipe.setPointer(8, swh_piping_air_velocity_sch.handle)
    heat_loss_pipe.setConstruction(pipe_construction)
    heat_loss_pipe.setPipeInsideDiameter(OpenStudio.convert(0.785, 'in', 'm').get)
    heat_loss_pipe.setPipeLength(OpenStudio.convert(pipe_length_ft, 'ft', 'm').get)

    heat_loss_pipe.addToNode(swh_loop.demandInletNode)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added #{pipe_length_ft.round}ft of #{pipe_construction.name} losing heat to #{swh_piping_air_temp_f.round}F air to #{swh_loop.name}.")
    return true
  end
end

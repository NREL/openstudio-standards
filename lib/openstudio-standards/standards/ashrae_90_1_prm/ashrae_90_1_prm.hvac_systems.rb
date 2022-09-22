class ASHRAE901PRM < Standard
  DESIGN_CHILLED_WATER_TEMPERATURE = 44 # Loop design chilled water temperature (F)
  DESIGN_CHILLED_WATER_TEMPERATURE_DELTA = 10.1 # Loop design chilled water temperature  (deltaF)
  CHW_OUTDOOR_TEMPERATURE_HIGH = 80 # Chilled water temperature reset at high outdoor air temperature (F)
  CHW_OUTDOOR_TEMPERATURE_LOW = 60 # Chilled water temperature reset at low outdoor air temperature (F)
  CHW_OUTDOOR_HIGH_SETPOINT = 44 # Chilled water setpoint temperature at high outdoor air temperature (F)
  CHW_OUTDOOR_LOW_SETPOINT = 54 # Chilled water setpoint temperature at low outdoor air temperature (F)
  CHILLER_CHW_LOW_TEMP_LIMIT = 36 # Chiller leaving chilled water lower temperature limit (F)
  CHILLER_CHW_COND_TEMP = 95 # Chiller entering condenser fluid temperature (F)
  PRIMARY_PUMP_POWER = 9 # primary pump power 15 W/gpm

  # Creates a chilled water loop and adds it to the model.
  # This function creates a primary and secondary loop configuration of the cooling loop
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param cooling_fuel [String] cooling fuel. Valid choices are: Electricity, DistrictCooling
  # @param dsgn_sup_wtr_temp [Double] design supply water temperature in degrees Fahrenheit, default 44F
  # @param dsgn_sup_wtr_temp_delt [Double] design supply-return water temperature difference in degrees Rankine, default 10R
  # @param chw_pumping_type [String] valid choices are const_pri, const_pri_var_sec
  # @param chiller_cooling_type [String] valid choices are AirCooled, WaterCooled
  # @param chiller_condenser_type [String] valid choices are WithCondenser, WithoutCondenser, nil
  # @param chiller_compressor_type [String] valid choices are Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
  # @param num_chillers [Integer] the number of chillers
  # @param condenser_water_loop [OpenStudio::Model::PlantLoop] optional condenser water loop for water-cooled chillers.
  #   If this is not passed in, the chillers will be air cooled.
  # @param waterside_economizer [String] Options are 'none', 'integrated', 'non-integrated'.
  #   If 'integrated' will add a heat exchanger to the supply inlet of the chilled water loop
  #     to provide waterside economizing whenever wet bulb temperatures allow
  #   If 'non-integrated' will add a heat exchanger in parallel with the chiller that will operate
  #     only when it can meet cooling demand exclusively with the waterside economizing.
  # @return [OpenStudio::Model::PlantLoop] the resulting chilled water loop
  def model_add_chw_loop(model,
                         system_name: 'Chilled Water Loop',
                         cooling_fuel: 'Electricity',
                         dsgn_sup_wtr_temp: nil,
                         dsgn_sup_wtr_temp_delt: nil,
                         chw_pumping_type: nil,
                         chiller_cooling_type: nil,
                         chiller_condenser_type: nil,
                         chiller_compressor_type: nil,
                         num_chillers: 1,
                         condenser_water_loop: nil,
                         waterside_economizer: 'none')
    OpenStudio.logFree(OpenStudio::Info, 'prm.log', 'Adding chilled water primary and secondry loop.')

    # create chilled water loop
    primary_chilled_water_loop = OpenStudio::Model::PlantLoop.new(model)
    if system_name.nil?
      primary_chilled_water_loop.setName('Chilled Water Loop')
    else
      primary_chilled_water_loop.setName(system_name)
    end
    # chilled water loop sizing and controls
    chw_sizing_control(model, primary_chilled_water_loop, dsgn_sup_wtr_temp, dsgn_sup_wtr_temp_delt)
    # @todo Should be a OutdoorAirReset, see the changes I've made in Standards.PlantLoop.apply_prm_baseline_temperatures

    # Add cooling sources
    if cooling_fuel == 'DistrictCooling'
      # DistrictCooling
      dist_clg = OpenStudio::Model::DistrictCooling.new(model)
      dist_clg.setName('Purchased Cooling')
      dist_clg.autosizeNominalCapacity
      primary_chilled_water_loop.addSupplyBranchForComponent(dist_clg)
    else
      # make the correct type of chiller based these properties
      chiller_sizing_factor = (1.0 / num_chillers).round(2)
      num_chillers.times do |i|
        chiller = OpenStudio::Model::ChillerElectricEIR.new(model)
        chiller.setName("#{template} #{chiller_cooling_type} #{chiller_condenser_type} #{chiller_compressor_type} Chiller #{i}")
        primary_chilled_water_loop.addSupplyBranchForComponent(chiller)
        chiller.setReferenceLeavingChilledWaterTemperature(DESIGN_CHILLED_WATER_TEMPERATURE)
        chiller.setLeavingChilledWaterLowerTemperatureLimit(OpenStudio.convert(CHILLER_CHW_LOW_TEMP_LIMIT, 'F', 'C').get)
        chiller.setReferenceEnteringCondenserFluidTemperature(OpenStudio.convert(CHILLER_CHW_COND_TEMP, 'F', 'C').get)
        chiller.setMinimumPartLoadRatio(0.15)
        chiller.setMaximumPartLoadRatio(1.0)
        chiller.setOptimumPartLoadRatio(1.0)
        chiller.setMinimumUnloadingRatio(0.25)
        chiller.setChillerFlowMode('ConstantFlow')
        chiller.setSizingFactor(chiller_sizing_factor)
        # connect the chiller to the condenser loop if one was supplied
        if condenser_water_loop.nil?
          chiller.setCondenserType('AirCooled')
        else
          condenser_water_loop.addDemandBranchForComponent(chiller)
          chiller.setCondenserType('WaterCooled')
        end
      end
    end

    # create chilled water pumps
    if chw_pumping_type == 'const_pri'
      # primary chilled water pump
      pri_chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      pri_chw_pump.setName("#{primary_chilled_water_loop.name} Pump")
      pri_chw_pump.setRatedPumpHead(OpenStudio.convert(60.0, 'ftH_{2}O', 'Pa').get)
      pri_chw_pump.setMotorEfficiency(0.9)
      # flat pump curve makes it behave as a constant speed pump
      pri_chw_pump.setFractionofMotorInefficienciestoFluidStream(0)
      pri_chw_pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
      pri_chw_pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
      pri_chw_pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
      pri_chw_pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
      pri_chw_pump.setPumpControlType('Intermittent')
      pri_chw_pump.addToNode(primary_chilled_water_loop.supplyInletNode)
    elsif chw_pumping_type == 'const_pri_var_sec'
      # NOTE: PRECONDITIONING for `const_pri_var_sec` pump type is only applicable for PRM routine and only applies to System Type 7 and System Type 8
      # See: model_add_prm_baseline_system under Model object.
      # In this scenario, we will need to create a primary and secondary configuration:
      # Primary: demand: heat exchanger, supply: chillers, name: Chilled Water Loop_Primary, additionalProperty: secondary_loop_name
      # Secondary: demand: Coils, supply: heat exchanger, name: Chilled Water Loop, additionalProperty: is_secondary_loop
      secondary_chilled_water_loop = OpenStudio::Model::PlantLoop.new(model)
      secondary_loop_name = system_name.nil? ? 'Chilled Water Loop' : system_name
      # Reset primary loop name
      primary_chilled_water_loop.setName("#{secondary_loop_name}_Primary")
      secondary_chilled_water_loop.setName(secondary_loop_name)
      chw_sizing_control(model, secondary_chilled_water_loop, dsgn_sup_wtr_temp, dsgn_sup_wtr_temp_delt)
      primary_chilled_water_loop.additionalProperties.setFeature('is_primary_loop', true)
      secondary_chilled_water_loop.additionalProperties.setFeature('is_secondary_loop', true)
      # primary chilled water pump
      # Add Constant pump, in plant loop, the number of chiller adjustment will assign pump to each chiller
      pri_chw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
      pri_chw_pump.setName("#{primary_chilled_water_loop.name} Primary Pump")
      # Will need to adjust the pump power after a sizing run
      pri_chw_pump.setRatedPumpHead(OpenStudio.convert(15.0, 'ftH_{2}O', 'Pa').get / num_chillers)
      pri_chw_pump.setMotorEfficiency(0.9)
      pri_chw_pump.setPumpControlType('Intermittent')
      # chiller_inlet_node = chiller.connectedObject(chiller.supplyInletPort).get.to_Node.get
      pri_chw_pump.addToNode(primary_chilled_water_loop.supplyInletNode)

      # secondary chilled water pump
      sec_chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      sec_chw_pump.setName("#{secondary_chilled_water_loop.name} Pump")
      sec_chw_pump.setRatedPumpHead(OpenStudio.convert(45.0, 'ftH_{2}O', 'Pa').get)
      sec_chw_pump.setMotorEfficiency(0.9)
      # curve makes it perform like variable speed pump
      sec_chw_pump.setFractionofMotorInefficienciestoFluidStream(0)
      sec_chw_pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
      sec_chw_pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0205)
      sec_chw_pump.setCoefficient3ofthePartLoadPerformanceCurve(0.4101)
      sec_chw_pump.setCoefficient4ofthePartLoadPerformanceCurve(0.5753)
      sec_chw_pump.setPumpControlType('Intermittent')
      sec_chw_pump.addToNode(secondary_chilled_water_loop.demandInletNode)

      # Add HX to connect secondary and primary loop
      heat_exchanger = OpenStudio::Model::HeatExchangerFluidToFluid.new(model)
      secondary_chilled_water_loop.addSupplyBranchForComponent(heat_exchanger)
      primary_chilled_water_loop.addDemandBranchForComponent(heat_exchanger)

      # Clean up connections
      hx_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
      hx_bypass_pipe.setName("#{secondary_chilled_water_loop.name} HX Bypass")
      secondary_chilled_water_loop.addSupplyBranchForComponent(hx_bypass_pipe)
      outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
      outlet_pipe.setName("#{secondary_chilled_water_loop.name} Supply Outlet")
      outlet_pipe.addToNode(secondary_chilled_water_loop.supplyOutletNode)
    else
      OpenStudio.logFree(OpenStudio::Error, 'prm.log', 'No pumping type specified for the chilled water loop.')
    end

    # check for existence of condenser_water_loop if WaterCooled
    if chiller_cooling_type == 'WaterCooled'
      if condenser_water_loop.nil?
        OpenStudio.logFree(OpenStudio::Error, 'prm.log', 'Requested chiller is WaterCooled but no condenser loop specified.')
      end
    end

    # check for non-existence of condenser_water_loop if AirCooled
    if chiller_cooling_type == 'AirCooled'
      unless condenser_water_loop.nil?
        OpenStudio.logFree(OpenStudio::Error, 'prm.log', 'Requested chiller is AirCooled but condenser loop specified.')
      end
    end

    # enable waterside economizer if requested
    unless condenser_water_loop.nil?
      case waterside_economizer
      when 'integrated'
        model_add_waterside_economizer(model, primary_chilled_water_loop, condenser_water_loop,
                                       integrated: true)
      when 'non-integrated'
        model_add_waterside_economizer(model, primary_chilled_water_loop, condenser_water_loop,
                                       integrated: false)
      end
    end

    # chilled water loop pipes
    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    chiller_bypass_pipe.setName("#{primary_chilled_water_loop.name} Chiller Bypass")
    primary_chilled_water_loop.addSupplyBranchForComponent(chiller_bypass_pipe)

    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    coil_bypass_pipe.setName("#{primary_chilled_water_loop.name} Coil Bypass")
    primary_chilled_water_loop.addDemandBranchForComponent(coil_bypass_pipe)

    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.setName("#{primary_chilled_water_loop.name} Supply Outlet")
    supply_outlet_pipe.addToNode(primary_chilled_water_loop.supplyOutletNode)

    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.setName("#{primary_chilled_water_loop.name} Demand Inlet")
    demand_inlet_pipe.addToNode(primary_chilled_water_loop.demandInletNode)

    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.setName("#{primary_chilled_water_loop.name} Demand Outlet")
    demand_outlet_pipe.addToNode(primary_chilled_water_loop.demandOutletNode)

    return primary_chilled_water_loop
  end

  private

  def chw_sizing_control(model, chilled_water_loop, dsgn_sup_wtr_temp, dsgn_sup_wtr_temp_delt)
    if dsgn_sup_wtr_temp.nil?
      dsgn_sup_wtr_temp_c = OpenStudio.convert(DESIGN_CHILLED_WATER_TEMPERATURE, 'F', 'C').get
    else
      dsgn_sup_wtr_temp_c = OpenStudio.convert(dsgn_sup_wtr_temp, 'F', 'C').get
    end
    if dsgn_sup_wtr_temp_delt.nil?
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(DESIGN_CHILLED_WATER_TEMPERATURE_DELTA, 'R', 'K').get
    else
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(dsgn_sup_wtr_temp_delt, 'R', 'K').get
    end
    chilled_water_loop.setMinimumLoopTemperature(1.0)
    chilled_water_loop.setMaximumLoopTemperature(40.0)

    sizing_plant = chilled_water_loop.sizingPlant
    sizing_plant.setLoopType('Cooling')
    sizing_plant.setDesignLoopExitTemperature(dsgn_sup_wtr_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(dsgn_sup_wtr_temp_delt_k)
    # Use OA reset setpoint manager
    outdoor_low_temperature_C = OpenStudio.convert(CHW_OUTDOOR_TEMPERATURE_LOW, 'F', 'C').get.round(1)
    outdoor_high_temperature_C = OpenStudio.convert(CHW_OUTDOOR_TEMPERATURE_HIGH, 'F', 'C').get.round(1)
    setpoint_temperature_outdoor_high_C = OpenStudio.convert(CHW_OUTDOOR_HIGH_SETPOINT, 'F', 'C').get.round(1)
    setpoint_temperature_outdoor_low_C = OpenStudio.convert(CHW_OUTDOOR_LOW_SETPOINT, 'F', 'C').get.round(1)

    chw_stpt_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
    chw_stpt_manager.setName("#{chilled_water_loop.name} Setpoint Manager")
    chw_stpt_manager.setOutdoorHighTemperature(outdoor_high_temperature_C) # Degrees Celsius
    chw_stpt_manager.setSetpointatOutdoorHighTemperature(setpoint_temperature_outdoor_high_C) # Degrees Celsius
    chw_stpt_manager.setOutdoorLowTemperature(outdoor_low_temperature_C) # Degrees Celsius
    chw_stpt_manager.setSetpointatOutdoorLowTemperature(setpoint_temperature_outdoor_low_C) # Degrees Celsius
    chw_stpt_manager.addToNode(chilled_water_loop.supplyOutletNode)
  end
end

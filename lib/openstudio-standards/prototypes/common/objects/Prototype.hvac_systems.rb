class Standard
  # @!group hvac_systems

  # Creates a hot water loop with a boiler, district heating, or a
  # water-to-water heat pump and adds it to the model.
  #
  # @param boiler_fuel_type [String] valid choices are Electricity, NaturalGas, PropaneGas, FuelOil#1, FuelOil#2, DistrictHeating, HeatPump
  # @param ambient_loop [OpenStudio::Model::PlantLoop] The condenser loop for the heat pump.
  # Only used when boiler_fuel_type is HeatPump.
  # @return [OpenStudio::Model::PlantLoop] the resulting hot water loop
  def model_add_hw_loop(model, boiler_fuel_type, building_type = nil, ambient_loop = nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding hot water loop.')

    # hot water loop
    hot_water_loop = OpenStudio::Model::PlantLoop.new(model)
    hot_water_loop.setName('Hot Water Loop')
    hot_water_loop.setMinimumLoopTemperature(10)

    # hot water loop controls
    # TODO: Yixing check other building types and add the parameter to the prototype input if more values comes out.
    hw_temp_f = if building_type == 'LargeHotel'
                  140 # HW setpoint 140F
                else
                  180 # HW setpoint 180F
                end

    hw_delta_t_r = 20 # 20F delta-T
    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get
    hw_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    hw_temp_sch.setName("Hot Water Loop Temp - #{hw_temp_f}F")
    hw_temp_sch.defaultDaySchedule.setName("Hot Water Loop Temp - #{hw_temp_f}F Default")
    hw_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), hw_temp_c)
    hw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, hw_temp_sch)
    hw_stpt_manager.setName('Hot water loop setpoint manager')
    hw_stpt_manager.addToNode(hot_water_loop.supplyOutletNode)
    sizing_plant = hot_water_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(hw_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(hw_delta_t_k)

    # hot water pump
    hw_pump = if building_type == 'Outpatient'
                OpenStudio::Model::PumpConstantSpeed.new(model)
              else
                OpenStudio::Model::PumpVariableSpeed.new(model)
              end
    hw_pump.setName('Hot Water Loop Pump')
    hw_pump_head_ft_h2o = 60.0
    hw_pump_head_press_pa = OpenStudio.convert(hw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
    hw_pump.setRatedPumpHead(hw_pump_head_press_pa)
    hw_pump.setMotorEfficiency(0.9)
    hw_pump.setPumpControlType('Intermittent')
    hw_pump.addToNode(hot_water_loop.supplyInletNode)

    case boiler_fuel_type
    # District Heating
    when 'DistrictHeating'
      dist_ht = OpenStudio::Model::DistrictHeating.new(model)
      dist_ht.setName('Purchased Heating')
      dist_ht.autosizeNominalCapacity
      hot_water_loop.addSupplyBranchForComponent(dist_ht)
    # Ambient Loop
    when 'HeatPump'
      water_to_water_hp = OpenStudio::Model::HeatPumpWaterToWaterEquationFitHeating.new(model)
      hot_water_loop.addSupplyBranchForComponent(water_to_water_hp)
      # Get or add an ambient loop
      if ambient_loop.nil?
        ambient_loop = model_get_or_add_ambient_water_loop(model)
      end
      ambient_loop.addDemandBranchForComponent(water_to_water_hp)
    # Boiler
    when 'Electricity', 'NaturalGas', 'PropaneGas', 'FuelOil#1', 'FuelOil#2'
      boiler_max_t_f = 203
      boiler_max_t_c = OpenStudio.convert(boiler_max_t_f, 'F', 'C').get
      boiler = OpenStudio::Model::BoilerHotWater.new(model)
      boiler.setName('Hot Water Loop Boiler')
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')
      boiler.setFuelType(boiler_fuel_type)
      boiler.setDesignWaterOutletTemperature(hw_temp_c)
      boiler.setNominalThermalEfficiency(0.78)
      boiler.setMaximumPartLoadRatio(1.2)
      boiler.setWaterOutletUpperTemperatureLimit(boiler_max_t_c)
      boiler.setBoilerFlowMode('LeavingSetpointModulated')
      hot_water_loop.addSupplyBranchForComponent(boiler)

      if building_type == 'LargeHotel'
        boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')
        boiler.setDesignWaterOutletTemperature(81)
        boiler.setMaximumPartLoadRatio(1.2)
        boiler.setSizingFactor(1.2)
        boiler.setWaterOutletUpperTemperatureLimit(95)
      end

      # TODO: Yixing. Add the temperature setpoint will cost the simulation with
      # thousands of Severe Errors. Need to figure this out later.
      # boiler_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self,hw_temp_sch)
      # boiler_stpt_manager.setName("Boiler outlet setpoint manager")
      # boiler_stpt_manager.addToNode(boiler.outletModelObject.get.to_Node.get)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Boiler fuel type #{boiler_fuel_type} is not valid, no boiler will be added.")
    end

    # hot water loop pipes
    boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    hot_water_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    hot_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.addToNode(hot_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.addToNode(hot_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.addToNode(hot_water_loop.demandOutletNode)

    return hot_water_loop
  end

  # Creates a chilled water loop and adds it to the model.
  #

  # @param chw_pumping_type [String] valid choices are const_pri, const_pri_var_sec
  # @param chiller_cooling_type [String] valid choices are AirCooled, WaterCooled
  # @param chiller_condenser_type [String] valid choices are WithCondenser, WithoutCondenser, nil
  # @param chiller_compressor_type [String] valid choices are Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
  # @param cooling_fuel [String] cooling fuel. Valid choices are:
  # Electricity, DistrictCooling
  # @param condenser_water_loop [OpenStudio::Model::PlantLoop] optional condenser water loop
  #   for water-cooled chillers.  If this is not passed in, the chillers will be air cooled.
  # @return [OpenStudio::Model::PlantLoop] the resulting chilled water loop
  def model_add_chw_loop(model,
                         chw_pumping_type,
                         chiller_cooling_type,
                         chiller_condenser_type,
                         chiller_compressor_type,
                         cooling_fuel,
                         condenser_water_loop = nil,
                         building_type = nil,
                         num_chillers = 1)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding chilled water loop.')

    # Chilled water loop
    chilled_water_loop = OpenStudio::Model::PlantLoop.new(model)
    chilled_water_loop.setName('Chilled Water Loop')
    chilled_water_loop.setMaximumLoopTemperature(98)
    chilled_water_loop.setMinimumLoopTemperature(1)

    # Chilled water loop controls
    chw_temp_f = 44 # CHW setpoint 44F
    chw_delta_t_r = 10.1 # 10.1F delta-T
    # TODO: Yixing check the CHW Setpoint from standards
    # TODO: Should be a OutdoorAirReset, see the changes I've made in Standards.PlantLoop.apply_prm_baseline_temperatures
    if building_type == 'LargeHotel'
      chw_temp_f = 45 # CHW setpoint 45F
      chw_delta_t_r = 12 # 12F delta-T
    end
    chw_temp_c = OpenStudio.convert(chw_temp_f, 'F', 'C').get
    chw_delta_t_k = OpenStudio.convert(chw_delta_t_r, 'R', 'K').get
    chw_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    chw_temp_sch.setName("Chilled Water Loop Temp - #{chw_temp_f}F")
    chw_temp_sch.defaultDaySchedule.setName("Chilled Water Loop Temp - #{chw_temp_f}F Default")
    chw_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), chw_temp_c)
    chw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, chw_temp_sch)
    chw_stpt_manager.setName('Chilled water loop setpoint manager')
    chw_stpt_manager.addToNode(chilled_water_loop.supplyOutletNode)

    sizing_plant = chilled_water_loop.sizingPlant
    sizing_plant.setLoopType('Cooling')
    sizing_plant.setDesignLoopExitTemperature(chw_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(chw_delta_t_k)

    # Chilled water pumps
    if chw_pumping_type == 'const_pri'
      # Primary chilled water pump
      pri_chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      pri_chw_pump.setName('Chilled Water Loop Pump')
      pri_chw_pump_head_ft_h2o = 60.0
      pri_chw_pump_head_press_pa = OpenStudio.convert(pri_chw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      pri_chw_pump.setRatedPumpHead(pri_chw_pump_head_press_pa)
      pri_chw_pump.setMotorEfficiency(0.9)
      # Flat pump curve makes it behave as a constant speed pump
      pri_chw_pump.setFractionofMotorInefficienciestoFluidStream(0)
      pri_chw_pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
      pri_chw_pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
      pri_chw_pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
      pri_chw_pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
      pri_chw_pump.setPumpControlType('Intermittent')
      pri_chw_pump.addToNode(chilled_water_loop.supplyInletNode)
    elsif chw_pumping_type == 'const_pri_var_sec'
      # Primary chilled water pump
      pri_chw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
      pri_chw_pump.setName('Chilled Water Loop Primary Pump')
      pri_chw_pump_head_ft_h2o = 15
      pri_chw_pump_head_press_pa = OpenStudio.convert(pri_chw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      pri_chw_pump.setRatedPumpHead(pri_chw_pump_head_press_pa)
      pri_chw_pump.setMotorEfficiency(0.9)
      pri_chw_pump.setPumpControlType('Intermittent')
      pri_chw_pump.addToNode(chilled_water_loop.supplyInletNode)
      # Secondary chilled water pump
      sec_chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      sec_chw_pump.setName('Chilled Water Loop Secondary Pump')
      sec_chw_pump_head_ft_h2o = 45
      sec_chw_pump_head_press_pa = OpenStudio.convert(sec_chw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      sec_chw_pump.setRatedPumpHead(sec_chw_pump_head_press_pa)
      sec_chw_pump.setMotorEfficiency(0.9)
      # Curve makes it perform like variable speed pump
      sec_chw_pump.setFractionofMotorInefficienciestoFluidStream(0)
      sec_chw_pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
      sec_chw_pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0205)
      sec_chw_pump.setCoefficient3ofthePartLoadPerformanceCurve(0.4101)
      sec_chw_pump.setCoefficient4ofthePartLoadPerformanceCurve(0.5753)
      sec_chw_pump.setPumpControlType('Intermittent')
      sec_chw_pump.addToNode(chilled_water_loop.demandInletNode)
      # Change the chilled water loop to have a two-way common pipes
      chilled_water_loop.setCommonPipeSimulation('CommonPipe')
    end

    # DistrictCooling
    if cooling_fuel == 'DistrictCooling'
      dist_clg = OpenStudio::Model::DistrictCooling.new(model)
      dist_clg.setName('Purchased Cooling')
      dist_clg.autosizeNominalCapacity
      chilled_water_loop.addSupplyBranchForComponent(dist_clg)
    # Chiller
    else

      # Make the correct type of chiller based these properties
      num_chillers.times do |i|
        chiller = OpenStudio::Model::ChillerElectricEIR.new(model)
        chiller.setName("#{template} #{chiller_cooling_type} #{chiller_condenser_type} #{chiller_compressor_type} Chiller #{i}")
        chilled_water_loop.addSupplyBranchForComponent(chiller)
        chiller.setReferenceLeavingChilledWaterTemperature(chw_temp_c)
        ref_cond_wtr_temp_f = 95
        ref_cond_wtr_temp_c = OpenStudio.convert(ref_cond_wtr_temp_f, 'F', 'C').get
        chiller.setReferenceEnteringCondenserFluidTemperature(ref_cond_wtr_temp_c)
        chiller.setMinimumPartLoadRatio(0.15)
        chiller.setMaximumPartLoadRatio(1.0)
        chiller.setOptimumPartLoadRatio(1.0)
        chiller.setMinimumUnloadingRatio(0.25)
        chiller.setCondenserType('AirCooled')
        chiller.setLeavingChilledWaterLowerTemperatureLimit(OpenStudio.convert(36, 'F', 'C').get)
        chiller.setChillerFlowMode('ConstantFlow')

        if building_type == 'LargeHotel' || building_type == 'Hospital'
          chiller.setSizingFactor(0.5)
        end

        # if building_type == "LargeHotel"
        # TODO: Yixing. Add the temperature setpoint and change the flow mode will cost the simulation with
        # thousands of Severe Errors. Need to figure this out later.
        # chiller.setChillerFlowMode('LeavingSetpointModulated')
        # chiller_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self,chw_temp_sch)
        # chiller_stpt_manager.setName("chiller outlet setpoint manager")
        # chiller_stpt_manager.addToNode(chiller.supplyOutletModelObject.get.to_Node.get)
        # end

        # Connect the chiller to the condenser loop if
        # one was supplied.
        if condenser_water_loop
          condenser_water_loop.addDemandBranchForComponent(chiller)
          chiller.setCondenserType('WaterCooled')
        end
      end
    end

    # chilled water loop pipes
    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    chilled_water_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    chilled_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.addToNode(chilled_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.addToNode(chilled_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.addToNode(chilled_water_loop.demandOutletNode)

    return chilled_water_loop
  end

  # Creates a condenser water loop and adds it to the model.
  #
  # @param cooling_tower_type [String] valid choices are Open Cooling Tower, Closed Cooling Tower
  # @param cooling_tower_fan_type [String] valid choices are Centrifugal, Propeller or Axial
  # @param cooling_tower_capacity_control [String] valid choices are Fluid Bypass, Fan Cycling, TwoSpeed Fan, Variable Speed Fan
  # @param number_of_cells_per_tower [Integer] the number of discrete cells per tower
  # @param number_cooling_towers [Integer] the number of cooling towers to be added (in parallel)
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::PlantLoop] the resulting plant loop
  def model_add_cw_loop(model,
                        cooling_tower_type,
                        cooling_tower_fan_type,
                        cooling_tower_capacity_control,
                        number_of_cells_per_tower,
                        number_cooling_towers = 1,
                        building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding condenser water loop.')

    # Condenser water loop
    condenser_water_loop = OpenStudio::Model::PlantLoop.new(model)
    condenser_water_loop.setName('Condenser Water Loop')
    condenser_water_loop.setMaximumLoopTemperature(80)
    condenser_water_loop.setMinimumLoopTemperature(5)

    # Condenser water loop controls
    cw_temp_f = 70 # CW setpoint 70F
    cw_temp_sizing_f = 85 # CW sized to deliver 85F
    cw_delta_t_r = 10 # 10F delta-T
    cw_approach_delta_t_r = 7 # 7F approach
    cw_temp_c = OpenStudio.convert(cw_temp_f, 'F', 'C').get
    cw_temp_sizing_c = OpenStudio.convert(cw_temp_sizing_f, 'F', 'C').get
    cw_delta_t_k = OpenStudio.convert(cw_delta_t_r, 'R', 'K').get
    cw_approach_delta_t_k = OpenStudio.convert(cw_approach_delta_t_r, 'R', 'K').get
    cw_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    cw_temp_sch.setName("Condenser Water Loop Temp - #{cw_temp_f}F")
    cw_temp_sch.defaultDaySchedule.setName("Condenser Water Loop Temp - #{cw_temp_f}F Default")
    cw_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), cw_temp_c)
    cw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, cw_temp_sch)
    cw_stpt_manager.addToNode(condenser_water_loop.supplyOutletNode)
    sizing_plant = condenser_water_loop.sizingPlant
    sizing_plant.setLoopType('Condenser')
    sizing_plant.setDesignLoopExitTemperature(cw_temp_sizing_c)
    sizing_plant.setLoopDesignTemperatureDifference(cw_delta_t_k)

    # Condenser water pump #TODO make this into a HeaderedPump:VariableSpeed
    cw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    cw_pump.setName('Condenser Water Loop Pump')
    cw_pump_head_ft_h2o = 49.7
    cw_pump_head_press_pa = OpenStudio.convert(cw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
    cw_pump.setRatedPumpHead(cw_pump_head_press_pa)
    cw_pump.setPumpControlType('Intermittent')
    cw_pump.addToNode(condenser_water_loop.supplyInletNode)

    # Cooling towers
    # Per PNNL PRM Reference Manual
    number_cooling_towers.times do |_i|
      sizing_factor = 1 / number_cooling_towers
      twr_name = "#{cooling_tower_fan_type} #{cooling_tower_capacity_control} #{cooling_tower_type}"

      # Tower object depends on the control type
      cooling_tower = nil
      case cooling_tower_capacity_control
      when 'Fluid Bypass', 'Fan Cycling'
        cooling_tower = OpenStudio::Model::CoolingTowerSingleSpeed.new(model)
        if cooling_tower_capacity_control == 'Fluid Bypass'
          cooling_tower.setCellControl('FluidBypass')
        else
          cooling_tower.setCellControl('FanCycling')
        end
      when 'TwoSpeed Fan'
        cooling_tower = OpenStudio::Model::CoolingTowerTwoSpeed.new(model)
        # TODO: expose newer cooling tower sizing fields in API
        # cooling_tower.setLowFanSpeedAirFlowRateSizingFactor(0.5)
        # cooling_tower.setLowFanSpeedFanPowerSizingFactor(0.3)
        # cooling_tower.setLowFanSpeedUFactorTimesAreaSizingFactor
        # cooling_tower.setLowSpeedNominalCapacitySizingFactor
      when 'Variable Speed Fan'
        cooling_tower = OpenStudio::Model::CoolingTowerVariableSpeed.new(model)
        cooling_tower.setDesignApproachTemperature(cw_approach_delta_t_k)
        cooling_tower.setDesignRangeTemperature(cw_delta_t_k)
        cooling_tower.setFractionofTowerCapacityinFreeConvectionRegime(0.125)
        twr_fan_curve = model_add_curve(model, 'VSD-TWR-FAN-FPLR')
        cooling_tower.setFanPowerRatioFunctionofAirFlowRateRatioCurve(twr_fan_curve)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "#{cooling_tower_capacity_control} is not a valid choice of cooling tower capacity control.  Valid choices are Fluid Bypass, Fan Cycling, TwoSpeed Fan, Variable Speed Fan.")
      end

      # Set the properties that apply to all tower types
      # and attach to the condenser loop.
      unless cooling_tower.nil?
        cooling_tower.setName(twr_name)
        cooling_tower.setSizingFactor(sizing_factor)
        cooling_tower.setNumberofCells(number_of_cells_per_tower)
        condenser_water_loop.addSupplyBranchForComponent(cooling_tower)
      end
    end

    # Condenser water loop pipes
    cooling_tower_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    condenser_water_loop.addSupplyBranchForComponent(cooling_tower_bypass_pipe)
    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    condenser_water_loop.addDemandBranchForComponent(chiller_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.addToNode(condenser_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.addToNode(condenser_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.addToNode(condenser_water_loop.demandOutletNode)

    return condenser_water_loop
  end

  # Creates a heat pump loop which has a boiler and fluid cooler
  #   for supplemental heating/cooling and adds it to the model.
  #
  # @return [OpenStudio::Model::PlantLoop] the resulting plant loop
  # @todo replace cooling tower with fluid cooler after fixing sizing inputs
  def model_add_hp_loop(model, building_type = nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding heat pump loop.')

    # Heat Pump loop
    heat_pump_water_loop = OpenStudio::Model::PlantLoop.new(model)
    heat_pump_water_loop.setName('Heat Pump Loop')
    heat_pump_water_loop.setMaximumLoopTemperature(80)
    heat_pump_water_loop.setMinimumLoopTemperature(5)

    # Heat Pump loop controls
    hp_high_temp_f = 65 # Supplemental heat below 65F
    hp_low_temp_f = 41 # Supplemental cooling below 41F
    hp_temp_sizing_f = 102.2 # CW sized to deliver 102.2F
    hp_delta_t_r = 19.8 # 19.8F delta-T
    boiler_hw_temp_f = 86 # Boiler makes 86F water

    hp_high_temp_c = OpenStudio.convert(hp_high_temp_f, 'F', 'C').get
    hp_low_temp_c = OpenStudio.convert(hp_low_temp_f, 'F', 'C').get
    hp_temp_sizing_c = OpenStudio.convert(hp_temp_sizing_f, 'F', 'C').get
    hp_delta_t_k = OpenStudio.convert(hp_delta_t_r, 'R', 'K').get
    boiler_hw_temp_c = OpenStudio.convert(boiler_hw_temp_f, 'F', 'C').get

    hp_high_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    hp_high_temp_sch.setName("Heat Pump Loop High Temp - #{hp_high_temp_f}F")
    hp_high_temp_sch.defaultDaySchedule.setName("Heat Pump Loop High Temp - #{hp_high_temp_f}F Default")
    hp_high_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), hp_high_temp_c)

    hp_low_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    hp_low_temp_sch.setName("Heat Pump Loop Low Temp - #{hp_low_temp_f}F")
    hp_low_temp_sch.defaultDaySchedule.setName("Heat Pump Loop Low Temp - #{hp_low_temp_f}F Default")
    hp_low_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), hp_low_temp_c)

    hp_stpt_manager = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(model)
    hp_stpt_manager.setHighSetpointSchedule(hp_high_temp_sch)
    hp_stpt_manager.setLowSetpointSchedule(hp_low_temp_sch)
    hp_stpt_manager.addToNode(heat_pump_water_loop.supplyOutletNode)

    sizing_plant = heat_pump_water_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(hp_temp_sizing_c)
    sizing_plant.setLoopDesignTemperatureDifference(hp_delta_t_k)

    # Heat Pump loop pump
    hp_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    hp_pump.setName('Heat Pump Loop Pump')
    hp_pump_head_ft_h2o = 60
    hp_pump_head_press_pa = OpenStudio.convert(hp_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
    hp_pump.setRatedPumpHead(hp_pump_head_press_pa)
    hp_pump.setPumpControlType('Intermittent')
    hp_pump.addToNode(heat_pump_water_loop.supplyInletNode)

    # Cooling towers
    if building_type == 'LargeOffice' || building_type == 'LargeOfficeDetail'
      # TODO: For some reason the FluidCoolorTwoSpeed is causing simulation failures.
      # might need to look into the defaults
      # cooling_tower = OpenStudio::Model::FluidCoolerTwoSpeed.new(self)
      cooling_tower = OpenStudio::Model::CoolingTowerTwoSpeed.new(model)
      cooling_tower.setName("#{heat_pump_water_loop.name} Central Tower")
      heat_pump_water_loop.addSupplyBranchForComponent(cooling_tower)
      #### Add SPM Scheduled Dual Setpoint to outlet of Fluid Cooler so correct Plant Operation Scheme is generated
      hp_stpt_manager_2 = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(model)
      hp_stpt_manager_2.setHighSetpointSchedule(hp_high_temp_sch)
      hp_stpt_manager_2.setLowSetpointSchedule(hp_low_temp_sch)
      hp_stpt_manager_2.addToNode(cooling_tower.outletModelObject.get.to_Node.get)

    else
      # TODO: replace with FluidCooler:TwoSpeed when available
      # cooling_tower = OpenStudio::Model::CoolingTowerTwoSpeed.new(self)
      # cooling_tower.setName("#{heat_pump_water_loop.name} Sup Cooling Tower")
      # heat_pump_water_loop.addSupplyBranchForComponent(cooling_tower)
      fluid_cooler = OpenStudio::Model::EvaporativeFluidCoolerSingleSpeed.new(model)
      fluid_cooler.setName("#{heat_pump_water_loop.name} Sup Cooling Tower")
      fluid_cooler.setDesignSprayWaterFlowRate(0.002208) # Based on HighRiseApartment
      fluid_cooler.setPerformanceInputMethod('UFactorTimesAreaAndDesignWaterFlowRate')
      heat_pump_water_loop.addSupplyBranchForComponent(fluid_cooler)
    end

    # Boiler
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    boiler.setName("#{heat_pump_water_loop.name} Sup Boiler")
    boiler.setFuelType('Gas')
    boiler.setDesignWaterOutletTemperature(boiler_hw_temp_c)
    boiler.setMinimumPartLoadRatio(0)
    boiler.setMaximumPartLoadRatio(1.2)
    boiler.setOptimumPartLoadRatio(1)
    boiler.setBoilerFlowMode('ConstantFlow')
    heat_pump_water_loop.addSupplyBranchForComponent(boiler)
    #### Add SPM Scheduled Dual Setpoint to outlet of Boiler so correct Plant Operation Scheme is generated
    hp_stpt_manager_3 = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(model)
    hp_stpt_manager_3.setHighSetpointSchedule(hp_high_temp_sch)
    hp_stpt_manager_3.setLowSetpointSchedule(hp_low_temp_sch)
    hp_stpt_manager_3.addToNode(boiler.outletModelObject.get.to_Node.get)

    # Heat Pump water loop pipes
    supply_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_bypass_pipe.setName("#{heat_pump_water_loop.name} Supply Bypass")
    heat_pump_water_loop.addSupplyBranchForComponent(supply_bypass_pipe)

    demand_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_bypass_pipe.setName("#{heat_pump_water_loop.name} Demand Bypass")
    heat_pump_water_loop.addDemandBranchForComponent(demand_bypass_pipe)

    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.setName("#{heat_pump_water_loop.name} Supply Outlet")
    supply_outlet_pipe.addToNode(heat_pump_water_loop.supplyOutletNode)

    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.setName("#{heat_pump_water_loop.name} Demand Inlet")
    demand_inlet_pipe.addToNode(heat_pump_water_loop.demandInletNode)

    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.setName("#{heat_pump_water_loop.name} Demand Outlet")
    demand_outlet_pipe.addToNode(heat_pump_water_loop.demandOutletNode)

    return heat_pump_water_loop
  end

  # Creates loop that roughly mimics a properly sized ground heat exchanger.
  #
  #   for supplemental heating/cooling and adds it to the model.
  #
  # @return [OpenStudio::Model::PlantLoop] the resulting plant loop
  def model_add_ground_hx_loop(model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding ground source loop.')

    # Ground source loop
    ground_hx_loop = OpenStudio::Model::PlantLoop.new(model)
    ground_hx_loop.setName('Ground HX Loop')
    ground_hx_loop.setMaximumLoopTemperature(80)
    ground_hx_loop.setMinimumLoopTemperature(5)

    # Loop controls
    max_delta_t_r = 12 # temp change at high and low entering condition
    min_inlet_f = 30 # low entering condition.
    max_inlet_f = 90 # high entering condition

    delta_t_k = OpenStudio.convert(max_delta_t_r, 'R', 'K').get
    min_inlet_c = OpenStudio.convert(min_inlet_f, 'F', 'C').get
    max_inlet_c = OpenStudio.convert(max_inlet_f, 'F', 'C').get

    # Calculate the linear formula that defines outlet
    # temperature based on inlet temperature of the ground hx.
    min_outlet_c = min_inlet_c + delta_t_k
    max_outlet_c = max_inlet_c - delta_t_k
    slope_c_per_c = (max_outlet_c - min_outlet_c) / (max_inlet_c - min_inlet_c)
    intercept_c = min_outlet_c - (slope_c_per_c * min_inlet_c)

    sizing_plant = ground_hx_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(max_outlet_c)
    sizing_plant.setLoopDesignTemperatureDifference(delta_t_k)

    # Pump
    pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    pump.setName("#{ground_hx_loop.name} Pump")
    pump_head_ft_h2o = 60
    pump_head_press_pa = OpenStudio.convert(pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
    pump.setRatedPumpHead(pump_head_press_pa)
    pump.setPumpControlType('Intermittent')
    pump.addToNode(ground_hx_loop.supplyInletNode)

    # Use EMS and a PlantComponentTemperatureSource to mimic the operation
    # of the ground heat exchanger.

    # Schedule to actuate ground HX outlet temperature
    hx_temp_sch = OpenStudio::Model::ScheduleConstant.new(model)
    hx_temp_sch.setName('Ground HX Temp Sch')
    hx_temp_sch.setValue(24) # TODO

    hx = OpenStudio::Model::PlantComponentTemperatureSource.new(model)
    hx.setName('Ground HX')
    hx.setTemperatureSpecificationType('Scheduled')
    hx.setSourceTemperatureSchedule(hx_temp_sch)
    ground_hx_loop.addSupplyBranchForComponent(hx)

    hx_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, hx_temp_sch)
    hx_stpt_manager.setName("#{hx.name} Supply Outlet Setpoint")
    hx_stpt_manager.addToNode(hx.outletModelObject.get.to_Node.get)

    loop_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, hx_temp_sch)
    loop_stpt_manager.setName("#{ground_hx_loop.name} Supply Outlet Setpoint")
    loop_stpt_manager.addToNode(ground_hx_loop.supplyOutletNode)

    # Sensor to read supply inlet temperature
    supply_inlet_node = ground_hx_loop.supplyInletNode

    inlet_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'System Node Temperature')
    inlet_temp_sensor.setName("#{hx.name} Inlet Temp Sensor")
    inlet_temp_sensor.setKeyName(supply_inlet_node.handle.to_s)

    # Actuator to set supply outlet temperature
    outlet_temp_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(hx_temp_sch, 'Schedule:Constant', 'Schedule Value')
    outlet_temp_actuator.setName("#{hx.name} Outlet Temp Actuator")

    # Actuator to set supply outlet temperature
    outlet_temp_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(hx_temp_sch, 'Schedule:Constant', 'Schedule Value')
    outlet_temp_actuator.setName("#{hx.name} Outlet Temp Actuator")

    # Program to control outlet temperature
    # Adjusts delta-t based on calculation of
    # slope and intercept from control temperatures
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName("#{hx.name} Temp Control")
    program_body = <<-EMS
      SET Tin = #{inlet_temp_sensor.handle}
      SET Tout = #{slope_c_per_c.round(2)} * Tin + #{intercept_c.round(1)}
      SET #{outlet_temp_actuator.handle} = Tout
    EMS
    program.setBody(program_body)

    # Program calling manager
    pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    pcm.setName("#{program.name} Calling Mgr")
    pcm.setCallingPoint('InsideHVACSystemIterationLoop')
    pcm.addProgram(program)

    return ground_hx_loop
  end

  # Adds an ambient condenser water loop that will be used in a district
  # to connect buildings as a shared sink/source for heat pumps.
  #
  # @return [OpenStudio::Model::PlantLoop] the ambient loop
  # @todo handle ground and heat pump with this; make heating/cooling source options (boiler, fluid cooler, district)
  def model_add_district_ambient_loop(model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding district ambient loop.')

    # Ambient loop
    loop = OpenStudio::Model::PlantLoop.new(model)
    loop.setName('Ambient Loop')
    loop.setMaximumLoopTemperature(80)
    loop.setMinimumLoopTemperature(5)

    # Ambient loop controls
    amb_high_temp_f = 90 # Supplemental cooling below 65F
    amb_low_temp_f = 41 # Supplemental heat below 41F
    amb_temp_sizing_f = 102.2 # CW sized to deliver 102.2F
    amb_delta_t_r = 19.8 # 19.8F delta-T

    amb_high_temp_c = OpenStudio.convert(amb_high_temp_f, 'F', 'C').get
    amb_low_temp_c = OpenStudio.convert(amb_low_temp_f, 'F', 'C').get
    amb_temp_sizing_c = OpenStudio.convert(amb_temp_sizing_f, 'F', 'C').get
    amb_delta_t_k = OpenStudio.convert(amb_delta_t_r, 'R', 'K').get

    amb_high_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    amb_high_temp_sch.setName("Ambient Loop High Temp - #{amb_high_temp_f}F")
    amb_high_temp_sch.defaultDaySchedule.setName("Ambient Loop High Temp - #{amb_high_temp_f}F Default")
    amb_high_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), amb_high_temp_c)

    amb_low_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    amb_low_temp_sch.setName("Ambient Loop Low Temp - #{amb_low_temp_f}F")
    amb_low_temp_sch.defaultDaySchedule.setName("Ambient Loop Low Temp - #{amb_low_temp_f}F Default")
    amb_low_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), amb_low_temp_c)

    amb_stpt_manager = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(model)
    amb_stpt_manager.setHighSetpointSchedule(amb_high_temp_sch)
    amb_stpt_manager.setLowSetpointSchedule(amb_low_temp_sch)
    amb_stpt_manager.addToNode(loop.supplyOutletNode)

    sizing_plant = loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(amb_temp_sizing_c)
    sizing_plant.setLoopDesignTemperatureDifference(amb_delta_t_k)

    # Ambient loop pump
    amb_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    amb_pump.setName('Ambient Loop Pump')
    amb_pump_head_ft_h2o = 60
    amb_pump_head_press_pa = OpenStudio.convert(amb_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
    amb_pump.setRatedPumpHead(amb_pump_head_press_pa)
    amb_pump.setPumpControlType('Intermittent')
    amb_pump.addToNode(loop.supplyInletNode)

    # Cooling
    district_cooling = OpenStudio::Model::DistrictCooling.new(model)
    district_cooling.setNominalCapacity(1_000_000_000_000) # large number; no autosizing
    loop.addSupplyBranchForComponent(district_cooling)

    # Heating
    district_heating = OpenStudio::Model::DistrictHeating.new(model)
    district_heating.setNominalCapacity(1_000_000_000_000) # large number; no autosizing
    loop.addSupplyBranchForComponent(district_heating)

    # Ambient water loop pipes
    supply_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_bypass_pipe.setName("#{loop.name} Supply Bypass")
    loop.addSupplyBranchForComponent(supply_bypass_pipe)

    demand_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_bypass_pipe.setName("#{loop.name} Demand Bypass")
    loop.addDemandBranchForComponent(demand_bypass_pipe)

    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.setName("#{loop.name} Supply Outlet")
    supply_outlet_pipe.addToNode(loop.supplyOutletNode)

    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.setName("#{loop.name} Demand Inlet")
    demand_inlet_pipe.addToNode(loop.demandInletNode)

    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.setName("#{loop.name} Demand Outlet")
    demand_outlet_pipe.addToNode(loop.demandOutletNode)

    return loop
  end

  # Creates a VAV system and adds it to the model.
  #

  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [String] hot water loop to connect heating and reheat coils to
  # @param chilled_water_loop [String] chilled water loop to connect cooling coil to
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param vav_fan_efficiency [Double] fan total efficiency, including motor and impeller
  # @param vav_fan_motor_efficiency [Double] fan motor efficiency
  # @param vav_fan_pressure_rise [Double] fan pressure rise, in Pa
  # @param return_plenum [OpenStudio::Model::ThermalZone] the zone to attach as
  # the supply plenum, or nil, in which case no return plenum will be used.
  # @param reheat_type [String] valid options are NaturalGas, Electricity, Water, nil (no heat)
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting VAV air loop
  def model_add_vav_reheat(model,
                           sys_name,
                           hot_water_loop,
                           chilled_water_loop,
                           thermal_zones,
                           hvac_op_sch,
                           oa_damper_sch,
                           vav_fan_efficiency,
                           vav_fan_motor_efficiency,
                           vav_fan_pressure_rise,
                           return_plenum,
                           reheat_type = 'Water',
                           building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding VAV system for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    hw_temp_f = 180 # HW setpoint 180F
    hw_delta_t_r = 20 # 20F delta-T
    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # control temps used across all air handlers
    clg_sa_temp_f = 55.04 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    preclg_sa_temp_f = 55.04 # Precool to 55F
    htg_sa_temp_f = 55.04 # Central deck htg temp 55F
    if building_type == 'LargeHotel'
      htg_sa_temp_f = 62 # Central deck htg temp 55F
    end
    zone_htg_sa_temp_f = 104 # Zone heating design supply air temperature to 104 F
    rht_sa_temp_f = if building_type == 'LargeHotel'
                      90 # VAV box reheat to 90F for large hotel
                    else
                      104 # VAV box reheat to 104F
                    end

    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f, 'F', 'C').get
    preclg_sa_temp_c = OpenStudio.convert(preclg_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
    rht_sa_temp_c = OpenStudio.convert(rht_sa_temp_f, 'F', 'C').get
    zone_htg_sa_temp_c = OpenStudio.convert(zone_htg_sa_temp_f, 'F', 'C').get
    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

    air_flow_ratio = if building_type == 'Hospital'
                       if sys_name == 'VAV_PATRMS'
                         0.5
                       elsif sys_name == 'VAV_1' || sys_name == 'VAV_2'
                         0.3
                       else
                         1
                       end
                     else
                       0.3
                     end

    # air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    sa_stpt_manager.setName("#{thermal_zones.size} Zone VAV supply air setpoint manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # air handler controls
    sizing_system = air_loop.sizingSystem
    sizing_system.setMinimumSystemAirFlowRatio(air_flow_ratio)
    # sizing_system.setPreheatDesignTemperature(htg_oa_tdb_c)
    sizing_system.setPrecoolDesignTemperature(preclg_sa_temp_c)
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_sa_temp_c)
    if building_type == 'Hospital'
      if sys_name == 'VAV_2' || sys_name == 'VAV_1'
        sizing_system.setSizingOption('Coincident')
      else
        sizing_system.setSizingOption('NonCoincident')
      end
    else
      sizing_system.setSizingOption('Coincident')
    end
    sizing_system.setAllOutdoorAirinCooling(false)
    sizing_system.setAllOutdoorAirinHeating(false)
    sizing_system.setSystemOutdoorAirMethod('ZoneSum')

    # fan
    fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.setFanEfficiency(vav_fan_efficiency)
    fan.setMotorEfficiency(vav_fan_motor_efficiency)
    fan.setPressureRise(vav_fan_pressure_rise)
    fan.setFanPowerMinimumFlowRateInputMethod('fraction')
    fan.setFanPowerMinimumFlowFraction(0.25)
    fan.addToNode(air_loop.supplyInletNode)
    fan.setEndUseSubcategory('VAV system Fans')

    # heating coil
    if hot_water_loop.nil?
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
      htg_coil.setName("#{air_loop.name} Main Htg Coil")
      htg_coil.addToNode(air_loop.supplyInletNode)
    else
      htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
      htg_coil.addToNode(air_loop.supplyInletNode)
      hot_water_loop.addDemandBranchForComponent(htg_coil)
      htg_coil.setName("#{air_loop.name} Main Htg Coil")
      htg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Main Htg Coil Controller")
      htg_coil.setRatedInletWaterTemperature(hw_temp_c)
      htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
      htg_coil.setRatedInletAirTemperature(htg_sa_temp_c)
      htg_coil.setRatedOutletAirTemperature(rht_sa_temp_c)
    end

    # cooling coil
    clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
    clg_coil.setName("#{air_loop.name} Clg Coil")
    clg_coil.addToNode(air_loop.supplyInletNode)
    clg_coil.setHeatExchangerConfiguration('CrossFlow')
    chilled_water_loop.addDemandBranchForComponent(clg_coil)
    clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")

    # outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    # oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')

    if building_type == 'LargeHotel'
      oa_intake_controller.setEconomizerControlType('DifferentialEnthalpy')
      oa_intake_controller.resetMaximumFractionofOutdoorAirSchedule
      oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
    end

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system need to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    # hook the VAV system to each zone
    thermal_zones.each do |zone|
      # reheat coil
      rht_coil = nil
      case reheat_type
      when 'NaturalGas'
        rht_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
      when 'Electricity'
        rht_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
      when 'Water'
        rht_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
        rht_coil.setRatedInletWaterTemperature(hw_temp_c)
        rht_coil.setRatedInletAirTemperature(htg_sa_temp_c)
        rht_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        rht_coil.setRatedOutletAirTemperature(rht_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(rht_coil)
      when nil
        # Zero-capacity, always-off electric heating coil
        rht_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule)
        rht_coil.setName("#{zone.name} No Reheat")
        rht_coil.setNominalCapacity(0)
      end

      # vav terminal
      terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, model.alwaysOnDiscreteSchedule, rht_coil)
      terminal.setName("#{zone.name} VAV Term")
      terminal.setZoneMinimumAirFlowMethod('Constant')
      air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(terminal, building_type, thermal_zone_outdoor_airflow_rate_per_area(zone))
      terminal.setMaximumFlowFractionDuringReheat(0.5)
      terminal.setMaximumReheatAirTemperature(rht_sa_temp_c)
      air_loop.addBranchForZone(zone, terminal.to_StraightComponent)

      # Zone sizing
      # TODO Create general logic for cooling airflow method.
      # Large hotel uses design day with limit, school uses design day.
      sizing_zone = zone.sizingZone
      if building_type == 'SecondarySchool'
        sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
      else
        sizing_zone.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
      end
      sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(zone_htg_sa_temp_c)

      unless return_plenum.nil?
        zone.setReturnPlenum(return_plenum)
      end
    end

    # Set the damper action based on the template.
    air_loop_hvac_apply_vav_damper_action(air_loop)

    return air_loop
  end

  # Creates a VAV system with parallel fan powered boxes and adds it to the model.
  #

  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param chilled_water_loop [String] chilled water loop to connect cooling coil to
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param vav_fan_efficiency [Double] fan total efficiency, including motor and impeller
  # @param vav_fan_motor_efficiency [Double] fan motor efficiency
  # @param vav_fan_pressure_rise [Double] fan pressure rise, in Pa
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting VAV air loop
  def model_add_vav_pfp_boxes(model,
                              sys_name,
                              chilled_water_loop,
                              thermal_zones,
                              hvac_op_sch,
                              oa_damper_sch,
                              vav_fan_efficiency,
                              vav_fan_motor_efficiency,
                              vav_fan_pressure_rise,
                              building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding VAV with PFP Boxes and Reheat system for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # control temps used across all air handlers
    clg_sa_temp_f = 55.04 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    preclg_sa_temp_f = 55.04 # Precool to 55F
    htg_sa_temp_f = 55.04 # Central deck htg temp 55F
    rht_sa_temp_f = 104 # VAV box reheat to 104F
    zone_htg_sa_temp_f = 104 # Zone heating design supply air temperature to 104 F

    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f, 'F', 'C').get
    preclg_sa_temp_c = OpenStudio.convert(preclg_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
    rht_sa_temp_c = OpenStudio.convert(rht_sa_temp_f, 'F', 'C').get
    zone_htg_sa_temp_c = OpenStudio.convert(zone_htg_sa_temp_f, 'F', 'C').get

    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

    # air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV with PFP Boxes and Reheat")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    sa_stpt_manager.setName("#{thermal_zones.size} Zone VAV supply air setpoint manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # air handler controls
    sizing_system = air_loop.sizingSystem
    sizing_system.setPreheatDesignTemperature(prehtg_sa_temp_c)
    sizing_system.setPrecoolDesignTemperature(preclg_sa_temp_c)
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_sa_temp_c)
    sizing_system.setSizingOption('Coincident')
    sizing_system.setAllOutdoorAirinCooling(false)
    sizing_system.setAllOutdoorAirinHeating(false)
    sizing_system.setSystemOutdoorAirMethod('ZoneSum')

    # fan
    fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.setFanEfficiency(vav_fan_efficiency)
    fan.setMotorEfficiency(vav_fan_motor_efficiency)
    fan.setPressureRise(vav_fan_pressure_rise)
    fan.setFanPowerMinimumFlowRateInputMethod('fraction')
    fan.setFanPowerMinimumFlowFraction(0.25)
    fan.addToNode(air_loop.supplyInletNode)
    fan.setEndUseSubcategory('VAV system Fans')

    # heating coil
    htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
    htg_coil.setName("#{air_loop.name} Htg Coil")
    htg_coil.addToNode(air_loop.supplyInletNode)

    # cooling coil
    clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
    clg_coil.setName("#{air_loop.name} Clg Coil")
    clg_coil.addToNode(air_loop.supplyInletNode)
    clg_coil.setHeatExchangerConfiguration('CrossFlow')
    chilled_water_loop.addDemandBranchForComponent(clg_coil)
    clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")

    # outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    # oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system need to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    # hook the VAV system to each zone
    thermal_zones.each do |zone|
      # reheat coil
      rht_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      rht_coil.setName("#{zone.name} Rht Coil")

      # terminal fan
      pfp_fan = OpenStudio::Model::FanConstantVolume.new(model, model.alwaysOnDiscreteSchedule)
      pfp_fan.setName("#{zone.name} PFP Term Fan")
      pfp_fan.setPressureRise(300)

      # parallel fan powered terminal
      pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(model,
                                                                                   model.alwaysOnDiscreteSchedule,
                                                                                   pfp_fan,
                                                                                   rht_coil)
      pfp_terminal.setName("#{zone.name} PFP Term")
      air_loop.addBranchForZone(zone, pfp_terminal.to_StraightComponent)

      # Zone sizing
      # TODO Create general logic for cooling airflow method.
      # Large hotel uses design day with limit, school uses design day.
      sizing_zone = zone.sizingZone
      sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
      sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
      # sizing_zone.setZoneHeatingDesignSupplyAirTemperature(rht_sa_temp_c)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(zone_htg_sa_temp_c)
    end

    return air_loop
  end

  # Creates a packaged VAV system and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param electric_reheat [Bool] if true, this system will have electric reheat coils,
  # but if false, the reheat coils will be served by the hot_water_loop.
  # @param hot_water_loop [String] hot water loop to connect heating and reheat coils to.
  #   if nil, will be electric heat and electric reheat
  # @param chilled_water_loop [String] chilled water loop to connect cooling coils to.
  #   if nil, will be DX cooling.
  # @param return_plenum [OpenStudio::Model::ThermalZone] the zone to attach as
  # the supply plenum, or nil, in which case no return plenum will be used.
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting packaged VAV air loop
  def model_add_pvav(model,
                     sys_name,
                     thermal_zones,
                     hvac_op_sch,
                     oa_damper_sch,
                     electric_reheat = false,
                     hot_water_loop = nil,
                     chilled_water_loop = nil,
                     return_plenum = nil,
                     building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding Packaged VAV for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # Control temps for HW loop
    # will only be used when hot_water_loop is provided.
    hw_temp_f = 180 # HW setpoint 180F
    hw_delta_t_r = 20 # 20F delta-T

    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get

    # Control temps used across all air handlers
    sys_dsn_prhtg_temp_f = 44.6 # Design central deck to preheat to 44.6F
    sys_dsn_clg_sa_temp_f = 55 # Design central deck to cool to 55F
    sys_dsn_htg_sa_temp_f = 55 # Central heat to 55F
    zn_dsn_clg_sa_temp_f = 55 # Design VAV box for 55F from central deck
    zn_dsn_htg_sa_temp_f = 122 # Design VAV box to reheat to 122F
    rht_rated_air_in_temp_f = 55 # Reheat coils designed to receive 55F
    rht_rated_air_out_temp_f = 122 # Reheat coils designed to supply 122F
    clg_sa_temp_f = 55 # Central deck clg temp operates at 55F

    sys_dsn_prhtg_temp_c = OpenStudio.convert(sys_dsn_prhtg_temp_f, 'F', 'C').get
    sys_dsn_clg_sa_temp_c = OpenStudio.convert(sys_dsn_clg_sa_temp_f, 'F', 'C').get
    sys_dsn_htg_sa_temp_c = OpenStudio.convert(sys_dsn_htg_sa_temp_f, 'F', 'C').get
    zn_dsn_clg_sa_temp_c = OpenStudio.convert(zn_dsn_clg_sa_temp_f, 'F', 'C').get
    zn_dsn_htg_sa_temp_c = OpenStudio.convert(zn_dsn_htg_sa_temp_f, 'F', 'C').get
    rht_rated_air_in_temp_c = OpenStudio.convert(rht_rated_air_in_temp_f, 'F', 'C').get
    rht_rated_air_out_temp_c = OpenStudio.convert(rht_rated_air_out_temp_f, 'F', 'C').get
    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get

    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

    # Air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if sys_name.nil?
      sys_name = "#{thermal_zones.size} Zone PVAV"
      air_loop.setName(sys_name)
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    # Air handler controls
    stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    stpt_manager.addToNode(air_loop.supplyOutletNode)
    sizing_system = air_loop.sizingSystem
    # sizing_system.setPreheatDesignTemperature(sys_dsn_prhtg_temp_c)
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(sys_dsn_clg_sa_temp_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(sys_dsn_htg_sa_temp_c)
    sizing_system.setSizingOption('Coincident')
    sizing_system.setAllOutdoorAirinCooling(false)
    sizing_system.setAllOutdoorAirinHeating(false)
    air_loop.setNightCycleControlType('CycleOnAny')

    # Fan
    fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.addToNode(air_loop.supplyInletNode)

    # Heating coil - depends on whether heating is hot water or electric,
    # which is determined by whether or not a hot water loop is provided.
    if hot_water_loop.nil?
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
      htg_coil.setName("#{air_loop.name} Main Htg Coil")
      htg_coil.addToNode(air_loop.supplyInletNode)
    else
      htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
      htg_coil.setName("#{air_loop.name} Main Htg Coil")
      htg_coil.setRatedInletWaterTemperature(hw_temp_c)
      htg_coil.setRatedInletAirTemperature(sys_dsn_prhtg_temp_c)
      htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
      htg_coil.setRatedOutletAirTemperature(rht_rated_air_out_temp_c)
      htg_coil.addToNode(air_loop.supplyInletNode)
      hot_water_loop.addDemandBranchForComponent(htg_coil)
    end

    # Cooling coil
    if chilled_water_loop.nil?
      clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model)
      clg_coil.setName("#{air_loop.name} Clg Coil")
      clg_coil.addToNode(air_loop.supplyInletNode)
    else
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
      clg_coil.setName("#{air_loop.name} Clg Coil")
      clg_coil.addToNode(air_loop.supplyInletNode)
      clg_coil.setHeatExchangerConfiguration('CrossFlow')
      chilled_water_loop.addDemandBranchForComponent(clg_coil)
      clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")
    end

    # Outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)
    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Ventilation Controller")
    controller_mv.setAvailabilitySchedule(oa_damper_sch)

    # Hook the VAV system to each zone
    thermal_zones.each do |zone|
      # Reheat coil
      rht_coil = nil
      # sys_name.include? "Outpatient F2 F3"  is only for reheat coil of Outpatient Floor2&3
      if electric_reheat || hot_water_loop.nil? || sys_name.include?('Outpatient F2 F3')
        rht_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
      else
        rht_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
        rht_coil.setRatedInletWaterTemperature(hw_temp_c)
        rht_coil.setRatedInletAirTemperature(rht_rated_air_in_temp_c)
        rht_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        rht_coil.setRatedOutletAirTemperature(rht_rated_air_out_temp_c)
        hot_water_loop.addDemandBranchForComponent(rht_coil)
      end

      # VAV terminal
      terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, model.alwaysOnDiscreteSchedule, rht_coil)
      terminal.setName("#{zone.name} VAV Term")
      terminal.setZoneMinimumAirFlowMethod('Constant')
      terminal.setMaximumReheatAirTemperature(rht_rated_air_out_temp_c)
      air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(terminal, building_type, thermal_zone_outdoor_airflow_rate_per_area(zone))
      air_loop.addBranchForZone(zone, terminal.to_StraightComponent)

      unless return_plenum.nil?
        zone.setReturnPlenum(return_plenum)
      end

      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(zn_dsn_clg_sa_temp_c)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(zn_dsn_htg_sa_temp_c)
    end

    # Set the damper action based on the template.
    air_loop_hvac_apply_vav_damper_action(air_loop)

    return true
  end

  # Creates a packaged VAV system with parallel fan powered boxes and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param vav_fan_efficiency [Double] fan total efficiency, including motor and impeller
  # @param vav_fan_motor_efficiency [Double] fan motor efficiency
  # @param vav_fan_pressure_rise [Double] fan pressure rise, in Pa
  # @param chilled_water_loop [String] chilled water loop to connect cooling coils to.
  #   if nil, will be DX cooling.
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting VAV air loop
  def model_add_pvav_pfp_boxes(model,
                               sys_name,
                               thermal_zones,
                               hvac_op_sch,
                               oa_damper_sch,
                               vav_fan_efficiency,
                               vav_fan_motor_efficiency,
                               vav_fan_pressure_rise,
                               chilled_water_loop = nil,
                               building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PVAV with PFP Boxes and Reheat system for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # control temps used across all air handlers
    clg_sa_temp_f = 55.04 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    preclg_sa_temp_f = 55.04 # Precool to 55F
    htg_sa_temp_f = 55.04 # Central deck htg temp 55F
    rht_sa_temp_f = 104 # VAV box reheat to 104F
    zone_htg_sa_temp_f = 104 # Zone heating design supply air temperature to 104 F

    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f, 'F', 'C').get
    preclg_sa_temp_c = OpenStudio.convert(preclg_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
    rht_sa_temp_c = OpenStudio.convert(rht_sa_temp_f, 'F', 'C').get
    zone_htg_sa_temp_c = OpenStudio.convert(zone_htg_sa_temp_f, 'F', 'C').get

    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

    # air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV with PFP Boxes and Reheat")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    sa_stpt_manager.setName("#{thermal_zones.size} Zone VAV supply air setpoint manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # air handler controls
    sizing_system = air_loop.sizingSystem
    sizing_system.setPreheatDesignTemperature(prehtg_sa_temp_c)
    sizing_system.setPrecoolDesignTemperature(preclg_sa_temp_c)
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_sa_temp_c)
    sizing_system.setSizingOption('Coincident')
    sizing_system.setAllOutdoorAirinCooling(false)
    sizing_system.setAllOutdoorAirinHeating(false)
    sizing_system.setSystemOutdoorAirMethod('ZoneSum')

    # fan
    fan = OpenStudio::Model::FanVariableVolume.new(model, model.alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.setFanEfficiency(vav_fan_efficiency)
    fan.setMotorEfficiency(vav_fan_motor_efficiency)
    fan.setPressureRise(vav_fan_pressure_rise)
    fan.setFanPowerMinimumFlowRateInputMethod('fraction')
    fan.setFanPowerMinimumFlowFraction(0.25)
    fan.addToNode(air_loop.supplyInletNode)
    fan.setEndUseSubcategory('VAV system Fans')

    # heating coil
    htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
    htg_coil.setName("#{air_loop.name} Main Htg Coil")
    htg_coil.addToNode(air_loop.supplyInletNode)

    # Cooling coil
    if chilled_water_loop.nil?
      clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model)
      clg_coil.setName("#{air_loop.name} Clg Coil")
      clg_coil.addToNode(air_loop.supplyInletNode)
    else
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
      clg_coil.setName("#{air_loop.name} Clg Coil")
      clg_coil.addToNode(air_loop.supplyInletNode)
      clg_coil.setHeatExchangerConfiguration('CrossFlow')
      chilled_water_loop.addDemandBranchForComponent(clg_coil)
      clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")
    end

    # outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system need to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    # hook the VAV system to each zone
    thermal_zones.each do |zone|
      # reheat coil
      rht_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      rht_coil.setName("#{zone.name} Rht Coil")

      # terminal fan
      pfp_fan = OpenStudio::Model::FanConstantVolume.new(model, model.alwaysOnDiscreteSchedule)
      pfp_fan.setName("#{zone.name} PFP Term Fan")
      pfp_fan.setPressureRise(300)

      # parallel fan powered terminal
      pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(model,
                                                                                   model.alwaysOnDiscreteSchedule,
                                                                                   pfp_fan,
                                                                                   rht_coil)
      pfp_terminal.setName("#{zone.name} PFP Term")
      air_loop.addBranchForZone(zone, pfp_terminal.to_StraightComponent)

      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
      sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
      # sizing_zone.setZoneHeatingDesignSupplyAirTemperature(rht_sa_temp_c)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(zone_htg_sa_temp_c)
    end

    return air_loop
  end

  # Creates a packaged VAV system and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [String] hot water loop to connect heating and reheat coils to.
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param fan_efficiency [Double] fan total efficiency, including motor and impeller
  # @param fan_motor_efficiency [Double] fan motor efficiency
  # @param fan_pressure_rise [Double] fan pressure rise, in Pa
  # @param chilled_water_loop [String] chilled water loop to connect cooling coil to.
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting packaged VAV air loop
  def model_add_cav(model,
                    sys_name,
                    hot_water_loop,
                    thermal_zones,
                    hvac_op_sch,
                    oa_damper_sch,
                    fan_efficiency,
                    fan_motor_efficiency,
                    fan_pressure_rise,
                    chilled_water_loop = nil,
                    building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding CAV for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # Hot water loop control temperatures
    hw_temp_f = 152.6 # HW setpoint 152.6F
    if building_type == 'Hospital'
      hw_temp_f = 180
    end
    hw_delta_t_r = 20 # 20F delta-T
    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get
    air_flow_ratio = 1

    # Air handler control temperatures
    clg_sa_temp_f = 55.04 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    if building_type == 'Hospital'
      prehtg_sa_temp_f = 55.04
    end
    preclg_sa_temp_f = 55.04 # Precool to 55F
    htg_sa_temp_f = 62.06 # Central deck htg temp 62.06F
    rht_sa_temp_f = 122 # VAV box reheat to 104F
    zone_htg_sa_temp_f = 122 # Zone heating design supply air temperature to 122F
    if building_type == 'Hospital'
      htg_sa_temp_f = 104 # Central deck htg temp 104F
      # rht_sa_temp_f = 122 # VAV box reheat to 104F
      zone_htg_sa_temp_f = 104 # Zone heating design supply air temperature to 122F
    end
    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f, 'F', 'C').get
    preclg_sa_temp_c = OpenStudio.convert(preclg_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
    rht_sa_temp_c = OpenStudio.convert(rht_sa_temp_f, 'F', 'C').get
    zone_htg_sa_temp_c = OpenStudio.convert(zone_htg_sa_temp_f, 'F', 'C').get

    # Air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone CAV")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    # Air handler supply air setpoint
    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    sa_stpt_manager.setName("#{air_loop.name} supply air setpoint manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # Air handler sizing
    sizing_system = air_loop.sizingSystem
    sizing_system.setMinimumSystemAirFlowRatio(air_flow_ratio)
    sizing_system.setPreheatDesignTemperature(prehtg_sa_temp_c)
    sizing_system.setPrecoolDesignTemperature(preclg_sa_temp_c)
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_sa_temp_c)
    if building_type == 'Hospital'
      sizing_system.setSizingOption('NonCoincident')
    else
      sizing_system.setSizingOption('Coincident')
    end
    sizing_system.setAllOutdoorAirinCooling(false)
    sizing_system.setAllOutdoorAirinHeating(false)
    sizing_system.setSystemOutdoorAirMethod('ZoneSum')

    # Fan
    fan = OpenStudio::Model::FanConstantVolume.new(model, model.alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    if building_type == 'Hospital'
      fan.setFanEfficiency(0.61425)
      fan.setMotorEfficiency(0.945)
      fan.setPressureRise(1018.41)
    else
      fan.setFanEfficiency(fan_efficiency)
      fan.setMotorEfficiency(fan_motor_efficiency)
      fan.setPressureRise(fan_pressure_rise)
    end
    fan.addToNode(air_loop.supplyInletNode)
    fan.setEndUseSubcategory('CAV system Fans')

    # Air handler heating coil
    htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
    htg_coil.addToNode(air_loop.supplyInletNode)
    hot_water_loop.addDemandBranchForComponent(htg_coil)
    htg_coil.setName("#{air_loop.name} Main Htg Coil")
    htg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Main Htg Coil Controller")
    htg_coil.setRatedInletWaterTemperature(hw_temp_c)
    htg_coil.setRatedInletAirTemperature(prehtg_sa_temp_c)
    htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
    htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)

    # Air handler cooling coil

    if chilled_water_loop.nil?
      clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model)
    else
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
      clg_coil.setHeatExchangerConfiguration('CrossFlow')
      chilled_water_loop.addDemandBranchForComponent(clg_coil)
      clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")
    end
    clg_coil.setName("#{air_loop.name} Clg Coil")
    clg_coil.addToNode(air_loop.supplyInletNode)

    # Outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    # oa_intake_controller.setMinimumOutdoorAirSchedule(motorized_oa_damper_sch)
    oa_intake_controller.setMinimumFractionofOutdoorAirSchedule(oa_damper_sch)

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('ZoneSum')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system needs to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    # Connect the CAV system to each zone
    thermal_zones.each do |zone|
      if building_type == 'Hospital'
        # CAV terminal
        terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        terminal.setName("#{zone.name} CAV Term")
      else
        # Reheat coil
        rht_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
        rht_coil.setRatedInletWaterTemperature(hw_temp_c)
        rht_coil.setRatedInletAirTemperature(htg_sa_temp_c)
        rht_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        rht_coil.setRatedOutletAirTemperature(rht_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(rht_coil)

        # VAV terminal
        terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, model.alwaysOnDiscreteSchedule, rht_coil)
        terminal.setName("#{zone.name} VAV Term")
        terminal.setZoneMinimumAirFlowMethod('Constant')
        air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(terminal, building_type, thermal_zone_outdoor_airflow_rate_per_area(zone))
        terminal.setMaximumFlowPerZoneFloorAreaDuringReheat(0.0)
        terminal.setMaximumFlowFractionDuringReheat(0.5)
        terminal.setMaximumReheatAirTemperature(rht_sa_temp_c)
      end
      air_loop.addBranchForZone(zone, terminal.to_StraightComponent)

      # Zone sizing
      # TODO Create general logic for cooling airflow method.
      # Large hotel uses design day with limit, school uses design day.
      sizing_zone = zone.sizingZone
      if building_type == 'SecondarySchool'
        sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
      else
        sizing_zone.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
      end
      sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
      # sizing_zone.setZoneHeatingDesignSupplyAirTemperature(rht_sa_temp_c)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(zone_htg_sa_temp_c)
    end

    # Set the damper action based on the template.
    air_loop_hvac_apply_vav_damper_action(air_loop)

    return true
  end

  # Creates a PSZ-AC system for each zone and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [String] hot water loop to connect heating coil to, or nil
  # @param chilled_water_loop [String] chilled water loop to connect cooling coil to, or nil
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param fan_location [Double] valid choices are BlowThrough, DrawThrough
  # @param fan_type [Double] valid choices are ConstantVolume, Cycling
  # @param heating_type [Double] valid choices are NaturalGas, Electricity, Water, nil (no heat)
  # Single Speed Heat Pump, Water To Air Heat Pump
  # @param supplemental_heating_type [Double] valid choices are Electricity, NaturalGas,  nil (no heat)
  # @param cooling_type [String] valid choices are Water, Two Speed DX AC,
  # Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] an array of the resulting PSZ-AC air loops
  # Todo: clarify where these default curves coefficients are coming from
  # Todo: I (jmarrec) believe it is the DOE Ref curves ("DOE Ref DX Clg Coil Cool-Cap-fT")
  def model_add_psz_ac(model,
                       sys_name,
                       hot_water_loop,
                       chilled_water_loop,
                       thermal_zones,
                       hvac_op_sch,
                       oa_damper_sch,
                       fan_location,
                       fan_type,
                       heating_type,
                       supplemental_heating_type,
                       cooling_type,
                       building_type = nil)

    hw_temp_f = 180 # HW setpoint 180F
    hw_delta_t_r = 20 # 20F delta-T
    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get

    # control temps used across all air handlers
    clg_sa_temp_f = 55 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    htg_sa_temp_f = 55 # Central deck htg temp 55F
    rht_sa_temp_f = 104 # VAV box reheat to 104F

    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
    rht_sa_temp_c = OpenStudio.convert(rht_sa_temp_f, 'F', 'C').get

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # Make a PSZ-AC for each zone
    air_loops = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PSZ-AC for #{zone.name}.")

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      if sys_name.nil?
        air_loop.setName("#{zone.name} PSZ-AC")
      else
        air_loop.setName("#{zone.name} #{sys_name}")
      end
      air_loop.setAvailabilitySchedule(hvac_op_sch)
      air_loops << air_loop

      # When an air_loop is contructed, its constructor creates a sizing:system object
      # the default sizing:system contstructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(12.8)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(12.8)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(40.0)
      air_loop_sizing.setSizingOption('Coincident')
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(12.8)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(40.0)

      # Add a setpoint manager single zone reheat to control the
      # supply air temperature based on the needs of this zone
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)

      fan = nil
      # ConstantVolume: Packaged Rooftop Single Zone Air conditioner;
      # Cycling: Unitary System;
      # CyclingHeatPump: Unitary Heat Pump system
      if fan_type == 'ConstantVolume'
        fan = OpenStudio::Model::FanConstantVolume.new(model, hvac_op_sch)
        fan.setName("#{air_loop.name} Fan")
        fan_static_pressure_in_h2o = 2.5
        fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
        fan.setPressureRise(fan_static_pressure_pa)
        fan.setFanEfficiency(0.54)
        fan.setMotorEfficiency(0.90)
      elsif fan_type == 'Cycling'

        fan = OpenStudio::Model::FanOnOff.new(model, hvac_op_sch) # Set fan op sch manually since fwd translator doesn't
        fan.setName("#{air_loop.name} Fan")
        fan_static_pressure_in_h2o = 2.5
        fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
        fan.setPressureRise(fan_static_pressure_pa)
        fan.setFanEfficiency(0.54)
        fan.setMotorEfficiency(0.90)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Fan type '#{fan_type}' not recognized, cannot add PSZ-AC.")
        return []
      end

      htg_coil = nil
      case heating_type
      when 'NaturalGas', 'Gas'
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
        htg_coil.setName("#{air_loop.name} Gas Htg Coil")
      when nil
        # Zero-capacity, always-off electric heating coil
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule)
        htg_coil.setName("#{air_loop.name} No Heat")
        htg_coil.setNominalCapacity(0)
      when 'Water'
        if hot_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water plant loop supplied')
          return false
        end
        htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
        htg_coil.setName("#{air_loop.name} Water Htg Coil")
        htg_coil.setRatedInletWaterTemperature(hw_temp_c)
        htg_coil.setRatedInletAirTemperature(prehtg_sa_temp_c)
        htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(htg_coil)
      when 'Single Speed Heat Pump'
        htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
        htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
        htg_cap_f_of_temp.setCoefficient2x(0.027626)
        htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
        htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
        htg_cap_f_of_temp.setMinimumValueofx(-20.0)
        htg_cap_f_of_temp.setMaximumValueofx(20.0)

        htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(model)
        htg_cap_f_of_flow.setCoefficient1Constant(0.84)
        htg_cap_f_of_flow.setCoefficient2x(0.16)
        htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
        htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
        htg_cap_f_of_flow.setMinimumValueofx(0.5)
        htg_cap_f_of_flow.setMaximumValueofx(1.5)

        htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
        htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
        htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
        htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
        htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
        htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
        htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

        htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
        htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
        htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
        htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
        htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

        htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
        htg_part_load_fraction.setCoefficient1Constant(0.85)
        htg_part_load_fraction.setCoefficient2x(0.15)
        htg_part_load_fraction.setCoefficient3xPOW2(0.0)
        htg_part_load_fraction.setMinimumValueofx(0.0)
        htg_part_load_fraction.setMaximumValueofx(1.0)

        htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model,
                                                                   model.alwaysOnDiscreteSchedule,
                                                                   htg_cap_f_of_temp,
                                                                   htg_cap_f_of_flow,
                                                                   htg_energy_input_ratio_f_of_temp,
                                                                   htg_energy_input_ratio_f_of_flow,
                                                                   htg_part_load_fraction)

        htg_coil.setName("#{air_loop.name} HP Htg Coil")
        htg_coil.setRatedCOP(3.3) # TODO: add this to standards
        htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(-12.2)
        htg_coil.setMaximumOutdoorDryBulbTemperatureforDefrostOperation(1.67)
        htg_coil.setCrankcaseHeaterCapacity(50.0)
        htg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(4.4)

        htg_coil.setDefrostStrategy('ReverseCycle')
        htg_coil.setDefrostControl('OnDemand')

        def_eir_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        def_eir_f_of_temp.setCoefficient1Constant(0.297145)
        def_eir_f_of_temp.setCoefficient2x(0.0430933)
        def_eir_f_of_temp.setCoefficient3xPOW2(-0.000748766)
        def_eir_f_of_temp.setCoefficient4y(0.00597727)
        def_eir_f_of_temp.setCoefficient5yPOW2(0.000482112)
        def_eir_f_of_temp.setCoefficient6xTIMESY(-0.000956448)
        def_eir_f_of_temp.setMinimumValueofx(12.77778)
        def_eir_f_of_temp.setMaximumValueofx(23.88889)
        def_eir_f_of_temp.setMinimumValueofy(21.11111)
        def_eir_f_of_temp.setMaximumValueofy(46.11111)

        htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(def_eir_f_of_temp)
      when 'Water To Air Heat Pump'
        if hot_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water plant loop supplied')
          return false
        end
        htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model)
        htg_coil.setName("#{air_loop.name} Water-to-Air HP Htg Coil")
        htg_coil.setRatedHeatingCoefficientofPerformance(4.2) # TODO: add this to standards
        htg_coil.setHeatingCapacityCoefficient1(0.237847462869254)
        htg_coil.setHeatingCapacityCoefficient2(-3.35823796081626)
        htg_coil.setHeatingCapacityCoefficient3(3.80640467406376)
        htg_coil.setHeatingCapacityCoefficient4(0.179200417311554)
        htg_coil.setHeatingCapacityCoefficient5(0.12860719846082)
        htg_coil.setHeatingPowerConsumptionCoefficient1(-3.79175529243238)
        htg_coil.setHeatingPowerConsumptionCoefficient2(3.38799239505527)
        htg_coil.setHeatingPowerConsumptionCoefficient3(1.5022612076303)
        htg_coil.setHeatingPowerConsumptionCoefficient4(-0.177653510577989)
        htg_coil.setHeatingPowerConsumptionCoefficient5(-0.103079864171839)

        hot_water_loop.addDemandBranchForComponent(htg_coil)
      when 'Electricity', 'Electric'
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        htg_coil.setName("#{air_loop.name} Electric Htg Coil")
      end

      supplemental_htg_coil = nil
      case supplemental_heating_type
      when 'Electricity', 'Electric' # TODO: change spreadsheet to Electricity
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        supplemental_htg_coil.setName("#{air_loop.name} Electric Backup Htg Coil")
      when 'NaturalGas', 'Gas'
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
        supplemental_htg_coil.setName("#{air_loop.name} Gas Backup Htg Coil")
      when nil
        # Zero-capacity, always-off electric heating coil
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule)
        supplemental_htg_coil.setName("#{air_loop.name} No Backup Heat")
        supplemental_htg_coil.setNominalCapacity(0)
      end

      clg_coil = nil
      if cooling_type == 'Water'
        if chilled_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No chilled water plant loop supplied')
          return false
        end
        clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
        clg_coil.setName("#{air_loop.name} Water Clg Coil")
        chilled_water_loop.addDemandBranchForComponent(clg_coil)
      elsif cooling_type == 'Two Speed DX AC'

        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
        clg_cap_f_of_temp.setCoefficient2x(0.04426)
        clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
        clg_cap_f_of_temp.setCoefficient4y(0.00333)
        clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
        clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
        clg_cap_f_of_temp.setMinimumValueofx(17.0)
        clg_cap_f_of_temp.setMaximumValueofx(22.0)
        clg_cap_f_of_temp.setMinimumValueofy(13.0)
        clg_cap_f_of_temp.setMaximumValueofy(46.0)

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
        clg_cap_f_of_flow.setCoefficient2x(0.34053)
        clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
        clg_cap_f_of_flow.setMinimumValueofx(0.75918)
        clg_cap_f_of_flow.setMaximumValueofx(1.13877)

        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
        clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
        clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
        clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
        clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
        clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
        clg_part_load_ratio.setCoefficient1Constant(0.77100)
        clg_part_load_ratio.setCoefficient2x(0.22900)
        clg_part_load_ratio.setCoefficient3xPOW2(0.0)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)

        clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_cap_f_of_temp_low_spd.setCoefficient1Constant(0.42415)
        clg_cap_f_of_temp_low_spd.setCoefficient2x(0.04426)
        clg_cap_f_of_temp_low_spd.setCoefficient3xPOW2(-0.00042)
        clg_cap_f_of_temp_low_spd.setCoefficient4y(0.00333)
        clg_cap_f_of_temp_low_spd.setCoefficient5yPOW2(-0.00008)
        clg_cap_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00021)
        clg_cap_f_of_temp_low_spd.setMinimumValueofx(17.0)
        clg_cap_f_of_temp_low_spd.setMaximumValueofx(22.0)
        clg_cap_f_of_temp_low_spd.setMinimumValueofy(13.0)
        clg_cap_f_of_temp_low_spd.setMaximumValueofy(46.0)

        clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient1Constant(1.23649)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient2x(-0.02431)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient3xPOW2(0.00057)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient4y(-0.01434)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient5yPOW2(0.00063)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00038)
        clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofx(17.0)
        clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofx(22.0)
        clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofy(13.0)
        clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofy(46.0)

        clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model,
                                                                model.alwaysOnDiscreteSchedule,
                                                                clg_cap_f_of_temp,
                                                                clg_cap_f_of_flow,
                                                                clg_energy_input_ratio_f_of_temp,
                                                                clg_energy_input_ratio_f_of_flow,
                                                                clg_part_load_ratio,
                                                                clg_cap_f_of_temp_low_spd,
                                                                clg_energy_input_ratio_f_of_temp_low_spd)

        clg_coil.setName("#{air_loop.name} 2spd DX AC Clg Coil")
        clg_coil.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new(0.69))
        clg_coil.setBasinHeaterCapacity(10)
        clg_coil.setBasinHeaterSetpointTemperature(2.0)

      elsif cooling_type == 'Single Speed DX AC'
        # Defaults to "DOE Ref DX Clg Coil Cool-Cap-fT"
        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_cap_f_of_temp.setCoefficient1Constant(0.9712123)
        clg_cap_f_of_temp.setCoefficient2x(-0.015275502)
        clg_cap_f_of_temp.setCoefficient3xPOW2(0.0014434524)
        clg_cap_f_of_temp.setCoefficient4y(-0.00039321)
        clg_cap_f_of_temp.setCoefficient5yPOW2(-0.0000068364)
        clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.0002905956)
        clg_cap_f_of_temp.setMinimumValueofx(-100.0)
        clg_cap_f_of_temp.setMaximumValueofx(100.0)
        clg_cap_f_of_temp.setMinimumValueofy(-100.0)
        clg_cap_f_of_temp.setMaximumValueofy(100.0)

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_cap_f_of_flow.setCoefficient1Constant(1.0)
        clg_cap_f_of_flow.setCoefficient2x(0.0)
        clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
        clg_cap_f_of_flow.setMinimumValueofx(-100.0)
        clg_cap_f_of_flow.setMaximumValueofx(100.0)

        # "DOE Ref DX Clg Coil Cool-EIR-fT",
        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.28687133)
        clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.023902164)
        clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000810648)
        clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.013458546)
        clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.0003389364)
        clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.0004870044)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofx(-100.0)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofx(100.0)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofy(-100.0)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofy(100.0)

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.0)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(0.0)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(-100.0)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(100.0)

        # "DOE Ref DX Clg Coil Cool-PLF-fPLR"
        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
        clg_part_load_ratio.setCoefficient1Constant(0.90949556)
        clg_part_load_ratio.setCoefficient2x(0.09864773)
        clg_part_load_ratio.setCoefficient3xPOW2(-0.00819488)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)
        clg_part_load_ratio.setMinimumCurveOutput(0.7)
        clg_part_load_ratio.setMaximumCurveOutput(1.0)

        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                   model.alwaysOnDiscreteSchedule,
                                                                   clg_cap_f_of_temp,
                                                                   clg_cap_f_of_flow,
                                                                   clg_energy_input_ratio_f_of_temp,
                                                                   clg_energy_input_ratio_f_of_flow,
                                                                   clg_part_load_ratio)

        clg_coil.setName("#{air_loop.name} 1spd DX AC Clg Coil")

      elsif cooling_type == 'Single Speed Heat Pump'
        # "PSZ-AC_Unitary_PackagecoolCapFT"
        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_cap_f_of_temp.setCoefficient1Constant(0.766956)
        clg_cap_f_of_temp.setCoefficient2x(0.0107756)
        clg_cap_f_of_temp.setCoefficient3xPOW2(-0.0000414703)
        clg_cap_f_of_temp.setCoefficient4y(0.00134961)
        clg_cap_f_of_temp.setCoefficient5yPOW2(-0.000261144)
        clg_cap_f_of_temp.setCoefficient6xTIMESY(0.000457488)
        clg_cap_f_of_temp.setMinimumValueofx(12.78)
        clg_cap_f_of_temp.setMaximumValueofx(23.89)
        clg_cap_f_of_temp.setMinimumValueofy(21.1)
        clg_cap_f_of_temp.setMaximumValueofy(46.1)

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_cap_f_of_flow.setCoefficient1Constant(0.8)
        clg_cap_f_of_flow.setCoefficient2x(0.2)
        clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
        clg_cap_f_of_flow.setMinimumValueofx(0.5)
        clg_cap_f_of_flow.setMaximumValueofx(1.5)

        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.297145)
        clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.0430933)
        clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000748766)
        clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.00597727)
        clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000482112)
        clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000956448)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofx(12.78)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofx(23.89)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofy(21.1)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.1)

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.156)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1816)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
        clg_part_load_ratio.setCoefficient1Constant(0.85)
        clg_part_load_ratio.setCoefficient2x(0.15)
        clg_part_load_ratio.setCoefficient3xPOW2(0.0)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)

        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                   model.alwaysOnDiscreteSchedule,
                                                                   clg_cap_f_of_temp,
                                                                   clg_cap_f_of_flow,
                                                                   clg_energy_input_ratio_f_of_temp,
                                                                   clg_energy_input_ratio_f_of_flow,
                                                                   clg_part_load_ratio)

        clg_coil.setName("#{air_loop.name} 1spd DX HP Clg Coil")
        # clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(OpenStudio::OptionalDouble.new(10.0))
        # clg_coil.setRatedSensibleHeatRatio(0.69)
        # clg_coil.setBasinHeaterCapacity(10)
        # clg_coil.setBasinHeaterSetpointTemperature(2.0)

      elsif cooling_type == 'Water To Air Heat Pump'
        if chilled_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No chilled water plant loop supplied')
          return false
        end
        clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model)
        clg_coil.setName("#{air_loop.name} Water-to-Air HP Clg Coil")
        clg_coil.setRatedCoolingCoefficientofPerformance(3.4) # TODO: add this to standards

        clg_coil.setTotalCoolingCapacityCoefficient1(-4.30266987344639)
        clg_coil.setTotalCoolingCapacityCoefficient2(7.18536990534372)
        clg_coil.setTotalCoolingCapacityCoefficient3(-2.23946714486189)
        clg_coil.setTotalCoolingCapacityCoefficient4(0.139995928440879)
        clg_coil.setTotalCoolingCapacityCoefficient5(0.102660179888915)
        clg_coil.setSensibleCoolingCapacityCoefficient1(6.0019444814887)
        clg_coil.setSensibleCoolingCapacityCoefficient2(22.6300677244073)
        clg_coil.setSensibleCoolingCapacityCoefficient3(-26.7960783730934)
        clg_coil.setSensibleCoolingCapacityCoefficient4(-1.72374720346819)
        clg_coil.setSensibleCoolingCapacityCoefficient5(0.490644802367817)
        clg_coil.setSensibleCoolingCapacityCoefficient6(0.0693119353468141)
        clg_coil.setCoolingPowerConsumptionCoefficient1(-5.67775976415698)
        clg_coil.setCoolingPowerConsumptionCoefficient2(0.438988156976704)
        clg_coil.setCoolingPowerConsumptionCoefficient3(5.845277342193)
        clg_coil.setCoolingPowerConsumptionCoefficient4(0.141605667000125)
        clg_coil.setCoolingPowerConsumptionCoefficient5(-0.168727936032429)

        chilled_water_loop.addDemandBranchForComponent(clg_coil)
      end

      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.setName("#{air_loop.name} OA Sys Controller")
      oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
      oa_system.setName("#{air_loop.name} OA Sys")
      econ_eff_sch = model_add_schedule(model, 'RetailStandalone PSZ_Econ_MaxOAFrac_Sch')

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode

      # Wrap coils in a unitary system or not, depending
      # on the system type.
      if fan_type == 'Cycling'

        if heating_type == 'Water To Air Heat Pump'
          unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
          unitary_system.setSupplyFan(fan)
          unitary_system.setHeatingCoil(htg_coil)
          unitary_system.setCoolingCoil(clg_coil)
          unitary_system.setSupplementalHeatingCoil(supplemental_htg_coil)
          unitary_system.setName("#{zone.name} Unitary HP")
          unitary_system.setControllingZoneorThermostatLocation(zone)
          unitary_system.setMaximumSupplyAirTemperature(50)
          unitary_system.setFanPlacement('BlowThrough')
          unitary_system.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
          unitary_system.setSupplyAirFlowRateMethodDuringHeatingOperation('SupplyAirFlowRate')
          unitary_system.setSupplyAirFlowRateMethodWhenNoCoolingorHeatingisRequired('SupplyAirFlowRate')
          unitary_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOnDiscreteSchedule)
          unitary_system.addToNode(supply_inlet_node)
          setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(50)
        else
          unitary_system = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir.new(model,
                                                                                     model.alwaysOnDiscreteSchedule,
                                                                                     fan,
                                                                                     htg_coil,
                                                                                     clg_coil,
                                                                                     supplemental_htg_coil)
          unitary_system.setName("#{air_loop.name} Unitary HP")
          unitary_system.setControllingZone(zone)
          unitary_system.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(OpenStudio.convert(40, 'F', 'C').get)
          unitary_system.setFanPlacement(fan_location)
          unitary_system.setSupplyAirFanOperatingModeSchedule(hvac_op_sch)
          unitary_system.addToNode(supply_inlet_node)

          setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(OpenStudio.convert(55, 'F', 'C').get)
          setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(OpenStudio.convert(104, 'F', 'C').get)
        end

      else
        if fan_location == 'DrawThrough'
          # Add the fan
          unless fan.nil?
            fan.addToNode(supply_inlet_node)
          end

          # Add the supplemental heating coil
          unless supplemental_htg_coil.nil?
            supplemental_htg_coil.addToNode(supply_inlet_node)
          end

          # Add the heating coil
          unless htg_coil.nil?
            htg_coil.addToNode(supply_inlet_node)
          end

          # Add the cooling coil
          unless clg_coil.nil?
            clg_coil.addToNode(supply_inlet_node)
          end
        elsif fan_location == 'BlowThrough'
          # Add the supplemental heating coil
          unless supplemental_htg_coil.nil?
            supplemental_htg_coil.addToNode(supply_inlet_node)
          end

          # Add the cooling coil
          unless clg_coil.nil?
            clg_coil.addToNode(supply_inlet_node)
          end

          # Add the heating coil
          unless htg_coil.nil?
            htg_coil.addToNode(supply_inlet_node)
          end

          # Add the fan
          unless fan.nil?
            fan.addToNode(supply_inlet_node)
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Invalid fan location')
          return false
        end

        setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(OpenStudio.convert(50, 'F', 'C').get)
        setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(OpenStudio.convert(122, 'F', 'C').get)

      end

      # Add the OA system
      oa_system.addToNode(supply_inlet_node)

      # Attach the nightcycle manager to the supply outlet node
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)
      air_loop.setNightCycleControlType('CycleOnAny')

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{air_loop.name} Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    end

    return air_loops
  end

  # Creates a packaged single zone VAV system for each zone and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param heating_type [Double] valid choices are NaturalGas, Electricity, Water, nil (no heat)
  # @param supplemental_heating_type [Double] valid choices are Electricity, NaturalGas,  nil (no heat)
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] an array of the resulting PSZ-AC air loops
  def model_add_psz_vav(model,
                        sys_name,
                        thermal_zones,
                        hvac_op_sch,
                        oa_damper_sch,
                        heating_type,
                        supplemental_heating_type,
                        building_type = nil)

    # control temps used across all air handlers
    clg_sa_temp_f = 55 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    htg_sa_temp_f = 55 # Central deck htg temp 55F
    rht_sa_temp_f = 104 # VAV box reheat to 104F

    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
    rht_sa_temp_c = OpenStudio.convert(rht_sa_temp_f, 'F', 'C').get

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # Make a PSZ-VAV for each zone
    air_loops = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PSZ-VAV for #{zone.name}.")

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      if sys_name.nil?
        air_loop.setName("#{zone.name} PSZ-VAV")
      else
        air_loop.setName("#{zone.name} #{sys_name}")
      end
      air_loop.setAvailabilitySchedule(hvac_op_sch)
      air_loops << air_loop

      # Sizing
      air_loop_sizing = air_loop.sizingSystem
      air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(0.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(12.8)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(12.8)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(40.0)
      air_loop_sizing.setSizingOption('Coincident')
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(14)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(40.0)

      # Add a setpoint manager single zone reheat to control the
      # supply air temperature based on the needs of this zone
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)

      # Fan
      fan = OpenStudio::Model::FanVariableVolume.new(model, hvac_op_sch)
      fan.setName("#{air_loop.name} Fan")
      fan_static_pressure_in_h2o = 2.5
      fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
      fan.setPressureRise(fan_static_pressure_pa)
      fan.setFanEfficiency(0.54)
      fan.setMotorEfficiency(0.90)

      # Heating coil
      htg_coil = nil
      case heating_type
      when 'NaturalGas', 'Gas'
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
        htg_coil.setName("#{air_loop.name} Gas Htg Coil")
      when nil
        # Zero-capacity, always-off electric heating coil
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule)
        htg_coil.setName("#{air_loop.name} No Heat")
        htg_coil.setNominalCapacity(0)
      when 'Electricity', 'Electric'
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        htg_coil.setName("#{air_loop.name} Electric Htg Coil")
      end

      supplemental_htg_coil = nil
      case supplemental_heating_type
      when 'Electricity', 'Electric' # TODO change spreadsheet to Electricity
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        supplemental_htg_coil.setName("#{air_loop.name} Electric Backup Htg Coil")
      when 'NaturalGas', 'Gas'
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
        supplemental_htg_coil.setName("#{air_loop.name} Gas Backup Htg Coil")
      when nil
        # Zero-capacity, always-off electric heating coil
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule)
        supplemental_htg_coil.setName("#{air_loop.name} No Backup Heat")
        supplemental_htg_coil.setNominalCapacity(0)
      end

      # Cooling coil
      clg_coil = OpenStudio::Model::CoilCoolingDXVariableSpeed.new(model)
      clg_coil.setName("#{air_loop.name} Var spd DX AC Clg Coil")
      clg_coil.setBasinHeaterCapacity(10)
      clg_coil.setBasinHeaterSetpointTemperature(2.0)

      # First speed level
      clg_spd_1 = OpenStudio::Model::CoilCoolingDXVariableSpeedSpeedData.new(model)
      clg_coil.addSpeed(clg_spd_1)

      clg_coil.setNominalSpeedLevel(1)

      # Outdoor air system
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.setName("#{air_loop.name} OA Sys Controller")
      oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
      oa_controller.autosizeMinimumOutdoorAirFlowRate
      oa_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
      oa_system.setName("#{air_loop.name} OA Sys")
      econ_eff_sch = model_add_schedule(model, 'RetailStandalone PSZ_Econ_MaxOAFrac_Sch')

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode

      # Wrap coils in a unitary system
      unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary_system.setSupplyFan(fan)
      unitary_system.setHeatingCoil(htg_coil)
      unitary_system.setCoolingCoil(clg_coil)
      unitary_system.setSupplementalHeatingCoil(supplemental_htg_coil)
      unitary_system.setName("#{zone.name} Unitary PSZ-VAV")
      unitary_system.setString(2, 'SingleZoneVAV') # TODO add setControlType() method
      unitary_system.setControllingZoneorThermostatLocation(zone)
      unitary_system.setMaximumSupplyAirTemperature(50)
      unitary_system.setFanPlacement('BlowThrough')
      unitary_system.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
      unitary_system.setSupplyAirFlowRateMethodDuringHeatingOperation('SupplyAirFlowRate')
      unitary_system.setSupplyAirFlowRateMethodWhenNoCoolingorHeatingisRequired('SupplyAirFlowRate')
      unitary_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOnDiscreteSchedule)
      unitary_system.addToNode(supply_inlet_node)

      # Add the OA system
      oa_system.addToNode(supply_inlet_node)

      # Set up nightcycling
      air_loop.setNightCycleControlType('CycleOnAny')

      # Create a VAV no reheat terminal and attach the zone/terminal pair to the air loop
      diffuser = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{air_loop.name} Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    end

    return air_loops
  end
  
  # Adds a data center load to a given space.
  #
  # @param space [OpenStudio::Model::Space] which space to assign the data center loads to
  # @param dc_watts_per_area [Double] data center load, in W/m^2
  # @return [Bool] returns true if successful, false if not
  def model_add_data_center_load(model, space, dc_watts_per_area)
    # Data center load
    data_center_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    data_center_definition.setName('Data Center Load')
    data_center_definition.setWattsperSpaceFloorArea(dc_watts_per_area)

    data_center_equipment = OpenStudio::Model::ElectricEquipment.new(data_center_definition)
    data_center_equipment.setName('Data Center Load')
    data_center_sch = model.alwaysOnDiscreteSchedule
    data_center_equipment.setSchedule(data_center_sch)
    data_center_equipment.setSpace(space)

    return true
  end

  # Creates a data center PSZ-AC system for each zone.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [String] hot water loop to connect heatin coil to
  # @param heat_pump_loop [String] heat pump water loop to connect heat pump to
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param main_data_center [Bool] whether or not this is the main data
  # center in the building.
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] an array of the resulting air loops
  def model_add_data_center_hvac(model,
                                 sys_name,
                                 hot_water_loop,
                                 heat_pump_loop,
                                 thermal_zones,
                                 hvac_op_sch,
                                 oa_damper_sch,
                                 main_data_center = false)

    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding data center HVAC for #{zone.name}.")
    end

    hw_temp_f = 180 # HW setpoint 180F
    hw_delta_t_r = 20 # 20F delta-T
    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get

    # control temps used across all air handlers
    clg_sa_temp_f = 55 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    htg_sa_temp_f = 55 # Central deck htg temp 55F
    rht_sa_temp_f = 104 # VAV box reheat to 104F

    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
    rht_sa_temp_c = OpenStudio.convert(rht_sa_temp_f, 'F', 'C').get

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # Make a PSZ-AC for each zone
    air_loops = []
    thermal_zones.each do |zone|
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      if sys_name.nil?
        air_loop.setName("#{zone.name} PSZ-AC Data Center")
      else
        air_loop.setName("#{zone.name} #{sys_name}")
      end
      air_loops << air_loop
      air_loop.setAvailabilitySchedule(hvac_op_sch)

      # When an air_loop is contructed, its constructor creates a sizing:system object
      # the default sizing:system contstructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(12.8)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(12.8)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(40.0)
      air_loop_sizing.setSizingOption('Coincident')
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(12.8)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(40.0)

      # Add a setpoint manager single zone reheat to control the
      # supply air temperature based on the needs of this zone
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)

      fan = OpenStudio::Model::FanOnOff.new(model, hvac_op_sch) # Set fan op sch manually since fwd translator doesn't
      fan.setName("#{air_loop.name} Fan")
      fan_static_pressure_in_h2o = 2.5
      fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
      fan.setPressureRise(fan_static_pressure_pa)
      fan.setFanEfficiency(0.54)
      fan.setMotorEfficiency(0.90)

      htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model)
      htg_coil.setName("#{air_loop.name} Water-to-Air HP Htg Coil")
      htg_coil.setRatedHeatingCoefficientofPerformance(4.2) # TODO: add this to standards
      htg_coil.setHeatingCapacityCoefficient1(0.237847462869254)
      htg_coil.setHeatingCapacityCoefficient2(-3.35823796081626)
      htg_coil.setHeatingCapacityCoefficient3(3.80640467406376)
      htg_coil.setHeatingCapacityCoefficient4(0.179200417311554)
      htg_coil.setHeatingCapacityCoefficient5(0.12860719846082)
      htg_coil.setHeatingPowerConsumptionCoefficient1(-3.79175529243238)
      htg_coil.setHeatingPowerConsumptionCoefficient2(3.38799239505527)
      htg_coil.setHeatingPowerConsumptionCoefficient3(1.5022612076303)
      htg_coil.setHeatingPowerConsumptionCoefficient4(-0.177653510577989)
      htg_coil.setHeatingPowerConsumptionCoefficient5(-0.103079864171839)

      heat_pump_loop.addDemandBranchForComponent(htg_coil)

      clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model)
      clg_coil.setName("#{air_loop.name} Water-to-Air HP Clg Coil")
      clg_coil.setRatedCoolingCoefficientofPerformance(3.4) # TODO: add this to standards

      clg_coil.setTotalCoolingCapacityCoefficient1(-4.30266987344639)
      clg_coil.setTotalCoolingCapacityCoefficient2(7.18536990534372)
      clg_coil.setTotalCoolingCapacityCoefficient3(-2.23946714486189)
      clg_coil.setTotalCoolingCapacityCoefficient4(0.139995928440879)
      clg_coil.setTotalCoolingCapacityCoefficient5(0.102660179888915)
      clg_coil.setSensibleCoolingCapacityCoefficient1(6.0019444814887)
      clg_coil.setSensibleCoolingCapacityCoefficient2(22.6300677244073)
      clg_coil.setSensibleCoolingCapacityCoefficient3(-26.7960783730934)
      clg_coil.setSensibleCoolingCapacityCoefficient4(-1.72374720346819)
      clg_coil.setSensibleCoolingCapacityCoefficient5(0.490644802367817)
      clg_coil.setSensibleCoolingCapacityCoefficient6(0.0693119353468141)
      clg_coil.setCoolingPowerConsumptionCoefficient1(-5.67775976415698)
      clg_coil.setCoolingPowerConsumptionCoefficient2(0.438988156976704)
      clg_coil.setCoolingPowerConsumptionCoefficient3(5.845277342193)
      clg_coil.setCoolingPowerConsumptionCoefficient4(0.141605667000125)
      clg_coil.setCoolingPowerConsumptionCoefficient5(-0.168727936032429)

      heat_pump_loop.addDemandBranchForComponent(clg_coil)

      supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
      supplemental_htg_coil.setName("#{air_loop.name} Electric Backup Htg Coil")

      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.setName("#{air_loop.name} OA Sys Controller")
      oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
      oa_controller.autosizeMinimumOutdoorAirFlowRate
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
      oa_system.setName("#{air_loop.name} OA Sys")

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode

      if main_data_center
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100_000)
        humidifier.setName("#{air_loop.name} Electric Steam Humidifier")

        extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        extra_elec_htg_coil.setName("#{air_loop.name} Electric Htg Coil")

        extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
        extra_water_htg_coil.setName("#{air_loop.name} Water Htg Coil")
        extra_water_htg_coil.setRatedInletWaterTemperature(hw_temp_c)
        extra_water_htg_coil.setRatedInletAirTemperature(prehtg_sa_temp_c)
        extra_water_htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        extra_water_htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)

        extra_water_htg_coil.addToNode(supply_inlet_node)
        extra_elec_htg_coil.addToNode(supply_inlet_node)
        humidifier.addToNode(supply_inlet_node)

        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
        humidity_spm.setControlZone(zone)

        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)

        humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
        humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'OfficeLarge DC_MinRelHumSetSch'))
        zone.setZoneControlHumidistat(humidistat)
      end

      unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary_system.setSupplyFan(fan)
      unitary_system.setHeatingCoil(htg_coil)
      unitary_system.setCoolingCoil(clg_coil)
      unitary_system.setSupplementalHeatingCoil(supplemental_htg_coil)

      unitary_system.setName("#{zone.name} Unitary HP")
      unitary_system.setControllingZoneorThermostatLocation(zone)
      unitary_system.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(OpenStudio.convert(40, 'F', 'C').get)
      unitary_system.setFanPlacement('BlowThrough')
      unitary_system.setSupplyAirFanOperatingModeSchedule(hvac_op_sch)
      unitary_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOnDiscreteSchedule)
      unitary_system.addToNode(supply_inlet_node)

      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(OpenStudio.convert(55, 'F', 'C').get)
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(OpenStudio.convert(104, 'F', 'C').get)

      # Add the OA system
      oa_system.addToNode(supply_inlet_node)

      # Attach the nightcycle manager to the supply outlet node
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)
      air_loop.setNightCycleControlType('CycleOnAny')

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{air_loop.name} Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    end

    return air_loops
  end

  # Creates a split DX AC system for each zone and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param fan_type [Double] valid choices are ConstantVolume, Cycling
  # @param heating_type [Double] valid choices are Gas, Single Speed Heat Pump
  # @param supplemental_heating_type [Double] valid choices are Electric, Gas
  # @param cooling_type [String] valid choices are Two Speed DX AC,a
  # Single Speed DX AC, Single Speed Heat Pump
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting split AC air loop.
  def model_add_split_ac(model,
                         sys_name,
                         thermal_zones,
                         hvac_op_sch,
                         oa_damper_sch,
                         fan_type,
                         heating_type,
                         supplemental_heating_type,
                         cooling_type,
                         building_type = nil)

    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding split DX AC for #{zone.name}.")
    end

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # OA_controller Maximum OA Fraction schedule
    econ_max_oa_frac_sch = model_add_schedule(model, 'HotelSmall SAC_Econ_MaxOAFrac_Sch')

    # Make a SAC for each group of thermal zones
    parts = []
    space_type_names = []
    thermal_zones.each do |zone|
      name = zone.name
      parts << name.get
      # get space types
      zone.spaces.each do |space|
        space_type_name = space.spaceType.get.standardsSpaceType.get
        space_type_names << space_type_name
      end

      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(14)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(50.0)
      sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)
      sizing_zone.setZoneHeatingDesignSupplyAirHumidityRatio(0.008)
    end
    thermal_zone_name = parts.join(' - ')

    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    air_loop.setName("#{thermal_zone_name} SAC")
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    # When an air_loop is contructed, its constructor creates a sizing:system object
    # the default sizing:system contstructor makes a system:sizing object
    # appropriate for a multizone VAV system
    # this systems is a constant volume system with no VAV terminals,
    # and therfore needs different default settings
    air_loop_sizing = air_loop.sizingSystem # TODO units
    air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
    air_loop_sizing.autosizeDesignOutdoorAirFlowRate
    air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
    air_loop_sizing.setPreheatDesignTemperature(7.0)
    air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
    air_loop_sizing.setPrecoolDesignTemperature(11)
    air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
    air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(12)
    air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(50)
    air_loop_sizing.setSizingOption('NonCoincident')
    air_loop_sizing.setAllOutdoorAirinCooling(false)
    air_loop_sizing.setAllOutdoorAirinHeating(false)
    air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.008)
    air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
    air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
    air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
    air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
    air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
    air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

    # Add a setpoint manager single zone reheat to control the
    # supply air temperature based on the needs of this zone
    controlzone = thermal_zones[0]
    setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
    setpoint_mgr_single_zone_reheat.setControlZone(controlzone)

    # Fan
    fan = nil
    if fan_type == 'ConstantVolume'
      fan = OpenStudio::Model::FanConstantVolume.new(model, model.alwaysOnDiscreteSchedule)
      fan.setName("#{thermal_zone_name} SAC Fan")
      fan_static_pressure_in_h2o = 2.5
      fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
      fan.setPressureRise(fan_static_pressure_pa)
      fan.setFanEfficiency(0.56) # get the average of four fans
      fan.setMotorEfficiency(0.86) # get the average of four fans
    elsif fan_type == 'Cycling'
      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan.setName("#{thermal_zone_name} SAC Fan")
      fan_static_pressure_in_h2o = 2.5
      fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
      fan.setPressureRise(fan_static_pressure_pa)
      fan.setFanEfficiency(0.53625)
      fan.setMotorEfficiency(0.825)
    end

    # Heating Coil
    htg_coil = nil
    if heating_type == 'Gas'
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
      htg_coil.setName("#{thermal_zone_name} SAC Gas Htg Coil")
      htg_coil.setGasBurnerEfficiency(0.8)
      htg_part_load_fraction_correlation = OpenStudio::Model::CurveCubic.new(model)
      htg_part_load_fraction_correlation.setCoefficient1Constant(0.8)
      htg_part_load_fraction_correlation.setCoefficient2x(0.2)
      htg_part_load_fraction_correlation.setCoefficient3xPOW2(0)
      htg_part_load_fraction_correlation.setCoefficient4xPOW3(0)
      htg_part_load_fraction_correlation.setMinimumValueofx(0)
      htg_part_load_fraction_correlation.setMaximumValueofx(1)
      htg_coil.setPartLoadFractionCorrelationCurve(htg_part_load_fraction_correlation)
    elsif heating_type == 'Single Speed Heat Pump'
      htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
      htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
      htg_cap_f_of_temp.setCoefficient2x(0.027626)
      htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
      htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
      htg_cap_f_of_temp.setMinimumValueofx(-20.0)
      htg_cap_f_of_temp.setMaximumValueofx(20.0)

      htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(model)
      htg_cap_f_of_flow.setCoefficient1Constant(0.84)
      htg_cap_f_of_flow.setCoefficient2x(0.16)
      htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
      htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
      htg_cap_f_of_flow.setMinimumValueofx(0.5)
      htg_cap_f_of_flow.setMaximumValueofx(1.5)

      htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
      htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
      htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
      htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
      htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
      htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
      htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

      htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
      htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
      htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
      htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
      htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

      htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
      htg_part_load_fraction.setCoefficient1Constant(0.85)
      htg_part_load_fraction.setCoefficient2x(0.15)
      htg_part_load_fraction.setCoefficient3xPOW2(0.0)
      htg_part_load_fraction.setMinimumValueofx(0.0)
      htg_part_load_fraction.setMaximumValueofx(1.0)

      htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model,
                                                                 model.alwaysOnDiscreteSchedule,
                                                                 htg_cap_f_of_temp,
                                                                 htg_cap_f_of_flow,
                                                                 htg_energy_input_ratio_f_of_temp,
                                                                 htg_energy_input_ratio_f_of_flow,
                                                                 htg_part_load_fraction)

      htg_coil.setName("#{thermal_zone_name} SAC HP Htg Coil")
    end

    # Supplemental Heating Coil
    supplemental_htg_coil = nil
    if supplemental_heating_type == 'Electric'
      supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
      supplemental_htg_coil.setName("#{thermal_zone_name} PSZ-AC Electric Backup Htg Coil")
    elsif supplemental_heating_type == 'Gas'
      supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
      supplemental_htg_coil.setName("#{thermal_zone_name} PSZ-AC Gas Backup Htg Coil")
    end

    # Cooling Coil
    clg_coil = nil
    if cooling_type == 'Two Speed DX AC'

      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
      clg_cap_f_of_temp.setCoefficient2x(0.04426)
      clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
      clg_cap_f_of_temp.setCoefficient4y(0.00333)
      clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
      clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
      clg_cap_f_of_temp.setMinimumValueofx(17.0)
      clg_cap_f_of_temp.setMaximumValueofx(22.0)
      clg_cap_f_of_temp.setMinimumValueofy(13.0)
      clg_cap_f_of_temp.setMaximumValueofy(46.0)

      clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
      clg_cap_f_of_flow.setCoefficient2x(0.34053)
      clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
      clg_cap_f_of_flow.setMinimumValueofx(0.75918)
      clg_cap_f_of_flow.setMaximumValueofx(1.13877)

      clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
      clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
      clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
      clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
      clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
      clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

      clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
      clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
      clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
      clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
      clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

      clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
      clg_part_load_ratio.setCoefficient1Constant(0.77100)
      clg_part_load_ratio.setCoefficient2x(0.22900)
      clg_part_load_ratio.setCoefficient3xPOW2(0.0)
      clg_part_load_ratio.setMinimumValueofx(0.0)
      clg_part_load_ratio.setMaximumValueofx(1.0)

      clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_cap_f_of_temp_low_spd.setCoefficient1Constant(0.42415)
      clg_cap_f_of_temp_low_spd.setCoefficient2x(0.04426)
      clg_cap_f_of_temp_low_spd.setCoefficient3xPOW2(-0.00042)
      clg_cap_f_of_temp_low_spd.setCoefficient4y(0.00333)
      clg_cap_f_of_temp_low_spd.setCoefficient5yPOW2(-0.00008)
      clg_cap_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00021)
      clg_cap_f_of_temp_low_spd.setMinimumValueofx(17.0)
      clg_cap_f_of_temp_low_spd.setMaximumValueofx(22.0)
      clg_cap_f_of_temp_low_spd.setMinimumValueofy(13.0)
      clg_cap_f_of_temp_low_spd.setMaximumValueofy(46.0)

      clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient1Constant(1.23649)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient2x(-0.02431)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient3xPOW2(0.00057)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient4y(-0.01434)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient5yPOW2(0.00063)
      clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00038)
      clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofx(17.0)
      clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofx(22.0)
      clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofy(13.0)
      clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofy(46.0)

      clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model,
                                                              model.alwaysOnDiscreteSchedule,
                                                              clg_cap_f_of_temp,
                                                              clg_cap_f_of_flow,
                                                              clg_energy_input_ratio_f_of_temp,
                                                              clg_energy_input_ratio_f_of_flow,
                                                              clg_part_load_ratio,
                                                              clg_cap_f_of_temp_low_spd,
                                                              clg_energy_input_ratio_f_of_temp_low_spd)

      clg_coil.setName("#{thermal_zone_name} SAC 2spd DX AC Clg Coil")
      clg_coil.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new(0.69))
      clg_coil.setBasinHeaterCapacity(10)
      clg_coil.setBasinHeaterSetpointTemperature(2.0)

    elsif cooling_type == 'Single Speed DX AC'

      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_cap_f_of_temp.setCoefficient1Constant(0.942587793)
      clg_cap_f_of_temp.setCoefficient2x(0.009543347)
      clg_cap_f_of_temp.setCoefficient3xPOW2(0.00068377)
      clg_cap_f_of_temp.setCoefficient4y(-0.011042676)
      clg_cap_f_of_temp.setCoefficient5yPOW2(0.000005249)
      clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00000972)
      clg_cap_f_of_temp.setMinimumValueofx(12.77778)
      clg_cap_f_of_temp.setMaximumValueofx(23.88889)
      clg_cap_f_of_temp.setMinimumValueofy(23.88889)
      clg_cap_f_of_temp.setMaximumValueofy(46.11111)

      clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_cap_f_of_flow.setCoefficient1Constant(0.8)
      clg_cap_f_of_flow.setCoefficient2x(0.2)
      clg_cap_f_of_flow.setCoefficient3xPOW2(0)
      clg_cap_f_of_flow.setMinimumValueofx(0.5)
      clg_cap_f_of_flow.setMaximumValueofx(1.5)

      clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.342414409)
      clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.034885008)
      clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.0006237)
      clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.004977216)
      clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000437951)
      clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000728028)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofx(12.77778)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofx(23.88889)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofy(23.88889)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.11111)

      clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.1552)
      clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1808)
      clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
      clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
      clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

      clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
      clg_part_load_ratio.setCoefficient1Constant(0.85)
      clg_part_load_ratio.setCoefficient2x(0.15)
      clg_part_load_ratio.setCoefficient3xPOW2(0.0)
      clg_part_load_ratio.setMinimumValueofx(0.0)
      clg_part_load_ratio.setMaximumValueofx(1.0)
      clg_part_load_ratio.setMinimumCurveOutput(0.7)
      clg_part_load_ratio.setMaximumCurveOutput(1.0)

      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                 model.alwaysOnDiscreteSchedule,
                                                                 clg_cap_f_of_temp,
                                                                 clg_cap_f_of_flow,
                                                                 clg_energy_input_ratio_f_of_temp,
                                                                 clg_energy_input_ratio_f_of_flow,
                                                                 clg_part_load_ratio)

      clg_coil.setName("#{thermal_zone_name} SAC 1spd DX AC Clg Coil")

    elsif cooling_type == 'Single Speed Heat Pump'

      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_cap_f_of_temp.setCoefficient1Constant(0.766956)
      clg_cap_f_of_temp.setCoefficient2x(0.0107756)
      clg_cap_f_of_temp.setCoefficient3xPOW2(-0.0000414703)
      clg_cap_f_of_temp.setCoefficient4y(0.00134961)
      clg_cap_f_of_temp.setCoefficient5yPOW2(-0.000261144)
      clg_cap_f_of_temp.setCoefficient6xTIMESY(0.000457488)
      clg_cap_f_of_temp.setMinimumValueofx(12.78)
      clg_cap_f_of_temp.setMaximumValueofx(23.89)
      clg_cap_f_of_temp.setMinimumValueofy(21.1)
      clg_cap_f_of_temp.setMaximumValueofy(46.1)

      clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_cap_f_of_flow.setCoefficient1Constant(0.8)
      clg_cap_f_of_flow.setCoefficient2x(0.2)
      clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
      clg_cap_f_of_flow.setMinimumValueofx(0.5)
      clg_cap_f_of_flow.setMaximumValueofx(1.5)

      clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.297145)
      clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.0430933)
      clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000748766)
      clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.00597727)
      clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000482112)
      clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000956448)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofx(12.78)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofx(23.89)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofy(21.1)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.1)

      clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.156)
      clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1816)
      clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
      clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
      clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

      clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
      clg_part_load_ratio.setCoefficient1Constant(0.85)
      clg_part_load_ratio.setCoefficient2x(0.15)
      clg_part_load_ratio.setCoefficient3xPOW2(0.0)
      clg_part_load_ratio.setMinimumValueofx(0.0)
      clg_part_load_ratio.setMaximumValueofx(1.0)

      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                 model.alwaysOnDiscreteSchedule,
                                                                 clg_cap_f_of_temp,
                                                                 clg_cap_f_of_flow,
                                                                 clg_energy_input_ratio_f_of_temp,
                                                                 clg_energy_input_ratio_f_of_flow,
                                                                 clg_part_load_ratio)

      clg_coil.setName("#{thermal_zone_name} SAC 1spd DX HP Clg Coil")
      # clg_coil.setRatedSensibleHeatRatio(0.69)
      # clg_coil.setBasinHeaterCapacity(10)
      # clg_coil.setBasinHeaterSetpointTemperature(2.0)

    end

    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_controller.setName("#{thermal_zone_name} SAC OA Sys Controller")
    oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_controller.autosizeMinimumOutdoorAirFlowRate
    oa_controller.setMaximumFractionofOutdoorAirSchedule(econ_max_oa_frac_sch)
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
    oa_system.setName("#{thermal_zone_name} SAC OA Sys")

    # Add the components to the air loop
    # in order from closest to zone to furthest from zone
    supply_inlet_node = air_loop.supplyInletNode

    # Add the fan
    unless fan.nil?
      fan.addToNode(supply_inlet_node)
    end

    # Add the supplemental heating coil
    unless supplemental_htg_coil.nil?
      supplemental_htg_coil.addToNode(supply_inlet_node)
    end

    # Add the heating coil
    unless htg_coil.nil?
      htg_coil.addToNode(supply_inlet_node)
    end

    # Add the cooling coil
    unless clg_coil.nil?
      clg_coil.addToNode(supply_inlet_node)
    end

    setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(OpenStudio.convert(55.4, 'F', 'C').get)
    setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(OpenStudio.convert(113, 'F', 'C').get)

    setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

    # Add the OA system
    oa_system.addToNode(supply_inlet_node)

    # Create a diffuser and attach the zone/diffuser pair to the air loop
    thermal_zones.each do |zone|
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{zone.name} SAC Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    end

    return air_loop
  end

  # Creates a PTAC system for each zone and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [String] hot water loop to connect heating coil to.
  #   Set to nil for heating types besides water.
  # @param thermal_zones [String] zones to connect to this system
  # @param fan_type [Double] valid choices are ConstantVolume, Cycling
  # @param heating_type [Double] valid choices are
  # NaturalGas, Electricity, Water, nil (no heat)
  # @param cooling_type [String] valid choices are
  # Two Speed DX AC, Single Speed DX AC
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner>] an
  # array of the resulting PTACs.
  def model_add_ptac(model,
                     sys_name,
                     hot_water_loop,
                     thermal_zones,
                     fan_type,
                     heating_type,
                     cooling_type,
                     building_type = nil)

    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PTAC for #{zone.name}.")
    end

    # schedule: always off
    always_off = OpenStudio::Model::ScheduleRuleset.new(model)
    always_off.setName('ALWAYS_OFF')
    always_off.defaultDaySchedule.setName('ALWAYS_OFF day')
    always_off.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.0)
    always_off.setSummerDesignDaySchedule(always_off.defaultDaySchedule)
    always_off.setWinterDesignDaySchedule(always_off.defaultDaySchedule)

    # Make a PTAC for each zone
    ptacs = []
    thermal_zones.each do |zone|
      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(14)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(50.0)
      sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)
      sizing_zone.setZoneHeatingDesignSupplyAirHumidityRatio(0.008)

      # add fan
      fan = nil
      if fan_type == 'ConstantVolume'
        fan = OpenStudio::Model::FanConstantVolume.new(model, model.alwaysOnDiscreteSchedule)
        fan.setName("#{zone.name} PTAC Fan")
        fan_static_pressure_in_h2o = 1.33
        fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
        fan.setPressureRise(fan_static_pressure_pa)
        fan.setFanEfficiency(0.52)
        fan.setMotorEfficiency(0.8)
      elsif fan_type == 'Cycling'
        fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
        fan.setName("#{zone.name} PTAC Fan")
        fan_static_pressure_in_h2o = 1.33
        fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
        fan.setPressureRise(fan_static_pressure_pa)
        fan.setFanEfficiency(0.52)
        fan.setMotorEfficiency(0.8)
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "ptac_fan_type of #{fan_type} is not recognized.")
      end

      # add heating coil
      htg_coil = nil
      case heating_type
      when 'NaturalGas', 'Gas'
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, model.alwaysOnDiscreteSchedule)
        htg_coil.setName("#{zone.name} PTAC Gas Htg Coil")
      when 'Electricity', 'Electric'
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        htg_coil.setName("#{zone.name} PTAC Electric Htg Coil")
      when nil
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule)
        htg_coil.setName("#{zone.name} PTAC No Heat")
        htg_coil.setNominalCapacity(0)
      when 'Water'
        if hot_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water plant loop supplied')
          return false
        end

        hw_sizing = hot_water_loop.sizingPlant
        hw_temp_c = hw_sizing.designLoopExitTemperature
        hw_delta_t_k = hw_sizing.loopDesignTemperatureDifference

        # Using openstudio defaults for now...
        prehtg_sa_temp_c = 16.6
        htg_sa_temp_c = 32.2

        htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
        htg_coil.setName("#{hot_water_loop.name} Water Htg Coil")
        # None of these temperatures are defined
        htg_coil.setRatedInletWaterTemperature(hw_temp_c)
        htg_coil.setRatedInletAirTemperature(prehtg_sa_temp_c)
        htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(htg_coil)
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "ptac_heating_type of #{heating_type} is not recognized.")
      end

      # add cooling coil
      clg_coil = nil
      if cooling_type == 'Two Speed DX AC'

        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_cap_f_of_temp.setCoefficient1Constant(0.42415)
        clg_cap_f_of_temp.setCoefficient2x(0.04426)
        clg_cap_f_of_temp.setCoefficient3xPOW2(-0.00042)
        clg_cap_f_of_temp.setCoefficient4y(0.00333)
        clg_cap_f_of_temp.setCoefficient5yPOW2(-0.00008)
        clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.00021)
        clg_cap_f_of_temp.setMinimumValueofx(17.0)
        clg_cap_f_of_temp.setMaximumValueofx(22.0)
        clg_cap_f_of_temp.setMinimumValueofy(13.0)
        clg_cap_f_of_temp.setMaximumValueofy(46.0)

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
        clg_cap_f_of_flow.setCoefficient2x(0.34053)
        clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
        clg_cap_f_of_flow.setMinimumValueofx(0.75918)
        clg_cap_f_of_flow.setMaximumValueofx(1.13877)

        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.23649)
        clg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.02431)
        clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00057)
        clg_energy_input_ratio_f_of_temp.setCoefficient4y(-0.01434)
        clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.00063)
        clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.00038)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofx(17.0)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofx(22.0)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofy(13.0)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.0)

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
        clg_part_load_ratio.setCoefficient1Constant(0.77100)
        clg_part_load_ratio.setCoefficient2x(0.22900)
        clg_part_load_ratio.setCoefficient3xPOW2(0.0)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)

        clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_cap_f_of_temp_low_spd.setCoefficient1Constant(0.42415)
        clg_cap_f_of_temp_low_spd.setCoefficient2x(0.04426)
        clg_cap_f_of_temp_low_spd.setCoefficient3xPOW2(-0.00042)
        clg_cap_f_of_temp_low_spd.setCoefficient4y(0.00333)
        clg_cap_f_of_temp_low_spd.setCoefficient5yPOW2(-0.00008)
        clg_cap_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00021)
        clg_cap_f_of_temp_low_spd.setMinimumValueofx(17.0)
        clg_cap_f_of_temp_low_spd.setMaximumValueofx(22.0)
        clg_cap_f_of_temp_low_spd.setMinimumValueofy(13.0)
        clg_cap_f_of_temp_low_spd.setMaximumValueofy(46.0)

        clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient1Constant(1.23649)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient2x(-0.02431)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient3xPOW2(0.00057)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient4y(-0.01434)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient5yPOW2(0.00063)
        clg_energy_input_ratio_f_of_temp_low_spd.setCoefficient6xTIMESY(-0.00038)
        clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofx(17.0)
        clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofx(22.0)
        clg_energy_input_ratio_f_of_temp_low_spd.setMinimumValueofy(13.0)
        clg_energy_input_ratio_f_of_temp_low_spd.setMaximumValueofy(46.0)

        clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(model,
                                                                model.alwaysOnDiscreteSchedule,
                                                                clg_cap_f_of_temp,
                                                                clg_cap_f_of_flow,
                                                                clg_energy_input_ratio_f_of_temp,
                                                                clg_energy_input_ratio_f_of_flow,
                                                                clg_part_load_ratio,
                                                                clg_cap_f_of_temp_low_spd,
                                                                clg_energy_input_ratio_f_of_temp_low_spd)

        clg_coil.setName("#{zone.name} PTAC 2spd DX AC Clg Coil")
        clg_coil.setRatedLowSpeedSensibleHeatRatio(OpenStudio::OptionalDouble.new(0.69))
        clg_coil.setBasinHeaterCapacity(10)
        clg_coil.setBasinHeaterSetpointTemperature(2.0)

      elsif cooling_type == 'Single Speed DX AC' # for small hotel

        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_cap_f_of_temp.setCoefficient1Constant(0.942587793)
        clg_cap_f_of_temp.setCoefficient2x(0.009543347)
        clg_cap_f_of_temp.setCoefficient3xPOW2(0.000683770)
        clg_cap_f_of_temp.setCoefficient4y(-0.011042676)
        clg_cap_f_of_temp.setCoefficient5yPOW2(0.000005249)
        clg_cap_f_of_temp.setCoefficient6xTIMESY(-0.000009720)
        clg_cap_f_of_temp.setMinimumValueofx(12.77778)
        clg_cap_f_of_temp.setMaximumValueofx(23.88889)
        clg_cap_f_of_temp.setMinimumValueofy(18.3)
        clg_cap_f_of_temp.setMaximumValueofy(46.11111)

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_cap_f_of_flow.setCoefficient1Constant(0.8)
        clg_cap_f_of_flow.setCoefficient2x(0.2)
        clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
        clg_cap_f_of_flow.setMinimumValueofx(0.5)
        clg_cap_f_of_flow.setMaximumValueofx(1.5)

        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
        clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.342414409)
        clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.034885008)
        clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000623700)
        clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.004977216)
        clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000437951)
        clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000728028)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofx(12.77778)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofx(23.88889)
        clg_energy_input_ratio_f_of_temp.setMinimumValueofy(18.3)
        clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.11111)

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.1552)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1808)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
        clg_part_load_ratio.setCoefficient1Constant(0.85)
        clg_part_load_ratio.setCoefficient2x(0.15)
        clg_part_load_ratio.setCoefficient3xPOW2(0.0)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)
        clg_part_load_ratio.setMinimumCurveOutput(0.7)
        clg_part_load_ratio.setMaximumCurveOutput(1.0)

        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                   model.alwaysOnDiscreteSchedule,
                                                                   clg_cap_f_of_temp,
                                                                   clg_cap_f_of_flow,
                                                                   clg_energy_input_ratio_f_of_temp,
                                                                   clg_energy_input_ratio_f_of_flow,
                                                                   clg_part_load_ratio)

        clg_coil.setName("#{zone.name} PTAC 1spd DX AC Clg Coil")

      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "ptac_cooling_type of #{heating_type} is not recognized.")
      end

      # Wrap coils in a PTAC system
      ptac_system = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,
                                                                                  model.alwaysOnDiscreteSchedule,
                                                                                  fan,
                                                                                  htg_coil,
                                                                                  clg_coil)

      ptac_system.setName("#{zone.name} PTAC")
      ptac_system.setFanPlacement('DrawThrough')
      if fan_type == 'ConstantVolume'
        ptac_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOnDiscreteSchedule)
      elsif fan_type == 'Cycling'
        ptac_system.setSupplyAirFanOperatingModeSchedule(always_off)
      end
      ptac_system.addToThermalZone(zone)

      ptacs << ptac_system
    end

    return ptacs
  end

  # Creates a PTHP system for each zone and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param fan_type [Double] valid choices are ConstantVolume, Cycling
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner>] an
  # array of the resulting PTACs.
  def model_add_pthp(model,
                     sys_name,
                     thermal_zones,
                     fan_type,
                     building_type = nil)

    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PTHP for #{zone.name}.")
    end

    # schedule: always off
    always_off = OpenStudio::Model::ScheduleRuleset.new(model)
    always_off.setName('ALWAYS_OFF')
    always_off.defaultDaySchedule.setName('ALWAYS_OFF day')
    always_off.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.0)
    always_off.setSummerDesignDaySchedule(always_off.defaultDaySchedule)
    always_off.setWinterDesignDaySchedule(always_off.defaultDaySchedule)

    # Make a PTHP for each zone
    pthps = []
    thermal_zones.each do |zone|
      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(14)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(50.0)
      sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)
      sizing_zone.setZoneHeatingDesignSupplyAirHumidityRatio(0.008)

      # add fan
      fan = nil
      if fan_type == 'ConstantVolume'
        fan = OpenStudio::Model::FanConstantVolume.new(model, model.alwaysOnDiscreteSchedule)
        fan.setName("#{zone.name} PTAC Fan")
        fan_static_pressure_in_h2o = 1.33
        fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
        fan.setPressureRise(fan_static_pressure_pa)
        fan.setFanEfficiency(0.52)
        fan.setMotorEfficiency(0.8)
      elsif fan_type == 'Cycling'
        fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
        fan.setName("#{zone.name} PTAC Fan")
        fan_static_pressure_in_h2o = 1.33
        fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
        fan.setPressureRise(fan_static_pressure_pa)
        fan.setFanEfficiency(0.52)
        fan.setMotorEfficiency(0.8)
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "ptac_fan_type of #{fan_type} is not recognized.")
      end

      # add heating coil
      htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
      htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
      htg_cap_f_of_temp.setCoefficient2x(0.027626)
      htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
      htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
      htg_cap_f_of_temp.setMinimumValueofx(-20.0)
      htg_cap_f_of_temp.setMaximumValueofx(20.0)

      htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(model)
      htg_cap_f_of_flow.setCoefficient1Constant(0.84)
      htg_cap_f_of_flow.setCoefficient2x(0.16)
      htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
      htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
      htg_cap_f_of_flow.setMinimumValueofx(0.5)
      htg_cap_f_of_flow.setMaximumValueofx(1.5)

      htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(model)
      htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
      htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
      htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
      htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
      htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
      htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

      htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
      htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
      htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
      htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
      htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

      htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(model)
      htg_part_load_fraction.setCoefficient1Constant(0.85)
      htg_part_load_fraction.setCoefficient2x(0.15)
      htg_part_load_fraction.setCoefficient3xPOW2(0.0)
      htg_part_load_fraction.setMinimumValueofx(0.0)
      htg_part_load_fraction.setMaximumValueofx(1.0)

      htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model,
                                                                 model.alwaysOnDiscreteSchedule,
                                                                 htg_cap_f_of_temp,
                                                                 htg_cap_f_of_flow,
                                                                 htg_energy_input_ratio_f_of_temp,
                                                                 htg_energy_input_ratio_f_of_flow,
                                                                 htg_part_load_fraction)

      htg_coil.setName("#{zone.name} PTHP Htg Coil")

      # add cooling coil
      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_cap_f_of_temp.setCoefficient1Constant(0.766956)
      clg_cap_f_of_temp.setCoefficient2x(0.0107756)
      clg_cap_f_of_temp.setCoefficient3xPOW2(-0.0000414703)
      clg_cap_f_of_temp.setCoefficient4y(0.00134961)
      clg_cap_f_of_temp.setCoefficient5yPOW2(-0.000261144)
      clg_cap_f_of_temp.setCoefficient6xTIMESY(0.000457488)
      clg_cap_f_of_temp.setMinimumValueofx(12.78)
      clg_cap_f_of_temp.setMaximumValueofx(23.89)
      clg_cap_f_of_temp.setMinimumValueofy(21.1)
      clg_cap_f_of_temp.setMaximumValueofy(46.1)

      clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_cap_f_of_flow.setCoefficient1Constant(0.8)
      clg_cap_f_of_flow.setCoefficient2x(0.2)
      clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
      clg_cap_f_of_flow.setMinimumValueofx(0.5)
      clg_cap_f_of_flow.setMaximumValueofx(1.5)

      clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      clg_energy_input_ratio_f_of_temp.setCoefficient1Constant(0.297145)
      clg_energy_input_ratio_f_of_temp.setCoefficient2x(0.0430933)
      clg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(-0.000748766)
      clg_energy_input_ratio_f_of_temp.setCoefficient4y(0.00597727)
      clg_energy_input_ratio_f_of_temp.setCoefficient5yPOW2(0.000482112)
      clg_energy_input_ratio_f_of_temp.setCoefficient6xTIMESY(-0.000956448)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofx(12.78)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofx(23.89)
      clg_energy_input_ratio_f_of_temp.setMinimumValueofy(21.1)
      clg_energy_input_ratio_f_of_temp.setMaximumValueofy(46.1)

      clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(model)
      clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.156)
      clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1816)
      clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
      clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
      clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

      clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(model)
      clg_part_load_ratio.setCoefficient1Constant(0.85)
      clg_part_load_ratio.setCoefficient2x(0.15)
      clg_part_load_ratio.setCoefficient3xPOW2(0.0)
      clg_part_load_ratio.setMinimumValueofx(0.0)
      clg_part_load_ratio.setMaximumValueofx(1.0)

      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                 model.alwaysOnDiscreteSchedule,
                                                                 clg_cap_f_of_temp,
                                                                 clg_cap_f_of_flow,
                                                                 clg_energy_input_ratio_f_of_temp,
                                                                 clg_energy_input_ratio_f_of_flow,
                                                                 clg_part_load_ratio)

      clg_coil.setName("#{zone.name} PTHP Clg Coil")
      # clg_coil.setRatedSensibleHeatRatio(0.69)
      # clg_coil.setBasinHeaterCapacity(10)
      # clg_coil.setBasinHeaterSetpointTemperature(2.0)

      # Supplemental heating coil
      supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)

      # Wrap coils in a PTHP system
      pthp_system = OpenStudio::Model::ZoneHVACPackagedTerminalHeatPump.new(model,
                                                                            model.alwaysOnDiscreteSchedule,
                                                                            fan,
                                                                            htg_coil,
                                                                            clg_coil,
                                                                            supplemental_htg_coil)

      pthp_system.setName("#{zone.name} PTHP")
      pthp_system.setFanPlacement('DrawThrough')
      if fan_type == 'ConstantVolume'
        pthp_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOnDiscreteSchedule)
      elsif fan_type == 'Cycling'
        pthp_system.setSupplyAirFanOperatingModeSchedule(always_off)
      end
      pthp_system.addToThermalZone(zone)

      pthps << pthp_system
    end

    return pthps
  end

  # Creates a unit heater for each zone and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param fan_control_type [Double] valid choices are Continuous, OnOff, Cycling
  # @param fan_pressure_rise [Double] fan pressure rise, in Pa
  # @param heating_type [Double] valid choices are
  # NaturalGas, Electricity, DistrictHeating
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::ZoneHVACUnitHeater>] an
  # array of the resulting unit heaters.
  def model_add_unitheater(model,
                           sys_name,
                           thermal_zones,
                           hvac_op_sch,
                           fan_control_type,
                           fan_pressure_rise,
                           heating_type,
                           hot_water_loop = nil,
                           building_type = nil)

    # Control temps for HW loop
    # will only be used when hot_water_loop is provided.
    hw_temp_f = 180 # HW setpoint 180F
    hw_delta_t_r = 20 # 20F delta-T
    htg_sa_temp_f = 100 # 100F air from unit heaters
    zn_temp_f = 60 # 60F entering unit heater from zone

    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
    zn_temp_c = OpenStudio.convert(zn_temp_f, 'F', 'C').get

    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding split unit heater for #{zone.name}.")
    end

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # Make a unit heater for each zone
    unit_heaters = []
    thermal_zones.each do |zone|
      # Zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(14)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(50.0)
      sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)
      sizing_zone.setZoneHeatingDesignSupplyAirHumidityRatio(0.008)

      # add fan
      fan = OpenStudio::Model::FanConstantVolume.new(model, hvac_op_sch)
      fan.setName("#{zone.name} UnitHeater Fan")
      fan.setPressureRise(fan_pressure_rise)
      fan.setFanEfficiency(0.53625)
      fan.setMotorEfficiency(0.825)

      # add heating coil
      htg_coil = nil
      if heating_type == 'NaturalGas' || heating_type == 'Gas'
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, hvac_op_sch)
        htg_coil.setName("#{zone.name} UnitHeater Gas Htg Coil")
      elsif heating_type == 'Electricity' || heating_type == 'Electric'
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, hvac_op_sch)
        htg_coil.setName("#{zone.name} UnitHeater Electric Htg Coil")
      elsif heating_type == 'DistrictHeating' && !hot_water_loop.nil?
        htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
        htg_coil.setName("#{zone.name} UnitHeater Water Htg Coil")
        htg_coil.setRatedInletWaterTemperature(hw_temp_c)
        htg_coil.setRatedInletAirTemperature(zn_temp_c)
        htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(htg_coil)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', 'No heating type was found when adding unit heater; no unit heater will be created.')
        return false
      end

      unit_heater = OpenStudio::Model::ZoneHVACUnitHeater.new(model,
                                                              hvac_op_sch,
                                                              fan,
                                                              htg_coil)
      unit_heater.setName("#{zone.name} UnitHeater")
      unit_heater.setFanControlType(fan_control_type)
      unit_heater.addToThermalZone(zone)
      unit_heaters << unit_heater
    end

    return unit_heaters
  end

  # Creates a high temp radiant heater for each zone and adds it to the model.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param heating_type [Double] valid choices are
  # Gas, Electric
  # @param combustion_efficiency [Double] combustion efficiency as decimal
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::ZoneHVACHighTemperatureRadiant>] an
  # array of the resulting radiant heaters.
  def model_add_high_temp_radiant(model,
                                  sys_name,
                                  thermal_zones,
                                  heating_type,
                                  combustion_efficiency,
                                  building_type = nil)

    # Make a high temp radiant heater for each zone
    rad_heaters = []
    thermal_zones.each do |zone|
      high_temp_radiant = OpenStudio::Model::ZoneHVACHighTemperatureRadiant.new(model)
      high_temp_radiant.setName("#{zone.name} High Temp Radiant")
      high_temp_radiant.setFuelType(heating_type)
      high_temp_radiant.setCombustionEfficiency(combustion_efficiency)
      high_temp_radiant.setTemperatureControlType(control_type)
      high_temp_radiant.setFractionofInputConvertedtoRadiantEnergy(0.8)
      high_temp_radiant.setHeatingThrottlingRange(2)
      high_temp_radiant.addToThermalZone(zone)
      rad_heaters << high_temp_radiant
    end

    return rad_heaters
  end

  # Creates an evaporative cooler for each zone and adds it to the model.
  #
  # @param thermal_zones [String] zones to connect to this system
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] the resulting evaporative coolers
  def model_add_evap_cooler(model,
                            thermal_zones,
                            building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding evaporative coolers for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # Evap cooler control temperatures
    min_sa_temp_f = 55
    clg_sa_temp_f = 70
    max_sa_temp_f = 78
    htg_sa_temp_f = 122 # Not used

    min_sa_temp_c = OpenStudio.convert(min_sa_temp_f, 'F', 'C').get
    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    max_sa_temp_c = OpenStudio.convert(max_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get

    approach_r = 3 # WetBulb approach
    approach_k = OpenStudio.convert(approach_r, 'R', 'K').get

    fan_static_pressure_in_h2o = 0.25
    fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get

    # EMS programs
    programs = []

    # Make an evap cooler for each zone
    evap_coolers = []
    thermal_zones.each do |zone|
      zone_name_clean = zone.name.get.delete(':')

      # Air loop
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName("#{zone_name_clean} Evap Cooler")

      # Schedule to control the airloop availability
      air_loop_avail_sch = OpenStudio::Model::ScheduleConstant.new(model)
      air_loop_avail_sch.setName("#{air_loop.name} Availability Sch")
      air_loop_avail_sch.setValue(1)
      air_loop.setAvailabilitySchedule(air_loop_avail_sch)

      # EMS to turn on Evap Cooler if
      # there is a cooling load in the target zone.
      # Without this EMS, the airloop runs 24/7-365,
      # even when there is no load in the zone.

      # Create a sensor to read the zone load
      zn_load_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Predicted Sensible Load to Cooling Setpoint Heat Transfer Rate')
      zn_load_sensor.setName("#{zone_name_clean} Clg Load Sensor")
      zn_load_sensor.setKeyName(zone.handle.to_s)

      # Create an actuator to set the airloop availability
      air_loop_avail_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(air_loop_avail_sch, 'Schedule:Constant', 'Schedule Value')
      air_loop_avail_actuator.setName("#{air_loop.name} Availability Actuator")

      # Create a program to turn on Evap Cooler if
      # there is a cooling load in the target zone.
      # Load < 0.0 is a cooling load.
      avail_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      avail_program.setName("#{air_loop.name} Availability Control")
      avail_program_body = <<-EMS
        IF #{zn_load_sensor.handle} < 0.0
          SET #{air_loop_avail_actuator.handle} = 1
        ELSE
          SET #{air_loop_avail_actuator.handle} = 0
        ENDIF
      EMS
      avail_program.setBody(avail_program_body)

      programs << avail_program

      # Setpoint follows OAT WetBulb
      evap_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
      evap_stpt_manager.setName("#{approach_r} F above OATwb")
      evap_stpt_manager.setReferenceTemperatureType('OutdoorAirWetBulb')
      evap_stpt_manager.setMaximumSetpointTemperature(max_sa_temp_c)
      evap_stpt_manager.setMinimumSetpointTemperature(min_sa_temp_c)
      evap_stpt_manager.setOffsetTemperatureDifference(approach_k)
      evap_stpt_manager.addToNode(air_loop.supplyOutletNode)

      # Air handler sizing
      sizing_system = air_loop.sizingSystem
      sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
      sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_sa_temp_c)
      sizing_system.setAllOutdoorAirinCooling(true)
      sizing_system.setAllOutdoorAirinHeating(true)
      sizing_system.setSystemOutdoorAirMethod('ZoneSum')

      # Direct Evap Cooler
      # TODO better assumptions for evap cooler performance
      # and fan pressure rise
      evap = OpenStudio::Model::EvaporativeCoolerDirectResearchSpecial.new(model, model.alwaysOnDiscreteSchedule)
      evap.setName("#{zone.name} Evap Media")
      evap.autosizePrimaryAirDesignFlowRate
      evap.addToNode(air_loop.supplyInletNode)

      # Fan (cycling), must be inside unitary system to cycle on airloop
      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan.setName("#{zone.name} Evap Cooler Supply Fan")
      fan.setFanEfficiency(0.55)
      fan.setPressureRise(fan_static_pressure_pa)

      # Dummy zero-capacity cooling coil
      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model)
      clg_coil.setName('Zero-capacity DX Coil')
      clg_coil.setAvailabilitySchedule(alwaysOffDiscreteSchedule)

      unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary_system.setName("#{zone.name} Evap Cooler Cycling Fan")
      unitary_system.setSupplyFan(fan)
      unitary_system.setCoolingCoil(clg_coil)
      unitary_system.setControllingZoneorThermostatLocation(zone)
      unitary_system.setMaximumSupplyAirTemperature(50)
      unitary_system.setFanPlacement('BlowThrough')
      unitary_system.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
      unitary_system.setSupplyAirFlowRateMethodDuringHeatingOperation('SupplyAirFlowRate')
      unitary_system.setSupplyAirFlowRateMethodWhenNoCoolingorHeatingisRequired('SupplyAirFlowRate')
      unitary_system.setSupplyAirFanOperatingModeSchedule(alwaysOffDiscreteSchedule)
      unitary_system.addToNode(air_loop.supplyInletNode)

      # Outdoor air intake system
      oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_intake_controller.setName("#{air_loop.name} OA Controller")
      oa_intake_controller.setMinimumLimitType('FixedMinimum')
      oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
      oa_intake_controller.setMinimumFractionofOutdoorAirSchedule(model.alwaysOnDiscreteSchedule)

      controller_mv = oa_intake_controller.controllerMechanicalVentilation
      controller_mv.setName("#{air_loop.name} Vent Controller")
      controller_mv.setSystemOutdoorAirMethod('ZoneSum')

      oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
      oa_intake.setName("#{air_loop.name} OA Sys")
      oa_intake.addToNode(air_loop.supplyInletNode)

      # make an air terminal for the zone
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      air_terminal.setName("#{zone.name} Air Terminal")

      # attach new terminal to the zone and to the airloop
      air_loop.addBranchForZone(zone, air_terminal.to_StraightComponent)

      sizing_zone = zone.sizingZone
      sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
      sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(clg_sa_temp_c)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(htg_sa_temp_c)

      evap_coolers << air_loop
    end

    # Create a programcallingmanager
    avail_pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    avail_pcm.setName('Evap Cooler Availability Program Calling Manager')
    avail_pcm.setCallingPoint('AfterPredictorAfterHVACManagers')
    programs.each do |program|
      avail_pcm.addProgram(program)
    end

    return evap_coolers
  end

  # Creates a service water heating loop.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
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
                         sys_name,
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

    if sys_name.nil?
      service_water_loop.setName('Service Water Loop')
    else
      service_water_loop.setName(sys_name)
    end

    # Temperature schedule type limits
    temp_sch_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
    temp_sch_type_limits.setName('Temperature Schedule Type Limits')
    temp_sch_type_limits.setLowerLimitValue(0.0)
    temp_sch_type_limits.setUpperLimitValue(100.0)
    temp_sch_type_limits.setNumericType('Continuous')
    temp_sch_type_limits.setUnitType('Temperature')

    # Service water heating loop controls
    swh_temp_c = service_water_temperature
    swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
    swh_delta_t_r = 9 # 9F delta-T
    swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
    swh_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    swh_temp_sch.setName("Service Water Loop Temp - #{swh_temp_f.round}F")
    swh_temp_sch.defaultDaySchedule.setName("Service Water Loop Temp - #{swh_temp_f.round}F Default")
    swh_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), swh_temp_c)
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
                                          water_heater_thermal_zone,
                                          building_type)

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

  # Determine the type of SWH pump that
  # a model will have.  Defaults to ConstantSpeed.
  # @return [String] the SWH pump type: ConstantSpeed, VariableSpeed
  def model_swh_pump_type(model, building_type)
    swh_pump_type = 'ConstantSpeed'
    return swh_pump_type
  end

  # Creates a water heater and attaches it to the supplied
  # service water heating loop.
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
  # @param building_type [String] the building type
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
                             water_heater_thermal_zone,
                             building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding water heater')

    # Water heater
    # TODO Standards - Change water heater methodology to follow
    # 'Model Enhancements Appendix A.'
    water_heater_capacity_btu_per_hr = OpenStudio.convert(water_heater_capacity, 'W', 'Btu/hr').get
    water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'kBtu/hr').get
    water_heater_vol_gal = OpenStudio.convert(water_heater_volume, 'm^3', 'gal').get

    # Temperature schedule type limits
    temp_sch_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
    temp_sch_type_limits.setName('Temperature Schedule Type Limits')
    temp_sch_type_limits.setLowerLimitValue(0.0)
    temp_sch_type_limits.setUpperLimitValue(100.0)
    temp_sch_type_limits.setNumericType('Continuous')
    temp_sch_type_limits.setUnitType('Temperature')

    if swh_temp_sch.nil?
      # Service water heating loop controls
      swh_temp_c = service_water_temperature
      swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
      swh_delta_t_r = 9 # 9F delta-T
      swh_temp_c = OpenStudio.convert(swh_temp_f, 'F', 'C').get
      swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
      swh_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      swh_temp_sch.setName("Service Water Loop Temp - #{swh_temp_f.round}F")
      swh_temp_sch.defaultDaySchedule.setName("Service Water Loop Temp - #{swh_temp_f.round}F Default")
      swh_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), swh_temp_c)
      swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
    end

    # Water heater depends on the fuel type
    water_heater = OpenStudio::Model::WaterHeaterMixed.new(model)
    water_heater.setName("#{water_heater_vol_gal.round}gal #{water_heater_fuel} Water Heater - #{water_heater_capacity_kbtu_per_hr.round}kBtu/hr")
    water_heater.setTankVolume(OpenStudio.convert(water_heater_vol_gal, 'gal', 'm^3').get)
    water_heater.setSetpointTemperatureSchedule(swh_temp_sch)

    if water_heater_thermal_zone.nil?
      # Assume the water heater is indoors at 70F for now
      default_water_heater_ambient_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      default_water_heater_ambient_temp_sch.setName('Water Heater Ambient Temp Schedule - 70F')
      default_water_heater_ambient_temp_sch.defaultDaySchedule.setName('Water Heater Ambient Temp Schedule - 70F Default')
      default_water_heater_ambient_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), OpenStudio.convert(70, 'F', 'C').get)
      default_water_heater_ambient_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
      water_heater.setAmbientTemperatureIndicator('Schedule')
      water_heater.setAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
    else
      water_heater.setAmbientTemperatureIndicator('ThermalZone')
      water_heater.setAmbientTemperatureThermalZone water_heater_thermal_zone
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
    temp_sch_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
    temp_sch_type_limits.setName('Temperature Schedule Type Limits')
    temp_sch_type_limits.setLowerLimitValue(0.0)
    temp_sch_type_limits.setUpperLimitValue(100.0)
    temp_sch_type_limits.setNumericType('Continuous')
    temp_sch_type_limits.setUnitType('Temperature')

    # Service water heating loop controls
    swh_temp_c = booster_water_temperature
    swh_temp_f = OpenStudio.convert(swh_temp_c, 'C', 'F').get
    swh_delta_t_r = 9 # 9F delta-T
    swh_delta_t_k = OpenStudio.convert(swh_delta_t_r, 'R', 'K').get
    swh_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    swh_temp_sch.setName("Service Water Booster Temp - #{swh_temp_f}F")
    swh_temp_sch.defaultDaySchedule.setName("Service Water Booster Temp - #{swh_temp_f}F Default")
    swh_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), swh_temp_c)
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
      default_water_heater_ambient_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      default_water_heater_ambient_temp_sch.setName('Water Heater Ambient Temp Schedule - 70F')
      default_water_heater_ambient_temp_sch.defaultDaySchedule.setName('Water Heater Ambient Temp Schedule - 70F Default')
      default_water_heater_ambient_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), OpenStudio.convert(70, 'F', 'C').get)
      default_water_heater_ambient_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
      water_heater.setAmbientTemperatureIndicator('Schedule')
      water_heater.setAmbientTemperatureSchedule(default_water_heater_ambient_temp_sch)
    else
      water_heater.setAmbientTemperatureIndicator('ThermalZone')
      water_heater.setAmbientTemperatureThermalZone booster_water_heater_thermal_zone
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
    # water_use_sensible_frac_sch = OpenStudio::Model::ScheduleConstant.new(self)
    # water_use_sensible_frac_sch.setValue(0.2)
    # water_use_latent_frac_sch = OpenStudio::Model::ScheduleConstant.new(self)
    # water_use_latent_frac_sch.setValue(0.05)
    water_use_sensible_frac_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    water_use_sensible_frac_sch.setName("Fraction Sensible - #{frac_sensible}")
    water_use_sensible_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), frac_sensible)
    water_use_latent_frac_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    water_use_latent_frac_sch.setName("Fraction Latent - #{frac_latent}")
    water_use_latent_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), frac_latent)
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    water_fixture_def.setName("#{use_name.capitalize} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    # Target mixed water temperature
    mixed_water_temp_f = OpenStudio.convert(water_use_temperature, 'C', 'F').get
    mixed_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    mixed_water_temp_sch.setName("Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F")
    mixed_water_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get)
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

    # water_use_sensible_frac_sch = OpenStudio::Model::ScheduleConstant.new(self)
    # water_use_sensible_frac_sch.setValue(0.2)
    # water_use_latent_frac_sch = OpenStudio::Model::ScheduleConstant.new(self)
    # water_use_latent_frac_sch.setValue(0.05)
    water_use_sensible_frac_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    water_use_sensible_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
    water_use_latent_frac_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    water_use_latent_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.05)
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    water_fixture_def.setName("#{space_name.capitalize} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    # Target mixed water temperature
    mixed_water_temp_c = data['service_water_heating_target_temperature']
    mixed_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    mixed_water_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), mixed_water_temp_c)
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
    mixed_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    mixed_water_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get)
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

  # Creates a DOAS system with fan coil units
  # for each zone.
  #
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [String] hot water loop to connect heating and zone fan coils to
  # @param chilled_water_loop [String] chilled water loop to connect cooling coil to
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param fan_max_flow_rate [Double] fan maximum flow rate, in m^3/s.
  # if nil, this value will be autosized.
  # @param economizer_control_type [String] valid choices are
  # FixedDryBulb,
  # @param building_type [String] the building type
  # @param energy_recovery [Bool] if true, an ERV will be added to the
  # DOAS system.
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting DOAS air loop
  def model_add_doas(model,
                     sys_name,
                     hot_water_loop,
                     chilled_water_loop,
                     thermal_zones,
                     hvac_op_sch,
                     oa_damper_sch,
                     fan_max_flow_rate,
                     economizer_control_type,
                     building_type = nil,
                     energy_recovery = false)

    # Check the total OA requirement for all zones on the system
    tot_oa_req = 0
    thermal_zones.each do |zone|
      tot_oa_req += thermal_zone_outdoor_airflow_rate(zone)
      break if tot_oa_req > 0
    end

    # If the total OA requirement is zero do not add the DOAS system
    # because the simulations will fail.
    if tot_oa_req.zero?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Not adding DOAS system for #{thermal_zones.size} zones because combined OA requirement for all zones is zero.")
      thermal_zones.each do |zone|
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
      end
      return false
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding DOAS system for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # DOAS Controls

    # Reset SAT down to 55F during hotter outdoor
    # conditions for humidity management
    lo_oat_f = 60
    sat_at_lo_oat_f = 60
    hi_oat_f = 70
    sat_at_hi_oat_f = 55
    lo_oat_c = OpenStudio.convert(lo_oat_f, 'F', 'C').get
    hi_oat_c = OpenStudio.convert(hi_oat_f, 'F', 'C').get
    sat_at_lo_oat_c = OpenStudio.convert(sat_at_lo_oat_f, 'F', 'C').get
    sat_at_hi_oat_c = OpenStudio.convert(sat_at_hi_oat_f, 'F', 'C').get

    # Create a setpoint manager
    sat_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
    sat_oa_reset.setName('DOAS SAT Reset')
    sat_oa_reset.setControlVariable('Temperature')
    sat_oa_reset.setSetpointatOutdoorLowTemperature(sat_at_lo_oat_c)
    sat_oa_reset.setOutdoorLowTemperature(lo_oat_c)
    sat_oa_reset.setSetpointatOutdoorHighTemperature(sat_at_hi_oat_c)
    sat_oa_reset.setOutdoorHighTemperature(hi_oat_c)

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    model.alwaysOnDiscreteSchedule
                  else
                    model_add_schedule(model, hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      model.alwaysOnDiscreteSchedule
                    else
                      model_add_schedule(model, oa_damper_sch)
                    end

    # DOAS
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone DOAS")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setNightCycleControlType('CycleOnAny')
    # modify system sizing properties
    sizing_system = air_loop.sizingSystem
    # set central heating and cooling temperatures for sizing
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(sat_at_hi_oat_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(sat_at_lo_oat_c)
    sizing_system.setSizingOption('Coincident')
    # load specification
    sizing_system.setTypeofLoadtoSizeOn('VentilationRequirement')
    sizing_system.setAllOutdoorAirinCooling(true)
    sizing_system.setAllOutdoorAirinHeating(true)
    sizing_system.setMinimumSystemAirFlowRatio(0.3)

    # set availability schedule
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    # get the supply air inlet node
    airloop_supply_inlet = air_loop.supplyInletNode

    # create air loop fan
    # constant speed fan
    fan_static_pressure_in_h2o = 2.5
    fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
    fan = OpenStudio::Model::FanConstantVolume.new(model, model.alwaysOnDiscreteSchedule)
    fan.setName('DOAS Fan')
    fan.setFanEfficiency(0.58175)
    fan.setPressureRise(fan_static_pressure_pa)
    if fan_max_flow_rate.nil?
      fan.autosizeMaximumFlowRate
    else
      fan.setMaximumFlowRate(OpenStudio.convert(fan_max_flow_rate, 'cfm', 'm^3/s').get) # unit of fan_max_flow_rate is cfm
    end
    fan.setMotorEfficiency(0.895)
    fan.setMotorInAirstreamFraction(1.0)
    fan.setEndUseSubcategory('DOAS Fans')
    fan.addToNode(airloop_supply_inlet)

    # create heating coil
    # water coil
    heating_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
    hot_water_loop.addDemandBranchForComponent(heating_coil)
    heating_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
    heating_coil.addToNode(airloop_supply_inlet)
    heating_coil.controllerWaterCoil.get.setControllerConvergenceTolerance(0.0001)

    # create cooling coil
    # water coil
    cooling_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
    chilled_water_loop.addDemandBranchForComponent(cooling_coil)
    cooling_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
    cooling_coil.addToNode(airloop_supply_inlet)

    # create controller outdoor air
    controller_oa = OpenStudio::Model::ControllerOutdoorAir.new(model)
    controller_oa.setName('DOAS OA Controller')
    controller_oa.setEconomizerControlType(economizer_control_type)
    controller_oa.setMinimumLimitType('FixedMinimum')
    controller_oa.autosizeMinimumOutdoorAirFlowRate
    controller_oa.setMinimumOutdoorAirSchedule(oa_damper_sch)
    controller_oa.resetEconomizerMaximumLimitDryBulbTemperature
    # TODO: Yixing read the schedule from the Prototype Input
    if building_type == 'LargeHotel'
      controller_oa.setMinimumFractionofOutdoorAirSchedule(model_add_schedule(model, 'HotelLarge FLR_3_DOAS_OAminOAFracSchedule'))
    end
    controller_oa.resetEconomizerMaximumLimitEnthalpy
    controller_oa.resetMaximumFractionofOutdoorAirSchedule
    controller_oa.resetEconomizerMinimumLimitDryBulbTemperature

    # create ventilation schedules and assign to OA controller
    controller_oa.setHeatRecoveryBypassControlType('BypassWhenWithinEconomizerLimits')

    # create outdoor air system
    system_oa = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, controller_oa)
    system_oa.addToNode(airloop_supply_inlet)

    # add setpoint manager to supply equipment outlet node
    sat_oa_reset.addToNode(air_loop.supplyOutletNode)

    # ERV, if requested
    if energy_recovery
      # Get the OA system and its outboard OA node
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      oa_node = oa_system.outboardOANode.get

      # Create the ERV and set its properties
      erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
      erv.addToNode(oa_node)
      erv.setHeatExchangerType('Rotary')
      # TODO: Come up with scheme for estimating power of ERV motor wheel
      # which might require knowing airlow (like prototype buildings do).
      # erv.setNominalElectricPower(value_new)
      erv.setEconomizerLockout(true)
      erv.setSupplyAirOutletTemperatureControl(false)

      erv.setSensibleEffectivenessat100HeatingAirFlow(0.76)
      erv.setSensibleEffectivenessat75HeatingAirFlow(0.81)
      erv.setLatentEffectivenessat100HeatingAirFlow(0.68)
      erv.setLatentEffectivenessat75HeatingAirFlow(0.73)

      erv.setSensibleEffectivenessat100CoolingAirFlow(0.76)
      erv.setSensibleEffectivenessat75CoolingAirFlow(0.81)
      erv.setLatentEffectivenessat100CoolingAirFlow(0.68)
      erv.setLatentEffectivenessat75CoolingAirFlow(0.73)

      # Increase fan pressure caused by the ERV
      fans = []
      fans += air_loop.supplyComponents('OS:Fan:VariableVolume'.to_IddObjectType)
      fans += air_loop.supplyComponents('OS:Fan:ConstantVolume'.to_IddObjectType)
      unless fans.empty?
        if fans[0].to_FanConstantVolume.is_initialized
          fans[0].to_FanConstantVolume.get.setPressureRise(OpenStudio.convert(1.0, 'inH_{2}O', 'Pa').get)
        elsif fans[0].to_FanVariableVolume.is_initialized
          fans[0].to_FanVariableVolume.get.setPressureRise(OpenStudio.convert(1.0, 'inH_{2}O', 'Pa').get)
        end
      end
    end

    # add thermal zones to airloop
    thermal_zones.each do |zone|
      zone_name = zone.name.to_s

      # Ensure that zone sizing accounts for DOAS
      zone_sizing = zone.sizingZone
      zone_sizing.setAccountforDedicatedOutdoorAirSystem(true)
      zone_sizing.setDedicatedOutdoorAirSystemControlStrategy('ColdSupplyAir')
      zone_sizing.setDedicatedOutdoorAirLowSetpointTemperatureforDesign(sat_at_hi_oat_c)
      zone_sizing.setDedicatedOutdoorAirHighSetpointTemperatureforDesign(sat_at_lo_oat_c)

      # make an air terminal for the zone
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      air_terminal.setName(zone_name + 'Air Terminal')

      # attach new terminal to the zone and to the airloop
      air_loop.addBranchForZone(zone, air_terminal.to_StraightComponent)
    end

    return air_loop
  end

  # Adds hydronic or electric baseboard heating to each zone.
  #
  # @param hot_water_loop [OpenStudio::Model::PlantLoop]
  # the hot water loop that serves the baseboards.  If nil, baseboards are electric.
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add baseboards to.
  # @return [Array<OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric, OpenStudio::Model::ZoneHVACBaseboardConvectiveWater>]
  # array of baseboard heaters.
  def model_add_baseboard(model,
                          hot_water_loop,
                          thermal_zones)

    # Make a baseboard heater for each zone
    baseboards = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding baseboard heat for #{zone.name}.")

      if hot_water_loop.nil?
        baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        baseboard.setName("#{zone.name} Electric Baseboard")
        baseboard.addToThermalZone(zone)
        baseboards << baseboard
      else
        htg_coil = OpenStudio::Model::CoilHeatingWaterBaseboard.new(model)
        htg_coil.setName("#{zone.name} Hydronic Baseboard Coil")
        hot_water_loop.addDemandBranchForComponent(htg_coil)
        baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveWater.new(model, model.alwaysOnDiscreteSchedule, htg_coil)
        baseboard.setName("#{zone.name} Hydronic Baseboard")
        baseboard.addToThermalZone(zone)
        baseboards << baseboard
      end
    end

    return baseboards
  end

  # Adds four pipe fan coil units to each zone.
  #
  # @param hot_water_loop [OpenStudio::Model::PlantLoop]
  # the hot water loop that serves the fan coils.  If nil, a zero-capacity,
  # electric heating coil set to Always-Off will be included in the unit.
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop]
  # the chilled water loop that serves the fan coils.
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add fan coil units to.
  # @param ventilation [Bool] if true, ventilation will be supplied through the unit.  If false,
  # no ventilation will be supplied through the unit, with the expectation that it will be provided
  # by a DOAS or separate system.
  # @return [Array<OpenStudio::Model::ZoneHVACFourPipeFanCoil>]
  # array of fan coil units.
  def model_add_four_pipe_fan_coil(model,
                                   hot_water_loop,
                                   chilled_water_loop,
                                   thermal_zones,
                                   ventilation = true)

    # Supply temps used across all zones
    zn_dsn_clg_sa_temp_f = 55
    zn_dsn_htg_sa_temp_f = 104

    zn_dsn_clg_sa_temp_c = OpenStudio.convert(zn_dsn_clg_sa_temp_f, 'F', 'C').get
    zn_dsn_htg_sa_temp_c = OpenStudio.convert(zn_dsn_htg_sa_temp_f, 'F', 'C').get

    # Make a fan coil unit for each zone
    fcus = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding fan coil for #{zone.name}.")

      zone_sizing = zone.sizingZone
      zone_sizing.setZoneCoolingDesignSupplyAirTemperature(zn_dsn_clg_sa_temp_c)
      zone_sizing.setZoneHeatingDesignSupplyAirTemperature(zn_dsn_htg_sa_temp_c)

      fcu_clg_coil = nil
      if chilled_water_loop
        fcu_clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, model.alwaysOnDiscreteSchedule)
        fcu_clg_coil.setName("#{zone.name} 'FCU Cooling Coil")
        chilled_water_loop.addDemandBranchForComponent(fcu_clg_coil)
        fcu_clg_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', 'Fan coil units require a chilled water loop, but none was provided.')
        return fcus
      end

      fcu_htg_coil = nil
      if hot_water_loop
        fcu_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
        fcu_htg_coil.setName("#{zone.name} FCU Heating Coil")
        hot_water_loop.addDemandBranchForComponent(fcu_htg_coil)
        fcu_htg_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
      else
        # Zero-capacity, always-off electric heating coil
        fcu_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule)
        fcu_htg_coil.setName("#{zone.name} No Heat")
        fcu_htg_coil.setNominalCapacity(0)
      end

      fcu_fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fcu_fan.setName("#{zone.name} Fan Coil fan")
      fcu_fan.setFanEfficiency(0.16)
      fcu_fan.setPressureRise(270.9) # Pa
      fcu_fan.autosizeMaximumFlowRate
      fcu_fan.setMotorEfficiency(0.29)
      fcu_fan.setMotorInAirstreamFraction(1.0)
      fcu_fan.setEndUseSubcategory('FCU Fans')

      fcu = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model,
                                                           model.alwaysOnDiscreteSchedule,
                                                           fcu_fan,
                                                           fcu_clg_coil,
                                                           fcu_htg_coil)
      fcu.setName("#{zone.name} FCU")
      fcu.setCapacityControlMethod('CyclingFan')
      fcu.autosizeMaximumSupplyAirFlowRate
      unless ventilation
        fcu.setMaximumOutdoorAirFlowRate(0)
      end
      fcu.addToThermalZone(zone)
      fcus << fcu
    end

    return fcus
  end

  # Adds a window air conditioner to each zone.
  # Code adapted from:
  # https://github.com/NREL/OpenStudio-BEopt/blob/master/measures/ResidentialHVACRoomAirConditioner/measure.rb
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add fan coil units to.
  # @return [Array<OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner>] and array of PTACs used as window AC units
  def model_add_window_ac(model,
                          thermal_zones)

    # Defaults
    eer = 8.5 # Btu/W-h
    shr = 0.65 # The sensible heat ratio (ratio of the sensible portion of the load to the total load) at the nominal rated capacity
    airflow_cfm_per_ton = 350.0 # cfm/ton

    # Performance curves
    # From Frigidaire 10.7 EER unit in Winkler et. al. Lab Testing of Window ACs (2013)
    # NOTE: These coefficients are in SI UNITS
    cool_cap_ft_coeffs_si = [0.6405, 0.01568, 0.0004531, 0.001615, -0.0001825, 0.00006614]
    cool_eir_ft_coeffs_si = [2.287, -0.1732, 0.004745, 0.01662, 0.000484, -0.001306]
    cool_cap_fflow_coeffs = [0.887, 0.1128, 0]
    cool_eir_fflow_coeffs = [1.763, -0.6081, 0]
    cool_plf_fplr_coeffs = [0.78, 0.22, 0]

    # Make the curves
    roomac_cap_ft = create_curve_biquadratic(cool_cap_ft_coeffs_si, 'RoomAC-Cap-fT', 0, 100, 0, 100, nil, nil)
    roomac_cap_fff = create_curve_quadratic(cool_cap_fflow_coeffs, 'RoomAC-Cap-fFF', 0, 2, 0, 2, is_dimensionless = true)
    roomac_eir_ft = create_curve_biquadratic(cool_eir_ft_coeffs_si, 'RoomAC-EIR-fT', 0, 100, 0, 100, nil, nil)
    roomac_eir_fff = create_curve_quadratic(cool_eir_fflow_coeffs, 'RoomAC-EIR-fFF', 0, 2, 0, 2, is_dimensionless = true)
    roomac_plf_fplr = create_curve_quadratic(cool_plf_fplr_coeffs, 'RoomAC-PLF-fPLR', 0, 1, 0, 1, is_dimensionless = true)

    acs = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding window AC for #{zone.name}.")

      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                 model.alwaysOnDiscreteSchedule,
                                                                 roomac_cap_ft,
                                                                 roomac_cap_fff,
                                                                 roomac_eir_ft,
                                                                 roomac_eir_fff,
                                                                 roomac_plf_fplr)
      clg_coil.setName('Window AC Clg Coil')
      clg_coil.setRatedSensibleHeatRatio(shr)
      clg_coil.setRatedCOP(OpenStudio::OptionalDouble.new(OpenStudio.convert(eer, 'Btu/h', 'W').get))
      clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(OpenStudio::OptionalDouble.new(773.3))
      clg_coil.setEvaporativeCondenserEffectiveness(OpenStudio::OptionalDouble.new(0.9))
      clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(OpenStudio::OptionalDouble.new(10))
      clg_coil.setBasinHeaterSetpointTemperature(OpenStudio::OptionalDouble.new(2))

      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan.setName('Window AC Supply Fan')
      fan.setFanEfficiency(1)
      fan.setPressureRise(0)
      fan.setMotorEfficiency(1)
      fan.setMotorInAirstreamFraction(0)

      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOffDiscreteSchedule)
      htg_coil.setName('Window AC Always Off Htg Coil')

      ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,
                                                                           model.alwaysOnDiscreteSchedule,
                                                                           fan,
                                                                           htg_coil,
                                                                           clg_coil)
      ptac.setName("#{zone.name} Window AC")
      ptac.setSupplyAirFanOperatingModeSchedule(alwaysOffDiscreteSchedule)
      ptac.addToThermalZone(zone)

      acs << ptac
    end

    return acs
  end

  # Adds a forced air furnace or central AC to each zone.
  # Code adapted from:
  # https://github.com/NREL/OpenStudio-BEopt/blob/master/measures/ResidentialHVACFurnaceFuel/measure.rb
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add fan coil units to.
  # @param heating [Bool] if true, the unit will include a NaturalGas heating coil
  # @param cooling [Bool] if true, the unit will include a DX cooling coil
  # @param ventilation [Bool] if true, the unit will include an OA intake
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] and array of air loops representing the furnaces
  def model_add_furnace_central_ac(model,
                                   thermal_zones,
                                   heating,
                                   cooling,
                                   ventilation)

    equip_name = nil
    if heating && cooling
      equip_name = 'Central Heating and AC'
    elsif heating && !cooling
      equip_name = 'Furnace'
    elsif cooling && !heating
      equip_name = 'Central AC'
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', 'Heating and cooling both disabled, not a valid Furnace or Central AC selection, no equipment was added.')
      return []
    end

    # Defaults
    fan_pressure_rise_in = 0.5 # 0.5 in W.C.
    afue = 0.78
    seer = 13
    eer = 11.1
    shr = 0.73
    ac_w_per_cfm = 0.365
    sat_htg_f = 120
    sat_clg_f = 55
    crank_case_heat_w = 0
    crank_case_max_temp_f = 55

    # Performance curves
    # These coefficients are in IP UNITS
    cool_cap_ft_coeffs_ip = [3.670270705, -0.098652414, 0.000955906, 0.006552414, -0.0000156, -0.000131877]
    cool_eir_ft_coeffs_ip = [-3.302695861, 0.137871531, -0.001056996, -0.012573945, 0.000214638, -0.000145054]
    cool_cap_fflow_coeffs = [0.718605468, 0.410099989, -0.128705457]
    cool_eir_fflow_coeffs = [1.32299905, -0.477711207, 0.154712157]
    cool_plf_fplr_coeffs = [0.8, 0.2, 0]

    # Convert coefficients from IP to SI
    cool_cap_ft_coeffs_si = convert_curve_biquadratic(cool_cap_ft_coeffs_ip)
    cool_eir_ft_coeffs_si = convert_curve_biquadratic(cool_eir_ft_coeffs_ip)

    # Make the curves
    ac_cap_ft = create_curve_biquadratic(cool_cap_ft_coeffs_si, 'AC-Cap-fT', 0, 100, 0, 100, nil, nil)
    ac_cap_fff = create_curve_quadratic(cool_cap_fflow_coeffs, 'AC-Cap-fFF', 0, 2, 0, 2, is_dimensionless = true)
    ac_eir_ft = create_curve_biquadratic(cool_eir_ft_coeffs_si, 'AC-EIR-fT', 0, 100, 0, 100, nil, nil)
    ac_eir_fff = create_curve_quadratic(cool_eir_fflow_coeffs, 'AC-EIR-fFF', 0, 2, 0, 2, is_dimensionless = true)
    ac_plf_fplr = create_curve_quadratic(cool_plf_fplr_coeffs, 'AC-PLF-fPLR', 0, 1, 0, 1, is_dimensionless = true)

    # Unit conversion
    fan_pressure_rise_pa = OpenStudio.convert(fan_pressure_rise_in, 'inH_{2}O', 'Pa').get

    furnaces = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding furnace AC for #{zone.name}.")

      air_loop_name = "#{zone.name} #{equip_name}"
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(air_loop_name.to_s)

      # Heating Coil
      htg_coil = nil
      if heating
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model)
        htg_coil.setName("#{air_loop_name} htg coil")
        htg_coil.setGasBurnerEfficiency(afue_to_thermal_eff(afue))
        htg_coil.setParasiticElectricLoad(0)
        htg_coil.setParasiticGasLoad(0)
      end

      # Cooling Coil
      clg_coil = nil
      if cooling
        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                   model.alwaysOnDiscreteSchedule,
                                                                   ac_cap_ft,
                                                                   ac_cap_fff,
                                                                   ac_eir_ft,
                                                                   ac_eir_fff,
                                                                   ac_plf_fplr)
        clg_coil.setName("#{air_loop_name} cooling coil")
        clg_coil.setRatedSensibleHeatRatio(shr)
        clg_coil.setRatedCOP(OpenStudio::OptionalDouble.new(eer_to_cop(eer)))
        clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(OpenStudio::OptionalDouble.new(ac_w_per_cfm / OpenStudio.convert(1.0, 'cfm', 'm^3/s').get))
        clg_coil.setNominalTimeForCondensateRemovalToBegin(OpenStudio::OptionalDouble.new(1000.0))
        clg_coil.setRatioOfInitialMoistureEvaporationRateAndSteadyStateLatentCapacity(OpenStudio::OptionalDouble.new(1.5))
        clg_coil.setMaximumCyclingRate(OpenStudio::OptionalDouble.new(3.0))
        clg_coil.setLatentCapacityTimeConstant(OpenStudio::OptionalDouble.new(45.0))
        clg_coil.setCondenserType('AirCooled')
        clg_coil.setCrankcaseHeaterCapacity(OpenStudio::OptionalDouble.new(crank_case_heat_w))
        clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(OpenStudio::OptionalDouble.new(OpenStudio.convert(crank_case_max_temp_f, 'F', 'C').get))
      end

      # Fan
      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan.setName("#{air_loop_name} supply fan")
      fan.setEndUseSubcategory('residential hvac fan')
      fan.setFanEfficiency(0.6) # Overall Efficiency of the Supply Fan, Motor and Drive
      fan.setPressureRise(fan_pressure_rise_pa)
      fan.setMotorEfficiency(1)
      fan.setMotorInAirstreamFraction(1)

      # Outdoor Air Intake
      oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_intake_controller.setName("#{air_loop.name} OA Controller")
      oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
      oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
      oa_intake.setName("#{air_loop.name} OA Sys")
      oa_intake.addToNode(air_loop.supplyInletNode)
      unless ventilation
        # Disable the OA
        oa_intake_controller.setMinimumOutdoorAirSchedule(alwaysOffDiscreteSchedule)
      end

      # Unitary System (holds the coils and fan)
      unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary.setName("#{air_loop_name} zoneunitary system")
      unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      unitary.setMaximumSupplyAirTemperature(OpenStudio.convert(120.0, 'F', 'C').get)
      unitary.setControllingZoneorThermostatLocation(zone)
      unitary.addToNode(air_loop.supplyInletNode)

      # Set flow rates during different conditions
      unitary.setSupplyAirFlowRateDuringHeatingOperation(0) unless heating
      unitary.setSupplyAirFlowRateDuringCoolingOperation(0) unless cooling
      unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0) unless ventilation

      # Attach the coils and fan
      unitary.setHeatingCoil(htg_coil) if htg_coil
      unitary.setCoolingCoil(clg_coil) if clg_coil
      unitary.setSupplyFan(fan)
      unitary.setFanPlacement('BlowThrough')
      unitary.setSupplyAirFanOperatingModeSchedule(alwaysOffDiscreteSchedule)

      # Diffuser
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName(" #{zone.name} direct air")
      air_loop.addBranchForZone(zone, diffuser)

      furnaces << air_loop
    end

    return furnaces
  end

  # Adds an air source heat pump to each zone.
  # Code adapted from:
  # https://github.com/NREL/OpenStudio-BEopt/blob/master/measures/ResidentialHVACAirSourceHeatPumpSingleSpeed/measure.rb
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add fan coil units to.
  # @param heating [Bool] if true, the unit will include a NaturalGas heating coil
  # @param cooling [Bool] if true, the unit will include a DX cooling coil
  # @param ventilation [Bool] if true, the unit will include an OA intake
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] and array of air loops representing the heat pumps
  def model_add_central_air_source_heat_pump(model,
                                             thermal_zones,
                                             heating,
                                             cooling,
                                             ventilation)

    equip_name = 'Central Air Source HP'

    # Defaults
    fan_pressure_rise_in = 0.5 # 0.5 in W.C.
    hspf = 7.7
    seer = 13
    eer = 11.4
    cop = 3.05
    shr = 0.73
    ac_w_per_cfm = 0.365
    min_hp_oat_f = 0
    sat_htg_f = 120
    sat_clg_f = 55
    crank_case_heat_w = 0
    crank_case_max_temp_f = 55

    # Unit conversion
    fan_pressure_rise_pa = OpenStudio.convert(fan_pressure_rise_in, 'inH_{2}O', 'Pa').get

    # Performance curves
    # These coefficients are in IP UNITS
    cool_cap_ft_coeffs_ip = [3.68637657, -0.098352478, 0.000956357, 0.005838141, -0.0000127, -0.000131702]
    cool_eir_ft_coeffs_ip = [-3.437356399, 0.136656369, -0.001049231, -0.0079378, 0.000185435, -0.0001441]
    cool_cap_fflow_coeffs = [0.718664047, 0.41797409, -0.136638137]
    cool_eir_fflow_coeffs = [1.143487507, -0.13943972, -0.004047787]
    cool_plf_fplr_coeffs = [0.8, 0.2, 0]

    heat_cap_ft_coeffs_ip = [0.566333415, -0.000744164, -0.0000103, 0.009414634, 0.0000506, -0.00000675]
    heat_eir_ft_coeffs_ip = [0.718398423, 0.003498178, 0.000142202, -0.005724331, 0.00014085, -0.000215321]
    heat_cap_fflow_coeffs = [0.694045465, 0.474207981, -0.168253446]
    heat_eir_fflow_coeffs = [2.185418751, -1.942827919, 0.757409168]
    heat_plf_fplr_coeffs = [0.8, 0.2, 0]

    defrost_eir_coeffs = [0.1528, 0, 0, 0, 0, 0]

    # Convert coefficients from IP to SI
    cool_cap_ft_coeffs_si = convert_curve_biquadratic(cool_cap_ft_coeffs_ip)
    cool_eir_ft_coeffs_si = convert_curve_biquadratic(cool_eir_ft_coeffs_ip)
    heat_cap_ft_coeffs_si = convert_curve_biquadratic(heat_cap_ft_coeffs_ip)
    heat_eir_ft_coeffs_si = convert_curve_biquadratic(heat_eir_ft_coeffs_ip)

    # Make the curves
    cool_cap_ft = create_curve_biquadratic(cool_cap_ft_coeffs_si, 'Cool-Cap-fT', 0, 100, 0, 100, nil, nil)
    cool_cap_fff = create_curve_quadratic(cool_cap_fflow_coeffs, 'Cool-Cap-fFF', 0, 2, 0, 2, is_dimensionless = true)
    cool_eir_ft = create_curve_biquadratic(cool_eir_ft_coeffs_si, 'Cool-EIR-fT', 0, 100, 0, 100, nil, nil)
    cool_eir_fff = create_curve_quadratic(cool_eir_fflow_coeffs, 'Cool-EIR-fFF', 0, 2, 0, 2, is_dimensionless = true)
    cool_plf_fplr = create_curve_quadratic(cool_plf_fplr_coeffs, 'Cool-PLF-fPLR', 0, 1, 0, 1, is_dimensionless = true)

    heat_cap_ft = create_curve_biquadratic(heat_cap_ft_coeffs_si, 'Heat-Cap-fT', 0, 100, 0, 100, nil, nil)
    heat_cap_fff = create_curve_quadratic(heat_cap_fflow_coeffs, 'Heat-Cap-fFF', 0, 2, 0, 2, is_dimensionless = true)
    heat_eir_ft = create_curve_biquadratic(heat_eir_ft_coeffs_si, 'Heat-EIR-fT', 0, 100, 0, 100, nil, nil)
    heat_eir_fff = create_curve_quadratic(heat_eir_fflow_coeffs, 'Heat-EIR-fFF', 0, 2, 0, 2, is_dimensionless = true)
    heat_plf_fplr = create_curve_quadratic(heat_plf_fplr_coeffs, 'Heat-PLF-fPLR', 0, 1, 0, 1, is_dimensionless = true)

    # Heating defrost curve for reverse cycle
    defrost_eir_curve = create_curve_biquadratic(defrost_eir_coeffs, 'DefrostEIR', -100, 100, -100, 100, nil, nil)

    # Unit conversion
    fan_pressure_rise_pa = OpenStudio.convert(fan_pressure_rise_in, 'inH_{2}O', 'Pa').get

    hps = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding furnace AC for #{zone.name}.")

      air_loop_name = "#{zone.name} #{equip_name}"
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName(air_loop_name.to_s)

      # Heating Coil
      htg_coil = nil
      supp_htg_coil = nil
      if heating
        htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model,
                                                                   model.alwaysOnDiscreteSchedule,
                                                                   heat_cap_ft,
                                                                   heat_cap_fff,
                                                                   heat_eir_ft,
                                                                   heat_eir_fff,
                                                                   heat_plf_fplr)
        htg_coil.setName("#{air_loop_name} heating coil")
        htg_coil.setRatedCOP(hspf_to_cop_heating_no_fan(hspf))
        htg_coil.setRatedSupplyFanPowerPerVolumeFlowRate(ac_w_per_cfm / OpenStudio.convert(1.0, 'cfm', 'm^3/s').get)
        htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(defrost_eir_curve)
        htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(OpenStudio.convert(min_hp_oat_f, 'F', 'C').get)
        htg_coil.setMaximumOutdoorDryBulbTemperatureforDefrostOperation(OpenStudio.convert(40.0, 'F', 'C').get)
        htg_coil.setCrankcaseHeaterCapacity(crank_case_heat_w)
        htg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(OpenStudio.convert(crank_case_max_temp_f, 'F', 'C').get)
        htg_coil.setDefrostStrategy('ReverseCycle')
        htg_coil.setDefrostControl('OnDemand')

        # Supplemental Heating Coil
        supp_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
        supp_htg_coil.setName("#{air_loop_name} supp htg coil")
        supp_htg_coil.setEfficiency(1)
      end

      # Cooling Coil
      clg_coil = nil
      if cooling
        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model,
                                                                   model.alwaysOnDiscreteSchedule,
                                                                   cool_cap_ft,
                                                                   cool_cap_fff,
                                                                   cool_eir_ft,
                                                                   cool_eir_fff,
                                                                   cool_plf_fplr)
        clg_coil.setName("#{air_loop_name} cooling coil")
        clg_coil.setRatedSensibleHeatRatio(shr)
        clg_coil.setRatedCOP(OpenStudio::OptionalDouble.new(cop))
        clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(OpenStudio::OptionalDouble.new(ac_w_per_cfm / OpenStudio.convert(1.0, 'cfm', 'm^3/s').get))
        clg_coil.setNominalTimeForCondensateRemovalToBegin(OpenStudio::OptionalDouble.new(1000.0))
        clg_coil.setRatioOfInitialMoistureEvaporationRateAndSteadyStateLatentCapacity(OpenStudio::OptionalDouble.new(1.5))
        clg_coil.setMaximumCyclingRate(OpenStudio::OptionalDouble.new(3.0))
        clg_coil.setLatentCapacityTimeConstant(OpenStudio::OptionalDouble.new(45.0))
        clg_coil.setCondenserType('AirCooled')
        clg_coil.setCrankcaseHeaterCapacity(OpenStudio::OptionalDouble.new(crank_case_heat_w))
        clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(OpenStudio::OptionalDouble.new(OpenStudio.convert(crank_case_max_temp_f, 'F', 'C').get))
      end

      # Fan
      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan.setName("#{air_loop_name} supply fan")
      fan.setEndUseSubcategory('residential hvac fan')
      fan.setFanEfficiency(0.6) # Overall Efficiency of the Supply Fan, Motor and Drive
      fan.setPressureRise(fan_pressure_rise_pa)
      fan.setMotorEfficiency(1)
      fan.setMotorInAirstreamFraction(1)

      # Outdoor Air Intake
      oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_intake_controller.setName("#{air_loop.name} OA Controller")
      oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
      oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
      oa_intake.setName("#{air_loop.name} OA Sys")
      oa_intake.addToNode(air_loop.supplyInletNode)
      unless ventilation
        # Disable the OA
        oa_intake_controller.setMinimumOutdoorAirSchedule(alwaysOffDiscreteSchedule)
      end

      # Unitary System (holds the coils and fan)
      unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary.setName("#{air_loop_name} zoneunitary system")
      unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      unitary.setMaximumSupplyAirTemperature(OpenStudio.convert(170.0, 'F', 'C').get) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(OpenStudio.convert(40.0, 'F', 'C').get)
      unitary.setControllingZoneorThermostatLocation(zone)
      unitary.addToNode(air_loop.supplyInletNode)

      # Set flow rates during different conditions
      unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0) unless ventilation

      # Attach the coils and fan
      unitary.setHeatingCoil(htg_coil) if htg_coil
      unitary.setCoolingCoil(clg_coil) if clg_coil
      unitary.setSupplementalHeatingCoil(supp_htg_coil) if supp_htg_coil
      unitary.setSupplyFan(fan)
      unitary.setFanPlacement('BlowThrough')
      unitary.setSupplyAirFanOperatingModeSchedule(alwaysOffDiscreteSchedule)

      # Diffuser
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName(" #{zone.name} direct air")
      air_loop.addBranchForZone(zone, diffuser)

      hps << air_loop
    end

    return hps
  end

  # Adds zone level water-to-air heat pumps for each zone.
  #
  # @param condenser_loop [OpenStudio::Model::PlantLoop] the condenser loop for the heat pumps
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add heat pumps to.
  # @param ventilation [Bool] if true, ventilation will be supplied through the unit.  If false,
  # no ventilation will be supplied through the unit, with the expectation that it will be provided
  # by a DOAS or separate system.
  # @return [Array<OpenStudio::Model::ZoneHVACWaterToAirHeatPump>] an array of heat pumps
  def model_add_water_source_hp(model, condenser_loop,
                                thermal_zones,
                                ventilation = true)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding zone water-to-air heat pump.')

    water_to_air_hp_systems = []
    thermal_zones.each do |zone|
      supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)

      htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model)
      htg_coil.setName('WSHP Htg Coil')
      htg_coil.setRatedHeatingCoefficientofPerformance(4.2)
      htg_coil.setHeatingCapacityCoefficient1(0.237847462869254)
      htg_coil.setHeatingCapacityCoefficient2(-3.35823796081626)
      htg_coil.setHeatingCapacityCoefficient3(3.80640467406376)
      htg_coil.setHeatingCapacityCoefficient4(0.179200417311554)
      htg_coil.setHeatingCapacityCoefficient5(0.12860719846082)
      htg_coil.setHeatingPowerConsumptionCoefficient1(-3.79175529243238)
      htg_coil.setHeatingPowerConsumptionCoefficient2(3.38799239505527)
      htg_coil.setHeatingPowerConsumptionCoefficient3(1.5022612076303)
      htg_coil.setHeatingPowerConsumptionCoefficient4(-0.177653510577989)
      htg_coil.setHeatingPowerConsumptionCoefficient5(-0.103079864171839)

      condenser_loop.addDemandBranchForComponent(htg_coil)

      clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(model)
      clg_coil.setName('WSHP Clg Coil')
      clg_coil.setRatedCoolingCoefficientofPerformance(3.4)
      clg_coil.setTotalCoolingCapacityCoefficient1(-4.30266987344639)
      clg_coil.setTotalCoolingCapacityCoefficient2(7.18536990534372)
      clg_coil.setTotalCoolingCapacityCoefficient3(-2.23946714486189)
      clg_coil.setTotalCoolingCapacityCoefficient4(0.139995928440879)
      clg_coil.setTotalCoolingCapacityCoefficient5(0.102660179888915)
      clg_coil.setSensibleCoolingCapacityCoefficient1(6.0019444814887)
      clg_coil.setSensibleCoolingCapacityCoefficient2(22.6300677244073)
      clg_coil.setSensibleCoolingCapacityCoefficient3(-26.7960783730934)
      clg_coil.setSensibleCoolingCapacityCoefficient4(-1.72374720346819)
      clg_coil.setSensibleCoolingCapacityCoefficient5(0.490644802367817)
      clg_coil.setSensibleCoolingCapacityCoefficient6(0.0693119353468141)
      clg_coil.setCoolingPowerConsumptionCoefficient1(-5.67775976415698)
      clg_coil.setCoolingPowerConsumptionCoefficient2(0.438988156976704)
      clg_coil.setCoolingPowerConsumptionCoefficient3(5.845277342193)
      clg_coil.setCoolingPowerConsumptionCoefficient4(0.141605667000125)
      clg_coil.setCoolingPowerConsumptionCoefficient5(-0.168727936032429)

      condenser_loop.addDemandBranchForComponent(clg_coil)

      # add fan
      fan = OpenStudio::Model::FanOnOff.new(model, model.alwaysOnDiscreteSchedule)
      fan.setName("#{zone.name} WSHP Fan")
      fan_static_pressure_in_h2o = 1.33
      fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
      fan.setPressureRise(fan_static_pressure_pa)
      fan.setFanEfficiency(0.52)
      fan.setMotorEfficiency(0.8)

      water_to_air_hp_system = OpenStudio::Model::ZoneHVACWaterToAirHeatPump.new(model, model.alwaysOnDiscreteSchedule, fan, htg_coil, clg_coil, supplemental_htg_coil)
      water_to_air_hp_system.setName("#{zone.name} WSHP")
      unless ventilation
        water_to_air_hp_system.setOutdoorAirFlowRateDuringHeatingOperation(OpenStudio::OptionalDouble.new(0))
        water_to_air_hp_system.setOutdoorAirFlowRateDuringCoolingOperation(OpenStudio::OptionalDouble.new(0))
        water_to_air_hp_system.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(OpenStudio::OptionalDouble.new(0))
      end
      water_to_air_hp_system.addToThermalZone(zone)

      water_to_air_hp_systems << water_to_air_hp_system
    end

    return water_to_air_hp_systems
  end

  # Adds zone level ERVs for each zone.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add heat pumps to.
  # @return [Array<OpenStudio::Model::ZoneHVACEnergyRecoveryVentilator>] an array of zone ERVs
  # @todo review the static pressure rise for the ERV
  def model_add_zone_erv(model, thermal_zones)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding zone ERV for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # ERV properties
    fan_static_pressure_in_h2o = 0.25
    fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
    fan_motor_efficiency = 0.8

    erv_systems = []
    thermal_zones.each do |zone|
      # Determine the OA requirement for this zone
      min_oa_flow_m3_per_s_per_m2 = thermal_zone_outdoor_airflow_rate_per_area(zone)

      supply_fan = OpenStudio::Model::FanOnOff.new(model)
      supply_fan.setName("#{zone.name} ERV Supply Fan")
      supply_fan.setMotorEfficiency(fan_motor_efficiency)
      impeller_eff = fan_baseline_impeller_efficiency(supply_fan)
      fan_change_impeller_efficiency(supply_fan, impeller_eff)
      supply_fan.setPressureRise(fan_static_pressure_pa)
      supply_fan.setMotorInAirstreamFraction(1)

      exhaust_fan = OpenStudio::Model::FanOnOff.new(model)
      exhaust_fan.setName("#{zone.name} ERV Exhaust Fan")
      exhaust_fan.setMotorEfficiency(fan_motor_efficiency)
      fan_change_impeller_efficiency(exhaust_fan, impeller_eff)
      exhaust_fan.setPressureRise(fan_static_pressure_pa)
      exhaust_fan.setMotorInAirstreamFraction(1)

      erv_controller = OpenStudio::Model::ZoneHVACEnergyRecoveryVentilatorController.new(model)
      # erv_controller.setExhaustAirTemperatureLimit("NoExhaustAirTemperatureLimit")
      # erv_controller.setExhaustAirEnthalpyLimit("NoExhaustAirEnthalpyLimit")
      # erv_controller.setTimeofDayEconomizerFlowControlSchedule(self.alwaysOnDiscreteSchedule)
      # erv_controller.setHighHumidityControlFlag(false)

      heat_exchanger = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
      # heat_exchanger.setHeatExchangerType("Plate")
      # heat_exchanger.setEconomizerLockout(true)
      # heat_exchanger.setSupplyAirOutletTemperatureControl(false)
      # heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(0.76)
      # heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(0.81)
      # heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(0.68)
      # heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(0.73)
      # heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(0.76)
      # heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(0.81)
      # heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(0.68)
      # heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(0.73)

      zone_hvac = OpenStudio::Model::ZoneHVACEnergyRecoveryVentilator.new(model, heat_exchanger, supply_fan, exhaust_fan)
      zone_hvac.setName("#{zone.name} ERV")
      zone_hvac.setVentilationRateperUnitFloorArea(min_oa_flow_m3_per_s_per_m2)
      zone_hvac.setController(erv_controller)
      zone_hvac.addToThermalZone(zone)

      # Calculate ERV SAT during sizing periods
      # Heating design day
      oat_f = 0
      return_air_f = 68
      eff = heat_exchanger.sensibleEffectivenessat100HeatingAirFlow
      coldest_erv_supply_f = oat_f - (eff * (oat_f - return_air_f))
      coldest_erv_supply_c = OpenStudio.convert(coldest_erv_supply_f, 'F', 'C').get

      # Cooling design day
      oat_f = 110
      return_air_f = 75
      eff = heat_exchanger.sensibleEffectivenessat100CoolingAirFlow
      hottest_erv_supply_f = oat_f - (eff * (oat_f - return_air_f))
      hottest_erv_supply_c = OpenStudio.convert(hottest_erv_supply_f, 'F', 'C').get

      # Ensure that zone sizing accounts for OA from ERV
      zone_sizing = zone.sizingZone
      zone_sizing.setAccountforDedicatedOutdoorAirSystem(true)
      zone_sizing.setDedicatedOutdoorAirSystemControlStrategy('ColdSupplyAir')
      zone_sizing.setDedicatedOutdoorAirLowSetpointTemperatureforDesign(coldest_erv_supply_c)
      zone_sizing.setDedicatedOutdoorAirHighSetpointTemperatureforDesign(hottest_erv_supply_c)

      erv_systems << zone_hvac
    end

    return erv_systems
  end

  # Adds ideal air loads systems for each zone.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add heat pumps to.
  # @return [Array<OpenStudio::Model::ZoneHVACIdealLoadsAirSystem>] an array of ideal air loads systems
  # @todo review the default ventilation settings
  def model_add_ideal_air_loads(model, thermal_zones)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding ideal air loads for #{thermal_zones.size} zones.")

    ideal_systems = []
    thermal_zones.each do |zone|
      ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
      ideal_loads.addToThermalZone(zone)
      ideal_systems << ideal_loads
    end

    return ideal_systems
  end

  # Adds an exhaust fan to each zone.
  #
  # @param availability_sch_name [String] the name of the fan availability schedule
  # @param flow_rate [Double] the exhaust fan flow rate in m^3/s
  # @param balanced_exhaust_fraction_schedule_name [String] the name
  # of the balanced exhaust fraction schedule.
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] an array of thermal zones
  # @return [Array<OpenStudio::Model::FanZoneExhaust>] an array of exhaust fans created
  def model_add_exhaust_fan(model, availability_sch_name,
                            flow_rate,
                            flow_fraction_schedule_name,
                            balanced_exhaust_fraction_schedule_name,
                            thermal_zones)

    # Make an exhaust fan for each zone
    fans = []
    thermal_zones.each do |zone|
      fan = OpenStudio::Model::FanZoneExhaust.new(model)
      fan.setName("#{zone.name} Exhaust Fan")
      fan.setAvailabilitySchedule(model_add_schedule(model, availability_sch_name))
      # two ways to input the flow rate: Number of Array.
      # For number: assign directly. For Array: assign each flow rate to each according zone.
      if flow_rate.is_a? Numeric
        fan.setMaximumFlowRate(flow_rate)
      elsif flow_rate.class.to_s == 'Array'
        index = thermal_zones.index(zone)
        flow_rate_zone = flow_rate[index]
        fan.setMaximumFlowRate(flow_rate_zone)
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Wrong format of flow rate')
      end
      unless flow_fraction_schedule_name.nil?
        fan.setFlowFractionSchedule(model_add_schedule(model, flow_fraction_schedule_name))
      end
      fan.setSystemAvailabilityManagerCouplingMode('Decoupled')
      unless balanced_exhaust_fraction_schedule_name.nil?
        fan.setBalancedExhaustFractionSchedule(model_add_schedule(model, balanced_exhaust_fraction_schedule_name))
      end
      fan.addToThermalZone(zone)
      fans << fan
    end

    return fans
  end

  # Adds a zone ventilation design flow rate to each zone.
  #
  # @param availability_sch_name [String] the name of the fan availability schedule
  # @param flow_rate [Double] the ventilation design flow rate in m^3/s for Exhaust/Natural or
  # Flow Rate per Zone Floor Area in m^3/s-m^2 for Intake
  # @param ventilation_type [String] the zone ventilation type either Exhaust, Natural, or Intake
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] an array of thermal zones
  # @return [Array<OpenStudio::Model::ZoneVentilationDesignFlowRate>] an array of zone ventilation objects created
  def model_add_zone_ventilation(model, availability_sch_name,
                                 flow_rate,
                                 ventilation_type,
                                 thermal_zones)

    # Make an exhaust fan for each zone
    zone_ventilations = []
    thermal_zones.each do |zone|
      ventilation = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
      ventilation.setName("#{zone.name} Ventilation")
      ventilation.setSchedule(model_add_schedule(model, availability_sch_name))
      ventilation.setVentilationType(ventilation_type)

      ventilation.setAirChangesperHour(0)
      ventilation.setTemperatureTermCoefficient(0)

      if ventilation_type == 'Exhaust'
        ventilation.setDesignFlowRateCalculationMethod('Flow/Zone')
        ventilation.setDesignFlowRate(flow_rate)
        ventilation.setFanPressureRise(31.1361206455786)
        ventilation.setFanTotalEfficiency(0.51)
        ventilation.setConstantTermCoefficient(1)
        ventilation.setVelocityTermCoefficient(0)
        ventilation.setMinimumIndoorTemperature(29.4444452244559)
        ventilation.setMaximumIndoorTemperature(100)
        ventilation.setDeltaTemperature(-100)
      elsif ventilation_type == 'Natural'
        ventilation.setDesignFlowRateCalculationMethod('Flow/Zone')
        ventilation.setDesignFlowRate(flow_rate)
        ventilation.setFanPressureRise(0)
        ventilation.setFanTotalEfficiency(1)
        ventilation.setConstantTermCoefficient(0)
        ventilation.setVelocityTermCoefficient(0.224)
        ventilation.setMinimumIndoorTemperature(-73.3333352760033)
        ventilation.setMaximumIndoorTemperature(29.4444452244559)
        ventilation.setDeltaTemperature(-100)
      elsif ventilation_type == 'Intake'
        ventilation.setDesignFlowRateCalculationMethod('Flow/Area')
        ventilation.setFlowRateperZoneFloorArea(flow_rate)
        ventilation.setFanPressureRise(49.8)
        ventilation.setFanTotalEfficiency(0.53625)
        ventilation.setConstantTermCoefficient(1)
        ventilation.setVelocityTermCoefficient(0)
        ventilation.setMinimumIndoorTemperature(7.5)
        ventilation.setMaximumIndoorTemperature(35)
        ventilation.setDeltaTemperature(-27.5)
        ventilation.setMinimumOutdoorTemperature(-30.0)
        ventilation.setMaximumOutdoorTemperature(50.0)
        ventilation.setMaximumWindSpeed(6.0)
      end
      ventilation.addToThermalZone(zone)
      zone_ventilations << ventilation
    end

    return zone_ventilations
  end

  # Either get the existing chilled water loop in the model or
  # add a new one if there isn't one already.
  #
  # @param cool_fuel [String] the cooling fuel. Valid choices are
  # Electricity, DistrictCooling, and HeatPump.
  # @param air_cooled [Bool] if true, the chiller will be air-cooled.
  #   if false, it will be water-cooled.
  def model_get_or_add_chilled_water_loop(model, cool_fuel, air_cooled = true)
    # Retrieve the existing chilled water loop
    # or add a new one if necessary.
    chilled_water_loop = nil
    if model.getPlantLoopByName('Chilled Water Loop').is_initialized
      chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
    else
      case cool_fuel
      when 'DistrictCooling'
        chilled_water_loop = model_add_chw_loop(model,
                                                'const_pri',
                                                chiller_cooling_type = nil,
                                                chiller_condenser_type = nil,
                                                chiller_compressor_type = nil,
                                                cool_fuel,
                                                condenser_water_loop = nil,
                                                building_type = nil)
      when 'HeatPump'
        condenser_water_loop = model_get_or_add_ambient_water_loop(model)
        chilled_water_loop = model_add_chw_loop(model,
                                                'const_pri_var_sec',
                                                'WaterCooled',
                                                chiller_condenser_type = nil,
                                                'Rotary Screw',
                                                cooling_fuel = nil,
                                                condenser_water_loop,
                                                building_type = nil)
      when 'Electricity'
        if air_cooled
          chilled_water_loop = model_add_chw_loop(model,
                                                  'const_pri',
                                                  chiller_cooling_type = nil,
                                                  chiller_condenser_type = nil,
                                                  chiller_compressor_type = nil,
                                                  cool_fuel,
                                                  condenser_water_loop = nil,
                                                  building_type = nil)
        else
          fan_type = model_cw_loop_cooling_tower_fan_type(model)
          condenser_water_loop = model_add_cw_loop(model,
                                                   'Open Cooling Tower',
                                                   'Propeller or Axial',
                                                   fan_type,
                                                   1,
                                                   1,
                                                   nil)
          chilled_water_loop = model_add_chw_loop(model,
                                                  'const_pri_var_sec',
                                                  'WaterCooled',
                                                  chiller_condenser_type = nil,
                                                  'Rotary Screw',
                                                  cooling_fuel = nil,
                                                  condenser_water_loop,
                                                  building_type = nil)
        end
      end
    end

    return chilled_water_loop
  end

  # Determine which type of fan the cooling tower
  # will have.  Defaults to TwoSpeed Fan.
  # @return [String] the fan type: TwoSpeed Fan, Variable Speed Fan
  def model_cw_loop_cooling_tower_fan_type(model)
    fan_type = 'TwoSpeed Fan'
    return fan_type
  end

  # Either get the existing hot water loop in the model or
  # add a new one if there isn't one already.
  #
  # @param heat_fuel [String] the heating fuel.
  # Valid choices are NaturalGas, Electricity, DistrictHeating
  def model_get_or_add_hot_water_loop(model, heat_fuel)
    # Retrieve the existing hot water loop
    # or add a new one if necessary.
    hot_water_loop = nil
    hot_water_loop = if model.getPlantLoopByName('Hot Water Loop').is_initialized
                       model.getPlantLoopByName('Hot Water Loop').get
                     else
                       model_add_hw_loop(model, heat_fuel)
                     end

    return hot_water_loop
  end

  # Either get the existing ambient water loop in the model or
  # add a new one if there isn't one already.
  #
  def model_get_or_add_ambient_water_loop(model)
    # Retrieve the existing hot water loop
    # or add a new one if necessary.
    ambient_water_loop = nil
    ambient_water_loop = if model.getPlantLoopByName('Ambient Loop').is_initialized
                           model.getPlantLoopByName('Ambient Loop').get
                         else
                           model_add_district_ambient_loop(model)
                         end

    return ambient_water_loop
  end

  # Either get the existing ground heat exchanger loop in the model or
  # add a new one if there isn't one already.
  #
  def model_get_or_add_ground_hx_loop(model)
    # Retrieve the existing ground HX loop
    # or add a new one if necessary.
    ground_hx_loop = nil
    ground_hx_loop = if model.getPlantLoopByName('Ground HX Loop').is_initialized
                       model.getPlantLoopByName('Ground HX Loop').get
                     else
                       model_add_ground_hx_loop(model)
                     end

    return ground_hx_loop
  end

  # Either get the existing heat pump loop in the model or
  # add a new one if there isn't one already.
  #
  def model_get_or_add_heat_pump_loop(model)
    # Retrieve the existing heat pump loop
    # or add a new one if necessary.
    heat_pump_loop = nil
    heat_pump_loop = if model.getPlantLoopByName('Heat Pump Loop').is_initialized
                       model.getPlantLoopByName('Heat Pump Loop').get
                     else
                       model_add_hp_loop(model)
                     end

    return heat_pump_loop
  end

  # Add the specified system type to the
  # specified zones based on the specified template.
  # For multi-zone system types, add one system per story.
  #
  # @param system_type [String] The system type.  Valid choices are
  # TODO enumerate the valid strings
  # @return [Bool] returns true if successful, false if not
  def model_add_hvac_system(model, system_type, main_heat_fuel, zone_heat_fuel, cool_fuel, zones)
    # Don't do anything if there are no zones
    return true if zones.empty?

    case system_type
    when 'PTAC'
      case main_heat_fuel
      when 'NaturalGas', 'DistrictHeating'
        heating_type = 'Water'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel)
      when 'Electricity'
        heating_type = main_heat_fuel
        hot_water_loop = nil
      when nil
        heating_type = zone_heat_fuel
        hot_water_loop = nil
      end

      model_add_ptac(model,
                     sys_name = nil,
                     hot_water_loop,
                     zones,
                     fan_type = 'ConstantVolume',
                     heating_type,
                     cooling_type = 'Single Speed DX AC')

    when 'PTHP'
      model_add_pthp(model,
                     sys_name = nil,
                     zones,
                     fan_type = 'ConstantVolume')

    when 'PSZ-AC'
      case main_heat_fuel
      when 'NaturalGas'
        heating_type = main_heat_fuel
        supplemental_heating_type = 'Electricity'
        hot_water_loop = nil
      when 'DistrictHeating'
        heating_type = 'Water'
        supplemental_heating_type = 'Electricity'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel)
      when nil
        heating_type = nil
        supplemental_heating_type = nil
        hot_water_loop = nil
      when 'Electricity'
        heating_type = main_heat_fuel
        supplemental_heating_type = 'Electricity'
      end

      case cool_fuel
      when 'DistrictCooling'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel)
        cooling_type = 'Water'
      else
        chilled_water_loop = nil
        cooling_type = 'Single Speed DX AC'
      end

      model_add_psz_ac(model,
                       sys_name = nil,
                       hot_water_loop,
                       chilled_water_loop,
                       zones,
                       hvac_op_sch = nil,
                       oa_damper_sch = nil,
                       fan_location = 'DrawThrough',
                       fan_type = 'ConstantVolume',
                       heating_type,
                       supplemental_heating_type,
                       cooling_type)

    when 'PSZ-HP'
      model_add_psz_ac(model,
                       sys_name = 'PSZ-HP',
                       hot_water_loop = nil,
                       chilled_water_loop = nil,
                       zones,
                       hvac_op_sch = nil,
                       oa_damper_sch = nil,
                       fan_location = 'DrawThrough',
                       fan_type = 'ConstantVolume',
                       heating_type = 'Single Speed Heat Pump',
                       supplemental_heating_type = 'Electricity',
                       cooling_type = 'Single Speed Heat Pump')
    when 'PSZ-VAV'
      case main_heat_fuel
      when 'NaturalGas'
        heating_type = main_heat_fuel
        supplemental_heating_type = 'Electricity'
      when nil
        heating_type = nil
        supplemental_heating_type = nil
      when 'Electricity'
        heating_type = main_heat_fuel
        supplemental_heating_type = 'Electricity'
      end

      model_add_psz_vav(model,
                        sys_name='PSZ-VAV',
                        zones,
                        hvac_op_sch=nil,
                        oa_damper_sch=nil,
                        heating_type,
                        supplemental_heating_type)

    when 'Fan Coil'
      case main_heat_fuel
      when 'NaturalGas', 'DistrictHeating', 'Electricity'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel)
      when nil
        hot_water_loop = nil
      end

      case cool_fuel
      when 'Electricity', 'DistrictCooling'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel, air_cooled = true)
      when nil
        chilled_water_loop = nil
      end

      model_add_four_pipe_fan_coil(model,
                                   hot_water_loop,
                                   chilled_water_loop,
                                   zones)

    when 'Baseboards'
      case main_heat_fuel
      when 'NaturalGas', 'DistrictHeating'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel)
      when 'Electricity'
        hot_water_loop = nil
      when nil
        # TODO: Error, Baseboard systems must have a main_heat_fuel
        # return ??
      end

      model_add_baseboard(model,
                          hot_water_loop,
                          zones)

    when 'Unit Heaters'
      model_add_unitheater(model,
                           sys_name = nil,
                           zones,
                           hvac_op_sch = nil,
                           fan_control_type = 'ConstantVolume',
                           fan_pressure_rise = OpenStudio.convert(0.2, 'inH_{2}O', 'Pa').get,
                           main_heat_fuel,
                           hot_water_loop = nil)

    when 'Window AC'
      model_add_window_ac(model,
                          zones)

    when 'Residential AC'
      model_add_furnace_central_ac(model,
                                   zones,
                                   heating = false,
                                   cooling = true,
                                   ventilation = false)

    when 'Forced Air Furnace'
      model_add_furnace_central_ac(model,
                                   zones,
                                   heating = true,
                                   cooling = false,
                                   ventilation = true)

    when 'Residential Forced Air Furnace'
      model_add_furnace_central_ac(model,
                                   zones,
                                   heating = true,
                                   cooling = false,
                                   ventilation = false)

    when 'Residential Air Source Heat Pump'
      heating = true unless main_heat_fuel.nil?
      cooling = true unless cool_fuel.nil?

      model_add_central_air_source_heat_pump(model,
                                             zones,
                                             heating,
                                             cooling,
                                             ventilation = false)

    when 'VAV Reheat'
      hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel)
      chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel, air_cooled = false)

      reheat_type = 'Water'
      if zone_heat_fuel == 'Electricity'
        reheat_type = 'Electricity'
      end

      model_add_vav_reheat(model,
                           sys_name = nil,
                           hot_water_loop,
                           chilled_water_loop,
                           zones,
                           hvac_op_sch = nil,
                           oa_damper_sch = nil,
                           vav_fan_efficiency = 0.62,
                           vav_fan_motor_efficiency = 0.9,
                           vav_fan_pressure_rise = OpenStudio.convert(4.0, 'inH_{2}O', 'Pa').get,
                           return_plenum = nil,
                           reheat_type)

    when 'VAV No Reheat'
      chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel, air_cooled = false)

      model_add_vav_reheat(model,
                           sys_name = nil,
                           hot_water_loop,
                           chilled_water_loop,
                           zones,
                           hvac_op_sch = nil,
                           oa_damper_sch = nil,
                           vav_fan_efficiency = 0.62,
                           vav_fan_motor_efficiency = 0.9,
                           vav_fan_pressure_rise = OpenStudio.convert(4.0, 'inH_{2}O', 'Pa').get,
                           return_plenum = nil,
                           reheat_type = nil)

    when 'VAV Gas Reheat'
      chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel, air_cooled = false)

      model_add_vav_reheat(model,
                           sys_name = nil,
                           hot_water_loop,
                           chilled_water_loop,
                           zones,
                           hvac_op_sch = nil,
                           oa_damper_sch = nil,
                           vav_fan_efficiency = 0.62,
                           vav_fan_motor_efficiency = 0.9,
                           vav_fan_pressure_rise = OpenStudio.convert(4.0, 'inH_{2}O', 'Pa').get,
                           return_plenum = nil,
                           reheat_type = 'NaturalGas')

    when 'PVAV Reheat'
      hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel)
      chilled_water_loop = case cool_fuel
                           when 'Electricity'
                             nil
                           else
                             model_get_or_add_chilled_water_loop(model, cool_fuel, air_cooled = false)
                           end

      electric_reheat = false
      if zone_heat_fuel == 'Electricity'
        electric_reheat = true
      end

      model_add_pvav(model,
                     sys_name = nil,
                     zones,
                     hvac_op_sch = nil,
                     oa_damper_sch = nil,
                     electric_reheat,
                     hot_water_loop,
                     chilled_water_loop,
                     return_plenum = nil)

    when 'PVAV PFP Boxes'
      chilled_water_loop = case cool_fuel
                           when 'DistrictCooling'
                             model_get_or_add_chilled_water_loop(model, cool_fuel)
                           end

      model_add_pvav_pfp_boxes(model,
                               sys_name = nil,
                               zones,
                               hvac_op_sch = nil,
                               oa_damper_sch = nil,
                               vav_fan_efficiency = 0.62,
                               vav_fan_motor_efficiency = 0.9,
                               vav_fan_pressure_rise = OpenStudio.convert(4.0, 'inH_{2}O', 'Pa').get,
                               chilled_water_loop)
    when 'VAV PFP Boxes'
      chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel, air_cooled = false)

      model_add_pvav_pfp_boxes(model,
                               sys_name = nil,
                               zones,
                               hvac_op_sch = nil,
                               oa_damper_sch = nil,
                               vav_fan_efficiency = 0.62,
                               vav_fan_motor_efficiency = 0.9,
                               vav_fan_pressure_rise = OpenStudio.convert(4.0, 'inH_{2}O', 'Pa').get,
                               chilled_water_loop)

    when 'Water Source Heat Pumps'
      condenser_loop = case main_heat_fuel
                       when 'NaturalGas'
                         model_get_or_add_heat_pump_loop(model)
                       else
                         model_get_or_add_ambient_water_loop(model)
                       end

      model_add_water_source_hp(model, condenser_loop,
                                zones,
                                ventilation = false)

    when 'Ground Source Heat Pumps'
      # TODO: replace condenser loop w/ ground HX model
      # that does not involve district objects
      condenser_loop = model_get_or_add_ground_hx_loop(model)
      model_add_water_source_hp(model, condenser_loop,
                                zones,
                                ventilation = false)

    when 'DOAS'
      hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel)
      chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel, air_cooled = false)

      model_add_doas(model,
                     sys_name = nil,
                     hot_water_loop,
                     chilled_water_loop,
                     zones,
                     hvac_op_sch = nil,
                     oa_damper_sch = nil,
                     fan_max_flow_rate = nil,
                     economizer_control_type = 'FixedDryBulb',
                     building_type = nil)

    when 'ERVs'
      model_add_zone_erv(model, zones)

    when 'Evaporative Cooler'
      model_add_evap_cooler(model,
                            zones)

    when 'Ideal Air Loads'
      model_add_ideal_air_loads(model,
                                zones)

    ### Combination Systems ###
    when 'Water Source Heat Pumps with ERVs'
      model_add_hvac_system(model,
                            system_type = 'Water Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

      model_add_hvac_system(model,
                            system_type = 'ERVs',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Water Source Heat Pumps with DOAS'
      model_add_hvac_system(model,
                            system_type = 'Water Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

      model_add_hvac_system(model,
                            system_type = 'DOAS',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Ground Source Heat Pumps with ERVs'
      model_add_hvac_system(model,
                            system_type = 'Ground Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

      model_add_hvac_system(model,
                            system_type = 'ERVs',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Ground Source Heat Pumps with DOAS'
      model_add_hvac_system(model,
                            system_type = 'Ground Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

      model_add_hvac_system(model,
                            system_type = 'DOAS',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Fan Coil with DOAS'
      model_add_hvac_system(model,
                            system_type = 'Fan Coil',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

      model_add_hvac_system(model,
                            system_type = 'DOAS',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Fan Coil with ERVs'
      model_add_hvac_system(model,
                            system_type = 'Fan Coil',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

      model_add_hvac_system(model,
                            system_type = 'ERVs',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "HVAC system type '#{system_type}' not recognized")
      return false
    end
  end

  # Determine the typical system type given the inputs.
  #
  # @param area_type [String] Valid choices are residential
  # and nonresidential
  # @param delivery_type [String] Conditioning delivery type.
  # Valid choices are air and hydronic
  # @param heating_source [String] Valid choices are
  # Electricity, NaturalGas, DistrictHeating, DistrictAmbient
  # @param cooling_source [String] Valid choices are
  # Electricity, DistrictCooling, DistrictAmbient
  # @param area_m2 [Double] Area in m^2
  # @param num_stories [Integer] Number of stories
  # @return [String] The system type.  Possibilities are
  # PTHP, PTAC, PSZ_AC, PSZ_HP, PVAV_Reheat, PVAV_PFP_Boxes,
  # VAV_Reheat, VAV_PFP_Boxes, Gas_Furnace, Electric_Furnace
  def model_typical_hvac_system_type(model,
                                     climate_zone,
                                     area_type,
                                     delivery_type,
                                     heating_source,
                                     cooling_source,
                                     area_m2,
                                     num_stories)
    #             [type, central_heating_fuel, zone_heating_fuel, cooling_fuel]
    system_type = [nil, nil, nil, nil]

    # Convert area to ft^2
    area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get

    # categorize building by type & size
    size_category = nil
    case area_type
    when 'residential'
      # residential and less than 4 stories
      size_category = if num_stories <= 3
                        'res_small'
                      # residential and more than 4 stories
                      else
                        'res_med'
                      end
    when 'nonresidential', 'retail', 'publicassembly', 'heatedonly'
      # nonresidential and 3 floors or less and < 75,000 ft2
      if num_stories <= 3 && area_ft2 < 75_000
        size_category = 'nonres_small'
      # nonresidential and 4 or 5 floors OR 5 floors or less and 75,000 ft2 to 150,000 ft2
      elsif ((num_stories == 4 || num_stories == 5) && area_ft2 < 75_000) || (num_stories <= 5 && (area_ft2 >= 75_000 && area_ft2 <= 150_000))
        size_category = 'nonres_med'
      # nonresidential and more than 5 floors or >150,000 ft2
      elsif num_stories >= 5 || area_ft2 > 150_000
        size_category = 'nonres_lg'
      end
    end

    # Define the lookup by row and by fuel type
    syts = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    # [heating_source][cooling_source][delivery_type][size_category]
    #  = [type, central_heating_fuel, zone_heating_fuel, cooling_fuel]

    ## Forced Air ##

    # Gas, Electric, forced air
    syts['NaturalGas']['Electricity']['air']['res_small'] = ['PTAC', 'NaturalGas', nil, 'Electricity']
    syts['NaturalGas']['Electricity']['air']['res_med'] = ['PTAC', 'NaturalGas', nil, 'Electricity']
    syts['NaturalGas']['Electricity']['air']['nonres_small'] = ['PSZ-AC', 'NaturalGas', nil, 'Electricity']
    syts['NaturalGas']['Electricity']['air']['nonres_med'] = ['PVAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity']
    syts['NaturalGas']['Electricity']['air']['nonres_lg'] = ['VAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity']

    # Electric, Electric, forced air
    syts['Electricity']['Electricity']['air']['res_small'] = ['PTHP', 'Electricity', nil, 'Electricity']
    syts['Electricity']['Electricity']['air']['res_med'] = ['PTHP', 'Electricity', nil, 'Electricity']
    syts['Electricity']['Electricity']['air']['nonres_small'] = ['PSZ-HP', 'Electricity', nil, 'Electricity']
    syts['Electricity']['Electricity']['air']['nonres_med'] = ['PVAV PFP Boxes', 'Electricity', 'Electricity', 'Electricity']
    syts['Electricity']['Electricity']['air']['nonres_lg'] = ['VAV PFP Boxes', 'Electricity', 'Electricity', 'Electricity']

    # District Hot Water, Electric, forced air
    syts['DistrictHeating']['Electricity']['air']['res_small'] = ['PTAC', 'DistrictHeating', nil, 'Electricity']
    syts['DistrictHeating']['Electricity']['air']['res_med'] = ['PTAC', 'DistrictHeating', nil, 'Electricity']
    syts['DistrictHeating']['Electricity']['air']['nonres_small'] = ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity']
    syts['DistrictHeating']['Electricity']['air']['nonres_med'] = ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity']
    syts['DistrictHeating']['Electricity']['air']['nonres_lg'] = ['VAV Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity']

    # Ambient Loop, Ambient Loop, forced air
    syts['DistrictAmbient']['DistrictAmbient']['air']['res_small'] = ['Water Source Heat Pumps with ERVs', 'HeatPump', nil, 'HeatPump']
    syts['DistrictAmbient']['DistrictAmbient']['air']['res_med'] = ['Water Source Heat Pumps with DOAS', 'HeatPump', nil, 'HeatPump']
    syts['DistrictAmbient']['DistrictAmbient']['air']['nonres_small'] = ['PVAV Reheat', 'HeatPump', 'HeatPump', 'HeatPump']
    syts['DistrictAmbient']['DistrictAmbient']['air']['nonres_med'] = ['PVAV Reheat', 'HeatPump', 'HeatPump', 'HeatPump']
    syts['DistrictAmbient']['DistrictAmbient']['air']['nonres_lg'] = ['VAV Reheat', 'HeatPump', 'HeatPump', 'HeatPump']

    # Gas, District Chilled Water, forced air
    syts['NaturalGas']['DistrictCooling']['air']['res_small'] = ['PSZ-AC', 'NaturalGas', nil, 'DistrictCooling']
    syts['NaturalGas']['DistrictCooling']['air']['res_med'] = ['PSZ-AC', 'NaturalGas', nil, 'DistrictCooling']
    syts['NaturalGas']['DistrictCooling']['air']['nonres_small'] = ['PSZ-AC', 'NaturalGas', nil, 'DistrictCooling']
    syts['NaturalGas']['DistrictCooling']['air']['nonres_med'] = ['PVAV Reheat', 'NaturalGas', 'NaturalGas', 'DistrictCooling']
    syts['NaturalGas']['DistrictCooling']['air']['nonres_lg'] = ['VAV Reheat', 'NaturalGas', 'NaturalGas', 'DistrictCooling']

    # Electric, District Chilled Water, forced air
    syts['Electricity']['DistrictCooling']['air']['res_small'] = ['PSZ-AC', 'Electricity', nil, 'DistrictCooling']
    syts['Electricity']['DistrictCooling']['air']['res_med'] = ['PSZ-AC', 'Electricity', nil, 'DistrictCooling']
    syts['Electricity']['DistrictCooling']['air']['nonres_small'] = ['PSZ-AC', 'Electricity', nil, 'DistrictCooling']
    syts['Electricity']['DistrictCooling']['air']['nonres_med'] = ['PVAV Reheat', 'Electricity', 'Electricity', 'DistrictCooling']
    syts['Electricity']['DistrictCooling']['air']['nonres_lg'] = ['VAV Reheat', 'Electricity', 'Electricity', 'DistrictCooling']

    # District Hot Water, District Chilled Water, forced air
    syts['DistrictHeating']['DistrictCooling']['air']['res_small'] = ['PSZ-AC', 'DistrictHeating', nil, 'DistrictCooling']
    syts['DistrictHeating']['DistrictCooling']['air']['res_med'] = ['PSZ-AC', 'DistrictHeating', nil, 'DistrictCooling']
    syts['DistrictHeating']['DistrictCooling']['air']['nonres_small'] = ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']
    syts['DistrictHeating']['DistrictCooling']['air']['nonres_med'] = ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']
    syts['DistrictHeating']['DistrictCooling']['air']['nonres_lg'] = ['VAV Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']

    ## Hydronic ##

    # Gas, Electric, hydronic
    syts['NaturalGas']['Electricity']['hydronic']['res_med'] = ['Fan Coil with DOAS', 'NaturalGas', nil, 'Electricity']
    syts['NaturalGas']['Electricity']['hydronic']['nonres_small'] = ['Water Source Heat Pumps with DOAS', 'NaturalGas', nil, 'Electricity']
    syts['NaturalGas']['Electricity']['hydronic']['nonres_med'] = ['Fan Coil with DOAS', 'NaturalGas', 'NaturalGas', 'Electricity']
    syts['NaturalGas']['Electricity']['hydronic']['nonres_lg'] = ['Fan Coil with DOAS', 'NaturalGas', 'NaturalGas', 'Electricity']

    # Electric, Electric, hydronic
    syts['Electricity']['Electricity']['hydronic']['res_small'] = ['Ground Source Heat Pumps with ERVs', 'Electricity', nil, 'Electricity']
    syts['Electricity']['Electricity']['hydronic']['res_med'] = ['Ground Source Heat Pumps with DOAS', 'Electricity', nil, 'Electricity']
    syts['Electricity']['Electricity']['hydronic']['nonres_small'] = ['Ground Source Heat Pumps with DOAS', 'Electricity', nil, 'Electricity']
    syts['Electricity']['Electricity']['hydronic']['nonres_med'] = ['Ground Source Heat Pumps with DOAS', 'Electricity', 'Electricity', 'Electricity']
    syts['Electricity']['Electricity']['hydronic']['nonres_lg'] = ['Ground Source Heat Pumps with DOAS', 'Electricity', 'Electricity', 'Electricity']

    # District Hot Water, Electric, hydronic
    syts['DistrictHeating']['Electricity']['hydronic']['res_small'] = [] # TODO decide if there is anything reasonable for this
    syts['DistrictHeating']['Electricity']['hydronic']['res_med'] = ['Fan Coil with DOAS', 'DistrictHeating', nil, 'Electricity']
    syts['DistrictHeating']['Electricity']['hydronic']['nonres_small'] = ['Water Source Heat Pumps with DOAS', 'DistrictHeating', 'DistrictHeating', 'Electricity']
    syts['DistrictHeating']['Electricity']['hydronic']['nonres_med'] = ['Fan Coil with DOAS', 'DistrictHeating', 'DistrictHeating', 'Electricity']
    syts['DistrictHeating']['Electricity']['hydronic']['nonres_lg'] = ['Fan Coil with DOAS', 'DistrictHeating', 'DistrictHeating', 'Electricity']

    # Ambient Loop, Ambient Loop, hydronic
    syts['DistrictAmbient']['DistrictAmbient']['hydronic']['res_small'] = ['Water Source Heat Pumps with ERVs', 'HeatPump', nil, 'HeatPump']
    syts['DistrictAmbient']['DistrictAmbient']['hydronic']['res_med'] = ['Water Source Heat Pumps with DOAS', 'HeatPump', nil, 'HeatPump']
    syts['DistrictAmbient']['DistrictAmbient']['hydronic']['nonres_small'] = ['Water Source Heat Pumps with DOAS', 'HeatPump', 'HeatPump', 'HeatPump']
    syts['DistrictAmbient']['DistrictAmbient']['hydronic']['nonres_med'] = ['Water Source Heat Pumps with DOAS', 'HeatPump', 'HeatPump', 'HeatPump']
    syts['DistrictAmbient']['DistrictAmbient']['hydronic']['nonres_lg'] = ['Fan Coil with DOAS', 'DistrictHeating', nil, 'Electricity'] # TODO: is this reasonable?

    # Gas, District Chilled Water, hydronic
    syts['NaturalGas']['DistrictCooling']['hydronic']['res_med'] = ['Fan Coil with DOAS', 'NaturalGas', nil, 'DistrictCooling']
    syts['NaturalGas']['DistrictCooling']['hydronic']['nonres_small'] = ['Fan Coil with DOAS', 'NaturalGas', nil, 'DistrictCooling']
    syts['NaturalGas']['DistrictCooling']['hydronic']['nonres_med'] = ['Fan Coil with DOAS', 'NaturalGas', 'NaturalGas', 'DistrictCooling']
    syts['NaturalGas']['DistrictCooling']['hydronic']['nonres_lg'] = ['Fan Coil with DOAS', 'NaturalGas', 'NaturalGas', 'DistrictCooling']

    # Electric, District Chilled Water, hydronic
    syts['Electricity']['DistrictCooling']['hydronic']['res_med'] = ['Fan Coil with ERVs', 'Electricity', nil, 'DistrictCooling']
    syts['Electricity']['DistrictCooling']['hydronic']['nonres_small'] = ['Fan Coil with DOAS', 'Electricity', nil, 'DistrictCooling']
    syts['Electricity']['DistrictCooling']['hydronic']['nonres_med'] = ['Fan Coil with DOAS', 'Electricity', 'Electricity', 'DistrictCooling']
    syts['Electricity']['DistrictCooling']['hydronic']['nonres_lg'] = ['Fan Coil with DOAS', 'Electricity', 'Electricity', 'DistrictCooling']

    # District Hot Water, District Chilled Water, hydronic
    syts['DistrictHeating']['DistrictCooling']['hydronic']['res_small'] = ['Fan Coil with ERVs', 'DistrictHeating', nil, 'DistrictCooling']
    syts['DistrictHeating']['DistrictCooling']['hydronic']['res_med'] = ['Fan Coil with DOAS', 'DistrictHeating', nil, 'DistrictCooling']
    syts['DistrictHeating']['DistrictCooling']['hydronic']['nonres_small'] = ['Fan Coil with DOAS', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']
    syts['DistrictHeating']['DistrictCooling']['hydronic']['nonres_med'] = ['Fan Coil with DOAS', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']
    syts['DistrictHeating']['DistrictCooling']['hydronic']['nonres_lg'] = ['Fan Coil with DOAS', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']

    # Get the system type
    system_type = syts[heating_source][cooling_source][delivery_type][size_category]

    if system_type.nil? || system_type.empty?
      system_type = [nil, nil, nil, nil]
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not determine system type for #{template}, #{area_type}, #{heating_source} heating, #{cooling_source} cooling, #{delivery_type} delivery, #{area_ft2.round} ft^2, #{num_stories} stories.")
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "System type is #{system_type[0]} for #{template}, #{area_type}, #{heating_source} heating, #{cooling_source} cooling, #{delivery_type} delivery, #{area_ft2.round} ft^2, #{num_stories} stories.")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{system_type[1]} for main heating") unless system_type[1].nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{system_type[2]} for zone heat/reheat") unless system_type[2].nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{system_type[3]} for cooling") unless system_type[3].nil?
    end

    return system_type
  end

  # This method will add an swh water fixture to the model for the space.
  # if the it will return a water fixture object, or NIL if there is no water load at all.
  def model_add_swh_end_uses_by_spaceonly(model, space, swh_loop)
    # Water use connection
    swh_connection = OpenStudio::Model::WaterUseConnections.new(model)

    # Water fixture definition
    water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(model)

    # water_use_sensible_frac_sch = OpenStudio::Model::ScheduleConstant.new(self)
    # water_use_sensible_frac_sch.setValue(0.2)
    # water_use_latent_frac_sch = OpenStudio::Model::ScheduleConstant.new(self)
    # water_use_latent_frac_sch.setValue(0.05)
    rated_flow_rate_gal_per_min = OpenStudio.convert(space['shw_peakflow_SI'], 'm^3/s', 'gal/min').get
    water_use_sensible_frac_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    water_use_sensible_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
    water_use_latent_frac_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    water_use_latent_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.05)
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(space['shw_peakflow_SI'])
    water_fixture_def.setName("#{space['shw_spaces'].name.to_s.capitalize} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    # Target mixed water temperature
    mixed_water_temp_c = space['shw_temp_SI']
    mixed_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    mixed_water_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), mixed_water_temp_c)
    water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

    # Water use equipment
    water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
    schedule = model_add_schedule(model, space['shw_sched'])
    water_fixture.setFlowRateFractionSchedule(schedule)
    water_fixture.setName("#{space['shw_spaces'].name.to_s.capitalize} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    swh_connection.addWaterUseEquipment(water_fixture)
    # Assign water fixture to a space
    water_fixture.setSpace(space['shw_spaces']) if model_attach_water_fixtures_to_spaces?(model)

    # Connect the water use connection to the SWH loop
    swh_loop.addDemandBranchForComponent(swh_connection)
    return water_fixture
  end
end

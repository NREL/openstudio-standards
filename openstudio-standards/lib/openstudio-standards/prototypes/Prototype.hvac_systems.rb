
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model
  require_relative 'Prototype.AirTerminalSingleDuctVAVReheat'

  # Creates a hot water loop with one boiler or district heating
  # and add it to the model.
  #
  # @param boiler_fuel_type [String] valid choices are Electricity, NaturalGas, PropaneGas, FuelOil#1, FuelOil#2, DistrictHeating
  # @return [OpenStudio::Model::PlantLoop] the resulting hot water loop
  def add_hw_loop(boiler_fuel_type, building_type = nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding hot water loop.')

    # hot water loop
    hot_water_loop = OpenStudio::Model::PlantLoop.new(self)
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
    hw_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    hw_temp_sch.setName("Hot Water Loop Temp - #{hw_temp_f}F")
    hw_temp_sch.defaultDaySchedule.setName("Hot Water Loop Temp - #{hw_temp_f}F Default")
    hw_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), hw_temp_c)
    hw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, hw_temp_sch)
    hw_stpt_manager.setName('Hot water loop setpoint manager')
    hw_stpt_manager.addToNode(hot_water_loop.supplyOutletNode)
    sizing_plant = hot_water_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(hw_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(hw_delta_t_k)

    # hot water pump
    hw_pump = if building_type == 'Outpatient'
                OpenStudio::Model::PumpConstantSpeed.new(self)
              else
                OpenStudio::Model::PumpVariableSpeed.new(self)
              end
    hw_pump.setName('Hot Water Loop Pump')
    hw_pump_head_ft_h2o = 60.0
    hw_pump_head_press_pa = OpenStudio.convert(hw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
    hw_pump.setRatedPumpHead(hw_pump_head_press_pa)
    hw_pump.setMotorEfficiency(0.9)
    hw_pump.setPumpControlType('Intermittent')
    hw_pump.addToNode(hot_water_loop.supplyInletNode)

    # DistrictHeating
    if boiler_fuel_type == 'DistrictHeating'
      dist_ht = OpenStudio::Model::DistrictHeating.new(self)
      dist_ht.setName('Purchased Heating')
      dist_ht.autosizeNominalCapacity
      hot_water_loop.addSupplyBranchForComponent(dist_ht)
    # Boiler
    else
      boiler_max_t_f = 203
      boiler_max_t_c = OpenStudio.convert(boiler_max_t_f, 'F', 'C').get
      boiler = OpenStudio::Model::BoilerHotWater.new(self)
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
    end

    # hot water loop pipes
    boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    hot_water_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    hot_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_outlet_pipe.addToNode(hot_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_inlet_pipe.addToNode(hot_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_outlet_pipe.addToNode(hot_water_loop.demandOutletNode)

    return hot_water_loop
  end

  # Creates a chilled water loop and adds it to the model.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param chw_pumping_type [String] valid choices are const_pri, const_pri_var_sec
  # @param chiller_cooling_type [String] valid choices are AirCooled, WaterCooled
  # @param chiller_condenser_type [String] valid choices are WithCondenser, WithoutCondenser, nil
  # @param chiller_compressor_type [String] valid choices are Centrifugal, Reciprocating, Rotary Screw, Scroll, nil
  # @param cooling_fuel [String] cooling fuel. Valid choices are:
  # Electricity, DistrictCooling
  # @param condenser_water_loop [OpenStudio::Model::PlantLoop] optional condenser water loop
  #   for water-cooled chillers.  If this is not passed in, the chillers will be air cooled.
  # @return [OpenStudio::Model::PlantLoop] the resulting chilled water loop
  def add_chw_loop(template,
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
    chilled_water_loop = OpenStudio::Model::PlantLoop.new(self)
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
    chw_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    chw_temp_sch.setName("Chilled Water Loop Temp - #{chw_temp_f}F")
    chw_temp_sch.defaultDaySchedule.setName("Chilled Water Loop Temp - #{chw_temp_f}F Default")
    chw_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), chw_temp_c)
    chw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, chw_temp_sch)
    chw_stpt_manager.setName('Chilled water loop setpoint manager')
    chw_stpt_manager.addToNode(chilled_water_loop.supplyOutletNode)

    sizing_plant = chilled_water_loop.sizingPlant
    sizing_plant.setLoopType('Cooling')
    sizing_plant.setDesignLoopExitTemperature(chw_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(chw_delta_t_k)

    # Chilled water pumps
    if chw_pumping_type == 'const_pri'
      # Primary chilled water pump
      pri_chw_pump = OpenStudio::Model::PumpVariableSpeed.new(self)
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
      pri_chw_pump = OpenStudio::Model::PumpConstantSpeed.new(self)
      pri_chw_pump.setName('Chilled Water Loop Primary Pump')
      pri_chw_pump_head_ft_h2o = 15
      pri_chw_pump_head_press_pa = OpenStudio.convert(pri_chw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      pri_chw_pump.setRatedPumpHead(pri_chw_pump_head_press_pa)
      pri_chw_pump.setMotorEfficiency(0.9)
      pri_chw_pump.setPumpControlType('Intermittent')
      pri_chw_pump.addToNode(chilled_water_loop.supplyInletNode)
      # Secondary chilled water pump
      sec_chw_pump = OpenStudio::Model::PumpVariableSpeed.new(self)
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
      dist_clg = OpenStudio::Model::DistrictCooling.new(self)
      dist_clg.setName('Purchased Cooling')
      dist_clg.autosizeNominalCapacity
      chilled_water_loop.addSupplyBranchForComponent(dist_clg)
    # Chiller
    else

      # Make the correct type of chiller based these properties
      num_chillers.times do |i|
        chiller = OpenStudio::Model::ChillerElectricEIR.new(self)
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
    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    chilled_water_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    chilled_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_outlet_pipe.addToNode(chilled_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_inlet_pipe.addToNode(chilled_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
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
  def add_cw_loop(template,
                  cooling_tower_type,
                  cooling_tower_fan_type,
                  cooling_tower_capacity_control,
                  number_of_cells_per_tower,
                  number_cooling_towers = 1,
                  building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding condenser water loop.')

    # Condenser water loop
    condenser_water_loop = OpenStudio::Model::PlantLoop.new(self)
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
    cw_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    cw_temp_sch.setName("Condenser Water Loop Temp - #{cw_temp_f}F")
    cw_temp_sch.defaultDaySchedule.setName("Condenser Water Loop Temp - #{cw_temp_f}F Default")
    cw_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), cw_temp_c)
    cw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, cw_temp_sch)
    cw_stpt_manager.addToNode(condenser_water_loop.supplyOutletNode)
    sizing_plant = condenser_water_loop.sizingPlant
    sizing_plant.setLoopType('Condenser')
    sizing_plant.setDesignLoopExitTemperature(cw_temp_sizing_c)
    sizing_plant.setLoopDesignTemperatureDifference(cw_delta_t_k)

    # Condenser water pump
    if building_type == 'Hospital' && (template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980')
      cw_pump = OpenStudio::Model::PumpConstantSpeed.new(self)
      cw_pump.setName('Condenser Water Loop Pump')
      cw_pump_head_ft_h2o = 60.0
      cw_pump_head_press_pa = OpenStudio.convert(cw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      cw_pump.setRatedPumpHead(cw_pump_head_press_pa)
      cw_pump.addToNode(condenser_water_loop.supplyInletNode)
    else
      # Condenser water pump #TODO make this into a HeaderedPump:VariableSpeed
      cw_pump = OpenStudio::Model::PumpVariableSpeed.new(self)
      cw_pump.setName('Condenser Water Loop Pump')
      cw_pump_head_ft_h2o = 49.7
      cw_pump_head_press_pa = OpenStudio.convert(cw_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
      cw_pump.setRatedPumpHead(cw_pump_head_press_pa)
      # Curve makes it perform like variable speed pump
      cw_pump.setFractionofMotorInefficienciestoFluidStream(0)
      cw_pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
      cw_pump.setCoefficient2ofthePartLoadPerformanceCurve(0.0216)
      cw_pump.setCoefficient3ofthePartLoadPerformanceCurve(-0.0325)
      cw_pump.setCoefficient4ofthePartLoadPerformanceCurve(1.0095)
      cw_pump.setPumpControlType('Intermittent')
      cw_pump.addToNode(condenser_water_loop.supplyInletNode)
    end

    # Cooling towers
    # Per PNNL PRM Reference Manual
    number_cooling_towers.times do |_i|
      sizing_factor = 1 / number_cooling_towers
      twr_name = "#{cooling_tower_fan_type} #{cooling_tower_capacity_control} #{cooling_tower_type}"

      # Tower object depends on the control type
      cooling_tower = nil
      case cooling_tower_capacity_control
      when 'Fluid Bypass', 'Fan Cycling'
        cooling_tower = OpenStudio::Model::CoolingTowerSingleSpeed.new(self)
        if cooling_tower_capacity_control == 'Fluid Bypass'
          cooling_tower.setCellControl('FluidBypass')
        else
          cooling_tower.setCellControl('FanCycling')
        end
      when 'TwoSpeed Fan'
        cooling_tower = OpenStudio::Model::CoolingTowerTwoSpeed.new(self)
        # TODO: expose newer cooling tower sizing fields in API
        # cooling_tower.setLowFanSpeedAirFlowRateSizingFactor(0.5)
        # cooling_tower.setLowFanSpeedFanPowerSizingFactor(0.3)
        # cooling_tower.setLowFanSpeedUFactorTimesAreaSizingFactor
        # cooling_tower.setLowSpeedNominalCapacitySizingFactor
      when 'Variable Speed Fan'
        cooling_tower = OpenStudio::Model::CoolingTowerVariableSpeed.new(self)
        cooling_tower.setDesignApproachTemperature(cw_approach_delta_t_k)
        cooling_tower.setDesignRangeTemperature(cw_delta_t_k)
        cooling_tower.setFractionofTowerCapacityinFreeConvectionRegime(0.125)
        twr_fan_curve = add_curve('VSD-TWR-FAN-FPLR')
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
    cooling_tower_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    condenser_water_loop.addSupplyBranchForComponent(cooling_tower_bypass_pipe)
    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    condenser_water_loop.addDemandBranchForComponent(chiller_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_outlet_pipe.addToNode(condenser_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_inlet_pipe.addToNode(condenser_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_outlet_pipe.addToNode(condenser_water_loop.demandOutletNode)

    return condenser_water_loop
  end

  # Creates a heat pump loop which has a boiler and fluid cooler
  #   for supplemental heating/cooling and adds it to the model.
  #
  # @return [OpenStudio::Model::PlantLoop] the resulting plant loop
  # @todo replace cooling tower with fluid cooler once added to OS 1.9.0
  def add_hp_loop(building_type = nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding heat pump loop.')

    # Heat Pump loop
    heat_pump_water_loop = OpenStudio::Model::PlantLoop.new(self)
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

    hp_high_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    hp_high_temp_sch.setName("Heat Pump Loop High Temp - #{hp_high_temp_f}F")
    hp_high_temp_sch.defaultDaySchedule.setName("Heat Pump Loop High Temp - #{hp_high_temp_f}F Default")
    hp_high_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), hp_high_temp_c)

    hp_low_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    hp_low_temp_sch.setName("Heat Pump Loop Low Temp - #{hp_low_temp_f}F")
    hp_low_temp_sch.defaultDaySchedule.setName("Heat Pump Loop Low Temp - #{hp_low_temp_f}F Default")
    hp_low_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), hp_low_temp_c)

    hp_stpt_manager = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(self)
    hp_stpt_manager.setHighSetpointSchedule(hp_high_temp_sch)
    hp_stpt_manager.setLowSetpointSchedule(hp_low_temp_sch)
    hp_stpt_manager.addToNode(heat_pump_water_loop.supplyOutletNode)

    sizing_plant = heat_pump_water_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(hp_temp_sizing_c)
    sizing_plant.setLoopDesignTemperatureDifference(hp_delta_t_k)

    # Heat Pump loop pump
    hp_pump = OpenStudio::Model::PumpConstantSpeed.new(self)
    hp_pump.setName('Heat Pump Loop Pump')
    hp_pump_head_ft_h2o = 60
    hp_pump_head_press_pa = OpenStudio.convert(hp_pump_head_ft_h2o, 'ftH_{2}O', 'Pa').get
    hp_pump.setRatedPumpHead(hp_pump_head_press_pa)
    hp_pump.setPumpControlType('Intermittent')
    hp_pump.addToNode(heat_pump_water_loop.supplyInletNode)

    # Cooling towers
    if building_type == 'LargeOffice'
      # TODO: For some reason the FluidCoolorTwoSpeed is causing simulation failures.
      # might need to look into the defaults
      # cooling_tower = OpenStudio::Model::FluidCoolerTwoSpeed.new(self)
      cooling_tower = OpenStudio::Model::CoolingTowerTwoSpeed.new(self)
      cooling_tower.setName("#{heat_pump_water_loop.name} Central Tower")
      heat_pump_water_loop.addSupplyBranchForComponent(cooling_tower)
      #### Add SPM Scheduled Dual Setpoint to outlet of Fluid Cooler so correct Plant Operation Scheme is generated
      hp_stpt_manager_2 = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(self)
      hp_stpt_manager_2.setHighSetpointSchedule(hp_high_temp_sch)
      hp_stpt_manager_2.setLowSetpointSchedule(hp_low_temp_sch)
      hp_stpt_manager_2.addToNode(cooling_tower.outletModelObject.get.to_Node.get)

    else
      # TODO: replace with FluidCooler:TwoSpeed when available
      # cooling_tower = OpenStudio::Model::CoolingTowerTwoSpeed.new(self)
      # cooling_tower.setName("#{heat_pump_water_loop.name} Sup Cooling Tower")
      # heat_pump_water_loop.addSupplyBranchForComponent(cooling_tower)
      fluid_cooler = OpenStudio::Model::EvaporativeFluidCoolerSingleSpeed.new(self)
      fluid_cooler.setName("#{heat_pump_water_loop.name} Sup Cooling Tower")
      fluid_cooler.setDesignSprayWaterFlowRate(0.002208) # Based on HighRiseApartment
      fluid_cooler.setPerformanceInputMethod('UFactorTimesAreaAndDesignWaterFlowRate')
      heat_pump_water_loop.addSupplyBranchForComponent(fluid_cooler)
    end

    # Boiler
    boiler = OpenStudio::Model::BoilerHotWater.new(self)
    boiler.setName("#{heat_pump_water_loop.name} Sup Boiler")
    boiler.setFuelType('Gas')
    boiler.setDesignWaterOutletTemperature(boiler_hw_temp_c)
    boiler.setMinimumPartLoadRatio(0)
    boiler.setMaximumPartLoadRatio(1.2)
    boiler.setOptimumPartLoadRatio(1)
    boiler.setBoilerFlowMode('ConstantFlow')
    heat_pump_water_loop.addSupplyBranchForComponent(boiler)
    #### Add SPM Scheduled Dual Setpoint to outlet of Boiler so correct Plant Operation Scheme is generated
    hp_stpt_manager_3 = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(self)
    hp_stpt_manager_3.setHighSetpointSchedule(hp_high_temp_sch)
    hp_stpt_manager_3.setLowSetpointSchedule(hp_low_temp_sch)
    hp_stpt_manager_3.addToNode(boiler.outletModelObject.get.to_Node.get)

    # Heat Pump water loop pipes
    supply_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_bypass_pipe.setName("#{heat_pump_water_loop.name} Supply Bypass")
    heat_pump_water_loop.addSupplyBranchForComponent(supply_bypass_pipe)

    demand_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_bypass_pipe.setName("#{heat_pump_water_loop.name} Demand Bypass")
    heat_pump_water_loop.addDemandBranchForComponent(demand_bypass_pipe)

    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_outlet_pipe.setName("#{heat_pump_water_loop.name} Supply Outlet")
    supply_outlet_pipe.addToNode(heat_pump_water_loop.supplyOutletNode)

    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_inlet_pipe.setName("#{heat_pump_water_loop.name} Demand Inlet")
    demand_inlet_pipe.addToNode(heat_pump_water_loop.demandInletNode)

    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_outlet_pipe.setName("#{heat_pump_water_loop.name} Demand Outlet")
    demand_outlet_pipe.addToNode(heat_pump_water_loop.demandOutletNode)

    return heat_pump_water_loop
  end

  # Creates a VAV system and adds it to the model.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  # @param electric_reheat [Bool] if true, this system will have electric reheat coils,
  # but if false, the reheat coils will be served by the hot_water_loop.
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting VAV air loop
  def add_vav_reheat(template,
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
                     electric_reheat = false,
                     building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding VAV system for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    hw_temp_f = 180 # HW setpoint 180F
    hw_delta_t_r = 20 # 20F delta-T
    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get

    if building_type == 'LargeHotel'
      rht_sa_temp_f = 90 # VAV box reheat to 90F for large hotel
      zone_htg_sa_temp_f = 104 # Zone heating design supply air temperature to 104 F
    else
      rht_sa_temp_f = 104 # VAV box reheat to 104F
      zone_htg_sa_temp_f = 104 # Zone heating design supply air temperature to 104 F
    end

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      alwaysOnDiscreteSchedule
                    else
                      add_schedule(oa_damper_sch)
                    end

    # control temps used across all air handlers
    clg_sa_temp_f = 55.04 # Central deck clg temp 55F
    prehtg_sa_temp_f = 44.6 # Preheat to 44.6F
    preclg_sa_temp_f = 55.04 # Precool to 55F
    htg_sa_temp_f = 55.04 # Central deck htg temp 55F
    if building_type == 'LargeHotel'
      htg_sa_temp_f = 62 # Central deck htg temp 55F
    end
    rht_sa_temp_f = 104 # VAV box reheat to 104F
    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get
    prehtg_sa_temp_c = OpenStudio.convert(prehtg_sa_temp_f, 'F', 'C').get
    preclg_sa_temp_c = OpenStudio.convert(preclg_sa_temp_f, 'F', 'C').get
    htg_sa_temp_c = OpenStudio.convert(htg_sa_temp_f, 'F', 'C').get
    rht_sa_temp_c = OpenStudio.convert(rht_sa_temp_f, 'F', 'C').get
    zone_htg_sa_temp_c = OpenStudio.convert(zone_htg_sa_temp_f, 'F', 'C').get
    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
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
    air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, sa_temp_sch)
    sa_stpt_manager.setName("#{thermal_zones.size} Zone VAV supply air setpoint manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # air handler controls
    sizing_system = air_loop.sizingSystem
    sizing_system.setMinimumSystemAirFlowRatio(air_flow_ratio)
    sizing_system.setPreheatDesignTemperature(prehtg_sa_temp_c)
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
    fan = OpenStudio::Model::FanVariableVolume.new(self, alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.setFanEfficiency(vav_fan_efficiency)
    fan.setMotorEfficiency(vav_fan_motor_efficiency)
    fan.setPressureRise(vav_fan_pressure_rise)
    fan.setFanPowerMinimumFlowRateInputMethod('fraction')
    fan.setFanPowerMinimumFlowFraction(0.25)
    fan.addToNode(air_loop.supplyInletNode)
    fan.setEndUseSubcategory('VAV system Fans')

    # heating coil
    htg_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
    htg_coil.addToNode(air_loop.supplyInletNode)
    hot_water_loop.addDemandBranchForComponent(htg_coil)
    htg_coil.setName("#{air_loop.name} Main Htg Coil")
    htg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Main Htg Coil Controller")
    htg_coil.setRatedInletWaterTemperature(hw_temp_c)
    htg_coil.setRatedInletAirTemperature(prehtg_sa_temp_c)
    htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
    htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)
    if building_type == 'LargeHotel'
      htg_coil.setRatedInletAirTemperature(htg_sa_temp_c)
      htg_coil.setRatedOutletAirTemperature(rht_sa_temp_c)
    else
      htg_coil.setRatedInletAirTemperature(prehtg_sa_temp_c)
      htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)
    end

    # cooling coil
    clg_coil = OpenStudio::Model::CoilCoolingWater.new(self, alwaysOnDiscreteSchedule)
    clg_coil.setName("#{air_loop.name} Clg Coil")
    clg_coil.addToNode(air_loop.supplyInletNode)
    clg_coil.setHeatExchangerConfiguration('CrossFlow')
    chilled_water_loop.addDemandBranchForComponent(clg_coil)
    clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")

    # outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(self)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    # oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')

    if building_type == 'LargeHotel'
      oa_intake_controller.setEconomizerControlType('DifferentialEnthalpy')
      oa_intake_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')
      oa_intake_controller.resetMaximumFractionofOutdoorAirSchedule
      oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
    end

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system need to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    # hook the VAV system to each zone
    thermal_zones.each do |zone|
      # reheat coil
      rht_coil = nil
      if electric_reheat
        rht_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
      else
        rht_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
        rht_coil.setRatedInletWaterTemperature(hw_temp_c)
        rht_coil.setRatedInletAirTemperature(htg_sa_temp_c)
        rht_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        rht_coil.setRatedOutletAirTemperature(rht_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(rht_coil)
      end

      # vav terminal
      terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(self, alwaysOnDiscreteSchedule, rht_coil)
      terminal.setName("#{zone.name} VAV Term")
      terminal.setZoneMinimumAirFlowMethod('Constant')
      terminal.apply_initial_prototype_damper_position(building_type, template, zone.outdoor_airflow_rate_per_area)
      terminal.setMaximumFlowPerZoneFloorAreaDuringReheat(0.0)
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
      # sizing_zone.setZoneHeatingDesignSupplyAirTemperature(rht_sa_temp_c)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(zone_htg_sa_temp_c)

      unless return_plenum.nil?
        zone.setReturnPlenum(return_plenum)
      end
    end

    # Set the damper action based on the template.
    air_loop.apply_vav_damper_action(template)

    return air_loop
  end

  # Creates a VAV system with parallel fan powered boxes and adds it to the model.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_vav_pfp_boxes(template,
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
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      alwaysOnDiscreteSchedule
                    else
                      add_schedule(oa_damper_sch)
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

    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

    # air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV with PFP Boxes and Reheat")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, sa_temp_sch)
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
    fan = OpenStudio::Model::FanVariableVolume.new(self, alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.setFanEfficiency(vav_fan_efficiency)
    fan.setMotorEfficiency(vav_fan_motor_efficiency)
    fan.setPressureRise(vav_fan_pressure_rise)
    fan.setFanPowerMinimumFlowRateInputMethod('fraction')
    fan.setFanPowerMinimumFlowFraction(0.25)
    fan.addToNode(air_loop.supplyInletNode)
    fan.setEndUseSubcategory('VAV system Fans')

    # heating coil
    htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
    htg_coil.setName("#{air_loop.name} Htg Coil")
    htg_coil.addToNode(air_loop.supplyInletNode)

    # cooling coil
    clg_coil = OpenStudio::Model::CoilCoolingWater.new(self, alwaysOnDiscreteSchedule)
    clg_coil.setName("#{air_loop.name} Clg Coil")
    clg_coil.addToNode(air_loop.supplyInletNode)
    clg_coil.setHeatExchangerConfiguration('CrossFlow')
    chilled_water_loop.addDemandBranchForComponent(clg_coil)
    clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")

    # outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(self)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    # oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system need to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    # hook the VAV system to each zone
    thermal_zones.each do |zone|
      # reheat coil
      rht_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
      rht_coil.setName("#{zone.name} Rht Coil")

      # terminal fan
      pfp_fan = OpenStudio::Model::FanConstantVolume.new(self, alwaysOnDiscreteSchedule)
      pfp_fan.setName("#{zone.name} PFP Term Fan")
      pfp_fan.setPressureRise(300)

      # parallel fan powered terminal
      pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(self,
                                                                                   alwaysOnDiscreteSchedule,
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
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_pvav(template,
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
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      alwaysOnDiscreteSchedule
                    else
                      add_schedule(oa_damper_sch)
                    end

    # Control temps for HW loop
    # will only be used when hot_water_loop is provided.
    hw_temp_f = 180 # HW setpoint 180F
    hw_delta_t_r = 20 # 20F delta-T

    hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
    hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get

    # Control temps used across all air handlers
    # TODO why aren't design and operational temps coordinated?
    sys_dsn_prhtg_temp_f = 44.6 # Design central deck to preheat to 44.6F
    sys_dsn_clg_sa_temp_f = 57.2 # Design central deck to cool to 57.2F
    sys_dsn_htg_sa_temp_f = 62 # Central heat to 62F
    zn_dsn_clg_sa_temp_f = 55 # Design VAV box for 55F from central deck
    zn_dsn_htg_sa_temp_f = 122 # Design VAV box to reheat to 122F
    rht_rated_air_in_temp_f = 62 # Reheat coils designed to receive 62F
    rht_rated_air_out_temp_f = 90 # Reheat coils designed to supply 90F...but zone expects 122F...?
    clg_sa_temp_f = 55 # Central deck clg temp operates at 55F

    sys_dsn_prhtg_temp_c = OpenStudio.convert(sys_dsn_prhtg_temp_f, 'F', 'C').get
    sys_dsn_clg_sa_temp_c = OpenStudio.convert(sys_dsn_clg_sa_temp_f, 'F', 'C').get
    sys_dsn_htg_sa_temp_c = OpenStudio.convert(sys_dsn_htg_sa_temp_f, 'F', 'C').get
    zn_dsn_clg_sa_temp_c = OpenStudio.convert(zn_dsn_clg_sa_temp_f, 'F', 'C').get
    zn_dsn_htg_sa_temp_c = OpenStudio.convert(zn_dsn_htg_sa_temp_f, 'F', 'C').get
    rht_rated_air_in_temp_c = OpenStudio.convert(rht_rated_air_in_temp_f, 'F', 'C').get
    rht_rated_air_out_temp_c = OpenStudio.convert(rht_rated_air_out_temp_f, 'F', 'C').get
    clg_sa_temp_c = OpenStudio.convert(clg_sa_temp_f, 'F', 'C').get

    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

    # Air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
    if sys_name.nil?
      sys_name = "#{thermal_zones.size} Zone PVAV"
      air_loop.setName(sys_name)
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    # Some exceptions for the Outpatient
    if sys_name.include? 'PVAV Outpatient F1'
      # Outpatient two AHU1 and AHU2 have different HVAC schedule
      hvac_op_sch = add_schedule('OutPatientHealthCare AHU1-Fan_Pre2004')
      # Outpatient has different temperature settings for sizing
      clg_sa_temp_f = 52 # for AHU1 in Outpatient, SAT is 52F
      sys_dsn_clg_sa_temp_f = if template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
                                52
                              else
                                45
                              end
      zn_dsn_clg_sa_temp_f = 52 # zone cooling design SAT
      zn_dsn_htg_sa_temp_f = 104 # zone heating design SAT
    elsif sys_name.include? 'PVAV Outpatient F2 F3'
      hvac_op_sch = add_schedule('OutPatientHealthCare AHU2-Fan_Pre2004')
      clg_sa_temp_f = 55 # for AHU2 in Outpatient, SAT is 55F
      sys_dsn_clg_sa_temp_f = 52
      zn_dsn_clg_sa_temp_f = 55 # zone cooling design SAT
      zn_dsn_htg_sa_temp_f = 104 # zone heating design SAT
    end

    # Air handler controls
    stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, sa_temp_sch)
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
    fan = OpenStudio::Model::FanVariableVolume.new(self, alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.addToNode(air_loop.supplyInletNode)

    # Heating coil - depends on whether heating is hot water or electric,
    # which is determined by whether or not a hot water loop is provided.
    if hot_water_loop.nil?
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(self, alwaysOnDiscreteSchedule)
      htg_coil.setName("#{air_loop.name} Main Htg Coil")
      htg_coil.addToNode(air_loop.supplyInletNode)
    else
      htg_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
      htg_coil.setName("#{air_loop.name} Main Htg Coil")
      htg_coil.setRatedInletWaterTemperature(hw_temp_c)
      htg_coil.setRatedInletAirTemperature(rht_rated_air_in_temp_c)
      htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
      htg_coil.setRatedOutletAirTemperature(rht_rated_air_out_temp_c)
      htg_coil.addToNode(air_loop.supplyInletNode)
      hot_water_loop.addDemandBranchForComponent(htg_coil)
    end

    # Cooling coil
    if chilled_water_loop.nil?
      clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(self)
      clg_coil.setName("#{air_loop.name} Clg Coil")
      clg_coil.addToNode(air_loop.supplyInletNode)
    else
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(self, alwaysOnDiscreteSchedule)
      clg_coil.setName("#{air_loop.name} Clg Coil")
      clg_coil.addToNode(air_loop.supplyInletNode)
      clg_coil.setHeatExchangerConfiguration('CrossFlow')
      chilled_water_loop.addDemandBranchForComponent(clg_coil)
      clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")
    end

    # Outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(self)
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, oa_intake_controller)
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
        rht_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
      else
        rht_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
        rht_coil.setRatedInletWaterTemperature(hw_temp_c)
        rht_coil.setRatedInletAirTemperature(rht_rated_air_in_temp_c)
        rht_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        rht_coil.setRatedOutletAirTemperature(rht_rated_air_out_temp_c)
        hot_water_loop.addDemandBranchForComponent(rht_coil)
      end

      # VAV terminal
      terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(self, alwaysOnDiscreteSchedule, rht_coil)
      terminal.setName("#{zone.name} VAV Term")
      terminal.setZoneMinimumAirFlowMethod('Constant')
      terminal.apply_initial_prototype_damper_position(building_type, template, zone.outdoor_airflow_rate_per_area)
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
    air_loop.apply_vav_damper_action(template)

    return true
  end

  # Creates a packaged VAV system with parallel fan powered boxes and adds it to the model.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_pvav_pfp_boxes(template,
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
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      alwaysOnDiscreteSchedule
                    else
                      add_schedule(oa_damper_sch)
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

    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

    # air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV with PFP Boxes and Reheat")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, sa_temp_sch)
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
    fan = OpenStudio::Model::FanVariableVolume.new(self, alwaysOnDiscreteSchedule)
    fan.setName("#{air_loop.name} Fan")
    fan.setFanEfficiency(vav_fan_efficiency)
    fan.setMotorEfficiency(vav_fan_motor_efficiency)
    fan.setPressureRise(vav_fan_pressure_rise)
    fan.setFanPowerMinimumFlowRateInputMethod('fraction')
    fan.setFanPowerMinimumFlowFraction(0.25)
    fan.addToNode(air_loop.supplyInletNode)
    fan.setEndUseSubcategory('VAV system Fans')

    # heating coil
    htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
    htg_coil.setName("#{air_loop.name} Main Htg Coil")
    htg_coil.addToNode(air_loop.supplyInletNode)

    # Cooling coil
    if chilled_water_loop.nil?
      clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(self)
      clg_coil.setName("#{air_loop.name} Clg Coil")
      clg_coil.addToNode(air_loop.supplyInletNode)
    else
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(self, alwaysOnDiscreteSchedule)
      clg_coil.setName("#{air_loop.name} Clg Coil")
      clg_coil.addToNode(air_loop.supplyInletNode)
      clg_coil.setHeatExchangerConfiguration('CrossFlow')
      chilled_water_loop.addDemandBranchForComponent(clg_coil)
      clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")
    end

    # outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(self)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system need to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    # hook the VAV system to each zone
    thermal_zones.each do |zone|
      # reheat coil
      rht_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
      rht_coil.setName("#{zone.name} Rht Coil")

      # terminal fan
      pfp_fan = OpenStudio::Model::FanConstantVolume.new(self, alwaysOnDiscreteSchedule)
      pfp_fan.setName("#{zone.name} PFP Term Fan")
      pfp_fan.setPressureRise(300)

      # parallel fan powered terminal
      pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(self,
                                                                                   alwaysOnDiscreteSchedule,
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
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_cav(template,
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
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      alwaysOnDiscreteSchedule
                    else
                      add_schedule(oa_damper_sch)
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
    air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone CAV")
    else
      air_loop.setName(sys_name)
    end
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    # Air handler supply air setpoint
    sa_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    sa_temp_sch.setName("Supply Air Temp - #{clg_sa_temp_f}F")
    sa_temp_sch.defaultDaySchedule.setName("Supply Air Temp - #{clg_sa_temp_f}F Default")
    sa_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_sa_temp_c)

    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, sa_temp_sch)
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
    fan = OpenStudio::Model::FanConstantVolume.new(self, alwaysOnDiscreteSchedule)
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
    htg_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
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
      clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(self)
    else
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(self, alwaysOnDiscreteSchedule)
      clg_coil.setHeatExchangerConfiguration('CrossFlow')
      chilled_water_loop.addDemandBranchForComponent(clg_coil)
      clg_coil.controllerWaterCoil.get.setName("#{air_loop.name} Clg Coil Controller")
    end
    clg_coil.setName("#{air_loop.name} Clg Coil")
    clg_coil.addToNode(air_loop.supplyInletNode)

    # Outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(self)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    # oa_intake_controller.setMinimumOutdoorAirSchedule(motorized_oa_damper_sch)
    oa_intake_controller.setMinimumFractionofOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('ZoneSum')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA Sys")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # The oa system needs to be added before setting the night cycle control
    air_loop.setNightCycleControlType('CycleOnAny')

    # Connect the CAV system to each zone
    thermal_zones.each do |zone|
      if building_type == 'Hospital'
        # CAV terminal
        terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(self, alwaysOnDiscreteSchedule)
        terminal.setName("#{zone.name} CAV Term")
      else
        # Reheat coil
        rht_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
        rht_coil.setName("#{zone.name} Rht Coil")
        rht_coil.setRatedInletWaterTemperature(hw_temp_c)
        rht_coil.setRatedInletAirTemperature(htg_sa_temp_c)
        rht_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        rht_coil.setRatedOutletAirTemperature(rht_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(rht_coil)

        # VAV terminal
        terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(self, alwaysOnDiscreteSchedule, rht_coil)
        terminal.setName("#{zone.name} VAV Term")
        terminal.setZoneMinimumAirFlowMethod('Constant')
        terminal.apply_initial_prototype_damper_position(building_type, template, zone.outdoor_airflow_rate_per_area)
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
    air_loop.apply_vav_damper_action(template)

    return true
  end

  # Creates a PSZ-AC system for each zone and adds it to the model.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  # @param heating_type [Double] valid choices are Gas, Water,
  # Single Speed Heat Pump, Water To Air Heat Pump
  # @param supplemental_heating_type [Double] valid choices are Electric, Gas
  # @param cooling_type [String] valid choices are Water, Two Speed DX AC,
  # Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] an array of the resulting PSZ-AC air loops
  # Todo: clarify where these default curves coefficients are coming from
  # Todo: I (jmarrec) believe it is the DOE Ref curves ("DOE Ref DX Clg Coil Cool-Cap-fT")
  def add_psz_ac(template,
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

    unless hot_water_loop.nil? || chilled_water_loop.nil?
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
    end

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      alwaysOnDiscreteSchedule
                    else
                      add_schedule(oa_damper_sch)
                    end

    # Make a PSZ-AC for each zone
    air_loops = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PSZ-AC for #{zone.name}.")

      air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
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
      if building_type == 'RetailStandalone' && (template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980')
        sizing_zone.setZoneCoolingDesignSupplyAirTemperature(14)
      else
        sizing_zone.setZoneCoolingDesignSupplyAirTemperature(12.8)
      end

      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(40.0)

      # Add a setpoint manager single zone reheat to control the
      # supply air temperature based on the needs of this zone
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(self)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)

      fan = nil
      # ConstantVolume: Packaged Rooftop Single Zone Air conditioner;
      # Cycling: Unitary System;
      # CyclingHeatPump: Unitary Heat Pump system
      if fan_type == 'ConstantVolume'
        fan = OpenStudio::Model::FanConstantVolume.new(self, hvac_op_sch)
        fan.setName("#{air_loop.name} Fan")
        fan_static_pressure_in_h2o = 2.5
        fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
        fan.setPressureRise(fan_static_pressure_pa)
        fan.setFanEfficiency(0.54)
        fan.setMotorEfficiency(0.90)
      elsif fan_type == 'Cycling'

        fan = OpenStudio::Model::FanOnOff.new(self, hvac_op_sch) # Set fan op sch manually since fwd translator doesn't
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
      if heating_type == 'Gas'
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(self, alwaysOnDiscreteSchedule)
        htg_coil.setName("#{air_loop.name} Gas Htg Coil")

        if template == 'DOE Ref Pre-1980'
          htg_coil.setGasBurnerEfficiency(0.78)
        end

      elsif heating_type == 'Water'
        if hot_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water plant loop supplied')
          return false
        end
        htg_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
        htg_coil.setName("#{air_loop.name} Water Htg Coil")
        htg_coil.setRatedInletWaterTemperature(hw_temp_c)
        htg_coil.setRatedInletAirTemperature(prehtg_sa_temp_c)
        htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(htg_coil)
      elsif heating_type == 'Single Speed Heat Pump'
        htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(self)
        htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
        htg_cap_f_of_temp.setCoefficient2x(0.027626)
        htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
        htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
        htg_cap_f_of_temp.setMinimumValueofx(-20.0)
        htg_cap_f_of_temp.setMaximumValueofx(20.0)

        htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(self)
        htg_cap_f_of_flow.setCoefficient1Constant(0.84)
        htg_cap_f_of_flow.setCoefficient2x(0.16)
        htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
        htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
        htg_cap_f_of_flow.setMinimumValueofx(0.5)
        htg_cap_f_of_flow.setMaximumValueofx(1.5)

        htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(self)
        htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
        htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
        htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
        htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
        htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
        htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

        htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
        htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
        htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
        htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
        htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

        htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(self)
        htg_part_load_fraction.setCoefficient1Constant(0.85)
        htg_part_load_fraction.setCoefficient2x(0.15)
        htg_part_load_fraction.setCoefficient3xPOW2(0.0)
        htg_part_load_fraction.setMinimumValueofx(0.0)
        htg_part_load_fraction.setMaximumValueofx(1.0)

        htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(self,
                                                                   alwaysOnDiscreteSchedule,
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

        def_eir_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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
      elsif heating_type == 'Water To Air Heat Pump'
        if hot_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water plant loop supplied')
          return false
        end
        htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(self)
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
      end

      supplemental_htg_coil = nil
      if supplemental_heating_type == 'Electric'
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
        supplemental_htg_coil.setName("#{air_loop.name} Electric Backup Htg Coil")
      elsif supplemental_heating_type == 'Gas'
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(self, alwaysOnDiscreteSchedule)
        supplemental_htg_coil.setName("#{air_loop.name} Gas Backup Htg Coil")
      end

      clg_coil = nil
      if cooling_type == 'Water'
        if chilled_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No chilled water plant loop supplied')
          return false
        end
        clg_coil = OpenStudio::Model::CoilCoolingWater.new(self, alwaysOnDiscreteSchedule)
        clg_coil.setName("#{air_loop.name} Water Clg Coil")
        chilled_water_loop.addDemandBranchForComponent(clg_coil)
      elsif cooling_type == 'Two Speed DX AC'

        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
        clg_cap_f_of_flow.setCoefficient2x(0.34053)
        clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
        clg_cap_f_of_flow.setMinimumValueofx(0.75918)
        clg_cap_f_of_flow.setMaximumValueofx(1.13877)

        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(self)
        clg_part_load_ratio.setCoefficient1Constant(0.77100)
        clg_part_load_ratio.setCoefficient2x(0.22900)
        clg_part_load_ratio.setCoefficient3xPOW2(0.0)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)

        clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(self,
                                                                alwaysOnDiscreteSchedule,
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
        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_cap_f_of_flow.setCoefficient1Constant(1.0)
        clg_cap_f_of_flow.setCoefficient2x(0.0)
        clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
        clg_cap_f_of_flow.setMinimumValueofx(-100.0)
        clg_cap_f_of_flow.setMaximumValueofx(100.0)

        # "DOE Ref DX Clg Coil Cool-EIR-fT",
        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.0)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(0.0)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(-100.0)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(100.0)

        # "DOE Ref DX Clg Coil Cool-PLF-fPLR"
        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(self)
        clg_part_load_ratio.setCoefficient1Constant(0.90949556)
        clg_part_load_ratio.setCoefficient2x(0.09864773)
        clg_part_load_ratio.setCoefficient3xPOW2(-0.00819488)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)
        clg_part_load_ratio.setMinimumCurveOutput(0.7)
        clg_part_load_ratio.setMaximumCurveOutput(1.0)

        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(self,
                                                                   alwaysOnDiscreteSchedule,
                                                                   clg_cap_f_of_temp,
                                                                   clg_cap_f_of_flow,
                                                                   clg_energy_input_ratio_f_of_temp,
                                                                   clg_energy_input_ratio_f_of_flow,
                                                                   clg_part_load_ratio)

        clg_coil.setName("#{air_loop.name} 1spd DX AC Clg Coil")

      elsif cooling_type == 'Single Speed Heat Pump'
        # "PSZ-AC_Unitary_PackagecoolCapFT"
        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_cap_f_of_flow.setCoefficient1Constant(0.8)
        clg_cap_f_of_flow.setCoefficient2x(0.2)
        clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
        clg_cap_f_of_flow.setMinimumValueofx(0.5)
        clg_cap_f_of_flow.setMaximumValueofx(1.5)

        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.156)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1816)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(self)
        clg_part_load_ratio.setCoefficient1Constant(0.85)
        clg_part_load_ratio.setCoefficient2x(0.15)
        clg_part_load_ratio.setCoefficient3xPOW2(0.0)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)

        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(self,
                                                                   alwaysOnDiscreteSchedule,
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
        clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(self)
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

      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(self)
      oa_controller.setName("#{air_loop.name} OA Sys Controller")
      oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
      oa_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, oa_controller)
      oa_system.setName("#{air_loop.name} OA Sys")
      econ_eff_sch = add_schedule('RetailStandalone PSZ_Econ_MaxOAFrac_Sch')

      case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        oa_controller.setMaximumFractionofOutdoorAirSchedule(econ_eff_sch) if building_type == 'RetailStandalone' || building_type == 'RetailStripmall'
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'No maximum fraction outdoor air schedule in PSZ for building types except RetailStandalone')
      end

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode

      # Wrap coils in a unitary system or not, depending
      # on the system type.
      if fan_type == 'Cycling'

        if heating_type == 'Water To Air Heat Pump'
          unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(self)
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
          unitary_system.setSupplyAirFanOperatingModeSchedule(alwaysOnDiscreteSchedule)
          unitary_system.addToNode(supply_inlet_node)
          setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(50)
        else
          unitary_system = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir.new(self,
                                                                                     alwaysOnDiscreteSchedule,
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
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(self, alwaysOnDiscreteSchedule)
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
  def add_data_center_load(space, dc_watts_per_area)
    # Data center load
    data_center_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
    data_center_definition.setName('Data Center Load')
    data_center_definition.setWattsperSpaceFloorArea(dc_watts_per_area)

    data_center_equipment = OpenStudio::Model::ElectricEquipment.new(data_center_definition)
    data_center_equipment.setName('Data Center Load')
    data_center_sch = alwaysOnDiscreteSchedule
    data_center_equipment.setSchedule(data_center_sch)
    data_center_equipment.setSpace(space)

    return true
  end

  # Creates a data center PSZ-AC system for each zone.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_data_center_hvac(template,
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
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      alwaysOnDiscreteSchedule
                    else
                      add_schedule(oa_damper_sch)
                    end

    # Make a PSZ-AC for each zone
    air_loops = []
    thermal_zones.each do |zone|
      air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
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
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(self)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)

      fan = OpenStudio::Model::FanOnOff.new(self, hvac_op_sch) # Set fan op sch manually since fwd translator doesn't
      fan.setName("#{air_loop.name} Fan")
      fan_static_pressure_in_h2o = 2.5
      fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
      fan.setPressureRise(fan_static_pressure_pa)
      fan.setFanEfficiency(0.54)
      fan.setMotorEfficiency(0.90)

      htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(self)
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

      clg_coil = OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit.new(self)
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

      supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
      supplemental_htg_coil.setName("#{air_loop.name} Electric Backup Htg Coil")

      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(self)
      oa_controller.setName("#{air_loop.name} OA Sys Controller")
      oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, oa_controller)
      oa_system.setName("#{air_loop.name} OA Sys")

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode

      if main_data_center
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(self)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100_000)
        humidifier.setName("#{air_loop.name} Electric Steam Humidifier")

        extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
        extra_elec_htg_coil.setName("#{air_loop.name} Electric Htg Coil")

        extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
        extra_water_htg_coil.setName("#{air_loop.name} Water Htg Coil")
        extra_water_htg_coil.setRatedInletWaterTemperature(hw_temp_c)
        extra_water_htg_coil.setRatedInletAirTemperature(prehtg_sa_temp_c)
        extra_water_htg_coil.setRatedOutletWaterTemperature(hw_temp_c - hw_delta_t_k)
        extra_water_htg_coil.setRatedOutletAirTemperature(htg_sa_temp_c)
        hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)

        extra_water_htg_coil.addToNode(supply_inlet_node)
        extra_elec_htg_coil.addToNode(supply_inlet_node)
        humidifier.addToNode(supply_inlet_node)

        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(self)
        humidity_spm.setControlZone(zone)

        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)

        humidistat = OpenStudio::Model::ZoneControlHumidistat.new(self)
        humidistat.setHumidifyingRelativeHumiditySetpointSchedule(add_schedule('OfficeLarge DC_MinRelHumSetSch'))
        zone.setZoneControlHumidistat(humidistat)
      end

      unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(self)
      unitary_system.setSupplyFan(fan)
      unitary_system.setHeatingCoil(htg_coil)
      unitary_system.setCoolingCoil(clg_coil)
      unitary_system.setSupplementalHeatingCoil(supplemental_htg_coil)

      unitary_system.setName("#{zone.name} Unitary HP")
      unitary_system.setControllingZoneorThermostatLocation(zone)
      unitary_system.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(OpenStudio.convert(40, 'F', 'C').get)
      unitary_system.setFanPlacement('BlowThrough')
      unitary_system.setSupplyAirFanOperatingModeSchedule(hvac_op_sch)
      unitary_system.setSupplyAirFanOperatingModeSchedule(alwaysOnDiscreteSchedule)
      unitary_system.addToNode(supply_inlet_node)

      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(OpenStudio.convert(55, 'F', 'C').get)
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(OpenStudio.convert(104, 'F', 'C').get)

      # Add the OA system
      oa_system.addToNode(supply_inlet_node)

      # Attach the nightcycle manager to the supply outlet node
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)
      air_loop.setNightCycleControlType('CycleOnAny')

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(self, alwaysOnDiscreteSchedule)
      diffuser.setName("#{air_loop.name} Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    end

    return air_loops
  end

  # Creates a split DX AC system for each zone and adds it to the model.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_split_ac(template,
                   sys_name,
                   thermal_zones,
                   hvac_op_sch,
                   alt_hvac_op_sch,
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
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # alternate hvac operation schedule
    alt_hvac_op_sch = if alt_hvac_op_sch.nil?
                        alwaysOnDiscreteSchedule
                      else
                        add_schedule(alt_hvac_op_sch)
                      end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      alwaysOnDiscreteSchedule
                    else
                      add_schedule(oa_damper_sch)
                    end

    # OA_controller Maximum OA Fraction schedule
    econ_max_oa_frac_sch = add_schedule('HotelSmall SAC_Econ_MaxOAFrac_Sch')

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

    # Meeting room cycling fan schedule
    if space_type_names.include? 'Meeting'
      hvac_op_sch = alt_hvac_op_sch
    end

    air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
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
    setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(self)
    setpoint_mgr_single_zone_reheat.setControlZone(controlzone)

    # Fan
    fan = nil
    if fan_type == 'ConstantVolume'
      fan = OpenStudio::Model::FanConstantVolume.new(self, alwaysOnDiscreteSchedule)
      fan.setName("#{thermal_zone_name} SAC Fan")
      fan_static_pressure_in_h2o = 2.5
      fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
      fan.setPressureRise(fan_static_pressure_pa)
      fan.setFanEfficiency(0.56) # get the average of four fans
      fan.setMotorEfficiency(0.86) # get the average of four fans
    elsif fan_type == 'Cycling'
      fan = OpenStudio::Model::FanOnOff.new(self, alwaysOnDiscreteSchedule)
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
      htg_coil = OpenStudio::Model::CoilHeatingGas.new(self, alwaysOnDiscreteSchedule)
      htg_coil.setName("#{thermal_zone_name} SAC Gas Htg Coil")
      htg_coil.setGasBurnerEfficiency(0.8)
      htg_part_load_fraction_correlation = OpenStudio::Model::CurveCubic.new(self)
      htg_part_load_fraction_correlation.setCoefficient1Constant(0.8)
      htg_part_load_fraction_correlation.setCoefficient2x(0.2)
      htg_part_load_fraction_correlation.setCoefficient3xPOW2(0)
      htg_part_load_fraction_correlation.setCoefficient4xPOW3(0)
      htg_part_load_fraction_correlation.setMinimumValueofx(0)
      htg_part_load_fraction_correlation.setMaximumValueofx(1)
      htg_coil.setPartLoadFractionCorrelationCurve(htg_part_load_fraction_correlation)
    elsif heating_type == 'Single Speed Heat Pump'
      htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(self)
      htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
      htg_cap_f_of_temp.setCoefficient2x(0.027626)
      htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
      htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
      htg_cap_f_of_temp.setMinimumValueofx(-20.0)
      htg_cap_f_of_temp.setMaximumValueofx(20.0)

      htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(self)
      htg_cap_f_of_flow.setCoefficient1Constant(0.84)
      htg_cap_f_of_flow.setCoefficient2x(0.16)
      htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
      htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
      htg_cap_f_of_flow.setMinimumValueofx(0.5)
      htg_cap_f_of_flow.setMaximumValueofx(1.5)

      htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(self)
      htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
      htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
      htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
      htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
      htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
      htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

      htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
      htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
      htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
      htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
      htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

      htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(self)
      htg_part_load_fraction.setCoefficient1Constant(0.85)
      htg_part_load_fraction.setCoefficient2x(0.15)
      htg_part_load_fraction.setCoefficient3xPOW2(0.0)
      htg_part_load_fraction.setMinimumValueofx(0.0)
      htg_part_load_fraction.setMaximumValueofx(1.0)

      htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(self,
                                                                 alwaysOnDiscreteSchedule,
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
      supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(self, alwaysOnDiscreteSchedule)
      supplemental_htg_coil.setName("#{thermal_zone_name} PSZ-AC Electric Backup Htg Coil")
    elsif supplemental_heating_type == 'Gas'
      supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(self, alwaysOnDiscreteSchedule)
      supplemental_htg_coil.setName("#{thermal_zone_name} PSZ-AC Gas Backup Htg Coil")
    end

    # Cooling Coil
    clg_coil = nil
    if cooling_type == 'Two Speed DX AC'

      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
      clg_cap_f_of_flow.setCoefficient2x(0.34053)
      clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
      clg_cap_f_of_flow.setMinimumValueofx(0.75918)
      clg_cap_f_of_flow.setMaximumValueofx(1.13877)

      clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
      clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
      clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
      clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
      clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

      clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(self)
      clg_part_load_ratio.setCoefficient1Constant(0.77100)
      clg_part_load_ratio.setCoefficient2x(0.22900)
      clg_part_load_ratio.setCoefficient3xPOW2(0.0)
      clg_part_load_ratio.setMinimumValueofx(0.0)
      clg_part_load_ratio.setMaximumValueofx(1.0)

      clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(self,
                                                              alwaysOnDiscreteSchedule,
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

      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      clg_cap_f_of_flow.setCoefficient1Constant(0.8)
      clg_cap_f_of_flow.setCoefficient2x(0.2)
      clg_cap_f_of_flow.setCoefficient3xPOW2(0)
      clg_cap_f_of_flow.setMinimumValueofx(0.5)
      clg_cap_f_of_flow.setMaximumValueofx(1.5)

      clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.1552)
      clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1808)
      clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
      clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
      clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

      clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(self)
      clg_part_load_ratio.setCoefficient1Constant(0.85)
      clg_part_load_ratio.setCoefficient2x(0.15)
      clg_part_load_ratio.setCoefficient3xPOW2(0.0)
      clg_part_load_ratio.setMinimumValueofx(0.0)
      clg_part_load_ratio.setMaximumValueofx(1.0)
      clg_part_load_ratio.setMinimumCurveOutput(0.7)
      clg_part_load_ratio.setMaximumCurveOutput(1.0)

      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(self,
                                                                 alwaysOnDiscreteSchedule,
                                                                 clg_cap_f_of_temp,
                                                                 clg_cap_f_of_flow,
                                                                 clg_energy_input_ratio_f_of_temp,
                                                                 clg_energy_input_ratio_f_of_flow,
                                                                 clg_part_load_ratio)

      clg_coil.setName("#{thermal_zone_name} SAC 1spd DX AC Clg Coil")

    elsif cooling_type == 'Single Speed Heat Pump'

      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      clg_cap_f_of_flow.setCoefficient1Constant(0.8)
      clg_cap_f_of_flow.setCoefficient2x(0.2)
      clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
      clg_cap_f_of_flow.setMinimumValueofx(0.5)
      clg_cap_f_of_flow.setMaximumValueofx(1.5)

      clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.156)
      clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1816)
      clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
      clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
      clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

      clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(self)
      clg_part_load_ratio.setCoefficient1Constant(0.85)
      clg_part_load_ratio.setCoefficient2x(0.15)
      clg_part_load_ratio.setCoefficient3xPOW2(0.0)
      clg_part_load_ratio.setMinimumValueofx(0.0)
      clg_part_load_ratio.setMaximumValueofx(1.0)

      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(self,
                                                                 alwaysOnDiscreteSchedule,
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

    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(self)
    oa_controller.setName("#{thermal_zone_name} SAC OA Sys Controller")
    oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_controller.setMaximumFractionofOutdoorAirSchedule(econ_max_oa_frac_sch)
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, oa_controller)
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
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(self, alwaysOnDiscreteSchedule)
      diffuser.setName("#{zone.name} SAC Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    end

    return air_loop
  end

  # Creates a PTAC system for each zone and adds it to the model.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [String] hot water loop to connect heating coil to.
  #   Set to nil for heating types besides water.
  # @param thermal_zones [String] zones to connect to this system
  # @param fan_type [Double] valid choices are ConstantVolume, Cycling
  # @param heating_type [Double] valid choices are
  # Gas, Electric, Water
  # @param cooling_type [String] valid choices are
  # Two Speed DX AC, Single Speed DX AC
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner>] an
  # array of the resulting PTACs.
  def add_ptac(template,
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
    always_off = OpenStudio::Model::ScheduleRuleset.new(self)
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
        fan = OpenStudio::Model::FanConstantVolume.new(self, alwaysOnDiscreteSchedule)
        fan.setName("#{zone.name} PTAC Fan")
        fan_static_pressure_in_h2o = 1.33
        fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
        fan.setPressureRise(fan_static_pressure_pa)
        fan.setFanEfficiency(0.52)
        fan.setMotorEfficiency(0.8)
      elsif fan_type == 'Cycling'
        fan = OpenStudio::Model::FanOnOff.new(self, alwaysOnDiscreteSchedule)
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
      if heating_type == 'Gas'
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(self, alwaysOnDiscreteSchedule)
        htg_coil.setName("#{zone.name} PTAC Gas Htg Coil")
      elsif heating_type == 'Electric'
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
        htg_coil.setName("#{zone.name} PTAC Electric Htg Coil")
      elsif heating_type == 'Water'
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

        htg_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
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

        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_cap_f_of_flow.setCoefficient1Constant(0.77136)
        clg_cap_f_of_flow.setCoefficient2x(0.34053)
        clg_cap_f_of_flow.setCoefficient3xPOW2(-0.11088)
        clg_cap_f_of_flow.setMinimumValueofx(0.75918)
        clg_cap_f_of_flow.setMaximumValueofx(1.13877)

        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.20550)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.32953)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.12308)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.75918)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.13877)

        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(self)
        clg_part_load_ratio.setCoefficient1Constant(0.77100)
        clg_part_load_ratio.setCoefficient2x(0.22900)
        clg_part_load_ratio.setCoefficient3xPOW2(0.0)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)

        clg_cap_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_energy_input_ratio_f_of_temp_low_spd = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_coil = OpenStudio::Model::CoilCoolingDXTwoSpeed.new(self,
                                                                alwaysOnDiscreteSchedule,
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

        clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_cap_f_of_flow.setCoefficient1Constant(0.8)
        clg_cap_f_of_flow.setCoefficient2x(0.2)
        clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
        clg_cap_f_of_flow.setMinimumValueofx(0.5)
        clg_cap_f_of_flow.setMaximumValueofx(1.5)

        clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

        clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
        clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.1552)
        clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1808)
        clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
        clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
        clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

        clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(self)
        clg_part_load_ratio.setCoefficient1Constant(0.85)
        clg_part_load_ratio.setCoefficient2x(0.15)
        clg_part_load_ratio.setCoefficient3xPOW2(0.0)
        clg_part_load_ratio.setMinimumValueofx(0.0)
        clg_part_load_ratio.setMaximumValueofx(1.0)
        clg_part_load_ratio.setMinimumCurveOutput(0.7)
        clg_part_load_ratio.setMaximumCurveOutput(1.0)

        clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(self,
                                                                   alwaysOnDiscreteSchedule,
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
      ptac_system = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(self,
                                                                                  alwaysOnDiscreteSchedule,
                                                                                  fan,
                                                                                  htg_coil,
                                                                                  clg_coil)

      ptac_system.setName("#{zone.name} PTAC")
      ptac_system.setFanPlacement('DrawThrough')
      if fan_type == 'ConstantVolume'
        ptac_system.setSupplyAirFanOperatingModeSchedule(alwaysOnDiscreteSchedule)
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
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param fan_type [Double] valid choices are ConstantVolume, Cycling
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner>] an
  # array of the resulting PTACs.
  def add_pthp(template,
               sys_name,
               thermal_zones,
               fan_type,
               building_type = nil)

    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PTHP for #{zone.name}.")
    end

    # schedule: always off
    always_off = OpenStudio::Model::ScheduleRuleset.new(self)
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
        fan = OpenStudio::Model::FanConstantVolume.new(self, alwaysOnDiscreteSchedule)
        fan.setName("#{zone.name} PTAC Fan")
        fan_static_pressure_in_h2o = 1.33
        fan_static_pressure_pa = OpenStudio.convert(fan_static_pressure_in_h2o, 'inH_{2}O', 'Pa').get
        fan.setPressureRise(fan_static_pressure_pa)
        fan.setFanEfficiency(0.52)
        fan.setMotorEfficiency(0.8)
      elsif fan_type == 'Cycling'
        fan = OpenStudio::Model::FanOnOff.new(self, alwaysOnDiscreteSchedule)
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
      htg_cap_f_of_temp = OpenStudio::Model::CurveCubic.new(self)
      htg_cap_f_of_temp.setCoefficient1Constant(0.758746)
      htg_cap_f_of_temp.setCoefficient2x(0.027626)
      htg_cap_f_of_temp.setCoefficient3xPOW2(0.000148716)
      htg_cap_f_of_temp.setCoefficient4xPOW3(0.0000034992)
      htg_cap_f_of_temp.setMinimumValueofx(-20.0)
      htg_cap_f_of_temp.setMaximumValueofx(20.0)

      htg_cap_f_of_flow = OpenStudio::Model::CurveCubic.new(self)
      htg_cap_f_of_flow.setCoefficient1Constant(0.84)
      htg_cap_f_of_flow.setCoefficient2x(0.16)
      htg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
      htg_cap_f_of_flow.setCoefficient4xPOW3(0.0)
      htg_cap_f_of_flow.setMinimumValueofx(0.5)
      htg_cap_f_of_flow.setMaximumValueofx(1.5)

      htg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveCubic.new(self)
      htg_energy_input_ratio_f_of_temp.setCoefficient1Constant(1.19248)
      htg_energy_input_ratio_f_of_temp.setCoefficient2x(-0.0300438)
      htg_energy_input_ratio_f_of_temp.setCoefficient3xPOW2(0.00103745)
      htg_energy_input_ratio_f_of_temp.setCoefficient4xPOW3(-0.000023328)
      htg_energy_input_ratio_f_of_temp.setMinimumValueofx(-20.0)
      htg_energy_input_ratio_f_of_temp.setMaximumValueofx(20.0)

      htg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      htg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.3824)
      htg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.4336)
      htg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0512)
      htg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.0)
      htg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.0)

      htg_part_load_fraction = OpenStudio::Model::CurveQuadratic.new(self)
      htg_part_load_fraction.setCoefficient1Constant(0.85)
      htg_part_load_fraction.setCoefficient2x(0.15)
      htg_part_load_fraction.setCoefficient3xPOW2(0.0)
      htg_part_load_fraction.setMinimumValueofx(0.0)
      htg_part_load_fraction.setMaximumValueofx(1.0)

      htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(self,
                                                                 alwaysOnDiscreteSchedule,
                                                                 htg_cap_f_of_temp,
                                                                 htg_cap_f_of_flow,
                                                                 htg_energy_input_ratio_f_of_temp,
                                                                 htg_energy_input_ratio_f_of_flow,
                                                                 htg_part_load_fraction)

      htg_coil.setName("#{zone.name} PTHP Htg Coil")

      # add cooling coil
      clg_cap_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_cap_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      clg_cap_f_of_flow.setCoefficient1Constant(0.8)
      clg_cap_f_of_flow.setCoefficient2x(0.2)
      clg_cap_f_of_flow.setCoefficient3xPOW2(0.0)
      clg_cap_f_of_flow.setMinimumValueofx(0.5)
      clg_cap_f_of_flow.setMaximumValueofx(1.5)

      clg_energy_input_ratio_f_of_temp = OpenStudio::Model::CurveBiquadratic.new(self)
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

      clg_energy_input_ratio_f_of_flow = OpenStudio::Model::CurveQuadratic.new(self)
      clg_energy_input_ratio_f_of_flow.setCoefficient1Constant(1.156)
      clg_energy_input_ratio_f_of_flow.setCoefficient2x(-0.1816)
      clg_energy_input_ratio_f_of_flow.setCoefficient3xPOW2(0.0256)
      clg_energy_input_ratio_f_of_flow.setMinimumValueofx(0.5)
      clg_energy_input_ratio_f_of_flow.setMaximumValueofx(1.5)

      clg_part_load_ratio = OpenStudio::Model::CurveQuadratic.new(self)
      clg_part_load_ratio.setCoefficient1Constant(0.85)
      clg_part_load_ratio.setCoefficient2x(0.15)
      clg_part_load_ratio.setCoefficient3xPOW2(0.0)
      clg_part_load_ratio.setMinimumValueofx(0.0)
      clg_part_load_ratio.setMaximumValueofx(1.0)

      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(self,
                                                                 alwaysOnDiscreteSchedule,
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
      supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)

      # Wrap coils in a PTHP system
      pthp_system = OpenStudio::Model::ZoneHVACPackagedTerminalHeatPump.new(self,
                                                                            alwaysOnDiscreteSchedule,
                                                                            fan,
                                                                            htg_coil,
                                                                            clg_coil,
                                                                            supplemental_htg_coil)

      pthp_system.setName("#{zone.name} PTHP")
      pthp_system.setFanPlacement('DrawThrough')
      if fan_type == 'ConstantVolume'
        pthp_system.setSupplyAirFanOperatingModeSchedule(alwaysOnDiscreteSchedule)
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
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_unitheater(template,
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
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # Make a unit heater for each zone
    unit_heaters = []
    thermal_zones.each do |zone|
      # Zone sizing
      sizing_zone = zone.sizingZone
      if building_type == 'RetailStandalone' && template != 'DOE Ref 1980-2004' && template != 'DOE Ref Pre-1980'
        sizing_zone.setZoneCoolingDesignSupplyAirTemperature(12.8)
      else
        sizing_zone.setZoneCoolingDesignSupplyAirTemperature(14)
      end

      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(50.0)
      sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)
      sizing_zone.setZoneHeatingDesignSupplyAirHumidityRatio(0.008)

      # add fan
      fan = OpenStudio::Model::FanConstantVolume.new(self, hvac_op_sch)
      fan.setName("#{zone.name} UnitHeater Fan")
      fan.setPressureRise(fan_pressure_rise)
      fan.setFanEfficiency(0.53625)
      fan.setMotorEfficiency(0.825)

      # add heating coil
      htg_coil = nil
      if heating_type == 'NaturalGas' || heating_type == 'Gas'
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(self, hvac_op_sch)
        htg_coil.setName("#{zone.name} UnitHeater Gas Htg Coil")
      elsif heating_type == 'Electricity' || heating_type == 'Electric'
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, hvac_op_sch)
        htg_coil.setName("#{zone.name} UnitHeater Electric Htg Coil")
      elsif heating_type == 'DistrictHeating' && !hot_water_loop.nil?
        htg_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
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

      unit_heater = OpenStudio::Model::ZoneHVACUnitHeater.new(self,
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
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param sys_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param heating_type [Double] valid choices are
  # Gas, Electric
  # @param combustion_efficiency [Double] combustion efficiency as decimal
  # @param building_type [String] the building type
  # @return [Array<OpenStudio::Model::ZoneHVACHighTemperatureRadiant>] an
  # array of the resulting radiant heaters.
  def add_high_temp_radiant(template,
                            sys_name,
                            thermal_zones,
                            heating_type,
                            combustion_efficiency,
                            building_type = nil)

    # Make a high temp radiant heater for each zone
    rad_heaters = []
    thermal_zones.each do |zone|
      high_temp_radiant = OpenStudio::Model::ZoneHVACHighTemperatureRadiant.new(self)
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

  # Creates a service water heating loop.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_swh_loop(template,
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

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding service water loop.')

    # Service water heating loop
    service_water_loop = OpenStudio::Model::PlantLoop.new(self)
    service_water_loop.setMinimumLoopTemperature(10)
    service_water_loop.setMaximumLoopTemperature(60)

    if sys_name.nil?
      service_water_loop.setName('Service Water Loop')
    else
      service_water_loop.setName(sys_name)
    end

    # Temperature schedule type limits
    temp_sch_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(self)
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
    swh_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    swh_temp_sch.setName("Service Water Loop Temp - #{swh_temp_f.round}F")
    swh_temp_sch.defaultDaySchedule.setName("Service Water Loop Temp - #{swh_temp_f.round}F Default")
    swh_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), swh_temp_c)
    swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
    swh_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, swh_temp_sch)
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

    swh_pump = if template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
                 if building_type == 'Medium Office'
                   OpenStudio::Model::PumpConstantSpeed.new(self)
                 else
                   OpenStudio::Model::PumpVariableSpeed.new(self)
                 end
               else
                 OpenStudio::Model::PumpConstantSpeed.new(self)
               end
    swh_pump.setName('Service Water Loop Pump')
    swh_pump.setRatedPumpHead(swh_pump_head_press_pa.to_f)
    swh_pump.setMotorEfficiency(swh_pump_motor_efficiency)
    swh_pump.setPumpControlType('Intermittent')
    swh_pump.addToNode(service_water_loop.supplyInletNode)

    water_heater = add_water_heater(template,
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
    water_heater_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    service_water_loop.addSupplyBranchForComponent(water_heater_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    service_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_outlet_pipe.addToNode(service_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_inlet_pipe.addToNode(service_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_outlet_pipe.addToNode(service_water_loop.demandOutletNode)

    return service_water_loop
  end

  # Creates a water heater and attaches it to the supplied
  # service water heating loop.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_water_heater(template,
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

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding water heater.')

    # Water heater
    # TODO Standards - Change water heater methodology to follow
    # 'Model Enhancements Appendix A.'
    water_heater_capacity_btu_per_hr = OpenStudio.convert(water_heater_capacity, 'W', 'Btu/hr').get
    water_heater_capacity_kbtu_per_hr = OpenStudio.convert(water_heater_capacity_btu_per_hr, 'Btu/hr', 'kBtu/hr').get
    water_heater_vol_gal = OpenStudio.convert(water_heater_volume, 'm^3', 'gal').get

    # Temperature schedule type limits
    temp_sch_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(self)
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
      swh_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      swh_temp_sch.setName("Service Water Loop Temp - #{swh_temp_f.round}F")
      swh_temp_sch.defaultDaySchedule.setName("Service Water Loop Temp - #{swh_temp_f.round}F Default")
      swh_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), swh_temp_c)
      swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
    end

    # Water heater depends on the fuel type
    water_heater = OpenStudio::Model::WaterHeaterMixed.new(self)
    water_heater.setName("#{water_heater_vol_gal}gal #{water_heater_fuel} Water Heater - #{water_heater_capacity_kbtu_per_hr.round}kBtu/hr")
    water_heater.setTankVolume(OpenStudio.convert(water_heater_vol_gal, 'gal', 'm^3').get)
    water_heater.setSetpointTemperatureSchedule(swh_temp_sch)

    if water_heater_thermal_zone.nil?
      # Assume the water heater is indoors at 70F for now
      default_water_heater_ambient_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
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

      schedule = add_schedule(flowrate_schedule)
      water_heater.setUseFlowRateFractionSchedule(schedule)
    end

    return water_heater
  end

  # Creates a booster water heater and attaches it
  # to the supplied service water heating loop.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_swh_booster(template,
                      main_service_water_loop,
                      water_heater_capacity,
                      water_heater_volume,
                      water_heater_fuel,
                      booster_water_temperature,
                      parasitic_fuel_consumption_rate,
                      booster_water_heater_thermal_zone,
                      building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding booster water heater to #{main_service_water_loop.name}.")

    # Booster water heating loop
    booster_service_water_loop = OpenStudio::Model::PlantLoop.new(self)
    booster_service_water_loop.setName('Service Water Loop')

    # Temperature schedule type limits
    temp_sch_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(self)
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
    swh_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    swh_temp_sch.setName("Service Water Booster Temp - #{swh_temp_f}F")
    swh_temp_sch.defaultDaySchedule.setName("Service Water Booster Temp - #{swh_temp_f}F Default")
    swh_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), swh_temp_c)
    swh_temp_sch.setScheduleTypeLimits(temp_sch_type_limits)
    swh_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, swh_temp_sch)
    swh_stpt_manager.setName('Hot water booster setpoint manager')
    swh_stpt_manager.addToNode(booster_service_water_loop.supplyOutletNode)
    sizing_plant = booster_service_water_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(swh_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(swh_delta_t_k)

    # Booster water heating pump
    swh_pump = OpenStudio::Model::PumpConstantSpeed.new(self)
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
    water_heater = OpenStudio::Model::WaterHeaterMixed.new(self)
    water_heater.setName("#{water_heater_vol_gal}gal #{water_heater_fuel} Booster Water Heater - #{water_heater_capacity_kbtu_per_hr.round}kBtu/hr")
    water_heater.setTankVolume(OpenStudio.convert(water_heater_vol_gal, 'gal', 'm^3').get)
    water_heater.setSetpointTemperatureSchedule(swh_temp_sch)

    if booster_water_heater_thermal_zone.nil?
      # Assume the water heater is indoors at 70F for now
      default_water_heater_ambient_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
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
    water_heater_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    booster_service_water_loop.addSupplyBranchForComponent(water_heater_bypass_pipe)
    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    booster_service_water_loop.addDemandBranchForComponent(coil_bypass_pipe)
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    supply_outlet_pipe.addToNode(booster_service_water_loop.supplyOutletNode)
    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_inlet_pipe.addToNode(booster_service_water_loop.demandInletNode)
    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(self)
    demand_outlet_pipe.addToNode(booster_service_water_loop.demandOutletNode)

    # Heat exchanger to supply the booster water heater
    # with normal hot water from the main service water loop.
    hx = OpenStudio::Model::HeatExchangerFluidToFluid.new(self)
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
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  def add_swh_end_uses(template,
                       use_name,
                       swh_loop,
                       peak_flowrate,
                       flowrate_schedule,
                       water_use_temperature,
                       space_name,
                       building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding water fixture to #{swh_loop.name}.")

    # Water use connection
    swh_connection = OpenStudio::Model::WaterUseConnections.new(self)

    # Water fixture definition
    water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(self)
    rated_flow_rate_m3_per_s = peak_flowrate
    rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get
    frac_sensible = 0.2
    frac_latent = 0.05
    # water_use_sensible_frac_sch = OpenStudio::Model::ScheduleConstant.new(self)
    # water_use_sensible_frac_sch.setValue(0.2)
    # water_use_latent_frac_sch = OpenStudio::Model::ScheduleConstant.new(self)
    # water_use_latent_frac_sch.setValue(0.05)
    water_use_sensible_frac_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    water_use_sensible_frac_sch.setName("Fraction Sensible - #{frac_sensible}")
    water_use_sensible_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), frac_sensible)
    water_use_latent_frac_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    water_use_latent_frac_sch.setName("Fraction Latent - #{frac_latent}")
    water_use_latent_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), frac_latent)
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    water_fixture_def.setName("#{use_name.capitalize} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    # Target mixed water temperature
    mixed_water_temp_f = OpenStudio.convert(water_use_temperature, 'C', 'F').get
    mixed_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    mixed_water_temp_sch.setName("Mixed Water At Faucet Temp - #{mixed_water_temp_f.round}F")
    mixed_water_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get)
    water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

    # Water use equipment
    water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
    schedule = add_schedule(flowrate_schedule)
    water_fixture.setFlowRateFractionSchedule(schedule)

    if space_name.nil?
      water_fixture.setName("#{use_name.capitalize} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    else
      water_fixture.setName("#{space_name.capitalize} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    end

    unless space_name.nil?
      space = getSpaceByName(space_name)
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
  def add_swh_end_uses_by_space(building_type, template, climate_zone, swh_loop, space_type_name, space_name, space_multiplier = nil, is_flow_per_area = true)
    # find the specific space_type properties from standard.json
    search_criteria = {
      'template' => template,
      'building_type' => building_type,
      'space_type' => space_type_name
    }
    data = find_object($os_standards['space_types'], search_criteria)
    if data.nil?
      puts "Error: #{search_criteria}"
    end
    space = getSpaceByName(space_name)
    space = space.get
    space_area = OpenStudio.convert(space.floorArea, 'm^2', 'ft^2').get # ft2
    if space_multiplier.nil?
      space_multiplier = 1
    end

    # If there is no service hot water load.. Don't bother adding anything.
    if data['service_water_heating_peak_flow_per_area'].to_f == 0.0 ||
       data['service_water_heating_peak_flow_rate'].to_f == 0.0
      return nil
    end

    # Water use connection
    swh_connection = OpenStudio::Model::WaterUseConnections.new(self)

    # Water fixture definition
    water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(self)
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
    water_use_sensible_frac_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    water_use_sensible_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
    water_use_latent_frac_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    water_use_latent_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.05)
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    water_fixture_def.setName("#{space_name.capitalize} Service Water Use Def #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    # Target mixed water temperature
    mixed_water_temp_c = data['service_water_heating_target_temperature']
    mixed_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    mixed_water_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), mixed_water_temp_c)
    water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

    # Water use equipment
    water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
    schedule = add_schedule(data['service_water_heating_schedule'])
    water_fixture.setFlowRateFractionSchedule(schedule)
    water_fixture.setName("#{space_name.capitalize} Service Water Use #{rated_flow_rate_gal_per_min.round(2)}gal/min")
    swh_connection.addWaterUseEquipment(water_fixture)

    # Connect the water use connection to the SWH loop
    swh_loop.addDemandBranchForComponent(swh_connection)
    return water_fixture
  end

  # Creates water fixtures and attaches them
  # to the supplied booster water loop.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @param swh_booster_loop [OpenStudio::Model::PlantLoop]
  # the booster water loop to add water fixtures to.
  # @param peak_flowrate [Double] in m^3/s
  # @param flowrate_schedule [String] name of the flow rate schedule
  # @param water_use_temperature [Double] mixed water use temperature, in C
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::WaterUseEquipment]
  # the resulting water fixture.
  def add_booster_swh_end_uses(template,
                               swh_booster_loop,
                               peak_flowrate,
                               flowrate_schedule,
                               water_use_temperature,
                               building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding water fixture to #{swh_booster_loop.name}.")

    # Water use connection
    swh_connection = OpenStudio::Model::WaterUseConnections.new(self)

    # Water fixture definition
    water_fixture_def = OpenStudio::Model::WaterUseEquipmentDefinition.new(self)
    rated_flow_rate_m3_per_s = peak_flowrate
    rated_flow_rate_gal_per_min = OpenStudio.convert(rated_flow_rate_m3_per_s, 'm^3/s', 'gal/min').get
    water_fixture_def.setName("Water Fixture Def - #{rated_flow_rate_gal_per_min} gal/min")
    water_fixture_def.setPeakFlowRate(rated_flow_rate_m3_per_s)
    # Target mixed water temperature
    mixed_water_temp_f = OpenStudio.convert(water_use_temperature, 'F', 'C').get
    mixed_water_temp_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    mixed_water_temp_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), OpenStudio.convert(mixed_water_temp_f, 'F', 'C').get)
    puts mixed_water_temp_sch
    water_fixture_def.setTargetTemperatureSchedule(mixed_water_temp_sch)

    # Water use equipment
    water_fixture = OpenStudio::Model::WaterUseEquipment.new(water_fixture_def)
    water_fixture.setName("Booster Water Fixture - #{rated_flow_rate_gal_per_min} gal/min at #{mixed_water_temp_f}F")
    schedule = add_schedule(flowrate_schedule)
    water_fixture.setFlowRateFractionSchedule(schedule)
    swh_connection.addWaterUseEquipment(water_fixture)

    # Connect the water use connection to the SWH loop
    swh_booster_loop.addDemandBranchForComponent(swh_connection)

    return water_fixture
  end

  # Creates a DOAS system with fan coil units
  # for each zone.
  #
  # @param template [String] Valid choices are 90.1-2004,
  # 90.1-2007, 90.1-2010, 90.1-2013
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
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting DOAS air loop
  def add_doas(template,
               sys_name,
               hot_water_loop,
               chilled_water_loop,
               thermal_zones,
               hvac_op_sch,
               oa_damper_sch,
               fan_max_flow_rate,
               economizer_control_type,
               building_type = nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding DOAS system for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # hvac operation schedule
    hvac_op_sch = if hvac_op_sch.nil?
                    alwaysOnDiscreteSchedule
                  else
                    add_schedule(hvac_op_sch)
                  end

    # oa damper schedule
    oa_damper_sch = if oa_damper_sch.nil?
                      alwaysOnDiscreteSchedule
                    else
                      add_schedule(oa_damper_sch)
                    end

    # DOAS
    air_loop = OpenStudio::Model::AirLoopHVAC.new(self)
    if sys_name.nil?
      air_loop.setName("#{thermal_zones.size} DOAS Air Loop HVAC")
    else
      air_loop.setName('DOAS Air Loop HVAC')
    end
    air_loop.setNightCycleControlType('CycleOnAny')
    # modify system sizing properties
    sizing_system = air_loop.sizingSystem
    # set central heating and cooling temperatures for sizing
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(12.8)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(16.7) # ML OS default is 16.7
    sizing_system.setSizingOption('Coincident')
    # load specification
    sizing_system.setSystemOutdoorAirMethod('ZoneSum') # ML OS default is ZoneSum
    sizing_system.setTypeofLoadtoSizeOn('Sensible')         # DOAS
    sizing_system.setAllOutdoorAirinCooling(true)           # DOAS
    sizing_system.setAllOutdoorAirinHeating(true)           # DOAS
    sizing_system.setMinimumSystemAirFlowRatio(0.3)         # No DCV

    # set availability schedule
    air_loop.setAvailabilitySchedule(hvac_op_sch)
    airloop_supply_inlet = air_loop.supplyInletNode

    # create air loop fan
    # constant speed fan
    fan = OpenStudio::Model::FanConstantVolume.new(self, alwaysOnDiscreteSchedule)
    fan.setName('DOAS fan')
    fan.setFanEfficiency(0.58175)
    fan.setPressureRise(622.5) # Pa
    if !fan_max_flow_rate.nil?
      fan.setMaximumFlowRate(OpenStudio.convert(fan_max_flow_rate, 'cfm', 'm^3/s').get) # unit of fan_max_flow_rate is cfm
    else
      fan.autosizeMaximumFlowRate
    end
    fan.setMotorEfficiency(0.895)
    fan.setMotorInAirstreamFraction(1.0)
    fan.setEndUseSubcategory('DOAS Fans')
    fan.addToNode(airloop_supply_inlet)

    # create heating coil
    # water coil
    heating_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
    hot_water_loop.addDemandBranchForComponent(heating_coil)
    heating_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
    heating_coil.addToNode(airloop_supply_inlet)
    heating_coil.controllerWaterCoil.get.setControllerConvergenceTolerance(0.0001)

    # create cooling coil
    # water coil
    cooling_coil = OpenStudio::Model::CoilCoolingWater.new(self, alwaysOnDiscreteSchedule)
    chilled_water_loop.addDemandBranchForComponent(cooling_coil)
    cooling_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)
    cooling_coil.addToNode(airloop_supply_inlet)

    # create controller outdoor air
    controller_oa = OpenStudio::Model::ControllerOutdoorAir.new(self)
    controller_oa.setName('DOAS OA Controller')
    controller_oa.setEconomizerControlType(economizer_control_type)
    controller_oa.setMinimumLimitType('FixedMinimum')
    controller_oa.setMinimumOutdoorAirSchedule(oa_damper_sch)
    controller_oa.resetEconomizerMaximumLimitDryBulbTemperature
    # TODO: Yixing read the schedule from the Prototype Input
    if building_type == 'LargeHotel'
      controller_oa.setMinimumFractionofOutdoorAirSchedule(add_schedule('HotelLarge FLR_3_DOAS_OAminOAFracSchedule'))
    end
    controller_oa.resetEconomizerMaximumLimitEnthalpy
    controller_oa.resetMaximumFractionofOutdoorAirSchedule
    controller_oa.resetEconomizerMinimumLimitDryBulbTemperature

    # create ventilation schedules and assign to OA controller
    controller_oa.setHeatRecoveryBypassControlType('BypassWhenWithinEconomizerLimits')

    # create outdoor air system
    system_oa = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(self, controller_oa)
    system_oa.addToNode(airloop_supply_inlet)

    # create scheduled setpoint manager for airloop
    # DOAS or VAV for cooling and not ventilation
    setpoint_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(self)
    setpoint_manager.setControlVariable('Temperature')
    setpoint_manager.setSetpointatOutdoorLowTemperature(15.5)
    setpoint_manager.setOutdoorLowTemperature(15.5)
    setpoint_manager.setSetpointatOutdoorHighTemperature(12.8)
    setpoint_manager.setOutdoorHighTemperature(21)

    # connect components to airloop
    # find the supply inlet node of the airloop

    # add setpoint manager to supply equipment outlet node
    setpoint_manager.addToNode(air_loop.supplyOutletNode)

    # add thermal zones to airloop
    thermal_zones.each do |zone|
      zone_name = zone.name.to_s

      zone_sizing = zone.sizingZone
      zone_sizing.setZoneCoolingDesignSupplyAirTemperature(12.8)
      zone_sizing.setZoneHeatingDesignSupplyAirTemperature(40)
      zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
      zone_sizing.setHeatingDesignAirFlowMethod('DesignDay')

      # make an air terminal for the zone
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(self, alwaysOnDiscreteSchedule)
      air_terminal.setName(zone_name + 'Air Terminal')

      fan_coil_cooling_coil = OpenStudio::Model::CoilCoolingWater.new(self, alwaysOnDiscreteSchedule)
      fan_coil_cooling_coil.setName(zone_name + 'FCU Cooling Coil')
      chilled_water_loop.addDemandBranchForComponent(fan_coil_cooling_coil)
      fan_coil_cooling_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)

      fan_coil_heating_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
      fan_coil_heating_coil.setName(zone_name + 'FCU Heating Coil')
      hot_water_loop.addDemandBranchForComponent(fan_coil_heating_coil)
      fan_coil_heating_coil.controllerWaterCoil.get.setMinimumActuatedFlow(0)

      fan_coil_fan = OpenStudio::Model::FanOnOff.new(self, alwaysOnDiscreteSchedule)
      fan_coil_fan.setName(zone_name + ' Fan Coil fan')
      fan_coil_fan.setFanEfficiency(0.16)
      fan_coil_fan.setPressureRise(270.9) # Pa
      fan_coil_fan.autosizeMaximumFlowRate
      fan_coil_fan.setMotorEfficiency(0.29)
      fan_coil_fan.setMotorInAirstreamFraction(1.0)
      fan_coil_fan.setEndUseSubcategory('FCU Fans')

      fan_coil = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(self, alwaysOnDiscreteSchedule,
                                                                fan_coil_fan, fan_coil_cooling_coil, fan_coil_heating_coil)
      fan_coil.setName(zone_name + 'FCU')
      fan_coil.setCapacityControlMethod('CyclingFan')
      fan_coil.autosizeMaximumSupplyAirFlowRate
      fan_coil.setMaximumOutdoorAirFlowRate(0)
      fan_coil.addToThermalZone(zone)

      # attach new terminal to the zone and to the airloop
      air_loop.addBranchForZone(zone, air_terminal.to_StraightComponent)
    end

    return air_loop
  end

  # Add an elevator the the specified space
  #
  # @param template [String] Valid choices are
  # DOE Ref Pre-1980, DOE Ref 1980-2004,
  # 90.1-2004, 90.1-2007, 90.1-2010, 90.1-2013,
  # @param space [OpenStudio::Model::Space] the space
  # to assign the elevators to.
  # @param number_of_elevators [Integer] the number of elevators
  # @param elevator_type [String] valid choices are
  # Traction, Hydraulic
  # @param elevator_schedule [String] the name of the elevator schedule
  # @param elevator_fan_schedule [String] the name of the elevator fan schedule
  # @param elevator_lights_schedule [String] the name of the elevator lights schedule
  # @param building_type [String] the building type
  # @return [OpenStudio::Model::ElectricEquipment] the resulting elevator
  def add_elevator(template,
                   space,
                   number_of_elevators,
                   elevator_type,
                   elevator_schedule,
                   elevator_fan_schedule,
                   elevator_lights_schedule,
                   building_type = nil)

    # Lift motor assumptions
    lift_pwr_w = nil
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      if elevator_type == 'Traction'
        lift_pwr_w = 18_537.0
      elsif elevator_type == 'Hydraulic'
        lift_pwr_w = if building_type == 'MidriseApartment'
                       16_055.0
                     else
                       14_610.0
                     end
      else
        lift_pwr_w = 14_610.0
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Elevator type '#{elevator_type}', not recognized, will assume Hydraulic elevator, #{lift_pwr_w} W.")
      end
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      if elevator_type == 'Traction'
        lift_pwr_w = 20_370.0
      elsif elevator_type == 'Hydraulic'
        lift_pwr_w = 16_055.0
      else
        lift_pwr_w = 16_055.0
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Elevator type '#{elevator_type}', not recognized, will assume Hydraulic elevator, #{lift_pwr_w} W.")
      end
    end

    # Size assumptions
    length_ft = 6.66
    width_ft = 4.25
    height_ft = 8.0
    area_ft2 = length_ft * width_ft
    volume_ft3 = area_ft2 * height_ft

    # Ventilation assumptions
    vent_rate_acm = 1 # air changes per minute
    vent_rate_cfm = volume_ft3 / vent_rate_acm
    vent_pwr_per_flow_w_per_cfm = 0.33
    vent_pwr_w = vent_pwr_per_flow_w_per_cfm * vent_rate_cfm

    # Lighting assumptions
    design_ltg_lm_per_ft2 = 30
    light_loss_factor = 0.75
    pct_incandescent = 0.7
    pct_led = 0.3
    incandescent_efficacy_lm_per_w = 10.0
    led_efficacy_lm_per_w = 35.0
    target_ltg_lm_per_ft2 = design_ltg_lm_per_ft2 / light_loss_factor # 40
    target_ltg_lm = target_ltg_lm_per_ft2 * area_ft2 # 1132.2
    lm_incandescent = target_ltg_lm * pct_incandescent # 792.54
    lm_led = target_ltg_lm * pct_led # 339.66
    w_incandescent = lm_incandescent / incandescent_efficacy_lm_per_w # 79.254
    w_led = lm_led / led_efficacy_lm_per_w # 9.7
    lighting_pwr_w = w_incandescent + w_led

    # Elevator lift motor
    elevator_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
    elevator_definition.setName('Elevator Lift Motor')
    elevator_definition.setDesignLevel(lift_pwr_w)

    elevator_equipment = OpenStudio::Model::ElectricEquipment.new(elevator_definition)
    elevator_equipment.setName("#{number_of_elevators.round} Elevator Lift Motors")
    elevator_sch = add_schedule(elevator_schedule)
    elevator_equipment.setSchedule(elevator_sch)
    elevator_equipment.setSpace(space)
    elevator_equipment.setMultiplier(number_of_elevators)

    # Pre-1980 and 1980-2004 don't have lights or fans
    return elevator_equipment if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'

    # Elevator fan
    elevator_fan_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
    elevator_fan_definition.setName('Elevator Fan')
    elevator_fan_definition.setDesignLevel(vent_pwr_w)

    elevator_fan_equipment = OpenStudio::Model::ElectricEquipment.new(elevator_fan_definition)
    elevator_fan_equipment.setName("#{number_of_elevators.round} Elevator Fans")
    elevator_fan_sch = add_schedule(elevator_fan_schedule)
    elevator_fan_equipment.setSchedule(elevator_fan_sch)
    elevator_fan_equipment.setSpace(space)
    elevator_fan_equipment.setMultiplier(number_of_elevators)

    # Elevator lights
    elevator_lights_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
    elevator_lights_definition.setName('Elevator Lights')
    elevator_lights_definition.setDesignLevel(lighting_pwr_w)

    elevator_lights_equipment = OpenStudio::Model::ElectricEquipment.new(elevator_lights_definition)
    elevator_lights_equipment.setName("#{number_of_elevators.round} Elevator Lights")
    elevator_lights_sch = add_schedule(elevator_lights_schedule)
    elevator_lights_equipment.setSchedule(elevator_lights_sch)
    elevator_lights_equipment.setSpace(space)
    elevator_lights_equipment.setMultiplier(number_of_elevators)

    return elevator_equipment
  end

  # Adds an exhaust fan to each zone.
  #
  # @param availability_sch_name [String] the name of the fan availability schedule
  # @param flow_rate [Double] the exhaust fan flow rate in m^3/s
  # @param balanced_exhaust_fraction_schedule_name [String] the name
  # of the balanced exhaust fraction schedule.
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] an array of thermal zones
  # @return [Array<OpenStudio::Model::FanZoneExhaust>] an array of exhaust fans created
  def add_exhaust_fan(availability_sch_name,
                      flow_rate,
                      flow_fraction_schedule_name,
                      balanced_exhaust_fraction_schedule_name,
                      thermal_zones)

    # Make an exhaust fan for each zone
    fans = []
    thermal_zones.each do |zone|
      fan = OpenStudio::Model::FanZoneExhaust.new(self)
      fan.setName("#{zone.name} Exhaust Fan")
      fan.setAvailabilitySchedule(add_schedule(availability_sch_name))
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
        fan.setFlowFractionSchedule(add_schedule(flow_fraction_schedule_name))
      end
      fan.setSystemAvailabilityManagerCouplingMode('Decoupled')
      unless balanced_exhaust_fraction_schedule_name.nil?
        fan.setBalancedExhaustFractionSchedule(add_schedule(balanced_exhaust_fraction_schedule_name))
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
  def add_zone_ventilation(availability_sch_name,
                           flow_rate,
                           ventilation_type,
                           thermal_zones)

    # Make an exhaust fan for each zone
    zone_ventilations = []
    thermal_zones.each do |zone|
      ventilation = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(self)
      ventilation.setName("#{zone.name} Ventilation")
      ventilation.setSchedule(add_schedule(availability_sch_name))
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

  # Adds a single refrigerated case connected to a rack composed
  # of a single compressor and a single air-cooled condenser.
  #
  # @note The legacy prototype IDF files use the simplified
  # Refreigeration:ComprssorRack object, but this object is
  # not included in OpenStudio.  Instead, a detailed rack
  # with similar performance is added.
  # @todo Set compressor properties since prototypes use simple
  # refrigeration rack instead of detailed
  # @todo fix latent case credit curve setter
  def add_refrigeration(template,
                        case_type,
                        cooling_capacity_per_length,
                        length,
                        evaporator_fan_pwr_per_length,
                        lighting_per_length,
                        lighting_sch_name,
                        defrost_pwr_per_length,
                        restocking_sch_name,
                        cop,
                        cop_f_of_t_curve_name,
                        condenser_fan_pwr,
                        condenser_fan_pwr_curve_name,
                        thermal_zone)

    # Default properties based on the case type
    # case_type = 'Walkin Freezer', 'Display Case'
    case_temp = nil
    latent_heat_ratio = nil
    runtime_fraction = nil
    fraction_antisweat_to_case = nil
    under_case_return_air_fraction = nil
    latent_case_credit_curve_name = nil
    defrost_type = nil
    if case_type == 'Walkin Freezer'
      case_temp = OpenStudio.convert(-9.4, 'F', 'C').get
      latent_heat_ratio = 0.1
      runtime_fraction = 0.4
      fraction_antisweat_to_case = 0.0
      under_case_return_air_fraction = 0.0
      case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        latent_case_credit_curve_name = 'Single Shelf Horizontal Latent Energy Multiplier_After2004'
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        latent_case_credit_curve_name = 'Single Shelf Horizontal Latent Energy Multiplier_Pre2004'
      end
      defrost_type = 'Electric'
    elsif case_type == 'Display Case'
      case_temp = OpenStudio.convert(35.6, 'F', 'C').get
      latent_heat_ratio = 0.08
      runtime_fraction = 0.85
      fraction_antisweat_to_case = 0.2
      under_case_return_air_fraction = 0.05
      latent_case_credit_curve_name = 'Multi Shelf Vertical Latent Energy Multiplier'
      defrost_type = 'None'
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Refrigeration System')

    # Defrost schedule
    defrost_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    defrost_sch.setName('Refrigeration Defrost Schedule')
    defrost_sch.defaultDaySchedule.setName('Refrigeration Defrost Schedule Default')
    if case_type == 'Walkin Freezer'
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 11, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 11, 20, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 0, 0), 0)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 20, 0), 1)
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
    elsif case_type == 'Display Case'
      defrost_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 20, 0), 0)
    end

    # Dripdown schedule
    defrost_dripdown_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    defrost_dripdown_sch.setName('Refrigeration Defrost DripDown Schedule')
    defrost_dripdown_sch.defaultDaySchedule.setName('Refrigeration Defrost DripDown Schedule Default')
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 11, 0, 0), 0)
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 11, 30, 0), 1)
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 0, 0), 0)
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 23, 30, 0), 1)
    defrost_dripdown_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)

    # Case Credit Schedule
    case_credit_sch = OpenStudio::Model::ScheduleRuleset.new(self)
    case_credit_sch.setName('Refrigeration Case Credit Schedule')
    case_credit_sch.defaultDaySchedule.setName('Refrigeration Case Credit Schedule Default')
    case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 7, 0, 0), 0.2)
    case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 21, 0, 0), 0.4)
    case_credit_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)

    # Case
    ref_case = OpenStudio::Model::RefrigerationCase.new(self, defrost_sch)
    ref_case.setName("#{thermal_zone.name} #{case_type}")
    ref_case.setAvailabilitySchedule(alwaysOnDiscreteSchedule)
    ref_case.setThermalZone(thermal_zone)
    ref_case.setRatedTotalCoolingCapacityperUnitLength(cooling_capacity_per_length)
    ref_case.setCaseLength(length)
    ref_case.setCaseOperatingTemperature(case_temp)
    ref_case.setStandardCaseFanPowerperUnitLength(evaporator_fan_pwr_per_length)
    ref_case.setOperatingCaseFanPowerperUnitLength(evaporator_fan_pwr_per_length)
    ref_case.setStandardCaseLightingPowerperUnitLength(lighting_per_length)
    ref_case.resetInstalledCaseLightingPowerperUnitLength
    ref_case.setCaseLightingSchedule(add_schedule(lighting_sch_name))
    ref_case.setHumidityatZeroAntiSweatHeaterEnergy(0)
    unless defrost_type == 'None'
      ref_case.setCaseDefrostType('Electric')
      ref_case.setCaseDefrostPowerperUnitLength(defrost_pwr_per_length)
      ref_case.setCaseDefrostDripDownSchedule(defrost_dripdown_sch)
    end
    ref_case.setUnderCaseHVACReturnAirFraction(under_case_return_air_fraction)
    ref_case.setFractionofAntiSweatHeaterEnergytoCase(fraction_antisweat_to_case)
    ref_case.resetDesignEvaporatorTemperatureorBrineInletTemperature
    ref_case.setRatedAmbientTemperature(OpenStudio.convert(75, 'F', 'C').get)
    ref_case.setRatedLatentHeatRatio(latent_heat_ratio)
    ref_case.setRatedRuntimeFraction(runtime_fraction)
    # TODO: enable ref_case.setLatentCaseCreditCurve(self.add_curve(latent_case_credit_curve_name))
    ref_case.setLatentCaseCreditCurve(add_curve(latent_case_credit_curve_name))
    ref_case.setCaseHeight(0)
    # TODO: setRefrigeratedCaseRestockingSchedule is not working
    ref_case.setRefrigeratedCaseRestockingSchedule(add_schedule(restocking_sch_name))
    if case_type == 'Walkin Freezer'
      ref_case.setCaseCreditFractionSchedule(case_credit_sch)
    end

    # Compressor
    # TODO set compressor properties since prototypes use simple
    # refrigeration rack instead of detailed
    compressor = OpenStudio::Model::RefrigerationCompressor.new(self)

    # Condenser
    condenser = OpenStudio::Model::RefrigerationCondenserAirCooled.new(self)
    condenser.setRatedFanPower(condenser_fan_pwr)

    # Refrigeration system
    ref_sys = OpenStudio::Model::RefrigerationSystem.new(self)
    ref_sys.addCompressor(compressor)
    ref_sys.addCase(ref_case)
    ref_sys.setRefrigerationCondenser(condenser)
    ref_sys.setSuctionPipingZone(thermal_zone)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding Refrigeration System')

    return true
  end
end

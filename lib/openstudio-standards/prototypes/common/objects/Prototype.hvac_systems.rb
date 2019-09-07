class Standard
  # @!group hvac_systems

  # Returns standard design sizing temperatures

  # @return [Hash] Hash of design sizing temperature lookups
  def standard_design_sizing_temperatures
    dsgn_temps = {}
    dsgn_temps['prehtg_dsgn_sup_air_temp_f'] = 45.0
    dsgn_temps['preclg_dsgn_sup_air_temp_f'] = 55.0
    dsgn_temps['htg_dsgn_sup_air_temp_f'] = 55.0
    dsgn_temps['clg_dsgn_sup_air_temp_f'] = 55.0
    dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 104.0
    dsgn_temps['zn_clg_dsgn_sup_air_temp_f'] = 55.0
    dsgn_temps['prehtg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['prehtg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['preclg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['preclg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['htg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['clg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['clg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['zn_clg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_clg_dsgn_sup_air_temp_f'], 'F', 'C').get
    return dsgn_temps
  end

  # Creates a hot water loop with a boiler, district heating, or a
  # water-to-water heat pump and adds it to the model.
  #
  # @param boiler_fuel_type [String] valid choices are Electricity, NaturalGas, PropaneGas, FuelOil#1, FuelOil#2, DistrictHeating, HeatPump
  # @param ambient_loop [OpenStudio::Model::PlantLoop] The condenser loop for the heat pump. Only used when boiler_fuel_type is HeatPump.
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param dsgn_sup_wtr_temp [Double] design supply water temperature in degrees Fahrenheit, default 180F
  # @param dsgn_sup_wtr_temp_delt [Double] design supply-return water temperature difference in degrees Rankine, default 20R
  # @param pump_spd_ctrl [String] pump speed control type, Constant or Variable (default)
  # @param pump_tot_hd [Double] pump head in ft H2O
  # @param boiler_draft_type [String] Boiler type Condensing, MechanicalNoncondensing, Natural (default)
  # @param boiler_eff_curve_temp_eval_var [String] LeavingBoiler or EnteringBoiler temperature for the boiler efficiency curve
  # @param boiler_lvg_temp_dsgn [Double] boiler leaving design temperature in degrees Fahrenheit
  # @param boiler_out_temp_lmt [Double] boiler outlet temperature limit in degrees Fahrenheit
  # @param boiler_max_plr [Double] boiler maximum part load ratio
  # @param boiler_sizing_factor [Double] boiler oversizing factor
  # @return [OpenStudio::Model::PlantLoop] the resulting hot water loop
  def model_add_hw_loop(model,
                        boiler_fuel_type,
                        ambient_loop: nil,
                        system_name: 'Hot Water Loop',
                        dsgn_sup_wtr_temp: 180.0,
                        dsgn_sup_wtr_temp_delt: 20.0,
                        pump_spd_ctrl: 'Variable',
                        pump_tot_hd: nil,
                        boiler_draft_type: nil,
                        boiler_eff_curve_temp_eval_var: nil,
                        boiler_lvg_temp_dsgn: nil,
                        boiler_out_temp_lmt: nil,
                        boiler_max_plr: nil,
                        boiler_sizing_factor: nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding hot water loop.')

    # create hot water loop
    hot_water_loop = OpenStudio::Model::PlantLoop.new(model)
    if system_name.nil?
      hot_water_loop.setName('Hot Water Loop')
    else
      hot_water_loop.setName(system_name)
    end

    # hot water loop sizing and controls
    if dsgn_sup_wtr_temp.nil?
      dsgn_sup_wtr_temp = 180.0
      dsgn_sup_wtr_temp_c = OpenStudio.convert(dsgn_sup_wtr_temp, 'F', 'C').get
    else
      dsgn_sup_wtr_temp_c = OpenStudio.convert(dsgn_sup_wtr_temp, 'F', 'C').get
    end
    if dsgn_sup_wtr_temp_delt.nil?
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(20.0, 'R', 'K').get
    else
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(dsgn_sup_wtr_temp_delt, 'R', 'K').get
    end

    sizing_plant = hot_water_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(dsgn_sup_wtr_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(dsgn_sup_wtr_temp_delt_k)
    hot_water_loop.setMinimumLoopTemperature(10.0)
    hw_temp_sch = model_add_constant_schedule_ruleset(model,
                                                      dsgn_sup_wtr_temp_c,
                                                      name = "#{hot_water_loop.name} Temp - #{dsgn_sup_wtr_temp.round(0)}F")
    hw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, hw_temp_sch)
    hw_stpt_manager.setName("#{hot_water_loop.name} Setpoint Manager")
    hw_stpt_manager.addToNode(hot_water_loop.supplyOutletNode)

    # create hot water pump
    if pump_spd_ctrl == 'Constant'
      hw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    elsif pump_spd_ctrl == 'Variable'
      hw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    else
      hw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    end
    hw_pump.setName("#{hot_water_loop.name} Pump")
    if pump_tot_hd.nil?
      pump_tot_hd_pa = OpenStudio.convert(60, 'ftH_{2}O', 'Pa').get
    else
      pump_tot_hd_pa = OpenStudio.convert(pump_tot_hd, 'ftH_{2}O', 'Pa').get
    end
    hw_pump.setRatedPumpHead(pump_tot_hd_pa)
    hw_pump.setMotorEfficiency(0.9)
    hw_pump.setPumpControlType('Intermittent')
    hw_pump.addToNode(hot_water_loop.supplyInletNode)

    # create boiler and add to loop
    case boiler_fuel_type
      # District Heating
      when 'DistrictHeating'
        district_heat = OpenStudio::Model::DistrictHeating.new(model)
        district_heat.setName("#{hot_water_loop.name} District Heating")
        district_heat.autosizeNominalCapacity
        hot_water_loop.addSupplyBranchForComponent(district_heat)
      # Ambient Loop
      when 'HeatPump', 'AmbientLoop'
        water_to_water_hp = OpenStudio::Model::HeatPumpWaterToWaterEquationFitHeating.new(model)
        water_to_water_hp.setName("#{hot_water_loop.name} Water to Water Heat Pump")
        hot_water_loop.addSupplyBranchForComponent(water_to_water_hp)
        # Get or add an ambient loop
        if ambient_loop.nil?
          ambient_loop = model_get_or_add_ambient_water_loop(model)
        end
        ambient_loop.addDemandBranchForComponent(water_to_water_hp)
      # Central Air Source Heat Pump
      when 'AirSourceHeatPump', 'ASHP'
        create_central_air_source_heat_pump(model, hot_water_loop)
      # Boiler
      when 'Electricity', 'Gas', 'NaturalGas', 'PropaneGas', 'FuelOil#1', 'FuelOil#2'
        if boiler_lvg_temp_dsgn.nil?
          lvg_temp_dsgn = dsgn_sup_wtr_temp
        else
          lvg_temp_dsgn = boiler_lvg_temp_dsgn
        end

        if boiler_out_temp_lmt.nil?
          out_temp_lmt = OpenStudio.convert(203.0, 'F', 'C').get
        else
          out_temp_lmt = boiler_out_temp_lmt
        end

        boiler = create_boiler_hot_water(model,
                                         hot_water_loop: hot_water_loop,
                                         fuel_type: boiler_fuel_type,
                                         draft_type: boiler_draft_type,
                                         nominal_thermal_efficiency: 0.78,
                                         eff_curve_temp_eval_var: boiler_eff_curve_temp_eval_var,
                                         lvg_temp_dsgn: lvg_temp_dsgn,
                                         out_temp_lmt: out_temp_lmt,
                                         max_plr: boiler_max_plr,
                                         sizing_factor: boiler_sizing_factor)

        # TODO: Yixing. Adding temperature setpoint controller at boiler outlet causes simulation errors
        # boiler_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(self, hw_temp_sch)
        # boiler_stpt_manager.setName("Boiler outlet setpoint manager")
        # boiler_stpt_manager.addToNode(boiler.outletModelObject.get.to_Node.get)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Boiler fuel type #{boiler_fuel_type} is not valid, no boiler will be added.")
    end

    # add hot water loop pipes
    supply_equipment_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_equipment_bypass_pipe.setName("#{hot_water_loop.name} Supply Equipment Bypass")
    hot_water_loop.addSupplyBranchForComponent(supply_equipment_bypass_pipe)

    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    coil_bypass_pipe.setName("#{hot_water_loop.name} Coil Bypass")
    hot_water_loop.addDemandBranchForComponent(coil_bypass_pipe)

    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.setName("#{hot_water_loop.name} Supply Outlet")
    supply_outlet_pipe.addToNode(hot_water_loop.supplyOutletNode)

    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.setName("#{hot_water_loop.name} Demand Inlet")
    demand_inlet_pipe.addToNode(hot_water_loop.demandInletNode)

    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.setName("#{hot_water_loop.name} Demand Outlet")
    demand_outlet_pipe.addToNode(hot_water_loop.demandOutletNode)

    return hot_water_loop
  end

  # Creates a chilled water loop and adds it to the model.
  #
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
  # @return [OpenStudio::Model::PlantLoop] the resulting chilled water loop
  def model_add_chw_loop(model,
                         system_name: 'Chilled Water Loop',
                         cooling_fuel: 'Electricity',
                         dsgn_sup_wtr_temp: 44.0,
                         dsgn_sup_wtr_temp_delt: 10.1,
                         chw_pumping_type: nil,
                         chiller_cooling_type: nil,
                         chiller_condenser_type: nil,
                         chiller_compressor_type: nil,
                         num_chillers: 1,
                         condenser_water_loop: nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding chilled water loop.')

    # create chilled water loop
    chilled_water_loop = OpenStudio::Model::PlantLoop.new(model)
    if system_name.nil?
      chilled_water_loop.setName('Chilled Water Loop')
    else
      chilled_water_loop.setName(system_name)
    end

    # chilled water loop sizing and controls
    if dsgn_sup_wtr_temp.nil?
      dsgn_sup_wtr_temp = 44.0
      dsgn_sup_wtr_temp_c = OpenStudio.convert(dsgn_sup_wtr_temp, 'F', 'C').get
    else
      dsgn_sup_wtr_temp_c = OpenStudio.convert(dsgn_sup_wtr_temp, 'F', 'C').get
    end
    if dsgn_sup_wtr_temp_delt.nil?
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(10.1, 'R', 'K').get
    else
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(dsgn_sup_wtr_temp_delt, 'R', 'K').get
    end
    chilled_water_loop.setMinimumLoopTemperature(1.0)
    chilled_water_loop.setMaximumLoopTemperature(40.0)
    sizing_plant = chilled_water_loop.sizingPlant
    sizing_plant.setLoopType('Cooling')
    sizing_plant.setDesignLoopExitTemperature(dsgn_sup_wtr_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(dsgn_sup_wtr_temp_delt_k)
    chw_temp_sch = model_add_constant_schedule_ruleset(model,
                                                       dsgn_sup_wtr_temp_c,
                                                       name = "#{chilled_water_loop.name} Temp - #{dsgn_sup_wtr_temp.round(0)}F")
    chw_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, chw_temp_sch)
    chw_stpt_manager.setName("#{chilled_water_loop.name} Setpoint Manager")
    chw_stpt_manager.addToNode(chilled_water_loop.supplyOutletNode)
    # TODO: Yixing check the CHW Setpoint from standards
    # TODO: Should be a OutdoorAirReset, see the changes I've made in Standards.PlantLoop.apply_prm_baseline_temperatures

    # create chilled water pumps
    if chw_pumping_type == 'const_pri'
      # primary chilled water pump
      pri_chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      pri_chw_pump.setName("#{chilled_water_loop.name} Pump")
      pri_chw_pump.setRatedPumpHead(OpenStudio.convert(60.0, 'ftH_{2}O', 'Pa').get)
      pri_chw_pump.setMotorEfficiency(0.9)
      # flat pump curve makes it behave as a constant speed pump
      pri_chw_pump.setFractionofMotorInefficienciestoFluidStream(0)
      pri_chw_pump.setCoefficient1ofthePartLoadPerformanceCurve(0)
      pri_chw_pump.setCoefficient2ofthePartLoadPerformanceCurve(1)
      pri_chw_pump.setCoefficient3ofthePartLoadPerformanceCurve(0)
      pri_chw_pump.setCoefficient4ofthePartLoadPerformanceCurve(0)
      pri_chw_pump.setPumpControlType('Intermittent')
      pri_chw_pump.addToNode(chilled_water_loop.supplyInletNode)
    elsif chw_pumping_type == 'const_pri_var_sec'
      # primary chilled water pump
      pri_chw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
      pri_chw_pump.setName("#{chilled_water_loop.name} Primary Pump")
      pri_chw_pump.setRatedPumpHead(OpenStudio.convert(15.0, 'ftH_{2}O', 'Pa').get)
      pri_chw_pump.setMotorEfficiency(0.9)
      pri_chw_pump.setPumpControlType('Intermittent')
      pri_chw_pump.addToNode(chilled_water_loop.supplyInletNode)
      # secondary chilled water pump
      sec_chw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
      sec_chw_pump.setName("#{chilled_water_loop.name} Secondary Pump")
      sec_chw_pump.setRatedPumpHead(OpenStudio.convert(45.0, 'ftH_{2}O', 'Pa').get)
      sec_chw_pump.setMotorEfficiency(0.9)
      # curve makes it perform like variable speed pump
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

    # check for existence of condenser_water_loop if WaterCooled
    if chiller_cooling_type == 'WaterCooled'
      if condenser_water_loop.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', 'Requested chiller is WaterCooled but no condenser loop specified.')
      end
    end

    # check for non-existence of condenser_water_loop if AirCooled
    if chiller_cooling_type == 'AirCooled'
      unless condenser_water_loop.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', 'Requested chiller is AirCooled but condenser loop specified.')
      end
    end

    if cooling_fuel == 'DistrictCooling'
      # DistrictCooling
      dist_clg = OpenStudio::Model::DistrictCooling.new(model)
      dist_clg.setName('Purchased Cooling')
      dist_clg.autosizeNominalCapacity
      chilled_water_loop.addSupplyBranchForComponent(dist_clg)
    else
      # make the correct type of chiller based these properties
      chiller_sizing_factor = (1.0 / num_chillers).round(2)
      num_chillers.times do |i|
        chiller = OpenStudio::Model::ChillerElectricEIR.new(model)
        chiller.setName("#{template} #{chiller_cooling_type} #{chiller_condenser_type} #{chiller_compressor_type} Chiller #{i}")
        chilled_water_loop.addSupplyBranchForComponent(chiller)
        chiller.setReferenceLeavingChilledWaterTemperature(dsgn_sup_wtr_temp_c)
        chiller.setLeavingChilledWaterLowerTemperatureLimit(OpenStudio.convert(36.0, 'F', 'C').get)
        chiller.setReferenceEnteringCondenserFluidTemperature(OpenStudio.convert(95.0, 'F', 'C').get)
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

    # chilled water loop pipes
    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    chiller_bypass_pipe.setName("#{chilled_water_loop.name} Chiller Bypass")
    chilled_water_loop.addSupplyBranchForComponent(chiller_bypass_pipe)

    coil_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    coil_bypass_pipe.setName("#{chilled_water_loop.name} Coil Bypass")
    chilled_water_loop.addDemandBranchForComponent(coil_bypass_pipe)

    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.setName("#{chilled_water_loop.name} Supply Outlet")
    supply_outlet_pipe.addToNode(chilled_water_loop.supplyOutletNode)

    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.setName("#{chilled_water_loop.name} Demand Inlet")
    demand_inlet_pipe.addToNode(chilled_water_loop.demandInletNode)

    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.setName("#{chilled_water_loop.name} Demand Outlet")
    demand_outlet_pipe.addToNode(chilled_water_loop.demandOutletNode)

    return chilled_water_loop
  end

  # Creates a condenser water loop and adds it to the model.
  #
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param cooling_tower_type [String] valid choices are Open Cooling Tower, Closed Cooling Tower
  # @param cooling_tower_fan_type [String] valid choices are Centrifugal, "Propeller or Axial"
  # @param cooling_tower_capacity_control [String] valid choices are Fluid Bypass, Fan Cycling, TwoSpeed Fan, Variable Speed Fan
  # @param number_of_cells_per_tower [Integer] the number of discrete cells per tower
  # @param number_cooling_towers [Integer] the number of cooling towers to be added (in parallel)
  # @param sup_wtr_temp [Double] supply water temperature in degrees Fahrenheit, default 70F
  # @param dsgn_sup_wtr_temp [Double] design supply water temperature in degrees Fahrenheit, default 85F
  # @param dsgn_sup_wtr_temp_delt [Double] design water range temperature in degrees Rankine, default 10R
  # @param wet_bulb_approach [Double] design wet bulb approach temperature, default 7R
  # @param pump_spd_ctrl [String] pump speed control type, Constant or Variable (default)
  # @param pump_tot_hd [Double] pump head in ft H2O
  # @return [OpenStudio::Model::PlantLoop] the resulting condenser water plant loop
  def model_add_cw_loop(model,
                        system_name: 'Condenser Water Loop',
                        cooling_tower_type: 'Open Cooling Tower',
                        cooling_tower_fan_type: 'Propeller or Axial',
                        cooling_tower_capacity_control: 'TwoSpeed Fan',
                        number_of_cells_per_tower: 1,
                        number_cooling_towers: 1,
                        sup_wtr_temp: 70.0,
                        dsgn_sup_wtr_temp: 85.0,
                        dsgn_sup_wtr_temp_delt: 10.0,
                        wet_bulb_approach: 7.0,
                        pump_spd_ctrl: 'Constant',
                        pump_tot_hd: 49.7)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding condenser water loop.')

    # create condenser water loop
    condenser_water_loop = OpenStudio::Model::PlantLoop.new(model)
    if system_name.nil?
      condenser_water_loop.setName('Condenser Water Loop')
    else
      condenser_water_loop.setName(system_name)
    end

    # condenser water loop sizing and controls
    if sup_wtr_temp.nil?
      sup_wtr_temp = 70.0
      sup_wtr_temp_c = OpenStudio.convert(sup_wtr_temp, 'F', 'C').get
    else
      sup_wtr_temp_c = OpenStudio.convert(sup_wtr_temp, 'F', 'C').get
    end
    if dsgn_sup_wtr_temp.nil?
      dsgn_sup_wtr_temp = 85.0
      dsgn_sup_wtr_temp_c = OpenStudio.convert(dsgn_sup_wtr_temp, 'F', 'C').get
    else
      dsgn_sup_wtr_temp_c = OpenStudio.convert(dsgn_sup_wtr_temp, 'F', 'C').get
    end
    if dsgn_sup_wtr_temp_delt.nil?
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(10.0, 'R', 'K').get
    else
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(dsgn_sup_wtr_temp_delt, 'R', 'K').get
    end
    if wet_bulb_approach.nil?
      wet_bulb_approach_k = OpenStudio.convert(7.0, 'R', 'K').get
    else
      wet_bulb_approach_k = OpenStudio.convert(wet_bulb_approach, 'R', 'K').get
    end
    condenser_water_loop.setMinimumLoopTemperature(5.0)
    condenser_water_loop.setMaximumLoopTemperature(80.0)
    sizing_plant = condenser_water_loop.sizingPlant
    sizing_plant.setLoopType('Condenser')
    sizing_plant.setDesignLoopExitTemperature(dsgn_sup_wtr_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(dsgn_sup_wtr_temp_delt_k)

    # follow outdoor air wetbulb with given approach temperature
    cw_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
    cw_stpt_manager.setName("#{condenser_water_loop.name} Setpoint Manager Follow OATwb with #{wet_bulb_approach}F Approach")
    cw_stpt_manager.setReferenceTemperatureType('OutdoorAirWetBulb')
    cw_stpt_manager.setMaximumSetpointTemperature(dsgn_sup_wtr_temp_c)
    cw_stpt_manager.setMinimumSetpointTemperature(sup_wtr_temp_c)
    cw_stpt_manager.setOffsetTemperatureDifference(wet_bulb_approach_k)
    cw_stpt_manager.addToNode(condenser_water_loop.supplyOutletNode)

    # create condenser water pump
    case pump_spd_ctrl
    when 'Constant'
      cw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    when 'Variable'
      cw_pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    when 'HeaderedVariable'
      cw_pump = OpenStudio::Model::HeaderedPumpsVariableSpeed.new(model)
      cw_pump.setNumberofPumpsinBank(2)
    when 'HeaderedConstant'
      cw_pump = OpenStudio::Model::HeaderedPumpsConstantSpeed.new(model)
      cw_pump.setNumberofPumpsinBank(2)
    else
      cw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    end
    cw_pump.setName("#{condenser_water_loop.name} #{pump_spd_ctrl} Pump")
    cw_pump.setPumpControlType('Intermittent')

    if pump_tot_hd.nil?
      pump_tot_hd_pa =  OpenStudio.convert(49.7, 'ftH_{2}O', 'Pa').get
    else
      pump_tot_hd_pa =  OpenStudio.convert(pump_tot_hd, 'ftH_{2}O', 'Pa').get
    end
    cw_pump.setRatedPumpHead(pump_tot_hd_pa)
    cw_pump.addToNode(condenser_water_loop.supplyInletNode)

    # Cooling towers
    # Per PNNL PRM Reference Manual
    number_cooling_towers.times do |_i|
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
        cooling_tower.setDesignRangeTemperature(dsgn_sup_wtr_temp_delt_k)
        cooling_tower.setDesignApproachTemperature(wet_bulb_approach_k)
        cooling_tower.setFractionofTowerCapacityinFreeConvectionRegime(0.125)
        twr_fan_curve = model_add_curve(model, 'VSD-TWR-FAN-FPLR')
        cooling_tower.setFanPowerRatioFunctionofAirFlowRateRatioCurve(twr_fan_curve)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "#{cooling_tower_capacity_control} is not a valid choice of cooling tower capacity control.  Valid choices are Fluid Bypass, Fan Cycling, TwoSpeed Fan, Variable Speed Fan.")
      end

      # Set the properties that apply to all tower types and attach to the condenser loop.
      unless cooling_tower.nil?
        cooling_tower.setName("#{cooling_tower_fan_type} #{cooling_tower_capacity_control} #{cooling_tower_type}")
        cooling_tower.setSizingFactor(1 / number_cooling_towers)
        cooling_tower.setNumberofCells(number_of_cells_per_tower)
        condenser_water_loop.addSupplyBranchForComponent(cooling_tower)
      end
    end

    # Condenser water loop pipes
    cooling_tower_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    cooling_tower_bypass_pipe.setName("#{condenser_water_loop.name} Cooling Tower Bypass")
    condenser_water_loop.addSupplyBranchForComponent(cooling_tower_bypass_pipe)

    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    chiller_bypass_pipe.setName("#{condenser_water_loop.name} Chiller Bypass")
    condenser_water_loop.addDemandBranchForComponent(chiller_bypass_pipe)

    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.setName("#{condenser_water_loop.name} Supply Outlet")
    supply_outlet_pipe.addToNode(condenser_water_loop.supplyOutletNode)

    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.setName("#{condenser_water_loop.name} Demand Inlet")
    demand_inlet_pipe.addToNode(condenser_water_loop.demandInletNode)

    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.setName("#{condenser_water_loop.name} Demand Outlet")
    demand_outlet_pipe.addToNode(condenser_water_loop.demandOutletNode)

    return condenser_water_loop
  end

  # Creates a heat pump loop which has a boiler and fluid cooler for supplemental heating/cooling and adds it to the model.
  #
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param sup_wtr_high_temp [Double] target supply water temperature to enable cooling in degrees Fahrenheit, default 65.0F
  # @param sup_wtr_low_temp [Double] target supply water temperature to enable heating in degrees Fahrenheit, default 41.0F
  # @param dsgn_sup_wtr_temp [Double] design supply water temperature in degrees Fahrenheit, default 102.2F
  # @param dsgn_sup_wtr_temp_delt [Double] design supply-return water temperature difference in degrees Rankine, default 19.8R
  # @return [OpenStudio::Model::PlantLoop] the resulting plant loop
  # TODO: replace cooling tower with fluid cooler after fixing sizing inputs
  def model_add_hp_loop(model,
                        system_name: 'Heat Pump Loop',
                        sup_wtr_high_temp: 65.0,
                        sup_wtr_low_temp: 41.0,
                        dsgn_sup_wtr_temp: 102.2,
                        dsgn_sup_wtr_temp_delt: 19.8)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding heat pump loop.')

    # create heat pump loop
    heat_pump_water_loop = OpenStudio::Model::PlantLoop.new(model)
    if system_name.nil?
      heat_pump_water_loop.setName('Heat Pump Loop')
    else
      heat_pump_water_loop.setName(system_name)
    end

    # hot water loop sizing and controls
    if sup_wtr_high_temp.nil?
      sup_wtr_high_temp = 65.0
      sup_wtr_high_temp_c = OpenStudio.convert(sup_wtr_high_temp, 'F', 'C').get
    else
      sup_wtr_high_temp_c = OpenStudio.convert(sup_wtr_high_temp, 'F', 'C').get
    end
    if sup_wtr_low_temp.nil?
      sup_wtr_low_temp = 41.0
      sup_wtr_low_temp_c = OpenStudio.convert(sup_wtr_low_temp, 'F', 'C').get
    else
      sup_wtr_low_temp_c = OpenStudio.convert(sup_wtr_low_temp, 'F', 'C').get
    end
    if dsgn_sup_wtr_temp.nil?
      dsgn_sup_wtr_temp_c = OpenStudio.convert(102.2, 'F', 'C').get
    else
      dsgn_sup_wtr_temp_c = OpenStudio.convert(dsgn_sup_wtr_temp, 'F', 'C').get
    end
    if dsgn_sup_wtr_temp_delt.nil?
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(19.8, 'R', 'K').get
    else
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(dsgn_sup_wtr_temp_delt, 'R', 'K').get
    end
    sizing_plant = heat_pump_water_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    heat_pump_water_loop.setMinimumLoopTemperature(5.0)
    heat_pump_water_loop.setMaximumLoopTemperature(80.0)
    sizing_plant.setDesignLoopExitTemperature(dsgn_sup_wtr_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(dsgn_sup_wtr_temp_delt_k)
    hp_high_temp_sch = model_add_constant_schedule_ruleset(model,
                                                           sup_wtr_high_temp_c,
                                                           name = "#{heat_pump_water_loop.name} High Temp - #{sup_wtr_high_temp.round(0)}F")
    hp_low_temp_sch = model_add_constant_schedule_ruleset(model,
                                                          sup_wtr_low_temp_c,
                                                          name = "#{heat_pump_water_loop.name} Low Temp - #{sup_wtr_low_temp.round(0)}F")
    hp_stpt_manager = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(model)
    hp_stpt_manager.setName("#{heat_pump_water_loop.name} Scheduled Dual Setpoint")
    hp_stpt_manager.setHighSetpointSchedule(hp_high_temp_sch)
    hp_stpt_manager.setLowSetpointSchedule(hp_low_temp_sch)
    hp_stpt_manager.addToNode(heat_pump_water_loop.supplyOutletNode)

    # create pump
    hp_pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    hp_pump.setName("#{heat_pump_water_loop.name} Pump")
    hp_pump.setRatedPumpHead(OpenStudio.convert(60.0, 'ftH_{2}O', 'Pa').get)
    hp_pump.setPumpControlType('Intermittent')
    hp_pump.addToNode(heat_pump_water_loop.supplyInletNode)

    # create cooling towers or fluid coolers
    # TODO: replace this system with a FluidCoolor:TwoSpeed once the simulation failures are resolved
    # This logic is overridden Prototype.LargeOffice.rb to use a CoolingTowerTwoSpeed object instead change this
    # cooling_tower = OpenStudio::Model::CoolingTowerTwoSpeed.new(self)
    # cooling_tower.setName("#{heat_pump_water_loop.name} Sup Cooling Tower")
    # heat_pump_water_loop.addSupplyBranchForComponent(cooling_tower)
    fluid_cooler = OpenStudio::Model::EvaporativeFluidCoolerSingleSpeed.new(model)
    fluid_cooler.setName("#{heat_pump_water_loop.name} Fluid Cooler")
    fluid_cooler.setDesignSprayWaterFlowRate(0.002208) # Based on HighRiseApartment
    fluid_cooler.setPerformanceInputMethod('UFactorTimesAreaAndDesignWaterFlowRate')
    heat_pump_water_loop.addSupplyBranchForComponent(fluid_cooler)

    # create boiler
    boiler = create_boiler_hot_water(model,
                                     hot_water_loop: heat_pump_water_loop,
                                     name: "#{heat_pump_water_loop.name} Supplemental Boiler",
                                     fuel_type: 'NaturalGas',
                                     flow_mode: 'ConstantFlow',
                                     lvg_temp_dsgn: 86.0,
                                     min_plr: 0.0,
                                     max_plr: 1.2,
                                     opt_plr: 1.0)
    # add setpoint manager schedule to boiler outlet so correct plant operation scheme is generated
    boiler_stpt_manager = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(model)
    boiler_stpt_manager.setName("#{heat_pump_water_loop.name} Boiler Scheduled Dual Setpoint")
    boiler_stpt_manager.setHighSetpointSchedule(hp_high_temp_sch)
    boiler_stpt_manager.setLowSetpointSchedule(hp_low_temp_sch)
    boiler_stpt_manager.addToNode(boiler.outletModelObject.get.to_Node.get)

    # add heat pump water loop pipes
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

  # Creates loop that roughly mimics a properly sized ground heat exchanger for supplemental heating/cooling and adds it to the model.
  #
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @return [OpenStudio::Model::PlantLoop] the resulting plant loop
  # TODO: replace condenser loop w/ ground HX model that does not involve district objects
  def model_add_ground_hx_loop(model,
                               system_name: 'Ground HX Loop')
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding ground source loop.')

    # create ground hx loop
    ground_hx_loop = OpenStudio::Model::PlantLoop.new(model)
    if system_name.nil?
      ground_hx_loop.setName('Ground HX Loop')
    else
      ground_hx_loop.setName(system_name)
    end

    # ground hx loop sizing and controls
    ground_hx_loop.setMinimumLoopTemperature(5.0)
    ground_hx_loop.setMaximumLoopTemperature(80.0)
    delta_t_k = OpenStudio.convert(12.0, 'R', 'K').get # temp change at high and low entering condition
    min_inlet_c = OpenStudio.convert(30.0, 'F', 'C').get # low entering condition.
    max_inlet_c = OpenStudio.convert(90.0, 'F', 'C').get # high entering condition

    # calculate the linear formula that defines outlet temperature based on inlet temperature of the ground hx
    min_outlet_c = min_inlet_c + delta_t_k
    max_outlet_c = max_inlet_c - delta_t_k
    slope_c_per_c = (max_outlet_c - min_outlet_c) / (max_inlet_c - min_inlet_c)
    intercept_c = min_outlet_c - (slope_c_per_c * min_inlet_c)

    sizing_plant = ground_hx_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(max_outlet_c)
    sizing_plant.setLoopDesignTemperatureDifference(delta_t_k)

    # create pump
    pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    pump.setName("#{ground_hx_loop.name} Pump")
    pump.setRatedPumpHead(OpenStudio.convert(60.0, 'ftH_{2}O', 'Pa').get)
    pump.setPumpControlType('Intermittent')
    pump.addToNode(ground_hx_loop.supplyInletNode)

    # use EMS and a PlantComponentTemperatureSource to mimic the operation of the ground heat exchanger.

    # schedule to actuate ground HX outlet temperature
    hx_temp_sch = OpenStudio::Model::ScheduleConstant.new(model)
    hx_temp_sch.setName('Ground HX Temp Sch')
    hx_temp_sch.setValue(24.0)

    ground_hx = OpenStudio::Model::PlantComponentTemperatureSource.new(model)
    ground_hx.setName('Ground HX')
    ground_hx.setTemperatureSpecificationType('Scheduled')
    ground_hx.setSourceTemperatureSchedule(hx_temp_sch)
    ground_hx_loop.addSupplyBranchForComponent(ground_hx)

    hx_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, hx_temp_sch)
    hx_stpt_manager.setName("#{ground_hx.name} Supply Outlet Setpoint")
    hx_stpt_manager.addToNode(ground_hx.outletModelObject.get.to_Node.get)

    loop_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, hx_temp_sch)
    loop_stpt_manager.setName("#{ground_hx_loop.name} Supply Outlet Setpoint")
    loop_stpt_manager.addToNode(ground_hx_loop.supplyOutletNode)

    # sensor to read supply inlet temperature
    inlet_temp_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,
                                                                            'System Node Temperature')
    inlet_temp_sensor.setName("#{ground_hx.name.to_s.gsub(/[ +-.]/,'_')} Inlet Temp Sensor")
    inlet_temp_sensor.setKeyName(ground_hx_loop.supplyInletNode.handle.to_s)

    # actuator to set supply outlet temperature
    outlet_temp_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(hx_temp_sch,
                                                                                 'Schedule:Constant',
                                                                                 'Schedule Value')
    outlet_temp_actuator.setName("#{ground_hx.name} Outlet Temp Actuator")

    # program to control outlet temperature
    # adjusts delta-t based on calculation of slope and intercept from control temperatures
    program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    program.setName("#{ground_hx.name.to_s.gsub(/[ +-.]/,'_')} Temperature Control")
    program_body = <<-EMS
      SET Tin = #{inlet_temp_sensor.handle}
      SET Tout = #{slope_c_per_c.round(2)} * Tin + #{intercept_c.round(1)}
      SET #{outlet_temp_actuator.handle} = Tout
    EMS
    program.setBody(program_body)

    # program calling manager
    pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    pcm.setName("#{program.name.to_s.gsub(/[ +-.]/,'_')} Calling Manager")
    pcm.setCallingPoint('InsideHVACSystemIterationLoop')
    pcm.addProgram(program)

    return ground_hx_loop
  end

  # Adds an ambient condenser water loop that will be used in a district to connect buildings as a shared sink/source for heat pumps.
  #
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @return [OpenStudio::Model::PlantLoop] the ambient loop
  # TODO: add inputs for design temperatures like heat pump loop object
  # TODO: handle ground and heat pump with this; make heating/cooling source options (boiler, fluid cooler, district)
  def model_add_district_ambient_loop(model,
                                      system_name: 'Ambient Loop')
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding district ambient loop.')

    # create ambient loop
    ambient_loop = OpenStudio::Model::PlantLoop.new(model)
    if system_name.nil?
      ambient_loop.setName('Ambient Loop')
    else
      ambient_loop.setName(system_name)
    end

    # ambient loop sizing and controls
    ambient_loop.setMinimumLoopTemperature(5.0)
    ambient_loop.setMaximumLoopTemperature(80.0)

    amb_high_temp_f = 90 # Supplemental cooling below 65F
    amb_low_temp_f = 41 # Supplemental heat below 41F
    amb_temp_sizing_f = 102.2 # CW sized to deliver 102.2F
    amb_delta_t_r = 19.8 # 19.8F delta-T
    amb_high_temp_c = OpenStudio.convert(amb_high_temp_f, 'F', 'C').get
    amb_low_temp_c = OpenStudio.convert(amb_low_temp_f, 'F', 'C').get
    amb_temp_sizing_c = OpenStudio.convert(amb_temp_sizing_f, 'F', 'C').get
    amb_delta_t_k = OpenStudio.convert(amb_delta_t_r, 'R', 'K').get

    amb_high_temp_sch = model_add_constant_schedule_ruleset(model,
                                                            amb_high_temp_c,
                                                            name = "Ambient Loop High Temp - #{amb_high_temp_f}F")

    amb_low_temp_sch = model_add_constant_schedule_ruleset(model,
                                                           amb_low_temp_c,
                                                           name = "Ambient Loop Low Temp - #{amb_low_temp_f}F")

    amb_stpt_manager = OpenStudio::Model::SetpointManagerScheduledDualSetpoint.new(model)
    amb_stpt_manager.setName("#{ambient_loop.name} Supply Water Setpoint Manager")
    amb_stpt_manager.setHighSetpointSchedule(amb_high_temp_sch)
    amb_stpt_manager.setLowSetpointSchedule(amb_low_temp_sch)
    amb_stpt_manager.addToNode(ambient_loop.supplyOutletNode)

    sizing_plant = ambient_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(amb_temp_sizing_c)
    sizing_plant.setLoopDesignTemperatureDifference(amb_delta_t_k)

    # create pump
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    pump.setName("#{ambient_loop.name} Pump")
    pump.setRatedPumpHead(OpenStudio.convert(60.0, 'ftH_{2}O', 'Pa').get)
    pump.setPumpControlType('Intermittent')
    pump.addToNode(ambient_loop.supplyInletNode)

    # cooling
    district_cooling = OpenStudio::Model::DistrictCooling.new(model)
    district_cooling.setNominalCapacity(1_000_000_000_000) # large number; no autosizing
    ambient_loop.addSupplyBranchForComponent(district_cooling)

    # heating
    district_heating = OpenStudio::Model::DistrictHeating.new(model)
    district_heating.setNominalCapacity(1_000_000_000_000) # large number; no autosizing
    ambient_loop.addSupplyBranchForComponent(district_heating)

    # add ambient water loop pipes
    supply_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_bypass_pipe.setName("#{ambient_loop.name} Supply Bypass")
    ambient_loop.addSupplyBranchForComponent(supply_bypass_pipe)

    demand_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_bypass_pipe.setName("#{ambient_loop.name} Demand Bypass")
    ambient_loop.addDemandBranchForComponent(demand_bypass_pipe)

    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    supply_outlet_pipe.setName("#{ambient_loop.name} Supply Outlet")
    supply_outlet_pipe.addToNode(ambient_loop.supplyOutletNode)

    demand_inlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_inlet_pipe.setName("#{ambient_loop.name} Demand Inlet")
    demand_inlet_pipe.addToNode(ambient_loop.demandInletNode)

    demand_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)
    demand_outlet_pipe.setName("#{ambient_loop.name} Demand Outlet")
    demand_outlet_pipe.addToNode(ambient_loop.demandOutletNode)

    return ambient_loop
  end

  # Creates a DOAS system with cold supply and terminal units for each zone.
  # This is the default DOAS system for DOE prototype buildings. Use model_add_doas for other DOAS systems.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] hot water loop to connect to heating and zone fan coils
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] chilled water loop to connect to cooling coil
  # @param hvac_op_sch [String] name of the HVAC operation schedule, default is always on
  # @param min_oa_sch [String] name of the minimum outdoor air schedule, default is always on
  # @param min_frac_oa_sch [String] name of the minimum fraction of outdoor air schedule, default is always on
  # @param fan_maximum_flow_rate [Double] fan maximum flow rate in cfm, default is autosize
  # @param econo_ctrl_mthd [String] economizer control type, default is Fixed Dry Bulb
  # @param energy_recovery [Bool] if true, an ERV will be added to the system
  # @param doas_control_strategy [String] DOAS control strategy
  # @param clg_dsgn_sup_air_temp [Double] design cooling supply air temperature in degrees Fahrenheit, default 65F
  # @param htg_dsgn_sup_air_temp [Double] design heating supply air temperature in degrees Fahrenheit, default 75F
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting DOAS air loop
  def model_add_doas_cold_supply(model,
                                 thermal_zones,
                                 system_name: nil,
                                 hot_water_loop: nil,
                                 chilled_water_loop: nil,
                                 hvac_op_sch: nil,
                                 min_oa_sch: nil,
                                 min_frac_oa_sch: nil,
                                 fan_maximum_flow_rate: nil,
                                 econo_ctrl_mthd: 'FixedDryBulb',
                                 energy_recovery: false,
                                 doas_control_strategy: 'NeutralSupplyAir',
                                 clg_dsgn_sup_air_temp: 55.0,
                                 htg_dsgn_sup_air_temp: 60.0)

    # Check the total OA requirement for all zones on the system
    tot_oa_req = 0
    thermal_zones.each do |zone|
      tot_oa_req += thermal_zone_outdoor_airflow_rate(zone)
      break if tot_oa_req > 0
    end

    # If the total OA requirement is zero do not add the DOAS system because the simulations will fail
    if tot_oa_req.zero?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Not adding DOAS system for #{thermal_zones.size} zones because combined OA requirement for all zones is zero.")
      return false
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding DOAS system for #{thermal_zones.size} zones.")

    # create a DOAS air loop
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if system_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone DOAS")
    else
      air_loop.setName(system_name)
    end

    # set availability schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # DOAS design temperatures
    if clg_dsgn_sup_air_temp.nil?
      clg_dsgn_sup_air_temp_c = OpenStudio.convert(55.0, 'F', 'C').get
    else
      clg_dsgn_sup_air_temp_c = OpenStudio.convert(clg_dsgn_sup_air_temp, 'F', 'C').get
    end

    if htg_dsgn_sup_air_temp.nil?
      htg_dsgn_sup_air_temp_c = OpenStudio.convert(60.0, 'F', 'C').get
    else
      htg_dsgn_sup_air_temp_c = OpenStudio.convert(htg_dsgn_sup_air_temp, 'F', 'C').get
    end

    # modify system sizing properties
    sizing_system = air_loop.sizingSystem
    sizing_system.setTypeofLoadtoSizeOn('VentilationRequirement')
    sizing_system.setAllOutdoorAirinCooling(true)
    sizing_system.setAllOutdoorAirinHeating(true)
    # set minimum airflow ratio to 1.0 to avoid under-sizing heating coil
    sizing_system.setMinimumSystemAirFlowRatio(1.0)
    sizing_system.setSizingOption('Coincident')
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_dsgn_sup_air_temp_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_dsgn_sup_air_temp_c)

    # create supply fan
    supply_fan = create_fan_by_name(model,
                                    'Constant_DOAS_Fan',
                                    fan_name: 'DOAS Supply Fan',
                                    end_use_subcategory: 'DOAS Fans')
    supply_fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    supply_fan.setMaximumFlowRate(OpenStudio.convert(fan_maximum_flow_rate, 'cfm', 'm^3/s').get) unless fan_maximum_flow_rate.nil?
    supply_fan.addToNode(air_loop.supplyInletNode)

    # create heating coil
    if hot_water_loop.nil?
      # electric backup heating coil
      create_coil_heating_electric(model,
                                   air_loop_node: air_loop.supplyInletNode,
                                   name: "#{air_loop.name} Backup Htg Coil")
      # heat pump coil
      create_coil_heating_dx_single_speed(model,
                                          air_loop_node: air_loop.supplyInletNode,
                                          name: "#{air_loop.name} Htg Coil")
    else
      create_coil_heating_water(model,
                                hot_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Htg Coil",
                                controller_convergence_tolerance: 0.0001)
    end

    # create cooling coil
    if chilled_water_loop.nil?
      create_coil_cooling_dx_two_speed(model,
                                       air_loop_node: air_loop.supplyInletNode,
                                       name: "#{air_loop.name} 2spd DX Clg Coil",
                                       type: 'OS default')
    else
      create_coil_cooling_water(model,
                                chilled_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Clg Coil")
    end

    # minimum outdoor air schedule
    if min_oa_sch.nil?
      min_oa_sch = model.alwaysOnDiscreteSchedule
    else
      min_oa_sch = model_add_schedule(model, min_oa_sch)
    end

    # minimum outdoor air fraction schedule
    if min_frac_oa_sch.nil?
      min_frac_oa_sch = model.alwaysOnDiscreteSchedule
    else
      min_frac_oa_sch = model_add_schedule(model, min_frac_oa_sch)
    end

    # create controller outdoor air
    controller_oa = OpenStudio::Model::ControllerOutdoorAir.new(model)
    controller_oa.setName("#{air_loop.name} OA Controller")
    controller_oa.setEconomizerControlType(econo_ctrl_mthd)
    controller_oa.setMinimumLimitType('FixedMinimum')
    controller_oa.autosizeMinimumOutdoorAirFlowRate
    controller_oa.setMinimumOutdoorAirSchedule(min_oa_sch)
    controller_oa.setMinimumFractionofOutdoorAirSchedule(min_frac_oa_sch)
    controller_oa.resetEconomizerMaximumLimitDryBulbTemperature
    controller_oa.resetEconomizerMaximumLimitEnthalpy
    controller_oa.resetMaximumFractionofOutdoorAirSchedule
    controller_oa.resetEconomizerMinimumLimitDryBulbTemperature
    controller_oa.setHeatRecoveryBypassControlType('BypassWhenWithinEconomizerLimits')

    # create outdoor air system
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, controller_oa)
    oa_system.setName("#{air_loop.name} OA System")
    oa_system.addToNode(air_loop.supplyInletNode)

    # create a setpoint manager
    sat_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
    sat_oa_reset.setName("#{air_loop.name} SAT Reset")
    sat_oa_reset.setControlVariable('Temperature')
    sat_oa_reset.setSetpointatOutdoorLowTemperature(htg_dsgn_sup_air_temp_c)
    sat_oa_reset.setOutdoorLowTemperature(OpenStudio.convert(60.0, 'F', 'C').get)
    sat_oa_reset.setSetpointatOutdoorHighTemperature(clg_dsgn_sup_air_temp_c)
    sat_oa_reset.setOutdoorHighTemperature(OpenStudio.convert(70.0, 'F', 'C').get)
    sat_oa_reset.addToNode(air_loop.supplyOutletNode)

    # set air loop availability controls and night cycle manager, after oa system added
    air_loop.setAvailabilitySchedule(hvac_op_sch)
    air_loop.setNightCycleControlType('CycleOnAny')

    # add energy recovery if requested
    if energy_recovery
      # Get the OA system and its outboard OA node
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get

      # create the ERV and set its properties
      erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
      erv.addToNode(oa_system.outboardOANode.get)
      erv.setHeatExchangerType('Rotary')
      # TODO: come up with scheme for estimating power of ERV motor wheel which might require knowing airflow.
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

      # increase fan static pressure to account for ERV
      erv_pressure_rise = OpenStudio.convert(1.0, 'inH_{2}O', 'Pa').get
      new_pressure_rise = supply_fan.pressureRise + erv_pressure_rise
      supply_fan.setPressureRise(new_pressure_rise)
    end

    # add thermal zones to airloop
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---adding #{zone.name} to #{air_loop.name}")

      # make an air terminal for the zone
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      air_terminal.setName("#{zone.name} Air Terminal")

      # attach new terminal to the zone and to the airloop
      air_loop.addBranchForZone(zone, air_terminal.to_StraightComponent)

      # DOAS sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setAccountforDedicatedOutdoorAirSystem(true)
      sizing_zone.setDedicatedOutdoorAirSystemControlStrategy('ColdSupplyAir')
      sizing_zone.setDedicatedOutdoorAirLowSetpointTemperatureforDesign(clg_dsgn_sup_air_temp_c)
      sizing_zone.setDedicatedOutdoorAirHighSetpointTemperatureforDesign(htg_dsgn_sup_air_temp_c)
    end

    return air_loop
  end

  # Creates a DOAS system with terminal units for each zone.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param doas_type [String] DOASCV or DOASVAV, determines whether the DOAS is operated at scheduled,
  #   constant flow rate, or airflow is variable to allow for economizing or demand controlled ventilation
  # @param doas_control_strategy [String] DOAS control strategy
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] hot water loop to connect to heating and zone fan coils
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] chilled water loop to connect to cooling coil
  # @param hvac_op_sch [String] name of the HVAC operation schedule, default is always on
  # @param min_oa_sch [String] name of the minimum outdoor air schedule, default is always on
  # @param min_frac_oa_sch [String] name of the minimum fraction of outdoor air schedule, default is always on
  # @param fan_maximum_flow_rate [Double] fan maximum flow rate in cfm, default is autosize
  # @param econo_ctrl_mthd [String] economizer control type, default is Fixed Dry Bulb
  #   If enabled, the DOAS will be sized for twice the ventilation minimum to allow economizing
  # @param include_exhaust_fan [Bool] if true, include an exhaust fan
  # @param energy_recovery [Bool] if true, an ERV will be added to the system
  # @param clg_dsgn_sup_air_temp [Double] design cooling supply air temperature in degrees Fahrenheit, default 65F
  # @param htg_dsgn_sup_air_temp [Double] design heating supply air temperature in degrees Fahrenheit, default 75F
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting DOAS air loop
  def model_add_doas(model,
                     thermal_zones,
                     system_name: nil,
                     doas_type: 'DOASCV',
                     hot_water_loop: nil,
                     chilled_water_loop: nil,
                     hvac_op_sch: nil,
                     min_oa_sch: nil,
                     min_frac_oa_sch: nil,
                     fan_maximum_flow_rate: nil,
                     econo_ctrl_mthd: 'NoEconomizer',
                     include_exhaust_fan: true,
                     energy_recovery: true,
                     demand_control_ventilation: false,
                     doas_control_strategy: 'NeutralSupplyAir',
                     clg_dsgn_sup_air_temp: 60.0,
                     htg_dsgn_sup_air_temp: 70.0)

    # Check the total OA requirement for all zones on the system
    tot_oa_req = 0
    thermal_zones.each do |zone|
      tot_oa_req += thermal_zone_outdoor_airflow_rate(zone)
    end

    # If the total OA requirement is zero do not add the DOAS system because the simulations will fail
    if tot_oa_req.zero?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Not adding DOAS system for #{thermal_zones.size} zones because combined OA requirement for all zones is zero.")
      return false
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding DOAS system for #{thermal_zones.size} zones.")

    # create a DOAS air loop
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if system_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone DOAS")
    else
      air_loop.setName(system_name)
    end

    # set availability schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # DOAS design temperatures
    if clg_dsgn_sup_air_temp.nil?
      clg_dsgn_sup_air_temp_c = OpenStudio.convert(60.0, 'F', 'C').get
    else
      clg_dsgn_sup_air_temp_c = OpenStudio.convert(clg_dsgn_sup_air_temp, 'F', 'C').get
    end

    if htg_dsgn_sup_air_temp.nil?
      htg_dsgn_sup_air_temp_c = OpenStudio.convert(70.0, 'F', 'C').get
    else
      htg_dsgn_sup_air_temp_c = OpenStudio.convert(htg_dsgn_sup_air_temp, 'F', 'C').get
    end

    # modify system sizing properties
    sizing_system = air_loop.sizingSystem
    sizing_system.setTypeofLoadtoSizeOn('VentilationRequirement')
    sizing_system.setAllOutdoorAirinCooling(true)
    sizing_system.setAllOutdoorAirinHeating(true)
    # set minimum airflow ratio to 1.0 to avoid under-sizing heating coil
    sizing_system.setMinimumSystemAirFlowRatio(1.0)
    sizing_system.setSizingOption('Coincident')
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(clg_dsgn_sup_air_temp_c)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(htg_dsgn_sup_air_temp_c)

    if doas_type == 'DOASCV'
      supply_fan = create_fan_by_name(model,
                                      'Constant_DOAS_Fan',
                                      fan_name: 'DOAS Supply Fan',
                                      end_use_subcategory: 'DOAS Fans')
    else # 'DOASVAV'
      supply_fan = create_fan_by_name(model,
                                      'Variable_DOAS_Fan',
                                      fan_name: 'DOAS Supply Fan',
                                      end_use_subcategory: 'DOAS Fans')
    end
    supply_fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    supply_fan.setMaximumFlowRate(OpenStudio.convert(fan_maximum_flow_rate, 'cfm', 'm^3/s').get) unless fan_maximum_flow_rate.nil?
    supply_fan.addToNode(air_loop.supplyInletNode)

    # create heating coil
    if hot_water_loop.nil?
      # electric backup heating coil
      create_coil_heating_electric(model,
                                   air_loop_node: air_loop.supplyInletNode,
                                   name: "#{air_loop.name} Backup Htg Coil")
      # heat pump coil
      create_coil_heating_dx_single_speed(model,
                                          air_loop_node: air_loop.supplyInletNode,
                                          name: "#{air_loop.name} Htg Coil")
    else
      create_coil_heating_water(model,
                                hot_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Htg Coil",
                                controller_convergence_tolerance: 0.0001)
    end

    # could add a humidity controller here set to limit supply air to a 16.6C/62F dewpoint
    # the default outdoor air reset to 60F prevents exceeding this dewpoint in all ASHRAE climate zones
    # the humidity controller needs a DX coil that can control humidity, e.g. CoilCoolingDXTwoStageWithHumidityControlMode
    # max_humidity_ratio_sch = model_add_constant_schedule_ruleset(model,
    #                                                              0.012,
    #                                                              name = "0.012 Humidity Ratio Schedule",
    #                                                              sch_type_limit: "Humidity Ratio")
    # sat_oa_reset = OpenStudio::Model::SetpointManagerScheduled.new(model, max_humidity_ratio_sch)
    # sat_oa_reset.setName("#{air_loop.name.to_s} Humidity Controller")
    # sat_oa_reset.setControlVariable('MaximumHumidityRatio')
    # sat_oa_reset.addToNode(air_loop.supplyInletNode)

    # create cooling coil
    if chilled_water_loop.nil?
      create_coil_cooling_dx_two_speed(model,
                                       air_loop_node: air_loop.supplyInletNode,
                                       name: "#{air_loop.name} 2spd DX Clg Coil",
                                       type: 'OS default')
    else
      create_coil_cooling_water(model,
                                chilled_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Clg Coil")
    end

    # minimum outdoor air schedule
    unless min_oa_sch.nil?
      min_oa_sch = model_add_schedule(model, min_oa_sch)
    end

    # minimum outdoor air fraction schedule
    if min_frac_oa_sch.nil?
      min_frac_oa_sch = model.alwaysOnDiscreteSchedule
    else
      min_frac_oa_sch = model_add_schedule(model, min_frac_oa_sch)
    end

    # create controller outdoor air
    controller_oa = OpenStudio::Model::ControllerOutdoorAir.new(model)
    controller_oa.setName("#{air_loop.name} Outdoor Air Controller")
    controller_oa.setEconomizerControlType(econo_ctrl_mthd)
    controller_oa.setMinimumLimitType('FixedMinimum')
    controller_oa.autosizeMinimumOutdoorAirFlowRate
    controller_oa.setMinimumOutdoorAirSchedule(min_oa_sch) unless min_oa_sch.nil?
    controller_oa.setMinimumFractionofOutdoorAirSchedule(min_frac_oa_sch)
    controller_oa.resetEconomizerMinimumLimitDryBulbTemperature
    controller_oa.resetEconomizerMaximumLimitDryBulbTemperature
    controller_oa.resetEconomizerMaximumLimitEnthalpy
    controller_oa.resetMaximumFractionofOutdoorAirSchedule
    controller_oa.setHeatRecoveryBypassControlType('BypassWhenWithinEconomizerLimits')
    controller_mech_vent = controller_oa.controllerMechanicalVentilation
    controller_mech_vent.setName("#{air_loop.name} Mechanical Ventilation Controller")
    controller_mech_vent.setDemandControlledVentilation(true) if demand_control_ventilation
    controller_mech_vent.setSystemOutdoorAirMethod('ZoneSum')

    # create outdoor air system
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, controller_oa)
    oa_system.setName("#{air_loop.name} OA System")
    oa_system.addToNode(air_loop.supplyInletNode)

    # create an exhaust fan
    if include_exhaust_fan
      if doas_type == 'DOASCV'
        exhaust_fan = create_fan_by_name(model,
                                         'Constant_DOAS_Fan',
                                         fan_name: 'DOAS Exhaust Fan',
                                         end_use_subcategory: 'DOAS Fans')
      else # 'DOASVAV'
        exhaust_fan = create_fan_by_name(model,
                                         'Variable_DOAS_Fan',
                                         fan_name: 'DOAS Exhaust Fan',
                                         end_use_subcategory: 'DOAS Fans')
      end
      # set pressure rise 0.5 inH2O lower than supply fan, 0.5 inH2O minimum
      exhaust_fan_pressure_rise = supply_fan.pressureRise - OpenStudio.convert(0.5, 'inH_{2}O', 'Pa').get
      exhaust_fan_pressure_rise = OpenStudio.convert(0.5, 'inH_{2}O', 'Pa').get if exhaust_fan_pressure_rise < OpenStudio.convert(0.5, 'inH_{2}O', 'Pa').get
      exhaust_fan.setPressureRise(exhaust_fan_pressure_rise)
      exhaust_fan.addToNode(air_loop.supplyInletNode)
    end

    # create a setpoint manager
    sat_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
    sat_oa_reset.setName("#{air_loop.name} SAT Reset")
    sat_oa_reset.setControlVariable('Temperature')
    sat_oa_reset.setSetpointatOutdoorLowTemperature(htg_dsgn_sup_air_temp_c)
    sat_oa_reset.setOutdoorLowTemperature(OpenStudio.convert(60.0, 'F', 'C').get)
    sat_oa_reset.setSetpointatOutdoorHighTemperature(clg_dsgn_sup_air_temp_c)
    sat_oa_reset.setOutdoorHighTemperature(OpenStudio.convert(70.0, 'F', 'C').get)
    sat_oa_reset.addToNode(air_loop.supplyOutletNode)

    # set air loop availability controls and night cycle manager, after oa system added
    air_loop.setAvailabilitySchedule(hvac_op_sch)
    air_loop.setNightCycleControlType('CycleOnAnyZoneFansOnly')

    # add energy recovery if requested
    if energy_recovery
      # Get the OA system and its outboard OA node
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get

      # create the ERV and set its properties
      erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
      erv.setName("#{air_loop.name} Heat Exchanger")
      erv.addToNode(oa_system.outboardOANode.get)
      erv.setHeatExchangerType('Rotary')
      erv.setSupplyAirOutletTemperatureControl(false)
      erv.setSensibleEffectivenessat100HeatingAirFlow(0.76)
      erv.setSensibleEffectivenessat75HeatingAirFlow(0.81)
      erv.setLatentEffectivenessat100HeatingAirFlow(0.68)
      erv.setLatentEffectivenessat75HeatingAirFlow(0.73)
      erv.setSensibleEffectivenessat100CoolingAirFlow(0.76)
      erv.setSensibleEffectivenessat75CoolingAirFlow(0.81)
      erv.setLatentEffectivenessat100CoolingAirFlow(0.68)
      erv.setLatentEffectivenessat75CoolingAirFlow(0.73)
      erv.setEconomizerLockout(true)
      # TODO: estimate ERV motor power which might require knowing airflow (like prototype buildings do)
      # erv.setNominalElectricPower(value_new)
      # TODO: set erv defrost control

      # increase fan static pressure to account for ERV
      erv_pressure_rise = OpenStudio.convert(1.0, 'inH_{2}O', 'Pa').get
      supply_fan_new_pressure_rise = supply_fan.pressureRise + erv_pressure_rise
      supply_fan.setPressureRise(supply_fan_new_pressure_rise)
      if include_exhaust_fan
        exhaust_fan_new_pressure_rise = exhaust_fan.pressureRise + erv_pressure_rise
        supply_fan.setPressureRise(exhaust_fan_new_pressure_rise)
      end
    end

    # add thermal zones to airloop
    thermal_zones.each do |zone|
      # skip zones with no outdoor air flow rate
      unless thermal_zone_outdoor_airflow_rate(zone) > 0
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name} has no outdoor air flow rate and will not be added to #{air_loop.name}")
        next
      end

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---adding #{zone.name} to #{air_loop.name}")

      # make an air terminal for the zone
      if doas_type == 'DOASCV'
        air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      else # 'DOASVAV'
        air_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
        air_terminal.setZoneMinimumAirFlowInputMethod('Constant')
        air_terminal.setConstantMinimumAirFlowFraction(0.1)
        air_terminal.setControlForOutdoorAir(true) if demand_control_ventilation # may not be necessary
      end
      air_terminal.setName("#{zone.name} Air Terminal")

      # attach new terminal to the zone and to the airloop
      air_loop.addBranchForZone(zone, air_terminal.to_StraightComponent)

      # DOAS sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setAccountforDedicatedOutdoorAirSystem(true)
      sizing_zone.setDedicatedOutdoorAirSystemControlStrategy(doas_control_strategy)
      sizing_zone.setDedicatedOutdoorAirLowSetpointTemperatureforDesign(clg_dsgn_sup_air_temp_c)
      sizing_zone.setDedicatedOutdoorAirHighSetpointTemperatureforDesign(htg_dsgn_sup_air_temp_c)
    end

    return air_loop
  end

  # Creates a VAV system and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param return_plenum [OpenStudio::Model::ThermalZone] the zone to attach as the supply plenum, or nil, in which case no return plenum will be used
  # @param heating_type [String] main heating coil fuel type
  #   valid choices are NaturalGas, Gas, Electricity, HeatPump, DistrictHeating, or nil (defaults to NaturalGas)
  # @param reheat_type [String] valid options are NaturalGas, Gas, Electricity, Water, nil (no heat)
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] hot water loop to connect heating and reheat coils to
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] chilled water loop to connect cooling coil to
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param oa_damper_sch [String] name of the oa damper schedule, or nil in which case will be defaulted to always open
  # @param fan_efficiency [Double] fan total efficiency, including motor and impeller
  # @param fan_motor_efficiency [Double] fan motor efficiency
  # @param fan_pressure_rise [Double] fan pressure rise, inH2O
  # @param min_sys_airflow_ratio [Double] minimum system airflow ratio
  # @param vav_sizing_option [String] air system sizing option, Coincident or NonCoincident
  # @param econo_ctrl_mthd [String] economizer control type
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting VAV air loop
  def model_add_vav_reheat(model,
                           thermal_zones,
                           system_name: nil,
                           return_plenum: nil,
                           heating_type: nil,
                           reheat_type: nil,
                           hot_water_loop: nil,
                           chilled_water_loop: nil,
                           hvac_op_sch: nil,
                           oa_damper_sch: nil,
                           fan_efficiency: 0.62,
                           fan_motor_efficiency: 0.9,
                           fan_pressure_rise: 4.0,
                           min_sys_airflow_ratio: 0.3,
                           vav_sizing_option: 'Coincident',
                           econo_ctrl_mthd: nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding VAV system for #{thermal_zones.size} zones.")

    # create air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if system_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV")
    else
      air_loop.setName(system_name)
    end

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    unless oa_damper_sch.nil?
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # default design temperatures and settings used across all air loops
    dsgn_temps = standard_design_sizing_temperatures
    sizing_system = adjust_sizing_system(air_loop, dsgn_temps)
    sizing_system.setMinimumSystemAirFlowRatio(min_sys_airflow_ratio) unless min_sys_airflow_ratio.nil?
    sizing_system.setSizingOption(vav_sizing_option) unless vav_sizing_option.nil?
    unless hot_water_loop.nil?
      hw_temp_c = hot_water_loop.sizingPlant.designLoopExitTemperature
      hw_delta_t_k = hot_water_loop.sizingPlant.loopDesignTemperatureDifference
    end

    # air handler controls
    sa_temp_sch = model_add_constant_schedule_ruleset(model,
                                                      dsgn_temps['clg_dsgn_sup_air_temp_c'],
                                                      name = "Supply Air Temp - #{dsgn_temps['clg_dsgn_sup_air_temp_f']}F")
    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    sa_stpt_manager.setName("#{air_loop.name} Supply Air Setpoint Manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # create fan
    # @type [OpenStudio::Model::FanVariableVolume] fan
    fan = create_fan_by_name(model,
                             'VAV_System_Fan',
                             fan_name: "#{air_loop.name} Fan",
                             fan_efficiency: fan_efficiency,
                             pressure_rise: fan_pressure_rise,
                             motor_efficiency: fan_motor_efficiency,
                             end_use_subcategory: 'VAV System Fans')
    fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    fan.addToNode(air_loop.supplyInletNode)

    # create heating coil
    if hot_water_loop.nil?
      if heating_type == 'Electricity'
        create_coil_heating_electric(model,
                                     air_loop_node: air_loop.supplyInletNode,
                                     name: "#{air_loop.name} Main Electric Htg Coil")
      else # default to NaturalGas
        create_coil_heating_gas(model,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Main Gas Htg Coil")
      end
    else
      create_coil_heating_water(model,
                                hot_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Main Htg Coil",
                                rated_inlet_water_temperature: hw_temp_c,
                                rated_outlet_water_temperature: (hw_temp_c - hw_delta_t_k),
                                rated_inlet_air_temperature: dsgn_temps['prehtg_dsgn_sup_air_temp_c'],
                                rated_outlet_air_temperature: dsgn_temps['htg_dsgn_sup_air_temp_c'])
    end

    # create cooling coil
    if chilled_water_loop.nil?
      create_coil_cooling_dx_two_speed(model,
                                       air_loop_node: air_loop.supplyInletNode,
                                       name: "#{air_loop.name} 2spd DX Clg Coil",
                                       type: 'OS default')
    else
      create_coil_cooling_water(model,
                                chilled_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Clg Coil")
    end

    # outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    oa_intake_controller.resetMaximumFractionofOutdoorAirSchedule
    oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
    unless econo_ctrl_mthd.nil?
      oa_intake_controller.setEconomizerControlType(econo_ctrl_mthd)
    end
    unless oa_damper_sch.nil?
      oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    end
    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')
    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA System")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # set air loop availability controls and night cycle manager, after oa system added
    air_loop.setAvailabilitySchedule(hvac_op_sch)
    air_loop.setNightCycleControlType('CycleOnAny')
    avail_mgr = air_loop.availabilityManager
    if avail_mgr.is_initialized
      avail_mgr = avail_mgr.get
      if avail_mgr.to_AvailabilityManagerNightCycle.is_initialized
        avail_mgr = avail_mgr.to_AvailabilityManagerNightCycle.get
        avail_mgr.setCyclingRunTime(1800)
      end
    end

    # hook the VAV system to each zone
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "Adding VAV system terminal for #{zone.name}")

      # create reheat coil
      case reheat_type
      when 'NaturalGas', 'Gas'
        rht_coil = create_coil_heating_gas(model,
                                           name: "#{zone.name} Gas Reheat Coil")
      when 'Electricity'
        rht_coil = create_coil_heating_electric(model,
                                                name: "#{zone.name} Electric Reheat Coil")
      when 'Water'
        rht_coil = create_coil_heating_water(model,
                                             hot_water_loop,
                                             name: "#{zone.name} Reheat Coil",
                                             rated_inlet_water_temperature: hw_temp_c,
                                             rated_outlet_water_temperature: (hw_temp_c - hw_delta_t_k),
                                             rated_inlet_air_temperature: dsgn_temps['htg_dsgn_sup_air_temp_c'],
                                             rated_outlet_air_temperature: dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      else
        # no reheat
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "No reheat coil for terminal in #{zone.name}")
      end

      # set zone reheat temperatures depending on reheat
      case reheat_type
      when 'NaturalGas', 'Gas', 'Electricity', 'Water'
        # create vav terminal
        terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, model.alwaysOnDiscreteSchedule, rht_coil)
        terminal.setName("#{zone.name} VAV Terminal")
        terminal.setZoneMinimumAirFlowMethod('Constant')
        air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(terminal, thermal_zone_outdoor_airflow_rate_per_area(zone))
        terminal.setMaximumFlowFractionDuringReheat(0.5)
        terminal.setMaximumReheatAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
        air_loop.addBranchForZone(zone, terminal.to_StraightComponent)

        # zone sizing
        sizing_zone = zone.sizingZone
        sizing_zone.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
        sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
        sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      else
        # no reheat
        # create vav terminal
        terminal = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
        terminal.setName("#{zone.name} VAV Terminal")
        terminal.setZoneMinimumAirFlowInputMethod('Constant')
        air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(terminal, thermal_zone_outdoor_airflow_rate_per_area(zone))
        air_loop.addBranchForZone(zone, terminal.to_StraightComponent)

        # zone sizing
        sizing_zone = zone.sizingZone
        sizing_zone.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      end

      unless return_plenum.nil?
        zone.setReturnPlenum(return_plenum)
      end
    end

    # set the damper action based on the template
    air_loop_hvac_apply_vav_damper_action(air_loop)

    return air_loop
  end

  # Creates a VAV system with parallel fan powered boxes and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] chilled water loop to connect to the cooling coil
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param oa_damper_sch [String] name of the oa damper schedule or nil in which case will be defaulted to always open
  # @param fan_efficiency [Double] fan total efficiency, including motor and impeller
  # @param fan_motor_efficiency [Double] fan motor efficiency
  # @param fan_pressure_rise [Double] fan pressure rise, inH2O
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting VAV air loop
  def model_add_vav_pfp_boxes(model,
                              thermal_zones,
                              system_name: nil,
                              chilled_water_loop: nil,
                              hvac_op_sch: nil,
                              oa_damper_sch: nil,
                              fan_efficiency: 0.62,
                              fan_motor_efficiency: 0.9,
                              fan_pressure_rise: 4.0)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding VAV with PFP Boxes and Reheat system for #{thermal_zones.size} zones.")

    # create air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if system_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV with PFP Boxes and Reheat")
    else
      air_loop.setName(system_name)
    end

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # default design temperatures and settings used across all air loops
    dsgn_temps = standard_design_sizing_temperatures
    sizing_system = adjust_sizing_system(air_loop, dsgn_temps)

    # air handler controls
    sa_temp_sch = model_add_constant_schedule_ruleset(model,
                                                      dsgn_temps['clg_dsgn_sup_air_temp_c'],
                                                      name = "Supply Air Temp - #{dsgn_temps['clg_dsgn_sup_air_temp_f']}F")
    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    sa_stpt_manager.setName("#{air_loop.name} Supply Air Setpoint Manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # create fan
    # @type [OpenStudio::Model::FanVariableVolume] fan
    fan = create_fan_by_name(model,
                             'VAV_System_Fan',
                             fan_name: "#{air_loop.name} Fan",
                             fan_efficiency: fan_efficiency,
                             pressure_rise: fan_pressure_rise,
                             motor_efficiency: fan_motor_efficiency,
                             end_use_subcategory: 'VAV System Fans')
    fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    fan.addToNode(air_loop.supplyInletNode)

    # create heating coil
    create_coil_heating_electric(model,
                                 air_loop_node: air_loop.supplyInletNode,
                                 name: "#{air_loop.name} Htg Coil")

    # create cooling coil
    create_coil_cooling_water(model,
                              chilled_water_loop,
                              air_loop_node: air_loop.supplyInletNode,
                              name: "#{air_loop.name} Clg Coil")

    # create outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
    # oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')
    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA System")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # set air loop availability controls and night cycle manager, after oa system added
    air_loop.setAvailabilitySchedule(hvac_op_sch)
    air_loop.setNightCycleControlType('CycleOnAny')

    # attach the VAV system to each zone
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding VAV with PFP Boxes and Reheat system terminal for #{zone.name}.")

      # create reheat coil
      rht_coil = create_coil_heating_electric(model,
                                              name: "#{zone.name} Electric Reheat Coil")

      # create terminal fan
      # @type [OpenStudio::Model::FanConstantVolume] pfp_fan
      pfp_fan = create_fan_by_name(model,
                                   'PFP_Fan',
                                   fan_name: "#{zone.name} PFP Term Fan")
      pfp_fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)

      # create parallel fan powered terminal
      pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(model,
                                                                                   model.alwaysOnDiscreteSchedule,
                                                                                   pfp_fan,
                                                                                   rht_coil)
      pfp_terminal.setName("#{zone.name} PFP Term")
      air_loop.addBranchForZone(zone, pfp_terminal.to_StraightComponent)

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
      sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
    end

    return air_loop
  end

  # Creates a packaged VAV system and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param return_plenum [OpenStudio::Model::ThermalZone] the zone to attach as the supply plenum, or nil, in which case no return plenum will be used
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] hot water loop to connect heating and reheat coils to. If nil, will be electric heat and electric reheat
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] chilled water loop to connect cooling coils to. If nil, will be DX cooling
  # @param heating_type [String] main heating coil fuel type
  #   valid choices are NaturalGas, Electricity, Water, or nil (defaults to NaturalGas)
  # @param electric_reheat [Bool] if true electric reheat coils, if false the reheat coils served by hot_water_loop
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param oa_damper_sch [String] name of the oa damper schedule or nil in which case will be defaulted to always open
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting packaged VAV air loop
  def model_add_pvav(model,
                     thermal_zones,
                     system_name: nil,
                     return_plenum: nil,
                     hot_water_loop: nil,
                     chilled_water_loop: nil,
                     heating_type: nil,
                     electric_reheat: false,
                     hvac_op_sch: nil,
                     oa_damper_sch: nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding Packaged VAV for #{thermal_zones.size} zones.")

    # create air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if system_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone PVAV")
    else
      air_loop.setName(system_name)
    end

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # default design temperatures used across all air loops
    dsgn_temps = standard_design_sizing_temperatures
    unless hot_water_loop.nil?
      hw_temp_c = hot_water_loop.sizingPlant.designLoopExitTemperature
      hw_delta_t_k = hot_water_loop.sizingPlant.loopDesignTemperatureDifference
    end

    # adjusted zone design heating temperature for pvav unless it would cause a temperature higher than reheat water supply temperature
    unless !hot_water_loop.nil? && hw_temp_c < OpenStudio.convert(140.0, 'F', 'C').get
      dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 122.0
      dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get
    end

    # default design settings used across all air loops
    sizing_system = adjust_sizing_system(air_loop, dsgn_temps)

    # air handler controls
    sa_temp_sch = model_add_constant_schedule_ruleset(model,
                                                      dsgn_temps['clg_dsgn_sup_air_temp_c'],
                                                      name = "Supply Air Temp - #{dsgn_temps['clg_dsgn_sup_air_temp_f']}F")
    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    sa_stpt_manager.setName("#{air_loop.name} Supply Air Setpoint Manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # create fan
    fan = create_fan_by_name(model,
                             'VAV_default',
                             fan_name: "#{air_loop.name} Fan")
    fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    fan.addToNode(air_loop.supplyInletNode)

    # create heating coil
    if hot_water_loop.nil?
      if heating_type == 'Electricity'
        create_coil_heating_electric(model,
                                     air_loop_node: air_loop.supplyInletNode,
                                     name: "#{air_loop.name} Main Electric Htg Coil")
      else # default to NaturalGas
        create_coil_heating_gas(model,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Main Gas Htg Coil")
      end
    else
      create_coil_heating_water(model,
                                hot_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Main Htg Coil",
                                rated_inlet_water_temperature: hw_temp_c,
                                rated_outlet_water_temperature: (hw_temp_c - hw_delta_t_k),
                                rated_inlet_air_temperature: dsgn_temps['prehtg_dsgn_sup_air_temp_c'],
                                rated_outlet_air_temperature: dsgn_temps['htg_dsgn_sup_air_temp_c'])
    end

    # create cooling coil
    if chilled_water_loop.nil?
      create_coil_cooling_dx_two_speed(model,
                                       air_loop_node: air_loop.supplyInletNode,
                                       name: "#{air_loop.name} 2spd DX Clg Coil",
                                       type: 'OS default')
    else
      create_coil_cooling_water(model,
                                chilled_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Clg Coil")
    end

    # Outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA System")
    oa_intake.addToNode(air_loop.supplyInletNode)
    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Ventilation Controller")
    controller_mv.setAvailabilitySchedule(oa_damper_sch)

    # set air loop availability controls and night cycle manager, after oa system added
    air_loop.setAvailabilitySchedule(hvac_op_sch)
    air_loop.setNightCycleControlType('CycleOnAny')
    avail_mgr = air_loop.availabilityManager
    if avail_mgr.is_initialized
      avail_mgr = avail_mgr.get
      if avail_mgr.to_AvailabilityManagerNightCycle.is_initialized
        avail_mgr = avail_mgr.to_AvailabilityManagerNightCycle.get
        avail_mgr.setCyclingRunTime(1800)
      end
    end

    # attach the VAV system to each zone
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "Adding PVAV terminal for #{zone.name}")

      # create reheat coil
      if electric_reheat || hot_water_loop.nil?
        rht_coil = create_coil_heating_electric(model,
                                                name: "#{zone.name} Electric Reheat Coil")
      else
        rht_coil = create_coil_heating_water(model,
                                             hot_water_loop,
                                             name: "#{zone.name} Reheat Coil",
                                             rated_inlet_water_temperature: hw_temp_c,
                                             rated_outlet_water_temperature: (hw_temp_c - hw_delta_t_k),
                                             rated_inlet_air_temperature: dsgn_temps['htg_dsgn_sup_air_temp_c'],
                                             rated_outlet_air_temperature: dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      end

      # create VAV terminal
      terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, model.alwaysOnDiscreteSchedule, rht_coil)
      terminal.setName("#{zone.name} VAV Terminal")
      terminal.setZoneMinimumAirFlowMethod('Constant')
      terminal.setMaximumReheatAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(terminal, thermal_zone_outdoor_airflow_rate_per_area(zone))
      air_loop.addBranchForZone(zone, terminal.to_StraightComponent)

      unless return_plenum.nil?
        zone.setReturnPlenum(return_plenum)
      end

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
    end

    # set the damper action based on the template
    air_loop_hvac_apply_vav_damper_action(air_loop)

    return true
  end

  # Creates a packaged VAV system with parallel fan powered boxes and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] chilled water loop to connect cooling coils to. If nil, will be DX cooling
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param oa_damper_sch [String] name of the oa damper schedule or nil in which case will be defaulted to always open
  # @param fan_efficiency [Double] fan total efficiency, including motor and impeller
  # @param fan_motor_efficiency [Double] fan motor efficiency
  # @param fan_pressure_rise [Double] fan pressure rise, inH2O
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting VAV air loop
  def model_add_pvav_pfp_boxes(model,
                               thermal_zones,
                               system_name: nil,
                               chilled_water_loop: nil,
                               hvac_op_sch: nil,
                               oa_damper_sch: nil,
                               fan_efficiency: 0.62,
                               fan_motor_efficiency: 0.9,
                               fan_pressure_rise: 4.0)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PVAV with PFP Boxes and Reheat system for #{thermal_zones.size} zones.")

    # create air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if system_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone VAV with PFP Boxes and Reheat")
    else
      air_loop.setName(system_name)
    end

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # default design temperatures and settings used across all air loops
    dsgn_temps = standard_design_sizing_temperatures
    sizing_system = adjust_sizing_system(air_loop, dsgn_temps)

    # air handler controls
    sa_temp_sch = model_add_constant_schedule_ruleset(model,
                                                      dsgn_temps['clg_dsgn_sup_air_temp_c'],
                                                      name = "Supply Air Temp - #{dsgn_temps['clg_dsgn_sup_air_temp_f']}F")
    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    sa_stpt_manager.setName("#{air_loop.name} Supply Air Setpoint Manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # create fan
    # @type [OpenStudio::Model::FanVariableVolume] fan
    fan = create_fan_by_name(model,
                             'VAV_System_Fan',
                             fan_name: "#{air_loop.name} Fan",
                             fan_efficiency: fan_efficiency,
                             pressure_rise: fan_pressure_rise,
                             motor_efficiency: fan_motor_efficiency,
                             end_use_subcategory: 'VAV System Fans')
    fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    fan.addToNode(air_loop.supplyInletNode)

    # create heating coil
    create_coil_heating_electric(model,
                                 air_loop_node: air_loop.supplyInletNode,
                                 name: "#{air_loop.name} Main Htg Coil")

    # create cooling coil
    if chilled_water_loop.nil?
      create_coil_cooling_dx_two_speed(model,
                                       air_loop_node: air_loop.supplyInletNode,
                                       name: "#{air_loop.name} 2spd DX Clg Coil", type: 'OS default')
    else
      create_coil_cooling_water(model,
                                chilled_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Clg Coil")
    end

    # create outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA System")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # set air loop availability controls and night cycle manager, after oa system added
    air_loop.setAvailabilitySchedule(hvac_op_sch)
    air_loop.setNightCycleControlType('CycleOnAny')

    # attach the VAV system to each zone
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "Adding PVAV PFP Box to zone #{zone.name}")

      # create electric reheat coil
      rht_coil = create_coil_heating_electric(model,
                                              name: "#{zone.name} Electric Reheat Coil")

      # create terminal fan
      # @type [OpenStudio::Model::FanConstantVolume] pfp_fan
      pfp_fan = create_fan_by_name(model,
                                   'PFP_Fan',
                                   fan_name: "#{zone.name} PFP Term Fan")
      pfp_fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)

      # parallel fan powered terminal
      pfp_terminal = OpenStudio::Model::AirTerminalSingleDuctParallelPIUReheat.new(model,
                                                                                   model.alwaysOnDiscreteSchedule,
                                                                                   pfp_fan,
                                                                                   rht_coil)
      pfp_terminal.setName("#{zone.name} PFP Term")
      air_loop.addBranchForZone(zone, pfp_terminal.to_StraightComponent)

      # adjust zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
      sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
    end

    return air_loop
  end

  # Creates a CAV system and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] hot water loop to connect to heating and reheat coils.
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] chilled water loop to connect to the cooling coil.
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param oa_damper_sch [String] name of the oa damper schedule or nil in which case will be defaulted to always open
  # @param fan_efficiency [Double] fan total efficiency, including motor and impeller
  # @param fan_motor_efficiency [Double] fan motor efficiency
  # @param fan_pressure_rise [Double] fan pressure rise, inH2O
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting packaged VAV air loop
  def model_add_cav(model,
                    thermal_zones,
                    system_name: nil,
                    hot_water_loop: nil,
                    chilled_water_loop: nil,
                    hvac_op_sch: nil,
                    oa_damper_sch: nil,
                    fan_efficiency: 0.62,
                    fan_motor_efficiency: 0.9,
                    fan_pressure_rise: 4.0)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding CAV for #{thermal_zones.size} zones.")

    # create air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if system_name.nil?
      air_loop.setName("#{thermal_zones.size} Zone CAV")
    else
      air_loop.setName(system_name)
    end

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # default design temperatures used across all air loops
    dsgn_temps = standard_design_sizing_temperatures
    unless hot_water_loop.nil?
      hw_temp_c = hot_water_loop.sizingPlant.designLoopExitTemperature
      hw_delta_t_k = hot_water_loop.sizingPlant.loopDesignTemperatureDifference
    end

    # adjusted design heating temperature for cav
    dsgn_temps['htg_dsgn_sup_air_temp_f'] = 62.0
    dsgn_temps['htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['htg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 122.0
    dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get

    # default design settings used across all air loops
    sizing_system = adjust_sizing_system(air_loop, dsgn_temps, min_sys_airflow_ratio: 1.0)

    # air handler controls
    sa_temp_sch = model_add_constant_schedule_ruleset(model,
                                                      dsgn_temps['clg_dsgn_sup_air_temp_c'],
                                                      name = "Supply Air Temp - #{dsgn_temps['clg_dsgn_sup_air_temp_f']}F")
    sa_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sa_temp_sch)
    sa_stpt_manager.setName("#{air_loop.name} Supply Air Setpoint Manager")
    sa_stpt_manager.addToNode(air_loop.supplyOutletNode)

    # create fan
    fan = create_fan_by_name(model,
                             'Packaged_RTU_SZ_AC_CAV_Fan',
                             fan_name: "#{air_loop.name} Fan",
                             fan_efficiency: fan_efficiency,
                             pressure_rise: fan_pressure_rise,
                             motor_efficiency: fan_motor_efficiency,
                             end_use_subcategory: 'CAV System Fans')
    fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    fan.addToNode(air_loop.supplyInletNode)

    # create heating coil
    create_coil_heating_water(model,
                              hot_water_loop,
                              air_loop_node: air_loop.supplyInletNode,
                              name: "#{air_loop.name} Main Htg Coil",
                              rated_inlet_water_temperature: hw_temp_c,
                              rated_outlet_water_temperature: (hw_temp_c - hw_delta_t_k),
                              rated_inlet_air_temperature: dsgn_temps['prehtg_dsgn_sup_air_temp_c'],
                              rated_outlet_air_temperature: dsgn_temps['htg_dsgn_sup_air_temp_c'])

    # create cooling coil
    if chilled_water_loop.nil?
      create_coil_cooling_dx_two_speed(model,
                                       air_loop_node: air_loop.supplyInletNode,
                                       name: "#{air_loop.name} 2spd DX Clg Coil",
                                       type: 'OS default')
    else
      create_coil_cooling_water(model,
                                chilled_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Clg Coil")
    end

    # create outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
    oa_intake_controller.setMinimumFractionofOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('ZoneSum')
    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA System")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # set air loop availability controls and night cycle manager, after oa system added
    air_loop.setAvailabilitySchedule(hvac_op_sch)
    air_loop.setNightCycleControlType('CycleOnAny')

    # Connect the CAV system to each zone
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "Adding CAV for #{zone.name}")

      # Reheat coil
      rht_coil = create_coil_heating_water(model,
                                           hot_water_loop,
                                           name: "#{zone.name} Reheat Coil",
                                           rated_inlet_water_temperature: hw_temp_c,
                                           rated_outlet_water_temperature: (hw_temp_c - hw_delta_t_k),
                                           rated_inlet_air_temperature: dsgn_temps['htg_dsgn_sup_air_temp_c'],
                                           rated_outlet_air_temperature: dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      # VAV terminal
      terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, model.alwaysOnDiscreteSchedule, rht_coil)
      terminal.setName("#{zone.name} VAV Terminal")
      terminal.setZoneMinimumAirFlowMethod('Constant')
      air_terminal_single_duct_vav_reheat_apply_initial_prototype_damper_position(terminal, thermal_zone_outdoor_airflow_rate_per_area(zone))
      terminal.setMaximumFlowPerZoneFloorAreaDuringReheat(0.0)
      terminal.setMaximumFlowFractionDuringReheat(0.5)
      terminal.setMaximumReheatAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      air_loop.addBranchForZone(zone, terminal.to_StraightComponent)

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
      sizing_zone.setHeatingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
    end

    # Set the damper action based on the template.
    air_loop_hvac_apply_vav_damper_action(air_loop)

    return true
  end

  # Creates a PSZ-AC system for each zone and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param cooling_type [String] valid choices are Water, Two Speed DX AC, Single Speed DX AC, Single Speed Heat Pump, Water To Air Heat Pump
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] chilled water loop to connect cooling coil to, or nil
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] hot water loop to connect heating coil to, or nil
  # @param heating_type [String] valid choices are NaturalGas, Electricity, Water, Single Speed Heat Pump, Water To Air Heat Pump, or nil (no heat)
  # @param supplemental_heating_type [String] valid choices are Electricity, NaturalGas,  nil (no heat)
  # @param fan_location [String] valid choices are BlowThrough, DrawThrough
  # @param fan_type [String] valid choices are ConstantVolume, Cycling
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param oa_damper_sch [String] name of the oa damper schedule or nil in which case will be defaulted to always open
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] an array of the resulting PSZ-AC air loops
  def model_add_psz_ac(model,
                       thermal_zones,
                       system_name: nil,
                       cooling_type: 'Single Speed DX AC',
                       chilled_water_loop: nil,
                       hot_water_loop: nil,
                       heating_type: nil,
                       supplemental_heating_type: nil,
                       fan_location: 'DrawThrough',
                       fan_type: 'ConstantVolume',
                       hvac_op_sch: nil,
                       oa_damper_sch: nil)

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # create a PSZ-AC for each zone
    air_loops = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PSZ-AC for #{zone.name}.")

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      if system_name.nil?
        air_loop.setName("#{zone.name} PSZ-AC")
      else
        air_loop.setName("#{zone.name} #{system_name}")
      end

      # default design temperatures and settings used across all air loops
      dsgn_temps = standard_design_sizing_temperatures
      unless hot_water_loop.nil?
        hw_temp_c = hot_water_loop.sizingPlant.designLoopExitTemperature
        hw_delta_t_k = hot_water_loop.sizingPlant.loopDesignTemperatureDifference
      end

      # adjusted design heating temperature for psz_ac
      dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 122.0
      dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get
      dsgn_temps['htg_dsgn_sup_air_temp_f'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_f']
      dsgn_temps['htg_dsgn_sup_air_temp_c'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_c']

      # default design settings used across all air loops
      sizing_system = adjust_sizing_system(air_loop, dsgn_temps, min_sys_airflow_ratio: 1.0)

      # air handler controls
      # add a setpoint manager single zone reheat to control the supply air temperature
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setName("#{zone.name} Setpoint Manager SZ Reheat")
      setpoint_mgr_single_zone_reheat.setControlZone(zone)
      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])

      # create fan
      # ConstantVolume: Packaged Rooftop Single Zone Air conditioner
      # Cycling: Unitary System
      # CyclingHeatPump: Unitary Heat Pump system
      if fan_type == 'ConstantVolume'
        fan = create_fan_by_name(model,
                                 'Packaged_RTU_SZ_AC_CAV_Fan',
                                 fan_name: "#{air_loop.name} Fan")
        fan.setAvailabilitySchedule(hvac_op_sch)
      elsif fan_type == 'Cycling'
        fan = create_fan_by_name(model,
                                 'Packaged_RTU_SZ_AC_Cycling_Fan',
                                 fan_name: "#{air_loop.name} Fan")
        fan.setAvailabilitySchedule(hvac_op_sch)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Fan type '#{fan_type}' not recognized, cannot add PSZ-AC.")
        return []
      end

      # create heating coil
      case heating_type
      when 'NaturalGas', 'Gas'
        htg_coil = create_coil_heating_gas(model,
                                           name: "#{air_loop.name} Gas Htg Coil")
      when 'Water'
        if hot_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water plant loop supplied')
          return false
        end
        htg_coil = create_coil_heating_water(model,
                                             hot_water_loop,
                                             name: "#{air_loop.name} Water Htg Coil",
                                             rated_inlet_water_temperature: hw_temp_c,
                                             rated_outlet_water_temperature: (hw_temp_c - hw_delta_t_k),
                                             rated_inlet_air_temperature: dsgn_temps['prehtg_dsgn_sup_air_temp_c'],
                                             rated_outlet_air_temperature: dsgn_temps['htg_dsgn_sup_air_temp_c'])
      when 'Single Speed Heat Pump'
        htg_coil = create_coil_heating_dx_single_speed(model,
                                                       name: "#{zone.name} HP Htg Coil",
                                                       type: 'PSZ-AC',
                                                       cop: 3.3)
      when 'Water To Air Heat Pump'
        htg_coil = create_coil_heating_water_to_air_heat_pump_equation_fit(model,
                                                                           hot_water_loop,
                                                                           name: "#{air_loop.name} Water-to-Air HP Htg Coil")
      when 'Electricity', 'Electric'
        htg_coil = create_coil_heating_electric(model,
                                                name: "#{air_loop.name} Electric Htg Coil")
      else
        # zero-capacity, always-off electric heating coil
        htg_coil = create_coil_heating_electric(model,
                                                name: "#{air_loop.name} No Heat",
                                                schedule: model.alwaysOffDiscreteSchedule,
                                                nominal_capacity: 0.0)
      end

      # create supplemental heating coil
      case supplemental_heating_type
      when 'Electricity', 'Electric'
        supplemental_htg_coil = create_coil_heating_electric(model,
                                                             name: "#{air_loop.name} Electric Backup Htg Coil")
      when 'NaturalGas', 'Gas'
        supplemental_htg_coil = create_coil_heating_gas(model,
                                                        name: "#{air_loop.name} Gas Backup Htg Coil")
      else
        # Zero-capacity, always-off electric heating coil
        supplemental_htg_coil = create_coil_heating_electric(model,
                                                             name: "#{air_loop.name} No Heat",
                                                             schedule: model.alwaysOffDiscreteSchedule,
                                                             nominal_capacity: 0.0)
      end

      # create cooling coil
      case cooling_type
      when 'Water'
        if chilled_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No chilled water plant loop supplied')
          return false
        end
        clg_coil = create_coil_cooling_water(model,
                                             chilled_water_loop,
                                             name: "#{air_loop.name} Water Clg Coil")
      when 'Two Speed DX AC'
        clg_coil = create_coil_cooling_dx_two_speed(model,
                                                    name: "#{air_loop.name} 2spd DX AC Clg Coil")
      when 'Single Speed DX AC'
        clg_coil = create_coil_cooling_dx_single_speed(model,
                                                       name: "#{air_loop.name} 1spd DX AC Clg Coil",
                                                       type: 'PSZ-AC')
      when 'Single Speed Heat Pump'
        clg_coil = create_coil_cooling_dx_single_speed(model,
                                                       name: "#{air_loop.name} 1spd DX HP Clg Coil",
                                                       type: 'Heat Pump')
        # clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(OpenStudio::OptionalDouble.new(10.0))
        # clg_coil.setRatedSensibleHeatRatio(0.69)
        # clg_coil.setBasinHeaterCapacity(10)
        # clg_coil.setBasinHeaterSetpointTemperature(2.0)
      when 'Water To Air Heat Pump'
        if chilled_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No chilled water plant loop supplied')
          return false
        end
        clg_coil = create_coil_cooling_water_to_air_heat_pump_equation_fit(model,
                                                                           chilled_water_loop,
                                                                           name: "#{air_loop.name} Water-to-Air HP Clg Coil")
      else
        clg_coil = nil
      end

      # wrap coils in a unitary system if cycling, or not if constant volume
      if fan_type == 'Cycling'
        if heating_type == 'Water To Air Heat Pump'
          # Cycling: Unitary System
          unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
          unitary_system.setSupplyFan(fan) unless fan.nil?
          unitary_system.setHeatingCoil(htg_coil) unless htg_coil.nil?
          unitary_system.setCoolingCoil(clg_coil) unless clg_coil.nil?
          unitary_system.setSupplementalHeatingCoil(supplemental_htg_coil) unless supplemental_htg_coil.nil?
          unitary_system.setName("#{zone.name} Unitary HP")
          unitary_system.setControllingZoneorThermostatLocation(zone)
          unitary_system.setMaximumSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
          unitary_system.setFanPlacement('BlowThrough')
          unitary_system.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
          unitary_system.setSupplyAirFlowRateMethodDuringHeatingOperation('SupplyAirFlowRate')
          unitary_system.setSupplyAirFlowRateMethodWhenNoCoolingorHeatingisRequired('SupplyAirFlowRate')
          unitary_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOnDiscreteSchedule)
          unitary_system.addToNode(air_loop.supplyInletNode)
        else
          # CyclingHeatPump: Unitary Heat Pump system
          unitary_system = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir.new(model,
                                                                                     model.alwaysOnDiscreteSchedule,
                                                                                     fan,
                                                                                     htg_coil,
                                                                                     clg_coil,
                                                                                     supplemental_htg_coil)
          unitary_system.setName("#{air_loop.name} Unitary HP")
          unitary_system.setControllingZone(zone)
          unitary_system.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(OpenStudio.convert(40.0, 'F', 'C').get)
          unitary_system.setFanPlacement(fan_location)
          unitary_system.setSupplyAirFanOperatingModeSchedule(hvac_op_sch)
          unitary_system.addToNode(air_loop.supplyInletNode)
        end
      else
        # ConstantVolume: Packaged Rooftop Single Zone Air conditioner
        if fan_location == 'DrawThrough'
          fan.addToNode(air_loop.supplyInletNode) unless fan.nil?
          supplemental_htg_coil.addToNode(air_loop.supplyInletNode) unless supplemental_htg_coil.nil?
          unless htg_coil.nil?
            htg_coil.addToNode(air_loop.supplyInletNode)
            # if water coil, rename controller b/c it is recreated when added to node
            htg_coil.controllerWaterCoil.get.setName("#{htg_coil.name} Controller") if heating_type == 'Water'
          end
          unless clg_coil.nil?
            clg_coil.addToNode(air_loop.supplyInletNode)
            # if water coil, rename controller b/c it is recreated when added to node
            clg_coil.controllerWaterCoil.get.setName("#{clg_coil.name} Controller") if cooling_type == 'Water'
          end
        elsif fan_location == 'BlowThrough'
          supplemental_htg_coil.addToNode(air_loop.supplyInletNode) unless supplemental_htg_coil.nil?
          clg_coil.addToNode(air_loop.supplyInletNode) unless clg_coil.nil?
          htg_coil.addToNode(air_loop.supplyInletNode) unless htg_coil.nil?
          fan.addToNode(air_loop.supplyInletNode) unless fan.nil?
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Invalid fan location')
          return false
        end
      end

      # add the OA system
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.setName("#{air_loop.name} OA System Controller")
      oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
      oa_controller.autosizeMinimumOutdoorAirFlowRate
      oa_controller.resetEconomizerMinimumLimitDryBulbTemperature
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
      oa_system.setName("#{air_loop.name} OA System")
      oa_system.addToNode(air_loop.supplyInletNode)

      # TODO: enable economizer maximum fraction outdoor air schedule input
      # econ_eff_sch = model_add_schedule(model, 'RetailStandalone PSZ_Econ_MaxOAFrac_Sch')

      # set air loop availability controls and night cycle manager, after oa system added
      air_loop.setAvailabilitySchedule(hvac_op_sch)
      air_loop.setNightCycleControlType('CycleOnAny')
      avail_mgr = air_loop.availabilityManager
      if avail_mgr.is_initialized
        avail_mgr = avail_mgr.get
        if avail_mgr.to_AvailabilityManagerNightCycle.is_initialized
          avail_mgr = avail_mgr.to_AvailabilityManagerNightCycle.get
          avail_mgr.setCyclingRunTime(1800)
        end
      end

      # create a diffuser and attach the zone/diffuser pair to the air loop
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{air_loop.name} Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
      air_loops << air_loop
    end

    return air_loops
  end

  # Creates a packaged single zone VAV system for each zone and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param heating_type [String] valid choices are NaturalGas, Electricity, Water, nil (no heat)
  # @param supplemental_heating_type [String] valid choices are Electricity, NaturalGas,  nil (no heat)
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param oa_damper_sch [String] name of the oa damper schedule or nil in which case will be defaulted to always open
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] an array of the resulting PSZ-AC air loops
  def model_add_psz_vav(model,
                        thermal_zones,
                        system_name: nil,
                        heating_type: nil,
                        supplemental_heating_type: nil,
                        hvac_op_sch: nil,
                        oa_damper_sch: nil)

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # create a PSZ-VAV for each zone
    air_loops = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PSZ-VAV for #{zone.name}.")

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      if system_name.nil?
        air_loop.setName("#{zone.name} PSZ-VAV")
      else
        air_loop.setName("#{zone.name} #{system_name}")
      end

      # default design temperatures used across all air loops
      dsgn_temps = standard_design_sizing_temperatures

      # adjusted zone design heating temperature for psz_vav
      dsgn_temps['htg_dsgn_sup_air_temp_f'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_f']
      dsgn_temps['htg_dsgn_sup_air_temp_c'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_c']

      # default design settings used across all air loops
      sizing_system = adjust_sizing_system(air_loop, dsgn_temps)

      # air handler controls
      # add a setpoint manager single zone reheat to control the supply air temperature
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setName("#{zone.name} Setpoint Manager SZ Reheat")
      setpoint_mgr_single_zone_reheat.setControlZone(zone)
      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])

      # create fan
      # @type [OpenStudio::Model::FanVariableVolume] fan
      fan = create_fan_by_name(model,
                               'VAV_System_Fan',
                               fan_name: "#{air_loop.name} Fan",
                               end_use_subcategory: 'VAV System Fans')
      fan.setAvailabilitySchedule(hvac_op_sch)

      # create heating coil
      case heating_type
      when 'NaturalGas', 'Gas'
        htg_coil = create_coil_heating_gas(model,
                                           name: "#{air_loop.name} Gas Htg Coil")
      when 'Electricity', 'Electric'
        htg_coil = create_coil_heating_electric(model,
                                                name: "#{air_loop.name} Electric Htg Coil")
      else
        # Zero-capacity, always-off electric heating coil
        htg_coil = create_coil_heating_electric(model,
                                                name: "#{air_loop.name} No Heat",
                                                schedule: model.alwaysOffDiscreteSchedule,
                                                nominal_capacity: 0.0)
      end

      # create supplemental heating coil
      case supplemental_heating_type
      when 'Electricity', 'Electric'
        supplemental_htg_coil = create_coil_heating_electric(model,
                                                             name: "#{air_loop.name} Electric Backup Htg Coil")
      when 'NaturalGas', 'Gas'
        supplemental_htg_coil = create_coil_heating_gas(model,
                                                        name: "#{air_loop.name} Gas Backup Htg Coil")
      else
        # zero-capacity, always-off electric heating coil
        supplemental_htg_coil = create_coil_heating_electric(model,
                                                             name: "#{air_loop.name} No Backup Heat",
                                                             schedule: model.alwaysOffDiscreteSchedule,
                                                             nominal_capacity: 0.0)
      end

      # create cooling coil
      clg_coil = OpenStudio::Model::CoilCoolingDXVariableSpeed.new(model)
      clg_coil.setName("#{air_loop.name} Var spd DX AC Clg Coil")
      clg_coil.setBasinHeaterCapacity(10.0)
      clg_coil.setBasinHeaterSetpointTemperature(2.0)
      # first speed level
      clg_spd_1 = OpenStudio::Model::CoilCoolingDXVariableSpeedSpeedData.new(model)
      clg_coil.addSpeed(clg_spd_1)
      clg_coil.setNominalSpeedLevel(1)

      # TODO: enable economizer maximum fraction outdoor air schedule input
      # econ_eff_sch = model_add_schedule(model, 'RetailStandalone PSZ_Econ_MaxOAFrac_Sch')

      # wrap coils in a unitary system
      unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary_system.setSupplyFan(fan)
      unitary_system.setHeatingCoil(htg_coil)
      unitary_system.setCoolingCoil(clg_coil)
      unitary_system.setSupplementalHeatingCoil(supplemental_htg_coil)
      unitary_system.setName("#{zone.name} Unitary PSZ-VAV")
      unitary_system.setString(2, 'SingleZoneVAV') # TODO: add setControlType() method
      unitary_system.setControllingZoneorThermostatLocation(zone)
      unitary_system.setMaximumSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      unitary_system.setFanPlacement('BlowThrough')
      unitary_system.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
      unitary_system.setSupplyAirFlowRateMethodDuringHeatingOperation('SupplyAirFlowRate')
      unitary_system.setSupplyAirFlowRateMethodWhenNoCoolingorHeatingisRequired('SupplyAirFlowRate')
      unitary_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOnDiscreteSchedule)
      unitary_system.addToNode(air_loop.supplyInletNode)

      # create outdoor air system
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.setName("#{air_loop.name} OA Sys Controller")
      oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
      oa_controller.autosizeMinimumOutdoorAirFlowRate
      oa_controller.resetEconomizerMinimumLimitDryBulbTemperature
      oa_controller.setHeatRecoveryBypassControlType('BypassWhenOAFlowGreaterThanMinimum')
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
      oa_system.setName("#{air_loop.name} OA System")
      oa_system.addToNode(air_loop.supplyInletNode)

      # set air loop availability controls and night cycle manager, after oa system added
      air_loop.setAvailabilitySchedule(hvac_op_sch)
      air_loop.setNightCycleControlType('CycleOnAny')

      # create a VAV no reheat terminal and attach the zone/terminal pair to the air loop
      diffuser = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{air_loop.name} Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
      air_loops << air_loop
    end

    return air_loops
  end

  # Adds a data center load to a given space.
  #
  # @param space [OpenStudio::Model::Space] which space to assign the data center loads to
  # @param dc_watts_per_area [Double] data center load, in W/m^2
  # @return [Bool] returns true if successful, false if not
  def model_add_data_center_load(model, space, dc_watts_per_area)
    # create data center load
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
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] hot water loop to connect to the heating coil
  # @param heat_pump_loop [OpenStudio::Model::PlantLoop] heat pump water loop to connect to heat pump
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param oa_damper_sch [String] name of the oa damper schedule or nil in which case will be defaulted to always open
  # @param main_data_center [Bool] whether or not this is the main data center in the building.
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] an array of the resulting air loops
  def model_add_data_center_hvac(model,
                                 thermal_zones,
                                 hot_water_loop,
                                 heat_pump_loop,
                                 system_name: nil,
                                 hvac_op_sch: nil,
                                 oa_damper_sch: nil,
                                 main_data_center: false)

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # create a PSZ-AC for each zone
    air_loops = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding data center HVAC for #{zone.name}.")

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      if system_name.nil?
        air_loop.setName("#{zone.name} PSZ-AC Data Center")
      else
        air_loop.setName("#{zone.name} #{system_name}")
      end

      # default design temperatures across all air loops
      dsgn_temps = standard_design_sizing_temperatures
      unless hot_water_loop.nil?
        hw_temp_c = hot_water_loop.sizingPlant.designLoopExitTemperature
        hw_delta_t_k = hot_water_loop.sizingPlant.loopDesignTemperatureDifference
      end

      # adjusted zone design heating temperature for data center psz_ac
      dsgn_temps['htg_dsgn_sup_air_temp_f'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_f']
      dsgn_temps['htg_dsgn_sup_air_temp_c'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_c']

      # default design settings used across all air loops
      sizing_system = adjust_sizing_system(air_loop, dsgn_temps, min_sys_airflow_ratio: 1.0)

      # air handler controls
      # add a setpoint manager single zone reheat to control the supply air temperature
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setName("#{zone.name} Setpoint Manager SZ Reheat")
      setpoint_mgr_single_zone_reheat.setControlZone(zone)
      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])

      # add the components to the air loop in order from closest to zone to furthest from zone
      if main_data_center
        # extra water heating coil
        create_coil_heating_water(model,
                                  hot_water_loop,
                                  air_loop_node: air_loop.supplyInletNode,
                                  name: "#{air_loop.name} Water Htg Coil",
                                  rated_inlet_water_temperature: hw_temp_c,
                                  rated_outlet_water_temperature: (hw_temp_c - hw_delta_t_k),
                                  rated_inlet_air_temperature: dsgn_temps['prehtg_dsgn_sup_air_temp_c'],
                                  rated_outlet_air_temperature: dsgn_temps['htg_dsgn_sup_air_temp_c'])

        # extra electric heating coil
        create_coil_heating_electric(model,
                                     air_loop_node: air_loop.supplyInletNode,
                                     name: "#{air_loop.name} Electric Htg Coil")

        # humidity controllers
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100_000)
        humidifier.setName("#{air_loop.name} Electric Steam Humidifier")
        humidifier.addToNode(air_loop.supplyInletNode)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
        humidity_spm.setControlZone(zone)
        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)
        humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
        humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'OfficeLarge DC_MinRelHumSetSch'))
        zone.setZoneControlHumidistat(humidistat)
      end

      # create fan
      # @type [OpenStudio::Model::FanConstantVolume]
      fan = create_fan_by_name(model,
                               'Packaged_RTU_SZ_AC_Cycling_Fan',
                               fan_name: "#{air_loop.name} Fan")
      fan.setAvailabilitySchedule(hvac_op_sch)

      # create heating and cooling coils
      htg_coil = create_coil_heating_water_to_air_heat_pump_equation_fit(model,
                                                                         heat_pump_loop,
                                                                         name: "#{air_loop.name} Water-to-Air HP Htg Coil")
      clg_coil = create_coil_cooling_water_to_air_heat_pump_equation_fit(model,
                                                                         heat_pump_loop,
                                                                         name: "#{air_loop.name} Water-to-Air HP Clg Coil")
      supplemental_htg_coil = create_coil_heating_electric(model,
                                                           name: "#{air_loop.name} Electric Backup Htg Coil")

      # wrap fan and coils in a unitary system object
      unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary_system.setName("#{zone.name} Unitary HP")
      unitary_system.setSupplyFan(fan)
      unitary_system.setHeatingCoil(htg_coil)
      unitary_system.setCoolingCoil(clg_coil)
      unitary_system.setSupplementalHeatingCoil(supplemental_htg_coil)
      unitary_system.setControllingZoneorThermostatLocation(zone)
      unitary_system.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(OpenStudio.convert(40.0, 'F', 'C').get)
      unitary_system.setFanPlacement('BlowThrough')
      unitary_system.setSupplyAirFanOperatingModeSchedule(hvac_op_sch)
      unitary_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOnDiscreteSchedule)
      unitary_system.addToNode(air_loop.supplyInletNode)

      # create outdoor air system
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.setName("#{air_loop.name} OA System Controller")
      oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
      oa_controller.autosizeMinimumOutdoorAirFlowRate
      oa_controller.resetEconomizerMinimumLimitDryBulbTemperature
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
      oa_system.setName("#{air_loop.name} OA System")
      oa_system.addToNode(air_loop.supplyInletNode)

      # set air loop availability controls and night cycle manager, after oa system added
      air_loop.setAvailabilitySchedule(hvac_op_sch)
      air_loop.setNightCycleControlType('CycleOnAny')

      # create a diffuser and attach the zone/diffuser pair to the air loop
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{air_loop.name} Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      air_loops << air_loop
    end

    return air_loops
  end


  # Creates a CRAC system for data center and adds it to the model.
  #
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # @param fan_location [Double] valid choices are BlowThrough, DrawThrough
  # @param fan_type [Double] valid choices are ConstantVolume, Cycling, VariableVolume
  # no heating
  # @param cooling_type [String] valid choices are Two Speed DX AC, Single Speed DX AC
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] an array of the resulting CRAC air loops
  def model_add_crac(model,
                     thermal_zones,
                     climate_zone,
                     system_name: nil,
                     hvac_op_sch: nil,
                     oa_damper_sch: nil,
                     fan_location: 'DrawThrough',
                     fan_type: 'ConstantVolume',
                     cooling_type: 'Single Speed DX AC')

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # Make a CRAC for each data center zone
    air_loops = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding CRAC for #{zone.name}.")

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      if system_name.nil?
        air_loop.setName("#{zone.name} CRAC")
      else
        air_loop.setName("#{zone.name} #{system_name}")
      end

      # default design temperatures across all air loops
      dsgn_temps = standard_design_sizing_temperatures

      # adjusted zone design heating temperature for data center psz_ac
      dsgn_temps['prehtg_dsgn_sup_air_temp_f'] = 64.4
      dsgn_temps['preclg_dsgn_sup_air_temp_f'] = 80.6
      dsgn_temps['htg_dsgn_sup_air_temp_f'] = 72.5
      dsgn_temps['clg_dsgn_sup_air_temp_f'] = 72.5
      dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 72.5
      dsgn_temps['zn_clg_dsgn_sup_air_temp_f'] = 72.5
      dsgn_temps['prehtg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['prehtg_dsgn_sup_air_temp_f'], 'F', 'C').get
      dsgn_temps['preclg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['preclg_dsgn_sup_air_temp_f'], 'F', 'C').get
      dsgn_temps['htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['htg_dsgn_sup_air_temp_f'], 'F', 'C').get
      dsgn_temps['clg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['clg_dsgn_sup_air_temp_f'], 'F', 'C').get
      dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get
      dsgn_temps['zn_clg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_clg_dsgn_sup_air_temp_f'], 'F', 'C').get

      # default design settings used across all air loops
      sizing_system = adjust_sizing_system(air_loop, dsgn_temps, min_sys_airflow_ratio: 0.05)

      # Zone sizing
      sizing_zone = zone.sizingZone
      # per ASHRAE 90.4, recommended range of data center supply air temperature is 18-27C, pick the mean value 22.5C as prototype
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])

      # create fan
      # ConstantVolume: Packaged Rooftop Single Zone Air conditioner
      # Cycling: Unitary System
      # CyclingHeatPump: Unitary Heat Pump system
      if fan_type == 'VariableVolume'
        fan = create_fan_by_name(model,
                                 'CRAC_VAV_fan',
                                 fan_name: "#{air_loop.name} Fan")
        fan.setAvailabilitySchedule(hvac_op_sch)
      elsif fan_type == 'ConstantVolume'
        fan = create_fan_by_name(model,
                                 'CRAC_CAV_fan',
                                 fan_name: "#{air_loop.name} Fan")
        fan.setAvailabilitySchedule(hvac_op_sch)
      elsif fan_type == 'Cycling'
        fan = create_fan_by_name(model,
                                 'CRAC_Cycling_fan',
                                 fan_name: "#{air_loop.name} Fan")
        fan.setAvailabilitySchedule(hvac_op_sch)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Fan type '#{fan_type}' not recognized, cannot add CRAC.")
        return []
      end

      # create cooling coil
      case cooling_type
      when 'Two Speed DX AC'
        clg_coil = create_coil_cooling_dx_two_speed(model,
                                                    name: "#{air_loop.name} 2spd DX AC Clg Coil")
      when 'Single Speed DX AC'
        clg_coil = create_coil_cooling_dx_single_speed(model,
                                                       name: "#{air_loop.name} 1spd DX AC Clg Coil",
                                                       type: 'PSZ-AC')
      else
        clg_coil = nil
      end

      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.setName("#{air_loop.name} OA System Controller")
      oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
      oa_system.setName("#{air_loop.name} OA System")

      # CRAC can't operate properly at very low ambient temperature (E+ limit: -25C)
      # As a result, the room temperature will rise to HUGE
      # Adding economizer can solve the issue, but economizer is not added until first sizing done, which causes severe error during sizing
      # To solve the issue, add economizer here for cold climates
      # select the climate zones with winter design temperature lower than -20C (for safer)
      cold_climates = ['ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A',
                         'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B' ]
      if cold_climates.include? climate_zone
        # Determine the economizer type in the prototype buildings, which depends on climate zone.
        economizer_type = model_economizer_type(model, climate_zone)
        oa_controller.setEconomizerControlType(economizer_type)

        # Check that the economizer type set by the prototypes
        # is not prohibited by code.  If it is, change to no economizer.
        unless air_loop_hvac_economizer_type_allowable?(air_loop, climate_zone)
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.Model', "#{air_loop.name} is required to have an economizer, but the type chosen, #{economizer_type} is prohibited by code for , climate zone #{climate_zone}.  Economizer type will be switched to No Economizer.")
          oa_controller.setEconomizerControlType('NoEconomizer')
        end
      end

      # add humidifier to control minimum RH
      humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
      humidifier.autosizeRatedCapacity
      humidifier.autosizeRatedPower
      humidifier.setName("#{air_loop.name} Electric Steam Humidifier")

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode

      if fan_location == 'DrawThrough'
        # Add the fan
        fan.addToNode(supply_inlet_node) unless fan.nil?
        # Add the humidifier
        humidifier.addToNode(supply_inlet_node) unless humidifier.nil?
        # Add the cooling coil
        clg_coil.addToNode(supply_inlet_node) unless clg_coil.nil?

      elsif fan_location == 'BlowThrough'
        # Add the humidifier
        humidifier.addToNode(supply_inlet_node) unless humidifier.nil?
        # Add the cooling coil
        clg_coil.addToNode(supply_inlet_node) unless clg_coil.nil?
        # Add the fan
        fan.addToNode(supply_inlet_node) unless fan.nil?

      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Invalid fan location')
        return false
      end

      # add humidifying setpoint
      humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
      humidity_spm.setControlZone(zone)
      humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)

      humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
      humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'DataCenter Humidity Setpoint Schedule'))
      zone.setZoneControlHumidistat(humidistat)

      # Add a setpoint manager for cooling to control the supply air temperature based on the needs of this zone
      # per ASHRAE 90.4-2016, recommended range of data center supply air temperature is 18-27C
      setpoint_mgr_cooling = OpenStudio::Model::SetpointManagerSingleZoneCooling.new(model)
      setpoint_mgr_cooling.setMinimumSupplyAirTemperature(dsgn_temps['prehtg_dsgn_sup_air_temp_c'])
      setpoint_mgr_cooling.setMaximumSupplyAirTemperature(dsgn_temps['preclg_dsgn_sup_air_temp_c'])

      # Add the OA system
      oa_system.addToNode(supply_inlet_node)

      # Attach the setpoint manager to the supply outlet node
      setpoint_mgr_cooling.addToNode(air_loop.supplyOutletNode)

      # set air loop availability controls
      air_loop.setAvailabilitySchedule(hvac_op_sch)

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      diffuser = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{air_loop.name} Diffuser")
      diffuser.setZoneMinimumAirFlowInputMethod('Constant')
      diffuser.setConstantMinimumAirFlowFraction(0.1)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      air_loops << air_loop
    end

    return air_loops
  end

  # Creates a CRAH system for larger size data center and adds it to the model.
  #
  # @param chilled_water_loop [string]
  # @param system_name [String] the name of the system, or nil in which case it will be defaulted
  # @param thermal_zones [String] zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule
  # or nil in which case will be defaulted to always on
  # @param oa_damper_sch [Double] name of the oa damper schedule,
  # or nil in which case will be defaulted to always open
  # no heating
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] an array of the resulting CRAH air loops
  def model_add_crah(model,
                     thermal_zones,
                     system_name: nil,
                     chilled_water_loop: nil,
                     hvac_op_sch: nil,
                     oa_damper_sch: nil,
                     return_plenum: nil)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding CRAH system for #{thermal_zones.size} zones data center.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # air handler
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    if system_name.nil?
      air_loop.setName("Data Center CRAH")
    else
      air_loop.setName(system_name)
    end

    # default design temperatures across all air loops
    dsgn_temps = standard_design_sizing_temperatures

    # adjusted zone design heating temperature for data center psz_ac
    dsgn_temps['prehtg_dsgn_sup_air_temp_f'] = 64.4
    dsgn_temps['preclg_dsgn_sup_air_temp_f'] = 80.6
    dsgn_temps['htg_dsgn_sup_air_temp_f'] = 72.5
    dsgn_temps['clg_dsgn_sup_air_temp_f'] = 72.5
    dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = dsgn_temps['htg_dsgn_sup_air_temp_f']
    dsgn_temps['zn_clg_dsgn_sup_air_temp_f'] = dsgn_temps['clg_dsgn_sup_air_temp_f']
    dsgn_temps['prehtg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['prehtg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['preclg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['preclg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['htg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['clg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['clg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = dsgn_temps['htg_dsgn_sup_air_temp_c']
    dsgn_temps['zn_clg_dsgn_sup_air_temp_c'] = dsgn_temps['clg_dsgn_sup_air_temp_c']

    # default design settings used across all air loops
    sizing_system = adjust_sizing_system(air_loop, dsgn_temps, min_sys_airflow_ratio: 0.3)

    # Add a setpoint manager for cooling to control the supply air temperature based on the needs of this zone
    # per ASHRAE 90.4-2016, recommended range of data center supply air temperature is 18-27C
    setpoint_mgr_cooling = OpenStudio::Model::SetpointManagerSingleZoneCooling.new(model)
    setpoint_mgr_cooling.setMinimumSupplyAirTemperature(dsgn_temps['prehtg_dsgn_sup_air_temp_c'])
    setpoint_mgr_cooling.setMaximumSupplyAirTemperature(dsgn_temps['preclg_dsgn_sup_air_temp_c'])
    setpoint_mgr_cooling.setName("CRAH supply air setpoint manager")
    setpoint_mgr_cooling.addToNode(air_loop.supplyOutletNode)

    # create fan
    # ConstantVolume: Packaged Rooftop Single Zone Air conditioner
    # Cycling: Unitary System
    # CyclingHeatPump: Unitary Heat Pump system
    fan = create_fan_by_name(model,
                             'VAV_System_Fan',
                             fan_name: "#{air_loop.name} Fan")
    fan.setAvailabilitySchedule(hvac_op_sch)
    fan.addToNode(air_loop.supplyInletNode)

    # add humidifier to control minimum RH
    humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
    humidifier.autosizeRatedCapacity
    humidifier.autosizeRatedPower
    humidifier.setName("#{air_loop.name} Electric Steam Humidifier")
    humidifier.addToNode(air_loop.supplyInletNode)

    # cooling coil
    if chilled_water_loop.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No chilled water plant loop supplied for CRAH system')
      return false
    else
      create_coil_cooling_water(model,
                                chilled_water_loop,
                                air_loop_node: air_loop.supplyInletNode,
                                name: "#{air_loop.name} Water Clg Coil",
                                schedule: hvac_op_sch,
                                design_outlet_air_temperature: dsgn_temps['clg_dsgn_sup_air_temp_c'])
    end

    # outdoor air intake system
    oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_intake_controller.setName("#{air_loop.name} OA Controller")
    oa_intake_controller.setMinimumLimitType('FixedMinimum')
    oa_intake_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_intake_controller.autosizeMinimumOutdoorAirFlowRate

    controller_mv = oa_intake_controller.controllerMechanicalVentilation
    controller_mv.setName("#{air_loop.name} Vent Controller")
    controller_mv.setSystemOutdoorAirMethod('ZoneSum')

    oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
    oa_intake.setName("#{air_loop.name} OA System")
    oa_intake.addToNode(air_loop.supplyInletNode)

    # set air loop availability controls
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    # hook the CRAH system to each zone
    thermal_zones.each do |zone|

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      diffuser = OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{zone.name} VAV terminal")
      diffuser.setZoneMinimumAirFlowInputMethod('Constant')
      diffuser.setConstantMinimumAirFlowFraction(0.1)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      # Zone sizing
      sizing_zone = zone.sizingZone
      # per ASHRAE 90.4, recommended range of data center supply air temperature is 18-27C, pick the mean value 22.5C as prototype
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])

      humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
      humidity_spm.setControlZone(zone)
      humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)

      humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
      humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'DataCenter Humidity Setpoint Schedule'))
      zone.setZoneControlHumidistat(humidistat)

      unless return_plenum.nil?
        zone.setReturnPlenum(return_plenum)
      end
    end

    return air_loop
  end


  # Creates a split DX AC system for each zone and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param cooling_type [String] valid choices are Two Speed DX AC, Single Speed DX AC, Single Speed Heat Pump
  # @param heating_type [String] valid choices are Gas, Single Speed Heat Pump
  # @param supplemental_heating_type [String] valid choices are Electric, Gas
  # @param fan_type [String] valid choices are ConstantVolume, Cycling
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param oa_damper_sch [String] name of the oa damper schedule, or nil in which case will be defaulted to always open
  # @param econ_max_oa_frac_sch [String] name of the economizer maximum outdoor air fraction schedule
  # @return [OpenStudio::Model::AirLoopHVAC] the resulting split AC air loop
  def model_add_split_ac(model,
                         thermal_zones,
                         cooling_type: 'Two Speed DX AC',
                         heating_type: 'Single Speed Heat Pump',
                         supplemental_heating_type: 'Gas',
                         fan_type: 'Cycling',
                         hvac_op_sch: nil,
                         oa_damper_sch: nil,
                         econ_max_oa_frac_sch: nil)

    # create a split AC for each group of thermal zones
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    thermal_zones_name = (thermal_zones.map { |z| z.name }).join(' - ')
    air_loop.setName("#{thermal_zones_name} SAC")

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # oa damper schedule
    if oa_damper_sch.nil?
      oa_damper_sch = model.alwaysOnDiscreteSchedule
    else
      oa_damper_sch = model_add_schedule(model, oa_damper_sch)
    end

    # default design temperatures used across all air loops
    dsgn_temps = standard_design_sizing_temperatures

    # adjusted zone design heating temperature for split_ac
    dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 122.0
    dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['htg_dsgn_sup_air_temp_f'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_f']
    dsgn_temps['htg_dsgn_sup_air_temp_c'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_c']

    # default design settings used across all air loops
    sizing_system = adjust_sizing_system(air_loop, dsgn_temps, min_sys_airflow_ratio: 1.0, sizing_option: 'NonCoincident')

    # air handler controls
    # add a setpoint manager single zone reheat to control the supply air temperature
    setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
    setpoint_mgr_single_zone_reheat.setName("#{air_loop.name} Setpoint Manager SZ Reheat")
    setpoint_mgr_single_zone_reheat.setControlZone(thermal_zones[0])
    setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
    setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
    setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

    # add the components to the air loop in order from closest to zone to furthest from zone
    # create fan
    fan = nil
    if fan_type == 'ConstantVolume'
      fan = create_fan_by_name(model,
                               'Split_AC_CAV_Fan',
                               fan_name: "#{air_loop.name} Fan",
                               end_use_subcategory: 'CAV System Fans')
      fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    elsif fan_type == 'Cycling'
      fan = create_fan_by_name(model,
                               'Split_AC_Cycling_Fan',
                               fan_name: "#{air_loop.name} Fan",
                               end_use_subcategory: 'CAV System Fans')
      fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "fan_type #{fan_type} invalid for split AC system.")
    end
    fan.addToNode(air_loop.supplyInletNode) unless fan.nil?

    # create supplemental heating coil
    if supplemental_heating_type == 'Electric'
      create_coil_heating_electric(model,
                                   air_loop_node: air_loop.supplyInletNode,
                                   name: "#{air_loop.name} PSZ-AC Electric Backup Htg Coil")
    elsif supplemental_heating_type == 'Gas'
      create_coil_heating_gas(model,
                              air_loop_node: air_loop.supplyInletNode,
                              name: "#{air_loop.name} PSZ-AC Gas Backup Htg Coil")
    end

    # create heating coil
    if heating_type == 'Gas'
      htg_coil = create_coil_heating_gas(model,
                                         air_loop_node: air_loop.supplyInletNode,
                                         name: "#{air_loop.name} Gas Htg Coil")
      htg_part_load_fraction_correlation = OpenStudio::Model::CurveCubic.new(model)
      htg_part_load_fraction_correlation.setCoefficient1Constant(0.8)
      htg_part_load_fraction_correlation.setCoefficient2x(0.2)
      htg_part_load_fraction_correlation.setCoefficient3xPOW2(0.0)
      htg_part_load_fraction_correlation.setCoefficient4xPOW3(0.0)
      htg_part_load_fraction_correlation.setMinimumValueofx(0.0)
      htg_part_load_fraction_correlation.setMaximumValueofx(1.0)
      htg_coil.setPartLoadFractionCorrelationCurve(htg_part_load_fraction_correlation)
    elsif heating_type == 'Single Speed Heat Pump'
      create_coil_heating_dx_single_speed(model,
                                          air_loop_node: air_loop.supplyInletNode,
                                          name: "#{air_loop.name} HP Htg Coil")
    end

    # create cooling coil
    if cooling_type == 'Two Speed DX AC'
      create_coil_cooling_dx_two_speed(model,
                                       air_loop_node: air_loop.supplyInletNode,
                                       name: "#{air_loop.name} 2spd DX AC Clg Coil")
    elsif cooling_type == 'Single Speed DX AC'
      create_coil_cooling_dx_single_speed(model,
                                          air_loop_node: air_loop.supplyInletNode,
                                          name: "#{air_loop.name} 1spd DX AC Clg Coil", type: 'Split AC')
    elsif cooling_type == 'Single Speed Heat Pump'
      create_coil_cooling_dx_single_speed(model,
                                          air_loop_node: air_loop.supplyInletNode,
                                          name: "#{air_loop.name} 1spd DX HP Clg Coil", type: 'Heat Pump')
    end

    # create outdoor air controller
    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_controller.setName("#{air_loop.name} OA System Controller")
    oa_controller.setMinimumOutdoorAirSchedule(oa_damper_sch)
    oa_controller.autosizeMinimumOutdoorAirFlowRate
    oa_controller.resetEconomizerMinimumLimitDryBulbTemperature
    oa_controller.setMaximumFractionofOutdoorAirSchedule(model_add_schedule(model, econ_max_oa_frac_sch)) unless econ_max_oa_frac_sch.nil?
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
    oa_system.setName("#{air_loop.name} OA System")
    oa_system.addToNode(air_loop.supplyInletNode)

    # set air loop availability controls after oa system added
    air_loop.setAvailabilitySchedule(hvac_op_sch)

    # create a diffuser and attach the zone/diffuser pair to the air loop
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding #{zone.name} to split DX AC system.")

      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{zone.name} SAC Diffuser")
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)
      sizing_zone.setZoneHeatingDesignSupplyAirHumidityRatio(0.008)
    end

    return air_loop
  end

  # Creates a PTAC system for each zone and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param cooling_type [String] valid choices are Two Speed DX AC, Single Speed DX AC
  # @param heating_type [String] valid choices are NaturalGas, Electricity, Water, nil (no heat)
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] hot water loop to connect heating coil to. Set to nil for heating types besides water
  # @param fan_type [String] valid choices are ConstantVolume, Cycling
  # @return [Array<OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner>] an array of the resulting PTACs
  def model_add_ptac(model,
                     thermal_zones,
                     cooling_type: 'Two Speed DX AC',
                     heating_type: 'Gas',
                     hot_water_loop: nil,
                     fan_type: 'ConstantVolume')

    # default design temperatures used across all air loops
    dsgn_temps = standard_design_sizing_temperatures
    unless hot_water_loop.nil?
      hw_temp_c = hot_water_loop.sizingPlant.designLoopExitTemperature
      hw_delta_t_k = hot_water_loop.sizingPlant.loopDesignTemperatureDifference
    end

    # adjusted zone design temperatures for ptac
    dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 122.0
    dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['zn_clg_dsgn_sup_air_temp_f'] = 57.0
    dsgn_temps['zn_clg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_clg_dsgn_sup_air_temp_f'], 'F', 'C').get

    # make a PTAC for each zone
    ptacs = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PTAC for #{zone.name}.")

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)
      sizing_zone.setZoneHeatingDesignSupplyAirHumidityRatio(0.008)

      # add fan
      if fan_type == 'ConstantVolume'
        fan = create_fan_by_name(model,
                                 'PTAC_CAV_Fan',
                                 fan_name: "#{zone.name} PTAC Fan")
        fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      elsif fan_type == 'Cycling'
        fan = create_fan_by_name(model,
                                 'PTAC_Cycling_Fan',
                                 fan_name: "#{zone.name} PTAC Fan")
        fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "ptac_fan_type of #{fan_type} is not recognized.")
      end

      # add heating coil
      case heating_type
      when 'NaturalGas', 'Gas'
        htg_coil = create_coil_heating_gas(model,
                                           name: "#{zone.name} PTAC Gas Htg Coil")
      when 'Electricity', 'Electric'
        htg_coil = create_coil_heating_electric(model,
                                                name: "#{zone.name} PTAC Electric Htg Coil")
      when nil
        htg_coil = create_coil_heating_electric(model,
                                                name: "#{zone.name} PTAC No Heat",
                                                schedule: model.alwaysOffDiscreteSchedule,
                                                nominal_capacity: 0)
      when 'Water'
        if hot_water_loop.nil?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No hot water plant loop supplied')
          return false
        end
        htg_coil = create_coil_heating_water(model,
                                             hot_water_loop,
                                             name: "#{hot_water_loop.name} Water Htg Coil",
                                             rated_inlet_water_temperature: hw_temp_c,
                                             rated_outlet_water_temperature: (hw_temp_c - hw_delta_t_k))
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "ptac_heating_type of #{heating_type} is not recognized.")
      end

      # add cooling coil
      if cooling_type == 'Two Speed DX AC'
        clg_coil = create_coil_cooling_dx_two_speed(model,
                                                    name: "#{zone.name} PTAC 2spd DX AC Clg Coil")
      elsif cooling_type == 'Single Speed DX AC'
        clg_coil = create_coil_cooling_dx_single_speed(model,
                                                       name: "#{zone.name} PTAC 1spd DX AC Clg Coil",
                                                       type: 'PTAC')
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "ptac_cooling_type of #{cooling_type} is not recognized.")
      end

      # wrap coils in a PTAC system
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
        ptac_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      end
      ptac_system.addToThermalZone(zone)
      ptacs << ptac_system
    end

    return ptacs
  end

  # Creates a PTHP system for each zone and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param fan_type [String] valid choices are ConstantVolume, Cycling
  # @return [Array<OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner>] an array of the resulting PTACs.
  def model_add_pthp(model,
                     thermal_zones,
                     fan_type: 'Cycling')

    # default design temperatures used across all air loops
    dsgn_temps = standard_design_sizing_temperatures

    # adjusted zone design temperatures for pthp
    dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 122.0
    dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['zn_clg_dsgn_sup_air_temp_f'] = 57.0
    dsgn_temps['zn_clg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_clg_dsgn_sup_air_temp_f'], 'F', 'C').get

    # make a PTHP for each zone
    pthps = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding PTHP for #{zone.name}.")

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)
      sizing_zone.setZoneHeatingDesignSupplyAirHumidityRatio(0.008)

      # add fan
      if fan_type == 'ConstantVolume'
        fan = create_fan_by_name(model,
                                 'PTAC_CAV_Fan',
                                 fan_name: "#{zone.name} PTAC Fan")
        fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      elsif fan_type == 'Cycling'
        fan = create_fan_by_name(model,
                                 'PTAC_Cycling_Fan',
                                 fan_name: "#{zone.name} PTAC Fan")
        fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "PTHP fan_type of #{fan_type} is not recognized.")
        return false
      end

      # add heating coil
      htg_coil = create_coil_heating_dx_single_speed(model,
                                                     name: "#{zone.name} PTHP Htg Coil")
      # add cooling coil
      clg_coil = create_coil_cooling_dx_single_speed(model,
                                                     name: "#{zone.name} PTHP Clg Coil",
                                                     type: 'Heat Pump')
      # supplemental heating coil
      supplemental_htg_coil = create_coil_heating_electric(model,
                                                           name: "#{zone.name} PTHP Supplemental Htg Coil")
      # wrap coils in a PTHP system
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
        pthp_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      end
      pthp_system.addToThermalZone(zone)
      pthps << pthp_system
    end

    return pthps
  end

  # Creates a unit heater for each zone and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param hvac_op_sch [String] name of the HVAC operation schedule or nil in which case will be defaulted to always on
  # @param fan_control_type [String] valid choices are OnOff, ConstantVolume, VariableVolume
  # @param fan_pressure_rise [Double] fan pressure rise, inH2O
  # @param heating_type [String] valid choices are NaturalGas, Gas, Electricity, Electric, DistrictHeating
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] hot water loop to connect to the heating coil
  # @param rated_inlet_water_temperature [Double] rated inlet water temperature in degrees Fahrenheit, default is 180F
  # @param rated_outlet_water_temperature [Double] rated outlet water temperature in degrees Fahrenheit, default is 160F
  # @param rated_inlet_air_temperature [Double] rated inlet air temperature in degrees Fahrenheit, default is 60F
  # @param rated_outlet_air_temperature [Double] rated outlet air temperature in degrees Fahrenheit, default is 100F
  # @return [Array<OpenStudio::Model::ZoneHVACUnitHeater>] an array of the resulting unit heaters.
  def model_add_unitheater(model,
                           thermal_zones,
                           hvac_op_sch: nil,
                           fan_control_type: 'ConstantVolume',
                           fan_pressure_rise: 0.2,
                           heating_type: nil,
                           hot_water_loop: nil,
                           rated_inlet_water_temperature: 180.0,
                           rated_outlet_water_temperature: 160.0,
                           rated_inlet_air_temperature: 60.0,
                           rated_outlet_air_temperature: 104.0)

    # hvac operation schedule
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # set defaults if nil
    fan_control_type = 'ConstantVolume' if fan_control_type.nil?
    fan_pressure_rise = 0.2 if fan_pressure_rise.nil?

    # default design temperatures used across all air loops
    dsgn_temps = standard_design_sizing_temperatures

    # adjusted zone design heating temperature for unit heater
    dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 122.0
    dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get

    # make a unit heater for each zone
    unit_heaters = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding unit heater for #{zone.name}.")

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])

      # add fan
      fan = create_fan_by_name(model,
                               'Unit_Heater_Fan',
                               fan_name: "#{zone.name} UnitHeater Fan",
                               pressure_rise: fan_pressure_rise)
      fan.setAvailabilitySchedule(hvac_op_sch)

      # add heating coil
      if heating_type == 'NaturalGas' || heating_type == 'Gas'
        htg_coil = create_coil_heating_gas(model,
                                           name: "#{zone.name} UnitHeater Gas Htg Coil",
                                           schedule: hvac_op_sch)
      elsif heating_type == 'Electricity' || heating_type == 'Electric'
        htg_coil = create_coil_heating_electric(model,
                                                name: "#{zone.name} UnitHeater Electric Htg Coil",
                                                schedule: hvac_op_sch)
      elsif heating_type == 'DistrictHeating' && !hot_water_loop.nil?
        # control temperature for hot water loop
        if rated_inlet_water_temperature.nil?
          rated_inlet_water_temperature_c = OpenStudio.convert(180.0, 'F', 'C').get
        else
          rated_inlet_water_temperature_c = OpenStudio.convert(rated_inlet_water_temperature, 'F', 'C').get
        end
        if rated_outlet_water_temperature.nil?
          rated_outlet_water_temperature_c = OpenStudio.convert(160.0, 'F', 'C').get
        else
          rated_outlet_water_temperature_c = OpenStudio.convert(rated_outlet_water_temperature, 'F', 'C').get
        end
        if rated_inlet_air_temperature.nil?
          rated_inlet_air_temperature_c = OpenStudio.convert(60.0, 'F', 'C').get
        else
          rated_inlet_air_temperature_c = OpenStudio.convert(rated_inlet_air_temperature, 'F', 'C').get
        end
        if rated_outlet_air_temperature.nil?
          rated_outlet_air_temperature_c = OpenStudio.convert(104.0, 'F', 'C').get
        else
          rated_outlet_air_temperature_c = OpenStudio.convert(rated_outlet_air_temperature, 'F', 'C').get
        end
        htg_coil = create_coil_heating_water(model,
                                             hot_water_loop,
                                             name: "#{zone.name} UnitHeater Water Htg Coil",
                                             rated_inlet_water_temperature: rated_inlet_water_temperature_c,
                                             rated_outlet_water_temperature: rated_outlet_water_temperature_c,
                                             rated_inlet_air_temperature: rated_inlet_air_temperature_c,
                                             rated_outlet_air_temperature: rated_outlet_air_temperature_c)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', 'No heating type was found when adding unit heater; no unit heater will be created.')
        return false
      end

      # create unit heater
      unit_heater = OpenStudio::Model::ZoneHVACUnitHeater.new(model,
                                                              hvac_op_sch,
                                                              fan,
                                                              htg_coil)
      unit_heater.setName("#{zone.name} Unit Heater")
      unit_heater.setFanControlType(fan_control_type)
      unit_heater.addToThermalZone(zone)
      unit_heaters << unit_heater
    end

    return unit_heaters
  end

  # Creates a high temp radiant heater for each zone and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @param heating_type [String] valid choices are Gas, Electric
  # @param combustion_efficiency [Double] combustion efficiency as decimal
  # @return [Array<OpenStudio::Model::ZoneHVACHighTemperatureRadiant>] an
  # array of the resulting radiant heaters.
  def model_add_high_temp_radiant(model,
                                  thermal_zones,
                                  heating_type: 'Gas',
                                  combustion_efficiency: 0.8)

    # Make a high temp radiant heater for each zone
    radiant_heaters = []
    thermal_zones.each do |zone|
      high_temp_radiant = OpenStudio::Model::ZoneHVACHighTemperatureRadiant.new(model)
      high_temp_radiant.setName("#{zone.name} High Temp Radiant")

      if heating_type.nil?
        high_temp_radiant.setFuelType('Gas')
      else
        high_temp_radiant.setFuelType(heating_type)
      end

      if combustion_efficiency.nil?
        if heating_type == 'Gas'
          high_temp_radiant.setCombustionEfficiency(0.8)
        elsif heating_type == 'Electric'
          high_temp_radiant.setCombustionEfficiency(1.0)
        end
      else
        high_temp_radiant.setCombustionEfficiency(combustion_efficiency)
      end

      # set defaults
      high_temp_radiant.setTemperatureControlType(control_type)
      high_temp_radiant.setFractionofInputConvertedtoRadiantEnergy(0.8)
      high_temp_radiant.setHeatingThrottlingRange(2)
      high_temp_radiant.addToThermalZone(zone)
      radiant_heaters << high_temp_radiant
    end

    return radiant_heaters
  end

  # Creates an evaporative cooler for each zone and adds it to the model.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to connect to this system
  # @return [Array<OpenStudio::Model::AirLoopHVAC>] the resulting evaporative coolers
  def model_add_evap_cooler(model,
                            thermal_zones)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding evaporative coolers for #{thermal_zones.size} zones.")
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Model.Model', "---#{zone.name}")
    end

    # default design temperatures used across all air loops
    dsgn_temps = standard_design_sizing_temperatures

    # adjusted design temperatures for evap cooler
    dsgn_temps['clg_dsgn_sup_air_temp_f'] = 70.0
    dsgn_temps['clg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['clg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['max_clg_dsgn_sup_air_temp_f'] = 78.0
    dsgn_temps['max_clg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['max_clg_dsgn_sup_air_temp_f'], 'F', 'C').get
    dsgn_temps['approach_r'] = 3.0 # wetbulb approach temperature
    dsgn_temps['approach_k'] = OpenStudio.convert(dsgn_temps['approach_r'], 'R', 'K').get

    # EMS programs
    programs = []

    # Make an evap cooler for each zone
    evap_coolers = []
    thermal_zones.each do |zone|
      zone_name_clean = zone.name.get.delete(':')

      # Air loop
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName("#{zone_name_clean} Evaporative Cooler")

      # default design settings used across all air loops
      sizing_system = adjust_sizing_system(air_loop, dsgn_temps)

      # air handler controls
      # setpoint follows OAT WetBulb
      evap_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
      evap_stpt_manager.setName("#{dsgn_temps['approach_r']} F above OATwb")
      evap_stpt_manager.setReferenceTemperatureType('OutdoorAirWetBulb')
      evap_stpt_manager.setMaximumSetpointTemperature(dsgn_temps['max_clg_dsgn_sup_air_temp_c'])
      evap_stpt_manager.setMinimumSetpointTemperature(dsgn_temps['clg_dsgn_sup_air_temp_c'])
      evap_stpt_manager.setOffsetTemperatureDifference(dsgn_temps['approach_k'])
      evap_stpt_manager.addToNode(air_loop.supplyOutletNode)

      # Schedule to control the airloop availability
      air_loop_avail_sch = OpenStudio::Model::ScheduleConstant.new(model)
      air_loop_avail_sch.setName("#{air_loop.name} Availability Sch")
      air_loop_avail_sch.setValue(1)
      air_loop.setAvailabilitySchedule(air_loop_avail_sch)

      # EMS to turn on Evap Cooler if there is a cooling load in the target zone.
      # Without this EMS, the airloop runs 24/7-365 even when there is no load in the zone.

      # Create a sensor to read the zone load
      zn_load_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,
                                                                           'Zone Predicted Sensible Load to Cooling Setpoint Heat Transfer Rate')
      zn_load_sensor.setName("#{zone_name_clean.to_s.gsub(/[ +-.]/,'_')} Clg Load Sensor")
      zn_load_sensor.setKeyName(zone.handle.to_s)

      # Create an actuator to set the airloop availability
      air_loop_avail_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(air_loop_avail_sch,
                                                                                      'Schedule:Constant',
                                                                                      'Schedule Value')
      air_loop_avail_actuator.setName("#{air_loop.name.to_s.gsub(/[ +-.]/,'_')} Availability Actuator")

      # Create a program to turn on Evap Cooler if
      # there is a cooling load in the target zone.
      # Load < 0.0 is a cooling load.
      avail_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
      avail_program.setName("#{air_loop.name.to_s.gsub(/[ +-.]/,'_')} Availability Control")
      avail_program_body = <<-EMS
        IF #{zn_load_sensor.handle} < 0.0
          SET #{air_loop_avail_actuator.handle} = 1
        ELSE
          SET #{air_loop_avail_actuator.handle} = 0
        ENDIF
      EMS
      avail_program.setBody(avail_program_body)

      programs << avail_program

      # Direct Evap Cooler
      # TODO: better assumptions for evap cooler performance and fan pressure rise
      evap = OpenStudio::Model::EvaporativeCoolerDirectResearchSpecial.new(model, model.alwaysOnDiscreteSchedule)
      evap.setName("#{zone.name} Evap Media")
      evap.autosizePrimaryAirDesignFlowRate
      evap.addToNode(air_loop.supplyInletNode)

      # Fan (cycling), must be inside unitary system to cycle on airloop
      fan = create_fan_by_name(model,
                               'Evap_Cooler_Supply_Fan',
                               fan_name: "#{zone.name} Evap Cooler Supply Fan")
      fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)

      # Dummy zero-capacity cooling coil
      clg_coil = create_coil_cooling_dx_single_speed(model,
                                                     name: 'Dummy Always Off DX Coil',
                                                     schedule: model.alwaysOffDiscreteSchedule)
      unitary_system = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary_system.setName("#{zone.name} Evap Cooler Cycling Fan")
      unitary_system.setSupplyFan(fan)
      unitary_system.setCoolingCoil(clg_coil)
      unitary_system.setControllingZoneorThermostatLocation(zone)
      unitary_system.setMaximumSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      unitary_system.setFanPlacement('BlowThrough')
      unitary_system.setSupplyAirFlowRateMethodDuringCoolingOperation('SupplyAirFlowRate')
      unitary_system.setSupplyAirFlowRateMethodDuringHeatingOperation('SupplyAirFlowRate')
      unitary_system.setSupplyAirFlowRateMethodWhenNoCoolingorHeatingisRequired('SupplyAirFlowRate')
      unitary_system.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      unitary_system.addToNode(air_loop.supplyInletNode)

      # Outdoor air intake system
      oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_intake_controller.setName("#{air_loop.name} OA Controller")
      oa_intake_controller.setMinimumLimitType('FixedMinimum')
      oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
      oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
      oa_intake_controller.setMinimumFractionofOutdoorAirSchedule(model.alwaysOnDiscreteSchedule)
      controller_mv = oa_intake_controller.controllerMechanicalVentilation
      controller_mv.setName("#{air_loop.name} Vent Controller")
      controller_mv.setSystemOutdoorAirMethod('ZoneSum')

      oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
      oa_intake.setName("#{air_loop.name} OA System")
      oa_intake.addToNode(air_loop.supplyInletNode)

      # make an air terminal for the zone
      air_terminal = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      air_terminal.setName("#{zone.name} Air Terminal")

      # attach new terminal to the zone and to the airloop
      air_loop.addBranchForZone(zone, air_terminal.to_StraightComponent)

      sizing_zone = zone.sizingZone
      sizing_zone.setCoolingDesignAirFlowMethod('DesignDay')
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])

      evap_coolers << air_loop
    end

    # Create a programcallingmanager
    avail_pcm = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    avail_pcm.setName('EvapCoolerAvailabilityProgramCallingManager')
    avail_pcm.setCallingPoint('AfterPredictorAfterHVACManagers')
    programs.each do |program|
      avail_pcm.addProgram(program)
    end

    return evap_coolers
  end

  # Adds hydronic or electric baseboard heating to each zone.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add baseboards to.
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] The hot water loop that serves the baseboards.  If nil, baseboards are electric.
  # @return [Array<OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric, OpenStudio::Model::ZoneHVACBaseboardConvectiveWater>]
  #   array of baseboard heaters.
  def model_add_baseboard(model,
                          thermal_zones,
                          hot_water_loop: nil)

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

  # Adds Variable Refrigerant Flow system and terminal units for each zone
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add fan coil units
  # @return [Array<OpenStudio::Model::ZoneHVACTerminalUnitVariableRefrigerantFlow>] array of vrf units.
  def model_add_vrf(model,
                    thermal_zones)

    # create vrf outdoor unit
    master_zone = thermal_zones[0]
    vrf_outdoor_unit = create_air_conditioner_variable_refrigerant_flow(model,
                                                                        name: "#{thermal_zones.size} Zone VRF System",
                                                                        master_zone: master_zone)

    # default design temperatures used across all air loops
    dsgn_temps = standard_design_sizing_temperatures

    vrfs = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding vrf unit for #{zone.name}.")

      # zone sizing
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])

      # add vrf terminal unit
      vrf_terminal_unit = OpenStudio::Model::ZoneHVACTerminalUnitVariableRefrigerantFlow.new(model)
      vrf_terminal_unit.setName("#{zone.name} VRF Terminal Unit")
      vrf_terminal_unit.addToThermalZone(zone)
      vrf_terminal_unit.setTerminalUnitAvailabilityschedule(model.alwaysOnDiscreteSchedule)

      # no outdoor air assumed
      vrf_terminal_unit.setOutdoorAirFlowRateDuringCoolingOperation(0.0)
      vrf_terminal_unit.setOutdoorAirFlowRateDuringHeatingOperation(0.0)
      vrf_terminal_unit.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(0.0)

      # set fan variables
      # always off denotes cycling fan
      vrf_terminal_unit.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      vrf_fan = vrf_terminal_unit.supplyAirFan.to_FanOnOff.get
      vrf_fan.setPressureRise(300.0)
      vrf_fan.setMotorEfficiency(0.8)
      vrf_fan.setFanEfficiency(0.6)
      vrf_fan.setName("#{zone.name} VRF Unit Cycling Fan")

      # add to main condensing unit
      vrf_outdoor_unit.addTerminal(vrf_terminal_unit)
    end

    return vrfs
  end

  # Adds four pipe fan coil units to each zone.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add fan coil units
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] the chilled water loop that serves the fan coils.
  # @param hot_water_loop [OpenStudio::Model::PlantLoop] the hot water loop that serves the fan coils.
  #   If nil, a zero-capacity, electric heating coil set to Always-Off will be included in the unit.
  # @param ventilation [Bool] If true, ventilation will be supplied through the unit.  If false,
  #   no ventilation will be supplied through the unit, with the expectation that it will be provided by a DOAS or separate system.
  # @return [Array<OpenStudio::Model::ZoneHVACFourPipeFanCoil>] array of fan coil units.
  def model_add_four_pipe_fan_coil(model,
                                   thermal_zones,
                                   chilled_water_loop,
                                   hot_water_loop: nil,
                                   ventilation: false)

    # default design temperatures used across all air loops
    dsgn_temps = standard_design_sizing_temperatures

    # make a fan coil unit for each zone
    fcus = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding fan coil for #{zone.name}.")
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(dsgn_temps['zn_clg_dsgn_sup_air_temp_c'])
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])

      if chilled_water_loop
        fcu_clg_coil = create_coil_cooling_water(model,
                                                 chilled_water_loop,
                                                 name: "#{zone.name} FCU Cooling Coil")
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', 'Fan coil units require a chilled water loop, but none was provided.')
        return false
      end

      if hot_water_loop
        fcu_htg_coil = create_coil_heating_water(model,
                                                 hot_water_loop,
                                                 name: "#{zone.name} FCU Heating Coil",
                                                 rated_outlet_air_temperature: dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      else
        # Zero-capacity, always-off electric heating coil
        fcu_htg_coil = create_coil_heating_electric(model,
                                                    name: "#{zone.name} No Heat",
                                                    schedule: model.alwaysOffDiscreteSchedule,
                                                    nominal_capacity: 0.0)
      end

      fcu_fan = create_fan_by_name(model,
                                   'Fan_Coil_Fan',
                                   fan_name: "#{zone.name} Fan Coil fan",
                                   end_use_subcategory: 'FCU Fans')
      fcu_fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      fcu_fan.autosizeMaximumFlowRate

      fcu = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model,
                                                           model.alwaysOnDiscreteSchedule,
                                                           fcu_fan,
                                                           fcu_clg_coil,
                                                           fcu_htg_coil)
      fcu.setName("#{zone.name} FCU")
      fcu.setCapacityControlMethod('CyclingFan')
      fcu.autosizeMaximumSupplyAirFlowRate
      unless ventilation
        fcu.setMaximumOutdoorAirFlowRate(0.0)
      end
      fcu.addToThermalZone(zone)
      fcus << fcu
    end

    return fcus
  end

  # Adds a window air conditioner to each zone.
  # Code adapted from: https://github.com/NREL/OpenStudio-BEopt/blob/master/measures/ResidentialHVACRoomAirConditioner/measure.rb
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to add fan coil units to.
  # @return [Array<OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner>] and array of PTACs used as window AC units
  def model_add_window_ac(model,
                          thermal_zones)

    # Defaults
    eer = 8.5 # Btu/W-h
    cop = OpenStudio.convert(eer, 'Btu/h', 'W').get
    shr = 0.65 # The sensible heat ratio (ratio of the sensible portion of the load to the total load) at the nominal rated capacity
    # airflow_cfm_per_ton = 350.0 # cfm/ton

    acs = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding window AC for #{zone.name}.")

      clg_coil = create_coil_cooling_dx_single_speed(model,
                                                     name: "#{zone.name} Window AC Cooling Coil",
                                                     type: 'Window AC',
                                                     cop: cop)
      clg_coil.setRatedSensibleHeatRatio(shr)
      clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(OpenStudio::OptionalDouble.new(773.3))
      clg_coil.setEvaporativeCondenserEffectiveness(OpenStudio::OptionalDouble.new(0.9))
      clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(OpenStudio::OptionalDouble.new(10))
      clg_coil.setBasinHeaterSetpointTemperature(OpenStudio::OptionalDouble.new(2))

      fan = create_fan_by_name(model,
                               'Window_AC_Supply_Fan',
                               fan_name: "#{zone.name} Window AC Supply Fan",
                               end_use_subcategory: 'Window AC Fans')
      fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)

      htg_coil = create_coil_heating_electric(model,
                                              name: "#{zone.name} Window AC Always Off Htg Coil",
                                              schedule: model.alwaysOffDiscreteSchedule,
                                              nominal_capacity: 0)
      ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,
                                                                           model.alwaysOnDiscreteSchedule,
                                                                           fan,
                                                                           htg_coil,
                                                                           clg_coil)
      ptac.setName("#{zone.name} Window AC")
      ptac.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)
      ptac.addToThermalZone(zone)
      acs << ptac
    end

    return acs
  end

  # Adds a forced air furnace or central AC to each zone.
  # Default is a forced air furnace without outdoor air
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
                                   heating: true,
                                   cooling: false,
                                   ventilation: false)

    if heating && cooling
      equip_name = 'Central Heating and AC'
    elsif heating && !cooling
      equip_name = 'Furnace'
    elsif cooling && !heating
      equip_name = 'Central AC'
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', 'Heating and cooling both disabled, not a valid Furnace or Central AC selection, no equipment was added.')
      return false
    end

    # defaults
    afue = 0.78
    # seer = 13.0
    eer = 11.1
    shr = 0.73
    ac_w_per_cfm = 0.365
    crank_case_heat_w = 0.0
    crank_case_max_temp_f = 55.0

    furnaces = []
    thermal_zones.each do |zone|
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName("#{zone.name} #{equip_name}")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding furnace AC for #{zone.name}.")


      # default design temperatures across all air loops
      dsgn_temps = standard_design_sizing_temperatures

      # adjusted temperatures for furnace_central_ac
      dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 122.0
      dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get
      dsgn_temps['htg_dsgn_sup_air_temp_f'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_f']
      dsgn_temps['htg_dsgn_sup_air_temp_c'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_c']

      # default design settings used across all air loops
      sizing_system = adjust_sizing_system(air_loop, dsgn_temps, sizing_option: 'NonCoincident')
      sizing_system.setAllOutdoorAirinCooling(true)
      sizing_system.setAllOutdoorAirinHeating(true)

      # create heating coil
      htg_coil = nil
      if heating
        htg_coil = create_coil_heating_gas(model,
                                           name: "#{air_loop.name} Heating Coil",
                                           efficiency: afue_to_thermal_eff(afue))
      end

      # create cooling coil
      clg_coil = nil
      if cooling
        clg_coil = create_coil_cooling_dx_single_speed(model,
                                                       name: "#{air_loop.name} Cooling Coil",
                                                       type: 'Residential Central AC')
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

      # create fan
      fan = create_fan_by_name(model,
                               'Residential_HVAC_Fan',
                               fan_name: "#{air_loop.name} Supply Fan",
                               end_use_subcategory: 'Residential HVAC Fans')
      fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)

      if ventilation
        # create outdoor air intake
        oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
        oa_intake_controller.setName("#{air_loop.name} OA Controller")
        oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
        oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
        oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
        oa_intake.setName("#{air_loop.name} OA System")
        oa_intake.addToNode(air_loop.supplyInletNode)
      end

      # create unitary system (holds the coils and fan)
      unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary.setName("#{air_loop.name} Unitary System")
      unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      unitary.setMaximumSupplyAirTemperature(dsgn_temps['zn_htg_dsgn_sup_air_temp_c'])
      unitary.setControllingZoneorThermostatLocation(zone)
      unitary.addToNode(air_loop.supplyInletNode)

      # set flow rates during different conditions
      unitary.setSupplyAirFlowRateDuringHeatingOperation(0.0) unless heating
      unitary.setSupplyAirFlowRateDuringCoolingOperation(0.0) unless cooling
      unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0.0) unless ventilation

      # attach the coils and fan
      unitary.setHeatingCoil(htg_coil) if htg_coil
      unitary.setCoolingCoil(clg_coil) if clg_coil
      unitary.setSupplyFan(fan)
      unitary.setFanPlacement('BlowThrough')
      unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)

      # create a diffuser
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName("#{zone.name} Direct Air")
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
                                             heating: true,
                                             cooling: true,
                                             ventilation: false)
    # defaults
    hspf = 7.7
    # seer = 13.0
    # eer = 11.4
    cop = 3.05
    shr = 0.73
    ac_w_per_cfm = 0.365
    min_hp_oat_f = 0.0
    crank_case_heat_w = 0.0
    crank_case_max_temp_f = 55

    hps = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding Central Air Source HP for #{zone.name}.")

      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
      air_loop.setName("#{zone.name} Central Air Source HP")

      # default design temperatures across all air loops
      dsgn_temps = standard_design_sizing_temperatures

      # adjusted temperatures for furnace_central_ac
      dsgn_temps['zn_htg_dsgn_sup_air_temp_f'] = 122.0
      dsgn_temps['zn_htg_dsgn_sup_air_temp_c'] = OpenStudio.convert(dsgn_temps['zn_htg_dsgn_sup_air_temp_f'], 'F', 'C').get
      dsgn_temps['htg_dsgn_sup_air_temp_f'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_f']
      dsgn_temps['htg_dsgn_sup_air_temp_c'] = dsgn_temps['zn_htg_dsgn_sup_air_temp_c']

      # default design settings used across all air loops
      sizing_system = adjust_sizing_system(air_loop, dsgn_temps, sizing_option: 'NonCoincident')
      sizing_system.setAllOutdoorAirinCooling(true)
      sizing_system.setAllOutdoorAirinHeating(true)

      # create heating coil
      htg_coil = nil
      supplemental_htg_coil = nil
      if heating
        htg_coil = create_coil_heating_dx_single_speed(model,
                                                       name: "#{air_loop.name} heating coil",
                                                       type: 'Residential Central Air Source HP',
                                                       cop: hspf_to_cop_heating_no_fan(hspf))
        htg_coil.setRatedSupplyFanPowerPerVolumeFlowRate(ac_w_per_cfm / OpenStudio.convert(1.0, 'cfm', 'm^3/s').get)
        htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(OpenStudio.convert(min_hp_oat_f, 'F', 'C').get)
        htg_coil.setMaximumOutdoorDryBulbTemperatureforDefrostOperation(OpenStudio.convert(40.0, 'F', 'C').get)
        htg_coil.setCrankcaseHeaterCapacity(crank_case_heat_w)
        htg_coil.setMaximumOutdoorDryBulbTemperatureforCrankcaseHeaterOperation(OpenStudio.convert(crank_case_max_temp_f, 'F', 'C').get)
        htg_coil.setDefrostStrategy('ReverseCycle')
        htg_coil.setDefrostControl('OnDemand')
        htg_coil.resetDefrostTimePeriodFraction

        # Supplemental Heating Coil

        # create supplemental heating coil
        supplemental_htg_coil = create_coil_heating_electric(model,
                                                             name: "#{air_loop.name} Supplemental Htg Coil")
      end

      # create cooling coil
      clg_coil = nil
      if cooling
        clg_coil = create_coil_cooling_dx_single_speed(model,
                                                       name: "#{air_loop.name} Cooling Coil",
                                                       type: 'Residential Central ASHP',
                                                       cop: cop)
        clg_coil.setRatedSensibleHeatRatio(shr)
        clg_coil.setRatedEvaporatorFanPowerPerVolumeFlowRate(OpenStudio::OptionalDouble.new(ac_w_per_cfm / OpenStudio.convert(1.0, 'cfm', 'm^3/s').get))
        clg_coil.setNominalTimeForCondensateRemovalToBegin(OpenStudio::OptionalDouble.new(1000.0))
        clg_coil.setRatioOfInitialMoistureEvaporationRateAndSteadyStateLatentCapacity(OpenStudio::OptionalDouble.new(1.5))
        clg_coil.setMaximumCyclingRate(OpenStudio::OptionalDouble.new(3.0))
        clg_coil.setLatentCapacityTimeConstant(OpenStudio::OptionalDouble.new(45.0))
        clg_coil.setCondenserType('AirCooled')
        clg_coil.setCrankcaseHeaterCapacity(OpenStudio::OptionalDouble.new(crank_case_heat_w))
        clg_coil.setMaximumOutdoorDryBulbTemperatureForCrankcaseHeaterOperation(OpenStudio::OptionalDouble.new(OpenStudio.convert(crank_case_max_temp_f, 'F', 'C').get))
      end

      # create fan
      fan = create_fan_by_name(model,
                               'Residential_HVAC_Fan',
                               fan_name: "#{air_loop.name} Supply Fan",
                               end_use_subcategory: 'Residential HVAC Fans')
      fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)

      # create outdoor air intake
      if ventilation
        oa_intake_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
        oa_intake_controller.setName("#{air_loop.name} OA Controller")
        oa_intake_controller.autosizeMinimumOutdoorAirFlowRate
        oa_intake_controller.resetEconomizerMinimumLimitDryBulbTemperature
        oa_intake = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_intake_controller)
        oa_intake.setName("#{air_loop.name} OA System")
        oa_intake.addToNode(air_loop.supplyInletNode)
      end

      # create unitary system (holds the coils and fan)
      unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
      unitary.setName("#{air_loop.name} Unitary System")
      unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      unitary.setMaximumSupplyAirTemperature(OpenStudio.convert(170.0, 'F', 'C').get) # higher temp for supplemental heat as to not severely limit its use, resulting in unmet hours.
      unitary.setMaximumOutdoorDryBulbTemperatureforSupplementalHeaterOperation(OpenStudio.convert(40.0, 'F', 'C').get)
      unitary.setControllingZoneorThermostatLocation(zone)
      unitary.addToNode(air_loop.supplyInletNode)

      # set flow rates during different conditions
      unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0.0) unless ventilation

      # attach the coils and fan
      unitary.setHeatingCoil(htg_coil) if htg_coil
      unitary.setCoolingCoil(clg_coil) if clg_coil
      unitary.setSupplementalHeatingCoil(supplemental_htg_coil) if supplemental_htg_coil
      unitary.setSupplyFan(fan)
      unitary.setFanPlacement('BlowThrough')
      unitary.setSupplyAirFanOperatingModeSchedule(model.alwaysOffDiscreteSchedule)

      # create a diffuser
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
      diffuser.setName(" #{zone.name} Direct Air")
      air_loop.addBranchForZone(zone, diffuser)

      hps << air_loop
    end

    return hps
  end

  # Adds zone level water-to-air heat pumps for each zone.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones served by heat pumps
  # @param condenser_loop [OpenStudio::Model::PlantLoop] the condenser loop for the heat pumps  #
  # @param ventilation [Bool] if true, ventilation will be supplied through the unit.
  #   If false, no ventilation will be supplied through the unit, with the expectation that it will be provided by a DOAS or separate system.
  # @return [Array<OpenStudio::Model::ZoneHVACWaterToAirHeatPump>] an array of heat pumps
  def model_add_water_source_hp(model,
                                thermal_zones,
                                condenser_loop,
                                ventilation: true)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', 'Adding zone water-to-air heat pump.')

    water_to_air_hp_systems = []
    thermal_zones.each do |zone|
      supplemental_htg_coil = create_coil_heating_electric(model,
                                                           name: "#{zone.name} Supplemental Htg Coil")
      htg_coil = create_coil_heating_water_to_air_heat_pump_equation_fit(model,
                                                                         condenser_loop,
                                                                         name: "#{zone.name} Water-to-Air HP Htg Coil")
      clg_coil = create_coil_cooling_water_to_air_heat_pump_equation_fit(model,
                                                                         condenser_loop,
                                                                         name: "#{zone.name} Water-to-Air HP Clg Coil")

      # add fan
      fan = create_fan_by_name(model,
                               'WSHP_Fan',
                               fan_name: "#{zone.name} WSHP Fan")
      fan.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)

      water_to_air_hp_system = OpenStudio::Model::ZoneHVACWaterToAirHeatPump.new(model,
                                                                                 model.alwaysOnDiscreteSchedule,
                                                                                 fan,
                                                                                 htg_coil,
                                                                                 clg_coil,
                                                                                 supplemental_htg_coil)
      water_to_air_hp_system.setName("#{zone.name} WSHP")
      unless ventilation
        water_to_air_hp_system.setOutdoorAirFlowRateDuringHeatingOperation(OpenStudio::OptionalDouble.new(0.0))
        water_to_air_hp_system.setOutdoorAirFlowRateDuringCoolingOperation(OpenStudio::OptionalDouble.new(0.0))
        water_to_air_hp_system.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(OpenStudio::OptionalDouble.new(0.0))
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
  # TODO: review the static pressure rise for the ERV
  def model_add_zone_erv(model,
                         thermal_zones)
    ervs = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding ERV for #{zone.name}.")

      # Determine the OA requirement for this zone
      min_oa_flow_m3_per_s_per_m2 = thermal_zone_outdoor_airflow_rate_per_area(zone)
      supply_fan = create_fan_by_name(model,
                                      'ERV_Supply_Fan',
                                      fan_name: "#{zone.name} ERV Supply Fan")
      impeller_eff = fan_baseline_impeller_efficiency(supply_fan)
      fan_change_impeller_efficiency(supply_fan, impeller_eff)
      exhaust_fan = create_fan_by_name(model,
                                       'ERV_Supply_Fan',
                                       fan_name: "#{zone.name} ERV Exhaust Fan")
      fan_change_impeller_efficiency(exhaust_fan, impeller_eff)

      erv_controller = OpenStudio::Model::ZoneHVACEnergyRecoveryVentilatorController.new(model)
      erv_controller.setName("#{zone.name} ERV Controller")
      # erv_controller.setExhaustAirTemperatureLimit("NoExhaustAirTemperatureLimit")
      # erv_controller.setExhaustAirEnthalpyLimit("NoExhaustAirEnthalpyLimit")
      # erv_controller.setTimeofDayEconomizerFlowControlSchedule(self.alwaysOnDiscreteSchedule)
      # erv_controller.setHighHumidityControlFlag(false)

      heat_exchanger = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(model)
      heat_exchanger.setName("#{zone.name} ERV HX")
      heat_exchanger.setHeatExchangerType('Plate')
      heat_exchanger.setEconomizerLockout(false)
      heat_exchanger.setSupplyAirOutletTemperatureControl(false)
      heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(0.76)
      heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(0.81)
      heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(0.68)
      heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(0.73)
      heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(0.76)
      heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(0.81)
      heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(0.68)
      heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(0.73)

      zone_hvac = OpenStudio::Model::ZoneHVACEnergyRecoveryVentilator.new(model, heat_exchanger, supply_fan, exhaust_fan)
      zone_hvac.setName("#{zone.name} ERV")
      zone_hvac.setVentilationRateperUnitFloorArea(min_oa_flow_m3_per_s_per_m2)
      zone_hvac.setController(erv_controller)
      zone_hvac.addToThermalZone(zone)

      # ensure the ERV takes priority, so ventilation load is included when treated by other zonal systems
      # From EnergyPlus I/O reference:
      # "For situations where one or more equipment types has limited capacity or limited control capability, order the
      #  sequence so that the most controllable piece of equipment runs last. For example, with a dedicated outdoor air
      #  system (DOAS), the air terminal for the DOAS should be assigned Heating Sequence = 1 and Cooling Sequence = 1.
      #  Any other equipment should be assigned sequence 2 or higher so that it will see the net load after the DOAS air
      #  is added to the zone."
      zone.setCoolingPriority(zone_hvac.to_ModelObject.get, 1)
      zone.setHeatingPriority(zone_hvac.to_ModelObject.get, 1)

      # Calculate ERV SAT during sizing periods
      # Standard rating conditions based on AHRI Std 1060 - 2013
      # heating design
      oat_f = 35.0
      return_air_f = 70.0
      eff = heat_exchanger.sensibleEffectivenessat100HeatingAirFlow
      coldest_erv_supply_f = oat_f - (eff * (oat_f - return_air_f))
      coldest_erv_supply_c = OpenStudio.convert(coldest_erv_supply_f, 'F', 'C').get

      # cooling design
      oat_f = 95.0
      return_air_f = 75.0
      eff = heat_exchanger.sensibleEffectivenessat100CoolingAirFlow
      hottest_erv_supply_f = oat_f - (eff * (oat_f - return_air_f))
      hottest_erv_supply_c = OpenStudio.convert(hottest_erv_supply_f, 'F', 'C').get

      # Ensure that zone sizing accounts for OA from ERV
      sizing_zone = zone.sizingZone
      sizing_zone.setAccountforDedicatedOutdoorAirSystem(true)
      sizing_zone.setDedicatedOutdoorAirSystemControlStrategy('NeutralSupplyAir')
      sizing_zone.setDedicatedOutdoorAirLowSetpointTemperatureforDesign(coldest_erv_supply_c)
      sizing_zone.setDedicatedOutdoorAirHighSetpointTemperatureforDesign(hottest_erv_supply_c)

      ervs << zone_hvac
    end

    return ervs
  end

  # Adds ideal air loads systems for each zone.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of zones to enable ideal air loads
  # @param hvac_op_sch [String] name of the HVAC operation schedule, default is always on
  # @param heat_avail_sch [String] name of the heating availability schedule, default is always on
  # @param cool_avail_sch [String] name of the cooling availability schedule, default is always on
  # @param heat_limit_type [String] heating limit type
  #   options are 'NoLimit', 'LimitFlowRate', 'LimitCapacity', and 'LimitFlowRateAndCapacity'
  # @param cool_limit_type [String] cooling limit type
  #   options are 'NoLimit', 'LimitFlowRate', 'LimitCapacity', and 'LimitFlowRateAndCapacity'
  # @param dehumid_limit_type [String] dehumidification limit type
  #   options are 'None', 'ConstantSensibleHeatRatio', 'Humidistat', 'ConstantSupplyHumidityRatio'
  # @param cool_sensible_heat_ratio [Double] cooling sensible heat ratio if dehumidification limit type is 'ConstantSensibleHeatRatio'
  # @param humid_ctrl_type [String] humidification control type
  #   options are 'None', 'Humidistat', 'ConstantSupplyHumidityRatio'
  # @param include_outdoor_air [Boolean] include design specification outdoor air ventilation
  # @param enable_dcv [Boolean] include demand control ventilation, uses occupancy schedule if true
  # @param econo_ctrl_mthd [String] economizer control method (require a cool_limit_type and include_outdoor_air set to true)
  #   options are 'NoEconomizer', 'DifferentialDryBulb', 'DifferentialEnthalpy'
  # @param heat_recovery_type [String] heat recovery type
  #   options are 'None', 'Sensible', 'Enthalpy'
  # @param heat_recovery_sensible_eff [Double] heat recovery sensible effectivness if heat recovery specified
  # @param heat_recovery_latent_eff [Double] heat recovery latent effectivness if heat recovery specified
  # @param add_output_meters [Boolean] include and output custom meter objects to sum all ideal air loads values
  # @return [Array<OpenStudio::Model::ZoneHVACIdealLoadsAirSystem>] an array of ideal air loads systems
  def model_add_ideal_air_loads(model,
                                thermal_zones,
                                hvac_op_sch: nil,
                                heat_avail_sch: nil,
                                cool_avail_sch: nil,
                                heat_limit_type: 'NoLimit',
                                cool_limit_type: 'NoLimit',
                                dehumid_limit_type: 'ConstantSensibleHeatRatio',
                                cool_sensible_heat_ratio: 0.7,
                                humid_ctrl_type: 'None',
                                include_outdoor_air: true,
                                enable_dcv: false,
                                econo_ctrl_mthd: 'NoEconomizer',
                                heat_recovery_type: 'None',
                                heat_recovery_sensible_eff: 0.7,
                                heat_recovery_latent_eff: 0.65,
                                add_output_meters: false)

    # set availability schedules
    if hvac_op_sch.nil?
      hvac_op_sch = model.alwaysOnDiscreteSchedule
    else
      hvac_op_sch = model_add_schedule(model, hvac_op_sch)
    end

    # set heating availability schedules
    if heat_avail_sch.nil?
      heat_avail_sch = model.alwaysOnDiscreteSchedule
    else
      heat_avail_sch = model_add_schedule(model, heat_avail_sch)
    end

    # set cooling availability schedules
    if cool_avail_sch.nil?
      cool_avail_sch = model.alwaysOnDiscreteSchedule
    else
      cool_avail_sch = model_add_schedule(model, cool_avail_sch)
    end

    ideal_systems = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding ideal air loads for for #{zone.name}.")
      ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
      ideal_loads.setName("#{zone.name} Ideal Loads Air System")
      ideal_loads.setAvailabilitySchedule(hvac_op_sch)
      ideal_loads.setHeatingAvailabilitySchedule(heat_avail_sch)
      ideal_loads.setCoolingAvailabilitySchedule(cool_avail_sch)
      ideal_loads.setHeatingLimit(heat_limit_type)
      ideal_loads.setCoolingLimit(cool_limit_type)
      ideal_loads.setDehumidificationControlType(dehumid_limit_type)
      ideal_loads.setCoolingSensibleHeatRatio(cool_sensible_heat_ratio)
      ideal_loads.setHumidificationControlType(humid_ctrl_type)
      if include_outdoor_air
        # get the design specification outdoor air of the largest space in the zone
        # TODO: create a new design specification outdoor air object that sums ventilation rates and schedules if multiple design specification outdoor air objects
        space_areas = zone.spaces.map { |s| s.floorArea }
        largest_space = zone.spaces.select { |s| s.floorArea == space_areas.max }
        largest_space = largest_space[0]
        design_spec_oa = largest_space.designSpecificationOutdoorAir
        if design_spec_oa.is_initialized
          design_spec_oa = design_spec_oa.get
          ideal_loads.setDesignSpecificationOutdoorAirObject(design_spec_oa)
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Model.Model', "Outdoor air requested for ideal loads object, but space #{largest_space.name} in thermal zone #{zone.name} does not have a design specification outdoor air object.")
        end
      end
      if enable_dcv
        ideal_loads.setDemandControlledVentilationType('OccupancySchedule')
      else
        ideal_loads.setDemandControlledVentilationType('None')
      end
      ideal_loads.setOutdoorAirEconomizerType(econo_ctrl_mthd)
      ideal_loads.setHeatRecoveryType(heat_recovery_type)
      ideal_loads.setSensibleHeatRecoveryEffectiveness(heat_recovery_sensible_eff)
      ideal_loads.setLatentHeatRecoveryEffectiveness(heat_recovery_latent_eff)
      ideal_loads.addToThermalZone(zone)
      ideal_systems << ideal_loads

      # set zone sizing parameters
      zone_sizing = zone.sizingZone
      zone_sizing.setHeatingMaximumAirFlowFraction(1.0)
    end

    if add_output_meters
      # ideal air loads system variables to include
      ideal_air_loads_system_variables = [
        'Zone Ideal Loads Supply Air Sensible Heating Energy',
        'Zone Ideal Loads Supply Air Latent Heating Energy',
        'Zone Ideal Loads Supply Air Total Heating Energy',
        'Zone Ideal Loads Supply Air Sensible Cooling Energy',
        'Zone Ideal Loads Supply Air Latent Cooling Energy',
        'Zone Ideal Loads Supply Air Total Cooling Energy',
        'Zone Ideal Loads Zone Sensible Heating Energy',
        'Zone Ideal Loads Zone Latent Heating Energy',
        'Zone Ideal Loads Zone Total Heating Energy',
        'Zone Ideal Loads Zone Sensible Cooling Energy',
        'Zone Ideal Loads Zone Latent Cooling Energy',
        'Zone Ideal Loads Zone Total Cooling Energy',
        'Zone Ideal Loads Outdoor Air Sensible Heating Energy',
        'Zone Ideal Loads Outdoor Air Latent Heating Energy',
        'Zone Ideal Loads Outdoor Air Total Heating Energy',
        'Zone Ideal Loads Outdoor Air Sensible Cooling Energy',
        'Zone Ideal Loads Outdoor Air Latent Cooling Energy',
        'Zone Ideal Loads Outdoor Air Total Cooling Energy',
        'Zone Ideal Loads Heat Recovery Sensible Heating Energy',
        'Zone Ideal Loads Heat Recovery Latent Heating Energy',
        'Zone Ideal Loads Heat Recovery Total Heating Energy',
        'Zone Ideal Loads Heat Recovery Sensible Cooling Energy',
        'Zone Ideal Loads Heat Recovery Latent Cooling Energy',
        'Zone Ideal Loads Heat Recovery Total Cooling Energy'
      ]

      meters_added = 0
      outputs_added = 0
      ideal_air_loads_system_variables.each do |variable|
        # create meter definition for variable
        meter_definition = OpenStudio::Model::MeterCustom.new(model)
        meter_definition.setName("Sum #{variable}")
        meter_definition.setFuelType('Generic')
        model.getZoneHVACIdealLoadsAirSystems.each { |sys| meter_definition.addKeyVarGroup(sys.name.to_s, variable) }
        meters_added += 1

        # add output meter
        output_meter_definition = OpenStudio::Model::OutputMeter.new(model)
        output_meter_definition.setName("Sum #{variable}")
        output_meter_definition.setReportingFrequency('Hourly')
        output_meter_definition.setMeterFileOnly(true)
        output_meter_definition.setCumulative(false)
        outputs_added += 1
      end
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Added #{meters_added} custom meter objects and #{outputs_added} meter outputs for ideal loads air systems.")
    end

    return ideal_systems
  end

  # Adds an exhaust fan to each zone.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] an array of thermal zones
  # @param flow_rate [Double] the exhaust fan flow rate in m^3/s
  # @param availability_sch_name [String] the name of the fan availability schedule
  # @param flow_fraction_schedule_name [String] the name of the flow fraction schedule
  # @param balanced_exhaust_fraction_schedule_name [String] the name of the balanced exhaust fraction schedule
  # @return [Array<OpenStudio::Model::FanZoneExhaust>] an array of exhaust fans created
  # @todo: use the create_fan_zone_exhaust method, default to 1.25 inH2O pressure rise and fan efficiency of 0.6
  def model_add_exhaust_fan(model,
                            thermal_zones,
                            flow_rate: nil,
                            availability_sch_name: nil,
                            flow_fraction_schedule_name: nil,
                            balanced_exhaust_fraction_schedule_name: nil)

    if availability_sch_name.nil?
      availability_schedule = model.alwaysOnDiscreteSchedule
    else
      availability_schedule = model_add_schedule(model, availability_sch_name)
    end

    # make an exhaust fan for each zone
    fans = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding zone exhaust fan for #{zone.name}.")
      fan = OpenStudio::Model::FanZoneExhaust.new(model)
      fan.setName("#{zone.name} Exhaust Fan")
      fan.setAvailabilitySchedule(availability_schedule)

      # input the flow rate as a number (assign directly) or from an array (assign each flow rate to each zone)
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
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] an array of thermal zones
  # @param ventilation_type [String] the zone ventilation type either Exhaust, Natural, or Intake
  # @param flow_rate [Double] the ventilation design flow rate in m^3/s
  # @param availability_sch_name [String] the name of the fan availability schedule
  # @return [Array<OpenStudio::Model::ZoneVentilationDesignFlowRate>] an array of zone ventilation objects created
  def model_add_zone_ventilation(model,
                                 thermal_zones,
                                 ventilation_type: nil,
                                 flow_rate: nil,
                                 availability_sch_name: nil)

    if availability_sch_name.nil?
      availability_schedule = model.alwaysOnDiscreteSchedule
    else
      availability_schedule = model_add_schedule(model, availability_sch_name)
    end

    if flow_rate.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Flow rate nil for zone ventilation.')
    end

    # make a zone ventilation object for each zone
    zone_ventilations = []
    thermal_zones.each do |zone|
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Model.Model', "Adding zone ventilation fan for #{zone.name}.")
      ventilation = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
      ventilation.setName("#{zone.name} Ventilation")
      ventilation.setSchedule(availability_schedule)

      if ventilation_type == 'Exhaust'
        ventilation.setDesignFlowRateCalculationMethod('Flow/Zone')
        ventilation.setDesignFlowRate(flow_rate)
        ventilation.setFanPressureRise(31.1361206455786)
        ventilation.setFanTotalEfficiency(0.51)
        ventilation.setConstantTermCoefficient(1.0)
        ventilation.setVelocityTermCoefficient(0.0)
        ventilation.setTemperatureTermCoefficient(0.0)
        ventilation.setMinimumIndoorTemperature(29.4444452244559)
        ventilation.setMaximumIndoorTemperature(100.0)
        ventilation.setDeltaTemperature(-100.0)
      elsif ventilation_type == 'Natural'
        ventilation.setDesignFlowRateCalculationMethod('Flow/Zone')
        ventilation.setDesignFlowRate(flow_rate)
        ventilation.setFanPressureRise(0.0)
        ventilation.setFanTotalEfficiency(1.0)
        ventilation.setConstantTermCoefficient(0.0)
        ventilation.setVelocityTermCoefficient(0.224)
        ventilation.setTemperatureTermCoefficient(0.0)
        ventilation.setMinimumIndoorTemperature(-73.3333352760033)
        ventilation.setMaximumIndoorTemperature(29.4444452244559)
        ventilation.setDeltaTemperature(-100.0)
      elsif ventilation_type == 'Intake'
        ventilation.setDesignFlowRateCalculationMethod('Flow/Area')
        ventilation.setFlowRateperZoneFloorArea(flow_rate)
        ventilation.setFanPressureRise(49.8)
        ventilation.setFanTotalEfficiency(0.53625)
        ventilation.setConstantTermCoefficient(1.0)
        ventilation.setVelocityTermCoefficient(0.0)
        ventilation.setTemperatureTermCoefficient(0.0)
        ventilation.setMinimumIndoorTemperature(7.5)
        ventilation.setMaximumIndoorTemperature(35)
        ventilation.setDeltaTemperature(-27.5)
        ventilation.setMinimumOutdoorTemperature(-30.0)
        ventilation.setMaximumOutdoorTemperature(50.0)
        ventilation.setMaximumWindSpeed(6.0)
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "ventilation type #{ventilation_type} invalid for zone ventilation.")
      end
      ventilation.setVentilationType(ventilation_type)
      ventilation.addToThermalZone(zone)
      zone_ventilations << ventilation
    end

    return zone_ventilations
  end

  # Get the existing chilled water loop in the model or add a new one if there isn't one already.
  #
  # @param cool_fuel [String] the cooling fuel. Valid choices are Electricity, DistrictCooling, and HeatPump.
  # @param chilled_water_loop_cooling_type [String] Archetype for chilled water loops, AirCooled or WaterCooled
  def model_get_or_add_chilled_water_loop(model, cool_fuel,
                                          chilled_water_loop_cooling_type: 'WaterCooled')
    # retrieve the existing chilled water loop or add a new one if necessary
    chilled_water_loop = nil
    if model.getPlantLoopByName('Chilled Water Loop').is_initialized
      chilled_water_loop = model.getPlantLoopByName('Chilled Water Loop').get
    else
      case cool_fuel
      when 'DistrictCooling'
        chilled_water_loop = model_add_chw_loop(model,
                                                chw_pumping_type: 'const_pri',
                                                cooling_fuel: cool_fuel)
      when 'HeatPump'
        condenser_water_loop = model_get_or_add_ambient_water_loop(model)
        chilled_water_loop = model_add_chw_loop(model,
                                                chw_pumping_type: 'const_pri_var_sec',
                                                chiller_cooling_type: 'WaterCooled',
                                                chiller_compressor_type: 'Rotary Screw',
                                                condenser_water_loop: condenser_water_loop)
      when 'Electricity'
        if chilled_water_loop_cooling_type == 'AirCooled'
          chilled_water_loop = model_add_chw_loop(model,
                                                  chw_pumping_type: 'const_pri',
                                                  cooling_fuel: cool_fuel)
        else
          fan_type = model_cw_loop_cooling_tower_fan_type(model)
          condenser_water_loop = model_add_cw_loop(model,
                                                   cooling_tower_type: 'Open Cooling Tower',
                                                   cooling_tower_fan_type: 'Propeller or Axial',
                                                   cooling_tower_capacity_control: fan_type,
                                                   number_of_cells_per_tower: 1,
                                                   number_cooling_towers: 1)
          chilled_water_loop = model_add_chw_loop(model,
                                                  chw_pumping_type: 'const_pri_var_sec',
                                                  chiller_cooling_type: 'WaterCooled',
                                                  chiller_compressor_type: 'Rotary Screw',
                                                  condenser_water_loop: condenser_water_loop)
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', 'No cool_fuel specified.')
      end
    end

    return chilled_water_loop
  end

  # Determine which type of fan the cooling tower will have.  Defaults to TwoSpeed Fan.
  # @return [String] the fan type: TwoSpeed Fan, Variable Speed Fan
  def model_cw_loop_cooling_tower_fan_type(model)
    fan_type = 'TwoSpeed Fan'
    return fan_type
  end

  # Get the existing hot water loop in the model or add a new one if there isn't one already.
  #
  # @param heat_fuel [String] the heating fuel. Valid choices are NaturalGas, Electricity, DistrictHeating
  # @param hot_water_loop_type [String] Archetype for hot water loops
  #   HighTemperature (180F supply) or LowTemperature (120F supply)
  def model_get_or_add_hot_water_loop(model, heat_fuel,
                                      hot_water_loop_type: 'HighTemperature')
    make_new_hot_water_loop = true
    hot_water_loop = nil
    # retrieve the existing hot water loop or add a new one if not of the correct type
    if model.getPlantLoopByName('Hot Water Loop').is_initialized
      hot_water_loop = model.getPlantLoopByName('Hot Water Loop').get
      design_loop_exit_temperature = hot_water_loop.sizingPlant.designLoopExitTemperature
      design_loop_exit_temperature = OpenStudio.convert(design_loop_exit_temperature, 'C', 'F').get
      # check that the loop is the correct archetype
      if hot_water_loop_type == 'HighTemperature'
        make_new_hot_water_loop = false if design_loop_exit_temperature > 130.0
      elsif hot_water_loop_type == 'LowTemperature'
        make_new_hot_water_loop = false if design_loop_exit_temperature <= 130.0
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Hot water loop archetype #{hot_water_loop_type} not recognized.")
      end
    end

    if make_new_hot_water_loop
      if hot_water_loop_type == 'HighTemperature'
        hot_water_loop = model_add_hw_loop(model, heat_fuel)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'New high temperature hot water loop created.')
      elsif hot_water_loop_type == 'LowTemperature'
        hot_water_loop = model_add_hw_loop(model, heat_fuel,
                                           dsgn_sup_wtr_temp: 120.0,
                                           boiler_draft_type: 'Condensing')
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'New low temperature hot water loop created.')
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Hot water loop archetype #{hot_water_loop_type} not recognized.")
      end
    end
    return hot_water_loop
  end

  # Get the existing ambient water loop in the model or add a new one if there isn't one already.
  def model_get_or_add_ambient_water_loop(model)
    # retrieve the existing hot water loop or add a new one if necessary
    ambient_water_loop = if model.getPlantLoopByName('Ambient Loop').is_initialized
                           model.getPlantLoopByName('Ambient Loop').get
                         else
                           model_add_district_ambient_loop(model)
                         end
    return ambient_water_loop
  end

  # Get the existing ground heat exchanger loop in the model or add a new one if there isn't one already.
  def model_get_or_add_ground_hx_loop(model)
    # retrieve the existing ground HX loop or add a new one if necessary
    ground_hx_loop = if model.getPlantLoopByName('Ground HX Loop').is_initialized
                       model.getPlantLoopByName('Ground HX Loop').get
                     else
                       model_add_ground_hx_loop(model)
                     end
    return ground_hx_loop
  end

  # Get the existing heat pump loop in the model or add a new one if there isn't one already.
  def model_get_or_add_heat_pump_loop(model)
    # retrieve the existing heat pump loop or add a new one if necessary
    heat_pump_loop = if model.getPlantLoopByName('Heat Pump Loop').is_initialized
                       model.getPlantLoopByName('Heat Pump Loop').get
                     else
                       model_add_hp_loop(model)
                     end
    return heat_pump_loop
  end

  # Add the specified system type to the specified zones based on the specified template.
  # For multi-zone system types, add one system per story.
  #
  # @param system_type [String] The system type
  # @param main_heat_fuel [String] Main heating fuel used for air loops and plant loops
  # @param zone_heat_fuel [String] Zone heating fuel for zone hvac equipment and terminal units
  # @param cool_fuel [String] Cooling fuel used for air loops, plant loops, and zone equipment
  # @param zones [Array<OpenStudio::Model::ThermalZone>] array of thermal zones served by the system
  # @param hot_water_loop_type [String] Archetype for hot water loops
  #   HighTemperature (180F supply) (default) or LowTemperature (120F supply)
  #   only used if HVAC system has a hot water loop
  # @param chilled_water_loop_cooling_type [String] Archetype for chilled water loops, AirCooled or WaterCooled
  #   only used if HVAC system has a chilled water loop and cool_fuel is Electricity
  # @param air_loop_heating_type [String] type of heating coil serving main air loop, options are Gas, DX, or Water
  # @param air_loop_cooling_type [String] type of cooling coil serving main air loop, options are DX or Water
  # @param fan_coil_ventilation [Bool] toggle whether to include outdoor air ventilation on zone fan coil units
  #   only used if HVAC system has four pipe fan coil units
  # @return [Bool] returns true if successful, false if not
  def model_add_hvac_system(model,
                            system_type,
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: 'HighTemperature',
                            chilled_water_loop_cooling_type: 'WaterCooled',
                            air_loop_heating_type: 'Water',
                            air_loop_cooling_type: 'Water',
                            fan_coil_ventilation: true)

    # don't do anything if there are no zones
    return true if zones.empty?

    case system_type
    when 'PTAC'
      case main_heat_fuel
      when 'NaturalGas', 'DistrictHeating'
        heating_type = 'Water'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: hot_water_loop_type)
      when 'AirSourceHeatPump'
        heating_type = 'Water'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: 'LowTemperature')
      when 'Electricity'
        heating_type = main_heat_fuel
        hot_water_loop = nil
      else
        heating_type = zone_heat_fuel
        hot_water_loop = nil
      end

      model_add_ptac(model,
                     zones,
                     cooling_type: 'Single Speed DX AC',
                     heating_type: heating_type,
                     hot_water_loop: hot_water_loop,
                     fan_type: 'ConstantVolume')

    when 'PTHP'
      model_add_pthp(model,
                     zones,
                     fan_type: 'ConstantVolume')

    when 'PSZ-AC'
      case main_heat_fuel
      when 'NaturalGas', 'Gas'
        heating_type = main_heat_fuel
        supplemental_heating_type = 'Electricity'
        if air_loop_heating_type == 'Water'
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                           hot_water_loop_type: hot_water_loop_type)
        else
          hot_water_loop = nil
        end
      when 'DistrictHeating'
        heating_type = 'Water'
        supplemental_heating_type = 'Electricity'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: hot_water_loop_type)
      when 'AirSourceHeatPump', 'ASHP'
        heating_type = 'Water'
        supplemental_heating_type = 'Electricity'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: 'LowTemperature')
      when 'Electricity'
        heating_type = main_heat_fuel
        supplemental_heating_type = 'Electricity'
      else
        heating_type = zone_heat_fuel
        supplemental_heating_type = nil
        hot_water_loop = nil
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
                       zones,
                       cooling_type: cooling_type,
                       chilled_water_loop: chilled_water_loop,
                       hot_water_loop: hot_water_loop,
                       heating_type: heating_type,
                       supplemental_heating_type: supplemental_heating_type,
                       fan_location: 'DrawThrough',
                       fan_type: 'ConstantVolume')

    when 'PSZ-HP'
      model_add_psz_ac(model,
                       zones,
                       system_name: 'PSZ-HP',
                       cooling_type: 'Single Speed Heat Pump',
                       heating_type: 'Single Speed Heat Pump',
                       supplemental_heating_type: 'Electricity',
                       fan_location: 'DrawThrough',
                       fan_type: 'ConstantVolume')

    when 'PSZ-VAV'
      if main_heat_fuel.nil?
        supplemental_heating_type = nil
      else
        supplemental_heating_type = 'Electricity'
      end
      model_add_psz_vav(model,
                        zones,
                        system_name: 'PSZ-VAV',
                        heating_type: main_heat_fuel,
                        supplemental_heating_type: supplemental_heating_type,
                        hvac_op_sch: nil,
                        oa_damper_sch: nil)

    when 'VRF'
      model_add_vrf(model,
                    zones)

    when 'Fan Coil'
      case main_heat_fuel
      when 'NaturalGas', 'DistrictHeating', 'Electricity'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: hot_water_loop_type)
      when 'AirSourceHeatPump'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: 'LowTemperature')
      else
        hot_water_loop = nil
      end

      case cool_fuel
      when 'Electricity', 'DistrictCooling'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                                 chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      else
        chilled_water_loop = nil
      end

      model_add_four_pipe_fan_coil(model,
                                   zones,
                                   chilled_water_loop,
                                   hot_water_loop: hot_water_loop,
                                   ventilation: fan_coil_ventilation)

    when 'Baseboards'
      case main_heat_fuel
      when 'NaturalGas', 'DistrictHeating'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: hot_water_loop_type)
      when 'AirSourceHeatPump'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: 'LowTemperature')
      when 'Electricity'
        hot_water_loop = nil
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Baseboards must have heating_type specified.')
        return false
      end
      model_add_baseboard(model,
                          zones,
                          hot_water_loop: hot_water_loop)

    when 'Unit Heaters'
      model_add_unitheater(model,
                           zones,
                           hvac_op_sch: nil,
                           fan_control_type: 'ConstantVolume',
                           fan_pressure_rise: 0.2,
                           heating_type: main_heat_fuel)

    when 'Window AC'
      model_add_window_ac(model,
                          zones)

    when 'Residential AC'
      model_add_furnace_central_ac(model,
                                   zones,
                                   heating: false,
                                   cooling: true,
                                   ventilation: false)

    when 'Forced Air Furnace'
      model_add_furnace_central_ac(model,
                                   zones,
                                   heating: true,
                                   cooling: false,
                                   ventilation: true)

    when 'Residential Forced Air Furnace'
      model_add_furnace_central_ac(model,
                                   zones,
                                   heating: true,
                                   cooling: false,
                                   ventilation: false)

    when 'Residential Forced Air Furnace with AC'
      model_add_furnace_central_ac(model,
                                   zones,
                                   heating: true,
                                   cooling: true,
                                   ventilation: false)

    when 'Residential Air Source Heat Pump'
      heating = true unless main_heat_fuel.nil?
      cooling = true unless cool_fuel.nil?
      model_add_central_air_source_heat_pump(model,
                                             zones,
                                             heating: heating,
                                             cooling: cooling,
                                             ventilation: false)

    when 'VAV Reheat'
      case main_heat_fuel
      when 'NaturalGas', 'Gas', 'HeatPump', 'DistrictHeating'
        heating_type = main_heat_fuel
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: hot_water_loop_type)
      when 'AirSourceHeatPump'
        heating_type = main_heat_fuel
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: 'LowTemperature')
      else
        heating_type = 'Electricity'
        hot_water_loop = nil
      end

      case air_loop_cooling_type
      when 'Water'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                                 chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      else
        chilled_water_loop = nil
      end

      if hot_water_loop.nil?
        case zone_heat_fuel
        when 'NaturalGas', 'Gas'
          reheat_type = 'NaturalGas'
        when 'Electricity'
          reheat_type = 'Electricity'
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "zone_heat_fuel '#{zone_heat_fuel}' not supported with main_heat_fuel '#{main_heat_fuel}' for a 'VAV Reheat' system type.")
          return false
        end
      else
        reheat_type = 'Water'
      end

      model_add_vav_reheat(model,
                           zones,
                           heating_type: heating_type,
                           reheat_type: reheat_type,
                           hot_water_loop: hot_water_loop,
                           chilled_water_loop: chilled_water_loop,
                           fan_efficiency: 0.62,
                           fan_motor_efficiency: 0.9,
                           fan_pressure_rise: 4.0)

    when 'VAV No Reheat'
      case main_heat_fuel
      when 'NaturalGas', 'Gas', 'HeatPump', 'DistrictHeating'
        heating_type = main_heat_fuel
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: hot_water_loop_type)
      when 'AirSourceHeatPump'
        heating_type = main_heat_fuel
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: 'LowTemperature')
      else
        heating_type = 'Electricity'
        hot_water_loop = nil
      end

      if air_loop_cooling_type == 'Water'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                                 chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      else
        chilled_water_loop = nil
      end
      model_add_vav_reheat(model,
                           zones,
                           heating_type: heating_type,
                           reheat_type: nil,
                           hot_water_loop: hot_water_loop,
                           chilled_water_loop: chilled_water_loop,
                           fan_efficiency: 0.62,
                           fan_motor_efficiency: 0.9,
                           fan_pressure_rise: 4.0)

    when 'VAV Gas Reheat'
      if air_loop_cooling_type == 'Water'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                                 chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      else
        chilled_water_loop = nil
      end
      model_add_vav_reheat(model,
                           zones,
                           heating_type: 'NaturalGas',
                           reheat_type: 'NaturalGas',
                           chilled_water_loop: chilled_water_loop,
                           fan_efficiency: 0.62,
                           fan_motor_efficiency: 0.9,
                           fan_pressure_rise: 4.0)

    when 'PVAV Reheat'
      case main_heat_fuel
      when 'AirSourceHeatPump'
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: 'LowTemperature')
      else
        hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                         hot_water_loop_type: hot_water_loop_type)
      end

      case cool_fuel
      when 'Electricity'
        chilled_water_loop = nil
      else
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                                 chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      end

      if zone_heat_fuel == 'Electricity'
        electric_reheat = true
      else
        electric_reheat = false
      end

      model_add_pvav(model,
                     zones,
                     hot_water_loop: hot_water_loop,
                     chilled_water_loop: chilled_water_loop,
                     electric_reheat: electric_reheat)

    when 'PVAV PFP Boxes'
      case cool_fuel
      when 'DistrictCooling'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel)
      else
        chilled_water_loop = nil
      end
      model_add_pvav_pfp_boxes(model,
                               zones,
                               chilled_water_loop: chilled_water_loop,
                               fan_efficiency: 0.62,
                               fan_motor_efficiency: 0.9,
                               fan_pressure_rise: 4.0)

    when 'VAV PFP Boxes'
      chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                               chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      model_add_pvav_pfp_boxes(model,
                               zones,
                               chilled_water_loop: chilled_water_loop,
                               fan_efficiency: 0.62,
                               fan_motor_efficiency: 0.9,
                               fan_pressure_rise: 4.0)

    when 'Water Source Heat Pumps'
      condenser_loop = case main_heat_fuel
                       when 'NaturalGas'
                         model_get_or_add_heat_pump_loop(model)
                       else
                         model_get_or_add_ambient_water_loop(model)
                       end
      model_add_water_source_hp(model,
                                zones,
                                condenser_loop,
                                ventilation: false)

    when 'Ground Source Heat Pumps'
      condenser_loop = model_get_or_add_ground_hx_loop(model)
      model_add_water_source_hp(model,
                                zones,
                                condenser_loop,
                                ventilation: false)

    when 'DOAS Cold Supply'
      hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                       hot_water_loop_type: hot_water_loop_type)
      chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                               chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      model_add_doas_cold_supply(model,
                                 zones,
                                 hot_water_loop: hot_water_loop,
                                 chilled_water_loop: chilled_water_loop)

    when 'DOAS'
      if air_loop_heating_type == 'Water'
        case main_heat_fuel
        when 'AirSourceHeatPump'
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                           hot_water_loop_type: 'LowTemperature')
        else
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                           hot_water_loop_type: hot_water_loop_type)
        end
      else
        hot_water_loop = nil
      end
      if air_loop_cooling_type == 'Water'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                                 chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      else
        chilled_water_loop = nil
      end
      model_add_doas(model,
                     zones,
                     hot_water_loop: hot_water_loop,
                     chilled_water_loop: chilled_water_loop)

    when 'DOAS with DCV'
      if air_loop_heating_type == 'Water'
        case main_heat_fuel
        when 'AirSourceHeatPump'
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                           hot_water_loop_type: 'LowTemperature')
        else
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                           hot_water_loop_type: hot_water_loop_type)
        end
      else
        hot_water_loop = nil
      end
      if air_loop_cooling_type == 'Water'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                                 chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      else
        chilled_water_loop = nil
      end
      model_add_doas(model,
                     zones,
                     hot_water_loop: hot_water_loop,
                     chilled_water_loop: chilled_water_loop,
                     doas_type: 'DOASVAV',
                     demand_control_ventilation: true)

    when 'DOAS with Economizing'
      if air_loop_heating_type == 'Water'
        case main_heat_fuel
        when 'AirSourceHeatPump'
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                           hot_water_loop_type: 'LowTemperature')
        else
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                           hot_water_loop_type: hot_water_loop_type)
        end
      else
        hot_water_loop = nil
      end
      if air_loop_cooling_type == 'Water'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                                 chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      else
        chilled_water_loop = nil
      end
      model_add_doas(model,
                     zones,
                     hot_water_loop: hot_water_loop,
                     chilled_water_loop: chilled_water_loop,
                     doas_type: 'DOASVAV',
                     econo_ctrl_mthd: 'FixedDryBulb')

    when 'DOAS with DCV and Economizing'
      if air_loop_heating_type == 'Water'
        case main_heat_fuel
        when 'AirSourceHeatPump'
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                           hot_water_loop_type: 'LowTemperature')
        else
          hot_water_loop = model_get_or_add_hot_water_loop(model, main_heat_fuel,
                                                           hot_water_loop_type: hot_water_loop_type)
        end
      else
        hot_water_loop = nil
      end
      if air_loop_cooling_type == 'Water'
        chilled_water_loop = model_get_or_add_chilled_water_loop(model, cool_fuel,
                                                                 chilled_water_loop_cooling_type: chilled_water_loop_cooling_type)
      else
        chilled_water_loop = nil
      end
      model_add_doas(model,
                     zones,
                     hot_water_loop: hot_water_loop,
                     chilled_water_loop: chilled_water_loop,
                     doas_type: 'DOASVAV',
                     demand_control_ventilation: true,
                     econo_ctrl_mthd: 'FixedDryBulb')

    when 'ERVs'
      model_add_zone_erv(model, zones)

    when 'Evaporative Cooler'
      model_add_evap_cooler(model, zones)

    when 'Ideal Air Loads'
      model_add_ideal_air_loads(model, zones)

    ### Combination Systems ###
    when 'Water Source Heat Pumps with ERVs'
      model_add_hvac_system(model,
                            system_type = 'ERVs',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

      model_add_hvac_system(model,
                            system_type = 'Water Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Water Source Heat Pumps with DOAS'
      model_add_hvac_system(model,
                            system_type = 'DOAS',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            air_loop_heating_type: air_loop_heating_type,
                            air_loop_cooling_type: air_loop_cooling_type)

      model_add_hvac_system(model,
                            system_type = 'Water Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Water Source Heat Pumps with DOAS with DCV'
      model_add_hvac_system(model,
                            system_type = 'DOAS with DCV',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            air_loop_heating_type: air_loop_heating_type,
                            air_loop_cooling_type: air_loop_cooling_type)

      model_add_hvac_system(model,
                            system_type = 'Water Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Ground Source Heat Pumps with ERVs'
      model_add_hvac_system(model,
                            system_type = 'ERVs',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

      model_add_hvac_system(model,
                            system_type = 'Ground Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Ground Source Heat Pumps with DOAS'
      model_add_hvac_system(model,
                            system_type = 'DOAS',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            air_loop_heating_type: air_loop_heating_type,
                            air_loop_cooling_type: air_loop_cooling_type)

      model_add_hvac_system(model,
                            system_type = 'Ground Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Ground Source Heat Pumps with DOAS with DCV'
      model_add_hvac_system(model,
                            system_type = 'DOAS with DCV',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            air_loop_heating_type: air_loop_heating_type,
                            air_loop_cooling_type: air_loop_cooling_type)

      model_add_hvac_system(model,
                            system_type = 'Ground Source Heat Pumps',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when 'Fan Coil with DOAS'
      model_add_hvac_system(model,
                            system_type = 'DOAS',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            air_loop_heating_type: 'Water',
                            air_loop_cooling_type: 'Water')

      model_add_hvac_system(model,
                            system_type = 'Fan Coil',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            fan_coil_ventilation: false)

    when 'Fan Coil with DOAS with DCV'
      model_add_hvac_system(model,
                            system_type = 'DOAS with DCV',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            air_loop_heating_type: 'Water',
                            air_loop_cooling_type: 'Water')

      model_add_hvac_system(model,
                            system_type = 'Fan Coil',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            fan_coil_ventilation: false)

    when 'Fan Coil with ERVs'
      model_add_hvac_system(model,
                            system_type = 'ERVs',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

      model_add_hvac_system(model,
                            system_type = 'Fan Coil',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            fan_coil_ventilation: false)

    when  'VRF with DOAS'
      model_add_hvac_system(model,
                            system_type = 'DOAS',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            air_loop_heating_type: 'DX',
                            air_loop_cooling_type: 'DX')

      model_add_hvac_system(model,
                            system_type = 'VRF',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    when  'VRF with DOAS with DCV'
      model_add_hvac_system(model,
                            system_type = 'DOAS with DCV',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones,
                            hot_water_loop_type: hot_water_loop_type,
                            chilled_water_loop_cooling_type: chilled_water_loop_cooling_type,
                            air_loop_heating_type: 'DX',
                            air_loop_cooling_type: 'DX')

      model_add_hvac_system(model,
                            system_type = 'VRF',
                            main_heat_fuel,
                            zone_heat_fuel,
                            cool_fuel,
                            zones)

    else

      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "HVAC system type '#{system_type}' not recognized")
      return false

    end

    # rename air loop and plant loop nodes for readability
    rename_air_loop_nodes(model)
    rename_plant_loop_nodes(model)
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
    # Note that when water use equipment is assigned to spaces then the water used by the equipment is multiplied by the
    # space (ultimately thermal zone) multiplier.  Note that there is a separate water use equipment multiplier as well
    # which is different than the space (ultimately thermal zone) multiplier.
    rated_flow_rate_gal_per_min = OpenStudio.convert(space['shw_peakflow_ind_SI'], 'm^3/s', 'gal/min').get
    water_use_sensible_frac_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    water_use_sensible_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.2)
    water_use_latent_frac_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    water_use_latent_frac_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.05)
    water_fixture_def.setSensibleFractionSchedule(water_use_sensible_frac_sch)
    water_fixture_def.setLatentFractionSchedule(water_use_latent_frac_sch)
    water_fixture_def.setPeakFlowRate(space['shw_peakflow_ind_SI'])
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

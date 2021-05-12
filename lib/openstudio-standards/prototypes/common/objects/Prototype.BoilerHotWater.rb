class Standard
  # @!group Boiler Hot Water

  # Prototype BoilerHotWater object
  #
  # @param hot_water_loop [<OpenStudio::Model::PlantLoop>] a hot water loop served by the boiler
  # @param name [String] the name of the boiler, or nil in which case it will be defaulted
  # @param fuel_type [String] type of fuel serving the boiler
  # @param draft_type [String] Boiler type Condensing, MechanicalNoncondensing, Natural (default)
  # @param nominal_thermal_efficiency [Double] boiler nominal thermal efficiency
  # @param eff_curve_temp_eval_var [String] LeavingBoiler or EnteringBoiler temperature for the boiler efficiency curve
  # @param flow_mode [String] boiler flow mode
  # @param lvg_temp_dsgn [Double] boiler leaving design temperature, degrees Fahrenheit
  #   note that this field is deprecated in OS versions 3.0+
  # @param out_temp_lmt [Double] boiler outlet temperature limit, degrees Fahrenheit
  # @param min_plr [Double] boiler minimum part load ratio
  # @param max_plr [Double] boiler maximum part load ratio
  # @param opt_plr [Double] boiler optimum part load ratio
  # @param sizing_factor [Double] boiler oversizing factor
  def create_boiler_hot_water(model,
                              hot_water_loop: nil,
                              name: 'Boiler',
                              fuel_type: 'NaturalGas',
                              draft_type: 'Natural',
                              nominal_thermal_efficiency: 0.80,
                              eff_curve_temp_eval_var: 'LeavingBoiler',
                              flow_mode: 'LeavingSetpointModulated',
                              lvg_temp_dsgn: 180.0,
                              out_temp_lmt: 203.0, # 95C
                              min_plr: 0.0,
                              max_plr: 1.2,
                              opt_plr: 1.0,
                              sizing_factor: nil)

    # create the boiler
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    if name.nil?
      if !hot_water_loop.nil?
        boiler.setName("#{hot_water_loop.name} Boiler")
      else
        boiler.setName('Boiler')
      end
    else
      boiler.setName(name)
    end

    if fuel_type.nil? || fuel_type == 'Gas'
      boiler.setFuelType('NaturalGas')
    else
      boiler.setFuelType(fuel_type)
    end

    if nominal_thermal_efficiency.nil?
      boiler.setNominalThermalEfficiency(0.8)
    else
      boiler.setNominalThermalEfficiency(nominal_thermal_efficiency)
    end

    if eff_curve_temp_eval_var.nil?
      boiler.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')
    else
      boiler.setEfficiencyCurveTemperatureEvaluationVariable(eff_curve_temp_eval_var)
    end

    if flow_mode.nil?
      boiler.setBoilerFlowMode('LeavingSetpointModulated')
    else
      boiler.setBoilerFlowMode(flow_mode)
    end

    if model.version < OpenStudio::VersionString.new('3.0.0')
      if lvg_temp_dsgn.nil?
        boiler.setDesignWaterOutletTemperature(OpenStudio.convert(180.0, 'F', 'C').get)
      else
        boiler.setDesignWaterOutletTemperature(OpenStudio.convert(lvg_temp_dsgn, 'F', 'C').get)
      end
    end

    if !out_temp_lmt.nil?
      boiler.setWaterOutletUpperTemperatureLimit(OpenStudio.convert(203.0, 'F', 'C').get)
    else
      boiler.setWaterOutletUpperTemperatureLimit(OpenStudio.convert(out_temp_lmt, 'F', 'C').get)
    end

    # logic to set different defaults for condensing boilers if not specified
    if draft_type == 'Condensing'
      if model.version < OpenStudio::VersionString.new('3.0.0')
        boiler.setDesignWaterOutletTemperature(OpenStudio.convert(120.0, 'F', 'C').get) if lvg_temp_dsgn.nil?
      end
      boiler.setNominalThermalEfficiency(0.96) if nominal_thermal_efficiency.nil?
    end

    if min_plr.nil?
      boiler.setMinimumPartLoadRatio(0.0)
    else
      boiler.setMinimumPartLoadRatio(min_plr)
    end

    if max_plr.nil?
      boiler.setMaximumPartLoadRatio(1.2)
    else
      boiler.setMaximumPartLoadRatio(max_plr)
    end

    if opt_plr.nil?
      boiler.setOptimumPartLoadRatio(1.0)
    else
      boiler.setOptimumPartLoadRatio(opt_plr)
    end

    boiler.setSizingFactor(sizing_factor) unless sizing_factor.nil?

    # add to supply side of hot water loop if specified
    hot_water_loop.addSupplyBranchForComponent(boiler) unless hot_water_loop.nil?

    return boiler
  end
end

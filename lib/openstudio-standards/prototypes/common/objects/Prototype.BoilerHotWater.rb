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
  # @param out_temp_lmt [Double] boiler outlet temperature limit, degrees Fahrenheit
  # @param min_plr [Double] boiler minimum part load ratio
  # @param max_plr [Double] boiler maximum part load ratio
  # @param opt_plr [Double] boiler optimum part load ratio
  # @param sizing_factor [Double] boiler oversizing factor
  def create_boiler_hot_water(model,
                              hot_water_loop: nil,
                              name: "Boiler",
                              fuel_type: "NaturalGas",
                              draft_type: "Natural",
                              nominal_thermal_efficiency: 0.80,
                              eff_curve_temp_eval_var: "LeavingBoiler",
                              flow_mode: "LeavingSetpointModulated",
                              lvg_temp_dsgn: nil,
                              out_temp_lmt: nil,
                              min_plr: nil,
                              max_plr: 1.2,
                              opt_plr: nil,
                              sizing_factor: nil)

    # create the boiler
    boiler = OpenStudio::Model::BoilerHotWater.new(model)
    if name.nil?
      if !hot_water_loop.nil?
        boiler.setName("#{hot_water_loop.name.to_s} Boiler")
      else
        boiler.setName("Boiler")
      end
    else
      boiler.setName(name)
    end

    if fuel_type.nil?
      boiler.setFuelType("NaturalGas")
    else
      boiler.setFuelType(fuel_type)
    end

    if nominal_thermal_efficiency.nil?
      boiler.setNominalThermalEfficiency(0.8)
    else
      boiler.setNominalThermalEfficiency(nominal_thermal_efficiency)
    end

    if eff_curve_temp_eval_var.nil?
      boiler.setEfficiencyCurveTemperatureEvaluationVariable("LeavingBoiler")
    else
      boiler.setEfficiencyCurveTemperatureEvaluationVariable(eff_curve_temp_eval_var)
    end

    if flow_mode.nil?
      boiler.setBoilerFlowMode("LeavingSetpointModulated")
    else
      boiler.setBoilerFlowMode(flow_mode)
    end

    # logic to set boiler design temperature and efficiency based on draft_type
    if draft_type == "Condensing"
      if lvg_temp_dsgn.nil?
        boiler.setDesignWaterOutletTemperature(OpenStudio.convert(120, 'F', 'C').get)
      else
        boiler.setDesignWaterOutletTemperature(OpenStudio.convert(lvg_temp_dsgn, 'F', 'C').get)
      end

      # higher efficiency condensing boiler
      if nominal_thermal_efficiency.nil?
        boiler.setNominalThermalEfficiency(0.96)
      end

      # TODO: add curve for condensing boiler

    else
      if lvg_temp_dsgn.nil?
        boiler.setDesignWaterOutletTemperature(OpenStudio.convert(180, 'F', 'C').get)
      else
        boiler.setDesignWaterOutletTemperature(OpenStudio.convert(lvg_temp_dsgn, 'F', 'C').get)
      end
    end

    boiler.setWaterOutletUpperTemperatureLimit(OpenStudio.convert(out_temp_lmt, 'F', 'C').get) if !out_temp_lmt.nil?
    boiler.setMinimumPartLoadRatio(min_plr) if !min_plr.nil?
    boiler.setMaximumPartLoadRatio(max_plr) if !max_plr.nil?
    boiler.setOptimumPartLoadRatio(opt_plr) if !opt_plr.nil?
    boiler.setMaximumPartLoadRatio(sizing_factor) if !sizing_factor.nil?

    if !hot_water_loop.nil?
      hot_water_loop.addSupplyBranchForComponent(boiler)
    end

    return boiler
  end
end
class Standard
  # @!group CoilHeatingWaterToAirHeatPumpEquationFit

  # Prototype CoilHeatingWaterToAirHeatPumpEquationFit object
  # Enters in default curves for coil by type of coil
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param plant_loop [<OpenStudio::Model::PlantLoop>] the coil will be placed on the demand side of this plant loop
  # @param air_loop_node [<OpenStudio::Model::Node>] the coil will be placed on this node of the air loop
  # @param name [String] the name of the system, or nil in which case it will be defaulted
  # @param type [String] the type of coil to reference the correct curve set
  # @param cop [Double] rated heating coefficient of performance
  # @return [OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit] the heating coil
  def create_coil_heating_water_to_air_heat_pump_equation_fit(model,
                                                              plant_loop,
                                                              air_loop_node: nil,
                                                              name: 'Water-to-Air HP Htg Coil',
                                                              type: nil,
                                                              cop: 4.2)

    htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model)

    # add to air loop if specified
    htg_coil.addToNode(air_loop_node) unless air_loop_node.nil?

    # set coil name
    htg_coil.setName(name)

    # add to plant loop
    if plant_loop.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'No plant loop supplied for heating coil')
      return false
    end
    plant_loop.addDemandBranchForComponent(htg_coil)

    # set coil cop
    if cop.nil?
      htg_coil.setRatedHeatingCoefficientofPerformance(4.2)
    else
      htg_coil.setRatedHeatingCoefficientofPerformance(cop)
    end

    # curve sets
    if type == 'OS default'
      # use OS default curves
    else # default curve set
      if model.version < OpenStudio::VersionString.new('3.2.0')
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
      else
        if model.getCurveByName('Water to Air Heat Pump Heating Capacity Curve').is_initialized
          heating_capacity_curve = model.getCurveByName('Water to Air Heat Pump Heating Capacity Curve').get
          heating_capacity_curve = heating_capacity_curve.to_CurveQuadLinear.get
        else
          heating_capacity_curve = OpenStudio::Model::CurveQuadLinear.new(model)
          heating_capacity_curve.setName('Water to Air Heat Pump Heating Capacity Curve')
          heating_capacity_curve.setCoefficient1Constant(0.237847462869254)
          heating_capacity_curve.setCoefficient2w(-3.35823796081626)
          heating_capacity_curve.setCoefficient3x(3.80640467406376)
          heating_capacity_curve.setCoefficient4y(0.179200417311554)
          heating_capacity_curve.setCoefficient5z(0.12860719846082)
          heating_capacity_curve.setMinimumValueofw(-100)
          heating_capacity_curve.setMaximumValueofw(100)
          heating_capacity_curve.setMinimumValueofx(-100)
          heating_capacity_curve.setMaximumValueofx(100)
          heating_capacity_curve.setMinimumValueofy(0)
          heating_capacity_curve.setMaximumValueofy(100)
          heating_capacity_curve.setMinimumValueofz(0)
          heating_capacity_curve.setMaximumValueofz(100)
        end
        htg_coil.setHeatingCapacityCurve(heating_capacity_curve)

        if model.getCurveByName('Water to Air Heat Pump Heating Power Consumption Curve').is_initialized
          heating_power_consumption_curve = model.getCurveByName('Water to Air Heat Pump Heating Power Consumption Curve').get
          heating_power_consumption_curve = heating_power_consumption_curve.to_CurveQuadLinear.get
        else
          heating_power_consumption_curve = OpenStudio::Model::CurveQuadLinear.new(model)
          heating_power_consumption_curve.setName('Water to Air Heat Pump Heating Power Consumption Curve')
          heating_power_consumption_curve.setCoefficient1Constant(-3.79175529243238)
          heating_power_consumption_curve.setCoefficient2w(3.38799239505527)
          heating_power_consumption_curve.setCoefficient3x(1.5022612076303)
          heating_power_consumption_curve.setCoefficient4y(-0.177653510577989)
          heating_power_consumption_curve.setCoefficient5z(-0.103079864171839)
          heating_power_consumption_curve.setMinimumValueofw(-100)
          heating_power_consumption_curve.setMaximumValueofw(100)
          heating_power_consumption_curve.setMinimumValueofx(-100)
          heating_power_consumption_curve.setMaximumValueofx(100)
          heating_power_consumption_curve.setMinimumValueofy(0)
          heating_power_consumption_curve.setMaximumValueofy(100)
          heating_power_consumption_curve.setMinimumValueofz(0)
          heating_power_consumption_curve.setMaximumValueofz(100)
        end
        htg_coil.setHeatingPowerConsumptionCurve(heating_power_consumption_curve)
      end

      # part load fraction correlation curve added as a required curve in OS v3.7.0
      if model.version > OpenStudio::VersionString.new('3.6.1')
        if model.getCurveByName('Water to Air Heat Pump Part Load Fraction Correlation Curve').is_initialized
          part_load_correlation_curve = model.getCurveByName('Water to Air Heat Pump Part Load Fraction Correlation Curve').get
          part_load_correlation_curve = part_load_correlation_curve.to_CurveLinear.get
        else
          part_load_correlation_curve = OpenStudio::Model::CurveLinear.new(model)
          part_load_correlation_curve.setName('Water to Air Heat Pump Part Load Fraction Correlation Curve')
          part_load_correlation_curve.setCoefficient1Constant(0.833746458696111)
          part_load_correlation_curve.setCoefficient2x(0.166253541303889)
          part_load_correlation_curve.setMinimumValueofx(0)
          part_load_correlation_curve.setMaximumValueofx(1)
          part_load_correlation_curve.setMinimumCurveOutput(0)
          part_load_correlation_curve.setMaximumCurveOutput(1)
        end
        htg_coil.setPartLoadFractionCorrelationCurve(part_load_correlation_curve)
      end
    end

    return htg_coil
  end
end

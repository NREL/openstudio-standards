class Standard
  # @!group CoilHeatingWaterToAirHeatPumpEquationFit

  # Prototype CoilHeatingWaterToAirHeatPumpEquationFit object
  # Enters in default curves for coil by type of coil
  # @param name [String] the name of the system, or nil in which case it will be defaulted
  # @param type [String] the type of coil to reference the correct curve set
  # @param cop [Double] rated heating coefficient of performance
  def create_coil_heating_water_to_air_heat_pump_equation_fit(model, name: "Water-to-Air HP Htg Coil", type: nil, cop: 4.2)

    htg_coil = OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit.new(model)

    # set coil name
    htg_coil.setName(name)

    # set coil cop
    htg_coil.setRatedCoolingCoefficientofPerformance(cop)

    # curve sets
    if type == 'OS default'
      # use OS default curves
    else # default curve set
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
    end

    return htg_coil
  end
end
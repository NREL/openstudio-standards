class Standard
  # @!group CoilHeatingWaterToAirHeatPumpEquationFit

  # Prototype CoilHeatingWaterToAirHeatPumpEquationFit object
  # Enters in default curves for coil by type of coil
  # @param plant_loop [<OpenStudio::Model::PlantLoop>] the coil will be placed on the demand side of this plant loop
  # @param air_loop_node [<OpenStudio::Model::Node>] the coil will be placed on this node of the air loop
  # @param name [String] the name of the system, or nil in which case it will be defaulted
  # @param type [String] the type of coil to reference the correct curve set
  # @param cop [Double] rated heating coefficient of performance
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

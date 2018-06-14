class Standard
  # @!group AirConditionerVariableRefrigerantFlow

  # Prototype AirConditionerVariableRefrigerantFlow object
  # Enters in default curves for coil by type of coil
  # @param name [String] the name of the system, or nil in which case it will be defaulted
  # @param schedule [String] name of the availability schedule, or [<OpenStudio::Model::Schedule>] Schedule object, or nil in which case default to always on
  # @param type [String] the type of unit to reference for the correct curve set
  # @param cooling_cop [Double] rated cooling coefficient of performance
  # @param heating_cop [Double] rated heating coefficient of performance
  # @param heat_recovery [Bool] does the unit have heat recovery
  # @param defrost_strategy [String] type of defrost strategy. options are reverse-cycle or resistive
  # @param condenser_type [String] type of condenser
  #   options are AirCooled (default), WaterCooled, and EvaporativelyCooled.
  #   if WaterCooled, the user most include a condenser_loop
  # @param master_zone [<OpenStudio::Model::ThermalZone>] master control zone to switch between heating and cooling
  # @param priority_control_type [String] type of master thermostat priority control type
  #   options are LoadPriority, ZonePriority, ThermostatOffsetPriority, MasterThermostatPriority
  def create_air_conditioner_variable_refrigerant_flow(model, name: "VRF System",
                                                       schedule: nil, type: nil,
                                                       cooling_cop: 4.0, heating_cop: 4.0,
                                                       heat_recovery: true, defrost_strategy: "Resistive",
                                                       condenser_type: "AirCooled", condenser_loop: nil,
                                                       master_zone: nil, priority_control_type: "ZonePriority")

    vrf_outdoor_unit = OpenStudio::Model::AirConditionerVariableRefrigerantFlow.new(model)

    # set name
    vrf_outdoor_unit.setName(name)

    # set availability schedule
    availability_schedule = nil
    if schedule.nil?
      # default always on
      availability_schedule = model.alwaysOnDiscreteSchedule
    elsif schedule.class == String
      availability_schedule = model_add_schedule(model, schedule)

      if availability_schedule.nil? && schedule == "alwaysOffDiscreteSchedule"
        availability_schedule = model.alwaysOffDiscreteSchedule
      elsif availability_schedule.nil?
        availability_schedule = model.alwaysOnDiscreteSchedule
      end
    elsif !schedule.to_Schedule.empty?
      availability_schedule = schedule
    else
      availability_schedule = model.alwaysOnDiscreteSchedule
    end
    vrf_outdoor_unit.setAvailabilitySchedule(availability_schedule)

    # set cops
    vrf_outdoor_unit.setRatedCoolingCOP(cooling_cop)
    vrf_outdoor_unit.setRatedHeatingCOP(heating_cop)

    # heat recovery
    if heat_recovery
      vrf_outdoor_unit.setHeatPumpWasteHeatRecovery(true)
    else
      vrf_outdoor_unit.setHeatPumpWasteHeatRecovery(false)
    end

    # defrost strategy
    vrf_outdoor_unit.setDefrostStrategy(defrost_strategy)

    # defaults
    vrf_outdoor_unit.setMinimumOutdoorTemperatureinCoolingMode(-6.0)
    vrf_outdoor_unit.setMinimumOutdoorTemperatureinHeatingMode(-20.0)
    vrf_outdoor_unit.setEquivalentPipingLengthusedforPipingCorrectionFactorinCoolingMode(30.48)
    vrf_outdoor_unit.setEquivalentPipingLengthusedforPipingCorrectionFactorinHeatingMode(30.48)
    vrf_outdoor_unit.setVerticalHeightusedforPipingCorrectionFactor(10.668)

    # condenser type
    if condenser_type == "WaterCooled"
      vrf_outdoor_unit.setString(56, condenser_type)
      # require condenser_loop
      if !condenser_loop
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.Model.Model', "Must specify condenser_loop for vrf_outdoor_unit if WaterCooled")
      end
      condenser_loop.addDemandBranchForComponent(vrf_outdoor_unit)
    elsif condenser_type == "EvaporativelyCooled"
      vrf_outdoor_unit.setString(56, condenser_type)
    end

    # set master zone
    if !master_zone.to_ThermalZone.empty?
      vrf_outdoor_unit.setZoneforMasterThermostatLocation(master_zone)
      vrf_outdoor_unit.setMasterThermostatPriorityControlType(priority_control_type)
    end

    vrf_heat_cap_f_of_low_temp = nil
    vrf_heat_cap_f_of_high_temp = nil
    vrf_heat_cap_ratio_boundary = nil
    vrf_heat_eir_f_of_low_temp = nil
    vrf_heat_eir_f_of_high_temp = nil
    heating_eir_low_plr = nil
    heating_eir_hi_plr = nil
    vrf_heat_eir_boundary = nil
    vrf_heating_comb_ratio = nil
    vrf_cplff_plr = nil

    # curve sets
    # TODO: update and add cooling curves based on manufacturer data
    if type == 'OS default'

      # use OS default curves

    else # default curve set

      # Heating Capacity Ratio Modifier Function of Low Temperature Curve Name
      vrf_heat_cap_f_of_low_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      vrf_heat_cap_f_of_low_temp.setCoefficient1Constant(1.014599599)
      vrf_heat_cap_f_of_low_temp.setCoefficient2x(-0.002506703)
      vrf_heat_cap_f_of_low_temp.setCoefficient3xPOW2(-0.000141599)
      vrf_heat_cap_f_of_low_temp.setCoefficient4y(0.026931595)
      vrf_heat_cap_f_of_low_temp.setCoefficient5yPOW2(1.83538E-06)
      vrf_heat_cap_f_of_low_temp.setCoefficient6xTIMESY(-0.000358147)
      vrf_heat_cap_f_of_low_temp.setMinimumValueofx(15)
      vrf_heat_cap_f_of_low_temp.setMaximumValueofx(27)
      vrf_heat_cap_f_of_low_temp.setMinimumValueofy(-20)
      vrf_heat_cap_f_of_low_temp.setMaximumValueofy(15)

      # Heating Capacity Ratio Modifier Function of High Temperature Curve Name
      vrf_heat_cap_f_of_high_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      vrf_heat_cap_f_of_high_temp.setCoefficient1Constant(1.161134821)
      vrf_heat_cap_f_of_high_temp.setCoefficient2x(0.027478868)
      vrf_heat_cap_f_of_high_temp.setCoefficient3xPOW2(-0.00168795)
      vrf_heat_cap_f_of_high_temp.setCoefficient4y(0.001783378)
      vrf_heat_cap_f_of_high_temp.setCoefficient5yPOW2(2.03208E-06)
      vrf_heat_cap_f_of_high_temp.setCoefficient6xTIMESY(-6.8969E-05)
      vrf_heat_cap_f_of_high_temp.setMinimumValueofx(15)
      vrf_heat_cap_f_of_high_temp.setMaximumValueofx(27)
      vrf_heat_cap_f_of_high_temp.setMinimumValueofy(-10)
      vrf_heat_cap_f_of_high_temp.setMaximumValueofy(15)

      # Heating Capacity Ratio Boundary Curve Name
      vrf_heat_cap_ratio_boundary = OpenStudio::Model::CurveCubic.new(model)
      vrf_heat_cap_ratio_boundary.setCoefficient1Constant(-7.6000882)
      vrf_heat_cap_ratio_boundary.setCoefficient2x(3.05090016)
      vrf_heat_cap_ratio_boundary.setCoefficient3xPOW2(-0.1162844)
      vrf_heat_cap_ratio_boundary.setCoefficient4xPOW3(0.0)
      vrf_heat_cap_ratio_boundary.setMinimumValueofx(15)
      vrf_heat_cap_ratio_boundary.setMaximumValueofx(27)

      # Heating Energy Input Ratio Modifier Function of Low Temperature Curve Name
      vrf_heat_eir_f_of_low_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      vrf_heat_eir_f_of_low_temp.setCoefficient1Constant(0.87465501)
      vrf_heat_eir_f_of_low_temp.setCoefficient2x(-0.01319754)
      vrf_heat_eir_f_of_low_temp.setCoefficient3xPOW2(0.00110307)
      vrf_heat_eir_f_of_low_temp.setCoefficient4y(-0.0133118)
      vrf_heat_eir_f_of_low_temp.setCoefficient5yPOW2(0.00089017)
      vrf_heat_eir_f_of_low_temp.setCoefficient6xTIMESY(-0.00012766)
      vrf_heat_eir_f_of_low_temp.setMinimumValueofx(15)
      vrf_heat_eir_f_of_low_temp.setMaximumValueofx(27)
      vrf_heat_eir_f_of_low_temp.setMinimumValueofy(-20)
      vrf_heat_eir_f_of_low_temp.setMaximumValueofy(12)

      # Heating Energy Input Ratio Modifier Function of High Temperature Curve Name
      vrf_heat_eir_f_of_high_temp = OpenStudio::Model::CurveBiquadratic.new(model)
      vrf_heat_eir_f_of_high_temp.setCoefficient1Constant(2.504005146)
      vrf_heat_eir_f_of_high_temp.setCoefficient2x(-0.05736767)
      vrf_heat_eir_f_of_high_temp.setCoefficient3xPOW2(4.07336E-05)
      vrf_heat_eir_f_of_high_temp.setCoefficient4y(-0.12959669)
      vrf_heat_eir_f_of_high_temp.setCoefficient5yPOW2(0.00135839)
      vrf_heat_eir_f_of_high_temp.setCoefficient6xTIMESY(0.00317047)
      vrf_heat_eir_f_of_high_temp.setMinimumValueofx(15)
      vrf_heat_eir_f_of_high_temp.setMaximumValueofx(27)
      vrf_heat_eir_f_of_high_temp.setMinimumValueofy(-20)
      vrf_heat_eir_f_of_high_temp.setMaximumValueofy(15)

      # Heating Energy Input Ratio Modifier Function of Low Part-Load Ratio Curve Name
      heating_eir_low_plr = OpenStudio::Model::CurveCubic.new(model)
      heating_eir_low_plr.setCoefficient1Constant(0.1400093)
      heating_eir_low_plr.setCoefficient2x(0.6415002)
      heating_eir_low_plr.setCoefficient3xPOW2(0.1339047)
      heating_eir_low_plr.setCoefficient4xPOW3(0.0845859)
      heating_eir_low_plr.setMinimumValueofx(0)
      heating_eir_low_plr.setMaximumValueofx(1)

      # Heating Energy Input Ratio Modifier Function of High Part-Load Ratio Curve Name
      heating_eir_hi_plr = OpenStudio::Model::CurveQuadratic.new(model)
      heating_eir_hi_plr.setCoefficient1Constant(2.4294355)
      heating_eir_hi_plr.setCoefficient2x(-2.235887)
      heating_eir_hi_plr.setCoefficient3xPOW2(0.8064516)
      heating_eir_hi_plr.setMinimumValueofx(0.0)
      heating_eir_hi_plr.setMaximumValueofx(1.5)

      # Heating Energy Input Ratio Boundary Curve Name
      vrf_heat_eir_boundary = OpenStudio::Model::CurveCubic.new(model)
      vrf_heat_eir_boundary.setCoefficient1Constant(-7.6000882)
      vrf_heat_eir_boundary.setCoefficient2x(3.05090016)
      vrf_heat_eir_boundary.setCoefficient3xPOW2(-0.1162844)
      vrf_heat_eir_boundary.setCoefficient4xPOW3(0.0)
      vrf_heat_eir_boundary.setMinimumValueofx(-20)
      vrf_heat_eir_boundary.setMaximumValueofx(15)

      # Heating Combination Ratio Correction Factor Curve Name
      vrf_heating_comb_ratio = OpenStudio::Model::CurveLinear.new(model)
      vrf_heating_comb_ratio.setCoefficient1Constant(0.96034)
      vrf_heating_comb_ratio.setCoefficient2x(0.03966)
      vrf_heating_comb_ratio.setMinimumValueofx(1.0)
      vrf_heating_comb_ratio.setMaximumValueofx(1.5)
      vrf_heating_comb_ratio.setMinimumCurveOutput(1.0)
      vrf_heating_comb_ratio.setMaximumCurveOutput(1.023)

      # Heating Part-Load Fraction Correlation Curve Name
      vrf_cplff_plr = OpenStudio::Model::CurveQuadratic.new(model)
      vrf_cplff_plr.setCoefficient1Constant(0.85)
      vrf_cplff_plr.setCoefficient2x(0.15)
      vrf_cplff_plr.setCoefficient3xPOW2(0)
      vrf_cplff_plr.setMinimumValueofx(0.0)
      vrf_cplff_plr.setMaximumValueofx(1.0)
      vrf_cplff_plr.setMinimumCurveOutput(0.85)
      vrf_cplff_plr.setMaximumCurveOutput(1.0)
    end

    vrf_outdoor_unit.setHeatingCapacityRatioModifierFunctionofLowTemperatureCurve(vrf_heat_cap_f_of_low_temp) if !vrf_heat_cap_f_of_low_temp.nil?
    vrf_outdoor_unit.setHeatingCapacityRatioModifierFunctionofHighTemperatureCurve(vrf_heat_cap_f_of_high_temp) if !vrf_heat_cap_f_of_high_temp.nil?
    vrf_outdoor_unit.setHeatingCapacityRatioBoundaryCurve(vrf_heat_cap_ratio_boundary) if !vrf_heat_cap_ratio_boundary.nil?
    vrf_outdoor_unit.setHeatingEnergyInputRatioModifierFunctionofLowTemperatureCurve(vrf_heat_eir_f_of_low_temp) if !vrf_heat_eir_f_of_low_temp.nil?
    vrf_outdoor_unit.setHeatingEnergyInputRatioModifierFunctionofHighTemperatureCurve(vrf_heat_eir_f_of_high_temp) if !vrf_heat_eir_f_of_high_temp.nil?
    vrf_outdoor_unit.setHeatingEnergyInputRatioModifierFunctionofLowPartLoadRatioCurve(heating_eir_low_plr) if !heating_eir_low_plr.nil?
    vrf_outdoor_unit.setHeatingEnergyInputRatioModifierFunctionofHighPartLoadRatioCurve(heating_eir_hi_plr) if !heating_eir_hi_plr.nil?
    vrf_outdoor_unit.setHeatingEnergyInputRatioBoundaryCurve(vrf_heat_eir_boundary) if !vrf_heat_eir_boundary.nil?
    vrf_outdoor_unit.setHeatingCombinationRatioCorrectionFactorCurve(vrf_heating_comb_ratio) if !vrf_heating_comb_ratio.nil?
    vrf_outdoor_unit.setHeatingPartLoadFractionCorrelationCurve(vrf_cplff_plr) if !vrf_cplff_plr.nil?

    return vrf_outdoor_unit
  end
end
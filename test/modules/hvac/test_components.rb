require_relative '../../helpers/minitest_helper'

class TestHVACComponents < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
    FileUtils.mkdir "#{__dir__}/output" unless Dir.exist? "#{__dir__}/output"
  end

  def test_create_boiler_hot_water
    model = OpenStudio::Model::Model.new

    boiler = @hvac.create_boiler_hot_water(model)
    assert(boiler.is_a?(OpenStudio::Model::BoilerHotWater), 'Expected boiler to be a BoilerHotWater object')
    assert_equal('Boiler', boiler.name.to_s, 'Expected boiler name to be Boiler')
    assert_equal('NaturalGas', boiler.fuelType.to_s, 'Expected boiler fuel type to be NaturalGas')
    assert_in_delta(0.8, boiler.nominalThermalEfficiency, 0.01, 'Expected boiler nominal thermal efficiency to be 0.8')
    assert_equal('LeavingBoiler', boiler.efficiencyCurveTemperatureEvaluationVariable.to_s, 'Expected boiler efficiency curve temperature evaluation variable to be LeavingBoiler')
    assert_equal('LeavingSetpointModulated', boiler.boilerFlowMode.to_s, 'Expected boiler flow mode to be LeavingSetpointModulated')
    assert_in_delta(OpenStudio.convert(203.0, 'F', 'C').get, boiler.waterOutletUpperTemperatureLimit, 0.1, 'Expected boiler design water outlet temperature to be 180.0 F')
    assert_in_delta(0.0, boiler.minimumPartLoadRatio, 0.01, 'Expected boiler minimum load to be 0.0')
    assert_in_delta(1.2, boiler.maximumPartLoadRatio, 0.01, 'Expected boiler maximum load to be 1.2')
    assert_in_delta(1.0, boiler.optimumPartLoadRatio, 0.01, 'Expected boiler optimal load to be 1.0')
    assert_in_delta(1.0, boiler.sizingFactor, 0.01, 'Expected boiler sizing factor to be 1.0')
  end

  def test_create_coil_cooling_dx_single_speed
    model = OpenStudio::Model::Model.new

    coil = @hvac.create_coil_cooling_dx_single_speed(model)
    assert(coil.is_a?(OpenStudio::Model::CoilCoolingDXSingleSpeed), 'Expected coil to be a CoilCoolingDXSingleSpeed object')
  end

  def test_create_coil_cooling_dx_two_speed
    model = OpenStudio::Model::Model.new

    coil = @hvac.create_coil_cooling_dx_two_speed(model)
    assert(coil.is_a?(OpenStudio::Model::CoilCoolingDXTwoSpeed), 'Expected coil to be a CoilCoolingDXTwoSpeed object')
  end

  def test_create_coil_cooling_water_to_air_heat_pump_equation_fit
    model = OpenStudio::Model::Model.new
    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    air_loop_node = OpenStudio::Model::Node.new(model)

    coil = @hvac.create_coil_cooling_water_to_air_heat_pump_equation_fit(model, plant_loop, air_loop_node: air_loop_node)
    assert(coil.is_a?(OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit), 'Expected coil to be a CoilCoolingWaterToAirHeatPumpEquationFit object')
    assert_equal('Water-to-Air HP Clg Coil', coil.name.to_s, "Expected coil name to be 'Water-to-Air HP Clg Coil'")
  end

  def test_create_coil_cooling_water
    model = OpenStudio::Model::Model.new
    plant_loop = OpenStudio::Model::PlantLoop.new(model)

    coil = @hvac.create_coil_cooling_water(model, plant_loop)
    assert(coil.is_a?(OpenStudio::Model::CoilCoolingWater), 'Expected coil to be a CoilCoolingWater object')
  end

  def test_create_coil_heating_dx_single_speed
    model = OpenStudio::Model::Model.new

    coil = @hvac.create_coil_heating_dx_single_speed(model)
    assert(coil.is_a?(OpenStudio::Model::CoilHeatingDXSingleSpeed), 'Expected coil to be a CoilHeatingDXSingleSpeed object')
  end

  def test_create_coil_heating_electric
    model = OpenStudio::Model::Model.new

    coil = @hvac.create_coil_heating_electric(model)
    assert(coil.is_a?(OpenStudio::Model::CoilHeatingElectric), 'Expected coil to be a CoilHeatingElectric object')
  end

  def test_create_coil_heating_gas
    model = OpenStudio::Model::Model.new

    coil = @hvac.create_coil_heating_gas(model)
    assert(coil.is_a?(OpenStudio::Model::CoilHeatingGas), 'Expected coil to be a CoilHeatingGas object')
  end

  def test_create_coil_heating_water_to_air_heat_pump_equation_fit
    model = OpenStudio::Model::Model.new
    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    air_loop_node = OpenStudio::Model::Node.new(model)

    coil = @hvac.create_coil_heating_water_to_air_heat_pump_equation_fit(model, plant_loop, air_loop_node: air_loop_node)
    assert(coil.is_a?(OpenStudio::Model::CoilHeatingWaterToAirHeatPumpEquationFit), 'Expected coil to be a CoilHeatingWaterToAirHeatPumpEquationFit object')
    assert_equal('Water-to-Air HP Htg Coil', coil.name.to_s, "Expected coil name to be 'Water-to-Air HP Htg Coil'")
  end

  def test_create_coil_heating_water
    model = OpenStudio::Model::Model.new
    plant_loop = OpenStudio::Model::PlantLoop.new(model)

    coil = @hvac.create_coil_heating_water(model, plant_loop)
    assert(coil.is_a?(OpenStudio::Model::CoilHeatingWater), 'Expected coil to be a CoilHeatingWater object')
  end

  def test_create_hx_air_to_air_sensible_and_latent
    model = OpenStudio::Model::Model.new

    hx = @hvac.create_hx_air_to_air_sensible_and_latent(model,
                                                        name: "ERV HX",
                                                        type: 'Rotary',
                                                        economizer_lockout: false,
                                                        supply_air_outlet_temperature_control: false,
                                                        frost_control_type: 'ExhaustOnly')
    assert(hx.is_a?(OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent), 'Expected hx to be a HeatExchangerAirToAirSensibleAndLatent object')
    assert_equal('ERV HX', hx.name.to_s, "Expected hx name to be 'ERV HX'")
    assert_equal('Rotary', hx.heatExchangerType.to_s, "'Expected hx type to be 'Rotary'")
    assert_equal(false, hx.economizerLockout, 'Expected hx economizer lockout to be false')
    assert_equal(false, hx.supplyAirOutletTemperatureControl, 'Expected hx supply air outlet temperature control to be false')
    assert_equal('ExhaustOnly', hx.frostControlType.to_s, "Expected hx frost control type to be 'ExhaustOnly'")
  end
end
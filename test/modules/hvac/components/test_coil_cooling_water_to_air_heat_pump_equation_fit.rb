require_relative '../../../helpers/minitest_helper'

class TestHVACCoilCoolingWaterToAirHeatPumpEquationFit < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
  end

  def test_create_coil_cooling_water_to_air_heat_pump_equation_fit
    model = OpenStudio::Model::Model.new
    plant_loop = OpenStudio::Model::PlantLoop.new(model)
    air_loop_node = OpenStudio::Model::Node.new(model)

    coil = @hvac.create_coil_cooling_water_to_air_heat_pump_equation_fit(model, plant_loop, air_loop_node: air_loop_node)
    assert(coil.is_a?(OpenStudio::Model::CoilCoolingWaterToAirHeatPumpEquationFit), 'Expected coil to be a CoilCoolingWaterToAirHeatPumpEquationFit object')
    assert_equal('Water-to-Air HP Clg Coil', coil.name.to_s, "Expected coil name to be 'Water-to-Air HP Clg Coil'")
  end
end

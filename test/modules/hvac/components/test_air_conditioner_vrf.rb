require_relative '../../../helpers/minitest_helper'

class TestHVACAirConditionerVRF < Minitest::Test
  def setup
    @hvac = OpenstudioStandards::HVAC
  end

  def test_create_air_conditioner_variable_refrigerant_flow
    model = OpenStudio::Model::Model.new
    thermal_zone = OpenStudio::Model::ThermalZone.new(model)
    thermal_zone.setName('VRF Master Thermal Zone')

    vrf = @hvac.create_air_conditioner_variable_refrigerant_flow(model)
    assert(vrf.is_a?(OpenStudio::Model::AirConditionerVariableRefrigerantFlow), 'Expected vrf to be an AirConditionerVariableRefrigerantFlow object')
    assert_equal('VRF System', vrf.name.to_s, "Expected AirConditionerVariableRefrigerantFlow name to be 'VRF System'")
    assert_equal('ReverseCycle', vrf.defrostStrategy, "Expected defrost strategy should be 'Resistive'")

    vrf = @hvac.create_air_conditioner_variable_refrigerant_flow(model, master_zone: thermal_zone)
    assert(vrf.is_a?(OpenStudio::Model::AirConditionerVariableRefrigerantFlow), 'Expected vrf to be an AirConditionerVariableRefrigerantFlow object')
    assert_equal('VRF Master Thermal Zone', vrf.zoneforMasterThermostatLocation.get.name.to_s, "Expected master zone to be 'VRF Master Thermal Zone'")
  end
end

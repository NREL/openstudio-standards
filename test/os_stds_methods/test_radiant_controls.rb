require_relative '../helpers/minitest_helper'
require_relative '../helpers/hvac_system_test_helper'

class TestRadiantControls < Minitest::Test
  def test_default_radiant_controls
    arguments = {model_test_name: 'default_radiant', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR'}

    errs = model_radiant_system_test(arguments)
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_default_radiant_ceiling
    arguments = {model_test_name: 'default_radiant_ceiling', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling'}

    errs = model_radiant_system_test(arguments)
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end
end

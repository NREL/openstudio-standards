require_relative '../helpers/minitest_helper'
require_relative '../helpers/hvac_system_test_helper'

class TestRadiantControls < Minitest::Test
  def test_default_radiant_controls
    arguments = {model_test_name: 'default_radiant', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       unmet_hrs_htg: 600.0, unmet_hrs_clg: 2750.0}

    errs = model_radiant_system_test(arguments)
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_default_radiant_ceiling
    arguments = {model_test_name: 'default_radiant_ceiling', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling', unmet_hrs_htg: 500.0, unmet_hrs_clg: 1500.0}

    errs = model_radiant_system_test(arguments)
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_whole_building_hours
    arguments = {model_test_name: 'whole_building_hours', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling', use_zone_occupancy_for_control: false, unmet_hrs_htg: 500.0, unmet_hrs_clg: 2500.0}

    errs = model_radiant_system_test(arguments)
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_two_pipe_plant_based_on_oat
    arguments = {model_test_name: 'two_pipe_plant_based_on_oat', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling', use_zone_occupancy_for_control: false, two_pipe_system: true, two_pipe_control_strategy: 'outdoor_air_lockout',
       unmet_hrs_htg: 500.0, unmet_hrs_clg: 3000.0}

    errs = model_radiant_system_test(arguments)
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_two_pipe_plant_based_on_zone_demand
    arguments = {model_test_name: 'two_pipe_plant_based_on_zone', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling', use_zone_occupancy_for_control: false, two_pipe_system: true, two_pipe_control_strategy: 'zone_demand',
       unmet_hrs_htg: 500.0, unmet_hrs_clg: 2500.0}

    errs = model_radiant_system_test(arguments)
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_plant_supply_water_temperature_based_on_oat
    arguments = {model_test_name: 'plant_supply_water_temperature_based_on_oat', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling', use_zone_occupancy_for_control: false, two_pipe_system: true, two_pipe_control_strategy: 'zone_demand',
       plant_supply_water_temperature_control: true, plant_supply_water_temperature_control_strategy: 'outdoor_air',
       unmet_hrs_htg: 500.0, unmet_hrs_clg: 2500.0}

    errs = model_radiant_system_test(arguments)
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end

  def test_plant_supply_water_temperature_based_on_zone_demand
    arguments = {model_test_name: 'plant_supply_water_temperature_based_on_zone_demand', main_heat_fuel: 'NaturalGas', cool_fuel: 'Electricity',
       hot_water_loop_type: 'LowTemperature', climate_zone: 'ASHRAE 169-2013-5B', model_name: 'basic_2_story_office_no_hvac_20WWR',
       radiant_type: 'ceiling', use_zone_occupancy_for_control: false, two_pipe_system: true, two_pipe_control_strategy: 'zone_demand',
       plant_supply_water_temperature_control: true, plant_supply_water_temperature_control_strategy: 'zone_demand',
       unmet_hrs_htg: 600.0, unmet_hrs_clg: 2500.0}

    errs = model_radiant_system_test(arguments)
    assert(errs.empty?, "Radiant slab system model failed with errors: #{errs}")
  end
end

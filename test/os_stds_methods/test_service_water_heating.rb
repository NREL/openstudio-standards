require_relative '../helpers/minitest_helper'

class TestServiceWaterHeating < Minitest::Test
  def test_add_hpwh_with_ems
    test_name = 'test_add_hpwh_with_ems'
    # Load model
    std = Standard.build('90.1-2013')
    model = std.safe_load_model("#{File.dirname(__FILE__)}/models/QuickServiceRestaurant_2A_2010.osm")

    # get existing water heater properties
    wh = model.getWaterHeaterMixedByName('100.0gal Natural Gas Water Heater - 100kBtu/hr 0.81 Therm Eff').get
    wh_capacity_w = wh.heaterMaximumCapacity.get
    wh_volume_m3_per_s = wh.tankVolume.get
    wh_setpoint_schedule = wh.setpointTemperatureSchedule.get
    kitchen_zone = model.getThermalZoneByName('Kitchen ZN').get
    service_water_loop = wh.plantLoop.get

    # add heat pump water heater
    hpwh = std.model_add_heatpump_water_heater(model,
      type: 'WrappedCondenser',
      water_heater_capacity: wh_capacity_w,
      electric_backup_capacity: wh_capacity_w,
      water_heater_volume: wh_volume_m3_per_s,
      swh_temp_sch: wh_setpoint_schedule,
      water_heater_thermal_zone: kitchen_zone,
      use_ems_control: true)

    # add to plant loop
    service_water_loop.addSupplyBranchForComponent(hpwh.tank)

    # remove existing water heater
    wh.remove

    #puts 'weather path:'
    #puts OpenstudioStandards::Weather.model_get_full_weather_file_path(model)
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: 'ASHRAE 169-2013-3A')
    annual_run_success = std.model_run_simulation_and_log_errors(model, "output/#{test_name}/AR")
    assert(annual_run_success)

    # run the model to make sure it applies correctly
    # model.save("output/#{test_name}_out.osm", true)
  end

  def test_add_hpwh_without_ems
    test_name = 'test_add_hpwh_without_ems'
    # Load model
    std = Standard.build('90.1-2013')
    model = std.safe_load_model("#{File.dirname(__FILE__)}/models/QuickServiceRestaurant_2A_2010.osm")

    # get existing water heater properties
    wh = model.getWaterHeaterMixedByName('100.0gal Natural Gas Water Heater - 100kBtu/hr 0.81 Therm Eff').get
    wh_capacity_w = wh.heaterMaximumCapacity.get
    wh_volume_m3_per_s = wh.tankVolume.get
    wh_setpoint_schedule = wh.setpointTemperatureSchedule.get
    kitchen_zone = model.getThermalZoneByName('Kitchen ZN').get
    service_water_loop = wh.plantLoop.get

    # add heat pump water heater
    hpwh = std.model_add_heatpump_water_heater(model,
      type: 'WrappedCondenser',
      water_heater_capacity: wh_capacity_w,
      electric_backup_capacity: wh_capacity_w,
      water_heater_volume: wh_volume_m3_per_s,
      swh_temp_sch: wh_setpoint_schedule,
      water_heater_thermal_zone: kitchen_zone,
      use_ems_control: false)

    # add to plant loop
    service_water_loop.addSupplyBranchForComponent(hpwh.tank)

    # remove existing water heater
    wh.remove

    #puts 'weather path:'
    #puts OpenstudioStandards::Weather.model_get_full_weather_file_path(model)
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: 'ASHRAE 169-2013-3A')
    annual_run_success = std.model_run_simulation_and_log_errors(model, "output/#{test_name}/AR")
    assert(annual_run_success)

    # run the model to make sure it applies correctly
    # model.save("output/#{test_name}_out.osm", true)
  end

  def test_water_heater_sub_type
    std = Standard.build('90.1-2019')

    # Gas water heaters
    assert(std.water_heater_determine_sub_type('NaturalGas', 74000, 5) == "residential_duty")
    assert(std.water_heater_determine_sub_type('NaturalGas', 74000, 20) == "consumer_storage")
    assert(std.water_heater_determine_sub_type('NaturalGas', 76000, 5) == "residential_duty")

    # Electricity water heaters
    assert(std.water_heater_determine_sub_type('Electricity', 74000, 5).nil?)
    assert(std.water_heater_determine_sub_type('Electricity', 74000, 2) == "residential_duty")
    assert(std.water_heater_determine_sub_type('Electricity', 300000, 2) == "instantaneous")
  end

  def test_uef_to_ef()
    std = Standard.build('90.1-2019')
    model = OpenStudio::Model::Model.new
    water_heater = OpenStudio::Model::WaterHeaterMixed.new(model)
    assert(std.water_heater_convert_uniform_energy_factor_to_energy_factor(water_heater, 'Electricity', 1, 1, 1) == 1.0194)
    assert(std.water_heater_convert_uniform_energy_factor_to_energy_factor(water_heater, 'Electricity', 1, 300000, 2) == 1)
    assert(std.water_heater_convert_uniform_energy_factor_to_energy_factor(water_heater, 'Electricity', 0, 74000, 2) == -0.0025)
    assert(std.water_heater_convert_uniform_energy_factor_to_energy_factor(water_heater, 'NaturalGas', 0, 76000, 5) == 0.0019)
    assert(std.water_heater_convert_uniform_energy_factor_to_energy_factor(water_heater, 'NaturalGas', 0, 74000, 20) == 0.0711)
  end
end

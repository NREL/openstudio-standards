require_relative '../../helpers/minitest_helper'

class TestEnergyUse < Minitest::Test
  def setup
    @sql_file_path = 'output/AR/run/eplusout.sql'

    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)

    # load model and set weather file
    @model = std.safe_load_model("#{File.dirname(__FILE__)}/../../doe_prototype/regression_models/PrimarySchool-90.1-2013-ASHRAE 169-2013-4A_expected_result.osm")
    weather_file_path = OpenstudioStandards::Weather.climate_zone_representative_weather_file_path(climate_zone)
    epw_file = OpenStudio::EpwFile.new(weather_file_path)
    OpenStudio::Model::WeatherFile.setWeatherFile(@model, epw_file)

    # run simulation to create the .sql file
    std.model_run_simulation_and_log_errors(@model, 'output/AR')
    sql = OpenStudio::SqlFile.new(@sql_file_path)
    @model.setSqlFile(sql)
  end

  def test_model_get_annual_energy_by_fuel_and_enduse
    result = OpenstudioStandards::SqlFile.model_get_annual_energy_by_fuel_and_enduse(@model, 'Electricity', 'Interior Lighting')
    assert_in_delta(697.42, result, 1.0)
  end

  def test_model_get_dd_energy_by_fuel_and_enduse
    result = OpenstudioStandards::SqlFile.model_get_dd_energy_by_fuel_and_enduse(@model, 'Electricity', 'Interior Lighting')
    assert_in_delta(0.0, result, 1.0)
  end

  def test_model_get_annual_results_by_end_use_and_fuel_type
    result = OpenstudioStandards::SqlFile.model_get_annual_results_by_end_use_and_fuel_type(@model)
    assert_in_delta(291.24, result['Heating|Natural Gas'], 1.0)
    assert_in_delta(1157.41, result['Interior Equipment|Electricity'], 0.1)
    assert_in_delta(367.71, result['Interior Equipment|Natural Gas'], 0.1)
    assert_in_delta(749.49, result['Water Systems|Water'], 0.1)
  end

  def test_model_get_dd_results_by_end_use_and_fuel_type
    result = OpenstudioStandards::SqlFile.model_get_dd_results_by_end_use_and_fuel_type(@model)
    assert_in_delta(697418844177.0164, result['InteriorLights|Electricity'], 1000.0)
  end

  def test_model_get_annual_eui_kbtu_per_ft2_by_fuel_and_enduse
    result = OpenstudioStandards::SqlFile.model_get_annual_eui_kbtu_per_ft2_by_fuel_and_enduse(@model, 'Electricity', 'Interior Lighting')
    assert_in_delta(8.938, result, 0.1)
  end

  def test_model_get_annual_eui_kbtu_per_ft2
    result = OpenstudioStandards::SqlFile.model_get_annual_eui_kbtu_per_ft2(@model)
    assert_in_delta(49.465, result, 1.0)
  end
end

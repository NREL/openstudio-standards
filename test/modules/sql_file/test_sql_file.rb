require_relative '../../helpers/minitest_helper'

class TestSqlFile < Minitest::Test
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

  def test_sql_file_safe_load
    result = OpenstudioStandards::SqlFile.sql_file_safe_load(@sql_file_path)
    assert('OpenStudio::SqlFile', result.class)
  end

  def test_model_tabular_data_query
    result = OpenstudioStandards::SqlFile.model_tabular_data_query(@model, 'AnnualBuildingUtilityPerformanceSummary', 'Building Area', 'Total Building Area', 'Area', 'm2')
    assert(6871.0, result)
  end

  def test_model_get_weather_run_period
    result = OpenstudioStandards::SqlFile.model_get_weather_run_period(@model)
    assert('RUN PERIOD 1', result)
  end

  def test_model_get_sql_file
    result = OpenstudioStandards::SqlFile.model_get_sql_file(@model)
    assert('OpenStudio::SqlFile', result.class)
  end
end

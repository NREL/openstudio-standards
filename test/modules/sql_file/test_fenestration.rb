require_relative '../../helpers/minitest_helper'

class TestFenestration < Minitest::Test
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

  def test_construction_calculated_fenestration_u_factor
    construction = @model.getConstructionByName('U 0.48 SHGC 0.40 Dbl Ref-D Clr 6mm/13mm').get
    u_factor_si = OpenstudioStandards::SqlFile.construction_calculated_fenestration_u_factor(construction)
    u_factor_ip = OpenStudio.convert(u_factor_si, 'W/m^2*K', 'Btu/ft^2*h*R').get
    assert_in_delta(0.48, u_factor_ip, 0.02)
  end
end
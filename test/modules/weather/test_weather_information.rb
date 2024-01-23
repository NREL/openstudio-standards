require_relative '../../helpers/minitest_helper'

class TestWeatherInformation < Minitest::Test
  def setup
    @weather = OpenstudioStandards::Weather
  end

  def test_climate_zone_weather_file_map
    # test California climate zones
    (1..16).to_a.each do |i|
      climate_zone = "CEC T24-CEC#{i}"
      weather_file_name = @weather.climate_zone_weather_file_map[climate_zone]
      weather_file_path = @weather.get_standards_weather_file_path(weather_file_name)
      ddy_file_path = weather_file_path.gsub('.epw', '.ddy')
      stat_file_path = weather_file_path.gsub('.epw', '.stat')
      assert(File.exist?(weather_file_path))
      assert(File.exist?(ddy_file_path))
      assert(File.exist?(stat_file_path))
    end
  end

  def test_model_get_climate_zone
    model = OpenStudio::Model::Model.new

    # test ASHRAE climate zone
    @weather.model_set_climate_zone(model, 'ASHRAE 169-2013-4A')
    result = @weather.model_get_climate_zone(model)
    assert_equal(result, 'ASHRAE 169-2013-4A')

    # test CEC climate zone
    @weather.model_set_climate_zone(model, 'CEC T24-CEC3')
    result = @weather.model_get_climate_zone(model)
    assert_equal(result, 'CEC T24-CEC3')
  end

  def test_model_get_ashrae_climate_zone_number
    model = OpenStudio::Model::Model.new
    @weather.model_set_climate_zone(model, 'ASHRAE 169-2013-4A')
    result = @weather.model_get_ashrae_climate_zone_number(model)
    assert_equal(result, 4)
  end

  def test_model_get_full_weather_file_path
    model = OpenStudio::Model::Model.new

    # test getting weather file path
    weather_file_path = OpenstudioStandards::Weather.climate_zone_representative_weather_file_path('ASHRAE 169-2013-5B')
    epw_file = OpenStudio::EpwFile.new(weather_file_path)
    OpenstudioStandards::Weather.model_set_weather_file(model, epw_file)
    result = OpenstudioStandards::Weather.model_get_full_weather_file_path(model)
    assert(result.get.to_s.include?('Denver'))
  end

  def test_get_standards_weather_file_path
    weather_file_name = 'USA_CO_Denver-Aurora-Buckley.AFB.724695_TMY3.epw'
    result = @weather.get_standards_weather_file_path(weather_file_name)
    assert(File.exist?(result))
    assert(result.include?('Denver'))
  end

  def test_climate_zone_representative_weather_file_path
    climate_zone = 'ASHRAE 169-2013-5B'
    result = OpenstudioStandards::Weather.climate_zone_representative_weather_file_path(climate_zone)
    assert(File.exist?(result))
    assert(result.include?('Denver'))
  end

  def test_ddy_regex_lookup
    result = @weather.ddy_regex_lookup('All Heating')
    assert(result.size == 3)
    result = @weather.ddy_regex_lookup('Monthly Cooling')
    assert(result.size == 24)
    result = @weather.ddy_regex_lookup('Heating 99.6%')
    test_name = "Seattle Seattle Tacoma Intl A Ann Htg 99.6% Condns DB"
    bad_name = "Seattle Fake Design Day Name"
    result.each{|r| assert(test_name =~ r)}
    result.each{|r| assert_nil(bad_name =~ r)}
  end

  def test_model_get_heating_design_outdoor_temperatures
    model = OpenStudio::Model::Model.new
    climate_zone = 'ASHRAE 169-2013-5B'
    weather_file_path = @weather.climate_zone_representative_weather_file_path(climate_zone)
    ddy_file_path = weather_file_path.gsub('.epw', '.ddy')
    ddy_list = @weather.ddy_regex_lookup('All Heating')
    @weather.model_set_design_days(model, ddy_file_path: ddy_file_path, ddy_list: ddy_list)
    result = OpenstudioStandards::Weather.model_get_heating_design_outdoor_temperatures(model)
    assert(result.size == 3)
  end
end

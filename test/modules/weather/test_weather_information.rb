require_relative '../../helpers/minitest_helper'

class TestWeatherInformation < Minitest::Test
  def setup
    @weather = OpenstudioStandards::Weather
  end

  def test_model_get_ashrae_climate_zone_number
    model = OpenStudio::Model::Model.new
    std = Standard.build('90.1-2013')
    std.model_set_climate_zone(model, 'ASHRAE 169-2013-4A')

    result = @weather.model_get_ashrae_climate_zone_number(model)
    assert_equal(result, 4)
  end

  def test_stat_file
    model = OpenStudio::Model::Model.new

    weather_file_names = [
      # "ALTURAS_725958_CZ2010", 
      # "LIVERMORE_724927_CZ2010", 
      # "USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3",
      "USA_WA_Seattle-Tacoma.Intl.AP.727930_TMY3"
    ]

    require 'json'
    require 'pp'
    weather_file_names.each do |weather_file_name|
      weather_file_path = OpenstudioStandards::Weather.get_weather_file_path(weather_file_name + '.epw')
      assert(weather_file_path)
      puts weather_file_path
      stat_file_path = weather_file_path.gsub('.epw', '.stat')
      assert(File.exist?(stat_file_path))
      stat_file = OpenstudioStandards::Weather::StatFile.new(stat_file_path)
      json = stat_file.to_json
      pp JSON.parse(json)
      

    end

  end

end

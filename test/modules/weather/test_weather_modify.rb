require_relative '../../helpers/minitest_helper'

class TestWeatherModify < Minitest::Test
  def setup
    @weather = OpenstudioStandards::Weather
  end

  def test_model_set_weather_file
    model = OpenStudio::Model::Model.new

    # get new weather file path and parse .epw file
    weather_file_path = @weather.get_standards_weather_file_path('USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    epw_file = OpenStudio::EpwFile.new(weather_file_path)

    # set new weather file from epw_file
    @weather.model_set_weather_file(model, epw_file)

    # test object properties
    wf = model.getWeatherFile
    assert(wf.city == 'Baltimore Blt Washngtn IntL')
    assert(wf.stateProvinceRegion == 'MD')
    assert(wf.country == 'USA')
    assert(wf.dataSource == 'TMY3')
    assert(wf.wMONumber.to_i == 724060)
    assert_in_delta(wf.latitude, 39.17, 0.01)
    assert_in_delta(wf.longitude, -76.68, 0.01)
    assert_in_delta(wf.elevation, 45.0, 0.1)
  end

  def test_model_set_site_information
    model = OpenStudio::Model::Model.new

    # get new weather file path and parse .epw file
    weather_file_path = @weather.get_standards_weather_file_path('USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    epw_file = OpenStudio::EpwFile.new(weather_file_path)

    # set new site info
    @weather.model_set_site_information(model, epw_file)

    # test things have changed
    s = model.getSite
    assert(s.name.to_s == 'Baltimore Blt Washngtn IntL_MD_USA')
    assert(s.timeZone.to_i == -5)
    assert_in_delta(s.latitude, 39.17, 0.01)
    assert_in_delta(s.longitude, -76.68, 0.01)
    assert_in_delta(s.elevation, 45.0, 0.1)
  end

  def test_model_set_site_water_mains_temperature
    model = OpenStudio::Model::Model.new

    # get new weather file path and parse .stat file
    weather_file_path = @weather.get_standards_weather_file_path('USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    stat_file = OpenstudioStandards::Weather::StatFile.load(weather_file_path.gsub('.epw', '.stat'))

    # set new site info
    @weather.model_set_site_water_mains_temperature(model, stat_file: stat_file)

    # test things have changed
    swmt = model.getSiteWaterMainsTemperature
    assert_in_delta(swmt.annualAverageOutdoorAirTemperature.get, 13.15, 0.01)
    assert_in_delta(swmt.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.get, 25.8, 0.01)
  end

  def test_model_set_undisturbed_ground_temperature_shallow
    model = OpenStudio::Model::Model.new

    # get new weather file path and parse .epw file
    weather_file_path = @weather.get_standards_weather_file_path('USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    epw_file = OpenStudio::EpwFile.new(weather_file_path)
    @weather.model_set_weather_file(model, epw_file)

    result = @weather.model_set_undisturbed_ground_temperature_shallow(model)
    assert(result.to_SiteGroundTemperatureShallow.is_initialized)

    stat_file =  OpenstudioStandards::Weather::StatFile.load(weather_file_path.sub('epw', 'stat'))
    result = @weather.model_set_undisturbed_ground_temperature_shallow(model, stat_file: stat_file)
    assert(result.to_SiteGroundTemperatureShallow.is_initialized)
  end

  def test_model_set_undisturbed_ground_temperature_deep
    model = OpenStudio::Model::Model.new

    # get new weather file path and parse .epw file
    weather_file_path = @weather.get_standards_weather_file_path('USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    epw_file = OpenStudio::EpwFile.new(weather_file_path)
    @weather.model_set_weather_file(model, epw_file)

    result = @weather.model_set_undisturbed_ground_temperature_deep(model)
    assert(result.to_SiteGroundTemperatureDeep.is_initialized)

    stat_file =  OpenstudioStandards::Weather::StatFile.load(weather_file_path.sub('epw', 'stat'))
    result = @weather.model_set_undisturbed_ground_temperature_deep(model, stat_file: stat_file)
    assert(result.to_SiteGroundTemperatureDeep.is_initialized)
  end

  def test_model_set_ground_temperatures
    model = OpenStudio::Model::Model.new

    # default temperatures from no input
    result = @weather.model_set_ground_temperatures(model)
    assert(result)
    ground_temp_object = model.getSiteGroundTemperatureBuildingSurface
    assert(ground_temp_object.isJanuaryGroundTemperatureDefaulted == false)

    # FC factor ground temperatures from provided climate zone
    model = OpenStudio::Model::Model.new
    result = @weather.model_set_ground_temperatures(model, climate_zone: 'ASHRAE 169-2013-5B')
    assert(result)
    ground_temp_object = model.getSiteGroundTemperatureFCfactorMethod
    assert(ground_temp_object.isJanuaryGroundTemperatureDefaulted == false)

    # FC factor ground temperatures from climate zone set in the model
    model = OpenStudio::Model::Model.new
    @weather.model_set_climate_zone(model, 'ASHRAE 169-2013-3A')
    result = @weather.model_set_ground_temperatures(model)
    assert(result)
    ground_temp_object = model.getSiteGroundTemperatureFCfactorMethod
    assert(ground_temp_object.isJanuaryGroundTemperatureDefaulted == false)

    # FC factor ground temperatures from .stat file associated with model .epw file
    model = OpenStudio::Model::Model.new
    @weather.model_set_ground_temperatures(model)
    weather_file_path = @weather.get_standards_weather_file_path('USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    epw_file = OpenStudio::EpwFile.new(weather_file_path)
    @weather.model_set_weather_file(model, epw_file)
    result = @weather.model_set_ground_temperatures(model)
    assert(result)
    ground_temp_object = model.getSiteGroundTemperatureFCfactorMethod
    assert(ground_temp_object.isJanuaryGroundTemperatureDefaulted == false)
  end

  def test_model_set_climate_zone
    model = OpenStudio::Model::Model.new

    # test new climate zone
    @weather.model_set_climate_zone(model, 'ASHRAE 169-2013-3A')

    czs = model.getClimateZones
    assert(czs.climateZones.size == 1)
    assert(czs.getClimateZone(0).value.to_s == '3A')
  end

  def test_model_set_design_days
    # test design days from model weather file
    model = OpenStudio::Model::Model.new
    weather_file_path = @weather.get_standards_weather_file_path('USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    epw_file = OpenStudio::EpwFile.new(weather_file_path)
    @weather.model_set_weather_file(model, epw_file)
    @weather.model_set_design_days(model)
    assert(model.getDesignDays.size == 3)

    # test design days with optional arguments
    model.getDesignDays.each(&:remove)
    ddy_file_path = weather_file_path.gsub('.epw', '.ddy')
    ddy_list = @weather.ddy_regex_lookup('All Heating') + @weather.ddy_regex_lookup('All Cooling')
    @weather.model_set_design_days(model, ddy_file_path: ddy_file_path, ddy_list: ddy_list)
    assert(model.getDesignDays.size == 16, "Model should have #{model.getDesignDays.size} design days")

    # test specific design days
    model = OpenStudio::Model::Model.new
    weather_file_path = @weather.get_standards_weather_file_path('IND_DL_New.Delhi-Safdarjung.AP.421820_TMYx.epw')
    epw_file = OpenStudio::EpwFile.new(weather_file_path)
    @weather.model_set_weather_file(model, epw_file)
    ddy_list = [/Htg 99.6. Condns DB/, /Clg .4% Condns DB=>MWB/, /September .4% Condns WB=>MCDB/]
    @weather.model_set_design_days(model, ddy_list: ddy_list)
    assert(model.getDesignDays.size == 3)
  end

  def test_model_set_weather_file_and_design_days
    # test from weather file
    model = OpenStudio::Model::Model.new
    weather_file_path = @weather.get_standards_weather_file_path('USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    result = @weather.model_set_weather_file_and_design_days(model, weather_file_path: weather_file_path)
    assert(result)

    # test from climate zone
    model = OpenStudio::Model::Model.new
    result = @weather.model_set_weather_file_and_design_days(model, climate_zone: 'ASHRAE 169-2013-5B')
    assert(result)

    # test with ddy list specified
    model = OpenStudio::Model::Model.new
    weather_file_path = @weather.get_standards_weather_file_path('OAKLAND_724930_CZ2010.epw')
    ddy_list = @weather.ddy_regex_lookup('All Heating') + @weather.ddy_regex_lookup('All Cooling')
    result = @weather.model_set_weather_file_and_design_days(model, weather_file_path: weather_file_path, ddy_list: ddy_list)
    assert(result)

    # test with neither
    model = OpenStudio::Model::Model.new
    result = @weather.model_set_weather_file_and_design_days(model)
    assert(!result)
  end

  def test_model_set_building_location
    # test from weather file
    model = OpenStudio::Model::Model.new
    weather_file_path = @weather.get_standards_weather_file_path('USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw')
    result = @weather.model_set_building_location(model, weather_file_path: weather_file_path)
    assert(result)

    # test from climate zone
    model = OpenStudio::Model::Model.new
    result = @weather.model_set_building_location(model, climate_zone: 'ASHRAE 169-2013-5B')
    assert(result)

    # test with ddy list specified
    model = OpenStudio::Model::Model.new
    weather_file_path = @weather.get_standards_weather_file_path('OAKLAND_724930_CZ2010.epw')
    ddy_list = @weather.ddy_regex_lookup('All Heating') + @weather.ddy_regex_lookup('All Cooling')
    result = @weather.model_set_building_location(model, weather_file_path: weather_file_path, ddy_list: ddy_list)
    assert(result)

    # test with neither
    model = OpenStudio::Model::Model.new
    result = @weather.model_set_building_location(model)
    assert(!result)

    # test Canadian weather file
    model = OpenStudio::Model::Model.new
    weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_BC_Vancouver.Intl.AP.718920_CWEC2020.epw')
    result = OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
    assert(result)
  end
end
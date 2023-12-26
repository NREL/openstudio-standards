require_relative '../../helpers/minitest_helper'

class TestWeatherModify < Minitest::Test
  def setup
    @weather = OpenstudioStandards::Weather
  end

  def load_test_model(path)
    if File.file? path
      vt = OpenStudio::OSVersion::VersionTranslator.new
      path = OpenStudio::Path.new(path)
      model = vt.loadModel(path)
      if model.is_initialized
        return model.get
      else
        raise LoadError, 'Could not load test model.'
      end
    end
  end

  def test_model_set_weather_file
    # load test model from prm tests
    test_dir = File.expand_path(File.join(File.dirname(__FILE__),'../../90_1_prm/models'))
    test_model = "bldg_1.osm"

    model = load_test_model(File.join(test_dir, test_model))
    # existing weather file set to Denver
    wf = model.getWeatherFile
    assert(wf.city == "Denver Intl Ap")

    # get new weather file path and parse epw file
    weather_file_path = @weather.get_standards_weather_file_path("USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw")
    epw_file = OpenstudioStandards::Weather::Epw.load(weather_file_path)

    # set new weather file from epw_file
    @weather.model_set_weather_file(model, epw_file)
    # test object properties
    wf = model.getWeatherFile
    assert(wf.city == "Baltimore Blt Washngtn IntL")
    assert(wf.stateProvinceRegion == "MD")
    assert(wf.country == "USA")
    assert(wf.dataSource == "TMY3")
    assert(wf.wMONumber.to_i == 724060)
    assert_in_delta(wf.latitude, 39.17, 0.01)
    assert_in_delta(wf.longitude, -76.68, 0.01)
    assert_in_delta(wf.elevation, 45.0, 0.1)

  end

  def test_model_set_site_information
    # load test model from prm tests
    test_dir = File.expand_path(File.join(File.dirname(__FILE__),'../../90_1_prm/models'))
    test_model = "bldg_1.osm"

    model = load_test_model(File.join(test_dir, test_model))

    # existing site set to Denver
    s = model.getSite
    assert(s.name.to_s == "Denver Intl Ap", "Existing Site Name: #{s.name}")
    assert(s.timeZone.to_i == -7)

    # get new weather file path and parse epw file
    weather_file_path = @weather.get_standards_weather_file_path("USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw")
    epw_file = OpenstudioStandards::Weather::Epw.load(weather_file_path)

    # set new site info
    @weather.model_set_site_information(model, epw_file)

    # test things have changed
    s = model.getSite
    assert(s.name.to_s == "Baltimore Blt Washngtn IntL_MD_USA")
    assert(s.timeZone.to_i == -5)
    assert_in_delta(s.latitude, 39.17, 0.01)
    assert_in_delta(s.longitude, -76.68, 0.01)
    assert_in_delta(s.elevation, 45.0, 0.1)
  end

  def test_model_set_site_water_mains_temperature
    # load test model from prm tests
    test_dir = File.expand_path(File.join(File.dirname(__FILE__),'../../90_1_prm/models'))
    test_model = "Run01_Prototype.osm"

    model = load_test_model(File.join(test_dir, test_model))

    # get existing site water mains temp
    swmt = model.getSiteWaterMainsTemperature
    assert_in_delta(swmt.annualAverageOutdoorAirTemperature.get, 20.31, 0.01)
    assert_in_delta(swmt.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.get, 17.8, 0.01)

    # get new weather file path and parse epw file
    weather_file_path = @weather.get_standards_weather_file_path("USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw")
    stat_file = OpenstudioStandards::Weather::StatFile.load(weather_file_path.gsub('.epw', '.stat'))
    # puts stat_file.to_json

    # set new site info
    @weather.model_set_site_water_mains_temperature(model, stat_file)

    # test things have changed
    swmt = model.getSiteWaterMainsTemperature
    assert_in_delta(swmt.annualAverageOutdoorAirTemperature.get, 13.15, 0.01)
    assert_in_delta(swmt.maximumDifferenceInMonthlyAverageOutdoorAirTemperatures.get, 25.8, 0.01)
  end

  def test_model_set_climate_zone
    # load test model from prm tests
    test_dir = File.expand_path(File.join(File.dirname(__FILE__),'../../90_1_prm/models'))
    test_model = "bldg_1.osm"

    model = load_test_model(File.join(test_dir, test_model))

    # existing climate zone 5B
    czs = model.getClimateZones
    assert(czs.climateZones.size == 2)
    assert(czs.getClimateZone(0).value == "5B")

    # test new cz
    @weather.model_set_climate_zone(model, "ASHRAE 169-2013-3A")
    
    czs = model.getClimateZones
    assert(czs.climateZones.size == 1)
    assert(czs.getClimateZone(0).value.to_s == "3A")

  end

  def test_model_set_design_days
    # load test model from prm tests
    test_dir = File.expand_path(File.join(File.dirname(__FILE__),'../../90_1_prm/models'))
    test_model = "bldg_1.osm"

    model = load_test_model(File.join(test_dir, test_model))

    assert(model.getDesignDays.size == 14)

    weather_file_path = @weather.get_standards_weather_file_path("USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw")
    ddy_file_path = weather_file_path.gsub('.epw', '.ddy')
    ddy_model = OpenStudio::EnergyPlus::loadAndTranslateIdf(ddy_file_path).get
    ddy_list = @weather.ddy_regex_lookup("All Heating") + @weather.ddy_regex_lookup("All Cooling")
    @weather.model_set_design_days(model, ddy_model, ddy_list)

    assert(ddy_model.getDesignDays.size >= model.getDesignDays.size)
    assert(model.getDesignDays.size == 7, "Model should have #{model.getDesignDays.size} design days")

  end
end
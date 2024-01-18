# methods to modify model weather/location information
module OpenstudioStandards
  module Weather
    # @!group Weather

    # populate the model WeatherFile object from parsed epw file
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param epw_file [OpenstudioStandards::Weather::EpwFile] parsed epw file object
    def self.model_set_weather_file(model, epw_file)
      weather_file = model.getWeatherFile
      weather_file.setCity(epw_file.city)
      weather_file.setStateProvinceRegion(epw_file.state)
      weather_file.setCountry(epw_file.country)
      weather_file.setDataSource(epw_file.data_type)
      weather_file.setWMONumber(epw_file.wmo.to_s)
      weather_file.setLatitude(epw_file.lat)
      weather_file.setLongitude(epw_file.lon)
      weather_file.setTimeZone(epw_file.gmt)
      weather_file.setElevation(epw_file.elevation)
      if model.version < OpenStudio::VersionString.new('3.0.0')
        weather_file.setString(10, "file:///#{epw_file.filename}")
      else
        weather_file.setString(10, epw_file.filename.to_s)
      end
    end

    # populate the model Site object from parsed epw file
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param epw_file [OpenstudioStandards::Weather::EpwFile] parsed epw file object
    def self.model_set_site_information(model, epw_file)
      weather_name = "#{epw_file.city}_#{epw_file.state}_#{epw_file.country}"
      weather_lat = epw_file.lat
      weather_lon = epw_file.lon
      weather_time = epw_file.gmt
      weather_elev = epw_file.elevation

      site = model.getSite
      site.setName(weather_name)
      site.setLatitude(weather_lat)
      site.setLongitude(weather_lon)
      site.setTimeZone(weather_time)
      site.setElevation(weather_elev)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Weather.modify', "City is #{epw_file.city}. State is #{epw_file.state}")
    end

    # set the model SiteWaterMainsTemperature object from parsed STAT file
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param stat_file [OpenstudioStandards::Weather::StatFile] parsed STAT file object
    def self.model_set_site_water_mains_temperature(model, stat_file)
      water_temp = model.getSiteWaterMainsTemperature
      water_temp.setAnnualAverageOutdoorAirTemperature(stat_file.mean_dry_bulb)
      water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(stat_file.delta_dry_bulb)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Weather.modify', "Site Water Mains Temperature mean OA dry bulb is #{stat_file.mean_dry_bulb}. Delta OA dry bulb is #{stat_file.delta_dry_bulb}.")
    end

    # imports design days into the model
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param ddy_model [OpenStudio::Model::Model] OpenStudio model object populated with design day objects
    # @param ddy_list [Array<String>] list of regular expressions matching design day names to import
    def self.model_set_design_days(model, ddy_model, ddy_list)
      # remove any existing design day objects
      model.getDesignDays.each(&:remove)

      # warn if no design days in file
      if ddy_model.getDesignDays.size.zero?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Weather.modify', 'No design days were found in the design day file.')
        return false
      end

      objs_to_add = []
      ddy_model.getDesignDays.sort.each do |d|
        if ddy_list.empty?
          # add all design days
          ddy_model.getDesignDays.each { |dd| objs_to_add << dd }
        else
          # add design days that match ddy_list regexes
          ddy_list.each do |ddy_name_regex|
            if d.name.get.to_s =~ ddy_name_regex
              objs_to_add << d
            end
          end
        end
      end

      objs_to_add.each do |o|
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Weather.modify', "Adding design day #{o.name.get}.")
        model.addObject(o)
      end
    end

    # Sets the model ClimateZone object
    # Clears out any climate zones previously added to the model.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param climate_zone [String] full climate zone string, e.g. "ASHRAE 169-2013-1A"
    # @return [Boolean] returns true if successful, false if not
    def self.model_set_climate_zone(model, climate_zone)
      # Remove previous climate zones from the model
      climate_zones = model.getClimateZones
      climate_zones.clear

      # Split the string into the correct institution and value
      if climate_zone.include?('CEC')
        climate_zones.setClimateZone('CEC', climate_zone.gsub('CEC T24-CEC', '').gsub('T24-CEC', ''))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Weather.modify', "Setting Climate Zone to #{climate_zones.getClimateZones('CEC').first.value}")
      elsif climate_zone.include?('ASHRAE')
        climate_zones.setClimateZone('ASHRAE', climate_zone.gsub(/ASHRAE .*-.*-/, ''))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Weather.modify', "Setting Climate Zone to #{climate_zones.getClimateZones('ASHRAE').first.value}")
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Weather.modify', "Unknown climate zone #{climate_zone}. Climate Zone will not be set.")
      end

      return true
    end

    # set the model WeatherFile and Site information based on a weather file
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param weather_file_path [String] absolute path of epw file. For weather files included in OpenStudio-standards, can be found using OpenstuioStandards::Weather::get_standards_weather_file_path
    # @param climate_zone [String] full climate zone string, e.g. "ASHRAE 169-2013-1A"
    # @param ddy_list [Array] list of regexes to match design day names to add to model, e.g. /Clg 1. Condns DB=>MWB/
    def self.model_change_building_location(model, weather_file_path, climate_zone = '', ddy_list = [])
      # load weather file
      epw_file = OpenstudioStandards::Weather::Epw.load(weather_file_path)

      model_set_weather_file(model, epw_file)
      model_set_site_information(model, epw_file)

      stat_file = OpenstudioStandards::Weather::StatFile.load(weather_file_path.gsub('.epw', '.stat'))
      model_set_site_water_mains_temperature(model, stat_file)

      ddy_file_path = weather_file_path.gsub('.epw', '.ddy')
      if !File.file?(ddy_file_path)
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Weather.modify', "Could not find design day file: #{ddy_file_path}")
        return false
      end

      ddy_model = OpenStudio::EnergyPlus.loadAndTranslateIdf(ddy_file_path).get
      model_set_design_days(model, ddy_model, ddy_list)

      if climate_zone.empty?
        # use the climate zone from the stat file
        climate_zone = stat_file.climate_zone
        climate_zone = "ASHRAE 169-2013-#{climate_zone}"
      end

      OpenstudioStandards::Weather.model_set_climate_zone(model, climate_zone)
    end
  end
end

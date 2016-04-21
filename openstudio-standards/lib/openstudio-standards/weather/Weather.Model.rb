
# Open the class to add methods to put weather info into the model
class OpenStudio::Model::Model

  # Helper method to set the weather file, import the design days, set
  # water mains temperature, and set ground temperature.
  # Based on ChangeBuildingLocation measure by Nicholas Long

  def add_design_days_and_weather_file(hvac_standards, building_type, building_vintage, climate_zone, epw_file)


    require_relative 'Weather.stat_file'
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.weather.Model', "Started adding weather file for climate zone: #{climate_zone}.")
    
       
    # Define the weather file for each climate zone
    climate_zone_weather_file_map = {
      'ASHRAE 169-2006-1A' => 'USA_FL_Miami.Intl.AP.722020_TMY3.epw',
      'ASHRAE 169-2006-1B' => 'SAU_Riyadh.404380_IWEC.epw',
      'ASHRAE 169-2006-2A' => 'USA_TX_Houston-Bush.Intercontinental.AP.722430_TMY3.epw',
      'ASHRAE 169-2006-2B' => 'USA_AZ_Phoenix-Sky.Harbor.Intl.AP.722780_TMY3.epw',
      'ASHRAE 169-2006-3A' => 'USA_TN_Memphis.Intl.AP.723340_TMY3.epw',
      'ASHRAE 169-2006-3B' => 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw',
      'ASHRAE 169-2006-3C' => 'USA_CA_San.Francisco.Intl.AP.724940_TMY3.epw',
      'ASHRAE 169-2006-4A' => 'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw',
      'ASHRAE 169-2006-4B' => 'USA_NM_Albuquerque.Intl.AP.723650_TMY3.epw',
      'ASHRAE 169-2006-4C' => 'USA_OR_Salem-McNary.Field.726940_TMY3.epw',
      'ASHRAE 169-2006-5A' => 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw',
      'ASHRAE 169-2006-5B' => 'USA_ID_Boise.Air.Terminal.726810_TMY3.epw',
      'ASHRAE 169-2006-5C' => 'CAN_BC_Vancouver.718920_CWEC.epw',
      'ASHRAE 169-2006-6A' => 'USA_VT_Burlington.Intl.AP.726170_TMY3.epw',
      'ASHRAE 169-2006-6B' => 'USA_MT_Helena.Rgnl.AP.727720_TMY3.epw',
      'ASHRAE 169-2006-7A' => 'USA_MN_Duluth.Intl.AP.727450_TMY3.epw',
      'ASHRAE 169-2006-7B' => 'USA_MN_Duluth.Intl.AP.727450_TMY3.epw',
      'ASHRAE 169-2006-8A' => 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw',
      'ASHRAE 169-2006-8B' => 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw',
      #For measure input
      'NECB HDD Method'  => "#{epw_file}",
      #For testing
      'NECB-CNEB-5'  => "#{epw_file}",
      'NECB-CNEB-6'  => "#{epw_file}",
      'NECB-CNEB-7a' => "#{epw_file}",
      'NECB-CNEB-7b' => "#{epw_file}",
      'NECB-CNEB-8'  => "#{epw_file}"      
    }

    # Define where the weather files live
    top_dir = File.expand_path( '../../..',File.dirname(__FILE__))
    weather_dir = "#{top_dir}/data/weather"   

    # Get the weather file name from the hash
    weather_file_name = climate_zone_weather_file_map[climate_zone]  
    if weather_file_name.nil?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.weather.Model', "Could not determine the weather file for climate zone: #{climate_zone}.")
      return false
    end
    
    # Add Weather File
    unless (Pathname.new weather_dir).absolute?
      weather_dir = File.expand_path(File.join(File.dirname(__FILE__), weather_dir))
    end
    
    weather_file = File.join(weather_dir, weather_file_name)
    epw_file = OpenStudio::EpwFile.new(weather_file)
    OpenStudio::Model::WeatherFile.setWeatherFile(self, epw_file).get

    weather_name = "#{epw_file.city}_#{epw_file.stateProvinceRegion}_#{epw_file.country}"
    weather_lat = epw_file.latitude
    weather_lon = epw_file.longitude
    weather_time = epw_file.timeZone
    weather_elev = epw_file.elevation

   
    # Add or update site data
    site = self.getSite
    site.setName(weather_name)
    site.setLatitude(weather_lat)
    site.setLongitude(weather_lon)
    site.setTimeZone(weather_time)
    site.setElevation(weather_elev)
    
    
    #Add or update ground temperature data
    ground_temp_vals = self.find_object($os_standards["ground_temperatures"], {'template'=>building_vintage, 'climate_zone'=>climate_zone, 'building_type'=>building_type})
    if ground_temp_vals && ground_temp_vals['jan']
      groundTemp = self.getSiteGroundTemperatureBuildingSurface
      groundTemp.setJanuaryGroundTemperature(ground_temp_vals['jan'])
      groundTemp.setFebruaryGroundTemperature(ground_temp_vals['feb'])
      groundTemp.setMarchGroundTemperature(ground_temp_vals['mar'])
      groundTemp.setAprilGroundTemperature(ground_temp_vals['apr'])
      groundTemp.setMayGroundTemperature(ground_temp_vals['may'])
      groundTemp.setJuneGroundTemperature(ground_temp_vals['jun'])
      groundTemp.setJulyGroundTemperature(ground_temp_vals['jul'])
      groundTemp.setAugustGroundTemperature(ground_temp_vals['aug'])
      groundTemp.setSeptemberGroundTemperature(ground_temp_vals['sep'])
      groundTemp.setOctoberGroundTemperature(ground_temp_vals['oct'])
      groundTemp.setNovemberGroundTemperature(ground_temp_vals['nov'])
      groundTemp.setDecemberGroundTemperature(ground_temp_vals['dec'])
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.weather.Model', "Could not find ground temperatures; will use generic temperatures, which will skew results.")
      groundTemp = self.getSiteGroundTemperatureBuildingSurface
      groundTemp.setJanuaryGroundTemperature(19.527)
      groundTemp.setFebruaryGroundTemperature(19.502)
      groundTemp.setMarchGroundTemperature(19.536)
      groundTemp.setAprilGroundTemperature(19.598)
      groundTemp.setMayGroundTemperature(20.002)
      groundTemp.setJuneGroundTemperature(21.640)
      groundTemp.setJulyGroundTemperature(22.225)
      groundTemp.setAugustGroundTemperature(22.375)
      groundTemp.setSeptemberGroundTemperature(21.449)
      groundTemp.setOctoberGroundTemperature(20.121)
      groundTemp.setNovemberGroundTemperature(19.802)
      groundTemp.setDecemberGroundTemperature(19.633)
    end

    # Add SiteWaterMainsTemperature -- via parsing of STAT file.
    stat_filename = "#{File.join(File.dirname(weather_file), File.basename(weather_file, '.*'))}.stat"
    if File.exist? stat_filename
      stat_file = EnergyPlus::StatFile.new(stat_filename)
      water_temp = self.getSiteWaterMainsTemperature
      water_temp.setAnnualAverageOutdoorAirTemperature(stat_file.mean_dry_bulb)
      water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(stat_file.delta_dry_bulb)
      #OpenStudio::logFree(OpenStudio::Info, "openstudio.weather.Model", "Mean dry bulb is #{stat_file.mean_dry_bulb}")
      #OpenStudio::logFree(OpenStudio::Info, "openstudio.weather.Model", "Delta dry bulb is #{stat_file.delta_dry_bulb}")
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.weather.Model', "Could not find .stat file for: #{stat_filename}.")
      return false
    end

    # Remove any existing Design Day objects that are in the file
    self.getDesignDays.each { |d| d.remove }

    # Load in the ddy file based on convention that it is in
    # the same directory and has the same basename as the epw file.
    ddy_file = "#{File.join(File.dirname(weather_file), File.basename(weather_file, '.*'))}.ddy"
    if File.exist? ddy_file
      ddy_model = OpenStudio::EnergyPlus.loadAndTranslateIdf(ddy_file).get
      ddy_model.getObjectsByType('OS:SizingPeriod:DesignDay'.to_IddObjectType).each do |d|
        # Import the 99.6% Heating and 0.4% Cooling design days
        ddy_list = /(Htg 99.6. Condns DB)|(Clg .4% Condns DB=>MWB)/
        if d.name.get =~ ddy_list   
          self.addObject(d.clone)
          #OpenStudio::logFree(OpenStudio::Info, 'openstudio.weather.Model', "Added #{d.name} design day.")
        end
      end
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.weather.Model', "Could not find .stat file for: #{stat_filename}.")
      puts "Could not find .stat file for: #{stat_filename}."
      return false
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.weather.Model', "Finished adding weather file for climate zone: #{climate_zone}.")
    puts "Could not find .stat file for: #{stat_filename}."
    
    return true
      
  end
    
end  
  
  
class Standard
  # Helper method to set the weather file, import the design days, set
  # water mains temperature, and set ground temperature.
  # Based on ChangeBuildingLocation measure by Nicholas Long

  def model_add_design_days_and_weather_file(model, climate_zone, epw_file)
    require_relative 'Weather.stat_file'

    # Remove any existing Design Day objects that are in the file
    model.getDesignDays.each(&:remove)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.weather.Model', "Started adding weather file for climate zone: #{climate_zone}.")

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
        # For measure input
        'NECB HDD Method' => epw_file.to_s,
        # For testing
        'NECB-CNEB-5'  => epw_file.to_s,
        'NECB-CNEB-6'  => epw_file.to_s,
        'NECB-CNEB-7a' => epw_file.to_s,
        'NECB-CNEB-7b' => epw_file.to_s,
        'NECB-CNEB-8'  => epw_file.to_s
    }

    # Get the weather file name from the hash
    weather_file_name = if epw_file.nil? || (epw_file.to_s.strip == '')
                          climate_zone_weather_file_map[climate_zone]
                        else
                          epw_file.to_s
                        end
    if weather_file_name.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.weather.Model', "Could not determine the weather file for climate zone: #{climate_zone}.")
      return false
    end

    # Define where the weather files lives
    weather_dir = nil
    if File.dirname(__FILE__)[0] == ':'
      # running embedded copy of the gem

      # load weather file from embedded files
      epw_string = load_resource_relative("../../../data/weather/#{weather_file_name}")
      ddy_string = load_resource_relative("../../../data/weather/#{weather_file_name.gsub('.epw', '.ddy')}")
      stat_string = load_resource_relative("../../../data/weather/#{weather_file_name.gsub('.epw', '.stat')}")

      # extract to local weather dir
      weather_dir = File.expand_path(File.join(Dir.pwd, 'extracted_files/weather/'))
      puts "Extracting weather files to #{weather_dir}"
      FileUtils.mkdir_p(weather_dir)
      File.open("#{weather_dir}/#{weather_file_name}", 'wb') { |f| f << epw_string; f.flush }
      File.open("#{weather_dir}/#{weather_file_name.gsub('.epw', '.ddy')}", 'wb') { |f| f << ddy_string; f.flush }
      File.open("#{weather_dir}/#{weather_file_name.gsub('.epw', '.stat')}", 'wb') { |f| f << stat_string; f.flush }
    else
      # loaded gem from system path
      top_dir = File.expand_path('../../..', File.dirname(__FILE__))
      weather_dir = File.expand_path("#{top_dir}/data/weather")
    end

    # Add Weather File
    unless (Pathname.new weather_dir).absolute?
      weather_dir = File.expand_path(File.join(File.dirname(__FILE__), weather_dir))
    end

    weather_file = File.join(weather_dir, weather_file_name)
    epw_file = OpenStudio::EpwFile.new(weather_file)
    OpenStudio::Model::WeatherFile.setWeatherFile(model, epw_file).get

    weather_name = "#{epw_file.city}_#{epw_file.stateProvinceRegion}_#{epw_file.country}"
    weather_lat = epw_file.latitude
    weather_lon = epw_file.longitude
    weather_time = epw_file.timeZone
    weather_elev = epw_file.elevation

    # Add or update site data
    site = model.getSite
    site.setName(weather_name)
    site.setLatitude(weather_lat)
    site.setLongitude(weather_lon)
    site.setTimeZone(weather_time)
    site.setElevation(weather_elev)

    # Add SiteWaterMainsTemperature -- via parsing of STAT file.
    stat_filename = "#{File.join(File.dirname(weather_file), File.basename(weather_file, '.*'))}.stat"
    if File.exist? stat_filename
      stat_file = EnergyPlus::StatFile.new(stat_filename)
      water_temp = model.getSiteWaterMainsTemperature
      water_temp.setAnnualAverageOutdoorAirTemperature(stat_file.mean_dry_bulb)
      water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(stat_file.delta_dry_bulb)
      # OpenStudio::logFree(OpenStudio::Info, "openstudio.weather.Model", "Mean dry bulb is #{stat_file.mean_dry_bulb}")
      # OpenStudio::logFree(OpenStudio::Info, "openstudio.weather.Model", "Delta dry bulb is #{stat_file.delta_dry_bulb}")
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.weather.Model', "Could not find .stat file for: #{stat_filename}.")
      return false
    end

    # Load in the ddy file based on convention that it is in
    # the same directory and has the same basename as the epw file.
    ddy_file = "#{File.join(File.dirname(weather_file), File.basename(weather_file, '.*'))}.ddy"
    if File.exist? ddy_file
      ddy_model = OpenStudio::EnergyPlus.loadAndTranslateIdf(ddy_file).get
      ddy_model.getObjectsByType('OS:SizingPeriod:DesignDay'.to_IddObjectType).each do |d|
        # Import the 99.6% Heating and 0.4% Cooling design days
        ddy_list = /(Htg 99.6. Condns DB)|(Clg .4% Condns DB=>MWB)/
        if d.name.get =~ ddy_list
          model.addObject(d.clone)
          # OpenStudio::logFree(OpenStudio::Info, 'openstudio.weather.Model', "Added #{d.name} design day.")
        end
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.weather.Model', "Could not find .ddy file for: #{ddy_file}.")
      puts "Could not find .ddy file for: #{ddy_file}."
      return false
    end

    return true
  end

  def model_add_ground_temperatures(model, building_type, climate_zone)
    ground_temp_vals = model_find_object(standards_data['ground_temperatures'], 'template' => template, 'climate_zone' => climate_zone, 'building_type' => building_type)
    if ground_temp_vals && ground_temp_vals['jan']
      ground_temp = model.getSiteGroundTemperatureBuildingSurface
      ground_temp.setJanuaryGroundTemperature(ground_temp_vals['jan'])
      ground_temp.setFebruaryGroundTemperature(ground_temp_vals['feb'])
      ground_temp.setMarchGroundTemperature(ground_temp_vals['mar'])
      ground_temp.setAprilGroundTemperature(ground_temp_vals['apr'])
      ground_temp.setMayGroundTemperature(ground_temp_vals['may'])
      ground_temp.setJuneGroundTemperature(ground_temp_vals['jun'])
      ground_temp.setJulyGroundTemperature(ground_temp_vals['jul'])
      ground_temp.setAugustGroundTemperature(ground_temp_vals['aug'])
      ground_temp.setSeptemberGroundTemperature(ground_temp_vals['sep'])
      ground_temp.setOctoberGroundTemperature(ground_temp_vals['oct'])
      ground_temp.setNovemberGroundTemperature(ground_temp_vals['nov'])
      ground_temp.setDecemberGroundTemperature(ground_temp_vals['dec'])
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.weather.Model', 'Could not find ground temperatures; will use generic temperatures, which will skew results.')
      ground_temp = model.getSiteGroundTemperatureBuildingSurface
      ground_temp.setJanuaryGroundTemperature(19.527)
      ground_temp.setFebruaryGroundTemperature(19.502)
      ground_temp.setMarchGroundTemperature(19.536)
      ground_temp.setAprilGroundTemperature(19.598)
      ground_temp.setMayGroundTemperature(20.002)
      ground_temp.setJuneGroundTemperature(21.640)
      ground_temp.setJulyGroundTemperature(22.225)
      ground_temp.setAugustGroundTemperature(22.375)
      ground_temp.setSeptemberGroundTemperature(21.449)
      ground_temp.setOctoberGroundTemperature(20.121)
      ground_temp.setNovemberGroundTemperature(19.802)
      ground_temp.setDecemberGroundTemperature(19.633)
    end
  end

  # Gets the maximum OA dry bulb temperatures
  # for all WinterDesignDays in the model.
  #
  # @return [Array<Double>] an array of OA temperatures in C
  def heating_design_outdoor_temperatures
    heating_design_outdoor_temps = []
    getDesignDays.each do |dd|
      next unless dd.dayType == 'WinterDesignDay'
      heating_design_outdoor_temps << dd.maximumDryBulbTemperature
    end

    return heating_design_outdoor_temps
  end
end

# *********************************************************************
# *  Copyright (c) 2008-2015, Natural Resources Canada
# *  All rights reserved.
# *
# *  This library is free software; you can redistribute it and/or
# *  modify it under the terms of the GNU Lesser General Public
# *  License as published by the Free Software Foundation; either
# *  version 2.1 of the License, or (at your option) any later version.
# *
# *  This library is distributed in the hope that it will be useful,
# *  but WITHOUT ANY WARRANTY; without even the implied warranty of
# *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# *  Lesser General Public License for more details.
# *
# *  You should have received a copy of the GNU Lesser General Public
# *  License along with this library; if not, write to the Free Software
# *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
# **********************************************************************/

# This module has been created to make it easier to manipulate weather files can contains region specific data.

module BTAP
  module Environment
    require_relative 'Weather.stat_file'

    # rubocop:disable Style/MutableConstant

    # Keeping data in hash for now.
    WEATHER_DATA1 = [
        { file: 'CAN_BC_Abbotsford.711080_CWEC.epw', location_name: ' CAN-BC-Abbotsford', energy_plus_location_name: 'Abbotsford_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Abbotsford', hdd18: 3134, cdd18: 33, latitude: 49.03, longitude: -122.37, elevation: 58, deltadb: 14.3, a90_1_2004_climate_zone: '5C', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_Bagotville.717270_CWEC.epw', location_name: ' CAN-PQ-Bagotville', energy_plus_location_name: 'Bagotville_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Bagotville', hdd18: 5781, cdd18: 49, latitude: 48.33, longitude: -71, elevation: 159, deltadb: 32.4, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Baie.Comeau.711870_CWEC.epw', location_name: ' CAN-PQ-Baie Comeau', energy_plus_location_name: 'Baie Comeau_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Baie Comeau', hdd18: 5889, cdd18: 3, latitude: 49.13, longitude: -68.2, elevation: 22, deltadb: 29.8, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_NF_Battle.Harbour.718170_CWEC.epw', location_name: ' CAN-NF-Battle Harbour', energy_plus_location_name: 'Battle Harbour_NF_CAN', country: 'CAN', state_province_region: 'NF', city: 'Battle Harbour', hdd18: 6462, cdd18: 0, latitude: 52.3, longitude: -55.83, elevation: 8, deltadb: 21.6, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_MB_Brandon.711400_CWEC.epw', location_name: ' CAN-MB-Brandon', energy_plus_location_name: 'Brandon_MB_CAN', country: 'CAN', state_province_region: 'MB', city: 'Brandon', hdd18: 5912, cdd18: 95, latitude: 49.92, longitude: -99.95, elevation: 409, deltadb: 36.7, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_AB_Calgary.718770_CWEC.epw', location_name: " CAN-AB-Calgary Int'l", energy_plus_location_name: "Calgary Int'l_AB_CAN", country: 'CAN', state_province_region: 'AB', city: "Calgary Int'l", hdd18: 5146, cdd18: 40, latitude: 51.12, longitude: -114.02, elevation: 1084, deltadb: 25, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PE_Charlottetown.717060_CWEC.epw', location_name: ' CAN-PE-Charlottetown CDA', energy_plus_location_name: 'Charlottetown CDA_PE_CAN', country: 'CAN', state_province_region: 'PE', city: 'Charlottetown CDA', hdd18: 4647, cdd18: 72, latitude: 46.28, longitude: -63.13, elevation: 54, deltadb: 25.6, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_MB_Churchill.719130_CWEC.epw', location_name: ' CAN-MB-Churchill', energy_plus_location_name: 'Churchill_MB_CAN', country: 'CAN', state_province_region: 'MB', city: 'Churchill', hdd18: 9114, cdd18: 3, latitude: 58.75, longitude: -94.07, elevation: 29, deltadb: 37.7, a90_1_2004_climate_zone: 8, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_BC_Comox.718930_CWEC.epw', location_name: ' CAN-BC-Comox', energy_plus_location_name: 'Comox_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Comox', hdd18: 3177, cdd18: 30, latitude: 49.72, longitude: -124.9, elevation: 24, deltadb: 15.2, a90_1_2004_climate_zone: '5C', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_BC_Cranbrook.718800_CWEC.epw', location_name: ' CAN-BC-Cranbrook', energy_plus_location_name: 'Cranbrook_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Cranbrook', hdd18: 4645, cdd18: 118, latitude: 49.6, longitude: -115.78, elevation: 940, deltadb: 26.6, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_AB_Edmonton.711230_CWEC.epw', location_name: ' CAN-AB-Edmonton Stony Plain', energy_plus_location_name: 'Edmonton Stony Plain_AB_CAN', country: 'CAN', state_province_region: 'AB', city: 'Edmonton Stony Plain', hdd18: 5583, cdd18: 22, latitude: 53.53, longitude: -114.1, elevation: 723, deltadb: 27.5, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_SK_Estevan.718620_CWEC.epw', location_name: ' CAN-SK-Estevan', energy_plus_location_name: 'Estevan_SK_CAN', country: 'CAN', state_province_region: 'SK', city: 'Estevan', hdd18: 5370, cdd18: 189, latitude: 49.22, longitude: -102.97, elevation: 581, deltadb: 35.1, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_AB_Fort.McMurray.719320_CWEC.epw', location_name: ' CAN-AB-Fort McMurray', energy_plus_location_name: 'Fort McMurray_AB_CAN', country: 'CAN', state_province_region: 'AB', city: 'Fort McMurray', hdd18: 6191, cdd18: 65, latitude: 56.65, longitude: -111.22, elevation: 369, deltadb: 33.5, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_BC_Fort.St.John.719430_CWEC.epw', location_name: ' CAN-BC-Fort St John', energy_plus_location_name: 'Fort St John_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Fort St John', hdd18: 5863, cdd18: 25, latitude: 56.23, longitude: -120.73, elevation: 695, deltadb: 29.1, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_NB_Fredericton.717000_CWEC.epw', location_name: ' CAN-NB-Fredericton', energy_plus_location_name: 'Fredericton_NB_CAN', country: 'CAN', state_province_region: 'NB', city: 'Fredericton', hdd18: 4734, cdd18: 132, latitude: 45.87, longitude: -66.53, elevation: 20, deltadb: 29.5, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_NF_Gander.718030_CWEC.epw', location_name: " CAN-NF-Gander Int'l", energy_plus_location_name: "Gander Int'l_NF_CAN", country: 'CAN', state_province_region: 'NF', city: "Gander Int'l", hdd18: 5101, cdd18: 25, latitude: 48.95, longitude: -54.57, elevation: 151, deltadb: 22.6, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_NF_Goose.718160_CWEC.epw', location_name: ' CAN-NF-Goose', energy_plus_location_name: 'Goose_NF_CAN', country: 'CAN', state_province_region: 'NF', city: 'Goose', hdd18: 6558, cdd18: 38, latitude: 53.32, longitude: -60.37, elevation: 49, deltadb: 33, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_AB_Grande.Prairie.719400_CWEC.epw', location_name: ' CAN-AB-Grand Prairie', energy_plus_location_name: 'Grand Prairie_AB_CAN', country: 'CAN', state_province_region: 'AB', city: 'Grand Prairie', hdd18: 5897, cdd18: 26, latitude: 55.18, longitude: -118.88, elevation: 669, deltadb: 28.9, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_NS_Greenwood.713970_CWEC.epw', location_name: ' CAN-NS-Greenwood', energy_plus_location_name: 'Greenwood_NS_CAN', country: 'CAN', state_province_region: 'NS', city: 'Greenwood', hdd18: 4131, cdd18: 128, latitude: 44.98, longitude: -64.92, elevation: 28, deltadb: 23.8, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_Grindstone.Island_CWEC.epw', location_name: ' CAN-PQ-Grindstone Island', energy_plus_location_name: 'Grindstone Island_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Grindstone Island', hdd18: 4941, cdd18: 18, latitude: 47.38, longitude: -61.87, elevation: 59, deltadb: 23.8, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_NT_Inuvik.719570_CWEC.epw', location_name: ' CAN-NT-Inuvik Ua', energy_plus_location_name: 'Inuvik Ua_NT_CAN', country: 'CAN', state_province_region: 'NT', city: 'Inuvik Ua', hdd18: 9952, cdd18: 17, latitude: 68.3, longitude: -133.48, elevation: 68, deltadb: 40.6, a90_1_2004_climate_zone: 8, boiler_fueltype: 'FuelOil#1', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_BC_Kamloops.718870_CWEC.epw', location_name: ' CAN-BC-Kamloops', energy_plus_location_name: 'Kamloops_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Kamloops', hdd18: 3629, cdd18: 287, latitude: 50.7, longitude: -120.45, elevation: 346, deltadb: 25.6, a90_1_2004_climate_zone: '5B', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_ON_Kingston.716200_CWEC.epw', location_name: ' CAN-ON-Kingston', energy_plus_location_name: 'Kingston_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'Kingston', hdd18: 4287, cdd18: 187, latitude: 44.22, longitude: -76.6, elevation: 93, deltadb: 27.7, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_Kuujjuarapik.719050_CWEC.epw', location_name: ' CAN-PQ-Kuujjuarapik', energy_plus_location_name: 'Kuujjuarapik_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Kuujjuarapik', hdd18: 7986, cdd18: 12, latitude: 55.28, longitude: -77.77, elevation: 12, deltadb: 32, a90_1_2004_climate_zone: 8, boiler_fueltype: 'Electricity', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Kuujuaq.719060_CWEC.epw', location_name: ' CAN-PQ-Kuujuaq', energy_plus_location_name: 'Kuujuaq_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Kuujuaq', hdd18: 8491, cdd18: 0, latitude: 58.1, longitude: -68.42, elevation: 37, deltadb: 31.8, a90_1_2004_climate_zone: 8, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_La.Grande.Riviere.718270_CWEC.epw', location_name: ' CAN-PQ-La Grande Riviere', energy_plus_location_name: 'La Grande Riviere_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'La Grande Riviere', hdd18: 7616, cdd18: 11, latitude: 53.63, longitude: -77.7, elevation: 195, deltadb: 35.2, a90_1_2004_climate_zone: 8, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Lake.Eon.714210_CWEC.epw', location_name: ' CAN-PQ-Lake Eon', energy_plus_location_name: 'Lake Eon_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Lake Eon', hdd18: 7383, cdd18: 8, latitude: 51.87, longitude: -63.28, elevation: 561, deltadb: 33.9, a90_1_2004_climate_zone: 8, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_AB_Lethbridge.712430_CWEC.epw', location_name: ' CAN-AB-Lethbridge', energy_plus_location_name: 'Lethbridge_AB_CAN', country: 'CAN', state_province_region: 'AB', city: 'Lethbridge', hdd18: 4432, cdd18: 126, latitude: 49.63, longitude: -112.8, elevation: 921, deltadb: 26.5, a90_1_2004_climate_zone: '6B', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_ON_London.716230_CWEC.epw', location_name: ' CAN-ON-London', energy_plus_location_name: 'London_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'London', hdd18: 4111, cdd18: 211, latitude: 43.03, longitude: -81.15, elevation: 278, deltadb: 27.9, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_AB_Medicine.Hat.718720_CWEC.epw', location_name: ' CAN-AB-Medicine Hat', energy_plus_location_name: 'Medicine Hat_AB_CAN', country: 'CAN', state_province_region: 'AB', city: 'Medicine Hat', hdd18: 4678, cdd18: 199, latitude: 50.02, longitude: -110.72, elevation: 716, deltadb: 31.6, a90_1_2004_climate_zone: '6B', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_NB_Miramichi.717440_CWEC.epw', location_name: ' CAN-NB-Miramichi', energy_plus_location_name: 'Miramichi_NB_CAN', country: 'CAN', state_province_region: 'NB', city: 'Miramichi', hdd18: 4921, cdd18: 141, latitude: 47.02, longitude: -65.45, elevation: 33, deltadb: 29.6, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_Mont.Joli.717180_CWEC.epw', location_name: ' CAN-PQ-Mont Joli', energy_plus_location_name: 'Mont Joli_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Mont Joli', hdd18: 5522, cdd18: 65, latitude: 48.6, longitude: -68.22, elevation: 52, deltadb: 30.8, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Montreal.Intl.AP.716270_CWEC.epw', location_name: " CAN-PQ-Montreal Int'l", energy_plus_location_name: "Montreal Int'l_PQ_CAN", country: 'CAN', state_province_region: 'PQ', city: "Montreal Int'l", hdd18: 4493, cdd18: 234, latitude: 45.47, longitude: -73.75, elevation: 36, deltadb: 30.2, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Montreal.Jean.Brebeuf.716278_CWEC.epw', location_name: ' CAN-PQ-Montreal Jean Brebeuf', energy_plus_location_name: 'Montreal Jean Brebeuf_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Montreal Jean Brebeuf', hdd18: 4616, cdd18: 209, latitude: 45.5, longitude: -73.62, elevation: 133, deltadb: 31.2, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Montreal.Mirabel.716278_CWEC.epw', location_name: ' CAN-PQ-Montreal Mirabel', energy_plus_location_name: 'Montreal Mirabel_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Montreal Mirabel', hdd18: 4861, cdd18: 102, latitude: 45.68, longitude: -74.03, elevation: 82, deltadb: 33.4, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_ON_Mount.Forest.716310_CWEC.epw', location_name: ' CAN-ON-Mount Forest', energy_plus_location_name: 'Mount Forest_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'Mount Forest', hdd18: 4578, cdd18: 121, latitude: 43.98, longitude: -80.75, elevation: 415, deltadb: 27.7, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_ON_Muskoka.716300_CWEC.epw', location_name: ' CAN-ON-Muskoka', energy_plus_location_name: 'Muskoka_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'Muskoka', hdd18: 4774, cdd18: 97, latitude: 44.97, longitude: -79.3, elevation: 282, deltadb: 29.3, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_Nitchequon.CAN270_CWEC.epw', location_name: ' CAN-PQ-Nitchequon', energy_plus_location_name: 'Nitchequon_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Nitchequon', hdd18: 7922, cdd18: 6, latitude: 53.2, longitude: -70.9, elevation: 536, deltadb: 35.8, a90_1_2004_climate_zone: 8, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_SK_North.Battleford.718760_CWEC.epw', location_name: ' CAN-SK-North Battleford', energy_plus_location_name: 'North Battleford_SK_CAN', country: 'CAN', state_province_region: 'SK', city: 'North Battleford', hdd18: 5962, cdd18: 75, latitude: 52.77, longitude: -108.25, elevation: 548, deltadb: 35.4, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_ON_North.Bay.717310_CWEC.epw', location_name: ' CAN-ON-North Bay', energy_plus_location_name: 'North Bay_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'North Bay', hdd18: 5341, cdd18: 103, latitude: 46.35, longitude: -79.43, elevation: 371, deltadb: 32.2, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_ON_Ottawa.716280_CWEC.epw', location_name: " CAN-ON-Ottawa Int'l", energy_plus_location_name: "Ottawa Int'l_ON_CAN", country: 'CAN', state_province_region: 'ON', city: "Ottawa Int'l", hdd18: 4664, cdd18: 189, latitude: 45.32, longitude: -75.67, elevation: 114, deltadb: 31.8, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_BC_Port.Hardy.711090_CWEC.epw', location_name: ' CAN-BC-Port Hardy', energy_plus_location_name: 'Port Hardy_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Port Hardy', hdd18: 3712, cdd18: 0, latitude: 50.68, longitude: -127.37, elevation: 22, deltadb: 10.8, a90_1_2004_climate_zone: '5C', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_BC_Prince.George.718960_CWEC.epw', location_name: ' CAN-BC-Prince George', energy_plus_location_name: 'Prince George_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Prince George', hdd18: 5070, cdd18: 15, latitude: 53.88, longitude: -122.68, elevation: 691, deltadb: 26, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_BC_Prince.Rupert.718980_CWEC.epw', location_name: ' CAN-BC-Prince Rupert', energy_plus_location_name: 'Prince Rupert_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Prince Rupert', hdd18: 4151, cdd18: 0, latitude: 54.3, longitude: -130.43, elevation: 34, deltadb: 13.5, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_Quebec.717140_CWEC.epw', location_name: ' CAN-PQ-Quebec City', energy_plus_location_name: 'Quebec City_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Quebec City', hdd18: 4964, cdd18: 111, latitude: 46.8, longitude: -71.38, elevation: 73, deltadb: 31, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_SK_Regina.718630_CWEC.epw', location_name: ' CAN-SK-Regina', energy_plus_location_name: 'Regina_SK_CAN', country: 'CAN', state_province_region: 'SK', city: 'Regina', hdd18: 5646, cdd18: 129, latitude: 50.43, longitude: -104.67, elevation: 577, deltadb: 35.4, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_NU_Resolute.719240_CWEC.epw', location_name: ' CAN-NU-Resolute', energy_plus_location_name: 'Resolute_NU_CAN', country: 'CAN', state_province_region: 'NU', city: 'Resolute', hdd18: 12_570, cdd18: 0, latitude: 74.72, longitude: -94.98, elevation: 67, deltadb: 35.9, a90_1_2004_climate_zone: 8, boiler_fueltype: 'FuelOil#2', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Riviere.du.Loup.717150_CWEC.epw', location_name: ' CAN-PQ-Riviere Du Loup', energy_plus_location_name: 'Riviere Du Loup_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Riviere Du Loup', hdd18: 5424, cdd18: 82, latitude: 47.8, longitude: -69.55, elevation: 148, deltadb: 30.1, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Roberval.717280_CWEC.epw', location_name: ' CAN-PQ-Roberval', energy_plus_location_name: 'Roberval_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Roberval', hdd18: 5757, cdd18: 97, latitude: 48.52, longitude: -72.27, elevation: 179, deltadb: 35.6, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_NS_Sable.Island.716000_CWEC.epw', location_name: ' CAN-NS-Sable Island', energy_plus_location_name: 'Sable Island_NS_CAN', country: 'CAN', state_province_region: 'NS', city: 'Sable Island', hdd18: 3860, cdd18: 14, latitude: 43.93, longitude: -60.02, elevation: 4, deltadb: 18.3, a90_1_2004_climate_zone: '5A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_NB_Saint.John.716090_CWEC.epw', location_name: ' CAN-NB-Saint John', energy_plus_location_name: 'Saint John_NB_CAN', country: 'CAN', state_province_region: 'NB', city: 'Saint John', hdd18: 4695, cdd18: 12, latitude: 45.32, longitude: -65.88, elevation: 109, deltadb: 23.8, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_BC_Sandspit.711010_CWEC.epw', location_name: ' CAN-BC-Sandspit', energy_plus_location_name: 'Sandspit_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Sandspit', hdd18: 3644, cdd18: 0, latitude: 53.25, longitude: -131.82, elevation: 6, deltadb: 13.1, a90_1_2004_climate_zone: '5C', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_SK_Saskatoon.718660_CWEC.epw', location_name: ' CAN-SK-Saskatoon', energy_plus_location_name: 'Saskatoon_SK_CAN', country: 'CAN', state_province_region: 'SK', city: 'Saskatoon', hdd18: 5812, cdd18: 84, latitude: 52.17, longitude: -106.68, elevation: 504, deltadb: 34.4, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_ON_Sault.Ste.Marie.712600_CWEC.epw', location_name: ' CAN-ON-Sault Ste Marie', energy_plus_location_name: 'Sault Ste Marie_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'Sault Ste Marie', hdd18: 4993, cdd18: 75, latitude: 46.48, longitude: -84.52, elevation: 192, deltadb: 28.3, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_Schefferville.718280_CWEC.epw', location_name: ' CAN-PQ-Schefferville', energy_plus_location_name: 'Schefferville_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Schefferville', hdd18: 8057, cdd18: 7, latitude: 54.8, longitude: -66.82, elevation: 521, deltadb: 34.6, a90_1_2004_climate_zone: 8, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Sept-Iles.718110_CWEC.epw', location_name: ' CAN-PQ-Sept-Iles', energy_plus_location_name: 'Sept-Iles_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Sept-Iles', hdd18: 6134, cdd18: 4, latitude: 50.22, longitude: -66.27, elevation: 55, deltadb: 30.9, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_NS_Shearwater.716010_CWEC.epw', location_name: ' CAN-NS-Shearwater', energy_plus_location_name: 'Shearwater_NS_CAN', country: 'CAN', state_province_region: 'NS', city: 'Shearwater', hdd18: 4197, cdd18: 58, latitude: 44.63, longitude: -63.5, elevation: 51, deltadb: 22, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_Sherbrooke.716100_CWEC.epw', location_name: ' CAN-PQ-Sherbrooke', energy_plus_location_name: 'Sherbrooke_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Sherbrooke', hdd18: 5068, cdd18: 93, latitude: 45.43, longitude: -71.68, elevation: 241, deltadb: 28.2, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_ON_Simcoe.715270_CWEC.epw', location_name: ' CAN-ON-Simcoe', energy_plus_location_name: 'Simcoe_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'Simcoe', hdd18: 4066, cdd18: 190, latitude: 42.85, longitude: -80.27, elevation: 241, deltadb: 26.4, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_BC_Smithers.719500_CWEC.epw', location_name: ' CAN-BC-Smithers', energy_plus_location_name: 'Smithers_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Smithers', hdd18: 5265, cdd18: 22, latitude: 54.82, longitude: -127.18, elevation: 523, deltadb: 24.2, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_St.Hubert.713710_CWEC.epw', location_name: ' CAN-PQ-St Hubert', energy_plus_location_name: 'St Hubert_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'St Hubert', hdd18: 4566, cdd18: 251, latitude: 45.52, longitude: -73.42, elevation: 27, deltadb: 31.2, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_NF_St.Johns.718010_CWEC.epw', location_name: " CAN-NF-St John's", energy_plus_location_name: "St John's_NF_CAN", country: 'CAN', state_province_region: 'NF', city: "St John's", hdd18: 4886, cdd18: 24, latitude: 47.62, longitude: -52.73, elevation: 140, deltadb: 20.5, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_PQ_Ste.Agathe.des.Monts.717200_CWEC.epw', location_name: ' CAN-PQ-Ste Agathe Des Monts', energy_plus_location_name: 'Ste Agathe Des Monts_PQ_CAN', country: 'CAN', state_province_region: 'PQ', city: 'Ste Agathe Des Monts', hdd18: 5350, cdd18: 45, latitude: 46.05, longitude: -74.28, elevation: 395, deltadb: 29.6, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_NF_Stephenville.718150_CWEC.epw', location_name: ' CAN-NF-Stephenville', energy_plus_location_name: 'Stephenville_NF_CAN', country: 'CAN', state_province_region: 'NF', city: 'Stephenville', hdd18: 4724, cdd18: 10, latitude: 48.53, longitude: -58.55, elevation: 26, deltadb: 23.1, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_BC_Summerland.717680_CWEC.epw', location_name: ' CAN-BC-Summerland', energy_plus_location_name: 'Summerland_BC_CAN', country: 'CAN', state_province_region: 'BC', city: 'Summerland', hdd18: 3388, cdd18: 199, latitude: 49.57, longitude: -119.65, elevation: 479, deltadb: 21.8, a90_1_2004_climate_zone: '5A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_SK_Swift.Current.718700_CWEC.epw', location_name: ' CAN-SK-Swift Current', energy_plus_location_name: 'Swift Current_SK_CAN', country: 'CAN', state_province_region: 'SK', city: 'Swift Current', hdd18: 5227, cdd18: 96, latitude: 50.28, longitude: -107.68, elevation: 818, deltadb: 30.8, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_NS_Sydney.717070_CWEC.epw', location_name: ' CAN-NS-Sydney', energy_plus_location_name: 'Sydney_NS_CAN', country: 'CAN', state_province_region: 'NS', city: 'Sydney', hdd18: 4634, cdd18: 51, latitude: 46.17, longitude: -60.05, elevation: 62, deltadb: 24, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_MB_The.Pas.718670_CWEC.epw', location_name: ' CAN-MB-The Pas', energy_plus_location_name: 'The Pas_MB_CAN', country: 'CAN', state_province_region: 'MB', city: 'The Pas', hdd18: 6442, cdd18: 106, latitude: 53.97, longitude: -101.1, elevation: 271, deltadb: 37.9, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_ON_Thunder.Bay.717490_CWEC.epw', location_name: ' CAN-ON-Thunder Bay', energy_plus_location_name: 'Thunder Bay_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'Thunder Bay', hdd18: 5624, cdd18: 60, latitude: 48.37, longitude: -89.32, elevation: 199, deltadb: 33.8, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_ON_Timmins.717390_CWEC.epw', location_name: ' CAN-ON-Timmins', energy_plus_location_name: 'Timmins_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'Timmins', hdd18: 5952, cdd18: 63, latitude: 48.57, longitude: -81.37, elevation: 295, deltadb: 33.8, a90_1_2004_climate_zone: 7, boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_ON_Toronto.716240_CWEC.epw', location_name: " CAN-ON-Toronto Int'l", energy_plus_location_name: "Toronto Int'l_ON_CAN", country: 'CAN', state_province_region: 'ON', city: "Toronto Int'l", hdd18: 4088, cdd18: 231, latitude: 43.67, longitude: -79.63, elevation: 173, deltadb: 26.6, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_ON_Trenton.716210_CWEC.epw', location_name: ' CAN-ON-Trenton', energy_plus_location_name: 'Trenton_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'Trenton', hdd18: 4176, cdd18: 207, latitude: 44.12, longitude: -77.53, elevation: 86, deltadb: 27.7, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_NS_Truro.713980_CWEC.epw', location_name: ' CAN-NS-Truro', energy_plus_location_name: 'Truro_NS_CAN', country: 'CAN', state_province_region: 'NS', city: 'Truro', hdd18: 4537, cdd18: 35, latitude: 45.37, longitude: -63.27, elevation: 40, deltadb: 25.2, a90_1_2004_climate_zone: '6A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_PQ_Val.d.Or.717250_CWEC.epw', location_name: " CAN-PQ-Val d'Or", energy_plus_location_name: "Val d'Or_PQ_CAN", country: 'CAN', state_province_region: 'PQ', city: "Val d'Or", hdd18: 6129, cdd18: 79, latitude: 48.07, longitude: -77.78, elevation: 337, deltadb: 35, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_BC_Vancouver.718920_CWEC.epw', location_name: " CAN-BC-Vancouver Int'l", energy_plus_location_name: "Vancouver Int'l_BC_CAN", country: 'CAN', state_province_region: 'BC', city: "Vancouver Int'l", hdd18: 3019, cdd18: 4, latitude: 49.18, longitude: -123.17, elevation: 2, deltadb: 13.9, a90_1_2004_climate_zone: '5C', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_BC_Victoria.717990_CWEC.epw', location_name: " CAN-BC-Victoria Int'l", energy_plus_location_name: "Victoria Int'l_BC_CAN", country: 'CAN', state_province_region: 'BC', city: "Victoria Int'l", hdd18: 3075, cdd18: 8, latitude: 48.65, longitude: -123.43, elevation: 19, deltadb: 12.3, a90_1_2004_climate_zone: '5C', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_YT_Whitehorse.719640_CWEC.epw', location_name: ' CAN-YT-Whitehorse', energy_plus_location_name: 'Whitehorse_YT_CAN', country: 'CAN', state_province_region: 'YT', city: 'Whitehorse', hdd18: 6946, cdd18: 2, latitude: 60.72, longitude: -135.07, elevation: 703, deltadb: 34.5, a90_1_2004_climate_zone: 7, boiler_fueltype: 'FuelOil#1', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_ON_Windsor.715380_CWEC.epw', location_name: ' CAN-ON-Windsor', energy_plus_location_name: 'Windsor_ON_CAN', country: 'CAN', state_province_region: 'ON', city: 'Windsor', hdd18: 3570, cdd18: 367, latitude: 42.27, longitude: -82.97, elevation: 190, deltadb: 27.1, a90_1_2004_climate_zone: '5A', boiler_fueltype: 'NaturalGas', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Gas', heating_coil_type_sys4: 'Gas', heating_coil_type_sys6: 'Hot Water', fan_type: 'var_speed_drive', swh_fueltype: 'NaturalGas' },
        { file: 'CAN_MB_Winnipeg.718520_CWEC.epw', location_name: " CAN-MB-Winnipeg Int'l", energy_plus_location_name: "Winnipeg Int'l_MB_CAN", country: 'CAN', state_province_region: 'MB', city: "Winnipeg Int'l", hdd18: 5754, cdd18: 197, latitude: 49.9, longitude: -97.23, elevation: 239, deltadb: 37.8, a90_1_2004_climate_zone: 7, boiler_fueltype: 'Electricity', baseboard_type: 'Electric', mau_type: true, mau_heating_coil_type: 'Electric', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' },
        { file: 'CAN_NT_Yellowknife.719360_CWEC.epw', location_name: ' CAN-NT-Yellowknife', energy_plus_location_name: 'Yellowknife_NT_CAN', country: 'CAN', state_province_region: 'NT', city: 'Yellowknife', hdd18: 8306, cdd18: 33, latitude: 62.47, longitude: -114.45, elevation: 206, deltadb: 42.1, a90_1_2004_climate_zone: 8, boiler_fueltype: 'FuelOil#2', baseboard_type: 'Hot Water', mau_type: true, mau_heating_coil_type: 'Hot Water', mau_cooling_type: 'DX', chiller_type: 'Scroll', heating_coil_type_sys_3: 'Electric', heating_coil_type_sys4: 'Electric', heating_coil_type_sys6: 'Electric', fan_type: 'var_speed_drive', swh_fueltype: 'Electricity' }
    ]

    # rubocop:enable Style/MutableConstant

    # this method is used to populate user interfaces if needed from the hash above.
    def self.get_canadian_weather_file_names
      canadian_file_names = []
      BTAP::Environment::WEATHER_DATA1.each { |hash| canadian_file_names << hash[:file] }
      return canadian_file_names
    end

    # this method returns the default system fuel types by epw_file.
    def self.get_canadian_system_defaults_by_weatherfile_name( epw_file )
      if (data = BTAP::Environment::WEATHER_DATA1.find { |d| d[:file] == epw_file.strip })
        return data[:boiler_fueltype], data[:baseboard_type], data[:mau_type], data[:mau_heating_coil_type], data[:mau_cooling_type], data[:chiller_type], data[:heating_coil_type_sys_3], data[:heating_coil_type_sys4], data[:heating_coil_type_sys6], data[:fan_type], data[:swh_fueltype]
      else
        puts 'Not found!'
      end
    end

    # This method will create a climate index file.
    # @author phylroy.lopez@nrcan.gc.ca
    # @param folder [String]
    # @param output_file [String]
    def self.create_climate_index_file(folder = "#{File.dirname(__FILE__)}/../../../weather", output_file = 'C:/test/phylroy.csv')
      data = ''
      counter = 0
      File.open(output_file, 'w') do |file|
        puts "outpus #{output_file}"
        data << "file,location_name,energy_plus_location_name,country,state_province_region,city,hdd10,hdd18,cdd10,cdd18,latitude,longitude,elevation, deltaDB, climate_zone, cz_standard, summer_wet_months, winter_dry_months,autumn_months, spring_months, typical_summer_wet_week, typical_winter_dry_week, typical_autumn_week, typical_spring_week, heating_design_info[1],cooling_design_info[1],extremes_design_info[1],db990\n"
        BTAP::FileIO.get_find_files_from_folder_by_extension(folder, 'epw').sort.each do |wfile|
          wf = BTAP::Environment::WeatherFile.new(wfile)
          data << "#{File.basename(wfile)}, #{wf.location_name}\,#{wf.energy_plus_location_name},#{wf.country}, #{wf.state_province_region}, #{wf.city}, #{wf.hdd10}, #{wf.hdd18},#{wf.cdd10},#{wf.cdd18},#{wf.latitude}, #{wf.longitude}, #{wf.elevation}, #{wf.delta_dry_bulb} ,#{wf.climate_zone},#{wf.standard},#{wf.summer_wet_months}, #{wf.winter_dry_months},#{wf.autumn_months}, #{wf.spring_months}, #{wf.typical_summer_wet_week}, #{wf.typical_winter_dry_week}, #{wf.typical_autumn_week}, #{wf.typical_spring_week},#{wf.heating_design_info[1]},#{wf.cooling_design_info[1]},#{wf.extremes_design_info[1]},#{wf.db990}\n"
          counter += 1
        end
        file.write(data)
      end
      puts "parsed #{counter} weather files."
    end



    # This method will create a climate index file.
    # @author phylroy.lopez@nrcan.gc.ca
    # @param folder [String]
    # @param output_file [String]
    def self.create_climate_json_file(folder = "#{File.dirname(__FILE__)}/../../../weather", output_file = 'C:/test/phylroy.csv')
      data_array = []
      File.open(output_file, 'w') do |file|

        BTAP::FileIO.get_find_files_from_folder_by_extension(folder, 'epw').sort.each do |wfile|
          wf = BTAP::Environment::WeatherFile.new(wfile)
          data = {}
          data_array << data
          data['file'] = File.basename(wfile).encode('UTF-8')
          data['location_name'] = wf.location_name.force_encoding('ISO-8859-1').encode('UTF-8')
          data['energy_plus_location_name'] = wf.energy_plus_location_name.force_encoding('ISO-8859-1').encode('UTF-8')
          data['country'] = wf.country.force_encoding('ISO-8859-1').encode('UTF-8')
          data['state_province_region'] = wf.state_province_region.force_encoding('ISO-8859-1').encode('UTF-8')
          data['city'] =  wf.city.force_encoding('ISO-8859-1').encode('UTF-8')
          data['hdd10'] = wf.hdd10
          data['hdd18'] = wf.hdd18
          data['cdd10'] = wf.cdd10
          data['cdd18'] = wf.cdd18
          data['latitude'] = wf.latitude
          data['longitude'] = wf.longitude
          data['elevation'] = wf.delta_dry_bulb
          data['climate_zone'] = wf.climate_zone.force_encoding('ISO-8859-1').encode('UTF-8')
          data['standard'] = wf.standard
          data['summer_wet_months'] = wf.summer_wet_months.force_encoding('ISO-8859-1').encode('UTF-8')
          data['winter_dry_months'] = wf.autumn_months.force_encoding('ISO-8859-1').encode('UTF-8')
          data['spring_months'] = wf.spring_months.force_encoding('ISO-8859-1').encode('UTF-8')
          data['typical_summer_wet_week'] = wf.typical_summer_wet_week
          data['typical_winter_dry_week'] = wf.typical_winter_dry_week
          data['typical_autumn_week'] = wf.typical_autumn_week
          data['typical_spring_week'] = wf.typical_spring_week
          data['wf.heating_design_info[1]'] = wf.heating_design_info[1]
          data['cooling_design_info[1]'] = wf.cooling_design_info[1]
          data['extremes_design_info[1]'] = wf.extremes_design_info[1].force_encoding('ISO-8859-1').encode('UTF-8')
          data['db990'] = wf.db990

        end
        File.write('/home/osdev/out.json',JSON.pretty_generate(data_array))
      end
    end


    class WeatherFile
      attr_accessor :location_name,
                    :energy_plus_location_name,
                    :latitude,
                    :longitude,
                    :elevation,
                    :city,
                    :state_province_region,
                    :country,
                    :hdd18,
                    :cdd18,
                    :hdd10,
                    :cdd10,
                    :heating_design_info,
                    :cooling_design_info,
                    :extremes_design_info,
                    :monthly_dry_bulb,
                    :delta_dry_bulb,
                    :climate_zone,
                    :standard,
                    :summer_wet_months,
                    :winter_dry_months,
                    :autumn_months,
                    :spring_months,
                    :typical_summer_wet_week,
                    :typical_winter_dry_week,
                    :typical_autumn_week,
                    :typical_spring_week,
                    :epw_filepath,
                    :ddy_filepath,
                    :stat_filepath,
                    :db990

      YEAR = 0
      MONTH = 1
      DAY = 2
      HOUR = 3
      MINUTE = 4
      DATA_SOURCE = 5
      DRY_BULB_TEMPERATURE = 6
      DEW_POINT_TEMPERATURE = 7
      RELATIVE_HUMIDITY = 8
      ATMOSPHERIC_STATION_PRESSURE = 9
      EXTRATERRESTRIAL_HORIZONTAL_RADIATION = 10 # not used
      EXTRATERRESTRIAL_DIRECT_NORMAL_RADIATION = 11 # not used
      HORIZONTAL_INFRARED_RADIATION_INTENSITY = 12
      GLOBAL_HORIZONTAL_RADIATION = 13 # not used
      DIRECT_NORMAL_RADIATION = 14
      DIFFUSE_HORIZONTAL_RADIATION = 15
      GLOBAL_HORIZONTAL_ILLUMINANCE = 16 # not used
      DIRECT_NORMAL_ILLUMINANCE = 17 # not used
      DIFFUSE_HORIZONTAL_ILLUMINANCE = 18 # not used
      ZENITH_LUMINANCE = 19 # not used
      WIND_DIRECTION = 20
      WIND_SPEED = 21
      TOTAL_SKY_COVER = 22 # not used
      OPAQUE_SKY_COVER = 23 # not used
      VISIBILITY = 24 # not used
      CEILING_HEIGHT = 25 # not used
      PRESENT_WEATHER_OBSERVATION = 26
      PRESENT_WEATHER_CODES = 27
      PRECIPITABLE_WATER = 28 # not used
      AEROSOL_OPTICAL_DEPTH = 29 # not used
      SNOW_DEPTH = 30
      DAYS_SINCE_LAST_SNOWFALL = 31 # not used
      ALBEDO = 32 # not used
      LIQUID_PRECIPITATION_DEPTH = 33
      LIQUID_PRECIPITATION_QUANTITY = 34

      # This method initializes and returns self.
      # @author phylroy.lopez@nrcan.gc.ca
      # @param weather_file [String]
      # @return [String] self
      def initialize(weather_file)
        # Define the openstudio-standards weather location
        top_dir = File.expand_path('../../..', File.dirname(__FILE__))
        weather_dir = "#{top_dir}/data/weather"

        # First check if the epw file exists at a full path.  If not found there,
        # check for the file in the openstudio-standards/data/weather directory.
        weather_file = weather_file.to_s
        @epw_filepath = nil
        @ddy_filepath = nil
        @stat_filepath = nil
        if File.exist?(weather_file)
          @epw_filepath = weather_file.to_s
          @ddy_filepath = weather_file.sub('epw', 'ddy').to_s
          @stat_filepath = weather_file.sub('epw', 'stat').to_s
        elsif File.exist?("#{weather_dir}/#{weather_file}")
          @epw_filepath = "#{weather_dir}/#{weather_file}"
          @ddy_filepath = "#{weather_dir}/#{weather_file.sub('epw', 'ddy')}"
          @stat_filepath = "#{weather_dir}/#{weather_file.sub('epw', 'stat')}"
        else
          raise("Could not find weather file #{weather_file}.  Make sure file path is correct.")
        end

        # Ensure that epw, ddy, and stat file all exist
        raise("Weather file #{@epw_filepath} not found.") unless File.exist?(@epw_filepath) && @epw_filepath.downcase.include?('.epw')
        raise("Weather file ddy #{@ddy_filepath} not found.") unless File.exist?(@ddy_filepath) && @ddy_filepath.downcase.include?('.ddy')
        raise("Weather file stat #{@stat_filepath} not found.") unless File.exist?(@stat_filepath) && @stat_filepath.downcase.include?('.stat')

        # load file objects.
        @epw_file = OpenStudio::EpwFile.new(OpenStudio::Path.new(@epw_filepath))
        if OpenStudio::EnergyPlus.loadAndTranslateIdf(@ddy_filepath).empty?
          raise "Unable to load ddy idf file#{@ddy_filepath}."
        else
          @ddy_file = OpenStudio::EnergyPlus.loadAndTranslateIdf(@ddy_filepath).get
        end
        @stat_file = EnergyPlus::StatFile.new(@stat_filepath)

        # assign variables.

        @latitude = @epw_file.latitude
        @longitude = @epw_file.longitude
        @elevation = @epw_file.elevation
        @city = @epw_file.city
        @state_province_region = @epw_file.stateProvinceRegion
        @country = @epw_file.country
        @hdd18 = @stat_file.hdd18
        @cdd18 = @stat_file.cdd18
        @hdd10 = @stat_file.hdd10
        @cdd10 = @stat_file.cdd10
        @heating_design_info = @stat_file.heating_design_info
        @cooling_design_info  = @stat_file.cooling_design_info
        @extremes_design_info = @stat_file.extremes_design_info
        @monthly_dry_bulb = @stat_file.monthly_dry_bulb
        @mean_dry_bulb = @stat_file.mean_dry_bulb
        @delta_dry_bulb = @stat_file.delta_dry_bulb
        @location_name = "#{@country}-#{@state_province_region}-#{@city}"
        @energy_plus_location_name = "#{@city}_#{@state_province_region}_#{@country}"
        @climate_zone = @stat_file.climate_zone
        @standard = @stat_file.standard
        @summer_wet_months = @stat_file.summer_wet_months
        @winter_dry_months = @stat_file.winter_dry_months
        @autumn_months = @stat_file.autumn_months
        @spring_months = @stat_file.spring_months
        @typical_summer_wet_week = @stat_file.typical_summer_wet_week
        @typical_winter_dry_week = @stat_file.typical_winter_dry_week
        @typical_autumn_week = @stat_file.typical_autumn_week
        @typical_spring_week = @stat_file.typical_spring_week
        @db990 = @heating_design_info[2]
        return self
      end

      # This method returns the Thermal Zone based on cdd10 and hdd18
      # @author padmassun.rajakareyar@canada.ca
      # @return [String] thermal_zone
      def a169_2006_climate_zone
        cdd10 = self.cdd10.to_f
        hdd18 = self.hdd18.to_f

        if cdd10 > 6000 # Extremely Hot  Humid (0A), Dry (0B)
          return 'ASHRAE 169-2006-0A'

        elsif (cdd10 > 5000) && (cdd10 <= 6000) # Very Hot  Humid (1A), Dry (1B)
          return 'ASHRAE 169-2006-1A'

        elsif (cdd10 > 3500) && (cdd10 <= 5000) # Hot  Humid (2A), Dry (2B)
          return 'ASHRAE 169-2006-2A'

        elsif ((cdd10 > 2500) && (cdd10 < 3500)) && (hdd18 <= 2000) # Warm  Humid (3A), Dry (3B)
          return 'ASHRAE 169-2006-3A' # and 'ASHRAE 169-2006-3B'

        elsif (cdd10 <= 2500) && (hdd18 <= 2000) # Warm  Marine (3C)
          return 'ASHRAE 169-2006-3C'

        elsif ((cdd10 > 1500) && (cdd10 < 3500)) && ((hdd18 > 2000) && (hdd18 <= 3000)) # Mixed  Humid (4A), Dry (4B)
          return 'ASHRAE 169-2006-4A' # and 'ASHRAE 169-2006-4B'

        elsif (cdd10 <= 1500) && ((hdd18 > 2000) && (hdd18 <= 3000)) # Mixed  Marine
          return 'ASHRAE 169-2006-4C'

        elsif ((cdd10 > 1000) && (cdd10 <= 3500)) && ((hdd18 > 3000) && (hdd18 <= 4000)) # Cool Humid (5A), Dry (5B)
          return 'ASHRAE 169-2006-5A' # and 'ASHRAE 169-2006-5B'

        elsif (cdd10 <= 1000) && ((hdd18 > 3000) && (hdd18 <= 4000)) # Cool  Marine (5C)
          return 'ASHRAE 169-2006-5C'

        elsif (hdd18 > 4000) && (hdd18 <= 5000) # Cold  Humid (6A), Dry (6B)
          return 'ASHRAE 169-2006-6A' # and 'ASHRAE 169-2006-6B'

        elsif (hdd18 > 5000) && (hdd18 <= 7000) # Very Cold (7)
          return 'ASHRAE 169-2006-7A'

        elsif hdd18 > 7000 # Subarctic/Arctic (8)
          return 'ASHRAE 169-2006-8A'

        else
          # raise ("invalid cdd10 of #{cdd10} or hdd18 of #{hdd18}")
          return '[INVALID]'
        end
      end

      # This method will set the weather file and returns a log string.
      # @author phylroy.lopez@nrcan.gc.ca
      # @param model [OpenStudio::model::Model] A model object
      # @return [String] log
      def set_weather_file(model, runner = nil)
        BTAP.runner_register('Info', 'BTAP::Environment::WeatherFile::set_weather', runner)
        OpenStudio::Model::WeatherFile.setWeatherFile(model, @epw_file)
        building_name = model.building.get.name
        weather_file_path = model.weatherFile.get.path.get
        BTAP.runner_register('Info', "Set model \"#{building_name}\" to weather file #{weather_file_path}.\n", runner)

        # Add or update site data
        site = model.getSite
        site.setName("#{@epw_file.city}_#{@epw_file.stateProvinceRegion}_#{@epw_file.country}")
        site.setLatitude(@epw_file.latitude)
        site.setLongitude(@epw_file.longitude)
        site.setTimeZone(@epw_file.timeZone)
        site.setElevation(@epw_file.elevation)

        BTAP.runner_register('Info', 'Setting water main temperatures via parsing of STAT file.', runner)
        water_temp = model.getSiteWaterMainsTemperature
        water_temp.setAnnualAverageOutdoorAirTemperature(@stat_file.mean_dry_bulb)
        water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(@stat_file.delta_dry_bulb)
        BTAP.runner_register('Info', "SiteWaterMainsTemperature.AnnualAverageOutdoorAirTemperature = #{@stat_file.mean_dry_bulb}.", runner)
        BTAP.runner_register('Info', "SiteWaterMainsTemperature.MaximumDifferenceInMonthlyAverageOutdoorAirTemperatures = #{@stat_file.delta_dry_bulb}.", runner)

        # Remove all the Design Day objects that are in the file
        model.getObjectsByType('OS:SizingPeriod:DesignDay'.to_IddObjectType).each(&:remove)

        # Load in the ddy file based on convention that it is in the same directory and has the same basename as the weather
        @ddy_file.getObjectsByType('OS:SizingPeriod:DesignDay'.to_IddObjectType).each do |d|
          # grab only the ones that matter
          ddy_list = /(Htg 99.6. Condns DB)|(Clg .4. Condns WB=>MDB)|(Clg .4% Condns DB=>MWB)/
          if d.name.get =~ ddy_list
            BTAP.runner_register('Info', "Adding design day '#{d.name}'.", runner)
            # add the object to the existing model
            model.addObject(d.clone)
          end
        end
        return true
      end

      # This method scans the epw file into memory.
      # @author phylroy.lopez@nrcan.gc.ca
      def scan
        @filearray = []
        file = File.new(@epw_filepath, 'r')
        while (line = file.gets)
          @filearray.push(line.split(','))
        end
        file.close
      end

      # This method will sets column to a value.
      # @author phylroy.lopez@nrcan.gc.ca
      # @param column [String]
      # @param value [Fixnum]
      def setcolumntovalue(column, value)
        @filearray.each do |line|
          unless line.first =~ /\D(.*)/
            line[column] = value
          end
        end
      end

      # This method will eliminate all radiation from the weather and returns self.
      # @author phylroy.lopez@nrcan.gc.ca
      # @return  [String] self
      def eliminate_all_radiation
        scan if @filearray.nil?
        setcolumntovalue(EXTRATERRESTRIAL_HORIZONTAL_RADIATION, '0') # not used
        setcolumntovalue(EXTRATERRESTRIAL_DIRECT_NORMAL_RADIATION, '0') # not used
        setcolumntovalue(HORIZONTAL_INFRARED_RADIATION_INTENSITY, '315')
        setcolumntovalue(GLOBAL_HORIZONTAL_RADIATION, '0') # not used
        setcolumntovalue(DIRECT_NORMAL_RADIATION, '0')
        setcolumntovalue(DIFFUSE_HORIZONTAL_RADIATION, '0')
        setcolumntovalue(TOTAL_SKY_COVER, '10') # not used
        setcolumntovalue(OPAQUE_SKY_COVER, '10') # not used
        setcolumntovalue(VISIBILITY, '0') # not used
        setcolumntovalue(CEILING_HEIGHT, '0') # not used
        # lux values
        setcolumntovalue(GLOBAL_HORIZONTAL_ILLUMINANCE, '0') # not used
        setcolumntovalue(DIRECT_NORMAL_ILLUMINANCE, '0') # not used
        setcolumntovalue(DIFFUSE_HORIZONTAL_ILLUMINANCE, '0') # not used
        setcolumntovalue(ZENITH_LUMINANCE, '0') # not used
        return self
      end

      # This method will eliminate solar radiation and returns self.
      # @author phylroy.lopez@nrcan.gc.ca
      # @return  [String] self
      def eliminate_only_solar_radiation
        scan if @filearray.nil?
        setcolumntovalue(GLOBAL_HORIZONTAL_RADIATION, '0') # not used
        setcolumntovalue(DIRECT_NORMAL_RADIATION, '0')
        setcolumntovalue(DIFFUSE_HORIZONTAL_RADIATION, '0')
        return self
      end

      # This method will eliminate all radiation except solar and returns self.
      # @author phylroy.lopez@nrcan.gc.ca
      # @return [String] self
      def eliminate_all_radiation_except_solar
        scan if @filearray.nil?
        setcolumntovalue(EXTRATERRESTRIAL_HORIZONTAL_RADIATION, '0') # not used
        setcolumntovalue(EXTRATERRESTRIAL_DIRECT_NORMAL_RADIATION, '0') # not used
        setcolumntovalue(HORIZONTAL_INFRARED_RADIATION_INTENSITY, '315')
        setcolumntovalue(TOTAL_SKY_COVER, '10') # not used
        setcolumntovalue(OPAQUE_SKY_COVER, '10') # not used
        setcolumntovalue(VISIBILITY, '0') # not used
        setcolumntovalue(CEILING_HEIGHT, '0') # not used
        # lux values
        setcolumntovalue(GLOBAL_HORIZONTAL_ILLUMINANCE, '0') # not used
        setcolumntovalue(DIRECT_NORMAL_ILLUMINANCE, '0') # not used
        setcolumntovalue(DIFFUSE_HORIZONTAL_ILLUMINANCE, '0') # not used
        setcolumntovalue(ZENITH_LUMINANCE, '0') # not used
        return self
      end

      # This method will eliminate percipitation and returns self.
      # @author phylroy.lopez@nrcan.gc.ca
      # @return  [String] self
      def eliminate_percipitation
        scan if @filearray.nil?
        setcolumntovalue(PRESENT_WEATHER_OBSERVATION, '0')
        setcolumntovalue(PRESENT_WEATHER_CODES, '999999999') # no weather. Clear day.
        setcolumntovalue(SNOW_DEPTH, '0')
        setcolumntovalue(LIQUID_PRECIPITATION_DEPTH, '0')
        setcolumntovalue(LIQUID_PRECIPITATION_QUANTITY, '0')
        return self
      end

      # This method eliminates wind and returns self.
      # @author phylroy.lopez@nrcan.gc.ca
      # @return  [String] self
      def eliminate_wind
        scan if @filearray.nil?
        setcolumntovalue(WIND_DIRECTION, '0')
        setcolumntovalue(WIND_SPEED, '0')
        return self
      end

      # This method sets Constant Dry and Dew Point Temperature Humidity And Pressure and returns self.
      # @author phylroy.lopez@nrcan.gc.ca
      # @param dbt [Float] dry bulb temperature
      # @param dpt [Float] dew point temperature
      # @param hum [Fixnum] humidity
      # @param press [Fixnum] pressure
      # @return [String] self
      def set_constant_dry_and_dewpoint_temperature_humidity_pressure(dbt = '0.0', dpt = '-1.1', hum = '92', press = '98500')
        scan if @filearray.nil?
        setcolumntovalue(DRY_BULB_TEMPERATURE, dbt)
        setcolumntovalue(DEW_POINT_TEMPERATURE, dpt)
        setcolumntovalue(RELATIVE_HUMIDITY, hum)
        setcolumntovalue(ATMOSPHERIC_STATION_PRESSURE, press)
        return self
      end

      # This method writes to a file.
      # @author phylroy.lopez@nrcan.gc.ca
      # @param filename [String]
      def writetofile(filename)
        scan if @filearray.nil?

        begin
          FileUtils.mkdir_p(File.dirname(filename))
          file = File.open(filename, 'w')
          @filearray.each do |line|
            firstvalue = true
            newline = ''
            line.each do |value|
              if firstvalue == true
                firstvalue = false
              else
                newline += ','
              end
              newline += value
            end
            file.puts(newline)
          end
        rescue IOError => e
          # some error occur, dir not writable etc.
        ensure
          file.close unless file.nil?
        end
        # copies original file
        FileUtils.cp(@ddy_filepath, "#{File.dirname(filename)}/#{File.basename(filename, '.epw')}.ddy")
        FileUtils.cp(@stat_filepath, "#{File.dirname(filename)}/#{File.basename(filename, '.epw')}.stat")
      end
    end # Environment
  end
end

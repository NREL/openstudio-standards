# Methods to store model weather/location information
module OpenstudioStandards
  # The Weather module provides methods to set and get information about the model weather file
  module Weather
    # @!group Information

    # A method to return an array of .epw files names mapped to each climate zone
    #
    # @param epw_file [String] optional epw_file name for NECB methods
    # @return [Hash] a hash of ashrae climate zone weather file pairs
    def self.climate_zone_weather_file_map(epw_file = '')
      # Define the weather file for each climate zone
      climate_zone_weather_file_map = {
        'ASHRAE 169-2006-0A' => 'VNM_SVN_Ho.Chi.Minh-Tan.Son.Nhat.Intl.AP.489000_TMYx.epw',
        'ASHRAE 169-2006-0B' => 'ARE_DU_Dubai.Intl.AP.411940_TMYx.epw',
        'ASHRAE 169-2006-1A' => 'USA_FL_Miami.Intl.AP.722020_TMY3.epw',
        'ASHRAE 169-2006-1B' => 'SAU_RI_Riyadh.AB.404380_TMYx.epw',
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
        'ASHRAE 169-2013-0A' => 'VNM_SVN_Ho.Chi.Minh-Tan.Son.Nhat.Intl.AP.489000_TMYx.epw',
        'ASHRAE 169-2013-0B' => 'ARE_DU_Dubai.Intl.AP.411940_TMYx.epw',
        'ASHRAE 169-2013-1A' => 'USA_HI_Honolulu.Intl.AP.911820_TMY3.epw',
        'ASHRAE 169-2013-1B' => 'IND_DL_New.Delhi-Safdarjung.AP.421820_TMYx.epw',
        'ASHRAE 169-2013-2A' => 'USA_FL_Tampa-MacDill.AFB.747880_TMY3.epw',
        'ASHRAE 169-2013-2B' => 'USA_AZ_Tucson-Davis-Monthan.AFB.722745_TMY3.epw',
        'ASHRAE 169-2013-3A' => 'USA_GA_Atlanta-Hartsfield.Jackson.Intl.AP.722190_TMY3.epw',
        'ASHRAE 169-2013-3B' => 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw',
        'ASHRAE 169-2013-3C' => 'USA_CA_San.Deigo-Brown.Field.Muni.AP.722904_TMY3.epw',
        'ASHRAE 169-2013-4A' => 'USA_NY_New.York-John.F.Kennedy.Intl.AP.744860_TMY3.epw',
        'ASHRAE 169-2013-4B' => 'USA_NM_Albuquerque.Intl.Sunport.723650_TMY3.epw',
        'ASHRAE 169-2013-4C' => 'USA_WA_Seattle-Tacoma.Intl.AP.727930_TMY3.epw',
        'ASHRAE 169-2013-5A' => 'USA_NY_Buffalo.Niagara.Intl.AP.725280_TMY3.epw',
        'ASHRAE 169-2013-5B' => 'USA_CO_Denver-Aurora-Buckley.AFB.724695_TMY3.epw',
        'ASHRAE 169-2013-5C' => 'USA_WA_Port.Angeles-William.R.Fairchild.Intl.AP.727885_TMY3.epw',
        'ASHRAE 169-2013-6A' => 'USA_MN_Rochester.Intl.AP.726440_TMY3.epw',
        'ASHRAE 169-2013-6B' => 'USA_MT_Great.Falls.Intl.AP.727750_TMY3.epw',
        'ASHRAE 169-2013-7A' => 'USA_MN_International.Falls.Intl.AP.727470_TMY3.epw',
        'ASHRAE 169-2013-7B' => 'USA_MN_International.Falls.Intl.AP.727470_TMY3.epw',
        'ASHRAE 169-2013-8A' => 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw',
        'ASHRAE 169-2013-8B' => 'USA_AK_Fairbanks.Intl.AP.702610_TMY3.epw',
        # For measure input
        'NECB HDD Method' => epw_file.to_s,
        # For testing
        'NECB-CNEB-5' => epw_file.to_s,
        'NECB-CNEB-6' => epw_file.to_s,
        'NECB-CNEB-7a' => epw_file.to_s,
        'NECB-CNEB-7b' => epw_file.to_s,
        'NECB-CNEB-8' => epw_file.to_s,
        # For DEER
        'CEC T24-CEC1' => 'ARCATA_725945_CZ2010.epw',
        'CEC T24-CEC2' => 'SANTA-ROSA_724957_CZ2010.epw',
        'CEC T24-CEC3' => 'OAKLAND_724930_CZ2010.epw',
        'CEC T24-CEC4' => 'SAN-JOSE-REID_724946_CZ2010.epw',
        'CEC T24-CEC5' => 'SANTA-MARIA_723940_CZ2010.epw',
        'CEC T24-CEC6' => 'TORRANCE_722955_CZ2010.epw',
        'CEC T24-CEC7' => 'SAN-DIEGO-LINDBERGH_722900_CZ2010.epw',
        'CEC T24-CEC8' => 'FULLERTON_722976_CZ2010.epw',
        'CEC T24-CEC9' => 'BURBANK-GLENDALE_722880_CZ2010.epw',
        'CEC T24-CEC10' => 'RIVERSIDE_722869_CZ2010.epw',
        'CEC T24-CEC11' => 'RED-BLUFF_725910_CZ2010.epw',
        'CEC T24-CEC12' => 'SACRAMENTO-EXECUTIVE_724830_CZ2010.epw',
        'CEC T24-CEC13' => 'FRESNO_723890_CZ2010.epw',
        'CEC T24-CEC14' => 'PALMDALE_723820_CZ2010.epw',
        'CEC T24-CEC15' => 'PALM-SPRINGS-INTL_722868_CZ2010.epw',
        'CEC T24-CEC16' => 'BLUE-CANYON_725845_CZ2010.epw'
      }
      return climate_zone_weather_file_map
    end

    # get the ASHRAE climate zone number
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Integer] ASHRAE climate zone number, 0-8
    def self.model_get_ashrae_climate_zone_number(model)
      # get ashrae climate zone from model
      ashrae_climate_zone = ''
      model.getClimateZones.climateZones.each do |climate_zone|
        if climate_zone.institution == 'ASHRAE'
          ashrae_climate_zone = climate_zone.value
        end
      end

      if ashrae_climate_zone == ''
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Weather.information', 'Please assign an ASHRAE Climate Zone to your model.')
        return false
      else
        cz_number = ashrae_climate_zone.split(//).first.to_i
      end

      # expected climate zone number should be 0 through 8
      if ![0, 1, 2, 3, 4, 5, 6, 7, 8].include? cz_number
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Weather.information', 'ASHRAE climate zone number is not within expected range of 1 to 8.')
        return false
      end

      return cz_number
    end

    # Get absolute path of a weather file included within openstudio-standards
    #
    # @param weather_file_name [String] Name of a weather file included within openstudio-standards, including file extension .epw
    # @return [String] Weather file path
    def self.get_standards_weather_file_path(weather_file_name)
      # Define where the weather files lives
      weather_dir = nil
      if __dir__[0] == ':' # Running from OpenStudio CLI
        # load weather file from embedded files
        epw_string = load_resource_relative("../../../data/weather/#{weather_file_name}")
        ddy_string = load_resource_relative("../../../data/weather/#{weather_file_name.gsub('.epw', '.ddy')}")
        stat_string = load_resource_relative("../../../data/weather/#{weather_file_name.gsub('.epw', '.stat')}")

        # extract to local weather dir
        weather_dir = File.expand_path(File.join(Dir.pwd, 'extracted_files/weather/'))
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Weather.information', "Extracting weather files from OpenStudio CLI to #{weather_dir}")
        FileUtils.mkdir_p(weather_dir)

        path_length = "#{weather_dir}/#{weather_file_name}".length
        if path_length > 260
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Weather.information', "Weather file path length #{path_length} is >260 characters and may cause issues in Windows environments.")
        end
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

      weather_file_path = File.join(weather_dir, weather_file_name)

      return weather_file_path
    end

    # Get absolute path of a weather file included within openstudio-standards that is representative of the climate zone
    #
    # @param climate_zone [String] Name of a climate zone
    # @return [String] Weather file absolutepath
    def self.get_representative_weather_file_path_from_climate_zone(climate_zone)
      climate_zone_weather_file_map = climate_zone_weather_file_map()
      weather_file_name = climate_zone_weather_file_map[climate_zone]
      if weather_file_name.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Weather.information', "Could not determine weather for climate zone: #{climate_zone}")
        return false
      else
        return get_standards_weather_file_path(weather_file_name)
      end
    end

    # Get a list of regular expressions matching the design day categories
    #
    # For looking up design day objects by type
    # @param category [String] The design day category: All Heating,
    def self.ddy_regex_lookup(category)
      ddy_regex_map = {
        /Htg 99.6. Condns DB/ => ['All Heating', 'Heating DB', 'Heating 99.6%'],
        /Htg 99. Condns DB/ => ['All Heating', 'Heating DB', 'Heating 99%'],
        /Htg Wind 99. Condns WS=>MCDB/ => ['All Heating', 'Heating Wind', 'Heating 99%'],
        /Clg 1. Condns DB=>MWB/ => ['All Cooling', 'Cooling DB', 'Cooling 1%'],
        /Clg 2. Condns DP=>MDB/ => ['All Cooling', 'Cooling DP', 'Cooling 2%'],
        /Clg .4. Condns WB=>MDB/ => ['All Cooling', 'Cooling WB', 'Cooling 0.4%'],
        /Clg .4. Condns DB=>MWB/ => ['All Cooling', 'Cooling DB', 'Cooling 0.4%'],
        /January .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'January', 'Cooling DB', 'Cooling 0.4%'],
        /February .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'February', 'Cooling DB', 'Cooling 0.4%'],
        /March .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'March', 'Cooling DB', 'Cooling 0.4%'],
        /April .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'April', 'Cooling DB', 'Cooling 0.4%'],
        /May .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'May', 'Cooling DB', 'Cooling 0.4%'],
        /June .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'June', 'Cooling DB', 'Cooling 0.4%'],
        /July .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'July', 'Cooling DB', 'Cooling 0.4%'],
        /August .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'August', 'Cooling DB', 'Cooling 0.4%'],
        /September .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'September', 'Cooling DB', 'Cooling 0.4%'],
        /October .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'October', 'Cooling DB', 'Cooling 0.4%'],
        /November .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'November', 'Cooling DB', 'Cooling 0.4%'],
        /December .4. Condns DB=>MCWB/ => ['All Cooling', 'Monthly Cooling', 'December', 'Cooling DB', 'Cooling 0.4%'],
        /January .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'January', 'Cooling WB', 'Cooling 0.4%'],
        /February .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'February', 'Cooling WB', 'Cooling 0.4%'],
        /March .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'March', 'Cooling WB', 'Cooling 0.4%'],
        /April .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'April', 'Cooling WB', 'Cooling 0.4%'],
        /May .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'May', 'Cooling WB', 'Cooling 0.4%'],
        /June .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'June', 'Cooling WB', 'Cooling 0.4%'],
        /July .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'July', 'Cooling WB', 'Cooling 0.4%'],
        /August .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'August', 'Cooling WB', 'Cooling 0.4%'],
        /September .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'September', 'Cooling WB', 'Cooling 0.4%'],
        /October .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'October', 'Cooling WB', 'Cooling 0.4%'],
        /November .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'November', 'Cooling WB', 'Cooling 0.4%'],
        /December .4. Condns WB=>MCDB/ => ['All Cooling', 'Monthly Cooling', 'December', 'Cooling WB', 'Cooling 0.4%']
      }
      valid = ddy_regex_map.values.flatten.uniq
      if valid.include?(category)
        return ddy_regex_map.select { |k, v| v.include?(category) }.keys
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Weather.information', "Could not find a matching ddy regular expression for entered category #{category}. Valid categories are #{valid}.")
        # raise
      end
    end

    # Returns the winter design outdoor air dry bulb temperatures in the model
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Array<Double>] an array of outdoor design dry bulb temperatures in degrees Celsius
    def self.model_get_heating_design_outdoor_temperatures(model)
      heating_design_outdoor_temps = []
      model.getDesignDays.each do |dd|
        next unless dd.dayType == 'WinterDesignDay'

        heating_design_outdoor_temps << dd.maximumDryBulbTemperature
      end

      return heating_design_outdoor_temps
    end
  end
end

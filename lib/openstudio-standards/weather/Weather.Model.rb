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
      CALCULATED_SATURATION_PRESSURE_OF_WATER_VAPOR = 100 # pws
      CALCULATED_PARTIAL_PRESSURE_OF_WATER_VAPOR = 101 # pw
      CALCULATED_TOTAL_MIXTURE_PRESSURE = 102 # p
      CALCULATED_HUMIDITY_RATIO = 103 # w
      CALCULATED_HUMIDITY_RATIO_AVG_DAILY = 104 # w averaged daily
      CALCULATED_HUMIDITY_RATIO_AVG_DAILY_DIFF_BASE = 105 # difference of w_averaged_daily from base if w_averaged_daily > base

      # This method initializes and returns self.
      # @author phylroy.lopez@nrcan.gc.ca
      # @param weather_file [String]
      # @return [String] self
      def initialize(weather_file)
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
        else
          # Run differently depending on whether running from embedded filesystem in OpenStudio CLI or not
          if __dir__[0] == ':' # Running from OpenStudio CLI
            # load weather file from embedded files
            epw_string = load_resource_relative("../../../data/weather/#{weather_file}")
            ddy_string = load_resource_relative("../../../data/weather/#{weather_file.gsub('.epw', '.ddy')}")
            stat_string = load_resource_relative("../../../data/weather/#{weather_file.gsub('.epw', '.stat')}")

            # extract to local weather dir
            weather_dir = File.expand_path(File.join(Dir.pwd, 'extracted_files/weather/'))
            puts "Extracting weather files to #{weather_dir}"
            FileUtils.mkdir_p(weather_dir)
            File.open("#{weather_dir}/#{weather_file}", 'wb') { |f| f << epw_string; f.flush }
            File.open("#{weather_dir}/#{weather_file.gsub('.epw', '.ddy')}", 'wb') { |f| f << ddy_string; f.flush }
            File.open("#{weather_dir}/#{weather_file.gsub('.epw', '.stat')}", 'wb') { |f| f << stat_string; f.flush }
          else # loaded gem from system path
            top_dir = File.expand_path('../../..', File.dirname(__FILE__))
            weather_dir = File.expand_path("#{top_dir}/data/weather")
          end

          @epw_filepath = "#{weather_dir}/#{weather_file}"
          @ddy_filepath = "#{weather_dir}/#{weather_file.sub('epw', 'ddy')}"
          @stat_filepath = "#{weather_dir}/#{weather_file.sub('epw', 'stat')}"
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

        @stat_file = OpenstudioStandards::Weather::StatFile.load(@stat_filepath)

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

      # This method calculates dehumidification degree days (DDD)
      # @author sara.gilani@canada.ca
      # Reference: ASHRAE Handbook - Fundamentals > CHAPTER 1. PSYCHROMETRICS
      def calculate_humidity_ratio
        # coefficients for the calculation of pws (Reference: ASHRAE Handbook - Fundamentals > CHAPTER 1. PSYCHROMETRICS)
        c1 = -5.6745359E+03
        c2 = 6.3925247E+00
        c3 = -9.6778430E-03
        c4 = 6.2215701E-07
        c5 = 2.0747825E-09
        c6 = -9.4840240E-13
        c7 = 4.1635019E+00
        c8 = -5.8002206E+03
        c9 = 1.3914993E+00
        c10 = -4.8640239E-02
        c11 = 4.1764768E-05
        c12 = -1.4452093E-08
        c13 = 6.5459673E+00
        sum_w = 0.0
        w_base = 0.010 # Note: this is base for the calculation of 'dehumidification degree days' (REF: Wright, L. (2019). Setting the Heating/Cooling Performance Criteria for the PHIUS 2018 Passive Building Standard. In ASHRAE Topical Conference Proceedings, pp. 399-409)
        ddd = 0.0 # dehimudifation degree-days
        convert_c_to_k = 273.15 # convert degree C to kelvins (k)

        scan if @filearray.nil?
        @filearray.each do |line|
          unless line.first =~ /\D(.*)/
            # Note: the below Step 1, 2, 3, and 4 are the steps for the calculation of humidity ratio as per ASHRAE Handbook - Fundamentals > CHAPTER 1. PSYCHROMETRICS
            # Step 1: calculate pws (SATURATION_PRESSURE_OF_WATER_VAPOR), [Pascal]
            if line[DRY_BULB_TEMPERATURE].to_f <= 0.0
              line[CALCULATED_SATURATION_PRESSURE_OF_WATER_VAPOR] = c1 / (line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k) +
                                                                    c2 +
                                                                    c3 * (line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k) +
                                                                    c4 * (line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k)**2 +
                                                                    c5 * (line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k)**3 +
                                                                    c6 * (line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k)**4 +
                                                                    c7 * Math.log((line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k), Math.exp(1)) # 2.718281828459
              line[CALCULATED_SATURATION_PRESSURE_OF_WATER_VAPOR] = Math.exp(1)**line[CALCULATED_SATURATION_PRESSURE_OF_WATER_VAPOR].to_f
            else # if line[DRY_BULB_TEMPERATURE].to_f > 0.0
              line[CALCULATED_SATURATION_PRESSURE_OF_WATER_VAPOR] = c8 / (line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k) +
                                                                    c9 +
                                                                    c10 * (line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k) +
                                                                    c11 * (line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k)**2 +
                                                                    c12 * (line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k)**3 +
                                                                    c13 * Math.log((line[DRY_BULB_TEMPERATURE].to_f + convert_c_to_k), Math.exp(1))
              line[CALCULATED_SATURATION_PRESSURE_OF_WATER_VAPOR] = Math.exp(1)**line[CALCULATED_SATURATION_PRESSURE_OF_WATER_VAPOR].to_f
            end

            # Step 2: calculate pw (PARTIAL_PRESSURE_OF_WATER_VAPOR), [Pascal]
            # Relative Humidity (RH) = 100 * pw / pws
            line[CALCULATED_PARTIAL_PRESSURE_OF_WATER_VAPOR] = line[CALCULATED_SATURATION_PRESSURE_OF_WATER_VAPOR].to_f * line[RELATIVE_HUMIDITY].to_f / 100.0

            # Step 3: calculate p (TOTAL_MIXTURE_PRESSURE), [Pascal]
            line[CALCULATED_TOTAL_MIXTURE_PRESSURE] = line[CALCULATED_PARTIAL_PRESSURE_OF_WATER_VAPOR].to_f + line[ATMOSPHERIC_STATION_PRESSURE].to_f

            # Step 4: calculate w (HUMIDITY_RATIO)
            line[CALCULATED_HUMIDITY_RATIO] = 0.621945 * line[CALCULATED_PARTIAL_PRESSURE_OF_WATER_VAPOR].to_f / (line[CALCULATED_TOTAL_MIXTURE_PRESSURE].to_f - line[CALCULATED_PARTIAL_PRESSURE_OF_WATER_VAPOR].to_f)

            #-----------------------------------------------------------------------------------------------------------
            # calculate daily average of w AND its difference from base
            if line[HOUR].to_f < 24.0
              sum_w += line[CALCULATED_HUMIDITY_RATIO].to_f
              line[CALCULATED_HUMIDITY_RATIO_AVG_DAILY] = 0.0
            elsif line[HOUR].to_f == 24.0
              line[CALCULATED_HUMIDITY_RATIO_AVG_DAILY] = (sum_w + line[CALCULATED_HUMIDITY_RATIO].to_f) / 24.0
              if line[CALCULATED_HUMIDITY_RATIO_AVG_DAILY].to_f > w_base
                line[CALCULATED_HUMIDITY_RATIO_AVG_DAILY_DIFF_BASE] = line[CALCULATED_HUMIDITY_RATIO_AVG_DAILY].to_f - w_base
              else
                line[CALCULATED_HUMIDITY_RATIO_AVG_DAILY_DIFF_BASE] = 0.0
              end
              sum_w = 0.0
            end

            ddd += line[CALCULATED_HUMIDITY_RATIO_AVG_DAILY_DIFF_BASE].to_f

          end
        end
        return ddd
      end
    end
  end
end

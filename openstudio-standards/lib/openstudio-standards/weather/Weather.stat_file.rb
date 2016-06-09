######################################################################
#  Copyright (c) 2008-2013, Alliance for Sustainable Energy.
#  All rights reserved.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

require 'pathname'

module EnergyPlus
  class StatFile
    attr_accessor :path
    attr_accessor :valid
    attr_accessor :lat
    attr_accessor :lon
    attr_accessor :elevation
    attr_accessor :gmt
    attr_accessor :monthly_dry_bulb
    attr_accessor :delta_dry_bulb
    attr_accessor :hdd18
    attr_accessor :cdd18
    attr_accessor :hdd10
    attr_accessor :cdd10
    attr_accessor :heating_design_info
    attr_accessor :cooling_design_info
    attr_accessor :extremes_design_info
    attr_accessor :climate_zone
    attr_accessor :standard
    attr_accessor :summer_wet_months
    attr_accessor :winter_dry_months
    attr_accessor :autumn_months 
    attr_accessor :spring_months 
    attr_accessor :typical_summer_wet_week 
    attr_accessor :typical_winter_dry_week 
    attr_accessor :typical_autumn_week
    attr_accessor :typical_spring_week

    def initialize(path)
      @path = Pathname.new(path)
      @valid = false
      @lat = []
      @lon = []
      @gmt = []
      @elevation = []
      @hdd18 = []
      @cdd18 = []
      @hdd10 = []
      @cdd10 = []
      @monthly_dry_bulb = []
      @delta_dry_bulb = []
      @heating_design_info = []
      @cooling_design_info  = []
      @extremes_design_info = []
      @climate_zone = []
      @standard = []
      @summer_wet_months = []
      @winter_dry_months = []
      @autumn_months = []
      @spring_months = []
      @typical_summer_wet_week = []
      @typical_winter_dry_week = []
      @typical_autumn_week = []
      @typical_spring_week = []
      @data = []
      init
    end
    
    #Output for debugging stat routines. 
    def output()
      line = String.new
      line << "#{@path} , "
      line << "#{@lat} ,"
      line << "#{@lon} ,"
      line << "#{@gmt} ,"
      line << "#{@elevation} ,"
      line << "#{@hdd18} ,"
      line << "#{@cdd18} ,"
      line << "#{@hdd10} ,"
      line << "#{@cdd10} ,"
      line << "#{mean_dry_bulb} ,"
      line << "#{delta_dry_bulb} ,"
      line << "#{@heating_design_info} ,"
      line << "#{@cooling_design_info}  ,"
      line << "#{@extremes_design_info} ,"
      line << "#{@climate_zone} ," 
      line << "#{@standard} ," 
      line << "#{@valid} ,"
    end
    

    def valid?
      return @valid
    end

    # the mean of the mean monthly dry bulbs
    def mean_dry_bulb
      if not @monthly_dry_bulb.empty? then
        sum = 0
        @monthly_dry_bulb.each { |db| sum += db }
        mean = sum/@monthly_dry_bulb.size
      else
        mean = ''
      end

      mean
    end

    # max - min of the mean monthly dry bulbs
    def delta_dry_bulb
      if not @monthly_dry_bulb.empty? then
        delta_t = @monthly_dry_bulb.max-@monthly_dry_bulb.min
      else
        delta_t = ''
      end

      delta_t
    end

    private

    # initialize
    def init
      if @path.exist?
        File.open(@path) do |f|
          text = f.read.force_encoding('iso-8859-1')
          parse(text)

        end
      end
    end

    def parse(text)

      # get lat, lon, gmt
      regex = /\{(N|S)\s*([0-9]*).\s*([0-9]*)'\}\s*\{(E|W)\s*([0-9]*).\s*([0-9]*)'\}\s*\{GMT\s*(.*)\s*Hours\}/
      match_data = text.match(regex)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find lat/lon/gmt")
        return
      else

        @lat = match_data[2].to_f + (match_data[3].to_f)/60.0
        if match_data[1] == 'S'
          @lat = -@lat
        end

        @lon = match_data[5].to_f + (match_data[6].to_f)/60.0
        if match_data[4] == 'W'
          @lon = -@lon
        end

        @gmt = match_data[7]
      end

      # get elevation
      regex = /Elevation --\s*(.*)m (above|below) sea level/
      match_data = text.match(regex)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find elevation")
        return
      else
        @elevation = match_data[1].to_f
        if match_data[2] == 'below'
          @elevation = -@elevation
        end
      end

     
      # get heating and cooling degree days
      cdd10Regex = /-\s*(.*) annual \((standard|wthr file)\) cooling degree-days \(10.C baseline\)/
      match_data = text.match(cdd10Regex)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find CDD 10")
        return

      else
        @cdd10 = match_data[1].to_f
      end

      hdd10Regex = /-\s*(.*) annual \((standard|wthr file)\) heating degree-days \(10.C baseline\)/
      match_data = text.match(hdd10Regex)

      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find HDD 10")
        return
      else
        @hdd10 = match_data[1].to_f
      end

      cdd18Regex = /-\s*(.*) annual \((standard|wthr file)\) cooling degree-days \(18.*C baseline\)/
      match_data = text.match(cdd18Regex)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find CDD 18")
        return
      else
        @cdd18 = match_data[1].to_f
      end

      hdd18Regex = /-\s*(.*) annual \((standard|wthr file)\) heating degree-days \(18.*C baseline\)/
      match_data = text.match(hdd18Regex)

      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find HDD 18")
        return
      else
        @hdd18 = match_data[1].to_f
      end


      #use regex to get the temperatures
      regex = /Daily Avg(.*)\n/
      match_data = text.match(regex)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find outdoor air temps")
        return
      else
        # first match is outdoor air temps
        monthly_temps = match_data[1].strip.split(/\s+/)

        # have to be 12 months
        if monthly_temps.size != 12
          OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find outdoor air temps")
          return
        end

        # insert as numbers
        monthly_temps.each { |temp| @monthly_dry_bulb << temp.to_f }
      end
      
      #Get 2004 Climate zone. 
      # - Climate type "3B" (ASHRAE Standard 196-2006 Climate Zone)**
      # - Climate type "6A" (ASHRAE Standards 90.1-2004 and 90.2-2004 Climate Zone)**
      #use regex to get the temperatures
      regex = /Climate type \"(.*?)\" \(ASHRAE Standards?(.*)\)\*\*/
      match_data = text.match(regex)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find Climate zone 2004")
        @climate_zone = "NA"
      else
        @climate_zone = match_data[1].to_s.strip
        @standard = match_data[2].to_s.strip
      end


      
      # Seasons as define by file (Summer, Autumn, Spring Winter...or Wet and Dry )  
      match_data = text.match(/(Summer is |Wet Period=)(.*)/)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't Summer  / Wet months")
      else
        @summer_wet_months = match_data[2].to_s.strip
      end
      
      match_data = text.match(/(Winter is |Dry Period=)(.*)/)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't Winter  / Dry months")
      else
        @winter_dry_months = match_data[2].to_s.strip
      end
      
      match_data = text.match(/Autumn is (.*)/)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't Summer months")
        @autumn_months = "NA"
      else
        @autumn_months = match_data[1].to_s.strip
      end
      
      match_data = text.match(/Spring is (.*)/)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't Summer months")
        @spring_months = "NA"
      else
        @spring_months = match_data[1].to_s.strip
      end
      
      
      
     
      regex = /Typical Week Period selected:(.*?)C/
      match_data = text.scan(regex)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find Typical weather weeks")
      else
        @typical_summer_wet_week = Date.parse("#{match_data[0][0].split(":")[0]} 2000")
        @typical_winter_dry_week = Date.parse("#{match_data[1][0].split(":")[0]} 2000")
        if match_data[2].nil?
          @typical_autumn_week = "NA"
          @typical_spring_week = "NA"
        else
          @typical_autumn_week = Date.parse("#{match_data[2][0].split(":")[0]} 2000")
          @typical_spring_week = Date.parse("#{match_data[3][0].split(":")[0]} 2000")
        end
      end
      
      regex = /Extreme Hot Week Period selected:(.*?)C/
      match_data = text.match(regex)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find Extreme hot weather week")
      else
        @extreme_hot_week = Date.parse("#{match_data[1].split(":")[0]}")
      end

      regex = /Extreme Cold Week Period selected:(.*?)C/
      match_data = text.match(regex)
      if match_data.nil?
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.Weather.stat_file", "Can't find Extreme hot weather week")
      else
        @extreme_cold_week = Date.parse("#{match_data[1].split(":")[0]}")
      end
      
      

      # now we are valid
      @valid = true
    end

  end
end
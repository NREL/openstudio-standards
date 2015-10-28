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
    attr_accessor :monthlyDB
    attr_accessor :hdd18
    attr_accessor :cdd18
    attr_accessor :hdd10
    attr_accessor :cdd10

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
      init
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
        puts "Can't find lat/lon/gmt"
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
        puts "Can't find elevation"
        return
      else
        @elevation = match_data[1].to_f
        if match_data[2] == 'below'
          @elevation = -@elevation
        end
      end

      # get heating and cooling degree days
      cdd10Regex = /-\s*(.*) annual \(standard\) cooling degree-days \(10.C baseline\)/
      match_data = text.match(cdd10Regex)
      if match_data.nil?
        puts "Can't find CDD 10"
        return
      else
        @cdd10 = match_data[1].to_f
      end

      hdd10Regex = /-\s*(.*) annual \(standard\) heating degree-days \(10.C baseline\)/
      match_data = text.match(hdd10Regex)
      if match_data.nil?
        puts "Can't find HDD 10"
        return
      else
        @hdd10 = match_data[1].to_f
      end

      cdd18Regex = /-\s*(.*) annual \(standard\) cooling degree-days \(18.3.C baseline\)/
      match_data = text.match(cdd18Regex)
      if match_data.nil?
        puts "Can't find CDD 18"
        return
      else
        @cdd18 = match_data[1].to_f
      end

      hdd18Regex = /-\s*(.*) annual \(standard\) heating degree-days \(18.3.C baseline\)/
      match_data = text.match(hdd18Regex)
      if match_data.nil?
        puts "Can't find HDD 18"
        return
      else
        @hdd18 = match_data[1].to_f
      end


      #use regex to get the temperatures
      regex = /Daily Avg(.*)\n/
      match_data = text.match(regex)
      if match_data.nil?
        puts "Can't find outdoor air temps"
        return
      else
        # first match is outdoor air temps
        monthly_temps = match_data[1].strip.split(/\s+/)

        # have to be 12 months
        if monthly_temps.size != 12
          puts "Can't find outdoor air temps"
          return
        end

        # insert as numbers
        monthly_temps.each { |temp| @monthly_dry_bulb << temp.to_f }
      end

      # now we are valid
      @valid = true
    end

  end
end
require 'csv'

module OpenstudioStandards
  module Weather
    class Epw
      attr_accessor :filename
      attr_reader :city
      attr_reader :state
      attr_reader :country
      attr_accessor :data_type
      attr_reader :wmo
      attr_reader :lat
      attr_reader :lon
      attr_reader :gmt
      attr_reader :elevation
      attr_accessor :data_period

      # access to all the weather data in array of arrays
      attr_reader :header_data
      attr_accessor :weather_data

      def initialize(filename)
        @filename = filename
        @city = ''
        @state = ''
        @country = ''
        @data_type = ''
        @wmo = ''
        @lat = ''
        @lon = ''
        @gmt = ''
        @elevation = ''
        @valid = false

        @header_data = []
        @weather_data = []
        process_header
      end

      # load an EPW file as an instance of OpenstudioStandards::Weather::Epw
      #
      # @param filename [String] full path to EPW file
      def self.load(filename)
        raise "EPW file does not exist: #{filename}" unless File.file?(filename)

        f = OpenstudioStandards::Weather::Epw.new(filename)
      end

      def to_kml(xml_builder_obj, url)
        xml_builder_obj.Placemark do
          xml_builder_obj.name @city
          xml_builder_obj.visibility '0'
          xml_builder_obj.description do
            xml_builder_obj.cdata!('<img src="kml/ep_header8.png" width=180 align=right><br><table><tr><td colspan="2">'\
                           "<b>#{@city}</b></href></td></tr>\n" +
                                       "<tr><td></td><td>WMO <b>#{@wmo}</b></td></tr>\n" +
                                       "<tr><td></td><td>Time Zone GMT <b>#{@gmt}</b> hours</td></tr>\n" +
                                       "<tr><td></td><td>URL #{url}</td></tr></table>")
          end
          xml_builder_obj.styleUrl '#weatherlocation'
          xml_builder_obj.Point do
            xml_builder_obj.altitudeMode 'absolute'
            xml_builder_obj.coordinates "#{@lon},#{@lat},#{elevation}"
          end
        end
      end

      def valid?
        return @valid
      end

      # save the weather data from EPW file to CSV
      #
      # @param filename [String] Path to the file that will be saved. Will overwrite if it exists.
      def save_as(filename)
        File.delete filename if File.exist? filename
        FileUtils.mkdir_p(File.dirname(filename)) unless Dir.exist?(File.dirname(filename))

        CSV.open(filename, 'wb') do |csv|
          @header_data.each { |r| csv << r }
          csv << [
            'DATA PERIODS', @data_period[:count], @data_period[:records_per_hour], @data_period[:name],
            @data_period[:start_day_of_week], @data_period[:start_date], @data_period[:end_date]
          ]
          @weather_data.each { |r| csv << r }
        end

        true
      end

      # Append the weather data (after data periods) to the end of the weather file. This allows
      # for the creation of multiyear weather files. Note that the date/order is not checked. It assumes
      # that the data are being added at the end is the more recent data
      #
      # @param filename [String] Path to the file that will be appended
      def append_weather_data(filename)
        to_append = OpenStudio::Weather::Epw.load(filename)

        prev_length = @weather_data.size
        @weather_data += to_append.weather_data

        prev_length + to_append.weather_data.size == @weather_data.size
      end

      # returns the EPW data as a JSON string
      #
      # @return [String] JSON string
      def to_json(*options)
        as_json(*options).to_json(*options)
      end

      private

      def as_json(options = {})
        {
          city: @city,
          state: @state,
          country: @country,
          data_type: @data_type,
          wmo: @wmo,
          latitude: @lat,
          longitude: @lon,
          elevation: @elevation,
          filename: @filename
        }
      end

      # initialize
      def process_header
        header_section = true
        row_count = 0

        CSV.foreach(@filename, 'r') do |row|
          row_count += 1

          if header_section
            if row[0] =~ /data.periods/i
              @data_period = {
                count: row[1].to_i,
                records_per_hour: row[2].to_i,
                name: row[3],
                start_day_of_week: row[4],
                start_date: row[5],
                end_date: row[6]
              }

              header_section = false

              next
            else
              @header_data << row
            end
          else
            @weather_data << row
          end

          # process only header row
          # LOCATION,Adak Nas,AK,USA,TMY3,704540,51.88,-176.65,-10.0,5.0
          if row_count == 1
            @valid = true

            @city = row[1].tr('/', '-')
            @state = row[2]
            @country = row[3]
            @data_type = row[4]
            if @data_type =~ /TMY3/i
              @data_type = 'TMY3'
            elsif @data_type =~ /TMY2/i
              @data_type = 'TMY2'
            elsif @data_type =~ /TMY/i
              @data_type = 'TMY'
            end
            @wmo = row[5]
            @wmo.nil? ? @wmo = 'wmoundefined' : @wmo = @wmo.to_i
            @lat = row[6].to_f
            @lon = row[7].to_f
            @gmt = row[8].to_f
            @elevation = row[9].to_f
          end
        end
      end
    end
  end
end

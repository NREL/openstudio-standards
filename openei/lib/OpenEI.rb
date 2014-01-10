# Nicholas Long

#TODO : Add error catching for various items.
# 1: OpenEI down
# 2: nil values in results
#    @rates = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }     #nested hash
require 'rubygems'
require 'net/http'
require 'json'
require 'cgi'

module OpenEIModule
  attr_accessor :open_ei_data
  def initialize
    @open_ei_data = ""
  end
end

class OpenEI

  @@BASE_URL = 'http://en.openei.org'

  attr_accessor :eia_utility_id
  attr_accessor :utility_name
  attr_accessor :utility_machine_name
  attr_accessor :rates
  attr_accessor :rate_names
  attr_accessor :debug_urls

  def initialize(search_str=nil, rate_filter=nil, debug=false)
    @eia_utility_id = nil
    @ulility_name = nil
    @utility_machine_name = nil
    @utility_info = nil
    @debug_urls = []
    @qualification = {"type" => "any"}
    @debug = debug

    @rates = {}
    @rate_names = {}

    if !search_str.nil?
      #do the whole workflow for extracting the rate
      geolocate(search_str)
      get_utility_info(@eia_utility_id)
      get_rates(@utility_name, rate_filter)
    end
  end


  def geolocate(search_str)
    if @debug
      puts "--------- Geolocating Utility ----------"
      puts "Geolocation String: #{search_str}"
    end

    url = "#{@@BASE_URL}/apps/servicescripts/utilMapsDb.php?address=#{search_str}"
    @debug_urls << ["geolocate", url]

    json_data = Net::HTTP.get_response(URI.parse(url)).body
    # TODO Catch exceptions on HTTP request

    data_resp = JSON.parse(json_data)

    # TODO: make sure that utility ID is unique
    # TODO: check if the rate is commercial or residential
    @eia_utility_id = data_resp['eia_utility_id'].to_i
    @utility_name = data_resp['openei_utility_name']

  end

  def get_utility_info(utility_id)
    if @debug
      puts "--------- Requesting Utility Info ----------"
    end
    url = "#{@@BASE_URL}/wiki/Special:Ask/-5B-5BCategory:Utility-20Companies-5D-5D-5B-5BEiaUtilityId::#{utility_id}-5D-5D/-3FLogo/-3FEiaUtilityId/-3FPlace/-3FName/-3FIndustrialAvgRate/-3FCommercialAvgRate/-3FResidentialAvgRate/limit%3D1/offset%3D0/format%3Djson"
    @debug_urls << ["utility info", url]
    json_data = Net::HTTP.get_response(URI.parse(url)).body

    data_resp = JSON.parse(json_data)
    @utility_info = data_resp['items'][0]
  end

  # Method to return all the rates to member variable @rates.
  # Currently this method only returns the Secondary .* Rates
  def get_rates(utility_name, rate_filter=nil)
    if @debug
      puts "--------- Requesting Utility Rates ----------"
    end

    if !utility_name.nil?
      @utility_machine_name = utility_name.gsub("&amp;", "%26").gsub(" ", "_")
      url = "#{@@BASE_URL}/services/rest/utility_rates?version=1&format=json_plain&ratesforutility=#{@utility_machine_name}&detail=full"
      @debug_urls << ["rates", url]

      json_data = Net::HTTP.get_response(URI.parse(url)).body
      # TODO catch exceptions

      data_resp = JSON.parse(json_data)

      filter = ""
      if !rate_filter.nil?
        filter = rate_filter
      else
        filter = "secondary"
      end

      data_resp['items'].each do |rate|
        # TODO make sure rate does not already exist in hash
        rate_name = rate['name']
        if @rates.has_key?(rate_name)
          if @debug
            puts "ERROR: Key already exists in list #{rate_name}"
          end
        else
          #puts rate_name
          #only find Secondary items
          @rate_names["name"] = rate_name

          if rate_name =~ /#{filter}/i
            if @debug
              puts "Adding Utility Rate: #{rate_name}"
            end
            @rates[rate_name] = OpenEIRate.new(rate, @debug)
          end
        end
      end
    end #if utility_name
  end

  def to_csv()
    out = []
    out << @eia_utility_id
    out << @utility_name
    out << @utility_machine_name
    if !rates.nil?
      @rates.each_value do |rate|
        out << rate.to_csv
      end
    end

    out.join(",")
  end


  def to_json(*a)
    hash = {
        :output_attributes => {
            :json_class => self.class.name,
            :attribute => {
                :eia_utility_id => @eia_utility_id,
                :qualification => @qualification,
                :utility_name => @utility_name,
                :utility_machine_name => @utility_machine_name },
        }
    }

    hash[:output_attributes][:attribute][:rates] = {}
    if !rates.nil?
      @rates.each_value do |rate|
        hash[:output_attributes][:attribute][:rates][rate.name] = rate.to_json
      end
    end

    hash.to_json(*a)
  end

  def self.json_create(o)
    new(*o['data'])
  end


end



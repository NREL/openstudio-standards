# Nicholas Long

require "#{Pathname.new(__FILE__) + '../../lib/OpenEIBlock'}"

class OpenEIRate
  attr_accessor :name
  attr_accessor :fixed_monthly_charge
  attr_accessor :data_source
  attr_accessor :openei_uri
  attr_accessor :sector
  attr_accessor :demand_charges
  attr_accessor :demand_weekday

  def initialize(open_ei_rate, debug=false)
    @BASE_YEAR = 2010  #defines the base year for the generation of any schedule
    @raw_values = open_ei_rate.to_a.map{|x| x[0]}.join(",") #used to count instances

    @debug = debug
    if @debug
      puts "--------- Parsing Rate ----------"
    end

    @name = open_ei_rate['name'].split(/(\W)/).map{|x| x.capitalize}.join  #titleize the name
    #gsub several terms
    @name.gsub!("Sg", "SG")
    @name.gsub!("Spvtou", "SPVTOU")
    @name.gsub!("Stou", "STOU")
    @label = open_ei_rate['label']
    @sector = open_ei_rate['sector']
    @data_source = open_ei_rate['source']
    @openei_uri = open_ei_rate['uri']

    @startdate = open_ei_rate['startdate']
    if !@startdate.nil?
      #"2010-06-01 00:00:00"
      #@startdate = DateTime.strptime(@startdate, '%Y-%m-%d %H:%M:%S')  #TODO convert this to date time class
    end

    # buy options
    @flat_rate_buy = open_ei_rate['flat_rate_buy']
    @usenetmetering = open_ei_rate['usenetmetering'] == "true" ? true : false

    # monthly charges & tiers
    @fixed_monthly_charge = open_ei_rate['fixedmonthlycharge']
    if !@fixed_monthly_charge.nil?
      @fixed_monthly_charge = @fixed_monthly_charge.to_f
    end

    # demand charges
    @demand = OpenEIBlock.new('demand', open_ei_rate)

    # tou rates
    parse_tou_schedule(open_ei_rate)

    # tiered rates (i.e. blocks)
    parse_tiered_rate_month(open_ei_rate)

  end

  def has_demand_charges?
    not @demand_charges.empty?
  end

  def assume_net_metering?
    @usenetmetering
  end

  def has_tou_rates?
    not @tou_rates.empty?
  end

  def to_openstudio()
    #do something here?

  end

  def to_csv
    out = []

    out << @fixed_monthly_charge
    out << @data_source
    out << @openei_uri
    out << @sector
    out << @demand_charges
    out << @demand_schedule

    out.join(",")
  end

  def to_json(*a)
    hash = {}
    hash['json_class'] =  self.class.name
    self.instance_variables.each do |var|
      if !self.instance_variable_get(var).kind_of?(Array) && !self.instance_variable_get(var).kind_of?(OpenEIBlock)
        hash[var.to_s.delete("@")] = self.instance_variable_get(var)
      end
    end

    hash[:demand] = @demand.to_json
    hash
  end

  def self.json_create(o)
    new(*o['data'])
  end

  private

  def parse_tou_schedule(open_ei_rate)
    tou_buy_cnt = 0
    if !open_ei_rate['tourateperiod1buy'].nil?

    end

    if !open_ei_rate['touweekdayschedule'].nil?

    end
  end



  def parse_tiered_rate_month(open_ei_rate)
    count =  @raw_values.split(/tieredratemonth/).size - 1

    result = /tieredratemonth(\d*),/.match(@raw_values)
  end







end
# Nicholas Long

class OpenEIBlock

  def initialize(block_name, open_ei_rate, debug=false)
    @raw_values = open_ei_rate.to_a.map{|x| x[0]}.join(",") #used to count instances
    @block_name = block_name
    @debug = debug

    if block_name == 'demand'
      # parse out the demand items and persist into a new block
      @demand_ratchet_percentage = open_ei_rate['demandratchetpercentage']
      @demand_charges = []
      @demand_charges_fixed = parse_demand_charges_fixed(open_ei_rate)
      @demand_schedule = []
      parse_demand_schedule(open_ei_rate)

    end
  end

  def to_json(*a)
    hash = {}
    hash['json_class'] =  self.class.name
    self.instance_variables.each do |var|
      if !self.instance_variable_get(var).kind_of? Array
        next if var == "@raw_values"
        next if var == "@debug"
        hash[var.to_s.delete("@")] = self.instance_variable_get(var)
      end
    end

    #append all of the arrays
    hash[:demand_charges_fixed] = Hash[*@demand_charges_fixed.flatten]

    hash
  end

  def self.json_create(o)
    new(*o['data'])
  end

  private

  #days are 0..6 with 0 = sunday
  def parse_schedule_string(weekday, weekend)
    result = []

    if !weekday.nil?
      #todo: do other validation?


      cnt = 0
      month_cnt = 1

      t_0 = Time.utc(2010,month_cnt,1,0,0,0)
      weekday.split("").each do |it|
        if cnt % 24 == 0 && month_cnt != 12
          month_cnt += 1
          t_0 = Time.utc(2010,month_cnt,1,0,0,0)
        end
        cnt += 1

        #rates are not 8760 rather they are just 288 (hour of day for entire month for 12 months)
        #if days.include?(t_0.wday)
        #  result << [t_0, it.to_i ]
        #  t_0 += 3600
        #end

      end
    end

    result
  end

  def parse_demand_schedule(open_ei_rate)
    if @debug
      puts "--------- Parsing Demand Charges ----------"
    end

    count = @raw_values.split('demandchargeperiod').size - 1
    (1..count).each do |it|
      @demand_charges << open_ei_rate["demandchargeperiod#{it}"].to_f
    end

    if @debug
      puts "--------- Parsing Demand Schedules ----------"
    end

    data1 = parse_schedule_string(open_ei_rate['demandchargeweekendschedule'], open_ei_rate['demandchargeweekdayschedule'])


    #data1.each do |index|
    #  puts "#{index[0].strftime("%m %H")} : #{index[1]}"
    #end

    #@demand_schedule << [t_0, @demand_charges[it.to_i - 1] ]
    #t_0 += 3600
  end

  def parse_demand_charges_fixed(open_ei_rate)
    count = @raw_values.split('fixeddemandchargemonth').size - 1
    data = []
    (1..count).each do |it|
      data << [ it, open_ei_rate["fixeddemandchargemonth#{it}"].to_f ]
    end

    if @debug
      puts data.inspect
    end

    data
  end

end
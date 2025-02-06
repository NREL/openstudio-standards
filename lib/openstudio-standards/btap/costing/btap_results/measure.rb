require 'erb'
require 'json'
require 'zlib'
require 'base64'
require 'csv'
require 'date'
require 'time'
require 'openstudio-standards'
require_relative 'resources/btap_measure_helper'
require_relative 'resources/btap_costing.rb'
require_relative 'resources/ventilation_costing.rb'
require_relative 'resources/envelope_costing.rb'
require_relative 'resources/lighting_costing.rb'
require_relative 'resources/heating_cooling_costing.rb'
require_relative 'resources/heating_cooling_costing.rb'
require_relative 'resources/shw_costing.rb'
require_relative 'resources/dcv_costing.rb'
require_relative 'resources/daylighting_sensor_control_costing.rb'
require_relative 'resources/led_lighting_costing.rb'
require_relative 'resources/pv_ground_costing.rb'
require_relative 'resources/nv_costing.rb'

module Enumerable
  def sum
    self.inject(0) {|accum, i| accum + i}
  end

  def mean
    self.sum / self.length.to_f
  end

  def sample_variance
    m = self.mean
    sum = self.inject(0) {|accum, i| accum +(i - m) ** 2}
    sum / (self.length - 1).to_f
  end

  def standard_deviation
    return Math.sqrt(self.sample_variance)
  end
end

# Method for sig figs, from stackoverflow
class Float
  def signif(signs)
    Float("%.#{signs}g" % self)
  end
end


#padmassun's *TODO LIST*
#need <Lighting Adjustment Applied (0.9)>
#need information about  <Jan 2.5 Design Temp> to complete <HRV Calc> for each space type
#padmassun's comment end

# start the measure
class BtapResults < OpenStudio::Measure::ReportingMeasure
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    'BTAP Results'
  end

  # human readable description
  def description
    'This measure creates BTAP result values used for NRCan analyses.'
  end

  # human readable description of modeling approach
  def modeler_description
    'Grabs data from OS model and sql database and keeps them in the '
  end

  # define the arguments that the user will input
  def arguments (model = nil)
    args = OpenStudio::Measure::OSArgumentVector.new
    generate_hourly_report = OpenStudio::Measure::OSArgument::makeStringArgument('generate_hourly_report', false)
    generate_hourly_report.setDisplayName('Generate Hourly Report')
    generate_hourly_report.setDefaultValue('false')
    args << generate_hourly_report

    output_diet = OpenStudio::Measure::OSArgument::makeBoolArgument('output_diet', true)
    output_diet.setDisplayName('Reduce outputs')
    output_diet.setDefaultValue(false)
    args << output_diet

    envelope_costing = OpenStudio::Measure::OSArgument::makeBoolArgument('envelope_costing', true)
    envelope_costing.setDisplayName('Enable Envelope Costing')
    envelope_costing.setDefaultValue(true)
    args << envelope_costing

    lighting_costing = OpenStudio::Measure::OSArgument::makeBoolArgument('lighting_costing', true)
    lighting_costing.setDisplayName('Enable Lighting Costing')
    lighting_costing.setDefaultValue(true)
    args << lighting_costing

    boilers_costing = OpenStudio::Measure::OSArgument::makeBoolArgument('boilers_costing', true)
    boilers_costing.setDisplayName('Enable Boiler Costing')
    boilers_costing.setDefaultValue(true)
    args << boilers_costing

    chillers_costing = OpenStudio::Measure::OSArgument::makeBoolArgument('chillers_costing', true)
    chillers_costing.setDisplayName('Enable Chiller Costing')
    chillers_costing.setDefaultValue(true)
    args << chillers_costing

    cooling_towers_costing = OpenStudio::Measure::OSArgument::makeBoolArgument('cooling_towers_costing', true)
    cooling_towers_costing.setDisplayName('Enable Cooling Tower Costing')
    cooling_towers_costing.setDefaultValue(true)
    args << cooling_towers_costing

    shw_costing = OpenStudio::Measure::OSArgument::makeBoolArgument('shw_costing', true)
    shw_costing.setDisplayName('Enable Service Hot Water Costing')
    shw_costing.setDefaultValue(true)
    args << shw_costing

    ventilation_costing = OpenStudio::Measure::OSArgument::makeBoolArgument('ventilation_costing', true)
    ventilation_costing.setDisplayName('Enable Ventilation Costing')
    ventilation_costing.setDefaultValue(true)
    args << ventilation_costing

    zone_system_costing = OpenStudio::Measure::OSArgument::makeBoolArgument('zone_system_costing', true)
    zone_system_costing.setDisplayName('Enable Zone System Costing')
    zone_system_costing.setDefaultValue(true)
    args << zone_system_costing

    baseline_cost_equipment_total_cost_per_m_sq = OpenStudio::Measure::OSArgument::makeDoubleArgument('baseline_cost_equipment_total_cost_per_m_sq', true)
    baseline_cost_equipment_total_cost_per_m_sq.setDisplayName('Baseline Capital Costs ($/m2). This is used to calculate simple payback. -1 skips')
    baseline_cost_equipment_total_cost_per_m_sq.setDefaultValue(-1.0)
    args << baseline_cost_equipment_total_cost_per_m_sq

    baseline_energy_eui_total_gj_per_m_sq = OpenStudio::Measure::OSArgument::makeDoubleArgument('baseline_energy_eui_total_gj_per_m_sq', true)
    baseline_energy_eui_total_gj_per_m_sq.setDisplayName('Baseline Energy (GJ/m2).  This is used to calculate baseline percent energy change. -1 skips')
    baseline_energy_eui_total_gj_per_m_sq.setDefaultValue(-1.0)
    args << baseline_energy_eui_total_gj_per_m_sq

    baseline_cost_utility_neb_total_cost_per_m_sq = OpenStudio::Measure::OSArgument::makeDoubleArgument('baseline_cost_utility_neb_total_cost_per_m_sq', true)
    baseline_cost_utility_neb_total_cost_per_m_sq.setDisplayName('Baseline Energy Costs ($/m2).  This is used to calculate simple payback. -1 skips')
    baseline_cost_utility_neb_total_cost_per_m_sq.setDefaultValue(-1.0)
    args << baseline_cost_utility_neb_total_cost_per_m_sq

    npv_start_year = OpenStudio::Measure::OSArgument::makeDoubleArgument('npv_start_year', true)
    npv_start_year.setDisplayName('Net Present Value: start year')
    npv_start_year.setDefaultValue(2022)
    args << npv_start_year

    npv_end_year = OpenStudio::Measure::OSArgument::makeDoubleArgument('npv_end_year', true)
    npv_end_year.setDisplayName('Net Present Value: end year')
    npv_end_year.setDefaultValue(2041)
    args << npv_end_year

    npv_discount_rate = OpenStudio::Measure::OSArgument::makeDoubleArgument('npv_discount_rate', true)
    npv_discount_rate.setDisplayName('Net Present Value: discount rate')
    npv_discount_rate.setDefaultValue(0.03)
    args << npv_discount_rate

    return args
  end

  # end the arguments method

  def store_data(runner, value, name, units)
    name = name.to_s.downcase.tr(" ", "_")
	if value.kind_of? Numeric 
      runner.registerValue(name.to_s, value)
	else
	  runner.registerValue(name.to_s, value.to_s)
    end
    #runner.registerError(" Error is RegisterValue for these arguments #{name}, value:#{value}, units:#{units} in runner #{runner}")
  end

  def look_up_csv_data(csv_fname, search_criteria)
    options = {:headers => :first_row,
               :converters => [:numeric]}
    unless File.exist?(csv_fname)
      raise ("File: [#{csv_fname}] Does not exist")
    end
    # we'll save the matches here
    matches = nil
    # save a copy of the headers
    headers = nil
    CSV.open(csv_fname, "r", options) do |csv|

      # Since CSV includes Enumerable we can use 'find_all'
      # which will return all the elements of the Enumerble for
      # which the block returns true

      matches = csv.find_all do |row|
        match = true
        search_criteria.keys.each do |key|
          match = match && (row[key].strip == search_criteria[key].strip)
        end
        match
      end
      headers = csv.headers
    end
    #puts matches
    raise("More than one match") if matches.size > 1
    puts "Zero matches found for [#{search_criteria}]" if matches.size == 0
    #return matches[0]
    return matches[0]
  end

  def runHourlyReports(runner, user_arguments)
    #super(runner, user_arguments)
    @json_data = {}
    @json_data["hourly_data"] = []
    @kvdata = {}

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(@model), user_arguments)
      return false
    end

    # get the last model and sql file
    #puts "#{Time.new} Loading model"
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get

    #puts "#{Time.new} Loading sql file"
    sql = runner.lastEnergyPlusSqlFile
    if sql.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sql = sql.get
    model.setSqlFile(sql)

    time_of_peaks = sql.execAndReturnVectorOfString("SELECT Value FROM tabulardatawithstrings WHERE ReportName='DemandEndUseComponentsSummary'" +
                                                        " AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='Time of Peak'").get

    meters = sql.execAndReturnVectorOfString("SELECT ColumnName FROM tabulardatawithstrings WHERE ReportName='DemandEndUseComponentsSummary'" +
                                                 " AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='Time of Peak'").get

    units = sql.execAndReturnVectorOfString("SELECT Units FROM tabulardatawithstrings WHERE ReportName='DemandEndUseComponentsSummary'" +
                                                " AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='Time of Peak'").get

    values = sql.execAndReturnVectorOfString("SELECT Value FROM tabulardatawithstrings WHERE ReportName='DemandEndUseComponentsSummary'" +
                                                 " AND ReportForString='Entire Facility' AND TableName='End Uses' AND RowName='Total End Uses'").get

    if time_of_peaks.empty? || meters.empty? || units.empty? || values.empty?
      runner.registerError("Could not get peak dates from sql file.")
    end
    annual_peaks = []
    meters.each_with_index do |meter, i|
      peak = {'meter' => meter, 'day_of_peak' => time_of_peaks[i], 'value' => values[i], 'unit' => units[i]}
      annual_peaks << peak
    end


    # Get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sql.availableEnvPeriods.each do |env_pd|
      env_type = sql.environmentType(env_pd)
      if env_type.is_initialized
        if env_type.get == OpenStudio::EnvironmentType.new("WeatherRunPeriod")
          ann_env_pd = env_pd
        end
      end
    end

    if ann_env_pd.nil?
      runner.registerAsNotApplicable("Can't find a weather runperiod, make sure you ran an annual simulation, not just the design days.")
      return true
    end

    # Get the timestep as fraction of an hour
    ts_frac = 1.0 / 4.0 # E+ default
    sim_ctrl = model.getSimulationControl
    step = sim_ctrl.timestep
    if step.is_initialized
      step = step.get
      steps_per_hr = step.numberOfTimestepsPerHour
      ts_frac = 1.0 / steps_per_hr.to_f
    end
    #runner.registerInfo("The timestep is #{ts_frac} of an hour.")

    # Determine the number of hours simulated
    hrs_sim = sql.hoursSimulated
    if hrs_sim.is_initialized
      hrs_sim = hrs_sim.get
    else
      runner.registerWarning("Could not determine number of hours simulated, assuming 8760")
      hrs_sim = 8760
    end

    # Save simuated hours to hash

    @json_data['hourly_data'] << {'simulated_hours' => hrs_sim}


    # Get all valid timeseries
    #puts "#{Time.new} Getting all valid timeseries"
    kvs = sql.execAndReturnVectorOfString('SELECT KeyValue FROM ReportDataDictionary')
    var_names = sql.execAndReturnVectorOfString('SELECT Name FROM ReportDataDictionary')
    freqs = sql.execAndReturnVectorOfString('SELECT ReportingFrequency FROM ReportDataDictionary')
    unitss = sql.execAndReturnVectorOfString('SELECT Units FROM ReportDataDictionary')
    variable_types = sql.execAndReturnVectorOfString('SELECT Type FROM ReportDataDictionary')
    index_groups = sql.execAndReturnVectorOfString('SELECT IndexGroup FROM ReportDataDictionary')
    rt_data_dictionarys = sql.execAndReturnVectorOfString('SELECT ReportDataDictionaryIndex FROM ReportDataDictionary')
    is_meters = sql.execAndReturnVectorOfString('SELECT IsMeter FROM ReportDataDictionary')
    if kvs.empty? || var_names.empty? || freqs.empty? || unitss.empty?
      runner.registerError("Could not get timeseries data from sql file.")
    end

    kvs = kvs.get
    var_names = var_names.get
    freqs = freqs.get
    unitss = unitss.get
    variable_types = variable_types.get
    index_groups = index_groups.get
    rt_data_dictionarys = rt_data_dictionarys.get
    is_meters = is_meters.get
    runner.registerInitialCondition("Found #{kvs.size} timeseries outputs.")
    #Create container for all data records.
    data_record_array = []
    #iterate through each data record.
    kvs.each_with_index do |kv, i|
      freq = freqs[i]
      var_name = var_names[i]
      kv = kvs[i]
      units = unitss[i]
      variable_type = variable_types[i]
      index_group = index_groups[i]
      rt_data_dictionary = rt_data_dictionarys[i]
      is_meter = is_meters[i]

      # For now, only collect hourly and subhourly data.
      next unless ['HVAC System Timestep', 'Zone Timestep', 'Timestep', 'Hourly'].include?(freq)
      # Series frequency in hrs
      ts_hr = nil
      case freq
      when 'HVAC System Timestep'
        ts_hr = (1.0 / 60.0) # Convert from non-uniform to minutely
      when 'Timestep', 'Zone Timestep'
        ts_hr = ts_frac
      when 'Hourly'
        ts_hr = 1.0
      when 'Daily'
        ts_hr = 24.0
      when 'Monthly'
        ts_hr = (24.0 * 30) # Even months
      when 'Runperiod'
        ts_hr = (24.0 * 365) # Assume whole year run
      end

      # Get the values
      ts = sql.timeSeries(ann_env_pd, freq, var_name, kv)
      if ts.empty?
        runner.registerWarning("No data found for #{freq} #{var_name} #{kv}.")
        next
      else
        runner.registerInfo("Found data for #{freq} #{var_name} #{kv}.")
        ts = ts.get
      end
      #Get date and time for values
      date_times = ts.dateTimes
      #Store simulation year.
      @simulation_year = Time.parse(date_times[0].to_s).year
      #store data values
      #@runner.registerInfo("Total Time = #{(Time.new - @start_time).round}sec.")


      vals = ts.values

      # If this series is a mass or volume flow rate, determine
      # the type of loop the component is on (air or water)
      # for later unit conversion.
      on_plant_loop = false
      on_air_loop = false
      if ['m3/s', 'kg/s'].include?(units.downcase)
        model.getPlantLoops.each do |plant_loop|
          if plant_loop.name.get.to_s.upcase == kv.upcase
            on_plant_loop = true
            break
          end
          plant_loop.components.each do |comp|
            if comp.name.get.to_s.upcase == kv.upcase
              on_plant_loop = true
              break
            end
          end
        end
        # If not on plant loop, check air loops
        unless on_plant_loop
          model.getAirLoopHVACs.each do |air_loop|
            if air_loop.name.get.to_s.upcase == kv.upcase
              on_air_loop = true
              break
            end
            air_loop.components.each do |comp|
              if comp.name.get.to_s.upcase == kv.upcase
                on_air_loop = true
                break
              end
            end
          end
        end
      end

      # For HVAC System Timestep data, convert from E+
      # non-uniform timesteps to minutely with missing
      # entries linearly interpolated.
      if freq == 'HVAC System Timestep'
        # Loop through each of the non-uniformly
        # reported timesteps.
        start_min = 0
        first_timestep = date_times[0]
        minutely_vals = []
        for i in 1..(date_times.size - 1)
          reported_time = date_times[i]
          # Figure out how many minutes to the
          # it's been since the previous reported timestep.
          min_until_prev_ts = 0
          for min in start_min..525600
            minute_ts = OpenStudio::Time.new(0, 0, min, 0) # d, hr, min, s
            minute_time = first_timestep + minute_ts
            if minute_time == reported_time
              break
            elsif minute_time < reported_time
              min_until_prev_ts += 1
            else
              # minute_time > reported_time
              # This scenario shouldn't happen
              runner.registerError("Somehow a timestep was skipped when converting from HVAC System Timestep to uniform minutely.  Results will not look correct.")
            end
          end

          # Get this value
          this_val = vals[i]

          # Get the previous value
          prev_val = vals[i - 1]

          # Linearly interpolate the values between
          val_per_min = (this_val - prev_val) / min_until_prev_ts

          # At each minute, report a value if one
          # exists and a blank if none exists.
          for min in start_min..525600
            minute_ts = OpenStudio::Time.new(0, 0, min, 0) # d, hr, min, s
            minute_time = first_timestep + minute_ts
            if minute_time == reported_time
              # There was a value for this minute,
              # report out this value and skip
              # to the next reported timestep
              start_min = min + 1
              minutely_vals << this_val
              #puts "#{minute_time} = #{this_val}"
              break
            elsif minute_time < reported_time
              # There wasn't a value for this minute,
              # report out a blank entry
              minutely_vals << prev_val + (val_per_min * (min - start_min + 1))
              #puts "#{minute_time} = #{prev_val + (val_per_min * (min - start_min + 1))} interp, mins = #{min - start_min + 1} val_per_min = #{val_per_min}, min_until_prev_ts = #{min_until_prev_ts}"
            else
              # minute_time > reported_time
              # This scenario shouldn't happen
              runner.registerError("Somehow a timestep was skipped when converting from HVAC System Timestep to uniform minutely.  Results will not look correct.")
            end
          end

        end

        #puts "---- #{Time.new} Done nonuniform timestep interpolation"

        # Replace the original values
        # with the new minutely values
        #puts "minutely has #{minutely_vals.size} entries"
        vals = minutely_vals
      end

      # Convert the values to a normal array
      #puts "---- #{Time.new} Starting conversion to normal array"
      data = []
      if freq == 'HVAC System Timestep'
        # Already normal array
        data = vals
      else
        for i in 0..(vals.size - 1)
          #next if vals[i].nil?
          data[i] = vals[i].signif(5)
        end
      end

      #Don't Create Hourly data if Hourly data already exists.
      #create Storage Array
      hourly_data = []
      if sql.timeSeries(ann_env_pd, 'Hourly', var_name, kv).empty?
        #Averaged versus Summed

        #Determine ts per hour
        timesteps_per_hour = 1 / ts_hr
        #set Counter
        counter = 0
        # Set last hour uding the number of simulaiton hours minus 1. For a full year
        # this is 8760-1. So the iterator will go from 0 to 8759.
        last_hour = hrs_sim.to_i - 1
        (0..last_hour).each do |hour|
          #Start and stop 'chunk' that makes up an hour.
          start = counter
          stop = counter + timesteps_per_hour.to_i - 1
          result = 0
          #iterate through the hour.
          (start..stop).each do |value|
            #Either sum or average over the hour based on the type.
            unless data[value].nil?
              if variable_type == "Sum"
                result += data[value]
              elsif variable_type == "Avg"
                result += data[value] / timesteps_per_hour
              end
            end
          end
          #Increament the counter to start the next hour 'chunk'
          counter = stop + 1
          #store the data into an array.
          hourly_data << result
        end
      else
        vals = sql.timeSeries(ann_env_pd, 'Hourly', var_name, kv).get.values
        for i in 0..(vals.size - 1)
          #next if vals[i].nil?
          hourly_data << vals[i].signif(5)
        end
      end

      #Get Annual PLR based not on Capacity, but on Min and Max Not total Capacity!
      min_max_ratio = {}
      max = hourly_data.max
      (1..10).each {|bin| min_max_ratio["#{(bin - 1) * 10}-#{(bin * 10)}%"] = 0}
      #iterate through each hour and bin the information based on 10th percentages.
      hourly_data.each do |data|
        #Get rid of any
        if max.to_f != 0.0
          percentage = (100.0 * data.to_f / max.to_f).round
        else
          percentage = 0
        end
        case percentage
        when 0..10 then
          min_max_ratio['0-10%'] += 1
        when 11..20 then
          min_max_ratio['10-20%'] += 1
        when 21..30 then
          min_max_ratio['20-30%'] += 1
        when 31..40 then
          min_max_ratio['30-40%'] += 1
        when 41..50 then
          min_max_ratio['40-50%'] += 1
        when 51..60 then
          min_max_ratio['50-60%'] += 1
        when 61..70 then
          min_max_ratio['60-70%'] += 1
        when 71..80 then
          min_max_ratio['70-80%'] += 1
        when 81..90 then
          min_max_ratio['80-90%'] += 1
        when 91..100 then
          min_max_ratio['90-100%'] += 1
        end
      end


      #Get Monthly 24 day bins
      #Create hourly time array.
      #start and end dates of simulation.
      date = DateTime.new(Time.parse(date_times.first.to_s).year, Time.parse(date_times.first.to_s).month, Time.parse(date_times.first.to_s).day)
      end_date = DateTime.new(Time.parse(date_times.last.to_s).year, Time.parse(date_times.last.to_s).month, Time.parse(date_times.last.to_s).day)
      counter = 0
      monthly_24_hour_averages = []
      monthly_24_hour_weekend_weekday_averages = []
      month_array = []
      while (date < end_date)
        month_array[date.month] = {} if month_array[date.month].nil?
        month_array[date.month][date.wday] = {} if month_array[date.month][date.wday].nil?
        month_array[date.month]['weekday'] = {} if month_array[date.month]['weekday'].nil?
        month_array[date.month]['weekend'] = {} if month_array[date.month]['weekend'].nil?
        month_array[date.month][date.wday][date.hour] = [] if month_array[date.month][date.wday][date.hour].nil?
        #create also weekday and weekend bins.
        month_array[date.month]['weekday'][date.hour] = [] if month_array[date.month]['weekday'][date.hour].nil?
        month_array[date.month]['weekend'][date.hour] = [] if month_array[date.month]['weekend'][date.hour].nil?
        #push all hours values over the month for hour for the day type to an array.
        #So this array will contain all the value for Monday at 1pm for example.
        # Keeping to 6 sig digits.
        month_array[date.month][date.wday][date.hour] << hourly_data[counter].to_f.signif(6)

        #Set weekday and end bins.
        if date.wday == 0 or date.wday == 6
          month_array[date.month]['weekend'][date.hour] << hourly_data[counter].to_f.signif(6)
        elsif (1..5).include?(date.wday)
          month_array[date.month]['weekday'][date.hour] << hourly_data[counter].to_f.signif(6)
        end
        #puts "#{date.strftime('%^b')},#{date.strftime('%^a')},#{date.hour}"
        date += Rational(3600, 86400); counter += 1
      end


      #keep month numbers from 1 to 12 to avoid confusion.
      (1..12).each_with_index do |imonth|
        #do weekdays
        (0..6).each do |day|
          day_hash = {"month" => imonth, 'wday' => day, 'mean_profile' => [], 'std_dev_profile' => []}
          #Stick to 24 clock standard 0-23 hours.
          (0..23).each do |hour|
            #This will deal with partial year simulations if needed.
            unless month_array[imonth].nil? or month_array[imonth][day].nil? or month_array[imonth][day][hour].nil?
              day_hash["mean_profile"] << month_array[imonth][day][hour].mean
              day_hash["std_dev_profile"] << month_array[imonth][day][hour].standard_deviation
            end
          end
          monthly_24_hour_averages << day_hash
        end
      end

      #keep month numbers from 1 to 12 to avoid confusion.
      (1..12).each_with_index do |imonth|
        #do weekdays
        ['weekday', 'weekend'].each do |day|
          day_hash = {"month" => imonth, 'wday' => day, 'mean_profile' => [], 'std_dev_profile' => []}
          #Stick to 24 clock standard 0-23 hours.
          (0..23).each do |hour|
            #This will deal with partial year simulations if needed.
            unless month_array[imonth].nil? or month_array[imonth][day].nil? or month_array[imonth][day][hour].nil?
              day_hash["mean_profile"] << month_array[imonth][day][hour].mean
              day_hash["std_dev_profile"] << month_array[imonth][day][hour].standard_deviation
            end
          end
          monthly_24_hour_weekend_weekday_averages << day_hash
        end
      end


      raise("Hourly data is #{hourly_data.size} does not match the hours simulated which is #{hrs_sim} at a freq of #{freq}") if hourly_data.size != hrs_sim
      #KV name may be blank...add "site" if blank and use that.
      kv = 'site' if kv == ''

      #Store all the data in a lovely hash.
      record = {
          'rt_data_dictionary' => rt_data_dictionary,
          'var_name' => var_name,
          'kv' => kv,
          'units' => units,
          'variable_type' => variable_type,
          'index_group' => index_group,
          'is_meter' => is_meter,
          'reporting_frequency' => freq,
          'hours_simulated' => hrs_sim,
          'total_num_data_points' => hrs_sim / ts_hr,
          'total_num_actual_data_points' => data.size,
          'total_num_actual_hourly_data_points' => hourly_data.size,
          'data_points_per_hour' => (1.0 / ts_hr.to_f),
          'start_date_time' => Time.parse(date_times.first.to_s),
          'end_date_time' => Time.parse(date_times.last.to_s),
          'min_hourly_value' => hourly_data.min,
          'max_hourly_value' => hourly_data.max,
          'min_max_hourly_breakdown' => min_max_ratio,
          'monthly_7_day_24_hour_averages' => monthly_24_hour_averages,
          'monthly_24_hour_weekend_weekday_averages' => monthly_24_hour_weekend_weekday_averages,
          'annual_peaks' => annual_peaks,
          'data_hvac_system_filtered' => data,
          'data_hourly_adjusted' => hourly_data
      }
      data_record_array << record

    end #End Data record loops.
    write_to_monthly_average_week_csv(data_record_array)
    write_to_8760_hour_csv(data_record_array)
    write_to_8760_hour_csv_all(data_record_array)
    monthly_24_hour_weekend_weekday_averages_csv(data_record_array)
    enduse_total_monthly_24_hour_weekend_weekday_averages_csv(data_record_array)
    return true
  end

  # end run

  def write_to_8760_hour_csv(data_record_array)
    selection = [
        'Heating Coil Air Heating Rate',
        'Cooling Coil Total Cooling Rate',
        'Boiler Heating Rate',
        'Chiller Condenser Heat Transfer Rate',
        'Water Heater Heating Rate',
        'Facility Total Electric Demand Power',
        'Gas:Facility',
        'Water Heater Gas Rate']
    selection = data_record_array.select {|record| selection.include?(record["var_name"])}
    CSV.open('8760_hourly_data.csv', 'w') do |writer|
      row = []
      row << 'var_name' << 'key_variable' << 'units' << 'hours_simulated'
      row += (0..8760).to_a
      writer << row
      selection.each do |r|
        row = []
        row << r['var_name'] << r['kv'] << r['units'] << r['hours_simulated']
        row += r['data_hourly_adjusted']
        writer << row
      end
    end
  end

  def write_to_8760_hour_csv_all(data_record_array)
    selection = [
        "Total Internal Radiant Heating Rate",
        "Total Internal Convective Heating Rate",
        "Zone Air Heat Balance Outdoor Air Transfer Rate",
        "Zone Total Internal Latent Gain Rate",
        "Zone Total Internal Total Heating Rate",
        "Zone Air System Sensible Heating Rate",
        "Zone Air System Sensible Cooling Rate"
    ]
    selection = data_record_array.select {|record| selection.include?(record["var_name"])}
    CSV.open('8760_hour_custom.csv', 'w') do |writer|
      row = []
      row << 'var_name' << 'key_variable' << 'units' << 'hours_simulated'
      row += (1..8760).to_a
      writer << row

      day = []
      day << 'Day of week:' << '' << '' << ''

      month = []
      month << 'Month:' << '' << '' << ''

      hour = []
      hour << 'hour:' << '' << '' << ''

      week = []
      week << 'Week #:' << '' << '' << ''

      full_date = []
      full_date << 'Full Date:' << '' << '' << ''
      return false if selection[0].nil?
      puts selection[0]['start_date_time']
      start_date_time = selection[0]['start_date_time']
      end_date_time = selection[0]['end_date_time']

      date = DateTime.new(start_date_time.year, start_date_time.month, start_date_time.day)
      end_date = DateTime.new(end_date_time.year, end_date_time.month, end_date_time.day)
      # create the header (time and date information)
      while (date < end_date)
        #puts "#{date.strftime('%^b')},#{date.strftime('%^d')},#{date.strftime('%^a')},#{date.hour}"
        day << "#{date.strftime('%^w')}" #Day of the week (Sunday is 0, 0 to 6).
        month << "#{date.strftime('%^b')}" #The abbreviated month name (Jan).
        week << "#{date.strftime('%^U')}" #Week number of the current year, starting with the first Sunday as the first day of the first week (00 to 53).
        hour << "#{date.strftime('%^H')}" #Hour of the day, 24-hour clock (00 to 23).
        full_date << "#{date.strftime('%^Y-%^m-%^d %^H:%^M:%^S')}"
        date += Rational(3600, 86400)

      end
      # write the header information
      writer << full_date
      writer << month
      writer << week
      writer << day
      writer << hour

      #write the hourly data to the csv file.
      selection.each do |r|
        row = []
        row << r['var_name'] << r['kv'] << r['units'] << r['hours_simulated']
        row += r['data_hourly_adjusted']
        writer << row
      end
    end
  end

  def write_to_monthly_average_week_csv(data_record_array)
    selection = [
        'Heating Coil Air Heating Rate',
        'Cooling Coil Total Cooling Rate',
        'Boiler Heating Rate',
        'Chiller Condenser Heat Transfer Rate',
        'Water Heater Heating Rate',
        'Facility Total Electric Demand Power',
        'Gas:Facility',
        'Water Heater Gas Rate']
    selection = data_record_array.select {|record| selection.include?(record["var_name"])}
    CSV.open('monthly_7_day_24_hour_averages.csv', 'w') do |writer|
      row = []
      row << 'var_name' << 'key_variable' << 'units' << 'month' << 'day_of_week' << "Data Type"
      row += (0..23).to_a
      writer << row
      selection.each do |r|
        r['monthly_7_day_24_hour_averages'].each do |m|
          #Write average 24 hour profile for day of the week m['day'] for each month.
          row = []
          row << r['var_name'] << r['kv'] << r['units'] << m['month'] << m['wday'] << "MEAN"
          row += m['mean_profile']
          writer << row
          row = []
          row << r['var_name'] << r['kv'] << r['units'] << m['month'] << m['wday'] << "STD_DEV"
          row += m['std_dev_profile']
          writer << row
        end
      end
    end
  end

  def monthly_24_hour_weekend_weekday_averages_csv(data_record_array)
    selection = [
        'Heating Coil Air Heating Rate',
        'Cooling Coil Total Cooling Rate',
        'Boiler Heating Rate',
        'Chiller Condenser Heat Transfer Rate',
        'Water Heater Heating Rate',
        'Facility Total Electric Demand Power',
        'Gas:Facility',
        'Water Heater Gas Rate']
    selection = data_record_array.select {|record| selection.include?(record["var_name"])}
    CSV.open('monthly_24_hour_weekend_weekday_averages.csv', 'w') do |writer|
      row = []
      row << 'var_name' << 'key_variable' << 'units' << 'month' << 'day_of_week' << "Data Type"
      row += (0..23).to_a
      writer << row
      selection.each do |r|
        r['monthly_24_hour_weekend_weekday_averages'].each do |m|
          #Write average 24 hour profile for day of the week m['day'] for each month.
          row = []
          row << r['var_name'] << r['kv'] << r['units'] << m['month'] << m['wday'] << "MEAN"
          row += m['mean_profile']
          writer << row
          row = []
          row << r['var_name'] << r['kv'] << r['units'] << m['month'] << m['wday'] << "STD_DEV"
          row += m['std_dev_profile']
          writer << row
        end
      end
    end
  end

  def enduse_total_monthly_24_hour_weekend_weekday_averages_csv(data_record_array)
    sum_key = "monthly_24_hour_weekend_weekday_averages"
    total_data_record_array = []
    end_uses_lookup = {
        "SHW" => ['Water Heater Heating Rate'],
        "Space Heating" => ['Heating Coil Air Heating Rate', 'Boiler Heating Rate'],
        "Total Heating" => ['Heating Coil Air Heating Rate', 'Boiler Heating Rate', 'Water Heater Heating Rate'],
        "Space Cooling" => ['Cooling Coil Total Cooling Rate'],
        "Total Electricity" => ['Facility Total Electric Demand Power'],
        "Gas" => ['Gas:Facility'],
        "Total Site Energy" => ['Facility Total Electric Demand Power', 'Gas:Facility']
    }

    #File.open("end_uses_lookup.json", 'w') {|f| f.write(JSON.pretty_generate(end_uses_lookup)) }
    #File.open("data_record_array.json", 'w') {|f| f.write(JSON.pretty_generate(data_record_array)) }
    end_uses_lookup.keys.each {|key|
      #puts "#{end_uses_lookup[key]}"
      data_groups = []
      data_record_array.each {|item|
        #puts "\t#{item["var_name"]}"
        # only consider values that have an hourly timestamp to avoid duplicate variables with different
        # time stamp values
        if end_uses_lookup[key].include?(item["var_name"]) && item["reporting_frequency"] == "Hourly"
          puts "#{item['var_name']}: Units: #{item['units']}"
          # convert Joules to Watts (Specific to Gas:Facility)
          if item['var_name'] == "Gas:Facility" && item['units'] == "J" && item["reporting_frequency"] == "Hourly"
            # perform deep copy to avoid changes in the original variable
            new_item = Marshal.load(Marshal.dump(item))
            new_item['units'] = "W"
            new_item[sum_key].each {|data_month|
              data_month['mean_profile'].map! {|i| i / 3600}
            }
            puts "^^#{new_item['var_name']}: Units: #{new_item['units']}^^"
            data_groups << Marshal.load(Marshal.dump(new_item))
            next
          end

          data_groups << Marshal.load(Marshal.dump(item))
        end
      }
      File.open("#{key}.json", 'w') {|f| f.write(JSON.pretty_generate(data_groups))}
      if (data_groups[0].nil?)
        puts "end_uses_lookup[key] of #{end_uses_lookup[key]} was not found"
        next
      end
      # perform deep copy to avoid changes in the original variable
      out = Marshal.load(Marshal.dump(data_groups[0]))


      out["var_name"] = key
      out["kv"] = "TOTAL"
      data_groups.each_with_index {|data_set, data_groups_index|
        #puts "#{data_set['kv']}\ndata_groups_index: #{data_groups_index}"
        next if data_groups_index == 0
        data_set[sum_key].each_with_index {|data_month, data_month_index|
          #puts "\tdata_month_index: #{data_month_index}"
          out_mean_profile = out[sum_key][data_month_index]["mean_profile"]
          data_month_mean_profile = Marshal.load(Marshal.dump(data_month['mean_profile']))
          #add two arrays of mean_profile
          # the code concats the two arrays and adds it together
          out[sum_key][data_month_index]["mean_profile"] = [out_mean_profile, data_month_mean_profile].transpose.map {|x| x.reduce(:+)}
          #puts "\t\t#{out[sum_key][data_month_index]["mean_profile"]}"
        }
        # sum all the hourly values to recalculate the bin distribution
        out_data_hourly_adjusted = out["data_hourly_adjusted"]
        data_set_data_hourly_adjusted = Marshal.load(Marshal.dump(data_set['data_hourly_adjusted']))
        #add two arrays of mean_profile
        out["data_hourly_adjusted"] = [out_data_hourly_adjusted, data_set_data_hourly_adjusted].transpose.map {|x| x.reduce(:+)}
      }

      #recalculate bin distributions
      #Get Annual PLR based not on Capacity, but on Min and Max Not total Capacity!
      min_max_ratio = {}
      max = out["data_hourly_adjusted"].max
      (1..10).each {|bin| min_max_ratio["#{(bin - 1) * 10}-#{(bin * 10)}%"] = 0}
      #iterate through each hour and bin the information based on 10th percentages.
      out["data_hourly_adjusted"].each do |data|
        #Get rid of any
        if max.to_f != 0.0
          percentage = (100.0 * data.to_f / max.to_f).round
        else
          percentage = 0
        end
        case percentage
        when 0..10 then
          min_max_ratio['0-10%'] += 1
        when 11..20 then
          min_max_ratio['10-20%'] += 1
        when 21..30 then
          min_max_ratio['20-30%'] += 1
        when 31..40 then
          min_max_ratio['30-40%'] += 1
        when 41..50 then
          min_max_ratio['40-50%'] += 1
        when 51..60 then
          min_max_ratio['50-60%'] += 1
        when 61..70 then
          min_max_ratio['60-70%'] += 1
        when 71..80 then
          min_max_ratio['70-80%'] += 1
        when 81..90 then
          min_max_ratio['80-90%'] += 1
        when 91..100 then
          min_max_ratio['90-100%'] += 1
        end
      end

      out['min_max_hourly_breakdown'] = min_max_ratio

      total_data_record_array << out
      #File.open("#{key.gsub(":","_")}-out.json", 'w') {|f| f.write(JSON.pretty_generate(out)) }
    }
    # store min max information in a separate hash
    monthly_data = {}
    total_data_record_array.each_with_index {|data_set, data_groups_index|
      data_set[sum_key].each_with_index {|data_month, data_month_index|
        month = data_month['month']
        key = data_set['var_name']
        #puts month
        monthly_data[key] ||= {}
        monthly_data[key][month] ||= {}
        monthly_data[key][month]['total'] ||= 0
        #puts "total before: #{monthly_data[key][month]['total']}"
        monthly_data[key][month]['total'] += data_set[sum_key][data_month_index]["mean_profile"].inject(0, :+)
        #puts "total aftr: #{monthly_data[key][month]['total']}\n"

        monthly_data[key][month]['maximum'] ||= -(2 ** (0.size * 8 - 2))
        monthly_data[key][month]['maximum_hour'] ||= -1

        #monthly_data[key][month]['minimum'] ||= (2**(0.size * 8 -2) -1)
        #monthly_data[key][month]['minimum_hour'] ||= -1

        if (monthly_data[key][month]['maximum'] < data_set[sum_key][data_month_index]["mean_profile"].max)
          monthly_data[key][month]['maximum'] = data_set[sum_key][data_month_index]["mean_profile"].max
          monthly_data[key][month]['maximum_hour'] = data_set[sum_key][data_month_index]["mean_profile"].each_with_index.max[1]
        end

        #if (monthly_data[key][month]['minimum'] > data_set[sum_key][data_month_index]["mean_profile"].min)
        #  monthly_data[key][month]['minimum'] = data_set[sum_key][data_month_index]["mean_profile"].min
        #  monthly_data[key][month]['minimum_hour'] = data_set[sum_key][data_month_index]["mean_profile"].each_with_index.min[1]
        #end

        #puts "\t\t#{data_set[sum_key][data_month_index]["mean_profile"]}"
        #puts "#{key}\n#{JSON.pretty_generate(monthly_data)}\n" unless key == "SHW"
      }
    }

    #puts JSON.pretty_generate(monthly_data)
    CSV.open('enduse_total_24_hour_weekend_weekday_averages.csv', 'w') do |writer|
      row = []
      row << 'var_name' << 'key_variable' << 'units' << 'month' << 'day_of_week' << "Data Type"
      row += (0..23).to_a
      writer << row
      #write the total end uses data to the csv file
      total_data_record_array.each do |r|
        r['monthly_24_hour_weekend_weekday_averages'].each do |m|
          #Write average 24 hour profile for day of the week m['day'] for each month.
          row = []
          row << r['var_name'] << r['kv'] << r['units'] << m['month'] << m['wday'] << "MEAN"
          row += m['mean_profile']
          writer << row
        end
      end
      row = []
      writer << row
      #write the min and max information to the csv file
      row << "End Use Variable" << "Month" << "Total" << "Maximum" << "Maximum's Hour"
      writer << row
      monthly_data.keys.each {|end_use|
        (1..12).each {|month|
          row = []
          row << end_use << month << monthly_data[end_use][month]["total"] << monthly_data[end_use][month]["maximum"] << monthly_data[end_use][month]["maximum_hour"]
          writer << row
        }
      }
      row = []
      writer << row
      #write the bin distribution of the end uses to the csv file
      row << "Bin Distribution" << "Key Value"
      total_data_record_array[0]['min_max_hourly_breakdown'].keys.each {|key| row << key}
      writer << row
      total_data_record_array.each {|r|
        row = []
        row << r['var_name'] << r['kv']
        r['min_max_hourly_breakdown'].keys.each {|key| row << r['min_max_hourly_breakdown'][key]}
        writer << row
      }
      row = []
      writer << row
      #write the bin distribution of all the unlocked variables to the csv file
      data_record_array.each {|r|
        row = []
        row << r['var_name'] << r['kv']
        r['min_max_hourly_breakdown'].keys.each {|key| row << r['min_max_hourly_breakdown'][key]}
        writer << row
      }
    end
  end

  def check_boolean_value (value, varname)
    return true if value =~ (/^(true|t|yes|y|1)$/i)
    return false if value.empty? || value =~ (/^(false|f|no|n|0)$/i)

    raise ArgumentError.new "invalid value for #{varname}: #{value}"
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)

    super(runner, user_arguments)
    generate_hourly_report = runner.getStringArgumentValue('generate_hourly_report', user_arguments)
    generate_hourly_report = check_boolean_value(generate_hourly_report, "generate_hourly_report")
    output_diet = runner.getBoolArgumentValue('output_diet', user_arguments)
    envelope_costing = runner.getBoolArgumentValue('envelope_costing', user_arguments)
    lighting_costing = runner.getBoolArgumentValue('lighting_costing', user_arguments)
    boilers_costing = runner.getBoolArgumentValue('boilers_costing', user_arguments)
    chillers_costing = runner.getBoolArgumentValue('chillers_costing', user_arguments)
    cooling_towers_costing = runner.getBoolArgumentValue('cooling_towers_costing', user_arguments)
    shw_costing = runner.getBoolArgumentValue('shw_costing', user_arguments)
    ventilation_costing = runner.getBoolArgumentValue('ventilation_costing', user_arguments)
    zone_system_costing = runner.getBoolArgumentValue('zone_system_costing', user_arguments)
    baseline_cost_equipment_total_cost_per_m_sq = runner.getDoubleArgumentValue('baseline_cost_equipment_total_cost_per_m_sq', user_arguments)
    baseline_cost_utility_neb_total_cost_per_m_sq = runner.getDoubleArgumentValue('baseline_cost_utility_neb_total_cost_per_m_sq', user_arguments)
    baseline_energy_eui_total_gj_per_m_sq = runner.getDoubleArgumentValue('baseline_energy_eui_total_gj_per_m_sq', user_arguments)
    npv_start_year = runner.getDoubleArgumentValue('npv_start_year', user_arguments)
    npv_end_year = runner.getDoubleArgumentValue('npv_end_year', user_arguments)
    npv_discount_rate = runner.getDoubleArgumentValue('npv_discount_rate', user_arguments)


    if generate_hourly_report
      runHourlyReports(runner, user_arguments)
    end

    # get sql, model, and web assets
    setup = {}

    # get the last model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    # get the last idf
    workspace = runner.lastEnergyPlusWorkspace
    if workspace.empty?
      runner.registerError('Cannot find last idf file.')
      return false
    end
    workspace = workspace.get

    # get the last sql file
    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)

    # populate hash to pass to measure
    setup[:model] = model
    # setup[:workspace] = workspace
    setup[:sqlFile] = sqlFile

    unless setup
      return false
    end

    model = setup[:model]
    # workspace = setup[:workspace]
    sql_file = setup[:sqlFile]
    web_asset_path = setup[:web_asset_path]
    model.setSqlFile(sql_file)

    # reporting final condition
    runner.registerInitialCondition('Gathering data from EnergyPlus SQL file and OSM model.')


    template_type = nil
    valid_templates = ['BTAPPRE1980','BTAP1980TO2010','NECB2011', 'NECB2015', 'NECB2017', 'NECB2020']
    valid_templates.each do |model_template|
      template_type = model_template if model.getBuilding.standardsTemplate.get.to_s.include?(model_template)
    end
    runner.registerError(" Template in the standardsTemplate #{model.getBuilding.standardsTemplate.get.to_s} is not valid for BTAPReports. It must contain #{valid_templates}") if template_type.nil?

    prototype_creator = Standard.build("#{template_type}")

    # Perform qaqc
    qaqc = prototype_creator.init_qaqc(model)

    # Perform costing
    costing = BTAPCosting.new()
    costing.load_database()

    cost_result, btap_items = costing.cost_audit_all(model: model,
                                         prototype_creator: prototype_creator,
                                         envelope_costing: envelope_costing,
                                         lighting_costing: lighting_costing,
                                         boilers_costing: boilers_costing,
                                         chillers_costing: chillers_costing,
                                         cooling_towers_costing: cooling_towers_costing,
                                         shw_costing: shw_costing,
                                         ventilation_costing: ventilation_costing,
                                         zone_system_costing: zone_system_costing,
                                         template_type: template_type
    )



    qaqc[:costing_information] = cost_result


    #dominant heating fuel type.
    command = "SELECT Value
                  FROM TabularDataWithStrings
                  WHERE ReportName='LEEDsummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Sec1.1A-General Information'
                  AND RowName = 'Principal Heating Source'
                  AND ColumnName='Data'"
    value = model.sqlFile().get.execAndReturnFirstString(command)
    # make sure all the data are availalbe
    if value.empty?
      raise("Could not determine primary heating source from sql file #{@model.building.get.name.get}")
    else
      qaqc[:building][:principal_heating_source] = value.get
      if value.get == "Additional Fuel"
        model.getPlantLoops.sort.each do |iplantloop|
          boilers = iplantloop.components.select {|icomponent| icomponent.to_BoilerHotWater.is_initialized}
          qaqc[:building][:principal_heating_source] = "FuelOilNo2" unless boilers.select {|boiler| boiler.to_BoilerHotWater.get.fuelType.to_s == "FuelOilNo2"}.empty?
        end
      end
    end

    #measure data
    qaqc[:measure_data_table] = self.measures_data_table(runner)

    #BTAPData
    #
    #
    btap_data = BTAPData.new(model: model,
                             runner: runner,
                             cost_result: cost_result,
                             baseline_cost_equipment_total_cost_per_m_sq: baseline_cost_equipment_total_cost_per_m_sq,
                             baseline_cost_utility_neb_total_cost_per_m_sq: baseline_cost_utility_neb_total_cost_per_m_sq,
                             baseline_energy_eui_total_gj_per_m_sq: baseline_energy_eui_total_gj_per_m_sq,
                             qaqc: qaqc,
                             npv_start_year: npv_start_year,
                             npv_end_year: npv_end_year,
                             npv_discount_rate: npv_discount_rate).btap_data



    #Store top level of btap_data into runner. This is used for optimization and OS server output. Stores only non-arrays
    btap_data.sort.to_h.each { |key_name,value| store_data(runner,value,key_name,"?") unless value.class.name == "Array"}
    store_data(runner, JSON.pretty_generate(btap_data['measures_data_table']),"measures_data_table","?")


    # All lines with "qaqc" commented out below
    File.open('cost_results.json', 'w') {|f| f.write(JSON.pretty_generate(cost_result, :allow_nan => true))}
    runner.registerInfo("Wrote File cost_results.json in #{Dir.pwd()} ")
    puts "Wrote File cost_results.json in #{Dir.pwd()} "

    File.open('qaqc.json', 'w') {|f| f.write(JSON.pretty_generate(qaqc, :allow_nan => true))}
    runner.registerInfo("Wrote File qaqc.json in #{Dir.pwd()} ")
    puts "Wrote File qaqc.json in #{Dir.pwd()} "

    File.open('btap_data.json', 'w') {|f| f.write(JSON.pretty_generate(btap_data.sort.to_h, :allow_nan => true))}
    runner.registerInfo("Wrote File btap_data.json in #{Dir.pwd()} ")
    puts "Wrote File btap_data.json in #{Dir.pwd()} "

    File.open('btap_items.json', 'w') {|f| f.write(JSON.pretty_generate(btap_items, :allow_nan => true))}
    runner.registerInfo("Wrote File btap_items.json in #{Dir.pwd()} ")
    puts "Wrote File btap_items.json in #{Dir.pwd()} "

    # closing the sql file
    sql_file.close
    return true
  end # end the run method



  #This measure will return an array of hashes with the varialbles used in the previous measures.
  def measures_data_table(runner)
    # Array to store hash row data.
    measure_variables_table = []
    # Go through each workstep.
    runner.workflow.workflowSteps.each do |step|
      # Check if the ws is a measure.
      if step.to_MeasureStep.is_initialized
        measure_step = step.to_MeasureStep.get
        # Set measure name using either the folder name or the measureStep name if possible.
        measure_name = measure_step.name.is_initialized ? measure_step.name.get : measure_step.measureDirName
        # Check if the 'result' (?) is initialized?
        if measure_step.result.is_initialized
          result = measure_step.result.get
          # Iterate through the result object stepValues to obtain the arg values. I am assuming this is for arg, var. pivot, continous...
          result.stepValues.each do |arg|
            # Store the row /hash for the table.
            units = arg.units.empty? ? nil : arg.units
            value = nil
            case arg.variantType.value
            when 0
              value = arg.valueAsBoolean()
            when 1..2
              value = arg.valueAsDouble()
            when 3
              value = arg.valueAsString()
            end
            measure_variables_table << {'measure_name' => measure_name, 'arg_name' => arg.name, 'value' => value, 'units' => units, 'type' => arg.variantType.value}
          end
        end
      end
    end
    return measure_variables_table
  end
  
  def outputs
    result = OpenStudio::Measure::OSOutputVector.new
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('baseline_capital_cost_difference_per_m_2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('baseline_cost_utility_neb_difference_per_m_2_per_year')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('baseline_energy_percent_change')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('baseline_payback_yrs')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_conditioned_floor_area_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_exterior_area_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_fdwr')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('bldg_name')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_nominal_floor_to_ceiling_height')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_nominal_floor_to_floor_height')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_srr')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('bldg_standards_building_type')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_standards_number_of_above_ground_stories')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_standards_number_of_stories')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('bldg_standards_template')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_surface_to_volume_ratio')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('bldg_volume_m_cu')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_equipment_envelope_total_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_equipment_heating_and_cooling_total_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_equipment_lighting_total_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_equipment_shw_total_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_equipment_total_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_equipment_ventilation_total_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_equipment_renewables_total_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('cost_city')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('cost_province_state')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_utility_neb_electricity_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_utility_neb_natural_gas_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_utility_neb_oil_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cost_utility_neb_total_cost_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_additional_fuel_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_cooling_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_district_cooling_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_district_heating_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_electricity_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_fans_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_heating_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_interior_equipment_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_interior_lighting_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_natural_gas_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_total_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_eui_water_systems_gj_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_peak_electric_w_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('energy_peak_natural_gas_w_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('energy_principal_heating_source')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_ground_floors_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_ground_roofs_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_ground_walls_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_outdoor_doors_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_outdoor_floors_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_outdoor_overhead_doors_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_outdoor_roofs_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_outdoor_walls_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_outdoor_windows_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('envelope_skylights_average_conductance_w_per_m_sq_k')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('location_cdd')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('location_city')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('location_country')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('location_hdd')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('location_latitude')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('location_longitude')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('location_state_province_region')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('location_weather_file')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('location_zone')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('shw_additional_fuel_per_year')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('shw_electricity_per_day')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('shw_electricity_per_day_per_occupant')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('shw_electricity_per_year')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('shw_natural_gas_per_year')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('shw_total_nominal_occupancy')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('shw_water_m_cu_per_day')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('shw_water_m_cu_per_day_per_occupant')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('shw_water_m_cu_per_year')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('simulation_btap_data_version')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('simulation_date')
    result << OpenStudio::Measure::OSOutput.makeStringOutput('simulation_os_standards_revision')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('simulation_os_standards_version')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('npv_total_per_m_sq')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('airloops_total_outdoor_air_mechanical_ventilation_ach_1_per_hr')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('airloops_total_outdoor_air_mechanical_ventilation_flow_per_conditioned_floor_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('airloops_total_outdoor_air_mechanical_ventilation_flow_per_exterior_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('airloops_total_outdoor_air_mechanical_ventilation_m3')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('airloops_total_outdoor_air_natural_ventilation_ach_1_per_hr')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('airloops_total_outdoor_air_natural_ventilation_flow_per_conditioned_floor_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('airloops_total_outdoor_air_natural_ventilation_flow_per_exterior_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('airloops_total_outdoor_air_natural_ventilation_m3')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_infiltration_ach_1_per_hr')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_infiltration_flow_per_conditioned_floor_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_infiltration_flow_per_exterior_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_infiltration_m3')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_mechanical_ventilation_ach_1_per_hr')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_mechanical_ventilation_flow_per_conditioned_floor_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_mechanical_ventilation_flow_per_exterior_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_mechanical_ventilation_m3')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_natural_ventilation_ach_1_per_hr')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_natural_ventilation_flow_per_conditioned_floor_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_natural_ventilation_flow_per_exterior_area_m3_per_s_m2')
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('zones_total_outdoor_air_natural_ventilation_m3')

    return result
  end
  


end # end the measure

# this allows the measure to be use by the application
BtapResults.new.registerWithApplication

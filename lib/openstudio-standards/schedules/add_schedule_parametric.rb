module OpenstudioStandards
  module Schedules
    # apply the smootherstep function to a given input located beetween a starting and ending value
    # range between start/end values will be unitized
    #
    # @param edge0 [Float] lower limit
    # @param edge1 [FLoat] upper limit
    # @param x [Float] input value
    # @return [Float] evaluated value
    def self.smootherstep(edge0, edge1, x)
      if x < edge0 && x > edge1
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Parametric.Model', 'Cannot apply smootherstep to an input outside of range')
        return false
      end
      # fractionalize input over unitized input range
      x_i = ((x - edge0) / (edge1 - edge0))

      return x_i * x_i * x_i * ((x_i * ((6.0 * x_i) - 15.0)) + 10.0)
    end

    # applies smootherstep to the input set of <24 time_value_pairs to interpolate missing points
    # returns an expanded array of 24 time value pairs
    def self.smooth_schedule_from_time_values(time_value_pairs, timesteps_per_hour)
      return_arry = []
      if time_value_pairs[0][0] != 0
        time_value_pairs.unshift([0, time_value_pairs[0][1]])
      end
      if time_value_pairs[-1][0] != 24
        time_value_pairs << [24, time_value_pairs[-1][1]]
      end

      time_value_pairs.each_cons(2) do |this_pair, next_pair|
        this_time = this_pair[0].to_f
        this_val = this_pair[1]
        next_time = next_pair[0].to_f
        next_val = next_pair[1]

        next_time == 24 ? exclude_end = false : exclude_end = true

        Range.new(this_time, next_time, exclude_end).step(1.0 / timesteps_per_hour).each do |time|
          val_frac = smootherstep(this_time, next_time, time)
          if next_val < this_val
            val_actual = this_val - (val_frac * (next_val - this_val).abs)
          else
            val_actual = this_val + (val_frac * (next_val - this_val).abs)
          end
          return_arry << [time, val_actual]
        end
      end
      return_arry
    end

    # expands parametric schedule control points
    #
    # @return [Array] array of time value pairs
    def self.expand_schedule_control_points(control_points, base, peak, start_time, end_time, timesteps_per_hour)
      # proc to round to timestep
      round_to_timestep = ->(val) { (val * timesteps_per_hour).round / timesteps_per_hour.to_f }

      time_value_pairs = []
      control_points.each do |point|
        # points are a list describing formula
        # first element is the time descriptor (st, et, half)
        # second element is an object with {time operator: time operand}
        # third element is the value indicator (base, peak)
        # fourth element is an object with {value operator: value operand}
        case point[0]
        when 'st'
          time = start_time
        when 'et'
          time = end_time
        when 'half'
          time = round_to_timestep.call((end_time - start_time) / 2.0) + start_time
        end

        point[1].each do |k, v|
          time = time.send(k.to_s, v)
        end

        # ensure time lands on timestep
        time = round_to_timestep.call(time)

        case point[2]
        when 'base'
          val = base
        when 'peak'
          val = peak
        end

        point[3].each do |k, v|
          val = val.send(k.to_s, v)
        end

        # limit value between 0 and 1
        val.clamp(0, 1)

        time_value_pairs << [time, val]
      end
      # apply smoothing to intermediate values between
      return smooth_schedule_from_time_values(time_value_pairs, timesteps_per_hour)
    end

    def self.model_add_time_value_pairs_to_schedule(day_sch, time_value_pairs)
      time_value_pairs.each_with_index do |pair, i|
        # p pair
        if i != (time_value_pairs.size - 1) && pair[1] == time_value_pairs[i + 1][1]
          next
        end

        hr = pair[0].to_i
        min = (pair[0].modulo(1) * 60).to_i

        puts "#{hr}:#{min} -> #{pair[1]}"

        day_sch.addValue(OpenStudio::Time.new(0, hr, min, 0), pair[1])
      end
    end

    # Add a parametric schedule from schedule dataset, evaluating schedule expressions
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param schedule_name [String] name of schedule
    # @param params [Hash] hash of schedule input parameters. Specific key/values will depend on the schedule type
    # @return [ScheduleRuleset] the resulting schedule ruleset
    def self.model_add_parametric_schedule(model, schedule_array, schedule_name, params)
      require 'date'

      timesteps_per_hour = model.getTimestep.numberOfTimestepsPerHour

      rules = schedule_array.select { |o| o[:name] == schedule_name }

      sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
      sch_ruleset.setName(schedule_name)

      rules.each do |rule|
        day_types = rule[:day_types]
        start_date = DateTime.strptime(rule[:start_date], '%m/%d/%Y')
        end_date = DateTime.strptime(rule[:end_date], '%m/%d/%Y')
        sch_type = rule[:type]
        control_points = rule[:control_points]

        params[:st].nil? ? st = rule[:st_std] : st = params[:st]
        params[:et].nil? ? et = rule[:et_std] : et = params[:et]
        params[:base].nil? ? base = rule[:base_std] : base = params[:base]
        params[:peak].nil? ? peak = rule[:peak_std] : peak = params[:peak]


        time_value_pairs = expand_schedule_control_points(control_points, base, peak, st, et, timesteps_per_hour)
        p time_value_pairs

        if day_types.include?('Default')
          day_sch = sch_ruleset.defaultDaySchedule
          day_sch.setName("#{schedule_name} Default")
          model_add_time_value_pairs_to_schedule(day_sch, time_value_pairs)
        end

        # Winter Design Day
        if day_types.include?('WntrDsn')
          day_sch = OpenStudio::Model::ScheduleDay.new(model)
          sch_ruleset.setWinterDesignDaySchedule(day_sch)
          day_sch = sch_ruleset.winterDesignDaySchedule
          day_sch.setName("#{schedule_name} Winter Design Day")
          model_add_time_value_pairs_to_schedule(day_sch, time_value_pairs)
        end

        # Summer Design Day
        if day_types.include?('SmrDsn')
          day_sch = OpenStudio::Model::ScheduleDay.new(model)
          sch_ruleset.setSummerDesignDaySchedule(day_sch)
          day_sch = sch_ruleset.summerDesignDaySchedule
          day_sch.setName("#{schedule_name} Summer Design Day")
          model_add_time_value_pairs_to_schedule(day_sch, time_value_pairs)
        end

        # Other days (weekdays, weekends, etc)
        if day_types.include?('Wknd') ||
           day_types.include?('Wkdy') ||
           day_types.include?('Sat') ||
           day_types.include?('Sun') ||
           day_types.include?('Mon') ||
           day_types.include?('Tue') ||
           day_types.include?('Wed') ||
           day_types.include?('Thu') ||
           day_types.include?('Fri')

          # Make the Rule
          sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
          day_sch = sch_rule.daySchedule
          day_sch.setName("#{schedule_name} #{day_types} Day")
          model_add_time_value_pairs_to_schedule(day_sch, time_value_pairs)

          # Set the dates when the rule applies
          sch_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_date.month.to_i), start_date.day.to_i))
          sch_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_date.month.to_i), end_date.day.to_i))

          # Set the days when the rule applies
          # Weekends
          if day_types.include?('Wknd')
            sch_rule.setApplySaturday(true)
            sch_rule.setApplySunday(true)
          end
          # Weekdays
          if day_types.include?('Wkdy')
            sch_rule.setApplyMonday(true)
            sch_rule.setApplyTuesday(true)
            sch_rule.setApplyWednesday(true)
            sch_rule.setApplyThursday(true)
            sch_rule.setApplyFriday(true)
          end
          # Individual Days
          sch_rule.setApplyMonday(true) if day_types.include?('Mon')
          sch_rule.setApplyTuesday(true) if day_types.include?('Tue')
          sch_rule.setApplyWednesday(true) if day_types.include?('Wed')
          sch_rule.setApplyThursday(true) if day_types.include?('Thu')
          sch_rule.setApplyFriday(true) if day_types.include?('Fri')
          sch_rule.setApplySaturday(true) if day_types.include?('Sat')
          sch_rule.setApplySunday(true) if day_types.include?('Sun')
        end
      end
      return sch_ruleset
    end
  end
end

require 'json'
require 'openstudio'

schedule_data = JSON.parse(File.read('schedules_data_test.json'), symbolize_names: true)

model = OpenStudio::Model::Model.new
model.getTimestep.setNumberOfTimestepsPerHour(4)

# default params
sch = OpenstudioStandards::Schedules.model_add_parametric_schedule(model, schedule_data, 'conference_meeting_multipurpose', {})
puts sch.defaultDaySchedule

model.save('test1.osm', true)

model = OpenStudio::Model::Model.new
model.getTimestep.setNumberOfTimestepsPerHour(4)

# modified params
sch = OpenstudioStandards::Schedules.model_add_parametric_schedule(model, schedule_data, 'conference_meeting_multipurpose', { st: 6.0, et: 23.0, base: 0.25, peak: 0.75 })
puts sch.defaultDaySchedule
model.save('test2.osm', true)

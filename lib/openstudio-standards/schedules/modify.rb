# Methods to modify existing Schedule objects
module OpenstudioStandards
  module Schedules
    module Modify

      # Increase/decrease by percentage or static value
      #
      # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
      # @param value [Double] Hash of name and time value pairs
      # @param modification_type [String] Options are 'Multiplier', which multiples by the value,
      #   and 'Sum' which adds by the value
      # @return [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
      # @todo add in design day adjustments, maybe as an optional argument
      # @todo provide option to clone existing schedule
      def schedule_ruleset_simple_value_adjust(schedule_ruleset, value, modification_type = 'Multiplier')
        # gather profiles
        profiles = []
        default_profile = schedule_ruleset.to_ScheduleRuleset.get.defaultDaySchedule
        profiles << default_profile
        rules = schedule_ruleset.scheduleRules
        rules.each do |rule|
          profiles << rule.daySchedule
        end

        # alter profiles
        profiles.each do |profile|
          times = profile.times
          i = 0
          profile.values.each do |sch_value|
            case modification_type
            when 'Multiplier', 'Percentage'
              # percentage was used early on but Multiplier is preferable
              profile.addValue(times[i], sch_value * value)
            when 'Sum', 'Value'
              # value was used early on but Sum is preferable
              profile.addValue(times[i], sch_value + value)
            end
            i += 1
          end
        end

        return schedule_ruleset
      end

      # Increase/decrease by percentage or static value
      # change value when value passes/fails test
      #
      # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
      # @param test_value [Double] if less than the test_value, use the pass_value to modify, otherwise use the fail_value
      # @param pass_value [Double] value to adjust by if less than test value
      # @param fail_value [Double] value to adjust by if more than test value
      # @param floor_value [Double] minimum value that the adjustment can take
      # @param modification_type [String] Options are 'Multiplier', which multiples by the value,
      #   and 'Sum' which adds by the value
      # @return [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
      # @todo add in design day adjustments, maybe as an optional argument
      # @todo provide option to clone existing schedule
      def schedule_ruleset_conditional_adjust_value(schedule_ruleset, test_value, pass_value, fail_value, floor_value, modification_type = 'Multiplier')
        # gather profiles
        profiles = []
        default_profile = schedule_ruleset.to_ScheduleRuleset.get.defaultDaySchedule
        profiles << default_profile
        rules = schedule_ruleset.scheduleRules
        rules.each do |rule|
          profiles << rule.daySchedule
        end

        # alter profiles
        profiles.each do |profile|
          times = profile.times
          i = 0

          profile.values.each do |sch_value|
            # run test on this sch_value
            if sch_value < test_value
              adjust_value = pass_value
            else
              adjust_value = fail_value
            end

            # skip if sch_value is floor or less
            next if sch_value <= floor_value

            case modification_type
            when 'Multiplier'
              # take the max of the floor or resulting value
              profile.addValue(times[i], [sch_value * adjust_value, floor_value].max)
            when 'Sum'
              # take the max of the floor or resulting value
              profile.addValue(times[i], [sch_value + adjust_value, floor_value].max) 
            end
            i += 1
          end
        end

        return schedule_ruleset
      end

      # Increase/decrease by percentage or static value
      # change value when time passes test
      #
      # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
      # @param hhmm_before [String] time before string in hhmm format, e.g. 1530
      # @param hhmm_after [String] string in hhmm format, e.g. 1530
      # @param inside_value [Double]
      # @param outside_value [Double]
      # @param modification_type [String] Options are 'Sum', which adds to the value,
      #   and 'Replace' which replaces the value
      # @return [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
      def schedule_ruleset_time_conditional_adjust_value(schedule_ruleset, hhmm_before, hhmm_after, inside_value, outside_value, modification_type = 'Sum')
        # setup variables
        array = hhmm_before.to_s.split('')
        before_hour = "#{array[0]}#{array[1]}".to_i
        before_min = "#{array[2]}#{array[3]}".to_i
        array = hhmm_after.to_s.split('')
        after_hour = "#{array[0]}#{array[1]}".to_i
        after_min = "#{array[2]}#{array[3]}".to_i

        # gather profiles
        profiles = []
        schedule = schedule_ruleset.to_ScheduleRuleset.get
        default_profile = schedule_ruleset.defaultDaySchedule
        profiles << default_profile
        rules = schedule_ruleset.scheduleRules
        rules.each do |rule|
          profiles << rule.daySchedule
        end

        # alter profiles
        profiles.each do |day_sch|
          times = day_sch.times
          i = 0

          # set times special times needed for methods below
          before_time = OpenStudio::Time.new(0, before_hour, before_min, 0)
          after_time = OpenStudio::Time.new(0, after_hour, after_min, 0)
          # day_end_time = OpenStudio::Time.new(0, 24, 0, 0)

          # add datapoint at before and after time
          original_value_at_before_time = day_sch.getValue(before_time)
          original_value_at_after_time = day_sch.getValue(after_time)
          day_sch.addValue(before_time, original_value_at_before_time)
          day_sch.addValue(after_time, original_value_at_after_time)

          # make arrays for original times and values
          times = day_sch.times
          sch_values = day_sch.values
          day_sch.clearValues

          # make arrays for new values
          new_times = []
          new_values = []

          # loop through original time/value pairs to populate new array
          for i in 0..(sch_values.length - 1)
            new_times << times[i]

            if times[i] > before_time && times[i] <= after_time
              # updated this so times[i] == before_time goes into the else
              if inside_value.nil?
                new_values << sch_values[i]
              elsif modification_type == 'Sum'
                new_values << inside_value + sch_values[i]
              elsif modification_type == 'Replace'
                new_values << inside_value
              else # should be Multiplier
                new_values << inside_value * sch_values[i]
              end
            else
              if outside_value.nil?
                new_values << sch_values[i]
              elsif modification_type == 'Sum'
                new_values << outside_value + sch_values[i]
              elsif modification_type == 'Replace'
                new_values << outside_value
              else # should be Multiplier
                new_values << outside_value * sch_values[i]
              end
            end

          end

          # generate new day_sch values
          for i in 0..(new_values.length - 1)
            day_sch.addValue(new_times[i], new_values[i])
          end
        end

        return schedule_ruleset
      end

      # Adjust hours of operation
      #
      # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
      # @param options [Hash] Hash of argument options
      # @return [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
      def schedule_ruleset_adjust_hours_of_operation(schedule_ruleset, options = {})
        defaults = {
          'base_start_hoo' => 8.0, # may not be good idea to have default
          'base_finish_hoo' => 18.0, # may not be good idea to have default
          'delta_length_hoo' => 0.0,
          'shift_hoo' => 0.0,
          'default' => true,
          'mon' => true,
          'tue' => true,
          'wed' => true,
          'thur' => true,
          'fri' => true,
          'sat' => true,
          'sun' => true,
          'summer' => false,
          'winter' => false
        }
    
        # merge user inputs with defaults
        options = defaults.merge(options)
    
        # grab schedule out of argument
        if schedule_ruleset.to_ScheduleRuleset.is_initialized
          schedule = schedule_ruleset.to_ScheduleRuleset.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Schedules.Modify', "schedule_ruleset_adjust_hours_of_operation only applies to ScheduleRuleset objects. Skipping #{schedule.name}")
          return nil
        end
    
        # array of all profiles to change
        profiles = []
    
        # push default profiles to array
        if options['default']
          default_rule = schedule.defaultDaySchedule
          profiles << default_rule
        end
    
        # push profiles to array
        rules = schedule.scheduleRules
        rules.each do |rule|
          day_sch = rule.daySchedule
    
          # if any day requested also exists in the rule, then it will be altered
          alter_rule = false
          if rule.applyMonday && rule.applyMonday == options['mon'] then alter_rule = true end
          if rule.applyTuesday && rule.applyTuesday == options['tue'] then alter_rule = true end
          if rule.applyWednesday && rule.applyWednesday == options['wed'] then alter_rule = true end
          if rule.applyThursday && rule.applyThursday == options['thur'] then alter_rule = true end
          if rule.applyFriday && rule.applyFriday == options['fri'] then alter_rule = true end
          if rule.applySaturday && rule.applySaturday == options['sat'] then alter_rule = true end
          if rule.applySunday && rule.applySunday == options['sun'] then alter_rule = true end
    
          # TODO: - add in logic to warn user about conflicts where a single rule has conflicting tests
    
          if alter_rule
            profiles << day_sch
          end
        end
    
        # add design days to array
        if options['summer']
          summer_design = schedule.summerDesignDaySchedule
          profiles << summer_design
        end
        if options['winter']
          winter_design = schedule.winterDesignDaySchedule
          profiles << winter_design
        end
    
        # give info messages as I change specific profiles
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Schedules.Modify', "Adjusting #{schedule.name}")
    
        # rename schedule
        schedule.setName("#{schedule.name} - extend #{options['delta_length_hoo']} shift #{options['shift_hoo']}")
    
        # break time args into hours and minutes
        start_hoo_hours = (options['base_start_hoo']).to_i
        start_hoo_minutes = (((options['base_start_hoo']) - (options['base_start_hoo']).to_i) * 60).to_i
        finish_hoo_hours = (options['base_finish_hoo']).to_i
        finish_hoo_minutes = (((options['base_finish_hoo']) - (options['base_finish_hoo']).to_i) * 60).to_i
        delta_hours = (options['delta_length_hoo']).to_i
        delta_minutes = (((options['delta_length_hoo']) - (options['delta_length_hoo']).to_i) * 60).to_i
        shift_hours = (options['shift_hoo']).to_i
        shift_minutes = (((options['shift_hoo']) - (options['shift_hoo']).to_i) * 60).to_i
    
        # time objects to use in measure
        time_0 = OpenStudio::Time.new(0, 0, 0, 0)
        time_1_min = OpenStudio::Time.new(0, 0, 1, 0) # add this to avoid times in day profile less than this
        time_12 =  OpenStudio::Time.new(0, 12, 0, 0)
        time_24 =  OpenStudio::Time.new(0, 24, 0, 0)
        start_hoo_time = OpenStudio::Time.new(0, start_hoo_hours, start_hoo_minutes, 0)
        finish_hoo_time = OpenStudio::Time.new(0, finish_hoo_hours, finish_hoo_minutes, 0)
        delta_time = OpenStudio::Time.new(0, delta_hours, delta_minutes, 0) # not used
        shift_time = OpenStudio::Time.new(0, shift_hours, shift_minutes, 0)
    
        # calculations
        if options['base_start_hoo'] <= options['base_finish_hoo']
          base_opp_day_length = options['base_finish_hoo'] - options['base_start_hoo']
          mid_hoo = start_hoo_time + (finish_hoo_time - start_hoo_time) / 2
          mid_non_hoo = mid_hoo + time_12
          if mid_non_hoo > time_24 then mid_non_hoo -= time_24 end
        else
          base_opp_day_length = options['base_finish_hoo'] - options['base_start_hoo'] + 24
          mid_non_hoo = finish_hoo_time + (start_hoo_time - finish_hoo_time) / 2
          mid_hoo = mid_non_hoo + time_12
          if mid_non_hoo > time_24 then mid_non_hoo -= time_24 end
        end
        adjusted_opp_day_length = base_opp_day_length + options['delta_length_hoo']
        hoo_time_multiplier = adjusted_opp_day_length / base_opp_day_length
        non_hoo_time_multiplier = (24 - adjusted_opp_day_length) / (24 - base_opp_day_length)
    
        # check for invalid input
        if adjusted_opp_day_length < 0
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Modify', 'Requested hours of operation adjustment results in an invalid negative hours of operation')
          return false
        end
        # check for invalid input
        if adjusted_opp_day_length > 24
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Modify', 'Requested hours of operation adjustment results in more than 24 hours of operation')
          return false
        end
    
        # making some temp objects to avoid having to deal with wrap around for change of hoo times
        mid_hoo < start_hoo_time ? (adj_mid_hoo = mid_hoo + time_24) : (adj_mid_hoo = mid_hoo)
        finish_hoo_time < adj_mid_hoo ? (adj_finish_hoo_time = finish_hoo_time + time_24) : (adj_finish_hoo_time = finish_hoo_time)
        mid_non_hoo < adj_finish_hoo_time ? (adj_mid_non_hoo = mid_non_hoo + time_24) : (adj_mid_non_hoo = mid_non_hoo)
        adj_start = start_hoo_time + time_24 # not used
    
        # edit profiles
        profiles.each do |day_sch|
          times = day_sch.times
          values = day_sch.values
    
          # in this case delete all values outside of
          # todo - may need similar logic if exactly 0 hours
          if adjusted_opp_day_length == 24
            start_val = day_sch.getValue(start_hoo_time)
            finish_val = day_sch.getValue(finish_hoo_time)
    
            # remove times out of range that should not be reference or compressed
            if start_hoo_time < finish_hoo_time
              times.each do |time|
                if time <= start_hoo_time || time > finish_hoo_time
                  day_sch.removeValue(time)
                end
              end
              # add in values
              day_sch.addValue(start_hoo_time,start_val)
              day_sch.addValue(finish_hoo_time,finish_val)
              day_sch.addValue(time_24,[start_val,finish_val].max)
            else
              times.each do |time|
                if time > start_hoo_time && time <= finish_hoo_time
                  day_sch.removeValue(time)
                end
              end
              # add in values
              day_sch.addValue(finish_hoo_time,finish_val)
              day_sch.addValue(start_hoo_time,start_val)
              day_sch.addValue(time_24,[values.first,values.last].max)
            end
    
          end
    
          times = day_sch.times
          values = day_sch.values
    
          # arrays for values to avoid overlap conflict of times
          new_times = []
          new_values = []
    
          # this is to store what datapoint will be first after midnight, and what the value at that time should be
          min_time_new = time_24
          min_time_value = nil
    
          # flag if found time at 24
          found_24_or_0 = false
    
          # push times to array
          times.each do |time|
            # create logic for four possible quadrants. Assume any quadrant can pass over 24/0 threshold
            time < start_hoo_time ? (temp_time = time + time_24) : (temp_time = time)
    
            # calculate change in time do to hoo delta
            if temp_time <= adj_finish_hoo_time
              expand_time = (temp_time - adj_mid_hoo) * hoo_time_multiplier - (temp_time - adj_mid_hoo)
            else
              expand_time = (temp_time - adj_mid_non_hoo) * non_hoo_time_multiplier - (temp_time - adj_mid_non_hoo)
            end
    
            new_time = time + shift_time + expand_time
    
            # adjust wrap around times
            if new_time < time_0
              new_time += time_24
            elsif new_time > time_24
              new_time -= time_24
            end
            new_times << new_time
    
            # see which new_time has the lowest value. Then add a value at 24 equal to that
            if !found_24_or_0 && new_time <= min_time_new
              min_time_new = new_time
              min_time_value = day_sch.getValue(time)
            elsif new_time == time_24 # this was added to address time exactly at 24
              min_time_new = new_time
              min_time_value = day_sch.getValue(time)
              found_24_or_0 = true
            elsif new_time == time_0
              min_time_new = new_time
              min_time_value = day_sch.getValue(time_0)
              found_24_or_0 = true
            end
          end
    
          # push values to array
          values.each do |value|
            new_values << value
          end
    
          # add value for what will be 24
          new_times << time_24
          new_values << min_time_value
    
          new_time_val_hash = {}
          new_times.each_with_index do |time,i|
            new_time_val_hash[time.totalHours] = {:time => time, :value => new_values[i]}
          end
    
          # clear values
          day_sch.clearValues
    
          new_time_val_hash = Hash[new_time_val_hash.sort]
          prev_time = nil
          new_time_val_hash.sort.each do |hours,time_val|
            if prev_time.nil? || time_val[:time] - prev_time > time_1_min
              day_sch.addValue(time_val[:time], time_val[:value])
              prev_time = time_val[:time]
            else
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Schedules.Modify', "Time step in #{day_sch.name} between #{prev_time.toString} and #{time_val[:time].toString} is too small to support, not adding value.")
            end
          end
    
        end
    
        return schedule
      end
    end
  end
end
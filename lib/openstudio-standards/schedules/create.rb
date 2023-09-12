# Methods to create Schedule objects
module OpenstudioStandards
  module Schedules
    # @!group Create

    # create a ruleset schedule with a basic profile
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param options [Hash] Hash of name and time value pairs
    # @return [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    def self.model_create_simple_schedule(model, options = {})
      defaults = {
        'name' => nil,
        'winterTimeValuePairs' => { 24.0 => 0.0 },
        'summerTimeValuePairs' => { 24.0 => 1.0 },
        'defaultTimeValuePairs' => { 24.0 => 1.0 }
      }

      # merge user inputs with defaults
      options = defaults.merge(options)

      # ScheduleRuleset
      sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
      if name
        sch_ruleset.setName(options['name'])
      end

      # Winter Design Day
      winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
      sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
      winter_dsn_day = sch_ruleset.winterDesignDaySchedule
      winter_dsn_day.setName("#{sch_ruleset.name} Winter Design Day")
      options['winterTimeValuePairs'].each do |k, v|
        hour = k.truncate
        min = ((k - hour) * 60).to_i
        winter_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0), v)
      end

      # Summer Design Day
      summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
      sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
      summer_dsn_day = sch_ruleset.summerDesignDaySchedule
      summer_dsn_day.setName("#{sch_ruleset.name} Summer Design Day")
      options['summerTimeValuePairs'].each do |k, v|
        hour = k.truncate
        min = ((k - hour) * 60).to_i
        summer_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0), v)
      end

      # All Days
      default_day = sch_ruleset.defaultDaySchedule
      default_day.setName("#{sch_ruleset.name} Schedule Week Day")
      options['defaultTimeValuePairs'].each do |k, v|
        hour = k.truncate
        min = ((k - hour) * 60).to_i
        default_day.addValue(OpenStudio::Time.new(0, hour, min, 0), v)
      end

      return sch_ruleset
    end

    # create a ruleset schedule with a complex profile
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param options [Hash] Hash of name and time value pairs
    # @return [OpenStudio::Model::ScheduleRuleset] OpenStudio ruleset schedule object
    def self.model_create_complex_schedule(model, options = {})
      defaults = {
        'name' => nil,
        'default_day' => ['always_on', [24.0, 1.0]]
      }

      # merge user inputs with defaults
      options = defaults.merge(options)

      # ScheduleRuleset
      sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
      if name
        sch_ruleset.setName(options['name'])
      end

      # Winter Design Day
      unless options['winter_design_day'].nil?
        winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
        sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
        winter_dsn_day = sch_ruleset.winterDesignDaySchedule
        winter_dsn_day.setName("#{sch_ruleset.name} Winter Design Day")
        options['winter_design_day'].each do |data_pair|
          hour = data_pair[0].truncate
          min = ((data_pair[0] - hour) * 60).to_i
          winter_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0), data_pair[1])
        end
      end

      # Summer Design Day
      unless options['summer_design_day'].nil?
        summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
        sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
        summer_dsn_day = sch_ruleset.summerDesignDaySchedule
        summer_dsn_day.setName("#{sch_ruleset.name} Summer Design Day")
        options['summer_design_day'].each do |data_pair|
          hour = data_pair[0].truncate
          min = ((data_pair[0] - hour) * 60).to_i
          summer_dsn_day.addValue(OpenStudio::Time.new(0, hour, min, 0), data_pair[1])
        end
      end

      # Default Day
      default_day = sch_ruleset.defaultDaySchedule
      default_day.setName("#{sch_ruleset.name} #{options['default_day'][0]}")
      default_data_array = options['default_day']
      default_data_array.delete_at(0)
      default_data_array.each do |data_pair|
        hour = data_pair[0].truncate
        min = ((data_pair[0] - hour) * 60).to_i
        default_day.addValue(OpenStudio::Time.new(0, hour, min, 0), data_pair[1])
      end

      # Rules
      unless options['rules'].nil?
        options['rules'].each do |data_array|
          rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
          rule.setName("#{sch_ruleset.name} #{data_array[0]} Rule")
          date_range = data_array[1].split('-')
          start_date = date_range[0].split('/')
          end_date = date_range[1].split('/')
          rule.setStartDate(model.getYearDescription.makeDate(start_date[0].to_i, start_date[1].to_i))
          rule.setEndDate(model.getYearDescription.makeDate(end_date[0].to_i, end_date[1].to_i))
          days = data_array[2].split('/')
          rule.setApplySunday(true) if days.include? 'Sun'
          rule.setApplyMonday(true) if days.include? 'Mon'
          rule.setApplyTuesday(true) if days.include? 'Tue'
          rule.setApplyWednesday(true) if days.include? 'Wed'
          rule.setApplyThursday(true) if days.include? 'Thu'
          rule.setApplyFriday(true) if days.include? 'Fri'
          rule.setApplySaturday(true) if days.include? 'Sat'
          day_schedule = rule.daySchedule
          day_schedule.setName("#{sch_ruleset.name} #{data_array[0]}")
          data_array.delete_at(0)
          data_array.delete_at(0)
          data_array.delete_at(0)
          data_array.each do |data_pair|
            hour = data_pair[0].truncate
            min = ((data_pair[0] - hour) * 60).to_i
            day_schedule.addValue(OpenStudio::Time.new(0, hour, min, 0), data_pair[1])
          end
        end
      end

      return sch_ruleset
    end

    # create a new schedule using absolute velocity of existing schedule
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ruleset schedule object
    # @return [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @todo fix velocity so it isn't fraction change per step, but per hour
    #   (I need to count hours between times and divide value by this)
    def self.model_create_schedule_from_rate_of_change(model, schedule_ruleset)
      # clone source schedule
      new_schedule = schedule_ruleset.clone(model)
      new_schedule.setName("#{schedule_ruleset.name} - Rate of Change")
      new_schedule = new_schedule.to_ScheduleRuleset.get

      # create array of all profiles to change. This includes summer, winter, default, and rules
      profiles = []
      profiles << new_schedule.winterDesignDaySchedule
      profiles << new_schedule.summerDesignDaySchedule
      profiles << new_schedule.defaultDaySchedule

      # time values may need
      end_profile_time = OpenStudio::Time.new(0, 24, 0, 0)
      hour_bump_time = OpenStudio::Time.new(0, 1, 0, 0)
      one_hour_left_time = OpenStudio::Time.new(0, 23, 0, 0)

      rules = new_schedule.scheduleRules
      rules.each do |rule|
        profiles << rule.daySchedule
      end

      profiles.uniq.each do |profile|
        times = profile.times
        values = profile.values

        i = 0
        values_intermediate = []
        times_intermediate = []
        until i == values.size
          if i == 0
            values_intermediate << 0.0
            if times[i] > hour_bump_time
              times_intermediate << times[i] - hour_bump_time
              if times[i + 1].nil?
                time_step_value = end_profile_time.hours + end_profile_time.minutes / 60 - times[i].hours - times[i].minutes / 60
              else
                time_step_value = times[i + 1].hours + times[i + 1].minutes / 60 - times[i].hours - times[i].minutes / 60
              end
              values_intermediate << (values[i + 1].to_f - values[i].to_f).abs / (time_step_value * 2)
            end
            times_intermediate << times[i]
          elsif i == (values.size - 1)
            if times[times.size - 2] < one_hour_left_time
              times_intermediate << times[times.size - 2] + hour_bump_time # this should be the second to last time
              time_step_value = times[i - 1].hours + times[i - 1].minutes / 60 - times[i - 2].hours - times[i - 2].minutes / 60
              values_intermediate << (values[i - 1].to_f - values[i - 2].to_f).abs / (time_step_value * 2)
            end
            values_intermediate << 0.0
            times_intermediate << times[i] # this should be the last time
          else
            # get value multiplier based on how many hours it is spread over
            time_step_value = times[i].hours + times[i].minutes / 60 - times[i - 1].hours - times[i - 1].minutes / 60
            values_intermediate << (values[i].to_f - values[i - 1].to_f).abs / time_step_value
            times_intermediate << times[i]
          end
          i += 1
        end

        # delete all profile values
        profile.clearValues

        i = 0
        until i == times_intermediate.size
          if i == (times_intermediate.size - 1)
            profile.addValue(times_intermediate[i], values_intermediate[i].to_f)
          else
            profile.addValue(times_intermediate[i], values_intermediate[i].to_f)
          end
          i += 1
        end
      end

      return new_schedule
    end

    # merge multiple schedules into one using load or other value to weight each schedules influence on the merge
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param schedule_weights_hash [Hash] Array of hashes of {OpenStudio::Model::ScheduleRuleset, Double}
    # @param sch_name [String] Optional name of new schedule
    # @return [Hash] Hash of {OpenStudio::Model::ScheduleRuleset, Double}
    #   with the OpenStudio ScheduleRuleset object and the total denominator
    # @todo apply weights to schedule rules as well, not just winter, summer, and default profile
    def self.model_create_weighted_merge_schedules(model, schedule_weights_hash, sch_name: 'Merged Schedule')
      # get denominator for weight
      denominator = 0.0
      schedule_weights_hash.each do |schedule, weight|
        denominator += weight
      end

      # create new schedule
      sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
      sch_ruleset.setName(sch_name)

      # create winter design day profile
      winter_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
      sch_ruleset.setWinterDesignDaySchedule(winter_dsn_day)
      winter_dsn_day = sch_ruleset.winterDesignDaySchedule
      winter_dsn_day.setName("#{sch_ruleset.name} Winter Design Day")

      # create  summer design day profile
      summer_dsn_day = OpenStudio::Model::ScheduleDay.new(model)
      sch_ruleset.setSummerDesignDaySchedule(summer_dsn_day)
      summer_dsn_day = sch_ruleset.summerDesignDaySchedule
      summer_dsn_day.setName("#{sch_ruleset.name} Summer Design Day")

      # create default profile
      default_day = sch_ruleset.defaultDaySchedule
      default_day.setName("#{sch_ruleset.name} Schedule Week Day")

      # hash of schedule rules
      rules_hash = {} # mon, tue, wed, thur, fri, sat, sun, startDate, endDate
      # to avoid stacking order issues across schedules, I may need to make a rule for each day of the week for each date range

      schedule_weights_hash.each do |schedule, weight|
        # populate winter design day profile
        old_winter_profile = schedule.to_ScheduleRuleset.get.winterDesignDaySchedule
        times_final = summer_dsn_day.times
        i = 0
        value_updated_array = []
        # loop through times already in profile and update values
        until i > times_final.size - 1
          value = old_winter_profile.getValue(times_final[i]) * weight / denominator
          starting_value = winter_dsn_day.getValue(times_final[i])
          winter_dsn_day.addValue(times_final[i], value + starting_value)
          value_updated_array << times_final[i]
          i += 1
        end
        # loop through any new times unique to the current old profile to be merged
        j = 0
        times = old_winter_profile.times
        values = old_winter_profile.values
        until j > times.size - 1
          unless value_updated_array.include? times[j]
            value = values[j] * weight / denominator
            starting_value = winter_dsn_day.getValue(times[j])
            winter_dsn_day.addValue(times[j], value + starting_value)
          end
          j += 1
        end

        # populate summer design day profile
        old_summer_profile = schedule.to_ScheduleRuleset.get.summerDesignDaySchedule
        times_final = summer_dsn_day.times
        i = 0
        value_updated_array = []
        # loop through times already in profile and update values
        until i > times_final.size - 1
          value = old_summer_profile.getValue(times_final[i]) * weight / denominator
          starting_value = summer_dsn_day.getValue(times_final[i])
          summer_dsn_day.addValue(times_final[i], value + starting_value)
          value_updated_array << times_final[i]
          i += 1
        end
        # loop through any new times unique to the current old profile to be merged
        j = 0
        times = old_summer_profile.times
        values = old_summer_profile.values
        until j > times.size - 1
          unless value_updated_array.include? times[j]
            value = values[j] * weight / denominator
            starting_value = summer_dsn_day.getValue(times[j])
            summer_dsn_day.addValue(times[j], value + starting_value)
          end
          j += 1
        end

        # populate default profile
        old_default_profile = schedule.to_ScheduleRuleset.get.defaultDaySchedule
        times_final = default_day.times
        i = 0
        value_updated_array = []
        # loop through times already in profile and update values
        until i > times_final.size - 1
          value = old_default_profile.getValue(times_final[i]) * weight / denominator
          starting_value = default_day.getValue(times_final[i])
          default_day.addValue(times_final[i], value + starting_value)
          value_updated_array << times_final[i]
          i += 1
        end
        # loop through any new times unique to the current old profile to be merged
        j = 0
        times = old_default_profile.times
        values = old_default_profile.values
        until j > times.size - 1
          unless value_updated_array.include? times[j]
            value = values[j] * weight / denominator
            starting_value = default_day.getValue(times[j])
            default_day.addValue(times[j], value + starting_value)
          end
          j += 1
        end

        # create rules

        # gather data for rule profiles

        # populate rule profiles
      end

      result = { 'mergedSchedule' => sch_ruleset, 'denominator' => denominator }
      return result
    end
  end
end
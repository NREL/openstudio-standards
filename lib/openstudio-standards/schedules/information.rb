module OpenstudioStandards
  # The Schedules module provides methods to create, modify, and get information about Schedule objects
  module Schedules
    # @!group Information
    # Methods to get information about Schedule objects

    # Returns the Schedule minimum and maximum values encountered during the run-period.
    # This method does not include summer and winter design day values.
    #
    # @param schedule [OpenStudio::Model::Schedule] OpenStudio Schedule object
    # return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_get_min_max(schedule)
      case schedule.iddObjectType.valueName.to_s
      when 'OS_Schedule_Ruleset'
        schedule = schedule.to_ScheduleRuleset.get
        result = OpenstudioStandards::Schedules.schedule_ruleset_get_min_max(schedule)
      when 'OS_Schedule_Constant'
        schedule = schedule.to_ScheduleConstant.get
        result = OpenstudioStandards::Schedules.schedule_constant_get_min_max(schedule)
      when 'OS_Schedule_Compact'
        schedule = schedule.to_ScheduleCompact.get
        result = OpenstudioStandards::Schedules.schedule_compact_get_min_max(schedule)
      when 'OS_Schedule_Year'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_get_min_max does not yet support ScheduleYear schedules.')
        result = { 'min' => nil, 'max' => nil }
      when 'OS_Schedule_Interval'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_get_min_max does not yet support ScheduleInterval schedules.')
        result = { 'min' => nil, 'max' => nil }
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "unrecognized schedule type #{schedule.iddObjectType.valueName} for schedule_get_min_max.")
        result = { 'min' => nil, 'max' => nil }
      end

      return result
    end

    # Returns the Schedule minimum and maximum values during the winter or summer design day.
    #
    # @param schedule [OpenStudio::Model::Schedule] OpenStudio Schedule object
    # @param type [String] 'winter' for the winter design day, 'summer' for the summer design day
    # return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_get_design_day_min_max(schedule, type = 'winter')
      case schedule.iddObjectType.valueName.to_s
      when 'OS_Schedule_Ruleset'
        schedule = schedule.to_ScheduleRuleset.get
        result = OpenstudioStandards::Schedules.schedule_ruleset_get_design_day_min_max(schedule, type)
      when 'OS_Schedule_Constant'
        schedule = schedule.to_ScheduleConstant.get
        result = OpenstudioStandards::Schedules.schedule_constant_get_design_day_min_max(schedule, type)
      when 'OS_Schedule_Compact'
        schedule = schedule.to_ScheduleCompact.get
        result = OpenstudioStandards::Schedules.schedule_compact_get_design_day_min_max(schedule, type)
      when 'OS_Schedule_Year'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_get_design_day_min_max does not yet support ScheduleYear schedules.')
        result = { 'min' => nil, 'max' => nil }
      when 'OS_Schedule_Interval'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_get_design_day_min_max does not yet support ScheduleInterval schedules.')
        result = { 'min' => nil, 'max' => nil }
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "unrecognized schedule type #{schedule.iddObjectType.valueName} for schedule_get_design_day_min_max.")
        result = { 'min' => nil, 'max' => nil }
      end

      return result
    end

    # Returns the Schedule equivalent full load hours (EFLH).
    # For example a fractional schedule of 0.5, 24/7, 365 would return a value of 4380.
    # This method includes leap days on leap years.
    #
    # @param schedule [OpenStudio::Model::Schedule] OpenStudio Schedule object
    # return [Double] The total equivalent full load hours for this schedule
    def self.schedule_get_equivalent_full_load_hours(schedule)
      case schedule.iddObjectType.valueName.to_s
      when 'OS_Schedule_Ruleset'
        schedule = schedule.to_ScheduleRuleset.get
        result = OpenstudioStandards::Schedules.schedule_ruleset_get_equivalent_full_load_hours(schedule)
      when 'OS_Schedule_Constant'
        schedule = schedule.to_ScheduleConstant.get
        result = OpenstudioStandards::Schedules.schedule_constant_get_equivalent_full_load_hours(schedule)
      when 'OS_Schedule_Compact'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_get_equivalent_full_load_hours does not yet support ScheduleCompact schedules.')
        result = nil
      when 'OS_Schedule_Year'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_get_equivalent_full_load_hours does not yet support ScheduleYear schedules.')
        result = nil
      when 'OS_Schedule_Interval'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_get_equivalent_full_load_hours does not yet support ScheduleInterval schedules.')
        result = nil
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "unrecognized schedule type #{schedule.iddObjectType.valueName} for schedule_get_equivalent_full_load_hours.")
        result = nil
      end

      return result
    end

    # Returns an array of average hourly values from a Schedule object
    # Returns 8760 values, 8784 for leap years.
    #
    # @param schedule [OpenStudio::Model::Schedule] OpenStudio Schedule object
    # @return [Array<Double>] Array of hourly values for the year
    def self.schedule_get_hourly_values(schedule)
      case schedule.iddObjectType.valueName.to_s
      when 'OS_Schedule_Ruleset'
        schedule = schedule.to_ScheduleRuleset.get
        result = OpenstudioStandards::Schedules.schedule_ruleset_get_hourly_values(schedule)
      when 'OS_Schedule_Constant'
        schedule = schedule.to_ScheduleConstant.get
        result = OpenstudioStandards::Schedules.schedule_constant_get_hourly_values(schedule)
      when 'OS_Schedule_Compact'
        schedule = schedule.to_ScheduleCompact.get
        result = OpenstudioStandards::Schedules.schedule_compact_get_hourly_values(schedule)
      when 'OS_Schedule_Year'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_get_hourly_values does not yet support ScheduleYear schedules.')
        result = nil
      when 'OS_Schedule_Interval'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_get_hourly_values does not yet support ScheduleInterval schedules.')
        result = nil
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "unrecognized schedule type #{schedule.iddObjectType.valueName} for schedule_get_hourly_values.")
        result = nil
      end

      return result
    end

    # @!endgroup Information

    # @!group Information:ScheduleConstant

    # Returns the ScheduleConstant minimum and maximum values encountered during the run-period.
    # This method does not include summer and winter design day values.
    #
    # @param schedule_constant [OpenStudio::Model::ScheduleConstant] OpenStudio ScheduleConstant object
    # return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_constant_get_min_max(schedule_constant)
      result = { 'min' => schedule_constant.value, 'max' => schedule_constant.value }

      return result
    end

    # Returns the ScheduleConstant minimum and maximum values during the winter or summer design day.
    #
    # @param schedule_constant [OpenStudio::Model::ScheduleConstant] OpenStudio ScheduleConstant object
    # @param type [String] 'winter' for the winter design day, 'summer' for the summer design day
    # return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_constant_get_design_day_min_max(schedule_constant, type)
      result = { 'min' => schedule_constant.value, 'max' => schedule_constant.value }

      return result
    end

    # Returns SheduleConstant equivalent full load hours (EFLH).
    # For example a fractional schedule of 0.5, 24/7, 365 would return a value of 4380.
    # This method includes leap days on leap years.
    #
    # @param schedule_constant [OpenStudio::Model::ScheduleConstant] OpenStudio ScheduleConstant object
    # return [Double] The total equivalent full load hours for this schedule
    def self.schedule_constant_get_equivalent_full_load_hours(schedule_constant)
      hours = 8760
      hours += 24 if schedule_constant.model.getYearDescription.isLeapYear
      eflh = schedule_constant.value * hours

      return eflh
    end

    # Returns an array of average hourly values from a ScheduleConstant object
    # Returns 8760 values, 8784 for leap years.
    #
    # @param schedule_constant [OpenStudio::Model::ScheduleConstant] OpenStudio ScheduleConstant object
    # @return [Array<Double>] Array of hourly values for the year
    def self.schedule_constant_get_hourly_values(schedule_constant)
      hours = 8760
      hours += 24 if schedule_constant.model.getYearDescription.isLeapYear
      values = Array.new(hours) { schedule_constant.value }

      return values
    end

    # @!endgroup Information:ScheduleConstant

    # @!group Information:ScheduleCompact

    # Returns the ScheduleCompact minimum and maximum values encountered during the run-period.
    # This method does not include summer and winter design day values.
    #
    # @param schedule_compact [OpenStudio::Model::ScheduleCompact] OpenStudio ScheduleCompact object
    # return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_compact_get_min_max(schedule_compact)
      vals = []
      prev_str = ''
      schedule_compact.extensibleGroups.each do |eg|
        if prev_str.include?('until')
          val = eg.getDouble(0)
          if val.is_initialized
            vals << eg.getDouble(0).get
          end
        end
        str = eg.getString(0)
        if str.is_initialized
          prev_str = str.get.downcase
        end
      end

      # Error if no values were found
      if vals.size.zero?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "Could not find any value in #{schedule_compact.name} when determining min and max.")
        result = { 'min' => nil, 'max' => nil }
        return result
      end

      result = { 'min' => vals.min, 'max' => vals.max }

      return result
    end

    # Returns the ScheduleCompact minimum and maximum values during the winter or summer design day.
    #
    # @param schedule_compact [OpenStudio::Model::ScheduleCompact] OpenStudio ScheduleCompact object
    # @param type [String] 'winter' for the winter design day, 'summer' for the summer design day
    # return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_compact_get_design_day_min_max(schedule_compact, type = 'winter')
      vals = []
      design_day_flag = false
      prev_str = ''
      schedule_compact.extensibleGroups.each do |eg|
        if design_day_flag && prev_str.include?('until')
          val = eg.getDouble(0)
          if val.is_initialized
            vals << val.get
          end
        end

        str = eg.getString(0)
        if str.is_initialized
          prev_str = str.get.downcase
          if prev_str.include?('for:')
            # Process a new day schedule, turn the flag off.
            design_day_flag = false
            # in the same line, if there is design day label and matches the type, turn the flag back on.
            if prev_str.include?(type) || prev_str.include?('alldays')
              design_day_flag = true
            end
          end
        end
      end

      # Error if no values were found
      if vals.size.zero?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "Could not find any value in #{schedule_compact.name} design day schedule when determining min and max.")
        result = { 'min' => nil, 'max' => nil }
        return result
      end

      result = { 'min' => vals.min, 'max' => vals.max }

      return result
    end

    # Returns an array of average hourly values from a ScheduleCompact object
    # Returns 8760 values, 8784 for leap years.
    #
    # @param schedule_compact [OpenStudio::Model::ScheduleCompact] OpenStudio ScheduleCompact object
    # @return [Array<Double>] Array of hourly values for the year
    def self.schedule_compact_get_hourly_values(schedule_compact)
      # set a ScheduleTypeLimits if none is present
      # this is required for the ScheduleTranslator instantiation
      unless schedule_compact.scheduleTypeLimits.is_initialized
        schedule_type_limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
        schedule_compact.setScheduleTypeLimits(schedule_type_limits)
      end

      # convert to a ScheduleRuleset and use its method
      sch_translator = ScheduleTranslator.new(schedule_compact.model, schedule_compact)
      schedule_ruleset = sch_translator.convert_schedule_compact_to_schedule_ruleset
      result = OpenstudioStandards::Schedules.schedule_ruleset_get_hourly_values(schedule_ruleset)

      return result
    end

    # @!endgroup Information:ScheduleCompact

    # @!group Information:ScheduleDay

    # Returns the ScheduleDay daily equivalent full load hours (EFLH).
    #
    # @param schedule_day [OpenStudio::Model::ScheduleDay] OpenStudio ScheduleDay object
    # return [Double] The daily total equivalent full load hours for this schedule
    def self.schedule_day_get_equivalent_full_load_hours(schedule_day)
      daily_flh = 0
      values = schedule_day.values
      times = schedule_day.times

      previous_time_decimal = 0
      times.each_with_index do |time, i|
        time_decimal = (time.days * 24.0) + time.hours + (time.minutes / 60.0) + (time.seconds / 3600.0)
        duration_of_value = time_decimal - previous_time_decimal
        daily_flh += values[i] * duration_of_value
        previous_time_decimal = time_decimal
      end

      return daily_flh
    end


    # Returns an array of average hourly values from a ScheduleDay object
    # Returns 24 values
    #
    # @param schedule_day [OpenStudio::Model::ScheduleDay] OpenStudio ScheduleDay object
    # @return [Array<Double>] Array of hourly values for the day
    def self.schedule_day_get_hourly_values(schedule_day)
      schedule_values = []

      # determine smallest time interval
      times = schedule_day.times
      time_interval_min = 15.0
      previous_time_decimal = 0.0
      times.each_with_index do |time, i|
        time_decimal = (time.days * 24.0 * 60.0) + (time.hours * 60.0) + time.minutes + (time.seconds / 60)
        interval_min = time_decimal - previous_time_decimal
        time_interval_min = interval_min if interval_min < time_interval_min
        previous_time_decimal = time_decimal
      end
      time_interval_min = time_interval_min.round(0).to_i

      # get the hourly average by averaging the values in the hour at the smallest time interval
      (0..23).each do |j|
        values = []
        times = (time_interval_min..60).step(time_interval_min).to_a
        times.each { |t| values << schedule_day.getValue(OpenStudio::Time.new(0, j, t, 0)) }
        schedule_values << (values.sum / times.size).round(5)
      end

      return schedule_values
    end

    # @!endgroup Information:ScheduleDay

    # @!group Information:ScheduleRuleset

    # Returns the ScheduleRuleset minimum and maximum values encountered during the run-period.
    # This method does not include summer and winter design day values.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_ruleset_get_min_max(schedule_ruleset)
      # validate schedule
      unless schedule_ruleset.to_ScheduleRuleset.is_initialized
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "Method schedule_ruleset_get_min_max() failed because object #{schedule_ruleset} is not a ScheduleRuleset.")
        return nil
      end

      # gather profiles
      profiles = []
      profiles << schedule_ruleset.defaultDaySchedule
      schedule_ruleset.scheduleRules.each { |rule| profiles << rule.daySchedule }

      # test profiles
      min = nil
      max = nil
      profiles.each do |profile|
        profile.values.each do |value|
          if min.nil?
            min = value
          else
            if min > value then min = value end
          end
          if max.nil?
            max = value
          else
            if max < value then max = value end
          end
        end
      end
      result = { 'min' => min, 'max' => max }

      return result
    end

    # Returns the ScheduleRuleset minimum and maximum values during the winter or summer design day.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @param type [String] 'winter' for the winter design day, 'summer' for the summer design day
    # return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_ruleset_get_design_day_min_max(schedule_ruleset, type = 'winter')
      # validate schedule
      unless schedule_ruleset.to_ScheduleRuleset.is_initialized
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "Method schedule_ruleset_get_design_day_min_max() failed because object #{schedule_ruleset} is not a ScheduleRuleset.")
        return nil
      end

      if type == 'winter'
        schedule = schedule_ruleset.winterDesignDaySchedule
      elsif type == 'summer'
        schedule = schedule_ruleset.summerDesignDaySchedule
      end

      if !schedule
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Schedules.Information', "#{schedule_ruleset.name} is missing #{type} design day schedule, use default day schedule to process the min max search")
        schedule = schedule_ruleset.defaultDaySchedule
      end

      min = nil
      max = nil
      schedule.values.each do |value|
        if min.nil?
          min = value
        else
          min = value if min > value
        end
        if max.nil?
          max = value
        else
          max = value if max < value
        end
      end
      result = { 'min' => min, 'max' => max }

      return result
    end

    # Returns SheduleRuleset equivalent full load hours (EFLH).
    # For example a fractional schedule of 0.5, 24/7, 365 would return a value of 4380.
    # This method includes leap days on leap years.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # return [Double] The total equivalent full load hours for this schedule
    def self.schedule_ruleset_get_equivalent_full_load_hours(schedule_ruleset)
      # validate schedule
      unless schedule_ruleset.to_ScheduleRuleset.is_initialized
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "Method schedule_ruleset_get_equivalent_full_load_hours() failed because object #{schedule_ruleset} is not a ScheduleRuleset.")
        return nil
      end

      # define the start and end date
      year_start_date = nil
      year_end_date = nil
      if schedule_ruleset.model.yearDescription.is_initialized
        year_description = schedule_ruleset.model.yearDescription.get
        year = year_description.assumedYear
        year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
        year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Schedules.Information', 'Year description is not specified. Full load hours calculation will assume 2009, the default year OS uses.')
        year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, 2009)
        year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, 2009)
      end

      # Get the ordered list of all the day schedules
      day_schs = schedule_ruleset.getDaySchedules(year_start_date, year_end_date)

      # Get the array of which schedule is used on each day of the year
      day_schs_used_each_day = schedule_ruleset.getActiveRuleIndices(year_start_date, year_end_date)

      # Create a map that shows how many days each schedule is used
      day_sch_freq = day_schs_used_each_day.group_by { |n| n }

      # Build a hash that maps schedule day index to schedule day
      schedule_index_to_day = {}
      day_schs.each_with_index do |day_sch, i|
        schedule_index_to_day[day_schs_used_each_day[i]] = day_sch
      end

      # Loop through each of the schedules that is used, figure out the
      # full load hours for that day, then multiply this by the number
      # of days that day schedule applies and add this to the total.
      annual_flh = 0.0
      max_daily_flh = 0.0
      default_day_sch = schedule_ruleset.defaultDaySchedule
      day_sch_freq.each do |freq|
        sch_index = freq[0]
        number_of_days_sch_used = freq[1].size

        # Get the day schedule at this index
        day_sch = nil
        day_sch = if sch_index == -1 # If index = -1, this day uses the default day schedule (not a rule)
                    default_day_sch
                  else
                    schedule_index_to_day[sch_index]
                  end
        daily_flh = OpenstudioStandards::Schedules.schedule_day_get_equivalent_full_load_hours(day_sch)

        # Multiply the daily EFLH by the number
        # of days this schedule is used per year
        # and add this to the overall total
        annual_flh += daily_flh * number_of_days_sch_used
      end

      # Warn if the max daily EFLH is more than 24,
      # which would indicate that this isn't a fractional schedule.
      if max_daily_flh > 24
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Schedules.Information', "#{schedule_ruleset.name} has more than 24 EFLH in one day schedule, indicating that it is not a fractional schedule.")
      end

      return annual_flh
    end

    # Returns an array of average hourly values from a ScheduleRuleset object
    # Returns 8760 values, 8784 for leap years.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @return [Array<Double>] Array of hourly values for the year
    def self.schedule_ruleset_get_hourly_values(schedule_ruleset)
      # validate schedule
      unless schedule_ruleset.to_ScheduleRuleset.is_initialized
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "Method schedule_ruleset_get_hourly_values() failed because object #{schedule_ruleset} is not a ScheduleRuleset.")
        return nil
      end

      # define the start and end date
      year_start_date = nil
      year_end_date = nil
      if schedule_ruleset.model.yearDescription.is_initialized
        year_description = schedule_ruleset.model.yearDescription.get
        year = year_description.assumedYear
        year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
        year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Schedules.Information', 'Year description is not specified. Annual hours above value calculation will assume 2009, the default year OS uses.')
        year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, 2009)
        year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, 2009)
      end

      # Get the ordered list of all the day schedules
      day_schs = schedule_ruleset.getDaySchedules(year_start_date, year_end_date)

      # Loop through each day schedule and add its hours to total
      # @todo store the 24 hourly average values for each day schedule instead of recalculating for all days
      annual_hourly_values = []
      day_schs.each do |day_sch|
        # add daily average hourly values to annual hourly values array
        daily_hours = OpenstudioStandards::Schedules.schedule_day_get_hourly_values(day_sch)
        daily_hours.each { |h| annual_hourly_values << h }
      end

      return annual_hourly_values
    end

    # Returns the total number of hours where the schedule is greater than the specified value.
    # This method includes leap days on leap years.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @param lower_limit [Double] the lower limit.  Values equal to the limit will not be counted.
    # @return [Double] The total number of hours this schedule is above the specified value.
    def self.schedule_ruleset_get_hours_above_value(schedule_ruleset, lower_limit)
      # validate schedule
      unless schedule_ruleset.to_ScheduleRuleset.is_initialized
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "Method schedule_ruleset_get_hours_above_value() failed because object #{schedule_ruleset} is not a ScheduleRuleset.")
        return nil
      end

      # define the start and end date
      year_start_date = nil
      year_end_date = nil
      if schedule_ruleset.model.yearDescription.is_initialized
        year_description = schedule_ruleset.model.yearDescription.get
        year = year_description.assumedYear
        year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
        year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Schedules.Information', 'Year description is not specified. Annual hours above value calculation will assume 2009, the default year OS uses.')
        year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, 2009)
        year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, 2009)
      end

      # Get the ordered list of all the day schedules
      day_schs = schedule_ruleset.getDaySchedules(year_start_date, year_end_date)

      # Get the array of which schedule is used on each day of the year
      day_schs_used_each_day = schedule_ruleset.getActiveRuleIndices(year_start_date, year_end_date)

      # Create a map that shows how many days each schedule is used
      day_sch_freq = day_schs_used_each_day.group_by { |n| n }

      # Build a hash that maps schedule day index to schedule day
      schedule_index_to_day = {}
      day_schs.each_with_index do |day_sch, i|
        schedule_index_to_day[day_schs_used_each_day[i]] = day_sch
      end

      # Loop through each of the schedules that is used, figure out the
      # hours for that day, then multiply this by the number
      # of days that day schedule applies and add this to the total.
      annual_hrs = 0.0
      default_day_sch = schedule_ruleset.defaultDaySchedule
      day_sch_freq.each do |freq|
        sch_index = freq[0]
        number_of_days_sch_used = freq[1].size

        # Get the day schedule at this index
        day_sch = nil
        day_sch = if sch_index == -1 # If index = -1, this day uses the default day schedule (not a rule)
                    default_day_sch
                  else
                    schedule_index_to_day[sch_index]
                  end

        # Determine the hours for just one day
        daily_hrs = 0.0
        values = day_sch.values
        times = day_sch.times

        previous_time_decimal = 0.0
        times.each_with_index do |time, i|
          time_decimal = (time.days * 24.0) + time.hours + (time.minutes / 60.0) + (time.seconds / 3600.0)
          duration_of_value = time_decimal - previous_time_decimal
          if values[i] > lower_limit
            daily_hrs += duration_of_value
          end
          previous_time_decimal = time_decimal
        end

        # Multiply the daily hours by the number
        # of days this schedule is used per year
        # and add this to the overall total
        annual_hrs += daily_hrs * number_of_days_sch_used
      end

      return annual_hrs
    end

    # create OpenStudio TimeSeries object from ScheduleRuleset values
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @return [OpenStudio::TimeSeries] OpenStudio TimeSeries object of schedule values
    def self.schedule_ruleset_get_timeseries(schedule_ruleset)
      # validate schedule
      unless schedule_ruleset.to_ScheduleRuleset.is_initialized
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "Method schedule_ruleset_get_timeseries() failed because object #{schedule_ruleset} is not a ScheduleRuleset.")
        return nil
      end

      yd = schedule_ruleset.model.getYearDescription
      start_date = yd.makeDate(1, 1)
      end_date = yd.makeDate(12, 31)

      values = OpenStudio::DoubleVector.new
      day = OpenStudio::Time.new(1.0)
      interval = OpenStudio::Time.new(1.0 / 48.0)
      day_schedules = schedule_ruleset.getDaySchedules(start_date, end_date)
      day_schedules.each do |day_schedule|
        time = interval
        while time < day
          values << day_schedule.getValue(time)
          time += interval
        end
      end
      timeseries = OpenStudio::TimeSeries.new(start_date, interval, OpenStudio.createVector(values), '')
      return timeseries
    end

    # Determine the hour when the schedule first exceeds the starting value and when
    # it goes back down to the ending value at the end of the day.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @return [Hash<OpenStudio:Time>] returns as hash with 'start_time', 'end time']
    def self.schedule_ruleset_get_start_and_end_times(schedule_ruleset)
      # validate schedule
      unless schedule_ruleset.to_ScheduleRuleset.is_initialized
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', "Method schedule_ruleset_get_start_and_end_times() failed because object #{schedule_ruleset} is not a ScheduleRuleset.")
        return [nil, nil]
      end

      # Define the start and end date
      if schedule_ruleset.model.yearDescription.is_initialized
        year_description = schedule_ruleset.model.yearDescription.get
        year = year_description.assumedYear
        year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
        year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
      else
        year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, 2009)
        year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, 2009)
      end

      # Get the ordered list of all the day schedules that are used by this schedule ruleset
      day_schs = schedule_ruleset.getDaySchedules(year_start_date, year_end_date)

      # Get a 365-value array of which schedule is used on each day of the year,
      day_schs_used_each_day = schedule_ruleset.getActiveRuleIndices(year_start_date, year_end_date)

      # Create a map that shows how many days each schedule is used
      day_sch_freq = day_schs_used_each_day.group_by { |n| n }
      day_sch_freq = day_sch_freq.sort_by { |freq| freq[1].size }
      common_day_freq = day_sch_freq.last

      # Build a hash that maps schedule day index to schedule day
      schedule_index_to_day = {}
      day_schs.each_with_index do |day_sch, i|
        schedule_index_to_day[day_schs_used_each_day[i]] = day_sch
      end

      # Get the most common day schedule
      sch_index = common_day_freq[0]
      number_of_days_sch_used = common_day_freq[1].size

      # Get the day schedule at this index
      day_sch = if sch_index == -1 # If index = -1, this day uses the default day schedule (not a rule)
                  schedule_ruleset.defaultDaySchedule
                else
                  schedule_index_to_day[sch_index]
                end

      # Determine the full load hours for just one day
      values = []
      times = []
      day_sch.times.each_with_index do |time, i|
        times << day_sch.times[i]
        values << day_sch.values[i]
      end

      # Get the minimum value
      start_val = values.first
      end_val = values.last

      # Get the start time (first time value goes above minimum)
      start_time = nil
      values.each_with_index do |val, i|
        break if i == values.size - 1 # Stop if we reach end of array

        if val == start_val && values[i + 1] > start_val
          start_time = times[i]
          break
        end
      end

      # Get the end time (first time value goes back down to minimum)
      end_time = nil
      values.each_with_index do |val, i|
        if i < values.size - 1
          if val > end_val && values[i + 1] == end_val
            end_time = times[i]
            break
          end
        else
          if val > end_val && values[0] == start_val # Check first hour of day for schedules that end at midnight
            end_time = OpenStudio::Time.new(0, 24, 0, 0)
            break
          end
        end
      end

      return { 'start_time' => start_time, 'end_time' => end_time }
    end

    # @!endgroup Information:ScheduleRuleset
  end
end

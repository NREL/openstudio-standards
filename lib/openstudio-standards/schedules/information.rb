# Methods to get information from Schedule objects
# Many of these methods may be moved to core OpenStudio
module OpenstudioStandards
  module Schedules
    # @!group Information

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
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Schedules.Information', 'schedule_min_max does not yet support ScheduleYear.')
        result = { 'min' => nil, 'max' => nil }
      end

      return result
    end

    # Returns the ScheduleConstant minimum and maximum values encountered during the run-period.
    # This method does not include summer and winter design day values.
    #
    # @param schedule_constant [OpenStudio::Model::ScheduleConstant] OpenStudio ScheduleConstant object
    # return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_constant_get_min_max(schedule_constant)
      result = { 'min' => schedule_constant.value, 'max' => schedule_constant.value }

      return result
    end

    # Returns the equivalent full load hours (EFLH) for a ScheduleConstant.
    # For example, an always-on fractional schedule
    # (always 1.0, 24/7, 365) would return a value of 8760
    # and (always 1.0, 24/7, 365) would return a value of 8784.
    #
    # @param schedule_constant [OpenStudio::Model::ScheduleConstant] OpenStudio ScheduleConstant object
    # return [Double] The total equivalent full load hours for this schedule
    def self.schedule_constant_get_equivalent_full_load_hours(schedule_constant)
      hours = 8760
      hours += 24 if schedule_constant.model.getYearDescription.isLeapYear
      eflh = schedule_constant.value * hours

      return eflh
    end

    # Returns an array of hourly values from a ScheduleConstant object
    # Will return 8760 values, and 8784 for leap years.
    #
    # @param schedule_constant [OpenStudio::Model::ScheduleConstant] OpenStudio ScheduleConstant object
    # @return [Array<Double>] Array of hourly values for the year
    def self.schedule_constant_get_hourly_values(schedule_constant)
      hours = 8760
      hours += 24 if schedule_constant.model.getYearDescription.isLeapYear
      values = Array.new(hours) { schedule_constant.value }

      return values
    end

    # Returns the ScheduleCompact minimum and maximum values encountered during the run-period.
    # This method does not include summer and winter design day values.
    #
    # @param schedule_constant [OpenStudio::Model::ScheduleCompact] OpenStudio ScheduleCompact object
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

    # Returns the ScheduleCompact minimum and maximum values during the winter or summer design day
    #
    # @param schedule_constant [OpenStudio::Model::ScheduleCompact] OpenStudio ScheduleCompact object
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

    # Returns the ScheduleRuleset minimum and maximum values encountered during the run-period.
    # This method does not include summer and winter design day values.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @return [Hash] returns a hash with 'min' and 'max' values
    def self.schedule_ruleset_get_min_max(schedule_ruleset)
      # validate schedule
      if schedule_ruleset.to_ScheduleRuleset.is_initialized
        schedule = schedule_ruleset.to_ScheduleRuleset.get

        # gather profiles
        profiles = []
        profiles << schedule.defaultDaySchedule
        rules = schedule.scheduleRules
        rules.each do |rule|
          profiles << rule.daySchedule
        end

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
      else
        result = nil
      end

      return result
    end

    # create OpenStudio TimeSeries object from ScheduleRuleset values
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @return [OpenStudio::TimeSeries] OpenStudio TimeSeries object of schedule values
    def self.schedule_ruleset_get_timeseries(schedule_ruleset)
      yd = schedule_ruleset.model.getYearDescription
      start_date = yd.makeDate(1, 1)
      end_date = yd.makeDate(12, 31)

      values = OpenStudio::DoubleVector.new
      day = OpenStudio::Time.new(1.0)
      interval = OpenStudio::Time.new(1.0 / 48.0)
      day_schedules = schedule_ruleset.to_ScheduleRuleset.get.getDaySchedules(start_date, end_date)
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
    # This method only works for ScheduleRuleset schedules.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @return [Hash<OpenStudio:Time>] returns as hash with 'start_time', 'end time']
    def self.schedule_ruleset_get_start_and_end_times(schedule_ruleset)
      # Ensure that this is a ScheduleRuleset
      schedule_ruleset = schedule_ruleset.to_ScheduleRuleset
      return [nil, nil] if schedule_ruleset.empty?

      schedule_ruleset = schedule_ruleset.get

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
  end
end

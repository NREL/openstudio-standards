# Methods to get information from Schedule objects
# Many of these methods may be moved to core OpenStudio
module OpenstudioStandards
  module Schedules
    # @!group Information

    # add general schedule_min_max(schedule) method and merge with other methods

    # returns the ScheduleRuleset minimum and maximum values encountered during the run-period.
    # This method does not include summer and winter design day values.
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @return [Hash] returns as hash with 'min' and 'max' values
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

# Methods to get information from Schedule objects
# Many of these methods may be moved to core OpenStudio
module OpenstudioStandards
  module Schedules
    # @!group Information

    # add general schedule_min_max(schedule) method and merge with other methods

    # returns the ScheduleRuleset minimum and maximum values
    #
    # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] OpenStudio ScheduleRuleset object
    # @return [Hash] returns as hash with 'min' and 'max' values
    def self.schedule_ruleset_get_min_max(schedule_ruleset)
      # validate schedule
      if schedule_ruleset.to_ScheduleRuleset.is_initialized
        schedule = schedule_ruleset.to_ScheduleRuleset.get

        # gather profiles
        profiles = []
        defaultProfile = schedule.defaultDaySchedule
        profiles << defaultProfile
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
        result = { 'min' => min, 'max' => max } # this doesn't include summer and winter design day
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
  end
end

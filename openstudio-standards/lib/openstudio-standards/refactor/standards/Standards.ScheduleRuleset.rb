
# Reopen the OpenStudio class to add methods to apply standards to this object
class StandardsModel < OpenStudio::Model::Model
  # Returns the equivalent full load hours (EFLH) for this schedule.
  # For example, an always-on fractional schedule
  # (always 1.0, 24/7, 365) would return a value of 8760.
  #
  # @author Andrew Parker, NREL.  Matt Leach, NORESCO.
  # @return [Double] The total number of full load hours for this schedule.
  def schedule_ruleset_annual_equivalent_full_load_hrs(schedule_ruleset)
    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Calculating total annual EFLH for schedule: #{self.name}")

    # Define the start and end date
    year_start_date = nil
    year_end_date = nil
    if schedule_ruleset.model.yearDescription.is_initialized
      year_description = schedule_ruleset.model.yearDescription.get
      year = year_description.assumedYear
      year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
      year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', 'WARNING: Year description is not specified; assuming 2009, the default year OS uses.')
      year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, 2009)
      year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, 2009)
    end

    # Get the ordered list of all the day schedules
    # that are used by this schedule ruleset
    day_schs = schedule_ruleset.getDaySchedules(year_start_date, year_end_date)
    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "***Day Schedules Used***")
    day_schs.uniq.each do |day_sch|
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  #{day_sch.name.get}")
    end

    # Get a 365-value array of which schedule is used on each day of the year,
    day_schs_used_each_day = schedule_ruleset.getActiveRuleIndices(year_start_date, year_end_date)
    if !day_schs_used_each_day.length == 365
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleRuleset', "#{schedule_ruleset.name} does not have 365 daily schedules accounted for, cannot accurately calculate annual EFLH.")
      return 0
    end

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
    annual_flh = 0
    max_daily_flh = 0
    default_day_sch = schedule_ruleset.defaultDaySchedule
    day_sch_freq.each do |freq|
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", freq.inspect
      # exit

      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Schedule Index = #{freq[0]}"
      sch_index = freq[0]
      number_of_days_sch_used = freq[1].size

      # Get the day schedule at this index
      day_sch = nil
      day_sch = if sch_index == -1 # If index = -1, this day uses the default day schedule (not a rule)
                  default_day_sch
                else
                  schedule_index_to_day[sch_index]
                end
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Calculating EFLH for: #{day_sch.name}")

      # Determine the full load hours for just one day
      daily_flh = 0
      values = day_sch.values
      times = day_sch.times

      previous_time_decimal = 0
      times.each_with_index do |time, i|
        time_decimal = (time.days * 24) + time.hours + (time.minutes / 60) + (time.seconds / 3600)
        duration_of_value = time_decimal - previous_time_decimal
        # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  Value of #{values[i]} for #{duration_of_value} hours")
        daily_flh += values[i] * duration_of_value
        previous_time_decimal = time_decimal
      end

      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  #{daily_flh.round(2)} EFLH per day")
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  Used #{number_of_days_sch_used} days per year")

      # Multiply the daily EFLH by the number
      # of days this schedule is used per year
      # and add this to the overall total
      annual_flh += daily_flh * number_of_days_sch_used
    end

    # Warn if the max daily EFLH is more than 24,
    # which would indicate that this isn't a
    # fractional schedule.
    if max_daily_flh > 24
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', "#{schedule_ruleset.name} has more than 24 EFLH in one day schedule, indicating that it is not a fractional schedule.")
    end

    return annual_flh
  end

  # Returns the min and max value for this schedule.
  # It doesn't evaluate design days only run-period conditions
  #
  # @author David Goldwasser, NREL.
  # @return [Hash] Hash has two keys, min and max.
  def schedule_ruleset_annual_min_max_value(schedule_ruleset)
    # gather profiles
    profiles = []
    profiles << schedule_ruleset.defaultDaySchedule
    rules = schedule_ruleset.scheduleRules
    rules.each do |rule|
      profiles << rule.daySchedule
    end

    # test profiles
    min = nil
    max = nil
    schedule_ruleset.profiles.each do |profile|
      profile.values.each do |value|
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
    end
    result = { 'min' => min, 'max' => max }

    return result
  end

  # Returns the total number of hours where the schedule
  # is greater than the specified value.
  #
  # @author Andrew Parker, NREL.
  # @param lower_limit [Double] the lower limit.  Values equal to the limit
  # will not be counted.
  # @return [Double] The total number of hours
  # this schedule is above the specified value.
  def schedule_ruleset_annual_hours_above_value(schedule_ruleset, lower_limit)
    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Calculating total annual hours above #{lower_limit} for schedule: #{self.name}")

    # Define the start and end date
    year_start_date = nil
    year_end_date = nil
    if schedule_ruleset.model.yearDescription.is_initialized
      year_description = schedule_ruleset.model.yearDescription.get
      year = year_description.assumedYear
      year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
      year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', 'WARNING: Year description is not specified; assuming 2009, the default year OS uses.')
      year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, 2009)
      year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, 2009)
    end

    # Get the ordered list of all the day schedules
    # that are used by this schedule ruleset
    day_schs = schedule_ruleset.getDaySchedules(year_start_date, year_end_date)
    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "***Day Schedules Used***")
    day_schs.uniq.each do |day_sch|
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  #{day_sch.name.get}")
    end

    # Get a 365-value array of which schedule is used on each day of the year,
    day_schs_used_each_day = schedule_ruleset.getActiveRuleIndices(year_start_date, year_end_date)
    if !day_schs_used_each_day.length == 365
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleRuleset', "#{schedule_ruleset.name} does not have 365 daily schedules accounted for, cannot accurately calculate annual EFLH.")
      return 0
    end

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
    annual_hrs = 0
    default_day_sch = schedule_ruleset.defaultDaySchedule
    day_sch_freq.each do |freq|
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", freq.inspect
      # exit

      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Schedule Index = #{freq[0]}"
      sch_index = freq[0]
      number_of_days_sch_used = freq[1].size

      # Get the day schedule at this index
      day_sch = nil
      day_sch = if sch_index == -1 # If index = -1, this day uses the default day schedule (not a rule)
                  default_day_sch
                else
                  schedule_index_to_day[sch_index]
                end
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Calculating hours above #{lower_limit} for: #{day_sch.name}")

      # Determine the hours for just one day
      daily_hrs = 0
      values = day_sch.values
      times = day_sch.times

      previous_time_decimal = 0
      times.each_with_index do |time, i|
        time_decimal = (time.days * 24) + time.hours + (time.minutes / 60) + (time.seconds / 3600)
        duration_of_value = time_decimal - previous_time_decimal
        # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  Value of #{values[i]} for #{duration_of_value} hours")
        daily_hrs += values[i] * duration_of_value
        previous_time_decimal = time_decimal
      end

      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  #{daily_hrs.round(2)} hours above #{lower_limit} per day")
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  Used #{number_of_days_sch_used} days per year")

      # Multiply the daily hours by the number
      # of days this schedule is used per year
      # and add this to the overall total
      annual_hrs += daily_hrs * number_of_days_sch_used
    end

    return annual_hrs
  end
end

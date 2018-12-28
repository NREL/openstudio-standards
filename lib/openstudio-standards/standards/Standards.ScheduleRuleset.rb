
class Standard
  # @!group ScheduleRuleset

  # Returns the min and max value for this schedule_day object
  #
  # @param [object] daySchedule
  # @return [Double]
  def day_schedule_equivalent_full_load_hrs(day_sch)

    # Determine the full load hours for just one day
    daily_flh = 0
    values = day_sch.values
    times = day_sch.times

    previous_time_decimal = 0
    times.each_with_index do |time, i|
      time_decimal = (time.days * 24.0) + time.hours + (time.minutes / 60.0) + (time.seconds / 3600.0)
      duration_of_value = time_decimal - previous_time_decimal
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  Value of #{values[i]} for #{duration_of_value} hours")
      daily_flh += values[i] * duration_of_value
      previous_time_decimal = time_decimal
    end

    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  #{daily_flh.round(2)} EFLH per day")
    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  Used #{number_of_days_sch_used} days per year")

    return daily_flh
  end

  # Returns the equivalent full load hours (EFLH) for this schedule.
  # For example, an always-on fractional schedule
  # (always 1.0, 24/7, 365) would return a value of 8760.
  #
  # @author Andrew Parker, NREL.  Matt Leach, NORESCO.
  # @param [object] scheduleRuleset
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

      daily_flh = day_schedule_equivalent_full_load_hrs(day_sch)

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
  # @param [object] scheduleRuleset
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
    profiles.each do |profile|
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
        time_decimal = (time.days * 24.0) + time.hours + (time.minutes / 60.0) + (time.seconds / 3600.0)
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

  # Returns the averaged hourly values of the ruleset schedule for all hours of the year
  #
  # @param schedule_ruleset [<OpenStudio::Model::ScheduleRuleset>] A ScheduleRuleset object
  # @return [Array<Double>] An array of hourly values over the whole year
  def schedule_ruleset_annual_hourly_values(schedule_ruleset)
    schedule_values = []
    year_description = schedule_ruleset.model.getYearDescription
    (1..365).each do |i|
      date = year_description.makeDate(i)
      day_sch = schedule_ruleset.getDaySchedules(date, date)[0]
      (0..23).each do |j|
        # take average value over the hour
        value_15 = day_sch.getValue(OpenStudio::Time.new(0, j, 15, 0))
        value_30 = day_sch.getValue(OpenStudio::Time.new(0, j, 30, 0))
        value_45 = day_sch.getValue(OpenStudio::Time.new(0, j, 45, 0))
        avg = (value_15 + value_30 + value_45).to_f / 3.0
        schedule_values << avg.round(5)
      end
    end
    return schedule_values
  end

  # Remove unused profiles and set most prevalent profile as default
  # When moving profile that isn't lowest priority to default need to address possible issues with overlapping rules dates or days of week
  # method expands on functionality of RemoveUnusedDefaultProfiles measure
  #
  # @author David Goldwasser
  # @param [Object] ScheduleRuleset
  # @return [Object] ScheduleRuleset
  def schedule_ruleset_cleanup_profiles(schedule_ruleset)

    # set start and end dates
    year_description = schedule_ruleset.model.yearDescription.get
    year = year_description.assumedYear
    year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
    year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)

    indices_vector = schedule_ruleset.getActiveRuleIndices(year_start_date, year_end_date)
    most_frequent_item = indices_vector.uniq.max_by{ |i| indices_vector.count( i ) }
    rule_vector = schedule_ruleset.scheduleRules

    replace_existing_default = false
    if indices_vector.include? -1 and most_frequent_item != -1
      # clean up if default isn't most common (e.g. sunday vs. weekday)
      # if no existing rules cover specific days of week, make new rule from default covering those days of week
      possible_days_of_week = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
      used_days_of_week = []
      rule_vector.each do |rule|
        if rule.applyMonday then used_days_of_week << "Monday" end
        if rule.applyTuesday then used_days_of_week << "Tuesday" end
        if rule.applyWednesday then used_days_of_week << "Wednesday" end
        if rule.applyThursday then used_days_of_week << "Thursday" end
        if rule.applyFriday then used_days_of_week << "Friday" end
        if rule.applySaturday then used_days_of_week << "Saturday" end
        if rule.applySunday then used_days_of_week << "Sunday" end
      end
      if used_days_of_week.uniq.size < possible_days_of_week.size
        replace_existing_default = true
        schedule_rule_new = OpenStudio::Model::ScheduleRule.new(schedule_ruleset,schedule_ruleset.defaultDaySchedule)
        if !used_days_of_week.include?("Monday") then schedule_rule_new.setApplyMonday(true) end
        if !used_days_of_week.include?("Tuesday") then schedule_rule_new.setApplyTuesday(true) end
        if !used_days_of_week.include?("Wednesday") then schedule_rule_new.setApplyWednesday(true) end
        if !used_days_of_week.include?("Thursday") then schedule_rule_new.setApplyThursday(true) end
        if !used_days_of_week.include?("Friday") then schedule_rule_new.setApplyFriday(true) end
        if !used_days_of_week.include?("Saturday") then schedule_rule_new.setApplySaturday(true) end
        if !used_days_of_week.include?("Sunday") then schedule_rule_new.setApplySunday(true) end
      end
    end

    if !indices_vector.include? -1 or replace_existing_default

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "#{schedule_ruleset.name} does not used the default profile, it will be replaced.")

      # reset values in default ScheduleDay
      old_default_schedule_day = schedule_ruleset.defaultDaySchedule
      old_default_schedule_day.clearValues

      # update selection to the most commonly used profile vs. the lowest priority, if it can be done without any conflicts
      # safe test is to see if any other rules use same days of week as most common,
      # if doesn't pass then make highest rule the new default to avoid any problems. School may not pass this test, woudl use last rule
      days_of_week_most_frequent_item = []
      schedule_rule_most_frequent = rule_vector[most_frequent_item]
      if schedule_rule_most_frequent.applyMonday then days_of_week_most_frequent_item << "Monday" end
      if schedule_rule_most_frequent.applyTuesday then days_of_week_most_frequent_item << "Tuesday" end
      if schedule_rule_most_frequent.applyWednesday then days_of_week_most_frequent_item << "Wednesday" end
      if schedule_rule_most_frequent.applyThursday then days_of_week_most_frequent_item << "Thursday" end
      if schedule_rule_most_frequent.applyFriday then days_of_week_most_frequent_item << "Friday" end
      if schedule_rule_most_frequent.applySaturday then days_of_week_most_frequent_item << "Saturday" end
      if schedule_rule_most_frequent.applySunday then days_of_week_most_frequent_item << "Sunday" end

      # loop through rules
      conflict_found = false
      rule_vector.each do |rule|
        next if rule == schedule_rule_most_frequent
        days_of_week_most_frequent_item.each do |day_of_week|
          if day_of_week == "Monday" and rule.applyMonday then conflict_found == true end
          if day_of_week == "Tuesday" and rule.applyTuesday then conflict_found == true end
          if day_of_week == "Wednesday" and rule.applyWednesday then conflict_found == true end
          if day_of_week == "Thursday" and rule.applyThursday then conflict_found == true end
          if day_of_week == "Friday" and rule.applyFriday then conflict_found == true end
          if day_of_week == "Saturday" and rule.applySaturday then conflict_found == true end
          if day_of_week == "Sunday" and rule.applySunday then conflict_found == true end
        end
      end
      if conflict_found
        new_default_index = indices_vector.max
      else
        new_default_index = most_frequent_item
      end

      # get values for new default profile
      new_default_daySchedule = rule_vector[new_default_index].daySchedule
      new_default_daySchedule_values = new_default_daySchedule.values
      new_default_daySchedule_times = new_default_daySchedule.times

      # update values and times for default profile
      for i in 0..(new_default_daySchedule_values.size - 1)
        old_default_schedule_day.addValue(new_default_daySchedule_times[i], new_default_daySchedule_values[i])
      end

      # remove rule object that has become the default. Also try to remove the ScheduleDay
      rule_vector[new_default_index].remove # this seems to also remove the ScheduleDay associated with the rule
    end

    return schedule_ruleset
  end

end

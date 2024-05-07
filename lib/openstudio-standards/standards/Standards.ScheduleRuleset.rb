class Standard
  # @!group ScheduleRuleset

  # Returns the min and max value for this schedule_day object
  #
  # @param day_sch [OpenStudio::Model::ScheduleDay] schedule day object
  # @return [Double] day full load hours
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
  # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
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
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', 'Year description is not specified. Full load hours calculation will assume 2009, the default year OS uses.')
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

  # Returns the min and max value in a design day (heating or cooling) from a ruleset schedule
  #
  # @author Weili Xu, PNNL.
  # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
  # @param type [String] 'winter' will enable the winter design day search, 'summer' enables summer design day search
  # @return [Hash] Hash has two keys, min and max.
  def schedule_ruleset_design_day_min_max_value(schedule_ruleset, type = 'winter')
    if type == 'winter'
      schedule = schedule_ruleset.winterDesignDaySchedule
    elsif type == 'summer'
      schedule = schedule_ruleset.summerDesignDaySchedule
    end

    if !schedule
      OpenStudio.logFree(OpenStudio::Warn, 'OpenStudio::Model::ScheduleRuleset', "#{schedule_ruleset.name} is missing #{type} design day schedule, use default day schedule to process the min max search")
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

    return { 'min' => min, 'max' => max }
  end

  # Returns the min and max value for this schedule.
  # It doesn't evaluate design days only run-period conditions
  #
  # @author David Goldwasser, NREL.
  # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
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

  # Returns the total number of hours where the schedule is greater than the specified value.
  #
  # @author Andrew Parker, NREL.
  # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
  # @param lower_limit [Double] the lower limit.  Values equal to the limit will not be counted.
  # @return [Double] The total number of hours this schedule is above the specified value.
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
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', 'Year description is not specified. Annual hours above value calculation will assume 2009, the default year OS uses.')
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
  # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
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
  # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
  # @return [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
  def schedule_ruleset_cleanup_profiles(schedule_ruleset)
    # set start and end dates
    year_description = schedule_ruleset.model.yearDescription.get
    year = year_description.assumedYear
    year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
    year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)

    indices_vector = schedule_ruleset.getActiveRuleIndices(year_start_date, year_end_date)
    most_frequent_item = indices_vector.uniq.max_by { |i| indices_vector.count(i) }
    rule_vector = schedule_ruleset.scheduleRules

    replace_existing_default = false
    if indices_vector.include? -1 && most_frequent_item != -1
      # clean up if default isn't most common (e.g. sunday vs. weekday)
      # if no existing rules cover specific days of week, make new rule from default covering those days of week
      possible_days_of_week = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
      used_days_of_week = []
      rule_vector.each do |rule|
        if rule.applyMonday then used_days_of_week << 'Monday' end
        if rule.applyTuesday then used_days_of_week << 'Tuesday' end
        if rule.applyWednesday then used_days_of_week << 'Wednesday' end
        if rule.applyThursday then used_days_of_week << 'Thursday' end
        if rule.applyFriday then used_days_of_week << 'Friday' end
        if rule.applySaturday then used_days_of_week << 'Saturday' end
        if rule.applySunday then used_days_of_week << 'Sunday' end
      end
      if used_days_of_week.uniq.size < possible_days_of_week.size
        replace_existing_default = true
        schedule_rule_new = OpenStudio::Model::ScheduleRule.new(schedule_ruleset, schedule_ruleset.defaultDaySchedule)
        if !used_days_of_week.include?('Monday') then schedule_rule_new.setApplyMonday(true) end
        if !used_days_of_week.include?('Tuesday') then schedule_rule_new.setApplyTuesday(true) end
        if !used_days_of_week.include?('Wednesday') then schedule_rule_new.setApplyWednesday(true) end
        if !used_days_of_week.include?('Thursday') then schedule_rule_new.setApplyThursday(true) end
        if !used_days_of_week.include?('Friday') then schedule_rule_new.setApplyFriday(true) end
        if !used_days_of_week.include?('Saturday') then schedule_rule_new.setApplySaturday(true) end
        if !used_days_of_week.include?('Sunday') then schedule_rule_new.setApplySunday(true) end
      end
    end

    if !indices_vector.include?(-1) || replace_existing_default

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "#{schedule_ruleset.name} does not used the default profile, it will be replaced.")

      # reset values in default ScheduleDay
      old_default_schedule_day = schedule_ruleset.defaultDaySchedule
      old_default_schedule_day.clearValues

      # update selection to the most commonly used profile vs. the lowest priority, if it can be done without any conflicts
      # safe test is to see if any other rules use same days of week as most common,
      # if doesn't pass then make highest rule the new default to avoid any problems. School may not pass this test, woudl use last rule
      days_of_week_most_frequent_item = []
      schedule_rule_most_frequent = rule_vector[most_frequent_item]
      if schedule_rule_most_frequent.applyMonday then days_of_week_most_frequent_item << 'Monday' end
      if schedule_rule_most_frequent.applyTuesday then days_of_week_most_frequent_item << 'Tuesday' end
      if schedule_rule_most_frequent.applyWednesday then days_of_week_most_frequent_item << 'Wednesday' end
      if schedule_rule_most_frequent.applyThursday then days_of_week_most_frequent_item << 'Thursday' end
      if schedule_rule_most_frequent.applyFriday then days_of_week_most_frequent_item << 'Friday' end
      if schedule_rule_most_frequent.applySaturday then days_of_week_most_frequent_item << 'Saturday' end
      if schedule_rule_most_frequent.applySunday then days_of_week_most_frequent_item << 'Sunday' end

      # loop through rules
      conflict_found = false
      rule_vector.each do |rule|
        next if rule == schedule_rule_most_frequent

        days_of_week_most_frequent_item.each do |day_of_week|
          if (day_of_week == 'Monday') && rule.applyMonday then conflict_found == true end
          if (day_of_week == 'Tuesday') && rule.applyTuesday then conflict_found == true end
          if (day_of_week == 'Wednesday') && rule.applyWednesday then conflict_found == true end
          if (day_of_week == 'Thursday') && rule.applyThursday then conflict_found == true end
          if (day_of_week == 'Friday') && rule.applyFriday then conflict_found == true end
          if (day_of_week == 'Saturday') && rule.applySaturday then conflict_found == true end
          if (day_of_week == 'Sunday') && rule.applySunday then conflict_found == true end
        end
      end
      if conflict_found
        new_default_index = indices_vector.max
      else
        new_default_index = most_frequent_item
      end

      # get values for new default profile
      new_default_day_schedule = rule_vector[new_default_index].daySchedule
      new_default_day_schedule_values = new_default_day_schedule.values
      new_default_day_schedule_times = new_default_day_schedule.times

      # update values and times for default profile
      for i in 0..(new_default_day_schedule_values.size - 1)
        old_default_schedule_day.addValue(new_default_day_schedule_times[i], new_default_day_schedule_values[i])
      end

      # remove rule object that has become the default. Also try to remove the ScheduleDay
      rule_vector[new_default_index].remove # this seems to also remove the ScheduleDay associated with the rule
    end

    return schedule_ruleset
  end

  # this will use parametric inputs contained in schedule and profiles along with inferred hours of operation to generate updated ruleset schedule profiles
  #
  # @author David Goldwasser
  # @param schedule [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
  # @param ramp_frequency [Double] ramp frequency in minutes
  # @param infer_hoo_for_non_assigned_objects [Boolean] attempt to get hoo for objects like swh with and exterior lighting
  # @param error_on_out_of_order [Boolean] true will error if applying formula creates out of order values
  # @return [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
  def schedule_apply_parametric_inputs(schedule, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order, parametric_inputs = nil)
    # Check if parametric inputs were supplied and generate them if not
    if parametric_inputs.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule.name}, no parametric inputs were not supplied so they will be generated now.")
      parametric_inputs = model_setup_parametric_schedules(schedule.model, gather_data_only: true)
    end

    # Check that parametric inputs exist for this schedule after generation
    if parametric_inputs[schedule].nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', "For #{schedule.name}, no parametric inputs exists so schedule will not be changed.")
      return schedule
    end

    # Check that an hours of operation schedule is associated with this schedule
    if parametric_inputs[schedule][:hoo_inputs].nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', "For #{schedule.name}, no associated hours of operation schedule was found so schedule will not be changed.")
      return schedule
    end

    # Get the hours of operation schedule
    hours_of_operation = parametric_inputs[schedule][:hoo_inputs]
    # OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.ScheduleRuleset', "For #{schedule.name} hours_of_operation = #{hours_of_operation.name}.")

    starting_aeflh = schedule_ruleset_annual_equivalent_full_load_hrs(schedule)

    # store floor and ceiling value
    val_flr = nil
    if schedule.hasAdditionalProperties && schedule.additionalProperties.hasFeature('param_sch_floor')
      val_flr = schedule.additionalProperties.getFeatureAsDouble('param_sch_floor').get
    end
    val_clg = nil
    if schedule.hasAdditionalProperties && schedule.additionalProperties.hasFeature('param_sch_ceiling')
      val_clg = schedule.additionalProperties.getFeatureAsDouble('param_sch_ceiling').get
    end

    # loop through schedule days from highest to lowest priority (with default as lowest priority)
    # if rule needs to be split to address hours of operation rules add new rule next to relevant existing rule
    profiles = {}
    schedule.scheduleRules.each do |rule|
      # remove any use manually generated non parametric rules or any auto-generated rules from prior application of formulas and hoo
      sch_day = rule.daySchedule
      if !sch_day.hasAdditionalProperties || !sch_day.additionalProperties.hasFeature('param_day_tag') || (sch_day.additionalProperties.getFeatureAsString('param_day_tag').get == 'autogen')
        sch_day.remove # remove day schedule for this rule
        rule.remove # remove the rule
      elsif !sch_day.additionalProperties.hasFeature('param_day_profile')
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', "#{schedule.name} doesn't have a parametric formula for #{rule.name} This profile will not be altered.")
        next
      else
        profiles[sch_day] = rule
      end
    end
    profiles[schedule.defaultDaySchedule] = nil

    # get indices for current schedule
    year_description = schedule.model.yearDescription.get
    year = year_description.assumedYear
    year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
    year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
    indices_vector = schedule.getActiveRuleIndices(year_start_date, year_end_date)

    # process profiles
    profiles.each do |sch_day, rule|
      # for current profile index identify hours of operation index that contains all days
      if rule.nil?
        current_rule_index = -1
      else
        current_rule_index = rule.ruleIndex
      end

      # loop through indices looking of rule in hoo that contains days in the rule
      hoo_target_index = nil
      days_used = []
      indices_vector.each_with_index do |profile_index, i|
        if profile_index == current_rule_index then days_used << i + 1 end
      end
      # find days_used in hoo profiles that contains all days used from this profile
      hoo_profile_match_hash = {}
      best_fit_check = {}
      hours_of_operation.each do |profile_index, value|
        days_for_rule_not_in_hoo_profile = days_used - value[:days_used]
        hoo_profile_match_hash[profile_index] = days_for_rule_not_in_hoo_profile
        best_fit_check[profile_index] = days_for_rule_not_in_hoo_profile.size
        if days_for_rule_not_in_hoo_profile.empty?
          hoo_target_index = profile_index
        end
      end
      clone_needed = false
      hoo_target_index = best_fit_check.key(best_fit_check.values.min)
      if best_fit_check[hoo_target_index] > 0
        clone_needed = true
      end

      # get hours of operation for this specific profile
      hoo_start = hours_of_operation[hoo_target_index][:hoo_start]
      hoo_end = hours_of_operation[hoo_target_index][:hoo_end]

      # update scheduleDay
      process_hrs_of_operation_hash(sch_day, hoo_start, hoo_end, val_flr, val_clg, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order)

      # clone new rule if needed
      if clone_needed

        # make list of new rules needed as has or array
        autogen_rules = {}
        days_to_fill = hoo_profile_match_hash[hoo_target_index]
        hours_of_operation.each do |profile_index, value|
          remainder = days_to_fill - value[:days_used]
          day_for_rule = days_to_fill - remainder
          if remainder.size < days_to_fill.size
            autogen_rules[profile_index] = { days_to_fill: day_for_rule, hoo_start: hoo_start, hoo_end: hoo_end }
          end
          days_to_fill = remainder
        end

        # loop through new rules to make and process
        autogen_rules.each do |autogen_rule, hash|
          # generate new rule
          sch_rule_autogen = OpenStudio::Model::ScheduleRule.new(schedule)
          if current_rule_index
            target_index = schedule.scheduleRules.size - 1 # just above default
          else
            target_index = current_rule_index - 1 # confirm just above orig rule
          end
          current_rule_index = target_index
          if rule.nil?
            sch_rule_autogen.setName("autogen #{schedule.name} #{target_index}")
          else
            sch_rule_autogen.setName("autogen #{rule.name} #{target_index}")
          end
          schedule.setScheduleRuleIndex(sch_rule_autogen, target_index)
          # @todo confirm this is higher priority than the non-auto-generated rule
          hash[:days_to_fill].each do |day|
            date = OpenStudio::Date.fromDayOfYear(day, year)
            sch_rule_autogen.addSpecificDate(date)
          end
          sch_rule_autogen.setApplySunday(true)
          sch_rule_autogen.setApplyMonday(true)
          sch_rule_autogen.setApplyTuesday(true)
          sch_rule_autogen.setApplyWednesday(true)
          sch_rule_autogen.setApplyThursday(true)
          sch_rule_autogen.setApplyFriday(true)
          sch_rule_autogen.setApplySaturday(true)

          # match profile from source rule (don't add time/values need a formula to process)
          sch_day_auto_gen = sch_rule_autogen.daySchedule
          sch_day_auto_gen.setName("#{sch_rule_autogen.name}_day_sch")
          sch_day_auto_gen.additionalProperties.setFeature('param_day_tag', 'autogen')
          val = sch_day.additionalProperties.getFeatureAsString('param_day_profile').get
          sch_day_auto_gen.additionalProperties.setFeature('param_day_profile', val)
          val = sch_day.additionalProperties.getFeatureAsString('param_day_secondary_logic').get
          sch_day_auto_gen.additionalProperties.setFeature('param_day_secondary_logic', val)
          val = sch_day.additionalProperties.getFeatureAsString('param_day_secondary_logic_arg_val').get
          sch_day_auto_gen.additionalProperties.setFeature('param_day_secondary_logic_arg_val', val)

          # get hours of operation for this specific profile
          hoo_start = hash[:hoo_start]
          hoo_end = hash[:hoo_end]

          # process new rule
          process_hrs_of_operation_hash(sch_day_auto_gen, hoo_start, hoo_end, val_flr, val_clg, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order)
        end

      end
    end

    # @todo create summer and winter design day profiles (make sure scheduleDay objects parametric)
    # @todo should they have their own formula, or should this be hard coded logic by schedule type

    # check orig vs. updated aeflh
    final_aeflh = schedule_ruleset_annual_equivalent_full_load_hrs(schedule)
    percent_change = ((starting_aeflh - final_aeflh) / starting_aeflh) * 100.0
    if percent_change.abs > 0.05
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule.name}, applying parametric schedules made a #{percent_change.round(1)}% change in annual equivalent full load hours. (from #{starting_aeflh.round(2)} to #{final_aeflh.round(2)})")
    end

    return schedule
  end

  # Apply specified hours of operation values to rules in this schedule.
  # Weekday values will be applied to the default profile.
  # Weekday values will be applied to any rules that are used on a weekday.
  # Saturday values will be applied to any rules that are used on a Saturday.
  # Sunday values will be applied to any rules that are used on a Sunday.
  # If a rule applies to Weekdays, Saturdays, and/or Sundays, values will be applied in that order of precedence.
  # If a rule does not apply to any of these days, it is unused and will not be modified.
  #
  # @param schedule_ruleset [OpenStudio::Model::ScheduleRuleset] schedule ruleset object
  # @param wkdy_start_time [OpenStudio::Time] Weekday start time. If nil, no change will be made to this day.
  # @param wkdy_end_time [OpenStudio::Time] Weekday end time.  If greater than 24:00, hours of operation will wrap over midnight.
  # @param sat_start_time [OpenStudio::Time] Saturday start time. If nil, no change will be made to this day.
  # @param sat_end_time [OpenStudio::Time] Saturday end time.  If greater than 24:00, hours of operation will wrap over midnight.
  # @param sun_start_time [OpenStudio::Time] Sunday start time.  If nil, no change will be made to this day.
  # @param sun_end_time [OpenStudio::Time] Sunday end time.  If greater than 24:00, hours of operation will wrap over midnight.
  # @return [Boolean] returns true if successful, false if not
  def schedule_ruleset_set_hours_of_operation(schedule_ruleset, wkdy_start_time: nil, wkdy_end_time: nil, sat_start_time: nil, sat_end_time: nil, sun_start_time: nil, sun_end_time: nil)
    # Default day is assumed to represent weekdays
    if wkdy_start_time && wkdy_end_time
      schedule_day_set_hours_of_operation(schedule_ruleset.defaultDaySchedule, wkdy_start_time, wkdy_end_time)
      # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, set default operating hours to #{wkdy_start_time}-#{wkdy_end_time}.")
    end

    # Modify each rule
    schedule_ruleset.scheduleRules.each do |rule|
      if rule.applyMonday || rule.applyTuesday || rule.applyWednesday || rule.applyThursday || rule.applyFriday
        if wkdy_start_time && wkdy_end_time
          schedule_day_set_hours_of_operation(rule.daySchedule, wkdy_start_time, wkdy_end_time)
          # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, set Saturday rule operating hours to #{wkdy_start_time}-#{wkdy_end_time}.")
        end
      elsif rule.applySaturday
        if sat_start_time && sat_end_time
          schedule_day_set_hours_of_operation(rule.daySchedule, sat_start_time, sat_end_time)
          # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, set Saturday rule operating hours to #{sat_start_time}-#{sat_end_time}.")
        end
      elsif rule.applySunday
        if sun_start_time && sun_end_time
          schedule_day_set_hours_of_operation(rule.daySchedule, sun_start_time, sun_end_time)
          # OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{schedule_ruleset.name}, set Sunday rule operating hours to #{sun_start_time}-#{sun_end_time}.")
        end
      end
    end

    return true
  end

  #
  # Return Array of weekday values from Array of all day values
  # @author Xuechen (Jerry) Lei, PNNL
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param values [Array] hourly time-series values of all days
  # @param value_includes_holiday [Boolean] whether the input values include a day of holiday at the end of the array
  #
  # @return [Array] hourly time-series values in weekdays
  #
  def get_weekday_values_from_8760(model, values, value_includes_holiday = true)
    start_day = model.getYearDescription.dayofWeekforStartDay
    start_day_map = {
      'Sunday' => 0,
      'Monday' => 1,
      'Tuesday' => 2,
      'Wednesday' => 3,
      'Thursday' => 4,
      'Friday' => 5,
      'Saturday' => 6
    }
    start_day_num = start_day_map[start_day]
    weekday_values = []
    day_of_week = start_day_num
    num_of_days = values.size / 24
    if value_includes_holiday
      num_of_days -= 1
    end

    for day_i in 1..num_of_days do
      if day_of_week >= 1 && day_of_week <= 5
        weekday_values += values.slice!(0, 24)
      end
      day_of_week += 1
      # reset day of week
      if day_of_week == 7
        day_of_week = 0
      end
    end

    return weekday_values
  end

  # Create a sequential array of values from a ScheduleReset object
  # Will actually include 24 extra values if model year is a leap year
  # Will also include 24 values at end of array representing the holiday day schedule
  # Intended use is for storing fan schedules to hash of ZoneName:SchedArray so schedules
  # can be saved when HVAC objects are deleted
  # @author Doug Maddox, PNNL
  # @param [object] model
  # @param [Object] schedule_ruleset
  # @return [Array<Double>] Array of sequential hourly values for year + 24 hours at end for holiday
  def get_8760_values_from_schedule_ruleset(model, schedule_ruleset)
    yd = model.getYearDescription
    start_date = yd.makeDate(1, 1)
    end_date = yd.makeDate(12, 31)

    day_of_week = start_date.dayOfWeek.valueName

    values = OpenStudio::DoubleVector.new
    day = OpenStudio::Time.new(1.0)
    interval = OpenStudio::Time.new(1.0 / 24.0)
    day_schedules = schedule_ruleset.to_ScheduleRuleset.get.getDaySchedules(start_date, end_date)

    numdays = day_schedules.size

    # Get holiday schedule and append to end of values array
    day_schedule_holiday = nil
    schedule_ruleset.to_ScheduleRuleset.get.scheduleRules.each do |week_rule|
      # If a holiday day type is defined, then store the schedule object for the first occurrence
      # For now this is not implemented into the 8760 array
      # if week_rule.applyHoliday
      #  day_schedule_holiday = week_rule.daySchedule
      #  break
      # end
    end
    if day_schedule_holiday.nil?
      day_schedule_holiday = schedule_ruleset.to_ScheduleRuleset.get.defaultDaySchedule
    end
    # Currently holidaySchedule is not working in SDK in ScheduleRuleset object
    # @todo enable the following lines when holidaySchedule is available
    # if !schedule_ruleset.isHolidayScheduleDefaulted
    #   day_schedule = schedule_ruleset.to_ScheduleRuleset.get.holidaySchedule
    # else
    #  day_schedule = schedule_ruleset.to_ScheduleRuleset.get.defaultSchedule
    # end

    # Make new array of day schedules for year, and add holiday day schedule to end
    day_sched_array = []
    day_schedules.each do |day_schedule|
      day_sched_array << day_schedule
    end

    day_sched_array << day_schedule_holiday
    numdays = day_schedules.size

    day_sched_array.each do |day_schedule|
      current_hour = interval
      time_values = day_schedule.times
      num_times = time_values.size
      value_sum = 0
      value_count = 0
      time_values.each do |until_hr|
        if until_hr < current_hour
          # Add to tally for next hour average
          value_sum += day_schedule.getValue(until_hr).to_f
          value_count += 1
        elsif until_hr >= current_hour + interval
          # Loop through hours to catch current hour up to until_hr
          while current_hour <= until_hr
            values << day_schedule.getValue(until_hr).to_f
            current_hour += interval
          end

          if (current_hour - until_hr) < interval
            # This means until_hr is not an even hour break
            # i.e. there is a sub-hour time step
            # Increment the sum for averaging
            value_sum += day_schedule.getValue(until_hr).to_f
            value_count += 1
          end

        else
          # Add to tally for this hour average
          value_sum += day_schedule.getValue(until_hr).to_f
          value_count += 1
          # Calc hour average
          if value_count > 0
            value_avg = value_sum / value_count
          else
            value_avg = 0
          end
          values << value_avg
          # setup for next hour
          value_sum = 0
          value_count = 0
          current_hour += interval
        end
      end
    end

    return values
  end

  # Create a ScheduleRuleset object from an 8760 sequential array of values for a
  # Values array will actually include 24 extra values if model year is a leap year
  # Values array will also include 24 values at end of array representing the holiday day schedule
  # @author Doug Maddox, PNNL
  # @param model [Object]
  # @param values [Array<Double>] array of annual values (8760 +/ 24) + holiday values (24)
  # @param sch_name [String] name of schedule to be created
  # @param sch_type_limits [Object] ScheduleTypeLimits object
  # @return [Object] ScheduleRuleset
  def make_ruleset_sched_from_8760(model, values, sch_name, sch_type_limits)
    # Build array of arrays: each top element is a week, each sub element is an hour of week
    all_week_values = []
    hr_of_yr = -1
    (0..51).each do |iweek|
      week_values = []
      (0..167).each do |hr_of_wk|
        hr_of_yr += 1
        week_values[hr_of_wk] = values[hr_of_yr]
      end
      all_week_values << week_values
    end

    # Extra week for days 365 and 366 (if applicable) of year
    # since 52 weeks is 364 days
    hr_of_yr += 1
    last_hr = values.size - 1
    iweek = 52
    week_values = []
    hr_of_wk = -1
    (hr_of_yr..last_hr).each do |ihr_of_yr|
      hr_of_wk += 1
      week_values[hr_of_wk] = values[ihr_of_yr]
    end
    all_week_values << week_values

    # Build ruleset schedules for first week
    yd = model.getYearDescription
    start_date = yd.makeDate(1, 1)
    one_day = OpenStudio::Time.new(1.0)
    seven_days = OpenStudio::Time.new(7.0)
    end_date = start_date + seven_days - one_day

    # Create new ruleset schedule
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    sch_ruleset.setName(sch_name)
    sch_ruleset.setScheduleTypeLimits(sch_type_limits)

    # Make week schedule for first week
    num_week_scheds = 1
    week_sch_name = sch_name + '_ws' + num_week_scheds.to_s
    week_1_rules = make_week_ruleset_sched_from_168(model, sch_ruleset, all_week_values[1], start_date, end_date, week_sch_name)
    week_n_rules = week_1_rules
    all_week_rules = []
    all_week_rules << week_1_rules
    iweek_previous_week_rule = 0

    # temporary loop for debugging
    week_n_rules.each do |sch_rule|
      day_rule = sch_rule.daySchedule
      xtest = 1
    end

    # For each subsequent week, check if it is same as previous
    # If same, then append to Schedule:Rule of previous week
    # If different, then create new Schedule:Rule
    (1..51).each do |iweek|
      is_a_match = true
      start_date = end_date + one_day
      end_date += seven_days
      (0..167).each do |ihr|
        if all_week_values[iweek][ihr] != all_week_values[iweek_previous_week_rule][ihr]
          is_a_match = false
          break
        end
      end
      if is_a_match
        # Update the end date for the Rules of the previous week to include this week
        all_week_rules[iweek_previous_week_rule].each do |sch_rule|
          sch_rule.setEndDate(end_date)
        end
      else
        # Create a new week schedule for this week
        num_week_scheds += 1
        week_sch_name = sch_name + '_ws' + num_week_scheds.to_s
        week_n_rules = make_week_ruleset_sched_from_168(model, sch_ruleset, all_week_values[iweek], start_date, end_date, week_sch_name)
        all_week_rules << week_n_rules
        # Set this week as the reference for subsequent weeks
        iweek_previous_week_rule = iweek
      end
    end

    # temporary loop for debugging
    week_n_rules.each do |sch_rule|
      day_rule = sch_rule.daySchedule
      xtest = 1
    end

    # Need to handle week 52 with days 365 and 366
    # For each of these days, check if it matches a day from the previous week
    iweek = 52
    # First handle day 365
    end_date += one_day
    start_date = end_date
    match_was_found = false
    # week_n is the previous week
    week_n_rules.each do |sch_rule|
      day_rule = sch_rule.daySchedule
      is_match = true
      # Need a 24 hour array of values for the day rule
      ihr_start = 0
      day_values = []
      day_rule.times.each do |time|
        now_value = day_rule.getValue(time).to_f
        until_ihr = time.totalHours.to_i - 1
        (ihr_start..until_ihr).each do |ihr|
          day_values << now_value
        end
      end
      (0..23).each do |ihr|
        if day_values[ihr] != all_week_values[iweek][ihr + ihr_start]
          # not matching for this day_rule
          is_match = false
          break
        end
      end
      if is_match
        match_was_found = true
        # Extend the schedule period to include this day
        sch_rule.setEndDate(end_date)
        break
      end
    end
    if match_was_found == false
      # Need to add a new rule
      day_of_week = start_date.dayOfWeek.valueName
      day_names = [day_of_week]
      day_sch_name = sch_name + '_Day_365'
      day_sch_values = []
      (0..23).each do |ihr|
        day_sch_values << all_week_values[iweek][ihr]
      end
      # sch_rule is a sub-component of the ScheduleRuleset
      sch_rule = add_one_ruleset_sch_rule(model, sch_ruleset, start_date, end_date, day_sch_values, day_sch_name, day_names)
      week_n_rules = sch_rule
    end

    # Handle day 366, if leap year
    # Last day in this week is the holiday schedule
    # If there are three days in this week, then the second is day 366
    if all_week_values[iweek].size == 24 * 3
      ihr_start = 23
      end_date += one_day
      start_date = end_date
      match_was_found = false
      # week_n is the previous week
      # which would be the week based on day 356, if that was its own week
      week_n_rules.each do |sch_rule|
        day_rule = sch_rule.daySchedule
        is_match = true
        day_rule.times.each do |ihr|
          if day_rule.getValue(ihr).to_f != all_week_values[iweek][ihr + ihr_start]
            # not matching for this day_rule
            is_match = false
            break
          end
        end
        if is_match
          match_was_found = true
          # Extend the schedule period to include this day
          sch_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_date.month.to_i), end_date.day.to_i))
          break
        end
      end
      if match_was_found == false
        # Need to add a new rule
        # sch_rule is a sub-component of the ScheduleRuleset

        day_of_week = start_date.dayOfWeek.valueName
        day_names = [day_of_week]
        day_sch_name = sch_name + '_Day_366'
        day_sch_values = []
        (0..23).each do |ihr|
          day_sch_values << all_week_values[iweek][ihr]
        end
        sch_rule = add_one_ruleset_sch_rule(model, sch_ruleset, start_date, end_date, day_sch_values, day_sch_name, day_names)
        week_n_rules = sch_rule
      end

      # Last day in values array is the holiday schedule
      # @todo add holiday schedule when implemented in OpenStudio SDK
    end

    # Need to handle design days
    # Find schedule with the most operating hours in a day,
    # and apply that to both cooling and heating design days
    hr_of_yr = -1
    max_eflh = 0
    ihr_max = -1
    (0..364).each do |iday|
      eflh = 0
      ihr_start = hr_of_yr + 1
      (0..23).each do |ihr|
        hr_of_yr += 1
        eflh += 1 if values[hr_of_yr] > 0
      end
      if eflh > max_eflh
        max_eflh = eflh
        # store index to first hour of day with max on hours
        ihr_max = ihr_start
      end
    end
    # Create the schedules for the design days
    day_sch = OpenStudio::Model::ScheduleDay.new(model)
    day_sch.setName(sch_name + 'Winter Design Day')
    (0..23).each do |ihr|
      hr_of_yr = ihr_max + ihr
      next if values[hr_of_yr] == values[hr_of_yr + 1]

      day_sch.addValue(OpenStudio::Time.new(0, ihr + 1, 0, 0), values[hr_of_yr])
    end
    sch_ruleset.setWinterDesignDaySchedule(day_sch)

    day_sch = OpenStudio::Model::ScheduleDay.new(model)
    day_sch.setName(sch_name + 'Summer Design Day')
    (0..23).each do |ihr|
      hr_of_yr = ihr_max + ihr
      next if values[hr_of_yr] == values[hr_of_yr + 1]

      day_sch.addValue(OpenStudio::Time.new(0, ihr + 1, 0, 0), values[hr_of_yr])
    end
    sch_ruleset.setSummerDesignDaySchedule(day_sch)

    return sch_ruleset
  end

  # Create a ScheduleRules object from an hourly array of values for a week
  # @author Doug Maddox, PNNL
  # @param model [Object]
  # @param sch_ruleset [Object] ScheduleRuleset object
  # @param values [Array<Double>] array of hourly values for week (168)
  # @param start_date [Date] start date of week period
  # @param end_date [Date] end date of week period
  # @param sch_name [String] name of parent ScheduleRuleset object
  # @return [Array<Object>] array of ScheduleRules objects
  def make_week_ruleset_sched_from_168(model, sch_ruleset, values, start_date, end_date, sch_name)
    one_day = OpenStudio::Time.new(1.0)
    now_date = start_date - one_day
    days_of_week = []
    values_by_day = []
    # Organize data into days
    # create a 2-D array values_by_day[iday][ihr]
    hr_of_wk = -1
    (0..6).each do |iday|
      hr_values = []
      (0..23).each do |hr_of_day|
        hr_of_wk += 1
        hr_values << values[hr_of_wk]
      end
      values_by_day << hr_values
      now_date += one_day
      days_of_week << now_date.dayOfWeek.valueName
    end

    # Make list of unique day schedules
    # First one is automatically unique
    # Store indexes to days with the same sched in array of arrays
    # day_sched_idays[0] << 0
    day_sched = {}
    day_sched['day_idx_list'] = [0]
    day_sched['hr_values'] = values_by_day[0]
    day_scheds = []
    day_scheds << day_sched

    # Check each day with the cumulative list of day_scheds and add new, if unique
    (1..6).each do |iday|
      match_was_found = false
      day_scheds.each do |day_sched|
        # Compare each jday to the current iday and check for a match
        is_a_match = true
        (0..23).each do |ihr|
          if day_sched['hr_values'][ihr] != values_by_day[iday][ihr]
            # this hour is not a match
            is_a_match = false
            break
          end
        end
        if is_a_match
          # Add the day index to the list for this day_sched
          day_sched['day_idx_list'] << iday
          match_was_found = true
          break
        end
      end
      if match_was_found == false
        # Add a new day type
        day_sched = {}
        day_sched['day_idx_list'] = [iday]
        day_sched['hr_values'] = values_by_day[iday]
        day_scheds << day_sched
      end
    end

    # Add the Rule and Day objects
    sch_rules = []
    iday_sch = 0
    day_scheds.each do |day_sched|
      iday_sch += 1

      day_names = []
      day_sched['day_idx_list'].each do |idx|
        day_names << days_of_week[idx]
      end
      day_sch_name = "#{sch_name} Day #{iday_sch}"
      day_sch_values = day_sched['hr_values']
      sch_rule = add_one_ruleset_sch_rule(model, sch_ruleset, start_date, end_date, day_sch_values, day_sch_name, day_names)

      sch_rules << sch_rule
    end

    return sch_rules
  end

  # Create a ScheduleRules object from an hourly array of values for a week
  # @author Doug Maddox, PNNL
  # @param model [Object]
  # @param sch_ruleset [Object] ScheduleRuleset object
  # @param values [Array<Double>] array of hourly values for day (24)
  # @param start_date [Date] start date of week period
  # @param end_date [Date] end date of week period
  # @param sch_name [String] name of ScheduleDay object
  # @param day_names [Array<String>] list of days of week for which this day type is applicable
  # @return [Object] ScheduleDay object
  def add_one_ruleset_sch_rule(model, sch_ruleset, start_date, end_date, values, sch_name, day_names)
    # sch_rule is a sub-component of the ScheduleRuleset
    sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
    # Set the dates when the rule applies
    sch_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_date.monthOfYear.value.to_i), start_date.dayOfMonth.to_i))
    sch_rule.setStartDate(start_date)
    sch_rule.setEndDate(end_date)

    # Set the days for which the rule applies
    day_names.each do |day_of_week|
      sch_rule.setApplySunday(true) if day_of_week == 'Sunday'
      sch_rule.setApplyMonday(true) if day_of_week == 'Monday'
      sch_rule.setApplyTuesday(true) if day_of_week == 'Tuesday'
      sch_rule.setApplyWednesday(true) if day_of_week == 'Wednesday'
      sch_rule.setApplyThursday(true) if day_of_week == 'Thursday'
      sch_rule.setApplyFriday(true) if day_of_week == 'Friday'
      sch_rule.setApplySaturday(true) if day_of_week == 'Saturday'
    end

    # Create the day schedule and add hourly values
    day_sch = sch_rule.daySchedule
    # day_sch = OpenStudio::Model::ScheduleDay.new(model)
    day_sch.setName(sch_name)
    (0..23).each do |ihr|
      next if values[ihr] == values[ihr + 1]

      day_sch.addValue(OpenStudio::Time.new(0, ihr + 1, 0, 0), values[ihr])
    end

    return sch_rule
  end

  private

  # Set the hours of operation (0 or 1) for a ScheduleDay.
  # Clears out existing time/value pairs and sets to supplied values.
  #
  # @author Andrew Parker
  # @param schedule_day [OpenStudio::Model::ScheduleDay] The day schedule to set.
  # @param start_time [OpenStudio::Time] Start time.
  # @param end_time [OpenStudio::Time] End time.  If greater than 24:00, hours of operation will wrap over midnight.
  #
  # @return [Void]
  # @api private
  def schedule_day_set_hours_of_operation(schedule_day, start_time, end_time)
    schedule_day.clearValues
    twenty_four_hours = OpenStudio::Time.new(0, 24, 0, 0)
    if end_time < twenty_four_hours
      # Operating hours don't wrap over midnight
      schedule_day.addValue(start_time, 0) # 0 until start time
      schedule_day.addValue(end_time, 1) # 1 from start time until end time
      schedule_day.addValue(twenty_four_hours, 0) # 0 after end time
    else
      # Operating hours start on previous day
      schedule_day.addValue(end_time - twenty_four_hours, 1) # 1 for hours started on the previous day
      schedule_day.addValue(start_time, 0) # 0 from end of previous days hours until start of today's
      schedule_day.addValue(twenty_four_hours, 1) # 1 from start of today's hours until midnight
    end
  end

  # process individual schedule profiles
  #
  # @author David Goldwasser
  # @param sch_day [OpenStudio::Model::ScheduleDay] schedule day object
  # @param hoo_start [Double] hours of operation start
  # @param hoo_end [Double] hours of operation end
  # @param val_flr [Double] value floor
  # @param val_clg [Double] value ceiling
  # @param ramp_frequency [Double] ramp frequency in minutes
  # @param infer_hoo_for_non_assigned_objects [Boolean] attempt to get hoo for objects like swh with and exterior lighting
  # @param error_on_out_of_order [Boolean] true will error if applying formula creates out of order values
  # @return [OpenStudio::Model::ScheduleDay] schedule day
  # @api private
  def process_hrs_of_operation_hash(sch_day, hoo_start, hoo_end, val_flr, val_clg, ramp_frequency, infer_hoo_for_non_assigned_objects, error_on_out_of_order)
    # process hoo and floor/ceiling vars to develop formulas without variables
    formula_string = sch_day.additionalProperties.getFeatureAsString('param_day_profile').get
    formula_hash = {}
    formula_string.split('|').each do |time_val_valopt|
      a1 = time_val_valopt.to_s.split('~')
      time = a1[0]
      value_array = a1.drop(1)
      formula_hash[time] = value_array
    end

    # setup additional variables
    if hoo_end >= hoo_start
      occ = hoo_end - hoo_start
    else
      occ = 24.0 + hoo_end - hoo_start
    end
    vac = 24.0 - occ
    range = val_clg - val_flr

    # apply variables and create updated hash with only numbers
    formula_hash_var_free = {}
    formula_hash.each do |time, val_in_out|
      # replace time variables with value
      time = time.gsub('hoo_start', hoo_start.to_s)
      time = time.gsub('hoo_end', hoo_end.to_s)
      time = time.gsub('occ', occ.to_s)
      # can save special variables like lunch or break using this logic
      time = time.gsub('mid', (hoo_start + occ * 0.5).to_s)
      time = time.gsub('vac', vac.to_s)
      begin
        time_float = eval(time)
        if time_float.to_i.to_s == time_float.to_s || time_float.to_f.to_s == time_float.to_s # check to see if numeric
          time_float = time_float.to_f
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleRuleset', "Time formula #{time} for #{sch_day.name} is invalid. It can't be converted to a float.")
        end
      rescue SyntaxError => e
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleRuleset', "Time formula #{time} for #{sch_day.name} is invalid. It can't be evaluated.")
      end

      # replace variables in array of values
      val_in_out_float = []
      val_in_out.each do |val|
        # replace variables for values
        val = val.gsub('val_flr', val_flr.to_s)
        val = val.gsub('val_clg', val_clg.to_s)
        val = val.gsub('val_range', range.to_s) # will expect a fractional value and will scale within ceiling and floor
        begin
          val_float = eval(val)
          if val_float.to_i.to_s == val_float.to_s || val_float.to_f.to_s == val_float.to_s # check to see if numeric
            val_float = val_float.to_f
          else
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleRuleset', "Value formula #{val_float} for #{sch_day.name} is invalid. It can't be converted to a float.")
          end
        rescue SyntaxError => e
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleRuleset', "Time formula #{val_float} for #{sch_day.name} is invalid. It can't be evaluated.")
        end
        val_in_out_float << val_float
      end

      # update hash
      formula_hash_var_free[time_float] = val_in_out_float
    end

    # this is old variable used in loop, just combining for now to avoid refactor, may change this later
    time_value_pairs = []
    formula_hash_var_free.each do |time, val_in_out|
      val_in_out.each do |val|
        time_value_pairs << [time, val]
      end
    end

    # re-order so first value is lowest, and last is highest (need to adjust so no negative or > 24 values first)
    neg_time_hash = {}
    temp_min_time_hash = {}
    time_value_pairs.each_with_index do |pair, i|
      # if value  24 add it to 24 so it will go on tail end of profile
      # case when value is greater than 24 can be left alone for now, will be addressed
      if pair[0] < 0.0
        neg_time_hash[i] = pair[0]
        time = pair[0] + 24.0
        time_value_pairs[i][0] = time
      else
        time = pair[0]
      end
      temp_min_time_hash[i] = pair[0]
    end
    time_value_pairs.rotate!(temp_min_time_hash.key(temp_min_time_hash.values.min))

    # validate order, issue warning and correct if out of order
    last_time = nil
    throw_order_warning = false
    pre_fix_time_value_pairs = time_value_pairs.to_s
    time_value_pairs.each_with_index do |time_value_pair, i|
      if last_time.nil?
        last_time = time_value_pair[0]
      elsif time_value_pair[0] < last_time || neg_time_hash.key?(i)

        # @todo it doesn't actually stop here now
        if error_on_out_of_order
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ScheduleRuleset', "Pre-interpolated processed hash for #{sch_day.name} has one or more out of order conflicts: #{pre_fix_time_value_pairs}. Method will stop because Error on Out of Order was set to true.")
        end

        if neg_time_hash.key?(i)
          orig_current_time = time_value_pair[0]
          updated_time = 0.0
          last_buffer = 'NA'
        else
          # pick midpoint and put each time there. e.g. times of (2,7,9,8,11) would be changed to  (2,7,8.5,8.5,11)
          delta = last_time - time_value_pair[0]

          # determine much space last item can move
          if i < 2
            last_buffer = time_value_pairs[i - 1][0] # can move down to 0 without any issues
          else
            last_buffer = time_value_pairs[i - 1][0] - time_value_pairs[i - 2][0]
          end

          # center if possible but don't exceed available buffer
          updated_time = time_value_pairs[i - 1][0] - [delta / 2.0, last_buffer].min
        end

        # update values in array
        orig_current_time = time_value_pair[0]
        time_value_pairs[i - 1][0] = updated_time
        time_value_pairs[i][0] = updated_time

        # reporting mostly for diagnostic purposes
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ScheduleRuleset', "For #{sch_day.name} profile item #{i} time was #{last_time} and item #{i + 1} time was #{orig_current_time}. Last buffer is #{last_buffer}. Changing both times to #{updated_time}.")

        last_time = updated_time
        throw_order_warning = true

      else
        last_time = time_value_pair[0]
      end
    end

    # issue warning if order was changed
    if throw_order_warning
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ScheduleRuleset', "Pre-interpolated processed hash for #{sch_day.name} has one or more out of order conflicts: #{pre_fix_time_value_pairs}. Time values were adjusted as shown to crate a valid profile: #{time_value_pairs}")
    end

    # add interpolated values at ramp_frequency
    time_value_pairs.each_with_index do |time_value_pair, i|
      # store current and next time and value
      current_time = time_value_pair[0]
      current_value = time_value_pair[1]
      if i + 1 < time_value_pairs.size
        next_time = time_value_pairs[i + 1][0]
        next_value = time_value_pairs[i + 1][1]
      else
        # use time and value of first item
        next_time = time_value_pairs[0][0] + 24 # need to adjust values for beginning of array
        next_value = time_value_pairs[0][1]
      end
      step_delta = next_time - current_time

      # skip if time between values is 0 or less than ramp frequency
      next if step_delta <= ramp_frequency

      # skip if next value is same
      next if current_value == next_value

      # add interpolated value to array
      interpolated_time = current_time + ramp_frequency
      interpolated_value = next_value * (interpolated_time - current_time) / step_delta + current_value * (next_time - interpolated_time) / step_delta
      time_value_pairs.insert(i + 1, [interpolated_time, interpolated_value])
    end

    # remove second instance of time when there are two
    time_values_used = []
    items_to_remove = []
    time_value_pairs.each_with_index do |time_value_pair, i|
      if time_values_used.include? time_value_pair[0]
        items_to_remove << i
      else
        time_values_used << time_value_pair[0]
      end
    end
    items_to_remove.reverse.each do |i|
      time_value_pairs.delete_at(i)
    end

    # if time is > 24 shift to front of array and adjust value
    rotate_steps = 0
    time_value_pairs.reverse.each_with_index do |time_value_pair, i|
      if time_value_pair[0] > 24
        rotate_steps -= 1
        time_value_pair[0] -= 24
      else
        next
      end
    end
    time_value_pairs.rotate!(rotate_steps)

    # add a 24 on the end of array that matches the first value
    if time_value_pairs.last[0] != 24.0
      time_value_pairs << [24.0, time_value_pairs.first[1]]
    end

    # reset scheduleDay values based on interpolated values
    sch_day.clearValues
    time_value_pairs.each do |time_val|
      hour = time_val.first.floor
      min = ((time_val.first - hour) * 60.0).floor
      os_time = OpenStudio::Time.new(0, hour, min, 0)
      value = time_val.last
      sch_day.addValue(os_time, value)
    end
    # @todo apply secondary logic

    # Tell EnergyPlus to interpolate schedules to timestep so that it doesn't have to be done in this code
    sch_day.setInterpolatetoTimestep('Average')

    return sch_day
  end
end

class Standard
  # @!group ScheduleRuleset


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
      sch_rule = OpenstudioStandards::Schedules.schedule_ruleset_add_rule(sch_ruleset, day_sch_values,
                                                                          start_date: start_date,
                                                                          end_date: end_date,
                                                                          day_names: day_names,
                                                                          rule_name: day_sch_name)
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
        sch_rule = OpenstudioStandards::Schedules.schedule_ruleset_add_rule(sch_ruleset, day_sch_values,
                                                                            start_date: start_date,
                                                                            end_date: end_date,
                                                                            day_names: day_names,
                                                                            rule_name: day_sch_name)
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
      sch_rule = OpenstudioStandards::Schedules.schedule_ruleset_add_rule(sch_ruleset, day_sch_values,
                                                                          start_date: start_date,
                                                                          end_date: end_date,
                                                                          day_names: day_names,
                                                                          rule_name: day_sch_name)
      sch_rules << sch_rule
    end

    return sch_rules
  end

  private



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
    # sch_day.setInterpolatetoTimestep(true)

    return sch_day
  end
end

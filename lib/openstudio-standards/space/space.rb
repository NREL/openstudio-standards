# Methods to obtain information about model spaces
module OpenstudioStandards
  module Space
    # @!group Space

    # Determine if the space is a plenum.
    # Assume it is a plenum if it is a supply or return plenum for an AirLoop,
    # if it is not part of the total floor area,
    # or if the space type name contains the word plenum.
    #
    # @param space [OpenStudio::Model::Space] space object
    # return [Boolean] returns true if plenum, false if not
    def self.space_plenum?(space)
      plenum_status = false

      # Check if it is designated
      # as not part of the building
      # floor area.  This method internally
      # also checks to see if the space's zone
      # is a supply or return plenum
      unless space.partofTotalFloorArea
        plenum_status = true
        return plenum_status
      end

      # @todo update to check if it has internal loads

      # Check if the space type name
      # contains the word plenum.
      space_type = space.spaceType
      if space_type.is_initialized
        space_type = space_type.get
        if space_type.name.get.to_s.downcase.include?('plenum')
          plenum_status = true
          return plenum_status
        end
        if space_type.standardsSpaceType.is_initialized
          if space_type.standardsSpaceType.get.downcase.include?('plenum')
            plenum_status = true
            return plenum_status
          end
        end
      end

      return plenum_status
    end

    # Determine if the space is residential based on the space type properties for the space.
    # For spaces with no space type, assume nonresidential.
    # For spaces that are plenums, base the decision on the space
    # type of the space below the largest floor in the plenum.
    #
    # @param space [OpenStudio::Model::Space] space object
    # return [Boolean] true if residential, false if nonresidential
    def self.space_residential?(space)
      is_res = false

      space_to_check = space

      # If this space is a plenum, check the space type
      # of the space below the largest floor in the space
      if space_plenum?(space)
        # Find the largest floor
        largest_floor_area = 0.0
        largest_surface = nil
        space.surfaces.each do |surface|
          next unless surface.surfaceType == 'Floor' && surface.outsideBoundaryCondition == 'Surface'

          if surface.grossArea > largest_floor_area
            largest_floor_area = surface.grossArea
            largest_surface = surface
          end
        end
        if largest_surface.nil?
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} is a plenum, but could not find a floor with a space below it to determine if plenum should be  res or nonres.  Assuming nonresidential.")
          return is_res
        end
        # Get the space on the other side of this floor
        if largest_surface.adjacentSurface.is_initialized
          adj_surface = largest_surface.adjacentSurface.get
          if adj_surface.space.is_initialized
            space_to_check = adj_surface.space.get
          else
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} is a plenum, but could not find a space attached to the largest floor's adjacent surface #{adj_surface.name} to determine if plenum should be res or nonres.  Assuming nonresidential.")
            return is_res
          end
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} is a plenum, but could not find a floor with a space below it to determine if plenum should be  res or nonres.  Assuming nonresidential.")
          return is_res
        end
      end

      space_type = space_to_check.spaceType
      if space_type.is_initialized
        space_type = space_type.get
        # @todo need an alternate way of determining residential without standards data
        res_types = [/Apartment/, /GuestRoom/, /PatRoom/, /ResBedroom/, /ResLiving/]
        res_types.each do |match|
          if res_types.any? { |match| space_type.name.get =~ match }
            is_res = true
          else
            is_res = false
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "Could not find a space type for #{space_to_check.name}, assuming nonresidential.")
        is_res = false
      end

      return is_res
    end

    # This method creates a new fractional schedule ruleset.
    # If occupied_percentage_threshold is set, this method will return a discrete on/off fractional schedule
    # with a value of one when occupancy across all spaces is greater than or equal to the occupied_percentage_threshold,
    # and zero all other times.  Otherwise the method will return the weighted fractional occupancy schedule.
    #
    # @param spaces [Array<OpenStudio::Model::Space>] array of spaces to generate occupancy schedule from
    # @param sch_name [String] the name of the generated occupancy schedule
    # @param occupied_percentage_threshold [Double] the minimum fraction (0 to 1) that counts as occupied
    #   if this parameter is set, the returned ScheduleRuleset will be 0 = unoccupied, 1 = occupied
    #   otherwise the ScheduleRuleset will be the weighted fractional occupancy schedule based on threshold_calc_method
    # @param threshold_calc_method [String] customizes behavior of occupied_percentage_threshold
    #   fractional passes raw value through,
    #   normalized_annual_range evaluates each value against the min/max range for the year
    #   normalized_daily_range evaluates each value against the min/max range for the day.
    #   The goal is a dynamic threshold that calibrates each day.
    # @return [<OpenStudio::Model::ScheduleRuleset>] a ScheduleRuleset of fractional or discrete occupancy
    # @todo Speed up this method.  Bottleneck is ScheduleRule.getDaySchedules
    def spaces_get_occupancy_schedule(spaces, sch_name: nil, occupied_percentage_threshold: nil, threshold_calc_method: 'value')
      unless !spaces.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.space', 'Empty spaces array passed to spaces_get_occupancy_schedule method.')
        return false
      end

      annual_normalized_tol = nil
      if threshold_calc_method == 'normalized_annual_range'
        # run this method without threshold to get annual min and max
        temp_merged = spaces_get_occupancy_schedule(spaces)
        tem_min_max = OpenstudioStandards::Schedules.schedule_ruleset_get_min_max(temp_merged)
        annual_normalized_tol = tem_min_max['min'] + (tem_min_max['max'] - tem_min_max['min']) * occupied_percentage_threshold
        temp_merged.remove
      end
      # Get all the occupancy schedules in spaces.
      # Include people added via the SpaceType and hard-assigned to the Space itself.
      occ_schedules_num_occ = {} # hash of
      max_occ_in_spaces = 0
      spaces.each do |space|
        # From the space type
        if space.spaceType.is_initialized
          space.spaceType.get.people.each do |people|
            num_ppl_sch = people.numberofPeopleSchedule
            if num_ppl_sch.is_initialized
              num_ppl_sch = num_ppl_sch.get
              num_ppl_sch = num_ppl_sch.to_ScheduleRuleset
              next if num_ppl_sch.empty? # Skip non-ruleset schedules

              num_ppl_sch = num_ppl_sch.get
              num_ppl = people.getNumberOfPeople(space.floorArea)
              if occ_schedules_num_occ[num_ppl_sch].nil?
                occ_schedules_num_occ[num_ppl_sch] = num_ppl
              else
                occ_schedules_num_occ[num_ppl_sch] += num_ppl
              end
              max_occ_in_spaces += num_ppl
            end
          end
        end
        # From the space
        space.people.each do |people|
          num_ppl_sch = people.numberofPeopleSchedule
          if num_ppl_sch.is_initialized
            num_ppl_sch = num_ppl_sch.get
            num_ppl_sch = num_ppl_sch.to_ScheduleRuleset
            next if num_ppl_sch.empty? # Skip non-ruleset schedules

            num_ppl_sch = num_ppl_sch.get
            num_ppl = people.getNumberOfPeople(space.floorArea)
            if occ_schedules_num_occ[num_ppl_sch].nil?
              occ_schedules_num_occ[num_ppl_sch] = num_ppl
            else
              occ_schedules_num_occ[num_ppl_sch] += num_ppl
            end
            max_occ_in_spaces += num_ppl
          end
        end
      end

      unless sch_name.nil?
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.space', "Finding space schedules for #{sch_name}.")
      end
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.space', "The #{spaces.size} spaces have #{occ_schedules_num_occ.size} unique occ schedules.")
      occ_schedules_num_occ.each do |occ_sch, num_occ|
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.space', "...#{occ_sch.name} - #{num_occ.round} people")
      end
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.space', "   Total #{max_occ_in_spaces.round} people in #{spaces.size} spaces.")

      # Store arrays of 365 day schedules used by each occ schedule once for later
      # Store arrays of day schedule times for later
      occ_schedules_day_schedules = {}
      day_schedule_times = {}
      year = spaces[0].model.getYearDescription
      first_date_of_year = year.makeDate(1)
      end_date_of_year = year.makeDate(365)
      occ_schedules_num_occ.each do |occ_sch, num_occ|
        day_schedules = occ_sch.getDaySchedules(first_date_of_year, end_date_of_year)
        # Store array of day schedules
        occ_schedules_day_schedules[occ_sch] = day_schedules
        day_schedules.uniq.each do |day_sch|
          # Skip schedules that have been stored previously
          next unless day_schedule_times[day_sch].nil?

          # Store times
          times = []
          day_sch.times.each do |time|
            times << time.toString
          end
          day_schedule_times[day_sch] = times
        end
      end

      # For each day of the year, determine time_value_pairs = []
      yearly_data = []
      (1..365).each do |i|
        times_on_this_day = []
        os_date = year.makeDate(i)
        day_of_week = os_date.dayOfWeek.valueName

        # Get the unique time indices and corresponding day schedules
        day_sch_num_occ = {}
        occ_schedules_num_occ.each do |occ_sch, num_occ|
          daily_sch = occ_schedules_day_schedules[occ_sch][i - 1]
          times_on_this_day += day_schedule_times[daily_sch]
          day_sch_num_occ[daily_sch] = num_occ
        end

        daily_normalized_tol = nil
        if threshold_calc_method == 'normalized_daily_range'
          # pre-process day to get daily min and max
          daily_spaces_occ_frac = []
          times_on_this_day.uniq.sort.each do |time|
            os_time = OpenStudio::Time.new(time)
            # Total number of people at each time
            tot_occ_at_time = 0
            day_sch_num_occ.each do |day_sch, num_occ|
              occ_frac = day_sch.getValue(os_time)
              tot_occ_at_time += occ_frac * num_occ
            end
            # Total fraction for the spaces at each time
            daily_spaces_occ_frac << tot_occ_at_time / max_occ_in_spaces
            daily_normalized_tol = daily_spaces_occ_frac.min + (daily_spaces_occ_frac.max - daily_spaces_occ_frac.min) * occupied_percentage_threshold
          end
        end

        # Determine the total fraction for the spaces at each time
        daily_times = []
        daily_os_times = []
        daily_values = []
        daily_occs = []
        times_on_this_day.uniq.sort.each do |time|
          os_time = OpenStudio::Time.new(time)
          # Total number of people at each time
          tot_occ_at_time = 0
          day_sch_num_occ.each do |day_sch, num_occ|
            occ_frac = day_sch.getValue(os_time)
            tot_occ_at_time += occ_frac * num_occ
          end

          # Total fraction for the spaces at each time,
          # rounded to avoid decimal precision issues
          spaces_occ_frac = (tot_occ_at_time / max_occ_in_spaces).round(3)

          # If occupied_percentage_threshold is specified, schedule values are boolean
          # Otherwise use the actual spaces_occ_frac
          if occupied_percentage_threshold.nil?
            occ_status = spaces_occ_frac
          elsif threshold_calc_method == 'normalized_annual_range'
            occ_status = 0 # unoccupied
            if spaces_occ_frac >= annual_normalized_tol
              occ_status = 1
            end
          elsif threshold_calc_method == 'normalized_daily_range'
            occ_status = 0 # unoccupied
            if spaces_occ_frac > daily_normalized_tol
              occ_status = 1
            end
          else
            occ_status = 0 # unoccupied
            if spaces_occ_frac >= occupied_percentage_threshold
              occ_status = 1
            end
          end

          # Add this data to the daily arrays
          daily_times << time
          daily_os_times << os_time
          daily_values << occ_status
          daily_occs << spaces_occ_frac.round(2)
        end

        # Simplify the daily times to eliminate intermediate points with the same value as the following point
        simple_daily_times = []
        simple_daily_os_times = []
        simple_daily_values = []
        simple_daily_occs = []
        daily_values.each_with_index do |value, j|
          next if value == daily_values[j + 1]

          simple_daily_times << daily_times[j]
          simple_daily_os_times << daily_os_times[j]
          simple_daily_values << daily_values[j]
          simple_daily_occs << daily_occs[j]
        end

        # Store the daily values
        yearly_data << { 'date' => os_date, 'day_of_week' => day_of_week, 'times' => simple_daily_times, 'values' => simple_daily_values, 'daily_os_times' => simple_daily_os_times, 'daily_occs' => simple_daily_occs }
      end

      # Create a TimeSeries from the data
      # time_series = OpenStudio::TimeSeries.new(times, values, 'unitless')
      # Make a schedule ruleset
      if sch_name.nil?
        sch_name = "#{spaces.size} space(s) Occ Sch"
      end
      sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(spaces[0].model)
      sch_ruleset.setName(sch_name.to_s)
      # add properties to schedule
      props = sch_ruleset.additionalProperties
      props.setFeature('max_occ_in_spaces', max_occ_in_spaces)
      props.setFeature('number_of_spaces_included', spaces.size)
      # nothing uses this but can make user be aware if this may be out of sync with current state of occupancy profiles
      props.setFeature('date_parent_object_last_edited', Time.now.getgm.to_s)
      props.setFeature('date_parent_object_created', Time.now.getgm.to_s)

      # Default - All Occupied
      day_sch = sch_ruleset.defaultDaySchedule
      day_sch.setName("#{sch_name} Default")
      day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

      # Winter Design Day - All Occupied
      day_sch = OpenStudio::Model::ScheduleDay.new(spaces[0].model)
      sch_ruleset.setWinterDesignDaySchedule(day_sch)
      day_sch = sch_ruleset.winterDesignDaySchedule
      day_sch.setName("#{sch_name} Winter Design Day")
      day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

      # Summer Design Day - All Occupied
      day_sch = OpenStudio::Model::ScheduleDay.new(spaces[0].model)
      sch_ruleset.setSummerDesignDaySchedule(day_sch)
      day_sch = sch_ruleset.summerDesignDaySchedule
      day_sch.setName("#{sch_name} Summer Design Day")
      day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

      # Create ruleset schedules, attempting to create the minimum number of unique rules
      ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].each do |weekday|
        end_of_prev_rule = yearly_data[0]['date']
        yearly_data.each_with_index do |daily_data, k|
          # Skip unless it is the day of week
          # currently under inspection
          day = daily_data['day_of_week']
          next unless day == weekday

          date = daily_data['date']
          times = daily_data['times']
          values = daily_data['values']
          daily_os_times = daily_data['daily_os_times']

          # If the next (Monday, Tuesday, etc.) is the same as today, keep going
          # If the next is different, or if we've reached the end of the year, create a new rule
          unless yearly_data[k + 7].nil?
            next_day_times = yearly_data[k + 7]['times']
            next_day_values = yearly_data[k + 7]['values']
            next if times == next_day_times && values == next_day_values
          end

          # If here, we need to make a rule to cover from the previous rule to today
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.space', "Making a new rule for #{weekday} from #{end_of_prev_rule} to #{date}")
          sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
          sch_rule.setName("#{sch_name} #{weekday} Rule")
          day_sch = sch_rule.daySchedule
          day_sch.setName("#{sch_name} #{weekday}")
          daily_os_times.each_with_index do |time, t|
            value = values[t]
            next if value == values[t + 1] # Don't add breaks if same value

            day_sch.addValue(time, value)
          end

          # Set the dates when the rule applies
          sch_rule.setStartDate(end_of_prev_rule)
          # for end dates in last week of year force it to use 12/31. Avoids issues if year or start day of week changes
          start_of_last_week = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 25, year.assumedYear)
          if date >= start_of_last_week
            year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year.assumedYear)
            sch_rule.setEndDate(year_end_date)
          else
            sch_rule.setEndDate(date)
          end

          # Individual Days
          sch_rule.setApplyMonday(true) if weekday == 'Monday'
          sch_rule.setApplyTuesday(true) if weekday == 'Tuesday'
          sch_rule.setApplyWednesday(true) if weekday == 'Wednesday'
          sch_rule.setApplyThursday(true) if weekday == 'Thursday'
          sch_rule.setApplyFriday(true) if weekday == 'Friday'
          sch_rule.setApplySaturday(true) if weekday == 'Saturday'
          sch_rule.setApplySunday(true) if weekday == 'Sunday'

          # Reset the previous rule end date
          end_of_prev_rule = date + OpenStudio::Time.new(0, 24, 0, 0)
        end
      end

      # utilize default profile and common similar days of week for same date range
      # todo - if move to method in Standards.ScheduleRuleset.rb udpate code to check if default profile is used before replacing it with lowest priority rule.
      # todo - also merging non adjacent priority rules without getting rid of any rules between the two could create unexpected reults
      prior_rules = []
      sch_ruleset.scheduleRules.each do |rule|
        if prior_rules.empty?
          prior_rules << rule
          next
        else
          rules_combined = false
          prior_rules.each do |prior_rule|
            # see if they are similar
            next if rules_combined
            # @todo update to combine adjacent date ranges vs. just matching date ranges
            next if prior_rule.startDate.get != rule.startDate.get
            next if prior_rule.endDate.get != rule.endDate.get
            next if prior_rule.daySchedule.times.to_a != rule.daySchedule.times.to_a
            next if prior_rule.daySchedule.values.to_a != rule.daySchedule.values.to_a

            # combine dates of week
            if rule.applyMonday then prior_rule.setApplyMonday(true) && rules_combined = true end
            if rule.applyTuesday then prior_rule.setApplyTuesday(true) && rules_combined = true end
            if rule.applyWednesday then prior_rule.setApplyWednesday(true) && rules_combined = true end
            if rule.applyThursday then prior_rule.setApplyThursday(true) && rules_combined = true end
            if rule.applyFriday then prior_rule.setApplyFriday(true) && rules_combined = true end
            if rule.applySaturday then prior_rule.setApplySaturday(true) && rules_combined = true end
            if rule.applySunday then prior_rule.setApplySunday(true) && rules_combined = true end
          end
          rules_combined ? rule.remove : prior_rules << rule
        end
      end
      # replace unused default profile with lowest priority rule
      values = prior_rules.last.daySchedule.values
      times = prior_rules.last.daySchedule.times
      prior_rules.last.remove
      sch_ruleset.defaultDaySchedule.clearValues
      values.size.times do |i|
        sch_ruleset.defaultDaySchedule.addValue(times[i], values[i])
      end

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.space', "Created #{sch_ruleset.name} with #{OpenstudioStandards::Schedules.schedule_ruleset_get_equivalent_full_load_hours(sch_ruleset)} annual EFLH.")

      return sch_ruleset
    end
  end
end
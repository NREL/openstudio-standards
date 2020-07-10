
class Standard
  # @!group ThermalZone

  # Calculates the zone outdoor airflow requirement (Voz)
  # based on the inputs in the DesignSpecification:OutdoorAir obects
  # in all spaces in the zone.
  #
  # @return [Double] the zone outdoor air flow rate
  #   @units cubic meters per second (m^3/s)
  def thermal_zone_outdoor_airflow_rate(thermal_zone)
    tot_oa_flow_rate = 0.0

    spaces = thermal_zone.spaces.sort

    sum_floor_area = 0.0
    sum_number_of_people = 0.0
    sum_volume = 0.0

    # Variables for merging outdoor air
    any_max_oa_method = false
    sum_oa_for_people = 0.0
    sum_oa_for_floor_area = 0.0
    sum_oa_rate = 0.0
    sum_oa_for_volume = 0.0

    # Find common variables for the new space
    spaces.each do |space|
      floor_area = space.floorArea
      sum_floor_area += floor_area

      number_of_people = space.numberOfPeople
      sum_number_of_people += number_of_people

      volume = space.volume
      sum_volume += volume

      dsn_oa = space.designSpecificationOutdoorAir
      next if dsn_oa.empty?
      dsn_oa = dsn_oa.get

      # compute outdoor air rates in case we need them
      oa_for_people = number_of_people * dsn_oa.outdoorAirFlowperPerson
      oa_for_floor_area = floor_area * dsn_oa.outdoorAirFlowperFloorArea
      oa_rate = dsn_oa.outdoorAirFlowRate
      oa_for_volume = volume * dsn_oa.outdoorAirFlowAirChangesperHour / 3600

      # First check if this space uses the Maximum method and other spaces do not
      if dsn_oa.outdoorAirMethod == 'Maximum'
        sum_oa_rate += [oa_for_people, oa_for_floor_area, oa_rate, oa_for_volume].max
      elsif dsn_oa.outdoorAirMethod == 'Sum'
        sum_oa_for_people += oa_for_people
        sum_oa_for_floor_area += oa_for_floor_area
        sum_oa_rate += oa_rate
        sum_oa_for_volume += oa_for_volume
      end
    end

    tot_oa_flow_rate += sum_oa_for_people
    tot_oa_flow_rate += sum_oa_for_floor_area
    tot_oa_flow_rate += sum_oa_rate
    tot_oa_flow_rate += sum_oa_for_volume

    # Convert to cfm
    tot_oa_flow_rate_cfm = OpenStudio.convert(tot_oa_flow_rate, 'm^3/s', 'cfm').get

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}, design min OA = #{tot_oa_flow_rate_cfm.round} cfm.")

    return tot_oa_flow_rate
  end

  # Calculates the zone outdoor airflow requirement and
  # divides by the zone area.
  #
  # @return [Double] the zone outdoor air flow rate per area
  #   @units cubic meters per second (m^3/s)
  def thermal_zone_outdoor_airflow_rate_per_area(thermal_zone)
    tot_oa_flow_rate_per_area = 0.0

    # Find total area of the zone
    sum_floor_area = 0.0
    thermal_zone.spaces.sort.each do |space|
      sum_floor_area += space.floorArea
    end

    # Get the OA flow rate
    tot_oa_flow_rate = thermal_zone_outdoor_airflow_rate(thermal_zone)

    # Calculate the per-area value
    tot_oa_flow_rate_per_area = tot_oa_flow_rate / sum_floor_area

    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "For #{self.name}, OA per area = #{tot_oa_flow_rate_per_area.round(8)} m^3/s*m^2.")

    return tot_oa_flow_rate_per_area
  end

  # Convert total minimum OA requirement to a per-area value.
  #
  # @return [Bool] true if successful, false if not
  def thermal_zone_convert_oa_req_to_per_area(thermal_zone)
    # For each space in the zone, convert
    # all design OA to per-area
    # unless the "Outdoor Air Method" is "Maximum"
    thermal_zone.spaces.each do |space|
      dsn_oa = space.designSpecificationOutdoorAir
      next if dsn_oa.empty?
      dsn_oa = dsn_oa.get
      next if dsn_oa.outdoorAirMethod == 'Maximum'

      # Get the space properties
      floor_area = space.floorArea
      number_of_people = space.numberOfPeople
      volume = space.volume

      # Sum up the total OA from all sources
      oa_for_people = number_of_people * dsn_oa.outdoorAirFlowperPerson
      oa_for_floor_area = floor_area * dsn_oa.outdoorAirFlowperFloorArea
      oa_rate = dsn_oa.outdoorAirFlowRate
      oa_for_volume = volume * dsn_oa.outdoorAirFlowAirChangesperHour / 3600
      tot_oa = oa_for_people + oa_for_floor_area + oa_rate + oa_for_volume

      # Convert total to per-area
      tot_oa_per_area = tot_oa / floor_area

      # Set the per-area requirement
      dsn_oa.setOutdoorAirFlowperFloorArea(tot_oa_per_area)
      # Zero-out the per-person, ACH, and flow requirements
      dsn_oa.setOutdoorAirFlowperPerson(0.0)
      dsn_oa.setOutdoorAirFlowAirChangesperHour(0.0)
      dsn_oa.setOutdoorAirFlowRate(0.0)
    end

    return true
  end

  # This method creates a new fractional schedule ruleset.
  # If occupied_percentage_threshold is set, this method will return a discrete on/off fractional schedule
  # with a value of one when occupancy across all spaces is greater than or equal to the occupied_percentage_threshold,
  # and zero all other times.  Otherwise the method will return the weighted fractional occupancy schedule.
  #
  # @param thermal_zone [<OpenStudio::Model::ThermalZone>] thermal_zone to create occupancy schedule
  # @param sch_name [String] the name of the generated occupancy schedule
  # @param occupied_percentage_threshold [Double] the minimum fraction (0 to 1) that counts as occupied
  #   if this parameter is set, the returned ScheduleRuleset will be 0 = unoccupied, 1 = occupied
  #   otherwise the ScheduleRuleset will be the weighted fractional occupancy schedule
  # @return [<OpenStudio::Model::ScheduleRuleset>] a ScheduleRuleset of fractional or discrete occupancy
  def thermal_zone_get_occupancy_schedule(thermal_zone, sch_name: nil, occupied_percentage_threshold: nil)
    if sch_name.nil?
      sch_name = "#{thermal_zone.name} Occ Sch"
    end
    # Get the occupancy schedule for all spaces in thermal_zone
    sch_ruleset = spaces_get_occupancy_schedule(thermal_zone.spaces,
                                                sch_name: sch_name,
                                                occupied_percentage_threshold: occupied_percentage_threshold)
    return sch_ruleset
  end

  # This method creates a new fractional schedule ruleset.
  # If occupied_percentage_threshold is set, this method will return a discrete on/off fractional schedule
  # with a value of one when occupancy across all spaces is greater than or equal to the occupied_percentage_threshold,
  # and zero all other times.  Otherwise the method will return the weighted fractional occupancy schedule.
  #
  # @param thermal_zones [Array<OpenStudio::Model::ThermalZone>] array of thermal_zones to create occupancy schedule
  # @param sch_name [String] the name of the generated occupancy schedule
  # @param occupied_percentage_threshold [Double] the minimum fraction (0 to 1) that counts as occupied
  #   if this parameter is set, the returned ScheduleRuleset will be 0 = unoccupied, 1 = occupied
  #   otherwise the ScheduleRuleset will be the weighted fractional occupancy schedule
  # @return [<OpenStudio::Model::ScheduleRuleset>] a ScheduleRuleset of fractional or discrete occupancy
  def thermal_zones_get_occupancy_schedule(thermal_zones, sch_name: nil, occupied_percentage_threshold: nil)
    if sch_name.nil?
      sch_name = "#{thermal_zones.size} zone Occ Sch"
    end
    # Get the occupancy schedule for all spaces in thermal_zones
    spaces = []
    thermal_zones.each do |thermal_zone|
      thermal_zone.spaces.each do |space|
        spaces << space
      end
    end
    sch_ruleset = spaces_get_occupancy_schedule(spaces,
                                                sch_name: sch_name,
                                                occupied_percentage_threshold: occupied_percentage_threshold)
    return sch_ruleset
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
  # fractional passes raw value through,
  # normalized_annual_range evaluates each value against the min/max range for the year
  # normalized_daily_range evaluates each value against the min/max range for the day.
  # The goal is a dynamic threshold that calibrates each day.
  # @return [<OpenStudio::Model::ScheduleRuleset>] a ScheduleRuleset of fractional or discrete occupancy
  # @todo Speed up this method.  Bottleneck is ScheduleRule.getDaySchedules
  def spaces_get_occupancy_schedule(spaces, sch_name: nil, occupied_percentage_threshold: nil, threshold_calc_method: "value")

    annual_normalized_tol = nil
    if threshold_calc_method == "normalized_annual_range"
      # run this method without threshold to get annual min and max
      temp_merged = spaces_get_occupancy_schedule(spaces)
      tem_min_max = schedule_ruleset_annual_min_max_value(temp_merged)
      annual_normalized_tol = tem_min_max['min'] + (tem_min_max['max'] - tem_min_max['min']) * occupied_percentage_threshold
      temp_merged.remove
    end
    # Get all the occupancy schedules in spaces.
    # Include people added via the SpaceType and hard-assigned to the Space itself.
    occ_schedules_num_occ = {}
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
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Finding space schedules for #{sch_name}.")
    end
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "The #{spaces.size} spaces have #{occ_schedules_num_occ.size} unique occ schedules.")
    occ_schedules_num_occ.each do |occ_sch, num_occ|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "...#{occ_sch.name} - #{num_occ.round} people")
    end
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "   Total #{max_occ_in_spaces.round} people in #{spaces.size} spaces.")

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
        daily_sch = occ_schedules_day_schedules[occ_sch][i-1]
        times_on_this_day += day_schedule_times[daily_sch]
        day_sch_num_occ[daily_sch] = num_occ
      end

      daily_normalized_tol = nil
      if threshold_calc_method == "normalized_daily_range"
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

        # Total fraction for the spaces at each time
        spaces_occ_frac = tot_occ_at_time / max_occ_in_spaces

        # If occupied_percentage_threshold is specified, schedule values are boolean
        # Otherwise use the actual spaces_occ_frac
        if occupied_percentage_threshold.nil?
          occ_status = spaces_occ_frac
        elsif threshold_calc_method == "normalized_annual_range"
          occ_status = 0 # unoccupied
          if spaces_occ_frac >= annual_normalized_tol
            occ_status = 1
          end
        elsif threshold_calc_method == "normalized_daily_range"
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
    props.setFeature("max_occ_in_spaces",max_occ_in_spaces)
    props.setFeature("number_of_spaces_included",spaces.size)
    # nothing uses this but can make user be aware if this may be out of sync with current state of occupancy profiles
    props.setFeature("date_parent_object_last_edited",Time.now.getgm.to_s)
    props.setFeature("date_parent_object_created",Time.now.getgm.to_s)

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
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Making a new rule for #{weekday} from #{end_of_prev_rule} to #{date}")
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
      if prior_rules.size == 0
        prior_rules << rule
        next
      else
        rules_combined = false
        prior_rules.each do |prior_rule|
          # see if they are similar
          next if rules_combined
          # todo - update to combine adjacent date ranges vs. just matching date ranges
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
        if rules_combined then rule.remove else prior_rules << rule end
      end
    end
    # replace unused default profile with lowest priority rule
    values = prior_rules.last.daySchedule.values
    times = prior_rules.last.daySchedule.times
    prior_rules.last.remove
    sch_ruleset.defaultDaySchedule.clearValues
    values.size.times do |i|
      sch_ruleset.defaultDaySchedule.addValue(times[i],values[i])
    end

    return sch_ruleset
  end

  # Determine if the thermal zone is residential based on the
  # space type properties for the spaces in the zone.
  # If there are both residential and nonresidential spaces
  # in the zone, the result will be whichever type
  # has more floor area. In the event that they are equal,
  # it will be assumed nonresidential.
  #
  # return [Bool] true if residential, false if nonresidential
  def thermal_zone_residential?(thermal_zone)
    # Determine the respective areas
    res_area_m2 = 0
    nonres_area_m2 = 0
    thermal_zone.spaces.each do |space|
      # Ignore space if not part of total area
      next unless space.partofTotalFloorArea
      if space_residential?(space)
        res_area_m2 += space.floorArea
      else
        nonres_area_m2 += space.floorArea
      end
    end

    # Determine which is larger
    is_res = false
    if res_area_m2 > nonres_area_m2
      is_res = true
    end

    return is_res
  end

  # Determine if the thermal zone is a Fossil Fuel,
  # Fossil/Electric Hybrid, and Purchased Heat zone.
  # If not, it is an Electric or Other Zone.
  # This is as-defined by 90.1 Appendix G.
  #
  # return [Bool] true if Fossil Fuel,
  # Fossil/Electric Hybrid, and Purchased Heat zone,
  # false if Electric or Other.
  # To-do: It's not doing it properly right now. If you have a zone with a VRF + a DOAS (via an ATU SingleDUct Uncontrolled)
  # it'll pick up both natural gas and electricity and classify it as fossil fuel, when I would definitely classify it as electricity
  def thermal_zone_fossil_hybrid_or_purchased_heat?(thermal_zone)
    is_fossil = false

    # Get an array of the heating fuels
    # used by the zone.  Possible values are
    # Electricity, NaturalGas, PropaneGas, FuelOilNo1, FuelOilNo2,
    # Coal, Diesel, Gasoline, DistrictHeating,
    # and SolarEnergy.
    htg_fuels = thermal_zone.heating_fuels

    if htg_fuels.include?('NaturalGas') ||
       htg_fuels.include?('PropaneGas') ||
       htg_fuels.include?('FuelOilNo1') ||
       htg_fuels.include?('FuelOilNo2') ||
       htg_fuels.include?('Coal') ||
       htg_fuels.include?('Diesel') ||
       htg_fuels.include?('Gasoline') ||
       htg_fuels.include?('DistrictHeating')

      is_fossil = true
    end

    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "For #{self.name}, heating fuels = #{htg_fuels.join(', ')}; thermal_zone_fossil_hybrid_or_purchased_heat?(thermal_zone)  = #{is_fossil}.")

    return is_fossil
  end

  # Determine if the thermal zone's fuel type category.
  # Options are:
  # fossil, electric, unconditioned
  # If a customization is passed, additional categories may
  # be returned.
  # If 'Xcel Energy CO EDA', the type fossilandelectric is added.
  # DistrictHeating is considered a fossil fuel since it is
  # typically created by natural gas boilers.
  #
  # @return [String] the fuel type category
  def thermal_zone_fossil_or_electric_type(thermal_zone, custom)
    fossil = false
    electric = false

    # Fossil heating
    htg_fuels = thermal_zone.heating_fuels
    if htg_fuels.include?('NaturalGas') ||
       htg_fuels.include?('PropaneGas') ||
       htg_fuels.include?('FuelOilNo1') ||
       htg_fuels.include?('FuelOilNo2') ||
       htg_fuels.include?('Coal') ||
       htg_fuels.include?('Diesel') ||
       htg_fuels.include?('Gasoline') ||
       htg_fuels.include?('DistrictHeating')
      fossil = true
    end

    # Electric heating
    if htg_fuels.include?('Electricity')
      electric = true
    end

    # Cooling fuels, for determining
    # unconditioned zones
    clg_fuels = thermal_zone.cooling_fuels

    # Categorize
    fuel_type = nil
    if fossil
      # If uses any fossil, counts as fossil even if electric is present too
      fuel_type = 'fossil'
    elsif electric
      fuel_type = 'electric'
    elsif htg_fuels.size.zero? && clg_fuels.size.zero?
      fuel_type = 'unconditioned'
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}, could not determine fuel type, assuming fossil.  Heating fuels = #{htg_fuels.join(', ')}; cooling fuels = #{clg_fuels.join(', ')}.")
      fuel_type = 'fossil'
    end

    # Customization for Xcel.
    # Likely useful for other utility
    # programs where fuel switching is important.
    # This is primarily for systems where Gas is
    # used at the central AHU and electric is
    # used at the terminals/zones.  Examples
    # include zone VRF/PTHP with gas-heated DOAS,
    # and gas VAV with electric reheat
    case custom
    when 'Xcel Energy CO EDA'
      if fossil && electric
        fuel_type = 'fossilandelectric'
      end
    end

    # OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.Model", "For #{self.name}, fuel type = #{fuel_type}.")

    return fuel_type
  end

  # Determine if the thermal zone is
  # Fossil/Purchased Heat/Electric Hybrid
  #
  # return [Bool] true if mixed
  # Fossil/Electric Hybrid, and Purchased Heat zone
  def thermal_zone_mixed_heating_fuel?(thermal_zone)
    is_mixed = false

    # Get an array of the heating fuels
    # used by the zone.  Possible values are
    # Electricity, NaturalGas, PropaneGas, FuelOilNo1, FuelOilNo2,
    # Coal, Diesel, Gasoline, DistrictHeating,
    # and SolarEnergy.
    htg_fuels = thermal_zone.heating_fuels

    # Includes fossil
    fossil = false
    if htg_fuels.include?('NaturalGas') ||
       htg_fuels.include?('PropaneGas') ||
       htg_fuels.include?('FuelOilNo1') ||
       htg_fuels.include?('FuelOilNo2') ||
       htg_fuels.include?('Coal') ||
       htg_fuels.include?('Diesel') ||
       htg_fuels.include?('Gasoline')

      fossil = true
    end

    # Electric and fossil and district
    if htg_fuels.include?('Electricity') && htg_fuels.include?('DistrictHeating') && fossil
      is_mixed = true
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}, heating mixed electricity, fossil, and district.")
    end

    # Electric and fossil
    if htg_fuels.include?('Electricity') && fossil
      is_mixed = true
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}, heating mixed electricity and fossil.")
    end

    # Electric and district
    if htg_fuels.include?('Electricity') && htg_fuels.include?('DistrictHeating')
      is_mixed = true
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}, heating mixed electricity and district.")
    end

    # Fossil and district
    if fossil && htg_fuels.include?('DistrictHeating')
      is_mixed = true
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}, heating mixed fossil and district.")
    end

    return is_mixed
  end

  # Determine the net area of the zone
  # Loops on each space, and checks if part of total floor area or not
  # If not part of total floor area, it is not added to the zone floor area
  # Will multiply it by the ZONE MULTIPLIER as well!
  #
  # @return [Double] the zone net floor area in m^2 (with multiplier taken into account)
  def thermal_zone_floor_area_with_zone_multipliers(thermal_zone)
    area_m2 = 0
    zone_mult = multiplier
    spaces.each do |space|
      # If space is not part of floor area, we don't add it
      next unless space.partofTotalFloorArea
      area_m2 += space.floorArea
    end

    return area_m2 * zone_mult
  end

  # Infers the baseline system type based on the equipment
  # serving the zone and their heating/cooling fuels.
  # Only does a high-level inference; does not look for the
  # presence/absence of required controls, etc.
  #
  # @return [String] Possible system types are
  # PTHP, PTAC, PSZ_AC, PSZ_HP, PVAV_Reheat, PVAV_PFP_Boxes,
  # VAV_Reheat, VAV_PFP_Boxes, Gas_Furnace, Electric_Furnace
  def thermal_zone_infer_system_type(thermal_zone)
    # Determine the characteristics
    # of the equipment serving the zone
    has_air_loop = false
    air_loop_num_zones = 0
    air_loop_is_vav = false
    air_loop_has_chw = false
    has_ptac = false
    has_pthp = false
    has_unitheater = false
    thermal_zone.equipment.each do |equip|
      # Skip HVAC components
      next unless equip.to_HVACComponent.is_initialized
      equip = equip.to_HVACComponent.get
      if equip.airLoopHVAC.is_initialized
        has_air_loop = true
        air_loop = equip.airLoopHVAC.get
        air_loop_num_zones = air_loop.thermalZones.size
        air_loop.supplyComponents.each do |sc|
          if sc.to_FanVariableVolume.is_initialized
            air_loop_is_vav = true
          elsif sc.to_CoilCoolingWater.is_initialized
            air_loop_has_chw = true
          end
        end
      elsif equip.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
        has_ptac = true
      elsif equip.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
        has_pthp = true
      elsif equip.to_ZoneHVACUnitHeater.is_initialized
        has_unitheater = true
      end
    end

    # Get the zone heating and cooling fuels
    htg_fuels = thermal_zone.heating_fuels
    clg_fuels = thermal_zone.cooling_fuels
    is_fossil = thermal_zone_fossil_hybrid_or_purchased_heat?(thermal_zone)

    # Infer the HVAC type
    sys_type = 'Unknown'

    # Single zone
    if air_loop_num_zones < 2
      # Gas
      if is_fossil
        # Air Loop
        if has_air_loop
          # Gas_Furnace (as air loop)
          sys_type = if clg_fuels.size.zero?
                       'Gas_Furnace'
                     # PSZ_AC
                     else
                       'PSZ_AC'
                     end
        # Zone Equipment
        else
          # Gas_Furnace (as unit heater)
          if has_unitheater
            sys_type = 'Gas_Furnace'
          end
          # PTAC
          if has_ptac
            sys_type = 'PTAC'
          end
        end
      # Electric
      else
        # Air Loop
        if has_air_loop
          # Electric_Furnace (as air loop)
          sys_type = if clg_fuels.size.zero?
                       'Electric_Furnace'
                     # PSZ_HP
                     else
                       'PSZ_HP'
                     end
        # Zone Equipment
        else
          # Electric_Furnace (as unit heater)
          if has_unitheater
            sys_type = 'Electric_Furnace'
          end
          # PTHP
          if has_pthp
            sys_type = 'PTHP'
          end
        end
      end
    # Multi-zone
    else
      # Gas
      if is_fossil
        # VAV_Reheat
        if air_loop_has_chw && air_loop_is_vav
          sys_type = 'VAV_Reheat'
        end
        # PVAV_Reheat
        if !air_loop_has_chw && air_loop_is_vav
          sys_type = 'PVAV_Reheat'
        end
      # Electric
      else
        # VAV_PFP_Boxes
        if air_loop_has_chw && air_loop_is_vav
          sys_type = 'VAV_PFP_Boxes'
        end
        # PVAV_PFP_Boxes
        if !air_loop_has_chw && air_loop_is_vav
          sys_type = 'PVAV_PFP_Boxes'
        end
      end
    end

    # Report out the characteristics for debugging if
    # the system type cannot be inferred.
    if sys_type == 'Unknown'
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}, the baseline system type could not be inferred.")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "***#{thermal_zone.name}***")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "system type = #{sys_type}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "has_air_loop = #{has_air_loop}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "air_loop_num_zones = #{air_loop_num_zones}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "air_loop_is_vav = #{air_loop_is_vav}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "air_loop_has_chw = #{air_loop_has_chw}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "has_ptac = #{has_ptac}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "has_pthp = #{has_pthp}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "has_unitheater = #{has_unitheater}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "htg_fuels = #{htg_fuels}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "clg_fuels = #{clg_fuels}")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "is_fossil = #{is_fossil}")
    end

    return sys_type
  end

  # Determines heating status.  If the zone has a thermostat
  # with a maximum heating setpoint above 5C (41F),
  # counts as heated.  Plenums are also assumed to be heated.
  #
  # @author Andrew Parker, Julien Marrec
  # @return [Bool] true if heated, false if not
  def thermal_zone_heated?(thermal_zone)
    temp_f = 41
    temp_c = OpenStudio.convert(temp_f, 'F', 'C').get

    htd = false

    # Consider plenum zones heated
    area_plenum = 0
    area_non_plenum = 0
    thermal_zone.spaces.each do |space|
      if space_plenum?(space)
        area_plenum += space.floorArea
      else
        area_non_plenum += space.floorArea
      end
    end

    # Majority
    if area_plenum > area_non_plenum
      htd = true
      return htd
    end

    # Check if the zone has radiant heating,
    # and if it does, get heating setpoint schedule
    # directly from the radiant system to check.
    thermal_zone.equipment.each do |equip|
      htg_sch = nil
      if equip.to_ZoneHVACHighTemperatureRadiant.is_initialized
        equip = equip.to_ZoneHVACHighTemperatureRadiant.get
        if equip.heatingSetpointTemperatureSchedule.is_initialized
          htg_sch = equip.heatingSetpointTemperatureSchedule.get
        end
      elsif equip.to_ZoneHVACLowTemperatureRadiantElectric.is_initialized
        equip = equip.to_ZoneHVACLowTemperatureRadiantElectric.get
        htg_sch = equip.heatingSetpointTemperatureSchedule.get
      elsif equip.to_ZoneHVACLowTempRadiantConstFlow.is_initialized
        equip = equip.to_ZoneHVACLowTempRadiantConstFlow.get
        htg_coil = equip.heatingCoil
        if htg_coil.to_CoilHeatingLowTempRadiantConstFlow.is_initialized
          htg_coil = htg_coil.to_CoilHeatingLowTempRadiantConstFlow.get
          if htg_coil.heatingHighControlTemperatureSchedule.is_initialized
            htg_sch = htg_coil.heatingHighControlTemperatureSchedule.get
          end
        end
      elsif equip.to_ZoneHVACLowTempRadiantVarFlow.is_initialized
        equip = equip.to_ZoneHVACLowTempRadiantVarFlow.get
        htg_coil = equip.heatingCoil
        if htg_coil.to_CoilHeatingLowTempRadiantVarFlow.is_initialized
          htg_coil = htg_coil.to_CoilHeatingLowTempRadiantVarFlow.get
          if htg_coil.heatingControlTemperatureSchedule.is_initialized
            htg_sch = htg_coil.heatingControlTemperatureSchedule.get
          end
        end
      end
      # Move on if no heating schedule was found
      next if htg_sch.nil?
      # Get the setpoint from the schedule
      if htg_sch.to_ScheduleRuleset.is_initialized
        htg_sch = htg_sch.to_ScheduleRuleset.get
        max_c = schedule_ruleset_annual_min_max_value(htg_sch)['max']
        if max_c > temp_c
          htd = true
        end
      elsif htg_sch.to_ScheduleConstant.is_initialized
        htg_sch = htg_sch.to_ScheduleConstant.get
        max_c = schedule_constant_annual_min_max_value(htg_sch)['max']
        if max_c > temp_c
          htd = true
        end
      elsif htg_sch.to_ScheduleCompact.is_initialized
        htg_sch = htg_sch.to_ScheduleCompact.get
        max_c = schedule_compact_annual_min_max_value(htg_sch)['max']
        if max_c > temp_c
          htd = true
        end
      else
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{thermal_zone.name} used an unknown schedule type for the heating setpoint; assuming heated.")
        htd = true
      end
    end

    # Unheated if no thermostat present
    if thermal_zone.thermostat.empty?
      return htd
    end

    # Check the heating setpoint
    tstat = thermal_zone.thermostat.get
    if tstat.to_ThermostatSetpointDualSetpoint
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      htg_sch = tstat.getHeatingSchedule
      if htg_sch.is_initialized
        htg_sch = htg_sch.get
        if htg_sch.to_ScheduleRuleset.is_initialized
          htg_sch = htg_sch.to_ScheduleRuleset.get
          max_c = schedule_ruleset_annual_min_max_value(htg_sch)['max']
          if max_c > temp_c
            htd = true
          end
        elsif htg_sch.to_ScheduleConstant.is_initialized
          htg_sch = htg_sch.to_ScheduleConstant.get
          max_c = schedule_constant_annual_min_max_value(htg_sch)['max']
          if max_c > temp_c
            htd = true
          end
        elsif htg_sch.to_ScheduleCompact.is_initialized
          htg_sch = htg_sch.to_ScheduleCompact.get
          max_c = schedule_compact_annual_min_max_value(htg_sch)['max']
          if max_c > temp_c
            htd = true
          end
        else
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{thermal_zone.name} used an unknown schedule type for the heating setpoint; assuming heated.")
          htd = true
        end
      end
    elsif tstat.to_ZoneControlThermostatStagedDualSetpoint
      tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
      htg_sch = tstat.heatingTemperatureSetpointSchedule
      if htg_sch.is_initialized
        htg_sch = htg_sch.get
        if htg_sch.to_ScheduleRuleset.is_initialized
          htg_sch = htg_sch.to_ScheduleRuleset.get
          max_c = schedule_ruleset_annual_min_max_value(htg_sch)['max']
          if max_c > temp_c
            htd = true
          end
        end
      end
    end

    return htd
  end

  # Determines cooling status.  If the zone has a thermostat
  # with a minimum cooling setpoint below 33C (91F),
  # counts as cooled.  Plenums are also assumed to be cooled.
  #
  # @author Andrew Parker, Julien Marrec
  # @return [Bool] true if cooled, false if not
  def thermal_zone_cooled?(thermal_zone)
    temp_f = 91
    temp_c = OpenStudio.convert(temp_f, 'F', 'C').get

    cld = false

    # Consider plenum zones cooled
    area_plenum = 0
    area_non_plenum = 0
    thermal_zone.spaces.each do |space|
      if space_plenum?(space)
        area_plenum += space.floorArea
      else
        area_non_plenum += space.floorArea
      end
    end

    # Majority
    if area_plenum > area_non_plenum
      cld = true
      return cld
    end

    # Check if the zone has radiant cooling,
    # and if it does, get cooling setpoint schedule
    # directly from the radiant system to check.
    thermal_zone.equipment.each do |equip|
      clg_sch = nil
      if equip.to_ZoneHVACLowTempRadiantConstFlow.is_initialized
        equip = equip.to_ZoneHVACLowTempRadiantConstFlow.get
        clg_coil = equip.heatingCoil
        if clg_coil.to_CoilCoolingLowTempRadiantConstFlow.is_initialized
          clg_coil = clg_coil.to_CoilCoolingLowTempRadiantConstFlow.get
          if clg_coil.coolingLowControlTemperatureSchedule.is_initialized
            clg_sch = clg_coil.coolingLowControlTemperatureSchedule.get
          end
        end
      elsif equip.to_ZoneHVACLowTempRadiantVarFlow.is_initialized
        equip = equip.to_ZoneHVACLowTempRadiantVarFlow.get
        clg_coil = equip.heatingCoil
        if clg_coil.to_CoilCoolingLowTempRadiantVarFlow.is_initialized
          clg_coil = clg_coil.to_CoilCoolingLowTempRadiantVarFlow.get
          if clg_coil.coolingControlTemperatureSchedule.is_initialized
            clg_sch = clg_coil.coolingControlTemperatureSchedule.get
          end
        end
      end
      # Move on if no cooling schedule was found
      next if clg_sch.nil?
      # Get the setpoint from the schedule
      if clg_sch.to_ScheduleRuleset.is_initialized
        clg_sch = clg_sch.to_ScheduleRuleset.get
        min_c = schedule_ruleset_annual_min_max_value(clg_sch)['min']
        if min_c < temp_c
          cld = true
        end
      elsif clg_sch.to_ScheduleConstant.is_initialized
        clg_sch = clg_sch.to_ScheduleConstant.get
        min_c = schedule_constant_annual_min_max_value(clg_sch)['min']
        if min_c < temp_c
          cld = true
        end
      elsif clg_sch.to_ScheduleCompact.is_initialized
        clg_sch = clg_sch.to_ScheduleCompact.get
        min_c = schedule_compact_annual_min_max_value(clg_sch)['min']
        if min_c < temp_c
          cld = true
        end
      else
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{thermal_zone.name} used an unknown schedule type for the cooling setpoint; assuming cooled.")
        cld = true
      end
    end

    # Unheated if no thermostat present
    if thermal_zone.thermostat.empty?
      return cld
    end

    # Check the cooling setpoint
    tstat = thermal_zone.thermostat.get
    if tstat.to_ThermostatSetpointDualSetpoint
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      clg_sch = tstat.getCoolingSchedule
      if clg_sch.is_initialized
        clg_sch = clg_sch.get
        if clg_sch.to_ScheduleRuleset.is_initialized
          clg_sch = clg_sch.to_ScheduleRuleset.get
          min_c = schedule_ruleset_annual_min_max_value(clg_sch)['min']
          if min_c < temp_c
            cld = true
          end
        elsif clg_sch.to_ScheduleConstant.is_initialized
          clg_sch = clg_sch.to_ScheduleConstant.get
          min_c = schedule_constant_annual_min_max_value(clg_sch)['min']
          if min_c < temp_c
            cld = true
          end
        elsif clg_sch.to_ScheduleCompact.is_initialized
          clg_sch = clg_sch.to_ScheduleCompact.get
          min_c = schedule_compact_annual_min_max_value(clg_sch)['min']
          if min_c < temp_c
            cld = true
          end
        else
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{thermal_zone.name} used an unknown schedule type for the cooling setpoint; assuming cooled.")
          cld = true
        end
      end
    elsif tstat.to_ZoneControlThermostatStagedDualSetpoint
      tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
      clg_sch = tstat.coolingTemperatureSetpointSchedule
      if clg_sch.is_initialized
        clg_sch = clg_sch.get
        if clg_sch.to_ScheduleRuleset.is_initialized
          clg_sch = clg_sch.to_ScheduleRuleset.get
          min_c = schedule_ruleset_annual_min_max_value(clg_sch)['min']
          if min_c < temp_c
            cld = true
          end
        end
      end
    end

    return cld
  end

  # Determine if the thermal zone is a plenum
  # based on whether a majority of the spaces
  # in the zone are plenums or not.
  # @return [Bool] true if majority plenum, false if not
  def thermal_zone_plenum?(thermal_zone)
    plenum_status = false

    area_plenum = 0
    area_non_plenum = 0
    thermal_zone.spaces.each do |space|
      if space_plenum?(space)
        area_plenum += space.floorArea
      else
        area_non_plenum += space.floorArea
      end
    end

    # Majority
    if area_plenum > area_non_plenum
      plenum_status = true
    end

    return plenum_status
  end

  # Determine if this zone is a vestibule.
  # Zone must be less than 200ft^2 and
  # also have an infiltration object specified
  # using Flow/Zone.
  # @return [Bool] returns true if vestibule, false if not
  def thermal_zone_vestibule?(thermal_zone)
    is_vest = false

    # Check area
    return is_vest if thermal_zone.floorArea < OpenStudio.convert(200, 'ft^2', 'm^2').get

    # Check presence of infiltration
    thermal_zone.spaces.each do |space|
      space.spaceInfiltrationDesignFlowRates.each do |infil|
        if infil.designFlowRate.is_initialized
          is_vest = true
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ThermalZone', "For #{thermal_zone.name}: This zone is considered a vestibule.")
          break
        end
      end
    end

    return is_vest
  end

  # Determines whether the zone is conditioned per 90.1,
  # which is based on heating and cooling loads.
  #
  # @param climate_zone [String] climate zone
  # @return [String] NonResConditioned, ResConditioned, Semiheated, Unconditioned
  # @todo add logic to detect indirectly-conditioned spaces
  def thermal_zone_conditioning_category(thermal_zone, climate_zone)
    # Get the heating load
    htg_load_btu_per_ft2 = 0.0
    htg_load_w_per_m2 = thermal_zone.heatingDesignLoad
    if htg_load_w_per_m2.is_initialized
      htg_load_btu_per_ft2 = OpenStudio.convert(htg_load_w_per_m2.get, 'W/m^2', 'Btu/hr*ft^2').get
    end

    # Get the cooling load
    clg_load_btu_per_ft2 = 0.0
    clg_load_w_per_m2 = thermal_zone.coolingDesignLoad
    if clg_load_w_per_m2.is_initialized
      clg_load_btu_per_ft2 = OpenStudio.convert(clg_load_w_per_m2.get, 'W/m^2', 'Btu/hr*ft^2').get
    end

    # Determine the heating limit based on climate zone
    # From Table 3.1 Heated Space Criteria
    htg_lim_btu_per_ft2 = 0.0
    case climate_zone
    when 'ASHRAE 169-2006-0A',
        'ASHRAE 169-2006-0B',
        'ASHRAE 169-2006-1A',
        'ASHRAE 169-2006-1B',
        'ASHRAE 169-2006-2A',
        'ASHRAE 169-2006-2B',
        'ASHRAE 169-2013-0A',
        'ASHRAE 169-2013-0B',
        'ASHRAE 169-2013-1A',
        'ASHRAE 169-2013-1B',
        'ASHRAE 169-2013-2A',
        'ASHRAE 169-2013-2B'
      htg_lim_btu_per_ft2 = 5
    when 'ASHRAE 169-2006-3A',
        'ASHRAE 169-2006-3B',
        'ASHRAE 169-2006-3C',
        'ASHRAE 169-2013-3A',
        'ASHRAE 169-2013-3B',
        'ASHRAE 169-2013-3C'
      htg_lim_btu_per_ft2 = 10
    when 'ASHRAE 169-2006-4A',
        'ASHRAE 169-2006-4B',
        'ASHRAE 169-2006-4C',
        'ASHRAE 169-2006-5A',
        'ASHRAE 169-2006-5B',
        'ASHRAE 169-2006-5C',
        'ASHRAE 169-2013-4A',
        'ASHRAE 169-2013-4B',
        'ASHRAE 169-2013-4C',
        'ASHRAE 169-2013-5A',
        'ASHRAE 169-2013-5B',
        'ASHRAE 169-2013-5C'
      htg_lim_btu_per_ft2 = 15
    when 'ASHRAE 169-2006-6A',
        'ASHRAE 169-2006-6B',
        'ASHRAE 169-2006-7A',
        'ASHRAE 169-2006-7B',
        'ASHRAE 169-2013-6A',
        'ASHRAE 169-2013-6B',
        'ASHRAE 169-2013-7A',
        'ASHRAE 169-2013-7B'
      htg_lim_btu_per_ft2 = 20
    when 'ASHRAE 169-2006-8A',
        'ASHRAE 169-2006-8B',
        'ASHRAE 169-2013-8A',
        'ASHRAE 169-2013-8B'
      htg_lim_btu_per_ft2 = 25
    end

    # Cooling limit is climate-independent
    clg_lim_btu_per_ft2 = 5

    # Semiheated limit is climate-independent
    semihtd_lim_btu_per_ft2 = 3.4

    # Determine if residential
    res = false
    if thermal_zone_residential?(thermal_zone)
      res = true
    end

    cond_cat = 'Unconditioned'
    if htg_load_btu_per_ft2 > htg_lim_btu_per_ft2
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{thermal_zone.name} is conditioned because heating load of #{htg_load_btu_per_ft2.round} Btu/hr*ft^2 exceeds minimum of #{htg_lim_btu_per_ft2.round} Btu/hr*ft^2.")
      cond_cat = if res
                   'ResConditioned'
                 else
                   'NonResConditioned'
                 end
    elsif clg_load_btu_per_ft2 > clg_lim_btu_per_ft2
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{thermal_zone.name} is conditioned because cooling load of #{clg_load_btu_per_ft2.round} Btu/hr*ft^2 exceeds minimum of #{clg_lim_btu_per_ft2.round} Btu/hr*ft^2.")
      cond_cat = if res
                   'ResConditioned'
                 else
                   'NonResConditioned'
                 end
    elsif htg_load_btu_per_ft2 > semihtd_lim_btu_per_ft2
      cond_cat = 'Semiheated'
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{thermal_zone.name} is semiheated because heating load of #{htg_load_btu_per_ft2.round} Btu/hr*ft^2 exceeds minimum of #{semihtd_lim_btu_per_ft2.round} Btu/hr*ft^2.")
    end

    return cond_cat
  end

  # Calculate the heating supply temperature based on the
  # specified delta-T. Delta-T is calculated based on the
  # highest value found in the heating setpoint schedule.
  #
  # @return [Double] the design heating supply temperature, in C
  # @todo Exception: 17F delta-T for labs
  def thermal_zone_prm_baseline_heating_design_supply_temperature(thermal_zone)
    setpoint_c = nil

    # Setpoint schedule
    tstat = thermal_zone.thermostatSetpointDualSetpoint
    if tstat.is_initialized
      tstat = tstat.get
      setpoint_sch = tstat.heatingSetpointTemperatureSchedule
      if setpoint_sch.is_initialized
        setpoint_sch = setpoint_sch.get
        if setpoint_sch.to_ScheduleRuleset.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleRuleset.get
          setpoint_c = schedule_ruleset_annual_min_max_value(setpoint_sch)['max']
        elsif setpoint_sch.to_ScheduleConstant.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleConstant.get
          setpoint_c = schedule_constant_annual_min_max_value(setpoint_sch)['max']
        elsif setpoint_sch.to_ScheduleCompact.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleCompact.get
          setpoint_c = schedule_compact_annual_min_max_value(setpoint_sch)['max']
        end
      end
    end

    # If the heating setpoint could not be determined
    # return the current design heating temperature
    if setpoint_c.nil?
      setpoint_c = thermal_zone.sizingZone.zoneHeatingDesignSupplyAirTemperature
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}: could not determine max heating setpoint.  Design heating SAT will be #{OpenStudio.convert(setpoint_c, 'C', 'F').get.round} F from proposed model.")
      return setpoint_c
    end

    # If the heating setpoint was set very low so that
    # heating equipment never comes on
    # return the current design heating temperature
    if setpoint_c < OpenStudio.convert(41, 'F', 'C').get
      setpoint_f = OpenStudio.convert(setpoint_c, 'C', 'F').get
      new_setpoint_c = thermal_zone.sizingZone.zoneHeatingDesignSupplyAirTemperature
      new_setpoint_f = OpenStudio.convert(new_setpoint_c, 'C', 'F').get
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}: max heating setpoint in proposed model was #{setpoint_f.round} F.  20 F SAT delta-T from this point is unreasonable. Design heating SAT will be #{new_setpoint_f.round} F from proposed model.")
      return new_setpoint_c
    end

    # Add 20F delta-T
    delta_t_r = 20
    delta_t_k = OpenStudio.convert(delta_t_r, 'R', 'K').get

    sat_c = setpoint_c + delta_t_k # Add for heating

    return sat_c
  end

  # Calculate the cooling supply temperature based on the
  # specified delta-T. Delta-T is calculated based on the
  # highest value found in the cooling setpoint schedule.
  #
  # @return [Double] the design heating supply temperature, in C
  # @todo Exception: 17F delta-T for labs
  def thermal_zone_prm_baseline_cooling_design_supply_temperature(thermal_zone)
    setpoint_c = nil

    # Setpoint schedule
    tstat = thermal_zone.thermostatSetpointDualSetpoint
    if tstat.is_initialized
      tstat = tstat.get
      setpoint_sch = tstat.coolingSetpointTemperatureSchedule
      if setpoint_sch.is_initialized
        setpoint_sch = setpoint_sch.get
        if setpoint_sch.to_ScheduleRuleset.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleRuleset.get
          setpoint_c = schedule_ruleset_annual_min_max_value(setpoint_sch)['min']
        elsif setpoint_sch.to_ScheduleConstant.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleConstant.get
          setpoint_c = schedule_constant_annual_min_max_value(setpoint_sch)['min']
        elsif setpoint_sch.to_ScheduleCompact.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleCompact.get
          setpoint_c = schedule_compact_annual_min_max_value(setpoint_sch)['min']
        end
      end
    end

    # If the cooling setpoint could not be determined
    # return the current design cooling temperature
    if setpoint_c.nil?
      setpoint_c = thermal_zone.sizingZone.zoneCoolingDesignSupplyAirTemperature
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}: could not determine min cooling setpoint.  Design cooling SAT will be #{OpenStudio.convert(setpoint_c, 'C', 'F').get.round} F from proposed model.")
      return setpoint_c
    end

    # If the cooling setpoint was set very high so that
    # cooling equipment never comes on
    # return the current design cooling temperature
    if setpoint_c > OpenStudio.convert(91, 'F', 'C').get
      setpoint_f = OpenStudio.convert(setpoint_c, 'C', 'F').get
      new_setpoint_c = thermal_zone.sizingZone.zoneCoolingDesignSupplyAirTemperature
      new_setpoint_f = OpenStudio.convert(new_setpoint_c, 'C', 'F').get
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}: max cooling setpoint in proposed model was #{setpoint_f.round} F.  20 F SAT delta-T from this point is unreasonable. Design cooling SAT will be #{new_setpoint_f.round} F from proposed model.")
      return new_setpoint_c
    end

    # Subtract 20F delta-T
    delta_t_r = 20
    delta_t_k = OpenStudio.convert(delta_t_r, 'R', 'K').get

    sat_c = setpoint_c - delta_t_k # Subtract for cooling

    return sat_c
  end

  # Set the design delta-T for zone heating and cooling sizing
  # supply air temperatures.  This value determines zone
  # air flows, which will be summed during system
  # design airflow calculation.
  #
  # @return [Bool] true if successful, false if not
  def thermal_zone_apply_prm_baseline_supply_temperatures(thermal_zone)
    # Skip spaces that aren't heated or cooled
    return true unless thermal_zone_heated?(thermal_zone) || thermal_zone_cooled?(thermal_zone)

    # Heating
    htg_sat_c = thermal_zone_prm_baseline_heating_design_supply_temperature(thermal_zone)
    htg_success = thermal_zone.sizingZone.setZoneHeatingDesignSupplyAirTemperature(htg_sat_c)

    # Cooling
    clg_sat_c = thermal_zone_prm_baseline_cooling_design_supply_temperature(thermal_zone)
    clg_success = thermal_zone.sizingZone.setZoneCoolingDesignSupplyAirTemperature(clg_sat_c)

    htg_sat_f = OpenStudio.convert(htg_sat_c, 'C', 'F').get
    clg_sat_f = OpenStudio.convert(clg_sat_c, 'C', 'F').get
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "For #{thermal_zone.name}, Htg SAT = #{htg_sat_f.round(1)}F, Clg SAT = #{clg_sat_f.round(1)}F.")

    result = false
    if htg_success && clg_success
      result = true
    end

    return result
  end

  # Adds a thermostat that heats the space to 0 F and cools to 120 F.
  # These numbers are outside of the threshold that is considered heated
  # or cooled by thermal_zone_cooled?() and thermal_zone_heated?()
  def thermal_zone_add_unconditioned_thermostat(thermal_zone)
    # Heated to 0F (below thermal_zone_heated?(thermal_zone)  threshold)
    htg_t_f = 0
    htg_t_c = OpenStudio.convert(htg_t_f, 'F', 'C').get
    htg_stpt_sch = OpenStudio::Model::ScheduleRuleset.new(thermal_zone.model)
    htg_stpt_sch.setName('Unconditioned Minimal Heating')
    htg_stpt_sch.defaultDaySchedule.setName('Unconditioned Minimal Heating Default')
    htg_stpt_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), htg_t_c)

    # Cooled to 120F (above thermal_zone_cooled?(thermal_zone)  threshold)
    clg_t_f = 120
    clg_t_c = OpenStudio.convert(clg_t_f, 'F', 'C').get
    clg_stpt_sch = OpenStudio::Model::ScheduleRuleset.new(thermal_zone.model)
    clg_stpt_sch.setName('Unconditioned Minimal Heating')
    clg_stpt_sch.defaultDaySchedule.setName('Unconditioned Minimal Heating Default')
    clg_stpt_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_t_c)

    # Thermostat
    thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(thermal_zone.model)
    thermostat.setName("#{thermal_zone.name} Unconditioned Thermostat")
    thermostat.setHeatingSetpointTemperatureSchedule(htg_stpt_sch)
    thermostat.setCoolingSetpointTemperatureSchedule(clg_stpt_sch)

    return true
  end

  # Determine the design internal load (W) for
  # this zone without space multipliers.
  # This include People, Lights, Electric Equipment,
  # and Gas Equipment in all spaces in this zone.
  # It assumes 100% of the wattage
  # is converted to heat, and that the design peak
  # schedule value is 1 (100%).
  #
  # @return [Double] the design internal load, in W
  def thermal_zone_design_internal_load(thermal_zone)
    load_w = 0.0

    thermal_zone.spaces.each do |space|
      load_w += space_design_internal_load(space)
    end

    return load_w
  end

  # Returns the space type that represents a majority
  # of the floor area.
  #
  # @return [Boost::Optional<OpenStudio::Model::SpaceType>] an optional SpaceType
  def thermal_zone_majority_space_type(thermal_zone)
    space_type_to_area = Hash.new(0.0)

    thermal_zone.spaces.each do |space|
      if space.spaceType.is_initialized
        space_type = space.spaceType.get
        space_type_to_area[space_type] += space.floorArea
      end
    end

    # If no space types, return empty optional SpaceType
    if space_type_to_area.size.zero?
      return OpenStudio::Model::OptionalSpaceType.new
    end

    # Sort by area
    biggest_space_type = space_type_to_area.sort_by { |st, area| area }.reverse[0][0]

    return OpenStudio::Model::OptionalSpaceType.new(biggest_space_type)
  end

  # Returns the building type that represents the majority of floor area
  #
  # @return [String] the building type
  def thermal_zone_building_type(thermal_zone)

    # determine areas of each building type
    building_type_areas = {}
    thermal_zone.spaces.each do |space|
      # ignore space if not part of total area
      next unless space.partofTotalFloorArea
      if space.spaceType.is_initialized
        space_type = space.spaceType.get
        if space_type.standardsBuildingType.is_initialized
          building_type = space_type.standardsBuildingType.get
          if building_type_areas[building_type].nil?
            building_type_areas[building_type] = space.floorArea
          else
            building_type_areas[building_type] += space.floorArea
          end
        end
      end
    end

    # return largest building type area
    building_type = building_type_areas.key(building_type_areas.values.max)

    if building_type.nil?
      OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.ThermalZone", "Thermal zone #{thermal_zone.name} does not have standards building type.")
    end

    return building_type
  end

  # Determine the thermal zone's occupancy type category.
  # Options are: residential, nonresidential
  #
  # @return [String] the occupancy type category
  # @todo Add public assembly building types
  def thermal_zone_occupancy_type(thermal_zone)
    occ_type = if thermal_zone_residential?(thermal_zone)
                 'residential'
               else
                 'nonresidential'
               end

    # OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.ThermalZone", "For #{self.name}, occupancy type = #{occ_type}.")

    return occ_type
  end

  # Determine if demand control ventilation (DCV) is
  # required for this zone based on area and occupant density.
  # Does not account for System requirements like ERV, economizer, etc.
  # Those are accounted for in the AirLoopHVAC method of the same name.
  #
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for 90.1-2013
  #   for cells, sickrooms, labs, barbers, salons, and bowling alleys
  def thermal_zone_demand_control_ventilation_required?(thermal_zone, climate_zone)
    dcv_required = false

    # Get the limits
    min_area_m2, min_area_m2_per_occ = thermal_zone_demand_control_ventilation_limits(thermal_zone)

    # Not required if both limits nil
    if min_area_m2.nil? && min_area_m2_per_occ.nil?
      return dcv_required
    end

    # Get the area served and the number of occupants
    area_served_m2 = 0
    num_people = 0
    thermal_zone.spaces.each do |space|
      area_served_m2 += space.floorArea
      num_people += space.numberOfPeople
    end
    area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get

    # Check the minimum area if there is a limit
    if min_area_m2
      # Convert limit to IP
      min_area_ft2 = OpenStudio.convert(min_area_m2, 'm^2', 'ft^2').get
      # Check the limit
      if area_served_ft2 < min_area_ft2
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ThermalZone', "For #{thermal_zone.name}: DCV is not required since the area is #{area_served_ft2.round} ft2, but the minimum size is #{min_area_ft2.round} ft2.")
        return dcv_required
      end
    end

    # Check the minimum occupancy density if there is a limit
    if min_area_m2_per_occ
      # Convert limit to IP
      min_area_ft2_per_occ = OpenStudio.convert(min_area_m2_per_occ, 'm^2', 'ft^2').get
      min_occ_per_ft2 = 1.0 / min_area_ft2_per_occ
      min_occ_per_1000_ft2 = min_occ_per_ft2 * 1000
      # Check the limit
      occ_per_ft2 = num_people / area_served_ft2
      occ_per_1000_ft2 = occ_per_ft2 * 1000
      if occ_per_1000_ft2 < min_occ_per_1000_ft2
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ThermalZone', "For #{thermal_zone.name}: DCV is not required since the occupant density is #{occ_per_1000_ft2.round} people/1000 ft2, but the minimum occupant density is #{min_occ_per_1000_ft2.round} people/1000 ft2.")
        return dcv_required
      end
    end

    # If here, DCV is required
    dcv_required = true

    return dcv_required
  end

  # Determine the area and occupancy level limits for
  # demand control ventilation.  No DCV requirements by default.
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] the thermal zone
  # @return [Array<Double>] the minimum area, in m^2
  # and the minimum occupancy density in m^2/person.  Returns nil
  # if there is no requirement.
  def thermal_zone_demand_control_ventilation_limits(thermal_zone)
    min_area_m2 = nil
    min_area_per_occ = nil
    return [min_area_m2, min_area_per_occ]
  end

  # Add Exhaust Fans based on space type lookup
  # This measure doesn't look if DCV is needed. Others methods can check if DCV needed and add it
  #
  # @return [Hash] Hash of newly made exhaust fan objects along with secondary exhaust and zone mixing objects
  # @todo - Combine availability and fraction flow schedule to make zone mixing schedule
  def thermal_zone_add_exhaust(thermal_zone, exhaust_makeup_inputs = {})
    exhaust_fans = {} # key is primary exhaust value is hash of arrays of secondary objects

    # hash to store space type information
    space_type_hash = {} # key is space type value is floor_area_si

    # get space type ratio for spaces in zone, making more than one exhaust fan if necessary
    thermal_zone.spaces.each do |space|
      next unless space.spaceType.is_initialized
      next unless space.partofTotalFloorArea
      space_type = space.spaceType.get
      if space_type_hash.key?(space_type)
        space_type_hash[space_type] += space.floorArea # excluding space.multiplier since used to calc loads in zone
      else
        next unless space_type.standardsBuildingType.is_initialized
        next unless space_type.standardsSpaceType.is_initialized
        space_type_hash[space_type] = space.floorArea # excluding space.multiplier since used to calc loads in zone
      end
    end

    # loop through space type hash and add exhaust as needed
    space_type_hash.each do |space_type, floor_area|
      # get floor custom or calculated floor area for max flow rate calculation
      makeup_target = [space_type.standardsBuildingType.get, space_type.standardsSpaceType.get]
      if exhaust_makeup_inputs.key?(makeup_target) && exhaust_makeup_inputs[makeup_target].key?(:target_effective_floor_area)
        # pass in custom floor area
        floor_area_si = exhaust_makeup_inputs[makeup_target][:target_effective_floor_area] / thermal_zone.multiplier.to_f
        floor_area_ip = OpenStudio.convert(floor_area_si, 'm^2', 'ft^2').get
      else
        floor_area_ip = OpenStudio.convert(floor_area, 'm^2', 'ft^2').get
      end

      space_type_properties = space_type_get_standards_data(space_type)
      exhaust_per_area = space_type_properties['exhaust_per_area']
      next if exhaust_per_area.nil?
      maximum_flow_rate_ip = exhaust_per_area * floor_area_ip
      maximum_flow_rate_si = OpenStudio.convert(maximum_flow_rate_ip, 'cfm', 'm^3/s').get
      if space_type_properties['exhaust_availability_schedule'].nil?
        exhaust_schedule = thermal_zone.model.alwaysOnDiscreteSchedule
        exhaust_flow_schedule = exhaust_schedule
      else
        sch_name = space_type_properties['exhaust_availability_schedule']
        exhaust_schedule = model_add_schedule(thermal_zone.model, sch_name)
        flow_sch_name = space_type_properties['exhaust_flow_fraction_schedule']
        exhaust_flow_schedule = model_add_schedule(thermal_zone.model, flow_sch_name)
          unless exhaust_schedule
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "Could not find an exhaust schedule called #{sch_name}, exhaust fans will run continuously.")
          exhaust_schedule = thermal_zone.model.alwaysOnDiscreteSchedule
        end
      end

      # add exhaust fans
      zone_exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(thermal_zone.model)
      zone_exhaust_fan.setName(thermal_zone.name.to_s + ' Exhaust Fan')
      zone_exhaust_fan.setAvailabilitySchedule(exhaust_schedule)
      zone_exhaust_fan.setFlowFractionSchedule(exhaust_flow_schedule)
      # not using zone_exhaust_fan.setFlowFractionSchedule. Exhaust fans are on when available
      zone_exhaust_fan.setMaximumFlowRate(maximum_flow_rate_si)
      zone_exhaust_fan.setEndUseSubcategory('Zone Exhaust Fans')
      zone_exhaust_fan.addToThermalZone(thermal_zone)
      exhaust_fans[zone_exhaust_fan] = {} # keys are :zone_mixing and :transfer_air_source_zone_exhaust

      # set fan pressure rise
      fan_zone_exhaust_apply_prototype_fan_pressure_rise(zone_exhaust_fan)

      # update efficiency and pressure rise
      prototype_fan_apply_prototype_fan_efficiency(zone_exhaust_fan)

      # add and alter objectxs related to zone exhaust makeup air
      if exhaust_makeup_inputs.key?(makeup_target) && exhaust_makeup_inputs[makeup_target][:source_zone]

        # add balanced schedule to zone_exhaust_fan
        balanced_sch_name = space_type_properties['balanced_exhaust_fraction_schedule']
        balanced_exhaust_schedule = model_add_schedule(thermal_zone.model, balanced_sch_name).to_ScheduleRuleset.get
        zone_exhaust_fan.setBalancedExhaustFractionSchedule(balanced_exhaust_schedule)

        # use max value of balanced exhaust fraction schedule for maximum flow rate
        max_sch_val = schedule_ruleset_annual_min_max_value(balanced_exhaust_schedule)['max']
        transfer_air_zone_mixing_si = maximum_flow_rate_si * max_sch_val

        # add dummy exhaust fan to a transfer_air_source_zones
        transfer_air_source_zone_exhaust = OpenStudio::Model::FanZoneExhaust.new(thermal_zone.model)
        transfer_air_source_zone_exhaust.setName(thermal_zone.name.to_s + ' Transfer Air Source')
        transfer_air_source_zone_exhaust.setAvailabilitySchedule(exhaust_schedule)
        # not using zone_exhaust_fan.setFlowFractionSchedule. Exhaust fans are on when available
        transfer_air_source_zone_exhaust.setMaximumFlowRate(transfer_air_zone_mixing_si)
        transfer_air_source_zone_exhaust.setFanEfficiency(1.0)
        transfer_air_source_zone_exhaust.setPressureRise(0.0)
        transfer_air_source_zone_exhaust.setEndUseSubcategory('Zone Exhaust Fans')
        transfer_air_source_zone_exhaust.addToThermalZone(exhaust_makeup_inputs[makeup_target][:source_zone])
        exhaust_fans[zone_exhaust_fan][:transfer_air_source_zone_exhaust] = transfer_air_source_zone_exhaust

        # TODO: - make zone mixing schedule by combining exhaust availability and fraction flow
        zone_mixing_schedule = exhaust_schedule

        # add zone mixing
        zone_mixing = OpenStudio::Model::ZoneMixing.new(thermal_zone)
        zone_mixing.setSchedule(zone_mixing_schedule)
        zone_mixing.setSourceZone(exhaust_makeup_inputs[makeup_target][:source_zone])
        zone_mixing.setDesignFlowRate(transfer_air_zone_mixing_si)
        exhaust_fans[zone_exhaust_fan][:zone_mixing] = zone_mixing

      end
    end

    return exhaust_fans
  end

  # returns adjacant_zones_with_shared_wall_areas
  #
  # @param [Bool] same_floor (only valid option for now is true)
  # @return [Array] adjacent zones
  def thermal_zone_get_adjacent_zones_with_shared_wall_areas(thermal_zone, same_floor = true)
    adjacent_zones = []

    thermal_zone.spaces.each do |space|
      adj_spaces = space_get_adjacent_spaces_with_shared_wall_areas(space)
      adj_spaces.each do |k, v|
        # skip if space is in current thermal zone.
        next unless space.thermalZone.is_initialized
        next if k.thermalZone.get == thermal_zone
        adjacent_zones << k.thermalZone.get
      end
    end

    adjacent_zones = adjacent_zones.uniq

    return adjacent_zones
  end

  # returns true if DCV is required for exhaust fan for specified tempate
  #
  # @return [Bool] returns true if DCV is required for exhaust fan for specified tempate
  def thermal_zone_exhaust_fan_dcv_required?(thermal_zone); end

  # Add DCV to exhaust fan and if requsted to related objects
  #
  # @return [Bool] not sure if there is anything to turn here other than if it was sucessful, no new objects made?
  def thermal_zone_add_exhaust_fan_dcv(thermal_zone, change_related_objects = true, zone_mixing_objects = [], transfer_air_source_zones = [])
    # set flow fraction schedule for all zone exhaust fans and then set zone mixing schedule to the intersection of exhaust avaialability and exhaust fractional schedule

    # are there associated zone mixing or dummy exhaust objects that need to change when this changes?
    # How are these ojects identifed?
    # If this is run directly after thermal_zone_add_exhaust(thermal_zone)  it will return a hash where each key is an exhaust object and hash is a hash of related zone mizing and dummy exhaust from the source zone
  end
end

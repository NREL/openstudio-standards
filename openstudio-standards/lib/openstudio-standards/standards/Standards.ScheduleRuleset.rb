
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ScheduleRuleset

  # Returns the equivalent full load hours (EFLH) for this schedule.
  # For example, an always-on fractional schedule 
  # (always 1.0, 24/7, 365) would return a value of 8760. 
  #
  # @author Andrew Parker, NREL.  Matt Leach, NORESCO.
  # return [Double] The total number of full load hours for this schedule.
  def annual_equivalent_full_load_hrs()

    OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Calculating total annual EFLH for schedule: #{self.name}")

    # Define the start and end date
    year_start_date = nil
    year_end_date = nil
    if model.yearDescription.is_initialized
      year_description = model.yearDescription.get
      year = year_description.assumedYear
      year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new("January"),1,year)
      year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new("December"),31,year)
    else
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.ScheduleRuleset", "WARNING: Year description is not specified; assuming 2009, the default year OS uses.")
      year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new("January"),1,2009)
      year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new("December"),31,2009)
    end

    # Get the ordered list of all the day schedules
    # that are used by this schedule ruleset
    day_schs = self.getDaySchedules(year_start_date, year_end_date)
    OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "***Day Schedules Used***")
    day_schs.uniq.each do |day_sch|
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  #{day_sch.name.get}")
    end
    
    # Get a 365-value array of which schedule is used on each day of the year,
    day_schs_used_each_day = self.getActiveRuleIndices(year_start_date, year_end_date)
    if !day_schs_used_each_day.length == 365
      OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.ScheduleRuleset", "#{self.name} does not have 365 daily schedules accounted for, cannot accurately calculate annual EFLH.")
      return 0
    end
    
    # Create a map that shows how many days each schedule is used
    day_sch_freq = day_schs_used_each_day.group_by { |n| n }
    
    # Build a hash that maps schedule day index to schedule day
    schedule_index_to_day = {}
    for i in 0..(day_schs.length-1)
      schedule_index_to_day[day_schs_used_each_day[i]] = day_schs[i]
    end
        
    # Loop through each of the schedules that is used, figure out the
    # full load hours for that day, then multiply this by the number
    # of days that day schedule applies and add this to the total.
    annual_flh = 0
    max_daily_flh = 0
    default_day_sch = self.defaultDaySchedule
    day_sch_freq.each do |freq|
      #OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", freq.inspect
      #exit

      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Schedule Index = #{freq[0]}"
      sch_index = freq[0]
      number_of_days_sch_used = freq[1].size

      # Get the day schedule at this index
      day_sch = nil
      if sch_index == -1 # If index = -1, this day uses the default day schedule (not a rule)
        day_sch = default_day_sch
      else
        day_sch = schedule_index_to_day[sch_index]
      end
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "Calculating EFLH for: #{day_sch.name}")
      
      # Determine the full load hours for just one day
      daily_flh = 0
      values = day_sch.values
      times = day_sch.times
      
      previous_time_decimal = 0
      for i in 0..(times.length - 1)
        time_days = times[i].days
        time_hours = times[i].hours
        time_minutes = times[i].minutes
        time_seconds = times[i].seconds
        time_decimal = (time_days*24) + time_hours + (time_minutes/60) + (time_seconds/3600)
        duration_of_value = time_decimal - previous_time_decimal
        OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  Value of #{values[i]} for #{duration_of_value} hours")
        daily_flh += values[i]*duration_of_value
        previous_time_decimal = time_decimal
      end

      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  #{daily_flh.round(2)} EFLH per day")
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.ScheduleRuleset", "  Used #{number_of_days_sch_used} days per year")

      # Multiply the daily EFLH by the number
      # of days this schedule is used per year
      # and add this to the overall total
      annual_flh += daily_flh * number_of_days_sch_used

    end

    # Warn if the max daily EFLH is more than 24,
    # which would indicate that this isn't a 
    # fractional schedule.
    if max_daily_flh > 24
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.ScheduleRuleset", "#{self.name} has more than 24 EFLH in one day schedule, indicating that it is not a fractional schedule.")
    end    
    
    return annual_flh

  end		

end

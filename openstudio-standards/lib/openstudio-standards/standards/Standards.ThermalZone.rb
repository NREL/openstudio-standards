
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ThermalZone

  # Calculates the zone outdoor airflow requirement (Voz)
  # based on the inputs in the DesignSpecification:OutdoorAir obects
  # in all spaces in the zone.
  #
  # @return [Double] the zone outdoor air flow rate
  #   @units cubic meters per second (m^3/s)
  def outdoor_airflow_rate

    tot_oa_flow_rate = 0.0
  
    spaces = self.spaces.sort

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
      oa_for_floor_area = floorArea * dsn_oa.outdoorAirFlowperFloorArea
      oa_rate = dsn_oa.outdoorAirFlowRate
      oa_for_volume = volume * dsn_oa.outdoorAirFlowAirChangesperHour

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
    tot_oa_flow_rate_cfm = OpenStudio.convert(tot_oa_flow_rate,'m^3/s','cfm').get
    
    OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "For #{self.name}, design min OA = #{tot_oa_flow_rate_cfm.round} cfm.")
    
    return tot_oa_flow_rate

  end

  # Calculates the zone outdoor airflow requirement and
  # divides by the zone area.
  #
  # @return [Double] the zone outdoor air flow rate per area
  #   @units cubic meters per second (m^3/s)
  def outdoor_airflow_rate_per_area()

    tot_oa_flow_rate_per_area = 0.0

    # Find total area of the zone
    sum_floor_area = 0.0
    self.spaces.sort.each do |space|
      sum_floor_area += space.floorArea
    end

    # Get the OA flow rate
    tot_oa_flow_rate = outdoor_airflow_rate
    
    # Calculate the per-area value
    tot_oa_flow_rate_per_area = tot_oa_flow_rate / sum_floor_area

    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "For #{self.name}, OA per area = #{tot_oa_flow_rate_per_area.round(8)} m^3/s*m^2.")

    return tot_oa_flow_rate_per_area

  end

  # This method creates a schedule where the value is zero when
  # the overall occupancy for 1 zone is below
  # the specified threshold, and one when the overall occupancy is
  # greater than or equal to the threshold.  This method is designed
  # to use the total number of people in the zone.
  #
  # @param occupied_percentage_threshold [Double] the minimum fraction (0 to 1) that counts as occupied
  # @return [ScheduleRuleset] a ScheduleRuleset where 0 = unoccupied, 1 = occupied
  # @todo Speed up this method.  Bottleneck is ScheduleRule.getDaySchedules
 def get_occupancy_schedule(occupied_percentage_threshold = 0.05)

    # Get all the occupancy schedules in every space in the zone
    # Include people added via the SpaceType
    # in addition to people hard-assigned to the Space itself.
    occ_schedules_num_occ = {}
    max_occ_on_thermal_zone = 0
	
    # Get the people objects
    self.spaces.each do |space|
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
              max_occ_on_thermal_zone += num_ppl     
            else
              occ_schedules_num_occ[num_ppl_sch] += num_ppl
              max_occ_on_thermal_zone += num_ppl
            end
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
            max_occ_on_thermal_zone += num_ppl     
          else
            occ_schedules_num_occ[num_ppl_sch] += num_ppl
            max_occ_on_thermal_zone += num_ppl
          end
        end
      end
    end
	   
    # For each day of the year, determine
    #time_value_pairs = []
    year = self.model.getYearDescription
    yearly_data = []
    yearly_times = OpenStudio::DateTimeVector.new
    yearly_values = []
    for i in 1..365

      times_on_this_day = []
      os_date = year.makeDate(i)
      day_of_week = os_date.dayOfWeek.valueName
    
      # Get the unique time indices and corresponding day schedules
      occ_schedules_day_schs = {}
      day_sch_num_occ = {}
      occ_schedules_num_occ.each do |occ_sch, num_occ|
        
        # Get the day schedules for this day
        # (there should only be one)
        day_schs = occ_sch.getDaySchedules(os_date, os_date)
        day_schs[0].times.each do |time|
          times_on_this_day << time.toString
        end
        day_sch_num_occ[day_schs[0]] = num_occ
        
      end

      # Determine the total fraction for the airloop at each time
      daily_times = []
      daily_os_times = []
      daily_values = []
      daily_occs = []
      times_on_this_day.uniq.sort.each do |time|

        os_time = OpenStudio::Time.new(time)
        os_date_time = OpenStudio::DateTime.new(os_date, os_time)
        # Total number of people at each time
        tot_occ_at_time = 0
        day_sch_num_occ.each do |day_sch, num_occ|
          occ_frac = day_sch.getValue(os_time)
          tot_occ_at_time += occ_frac * num_occ
        end
      
        # Total fraction for the airloop at each time
        thermal_zone_occ_frac = tot_occ_at_time / max_occ_on_thermal_zone
        occ_status = 0 # unoccupied
        if thermal_zone_occ_frac >= occupied_percentage_threshold
          occ_status = 1
        end

        # Add this data to the daily arrays
        daily_times << time
        daily_os_times << os_time
        daily_values << occ_status
        daily_occs << thermal_zone_occ_frac.round(2)

      end

     
      # Simplify the daily times to eliminate intermediate
      # points with the same value as the following point.
      simple_daily_times = []
      simple_daily_os_times = []
      simple_daily_values = []
      simple_daily_occs = []
      daily_values.each_with_index do |value, i| 
        next if value == daily_values[i+1]
        simple_daily_times << daily_times[i]
        simple_daily_os_times << daily_os_times[i]
        simple_daily_values << daily_values[i]
        simple_daily_occs << daily_occs[i]
      end
       
      # Store the daily values
      yearly_data << {'date'=>os_date,'day_of_week'=>day_of_week,'times'=>simple_daily_times,'values'=>simple_daily_values,'daily_os_times'=>simple_daily_os_times, 'daily_occs'=>simple_daily_occs}

    end
    
    # Create a TimeSeries from the data
    #time_series = OpenStudio::TimeSeries.new(times, values, 'unitless')

    # Make a schedule ruleset
    sch_name = "#{self.name} Occ Sch"
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(self.model)
    sch_ruleset.setName("#{sch_name}")  

    # Default - All Occupied
    day_sch = sch_ruleset.defaultDaySchedule
    day_sch.setName("#{sch_name} Default")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Winter Design Day - All Occupied
    day_sch = OpenStudio::Model::ScheduleDay.new(self.model)
    sch_ruleset.setWinterDesignDaySchedule(day_sch)
    day_sch = sch_ruleset.winterDesignDaySchedule
    day_sch.setName("#{sch_name} Winter Design Day")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)     

    # Summer Design Day - All Occupied
    day_sch = OpenStudio::Model::ScheduleDay.new(self.model)
    sch_ruleset.setSummerDesignDaySchedule(day_sch)
    day_sch = sch_ruleset.summerDesignDaySchedule
    day_sch.setName("#{sch_name} Summer Design Day")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)
    
    # Create ruleset schedules, attempting to create
    # the minimum number of unique rules.
    ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].each do |day_of_week|
      end_of_prev_rule = yearly_data[0]['date']
      yearly_data.each_with_index do |daily_data, i|
        # Skip unless it is the day of week
        # currently under inspection
        day = daily_data['day_of_week']
        next unless day == day_of_week
        date = daily_data['date']
        times = daily_data['times']
        values = daily_data['values']
        daily_occs = daily_data['daily_occs']
        
        # If the next (Monday, Tuesday, etc.)
        # is the same as today, keep going.
        # If the next is different, or if
        # we've reached the end of the year,
        # create a new rule
        if !yearly_data[i+7].nil?
          next_day_times = yearly_data[i+7]['times']
          next_day_values = yearly_data[i+7]['values']
          next if times == next_day_times && values == next_day_values
        end
        
        daily_os_times = daily_data['daily_os_times']
        daily_occs = daily_data['daily_occs']
        
        # If here, we need to make a rule to cover from the previous
        # rule to today
 
        sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
        sch_rule.setName("#{sch_name} #{day_of_week} Rule")
        day_sch = sch_rule.daySchedule
        day_sch.setName("#{sch_name} #{day_of_week}")
        daily_os_times.each_with_index do |time, i|
          value = values[i]
          next if value == values[i+1] # Don't add breaks if same value
          day_sch.addValue(time, value)
        end
        
        # Set the dates when the rule applies
        sch_rule.setStartDate(end_of_prev_rule)
        sch_rule.setEndDate(date)

        # Individual Days
        sch_rule.setApplyMonday(true) if day_of_week == 'Monday'
        sch_rule.setApplyTuesday(true) if day_of_week == 'Tuesday'
        sch_rule.setApplyWednesday(true) if day_of_week == 'Wednesday'
        sch_rule.setApplyThursday(true) if day_of_week == 'Thursday'
        sch_rule.setApplyFriday(true) if day_of_week == 'Friday'
        sch_rule.setApplySaturday(true) if day_of_week == 'Saturday'
        sch_rule.setApplySunday(true) if day_of_week == 'Sunday'
      
        # Reset the previous rule end date
        end_of_prev_rule = date + OpenStudio::Time.new(0, 24, 0, 0)
      
      end
      
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
  def is_residential(standard)
  
    # Determine the respective areas
    res_area_m2 = 0
    nonres_area_m2 = 0
    self.spaces.each do |space|
      # Ignore space if not part of total area
      next if !space.partofTotalFloorArea
      if space.is_residential(standard)
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
  def is_fossil_hybrid_or_purchased_heat
  
    is_fossil = false
  
    # Get an array of the heating fuels
    # used by the zone.  Possible values are
    # Electricity, NaturalGas, PropaneGas, FuelOil#1, FuelOil#2,
    # Coal, Diesel, Gasoline, DistrictHeating, 
    # and SolarEnergy.
    htg_fuels = self.heating_fuels
    
    if htg_fuels.include?('NaturalGas') ||
       htg_fuels.include?('PropaneGas') ||
       htg_fuels.include?('FuelOil#1') ||
       htg_fuels.include?('FuelOil#2') ||
       htg_fuels.include?('Coal') ||
       htg_fuels.include?('Diesel') ||
       htg_fuels.include?('Gasoline') ||
       htg_fuels.include?('DistrictHeating')
       
      is_fossil = true
    end
  
    #OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "For #{self.name}, heating fuels = #{htg_fuels.join(', ')}; is_fossil_hybrid_or_purchased_heat = #{is_fossil}.")
  
    return is_fossil
  
  end
  
    # Determine the net area of the zone
  # Loops on each space, and checks if part of total floor area or not
  # If not part of total floor area, it is not added to the zone floor area
  # Will multiply it by the ZONE MULTIPLIER as well!
  #
  # @return [Double] the zone net floor area in m^2 (with multiplier taken into account)
  #   @units square meters (m^2)
  def get_net_area
    area_m2 = 0
    zone_mult = self.multiplier
    self.spaces.each do |space|
      # If space is not part of floor area, we don't add it
      next if !space.partofTotalFloorArea
      area_m2 += space.floorArea
    end
    
    return area_m2 * zone_mult
    
  end
  
 
end

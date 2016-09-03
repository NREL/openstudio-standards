
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
      oa_for_floor_area = floor_area * dsn_oa.outdoorAirFlowperFloorArea
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
    tot_oa_flow_rate_cfm = OpenStudio.convert(tot_oa_flow_rate, 'm^3/s', 'cfm').get

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "For #{name}, design min OA = #{tot_oa_flow_rate_cfm.round} cfm.")

    return tot_oa_flow_rate
  end

  # Calculates the zone outdoor airflow requirement and
  # divides by the zone area.
  #
  # @return [Double] the zone outdoor air flow rate per area
  #   @units cubic meters per second (m^3/s)
  def outdoor_airflow_rate_per_area
    tot_oa_flow_rate_per_area = 0.0

    # Find total area of the zone
    sum_floor_area = 0.0
    spaces.sort.each do |space|
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
            max_occ_on_thermal_zone += num_ppl
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
          max_occ_on_thermal_zone += num_ppl
        end
      end
    end

    # For each day of the year, determine
    # time_value_pairs = []
    year = model.getYearDescription
    yearly_data = []
    yearly_times = OpenStudio::DateTimeVector.new
    yearly_values = []
    (1..365).each do |i|
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
    sch_name = "#{name} Occ Sch"
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
    sch_ruleset.setName(sch_name.to_s)

    # Default - All Occupied
    day_sch = sch_ruleset.defaultDaySchedule
    day_sch.setName("#{sch_name} Default")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Winter Design Day - All Occupied
    day_sch = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setWinterDesignDaySchedule(day_sch)
    day_sch = sch_ruleset.winterDesignDaySchedule
    day_sch.setName("#{sch_name} Winter Design Day")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Summer Design Day - All Occupied
    day_sch = OpenStudio::Model::ScheduleDay.new(model)
    sch_ruleset.setSummerDesignDaySchedule(day_sch)
    day_sch = sch_ruleset.summerDesignDaySchedule
    day_sch.setName("#{sch_name} Summer Design Day")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Create ruleset schedules, attempting to create
    # the minimum number of unique rules.
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
        daily_occs = daily_data['daily_occs']

        # If the next (Monday, Tuesday, etc.)
        # is the same as today, keep going.
        # If the next is different, or if
        # we've reached the end of the year,
        # create a new rule
        unless yearly_data[k + 7].nil?
          next_day_times = yearly_data[k + 7]['times']
          next_day_values = yearly_data[k + 7]['values']
          next if times == next_day_times && values == next_day_values
        end

        daily_os_times = daily_data['daily_os_times']
        daily_occs = daily_data['daily_occs']

        # If here, we need to make a rule to cover from the previous
        # rule to today

        sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
        sch_rule.setName("#{sch_name} #{weekday} Rule")
        day_sch = sch_rule.daySchedule
        day_sch.setName("#{sch_name} #{weekday}")
        daily_os_times.each_with_index do |time, l|
          value = values[l]
          next if value == values[l + 1] # Don't add breaks if same value
          day_sch.addValue(time, value)
        end

        # Set the dates when the rule applies
        sch_rule.setStartDate(end_of_prev_rule)
        sch_rule.setEndDate(date)

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
  def residential?(template)
    # Determine the respective areas
    res_area_m2 = 0
    nonres_area_m2 = 0
    spaces.each do |space|
      # Ignore space if not part of total area
      next unless space.partofTotalFloorArea
      if space.residential?(template)
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
  def fossil_hybrid_or_purchased_heat?
    is_fossil = false

    # Get an array of the heating fuels
    # used by the zone.  Possible values are
    # Electricity, NaturalGas, PropaneGas, FuelOil#1, FuelOil#2,
    # Coal, Diesel, Gasoline, DistrictHeating,
    # and SolarEnergy.
    htg_fuels = heating_fuels

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

    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "For #{self.name}, heating fuels = #{htg_fuels.join(', ')}; fossil_hybrid_or_purchased_heat? = #{is_fossil}.")

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
  def fossil_or_electric_type(custom)
    fossil = false
    electric = false

    # Fossil heating
    htg_fuels = heating_fuels
    if htg_fuels.include?('NaturalGas') ||
       htg_fuels.include?('PropaneGas') ||
       htg_fuels.include?('FuelOil#1') ||
       htg_fuels.include?('FuelOil#2') ||
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
    clg_fuels = cooling_fuels

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
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.Model', "For #{name}, could not determine fuel type, assuming fossil.  Heating fuels = #{htg_fuels.join(', ')}; cooling fuels = #{clg_fuels.join(', ')}.")
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
  def mixed_heating_fuel?
    is_mixed = false

    # Get an array of the heating fuels
    # used by the zone.  Possible values are
    # Electricity, NaturalGas, PropaneGas, FuelOil#1, FuelOil#2,
    # Coal, Diesel, Gasoline, DistrictHeating,
    # and SolarEnergy.
    htg_fuels = heating_fuels

    # Includes fossil
    fossil = false
    if htg_fuels.include?('NaturalGas') ||
       htg_fuels.include?('PropaneGas') ||
       htg_fuels.include?('FuelOil#1') ||
       htg_fuels.include?('FuelOil#2') ||
       htg_fuels.include?('Coal') ||
       htg_fuels.include?('Diesel') ||
       htg_fuels.include?('Gasoline')

      fossil = true
    end

    # Electric and fossil and district
    if htg_fuels.include?('Electricity') && htg_fuels.include?('DistrictHeating') && fossil
      is_mixed = true
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "For #{name}, heating mixed electricity, fossil, and district.")
    end

    # Electric and fossil
    if htg_fuels.include?('Electricity') && fossil
      is_mixed = true
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "For #{name}, heating mixed electricity and fossil.")
    end

    # Electric and district
    if htg_fuels.include?('Electricity') && htg_fuels.include?('DistrictHeating')
      is_mixed = true
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "For #{name}, heating mixed electricity and district.")
    end

    # Fossil and district
    if fossil && htg_fuels.include?('DistrictHeating')
      is_mixed = true
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "For #{name}, heating mixed fossil and district.")
    end

    return is_mixed
  end

  # Determine the net area of the zone
  # Loops on each space, and checks if part of total floor area or not
  # If not part of total floor area, it is not added to the zone floor area
  # Will multiply it by the ZONE MULTIPLIER as well!
  #
  # @return [Double] the zone net floor area in m^2 (with multiplier taken into account)
  def floor_area_with_zone_multipliers
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
  def infer_system_type
    # Determine the characteristics
    # of the equipment serving the zone
    has_air_loop = false
    air_loop_num_zones = 0
    air_loop_is_vav = false
    air_loop_has_chw = false
    has_ptac = false
    has_pthp = false
    has_unitheater = false
    equipment.each do |equip|
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
    htg_fuels = heating_fuels
    clg_fuels = cooling_fuels
    is_fossil = fossil_hybrid_or_purchased_heat?

    # Infer the HVAC type
    sys_type = 'Unknown'

    # Single zone
    if air_loop_num_zones < 2
      # Gas
      if is_fossil
        # Air Loop
        if has_air_loop
          # Gas_Furnace (as air loop)
          sys_type = if cooling_fuels.size.zero?
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
          sys_type = if cooling_fuels.size.zero?
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
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{name}, the baseline system type could not be inferred.")
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "***#{name}***")
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
  def heated?
    temp_f = 41
    temp_c = OpenStudio.convert(temp_f, 'F', 'C').get

    htd = false

    # Consider plenum zones heated
    area_plenum = 0
    area_non_plenum = 0
    spaces.each do |space|
      if space.plenum?
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

    # Unheated if no thermostat present
    if thermostat.empty?
      return htd
    end

    # Check the heating setpoint
    tstat = thermostat.get
    if tstat.to_ThermostatSetpointDualSetpoint
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      htg_sch = tstat.getHeatingSchedule
      if htg_sch.is_initialized
        htg_sch = htg_sch.get
        if htg_sch.to_ScheduleRuleset.is_initialized
          htg_sch = htg_sch.to_ScheduleRuleset.get
          max_c = htg_sch.annual_min_max_value['max']
          if max_c > temp_c
            htd = true
          end
        elsif htg_sch.to_ScheduleConstant.is_initialized
          htg_sch = htg_sch.to_ScheduleConstant.get
          max_c = htg_sch.annual_min_max_value['max']
          if max_c > temp_c
            htd = true
          end
        elsif htg_sch.to_ScheduleCompact.is_initialized
          htg_sch = htg_sch.to_ScheduleCompact.get
          max_c = htg_sch.annual_min_max_value['max']
          if max_c > temp_c
            htd = true
          end
        else
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{name} used an unknown schedule type for the heating setpoint; assuming heated.")
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
          max_c = htg_sch.annual_min_max_value['max']
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
  def cooled?
    temp_f = 91
    temp_c = OpenStudio.convert(temp_f, 'F', 'C').get

    cld = false

    # Consider plenum zones cooled
    area_plenum = 0
    area_non_plenum = 0
    spaces.each do |space|
      if space.plenum?
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

    # Unheated if no thermostat present
    if thermostat.empty?
      return cld
    end

    # Check the cooling setpoint
    tstat = thermostat.get
    if tstat.to_ThermostatSetpointDualSetpoint
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      clg_sch = tstat.getCoolingSchedule
      if clg_sch.is_initialized
        clg_sch = clg_sch.get
        if clg_sch.to_ScheduleRuleset.is_initialized
          clg_sch = clg_sch.to_ScheduleRuleset.get
          min_c = clg_sch.annual_min_max_value['min']
          if min_c < temp_c
            cld = true
          end
        elsif clg_sch.to_ScheduleConstant.is_initialized
          clg_sch = clg_sch.to_ScheduleConstant.get
          min_c = clg_sch.annual_min_max_value['min']
          if min_c < temp_c
            cld = true
          end
        elsif clg_sch.to_ScheduleCompact.is_initialized
          clg_sch = clg_sch.to_ScheduleCompact.get
          min_c = clg_sch.annual_min_max_value['min']
          if min_c < temp_c
            cld = true
          end
        else
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{name} used an unknown schedule type for the cooling setpoint; assuming cooled.")
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
          min_c = clg_sch.annual_min_max_value['min']
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
  def plenum?
    plenum_status = false

    area_plenum = 0
    area_non_plenum = 0
    spaces.each do |space|
      if space.plenum?
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

  # Determines whether the zone is conditioned per 90.1,
  # which is based on heating and cooling loads.
  #
  # @param climate_zone [String] climate zone
  # @return [String] NonResConditioned, ResConditioned, Semiheated, Unconditioned
  # @todo add logic to detect indirectly-conditioned spaces
  def conditioning_category(template, climate_zone)
    # Get the heating load
    htg_load_btu_per_ft2 = 0.0
    htg_load_w_per_m2 = heatingDesignLoad
    if htg_load_w_per_m2.is_initialized
      htg_load_btu_per_ft2 = OpenStudio.convert(htg_load_w_per_m2.get, 'W/m^2', 'Btu/hr*ft^2').get
    end

    # Get the cooling load
    clg_load_btu_per_ft2 = 0.0
    clg_load_w_per_m2 = coolingDesignLoad
    if clg_load_w_per_m2.is_initialized
      clg_load_btu_per_ft2 = OpenStudio.convert(clg_load_w_per_m2.get, 'W/m^2', 'Btu/hr*ft^2').get
    end

    # Determine the heating limit based on climate zone
    # From Table 3.1 Heated Space Criteria
    htg_lim_btu_per_ft2 = 0.0
    case climate_zone
    when 'ASHRAE 169-2006-1A',
        'ASHRAE 169-2006-1B',
        'ASHRAE 169-2006-2A',
        'ASHRAE 169-2006-2B'
      htg_lim_btu_per_ft2 = 5
    when 'ASHRAE 169-2006-3A',
        'ASHRAE 169-2006-3B',
        'ASHRAE 169-2006-3C'
      htg_lim_btu_per_ft2 = 10
    when 'ASHRAE 169-2006-4A',
        'ASHRAE 169-2006-4B',
        'ASHRAE 169-2006-4C',
        'ASHRAE 169-2006-5A',
        'ASHRAE 169-2006-5B',
        'ASHRAE 169-2006-5C',
      htg_lim_btu_per_ft2 = 15
    when 'ASHRAE 169-2006-6A',
        'ASHRAE 169-2006-6B',
        'ASHRAE 169-2006-7A',
        'ASHRAE 169-2006-7B',
      htg_lim_btu_per_ft2 = 20
    when
        'ASHRAE 169-2006-8A',
        'ASHRAE 169-2006-8B'
      htg_lim_btu_per_ft2 = 25
    end

    # Cooling limit is climate-independent
    clg_lim_btu_per_ft2 = 5

    # Semiheated limit is climate-independent
    semihtd_lim_btu_per_ft2 = 3.4

    # Determine if residential
    res = false
    if residential?(template)
      res = true
    end

    cond_cat = 'Unconditioned'
    if htg_load_btu_per_ft2 > htg_lim_btu_per_ft2
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{name} is conditioned because heating load of #{htg_load_btu_per_ft2.round} Btu/hr*ft^2 exceeds minimum of #{htg_lim_btu_per_ft2.round} Btu/hr*ft^2.")
      cond_cat = if res
                   'ResConditioned'
                 else
                   'NonResConditioned'
                 end
    elsif clg_load_btu_per_ft2 > clg_lim_btu_per_ft2
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{name} is conditioned because cooling load of #{clg_load_btu_per_ft2.round} Btu/hr*ft^2 exceeds minimum of #{clg_lim_btu_per_ft2.round} Btu/hr*ft^2.")
      cond_cat = if res
                   'ResConditioned'
                 else
                   'NonResConditioned'
                 end
    elsif htg_load_btu_per_ft2 > semihtd_lim_btu_per_ft2
      cond_cat = 'Semiheated'
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "Zone #{name} is semiheated because heating load of #{htg_load_btu_per_ft2.round} Btu/hr*ft^2 exceeds minimum of #{semihtd_lim_btu_per_ft2.round} Btu/hr*ft^2.")
    end

    return cond_cat
  end

  # Calculate the heating supply temperature based on the
  # specified delta-T. Delta-T is calculated based on the
  # highest value found in the heating setpoint schedule.
  #
  # @return [Double] the design heating supply temperature, in C
  # @todo Exception: 17F delta-T for labs
  def prm_baseline_heating_design_supply_temperature
    setpoint_c = nil

    # Setpoint schedule
    tstat = thermostatSetpointDualSetpoint
    if tstat.is_initialized
      tstat = tstat.get
      setpoint_sch = tstat.heatingSetpointTemperatureSchedule
      if setpoint_sch.is_initialized
        setpoint_sch = setpoint_sch.get
        if setpoint_sch.to_ScheduleRuleset.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleRuleset.get
          setpoint_c = setpoint_sch.annual_min_max_value['max']
        elsif setpoint_sch.to_ScheduleConstant.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleConstant.get
          setpoint_c = setpoint_sch.annual_min_max_value['max']
        elsif setpoint_sch.to_ScheduleCompact.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleCompact.get
          setpoint_c = setpoint_sch.annual_min_max_value['max']
        end
      end
    end

    # If the heating setpoint could not be determined
    # return the current design heating temperature
    if setpoint_c.nil?
      setpoint_c = sizingZone.zoneHeatingDesignSupplyAirTemperature
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{name}: could not determine max heating setpoint.  Design heating SAT will be #{OpenStudio.convert(setpoint_c, 'C', 'F').get.round} F from proposed model.")
      return setpoint_c
    end

    # If the heating setpoint was set very low so that
    # heating equipment never comes on
    # return the current design heating temperature
    if setpoint_c < OpenStudio.convert(41, 'F', 'C').get
      setpoint_f = OpenStudio.convert(setpoint_c, 'C', 'F').get
      new_setpoint_c = sizingZone.zoneHeatingDesignSupplyAirTemperature
      new_setpoint_f = OpenStudio.convert(new_setpoint_c, 'C', 'F').get
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{name}: max heating setpoint in proposed model was #{setpoint_f.round} F.  20 F SAT delta-T from this point is unreasonable. Design heating SAT will be #{new_setpoint_f.round} F from proposed model.")
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
  def prm_baseline_cooling_design_supply_temperature
    setpoint_c = nil

    # Setpoint schedule
    tstat = thermostatSetpointDualSetpoint
    if tstat.is_initialized
      tstat = tstat.get
      setpoint_sch = tstat.coolingSetpointTemperatureSchedule
      if setpoint_sch.is_initialized
        setpoint_sch = setpoint_sch.get
        if setpoint_sch.to_ScheduleRuleset.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleRuleset.get
          setpoint_c = setpoint_sch.annual_min_max_value['min']
        elsif setpoint_sch.to_ScheduleConstant.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleConstant.get
          setpoint_c = setpoint_sch.annual_min_max_value['min']
        elsif setpoint_sch.to_ScheduleCompact.is_initialized
          setpoint_sch = setpoint_sch.to_ScheduleCompact.get
          setpoint_c = setpoint_sch.annual_min_max_value['min']
        end
      end
    end

    # If the cooling setpoint could not be determined
    # return the current design cooling temperature
    if setpoint_c.nil?
      setpoint_c = sizingZone.zoneCoolingDesignSupplyAirTemperature
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{name}: could not determine min cooling setpoint.  Design cooling SAT will be #{OpenStudio.convert(setpoint_c, 'C', 'F').get.round} F from proposed model.")
      return setpoint_c
    end

    # If the cooling setpoint was set very high so that
    # cooling equipment never comes on
    # return the current design cooling temperature
    if setpoint_c > OpenStudio.convert(91, 'F', 'C').get
      setpoint_f = OpenStudio.convert(setpoint_c, 'C', 'F').get
      new_setpoint_c = sizingZone.zoneCoolingDesignSupplyAirTemperature
      new_setpoint_f = OpenStudio.convert(new_setpoint_c, 'C', 'F').get
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Standards.ThermalZone', "For #{name}: max cooling setpoint in proposed model was #{setpoint_f.round} F.  20 F SAT delta-T from this point is unreasonable. Design cooling SAT will be #{new_setpoint_f.round} F from proposed model.")
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
  def apply_prm_baseline_supply_temperatures
    # Skip spaces that aren't heated or cooled
    return true unless heated? || cooled?

    # Heating
    htg_sat_c = prm_baseline_heating_design_supply_temperature
    htg_success = sizingZone.setZoneHeatingDesignSupplyAirTemperature(htg_sat_c)

    # Cooling
    clg_sat_c = prm_baseline_cooling_design_supply_temperature
    clg_success = sizingZone.setZoneCoolingDesignSupplyAirTemperature(clg_sat_c)

    htg_sat_f = OpenStudio.convert(htg_sat_c, 'C', 'F').get
    clg_sat_f = OpenStudio.convert(clg_sat_c, 'C', 'F').get
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.ThermalZone', "For #{name}, Htg SAT = #{htg_sat_f.round(1)}F, Clg SAT = #{clg_sat_f.round(1)}F.")

    result = false
    if htg_success && clg_success
      result = true
    end

    return result
  end

  def add_unconditioned_thermostat
    # Heated to 0F (below heated? threshold)
    htg_t_f = 0
    htg_t_c = OpenStudio.convert(htg_t_f, 'F', 'C').get
    htg_stpt_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    htg_stpt_sch.setName('Unconditioned Minimal Heating')
    htg_stpt_sch.defaultDaySchedule.setName('Unconditioned Minimal Heating Default')
    htg_stpt_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), htg_t_c)

    # Cooled to 120F (above cooled? threshold)
    clg_t_f = 120
    clg_t_c = OpenStudio.convert(clg_t_f, 'F', 'C').get
    clg_stpt_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    clg_stpt_sch.setName('Unconditioned Minimal Heating')
    clg_stpt_sch.defaultDaySchedule.setName('Unconditioned Minimal Heating Default')
    clg_stpt_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), clg_t_c)

    # Thermostat
    thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
    thermostat.setName("#{name} Unconditioned Thermostat")
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
  def design_internal_load
    load_w = 0.0

    spaces.each do |space|
      load_w += space.design_internal_load
    end

    return load_w
  end

  # Returns the space type that represents a majority
  # of the floor area.
  #
  # @return [Boost::Optional<OpenStudio::Model::SpaceType>] an optional SpaceType
  def majority_space_type
    space_type_to_area = Hash.new(0.0)

    spaces.each do |space|
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

  # Determine if the thermal zone's occupancy type category.
  # Options are:
  # residential, nonresidential
  # 90.1-2013 adds additional Options:
  # publicassembly, retail
  #
  # @return [String] the occupancy type category
  # @todo Add public assembly building types
  def occupancy_type(template)
    occ_type = if residential?(template)
                 'residential'
               else
                 'nonresidential'
               end

    # Based on the space type that
    # represents a majority of the zone.
    if template == '90.1-2013'
      space_type = majority_space_type
      if space_type.is_initialized
        space_type = space_type.get
        bldg_type = space_type.standardsBuildingType
        if bldg_type.is_initialized
          bldg_type = bldg_type.get
          case bldg_type
          when 'Retail', 'StripMall', 'SuperMarket'
            occ_type = 'retail'
            # when 'SomeBuildingType' # TODO add publicassembly building types
            # occ_type = 'publicassembly'
          end
        end
      end
    end

    # OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.ThermalZone", "For #{self.name}, occupancy type = #{occ_type}.")

    return occ_type
  end
end

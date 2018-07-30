class NECB2011
  def model_add_swh(model, building_type, climate_zone, prototype_input, epw_file)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Service Water Heating')

    # Calculate the tank size and service water pump information
    shw_sizing = auto_size_shw_capacity(model, climate_zone, epw_file)
    pump_defaults = auto_size_shw_pump(model)

    # Add the main service water heating loop

    swh_fueltype = self.get_canadian_system_defaults_by_weatherfile_name(model)['swh_fueltype']

    main_swh_loop = model_add_swh_loop(model,
                                       'Main Service Water Loop',
                                       nil,
                                       shw_sizing['max_temp_SI'],
                                       pump_defaults[:head],
                                       pump_defaults[:motor_efficiency],
                                       shw_sizing['tank_capacity_SI'],
                                       shw_sizing['tank_volume_SI'],
                                       swh_fueltype,
                                       shw_sizing['parasitic_loss'],
                                       nil)

    shw_sizing['spaces_w_dhw'].each {|space| model_add_swh_end_uses_by_spaceonly(model, space, main_swh_loop)}

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding Service Water Heating')

    return true
  end

  # add swh

  # Applies the standard efficiency ratings and typical losses and paraisitic loads to this object.
  # Efficiency and skin loss coefficient (UA)
  # Per PNNL http://www.energycodes.gov/sites/default/files/documents/PrototypeModelEnhancements_2014_0.pdf
  # Appendix A: Service Water Heating
  #
  # @return [Bool] true if successful, false if not
  def water_heater_mixed_apply_efficiency(water_heater_mixed)
    # Get the capacity of the water heater
    # TODO add capability to pull autosized water heater capacity
    # if the Sizing:WaterHeater object is ever implemented in OpenStudio.
    capacity_w = water_heater_mixed.heaterMaximumCapacity
    if capacity_w.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find capacity, standard will not be applied.")
      return false
    else
      capacity_w = capacity_w.get
    end
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Get the volume of the water heater
    # TODO add capability to pull autosized water heater volume
    # if the Sizing:WaterHeater object is ever implemented in OpenStudio.
    volume_m3 = water_heater_mixed.tankVolume
    if volume_m3.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, cannot find volume, standard will not be applied.")
      return false
    else
      volume_m3 = volume_m3.get
    end
    volume_gal = OpenStudio.convert(volume_m3, 'm^3', 'gal').get

    # Get the heater fuel type
    fuel_type = water_heater_mixed.heaterFuelType
    unless fuel_type == 'NaturalGas' || fuel_type == 'Electricity'
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.WaterHeaterMixed', "For #{water_heater_mixed.name}, fuel type of #{fuel_type} is not yet supported, standard will not be applied.")
    end

    # Calculate the water heater efficiency and
    # skin loss coefficient (UA)
    # Calculate the energy factor (EF)
    # From PNNL http://www.energycodes.gov/sites/default/files/documents/PrototypeModelEnhancements_2014_0.pdf
    # Appendix A: Service Water Heating
    water_heater_eff = nil
    ua_btu_per_hr_per_f = nil
    sl_btu_per_hr = nil
    case fuel_type
      when 'Electricity'
        volume_l_per_s = volume_m3 * 1000
        if capacity_btu_per_hr <= OpenStudio.convert(12, 'kW', 'Btu/hr').get
          # Fixed water heater efficiency per PNNL
          water_heater_eff = 1
          # Calculate the max allowable standby loss (SL)
          sl_w = if volume_l_per_s < 270
                   40 + 0.2 * volume_l_per_s # assume bottom inlet
                 else
                   0.472 * volume_l_per_s - 33.5
                 end # assume bottom inlet
          sl_btu_per_hr = OpenStudio.convert(sl_w, 'W', 'Btu/hr').get
        else
          # Fixed water heater efficiency per PNNL
          water_heater_eff = 1
          # Calculate the max allowable standby loss (SL)   # use this - NECB does not give SL calculation for cap > 12 kW
          sl_btu_per_hr = 20 + (35 * Math.sqrt(volume_gal))
        end
        # Calculate the skin loss coefficient (UA)
        ua_btu_per_hr_per_f = sl_btu_per_hr / 70
      when 'NaturalGas'
        if capacity_btu_per_hr <= 75_000
          # Fixed water heater thermal efficiency per PNNL
          water_heater_eff = 0.82
          # Calculate the minimum Energy Factor (EF)
          base_ef = 0.67
          vol_drt = 0.0019
          ef = base_ef - (vol_drt * volume_gal)
          # Calculate the Recovery Efficiency (RE)
          # based on a fixed capacity of 75,000 Btu/hr
          # and a fixed volume of 40 gallons by solving
          # this system of equations:
          # ua = (1/.95-1/re)/(67.5*(24/41094-1/(re*cap)))
          # 0.82 = (ua*67.5+cap*re)/cap
          cap = 75_000.0
          re = (Math.sqrt(6724 * ef**2 * cap**2 + 40_409_100 * ef**2 * cap - 28_080_900 * ef * cap + 29_318_000_625 * ef**2 - 58_636_001_250 * ef + 29_318_000_625) + 82 * ef * cap + 171_225 * ef - 171_225) / (200 * ef * cap)
          # Calculate the skin loss coefficient (UA)
          # based on the actual capacity.
          ua_btu_per_hr_per_f = (water_heater_eff - re) * capacity_btu_per_hr / 67.5
        else
          # Thermal efficiency requirement from 90.1
          et = 0.8
          # Calculate the max allowable standby loss (SL)
          cap_adj = 800
          vol_drt = 110
          sl_btu_per_hr = (capacity_btu_per_hr / cap_adj + vol_drt * Math.sqrt(volume_gal))
          # Calculate the skin loss coefficient (UA)
          ua_btu_per_hr_per_f = (sl_btu_per_hr * et) / 70
          # Calculate water heater efficiency
          water_heater_eff = (ua_btu_per_hr_per_f * 70 + capacity_btu_per_hr * et) / capacity_btu_per_hr
        end
    end

    # Convert to SI
    ua_btu_per_hr_per_c = OpenStudio.convert(ua_btu_per_hr_per_f, 'Btu/hr*R', 'W/K').get

    # Set the water heater properties
    # Efficiency
    water_heater_mixed.setHeaterThermalEfficiency(water_heater_eff)
    # Skin loss
    water_heater_mixed.setOffCycleLossCoefficienttoAmbientTemperature(ua_btu_per_hr_per_c)
    water_heater_mixed.setOnCycleLossCoefficienttoAmbientTemperature(ua_btu_per_hr_per_c)
    # TODO: Parasitic loss (pilot light)
    # PNNL document says pilot lights were removed, but IDFs
    # still have the on/off cycle parasitic fuel consumptions filled in
    water_heater_mixed.setOnCycleParasiticFuelType(fuel_type)
    # self.setOffCycleParasiticFuelConsumptionRate(??)
    water_heater_mixed.setOnCycleParasiticHeatFractiontoTank(0)
    water_heater_mixed.setOffCycleParasiticFuelType(fuel_type)
    # self.setOffCycleParasiticFuelConsumptionRate(??)
    water_heater_mixed.setOffCycleParasiticHeatFractiontoTank(0.8)

    # set part-load performance curve
    if fuel_type == 'NaturalGas'
      plf_vs_plr_curve = model_add_curve(water_heater_mixed.model, 'SWH-EFFFPLR-NECB2011')
      water_heater_mixed.setPartLoadFactorCurve(plf_vs_plr_curve)
    end

    # Append the name with standards information
    water_heater_mixed.setName("#{water_heater_mixed.name} #{water_heater_eff.round(3)} Therm Eff")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.WaterHeaterMixed', "For #{template}: #{water_heater_mixed.name}; thermal efficiency = #{water_heater_eff.round(3)}, skin-loss UA = #{ua_btu_per_hr_per_f.round}Btu/hr")

    return true
  end

  # This calculates the volume and capacity of one mixed tank that is assumed to service all shw in the building
  def auto_size_shw_capacity(model, climate_zone, epw_file)
    peak_flow_rate = 0
    shw_space_types = []
    space_peak_flows = []
    water_use = 0
    weekly_peak_flow = {
        'Default|Wkdy' => Array.new(24,0),
        'Sat' => Array.new(24,0),
        'Sun|Hol' => Array.new(24,0)
    }
    peak_day_sched = nil
    peak_hour_sched = 0
    peak_flow_sched = 0
    next_hour_day = nil
    next_hour_hour = 0
    next_hour_flow = 0
    total_peak_flow_rate = 0
    shw_spaces = []
    shw_sched_names = []
    # First go through all the spaces in the building and determine and determine their shw requirements
    model.getSpaces.sort.each do |space|
      space_peak_flow = 0
      data = nil
      space_type_name = space.spaceType.get.nameString
      tank_temperature = 60
      # find the specific space_type properties from standard.json
      standards_data['space_types']['table'].each do |space_type|
        if space_type_name == (space_type['building_type'] + " " + space_type['space_type'])
          # If there is no service hot water load.. Don't bother adding anything.
          if space_type['service_water_heating_peak_flow_per_area'].to_f == 0.0 && space_type['service_water_heating_peak_flow_rate'].to_f == 0.0 || space_type['service_water_heating_schedule'].nil?
            next
          else
            # If there is a service hot water load collect the space information
            data = space_type
#            shw_spaces << space
          end
        end
      end
      # If there is no service hot water load.. Don't bother adding anything.
      # Skip space types with no data
      next if data.nil?
      space_area = OpenStudio.convert(space.floorArea, 'm^2', 'ft^2').get # ft2
      # Calculate the peak shw flow rate for the space.  Peak flow from JSON file is in US Gal/hr/ft^2
      space_peak_flow = (data['service_water_heating_peak_flow_per_area'].to_f*space_area)*space.multiplier
#      space_peak_flows << space_peak_flow
      # Add the peak shw flow rate for the space to the total for the entire building
      total_peak_flow_rate += space_peak_flow
      # Get the tank temperature for the space.  This should always be 60 C but I added this part in case something changes in the future.
      if data['service_water_heating_target_temperature'].nil? || (data['service_water_heating_target_temperature'] <= 16)
        tank_temperature = 60
      else
        tank_temperature = data['service_water_heating_target_temperature']
      end
      # Get the shw schedule
#      shw_sched_names << data['service_water_heating_schedule']
      space_info = {
          'shw_spaces' => space,
          'shw_peakflow_SI' => OpenStudio.convert(space_peak_flow, 'gal/hr', 'm^3/s').get,
          'shw_temp_SI' => tank_temperature,
          'shw_sched' => data['service_water_heating_schedule']
      }
      shw_spaces << space_info

      # The following gets the water use schedule for space and applies it to the peak flow rate for the space.  This
      # creates an array containing the hourly shw consumption for the space for each day type (Weekday/default, Saturday,
      # Sunday/Holiday).  The hourly shw consumption for each space is added to the array ultimately producing an array
      # containing the hourly shw demand for the entire building.  This is used to determine the peak shw demand
      # hour and rate for the building.  This is different than the overall peak shw demand for the building in that it
      # takes into account the shw schedule.  The peak shw demand hour and rate should always be less than the overall peak
      # shw demand.

      # Cycle through the hash accumulating the shw rates for each day type.
      weekly_peak_flow.sort.each do |day_peak_sched|
        day_sched = []
        # Create the search criteria and retrieve the schedule for the current space and current day type.
        search_criteria = {
            'template' => template,
            'name' => data['service_water_heating_schedule'],
            'day_types' => day_peak_sched[0]
        }
        day_sched = model_find_object(standards_data['schedules'], search_criteria)
        # Make sure the schedule is not empty and contains 24 hours.
        if day_sched.empty? || day_sched['values'].size != 24
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.model_add_swh', "The water use schedule called #{data['service_water_heating_schedule']} for #{space_type_name} is corrupted or could not be found.  Please check that the schedules.json file is available and that the schedule names are spelled correctly")
          return false
        end
        # For each hour of the current day type multiply the shw schedule fractional multiplier (representing the fraction of the total shw
        # rate used in that hour) times the overall peak shw rate for the current space.  Add the resulting values to the
        # array tracking hourly shw demand for the building.  Also, determine what the highest hourly demand is for the
        # building.
        day_peak_sched[1].sort.each_with_index do |hour_flow, hour_index|
          weekly_peak_flow[day_peak_sched[0]][hour_index] += day_sched['values'][hour_index]*space_peak_flow
          if weekly_peak_flow[day_peak_sched[0]][hour_index] > peak_flow_sched
            peak_flow_sched = weekly_peak_flow[day_peak_sched[0]][hour_index]
          end
        end
      end
    end
    next_day_test = nil
    next_hour_test = 0
    # The following loop goes through each hour in the array tracking hourly shw demand to find which hours contain the
    # peak hourly shw demand (this is in case the peak hourly shw demand occurs more than once).  It then determines what
    # the hourly shw demand is for the following hour.  It is meant to determine, of the peak hourly shw times, which has
    # the highest shw demand the following hour.  This is used to determine shw capacity and volume.
    weekly_peak_flow.sort.each do |day_peak_sched|
      day_peak_sched[1].sort.each_with_index do |hour_flow, hour_index|
        if hour_flow == peak_flow_sched
          if hour_index == 23
            next_hour_test = 0
            case day_peak_sched[0]
              when 'Default|Wkdy'
                next_day_test = 'Sat'
              when 'Sat'
                next_day_test = 'Sun|Hol'
              when 'Sun|Hol'
                next_day_test = 'Default|Wkdy'
            end
          else
            next_hour_test = hour_index + 1
            next_day_test = day_peak_sched[0]
          end
          if next_hour_flow < weekly_peak_flow[next_day_test][next_hour_test]
            next_hour_flow = weekly_peak_flow[next_day_test][next_hour_test]
            next_hour_hour = next_hour_test
            next_hour_day = next_day_test
            peak_day_sched = day_peak_sched[0]
            peak_hour_sched = hour_index
          end
        end
      end
    end
    # The shw tank is sized so that it can fulfill the hour with the highest shw needs.  Since the flow is in US Gal/hr
    # No conversion is necessary.
    tank_volume = peak_flow_sched
    # Interperite the fractional shw schedules as being the fraction of the hour that the maximum shw rate is used and determine
    # what this fraction is for the entire building.
    peak_time_fraction = 1 - (peak_flow_sched / total_peak_flow_rate)
    # Assume the shw tank needs some minimum amount of time to recover (avoids requiring a ridiculously high capacity).
    # If the recovery time is to short then the tank needs to hold enough water to service the peak shw hour and the one
    # after.  Then give the tank the entire hour to heat up again.  Note again that since peak flows are per hour, and
    # we are only looking at an hour, no conversion is necessary.
    if peak_time_fraction <= 0.2
      tank_volume += (next_hour_flow)
      peak_time_fraction = 1
    end
    tank_volume_SI = OpenStudio.convert(tank_volume, 'gal', 'm^3').get
    # Determine the tank capacity as the heat output required to heat up the entire volume of the tank in time remaining
    # in the hour after the peak shw draw is stopped (assume water is provided to the building at 15C ).
    max_temp = -273
    shw_spaces.each do |shw_space|
      if shw_space['shw_temp_SI'] > max_temp
        max_temp = shw_space['shw_temp_SI']
      end
    end
    tank_capacity_SI = tank_volume_SI * 1000 * 4180 * (max_temp - 15)/(3600*peak_time_fraction)
    height_to_radius = 2
    tank_radius = (tank_volume_SI/(height_to_radius*Math::PI))**(1.0/3)
    tank_area = 2*(1+height_to_radius)*Math::PI*(tank_radius**2)
    room_temp = OpenStudio.convert(70, 'F', 'C').get
    u = 0.45
    parasitic_loss = u*tank_area*(max_temp - room_temp)
    tank_param = {
        "tank_volume_SI" => tank_volume_SI,
        "tank_capacity_SI" => tank_capacity_SI,
        "max_temp_SI" => max_temp,
        "loop_peak_flow_rate_SI" => OpenStudio.convert(total_peak_flow_rate, 'gal/hr', 'm^3/s').get,
        "parasitic_loss" => parasitic_loss,
        "spaces_w_dhw" => shw_spaces
    }
    return tank_param
  end

  # Partially completed code to autosize the pump head by calculating the piping length and deriving required head from that.
  # Will also determine the pump motor efficiency.  If auto_sized is set to false then it returns a default pump head of
  # 179532 Pa and motor efficiency of 0.9 (based on the OpenStudio 2.4.1 defaults for a constant speed pump).  Until the
  # auto sizing method is complete only pass false for auto_sized.
  # Chris Kirney 2018-06-20
  def auto_size_shw_pump(model, auto_sized = false)
    return {head: 179532, motor_efficiency: 0.9} if not auto_sized
    spaces_peak_flow = []
    global_max_z = -100000
    shw_spaces = []
    max_space_centroids = []
    building_centre = Array.new(3,0)
    model.getSpaces.sort.each do |space|
      shw_space_info = {
          "space_centroid" => nil,
          "peak_flow" => 0,
          "building_cent_dist" => 0
      }
      space_surfaces = []
      min_surface = []
      space_peak_flow = 0
      data = nil
      space_type_name = space.spaceType.get.nameString
      # find the specific space_type properties from standard.json
      standards_data['space_types']['table'].each do |space_type|
        if space_type_name == (space_type['building_type'] + " " + space_type['space_type'])
          # If there is no service hot water load.. Don't bother adding anything.
          if space_type['service_water_heating_peak_flow_per_area'].to_f == 0.0 && space_type['service_water_heating_peak_flow_rate'].to_f == 0.0 || space_type['service_water_heating_schedule'].nil?
            next
          else
            # If there is a service hot water load collect the space information
            data = space_type
          end
        end
      end
      # If there is no service hot water load.. Don't bother adding anything.
      # Skip space types with no data
      next if data.nil?
      space_area = OpenStudio.convert(space.floorArea, 'm^2', 'ft^2').get # ft2
      # Calculate the peak shw flow rate for the space
      space_peak_flow = (data['service_water_heating_peak_flow_per_area'].to_f*space_area)
      shw_space_info['peak_flow'] = OpenStudio.convert(space_peak_flow, 'gal/hr', 'm^3/s').get
      space_min_z = 100000000
      min_surface = nil
      space_surfaces = space.surfaces
      min_surface = space_surfaces.min_by{|index| index.centroid.z.to_f}
      shw_space_info["space_centroid"] = min_surface.centroid
      shw_spaces << shw_space_info
      building_centre[0] += min_surface.centroid.x.to_f
      building_centre[1] += min_surface.centroid.y.to_f
      building_centre[2] += 1
    end
    building_centre[0] /= building_centre[2]
    building_centre[1] /= building_centre[2]
    min_length = 1000000000
    space_length = 0
    shw_spaces.each do |shw_space|
      shw_space['building_cent_dist'] = Math.sqrt(((shw_space['space_centroid'].x.to_f - building_centre[0])**2) + ((shw_space['space_centroid'].y.to_f - building_centre[1])**2))
      shw_space['building_cent_dist'].round(1) <= min_length ? min_length = shw_space['building_cent_dist'].round(1) : next
    end
    centre_spaces = []
    shw_spaces.each do |shw_space|
      shw_space['building_cent_dist'].round(1) == min_length ? centre_spaces << shw_space : next
    end
    centre_space = centre_spaces.max_by{|index| index['space_centroid'].z.to_f}
    put 'hello'
  end
end

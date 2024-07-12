class ACM179dASHRAE9012007

  # Add Exhaust Fans based on space type lookup.
  # This measure doesn't look if DCV is needed.
  # Others methods can check if DCV needed and add it.
  #
  # @param thermal_zone [OpenStudio::Model::ThermalZone] thermal zone
  # @param exhaust_makeup_inputs [Hash] has of makeup exhaust inputs
  # @return [Hash] Hash of newly made exhaust fan objects along with secondary exhaust and zone mixing objects
  # @todo combine availability and fraction flow schedule to make zone mixing schedule
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

        # @todo make zone mixing schedule by combining exhaust availability and fraction flow
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

end

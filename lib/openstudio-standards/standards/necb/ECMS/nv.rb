class ECMS

  def apply_nv(model:, nv_type:, nv_opening_fraction:, nv_Tout_min:, nv_Delta_Tin_Tout:)

    ##### If any of users' inputs are nil/false/none, do nothing.
    ##### If users' input for 'nv_type' is 'NECB_Default', do nothing.
    ##### If any of users' inputs for nv_opening_fraction/nv_Tout_min/nv_Delta_Tin_Tout is 'NECB_Default', use default values as defined here.
    return if nv_type.nil? || nv_type == false || nv_type == 'none' || nv_type == 'NECB_Default'
    return if nv_opening_fraction.nil? || nv_opening_fraction == false || nv_opening_fraction == 'none'
    return if nv_Tout_min.nil? || nv_Tout_min == false || nv_Tout_min == 'none'
    return if nv_Delta_Tin_Tout.nil? || nv_Delta_Tin_Tout == false || nv_Delta_Tin_Tout == 'none'

    ##### Convert a string to a float (except for nv_type)
    if nv_opening_fraction.instance_of?(String) && nv_opening_fraction != 'NECB_Default'
      nv_opening_fraction = nv_opening_fraction.to_f
    end
    if nv_Tout_min.instance_of?(String) && nv_Tout_min != 'NECB_Default'
      nv_Tout_min = nv_Tout_min.to_f
    end
    if nv_Delta_Tin_Tout.instance_of?(String) && nv_Delta_Tin_Tout != 'NECB_Default'
      nv_Delta_Tin_Tout = nv_Delta_Tin_Tout.to_f
    end

    ##### Set default nv_opening_fraction as 0.1
    if nv_opening_fraction == 'NECB_Default'
      nv_opening_fraction = 0.1
    end
    ##### Set default nv_Tout_min as 13.0
    if nv_Tout_min == 'NECB_Default'
      nv_Tout_min = 13.0 #Note: 13.0 is based on inputs from Michel Tardif re a real school in QC
    end
    ##### Set default nv_Delta_Tin_Tout as 1.0
    if nv_Delta_Tin_Tout == 'NECB_Default'
      nv_Delta_Tin_Tout = 1.0 #Note: 1.0 is based on inputs from Michel Tardif re a real school in QC
    end

    setpoint_adjustment_for_nv = 2.0  #This is to adjust heating and cooling setpoint temperature as min and max indoor temperature to have NV

    model.getZoneHVACEquipmentLists.sort.each do |zone_hvac_equipment_list|

      thermal_zone = zone_hvac_equipment_list.thermalZone

      thermal_zone.spaces.sort.each do |space|
        number_of_windows = 0.0

        ##### Gather OA per person and floor area of the space from the osm file
        outdoor_air = space.designSpecificationOutdoorAir.get
        outdoor_air_flow_per_person = outdoor_air.outdoorAirFlowperPerson
        outdoor_air_flow_per_floor_area = outdoor_air.outdoorAirFlowperFloorArea

        ##### Get heating/cooling setpoint temperature schedules from the osm file
        # These schedules are used for min/max Tin schedules under the objects of "ZoneVentilation:DesignFlowRate" and "ZoneVentilation:WindandStackOpenArea".
        # Note: as per E+ I/O Ref.: "If the user enters a valid schedule name, the minimum/maximum temperature values specified in this schedule will override the constant value specified in the Minimum/Maximum Indoor Temperature field." under the objects of "ZoneVentilation:DesignFlowRate" and "ZoneVentilation:WindandStackOpenArea".
        if thermal_zone.thermostat.is_initialized
          if thermal_zone.thermostat.get.to_ThermostatSetpointDualSetpoint.is_initialized
            if thermal_zone.thermostat.get.to_ThermostatSetpointDualSetpoint.get.heatingSetpointTemperatureSchedule.is_initialized ||
                thermal_zone.thermostat.get.to_ThermostatSetpointDualSetpoint.get.coolingSetpointTemperatureSchedule.is_initialized
              zone_thermostat = thermal_zone.thermostatSetpointDualSetpoint.get
              zone_clg_thermostat_sch = zone_thermostat.coolingSetpointTemperatureSchedule.get
              zone_htg_thermostat_sch = zone_thermostat.heatingSetpointTemperatureSchedule.get

              ##### Create schedule for max Tin to have NV on the basis of cooling setpoint temperature for default day
              zone_clg_thermostat_sch_name = zone_clg_thermostat_sch.name
              zone_clg_sp_schedule = zone_clg_thermostat_sch.to_ScheduleRuleset.get

              max_Tin_schedule = zone_clg_sp_schedule.clone(model).to_ScheduleRuleset.get
              max_Tin_schedule.setName('natural_ventilation_max_Tin_schedule')
              ## default days/weekdays
              max_Tin_schedule_defaultDay = max_Tin_schedule.defaultDaySchedule
              max_Tin_schedule_defaultDay.setName('natural_ventilation_max_Tin_schedule_defaultDay')
              max_Tin_schedule_defaultDay_times = max_Tin_schedule_defaultDay.times
              max_Tin_schedule_defaultDay_values = max_Tin_schedule_defaultDay.values
              max_Tin_schedule_defaultDay_values_adjusted = max_Tin_schedule_defaultDay_values.map { |i| i + setpoint_adjustment_for_nv }
              i = 0.0
              max_Tin_schedule_defaultDay_times.each do |time|
                max_Tin_schedule_defaultDay.addValue(time, max_Tin_schedule_defaultDay_values_adjusted[i])
                i += 1.0
              end

              ##### Create schedule for min Tin to have NV on the basis of cooling setpoint temperature for default day
              zone_htg_thermostat_sch_name = zone_htg_thermostat_sch.name
              zone_htg_sp_schedule = zone_htg_thermostat_sch.to_ScheduleRuleset.get
              min_Tin_schedule = zone_htg_sp_schedule.clone(model).to_ScheduleRuleset.get
              min_Tin_schedule.setName('natural_ventilation_min_Tin_schedule')
              ## default days/weekdays
              min_Tin_schedule_defaultDay = min_Tin_schedule.defaultDaySchedule
              min_Tin_schedule_defaultDay.setName('natural_ventilation_min_Tin_schedule_defaultDay')
              min_Tin_schedule_defaultDay_times = min_Tin_schedule_defaultDay.times
              min_Tin_schedule_defaultDay_values = min_Tin_schedule_defaultDay.values
              min_Tin_schedule_defaultDay_values_adjusted = min_Tin_schedule_defaultDay_values.map { |i| i - setpoint_adjustment_for_nv }
              i = 0.0
              min_Tin_schedule_defaultDay_times.each do |time|
                min_Tin_schedule_defaultDay.addValue(time, min_Tin_schedule_defaultDay_values_adjusted[i])
                i += 1.0
              end


            end
          end
        end

        ##### Calculate how many windows a space has.
        # The total number of windows is used to divide OA/person and OA/FloorArea of the space by it (i.e. number of windows).
        # In this way, NV-driven OA in each space would be avoided to be more than required.
        space.surfaces.sort.each do |surface|
          surface.subSurfaces.sort.each do |subsurface|
            if (subsurface.subSurfaceType == 'OperableWindow' || subsurface.subSurfaceType == 'FixedWindow') && subsurface.outsideBoundaryCondition == 'Outdoors'
              number_of_windows += 1.0
            end
          end
        end
        oa_per_person_normalized_by_number_of_windows = outdoor_air_flow_per_person/number_of_windows
        oa_per_floor_area_normalized_by_number_of_windows = outdoor_air_flow_per_floor_area/number_of_windows

        ##### Add NV in each space that has window(s) using two objects: "ZoneVentilation:DesignFlowRate" and "ZoneVentilation:WindandStackOpenArea"
        space.surfaces.sort.each do |surface|
          surface.subSurfaces.sort.each do |subsurface|
            if (subsurface.subSurfaceType == 'OperableWindow' || subsurface.subSurfaceType == 'FixedWindow') && subsurface.outsideBoundaryCondition == 'Outdoors'
              window_azimuth_deg = OpenStudio::convert(subsurface.azimuth,"rad","deg").get
              window_area = subsurface.netArea

              ##### Define a constant schedule for operable windows
              operable_window_schedule = OpenStudio::Model::ScheduleConstant.new(model)
              operable_window_schedule.setName('operable_window_schedule_constant')
              operable_window_schedule.setScheduleTypeLimits(BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_on_off(model))

              ##### Add a "ZoneVentilation:DesignFlowRate" object for NV to set OA per person.
              zn_vent_design_flow_rate_1 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
              zn_vent_design_flow_rate_1.setDesignFlowRateCalculationMethod('Flow/Person')
              zn_vent_design_flow_rate_1.setFlowRateperPerson(oa_per_person_normalized_by_number_of_windows)
              zn_vent_design_flow_rate_1.setVentilationType('Natural')
              zn_vent_design_flow_rate_1.setMinimumIndoorTemperatureSchedule(min_Tin_schedule)
              zn_vent_design_flow_rate_1.setMaximumIndoorTemperatureSchedule(max_Tin_schedule)
              zn_vent_design_flow_rate_1.setMinimumOutdoorTemperature(nv_Tout_min)
              zn_vent_design_flow_rate_1.setMaximumOutdoorTemperatureSchedule(max_Tin_schedule)
              zn_vent_design_flow_rate_1.setDeltaTemperature(nv_Delta_Tin_Tout) #E+ I/O Ref.: "This is the temperature difference between the indoor and outdoor air dry-bulb temperatures below which ventilation is shutoff."
              zone_hvac_equipment_list.addEquipment(zn_vent_design_flow_rate_1)

              ##### Add another "ZoneVentilation:DesignFlowRate" object for NV to set OA per floor area.
              zn_vent_design_flow_rate_2 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
              zn_vent_design_flow_rate_2.setDesignFlowRateCalculationMethod('Flow/Area')
              zn_vent_design_flow_rate_2.setFlowRateperZoneFloorArea(oa_per_floor_area_normalized_by_number_of_windows)
              zn_vent_design_flow_rate_2.setVentilationType('Natural')
              zn_vent_design_flow_rate_2.setMinimumIndoorTemperatureSchedule(min_Tin_schedule)
              zn_vent_design_flow_rate_2.setMaximumIndoorTemperatureSchedule(max_Tin_schedule)
              zn_vent_design_flow_rate_2.setMinimumOutdoorTemperature(nv_Tout_min)
              zn_vent_design_flow_rate_2.setMaximumOutdoorTemperatureSchedule(max_Tin_schedule)
              zn_vent_design_flow_rate_2.setDeltaTemperature(nv_Delta_Tin_Tout)
              zone_hvac_equipment_list.addEquipment(zn_vent_design_flow_rate_2)

              ##### Add the "ZoneVentilation:WindandStackOpenArea" for NV.
              # Note: it has been assumed that 'Opening Effectiveness' and 'Discharge Coefficient for Opening' are autocalculated (which are the default assumptions).
              zn_vent_wind_and_stack = OpenStudio::Model::ZoneVentilationWindandStackOpenArea.new(model)
              zn_vent_wind_and_stack.setOpeningArea(window_area * nv_opening_fraction)
              zn_vent_wind_and_stack.setOpeningAreaFractionSchedule(operable_window_schedule)
              # (Ref: E+ I/O) The Effective Angle value "is used to calculate the angle between the wind direction and the opening outward normal to determine the opening effectiveness values when the input field Opening Effectiveness = Autocalculate."
              # (Ref: E+ I/O) "Effective Angle is the angle in degrees counting from the North clockwise to the opening outward normal."
              zn_vent_wind_and_stack.setEffectiveAngle(window_azimuth_deg)
              zn_vent_wind_and_stack.setMinimumIndoorTemperatureSchedule(min_Tin_schedule)
              zn_vent_wind_and_stack.setMaximumIndoorTemperatureSchedule(max_Tin_schedule)
              zn_vent_wind_and_stack.setMinimumOutdoorTemperature(nv_Tout_min)
              zn_vent_wind_and_stack.setMaximumOutdoorTemperatureSchedule(max_Tin_schedule)
              zn_vent_wind_and_stack.setDeltaTemperature(nv_Delta_Tin_Tout)
              zone_hvac_equipment_list.addEquipment(zn_vent_wind_and_stack)

            end #if (subsurface.subSurfaceType == 'OperableWindow' || subsurface.subSurfaceType == 'FixedWindow') && subsurface.outsideBoundaryCondition == 'Outdoors'
          end #surface.subSurfaces.sort.each do |subsurface|
        end #space.surfaces.sort.each do |surface|


      end #thermal_zone.spaces.sort.each do |space|

    end #model.getZoneHVACEquipmentLists.sort.each do |zone_hvac_equipment_list|

    ##### Add AvailabilityManagerHybridVentilation to "prevents simultaneous natural ventilation and HVAC system operation" (Ref: E+ I/O)
    model.getAirLoopHVACs.sort.each do |air_loop|
      air_loop.availabilityManagers.sort.each do |avail_mgr|
        if avail_mgr.to_AvailabilityManagerHybridVentilation.empty?
          avail_mgr_hybr_vent = OpenStudio::Model::AvailabilityManagerHybridVentilation.new(model)
          avail_mgr_hybr_vent.setMinimumOutdoorTemperature(nv_Tout_min) #Note: since "Ventilation Control Mode" is by default set to "Temperature (i.e. 1)", only min and max Tout are needed. (see E+ I/O Ref.)  #Note: Tout_min is to avoid overcooling (see E+ I/O Ref).
          avail_mgr_hybr_vent.setMaximumOutdoorTemperature(30.0) #Note: the AvailabilityManagerHybridVentilation obj does not have a schedule field for Tout, so it has been set to a fixed value of 30C.
          air_loop.addAvailabilityManager(avail_mgr_hybr_vent)
        end
      end
    end

  end

end
class ECMS

  def apply_nv(model:, nv_type:, nv_opening_fraction:, nv_Tout_min:, nv_Tout_max:, nv_Delta_Tin_Tout:) #TODO: add argument re whether Fanger or adaptive comfort model

    ##### If any of users' inputs are nil/false, do nothing.
    return if nv_type.nil? || nv_type == FALSE
    return if nv_opening_fraction.nil? || nv_opening_fraction == FALSE
    return if nv_Tout_min.nil? || nv_Tout_min == FALSE
    return if nv_Tout_max.nil? || nv_Tout_max == FALSE
    return if nv_Delta_Tin_Tout.nil? || nv_Delta_Tin_Tout == FALSE

    model.getZoneHVACEquipmentLists.sort.each do |zone_hvac_equipment_list|  #TODO: consider zones that do not have hvac?
      # puts zone_hvac_equipment_list

      thermal_zone = zone_hvac_equipment_list.thermalZone
      puts "thermal_zone_name_is #{thermal_zone.name.to_s}"

      thermal_zone.spaces.sort.each do |space|
        puts space.name.to_s
        number_of_windows = 0.0 # This is to have natural ventilation only through one of a space's windows if the space has more than one window to avoid flow rate more than what is needed in the space (i.e. OA/person + OA/FloorArea).

        ### gather OA of the space from the osm file
        outdoor_air = space.designSpecificationOutdoorAir.get
        outdoor_air_flow_per_person = outdoor_air.outdoorAirFlowperPerson
        outdoor_air_flow_per_floor_area = outdoor_air.outdoorAirFlowperFloorArea
        puts "outdoor_air_flow_per_person is #{outdoor_air_flow_per_person}"
        puts "outdoor_air_flow_per_floor_area us #{outdoor_air_flow_per_floor_area}"

        ### add AvailabilityManagerHybridVentilation to "prevents simultaneous natural ventilation and HVAC system operation" (Ref: E+ I/O)
        thermal_zone.airLoopHVACs.sort.each do |air_loop|
          # puts air_loop
          avail_mgr_hybr_vent = OpenStudio::Model::AvailabilityManagerHybridVentilation.new(model)
          avail_mgr_hybr_vent.setMinimumOutdoorTemperature(nv_Tout_min) #Note: since "Ventilation Control Mode" is by default set to "Temperature (i.e. 1)", only min and max Tout are needed. (see E+ I/O)
          avail_mgr_hybr_vent.setMaximumOutdoorTemperature(nv_Tout_max) #Note: Tout_min is to avoid overcooling, Tout_max is to avoid overheating. (see see E+ I/O)
          air_loop.addAvailabilityManager(avail_mgr_hybr_vent)
        end

        ### get setpoint temperature from the osm file   #TODO: use setpoint schedules (NECB-B-Thermostat Setpoint-Heating/Cooling) for min/max Tin instead of hard numbers for min/max Tin (in that case, no matter what values are entered in the fields of min/max Tin)
        if thermal_zone.thermostat.is_initialized
          if thermal_zone.thermostat.get.to_ThermostatSetpointDualSetpoint.is_initialized
            if thermal_zone.thermostat.get.to_ThermostatSetpointDualSetpoint.get.heatingSetpointTemperatureSchedule.is_initialized ||
                thermal_zone.thermostat.get.to_ThermostatSetpointDualSetpoint.get.coolingSetpointTemperatureSchedule.is_initialized
              zone_thermostat = thermal_zone.thermostatSetpointDualSetpoint.get
              zone_clg_thermostat_sch = zone_thermostat.coolingSetpointTemperatureSchedule.get
              zone_htg_thermostat_sch = zone_thermostat.heatingSetpointTemperatureSchedule.get

              zone_clg_thermostat_sch_name = zone_clg_thermostat_sch.name
              zone_clg_sp_schedule = zone_clg_thermostat_sch.to_ScheduleRuleset.get
              zone_clg_sp_profile = zone_clg_sp_schedule.defaultDaySchedule

              zone_htg_thermostat_sch_name = zone_htg_thermostat_sch.name
              zone_htg_sp_schedule = zone_htg_thermostat_sch.to_ScheduleRuleset.get
              zone_htg_sp_profile = zone_htg_sp_schedule.defaultDaySchedule
            end
          end
        end

        space.surfaces.sort.each do |surface|
          surface.subSurfaces.sort.each do |subsurface|
            # puts subsurface.name.to_s
            if (subsurface.subSurfaceType == 'OperableWindow' || subsurface.subSurfaceType == 'FixedWindow') && subsurface.outsideBoundaryCondition == 'Outdoors'  #TODO: Question? change window type to only 'OperableWindow'? for testing purposes, window type of'FixedWindow' has been included.
              window_azimuth_deg = OpenStudio::convert(subsurface.azimuth,"rad","deg").get
              window_area = subsurface.netArea
              puts "window name is #{subsurface.name.to_s}"
              puts "window azimuth (deg) is #{window_azimuth_deg}"
              puts "window area is #{window_area}"
              # raise('check azimuth of exterior window')

              if number_of_windows == 0.0   #TODO: calculate number of windows; divide OA/person and OA/FloorArea by it to avoid OA more that required
                ##### define a constant schedule for operable windows
                operable_window_schedule = OpenStudio::Model::ScheduleConstant.new(model)
                operable_window_schedule.setName('operable_window_schedule_constant')
                operable_window_schedule.setScheduleTypeLimits(BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_on_off(model))

                ##### set air flow rate for natural ventilation
                zn_vent_design_flow_rate_1 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
                zn_vent_design_flow_rate_1.setDesignFlowRateCalculationMethod('Flow/Person')
                zn_vent_design_flow_rate_1.setFlowRateperPerson(outdoor_air_flow_per_person)
                zn_vent_design_flow_rate_1.setVentilationType('Natural')
                zn_vent_design_flow_rate_1.setMinimumIndoorTemperatureSchedule(zone_htg_sp_schedule) #Ref: E+ I/O: "If the user enters a valid schedule name, the minimum temperature values specified in this schedule will override the constant value specified in the Minimum Indoor Temperature field."
                zn_vent_design_flow_rate_1.setMaximumIndoorTemperatureSchedule(zone_clg_sp_schedule) #Ref: E+ I/O: "If the user enters a valid schedule name, the maximum temperature values specified in this schedule will override the constant value specified in the Maximum Indoor Temperature field."
                zn_vent_design_flow_rate_1.setMinimumOutdoorTemperature(nv_Tout_min)
                zn_vent_design_flow_rate_1.setMaximumOutdoorTemperature(nv_Tout_max)
                zn_vent_design_flow_rate_1.setDeltaTemperature(nv_Delta_Tin_Tout) #Ref: E+ I/O: "This is the temperature difference between the indoor and outdoor air dry-bulb temperatures below which ventilation is shutoff."
                zone_hvac_equipment_list.addEquipment(zn_vent_design_flow_rate_1)
                thermal_zone.setCoolingPriority(zn_vent_design_flow_rate_1.to_ModelObject.get, 1)
                thermal_zone.setHeatingPriority(zn_vent_design_flow_rate_1.to_ModelObject.get, 1)

                #####
                zn_vent_design_flow_rate_2 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
                zn_vent_design_flow_rate_2.setDesignFlowRateCalculationMethod('Flow/Area')
                zn_vent_design_flow_rate_2.setFlowRateperZoneFloorArea(outdoor_air_flow_per_floor_area)
                zn_vent_design_flow_rate_2.setVentilationType('Natural')
                zn_vent_design_flow_rate_2.setMinimumIndoorTemperatureSchedule(zone_htg_sp_schedule)
                zn_vent_design_flow_rate_2.setMaximumIndoorTemperatureSchedule(zone_clg_sp_schedule)
                zn_vent_design_flow_rate_2.setMinimumOutdoorTemperature(nv_Tout_min)
                zn_vent_design_flow_rate_2.setMaximumOutdoorTemperature(nv_Tout_max)
                zn_vent_design_flow_rate_2.setDeltaTemperature(nv_Delta_Tin_Tout)
                zone_hvac_equipment_list.addEquipment(zn_vent_design_flow_rate_2)
                thermal_zone.setCoolingPriority(zn_vent_design_flow_rate_2.to_ModelObject.get, 2)
                thermal_zone.setHeatingPriority(zn_vent_design_flow_rate_2.to_ModelObject.get, 2)

                #####
                ### note: it has been assumed that 'Opening Effectiveness' and 'Discharge Coefficient for Opening' are autocalculated (which is the default).
                zn_vent_wind_and_stack = OpenStudio::Model::ZoneVentilationWindandStackOpenArea.new(model)
                zn_vent_wind_and_stack.setOpeningArea(window_area * nv_opening_fraction)
                zn_vent_wind_and_stack.setOpeningAreaFractionSchedule(operable_window_schedule)
                # (Ref: E+ I/O) "The below input field value is used to calculate the angle between the wind direction and the opening outward normal to determine the opening effectiveness values when the input field Opening Effectiveness = Autocalculate."
                # (Ref: E+ I/O) "Effective Angle is the angle in degrees counting from the North clockwise to the opening outward normal."
                zn_vent_wind_and_stack.setEffectiveAngle(window_azimuth_deg)
                zn_vent_wind_and_stack.setMinimumIndoorTemperatureSchedule(zone_htg_sp_schedule)
                zn_vent_wind_and_stack.setMaximumIndoorTemperatureSchedule(zone_clg_sp_schedule)
                zn_vent_wind_and_stack.setMinimumOutdoorTemperature(nv_Tout_min)
                zn_vent_wind_and_stack.setMaximumOutdoorTemperature(nv_Tout_max)
                zn_vent_wind_and_stack.setDeltaTemperature(nv_Delta_Tin_Tout)
                zone_hvac_equipment_list.addEquipment(zn_vent_wind_and_stack)
                thermal_zone.setCoolingPriority(zn_vent_wind_and_stack.to_ModelObject.get, 3)
                thermal_zone.setHeatingPriority(zn_vent_wind_and_stack.to_ModelObject.get, 3)

              end

              number_of_windows += 1.0

            end
          end
        end






      end



    end


  end

end
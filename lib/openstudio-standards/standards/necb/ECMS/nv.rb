class ECMS

  def apply_nv(model:, nv_type:, nv_comfort_model:, nv_opening_fraction:, nv_Tout_min:, nv_Tout_max:, nv_Delta_Tin_Tout:)

    ##### If any of users' inputs are nil/false, do nothing.
    return if nv_type.nil? || nv_type == FALSE
    return if nv_comfort_model.nil? || nv_comfort_model == FALSE
    return if nv_opening_fraction.nil? || nv_opening_fraction == FALSE
    return if nv_Tout_min.nil? || nv_Tout_min == FALSE
    return if nv_Tout_max.nil? || nv_Tout_max == FALSE
    return if nv_Delta_Tin_Tout.nil? || nv_Delta_Tin_Tout == FALSE

    model.getZoneHVACEquipmentLists.sort.each do |zone_hvac_equipment_list|
      # puts zone_hvac_equipment_list

      thermal_zone = zone_hvac_equipment_list.thermalZone
      # puts "thermal_zone_name_is #{thermal_zone.name.to_s}"

      thermal_zone.spaces.sort.each do |space|
        # puts space.name.to_s
        number_of_windows = 0.0

        ##### Gather OA per person and floor area of the space from the osm file
        outdoor_air = space.designSpecificationOutdoorAir.get
        outdoor_air_flow_per_person = outdoor_air.outdoorAirFlowperPerson
        outdoor_air_flow_per_floor_area = outdoor_air.outdoorAirFlowperFloorArea
        # puts "outdoor_air_flow_per_person is #{outdoor_air_flow_per_person}"
        # puts "outdoor_air_flow_per_floor_area us #{outdoor_air_flow_per_floor_area}"

        ##### Add AvailabilityManagerHybridVentilation to "prevents simultaneous natural ventilation and HVAC system operation" (Ref: E+ I/O)
        thermal_zone.airLoopHVACs.sort.each do |air_loop|
          # puts air_loop
          avail_mgr_hybr_vent = OpenStudio::Model::AvailabilityManagerHybridVentilation.new(model)
          avail_mgr_hybr_vent.setMinimumOutdoorTemperature(nv_Tout_min) #Note: since "Ventilation Control Mode" is by default set to "Temperature (i.e. 1)", only min and max Tout are needed. (see E+ I/O Ref.)
          avail_mgr_hybr_vent.setMaximumOutdoorTemperature(nv_Tout_max) #Note: Tout_min is to avoid overcooling, Tout_max is to avoid overheating. (see E+ I/O Ref.)
          air_loop.addAvailabilityManager(avail_mgr_hybr_vent)
        end

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

              zone_clg_thermostat_sch_name = zone_clg_thermostat_sch.name
              zone_clg_sp_schedule = zone_clg_thermostat_sch.to_ScheduleRuleset.get
              zone_clg_sp_profile = zone_clg_sp_schedule.defaultDaySchedule

              zone_htg_thermostat_sch_name = zone_htg_thermostat_sch.name
              zone_htg_sp_schedule = zone_htg_thermostat_sch.to_ScheduleRuleset.get
              zone_htg_sp_profile = zone_htg_sp_schedule.defaultDaySchedule
            end
          end
        end

        ##### Calculate how many windows a space has.
        # The total number of windows is used to divide OA/person and OA/FloorArea of the space by it (i.e. number of windows).
        # In this way, NV-driven OA in each space would be avoided to be more than required.
        space.surfaces.sort.each do |surface|
          surface.subSurfaces.sort.each do |subsurface|
            # puts subsurface.name.to_s
            if (subsurface.subSurfaceType == 'OperableWindow' || subsurface.subSurfaceType == 'FixedWindow') && subsurface.outsideBoundaryCondition == 'Outdoors'  #TODO: Question: Should I change window type to only 'OperableWindow'? For testing purposes, I have included the window type of 'FixedWindow' as well.
              number_of_windows += 1.0
            end
          end
        end
        # puts "#{space.name.to_s} has #{number_of_windows} window(s)"
        oa_per_person_normalized_by_number_of_windows = outdoor_air_flow_per_person/number_of_windows
        oa_per_floor_area_normalized_by_number_of_windows = outdoor_air_flow_per_floor_area/number_of_windows

        ##### Add NV in each space that has window(s) using two objects: "ZoneVentilation:DesignFlowRate" and "ZoneVentilation:WindandStackOpenArea"
        space.surfaces.sort.each do |surface|
          surface.subSurfaces.sort.each do |subsurface|
            # puts subsurface.name.to_s
            if (subsurface.subSurfaceType == 'OperableWindow' || subsurface.subSurfaceType == 'FixedWindow') && subsurface.outsideBoundaryCondition == 'Outdoors'  #TODO: Question: Should I change window type to only 'OperableWindow'? For testing purposes, I have included the window type of 'FixedWindow' as well.
              window_azimuth_deg = OpenStudio::convert(subsurface.azimuth,"rad","deg").get
              window_area = subsurface.netArea
              puts "window name is #{subsurface.name.to_s}"
              puts "window azimuth (deg) is #{window_azimuth_deg}"
              puts "window area is #{window_area}"
              # raise('check azimuth of exterior window')

              ##### Define a constant schedule for operable windows
              operable_window_schedule = OpenStudio::Model::ScheduleConstant.new(model)
              operable_window_schedule.setName('operable_window_schedule_constant')
              operable_window_schedule.setScheduleTypeLimits(BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_on_off(model))

              if nv_comfort_model == 'Fanger_Model'

                ##### Add a "ZoneVentilation:DesignFlowRate" object for NV to set OA per person.
                zn_vent_design_flow_rate_1 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
                zn_vent_design_flow_rate_1.setDesignFlowRateCalculationMethod('Flow/Person')
                zn_vent_design_flow_rate_1.setFlowRateperPerson(oa_per_person_normalized_by_number_of_windows)
                zn_vent_design_flow_rate_1.setVentilationType('Natural')
                zn_vent_design_flow_rate_1.setMinimumIndoorTemperatureSchedule(zone_htg_sp_schedule)
                zn_vent_design_flow_rate_1.setMaximumIndoorTemperatureSchedule(zone_clg_sp_schedule)
                zn_vent_design_flow_rate_1.setMinimumOutdoorTemperature(nv_Tout_min)
                zn_vent_design_flow_rate_1.setMaximumOutdoorTemperature(nv_Tout_max)
                zn_vent_design_flow_rate_1.setDeltaTemperature(nv_Delta_Tin_Tout) #E+ I/O Ref.: "This is the temperature difference between the indoor and outdoor air dry-bulb temperatures below which ventilation is shutoff."
                zone_hvac_equipment_list.addEquipment(zn_vent_design_flow_rate_1)

                ##### Add another "ZoneVentilation:DesignFlowRate" object for NV to set OA per floor area.
                zn_vent_design_flow_rate_2 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
                zn_vent_design_flow_rate_2.setDesignFlowRateCalculationMethod('Flow/Area')
                zn_vent_design_flow_rate_2.setFlowRateperZoneFloorArea(oa_per_floor_area_normalized_by_number_of_windows)
                zn_vent_design_flow_rate_2.setVentilationType('Natural')
                zn_vent_design_flow_rate_2.setMinimumIndoorTemperatureSchedule(zone_htg_sp_schedule)
                zn_vent_design_flow_rate_2.setMaximumIndoorTemperatureSchedule(zone_clg_sp_schedule)
                zn_vent_design_flow_rate_2.setMinimumOutdoorTemperature(nv_Tout_min)
                zn_vent_design_flow_rate_2.setMaximumOutdoorTemperature(nv_Tout_max)
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
                zn_vent_wind_and_stack.setMinimumIndoorTemperatureSchedule(zone_htg_sp_schedule)
                zn_vent_wind_and_stack.setMaximumIndoorTemperatureSchedule(zone_clg_sp_schedule)
                zn_vent_wind_and_stack.setMinimumOutdoorTemperature(nv_Tout_min)
                zn_vent_wind_and_stack.setMaximumOutdoorTemperature(nv_Tout_max)
                zn_vent_wind_and_stack.setDeltaTemperature(nv_Delta_Tin_Tout)
                zone_hvac_equipment_list.addEquipment(zn_vent_wind_and_stack)

              # elsif nv_comfort_model == 'Adaptive_Model'  #TODO: to include adaptive thermal comfort model (ASHRAE 55)

              end #nv_comfort_model == 'Fanger_Model'

            end #if (subsurface.subSurfaceType == 'OperableWindow' || subsurface.subSurfaceType == 'FixedWindow') && subsurface.outsideBoundaryCondition == 'Outdoors'
          end #surface.subSurfaces.sort.each do |subsurface|
        end #space.surfaces.sort.each do |surface|


      end #thermal_zone.spaces.sort.each do |space|


    end #model.getZoneHVACEquipmentLists.sort.each do |zone_hvac_equipment_list|


  end

end
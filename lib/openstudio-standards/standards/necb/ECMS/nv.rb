class ECMS

  def apply_nv(model:, nv_type:, nv_opening_fraction:)

    ##### If any of users' inputs are nil/false, do nothing.
    return if nv_type.nil? || nv_type == FALSE
    return if nv_opening_fraction.nil? || nv_opening_fraction == FALSE

    model.getZoneHVACEquipmentLists.sort.each do |zone_hvac_equipment_list|  #TODO: consider zones that do not have hvac?
      # puts zone_hvac_equipment_list

      #TODO to be deleted START
      # # # set air loop availability controls and night cycle manager, after oa system added
      # air_loop.setAvailabilitySchedule(hvac_op_sch)
      # air_loop.setNightCycleControlType('CycleOnAny')
      # avail_mgr = air_loop.availabilityManager
      # if avail_mgr.is_initialized
      #   avail_mgr = avail_mgr.get
      #   if avail_mgr.to_AvailabilityManagerNightCycle.is_initialized
      #     avail_mgr = avail_mgr.to_AvailabilityManagerNightCycle.get
      #     avail_mgr.setCyclingRunTime(1800)
      #   end
      # end
      # AvailabilityManagerScheduled ????? use for on/off of HVAC?
      #TODO to be deleted END

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


        space.surfaces.sort.each do |surface|
          surface.subSurfaces.sort.each do |subsurface|
            # puts subsurface.name.to_s
            if subsurface.subSurfaceType == 'FixedWindow' && subsurface.outsideBoundaryCondition == 'Outdoors'  #TODO: change window type to 'OperableWindow'
              window_azimuth_deg = OpenStudio::convert(subsurface.azimuth,"rad","deg").get
              window_area = subsurface.netArea
              puts "window name is #{subsurface.name.to_s}"
              puts "window azimuth (deg) is #{window_azimuth_deg}"
              puts "window area is #{window_area}"
              # raise('check azimuth of exterior window')

              if number_of_windows == 0.0
                ##### define a constant schedule for operable windows
                operable_window_schedule = OpenStudio::Model::ScheduleConstant.new(model)
                operable_window_schedule.setName('operable_window_schedule_constant')
                operable_window_schedule.setScheduleTypeLimits(BTAP::Resources::Schedules::StandardScheduleTypeLimits::get_on_off(model))

                ##### define EMS sensors: Tin and Tout
                sensor_Tin = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Zone Mean Air Temperature')
                sensor_Tin.setName("#{thermal_zone.name.to_s}_sensor_Tin")
                sensor_Tin.setKeyName(thermal_zone.name.get)

                sensor_Tout = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Site Outdoor Air Drybulb Temperature')

                ##### define EMS actuators: (1) whether window is open or closed; (2) whether HVAC is on or off.
                actuator_window_state = OpenStudio::Model::EnergyManagementSystemActuator.new(operable_window_schedule, 'Schedule:Constant', 'Schedule Value')
                actuator_window_state.setName("#{thermal_zone.name.to_s}_actuator_window_state")



                ##### define EMS program
                nv_avail_sch_prog = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
                nv_avail_sch_prog.setName('NV_program')
                nv_avail_sch_prog_body = <<-EMS
                IF #{sensor_Tout.handle} < #{sensor_Tin.handle} 
                  SET #{actuator_window_state.handle} = 1.0
                ELSEIF #{sensor_Tout.handle} > #{sensor_Tin.handle}
                  SET #{actuator_window_state.handle} = 0.0
                ENDIF
                EMS
                nv_avail_sch_prog.setBody(nv_avail_sch_prog_body)

                ##### define EMS program calling managers
                nv_prog_mgr = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
                nv_prog_mgr.setName('NV_program_calling_manager')
                nv_prog_mgr.setCallingPoint('BeginTimestepBeforePredictor')
                nv_prog_mgr.addProgram(nv_avail_sch_prog)

                #####
                zn_vent_design_flow_rate_1 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
                zn_vent_design_flow_rate_1.setDesignFlowRateCalculationMethod('Flow/Person')
                zn_vent_design_flow_rate_1.setFlowRateperPerson(outdoor_air_flow_per_person)
                zn_vent_design_flow_rate_1.setVentilationType('Natural')
                zone_hvac_equipment_list.addEquipment(zn_vent_design_flow_rate_1)
                thermal_zone.setCoolingPriority(zn_vent_design_flow_rate_1.to_ModelObject.get, 1)
                thermal_zone.setHeatingPriority(zn_vent_design_flow_rate_1.to_ModelObject.get, 1)

                #####
                zn_vent_design_flow_rate_2 = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
                zn_vent_design_flow_rate_2.setDesignFlowRateCalculationMethod('Flow/Area')
                zn_vent_design_flow_rate_2.setFlowRateperZoneFloorArea(outdoor_air_flow_per_floor_area)
                zn_vent_design_flow_rate_2.setVentilationType('Natural')
                zone_hvac_equipment_list.addEquipment(zn_vent_design_flow_rate_2)
                thermal_zone.setCoolingPriority(zn_vent_design_flow_rate_2.to_ModelObject.get, 2)
                thermal_zone.setHeatingPriority(zn_vent_design_flow_rate_2.to_ModelObject.get, 2)

                #####
                ### note: it has been assumed that 'Opening Effectiveness' and 'Discharge Coefficient for Opening' are autocalculated (which is the default).
                zn_vent_wind_and_stack = OpenStudio::Model::ZoneVentilationWindandStackOpenArea.new(model)
                zn_vent_wind_and_stack.setOpeningArea(window_area * nv_opening_fraction)
                zn_vent_wind_and_stack.setOpeningAreaFractionSchedule(operable_window_schedule)
                # E+ I/O: "The below input field value is used to calculate the angle between the wind direction and the opening outward normal to determine the opening effectiveness values when the input field Opening Effectiveness = Autocalculate."
                # E+ I/O: "Effective Angle is the angle in degrees counting from the North clockwise to the opening outward normal."
                zn_vent_wind_and_stack.setEffectiveAngle(window_azimuth_deg)
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
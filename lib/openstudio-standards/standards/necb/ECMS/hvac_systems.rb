class ECMS

  # =============================================================================================================================
  # Remove existing zone equipment
  def remove_all_zone_eqpt(sys_objs)
    sys_objs.each do |isys|
      isys.thermalZones.each do |izone|
        if(izone.equipment.empty?) then next end
        izone.equipment.each {|icomp| icomp.remove}
      end
    end
  end

  # =============================================================================================================================
  # Remove hot-water plant loops
  def remove_hw_loops(model)
    model.getPlantLoops.each do |iloop|
      hw_loop = false
      iloop.supplyComponents.each do |icomp|
        if(icomp.to_BoilerHotWater.is_initialized)
          hw_loop = true
          break
        end
      end
      if hw_loop then iloop.remove end
    end
  end

  # =============================================================================================================================
  # Remove chilled-water plant loops
  def remove_chw_loops(model)
    model.getPlantLoops.each do |iloop|
      chw_loop = false
      iloop.supplyComponents.each do |icomp|
        if(icomp.to_ChillerElectricEIR.is_initialized)
          chw_loop = true
          break
        end
      end
      if chw_loop then iloop.remove end
    end
  end

  # =============================================================================================================================
  # Remove condenser-water plant loops
  def remove_cw_loops(model)
    model.getPlantLoops.each do |iloop|
      cw_loop = false
      iloop.supplyComponents.each do |icomp|
        if(icomp.to_CoolingTowerSingleSpeed.is_initialized)
          cw_loop = true
        end
      end
      if cw_loop then iloop.remove end
    end
  end

  # =============================================================================================================================
  # Remove air loops
  def remove_air_loops(model)
    # remove air loops
    model.getAirLoopHVACs.each do |iloop|
      iloop.remove
    end
  end

  # =============================================================================================================================
  # Return map of systems to zones and set flag for dedicated outdoor air unit for each system
  def get_map_systems_to_zones(systems)
    map_systems_to_zones = {}
    system_doas_flags = {}
    systems.each do |system|
      zones = system.thermalZones
      map_systems_to_zones[system.name.to_s] = zones
      if system.sizingSystem.typeofLoadtoSizeOn.to_s == "VentilationRequirement"
        system_doas_flags[system.name.to_s] = true
      else
        system_doas_flags[system.name.to_s] = false
      end
    end
    return map_systems_to_zones,system_doas_flags
  end

  # =============================================================================================================================
  # Return hash of zone and cooling equipment type in the zone
  def get_zone_clg_eqpt_type(model)
    zone_clg_eqpt_type = {}
    model.getThermalZones.each do |zone|
      zone.equipment.each do |eqpt|
        if eqpt.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          zone_clg_eqpt_type[zone.name.to_s] = "ZoneHVACPackagedTerminalAirConditioner"
          break
        end
      end
    end
    return zone_clg_eqpt_type
  end

  # =============================================================================================================================
  # Return hash of flags for whether storey is conditioned and average ceiling z-coordinates of building storeys.
  def get_storey_avg_clg_zcoords(model)
    storey_avg_clg_zcoords = {}
    model.getBuildingStorys.each do |storey|
      storey_avg_clg_zcoords[storey] = []
      storey_cond = false
      total_area = 0.0
      sum = 0.0
      storey.spaces.each do |space|
        # Determine if any of the spaces/zones of the storey are conditioned? If yes then the floor is considered to be conditioned
        if space.thermalZone.is_initialized
          zone = space.thermalZone.get
          if zone.thermostat.is_initialized
            if zone.thermostat.get.to_ThermostatSetpointDualSetpoint.is_initialized
              if zone.thermostat.get.to_ThermostatSetpointDualSetpoint.get.heatingSetpointTemperatureSchedule.is_initialized ||
                  zone.thermostat.get.to_ThermostatSetpointDualSetpoint.get.coolingSetpointTemperatureSchedule.is_initialized
                storey_cond = true
              end
            end
          end
        end
        # Find average height of z-coordinates of ceiling/roof of floor
        space.surfaces.each do |surf|
          if (surf.surfaceType.to_s.upcase == "ROOFCEILING")
            sum += (surf.centroid.z.to_f + space.zOrigin.to_f) * surf.grossArea.to_f
            total_area += surf.grossArea.to_f
          end
        end
      end
      storey_avg_clg_zcoords[storey] << storey_cond
      storey_avg_clg_zcoords[storey] << (sum / total_area)
    end

    return storey_avg_clg_zcoords
  end

  # =============================================================================================================================
  # Return x,y,z coordinates of exterior wall with largest area on the lowest floor
  def get_lowest_floor_ext_wall_centroid_coords(storeys_clg_zcoords)
    ext_wall,ext_wall_x,ext_wall_y,ext_wall_z = nil,nil,nil,nil
    storeys_clg_zcoords.keys.each do |storey|
      max_area = 0.0
      sorted_spaces = storey.spaces.sort_by {|space| space.name.to_s}
      sorted_spaces.each do |space|
        ext_walls = space.surfaces.select {|surf| (surf.surfaceType.to_s.upcase == "WALL") && (surf.outsideBoundaryCondition.to_s.upcase == "OUTDOORS")}
        ext_walls = ext_walls.sort_by {|wall| wall.grossArea.to_f}
        if not ext_walls.empty?
          if ext_walls.last.grossArea.to_f > max_area
            max_area = ext_walls.last.grossArea.to_f
            ext_wall_x = ext_walls.last.centroid.x.to_f + space.xOrigin.to_f
            ext_wall_y = ext_walls.last.centroid.y.to_f + space.yOrigin.to_f
            ext_wall_z = ext_walls.last.centroid.z.to_f + space.zOrigin.to_f
            ext_wall = ext_walls.last
          end
        end
      end
      break unless not ext_wall
    end
    if not ext_wall
      OpenStudio.logFree(OpenStudio::Info, 'openstudiostandards.get_lowest_floor_ext_wall_centroid_coords','Did not find an exteior wall in the building!')
    end

    return ext_wall_x,ext_wall_y,ext_wall_z
  end

  # =============================================================================================================================
  # Return x,y,z coordinates of space centroid
  def get_space_centroid_coords(space)
    total_area = 0.0
    sum_x,sum_y,sum_z = 0.0,0.0,0.0
    space.surfaces.each do |surf|
      total_area += surf.grossArea.to_f
      sum_x += (surf.centroid.x.to_f + space.xOrigin.to_f) * surf.grossArea.to_f
      sum_y += (surf.centroid.y.to_f + space.yOrigin.to_f) * surf.grossArea.to_f
      sum_z += (surf.centroid.z.to_f + space.zOrigin.to_f) * surf.grossArea.to_f
    end
    space_centroid_x = sum_x / total_area
    space_centroid_y = sum_y / total_area
    space_centroid_z = sum_z / total_area

    return space_centroid_x,space_centroid_y,space_centroid_z
  end

  # =============================================================================================================================
  # Return x,y,z coordinates of the centroid of the roof of the storey
  def get_roof_centroid_coords(storey)
    sum_x,sum_y,sum_z,total_area = 0.0,0.0,0.0,0.0
    cent_x,cent_y,cent_z = nil,nil,nil
    storey.spaces.each do |space|
      roof_surfaces = space.surfaces.select {|surf| (surf.surfaceType.to_s.upcase == "ROOFCEILING") && (surf.outsideBoundaryCondition.to_s.upcase == "OUTDOORS")}
      roof_surfaces.each do |surf|
        sum_x += (surf.centroid.x.to_f + space.xOrigin.to_f) * surf.grossArea.to_f
        sum_y += (surf.centroid.y.to_f + space.yOrigin.to_f) * surf.grossArea.to_f
        sum_z += (surf.centroid.z.to_f + space.zOrigin.to_f) * surf.grossArea.to_f
        total_area += surf.grossArea.to_f
      end
    end
    if total_area > 0.0
      cent_x = sum_x / total_area
      cent_y = sum_y / total_area
      cent_z = sum_z / total_area
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudiostandards.get_roof_centroid_coords','Did not find a roof on the top floor!')
    end

    return cent_x,cent_y,cent_z
  end

  # =============================================================================================================================
  # Determine maximum equivalent and net vertical pipe runs for VRF model
  def get_max_vrf_pipe_lengths(model)
    # Get and sort floors average ceilings z-coordinates hash
    storeys_clg_zcoords = get_storey_avg_clg_zcoords(model)
    storeys_clg_zcoords = storeys_clg_zcoords.sort_by {|key,value| value[1]}.to_h  # sort storeys hash based on ceiling/roof z-coordinate
    if storeys_clg_zcoords.values.last[0]
      # If the top floor is conditioned, then assume the top floor is not an attic floor and place the VRF outdoor unit at the roof centroid
      location_cent_x,location_cent_y,location_cent_z = get_roof_centroid_coords(storeys_clg_zcoords.keys.last)
    else
      # If the top floor is not conditioned, then assume it's an attic floor. In this case place the VRF outdoor unit next to the centroid
      # of the exterior wall with the largest area on the lowest floor.
      location_cent_x,location_cent_y,location_cent_z = get_lowest_floor_ext_wall_centroid_coords(storeys_clg_zcoords)
    end
    # Initialize distances
    max_equiv_distance = 0.0
    max_vert_distance = 0.0
    min_vert_distance = 0.0
    storeys_clg_zcoords.keys.each do |storey|
      next unless storeys_clg_zcoords[storey][0]
      storey.spaces.each do |space|
        # Is there a VRF terminal unit in the space/zone?
        vrf_term_units = []
        if space.thermalZone.is_initialized
          vrf_term_units = space.thermalZone.get.equipment.select {|eqpt| eqpt.to_ZoneHVACTerminalUnitVariableRefrigerantFlow.is_initialized}
        end
        next unless not vrf_term_units.empty?
        space_centroid_x,space_centroid_y,space_centroid_z = get_space_centroid_coords(space)
        # Update max horizontal and vertical distances if needed
        equiv_distance = (location_cent_x.to_f - space_centroid_x.to_f).abs +
            (location_cent_y.to_f - space_centroid_y.to_f).abs +
            (location_cent_z.to_f - space_centroid_z.to_f).abs
        if equiv_distance > max_equiv_distance then max_equiv_distance = equiv_distance end
        pos_vert_distance = [space_centroid_z.to_f-location_cent_z.to_f,0.0].max
        if pos_vert_distance > max_vert_distance then max_vert_distance = pos_vert_distance end
        neg_vert_distance = [space_centroid_z.to_f-location_cent_z.to_f,0.0].min
        if neg_vert_distance < min_vert_distance then min_vert_distance = neg_vert_distance end
      end
    end
    max_net_vert_distance = max_vert_distance + min_vert_distance
    max_net_vert_distance = [max_net_vert_distance,0.000001].max

    return max_equiv_distance,max_net_vert_distance
  end

  # =============================================================================================================================
  # Add an outdoor VRF unit
  def add_outdoor_vrf_unit(model:,
                           ecm_name: nil,
                           condenser_type: "AirCooled")
    outdoor_vrf_unit = OpenStudio::Model::AirConditionerVariableRefrigerantFlow.new(model)
    outdoor_vrf_unit.setName("VRF Outdoor Unit")
    outdoor_vrf_unit.setHeatPumpWasteHeatRecovery(true)
    outdoor_vrf_unit.setRatedHeatingCOP(4.0)
    outdoor_vrf_unit.setRatedCoolingCOP(4.0)
    outdoor_vrf_unit.setMinimumOutdoorTemperatureinHeatingMode(-25.0)
    outdoor_vrf_unit.setHeatingPerformanceCurveOutdoorTemperatureType("WetBulbTemperature")
    outdoor_vrf_unit.setMasterThermostatPriorityControlType("ThermostatOffsetPriority")
    outdoor_vrf_unit.setDefrostControl('OnDemand')
    outdoor_vrf_unit.setDefrostStrategy('ReverseCycle')
    outdoor_vrf_unit.autosizeResistiveDefrostHeaterCapacity
    outdoor_vrf_unit.setPipingCorrectionFactorforHeightinHeatingModeCoefficient(-0.00019231)
    outdoor_vrf_unit.setPipingCorrectionFactorforHeightinCoolingModeCoefficient(-0.00019231)
    outdoor_vrf_unit.setMinimumOutdoorTemperatureinHeatRecoveryMode(-5.0)
    outdoor_vrf_unit.setMaximumOutdoorTemperatureinHeatRecoveryMode(26.2)
    outdoor_vrf_unit.setInitialHeatRecoveryCoolingCapacityFraction(0.5)
    outdoor_vrf_unit.setHeatRecoveryCoolingCapacityTimeConstant(0.15)
    outdoor_vrf_unit.setInitialHeatRecoveryCoolingEnergyFraction(1.0)
    outdoor_vrf_unit.setHeatRecoveryCoolingEnergyTimeConstant(0.0)
    outdoor_vrf_unit.setInitialHeatRecoveryHeatingCapacityFraction(1.0)
    outdoor_vrf_unit.setHeatRecoveryHeatingCapacityTimeConstant(0.15)
    outdoor_vrf_unit.setInitialHeatRecoveryHeatingEnergyFraction(1.0)
    outdoor_vrf_unit.setHeatRecoveryCoolingEnergyTimeConstant(0.0)
    outdoor_vrf_unit.setMinimumHeatPumpPartLoadRatio(0.5)
    outdoor_vrf_unit.setCondenserType(condenser_type)
    outdoor_vrf_unit.setCrankcaseHeaterPowerperCompressor(1.0e-6)
    heat_defrost_eir_ft = nil
    if ecm_name
      search_criteria = {}
      search_criteria["name"] = "Mitsubishi_Hyper_Heating_VRF_Outdoor_Unit"
      props =  model_find_object(standards_data['tables']["heat_pump_heating_ecm"]['table'], search_criteria, 1.0)
      heat_defrost_eir_ft = model_add_curve(model, props['heat_defrost_eir_ft'])
    end
    if heat_defrost_eir_ft
      outdoor_vrf_unit.setDefrostEnergyInputRatioModifierFunctionofTemperatureCurve(heat_defrost_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{outdoor_vrf_unit.name}, cannot find heat_defrost_eir_ft curve, will not be set.")
    end

    return outdoor_vrf_unit
  end

  # =============================================================================================================================
  # Method to determine whether zone can have terminal vrf equipment. Zones with no vrf terminal equipment are characterized by
  # transient occupancy such is the case for corridors, stairwells, storage, etc ...
  def zone_with_no_vrf_eqpt?(zone)
    space_types_to_skip = {}
    space_types_to_skip["NECB2011"] = ["Atrium - H < 13m",
                                       "Atrium - H > 13m","Audience - auditorium",
                                       "Corr. < 2.4m wide",
                                       "Corr. >= 2.4m wide",
                                       "Electrical/Mechanical",
                                       "Hospital corr. < 2.4m",
                                       "Hospital corr. >= 2.4m",
                                       "Mfg - corr. < 2.4m",
                                       "Mfg - corr. >= 2.4m",
                                       "Lobby - elevator",
                                       "Lobby - hotel",
                                       "Lobby - motion picture",
                                       "Lobby - other",
                                       "Lobby - performance arts",
                                       "Locker room",
                                       "Parking garage space",
                                       "Stairway",
                                       "Storage area",
                                       "Storage area - occsens",
                                       "Storage area - refrigerated",
                                       "Storage area - refrigerated - occsens",
                                       "Washroom",
                                       "Warehouse - fine",
                                       "Warehouse - fine - refrigerated",
                                       "Warehouse - med/blk",
                                       "Warehouse - med/blk - refrigerated",
                                       "Warehouse - med/blk2",
                                       "Warehouse - med/blk2 - refrigerated",
                                       "Hotel/Motel - lobby"]

    space_types_to_skip["NECB2015"] = ["Atrium (height < 6m)",
                                       "Atrium (6 =< height <= 12m)",
                                       "Atrium (height > 12m)",
                                       "Computer/Server room-sch-A",
                                       "Copy/Print room",
                                       "Corridor/Transition area - hospital",
                                       "Corridor/Transition area - manufacturing facility",
                                       "Corridor/Transition area - space designed to ANSI/IES RP-28",
                                       "Corridor/Transition area other",
                                       "Electrical/Mechanical room",
                                       "Emergency vehicle garage",
                                       "Lobby - elevator",
                                       "Lobby - hotel",
                                       "Lobby - motion picture theatre",
                                       "Lobby - performing arts theatre",
                                       "Lobby - space designed to ANSI/IES RP-28",
                                       "Lobby - other",
                                       "Locker room",
                                       "Storage garage interior",
                                       "Storage room < 5 m2",
                                       "Storage room <= 5 m2 <= 100 m2",
                                       "Storage room > 100 m2",
                                       "Washroom - space designed to ANSI/IES RP-28",
                                       "Washroom - other",
                                       "Warehouse storage area medium to bulky palletized items",
                                       "Warehouse storage area small hand-carried items(4)"]

    space_types_to_skip["NECB2017"] = ["Atrium (height < 6m)",
                                       "Atrium (6 =< height <= 12m)",
                                       "Atrium (height > 12m)",
                                       "Computer/Server room",
                                       "Copy/Print room",
                                       "Corridor/Transition area - hospital",
                                       "Corridor/Transition area - manufacturing facility",
                                       "Corridor/Transition area - space designed to ANSI/IES RP-28",
                                       "Corridor/Transition area other",
                                       "Electrical/Mechanical room",
                                       "Emergency vehicle garage",
                                       "Lobby - elevator",
                                       "Lobby - hotel",
                                       "Lobby - motion picture theatre",
                                       "Lobby - performing arts theatre",
                                       "Lobby - space designed to ANSI/IES RP-28",
                                       "Lobby - other",
                                       "Locker room",
                                       "Stairway/Stairwell",
                                       "Storage garage interior",
                                       "Storage room < 5 m2",
                                       "Storage room <= 5 m2 <= 100 m2",
                                       "Storage room > 100 m2",
                                       "Washroom - space designed to ANSI/IES RP-28",
                                       "Washroom - other",
                                       "Warehouse storage area medium to bulky palletized items",
                                       "Warehouse storage area small hand-carried items(4)"]

    zone_does_not_have_vrf_eqpt = false
    zone.spaces.each do |space|
      space_types_to_skip.each do |std,spfs|
        spfs.each do |spf|
          if space.spaceType.get.name.to_s.downcase.include? spf.downcase
            zone_does_not_have_vrf_eqpt = true
            break
          end
        end
        break if zone_does_not_have_vrf_eqpt
      end
      break if zone_does_not_have_vrf_eqpt
    end
  end

  # =============================================================================================================================
  # Add equipment for ECM 'hs08_doas_ccashp_vrf':
  #   -Constant-volume DOAS with cold-climate air source heat pump for heating and cooling and electric backup
  #   -Zonal terminal VRF units connected to an outdoor VRF condenser unit
  #   -Zonal electric backup
  def add_ecm_hs08_ccashp_vrf(model:,
                            system_zones_map:,
                            system_doas_flags:)
    # Add outdoor VRF unit
    outdoor_vrf_unit = add_outdoor_vrf_unit(model: model,ecm_name: "hs08_vrfzonal")
    # Update system doas flags
    system_doas_flags.keys.each {|sname| system_doas_flags[sname] = true}
    # use system zones map and generate new air system and zonal equipment
    system_zones_map.sort.each do |sys_name,zones|
      sys_info = air_sys_comps_assumptions(sys_name: sys_name,
                                           zones: zones,
                                           system_doas_flags: system_doas_flags)
      airloop, return_fan = add_air_system(model: model,
                                           zones: zones,
                                           sys_abbr: sys_info["sys_abbr"],
                                           sys_vent_type: sys_info["sys_vent_type"],
                                           sys_heat_rec_type: sys_info["sys_heat_rec_type"],
                                           sys_htg_eqpt_type: "ccashp",
                                           sys_supp_htg_eqpt_type: "coil_electric",
                                           sys_clg_eqpt_type: "ccashp",
                                           sys_supp_fan_type: sys_info["sys_supp_fan_type"],
                                           sys_ret_fan_type: sys_info["sys_ret_fan_type"],
                                           sys_setpoint_mgr_type: sys_info["sys_setpoint_mgr_type"])
      htg_dx_coils = model.getCoilHeatingDXVariableSpeeds
      search_criteria = {}
      search_criteria["name"] = "Mitsubishi_Hyper_Heating_VRF_Outdoor_Unit RTU"
      props =  model_find_object(standards_data['tables']["heat_pump_heating_ecm"]['table'], search_criteria, 1.0)
      heat_defrost_eir_ft = model_add_curve(model, props['heat_defrost_eir_ft'])
      # This defrost curve has to be assigned here before sizing
      if heat_defrost_eir_ft
        htg_dx_coils.sort.each {|dxcoil| dxcoil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(heat_defrost_eir_ft)}
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{htg_dx_coils[0].name}, cannot find heat_defrost_eir_ft curve, will not be set.")
      end
      # add zone equipment and diffuser
      # add terminal VRF units
      add_zone_eqpt(model: model,
                    airloop: airloop,
                    zones: zones,
                    outdoor_unit: outdoor_vrf_unit,
                    zone_diffuser_type: sys_info["zone_diffuser_type"],
                    zone_htg_eqpt_type: "vrf",
                    zone_supp_htg_eqpt_type: "none",
                    zone_clg_eqpt_type: "vrf",
                    zone_fan_type: "On_Off")
      # add electric unit heaters fpr backup
      add_zone_eqpt(model: model,
                    airloop: airloop,
                    zones: zones,
                    outdoor_unit: nil,
                    zone_diffuser_type: nil,
                    zone_htg_eqpt_type: "baseboard_electric",
                    zone_supp_htg_eqpt_type: "none",
                    zone_clg_eqpt_type: "none",
                    zone_fan_type: "none")  # OS doesn't support onoff fans for unit heaters
      # Now we can find and apply maximum horizontal and vertical distances between outdoor vrf unit and zones with vrf terminal units
      max_hor_pipe_length,max_vert_pipe_length = get_max_vrf_pipe_lengths(model)
      outdoor_vrf_unit.setEquivalentPipingLengthusedforPipingCorrectionFactorinCoolingMode(max_hor_pipe_length)
      outdoor_vrf_unit.setEquivalentPipingLengthusedforPipingCorrectionFactorinHeatingMode(max_hor_pipe_length)
      outdoor_vrf_unit.setVerticalHeightusedforPipingCorrectionFactor(max_vert_pipe_length)
    end
  end

  # =============================================================================================================================
  # Apply efficiencies and performance curves for ECM 'hs08_vrfzonal'
  def apply_efficiency_ecm_hs08_ccashp_vrf(model)
    # Use same performance data as ECM "hs09_ccashpsys" for air system
    apply_efficiency_ecm_hs09_ccashpsys(model)
    # Apply efficiency and curves for VRF units
    eqpt_name = "Mitsubishi_Hyper_Heating_VRF_Outdoor_Unit"
    model.getAirConditionerVariableRefrigerantFlows.sort.each do |vrf_unit|
      airconditioner_variablerefrigerantflow_cooling_apply_efficiency_and_curves(vrf_unit,eqpt_name)
      airconditioner_variablerefrigerantflow_heating_apply_efficiency_and_curves(vrf_unit,eqpt_name)
    end
    # Set fan size of VRF terminal units
    fan_power_per_flow_rate = 150.0  # based on Mitsubishi data: 100 low and 200 high (W-s/m3)
    model.getZoneHVACTerminalUnitVariableRefrigerantFlows.each do |iunit|
      fan = iunit.supplyAirFan.to_FanOnOff.get
      fan_pr_rise = fan_power_per_flow_rate*(fan.fanEfficiency*fan.motorEfficiency)
      fan.setPressureRise(fan_pr_rise)
    end
    # Set fan size of unit heaters
    model.getZoneHVACUnitHeaters.each do |iunit|
      fan = iunit.supplyAirFan.to_FanConstantVolume.get
      fan_pr_rise = fan_power_per_flow_rate*(fan.fanEfficiency*fan.motorEfficiency)
      fan.setPressureRise(fan_pr_rise)
    end
  end

  # =============================================================================================================================
  # create air loop
  def create_airloop(model,sys_vent_type)
    airloop = OpenStudio::Model::AirLoopHVAC.new(model)
    airloop.sizingSystem.setPreheatDesignTemperature(7.0)
    airloop.sizingSystem.setPreheatDesignHumidityRatio(0.008)
    airloop.sizingSystem.setPrecoolDesignTemperature(13.0)
    airloop.sizingSystem.setPrecoolDesignHumidityRatio(0.008)
    airloop.sizingSystem.setSizingOption('NonCoincident')
    airloop.sizingSystem.setCoolingDesignAirFlowMethod('DesignDay')
    airloop.sizingSystem.setCoolingDesignAirFlowRate(0.0)
    airloop.sizingSystem.setHeatingDesignAirFlowMethod('DesignDay')
    airloop.sizingSystem.setHeatingDesignAirFlowRate(0.0)
    airloop.sizingSystem.setSystemOutdoorAirMethod('ZoneSum')
    airloop.sizingSystem.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
    airloop.sizingSystem.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
    airloop.sizingSystem.setMinimumSystemAirFlowRatio(1.0)
    case sys_vent_type.downcase
    when "doas"
      airloop.sizingSystem.setAllOutdoorAirinCooling(true)
      airloop.sizingSystem.setAllOutdoorAirinHeating(true)
      airloop.sizingSystem.setTypeofLoadtoSizeOn('VentilationRequirement')
      airloop.sizingSystem.setCentralCoolingDesignSupplyAirTemperature(19.9)
      airloop.sizingSystem.setCentralHeatingDesignSupplyAirTemperature(20.0)
    when "mixed"
      airloop.sizingSystem.setAllOutdoorAirinCooling(false)
      airloop.sizingSystem.setAllOutdoorAirinHeating(false)
      airloop.sizingSystem.setTypeofLoadtoSizeOn('Sensible')
      airloop.sizingSystem.setCentralCoolingDesignSupplyAirTemperature(13.0)
      airloop.sizingSystem.setCentralHeatingDesignSupplyAirTemperature(43.0)
    end

    return airloop
  end

  # =============================================================================================================================
  # create air system setpoint manager
  def create_air_sys_spm(model,setpoint_mgr_type,zones)
    spm = nil
    case setpoint_mgr_type.downcase
    when "scheduled"
      sat = 20.0
      sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      sat_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), sat)
      spm = OpenStudio::Model::SetpointManagerScheduled.new(model, sat_sch)
    when "single_zone_reheat"
      spm = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      spm.setControlZone(zones[0])
      spm.setMinimumSupplyAirTemperature(13.0)
      spm.setMaximumSupplyAirTemperature(43.0)
    when "warmest"
      spm = OpenStudio::Model::SetpointManagerWarmest.new(model)
      spm.setMinimumSetpointTemperature(13.0)
      spm.setMaximumSetpointTemperature(43.0)
    end

    return spm
  end

  # =============================================================================================================================
  # create air system fan
  def create_air_sys_fan(model,fan_type)
    fan = nil
    case fan_type.downcase
    when "constant_volume"
      fan = OpenStudio::Model::FanConstantVolume.new(model)
      fan.setName("FanConstantVolume")
    when "variable_volume"
      fan = OpenStudio::Model::FanVariableVolume.new(model)
      fan.setName("FanVariableVolume")
    when "on_off"
      fan = OpenStudio::Model::FanOnOff.new(model)
      fan.setName("FanOnOff")
    end

    return fan
  end

  # =============================================================================================================================
  # create air system cooling equipment
  def create_air_sys_clg_eqpt(model,clg_eqpt_type)
    clg_eqpt = nil
    case clg_eqpt_type.downcase
    when "ashp"
      clg_eqpt = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model)
      clg_eqpt.setName("CoilCoolingDxSingleSpeed_ASHP")
      clg_eqpt.setCrankcaseHeaterCapacity(1.0e-6)
    when "ccashp"
      clg_eqpt = OpenStudio::Model::CoilCoolingDXVariableSpeed.new(model)
      clg_eqpt.setName("CoilCoolingDXVariableSpeed_CCASHP")
      clg_eqpt_speed1 = OpenStudio::Model::CoilCoolingDXVariableSpeedSpeedData.new(model)
      clg_eqpt.addSpeed(clg_eqpt_speed1)
      clg_eqpt.setNominalSpeedLevel(1)
      clg_eqpt.setCrankcaseHeaterCapacity(1.0e-6)
    when "vrf"
      clg_eqpt = OpenStudio::Model::CoilCoolingDXVariableRefrigerantFlow.new(model)
      clg_eqpt.setName("CoilCoolingDXVariableRefrigerantFlow")
    end

    return clg_eqpt
  end

  # =============================================================================================================================
  # create air system heating equipment
  def create_air_sys_htg_eqpt(model,htg_eqpt_type)
    always_on = model.alwaysOnDiscreteSchedule
    htg_eqpt = nil
    case htg_eqpt_type.downcase
    when "coil_electric"
      htg_eqpt = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
      htg_eqpt.setName("CoilHeatingElectric")
    when "ashp"
      htg_eqpt = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model)
      htg_eqpt.setName("CoilHeatingDXSingleSpeed_ASHP")
      htg_eqpt.setDefrostStrategy('ReverseCycle')
      htg_eqpt.setDefrostControl('OnDemand')
      htg_eqpt.setCrankcaseHeaterCapacity(1.0e-6)
    when "ccashp"
      htg_eqpt = OpenStudio::Model::CoilHeatingDXVariableSpeed.new(model)
      htg_eqpt.setName("CoilHeatingDXVariableSpeed_CCASHP")
      htg_eqpt_speed1 = OpenStudio::Model::CoilHeatingDXVariableSpeedSpeedData.new(model)
      htg_eqpt.addSpeed(htg_eqpt_speed1)
      htg_eqpt.setNominalSpeedLevel(1)
      htg_eqpt.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(-25.0)
      htg_eqpt.setDefrostStrategy("ReverseCycle")
      htg_eqpt.setDefrostControl("OnDemand")
      htg_eqpt.setCrankcaseHeaterCapacity(1.0e-6)
    end

    return htg_eqpt
  end

  # =============================================================================================================================
  # add air system with all its components
  def add_air_system(model:,
                   zones:,
                   sys_abbr:,
                   sys_vent_type:,
                   sys_heat_rec_type:,
                   sys_htg_eqpt_type:,
                   sys_supp_htg_eqpt_type:,
                   sys_clg_eqpt_type:,
                   sys_supp_fan_type:,
                   sys_ret_fan_type:,
                   sys_setpoint_mgr_type:)

    # create all the needed components and the air loop
    airloop = create_airloop(model,sys_vent_type)
    setpoint_mgr = create_air_sys_spm(model,sys_setpoint_mgr_type,zones)
    supply_fan = create_air_sys_fan(model,sys_supp_fan_type)
    supply_fan.setName("Supply Fan") if supply_fan
    return_fan = create_air_sys_fan(model,sys_ret_fan_type)
    return_fan.setName("Return Fan") if return_fan
    htg_eqpt = create_air_sys_htg_eqpt(model,sys_htg_eqpt_type)
    supp_htg_eqpt = create_air_sys_htg_eqpt(model,sys_supp_htg_eqpt_type)
    clg_eqpt = create_air_sys_clg_eqpt(model,sys_clg_eqpt_type)
    # add components to the air loop
    clg_eqpt.addToNode(airloop.supplyOutletNode) if clg_eqpt
    htg_eqpt.addToNode(airloop.supplyOutletNode) if htg_eqpt
    supp_htg_eqpt.addToNode(airloop.supplyOutletNode) if supp_htg_eqpt
    supply_fan.addToNode(airloop.supplyOutletNode) if supply_fan
    setpoint_mgr.addToNode(airloop.supplyOutletNode) if setpoint_mgr

    # OA controller
    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
    oa_controller.autosizeMinimumOutdoorAirFlowRate
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
    oa_system.addToNode(airloop.supplyInletNode)

    # Set airloop name
    sys_name_pars = {}
    sys_name_pars["sys_hr"] = "none"
    sys_name_pars["sys_clg"] = sys_clg_eqpt_type
    sys_name_pars["sys_htg"] = sys_htg_eqpt_type
    sys_name_pars["sys_sf"] = "cv" if sys_supp_fan_type == "constant_volume"
    sys_name_pars["sys_sf"] = "vv" if sys_supp_fan_type == "variable_volume"
    sys_name_pars["zone_htg"] = "none"
    sys_name_pars["zone_clg"] = "none"
    sys_name_pars["sys_rf"] = "none"
    sys_name_pars["sys_rf"] = "cv" if sys_ret_fan_type == "constant_volume"
    sys_name_pars["sys_rf"] = "vv" if sys_ret_fan_type == "variable_volume"
    assign_base_sys_name(airloop,sys_abbr: sys_abbr,sys_oa: sys_vent_type,sys_name_pars: sys_name_pars)
    return airloop,return_fan
  end

  # =============================================================================================================================
  # create zone diffuser
  def create_zone_diffuser(model,zone_diffuser_type,zone)
    always_on = model.alwaysOnDiscreteSchedule
    diffuser = nil
    case zone_diffuser_type.downcase
    when "single_duct_uncontrolled"
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
    when "single_duct_vav_reheat"
      reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, always_on, reheat_coil)
      #diffuser.setFixedMinimumAirFlowRate(0.002 * zone.floorArea )
      diffuser.setMaximumReheatAirTemperature(43.0)
      diffuser.setDamperHeatingAction('Normal')
    end

    return diffuser
  end

  # =============================================================================================================================
  # create zonal heating equipment
  def create_zone_htg_eqpt(model,zone_htg_eqpt_type)
    always_on = model.alwaysOnDiscreteSchedule
    always_off = model.alwaysOffDiscreteSchedule
    htg_eqpt = nil
    case zone_htg_eqpt_type.downcase
    when "baseboard_electric"
      htg_eqpt = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
      htg_eqpt.setName("Zone HVAC Baseboard Convective Electric")
    when "coil_electric","ptac_electric_off","unitheater_electric"
      htg_eqpt = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
      htg_eqpt.setName("CoilHeatingElectric")
      htg_eqpt.setAvailabilitySchedule(always_off) if zone_htg_eqpt_type == "ptac_electric_off"
    when "pthp"
      htg_eqpt = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model)
      htg_eqpt.setName("CoilHeatingDXSingleSpeed_PTHP")
      htg_eqpt.setDefrostStrategy('ReverseCycle')
      htg_eqpt.setDefrostControl("OnDemand")
      htg_eqpt.setCrankcaseHeaterCapacity(1.0e-6)
    when "vrf"
      htg_eqpt = OpenStudio::Model::CoilHeatingDXVariableRefrigerantFlow.new(model)
      htg_eqpt.setName("CoilHeatingDXVariableRefrigerantFlow")
    end

    return htg_eqpt
  end

  # =============================================================================================================================
  # create zonal cooling equipment
  def create_zone_clg_eqpt(model,zone_clg_eqpt_type)
    always_on = model.alwaysOnDiscreteSchedule
    clg_eqpt = nil
    case zone_clg_eqpt_type.downcase
    when "ptac_electric_off","pthp"
      clg_eqpt = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model)
      clg_eqpt.setName("CoilCoolingDXSingleSpeed_PTHP") if zone_clg_eqpt_type.downcase == "pthp"
      clg_eqpt.setName("CoilCoolingDXSingleSpeed_PTAC") if zone_clg_eqpt_type.downcase == "ptac_electric_off"
      clg_eqpt.setCrankcaseHeaterCapacity(1.0e-6)
    when "vrf"
      clg_eqpt = OpenStudio::Model::CoilCoolingDXVariableRefrigerantFlow.new(model)
      clg_eqpt.setName("CoilCoolingDXVariableRefrigerantFlow")
    end

    return clg_eqpt
  end

  # =============================================================================================================================
  # create zpne container eqpt
  def create_zone_container_eqpt(model:,
                              zone_cont_eqpt_type:,
                              zone_htg_eqpt:,
                              zone_supp_htg_eqpt:,
                              zone_clg_eqpt:,
                              zone_fan:,
                              zone_vent_off: true)

    always_on = model.alwaysOnDiscreteSchedule
    always_off = model.alwaysOffDiscreteSchedule
    zone_eqpt = nil
    case zone_cont_eqpt_type.downcase
    when "ptac_electric_off"
      zone_eqpt = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,always_on,zone_fan,zone_htg_eqpt,zone_clg_eqpt)
      zone_eqpt.setName("ZoneHVACPackagedTerminalAirConditioner")
      if zone_vent_off
        zone_eqpt.setOutdoorAirFlowRateDuringCoolingOperation(1.0e-6)
        zone_eqpt.setOutdoorAirFlowRateDuringHeatingOperation(1.0e-6)
        zone_eqpt.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(1.0e-6)
      end
    when "pthp"
      zone_eqpt = OpenStudio::Model::ZoneHVACPackagedTerminalHeatPump.new(model,always_on,zone_fan,zone_htg_eqpt,zone_clg_eqpt,zone_supp_htg_eqpt)
      zone_eqpt.setName("ZoneHVACPackagedTerminalHeatPump")
      if zone_vent_off
        zone_eqpt.setOutdoorAirFlowRateDuringCoolingOperation(1.0e-6)
        zone_eqpt.setOutdoorAirFlowRateDuringHeatingOperation(1.0e-6)
        zone_eqpt.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(1.0e-6)
        zone_eqpt.setSupplyAirFanOperatingModeSchedule(always_off)
      end
    when "unitheater_electric"
      zone_eqpt = OpenStudio::Model::ZoneHVACUnitHeater.new(model,always_on,zone_fan,zone_htg_eqpt)
      zone_eqpt.setName("ZoneHVACUnitHeater")
      zone_eqpt.setFanControlType("OnOff")
    when "vrf"
      zone_eqpt = OpenStudio::Model::ZoneHVACTerminalUnitVariableRefrigerantFlow.new(model,zone_clg_eqpt,zone_htg_eqpt,zone_fan)
      zone_eqpt.setName("ZoneHVACTerminalUnitVariableRefrigerantFlow")
      zone_eqpt.setSupplyAirFanOperatingModeSchedule(always_off)
      if zone_vent_off
        zone_eqpt.setOutdoorAirFlowRateDuringCoolingOperation(1.0e-6)
        zone_eqpt.setOutdoorAirFlowRateDuringHeatingOperation(1.0e-6)
        zone_eqpt.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(1.0e-6)
        zone_eqpt.setZoneTerminalUnitOffParasiticElectricEnergyUse(1.0e-6)
        zone_eqpt.setZoneTerminalUnitOnParasiticElectricEnergyUse(1.0e-6)
      end
    end

    return zone_eqpt
  end

  # =============================================================================================================================
  # add zonal heating and cooling equipment
  def add_zone_eqpt(model:,
                    airloop:,
                    zones:,
                    outdoor_unit:,
                    zone_diffuser_type:,
                    zone_htg_eqpt_type:,
                    zone_supp_htg_eqpt_type:,
                    zone_clg_eqpt_type:,
                    zone_fan_type:)

    always_on = model.alwaysOnDiscreteSchedule
    zones.sort.each do |zone|
      # during the first call to this method for a zone, the diffuser type has to be specified if there is an air loop serving the zone
      if zone_diffuser_type
        zone.sizingZone.setZoneCoolingDesignSupplyAirTemperature(13.0)
        zone.sizingZone.setZoneHeatingDesignSupplyAirTemperature(43.0)
        zone.sizingZone.setZoneCoolingSizingFactor(1.1)
        zone.sizingZone.setZoneHeatingSizingFactor(1.3)
        diffuser = create_zone_diffuser(model,zone_diffuser_type,zone)
        airloop.removeBranchForZone(zone)
        airloop.addBranchForZone(zone, diffuser.to_StraightComponent)
      end
      clg_eqpt = create_zone_clg_eqpt(model,zone_clg_eqpt_type)
      htg_eqpt = create_zone_htg_eqpt(model,zone_htg_eqpt_type)
      supp_htg_eqpt = create_zone_htg_eqpt(model,zone_supp_htg_eqpt_type)
      fan = create_air_sys_fan(model,zone_fan_type)
      # for container zonal equipment call method "create_zone_container_equipment"
      this_is_container_comp = false
      if (zone_htg_eqpt_type == "pthp") || (zone_htg_eqpt_type == "vrf") ||
         (zone_htg_eqpt_type.include? "unitheater")  || (zone_htg_eqpt_type.include? "ptac")
        this_is_container_comp = true
        zone_cont_eqpt = create_zone_container_eqpt(model: model,
                                                    zone_cont_eqpt_type: zone_htg_eqpt_type,
                                                    zone_htg_eqpt: htg_eqpt,
                                                    zone_supp_htg_eqpt: supp_htg_eqpt,
                                                    zone_clg_eqpt: clg_eqpt,
                                                    zone_fan: fan)
      end
      if zone_cont_eqpt
        zone_cont_eqpt.addToThermalZone(zone)
        outdoor_unit.addTerminal(zone_cont_eqpt) if outdoor_unit
      elsif htg_eqpt && !this_is_container_comp
        htg_eqpt.addToThermalZone(zone)
      end
    end
    sys_name_zone_htg_eqpt_type = zone_htg_eqpt_type
    sys_name_zone_htg_eqpt_type = "b-e" if (zone_htg_eqpt_type == "baseboard_electric" || zone_htg_eqpt_type == "ptac_electric_off")
    sys_name_zone_clg_eqpt_type = zone_clg_eqpt_type
    sys_name_zone_clg_eqpt_type = "ptac" if zone_clg_eqpt_type == "ptac_electric_off"
    update_sys_name(airloop,zone_htg: sys_name_zone_htg_eqpt_type,zone_clg: sys_name_zone_clg_eqpt_type) if zone_diffuser_type
  end

  # =============================================================================================================================
  # Set assumptions for type of components for air system based on the number of zones served by the system and whether it's
  # a mixed or doas.
  def air_sys_comps_assumptions(sys_name:,
                                zones:,
                                system_doas_flags:)

    sys_info = {}
    sys_info["sys_abbr"] = sys_name.split("|")[0]
    sys_info["sys_vent_type"] = "mixed"
    sys_info["sys_vent_type"] = "doas" if system_doas_flags[sys_name.to_s]
    sys_info["sys_heat_rec_type"] = "none"
    sys_info["sys_htg_eqpt_type"] = "coil_electric"
    sys_info["sys_supp_htg_eqpt_type"] = "none"
    sys_info["sys_clg_eqpt_type"] = "coil_dx"
    if zones.size == 1
      sys_info["sys_setpoint_mgr_type"] = "single_zone_reheat"
      sys_info["sys_setpoint_mgr_type"] = "scheduled" if system_doas_flags[sys_name.to_s]
      sys_info["sys_supp_fan_type"] = "constant_volume"
      sys_info["sys_ret_fan_type"] = "none"
      sys_info["zone_diffuser_type"] = "single_duct_uncontrolled"
    elsif zones.size > 1
      if system_doas_flags[sys_name.to_s]
        sys_info["sys_setpoint_mgr_type"] = "scheduled"
        sys_info["sys_supp_fan_type"] = "constant_volume"
        sys_info["sys_ret_fan_type"] = "none"
        sys_info["zone_diffuser_type"] = "single_duct_uncontrolled"
      else
        sys_info["sys_setpoint_mgr_type"] = "warmest"
        sys_info["sys_supp_fan_type"] = "variable_volume"
        sys_info["sys_ret_fan_type"] = "variable_volume"
        sys_info["zone_diffuser_type"] = "single_duct_vav_reheat"
      end
    end

    return sys_info
  end

  # =============================================================================================================================
  # Add equipment for ecm "hs09_ccashpsys":
  #   -Constant-volume reheat system for single zone systems
  #   -VAV system with reheat for non DOAS multi-zone systems
  #   -Cold-climate air-source heat pump for heating and cooling with electric backup
  #   -Electric baseboards
  def add_ecm_hs09_ccashpsys(model:,
                             system_zones_map:,    # hash of ailoop names as keys and array of zones as values
                             system_doas_flags:)   # hash of system names as keys and flag for DOAS as values

    systems = []
    system_zones_map.sort.each do |sys_name,zones|
      sys_info = air_sys_comps_assumptions(sys_name: sys_name,
                                             zones: zones,
                                             system_doas_flags: system_doas_flags)
      # add air loop and its equipment
      airloop, return_fan = add_air_system(model: model,
                               zones: zones,
                               sys_abbr: sys_info["sys_abbr"],
                               sys_vent_type: sys_info["sys_vent_type"],
                               sys_heat_rec_type: sys_info["sys_heat_rec_type"],
                               sys_htg_eqpt_type: "ccashp",
                               sys_supp_htg_eqpt_type: "coil_electric",
                               sys_clg_eqpt_type: "ccashp",
                               sys_supp_fan_type: sys_info["sys_supp_fan_type"],
                               sys_ret_fan_type: sys_info["sys_ret_fan_type"],
                               sys_setpoint_mgr_type: sys_info["sys_setpoint_mgr_type"])
      htg_dx_coils = model.getCoilHeatingDXVariableSpeeds
      search_criteria = {}
      search_criteria["name"] = "Mitsubishi_Hyper_Heating_VRF_Outdoor_Unit RTU",
      props =  model_find_object(standards_data['tables']["heat_pump_heating_ecm"]['table'], search_criteria, 1.0)
      heat_defrost_eir_ft = model_add_curve(model, props['heat_defrost_eir_ft'])
      # This defrost curve has to be assigned here before sizing
      if heat_defrost_eir_ft
        htg_dx_coils.sort.each {|dxcoil| dxcoil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(heat_defrost_eir_ft)}
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{htg_dx_coils[0].name}, cannot find heat_defrost_eir_ft curve, will not be set.")
      end
      # add zone equipment and diffuser
      zone_htg_eqpt_type = "baseboard_electric"
      zone_htg_eqpt_type = "ptac_electric_off" if sys_info["sys_vent_type"] == "doas"
      zone_clg_eqpt_type = "none"
      zone_clg_eqpt_type = "ptac_electric_off" if sys_info["sys_vent_type"] == "doas"
      zone_fan_type = "none"
      zone_fan_type = "constant_volume" if sys_info["sys_vent_type"] == "doas"
      add_zone_eqpt(model: model,
                    airloop: airloop,
                    zones: zones,
                    outdoor_unit: nil,
                    zone_diffuser_type: sys_info["zone_diffuser_type"],
                    zone_htg_eqpt_type: zone_htg_eqpt_type,
                    zone_supp_htg_eqpt_type: "none",
                    zone_clg_eqpt_type: zone_clg_eqpt_type,
                    zone_fan_type: zone_fan_type)
      # for doas use baseboard electric as backup for PTAC units
      if sys_info["sys_vent_type"] == "doas"
        add_zone_eqpt(model: model,
                      airloop: airloop,
                      zones: zones,
                      outdoor_unit: nil,
                      zone_diffuser_type: nil,
                      zone_htg_eqpt_type: "baseboard_electric",
                      zone_supp_htg_eqpt_type: "none",
                      zone_clg_eqpt_type: "none",
                      zone_fan_type: "none")
      end
      return_fan.addToNode(airloop.returnAirNode.get) if return_fan
      systems << airloop
    end

    return systems
  end

  # =============================================================================================================================
  # Apply efficiencies and performance curves for ECM "hs09_ccashpsys"
  def apply_efficiency_ecm_hs09_ccashpsys(model)
    # fraction of electric backup heating coil capacity assigned to dx heating coil
    fr_backup_coil_cap_as_dx_coil_cap = 0.5
    model.getAirLoopHVACs.sort.each do |isys|
      clg_dx_coil = nil
      htg_dx_coil = nil
      backup_coil = nil
      fans = []
      # Find the components on the air loop
      isys.supplyComponents.sort.each do |icomp|
        if icomp.to_CoilCoolingDXVariableSpeed.is_initialized
          clg_dx_coil = icomp.to_CoilCoolingDXVariableSpeed.get
        elsif icomp.to_CoilHeatingDXVariableSpeed.is_initialized
          htg_dx_coil = icomp.to_CoilHeatingDXVariableSpeed.get
        elsif  icomp.to_CoilHeatingElectric.is_initialized
          backup_coil = icomp.to_CoilHeatingElectric.get
        elsif icomp.to_FanConstantVolume.is_initialized
          fans << icomp.to_FanConstantVolume.get
        elsif icomp.to_FanVariableVolume.is_initialized
          fans << icomp.to_FanVariableVolume.get
        end
      end
      if clg_dx_coil && htg_dx_coil && backup_coil
        clg_dx_coil_init_name = get_hvac_comp_init_name(clg_dx_coil,false)
        clg_dx_coil.setName(clg_dx_coil_init_name)
        if clg_dx_coil.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.is_initialized
          max_pd = 0.0
          supply_fan = nil
          fans.each do |fan|
            if fan.pressureRise.to_f > max_pd
              max_pd = fan.pressureRise.to_f
              supply_fan = fan  # assume supply fan has higher pressure drop
            end
          end
          fan_power = supply_fan.autosizedMaximumFlowRate.to_f*max_pd/supply_fan.fanTotalEfficiency.to_f
          clg_dx_coil_cap = clg_dx_coil.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.to_f*
              supply_fan.autosizedMaximumFlowRate.to_f/clg_dx_coil.autosizedRatedAirFlowRateAtSelectedNominalSpeedLevel.to_f+
              fan_power/clg_dx_coil.speeds.last.referenceUnitGrossRatedSensibleHeatRatio.to_f
        else
          clg_dx_coil_cap = clg_dx_coil.grossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.to_f
        end
        htg_dx_coil_init_name = get_hvac_comp_init_name(htg_dx_coil,false)
        htg_dx_coil.setName(htg_dx_coil_init_name)
        backup_coil_cap = backup_coil.autosizedNominalCapacity.to_f
        # Set the DX capacities to the maximum of the fraction of the backup coil capacity or the cooling capacity needed
        dx_cap = fr_backup_coil_cap_as_dx_coil_cap*backup_coil_cap
        if dx_cap < clg_dx_coil_cap then dx_cap = clg_dx_coil_cap end
        clg_dx_coil.setGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel(dx_cap)
        htg_dx_coil.setRatedHeatingCapacityAtSelectedNominalSpeedLevel(dx_cap)
        # Assign performance curves and COPs
        eqpt_name = "Mitsubishi_Hyper_Heating_VRF_Outdoor_Unit RTU"
        coil_cooling_dx_variable_speed_apply_efficiency_and_curves(clg_dx_coil,eqpt_name)
        coil_heating_dx_variable_speed_apply_efficiency_and_curves(htg_dx_coil,eqpt_name)
      end
    end
  end

  # =============================================================================================================================
  # Add equipment for ECM "hs11_pthp"
  #   -Constant volume DOAS with air-source heat pump for heating and cooling and electric backup
  #   -Packaged-Terminal air-source heat pumps with electric backup
  def add_ecm_hs11_pthp(model:,
                        system_zones_map:,
                        system_doas_flags:)

    # Update system doas flags
    system_doas_flags.keys.each {|sname| system_doas_flags[sname] = true}
    # use system zones map and generate new air system and zonal equipment
    systems = []
    system_zones_map.sort.each do |sys_name,zones|
      sys_info = air_sys_comps_assumptions(sys_name: sys_name,
                                           zones: zones,
                                           system_doas_flags: system_doas_flags)
      airloop, return_fan = add_air_system(model: model,
                                           zones: zones,
                                           sys_abbr: sys_info["sys_abbr"],
                                           sys_vent_type: sys_info["sys_vent_type"],
                                           sys_heat_rec_type: sys_info["sys_heat_rec_type"],
                                           sys_htg_eqpt_type: "ashp",
                                           sys_supp_htg_eqpt_type: "coil_electric",
                                           sys_clg_eqpt_type: "ashp",
                                           sys_supp_fan_type: sys_info["sys_supp_fan_type"],
                                           sys_ret_fan_type: sys_info["sys_ret_fan_type"],
                                           sys_setpoint_mgr_type: sys_info["sys_setpoint_mgr_type"])
      # Get and assign defrost performance curve
      search_criteria = {}
      search_criteria["name"] = "HS11_PTHP"
      props = model_find_object(standards_data['tables']["heat_pump_heating_ecm"]['table'], search_criteria, 1.0)
      heat_defrost_eir_ft = model_add_curve(model, props["heat_defrost_eir_ft"])
      if !heat_defrost_eir_ft
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXConstantSpeed', "Cannot find heat_defrost_eir_ft curve, will not be set.")
      end
      airloop.supplyComponents.each do |comp|
        if comp.to_CoilHeatingDXSingleSpeed.is_initialized
          htg_coil = comp.to_CoilHeatingDXSingleSpeed.get
          htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(heat_defrost_eir_ft)
        end
      end
      # add zone equipment and diffuser
      zone_htg_eqpt_type = "pthp"
      zone_clg_eqpt_type = "pthp"
      zone_supp_htg_eqpt_type = "coil_electric"
      zone_fan_type = "on_off"
      add_zone_eqpt(model: model,
                    airloop: airloop,
                    zones: zones,
                    outdoor_unit: nil,
                    zone_diffuser_type: sys_info["zone_diffuser_type"],
                    zone_htg_eqpt_type: zone_htg_eqpt_type,
                    zone_supp_htg_eqpt_type: zone_supp_htg_eqpt_type,
                    zone_clg_eqpt_type: zone_clg_eqpt_type,
                    zone_fan_type: zone_fan_type)
      zones.each do |zone|
        zone.equipment.each do |comp|
          if comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
            if comp.to_ZoneHVACPackagedTerminalHeatPump.get.heatingCoil.to_CoilHeatingDXSingleSpeed.is_initialized
              htg_coil = comp.to_ZoneHVACPackagedTerminalHeatPump.get.heatingCoil.to_CoilHeatingDXSingleSpeed.get
              htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(heat_defrost_eir_ft)
            end
          end
        end
      end
      return_fan.addToNode(airloop.returnAirNode.get) if return_fan
      systems << airloop
    end

    return systems
  end

  # =============================================================================================================================
  # Apply efficiencies and performance curves for ECM "hs11_pthp"
  def apply_efficiency_ecm_hs11_pthp(model)
    fr_backup_coil_cap_as_dx_coil_cap = 0.5  # fraction of electric backup heating coil capacity assigned to dx heating coil
    apply_efficiency_ecm_hs12_ashpsys(model)
    pthp_eqpt_name = "HS11_PTHP"
    model.getAirLoopHVACs.sort.each do |isys|
      isys.thermalZones.each do |zone|
        clg_dx_coil = nil
        htg_dx_coil = nil
        backup_coil = nil
        fan = nil
        zone.equipment.sort.each do |icomp|
          if icomp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
            if icomp.to_ZoneHVACPackagedTerminalHeatPump.get.coolingCoil.to_CoilCoolingDXSingleSpeed.is_initialized
              clg_dx_coil = icomp.to_ZoneHVACPackagedTerminalHeatPump.get.coolingCoil.to_CoilCoolingDXSingleSpeed.get
            end
            if icomp.to_ZoneHVACPackagedTerminalHeatPump.get.heatingCoil.to_CoilHeatingDXSingleSpeed.is_initialized
              htg_dx_coil = icomp.to_ZoneHVACPackagedTerminalHeatPump.get.heatingCoil.to_CoilHeatingDXSingleSpeed.get
            end
            if icomp.to_ZoneHVACPackagedTerminalHeatPump.get.supplementalHeatingCoil.to_CoilHeatingElectric.is_initialized
              backup_coil = icomp.to_ZoneHVACPackagedTerminalHeatPump.get.supplementalHeatingCoil.to_CoilHeatingElectric.get
            end
            if icomp.to_ZoneHVACPackagedTerminalHeatPump.get.supplyAirFan.to_FanOnOff.is_initialized
              fan = icomp.to_ZoneHVACPackagedTerminalHeatPump.get.supplyAirFan.to_FanOnOff.get
            end
          end
          if clg_dx_coil && htg_dx_coil && backup_coil && fan
            clg_dx_coil_init_name = get_hvac_comp_init_name(clg_dx_coil,false)
            clg_dx_coil.setName(clg_dx_coil_init_name)
            if clg_dx_coil.autosizedRatedTotalCoolingCapacity.is_initialized
              clg_dx_coil_cap = clg_dx_coil.autosizedRatedTotalCoolingCapacity.to_f
            else
              clg_dx_coil_cap = clg_dx_coil.ratedTotalCoolingCapacity.to_f
            end
            htg_dx_coil_init_name = get_hvac_comp_init_name(htg_dx_coil,true)
            htg_dx_coil.setName(htg_dx_coil_init_name)
            backup_coil_cap = backup_coil.autosizedNominalCapacity.to_f
            # Set the DX capacities to the maximum of the fraction of the backup coil capacity or the cooling capacity needed
            dx_cap = fr_backup_coil_cap_as_dx_coil_cap*backup_coil_cap
            if dx_cap < clg_dx_coil_cap then dx_cap = clg_dx_coil_cap end
            #clg_dx_coil.setRatedTotalCoolingCapacity(dx_cap)
            #htg_dx_coil.setRatedTotalHeatingCapacity(dx_cap)
            # assign performance curves and COPs
            coil_cooling_dx_single_speed_apply_efficiency_and_curves(clg_dx_coil,pthp_eqpt_name)
            coil_heating_dx_single_speed_apply_efficiency_and_curves(htg_dx_coil,pthp_eqpt_name)
            # Set fan power
            fan_power_per_flow_rate = 150.0  # based on Mitsubishi data: 100 low and 200 high (W-s/m3)
            fan_pr_rise = fan_power_per_flow_rate*(fan.fanEfficiency*fan.motorEfficiency)
            fan.setPressureRise(fan_pr_rise)
         end
        end
      end
    end
  end

  # =============================================================================================================================
  # Add equipment for ecm "hs12_ashpsys":
  #   -Constant-volume reheat system for single zone systems
  #   -VAV system with reheat for non DOAS multi-zone systems
  #   -Air-source heat pump for heating and cooling with electric backup
  #   -Electric baseboards
  def add_ecm_hs12_ashpsys(model:,
                           system_zones_map:,
                           system_doas_flags:)

    systems = []
    system_zones_map.sort.each do |sys_name,zones|
      sys_info = air_sys_comps_assumptions(sys_name: sys_name,
                                           zones: zones,
                                           system_doas_flags: system_doas_flags)
      # add air loop and its equipment
      airloop, return_fan = add_air_system(model: model,
                                           zones: zones,
                                           sys_abbr: sys_info["sys_abbr"],
                                           sys_vent_type: sys_info["sys_vent_type"],
                                           sys_heat_rec_type: sys_info["sys_heat_rec_type"],
                                           sys_htg_eqpt_type: "ashp",
                                           sys_supp_htg_eqpt_type: "coil_electric",
                                           sys_clg_eqpt_type: "ashp",
                                           sys_supp_fan_type: sys_info["sys_supp_fan_type"],
                                           sys_ret_fan_type: sys_info["sys_ret_fan_type"],
                                           sys_setpoint_mgr_type: sys_info["sys_setpoint_mgr_type"])
      # get and assign defrost curve
      htg_dx_coils = model.getCoilHeatingDXSingleSpeeds
      search_criteria = {}
      search_criteria["name"] = "NECB2015_ASHP"
          props =  model_find_object(standards_data['tables']["heat_pump_heating_ecm"]['table'], search_criteria, 1.0)
      heat_defrost_eir_ft = model_add_curve(model, props['heat_defrost_eir_ft'])
      if heat_defrost_eir_ft
        htg_dx_coils.sort.each {|dxcoil| dxcoil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(heat_defrost_eir_ft)}
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{htg_dx_coils[0].name}, cannot find heat_defrost_eir_ft curve, will not be set.")
      end
      # add zone equipment and diffuser
      zone_htg_eqpt_type = "baseboard_electric"
      zone_htg_eqpt_type = "ptac_electric_off" if sys_info["sys_vent_type"] == "doas"
      zone_clg_eqpt_type = "none"
      zone_clg_eqpt_type = "ptac_electric_off" if sys_info["sys_vent_type"] == "doas"
      zone_fan_type = "none"
      zone_fan_type = "constant_volume" if sys_info["sys_vent_type"] == "doas"
      add_zone_eqpt(model: model,
                    airloop: airloop,
                    zones: zones,
                    outdoor_unit: nil,
                    zone_diffuser_type: sys_info["zone_diffuser_type"],
                    zone_htg_eqpt_type: zone_htg_eqpt_type,
                    zone_supp_htg_eqpt_type: "none",
                    zone_clg_eqpt_type: zone_clg_eqpt_type,
                    zone_fan_type: zone_fan_type)
      # for doas use baseboard electric as backup for PTAC units
      if sys_info["sys_vent_type"] == "doas"
        add_zone_eqpt(model: model,
                      airloop: airloop,
                      zones: zones,
                      outdoor_unit: nil,
                      zone_diffuser_type: nil,
                      zone_htg_eqpt_type: "baseboard_electric",
                      zone_supp_htg_eqpt_type: "none",
                      zone_clg_eqpt_type: "none",
                      zone_fan_type: "none")
      end
      return_fan.addToNode(airloop.returnAirNode.get) if return_fan
      systems << airloop
    end

    return systems
  end

  # =============================================================================================================================
  # Name of HVAC component might have been updated by standards methods for setting efficiency. Here original name of the component
  # is restored.
  def get_hvac_comp_init_name(obj,htg_flag)
    return obj.name.to_s if obj.name.to_s.split.size <= 2
    init_name = obj.name.to_s.split[0]
    range = obj.name.to_s.split.size-3
    range = obj.name.to_s.split.size-5 if htg_flag
    for i in 1..range
      init_name += " #{obj.name.to_s.split[i]}"
    end
    return init_name
  end

  # =============================================================================================================================
  # Apply efficiencies and performance curves for ECM "hs12_ashpsys"
  def apply_efficiency_ecm_hs12_ashpsys(model)
    fr_backup_coil_cap_as_dx_coil_cap = 0.5  # fraction of electric backup heating coil capacity assigned to dx heating coil
    ashp_eqpt_name = "NECB2015_ASHP"
    model.getAirLoopHVACs.sort.each do |isys|
      clg_dx_coil = nil
      htg_dx_coil = nil
      backup_coil = nil
      # Find the coils on the air loop
      isys.supplyComponents.sort.each do |icomp|
        if icomp.to_CoilCoolingDXSingleSpeed.is_initialized
          clg_dx_coil = icomp.to_CoilCoolingDXSingleSpeed.get
        elsif icomp.to_CoilHeatingDXSingleSpeed.is_initialized
          htg_dx_coil = icomp.to_CoilHeatingDXSingleSpeed.get
        elsif  icomp.to_CoilHeatingElectric.is_initialized
          backup_coil = icomp.to_CoilHeatingElectric.get
        end
      end
      if clg_dx_coil && htg_dx_coil && backup_coil
        # update names of dx coils
        clg_dx_coil_init_name = get_hvac_comp_init_name(clg_dx_coil,false)
        clg_dx_coil.setName(clg_dx_coil_init_name)
        if clg_dx_coil.autosizedRatedTotalCoolingCapacity.is_initialized
          clg_dx_coil_cap = clg_dx_coil.autosizedRatedTotalCoolingCapacity.to_f
        else
          clg_dx_coil_cap = clg_dx_coil.ratedTotalCoolingCapacity.to_f
        end
        htg_dx_coil_init_name = get_hvac_comp_init_name(htg_dx_coil,true)
        htg_dx_coil.setName(htg_dx_coil_init_name)
        backup_coil_cap = backup_coil.autosizedNominalCapacity.to_f
        # set the DX capacities to the maximum of the fraction of the backup coil capacity or the cooling capacity needed
        dx_cap = fr_backup_coil_cap_as_dx_coil_cap*backup_coil_cap
        if dx_cap < clg_dx_coil_cap then dx_cap = clg_dx_coil_cap end
        clg_dx_coil.setRatedTotalCoolingCapacity(dx_cap)
        htg_dx_coil.setRatedTotalHeatingCapacity(dx_cap)
        # assign performance curves and COPs
        coil_cooling_dx_single_speed_apply_efficiency_and_curves(clg_dx_coil,ashp_eqpt_name)
        coil_heating_dx_single_speed_apply_efficiency_and_curves(htg_dx_coil,ashp_eqpt_name)
      end
    end
  end

  # =============================================================================================================================
  # Applies the standard efficiency ratings and typical performance curves "CoilCoolingDXSingleSpeed" object.
  def coil_cooling_dx_single_speed_apply_efficiency_and_curves(coil_cooling_dx_single_speed,eqpt_name)
    successfully_set_all_properties = true

    search_criteria = {}
    search_criteria["name"] = eqpt_name

    # Get the capacity
    capacity_w = coil_cooling_dx_single_speed_find_capacity(coil_cooling_dx_single_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get

    # Lookup efficiencies
    ac_props =  model_find_object(standards_data['tables']["heat_pump_cooling_ecm"]['table'], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FT curve
    cool_cap_ft = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_cap_ft'])

    if cool_cap_ft
      coil_cooling_dx_single_speed.setTotalCoolingCapacityFunctionOfTemperatureCurve(cool_cap_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FFLOW curve
    cool_cap_fflow = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_cap_fflow'])
    if cool_cap_fflow
      coil_cooling_dx_single_speed.setTotalCoolingCapacityFunctionOfFlowFractionCurve(cool_cap_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find cool_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FT curve
    cool_eir_ft = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_eir_ft'])
    if cool_eir_ft
      coil_cooling_dx_single_speed.setEnergyInputRatioFunctionOfTemperatureCurve(cool_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FFLOW curve
    cool_eir_fflow = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_eir_fflow'])
    if cool_eir_fflow
      coil_cooling_dx_single_speed.setEnergyInputRatioFunctionOfFlowFractionCurve(cool_eir_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find cool_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-PLF-FPLR curve
    cool_plf_fplr = model_add_curve(coil_cooling_dx_single_speed.model, ac_props['cool_plf_fplr'])
    if cool_plf_fplr
      coil_cooling_dx_single_speed.setPartLoadFractionCorrelationCurve(cool_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_Single_speed.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Find the minimum COP and rename with efficiency rating
    cop = coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed, false,search_criteria)

    # Set the efficiency values
    unless cop.nil?
      coil_cooling_dx_single_speed.setRatedCOP(cop.to_f)
    end

  end

  # =============================================================================================================================
  # Applies the standard efficiency ratings and typical performance curves to "CoilHeatingSingleSpeed" object.
  def coil_heating_dx_single_speed_apply_efficiency_and_curves(coil_heating_dx_single_speed,eqpt_name)
    successfully_set_all_properties = true

    # Get the search criteria
    search_criteria = {}
    search_criteria["name"] = eqpt_name

    # Get the capacity
    capacity_w = coil_heating_dx_single_speed_find_capacity(coil_heating_dx_single_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies
    props =  model_find_object(standards_data['tables']["heat_pump_heating_ecm"]['table'], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FT curve
    heat_cap_ft = model_add_curve(coil_heating_dx_single_speed.model, props['heat_cap_ft'])
    if heat_cap_ft
      coil_heating_dx_single_speed.setTotalHeatingCapacityFunctionofTemperatureCurve(heat_cap_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FFLOW curve
    heat_cap_fflow = model_add_curve(coil_heating_dx_single_speed.model, props['heat_cap_fflow'])
    if heat_cap_fflow
      coil_heating_dx_single_speed.setTotalHeatingCapacityFunctionofFlowFractionCurve(heat_cap_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FT curve
    heat_eir_ft = model_add_curve(coil_heating_dx_single_speed.model, props['heat_eir_ft'])
    if heat_eir_ft
      coil_heating_dx_single_speed.setEnergyInputRatioFunctionofTemperatureCurve(heat_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FFLOW curve
    heat_eir_fflow = model_add_curve(coil_heating_dx_single_speed.model, props['heat_eir_fflow'])
    if heat_eir_fflow
      coil_heating_dx_single_speed.setEnergyInputRatioFunctionofFlowFractionCurve(heat_eir_fflow)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-PLF-FPLR curve
    heat_plf_fplr = model_add_curve(coil_heating_dx_single_speed.model, props['heat_plf_fplr'])
    if heat_plf_fplr
      coil_heating_dx_single_speed.setPartLoadFractionCorrelationCurve(heat_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find heat_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Find the minimum COP and rename with efficiency rating
    cop = coil_heating_dx_single_speed_standard_minimum_cop(coil_heating_dx_single_speed, false,search_criteria)

    # Set the efficiency values
    unless cop.nil?
      coil_heating_dx_single_speed.setRatedCOP(cop.to_f)
    end

  end

  # =============================================================================================================================
  # Applies the standard efficiency ratings and typical performance curves "CoilCoolingDXVariableSpeed" object.
  def coil_cooling_dx_variable_speed_apply_efficiency_and_curves(coil_cooling_dx_variable_speed,eqpt_name)
    successfully_set_all_properties = true

    # Get the capacity
    capacity_w = coil_cooling_dx_variable_speed_find_capacity(coil_cooling_dx_variable_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    search_criteria = {}
    search_criteria["name"] = eqpt_name
    ac_props =  model_find_object(standards_data['tables']['heat_pump_cooling_ecm']['table'], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.CoilCoolingDXVariableSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FT curve
    cool_cap_ft = model_add_curve(coil_cooling_dx_variable_speed.model, ac_props['cool_cap_ft'])
    if cool_cap_ft
      coil_cooling_dx_variable_speed.speeds.each {|speed| speed.setTotalCoolingCapacityFunctionofTemperatureCurve(cool_cap_ft)}
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.CoilCoolingDXVariableSpeed', "For #{coil_cooling_dx_variable_speed.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FFLOW curve
    cool_cap_fflow = model_add_curve(coil_cooling_dx_variable_speed.model, ac_props['cool_cap_fflow'])
    if cool_cap_fflow
      coil_cooling_dx_variable_speed.speeds.each {|speed| speed.setTotalCoolingCapacityFunctionofAirFlowFractionCurve(cool_cap_fflow)}
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.CoilCoolingDXVariableSpeed', "For #{coil_cooling_dx_variable_speed.name}, cannot find cool_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FT curve
    cool_eir_ft = model_add_curve(coil_cooling_dx_variable_speed.model, ac_props['cool_eir_ft'])
    if cool_eir_ft
      coil_cooling_dx_variable_speed.speeds.each {|speed| speed.setEnergyInputRatioFunctionofTemperatureCurve(cool_eir_ft)}
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{coil_cooling_dx_variable_speed.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FFLOW curve
    cool_eir_fflow = model_add_curve(coil_cooling_dx_variable_speed.model, ac_props['cool_eir_fflow'])
    if cool_eir_fflow
      coil_cooling_dx_variable_speed.speeds.each {|speed| speed.setEnergyInputRatioFunctionofAirFlowFractionCurve(cool_eir_fflow)}
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{coil_cooling_dx_variable_speed.name}, cannot find cool_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-PLF-FPLR curve
    cool_plf_fplr = model_add_curve(coil_cooling_dx_variable_speed.model, ac_props['cool_plf_fplr'])
    if cool_plf_fplr
      coil_cooling_dx_variable_speed.setEnergyPartLoadFractionCurve(cool_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{coil_cooling_dx_variable_speed.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Find the minimum COP and rename with efficiency rating
    cop = coil_cooling_dx_variable_speed_standard_minimum_cop(coil_cooling_dx_variable_speed, false,search_criteria)

    # Set the efficiency values
    unless cop.nil?
      coil_cooling_dx_variable_speed.speeds.each {|speed| speed.setReferenceUnitGrossRatedCoolingCOP(cop.to_f)}
    end

  end

  # =============================================================================================================================
  # Applies the standard efficiency ratings and typical performance curves to "CoilHeatingVariableSpeed" object.
  def coil_heating_dx_variable_speed_apply_efficiency_and_curves(coil_heating_dx_variable_speed,eqpt_name)
    successfully_set_all_properties = true

    # Get the search criteria
    search_criteria = {}
    search_criteria["name"] = eqpt_name

    # Get the capacity
    capacity_w = coil_heating_dx_variable_speed_find_capacity(coil_heating_dx_variable_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies
    props =  model_find_object(standards_data['tables']["heat_pump_heating_ecm"]['table'], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{coil_heating_dx_variable_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FT curve
    heat_cap_ft = model_add_curve(coil_heating_dx_variable_speed.model, props['heat_cap_ft'])
    if heat_cap_ft
      coil_heating_dx_variable_speed.speeds.each {|speed| speed.setHeatingCapacityFunctionofTemperatureCurve(heat_cap_ft)}
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{coil_heating_dx_variable_speed.name}, cannot find heat_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FFLOW curve
    heat_cap_fflow = model_add_curve(coil_heating_dx_variable_speed.model, props['heat_cap_fflow'])
    if heat_cap_fflow
      coil_heating_dx_variable_speed.speeds.each {|speed| speed.setTotalHeatingCapacityFunctionofAirFlowFractionCurve(heat_cap_fflow)}
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{coil_heating_dx_variable_speed.name}, cannot find heat_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FT curve
    heat_eir_ft = model_add_curve(coil_heating_dx_variable_speed.model, props['heat_eir_ft'])
    if heat_eir_ft
      coil_heating_dx_variable_speed.speeds.each {|speed| speed.setEnergyInputRatioFunctionofTemperatureCurve(heat_eir_ft)}
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSingleSpeed', "For #{coil_heating_dx_variable_speed.name}, cannot find heat_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FFLOW curve
    heat_eir_fflow = model_add_curve(coil_heating_dx_variable_speed.model, props['heat_eir_fflow'])
    if heat_eir_fflow
      coil_heating_dx_variable_speed.speeds.each {|speed| speed.setEnergyInputRatioFunctionofAirFlowFractionCurve(heat_eir_fflow)}
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{coil_heating_dx_variable_speed.name}, cannot find heat_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-PLF-FPLR curve
    heat_plf_fplr = model_add_curve(coil_heating_dx_variable_speed.model, props['heat_plf_fplr'])
    if heat_plf_fplr
      coil_heating_dx_variable_speed.setEnergyPartLoadFractionCurve(heat_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{coil_heating_dx_variable_speed.name}, cannot find heat_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Find the minimum COP and rename with efficiency rating
    cop = coil_heating_dx_variable_speed_standard_minimum_cop(coil_heating_dx_variable_speed, false,search_criteria)

    # Set the efficiency values
    unless cop.nil?
      coil_heating_dx_variable_speed.speeds.each {|speed| speed.setReferenceUnitGrossRatedHeatingCOP(cop.to_f)}
    end

  end

  # =============================================================================================================================
  # Applies the standard cooling efficiency ratings and typical performance curves to "AirConditionerVariableRefrigerantFlow" object.
  def airconditioner_variablerefrigerantflow_cooling_apply_efficiency_and_curves(airconditioner_variablerefrigerantflow,eqpt_name)
    successfully_set_all_properties = true

    search_criteria = {}
    search_criteria["name"] = eqpt_name

    # Get the capacity
    capacity_w = airconditioner_variablerefrigerantflow_cooling_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies
    props =  model_find_object(standards_data['tables']['heat_pump_cooling_ecm']['table'], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FT Low curve
    cool_cap_ft_low = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_cap_ft_low'])
    if cool_cap_ft_low
      airconditioner_variablerefrigerantflow.setCoolingCapacityRatioModifierFunctionofLowTemperatureCurve(cool_cap_ft_low)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_cap_ft_low curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FT boundary curve
    cool_cap_ft_boundary = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_cap_ft_boundary'])
    if cool_cap_ft_boundary
      airconditioner_variablerefrigerantflow.setCoolingCapacityRatioBoundaryCurve(cool_cap_ft_boundary)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_cap_ft_boundary curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FT high curve
    cool_cap_ft_high = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_cap_ft_high'])
    if cool_cap_ft_high
      airconditioner_variablerefrigerantflow.setCoolingCapacityRatioModifierFunctionofHighTemperatureCurve(cool_cap_ft_high)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_cap_ft_high curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FT low curve
    cool_eir_ft_low = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_eir_ft_low'])
    if cool_eir_ft_low
      airconditioner_variablerefrigerantflow.setCoolingEnergyInputRatioModifierFunctionofLowTemperatureCurve(cool_eir_ft_low)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_eir_ft_low curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FT boundary curve
    cool_eir_ft_boundary = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_eir_ft_boundary'])
    if cool_eir_ft_boundary
      airconditioner_variablerefrigerantflow.setCoolingEnergyInputRatioBoundaryCurve(cool_eir_ft_boundary)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_eir_ft_boundary curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FT high curve
    cool_eir_ft_high = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_eir_ft_high'])
    if cool_eir_ft_high
      airconditioner_variablerefrigerantflow.setCoolingEnergyInputRatioModifierFunctionofHighTemperatureCurve(cool_eir_ft_high)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_eir_ft_high curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FPLR low curve
    cool_eir_fplr_low = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_eir_fplr_low'])
    if cool_eir_fplr_low
      airconditioner_variablerefrigerantflow.setCoolingEnergyInputRatioModifierFunctionofLowPartLoadRatioCurve(cool_eir_fplr_low)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_eir_fplr_low curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FPLR high curve
    cool_eir_fplr_high = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_eir_fplr_high'])
    if cool_eir_fplr_high
      airconditioner_variablerefrigerantflow.setCoolingEnergyInputRatioModifierFunctionofHighPartLoadRatioCurve(cool_eir_fplr_high)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_eir_fplr_high curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CCR curve
    cool_ccr = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_ccr'])
    if cool_ccr
      airconditioner_variablerefrigerantflow.setCoolingCombinationRatioCorrectionFactorCurve(cool_ccr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_ccr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-PLF-FPLR curve
    cool_plf_fplr = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_plf_fplr'])
    if cool_plf_fplr
      airconditioner_variablerefrigerantflow.setCoolingPartLoadFractionCorrelationCurve(cool_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-PLF-FPLR curve
    cool_plf_fplr = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_plf_fplr'])
    if cool_plf_fplr
      airconditioner_variablerefrigerantflow.setCoolingPartLoadFractionCorrelationCurve(cool_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FPL curve
    cool_cap_fpl = model_add_curve(airconditioner_variablerefrigerantflow.model, props['cool_cap_fpl'])
    if cool_cap_fpl
      airconditioner_variablerefrigerantflow.setPipingCorrectionFactorforLengthinCoolingModeCurve(cool_cap_fpl)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_cap_fpl curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Find the minimum COP
    cop = airconditioner_variablerefrigerantflow_cooling_standard_minimum_cop(airconditioner_variablerefrigerantflow, false, search_criteria)

    # Set the efficiency values
    unless cop.nil?
      airconditioner_variablerefrigerantflow.setRatedCoolingCOP(cop.to_f)
    end

  end

  # =============================================================================================================================
  # Applies the standard heating efficiency ratings and typical performance curves to "AirConditionerVariableRefrigerantFlow" object.
  def airconditioner_variablerefrigerantflow_heating_apply_efficiency_and_curves(airconditioner_variablerefrigerantflow,eqpt_name)
    successfully_set_all_properties = true

    search_criteria = {}
    search_criteria["name"] = eqpt_name

    # Get the capacity
    capacity_w = airconditioner_variablerefrigerantflow_heating_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies
    props =  model_find_object(standards_data['tables']["heat_pump_heating_ecm"]['table'], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heating efficiency info using #{search_criteria}, cannot apply efficiency.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FT Low curve
    heat_cap_ft_low = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_cap_ft_low'])
    if heat_cap_ft_low
      airconditioner_variablerefrigerantflow.setHeatingCapacityRatioModifierFunctionofLowTemperatureCurve(heat_cap_ft_low)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_cap_ft_low curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FT boundary curve
    heat_cap_ft_boundary = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_cap_ft_boundary'])
    if heat_cap_ft_boundary
      airconditioner_variablerefrigerantflow.setHeatingCapacityRatioBoundaryCurve(heat_cap_ft_boundary)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standard.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_cap_ft_boundary curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FT high curve
    heat_cap_ft_high = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_cap_ft_high'])
    if heat_cap_ft_high
      airconditioner_variablerefrigerantflow.setHeatingCapacityRatioModifierFunctionofHighTemperatureCurve(heat_cap_ft_high)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_cap_ft_high curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FT low curve
    heat_eir_ft_low = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_eir_ft_low'])
    if heat_eir_ft_low
      airconditioner_variablerefrigerantflow.setHeatingEnergyInputRatioModifierFunctionofLowTemperatureCurve(heat_eir_ft_low)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_eir_ft_low curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FT boundary curve
    heat_eir_ft_boundary = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_eir_ft_boundary'])
    if heat_eir_ft_boundary
      airconditioner_variablerefrigerantflow.setHeatingEnergyInputRatioBoundaryCurve(heat_eir_ft_boundary)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_eir_ft_boundary curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FT high curve
    heat_eir_ft_high = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_eir_ft_high'])
    if heat_eir_ft_high
      airconditioner_variablerefrigerantflow.setHeatingEnergyInputRatioModifierFunctionofHighTemperatureCurve(heat_eir_ft_high)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_eir_ft_high curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FPLR low curve
    heat_eir_fplr_low = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_eir_fplr_low'])
    if heat_eir_fplr_low
      airconditioner_variablerefrigerantflow.setHeatingEnergyInputRatioModifierFunctionofLowPartLoadRatioCurve(heat_eir_fplr_low)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_eir_fplr_low curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-EIR-FPLR high curve
    heat_eir_fplr_high = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_eir_fplr_high'])
    if heat_eir_fplr_high
      airconditioner_variablerefrigerantflow.setHeatingEnergyInputRatioModifierFunctionofHighPartLoadRatioCurve(heat_eir_fplr_high)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_eir_fplr_high curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-HCR curve
    heat_hcr = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_hcr'])
    if heat_hcr
      airconditioner_variablerefrigerantflow.setHeatingCombinationRatioCorrectionFactorCurve(heat_hcr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_hcr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-PLF-FPLR curve
    heat_plf_fplr = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_plf_fplr'])
    if heat_plf_fplr
      airconditioner_variablerefrigerantflow.setHeatingPartLoadFractionCorrelationCurve(heat_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the HEAT-CAP-FPL curve
    heat_cap_fpl = model_add_curve(airconditioner_variablerefrigerantflow.model, props['heat_cap_fpl'])
    if heat_cap_fpl
      airconditioner_variablerefrigerantflow.setPipingCorrectionFactorforLengthinHeatingModeCurve(heat_cap_fpl)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heat_cap_fpl curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Find the minimum COP and rename with efficiency rating
    cop = airconditioner_variablerefrigerantflow_heating_standard_minimum_cop(airconditioner_variablerefrigerantflow, false, search_criteria)

    # Set the efficiency values
    unless cop.nil?
      airconditioner_variablerefrigerantflow.setRatedHeatingCOP(cop.to_f)
    end

  end

  # =============================================================================================================================
  # Find minimum efficiency for "CoilCoolingDXSingleSpeed" object
  def coil_cooling_dx_single_speed_standard_minimum_cop(coil_cooling_dx_single_speed,
                                                        rename = false,
                                                        search_criteria)

    capacity_w = coil_cooling_dx_single_speed_find_capacity(coil_cooling_dx_single_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    ac_props = model_find_object(standards_data['tables']['heat_pump_cooling_ecm']['table'], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{coil_cooling_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Get the minimum efficiency standards
    cop = nil

    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{coil_cooling_dx_single_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{coil_cooling_dx_single_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{coil_cooling_dx_single_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{coil_cooling_dx_single_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless ac_props['minimum_coefficient_of_performance_cooling'].nil?
      cop = ac_props['minimum_coefficient_of_performance_cooling']
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXSingleSpeed', "For #{template}: #{coil_cooling_dx_single_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COP = #{cop}")
    end

    # Rename
    if rename
      coil_cooling_dx_single_speed.setName(new_comp_name)
    end

    return cop
  end

  # =============================================================================================================================
  # Find minimum efficiency for "CoilHeatingDXSingleSpeed" object
  def coil_heating_dx_single_speed_standard_minimum_cop(coil_heating_dx_single_speed,
                                                          rename = false,
                                                          search_criteria)

    capacity_w = coil_heating_dx_single_speed_find_capacity(coil_heating_dx_single_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    props = model_find_object(standards_data['tables']["heat_pump_heating_ecm"], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Get the minimum efficiency standards
    cop = nil

    # If specified as EER
    unless props['minimum_energy_efficiency_ratio'].nil?
      min_eer = props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as HSPF (heat pump)
    unless props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_heating_with_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}HSPF"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless props['minimum_full_load_efficiency'].nil?
      min_eer = props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless props['minimum_coefficient_of_performance_heating'].nil?
      cop = props['minimum_coefficient_of_performance_heating']
      new_comp_name = "#{coil_heating_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXSingleSpeed', "For #{template}: #{coil_heating_dx_single_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Rename
    if rename
      coil_heating_dx_single_speed.setName(new_comp_name)
    end

    return cop
  end

  # =============================================================================================================================
  # Find minimum efficiency for "CoilCoolingDXVariableSpeed" object
  def coil_cooling_dx_variable_speed_standard_minimum_cop(coil_cooling_dx_variable_speed,
                                                          rename = false,
                                                          search_criteria)

    capacity_w = coil_cooling_dx_variable_speed_find_capacity(coil_cooling_dx_variable_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    ac_props = model_find_object(standards_data['tables']['heat_pump_cooling_ecm']['table'], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{coil_cooling_dx_variable_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Get the minimum efficiency standards
    cop = nil

    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_single_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless ac_props['minimum_coefficient_of_performance_cooling'].nil?
      cop = ac_props['minimum_coefficient_of_performance_cooling']
      new_comp_name = "#{coil_cooling_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COP = #{cop}")
    end

    # Rename
    if rename
      coil_cooling_dx_variable_speed.setName(new_comp_name)
    end

    return cop
  end

  # =============================================================================================================================
  # Find minimum efficiency for "CoilHeatingDXVariableSpeed" object
  def coil_heating_dx_variable_speed_standard_minimum_cop(coil_heating_dx_variable_speed,
                                                          rename = false,
                                                          search_criteria)

    capacity_w = coil_heating_dx_variable_speed_find_capacity(coil_heating_dx_variable_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    props = model_find_object(standards_data['tables']["heat_pump_heating_ecm"], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{coil_heating_dx_variable_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Get the minimum efficiency standards
    cop = nil

    # If specified as EER
    unless props['minimum_energy_efficiency_ratio'].nil?
      min_eer = props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{template}: #{coil_heating_dx_variable_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as HSPF (heat pump)
    unless props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_heating_with_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}HSPF"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{template}: #{coil_heating_dx_variable_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless props['minimum_full_load_efficiency'].nil?
      min_eer = props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{template}: #{coil_heating_dx_variable_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless props['minimum_coefficient_of_performance_heating'].nil?
      cop = props['minimum_coefficient_of_performance_heating']
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{template}: #{coil_heating_dx_variable_speed.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Rename
    if rename
      coil_heating_dx_variable_speed.setName(new_comp_name)
    end

    return cop
  end

  # =============================================================================================================================
  # Find minimum cooling efficiency for "AirConditionerVariableRefrigerantFlow" object
  def airconditioner_variablerefrigerantflow_cooling_standard_minimum_cop(airconditioner_variablerefrigerantflow,
                                                                          rename = false,
                                                                          search_criteria)

    capacity_w = airconditioner_variablerefrigerantflow_cooling_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    props = model_find_object(standards_data['tables']['heat_pump_cooling_ecm'], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Get the minimum efficiency standards
    cop = nil

    # If specified as EER
    unless props['minimum_energy_efficiency_ratio'].nil?
      min_eer = props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as HSPF (heat pump)
    unless props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_heating_with_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}HSPF"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless props['minimum_full_load_efficiency'].nil?
      min_eer = props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless props['minimum_coefficient_of_performance_cooling'].nil?
      cop = props['minimum_coefficient_of_performance_cooling']
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Rename
    if rename
      airconditioner_variablerefrigerantflow.setName(new_comp_name)
    end

    return cop
  end

  # =============================================================================================================================
  # Find minimum heating efficiency for "AirConditionerVariableRefrigerantFlow" object
  def airconditioner_variablerefrigerantflow_heating_standard_minimum_cop(airconditioner_variablerefrigerantflow,
                                                                          rename = false,
                                                                          search_criteria)

    capacity_w = airconditioner_variablerefrigerantflow_heating_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    props = model_find_object(standards_data['tables']["heat_pump_heating_ecm"], search_criteria, capacity_btu_per_hr)

    # Check to make sure properties were found
    if props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name}, cannot find heating efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Get the minimum efficiency standards
    cop = nil

    # If specified as EER
    unless props['minimum_energy_efficiency_ratio'].nil?
      min_eer = props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as HSPF (heat pump)
    unless props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_heating_with_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}HSPF"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless props['minimum_full_load_efficiency'].nil?
      min_eer = props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless props['minimum_coefficient_of_performance_heating'].nil?
      cop = props['minimum_coefficient_of_performance_heating']
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Rename
    if rename
      airconditioner_variablerefrigerantflow.setName(new_comp_name)
    end

    return cop
  end

  # =============================================================================================================================
  # Find cooling capacity for "CoilCoolingDXVariableSpeed" object
  def coil_cooling_dx_variable_speed_find_capacity(coil_cooling_dx_variable_speed)
    capacity_w = nil
    if coil_cooling_dx_variable_speed.grossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.is_initialized
      capacity_w = coil_cooling_dx_variable_speed.grossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.get
    elsif coil_cooling_dx_variable_speed.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.is_initialized
      capacity_w = coil_cooling_dx_variable_speed.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{coil_cooling_dx_variable_speed.name} capacity is not available, cannot apply efficiency standard.")
      return 0.0
    end

    return capacity_w
  end

  # =============================================================================================================================
  # Find heating capacity for "CoilHeatingDXVariableSpeed" object
  def coil_heating_dx_variable_speed_find_capacity(coil_heating_dx_variable_speed)
    capacity_w = nil
    if coil_heating_dx_variable_speed.ratedHeatingCapacityAtSelectedNominalSpeedLevel.is_initialized
      capacity_w = coil_heating_dx_variable_speed.ratedHeatingCapacityAtSelectedNominalSpeedLevel.get
    elsif coil_heating_dx_variable_speed.autosizedRatedHeatingCapacityAtSelectedNominalSpeedLevel.is_initialized
      capacity_w = coil_heating_dx_variable_speed.autosizedRatedHeatingCapacityAtSelectedNominalSpeedLevel.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{coil_heating_dx_variable_speed.name} capacity is not available, cannot apply efficiency standard.")
      return 0.0
    end

    return capacity_w
  end

  # =============================================================================================================================
  # Find cooling capacity for "AirConditionerVariableRefrigerantFlow" object
  def airconditioner_variablerefrigerantflow_cooling_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_w = nil
    if airconditioner_variablerefrigerantflow.ratedTotalCoolingCapacity.is_initialized
      capacity_w = airconditioner_variablerefrigerantflow.ratedTotalCoolingCapacity.get
    elsif airconditioner_variablerefrigerantflow.autosizedRatedTotalCoolingCapacity.is_initialized
      capacity_w = airconditioner_variablerefrigerantflow.autosizedRatedTotalCoolingCapacity.get
      airconditioner_variablerefrigerantflow.setRatedTotalCoolingCapacity(capacity_w)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name} cooling capacity is not available, cannot apply efficiency standard.")
      return 0.0
    end

    return capacity_w
  end

  # =============================================================================================================================
  # Find heating capacity for "AirConditionerVariableRefrigerantFlow" object
  def airconditioner_variablerefrigerantflow_heating_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_w = nil
    if airconditioner_variablerefrigerantflow.ratedTotalHeatingCapacity.is_initialized
      capacity_w = airconditioner_variablerefrigerantflow.ratedTotalHeatingCapacity.get
    elsif airconditioner_variablerefrigerantflow.autosizedRatedTotalHeatingCapacity.is_initialized
      capacity_w = airconditioner_variablerefrigerantflow.autosizedRatedTotalHeatingCapacity.get
      airconditioner_variablerefrigerantflow.setRatedTotalHeatingCapacity(capacity_w)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{airconditioner_variablerefrigerantflow.name} heating capacity is not available, cannot apply efficiency standard.")
      return 0.0
    end

    return capacity_w
  end

  # ============================================================================================================================
  # Apply boiler efficiency
  # This model takes an OS model and a boiler efficiency string or hash sent to it with the following form:
  #    "boiler_eff": {
  #        "name" => "NECB 88% Efficient Condensing Boiler",
  #        "efficiency" => 0.88,
  #        "part_load_curve" => "BOILER-EFFPLR-COND-NECB2011",
  #        "notes" => "From NECB 2011."
  #    }
  # If boiler_eff is nill then it does nothing.  If both "efficiency" and "part_load_curve" are nil then it does
  # nothing.  If a boiler_eff is passed as a string and not a hash then it looks for a "name" field in the
  # boiler_set.json file that matches boiler_eff and gets the associated boiler performance details from the file.
  # If an efficiency is set but is not between 0.01 and 1.0 it returns an error.  Otherwise, it looks for plant loop
  # supply components that match the "OS_BoilerHotWater" type.  If it finds one it then calls the
  # "reset_boiler_efficiency method which resets the the boiler efficiency and looks for the part load efficiency curve
  # in the curves.json file.  If it finds a curve it sets the part load curve to that, otherwise it returns an error.
  # It also renames the boiler to include the "boiler_eff"["name"].
  def modify_boiler_efficiency(model:, boiler_eff: nil)
    return if boiler_eff.nil?
    # If boiler_eff is a string rather than a hash then assume it is the name of a boiler efficiency package and look
    # for a package with that name in boiler_set.json.
    if boiler_eff.is_a?(String)
      eff_packages = @standards_data['tables']['boiler_eff_ecm']['table']
      eff_package = eff_packages.select{|eff_pack_info| eff_pack_info["name"] == boiler_eff}
      if eff_package.empty?
        raise "Cannot not find #{boiler_eff} in the ECMS boiler_set.json file.  Please check that the name is correctly spelled in the ECMS class boiler_set.json and in the code calling (directly or through another method) the ECMS class modify_boiler_efficiency method."
      elsif eff_package.size > 1
        raise "More than one boiler efficiency package with the name #{boiler_eff} was found.  Please check the ECMS class boiler_set.json file and make sure that each boiler efficiency package has a unique name."
      else
        ecm_name = boiler_eff
        boiler_eff = {
            "name" => ecm_name,
            "efficiency" => eff_package[0]['efficiency'],
            "part_load_curve" => eff_package[0]['part_load_curve']
        }
      end
    end
    # If nothing is passed in the boiler_eff hash then assume this was not supposed to be used and return without doing
    # anything.
    return if boiler_eff["name"].nil? && boiler_eff["efficiency"].nil? && boiler_eff["part_load_curve"].nil?
    # If no efficiency or partload curve are found (either passed directly or via the boiler_set.json file) then assume
    # that the current SHW setting should not be changed.  Return without changing anything.
    return if boiler_eff["efficiency"].nil? && boiler_eff["part_load_curve"].nil?
    raise "You attempted to set the efficiency of boilers in this model to nil. Please check the ECMS class boiler_set.json and make sure the efficiency is properly set" if boiler_eff["efficiency"].nil?
    raise "You attempted to set the efficiency of boilers in this model to: #{boiler_eff['efficiency']}. Please check the ECMS class boiler_set.json and make sure the efficiency you set is between 0.01 and 1.0." if (boiler_eff['efficiency'] < 0.01 || boiler_eff['efficiency'] > 1.0)
    raise "You attempted to set the part load curve of boilers in this model to nil.  Please check the ECMS class boiler_set.json file and ensure that both the efficiency and part load curve are set." if boiler_eff['part_load_curve'].nil?
    model.getBoilerHotWaters.sort.each do |mod_boiler|
      reset_boiler_efficiency(model: model, component: mod_boiler.to_BoilerHotWater.get, eff: boiler_eff)
    end
  end

  # This method takes an OS model, a "OS_BoilerHotWater" type compenent, condensing efficiency limit and an efficiency
  # hash which looks like:
  #    "eff": {
  #        "name": "NECB 88% Efficient Condensing Boiler",
  #        "efficiency" => 0.88,
  #        "part_load_curve" => "BOILER-EFFPLR-COND-NECB2011",
  #        "notes" => "From NECB 2011."
  #    }
  # This method sets efficiency of the boiler to whatever is entered in eff["efficiency"].  It then looks for the
  # "part_load_curve" value in the curves.json file. If it does not find one it returns an error.  If it finds one it
  # reset the part load curve to whatever was found. It then determines the nominal capacity of the boiler.  If the
  # nominal capacity is greater than 1W the boiler is considered a primary boiler (for the name only) if the capacity is
  # less than 1W the boiler is considered a secondary boiler (for the name only).  It then renames the boiler according
  # to the following pattern:
  # "Primary/Secondary eff["name"] capacity kBtu/hr".
  def reset_boiler_efficiency(model:, component:, eff:)
    component.setNominalThermalEfficiency(eff['efficiency'])
    part_load_curve_name = eff["part_load_curve"].to_s
    existing_curve = @standards_data['curves'].select { |curve| curve['name'] == part_load_curve_name }
    raise "No boiler with the name #{part_load_curve_name} could be found in the ECMS class curves.json file.  Please check both the ECMS class boiler_set.json and class curves.json files to ensure the curve is entered and referenced correctly." if existing_curve.empty?
    part_load_curve_data = (@standards_data["curves"].select { |curve| curve['name'] == part_load_curve_name })[0]
    if part_load_curve_data['independent_variable_1'].to_s.upcase == 'TEnteringBoiler'.upcase || part_load_curve_data['independent_variable_2'].to_s.upcase == 'TEnteringBoiler'.upcase
      component.setEfficiencyCurveTemperatureEvaluationVariable('EnteringBoiler')
    elsif part_load_curve_data['independent_variable_1'].to_s.upcase == 'TLeavingBoiler'.upcase || part_load_curve_data['independent_variable_2'].to_s.upcase == 'TLeavingBoiler'.upcase
      component.setEfficiencyCurveTemperatureEvaluationVariable('LeavingBoiler')
    end
    part_load_curve = model_add_curve(model, part_load_curve_name)
    if part_load_curve
      component.setNormalizedBoilerEfficiencyCurve(part_load_curve)
      if component.isNominalCapacityAutosized
        boiler_size_W = model.getAutosizedValue(component, 'Design Size Nominal Capacity', 'W').to_f
      else
        boiler_size_W = component.nominalCapacity.to_f
      end
      boiler_size_kbtu_per_hour = (OpenStudio.convert(boiler_size_W, 'W', 'kBtu/h').get)
      boiler_primacy = 'Primary '
      if boiler_size_W < 1.0
        boiler_primacy = 'Secondary '
      end
      if eff['name'].nil?
        eff_measure_name = "Revised Performance Boiler"
      else
        eff_measure_name = eff['name']
      end
      new_boiler_name = boiler_primacy + eff_measure_name + " #{boiler_size_kbtu_per_hour.round(0)}kBtu/hr #{component.nominalThermalEfficiency} Thermal Eff"
      component.setName(new_boiler_name)
    else
      raise "There was a problem setting the boiler part load curve named #{part_load_curve_name} for #{component.name}.  Please ensure that the curve is entered and referenced correctly in the ECMS class curves.json and boiler_set.json files."
    end
  end

  # ============================================================================================================================
  # Apply Furnace efficiency
  # This model takes an OS model and a furnace efficiency string or hash sent to it with the following form:
  #    "furnace_eff": {
  #        "name" => "NECB 85% Efficient Condensing Furnace",
  #        "efficiency" => 0.85,
  #        "part_load_curve" => "FURNACE-EFFPLR-COND-NECB2011",
  #        "notes" => "From NECB 2011."
  #    }
  # If furnace_eff is nil then it does nothing.  If both "efficiency" and "part_load_curve" are nil then it does
  # nothing.  If a furnace_eff is a string it looks for furnace_eff as a "name" in the furnace_set.json file to find
  # the performance details.  If an efficiency is set but is not between 0.01 and 1.0 it returns an error.  Otherwise,
  # it looks for air loop supply components that match the "OS_CoilHeatingGas" type.  If it finds one it then calls the
  # reset_furnace_efficiency method which resets the the furnace efficiency and looks for the part load efficiency curve
  # in the curves.json file.  If it finds a curve it sets the part load curve to that, otherwise it returns an error. It
  # also renames the furnace to include the "furnace_eff"["name"].
  def modify_furnace_efficiency(model:, furnace_eff: nil)
    return if furnace_eff.nil?
    # If furnace_eff is a string rather than a hash then assume it is the name of a furnace efficiency package and look
    # for a package with that name in furnace_set.json.
    if furnace_eff.is_a?(String)
      eff_packages = @standards_data['tables']['furnace_eff_ecm']['table']
      eff_package = eff_packages.select{|eff_pack_info| eff_pack_info["name"] == furnace_eff}
      if eff_package.empty?
        raise "Cannot not find #{furnace_eff} in the ECMS furnace_set.json file.  Please check that the name is correctly spelled in the ECMS class furnace_set.json and in the code calling (directly or through another method) the ECMS class modify_furnace_efficiency method."
      elsif eff_package.size > 1
        raise "More than one furnace efficiency package with the name #{furnace_eff} was found.  Please check the ECMS class furnace_set.json file and make sure that each furnace efficiency package has a unique name."
      else
        ecm_name = furnace_eff
        furnace_eff = {
            "name" => ecm_name,
            "efficiency" => eff_package[0]['efficiency'],
            "part_load_curve" => eff_package[0]['part_load_curve']
        }
      end
    end
    # If nothing is passed in the furnace_eff hash then assume this was not supposed to be used and return without doing
    # anything.
    return if furnace_eff["name"].nil? && furnace_eff["efficiency"].nil? && furnace_eff["part_load_curve"].nil?
    # If no efficiency or partload curve are found (either passed directly or via the furnace_set.json file) then assume
    # that the current furance performance settings should not be changed.  Return without changing anything.
    return if furnace_eff["efficiency"].nil? && furnace_eff["part_load_curve"].nil?
    raise "You attempted to set the efficiency of furnaces in this model to nil.  Please check the ECMS class furnace_set.json file and make sure the efficiency is set" if furnace_eff["efficiency"].nil?
    raise "You attempted to set the efficiency of furnaces in this model to: #{furnace_eff['efficiency']}. Please check the ECMS class furnace_set.json file and make sure the efficiency you set is between 0.01 and 1.0." if (furnace_eff['efficiency'] < 0.01 || furnace_eff['efficiency'] > 1.0)
    raise "You attempted to set the part load curve of furnaces in this model to nil.  Please check the ECMS class furnace_set.json file and ensure that both the efficiency and part load curve are set." if furnace_eff['part_load_curve'].nil?
    model.getCoilHeatingGass.sort.each do |mod_furnace|
      reset_furnace_efficiency(model: model, component: mod_furnace.to_CoilHeatingGas.get, eff: furnace_eff)
    end
  end

  # This method takes an OS model, a "OS_CoilHeatingGas" type compenent, and an efficiency hash which looks like:
  #    "eff": {
  #        "name": "NECB 85% Efficient Condensing Furnace",
  #        "efficiency" => 0.85,
  #        "part_load_curve" => "FURNACE-EFFPLR-COND-NECB2011",
  #        "notes" => "From NECB 2011."
  #    }
  # This method sets the efficiency of the furnace to whatever is entered in eff["efficiency"].  It then looks for the
  # "part_load_curve" value in the curves.json file.  If it does not find one it returns an error.  If it finds one it
  # reset the part load curve to whatever was found.  It then renames the furnace according to the following pattern:
  # "eff["name"] + <furnace number (whatever was there before)>".
  def reset_furnace_efficiency(model:, component:, eff:)
    component.setGasBurnerEfficiency(eff['efficiency'])
    part_load_curve_name = eff["part_load_curve"].to_s
    existing_curve = @standards_data['curves'].select { |curve| curve['name'] == part_load_curve_name }
    raise "No furnace part load curve with the name #{part_load_curve_name} could be found in the ECMS class curves.json file.  Please check both the ECMS class curves.json and the measure furnace_set.json files to ensure the curve is entered and referenced correctly." if existing_curve.empty?
    part_load_curve = model_add_curve(model, part_load_curve_name)
    raise "There was a problem setting the furnace part load curve named #{part_load_curve_name} for #{component.name}.  Please ensure that the curve is entered and referenced correctly in the ECMS class curves.json or measure furnace_set.json files." unless part_load_curve
    component.setPartLoadFractionCorrelationCurve(part_load_curve)
    if eff['name'].nil?
      ecm_package_name = "Revised Performance Furnace"
    else
      ecm_package_name = eff['name']
    end
    furnace_num = component.name.to_s.gsub(/[^0-9]/, '')
    new_furnace_name = ecm_package_name + " #{furnace_num}"
    component.setName(new_furnace_name)
  end

  # ============================================================================================================================
  # Apply shw efficiency
  # This model takes an OS model and a shw efficiency string or hash sent to it with the following form:
  #    "shw_eff": {
  #        "name" => "Natural Gas Power Vent with Electric Ignition",
  #        "efficiency" => 0.94,
  #        "part_load_curve" => "SWH-EFFFPLR-NECB2011"
  #        "notes" => "From NECB 2011."
  #    }
  # If shw_eff is nil then it does nothing.  If both "efficiency" and "part_load_curve" are nil then it does nothing.
  # If shw_eff is a string then it looks for shw_eff as a "name" in the shw_set.json file for the details on the tank.
  # If an efficiency is set but is not between 0.01 and 1.0 it returns an error.  Otherwise, it looks for mixed water
  # heaters.  If it finds any it then calls the reset_shw_efficiency method which resets the the shw efficiency and the
  # part load curve. It also renames the shw tank with the following pattern:
  # {valume}Gal {eff_name} Water Heater - {Capacity}kBtu/hr {efficiency} Therm Eff
  def modify_shw_efficiency(model:, shw_eff: nil)
    return if shw_eff.nil?
    # If shw_eff is a string rather than a hash then assume it is the name of a shw efficiency package and look
    # for a package with that name in shw_set.json.
    if shw_eff.is_a?(String)
      eff_packages = @standards_data['tables']['shw_eff_ecm']['table']
      eff_package = eff_packages.select{|eff_pack_info| eff_pack_info["name"] == shw_eff}
      if eff_package.empty?
        raise "Cannot not find #{shw_eff} in the ECMS shw_set.json file.  Please check that the name is correctly spelled in the ECMS class shw_set.json and in the code calling (directly or through another method) the ECMS class modify_shw_efficiency method."
      elsif eff_package.size > 1
        raise "More than one shw tank efficiency package with the name #{shw_eff} was found.  Please check the ECMS class shw_set.json file and make sure that each shw tank efficiency package has a unique name."
      else
        ecm_name = shw_eff
        shw_eff = {
            "name" => ecm_name,
            "efficiency" => eff_package[0]['efficiency'],
            "part_load_curve" => eff_package[0]['part_load_curve']
        }
      end
    end
    # If nothing is passed in the shw_eff hash then assume this was not supposed to be used and return without doing
    # anything.
    return if shw_eff["name"].nil? && shw_eff["efficiency"].nil? && shw_eff["part_load_curve"].nil?
    # If no efficiency or partload curve are found (either passed directly or via the shw_set.json file) then assume
    # that the current shw performance settings should not be changed.  Return without changing anything.
    return if shw_eff["efficiency"].nil? && shw_eff["part_load_curve"].nil?
    raise "You attempted to set the efficiency of shw tanks in this model to nil.  Please check the ECMS class shw_set.json file and make sure the efficiency is set" if shw_eff["efficiency"].nil?
    raise "You attempted to set the efficiency of shw tanks in this model to: #{shw_eff['efficiency']}. Please check the ECMS class shw_set.json and make sure the efficiency you set is between 0.01 and 1.0." if (shw_eff['efficiency'] < 0.01 || shw_eff['efficiency'] > 1.0)
    raise "You attempted to set the part load curve of shw tanks in this model to nil.  Please check the ECMS class shw_set.json file and ensure that both the efficiency and part load curve are set." if shw_eff['part_load_curve'].nil?
    model.getWaterHeaterMixeds.sort.each do |shw_mod|
      reset_shw_efficiency(model: model, component: shw_mod, eff: shw_eff)
    end
  end

  # This method takes an OS model, a "OS_WaterHeaterMixed" type compenent, and an efficiency hash which looks like:
  #    "eff": {
  #        "name": "Natural Gas Power Vent with Electric Ignition",
  #        "efficiency" => 0.94,
  #        "part_load_curve" => "SWH-EFFFPLR-NECB2011",
  #        "notes" => "From NECB 2011."
  #    }
  # This method sets the efficiency of the shw heater to whatever is entered in eff["efficiency"].  It then looks for the
  # "part_load_curve" value in the curves.json file.  If it does not find one it returns an error.  If it finds one it
  # resets the part load curve to whatever was found.  It then renames the shw tank according to the following pattern:
  # {valume}Gal {eff_name} Water Heater - {Capacity}kBtu/hr {efficiency} Therm Eff
  def reset_shw_efficiency(model:, component:, eff:)
    return if component.heaterFuelType.to_s.upcase == 'ELECTRICITY'
    eff_result = component.setHeaterThermalEfficiency(eff['efficiency'].to_f)
    raise "There was a problem setting the efficiency of the SHW #{component.name.to_s}.  Please check the ECMS class shw_set.json file or the model." unless eff_result
    part_load_curve_name = eff["part_load_curve"].to_s
    existing_curve = @standards_data['curves'].select { |curve| curve['name'] == part_load_curve_name }
    raise "No shw tank part load curve with the name #{part_load_curve_name} could be found in the ECMS class curves.json file.  Please check both the ECMS class curves.json and the measure shw_set.json files to ensure the curve is entered and referenced correctly." if existing_curve.empty?
    part_load_curve = model_add_curve(model, part_load_curve_name)
    raise "There was a problem setting the shw tank part load curve named #{part_load_curve_name} for #{component.name}.  Please ensure that the curve is entered and referenced correctly in the ECMS class curves.json and shw_set.json files." unless part_load_curve
    component.setPartLoadFactorCurve(part_load_curve)
    #Get the volume and capacity of the SHW tank.
    if component.isTankVolumeAutosized
      shw_vol_gal = "auto_size"
    else
      shw_vol_m3 = component.tankVolume.to_f
      shw_vol_gal = (OpenStudio.convert(shw_vol_m3, 'm^3', 'gal').get).to_f.round(0)
    end
    if component.isHeaterMaximumCapacityAutosized
      shw_capacity_kBtu_hr = "auto_cap"
    else
      shw_capacity_W = component.heaterMaximumCapacity.to_f
      shw_capacity_kBtu_hr = (OpenStudio.convert(shw_capacity_W, 'W', 'kBtu/h').get).to_f.round(0)
    end
    # Set a default revised shw tank name if no name is present in the eff hash.
    if eff["name"].nil?
      shw_ecm_package_name = "Revised"
    else
      shw_ecm_package_name = eff["name"]
    end
    shw_name = "#{shw_vol_gal} Gal #{shw_ecm_package_name} Water Heater - #{shw_capacity_kBtu_hr}kBtu/hr #{eff["efficiency"]} Therm Eff"
    component.setName(shw_name)
  end

  # ============================================================================================================================
  # Method to update the cop and/or the performance curves of unitary dx coils. The method input 'unitary_cop' can either be a
  # string or a hash. When it's a string it's used to find a hash in the json table 'unitary_cop_ecm'. When it's a hash it holds
  # the parameters needed to update the cop and/or the performance curves of the unitary coil.
  def modify_unitary_cop(model:, unitary_cop:,sql_db_vars_map:)
    return if (unitary_cop.nil? || (unitary_cop.to_s == "NECB_Default"))
    coils = model.getCoilCoolingDXSingleSpeeds + model.getCoilCoolingDXMultiSpeeds
    unitary_cop_copy = unitary_cop.dup
    coils.sort.each do |coil|
      coil_type = "SingleSpeed"
      coil_type = "MultiSpeed" if coil.class.name.to_s.include? 'CoilCoolingDXMultiSpeed'
      # if the parameter 'unitary_cop' is a string then get the information on the new parameters for the coils from
      # the json table 'unitary_cop_ecm'
      if unitary_cop_copy.is_a?(String)
        search_criteria = {}
        search_criteria['name'] = unitary_cop_copy
        coil_name = coil.name.to_s
        coil.setName(sql_db_vars_map[coil_name])
        if coil_type == "SingleSpeed"
          capacity_w = coil_cooling_dx_single_speed_find_capacity(coil)
        elsif coil_type == "MultiSpeed"
          capacity_w = coil_cooling_dx_multi_speed_find_capacity(coil)
        end
        coil.setName(coil_name)
        cop_package = model_find_object(@standards_data['tables']['unitary_cop_ecm'], search_criteria, capacity_w)

        raise "Cannot not find #{unitary_cop_ecm} in the ECMS unitary_acs.json file.  Please check that the name is correctly spelled in the ECMS class unitary_acs.json file and in the code calling (directly or through another method) the ECMS class modify_unitary_eff method." if cop_package.empty?
        ecm_name = unitary_cop_copy
        unitary_cop = {
          "name" => ecm_name,
          "minimum_energy_efficiency_ratio" => cop_package['minimum_energy_efficiency_ratio'],
          "minimum_seasonal_energy_efficiency_ratio" => cop_package['minimum_seasonal_energy_efficiency_ratio'],
          "cool_cap_ft" => cop_package['cool_cap_ft'],
          "cool_cap_fflow" => cop_package['cool_cap_fflow'],
          "cool_eir_ft" => cop_package['cool_eir_ft'],
          "cool_eir_fflow" => cop_package['cool_eir_fflow'],
          "cool_plf_fplr" => cop_package['cool_eir_fplr']
        }
      end
      next if (unitary_cop['minimum_energy_efficiency_ratio'].nil? && unitary_cop['minimum_seasonal_energy_efficiency_ratio'].nil? && unitary_cop['cool_cap_ft'].nil? &&
          unitary_cop['cool_cap_fflow'].nil? && unitary_cop['cool_eir_ft'].nil? && unitary_cop['cool_eir_fflow'].nil? && unitary_cop['cool_plf_fplr'].nil?)

      # If the dx coil is on an air loop then update its cop and the performance curves when these are specified in the ecm data
      if (coil_type == "SingleSpeed" && coil.airLoopHVAC.is_initialized) ||
          (coil_type == "MultiSpeed" && coil.containingHVACComponent.get.airLoopHVAC.is_initialized)
        cop = nil
        if unitary_cop['minimum_energy_efficiency_ratio']
          cop = eer_to_cop(unitary_cop['minimum_energy_efficiency_ratio'].to_f)
        elsif unitary_cop['minimum_seasonal_energy_efficiency_ratio']
          cop = seer_to_cop_cooling_with_fan(unitary_cop['minimum_seasonal_energy_efficiency_ratio'].to_f)
        end
        cool_cap_ft = nil
        cool_cap_ft = @standards_data['curves'].select { |curve| curve['name'] == unitary_cop['cool_cap_ft'] } if unitary_cop['cool_cap_ft']
        cool_cap_fflow = nil
        cool_cap_fflow = @standards_data['curves'].select { |curve| curve['name'] == unitary_cop['cool_cap_fflow'] } if unitary_cop['cool_cap_fflow']
        cool_eir_ft = nil
        cool_eir_ft = @standards_data['curves'].select { |curve| curve['name'] == unitary_cop['cool_eir_ft'] } if unitary_cop['cool_eir_ft']
        cool_eir_fflow = nil
        cool_eir_fflow = @standards_data['curves'].select { |curve| curve['name'] == unitary_cop['cool_eir_fflow'] } if unitary_cop['cool_eir_fflow']
        cool_plf_fplr = nil
        cool_plf_fplr = @standards_data['curves'].select { |curve| curve['name'] == unitary_cop['cool_plf_fplr'] } if unitary_cop['cool_plf_fplr']
        if coil_type == "SingleSpeed"
          coil.setRatedCOP(cop) if cop
          coil.setTotalCoolingCapacityFunctionOfTemperatureCurve(cool_cap_ft) if cool_cap_ft
          coil.setTotalCoolingCapacityFunctionOfFlowFractionCurve(cool_cap_fflow) if cool_cap_fflow
          coil.setEnergyInputRatioFunctionOfTemperatureCurve(cool_eir_ft) if cool_eir_ft
          coil.setEnergyInputRatioFunctionOfFlowFractionCurve(cool_eir_fflow) if cool_eir_fflow
          coil.setPartLoadFractionCorrelationCurve(cool_plf_fplr) if cool_plf_fplr
        elsif coil_type == "MultiSpeed"
          coil.stages.sort.each do |stage|
            stage.setGrossRatedCoolingCOP(cop) if cop
            stage.setTotalCoolingCapacityFunctionofTemperatureCurve(cool_cap_ft) if cool_cap_ft
            stage.setTotalCoolingCapacityFunctionofFlowFractionCurve(cool_cap_fflow) if cool_cap_fflow
            stage.setEnergyInputRatioFunctionofTemperatureCurve(cool_eir_ft) if cool_eir_ft
            stage.setEnergyInputRatioFunctionofFlowFractionCurve(cool_eir_fflow) if cool_eir_fflow
            stage.setPartLoadFractionCorrelationCurve(cool_plf_fplr) if cool_plf_fplr
          end
        end
        coil.setName("CoilCoolingDXSingleSpeed_dx-adv") if (cop && coil_type == "SingleSpeed")
        coil.setName("CoilCoolingDXMultiSpeed_dx-adv") if (cop && coil_type == "MultiSpeed")
      end
    end
  end

  # ============================================================================================================================
  # Despite the name, this method does not actually remove any air loops.  All air loops, hot water loops, cooling and
  # any existing baseboard heaters should already be gone.  The name is an artifact of the way ECM methods are named and
  # used.  With everything gone, this method adds a hot water loop (if required) and baseboard heating back in to all
  # zones requiring heating.  Originally, code was included in the 'apply_systems' method which would prevent the air
  # loops and other stuff from being created if someone did not want them.  But others felt that that was not a clear
  # way of doing things and did not feel the performance penalty of creating objects, then removing them, then creating
  # them again was significant.
  def add_ecm_remove_airloops_add_zone_baseboards(model:,
                                                  system_zones_map:,
                                                  system_doas_flags: nil,
                                                  zone_clg_eqpt_type: nil,
                                                  standard:,
                                                  primary_heating_fuel:)
    # Set the primary fuel set to default to to specific fuel type.
    standards_info = standard.standards_data

    if primary_heating_fuel == 'DefaultFuel'
      epw = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get)
      primary_heating_fuel = standards_info['regional_fuel_use'].detect {|fuel_sources| fuel_sources['state_province_regions'].include?(epw.state_province_region)}['fueltype_set']
    end
    # Get fuelset.
    system_fuel_defaults = standards_info['fuel_type_sets'].detect {|fuel_type_set| fuel_type_set['name'] == primary_heating_fuel}
    raise("fuel_type_sets named #{primary_heating_fuel} not found in fuel_type_sets table.") if system_fuel_defaults.nil?


    # Assign fuel sources.
    boiler_fueltype = system_fuel_defaults['boiler_fueltype']
    baseboard_type = system_fuel_defaults['baseboard_type']
    mau_heating_coil_type = "none"

    # Create the hot water loop if necessary.
    hw_loop = standard.create_hw_loop_if_required(baseboard_type,
                                          boiler_fueltype,
                                          mau_heating_coil_type,
                                          model)

    # Add baseboard heaters to each heated zone.
    system_zones_map.sort.each do |sname,zones|
      zones.each do |zone|
        standard.add_zone_baseboards(baseboard_type: baseboard_type,
                                     hw_loop: hw_loop,
                                     model: model,
                                     zone: zone)
      end
    end
  end

  # ============================================================================================================================
  # Apply advanced chiller measure
  def modify_chiller_efficiency(model:, chiller_type:)
    return if chiller_type.nil? || chiller_type == false || chiller_type == 'none' || chiller_type == 'NECB_Default'

    model.getChillerElectricEIRs.sort.each do |mod_chiller|
      ref_capacity_w = mod_chiller.referenceCapacity
      ref_capacity_w = ref_capacity_w.to_f

      ##### Look for a chiller set in chiller_set.json (with a capacity close to that of the existing chiller)
      chiller_set, chiller_min_cap, chiller_max_cap = find_chiller_set(chiller_type: chiller_type, ref_capacity_w: ref_capacity_w)

      ##### No need to replace any chillers with capacity = 0.001 W as per Kamel Haddad's comment
      if ref_capacity_w > 0.0011
        reset_chiller_efficiency(model: model, component: mod_chiller.to_ChillerElectricEIR.get, cop: chiller_set)
      end
    end

    ##### Change fan power of single-speed Cooling towers from 'Hard Sized' to Autosized (Otherwise, E+ gives the fatal error 'Autosizing of cooling tower UA failed for tower')
    model.getCoolingTowerSingleSpeeds.sort.each do |cooling_tower_single_speed|
      cooling_tower_single_speed.autosizeFanPoweratDesignAirFlowRate()
    end

  end

  def find_chiller_set(chiller_type:, ref_capacity_w:)
    if chiller_type.is_a?(String)

      ##### Find the chiller that has the required capacity
      search_criteria = {}
      search_criteria['name'] = chiller_type
      capacity_w = ref_capacity_w
      chiller_packages = model_find_object(@standards_data['tables']['chiller_eff_ecm'], search_criteria, capacity_w)
      chiller_name = chiller_packages['notes']
      ecm_name = chiller_name
      chiller_set = {
          "notes" => ecm_name,
          "capacity_w" => chiller_packages['capacity_w'],
          "cop_w_by_w" => chiller_packages['cop_w_by_w'],
          "ref_leaving_chilled_water_temp_c" => chiller_packages['ref_leaving_chilled_water_temp_c'],
          "ref_entering_condenser_fluid_temp_c" => chiller_packages['ref_entering_condenser_fluid_temp_c'],
          "ref_chilled_water_flow_rate_m3_s" => chiller_packages['ref_chilled_water_flow_rate_m3_s'],
          "ref_condenser_fluid_flow_rate_m3_s" => chiller_packages['ref_condenser_fluid_flow_rate_m3_s'],
          "capft_curve" => chiller_packages['capft_curve'],
          "eirft_curve" => chiller_packages['eirft_curve'],
          "eirfplr_curve" => chiller_packages['eirfplr_curve'],
          "min_part_load_ratio" => chiller_packages['min_part_load_ratio'],
          "max_part_load_ratio" => chiller_packages['max_part_load_ratio'],
          "opt_part_load_ratio" => chiller_packages['opt_part_load_ratio'],
          "min_unloading_ratio" => chiller_packages['min_unloading_ratio'],
          "condenser_type" => chiller_packages['condenser_type'],
          "fraction_of_compressor_electric_consumption_rejected_by_condenser" => chiller_packages['fraction_of_compressor_electric_consumption_rejected_by_condenser'],
          "leaving_chilled_water_lower_temperature_limit_c" => chiller_packages['leaving_chilled_water_lower_temperature_limit_c'],
          "chiller_flow_mode" => chiller_packages['chiller_flow_mode'],
          "design_heat_recovery_water_flow_rate_m3_s" => chiller_packages['design_heat_recovery_water_flow_rate_m3_s'],
      }
      chiller_min_cap = chiller_packages['minimum_capacity']
      chiller_max_cap = chiller_packages['maximum_capacity']
    end

    return chiller_set, chiller_min_cap, chiller_max_cap
  end

  # ============================================================================================================================
  def reset_chiller_efficiency(model:, component:, cop:)
    # Note that all parameters (except for the capacity) of an existing chiller are replaced with the ones of the VSD chiller, as per Kamel Haddad's comment.
    component.setName('ChillerElectricEIR_VSDCentrifugalWaterChiller')
    component.setReferenceCOP(cop['cop_w_by_w'])
    component.setReferenceLeavingChilledWaterTemperature(cop['ref_leaving_chilled_water_temp_c'])
    component.setReferenceEnteringCondenserFluidTemperature(cop['ref_entering_condenser_fluid_temp_c'])
    component.setReferenceChilledWaterFlowRate(cop['ref_chilled_water_flow_rate_m3_s'])
    component.setReferenceCondenserFluidFlowRate(cop['ref_condenser_fluid_flow_rate_m3_s'])
    component.setMinimumPartLoadRatio(cop['min_part_load_ratio'])
    component.setMaximumPartLoadRatio(cop['max_part_load_ratio'])
    component.setOptimumPartLoadRatio(cop['opt_part_load_ratio'])
    component.setMinimumUnloadingRatio(cop['min_unloading_ratio'])
    component.setCondenserType(cop['condenser_type'])
    component.setFractionofCompressorElectricConsumptionRejectedbyCondenser(cop['fraction_of_compressor_electric_consumption_rejected_by_condenser'])
    component.setLeavingChilledWaterLowerTemperatureLimit(cop['leaving_chilled_water_lower_temperature_limit_c'])
    component.setChillerFlowMode(cop['chiller_flow_mode'])
    component.setDesignHeatRecoveryWaterFlowRate(cop['design_heat_recovery_water_flow_rate_m3_s'])

    # set other fields of this object to nothing #Note that this could not be done for the 'Condenser Heat Recovery Relative Capacity Fraction' field as there is no 'reset' for this field.
    component.resetCondenserFanPowerRatio()
    component.resetSizingFactor()
    component.resetBasinHeaterCapacity()
    component.resetBasinHeaterSetpointTemperature()
    component.resetBasinHeaterSchedule
    component.resetHeatRecoveryInletHighTemperatureLimitSchedule
    component.resetHeatRecoveryLeavingTemperatureSetpointNode

    ##### Replace cooling_capacity_function_of_temperature (CAPFT) curve
    capft_curve_name = cop['capft_curve'].to_s
    existing_curve = @standards_data['curves'].select { |curve| curve['name'] == capft_curve_name }
    raise "No chiller with the name #{capft_curve_name} could be found in the ECMS class curves.json file.  Please check both the ECMS class chiller_set.json and curves.json files to ensure the curve is entered and referenced correctly." if existing_curve.empty?
    capft_curve_data = (@standards_data['curves'].select { |curve| curve['name'] == capft_curve_name })[0]
    capft_curve = model_add_curve(model, capft_curve_name)
    if capft_curve
      component.setCoolingCapacityFunctionOfTemperature(capft_curve)
    else
      raise "There was a problem setting the CoolingCapacityFunctionOfTemperature curve named #{capft_curve_name} for #{component.name}.  Please ensure that the curve is entered and referenced correctly in the ECMS class curves.json and chiller_set.json files."
    end

    ##### Replace electric_input_to_cooling_output_ratio_function_of_temperature (EIRFT) curve
    eirft_curve_name = cop['eirft_curve'].to_s
    existing_curve = @standards_data['curves'].select { |curve| curve['name'] == eirft_curve_name }
    raise "No chiller with the name #{eirft_curve_name} could be found in the ECMS class curves.json file.  Please check both the ECMS class chiller_set.json and curves.json files to ensure the curve is entered and referenced correctly." if existing_curve.empty?
    eirft_curve_data = (@standards_data['curves'].select { |curve| curve['name'] == eirft_curve_name })[0]
    eirft_curve = model_add_curve(model, eirft_curve_name)
    if eirft_curve
      component.setElectricInputToCoolingOutputRatioFunctionOfTemperature(eirft_curve)
    else
      raise "There was a problem setting the ElectricInputToCoolingOutputRatioFunctionOfTemperature curve named #{eirft_curve_name} for #{component.name}.  Please ensure that the curve is entered and referenced correctly in the ECMS class curves.json and chiller_set.json files."
    end

    ##### Replace electric_input_to_cooling_output_ratio_function_of_part_load_ratio (EIRFPLR) curve
    eirfplr_curve_name = cop['eirfplr_curve'].to_s
    existing_curve = @standards_data['curves'].select { |curve| curve['name'] == eirfplr_curve_name }
    raise "No chiller with the name #{eirfplr_curve_name} could be found in the ECMS class curves.json file.  Please check both the ECMS class chiller_set.json and curves.json files to ensure the curve is entered and referenced correctly." if existing_curve.empty?
    eirfplr_curve_data = (@standards_data['curves'].select { |curve| curve['name'] == eirfplr_curve_name })[0]
    eirfplr_curve = model_add_curve(model, eirfplr_curve_name)
    if eirfplr_curve
      component.setElectricInputToCoolingOutputRatioFunctionOfPLR(eirfplr_curve)
    else
      raise "There was a problem setting the ElectricInputToCoolingOutputRatioFunctionOfPLR curve named #{eirfplr_curve_name} for #{component.name}.  Please ensure that the curve is entered and referenced correctly in the ECMS class curves.json and chiller_set.json files."
    end

  end

end

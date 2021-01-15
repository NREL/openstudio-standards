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
  def add_outdoor_vrf_unit(model:,ecm_name: nil,condenser_type: "AirCooled")
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
    outdoor_vrf_unit.setCrankcaseHeaterPowerperCompressor(0.001)
    heat_defrost_eir_ft = nil
    if ecm_name
      search_criteria = coil_dx_find_search_criteria(outdoor_vrf_unit)
      props =  model_find_object(standards_data['tables']["heat_pumps_heating_ecm_#{ecm_name.downcase}"]['table'], search_criteria, 1.0, Date.today)
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
  # Add indoor VRF units and update horizontal and vertical pipe runs for outdoor VRF unit
  def add_indoor_vrf_units(model:,system_zones_map:,outdoor_vrf_unit:)
    always_on = model.alwaysOnDiscreteSchedule
    always_off = model.alwaysOffDiscreteSchedule
    system_zones_map.sort.each do |sname,zones|
      zones.sort.each do |izone|
        zone_vrf_fan = OpenStudio::Model::FanOnOff.new(model, always_on)
        zone_vrf_fan.setName("#{izone.name} VRF Fan")
        zone_vrf_clg_coil = OpenStudio::Model::CoilCoolingDXVariableRefrigerantFlow.new(model)
        zone_vrf_clg_coil.setName("#{izone.name} VRF Clg Coil")
        zone_vrf_htg_coil = OpenStudio::Model::CoilHeatingDXVariableRefrigerantFlow.new(model)
        zone_vrf_htg_coil.setName("#{izone.name} VRF Htg Coil")
        zone_vrf_unit = OpenStudio::Model::ZoneHVACTerminalUnitVariableRefrigerantFlow.new(model,zone_vrf_clg_coil,zone_vrf_htg_coil,zone_vrf_fan)
        zone_vrf_unit.setName("#{izone.name} VRF Indoor Unit")
        zone_vrf_unit.setOutdoorAirFlowRateDuringCoolingOperation(0.000001)
        zone_vrf_unit.setOutdoorAirFlowRateDuringHeatingOperation(0.000001)
        zone_vrf_unit.setOutdoorAirFlowRateWhenNoCoolingorHeatingisNeeded(0.000001)
        zone_vrf_unit.setZoneTerminalUnitOffParasiticElectricEnergyUse(0.000001)
        zone_vrf_unit.setZoneTerminalUnitOnParasiticElectricEnergyUse(0.000001)
        zone_vrf_unit.setSupplyAirFanOperatingModeSchedule(always_off)
        zone_vrf_unit.setRatedTotalHeatingCapacitySizingRatio(1.3)
        zone_vrf_unit.addToThermalZone(izone)
        outdoor_vrf_unit.addTerminal(zone_vrf_unit)
        # VRF terminal unit does not have a backup coil, use a unit heater as backup coil
        zone_unitheater_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on) # OS does not support an OnOff fan for unit heaters
        zone_unitheater_fan.setName("#{izone.name} Unit Heater Fan")
        zone_unitheater_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
        zone_unitheater_htg_coil.setName("#{izone.name} Unit Heater Htg Coil")
        zone_unit_heater = OpenStudio::Model::ZoneHVACUnitHeater.new(model,always_on,zone_unitheater_fan,zone_unitheater_htg_coil)
        zone_unit_heater.setName("#{izone.name} Unit Heater")
        zone_unit_heater.setFanControlType("OnOff")
        zone_unit_heater.addToThermalZone(izone)
      end
    end
    # Now we can find and apply maximum horizontal and vertical distances between outdoor vrf unit and zones with vrf terminal units
    max_hor_pipe_length,max_vert_pipe_length = get_max_vrf_pipe_lengths(model)
    #raise("test1:#{max_hor_pipe_length},#{max_vert_pipe_length}")
    outdoor_vrf_unit.setEquivalentPipingLengthusedforPipingCorrectionFactorinCoolingMode(max_hor_pipe_length)
    outdoor_vrf_unit.setEquivalentPipingLengthusedforPipingCorrectionFactorinHeatingMode(max_hor_pipe_length)
    outdoor_vrf_unit.setVerticalHeightusedforPipingCorrectionFactor(max_vert_pipe_length)
  end

  # =============================================================================================================================
  # Add a dedicated outside air loop with cold-climate heat pump with electric backup
  # Add cold-climate zonal terminal VRF units
  def add_ecm_hs08_vrfzonal(model:,system_zones_map:,system_doas_flags:,zone_clg_eqpt_type:, standard:)
    # Update system doas flags
    system_doas_flags.keys.each {|sname| system_doas_flags[sname] = true}
    # Add doas with cold-climate air-source heat pump and electric backup
    add_ecm_hs09_ccashpsys(model: model,system_zones_map: system_zones_map,system_doas_flags: system_doas_flags,standard: standard,baseboard_flag: false)
    # Add outdoor VRF unit
    outdoor_vrf_unit = add_outdoor_vrf_unit(model: model,ecm_name: "hs08_vrfzonal")
    # Add indoor VRF terminal units
    add_indoor_vrf_units(model: model,system_zones_map: system_zones_map,outdoor_vrf_unit: outdoor_vrf_unit)
  end

  # =============================================================================================================================
  # Apply efficiencies and performance curves for ECM 'hs08_vrfzonal'
  def apply_efficiency_ecm_hs08_vrfzonal(model:,ecm_name:)
    # Use same performance data as ECM "hs09_ccashpsys" for air system
    apply_efficiency_ecm_hs09_ccashpsys(model: model,ecm_name: "hs09_ccashpsys")
    # Apply efficiency and curves for VRF units
    model.getAirConditionerVariableRefrigerantFlows.sort.each do |vrf_unit|
      airconditioner_variablerefrigerantflow_cooling_apply_efficiency_and_curves(vrf_unit,ecm_name)
      airconditioner_variablerefrigerantflow_heating_apply_efficiency_and_curves(vrf_unit,ecm_name)
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
  # Add air loops with cold-climate heat pump with electric backup coil.
  # Add zone electric baseboards
  def add_ecm_hs09_ccashpsys(model:,system_zones_map:,system_doas_flags:,zone_clg_eqpt_type: nil,standard:,baseboard_flag: true)
    always_on = model.alwaysOnDiscreteSchedule
    always_off = model.alwaysOffDiscreteSchedule
    systems = []
    system_zones_map.sort.each do |sys_name,zones|
      system_data = {}
      system_data[:PreheatDesignTemperature] = 7.0
      system_data[:PreheatDesignHumidityRatio] = 0.008
      system_data[:PrecoolDesignTemperature] = 13.0
      system_data[:PrecoolDesignHumidityRatio] = 0.008
      system_data[:SizingOption] = 'NonCoincident'
      system_data[:CoolingDesignAirFlowMethod] = 'DesignDay'
      system_data[:CoolingDesignAirFlowRate] = 0.0
      system_data[:HeatingDesignAirFlowMethod] = 'DesignDay'
      system_data[:HeatingDesignAirFlowRate] = 0.0
      system_data[:SystemOutdoorAirMethod] = 'ZoneSum'
      system_data[:CentralCoolingDesignSupplyAirHumidityRatio] = 0.0085
      system_data[:CentralHeatingDesignSupplyAirHumidityRatio] = 0.0080
      system_data[:MinimumSystemAirFlowRatio] = 1.0
      system_data[:system_supply_air_temperature] = 20.0
      system_data[:ZoneCoolingDesignSupplyAirTemperature] = 13.0
      system_data[:ZoneHeatingDesignSupplyAirTemperature] = 43.0
      system_data[:ZoneCoolingSizingFactor] = 1.1
      system_data[:ZoneHeatingSizingFactor] = 1.3
      if system_doas_flags[sys_name.to_s]
        system_data[:name] = sys_name.to_s
        system_data[:AllOutdoorAirinCooling] = true
        system_data[:AllOutdoorAirinHeating] = true
        system_data[:TypeofLoadtoSizeOn] = 'VentilationRequirement'
        system_data[:CentralCoolingDesignSupplyAirTemperature] = 19.9
        system_data[:CentralHeatingDesignSupplyAirTemperature] = 20.0
        sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        sat_sch.setName('Makeup-Air Unit Supply Air Temp')
        sat_sch.defaultDaySchedule.setName('Makeup Air Unit Supply Air Temp Default')
        sat_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), system_data[:system_supply_air_temperature])
        setpoint_mgr = OpenStudio::Model::SetpointManagerScheduled.new(model, sat_sch)
      else
        system_data[:name] = sys_name.to_s
        system_data[:AllOutdoorAirinCooling] = false
        system_data[:AllOutdoorAirinHeating] = false
        system_data[:TypeofLoadtoSizeOn] = 'Sensible'
        system_data[:CentralCoolingDesignSupplyAirTemperature] = 13.0
        system_data[:CentralHeatingDesignSupplyAirTemperature] = 43.0
        if zones.size == 1
          setpoint_mgr = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
          setpoint_mgr.setControlZone(zones[0])
          setpoint_mgr.setMinimumSupplyAirTemperature(13.0)
          setpoint_mgr.setMaximumSupplyAirTemperature(43.0)
        else
          setpoint_mgr = OpenStudio::Model::SetpointManagerWarmest.new(model)
          setpoint_mgr.setMinimumSetpointTemperature(13.0)
          setpoint_mgr.setMaximumSetpointTemperature(43.0)
        end
      end
      airloop = standard.common_air_loop(model: model, system_data: system_data)
      # Fan
      if system_doas_flags[sys_name.to_s] || zones.size == 1
        sys_supply_fan = OpenStudio::Model::FanConstantVolume.new(model)
      else
        sys_supply_fan = OpenStudio::Model::FanVariableVolume.new(model)
        sys_return_fan = OpenStudio::Model::FanVariableVolume.new(model)
        sys_return_fan.setName("System Return Fan")
      end
      sys_supply_fan.setName("System Supply Fan")
      # Cooling coil
      sys_clg_coil = OpenStudio::Model::CoilCoolingDXVariableSpeed.new(model)
      sys_clg_coil.setName("CoilCoolingDXVariableSpeed_CCASHP")
      sys_clg_coil_speeddata1 = OpenStudio::Model::CoilCoolingDXVariableSpeedSpeedData.new(model)
      sys_clg_coil.addSpeed(sys_clg_coil_speeddata1)
      sys_clg_coil.setNominalSpeedLevel(1)
      # Electric supplemental heating coil
      sys_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
      sys_elec_htg_coil.setName("CoilHeatingElectric")
      # DX heating coil
      sys_dx_htg_coil = OpenStudio::Model::CoilHeatingDXVariableSpeed.new(model)
      sys_dx_htg_coil.setName("CoilHeatingDXVariableSpeed_CCASHP")
      sys_dx_htg_coil_speed1 = OpenStudio::Model::CoilHeatingDXVariableSpeedSpeedData.new(model)
      sys_dx_htg_coil.addSpeed(sys_dx_htg_coil_speed1)
      sys_dx_htg_coil.setNominalSpeedLevel(1)
      sys_dx_htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(-25.0)
      sys_dx_htg_coil.setDefrostStrategy("ReverseCycle")
      #sys_dx_htg_coil.setDefrostStrategy("Resistive")
      #sys_dx_htg_coil.setResistiveDefrostHeaterCapacity(0.001)
      sys_dx_htg_coil.setDefrostControl("OnDemand")
      sys_dx_htg_coil.setCrankcaseHeaterCapacity(0.001)
      search_criteria = coil_dx_find_search_criteria(sys_dx_htg_coil)
      props =  model_find_object(standards_data['tables']["heat_pumps_heating_ecm_hs09_ccashpsys"]['table'], search_criteria, 1.0, Date.today)
      heat_defrost_eir_ft = model_add_curve(model, props['heat_defrost_eir_ft'])
      # This defrost curve has to be assigned here before sizing
      if heat_defrost_eir_ft
        sys_dx_htg_coil.setDefrostEnergyInputRatioFunctionofTemperatureCurve(heat_defrost_eir_ft)
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{sys_dx_htg_coil.name}, cannot find heat_defrost_eir_ft curve, will not be set.")
      end
      sys_clg_coil.addToNode(airloop.supplyOutletNode)
      sys_dx_htg_coil.addToNode(airloop.supplyOutletNode)
      sys_elec_htg_coil.addToNode(airloop.supplyOutletNode)
      sys_supply_fan.addToNode(airloop.supplyOutletNode)
      setpoint_mgr.addToNode(airloop.supplyOutletNode)
      # OA controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      oa_controller.autosizeMinimumOutdoorAirFlowRate
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)
      oa_system.addToNode(airloop.supplyInletNode)
      zones.each do |zone|
        zone.sizingZone.setZoneCoolingDesignSupplyAirTemperature(13.0)
        zone.sizingZone.setZoneHeatingDesignSupplyAirTemperature(43.0)
        zone.sizingZone.setZoneCoolingSizingFactor(1.1)
        zone.sizingZone.setZoneHeatingSizingFactor(1.3)
        if zone_clg_eqpt_type
          case zone_clg_eqpt_type[zone.name.to_s]
          when "ZoneHVACPackagedTerminalAirConditioner"
            standard.add_ptac_dx_cooling(model,zone,true)
          end
        end
        if system_doas_flags[sys_name.to_s] || zones.size == 1
          diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
        else
          reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          diffuser = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, always_on, reheat_coil)
          sys_return_fan.addToNode(airloop.returnAirNode.get)
          diffuser.setFixedMinimumAirFlowRate(0.002 * zone.floorArea )
          diffuser.setMaximumReheatAirTemperature(43.0)
          diffuser.setDamperHeatingAction('Normal')
        end
        airloop.removeBranchForZone(zone)
        airloop.addBranchForZone(zone, diffuser.to_StraightComponent)
        if baseboard_flag then standard.add_zone_baseboards(baseboard_type: 'Electric', hw_loop: nil, model: model, zone: zone) end
      end
      update_sys_name(airloop,
                      sys_abbr: nil,
                      sys_oa: nil,
                      sys_hr: nil,
                      sys_htg: "ccashp",
                      sys_clg: "ccashp",
                      sys_sf: nil,
                      zone_htg: "b-e",
                      zone_clg: "none",
                      sys_rf: nil)
      systems << airloop
    end

    return systems
  end

  # =============================================================================================================================
  # Apply efficiencies and performance curves for ECM 'hs09_ccashpsys'
  def apply_efficiency_ecm_hs09_ccashpsys(model:,ecm_name:)
    # fraction of electric backup heating coil capacity assigned to dx heating coil
    fr_backup_coil_cap_as_dx_coil_cap = 0.5
    model.getAirLoopHVACs.each do |isys|
      clg_dx_coil = nil
      htg_dx_coil = nil
      backup_coil = nil
      fans = []
      # Find the components on the air loop
      isys.supplyComponents.each do |icomp|
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
        clg_dx_coil_cap = clg_dx_coil.autosizedGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel.to_f
        htg_dx_coil_cap = htg_dx_coil.autosizedRatedHeatingCapacityAtSelectedNominalSpeedLevel.to_f
        backup_coil_cap = backup_coil.autosizedNominalCapacity.to_f
        fan_power = 0.0
        fans.each do |ifan|
          fan_power += ifan.pressureRise.to_f*ifan.autosizedMaximumFlowRate.to_f/ifan.fanEfficiency.to_f
        end
        # Set the DX capacities to the maximum of the fraction of the backup coil capacity or the cooling capacity needed
        dx_cap = fr_backup_coil_cap_as_dx_coil_cap*backup_coil_cap
        if dx_cap < (clg_dx_coil_cap+fan_power) then dx_cap = clg_dx_coil_cap+fan_power end
        clg_dx_coil.setGrossRatedTotalCoolingCapacityAtSelectedNominalSpeedLevel(dx_cap)
        htg_dx_coil.setRatedHeatingCapacityAtSelectedNominalSpeedLevel(dx_cap)
      end
    end
    # Assign performance curves and COPs
    model.getCoilCoolingDXVariableSpeeds.sort.each {|coil| coil_cooling_dx_variable_speed_apply_efficiency_and_curves(coil,ecm_name)}
    model.getCoilHeatingDXVariableSpeeds.sort.each {|coil| coil_heating_dx_variable_speed_apply_efficiency_and_curves(coil,ecm_name)}
  end

  # =============================================================================================================================
  # Applies the standard efficiency ratings and typical performance curves "CoilCoolingDXVariableSpeed" object.
  def coil_cooling_dx_variable_speed_apply_efficiency_and_curves(coil_cooling_dx_variable_speed,ecm_name)
    successfully_set_all_properties = true

    # Get the search criteria
    search_criteria = coil_dx_find_search_criteria(coil_cooling_dx_variable_speed)

    # Get the capacity
    capacity_w = coil_cooling_dx_variable_speed_find_capacity(coil_cooling_dx_variable_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props =  if coil_dx_heat_pump?(coil_cooling_dx_variable_speed)
                  model_find_object(standards_data['tables']["heat_pumps_ecm_#{ecm_name.downcase}"]['table'], search_criteria, capacity_btu_per_hr, Date.today)
                else
                  model_find_object(standards_data['tables']["unitary_acs_ecm_#{ecm_name.downcase}"]['table'], search_criteria, capacity_btu_per_hr, Date.today)
                end

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
    cop = coil_cooling_dx_variable_speed_standard_minimum_cop(coil_cooling_dx_variable_speed, true,ecm_name)

    # Set the efficiency values
    unless cop.nil?
      coil_cooling_dx_variable_speed.speeds.each {|speed| speed.setReferenceUnitGrossRatedCoolingCOP(cop.to_f)}
    end

  end

  # =============================================================================================================================
  # Applies the standard efficiency ratings and typical performance curves to "CoilHeatingVariableSpeed" object.
  def coil_heating_dx_variable_speed_apply_efficiency_and_curves(coil_heating_dx_variable_speed,ecm_name)
    successfully_set_all_properties = true

    # Get the search criteria
    search_criteria = coil_dx_find_search_criteria(coil_heating_dx_variable_speed)

    # Get the capacity
    capacity_w = coil_heating_dx_variable_speed_find_capacity(coil_heating_dx_variable_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies
    props =  model_find_object(standards_data['tables']["heat_pumps_heating_ecm_#{ecm_name.downcase}"]['table'], search_criteria, capacity_btu_per_hr, Date.today)

    # Check to make sure properties were found
    if props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{coil_heating_dx_single_speed.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
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
    cop = coil_heating_dx_variable_speed_standard_minimum_cop(coil_heating_dx_variable_speed, true,ecm_name)

    # Set the efficiency values
    unless cop.nil?
      coil_heating_dx_variable_speed.speeds.each {|speed| speed.setReferenceUnitGrossRatedHeatingCOP(cop.to_f)}
    end

  end

  # =============================================================================================================================
  # Applies the standard cooling efficiency ratings and typical performance curves to "AirConditionerVariableRefrigerantFlow" object.
  def airconditioner_variablerefrigerantflow_cooling_apply_efficiency_and_curves(airconditioner_variablerefrigerantflow,ecm_name)
    successfully_set_all_properties = true

    # Get the search criteria
    search_criteria = coil_dx_find_search_criteria(airconditioner_variablerefrigerantflow)

    # Get the capacity
    capacity_w = airconditioner_variablerefrigerantflow_cooling_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies
    props =  model_find_object(standards_data['tables']["heat_pumps_ecm_#{ecm_name.downcase}"]['table'], search_criteria, capacity_btu_per_hr, Date.today)

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
    cop = airconditioner_variablerefrigerantflow_cooling_standard_minimum_cop(airconditioner_variablerefrigerantflow, false, ecm_name)

    # Set the efficiency values
    unless cop.nil?
      airconditioner_variablerefrigerantflow.setRatedCoolingCOP(cop.to_f)
    end

  end

  # =============================================================================================================================
  # Applies the standard heating efficiency ratings and typical performance curves to "AirConditionerVariableRefrigerantFlow" object.
  def airconditioner_variablerefrigerantflow_heating_apply_efficiency_and_curves(airconditioner_variablerefrigerantflow,ecm_name)
    successfully_set_all_properties = true

    # Get the search criteria
    search_criteria = coil_dx_find_search_criteria(airconditioner_variablerefrigerantflow)

    # Get the capacity
    capacity_w = airconditioner_variablerefrigerantflow_heating_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies
    props =  model_find_object(standards_data['tables']["heat_pumps_heating_ecm_#{ecm_name.downcase}"]['table'], search_criteria, capacity_btu_per_hr, Date.today)

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
    cop = airconditioner_variablerefrigerantflow_heating_standard_minimum_cop(airconditioner_variablerefrigerantflow, true, ecm_name)

    # Set the efficiency values
    unless cop.nil?
      airconditioner_variablerefrigerantflow.setRatedHeatingCOP(cop.to_f)
    end

  end

  # =============================================================================================================================
  # Find minimum efficiency for "CoilCoolingDXVariableSpeed" object
  def coil_cooling_dx_variable_speed_standard_minimum_cop(coil_cooling_dx_variable_speed, rename = false,ecm_name)
    search_criteria = coil_dx_find_search_criteria(coil_cooling_dx_variable_speed)
    cooling_type = search_criteria['cooling_type']
    heating_type = search_criteria['heating_type']
    sub_category = search_criteria['subcategory']
    capacity_w = coil_cooling_dx_variable_speed_find_capacity(coil_cooling_dx_variable_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    ac_props = if coil_dx_heat_pump?(coil_cooling_dx_variable_speed)
                 model_find_object(standards_data['tables']["heat_pumps_ecm_#{ecm_name.downcase}"]['table'], search_criteria, capacity_btu_per_hr, Date.today)
               else
                 model_find_object(standards_data['tables']["unitary_acs_ecm_#{ecm_name.downcase}"]['table'], search_criteria, capacity_btu_per_hr, Date.today)
               end

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
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop_cooling_with_fan(min_seer)
      new_comp_name = "#{coil_cooling_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless ac_props['minimum_coefficient_of_performance_cooling'].nil?
      cop = ac_props['minimum_coefficient_of_performance_cooling']
      new_comp_name = "#{coil_cooling_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXVariableSpeed', "For #{template}: #{coil_cooling_dx_variable_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COP = #{cop}")
    end

    # Rename
    if rename
      coil_cooling_dx_variable_speed.setName(new_comp_name)
    end

    return cop
  end

  # =============================================================================================================================
  # Find minimum efficiency for "CoilHeatingDXVariableSingleSpeed" object
  def coil_heating_dx_variable_speed_standard_minimum_cop(coil_heating_dx_variable_speed, rename = false,ecm_name)
    search_criteria = coil_dx_find_search_criteria(coil_heating_dx_variable_speed)
    cooling_type = search_criteria['cooling_type']
    heating_type = search_criteria['heating_type']
    sub_category = search_criteria['subcategory']
    capacity_w = coil_heating_dx_variable_speed_find_capacity(coil_heating_dx_variable_speed)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    props = model_find_object(standards_data['tables']["heat_pumps_heating_ecm_#{ecm_name.downcase}"], search_criteria, capacity_btu_per_hr, Date.today)

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
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{template}: #{coil_heating_dx_variable_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as HSPF (heat pump)
    unless props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_heating_with_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}HSPF"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{template}: #{coil_heating_dx_variable_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless props['minimum_full_load_efficiency'].nil?
      min_eer = props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{template}: #{coil_heating_dx_variable_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless props['minimum_coefficient_of_performance_heating'].nil?
      cop = props['minimum_coefficient_of_performance_heating']
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingDXVariableSpeed', "For #{template}: #{coil_heating_dx_variable_speed.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Rename
    if rename
      coil_heating_dx_variable_speed.setName(new_comp_name)
    end

    return cop
  end

  # =============================================================================================================================
  # Find minimum cooling efficiency for "AirConditionerVariableRefrigerantFlow" object
  def airconditioner_variablerefrigerantflow_cooling_standard_minimum_cop(airconditioner_variablerefrigerantflow, rename = false, ecm_name)
    search_criteria = coil_dx_find_search_criteria(airconditioner_variablerefrigerantflow)
    cooling_type = search_criteria['cooling_type']
    heating_type = search_criteria['heating_type']
    sub_category = search_criteria['subcategory']
    capacity_w = airconditioner_variablerefrigerantflow_cooling_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    props = model_find_object(standards_data['tables']["heat_pumps_ecm_#{ecm_name.downcase}"], search_criteria, capacity_btu_per_hr, Date.today)

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
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as HSPF (heat pump)
    unless props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_heating_with_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}HSPF"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless props['minimum_full_load_efficiency'].nil?
      min_eer = props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless props['minimum_coefficient_of_performance_cooling'].nil?
      cop = props['minimum_coefficient_of_performance_cooling']
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # Rename
    if rename
      airconditioner_variablerefrigerantflow.setName(new_comp_name)
    end

    return cop
  end

  # =============================================================================================================================
  # Find minimum heating efficiency for "AirConditionerVariableRefrigerantFlow" object
  def airconditioner_variablerefrigerantflow_heating_standard_minimum_cop(airconditioner_variablerefrigerantflow, rename = false, ecm_name)
    search_criteria = coil_dx_find_search_criteria(airconditioner_variablerefrigerantflow)
    cooling_type = search_criteria['cooling_type']
    heating_type = search_criteria['heating_type']
    sub_category = search_criteria['subcategory']
    capacity_w = airconditioner_variablerefrigerantflow_heating_find_capacity(airconditioner_variablerefrigerantflow)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    props = model_find_object(standards_data['tables']["heat_pumps_heating_ecm_#{ecm_name.downcase}"], search_criteria, capacity_btu_per_hr, Date.today)

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
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as HSPF (heat pump)
    unless props['minimum_heating_seasonal_performance_factor'].nil?
      min_hspf = props['minimum_heating_seasonal_performance_factor']
      cop = hspf_to_cop_heating_with_fan(min_hspf)
      new_comp_name = "#{coil_heating_dx_variable_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}HSPF"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless props['minimum_full_load_efficiency'].nil?
      min_eer = props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # If specified as COP
    unless props['minimum_coefficient_of_performance_heating'].nil?
      cop = props['minimum_coefficient_of_performance_heating']
      new_comp_name = "#{airconditioner_variablerefrigerantflow.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{cop}COP"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirConditionerVariableRefrigerantFlow', "For #{template}: #{airconditioner_variablerefrigerantflow.name}: #{cooling_type} #{heating_type} #{sub_category} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
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
  def add_ecm_remove_airloops_add_zone_baseboards(model:,system_zones_map:, system_doas_flags: nil, zone_clg_eqpt_type: nil, standard:, primary_heating_fuel:)
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
end

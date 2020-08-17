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
        system_data[:name] = "CCASHP Makeup Air Unit"
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
        system_data[:name] = "CCASHP System"
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
      sys_clg_coil.setName("CCASHP DX Clg Coil")
      sys_clg_coil_speeddata1 = OpenStudio::Model::CoilCoolingDXVariableSpeedSpeedData.new(model)
      sys_clg_coil.addSpeed(sys_clg_coil_speeddata1)
      sys_clg_coil.setNominalSpeedLevel(1)
      # Electric supplemental heating coil
      sys_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
      sys_elec_htg_coil.setName("CCASHP Elec Htg Coil")
      # DX heating coil
      sys_dx_htg_coil = OpenStudio::Model::CoilHeatingDXVariableSpeed.new(model)
      sys_dx_htg_coil.setName("CCASHP DX Htg Coil")
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

end
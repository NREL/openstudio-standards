class NECB2011
  def model_add_hvac(model, epw_file)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    system_fuel_defaults = self.get_canadian_system_defaults_by_weatherfile_name(model)
    necb_autozone_and_autosystem(model, nil, false, system_fuel_defaults)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    return true
  end

  # NECB does not change damper positions
  #
  # return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_multizone_vav_outdoor_air_sizing(air_loop_hvac)
    # Do not change anything.
    return true
  end

  # Determine whether or not this system
  # is required to have an economizer.
  #
  # @return [Bool] returns true if an economizer is required, false if not
  def air_loop_hvac_economizer_required?(air_loop_hvac)
    economizer_required = false

    # need a better way to determine if an economizer is needed.
    return economizer_required if air_loop_hvac.name.to_s.include? 'Outpatient F1'

    # A big number of btu per hr as the minimum requirement
    infinity_btu_per_hr = 999_999_999_999
    minimum_capacity_btu_per_hr = infinity_btu_per_hr

    # Determine if the airloop serves any computer rooms
    # / data centers, which changes the economizer.
    is_dc = false
    if air_loop_hvac_data_center_area_served(air_loop_hvac) > 0
      is_dc = true
    end

    # Determine the minimum capacity that requires an economizer
    minimum_capacity_btu_per_hr = 68_243 # NECB requires economizer for cooling cap > 20 kW

    # puts air_loop_hvac.name.to_s
    # Design Supply Air Flow Rate: This method below reads the value from the sql file.
    dsafr_m3_per_s = air_loop_hvac.model.getAutosizedValue(air_loop_hvac, 'Design Supply Air Flow Rate', 'm3/s')
    min_dsafr_l_per_s = 1500
    unless dsafr_m3_per_s.empty?
      dsafr_l_per_s = dsafr_m3_per_s.get()*1000
      if dsafr_l_per_s > min_dsafr_l_per_s
        economizer_required = true
        puts "economizer_required = true for #{air_loop_hvac.name} because dsafr_l_per_s(#{dsafr_l_per_s}) > 1500"
        if is_dc
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} requires an economizer because the 'Design Supply Air Flow Rate' of #{dsafr_l_per_s} L/s exceeds the minimum air flow rate of #{min_dsafr_l_per_s} L/s for data centers.")
        else
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} requires an economizer because the 'Design Supply Air Flow Rate' of #{dsafr_l_per_s} L/s exceeds the minimum air flow rate of #{min_dsafr_l_per_s} L/s.")
        end
      end
    end
    # Check whether the system requires an economizer by comparing
    # the system capacity to the minimum capacity.
    total_cooling_capacity_w = air_loop_hvac_total_cooling_capacity(air_loop_hvac)
    total_cooling_capacity_btu_per_hr = OpenStudio.convert(total_cooling_capacity_w, 'W', 'Btu/hr').get
    if total_cooling_capacity_btu_per_hr >= minimum_capacity_btu_per_hr
      if is_dc
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} requires an economizer because the total cooling capacity of #{total_cooling_capacity_btu_per_hr.round} Btu/hr exceeds the minimum capacity of #{minimum_capacity_btu_per_hr.round} Btu/hr for data centers.")
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} requires an economizer because the total cooling capacity of #{total_cooling_capacity_btu_per_hr.round} Btu/hr exceeds the minimum capacity of #{minimum_capacity_btu_per_hr.round} Btu/hr.")
      end
      puts "economizer_required = true for #{air_loop_hvac.name} because total_cooling_capacity_btu_per_hr(#{total_cooling_capacity_btu_per_hr}) >= #{minimum_capacity_btu_per_hr}"
      economizer_required = true
    else
      if is_dc
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} does not require an economizer because the total cooling capacity of #{total_cooling_capacity_btu_per_hr.round} Btu/hr is less than the minimum capacity of #{minimum_capacity_btu_per_hr.round} Btu/hr for data centers.")
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "#{air_loop_hvac.name} does not require an economizer because the total cooling capacity of #{total_cooling_capacity_btu_per_hr.round} Btu/hr is less than the minimum capacity of #{minimum_capacity_btu_per_hr.round} Btu/hr.")
      end
    end

    return economizer_required
  end

  # NECB always requires an integrated economizer
  # (NoLockout); as per 5.2.2.8(3)
  # this means that compressor allowed to turn on when economizer is open
  #
  # @note this method assumes you previously checked that an economizer is required at all
  #   via #economizer_required?
  # @param (see #economizer_required?)
  # @return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_economizer_integration(air_loop_hvac, climate_zone)
    # Get the OA system and OA controller
    oa_sys = air_loop_hvac.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir

    # Apply integrated economizer
    oa_control.setLockoutType('NoLockout')

    return true
  end

  # Check if ERV is required on this airloop.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def air_loop_hvac_energy_recovery_ventilator_required?(air_loop_hvac, climate_zone)
    # ERV Not Applicable for AHUs that serve
    # parking garage, warehouse, or multifamily
    # if space_types_served_names.include?('PNNL_Asset_Rating_Apartment_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_LowRiseApartment_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_ParkingGarage_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_Warehouse_Space_Type')
    # OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV not applicable because it because it serves parking garage, warehouse, or multifamily.")
    # return false
    # end

    erv_required = nil
    # ERV not applicable for medical AHUs (AHU1 in Outpatient), per AIA 2001 - 7.31.D2.
    if air_loop_hvac.name.to_s.include? 'Outpatient F1'
      erv_required = false
      return erv_required
    end

    # ERV not applicable for medical AHUs, per AIA 2001 - 7.31.D2.
    if air_loop_hvac.name.to_s.include? 'VAV_ER'
      erv_required = false
      return erv_required
    elsif air_loop_hvac.name.to_s.include? 'VAV_OR'
      erv_required = false
      return erv_required
    end

    # ERV Not Applicable for AHUs that have DCV
    # or that have no OA intake.
    controller_oa = nil
    controller_mv = nil
    oa_system = nil
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      if controller_mv.demandControlledVentilation == true
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not applicable because DCV enabled.")
        return false
      end
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not applicable because it has no OA intake.")
      return false
    end

    # Get the AHU design supply air flow rate
    dsn_flow_m3_per_s = nil
    if air_loop_hvac.designSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = air_loop_hvac.designSupplyAirFlowRate.get
    elsif air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} design supply air flow rate is not available, cannot apply efficiency standard.")
      return false
    end
    dsn_flow_cfm = OpenStudio.convert(dsn_flow_m3_per_s, 'm^3/s', 'cfm').get

    # Get the minimum OA flow rate
    min_oa_flow_m3_per_s = nil
    if controller_oa.minimumOutdoorAirFlowRate.is_initialized
      min_oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
    elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
      min_oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{controller_oa.name}: minimum OA flow rate is not available, cannot apply efficiency standard.")
      return false
    end
    min_oa_flow_cfm = OpenStudio.convert(min_oa_flow_m3_per_s, 'm^3/s', 'cfm').get

    # Calculate the percent OA at design airflow
    pct_oa = min_oa_flow_m3_per_s / dsn_flow_m3_per_s

    # The NECB2011 requirement is that systems with an exhaust heat content > 150 kW require an HRV
    # The calculation for this is done below, to modify erv_required
    # erv_cfm set to nil here as placeholder, will lead to erv_required = false
    erv_cfm = nil

    # Determine if an ERV is required
    # erv_required = nil
    if erv_cfm.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not required based on #{(pct_oa * 100).round}% OA flow, design supply air flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}.")
      erv_required = false
    elsif dsn_flow_cfm < erv_cfm
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not required based on #{(pct_oa * 100).round}% OA flow, design supply air flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}. Does not exceed minimum flow requirement of #{erv_cfm}cfm.")
      erv_required = false
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV required based on #{(pct_oa * 100).round}% OA flow, design supply air flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}. Exceeds minimum flow requirement of #{erv_cfm}cfm.")
      erv_required = true
    end

    # This code modifies erv_required for NECB2011
    # Calculation of exhaust heat content and check whether it is > 150 kW

    # get all zones in the model
    zones = air_loop_hvac.thermalZones

    # initialize counters
    sum_zone_oa = 0.0
    sum_zone_oa_times_heat_design_t = 0.0

    # zone loop
    zones.each do |zone|
      # get design heat temperature for each zone; this is equivalent to design exhaust temperature
      heat_design_t = 21.0
      zone_thermostat = zone.thermostat.get
      if zone_thermostat.to_ThermostatSetpointDualSetpoint.is_initialized
        dual_thermostat = zone_thermostat.to_ThermostatSetpointDualSetpoint.get
        htg_temp_sch = dual_thermostat.heatingSetpointTemperatureSchedule.get
        htg_temp_sch_ruleset = htg_temp_sch.to_ScheduleRuleset.get
        winter_dd_sch = htg_temp_sch_ruleset.winterDesignDaySchedule
        heat_design_t = winter_dd_sch.values.max
      end

      # initialize counter
      zone_oa = 0.0
      # outdoor defined at space level; get OA flow for all spaces within zone
      spaces = zone.spaces

      # space loop
      spaces.each do |space|
        unless space.designSpecificationOutdoorAir.empty? # if empty, don't do anything
          outdoor_air = space.designSpecificationOutdoorAir.get
          # in bTAP, outdoor air specified as outdoor air per
          oa_flow_per_floor_area = outdoor_air.outdoorAirFlowperFloorArea
          oa_flow = oa_flow_per_floor_area * space.floorArea * zone.multiplier # oa flow for the space
          zone_oa += oa_flow # add up oa flow for all spaces to get zone air flow
        end
      end # space loop
      sum_zone_oa += zone_oa # sum of all zone oa flows to get system oa flow
      sum_zone_oa_times_heat_design_t += (zone_oa * heat_design_t) # calculated to get oa flow weighted average of design exhaust temperature
    end # zone loop

    # Calculate average exhaust temperature (oa flow weighted average)
    avg_exhaust_temp = sum_zone_oa_times_heat_design_t / sum_zone_oa

    # for debugging/testing
    #      puts "average exhaust temp = #{avg_exhaust_temp}"
    #      puts "sum_zone_oa = #{sum_zone_oa}"

    # Get January winter design temperature
    # get model weather file name
    weather_file = BTAP::Environment::WeatherFile.new(air_loop_hvac.model.weatherFile.get.path.get)

    # get winter(heating) design temp stored in array
    # Note that the NECB2011 specifies using the 2.5% january design temperature
    # The outdoor temperature used here is the 0.4% heating design temperature of the coldest month, available in stat file
    outdoor_temp = weather_file.heating_design_info[1]

    #      for debugging/testing
    #      puts "outdoor design temp = #{outdoor_temp}"

    # Calculate exhaust heat content
    exhaust_heat_content = 0.00123 * sum_zone_oa * 1000.0 * (avg_exhaust_temp - outdoor_temp)

    # for debugging/testing
    #      puts "exhaust heat content = #{exhaust_heat_content}"

    # Modify erv_required based on exhaust heat content
    if exhaust_heat_content > 150.0
      erv_required = true
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV required based on exhaust heat content.")
    else
      erv_required = false
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not required based on exhaust heat content.")
    end

    return erv_required
  end

  # Add an ERV to this airloop.
  # Will be a rotary-type HX
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def air_loop_hvac_apply_energy_recovery_ventilator(air_loop_hvac)
    # Get the oa system
    oa_system = nil
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV cannot be added because the system has no OA intake.")
      return false
    end

    # Create an ERV
    erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(air_loop_hvac.model)
    erv.setName("#{air_loop_hvac.name} ERV")
    erv.setSensibleEffectivenessat100HeatingAirFlow(0.5)
    erv.setLatentEffectivenessat100HeatingAirFlow(0.5)
    erv.setSensibleEffectivenessat75HeatingAirFlow(0.5)
    erv.setLatentEffectivenessat75HeatingAirFlow(0.5)
    erv.setSensibleEffectivenessat100CoolingAirFlow(0.5)
    erv.setLatentEffectivenessat100CoolingAirFlow(0.5)
    erv.setSensibleEffectivenessat75CoolingAirFlow(0.5)
    erv.setLatentEffectivenessat75CoolingAirFlow(0.5)
    erv.setSupplyAirOutletTemperatureControl(true)
    erv.setHeatExchangerType('Rotary')
    erv.setFrostControlType('ExhaustOnly')
    erv.setEconomizerLockout(true)
    erv.setThresholdTemperature(-23.3) # -10F
    erv.setInitialDefrostTimeFraction(0.167)
    erv.setRateofDefrostTimeFractionIncrease(1.44)

    # Add the ERV to the OA system
    erv.addToNode(oa_system.outboardOANode.get)

    # Add a setpoint manager OA pretreat
    # to control the ERV
    spm_oa_pretreat = OpenStudio::Model::SetpointManagerOutdoorAirPretreat.new(air_loop_hvac.model)
    spm_oa_pretreat.setMinimumSetpointTemperature(-99.0)
    spm_oa_pretreat.setMaximumSetpointTemperature(99.0)
    spm_oa_pretreat.setMinimumSetpointHumidityRatio(0.00001)
    spm_oa_pretreat.setMaximumSetpointHumidityRatio(1.0)
    # Reference setpoint node and
    # Mixed air stream node are outlet
    # node of the OA system
    mixed_air_node = oa_system.mixedAirModelObject.get.to_Node.get
    spm_oa_pretreat.setReferenceSetpointNode(mixed_air_node)
    spm_oa_pretreat.setMixedAirStreamNode(mixed_air_node)
    # Outdoor air node is
    # the outboard OA node of teh OA system
    spm_oa_pretreat.setOutdoorAirStreamNode(oa_system.outboardOANode.get)
    # Return air node is the inlet
    # node of the OA system
    return_air_node = oa_system.returnAirModelObject.get.to_Node.get
    spm_oa_pretreat.setReturnAirStreamNode(return_air_node)
    # Attach to the outlet of the ERV
    erv_outlet = erv.primaryAirOutletModelObject.get.to_Node.get
    spm_oa_pretreat.addToNode(erv_outlet)

    # Apply the prototype Heat Exchanger power assumptions.
    heat_exchanger_air_to_air_sensible_and_latent_apply_prototype_nominal_electric_power(erv)

    # Determine if the system is a DOAS based on
    # whether there is 100% OA in heating and cooling sizing.
    is_doas = false
    sizing_system = air_loop_hvac.sizingSystem
    if sizing_system.allOutdoorAirinCooling && sizing_system.allOutdoorAirinHeating
      is_doas = true
    end

    # Set the bypass control type
    # If DOAS system, BypassWhenWithinEconomizerLimits
    # to disable ERV during economizing.
    # Otherwise, BypassWhenOAFlowGreaterThanMinimum
    # to disable ERV during economizing and when OA
    # is also greater than minimum.
    bypass_ctrl_type = if is_doas
                         'BypassWhenWithinEconomizerLimits'
                       else
                         'BypassWhenOAFlowGreaterThanMinimum'
                       end
    oa_system.getControllerOutdoorAir.setHeatRecoveryBypassControlType(bypass_ctrl_type)

    return true
  end

  # Determine if demand control ventilation (DCV) is
  # required for this air loop.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for
  #   systems that serve multifamily, parking garage, warehouse
  def air_loop_hvac_demand_control_ventilation_required?(air_loop_hvac, climate_zone)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{air_loop_hvac.name}: DCV is not required for any system.")
    dcv_required = false
    return dcv_required
  end

  # Set the VAV damper control to single maximum or
  # dual maximum control depending on the standard.
  #
  # @return [Bool] Returns true if successful, false if not
  # @todo see if this impacts the sizing run.
  def air_loop_hvac_apply_vav_damper_action(air_loop_hvac)
    damper_action = 'Single Maximum'

    # Interpret this as an EnergyPlus input
    damper_action_eplus = nil
    if damper_action == 'Single Maximum'
      damper_action_eplus = 'Normal'
    elsif damper_action == 'Dual Maximum'
      # EnergyPlus 8.7 changed the meaning of 'Reverse'.
      # For versions of OpenStudio using E+ 8.6 or lower
      damper_action_eplus = if air_loop_hvac.model.version < OpenStudio::VersionString.new('2.0.5')
                              'Reverse'
                              # For versions of OpenStudio using E+ 8.7 or higher
                            else
                              'ReverseWithLimits'
                            end
    end

    # Set the control for any VAV reheat terminals
    # on this airloop.
    control_type_set = false
    air_loop_hvac.demandComponents.each do |equip|
      if equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
        term = equip.to_AirTerminalSingleDuctVAVReheat.get
        # Dual maximum only applies to terminals with HW reheat coils
        if damper_action == 'Dual Maximum'
          if term.reheatCoil.to_CoilHeatingWater.is_initialized
            term.setDamperHeatingAction(damper_action_eplus)
            control_type_set = true
          end
        else
          term.setDamperHeatingAction(damper_action_eplus)
          control_type_set = true
          term.setMaximumFlowFractionDuringReheat(0.5)
        end
      end
    end

    if control_type_set
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: VAV damper action was set to #{damper_action} control.")
    end

    return true
  end

  # NECB has no single zone air loop control requirements
  #
  # @return [Bool] returns true if successful, false if not
  def air_loop_hvac_apply_single_zone_controls(air_loop_hvac, climate_zone)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: No special economizer controls were modeled.")
    return true
  end

  # NECB doesn't require static pressure reset.
  #
  # return [Bool] returns true if static pressure reset is required, false if not
  def air_loop_hvac_static_pressure_reset_required?(air_loop_hvac, has_ddc)
    # static pressure reset not required
    sp_reset_required = false
    return sp_reset_required
  end

  # Determine the air flow and number of story limits
  # for whether motorized OA damper is required.
  # @return [Array<Double>] [minimum_oa_flow_cfm, maximum_stories].
  # If both nil, never required
  def air_loop_hvac_motorized_oa_damper_limits(air_loop_hvac, climate_zone)
    minimum_oa_flow_cfm = 0
    maximum_stories = 0
    return [minimum_oa_flow_cfm, maximum_stories]
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @param boiler_hot_water [OpenStudio::Model::BoilerHotWater] the object to modify
  # @return [Bool] true if successful, false if not
  def boiler_hot_water_apply_efficiency_and_curves(boiler_hot_water)
    successfully_set_all_properties = false

    # Define the criteria to find the boiler properties
    # in the hvac standards data set.
    search_criteria = boiler_hot_water_find_search_criteria(boiler_hot_water)
    fuel_type = search_criteria['fuel_type']
    fluid_type = search_criteria['fluid_type']

    # Get the capacity
    capacity_w = boiler_hot_water_find_capacity(boiler_hot_water)

    # Check if secondary and/or modulating boiler required
    if capacity_w / 1000.0 >= 352.0
      if boiler_hot_water.name.to_s.include?('Primary Boiler')
        boiler_capacity = capacity_w
        boiler_hot_water.setBoilerFlowMode('LeavingSetpointModulated')
        boiler_hot_water.setMinimumPartLoadRatio(0.25)
      elsif boiler_hot_water.name.to_s.include?('Secondary Boiler')
        boiler_capacity = 0.001
      end
    elsif ((capacity_w / 1000.0) >= 176.0) && ((capacity_w / 1000.0) < 352.0)
      boiler_capacity = capacity_w / 2
    elsif (capacity_w / 1000.0) <= 176.0
      if boiler_hot_water.name.to_s.include?('Primary Boiler')
        boiler_capacity = capacity_w
      elsif boiler_hot_water.name.to_s.include?('Secondary Boiler')
        boiler_capacity = 0.001
      end
    end
    boiler_hot_water.setNominalCapacity(boiler_capacity)

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(boiler_capacity, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(boiler_capacity, 'W', 'kBtu/hr').get

    # Get the boiler properties
    blr_props = model_find_object(standards_data['boilers'], search_criteria, capacity_btu_per_hr)
    unless blr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{boiler_hot_water.name}, cannot find boiler properties, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the EFFFPLR curve
    eff_fplr = model_add_curve(boiler_hot_water.model, blr_props['efffplr'])
    if eff_fplr
      boiler_hot_water.setNormalizedBoilerEfficiencyCurve(eff_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.BoilerHotWater', "For #{boiler_hot_water.name}, cannot find eff_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Get the minimum efficiency standards
    thermal_eff = nil

    # If specified as AFUE
    unless blr_props['minimum_annual_fuel_utilization_efficiency'].nil?
      min_afue = blr_props['minimum_annual_fuel_utilization_efficiency']
      thermal_eff = afue_to_thermal_eff(min_afue)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_afue} AFUE"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end

    # If specified as thermal efficiency
    unless blr_props['minimum_thermal_efficiency'].nil?
      thermal_eff = blr_props['minimum_thermal_efficiency']
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless blr_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = blr_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{template}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
    end

    # Set the name
    boiler_hot_water.setName(new_comp_name)

    # Set the efficiency values
    unless thermal_eff.nil?
      boiler_hot_water.setNominalThermalEfficiency(thermal_eff)
    end

    return successfully_set_all_properties
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @return [Bool] true if successful, false if not
  def chiller_electric_eir_apply_efficiency_and_curves(chiller_electric_eir, clg_tower_objs)
    chillers = standards_data['chillers']

    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = chiller_electric_eir_find_search_criteria(chiller_electric_eir)
    cooling_type = search_criteria['cooling_type']
    condenser_type = search_criteria['condenser_type']
    compressor_type = search_criteria['compressor_type']

    # Get the chiller capacity
    capacity_w = chiller_electric_eir_find_capacity(chiller_electric_eir)

    # All chillers must be modulating down to 25% of their capacity
    chiller_electric_eir.setChillerFlowMode('LeavingSetpointModulated')
    chiller_electric_eir.setMinimumPartLoadRatio(0.25)
    chiller_electric_eir.setMinimumUnloadingRatio(0.25)
    if (capacity_w / 1000.0) < 2100.0
      if chiller_electric_eir.name.to_s.include? 'Primary Chiller'
        chiller_capacity = capacity_w
      elsif chiller_electric_eir.name.to_s.include? 'Secondary Chiller'
        chiller_capacity = 0.001
      end
    else
      chiller_capacity = capacity_w / 2.0
    end
    chiller_electric_eir.setReferenceCapacity(chiller_capacity)

    # Convert capacity to tons
    capacity_tons = OpenStudio.convert(chiller_capacity, 'W', 'ton').get

    # Get the chiller properties
    chlr_props = model_find_object(chillers, search_criteria, capacity_tons, Date.today)
    unless chlr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find chiller properties, cannot apply standard efficiencies or curves.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the CAPFT curve
    cool_cap_ft = model_add_curve(chiller_electric_eir.model, chlr_props['capft'])
    if cool_cap_ft
      chiller_electric_eir.setCoolingCapacityFunctionOfTemperature(cool_cap_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the EIRFT curve
    cool_eir_ft = model_add_curve(chiller_electric_eir.model, chlr_props['eirft'])
    if cool_eir_ft
      chiller_electric_eir.setElectricInputToCoolingOutputRatioFunctionOfTemperature(cool_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the EIRFPLR curve
    # which may be either a CurveBicubic or a CurveQuadratic based on chiller type
    cool_plf_fplr = model_add_curve(chiller_electric_eir.model, chlr_props['eirfplr'])
    if cool_plf_fplr
      chiller_electric_eir.setElectricInputToCoolingOutputRatioFunctionOfPLR(cool_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Set the efficiency value
    kw_per_ton = nil
    cop = nil
    if chlr_props['minimum_full_load_efficiency']
      kw_per_ton = chlr_props['minimum_full_load_efficiency']
      cop = kw_per_ton_to_cop(kw_per_ton)
      chiller_electric_eir.setReferenceCOP(cop)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find minimum full load efficiency, will not be set.")
      successfully_set_all_properties = false
    end

    # Set cooling tower properties now that the new COP of the chiller is set
    if chiller_electric_eir.name.to_s.include? 'Primary Chiller'
      # Single speed tower model assumes 25% extra for compressor power
      tower_cap = capacity_w * (1.0 + 1.0 / chiller_electric_eir.referenceCOP)
      if (tower_cap / 1000.0) < 1750
        clg_tower_objs[0].setNumberofCells(1)
      else
        clg_tower_objs[0].setNumberofCells((tower_cap / (1000 * 1750) + 0.5).round)
      end
      clg_tower_objs[0].setFanPoweratDesignAirFlowRate(0.015 * tower_cap)
    end

    # Append the name with size and kw/ton
    chiller_electric_eir.setName("#{chiller_electric_eir.name} #{capacity_tons.round}tons #{kw_per_ton.round(1)}kW/ton")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.ChillerElectricEIR', "For #{template}: #{chiller_electric_eir.name}: #{cooling_type} #{condenser_type} #{compressor_type} Capacity = #{capacity_tons.round}tons; COP = #{cop.round(1)} (#{kw_per_ton.round(1)}kW/ton)")

    return successfully_set_all_properties
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @return [Bool] true if successful, false if not
  def coil_cooling_dx_multi_speed_apply_efficiency_and_curves(coil_cooling_dx_multi_speed, sql_db_vars_map)
    successfully_set_all_properties = true

    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = {}
    search_criteria['template'] = template
    cooling_type = coil_cooling_dx_multi_speed.condenserType
    search_criteria['cooling_type'] = cooling_type

    # TODO: Standards - add split system vs single package to model
    # For now, assume single package as default
    sub_category = 'Single Package'

    # Determine the heating type if unitary or zone hvac
    heat_pump = false
    heating_type = nil
    containing_comp = nil
    if coil_cooling_dx_multi_speed.airLoopHVAC.empty?
      if coil_cooling_dx_multi_speed.containingHVACComponent.is_initialized
        containing_comp = coil_cooling_dx_multi_speed.containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized
          htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get.heatingCoil
          if htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized
            heat_pump = true
            heating_type = 'Electric Resistance or None'
          elsif htg_coil.to_CoilHeatingGasMultiStage.is_initialized
            heating_type = 'All Other'
          end
        end # TODO: Add other unitary systems
      elsif coil_cooling_dx_multi_speed.containingZoneHVACComponent.is_initialized
        containing_comp = coil_cooling_dx_multi_speed.containingZoneHVACComponent.get
        if containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          sub_category = 'PTAC'
          htg_coil = containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.get.heatingCoil
          if htg_coil.to_CoilHeatingElectric.is_initialized
            heating_type = 'Electric Resistance or None'
          elsif htg_coil.to_CoilHeatingWater.is_initialized || htg_coil.to_CoilHeatingGas.is_initialized || htg_col.to_CoilHeatingGasMultiStage
            heating_type = 'All Other'
          end
        end # TODO: Add other zone hvac systems
      end
    end

    # Add the heating type to the search criteria
    unless heating_type.nil?
      search_criteria['heating_type'] = heating_type
    end

    search_criteria['subcategory'] = sub_category

    # Get the coil capacity
    capacity_w = nil
    clg_stages = stages
    if clg_stages.last.grossRatedTotalCoolingCapacity.is_initialized
      capacity_w = clg_stages.last.grossRatedTotalCoolingCapacity.get
    elsif coil_cooling_dx_multi_speed.autosizedSpeed4GrossRatedTotalCoolingCapacity.is_initialized
      capacity_w = coil_cooling_dx_multi_speed.autosizedSpeed4GrossRatedTotalCoolingCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Volume flow rate
    flow_rate4 = nil
    if clg_stages.last.ratedAirFlowRate.is_initialized
      flow_rate4 = clg_stages.last.ratedAirFlowRate.get
    elsif coil_cooling_dx_multi_speed.autosizedSpeed4RatedAirFlowRate.is_initialized
      flow_rate4 = coil_cooling_dx_multi_speed.autosizedSpeed4RatedAirFlowRate.get
    end

    # Set number of stages
    stage_cap = []
    num_stages = (capacity_w / (66.0 * 1000.0) + 0.5).round
    num_stages = [num_stages, 4].min
    if num_stages == 1
      stage_cap[0] = capacity_w / 2.0
      stage_cap[1] = 2.0 * stage_cap[0]
      stage_cap[2] = stage_cap[1] + 0.1
      stage_cap[3] = stage_cap[2] + 0.1
    else
      stage_cap[0] = 66.0 * 1000.0
      stage_cap[1] = 2.0 * stage_cap[0]
      if num_stages == 2
        stage_cap[2] = stage_cap[1] + 0.1
        stage_cap[3] = stage_cap[2] + 0.1
      elsif num_stages == 3
        stage_cap[2] = 3.0 * stage_cap[0]
        stage_cap[3] = stage_cap[2] + 0.1
      elsif num_stages == 4
        stage_cap[2] = 3.0 * stage_cap[0]
        stage_cap[3] = 4.0 * stage_cap[0]
      end
    end
    # set capacities, flow rates, and sensible heat ratio for stages
    (0..3).each do |istage|
      clg_stages[istage].setGrossRatedTotalCoolingCapacity(stage_cap[istage])
      clg_stages[istage].setRatedAirFlowRate(flow_rate4 * stage_cap[istage] / capacity_w)
    end

    # Convert capacity to Btu/hr
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Lookup efficiencies depending on whether it is a unitary AC or a heat pump
    ac_props = nil
    ac_props = if heat_pump == true
                 model_find_object(standards_data['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
               else
                 model_find_object(standards_data['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
               end

    # Check to make sure properties were found
    if ac_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find efficiency info, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the COOL-CAP-FT curve
    cool_cap_ft = model_add_curve(model, ac_props['cool_cap_ft'], standards)
    if cool_cap_ft
      clg_stages.each do |stage|
        stage.setTotalCoolingCapacityFunctionofTemperatureCurve(cool_cap_ft)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-CAP-FFLOW curve
    cool_cap_fflow = model_add_curve(model, ac_props['cool_cap_fflow'], standards)
    if cool_cap_fflow
      clg_stages.each do |stage|
        stage.setTotalCoolingCapacityFunctionofFlowFractionCurve(cool_cap_fflow)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_cap_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FT curve
    cool_eir_ft = model_add_curve(model, ac_props['cool_eir_ft'], standards)
    if cool_eir_ft
      clg_stages.each do |stage|
        stage.setEnergyInputRatioFunctionofTemperatureCurve(cool_eir_ft)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-EIR-FFLOW curve
    cool_eir_fflow = model_add_curve(model, ac_props['cool_eir_fflow'], standards)
    if cool_eir_fflow
      clg_stages.each do |stage|
        stage.setEnergyInputRatioFunctionofFlowFractionCurve(cool_eir_fflow)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_eir_fflow curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the COOL-PLF-FPLR curve
    cool_plf_fplr = model_add_curve(model, ac_props['cool_plf_fplr'], standards)
    if cool_plf_fplr
      clg_stages.each do |stage|
        stage.setPartLoadFractionCorrelationCurve(cool_plf_fplr)
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_cooling_dx_multi_speed.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Get the minimum efficiency standards
    cop = nil

    if coil_dx_subcategory(coil_cooling_dx_multi_speed) == 'PTAC'
      ptac_eer_coeff_1 = ac_props['ptac_eer_coefficient_1']
      ptac_eer_coeff_2 = ac_props['ptac_eer_coefficient_2']
      capacity_btu_per_hr = 7000 if capacity_btu_per_hr < 7000
      capacity_btu_per_hr = 15_000 if capacity_btu_per_hr > 15_000
      ptac_eer = ptac_eer_coeff_1 + (ptac_eer_coeff_2 * capacity_btu_per_hr)
      cop = eer_to_cop(ptac_eer)
      # self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER")
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{ptac_eer}")
    end

    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{template}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    sql_db_vars_map[new_comp_name] = name.to_s
    coil_cooling_dx_multi_speed.setName(new_comp_name)

    # Set the efficiency values

    unless cop.nil?
      clg_stages.each do |istage|
        istage.setGrossRatedCoolingCOP(cop)
      end
    end

    return sql_db_vars_map
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @return [Bool] true if successful, false if not
  def coil_heating_gas_multi_stage_apply_efficiency_and_curves(coil_heating_gas_multi_stage, standards)
    successfully_set_all_properties = true

    # Get the coil capacity
    capacity_w = nil
    htg_stages = stages
    if htg_stages.last.nominalCapacity.is_initialized
      capacity_w = htg_stages.last.nominalCapacity.get
    elsif coil_heating_gas_multi_stage.autosizedStage4NominalCapacity.is_initialized
      capacity_w = coil_heating_gas_multi_stage.autosizedStage4NominalCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_heating_gas_multi_stage.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Set number of stages
    num_stages = (capacity_w / (66.0 * 1000.0) + 0.5).round
    num_stages = [num_stages, 4].min
    stage_cap = []
    if num_stages == 1
      stage_cap[0] = capacity_w / 2.0
      stage_cap[1] = 2.0 * stage_cap[0]
      stage_cap[2] = stage_cap[1] + 0.1
      stage_cap[3] = stage_cap[2] + 0.1
    else
      stage_cap[0] = 66.0 * 1000.0
      stage_cap[1] = 2.0 * stage_cap[0]
      if num_stages == 2
        stage_cap[2] = stage_cap[1] + 0.1
        stage_cap[3] = stage_cap[2] + 0.1
      elsif num_stages == 3
        stage_cap[2] = 3.0 * stage_cap[0]
        stage_cap[3] = stage_cap[2] + 0.1
      elsif num_stages == 4
        stage_cap[2] = 3.0 * stage_cap[0]
        stage_cap[3] = 4.0 * stage_cap[0]
      end
    end
    # set capacities, flow rates, and sensible heat ratio for stages
    (0..3).each do |istage|
      htg_stages[istage].setNominalCapacity(stage_cap[istage])
    end
    # PLF vs PLR curve
    furnace_plffplr_curve_name = 'FURNACE-EFFPLR-NECB2011'

    # plf vs plr curve for furnace
    furnace_plffplr_curve = model_add_curve(coil_heating_gas_multi_stage.model, furnace_plffplr_curve_name, standards)
    if furnace_plffplr_curve
      coil_heating_gas_multi_stage.setPartLoadFractionCorrelationCurve(furnace_plffplr_curve)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGasMultiStage', "For #{coil_heating_gas_multi_stage.name}, cannot find plffplr curve, will not be set.")
      successfully_set_all_properties = false
    end
  end

  # Determines the baseline fan impeller efficiency
  # based on the specified fan type.
  #
  # @return [Double] impeller efficiency (0.0 to 1.0)
  # @todo Add fan type to data model and modify this method
  def fan_baseline_impeller_efficiency(fan)
    # Assume that the fan efficiency is 65% for normal fans
    # TODO add fan type to fan data model
    # and infer impeller efficiency from that?
    # or do we always assume a certain type of
    # fan impeller for the baseline system?
    # TODO check COMNET and T24 ACM and PNNL 90.1 doc
    fan_impeller_eff = 0.65

    return fan_impeller_eff
  end

  # Determines the minimum fan motor efficiency and nominal size
  # for a given motor bhp.  This should be the total brake horsepower with
  # any desired safety factor already included.  This method picks
  # the next nominal motor catgory larger than the required brake
  # horsepower, and the efficiency is based on that size.  For example,
  # if the bhp = 6.3, the nominal size will be 7.5HP and the efficiency
  # for 90.1-2010 will be 91.7% from Table 10.8B.  This method assumes
  # 4-pole, 1800rpm totally-enclosed fan-cooled motors.
  #
  # @param motor_bhp [Double] motor brake horsepower (hp)
  # @return [Array<Double>] minimum motor efficiency (0.0 to 1.0), nominal horsepower
  def fan_standard_minimum_motor_efficiency_and_size(fan, motor_bhp)
    fan_motor_eff = 0.85
    nominal_hp = motor_bhp

    # Don't attempt to look up motor efficiency
    # for zero-hp fans, which may occur when there is no
    # airflow required for a particular system, typically
    # heated-only spaces with high internal gains
    # and no OA requirements such as elevator shafts.
    return [fan_motor_eff, 0] if motor_bhp == 0.0

    # Lookup the minimum motor efficiency
    motors = standards_data['motors']

    # Assuming all fan motors are 4-pole ODP
    template_mod = @template
    if fan.class.name == 'OpenStudio::Model::FanConstantVolume'
      template_mod += '-CONSTANT'
    elsif fan.class.name == 'OpenStudio::Model::FanVariableVolume'
      # Is this a return or supply fan
      if fan.name.to_s.include?('Supply')
        template_mod += '-VARIABLE-SUPPLY'
      elsif fan.name.to_s.include?('Return')
        template_mod += '-VARIABLE-RETURN'
      end
      # 0.909 corrects for 10% over sizing implemented upstream
      # 0.7457 is to convert from bhp to kW
      fan_power_kw = 0.909 * 0.7457 * motor_bhp
      power_vs_flow_curve_name = if fan_power_kw >= 25.0
                                 'VarVolFan-FCInletVanes-NECB2011-FPLR'
                               elsif fan_power_kw >= 7.5 && fan_power_kw < 25
                                 'VarVolFan-AFBIInletVanes-NECB2011-FPLR'
                               else
                                 'VarVolFan-AFBIFanCurve-NECB2011-FPLR'
                               end
      power_vs_flow_curve = model_add_curve(fan.model, power_vs_flow_curve_name)
      fan.setFanPowerMinimumFlowRateInputMethod('Fraction')
      fan.setFanPowerCoefficient5(0.0)
      fan.setFanPowerMinimumFlowFraction(power_vs_flow_curve.minimumValueofx)
      fan.setFanPowerCoefficient1(power_vs_flow_curve.coefficient1Constant)
      fan.setFanPowerCoefficient2(power_vs_flow_curve.coefficient2x)
      fan.setFanPowerCoefficient3(power_vs_flow_curve.coefficient3xPOW2)
      fan.setFanPowerCoefficient4(power_vs_flow_curve.coefficient4xPOW3)
    else
      raise('')
    end

    search_criteria = {
        'template' => template_mod,
        'number_of_poles' => 4.0,
        'type' => 'Enclosed'
    }

    # Exception for small fans, including
    # zone exhaust, fan coil, and fan powered terminals.
    # In this case, use the 0.5 HP for the lookup.
    if fan_small_fan?(fan)
      nominal_hp = 0.5
    else
      motor_properties = model_find_object(motors, search_criteria, motor_bhp)
      if motor_properties.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{fan.name}, could not find motor properties using search criteria: #{search_criteria}, motor_bhp = #{motor_bhp} hp.")
        return [fan_motor_eff, nominal_hp]
      end

      nominal_hp = motor_properties['maximum_capacity'].to_f.round(1)
      # If the biggest fan motor size is hit, use the highest category efficiency
      if nominal_hp == 9999.0
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Fan', "For #{fan.name}, there is no greater nominal HP.  Use the efficiency of the largest motor category.")
        nominal_hp = motor_bhp
      end

      # Round to nearest whole HP for niceness
      if nominal_hp >= 2
        nominal_hp = nominal_hp.round
      end
    end

    # Get the efficiency based on the nominal horsepower
    # Add 0.01 hp to avoid search errors.
    motor_properties = model_find_object(motors, search_criteria, nominal_hp + 0.01)
    if motor_properties.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{fan.name}, could not find nominal motor properties using search criteria: #{search_criteria}, motor_hp = #{nominal_hp} hp.")
      return [fan_motor_eff, nominal_hp]
    end
    fan_motor_eff = motor_properties['nominal_full_load_efficiency']

    return [fan_motor_eff, nominal_hp]
  end

  # Determines whether there is a requirement to have a
  # VSD or some other method to reduce fan power
  # at low part load ratios.
  def fan_variable_volume_part_load_fan_power_limitation?(fan_variable_volume)
    part_load_control_required = false

    return part_load_control_required
  end

  # Determine if demand control ventilation (DCV) is
  # required for this zone based on area and occupant density.
  # Does not account for System requirements like ERV, economizer, etc.
  # Those are accounted for in the AirLoopHVAC method of the same name.
  #
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for 90.1-2013
  #   for cells, sickrooms, labs, barbers, salons, and bowling alleys
  def thermal_zone_demand_control_ventilation_required?(thermal_zone, climate_zone)
    return false
  end

  def model_apply_sizing_parameters(model)
    model.getSizingParameters.setHeatingSizingFactor(self.get_standards_constant('sizing_factor_max_heating'))
    model.getSizingParameters.setCoolingSizingFactor(self.get_standards_constant('sizing_factor_max_cooling'))
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Set sizing factors to #{self.get_standards_constant('sizing_factor_max_heating')} for heating and #{self.get_standards_constant('sizing_factor_max_heating')} for cooling.")
  end

  def fan_constant_volume_apply_prototype_fan_pressure_rise(fan_constant_volume)
    fan_constant_volume.setPressureRise( self.get_standards_constant('fan_constant_volume_pressure_rise_value'))
    return true
  end

  # Sets the fan pressure rise based on the Prototype buildings inputs
  # which are governed by the flow rate coming through the fan
  # and whether the fan lives inside a unit heater, PTAC, etc.
  def fan_variable_volume_apply_prototype_fan_pressure_rise(fan_variable_volume)
    # 1000 Pa for supply fan and 458.33 Pa for return fan (accounts for efficiency differences between two fans)
    if(fan_variable_volume.name.to_s.include?('Supply'))
      sfan_deltaP = self.get_standards_constant('supply_fan_variable_volume_pressure_rise_value')
      fan_variable_volume.setPressureRise(sfan_deltaP)
    elsif(fan_variable_volume.name.to_s.include?('Return'))
      rfan_deltaP = self.get_standards_constant('return_fan_variable_volume_pressure_rise_value')
      fan_variable_volume.setPressureRise(rfan_deltaP)
    end
    return true
  end

  def apply_economizers(climate_zone, model)
    # NECB2011 prescribes ability to provide 100% OA (5.2.2.7-5.2.2.9)
    econ_max_100_pct_oa_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    econ_max_100_pct_oa_sch.setName('Economizer Max OA Fraction 100 pct')
    econ_max_100_pct_oa_sch.defaultDaySchedule.setName('Economizer Max OA Fraction 100 pct Default')
    econ_max_100_pct_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1.0)

    # Check each airloop
    model.getAirLoopHVACs.sort.each do |air_loop|
      if air_loop_hvac_economizer_required?(air_loop) == true
        # If an economizer is required, determine the economizer type
        # in the prototype buildings, which depends on climate zone.
        economizer_type = nil

        # NECB 5.2.2.8 states that economizer can be controlled based on difference betweeen
        # return air temperature and outside air temperature OR return air enthalpy
        # and outside air enthalphy; latter chosen to be consistent with MNECB and CAN-QUEST implementation
        economizer_type = 'DifferentialEnthalpy'
        # Set the economizer type
        # Get the OA system and OA controller
        oa_sys = air_loop.airLoopHVACOutdoorAirSystem
        if oa_sys.is_initialized
          oa_sys = oa_sys.get
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.Model', "#{air_loop.name} is required to have an economizer, but it has no OA system.")
          next
        end
        oa_control = oa_sys.getControllerOutdoorAir
        oa_control.setEconomizerControlType(economizer_type)
      end
    end
  end

  def set_zones_thermostat_schedule_based_on_space_type_schedules(model, runner = nil)
    puts 'in set_zones_thermostat_schedule_based_on_space_type_schedules'
    BTAP.runner_register('DEBUG', 'Start-set_zones_thermostat_schedule_based_on_space_type_schedules', runner)
    model.getThermalZones.sort.each do |zone|
      BTAP.runner_register('DEBUG', "Zone = #{zone.name} Spaces =#{zone.spaces.size} ", runner)
      array = []

      zone.spaces.sort.each do |space|
        schedule_type = determine_necb_schedule_type(space).to_s
        BTAP.runner_register('DEBUG', "space name/type:#{space.name}/#{schedule_type}", runner)

        # if wildcard space type, need to get dominant schedule type
        if '*'.to_s == schedule_type
          dominant_sched_type = determine_dominant_necb_schedule_type(model)
          schedule_type = dominant_sched_type
        end

        array << schedule_type
      end
      array.uniq!
      if array.size > 1
        BTAP.runner_register('Error', "#{zone.name} has spaces with different schedule types. Please ensure that all the spaces are of the same schedule type A to I.", runner)
        return false
      end

      htg_search_string = "NECB-#{array[0]}-Thermostat Setpoint-Heating"
      clg_search_string = "NECB-#{array[0]}-Thermostat Setpoint-Cooling"

      if model.getScheduleRulesetByName(htg_search_string).empty? == false
        htg_sched = model.getScheduleRulesetByName(htg_search_string).get
      else
        BTAP.runner_register('ERROR', "heating_thermostat_setpoint_schedule NECB-#{array[0]} does not exist", runner)
        return false
      end

      if model.getScheduleRulesetByName(clg_search_string).empty? == false
        clg_sched = model.getScheduleRulesetByName(clg_search_string).get
      else
        BTAP.runner_register('ERROR', "cooling_thermostat_setpoint_schedule NECB-#{array[0]} does not exist", runner)
        return false
      end

      name = "NECB-#{array[0]}-Thermostat Dual Setpoint Schedule"

      # If dual setpoint already exists, use that one, else create one
      ds = if model.getThermostatSetpointDualSetpointByName(name).empty? == false
             model.getThermostatSetpointDualSetpointByName(name).get
           else
             BTAP::Resources::Schedules.create_annual_thermostat_setpoint_dual_setpoint(model, name, htg_sched, clg_sched)
           end

      thermostat_clone = ds.clone.to_ThermostatSetpointDualSetpoint.get
      zone.setThermostatSetpointDualSetpoint(thermostat_clone)
      BTAP.runner_register('Info', "ThermalZone #{zone.name} set to DualSetpoint Schedule NECB-#{array[0]}", runner)
    end

    BTAP.runner_register('DEBUG', 'END-set_zones_thermostat_schedule_based_on_space_type_schedules', runner)
    return true
  end

  # Helper method to find out which climate zone set contains a specific climate zone.
  # Returns climate zone set name as String if success, nil if not found.
  def model_find_climate_zone_set(model, clim)
    return "NECB-CNEB ClimatZone 4-8"
  end

  def add_sys1_unitary_ac_baseboard_heating(model, zones, boiler_fueltype, mau, mau_heating_coil_type, baseboard_type, hw_loop)
    # System Type 1: PTAC with no heating (unitary AC)
    # Zone baseboards, electric or hot water depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # PSZ to represent make-up air unit (if present)
    # This measure creates:
    # a PTAC  unit for each zone in the building; DX cooling coil
    # and heating coil that is always off
    # Baseboards ("Hot Water or "Electric") in zones connected to hot water loop
    # MAU is present if argument mau == true, not present if argument mau == false
    # MAU is PSZ; DX cooling
    # MAU heating coil: hot water coil or electric, depending on argument mau_heating_coil_type
    # mau_heating_coil_type choices are "Hot Water", "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    # Some system parameters are set after system is set up; by applying method 'apply_hvac_efficiency_standard'

    always_on = model.alwaysOnDiscreteSchedule

    # define always off schedule for ptac heating coil
    always_off = BTAP::Resources::Schedules::StandardSchedules::ON_OFF.always_off(model)

    # Create MAU
    # TO DO: MAU sizing, characteristics (fan operation schedules, temperature setpoints, outdoor air, etc)

    if mau == true

      mau_air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      mau_air_loop.setName('Make-up air unit')

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = mau_air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn('VentilationRequirement')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(13.0)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43)
      air_loop_sizing.setSizingOption('NonCoincident')
      air_loop_sizing.setAllOutdoorAirinCooling(true)
      air_loop_sizing.setAllOutdoorAirinHeating(true)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

      mau_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      if mau_heating_coil_type == 'Electric' # electric coil
        mau_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
      end

      if mau_heating_coil_type == 'Hot Water'
        mau_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
        hw_loop.addDemandBranchForComponent(mau_htg_coil)
      end

      # Set up DX coil with default curves (set to NECB);

      mau_clg_coil = BTAP::Resources::HVAC::Plant.add_onespeed_DX_coil(model, always_on)

      # oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      # oa_controller.setEconomizerControlType("DifferentialEnthalpy")

      # oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = mau_air_loop.supplyInletNode
      mau_fan.addToNode(supply_inlet_node)
      mau_htg_coil.addToNode(supply_inlet_node)
      mau_clg_coil.addToNode(supply_inlet_node)
      oa_system.addToNode(supply_inlet_node)

      # Add a setpoint manager to control the supply air temperature
      sat = 20.0
      sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      sat_sch.setName('Makeup-Air Unit Supply Air Temp')
      sat_sch.defaultDaySchedule.setName('Makeup Air Unit Supply Air Temp Default')
      sat_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), sat)
      setpoint_mgr = OpenStudio::Model::SetpointManagerScheduled.new(model, sat_sch)
      setpoint_mgr.addToNode(mau_air_loop.supplyOutletNode)

    end # Create MAU

    # Create a PTAC for each zone:
    # PTAC DX Cooling with electric heating coil; electric heating coil is always off

    # TO DO: need to apply this system to space types:
    # (1) data processing area: control room, data centre
    # when cooling capacity <= 20kW and
    # (2) residential/accommodation: murb, hotel/motel guest room
    # when building/space heated only (this as per NECB; apply to
    # all for initial work? CAN-QUEST limitation)

    # TO DO: PTAC characteristics: sizing, fan schedules, temperature setpoints, interaction with MAU

    zones.each do |zone|
      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      # Set up PTAC heating coil; apply always off schedule

      # htg_coil_elec = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_off)

      # Set up PTAC DX coil with NECB performance curve characteristics;
      clg_coil = BTAP::Resources::HVAC::Plant.add_onespeed_DX_coil(model, always_on)

      # Set up PTAC constant volume supply fan
      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)
      fan.setPressureRise(640)

      ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,
                                                                           always_on,
                                                                           fan,
                                                                           htg_coil,
                                                                           clg_coil)
      ptac.setName("#{zone.name} PTAC")
      ptac.addToThermalZone(zone)

      # add zone baseboards
      if baseboard_type == 'Electric'

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant.add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if baseboard_type == 'Hot Water'
        baseboard_coil = BTAP::Resources::HVAC::Plant.add_hw_baseboard_coil(model)
        # Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)

        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment.add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        # add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)

      end

      #  # Create a diffuser and attach the zone/diffuser pair to the MAU air loop, if applicable
      if mau == true

        diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
        mau_air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      end # components for MAU
    end # of zone loop

    return true
  end

  # sys1_unitary_ac_baseboard_heating

  def add_sys1_unitary_ac_baseboard_heating_multi_speed(model, zones, boiler_fueltype, mau, mau_heating_coil_type, baseboard_type, hw_loop)
    # System Type 1: PTAC with no heating (unitary AC)
    # Zone baseboards, electric or hot water depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # PSZ to represent make-up air unit (if present)
    # This measure creates:
    # a PTAC  unit for each zone in the building; DX cooling coil
    # and heating coil that is always off
    # Baseboards ("Hot Water or "Electric") in zones connected to hot water loop
    # MAU is present if argument mau == true, not present if argument mau == false
    # MAU is PSZ; DX cooling
    # MAU heating coil: hot water coil or electric, depending on argument mau_heating_coil_type
    # mau_heating_coil_type choices are "Hot Water", "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    # Some system parameters are set after system is set up; by applying method 'apply_hvac_efficiency_standard'

    always_on = model.alwaysOnDiscreteSchedule

    # define always off schedule for ptac heating coil
    always_off = BTAP::Resources::Schedules::StandardSchedules::ON_OFF.always_off(model)

    # TODO: Heating and cooling temperature set point schedules are set somewhere else
    # TODO: For now fetch the schedules and use them in setting up the heat pump system
    # TODO: Later on these schedules need to be passed on to this method
    htg_temp_sch = nil
    clg_temp_sch = nil
    zones.each do |izone|
      if izone.thermostat.is_initialized
        zone_thermostat = izone.thermostat.get
        if zone_thermostat.to_ThermostatSetpointDualSetpoint.is_initialized
          dual_thermostat = zone_thermostat.to_ThermostatSetpointDualSetpoint.get
          htg_temp_sch = dual_thermostat.heatingSetpointTemperatureSchedule.get
          clg_temp_sch = dual_thermostat.coolingSetpointTemperatureSchedule.get
          break
        end
      end
    end

    # Create MAU
    # TO DO: MAU sizing, characteristics (fan operation schedules, temperature setpoints, outdoor air, etc)

    if mau == true

      staged_thermostat = OpenStudio::Model::ZoneControlThermostatStagedDualSetpoint.new(model)
      staged_thermostat.setHeatingTemperatureSetpointSchedule(htg_temp_sch)
      staged_thermostat.setNumberofHeatingStages(4)
      staged_thermostat.setCoolingTemperatureSetpointBaseSchedule(clg_temp_sch)
      staged_thermostat.setNumberofCoolingStages(4)

      mau_air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      mau_air_loop.setName('Make-up air unit')

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = mau_air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(12.8)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43.0)
      air_loop_sizing.setSizingOption('NonCoincident')
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

      mau_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      # Multi-stage gas heating coil
      if mau_heating_coil_type == 'Electric' || mau_heating_coil_type == 'Hot Water'

        mau_htg_coil = OpenStudio::Model::CoilHeatingGasMultiStage.new(model)
        mau_htg_stage_1 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        mau_htg_stage_2 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        mau_htg_stage_3 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        mau_htg_stage_4 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)

        if mau_heating_coil_type == 'Electric'

          mau_supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)

        elsif mau_heating_coil_type == 'Hot Water'

          mau_supplemental_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
          hw_loop.addDemandBranchForComponent(mau_supplemental_htg_coil)

        end

        mau_htg_stage_1.setNominalCapacity(0.1)
        mau_htg_stage_2.setNominalCapacity(0.2)
        mau_htg_stage_3.setNominalCapacity(0.3)
        mau_htg_stage_4.setNominalCapacity(0.4)

      end

      # Add stages to heating coil
      mau_htg_coil.addStage(mau_htg_stage_1)
      mau_htg_coil.addStage(mau_htg_stage_2)
      mau_htg_coil.addStage(mau_htg_stage_3)
      mau_htg_coil.addStage(mau_htg_stage_4)

      # TODO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

      # Set up DX cooling coil
      mau_clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      mau_clg_coil.setFuelType('Electricity')
      mau_clg_stage_1 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_stage_2 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_stage_3 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_stage_4 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      mau_clg_coil.addStage(mau_clg_stage_1)
      mau_clg_coil.addStage(mau_clg_stage_2)
      mau_clg_coil.addStage(mau_clg_stage_3)
      mau_clg_coil.addStage(mau_clg_stage_4)

      air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.new(model, mau_fan, mau_htg_coil, mau_clg_coil, mau_supplemental_htg_coil)
      #              air_to_air_heatpump.setName("#{zone.name} ASHP")
      air_to_air_heatpump.setControllingZoneorThermostatLocation(zones[1])
      air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
      air_to_air_heatpump.setNumberofSpeedsforHeating(4)
      air_to_air_heatpump.setNumberofSpeedsforCooling(4)

      # oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)
      # oa_controller.setEconomizerControlType("DifferentialEnthalpy")

      # oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = mau_air_loop.supplyInletNode
      air_to_air_heatpump.addToNode(supply_inlet_node)
      oa_system.addToNode(supply_inlet_node)

    end # Create MAU

    # Create a PTAC for each zone:
    # PTAC DX Cooling with electric heating coil; electric heating coil is always off

    # TO DO: need to apply this system to space types:
    # (1) data processing area: control room, data centre
    # when cooling capacity <= 20kW and
    # (2) residential/accommodation: murb, hotel/motel guest room
    # when building/space heated only (this as per NECB; apply to
    # all for initial work? CAN-QUEST limitation)

    # TO DO: PTAC characteristics: sizing, fan schedules, temperature setpoints, interaction with MAU

    zones.each do |zone|
      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      # Set up PTAC heating coil; apply always off schedule

      # htg_coil_elec = OpenStudio::Model::CoilHeatingElectric.new(model,always_on)
      htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_off)

      # Set up PTAC DX coil with NECB performance curve characteristics;
      clg_coil = BTAP::Resources::HVAC::Plant.add_onespeed_DX_coil(model, always_on)

      # Set up PTAC constant volume supply fan
      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)
      fan.setPressureRise(640)

      ptac = OpenStudio::Model::ZoneHVACPackagedTerminalAirConditioner.new(model,
                                                                           always_on,
                                                                           fan,
                                                                           htg_coil,
                                                                           clg_coil)
      ptac.setName("#{zone.name} PTAC")
      ptac.addToThermalZone(zone)

      # add zone baseboards
      if baseboard_type == 'Electric'

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant.add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if baseboard_type == 'Hot Water'
        baseboard_coil = BTAP::Resources::HVAC::Plant.add_hw_baseboard_coil(model)
        # Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)

        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment.add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        # add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)

      end

      #  # Create a diffuser and attach the zone/diffuser pair to the MAU air loop, if applicable
      if mau == true

        diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
        mau_air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      end # components for MAU
    end # of zone loop

    return true
  end

  # sys1_unitary_ac_baseboard_heating

  def add_sys2_FPFC_sys5_TPFC(model, zones, boiler_fueltype, chiller_type, fan_coil_type, mua_cooling_type, hw_loop)
    # System Type 2: FPFC or System 5: TPFC
    # This measure creates:
    # -a four pipe or a two pipe fan coil unit for each zone in the building;
    # -a make up air-unit to provide ventilation to each zone;
    # -a heating loop, cooling loop and condenser loop to serve four pipe fan coil units
    # Arguments:
    #   boiler_fueltype: "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
    #   chiller_type: "Scroll";"Centrifugal";"Rotary Screw";"Reciprocating"
    #   mua_cooling_type: make-up air unit cooling type "DX";"Hydronic"
    #   fan_coil_type options are "TPFC" or "FPFC"

    # TODO: Add arguments as needed when the sizing routine is finalized. For example we will need to know the
    # required size of the boilers to decide on how many units are needed based on NECB rules.

    always_on = model.alwaysOnDiscreteSchedule

    # schedule for two-pipe fan coil operation

    twenty_four_hrs = OpenStudio::Time.new(0, 24, 0, 0)

    # Heating coil availability schedule for tpfc
    tpfc_htg_availability_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    tpfc_htg_availability_sch.setName('tpfc_htg_availability')
    # Cooling coil availability schedule for tpfc
    tpfc_clg_availability_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    tpfc_clg_availability_sch.setName('tpfc_clg_availability')
    istart_month = [1, 7, 11]
    istart_day = [1, 1, 1]
    iend_month = [6, 10, 12]
    iend_day = [30, 31, 31]
    sch_htg_value = [1, 0, 1]
    sch_clg_value = [0, 1, 0]
    for i in 0..2
      tpfc_htg_availability_sch_rule = OpenStudio::Model::ScheduleRule.new(tpfc_htg_availability_sch)
      tpfc_htg_availability_sch_rule.setName('tpfc_htg_availability_sch_rule')
      tpfc_htg_availability_sch_rule.setStartDate(model.getYearDescription.makeDate(istart_month[i], istart_day[i]))
      tpfc_htg_availability_sch_rule.setEndDate(model.getYearDescription.makeDate(iend_month[i], iend_day[i]))
      tpfc_htg_availability_sch_rule.setApplySunday(true)
      tpfc_htg_availability_sch_rule.setApplyMonday(true)
      tpfc_htg_availability_sch_rule.setApplyTuesday(true)
      tpfc_htg_availability_sch_rule.setApplyWednesday(true)
      tpfc_htg_availability_sch_rule.setApplyThursday(true)
      tpfc_htg_availability_sch_rule.setApplyFriday(true)
      tpfc_htg_availability_sch_rule.setApplySaturday(true)
      day_schedule = tpfc_htg_availability_sch_rule.daySchedule
      day_schedule.setName('tpfc_htg_availability_sch_rule_day')
      day_schedule.addValue(twenty_four_hrs, sch_htg_value[i])

      tpfc_clg_availability_sch_rule = OpenStudio::Model::ScheduleRule.new(tpfc_clg_availability_sch)
      tpfc_clg_availability_sch_rule.setName('tpfc_clg_availability_sch_rule')
      tpfc_clg_availability_sch_rule.setStartDate(model.getYearDescription.makeDate(istart_month[i], istart_day[i]))
      tpfc_clg_availability_sch_rule.setEndDate(model.getYearDescription.makeDate(iend_month[i], iend_day[i]))
      tpfc_clg_availability_sch_rule.setApplySunday(true)
      tpfc_clg_availability_sch_rule.setApplyMonday(true)
      tpfc_clg_availability_sch_rule.setApplyTuesday(true)
      tpfc_clg_availability_sch_rule.setApplyWednesday(true)
      tpfc_clg_availability_sch_rule.setApplyThursday(true)
      tpfc_clg_availability_sch_rule.setApplyFriday(true)
      tpfc_clg_availability_sch_rule.setApplySaturday(true)
      day_schedule = tpfc_clg_availability_sch_rule.daySchedule
      day_schedule.setName('tpfc_clg_availability_sch_rule_day')
      day_schedule.addValue(twenty_four_hrs, sch_clg_value[i])

    end

    # Create a chilled water loop

    chw_loop = OpenStudio::Model::PlantLoop.new(model)
    chiller1, chiller2 = BTAP::Resources::HVAC::HVACTemplates::NECB2011.setup_chw_loop_with_components(model, chw_loop, chiller_type)

    # Create a condenser Loop

    cw_loop = OpenStudio::Model::PlantLoop.new(model)
    ctower = BTAP::Resources::HVAC::HVACTemplates::NECB2011.setup_cw_loop_with_components(model, cw_loop, chiller1, chiller2)

    # Set up make-up air unit for ventilation
    # TO DO: Need to investigate characteristics of make-up air unit for NECB reference
    # and define them here

    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

    air_loop.setName('Make-up air unit')

    # When an air_loop is contructed, its constructor creates a sizing:system object
    # the default sizing:system constructor makes a system:sizing object
    # appropriate for a multizone VAV system
    # this systems is a constant volume system with no VAV terminals,
    # and therfore needs different default settings
    air_loop_sizing = air_loop.sizingSystem # TODO units
    air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
    air_loop_sizing.autosizeDesignOutdoorAirFlowRate
    air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
    air_loop_sizing.setPreheatDesignTemperature(7.0)
    air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
    air_loop_sizing.setPrecoolDesignTemperature(13.0)
    air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
    air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
    air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(13.1)
    air_loop_sizing.setSizingOption('NonCoincident')
    air_loop_sizing.setAllOutdoorAirinCooling(false)
    air_loop_sizing.setAllOutdoorAirinHeating(false)
    air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.008)
    air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.008)
    air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
    air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
    air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
    air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
    air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

    fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

    # Assume direct-fired gas heating coil for now; need to add logic
    # to set up hydronic or electric coil depending on proposed?

    htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)

    # Add DX or hydronic cooling coil
    if mua_cooling_type == 'DX'
      clg_coil = BTAP::Resources::HVAC::Plant.add_onespeed_DX_coil(model, tpfc_clg_availability_sch)
    elsif mua_cooling_type == 'Hydronic'
      clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, tpfc_clg_availability_sch)
      chw_loop.addDemandBranchForComponent(clg_coil)
    end

    # does MAU have an economizer?
    oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

    # oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

    # Add the components to the air loop
    # in order from closest to zone to furthest from zone
    supply_inlet_node = air_loop.supplyInletNode
    fan.addToNode(supply_inlet_node)
    htg_coil.addToNode(supply_inlet_node)
    clg_coil.addToNode(supply_inlet_node)
    oa_system.addToNode(supply_inlet_node)

    # Add a setpoint manager single zone reheat to control the
    # supply air temperature based on the needs of default zone (OpenStudio picks one)
    # TO DO: need to have method to pick appropriate control zone?

    setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
    setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(13.0)
    setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(13.1)
    setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

    # Set up FC (ZoneHVAC,cooling coil, heating coil, fan) in each zone

    zones.each do |zone|
      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      # fc supply fan
      fc_fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      if fan_coil_type == 'FPFC'
        # heating coil
        fc_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)

        # cooling coil
        fc_clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, always_on)
      elsif fan_coil_type == 'TPFC'
        # heating coil
        fc_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, tpfc_htg_availability_sch)

        # cooling coil
        fc_clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, tpfc_clg_availability_sch)
      end

      # connect heating coil to hot water loop
      hw_loop.addDemandBranchForComponent(fc_htg_coil)
      # connect cooling coil to chilled water loop
      chw_loop.addDemandBranchForComponent(fc_clg_coil)

      zone_fc = OpenStudio::Model::ZoneHVACFourPipeFanCoil.new(model, always_on, fc_fan, fc_clg_coil, fc_htg_coil)
      zone_fc.addToThermalZone(zone)

      # Create a diffuser and attach the zone/diffuser pair to the air loop (make-up air unit)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)
    end # zone loop
  end

  # add_sys2_FPFC_sys5_TPFC

  def add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model, zones, boiler_fueltype, heating_coil_type, baseboard_type, hw_loop)
    # System Type 3: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas", "DX"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    always_on = model.alwaysOnDiscreteSchedule

    zones.each do |zone|
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      air_loop.setName("#{zone.name} NECB System 3 PSZ")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(13.0)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43)
      air_loop_sizing.setSizingOption('NonCoincident')
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      case heating_coil_type
        when 'Electric' # electric coil
          htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)

        when 'Gas'
          htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)

        when 'DX'
          htg_coil = OpenStudio::Model::CoilHeatingDXSingleSpeed.new(model)
          supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          htg_coil.setMinimumOutdoorDryBulbTemperatureforCompressorOperation(-10.0)
          sizing_zone.setZoneHeatingSizingFactor(1.3)
          sizing_zone.setZoneCoolingSizingFactor(1.0)
        else
          raise("#{heating_coil_type} is not a valid heating coil type.)")
      end

      # TO DO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

      # Set up DX coil with NECB performance curve characteristics;
      clg_coil = OpenStudio::Model::CoilCoolingDXSingleSpeed.new(model)

      # oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

      # oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode
      #              fan.addToNode(supply_inlet_node)
      #              supplemental_htg_coil.addToNode(supply_inlet_node) if heating_coil_type == "DX"
      #              htg_coil.addToNode(supply_inlet_node)
      #              clg_coil.addToNode(supply_inlet_node)
      #              oa_system.addToNode(supply_inlet_node)
      if heating_coil_type == 'DX'
        air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir.new(model, always_on, fan, htg_coil, clg_coil, supplemental_htg_coil)
        air_to_air_heatpump.setName("#{zone.name} ASHP")
        air_to_air_heatpump.setControllingZone(zone)
        air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
        air_to_air_heatpump.addToNode(supply_inlet_node)
      else
        fan.addToNode(supply_inlet_node)
        htg_coil.addToNode(supply_inlet_node)
        clg_coil.addToNode(supply_inlet_node)
      end
      oa_system.addToNode(supply_inlet_node)

      # Add a setpoint manager single zone reheat to control the
      # supply air temperature based on the needs of this zone
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)
      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(13)
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(43)
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      # diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      if baseboard_type == 'Electric'

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant.add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if baseboard_type == 'Hot Water'
        baseboard_coil = BTAP::Resources::HVAC::Plant.add_hw_baseboard_coil(model)
        # Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)

        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment.add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        # add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)
      end
    end # zone loop

    return true
  end

  # end add_sys3_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed

  def add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed(model, zones, boiler_fueltype, heating_coil_type, baseboard_type, hw_loop)
    # System Type 3: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas", "DX"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"

    always_on = model.alwaysOnDiscreteSchedule

    # TODO: Heating and cooling temperature set point schedules are set somewhere else
    # TODO: For now fetch the schedules and use them in setting up the heat pump system
    # TODO: Later on these schedules need to be passed on to this method
    htg_temp_sch = nil
    clg_temp_sch = nil
    zones.each do |izone|
      if izone.thermostat.is_initialized
        zone_thermostat = izone.thermostat.get
        if zone_thermostat.to_ThermostatSetpointDualSetpoint.is_initialized
          dual_thermostat = zone_thermostat.to_ThermostatSetpointDualSetpoint.get
          htg_temp_sch = dual_thermostat.heatingSetpointTemperatureSchedule.get
          clg_temp_sch = dual_thermostat.coolingSetpointTemperatureSchedule.get
          break
        end
      end
    end

    zones.each do |zone|
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      air_loop.setName("#{zone.name} NECB System 3 PSZ")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(13.0)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43.0)
      air_loop_sizing.setSizingOption('NonCoincident')
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      staged_thermostat = OpenStudio::Model::ZoneControlThermostatStagedDualSetpoint.new(model)
      staged_thermostat.setHeatingTemperatureSetpointSchedule(htg_temp_sch)
      staged_thermostat.setNumberofHeatingStages(4)
      staged_thermostat.setCoolingTemperatureSetpointBaseSchedule(clg_temp_sch)
      staged_thermostat.setNumberofCoolingStages(4)
      zone.setThermostat(staged_thermostat)

      # Multi-stage gas heating coil
      if heating_coil_type == 'Gas' || heating_coil_type == 'Electric'
        htg_coil = OpenStudio::Model::CoilHeatingGasMultiStage.new(model)
        htg_stage_1 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        htg_stage_2 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        htg_stage_3 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        htg_stage_4 = OpenStudio::Model::CoilHeatingGasMultiStageStageData.new(model)
        if heating_coil_type == 'Gas'
          supplemental_htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)
        elsif heating_coil_type == 'Electric'
          supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          htg_stage_1.setNominalCapacity(0.1)
          htg_stage_2.setNominalCapacity(0.2)
          htg_stage_3.setNominalCapacity(0.3)
          htg_stage_4.setNominalCapacity(0.4)
        end

        # Multi-Stage DX or Electric heating coil
      elsif heating_coil_type == 'DX'
        htg_coil = OpenStudio::Model::CoilHeatingDXMultiSpeed.new(model)
        htg_stage_1 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        htg_stage_2 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        htg_stage_3 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        htg_stage_4 = OpenStudio::Model::CoilHeatingDXMultiSpeedStageData.new(model)
        supplemental_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
        sizing_zone.setZoneHeatingSizingFactor(1.3)
        sizing_zone.setZoneCoolingSizingFactor(1.0)
      else
        raise("#{heating_coil_type} is not a valid heating coil type.)")
      end

      # Add stages to heating coil
      htg_coil.addStage(htg_stage_1)
      htg_coil.addStage(htg_stage_2)
      htg_coil.addStage(htg_stage_3)
      htg_coil.addStage(htg_stage_4)

      # TODO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

      # Set up DX cooling coil
      clg_coil = OpenStudio::Model::CoilCoolingDXMultiSpeed.new(model)
      clg_coil.setFuelType('Electricity')
      clg_stage_1 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_stage_2 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_stage_3 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_stage_4 = OpenStudio::Model::CoilCoolingDXMultiSpeedStageData.new(model)
      clg_coil.addStage(clg_stage_1)
      clg_coil.addStage(clg_stage_2)
      clg_coil.addStage(clg_stage_3)
      clg_coil.addStage(clg_stage_4)

      # oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

      # oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode

      air_to_air_heatpump = OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.new(model, fan, htg_coil, clg_coil, supplemental_htg_coil)
      air_to_air_heatpump.setName("#{zone.name} ASHP")
      air_to_air_heatpump.setControllingZoneorThermostatLocation(zone)
      air_to_air_heatpump.setSupplyAirFanOperatingModeSchedule(always_on)
      air_to_air_heatpump.addToNode(supply_inlet_node)
      air_to_air_heatpump.setNumberofSpeedsforHeating(4)
      air_to_air_heatpump.setNumberofSpeedsforCooling(4)

      oa_system.addToNode(supply_inlet_node)

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      # diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      if baseboard_type == 'Electric'

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant.add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if baseboard_type == 'Hot Water'
        baseboard_coil = BTAP::Resources::HVAC::Plant.add_hw_baseboard_coil(model)
        # Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)

        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment.add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        # add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)
      end
    end # zone loop

    return true
  end

  # end add_sys3_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed

  def add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model, zones, boiler_fueltype, heating_coil_type, baseboard_type, hw_loop)
    # System Type 4: PSZ-AC
    # This measure creates:
    # -a constant volume packaged single-zone A/C unit
    # for each zone in the building; DX cooling with
    # heating coil: fuel-fired or electric, depending on argument heating_coil_type
    # heating_coil_type choices are "Electric", "Gas"
    # zone baseboards: hot water or electric, depending on argument baseboard_type
    # baseboard_type choices are "Hot Water" or "Electric"
    # boiler_fueltype choices match OS choices for Boiler component fuel type, i.e.
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
    # NOTE: This is the same as system type 3 (single zone make-up air unit and single zone rooftop unit are both PSZ systems)
    # SHOULD WE COMBINE sys3 and sys4 into one script?

    always_on = model.alwaysOnDiscreteSchedule

    # Create a PSZ for each zone
    # TO DO: need to apply this system to space types:
    # (1) automotive area: repair/parking garage, fire engine room, indoor truck bay
    # (2) supermarket/food service: food preparation with kitchen hood/vented appliance
    # (3) warehouse area (non-refrigerated spaces)

    zones.each do |zone|
      air_loop = OpenStudio::Model::AirLoopHVAC.new(model)

      air_loop.setName("#{zone.name} NECB System 4 PSZ")

      # When an air_loop is constructed, its constructor creates a sizing:system object
      # the default sizing:system constructor makes a system:sizing object
      # appropriate for a multizone VAV system
      # this systems is a constant volume system with no VAV terminals,
      # and therfore needs different default settings
      air_loop_sizing = air_loop.sizingSystem # TODO units
      air_loop_sizing.setTypeofLoadtoSizeOn('Sensible')
      air_loop_sizing.autosizeDesignOutdoorAirFlowRate
      air_loop_sizing.setMinimumSystemAirFlowRatio(1.0)
      air_loop_sizing.setPreheatDesignTemperature(7.0)
      air_loop_sizing.setPreheatDesignHumidityRatio(0.008)
      air_loop_sizing.setPrecoolDesignTemperature(13.0)
      air_loop_sizing.setPrecoolDesignHumidityRatio(0.008)
      air_loop_sizing.setCentralCoolingDesignSupplyAirTemperature(13.0)
      air_loop_sizing.setCentralHeatingDesignSupplyAirTemperature(43.0)
      air_loop_sizing.setSizingOption('NonCoincident')
      air_loop_sizing.setAllOutdoorAirinCooling(false)
      air_loop_sizing.setAllOutdoorAirinHeating(false)
      air_loop_sizing.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
      air_loop_sizing.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
      air_loop_sizing.setCoolingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setCoolingDesignAirFlowRate(0.0)
      air_loop_sizing.setHeatingDesignAirFlowMethod('DesignDay')
      air_loop_sizing.setHeatingDesignAirFlowRate(0.0)
      air_loop_sizing.setSystemOutdoorAirMethod('ZoneSum')

      # Zone sizing temperature
      sizing_zone = zone.sizingZone
      sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
      sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
      sizing_zone.setZoneCoolingSizingFactor(1.1)
      sizing_zone.setZoneHeatingSizingFactor(1.3)

      fan = OpenStudio::Model::FanConstantVolume.new(model, always_on)

      if heating_coil_type == 'Electric' # electric coil
        htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
      end

      if heating_coil_type == 'Gas'
        htg_coil = OpenStudio::Model::CoilHeatingGas.new(model, always_on)
      end

      # TO DO: other fuel-fired heating coil types? (not available in OpenStudio/E+ - may need to play with efficiency to mimic other fuel types)

      # Set up DX coil with NECB performance curve characteristics;

      clg_coil = BTAP::Resources::HVAC::Plant.add_onespeed_DX_coil(model, always_on)

      # oa_controller
      oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

      # oa_system
      oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

      # Add the components to the air loop
      # in order from closest to zone to furthest from zone
      supply_inlet_node = air_loop.supplyInletNode
      fan.addToNode(supply_inlet_node)
      htg_coil.addToNode(supply_inlet_node)
      clg_coil.addToNode(supply_inlet_node)
      oa_system.addToNode(supply_inlet_node)

      # Add a setpoint manager single zone reheat to control the
      # supply air temperature based on the needs of this zone
      setpoint_mgr_single_zone_reheat = OpenStudio::Model::SetpointManagerSingleZoneReheat.new(model)
      setpoint_mgr_single_zone_reheat.setControlZone(zone)
      setpoint_mgr_single_zone_reheat.setMinimumSupplyAirTemperature(13.0)
      setpoint_mgr_single_zone_reheat.setMaximumSupplyAirTemperature(43.0)
      setpoint_mgr_single_zone_reheat.addToNode(air_loop.supplyOutletNode)

      # Create sensible heat exchanger
      #              heat_exchanger = BTAP::Resources::HVAC::Plant::add_hrv(model)
      #              heat_exchanger.setSensibleEffectivenessat100HeatingAirFlow(0.5)
      #              heat_exchanger.setSensibleEffectivenessat75HeatingAirFlow(0.5)
      #              heat_exchanger.setSensibleEffectivenessat100CoolingAirFlow(0.5)
      #              heat_exchanger.setSensibleEffectivenessat75CoolingAirFlow(0.5)
      #              heat_exchanger.setLatentEffectivenessat100HeatingAirFlow(0.0)
      #              heat_exchanger.setLatentEffectivenessat75HeatingAirFlow(0.0)
      #              heat_exchanger.setLatentEffectivenessat100CoolingAirFlow(0.0)
      #              heat_exchanger.setLatentEffectivenessat75CoolingAirFlow(0.0)
      #              heat_exchanger.setSupplyAirOutletTemperatureControl(false)
      #
      #              Connect heat exchanger
      #              oa_node = oa_system.outboardOANode
      #              heat_exchanger.addToNode(oa_node.get)

      # Create a diffuser and attach the zone/diffuser pair to the air loop
      # diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model,always_on)
      diffuser = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, always_on)
      air_loop.addBranchForZone(zone, diffuser.to_StraightComponent)

      if baseboard_type == 'Electric'

        #  zone_elec_baseboard = OpenStudio::Model::ZoneHVACBaseboardConvectiveElectric.new(model)
        zone_elec_baseboard = BTAP::Resources::HVAC::Plant.add_elec_baseboard(model)
        zone_elec_baseboard.addToThermalZone(zone)

      end

      if baseboard_type == 'Hot Water'
        baseboard_coil = BTAP::Resources::HVAC::Plant.add_hw_baseboard_coil(model)
        # Connect baseboard coil to hot water loop
        hw_loop.addDemandBranchForComponent(baseboard_coil)

        zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment.add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
        # add zone_baseboard to zone
        zone_baseboard.addToThermalZone(zone)
      end
    end # zone loop

    return true
  end

  # end add_sys4_single_zone_make_up_air_unit_with_baseboard_heating

  def add_sys6_multi_zone_built_up_system_with_baseboard_heating(model, zones, boiler_fueltype, heating_coil_type, baseboard_type, chiller_type, fan_type, hw_loop)
    # System Type 6: VAV w/ Reheat
    # This measure creates:
    # a single hot water loop with a natural gas or electric boiler or for the building
    # a single chilled water loop with water cooled chiller for the building
    # a single condenser water loop for heat rejection from the chiller
    # a VAV system w/ hot water or electric heating, chilled water cooling, and
    # hot water or electric reheat for each story of the building
    # Arguments:
    # "boiler_fueltype" choices match OS choices for boiler fuel type:
    # "NaturalGas","Electricity","PropaneGas","FuelOil#1","FuelOil#2","Coal","Diesel","Gasoline","OtherFuel1"
    # "heating_coil_type": "Electric" or "Hot Water"
    # "baseboard_type": "Electric" and "Hot Water"
    # "chiller_type": "Scroll";"Centrifugal";""Screw";"Reciprocating"
    # "fan_type": "AF_or_BI_rdg_fancurve";"AF_or_BI_inletvanes";"fc_inletvanes";"var_speed_drive"

    always_on = model.alwaysOnDiscreteSchedule

    # Chilled Water Plant

    chw_loop = OpenStudio::Model::PlantLoop.new(model)
    chiller1, chiller2 = BTAP::Resources::HVAC::HVACTemplates::NECB2011.setup_chw_loop_with_components(model, chw_loop, chiller_type)

    # Condenser System

    cw_loop = OpenStudio::Model::PlantLoop.new(model)
    ctower = BTAP::Resources::HVAC::HVACTemplates::NECB2011.setup_cw_loop_with_components(model, cw_loop, chiller1, chiller2)

    # Make a Packaged VAV w/ PFP Boxes for each story of the building
    model.getBuildingStorys.sort.each do |story|
      unless (BTAP::Geometry::BuildingStoreys.get_zones_from_storey(story) & zones).empty?

        air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
        air_loop.setName('VAV with Reheat')
        sizing_system = air_loop.sizingSystem
        sizing_system.setCentralCoolingDesignSupplyAirTemperature(13.0)
        sizing_system.setCentralHeatingDesignSupplyAirTemperature(13.1)
        sizing_system.autosizeDesignOutdoorAirFlowRate
        sizing_system.setMinimumSystemAirFlowRatio(0.3)
        sizing_system.setPreheatDesignTemperature(7.0)
        sizing_system.setPreheatDesignHumidityRatio(0.008)
        sizing_system.setPrecoolDesignTemperature(13.0)
        sizing_system.setPrecoolDesignHumidityRatio(0.008)
        sizing_system.setSizingOption('NonCoincident')
        sizing_system.setAllOutdoorAirinCooling(false)
        sizing_system.setAllOutdoorAirinHeating(false)
        sizing_system.setCentralCoolingDesignSupplyAirHumidityRatio(0.0085)
        sizing_system.setCentralHeatingDesignSupplyAirHumidityRatio(0.0080)
        sizing_system.setCoolingDesignAirFlowMethod('DesignDay')
        sizing_system.setCoolingDesignAirFlowRate(0.0)
        sizing_system.setHeatingDesignAirFlowMethod('DesignDay')
        sizing_system.setHeatingDesignAirFlowRate(0.0)
        sizing_system.setSystemOutdoorAirMethod('ZoneSum')

        supply_fan = OpenStudio::Model::FanVariableVolume.new(model, always_on)
        supply_fan.setName('Sys6 Supply Fan')
        return_fan = OpenStudio::Model::FanVariableVolume.new(model, always_on)
        return_fan.setName('Sys6 Return Fan')

        if heating_coil_type == 'Hot Water'
          htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
          hw_loop.addDemandBranchForComponent(htg_coil)
        end
        if heating_coil_type == 'Electric'
          htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
        end

        clg_coil = OpenStudio::Model::CoilCoolingWater.new(model, always_on)
        chw_loop.addDemandBranchForComponent(clg_coil)

        oa_controller = OpenStudio::Model::ControllerOutdoorAir.new(model)

        oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model, oa_controller)

        # Add the components to the air loop
        # in order from closest to zone to furthest from zone
        supply_inlet_node = air_loop.supplyInletNode
        supply_outlet_node = air_loop.supplyOutletNode
        supply_fan.addToNode(supply_inlet_node)
        htg_coil.addToNode(supply_inlet_node)
        clg_coil.addToNode(supply_inlet_node)
        oa_system.addToNode(supply_inlet_node)
        returnAirNode = oa_system.returnAirModelObject.get.to_Node.get
        return_fan.addToNode(returnAirNode)

        # Add a setpoint manager to control the
        # supply air to a constant temperature
        sat_c = 13.0
        sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
        sat_sch.setName('Supply Air Temp')
        sat_sch.defaultDaySchedule.setName('Supply Air Temp Default')
        sat_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), sat_c)
        sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, sat_sch)
        sat_stpt_manager.addToNode(supply_outlet_node)

        # Make a VAV terminal with HW reheat for each zone on this story that is in intersection with the zones array.
        # and hook the reheat coil to the HW loop
        (BTAP::Geometry::BuildingStoreys.get_zones_from_storey(story) & zones).each do |zone|
          # Zone sizing parameters
          sizing_zone = zone.sizingZone
          sizing_zone.setZoneCoolingDesignSupplyAirTemperature(13.0)
          sizing_zone.setZoneHeatingDesignSupplyAirTemperature(43.0)
          sizing_zone.setZoneCoolingSizingFactor(1.1)
          sizing_zone.setZoneHeatingSizingFactor(1.3)

          if heating_coil_type == 'Hot Water'
            reheat_coil = OpenStudio::Model::CoilHeatingWater.new(model, always_on)
            hw_loop.addDemandBranchForComponent(reheat_coil)
          elsif heating_coil_type == 'Electric'
            reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model, always_on)
          end

          vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model, always_on, reheat_coil)
          air_loop.addBranchForZone(zone, vav_terminal.to_StraightComponent)
          # NECB2011 minimum zone airflow setting
          min_flow_rate = 0.002 * zone.floorArea
          vav_terminal.setFixedMinimumAirFlowRate(min_flow_rate)
          vav_terminal.setMaximumReheatAirTemperature(43.0)
          vav_terminal.setDamperHeatingAction('Normal')

          # Set zone baseboards
          if baseboard_type == 'Electric'
            zone_elec_baseboard = BTAP::Resources::HVAC::Plant.add_elec_baseboard(model)
            zone_elec_baseboard.addToThermalZone(zone)
          end
          if baseboard_type == 'Hot Water'
            baseboard_coil = BTAP::Resources::HVAC::Plant.add_hw_baseboard_coil(model)
            # Connect baseboard coil to hot water loop
            hw_loop.addDemandBranchForComponent(baseboard_coil)
            zone_baseboard = BTAP::Resources::HVAC::ZoneEquipment.add_zone_baseboard_convective_water(model, always_on, baseboard_coil)
            # add zone_baseboard to zone
            zone_baseboard.addToThermalZone(zone)
          end
        end
      end
    end # next story

    # for debugging
    # puts "end add_sys6_multi_zone_built_up_with_baseboard_heating"

    return true
  end

  def setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, pump_flow_sch)
    hw_loop.setName('Hot Water Loop')
    sizing_plant = hw_loop.sizingPlant
    sizing_plant.setLoopType('Heating')
    sizing_plant.setDesignLoopExitTemperature(82.0) # TODO: units
    sizing_plant.setLoopDesignTemperatureDifference(16.0)

    # pump (set to variable speed for now till fix to run away plant temperature is found)
    # pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    pump = OpenStudio::Model::PumpVariableSpeed.new(model)
    # TODO: the keyword "setPumpFlowRateSchedule" does not seem to work. A message
    # was sent to NREL to let them know about this. Once there is a fix for this,
    # use the proper pump schedule depending on whether we have two-pipe or four-pipe
    # fan coils.
    #            pump.resetPumpFlowRateSchedule()
    #            pump.setPumpFlowRateSchedule(pump_flow_sch)

    # boiler
    boiler1 = OpenStudio::Model::BoilerHotWater.new(model)
    boiler2 = OpenStudio::Model::BoilerHotWater.new(model)
    boiler1.setFuelType(boiler_fueltype)
    boiler2.setFuelType(boiler_fueltype)
    boiler1.setName('Primary Boiler')
    boiler2.setName('Secondary Boiler')

    # boiler_bypass_pipe
    boiler_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # supply_outlet_pipe
    supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # Add the components to the hot water loop
    hw_supply_inlet_node = hw_loop.supplyInletNode
    hw_supply_outlet_node = hw_loop.supplyOutletNode
    pump.addToNode(hw_supply_inlet_node)

    hw_loop.addSupplyBranchForComponent(boiler1)
    hw_loop.addSupplyBranchForComponent(boiler2)
    hw_loop.addSupplyBranchForComponent(boiler_bypass_pipe)
    supply_outlet_pipe.addToNode(hw_supply_outlet_node)

    # Add a setpoint manager to control the
    # hot water based on outdoor temperature
    hw_oareset_stpt_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
    hw_oareset_stpt_manager.setControlVariable('Temperature')
    hw_oareset_stpt_manager.setSetpointatOutdoorLowTemperature(82.0)
    hw_oareset_stpt_manager.setOutdoorLowTemperature(-16.0)
    hw_oareset_stpt_manager.setSetpointatOutdoorHighTemperature(60.0)
    hw_oareset_stpt_manager.setOutdoorHighTemperature(0.0)
    hw_oareset_stpt_manager.addToNode(hw_supply_outlet_node)
  end

  # of setup_hw_loop_with_components

  def setup_chw_loop_with_components(model, chw_loop, chiller_type)
    chw_loop.setName('Chilled Water Loop')
    sizing_plant = chw_loop.sizingPlant
    sizing_plant.setLoopType('Cooling')
    sizing_plant.setDesignLoopExitTemperature(7.0)
    sizing_plant.setLoopDesignTemperatureDifference(6.0)

    # pump = OpenStudio::Model::PumpConstantSpeed.new(model)
    chw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)

    chiller1 = OpenStudio::Model::ChillerElectricEIR.new(model)
    chiller2 = OpenStudio::Model::ChillerElectricEIR.new(model)
    chiller1.setCondenserType('WaterCooled')
    chiller2.setCondenserType('WaterCooled')
    chiller1_name = "Primary Chiller WaterCooled #{chiller_type}"
    chiller1.setName(chiller1_name)
    chiller2_name = "Secondary Chiller WaterCooled #{chiller_type}"
    chiller2.setName(chiller2_name)

    chiller_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    chw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # Add the components to the chilled water loop
    chw_supply_inlet_node = chw_loop.supplyInletNode
    chw_supply_outlet_node = chw_loop.supplyOutletNode
    chw_pump.addToNode(chw_supply_inlet_node)
    chw_loop.addSupplyBranchForComponent(chiller1)
    chw_loop.addSupplyBranchForComponent(chiller2)
    chw_loop.addSupplyBranchForComponent(chiller_bypass_pipe)
    chw_supply_outlet_pipe.addToNode(chw_supply_outlet_node)

    # Add a setpoint manager to control the
    # chilled water to a constant temperature
    chw_t_c = 7.0
    chw_t_sch = BTAP::Resources::Schedules.create_annual_constant_ruleset_schedule(model, 'CHW Temp', 'Temperature', chw_t_c)
    chw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, chw_t_sch)
    chw_t_stpt_manager.addToNode(chw_supply_outlet_node)

    return chiller1, chiller2
  end

  # of setup_chw_loop_with_components

  def setup_cw_loop_with_components(model, cw_loop, chiller1, chiller2)
    cw_loop.setName('Condenser Water Loop')
    cw_sizing_plant = cw_loop.sizingPlant
    cw_sizing_plant.setLoopType('Condenser')
    cw_sizing_plant.setDesignLoopExitTemperature(29.0)
    cw_sizing_plant.setLoopDesignTemperatureDifference(6.0)

    cw_pump = OpenStudio::Model::PumpConstantSpeed.new(model)

    clg_tower = OpenStudio::Model::CoolingTowerSingleSpeed.new(model)

    # TO DO: Need to define and set cooling tower curves

    clg_tower_bypass_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    cw_supply_outlet_pipe = OpenStudio::Model::PipeAdiabatic.new(model)

    # Add the components to the condenser water loop
    cw_supply_inlet_node = cw_loop.supplyInletNode
    cw_supply_outlet_node = cw_loop.supplyOutletNode
    cw_pump.addToNode(cw_supply_inlet_node)
    clg_tower.setDesignInletAirWetBulbTemperature(24.0)
    clg_tower.setDesignInletAirDryBulbTemperature(35.0)
    clg_tower.setDesignApproachTemperature(5.0)
    clg_tower.setDesignRangeTemperature(6.0)
    cw_loop.addSupplyBranchForComponent(clg_tower)
    cw_loop.addSupplyBranchForComponent(clg_tower_bypass_pipe)
    cw_supply_outlet_pipe.addToNode(cw_supply_outlet_node)
    cw_loop.addDemandBranchForComponent(chiller1)
    cw_loop.addDemandBranchForComponent(chiller2)

    # Add a setpoint manager to control the
    # condenser water to constant temperature
    cw_t_c = 29.0
    cw_t_sch = BTAP::Resources::Schedules.create_annual_constant_ruleset_schedule(model, 'CW Temp', 'Temperature', cw_t_c)
    cw_t_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model, cw_t_sch)
    cw_t_stpt_manager.addToNode(cw_supply_outlet_node)

    return clg_tower
  end

  def necb_spacetype_system_selection(model, heating_design_load = nil, cooling_design_load = nil)
    spacezoning_data = Struct.new(
        :space, # the space object
        :space_name, # the space name
        :building_type_name, # space type name
        :space_type_name, # space type name
        :necb_hvac_system_selection_type, #
        :system_number, # the necb system type
        :number_of_stories, # number of stories
        :horizontal_placement, # the horizontal placement (norht, south, east, west, core)
        :vertical_placment, # the vertical placement ( ground, top, both, middle )
        :people_obj, # Spacetype people object
        :heating_capacity,
        :cooling_capacity,
        :is_dwelling_unit, # Checks if it is a dwelling unit.
        :is_wildcard
    )

    # Array to store schedule objects
    schedule_type_array = []


    # find the number of stories in the model this include multipliers.
    number_of_stories = model.getBuilding.standardsNumberOfAboveGroundStories
    if number_of_stories.empty?
      raise 'Number of above ground stories not present in geometry model. Please ensure this is defined in your Building Object'
    else
      number_of_stories = number_of_stories.get
    end

    # set up system array containers. These will contain the spaces associated with the system types.
    space_zoning_data_array = []

    # First pass of spaces to collect information into the space_zoning_data_array .
    model.getSpaces.sort.each do |space|
      # this will get the spacetype system index 8.4.4.8A  from the SpaceTypeData and BuildingTypeData in  (1-12)
      space_system_index = nil
      if space.spaceType.empty?
        space_system_index = nil
      else
        # gets row information from standards spreadsheet.
        space_type_property = model_find_object(standards_data['space_types'], 'template' => @template, 'space_type' => space.spaceType.get.standardsSpaceType.get, 'building_type' => space.spaceType.get.standardsBuildingType.get)
        raise("could not find necb system selection type for space: #{space.name} and spacetype #{space.spaceType.get.standardsSpaceType.get}") if space_type_property.nil?
        # stores the Building or SpaceType System type name.
        necb_hvac_system_selection_type = space_type_property['necb_hvac_system_selection_type']
        # Check if the NECB HVAC system selection type name was found in the standards data
        if necb_hvac_system_selection_type.nil?
          raise "#{space.name} does not have an NECB system association. Please define a NECB HVAC System Selection Type in the google docs standards database."
        end
      end

      # Get the heating and cooling load for the space. Only Zones with a defined thermostat will have a load.
      # Make sure we don't have sideeffects by changing the argument variables.
      cooling_load = cooling_design_load
      heating_load = heating_design_load
      if space.spaceType.get.standardsSpaceType.get == '- undefined -'
        cooling_load = 0.0
        heating_load = 0.0
      else
        cooling_load = space.thermalZone.get.coolingDesignLoad.get * space.floorArea * space.multiplier / 1000.0 if cooling_load.nil?
        heating_load = space.thermalZone.get.heatingDesignLoad.get * space.floorArea * space.multiplier / 1000.0 if heating_load.nil?
      end

      # identify space-system_index and assign the right NECB system type 1-7.

      # Check if there is an hvac system selection category associated with the space.
      if necb_hvac_system_selection_type.nil?
        raise "#{space.name} does not have an NECB system association. Please define a NECB HVAC System Selection Type in the google docs standards database."
      end

      system = nil
      is_dwelling_unit = false
      is_wildcard = nil

      # Get the NECB HVAC system selection table from standards_data which was ultimately read from necb_hvac_system_selection.JSON
      necb_hvac_system_selection_table = []
      necb_hvac_system_selection_table = standards_data['necb_hvac_system_selection_type']['table']

      # Using cooling_design_load as a selection criteria for necb hvac system section.  Set to zero to avoid triggering an exception in the
      # main selection loop
      necb_hvac_system_selection_cooling_desg_load = 0
      unless cooling_design_load.nil?
        necb_hvac_system_selection_cooling_desg_load = cooling_design_load
      end

      # Make sure that we loaded the necb_hvac_system_selection_type.json file properly and that the information is stored in standards_data
      if necb_hvac_system_selection_table.empty?
        raise("Could not find necb system selection type table. Please make sure that the necb_havc_system_selection_type.json file is present")
      else
        # Loop through the NECB HVAC system selection table entries read from necb_hvac_system_selection_type table.JSON
        # Look for the entry with the same type name that fits within the appropriate number of stories and cooling capacity criteria
        # If one fits then read the associated HVAC system type number and check if it is defined as a dwelling unit or wildcard
        necb_hvac_system_selection_table.each do |necb_hvac_system_select|
          if necb_hvac_system_select['necb_hvac_system_selection_type'] == necb_hvac_system_selection_type and necb_hvac_system_select['min_stories'] <= number_of_stories && necb_hvac_system_select['max_stories'] >= number_of_stories and necb_hvac_system_select['min_cooling_capacity_kw'] <= necb_hvac_system_selection_cooling_desg_load && necb_hvac_system_select['max_cooling_capacity_kw'] >= necb_hvac_system_selection_cooling_desg_load
            system = necb_hvac_system_select['system_type']
            is_dwelling_unit = necb_hvac_system_select['dwelling']
            if necb_hvac_system_select['necb_hvac_system_selection_type']=='Wildcard'
              is_wildcard = true
            end
            break
          end
        end
      end

      # If the previous loop could not find an appropriate NECB HVAC system selection type then "system" will be defined by either nil, 0, or 'Wildcard'.
      # If 'Wildcard' then the system remains at nil but is_wildard is true and the HVAC is dealt with elsewhere
      # If 0, then the system will be treated as - undefined -.  Otherwise no system has been chosen so an error will be returned.
      if system.nil? and is_wildcard.nil?
        if necb_hvac_system_selection_type == 0
          system = 0
        else
          raise "NECB HVAC System Selection Type #{necb_hvac_system_selection_type} not valid"
        end
      end

      # get placement on floor, core or perimeter and if a top, bottom, middle or single story.
      horizontal_placement, vertical_placement = BTAP::Geometry::Spaces.get_space_placement(space)
      # dump all info into an array for debugging and iteration.
      unless space.spaceType.empty?
        space_type_name = space.spaceType.get.standardsSpaceType.get
        building_type_name = space.spaceType.get.standardsBuildingType.get
        space_zoning_data_array << spacezoning_data.new(space,
                                                        space.name.get,
                                                        building_type_name,
                                                        space_type_name,
                                                        necb_hvac_system_selection_type,
                                                        system,
                                                        number_of_stories,
                                                        horizontal_placement,
                                                        vertical_placement,
                                                        space.spaceType.get.people,
                                                        heating_load,
                                                        cooling_load,
                                                        is_dwelling_unit,
                                                        is_wildcard)
        schedule_type_array << determine_necb_schedule_type(space).to_s
      end
    end

    return schedule_type_array.uniq!, space_zoning_data_array
  end

  # This method will take a model that uses NECB2011 spacetypes , and..
  # 1. Create a building story schema.
  # 2. Remove all existing Thermal Zone defintions.
  # 3. Create new thermal zones based on the following definitions.
  # Rule1 all zones must contain only the same schedule / occupancy schedule.
  # Rule2 zones must cater to similar solar gains (N,E,S,W)
  # Rule3 zones must not pass from floor to floor. They must be contained to a single floor or level.
  # Rule4 Wildcard spaces will be associated with the nearest zone of similar schedule type in which is shared most of it's internal surface with.
  # Rule5 For NECB zones must contain spaces of similar system type only.
  # Rule6 Residential / dwelling units must not share systems with other space types.
  # @author phylroy.lopez@nrcan.gc.ca
  # @param model [OpenStudio::model::Model] A model object
  # @return [String] system_zone_array
  def necb_autozone_and_autosystem(
      model = nil,
      runner = nil,
      use_ideal_air_loads = false,
      system_fuel_defaults
  )

    # Create a data struct for the space to system to placement information.

    # system assignment.
    unless ['NaturalGas', 'Electricity', 'PropaneGas', 'FuelOil#1', 'FuelOil#2', 'Coal', 'Diesel', 'Gasoline', 'OtherFuel1'].include?(system_fuel_defaults['boiler_fueltype'])
      BTAP.runner_register('ERROR', "boiler_fueltype = #{system_fuel_defaults['boiler_fueltype']}", runner)
      return
    end

    unless [true, false].include?(system_fuel_defaults['mau_type'])
      BTAP.runner_register('ERROR', "mau_type = #{system_fuel_defaults['mau_type']}", runner)
      return
    end

    unless ['Hot Water', 'Electric'].include?(system_fuel_defaults['mau_heating_coil_type'])
      BTAP.runner_register('ERROR', "mau_heating_coil_type = #{system_fuel_defaults['mau_heating_coil_type']}", runner)
      return false
    end

    unless ['Hot Water', 'Electric'].include?(system_fuel_defaults['baseboard_type'])
      BTAP.runner_register('ERROR', "baseboard_type = #{system_fuel_defaults['baseboard_type']}", runner)
      return false
    end

    unless ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating'].include?(system_fuel_defaults['chiller_type'])
      BTAP.runner_register('ERROR', "chiller_type = #{system_fuel_defaults['chiller_type']}", runner)
      return false
    end
    unless ['DX', 'Hydronic'].include?(system_fuel_defaults['mau_cooling_type'])
      BTAP.runner_register('ERROR', "mau_cooling_type = #{system_fuel_defaults['mau_cooling_type']}", runner)
      return false
    end

    unless ['Electric', 'Gas', 'DX'].include?(system_fuel_defaults['heating_coil_type_sys3'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys3 = #{system_fuel_defaults['heating_coil_type_sys3']}", runner)
      return false
    end

    unless ['Electric', 'Gas', 'DX'].include?(system_fuel_defaults['heating_coil_type_sys4'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys4 = #{system_fuel_defaults['heating_coil_type_sys4']}", runner)
      return false
    end

    unless ['Hot Water', 'Electric'].include?(system_fuel_defaults['heating_coil_type_sys6'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys6 = #{system_fuel_defaults['heating_coil_type_sys6']}", runner)
      return false
    end

    unless ['AF_or_BI_rdg_fancurve', 'AF_or_BI_inletvanes', 'fc_inletvanes', 'var_speed_drive'].include?(system_fuel_defaults['fan_type'])
      BTAP.runner_register('ERROR', "fan_type = #{system_fuel_defaults['fan_type']}", runner)
      return false
    end
    # REPEATED CODE!!
    unless ['Electric', 'Hot Water'].include?(system_fuel_defaults['heating_coil_type_sys6'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys6 = #{system_fuel_defaults['heating_coil_type_sys6']}", runner)
      return false
    end
    # REPEATED CODE!!
    unless ['Electric', 'Gas'].include?(system_fuel_defaults['heating_coil_type_sys4'])
      BTAP.runner_register('ERROR', "heating_coil_type_sys4 = #{system_fuel_defaults['heating_coil_type_sys4']}", runner)
      return false
    end

    # Ensure that floors have been assigned by user.
    raise('No building stories have been defined.. User must define building stories and spaces in model.') if model.getBuildingStorys.empty?
    # BTAP::Geometry::BuildingStoreys::auto_assign_stories(model)

    # this method will determine the spaces that should be set to each system
    schedule_type_array, space_zoning_data_array = necb_spacetype_system_selection(model, nil, nil)

    # Deal with Wildcard spaces. Might wish to have logic to do coridors first.
    space_zoning_data_array.sort_by(&:space_name).each do |space_zone_data|
      # If it is a wildcard space.
      if space_zone_data.system_number.nil?
        # iterate through all adjacent spaces from largest shared wall area to smallest.
        # Set system type to match first space system that is not nil.
        adj_spaces = space_get_adjacent_spaces_with_shared_wall_areas(space_zone_data.space, true)
        if adj_spaces.nil?
          puts "Warning: No adjacent spaces for #{space_zone_data.space.name} on same floor, looking for others above and below to set system"
          adj_spaces = space_get_adjacent_spaces_with_shared_wall_areas(space_zone_data.space, false)
        end
        adj_spaces.sort.each do |adj_space|
          # if there are no adjacent spaces. Raise an error.
          raise "Could not determine adj space to space #{space_zone_data.space.name.get}" if adj_space.nil?
          adj_space_data = space_zoning_data_array.find {|data| data.space == adj_space[0]}
          if adj_space_data.system_number.nil?
            next
          else
            space_zone_data.system_number = adj_space_data.system_number
            puts space_zone_data.space.name.get.to_s
            break
          end
        end
        raise "Could not determine adj space system to space #{space_zone_data.space.name.get}" if space_zone_data.system_number.nil?
      end
    end

    # remove any thermal zones used for sizing to start fresh. Should only do this after the above system selection method.
    model.getThermalZones.sort.each(&:remove)

    # now lets apply the rules.
    # Rule1 all zones must contain only the same schedule / occupancy schedule.
    # Rule2 zones must cater to similar solar gains (N,E,S,W)
    # Rule3 zones must not pass from floor to floor. They must be contained to a single floor or level.
    # Rule4 Wildcard spaces will be associated with the nearest zone of similar schedule type in which is shared most of it's internal surface with.
    # Rule5 NECB zones must contain spaces of similar system type only.
    # Rule6 Multiplier zone will be part of the floor and orientation of the base space.
    # Rule7 Residential / dwelling units must not share systems with other space types.
    # Array of system types of Array of Spaces
    system_zone_array = []
    # Lets iterate by system
    (0..7).each do |system_number|
      system_zone_array[system_number] = []
      # iterate by story
      story_counter = 0
      model.getBuildingStorys.sort.each do |story|
        # puts "Story:#{story}"
        story_counter += 1
        # iterate by operation schedule type.
        schedule_type_array.each do |schedule_type|
          # iterate by horizontal location
          ['north', 'east', 'west', 'south', 'core'].each do |horizontal_placement|
            # puts "horizontal_placement:#{horizontal_placement}"
            [true, false].each do |is_dwelling_unit|
              space_array = []
              space_zoning_data_array.each do |space_info|
                # puts "Spacename: #{space_info.space.name}:#{space_info.space.spaceType.get.name}"
                if (space_info.system_number == system_number) &&
                    (space_info.space.buildingStory.get == story) &&
                    (determine_necb_schedule_type(space_info.space).to_s == schedule_type) &&
                    (space_info.horizontal_placement == horizontal_placement) &&
                    (space_info.is_dwelling_unit == is_dwelling_unit)
                  space_array << space_info.space
                end
              end

              # create Thermal Zone if space_array is not empty.
              unless space_array.empty?
                # Process spaces that have multipliers associated with them first.
                # This map define the multipliers for spaces with multipliers not equals to 1
                space_multiplier_map = @space_multiplier_map

                # create new zone and add the spaces to it.
                space_array.each do |space|
                  # Create thermalzone for each space.
                  thermal_zone = OpenStudio::Model::ThermalZone.new(model)
                  # Create a more informative space name.
                  thermal_zone.setName("Sp-#{space.name} Sys-#{system_number} Flr-#{story_counter} Sch-#{schedule_type} HPlcmt-#{horizontal_placement} ZN")
                  # Add zone mulitplier if required.
                  thermal_zone.setMultiplier(space_multiplier_map[space.name.to_s]) unless space_multiplier_map[space.name.to_s].nil?
                  # Space to thermal zone. (for archetype work it is one to one)
                  space.setThermalZone(thermal_zone)
                  # Get thermostat for space type if it already exists.
                  space_type_name = space.spaceType.get.name.get
                  thermostat_name = space_type_name + ' Thermostat'
                  thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
                  if thermostat.empty?
                    OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name} ZN")
                    raise " Thermostat #{thermostat_name} not found for space name: #{space.name}"
                  else
                    thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
                    thermal_zone.setThermostatSetpointDualSetpoint(thermostat_clone)
                  end
                  # Add thermal to zone system number.
                  system_zone_array[system_number] << thermal_zone
                end
              end
            end
          end
        end
      end
    end # system iteration

    # Create and assign the zones to the systems.
    if use_ideal_air_loads == true
      # otherwise use ideal loads.
      model.getThermalZones.sort.each do |thermal_zone|
        thermal_zone_ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
        thermal_zone_ideal_loads.addToThermalZone(thermal_zone)
      end
    else
      hw_loop_needed = false
      system_zone_array.each_with_index do |zones, system_index|
        next if zones.empty?
        if system_index == 1 && (system_fuel_defaults['mau_heating_coil_type'] == 'Hot Water' || system_fuel_defaults['baseboard_type'] == 'Hot Water')
          hw_loop_needed = true
        elsif system_index == 2 || system_index == 5 || system_index == 7
          hw_loop_needed = true
        elsif (system_index == 3 || system_index == 4) && system_fuel_defaults['baseboard_type'] == 'Hot Water'
          hw_loop_needed = true
        elsif system_index == 6 && (system_fuel_defaults['mau_heating_coil_type'] == 'Hot Water' || system_fuel_defaults['baseboard_type'] == 'Hot Water')
          hw_loop_needed = true
        end
        if hw_loop_needed
          break
        end
      end
      if hw_loop_needed
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        setup_hw_loop_with_components( model, hw_loop, system_fuel_defaults['boiler_fueltype'], always_on )
      end
      system_zone_array.each_with_index do |zones, system_index|
        # skip if no thermal zones for this system.
        next if zones.empty?
        case system_index
          when 0, nil
            # Do nothing no system assigned to zone. Used for Unconditioned spaces
          when 1
            add_sys1_unitary_ac_baseboard_heating(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['mau_type'], system_fuel_defaults['mau_heating_coil_type'], system_fuel_defaults['baseboard_type'], hw_loop)
          when 2
            add_sys2_FPFC_sys5_TPFC(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['chiller_type'], 'FPFC', system_fuel_defaults['mau_cooling_type'], hw_loop)
          when 3
            add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['heating_coil_type_sys3'], system_fuel_defaults['baseboard_type'], hw_loop)
          when 4
            add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['heating_coil_type_sys4'], system_fuel_defaults['baseboard_type'], hw_loop)
          when 5
            add_sys2_FPFC_sys5_TPFC(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['chiller_type'], 'TPFC', system_fuel_defaults['mau_cooling_type'], hw_loop)
          when 6
            add_sys6_multi_zone_built_up_system_with_baseboard_heating(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['heating_coil_type_sys6'], system_fuel_defaults['baseboard_type'], system_fuel_defaults['chiller_type'], system_fuel_defaults['fan_type'], hw_loop)
          when 7
            add_sys2_FPFC_sys5_TPFC(model, zones, system_fuel_defaults['boiler_fueltype'], system_fuel_defaults['chiller_type'], 'FPFC', system_fuel_defaults['mau_cooling_type'], hw_loop)
        end
      end
    end
    # Check to ensure that all spaces are assigned to zones except undefined ones.
    errors = []
    model.getSpaces.sort.each do |space|
      if space.thermalZone.empty? && (space.spaceType.get.name.get != 'Space Function - undefined -')
        errors << "space #{space.name} with spacetype #{space.spaceType.get.name.get} was not assigned a thermalzone."
      end
    end
    unless errors.empty?
      raise(" #{errors}")
    end
  end

  # Creates thermal zones to contain each space, as defined for each building in the
  # system_to_space_map inside the Prototype.building_name
  # e.g. (Prototype.secondary_school.rb) file.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  def model_create_thermal_zones(model, space_multiplier_map = nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started creating thermal zones')
    space_multiplier_map = {} if space_multiplier_map.nil?

    # Remove any Thermal zones assigned
    model.getThermalZones.each(&:remove)

    # Create a thermal zone for each space in the self
    model.getSpaces.sort.each do |space|
      zone = OpenStudio::Model::ThermalZone.new(model)
      zone.setName("#{space.name} ZN")
      unless space_multiplier_map[space.name.to_s].nil? || (space_multiplier_map[space.name.to_s] == 1)
        zone.setMultiplier(space_multiplier_map[space.name.to_s])
      end
      space.setThermalZone(zone)

      # Skip thermostat for spaces with no space type
      next if space.spaceType.empty?

      # Add a thermostat
      space_type_name = space.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostat_clone)
          # Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
          ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
          ideal_loads.addToThermalZone(zone)
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished creating thermal zones')
  end


end

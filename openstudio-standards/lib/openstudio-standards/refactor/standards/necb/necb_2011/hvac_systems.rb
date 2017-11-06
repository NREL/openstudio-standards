
class NECB_2011_Model
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
  # @param climate_zone [String] valid choices: 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B',
  # 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C',
  # 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B', 'ASHRAE 169-2006-5C', 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A',
  # 'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B'
  # @return [Bool] returns true if an economizer is required, false if not
  def air_loop_hvac_economizer_required?(air_loop_hvac)
    economizer_required = false

    #need a better way to determine if an economizer is needed.
    return economizer_required if air_loop_hvac.name.to_s.include? 'Outpatient F1'

    # A big number of btu per hr as the minimum requirement
    infinity_btu_per_hr = 999_999_999_999
    minimum_capacity_btu_per_hr = infinity_btu_per_hr

    # Determine if the airloop serves any computer rooms
    # / data centers, which changes the economizer.
    is_dc = false
    if air_loop_hvac_data_center_area_served(air_loop_hvac)  > 0
      is_dc = true
    end

    # Determine the minimum capacity that requires an economizer
    minimum_capacity_btu_per_hr = 68_243 # NECB requires economizer for cooling cap > 20 kW

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

    # The NECB 2011 requirement is that systems with an exhaust heat content > 150 kW require an HRV
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

    # This code modifies erv_required for NECB 2011
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
    # Note that the NECB 2011 specifies using the 2.5% january design temperature
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
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{instvartemplate} #{climate_zone}:  #{air_loop_hvac.name}: DCV is not required for any system.")
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
      if air_loop_hvac.model.version < OpenStudio::VersionString.new('2.0.5')
        damper_action_eplus = 'Reverse'
        # For versions of OpenStudio using E+ 8.7 or higher
      else
        damper_action_eplus = 'ReverseWithLimits'
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
    blr_props = model_find_object( $os_standards['boilers'], search_criteria, capacity_btu_per_hr)
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
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{instvartemplate}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; AFUE = #{min_afue}")
    end

    # If specified as thermal efficiency
    unless blr_props['minimum_thermal_efficiency'].nil?
      thermal_eff = blr_props['minimum_thermal_efficiency']
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{thermal_eff} Thermal Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{instvartemplate}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Thermal Efficiency = #{thermal_eff}")
    end

    # If specified as combustion efficiency
    unless blr_props['minimum_combustion_efficiency'].nil?
      min_comb_eff = blr_props['minimum_combustion_efficiency']
      thermal_eff = combustion_eff_to_thermal_eff(min_comb_eff)
      new_comp_name = "#{boiler_hot_water.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_comb_eff} Combustion Eff"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.BoilerHotWater', "For #{instvartemplate}: #{boiler_hot_water.name}: #{fuel_type} #{fluid_type} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; Combustion Efficiency = #{min_comb_eff}")
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
    chillers = $os_standards['chillers']

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
    chlr_props = model_find_object( chillers, search_criteria, capacity_tons, Date.today)
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
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.ChillerElectricEIR', "For #{instvartemplate}: #{chiller_electric_eir.name}: #{cooling_type} #{condenser_type} #{compressor_type} Capacity = #{capacity_tons.round}tons; COP = #{cop.round(1)} (#{kw_per_ton.round(1)}kW/ton)")

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
    search_criteria['template'] = instvartemplate
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
                 model_find_object( $os_standards['heat_pumps'], search_criteria, capacity_btu_per_hr, Date.today)
               else
                 model_find_object( $os_standards['unitary_acs'], search_criteria, capacity_btu_per_hr, Date.today)
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

    if coil_dx_subcategory(coil_cooling_dx_multi_speed)  == 'PTAC'
      ptac_eer_coeff_1 = ac_props['ptac_eer_coefficient_1']
      ptac_eer_coeff_2 = ac_props['ptac_eer_coefficient_2']
      capacity_btu_per_hr = 7000 if capacity_btu_per_hr < 7000
      capacity_btu_per_hr = 15_000 if capacity_btu_per_hr > 15_000
      ptac_eer = ptac_eer_coeff_1 + (ptac_eer_coeff_2 * capacity_btu_per_hr)
      cop = eer_to_cop(ptac_eer)
      # self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER")
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{ptac_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{ptac_eer}")
    end

    # If specified as SEER
    unless ac_props['minimum_seasonal_energy_efficiency_ratio'].nil?
      min_seer = ac_props['minimum_seasonal_energy_efficiency_ratio']
      cop = seer_to_cop(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER
    unless ac_props['minimum_energy_efficiency_ratio'].nil?
      min_eer = ac_props['minimum_energy_efficiency_ratio']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
    end

    # if specified as SEER (heat pump)
    unless ac_props['minimum_seasonal_efficiency'].nil?
      min_seer = ac_props['minimum_seasonal_efficiency']
      cop = seer_to_cop(min_seer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER"
      #      self.setName("#{self.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_seer}SEER")
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; SEER = #{min_seer}")
    end

    # If specified as EER (heat pump)
    unless ac_props['minimum_full_load_efficiency'].nil?
      min_eer = ac_props['minimum_full_load_efficiency']
      cop = eer_to_cop(min_eer)
      new_comp_name = "#{coil_cooling_dx_multi_speed.name} #{capacity_kbtu_per_hr.round}kBtu/hr #{min_eer}EER"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{instvartemplate}: #{coil_cooling_dx_multi_speed.name}: #{cooling_type} #{heating_type} #{subcategory} Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; EER = #{min_eer}")
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
    motors = $os_standards['motors']

    # Assuming all fan motors are 4-pole ODP
    instvartemplate_mod = instvartemplate.dup
    if fan.class.name == 'OpenStudio::Model::FanConstantVolume'
      instvartemplate_mod += '-CONSTANT'
    elsif fan.class.name == 'OpenStudio::Model::FanVariableVolume'
      instvartemplate_mod += '-VARIABLE'
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
      raise("")
    end

    search_criteria = {
        'template' => instvartemplate_mod,
        'number_of_poles' => 4.0,
        'type' => 'Enclosed'
    }

    # Exception for small fans, including
    # zone exhaust, fan coil, and fan powered terminals.
    # In this case, use the 0.5 HP for the lookup.
    if fan_small_fan?(fan)
      nominal_hp = 0.5
    else
      motor_properties = model_find_object( motors, search_criteria, motor_bhp)
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
    motor_properties = model_find_object( motors, search_criteria, nominal_hp + 0.01)
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

end

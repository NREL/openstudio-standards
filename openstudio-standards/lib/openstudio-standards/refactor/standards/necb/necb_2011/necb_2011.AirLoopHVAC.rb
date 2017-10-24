
# Reopen the OpenStudio class to add methods to apply standards to this object
class NECB_2011_Model < StandardsModel
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
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param climate_zone [String] valid choices: 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B',
  # 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C',
  # 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B', 'ASHRAE 169-2006-5C', 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A',
  # 'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B'
  # @return [Bool] returns true if an economizer is required, false if not
  def air_loop_hvac_economizer_required?(air_loop_hvac, climate_zone)
    economizer_required = false

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
    erv.apply_prototype_nominal_electric_power

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

  # Determine if a system's fans must shut off when
  # not required.
  #
  # @param template [String]
  # @return [Bool] true if required, false if not
  def air_loop_hvac_unoccupied_fan_shutoff_required?(air_loop_hvac)
    shutoff_required = true

    # Systems less than 0.75 HP
    # must turn off when unoccupied.
    minimum_fan_hp = 0.75

    # Determine the system fan horsepower
    total_hp = 0.0
    air_loop_hvac_supply_return_exhaust_relief_fans(air_loop_hvac).each do |fan|
      total_hp += fan_motor_horsepower(fan) 
    end

    # Check the HP exception
    if total_hp < minimum_fan_hp
      shutoff_required = false
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}: Unoccupied fan shutoff not required because system fan HP of #{total_hp.round(2)} HP is less than the minimum threshold of #{minimum_fan_hp} HP.")
    end

    return shutoff_required

    dx_clg = false

    # Check for all DX coil types
    dx_types = [
      'OS_Coil_Cooling_DX_MultiSpeed',
      'OS_Coil_Cooling_DX_TwoSpeed',
      'OS_Coil_Cooling_DX_TwoStageWithHumidityControlMode'
    ]

    air_loop_hvac.supplyComponents.each do |component|
      # Get the object type, getting the internal coil
      # type if inside a unitary system.
      obj_type = component.iddObjectType.valueName.to_s
      case obj_type
      when 'OS_AirLoopHVAC_UnitaryHeatCool_VAVChangeoverBypass'
        component = component.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get
        obj_type = component.coolingCoil.iddObjectType.valueName.to_s
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        obj_type = component.coolingCoil.iddObjectType.valueName.to_s
      when 'OS_AirLoopHVAC_UnitaryHeatPump_AirToAir_MultiSpeed'
        component = component.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get
        obj_type = component.coolingCoil.iddObjectType.valueName.to_s
      when 'OS_AirLoopHVAC_UnitarySystem'
        component = component.to_AirLoopHVACUnitarySystem.get
        if component.coolingCoil.is_initialized
          obj_type = component.coolingCoil.get.iddObjectType.valueName.to_s
        end
      end
      # See if the object type is a DX coil
      if dx_types.include?(obj_type)
        dx_clg = true
        break # Stop if find a DX coil
      end
    end

    return dx_clg
  end
end

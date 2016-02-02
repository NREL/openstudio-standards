
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::AirLoopHVAC


  # Apply multizone vav outdoor air method and
  # adjust multizone VAV damper positions
  # to achieve a system minimum ventilation effectiveness
  # of 0.6 per PNNL.  Hard-size the resulting min OA
  # into the sizing:system object.
  #
  # return [Bool] returns true if successful, false if not
  def apply_multizone_vav_outdoor_air_sizing(template)

    # TODO enable damper position adjustment for legacy IDFS
    if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "Damper positions not modified for DOE Ref Pre-1980 or DOE Ref 1980-2004 vintages.")
      return true
    end
  
    # Only applies to multi-zone vav systems
    if self.is_multizone_vav_system
      self.set_minimum_vav_damper_positions
    end
    
    return true
 
  end  

  # Apply all standard required controls to the airloop
  #
  # @param (see #is_economizer_required)
  # @return [Bool] returns true if successful, false if not
  # @todo optimum start
  # @todo night damper shutoff
  # @todo nightcycle control
  # @todo night fan shutoff
  def apply_standard_controls(template, climate_zone)
    
    # Energy Recovery Ventilation
    if self.is_energy_recovery_ventilator_required(template, climate_zone)
      self.apply_energy_recovery_ventilator
    end
    
    # Economizers
    self.set_economizer_limits(template, climate_zone)
    self.set_economizer_integration(template, climate_zone)    
    
    # Multizone VAV Systems
    if self.is_multizone_vav_system
      
      # VAV Reheat Control
      self.set_vav_damper_action(template)
      
      # Multizone VAV Optimization
      if self.is_multizone_vav_optimization_required(template, climate_zone)
        self.enable_multizone_vav_optimization
      else
        self.disable_multizone_vav_optimization
      end
      
    end
    
    # Single zone systems
    # if self.thermalZones.size == 1
      # self.apply_single_zone_controls(template, climate_zone)
    # end

    # DCV
    if self.is_demand_control_ventilation_required(template, climate_zone)
      self.enable_demand_control_ventilation
    else
      # TODO Need to convert the design spec OA objects
      # to per-area only so that if VRP is enabled we
      # don't get DCV accidentally?  See PNNL Achieving 30% 5.2.2.21,
      # not convinced that this is actually necessary with current E+
      # capabilities.
    end
    
    # SAT reset
    if self.is_supply_air_temperature_reset_required(template, climate_zone)
      self.enable_supply_air_temperature_reset
    end
   
    # Motorized OA damper
    if self.is_motorized_oa_damper_required(template, climate_zone)
      # TODO self.add_motorized_oa_damper
    else
      self.remove_motorized_oa_damper
    end
   
    # TODO Optimum Start
    # for systems exceeding 10,000 cfm
    # need 1.9.0 for this AVM
    
    # TODO night damper shutoff
    
    # TODO night cycle
    
    # TODO night fan shutoff > 0.75 hp
 
  end  

  # Calculate and apply the performance rating method
  # baseline fan power to this air loop.
  # Fan motor efficiency will be set, and then
  # fan pressure rise adjusted so that the
  # fan power is the maximum allowable.
  # Also adjusts the fan power and flow rates
  # of any parallel PIU terminals on the system.
  #
  # @todo Figure out how to split fan power between multiple fans
  # if the proposed model had multiple fans (supply, return, exhaust, etc.)
  # return [Bool] true if successful, false if not.
  def set_performance_rating_method_baseline_fan_power(template)
  
    # Main AHU fans
    
    # Calculate the allowable fan motor bhp
    # for the entire airloop.
    allowable_fan_bhp = self.allowable_system_brake_horsepower(template)

    # Divide the allowable power evenly between the fans
    # on this airloop.
    all_fans = self.supply_return_exhaust_relief_fans   
    allowable_fan_bhp = allowable_fan_bhp / all_fans.size    
    
    # Set the motor efficiencies
    # for all fans based on the calculated
    # allowed brake hp.  Then calculate the allowable
    # fan power for each fan and adjust
    # the fan pressure rise accordingly
    all_fans.each do |fan|
      fan.set_standard_minimum_motor_efficiency(template, allowable_fan_bhp)
      allowable_power_w = allowable_fan_bhp * 746 / fan.motorEfficiency
      fan.adjust_pressure_rise_to_meet_fan_power(allowable_power_w)
    end

    # Fan powered terminal fans
    
    # Adjust each terminal fan
    self.demandComponents.each do |dc|
      next if dc.to_AirTerminalSingleDuctParallelPIUReheat.empty?
      pfp_term = dc.to_AirTerminalSingleDuctParallelPIUReheat.get
      pfp_term.set_performance_rating_method_baseline_fan_power(template)
    end
  
    return true
  
  end
  
  # Determine the fan power limitation pressure drop adjustment
  # Per Table 6.5.3.1.1B
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [Double] fan power limitation pressure drop adjustment
  #   units = horsepower
  # @todo Determine the presence of MERV filters and other stuff in Table 6.5.3.1.1B.  May need to extend AirLoopHVAC data model
  def fan_power_limitation_pressure_drop_adjustment_brake_horsepower(template = "ASHRAE 90.1-2007")
  
    # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = 0
    dsn_air_flow_cfm = 0
    if self.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_air_flow_m3_per_s = self.autosizedDesignSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
    else
      dsn_air_flow_m3_per_s = self.designSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Hard sized Design Supply Air Flow Rate.")
    end  
  
    # TODO determine the presence of MERV filters and other stuff
    # in Table 6.5.3.1.1B
    # perhaps need to extend AirLoopHVAC data model
    has_fully_ducted_return_and_or_exhaust_air_systems = false
    
    # Calculate Fan Power Limitation Pressure Drop Adjustment (in wc)
    fan_pwr_adjustment_in_wc = 0
    
    # Fully ducted return and/or exhaust air systems
    if has_fully_ducted_return_and_or_exhaust_air_systems
      adj_in_wc = 0.5
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC","--Added #{adj_in_wc} in wc for Fully ducted return and/or exhaust air systems")
    end
    
    # Convert the pressure drop adjustment to brake horsepower (bhp)
    # assuming that all supply air passes through all devices
    fan_pwr_adjustment_bhp = fan_pwr_adjustment_in_wc*dsn_air_flow_cfm / 4131
    OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC","For #{self.name}: Fan Power Limitation Pressure Drop Adjustment = #{(fan_pwr_adjustment_bhp.round(2))} bhp")
 
    return fan_pwr_adjustment_bhp
 
  end

  # Determine the allowable fan system brake horsepower
  # Per Table 6.5.3.1.1A
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [Double] allowable fan system brake horsepower
  #   units = horsepower
  def allowable_system_brake_horsepower(template = "ASHRAE 90.1-2007")
  
    # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = 0
    dsn_air_flow_cfm = 0
    if self.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_air_flow_m3_per_s = self.autosizedDesignSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
    else
      dsn_air_flow_m3_per_s = self.designSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Hard sized Design Supply Air Flow Rate.")
    end

    # Get the fan limitation pressure drop adjustment bhp
    fan_pwr_adjustment_bhp = self.fan_power_limitation_pressure_drop_adjustment_brake_horsepower
    
    # Determine the number of zones the system serves
    num_zones_served = self.thermalZones.size
    
    # Get the supply air fan and determine whether VAV or CAV system.
    # Assume that supply air fan is fan closest to the demand outlet node.
    # The fan may be inside of a piece of unitary equipment.
    fan_pwr_limit_type = nil
    self.supplyComponents.reverse.each do |comp|
      if comp.to_FanConstantVolume.is_initialized || comp.to_FanOnOff.is_initialized
        fan_pwr_limit_type = "constant volume"
      elsif comp.to_FanVariableVolume.is_initialized
        fan_pwr_limit_type = "variable volume"
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if fan.to_FanConstantVolume.is_initialized || comp.to_FanOnOff.is_initialized
          fan_pwr_limit_type = "constant volume"
        elsif fan.to_FanVariableVolume.is_initialized
          fan_pwr_limit_type = "variable volume"
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        if fan.to_FanConstantVolume.is_initialized || comp.to_FanOnOff.is_initialized
          fan_pwr_limit_type = "constant volume"
        elsif fan.to_FanVariableVolume.is_initialized
          fan_pwr_limit_type = "variable volume"
        end
      end  
    end
    
    # For 90.1-2010, single-zone VAV systems use the 
    # constant volume limitation per 6.5.3.1.1
    if template == "ASHRAE 90.1-2010" && fan_pwr_limit_type = "variable volume" && num_zones_served == 1
      fan_pwr_limit_type = "constant volume"
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC","For #{self.name}: Using the constant volume limitation because single-zone VAV system.")
    end
    
    # Calculate the Allowable Fan System brake horsepower per Table G3.1.2.9
    allowable_fan_bhp = 0
    if fan_pwr_limit_type == "constant volume"
      allowable_fan_bhp = dsn_air_flow_cfm*0.00094+fan_pwr_adjustment_bhp
    elsif fan_pwr_limit_type == "variable volume"
      allowable_fan_bhp = dsn_air_flow_cfm*0.0013+fan_pwr_adjustment_bhp
    end
    OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC","For #{self.name}: Allowable brake horsepower = #{(allowable_fan_bhp).round(2)} bhp based on #{dsn_air_flow_cfm.round} cfm and #{fan_pwr_adjustment_bhp.round(2)} bhp of adjustment.")
    
    # Calculate and report the total area for debugging/testing
    floor_area_served_m2 = self.floor_area_served
    floor_area_served_ft2 = OpenStudio.convert(floor_area_served_m2, 'm^2', 'ft^2').get
    cfm_per_ft2 = dsn_air_flow_cfm / floor_area_served_ft2
    cfm_per_hp = dsn_air_flow_cfm / allowable_fan_bhp
    OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC","For #{self.name}: area served = #{floor_area_served_ft2.round} ft^2.")
    OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC","For #{self.name}: flow per area = #{cfm_per_ft2.round} cfm/ft^2.")
    OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC","For #{self.name}: flow per hp = #{cfm_per_hp.round} cfm/hp.")
    
    return allowable_fan_bhp

  end

  # Get all of the supply, return, exhaust, and relief fans on this system
  #
  # @return [Array] an array of FanConstantVolume, FanVariableVolume, and FanOnOff objects
  def supply_return_exhaust_relief_fans() 
    
    # Fans on the supply side of the airloop directly, or inside of unitary equipment.
    fans = []
    sup_and_oa_comps = self.supplyComponents
    sup_and_oa_comps += self.oaComponents
    sup_and_oa_comps.each do |comp|
      if comp.to_FanConstantVolume.is_initialized 
        fans << comp.to_FanConstantVolume.get
      elsif comp.to_FanVariableVolume.is_initialized
        fans << comp.to_FanVariableVolume.get
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        sup_fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if sup_fan.to_FanConstantVolume.is_initialized
          fans << sup_fan.to_FanConstantVolume.get
        elsif sup_fan.to_FanOnOff.is_initialized
          fans << sup_fan.to_FanOnOff.get
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        sup_fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        if sup_fan.to_FanConstantVolume.is_initialized
          fans << sup_fan.to_FanConstantVolume.get
        elsif sup_fan.to_FanOnOff.is_initialized
          fans << sup_fan.to_FanOnOff.get
        elsif sup_fan.to_FanVariableVolume.is_initialized
          fans << sup_fan.to_FanVariableVolume.get  
        end      
      end
    end 
    
    return fans
    
  end
  
  # Determine the total brake horsepower of the fans on the system
  # with or without the fans inside of fan powered terminals.
  #
  # @param include_terminal_fans [Bool] if true, power from fan powered terminals will be included
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [Double] total brake horsepower of the fans on the system
  #   units = horsepower  
  def system_fan_brake_horsepower(include_terminal_fans = true, template = "ASHRAE 90.1-2007")

    # TODO get the template from the parent model itself?
    # Or not because maybe you want to see the difference between two standards?
    OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC","#{self.name}-Determining #{template} allowable system fan power.")
  
    # Get all fans
    fans = []
    # Supply, exhaust, relief, and return fans
    fans += self.supply_return_exhaust_relief_fans
    
    # Fans inside of fan-powered terminals
    if include_terminal_fans
      self.demandComponents.each do |comp|
        if comp.to_AirTerminalSingleDuctSeriesPIUReheat.is_initialized
          term_fan = comp.to_AirTerminalSingleDuctSeriesPIUReheat.get.supplyAirFan
          if term_fan.to_FanConstantVolume.is_initialized
            fans << term_fan.to_FanConstantVolume.get
          end
        elsif comp.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized
          term_fan = comp.to_AirTerminalSingleDuctParallelPIUReheat.get.fan
          if term_fan.to_FanConstantVolume.is_initialized
            fans << term_fan.to_FanConstantVolume.get
          end     
        end
      end
    end
    
    # Loop through all fans on the system and
    # sum up their brake horsepower values.
    sys_fan_bhp = 0
    fans.sort.each do |fan|
      sys_fan_bhp += fan.brakeHorsepower
    end
    
    return sys_fan_bhp
   
  end 
  
  # Set the fan pressure rises that will result in
  # the system hitting the baseline allowable fan power
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013' 
  def set_baseline_fan_pressure_rise(template = "ASHRAE 90.1-2007")

    OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "#{self.name}-Setting #{template} baseline fan power.")
  
    # Get the total system bhp from the proposed system, including terminal fans
    proposed_sys_bhp = self.system_fan_brake_horsepower(true)
  
    # Get the allowable fan brake horsepower
    allowable_fan_bhp = self.allowable_system_brake_horsepower(template)

    # Get the fan power limitation from proposed system
    fan_pwr_adjustment_bhp = self.fan_power_limitation_pressure_drop_adjustment_brake_horsepower
    
    # Subtract the fan power adjustment
    allowable_fan_bhp = allowable_fan_bhp-fan_pwr_adjustment_bhp
    
    # Get all fans
    fans = self.supply_return_exhaust_relief_fans    
    
    # TODO improve description
    # Loop through the fans, changing the pressure rise
    # until the fan bhp is the same percentage of the baseline allowable bhp
    # as it was on the proposed system.
    fans.each do |fan|
      # TODO: Yixing Check the model of the Fan Coil Unit
      next if fan.name.to_s.include?("Fan Coil fan")
      next if fan.name.to_s.include?("UnitHeater Fan")

      OpenStudio::logFree(OpenStudio::Info, "#{fan.name}")
    
      # Get the bhp of the fan on the proposed system
      proposed_fan_bhp = fan.brakeHorsepower
      
      # Get the bhp of the fan on the proposed system
      proposed_fan_bhp_frac = proposed_fan_bhp / proposed_sys_bhp
      
      # Determine the target bhp of the fan on the baseline system
      baseline_fan_bhp = proposed_fan_bhp_frac*allowable_fan_bhp
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{(baseline_fan_bhp).round(1)} bhp = Baseline fan brake horsepower.")
      
      # Set the baseline impeller eff of the fan, 
      # preserving the proposed motor eff.
      baseline_impeller_eff = fan.baselineImpellerEfficiency(template)
      fan.changeImpellerEfficiency(baseline_impeller_eff)
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{(baseline_impeller_eff*100).round(1)}% = Baseline fan impeller efficiency.")
      
      # Set the baseline motor efficiency for the specified bhp
      baseline_motor_eff = fan.standardMinimumMotorEfficiency(template, standards, allowable_fan_bhp)
      fan.changeMotorEfficiency(baseline_motor_eff)
      
      # Get design supply air flow rate (whether autosized or hard-sized)
      dsn_air_flow_m3_per_s = 0
      if fan.autosizedDesignSupplyAirFlowRate.is_initialized
        dsn_air_flow_m3_per_s = fan.autosizedDesignSupplyAirFlowRate.get
        dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
        OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
      else
        dsn_air_flow_m3_per_s = fan.designSupplyAirFlowRate.get
        dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
        OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = User entered Design Supply Air Flow Rate.")
      end
      
      # Determine the fan pressure rise that will result in the target bhp
      # pressure_rise_pa = fan_bhp*746 / fan_motor_eff*fan_total_eff / dsn_air_flow_m3_per_s
      baseline_pressure_rise_pa = baseline_fan_bhp*746 / fan.motorEfficiency*fan.fanEfficiency / dsn_air_flow_m3_per_s
      baseline_pressure_rise_in_wc = OpenStudio.convert(fan_pressure_rise_pa, "Pa", "inH_{2}O",).get
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{(fan_pressure_rise_in_wc).round(2)} in w.c. = Pressure drop to achieve allowable fan power.")

      # Calculate the bhp of the fan to make sure it matches
      calc_bhp = fan.brakeHorsepower
      if ((calc_bhp-baseline_fan_bhp) / baseline_fan_bhp).abs > 0.02
        OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.AirLoopHVAC", "#{fan.name} baseline fan bhp supposed to be #{baseline_fan_bhp}, but is #{calc_bhp}.")
      end

    end
    
    # Calculate the total bhp of the system to make sure it matches the goal
    calc_sys_bhp = self.system_fan_brake_horsepower(false)
    if ((calc_sys_bhp-allowable_fan_bhp) / allowable_fan_bhp).abs > 0.02
      OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.AirLoopHVAC", "#{self.name} baseline system bhp supposed to be #{allowable_fan_bhp}, but is #{calc_sys_bhp}.")
    end

  end

  # Get the total cooling capacity for the air loop
  #
  # @return [Double] total cooling capacity
  #   units = Watts (W)
  # @todo Change to pull water coil nominal capacity instead of design load; not a huge difference, but water coil nominal capacity not available in sizing table.
  # @todo Handle all additional cooling coil types.  Currently only handles CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, and CoilCoolingWater
  def total_cooling_capacity
  
    # Sum the cooling capacity for all cooling components
    # on the airloop, which may be inside of unitary systems.
    total_cooling_capacity_w = 0
    self.supplyComponents.each do |sc|
      # CoilCoolingDXSingleSpeed
      if sc.to_CoilCoolingDXSingleSpeed.is_initialized
        coil = sc.to_CoilCoolingDXSingleSpeed.get
        if coil.ratedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.ratedTotalCoolingCapacity.get
        elsif coil.autosizedRatedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.autosizedRatedTotalCoolingCapacity.get
        else
          OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
        # CoilCoolingDXTwoSpeed
      elsif sc.to_CoilCoolingDXTwoSpeed.is_initialized  
        coil = sc.to_CoilCoolingDXTwoSpeed.get
        if coil.ratedHighSpeedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.ratedHighSpeedTotalCoolingCapacity.get
        elsif coil.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.autosizedRatedHighSpeedTotalCoolingCapacity.get
        else
          OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
        # CoilCoolingWater
      elsif sc.to_CoilCoolingWater.is_initialized
        coil = sc.to_CoilCoolingWater.get
        if coil.autosizedDesignCoilLoad.is_initialized # TODO Change to pull water coil nominal capacity instead of design load
          total_cooling_capacity_w += coil.autosizedDesignCoilLoad.get
        else
          OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
      elsif sc.to_AirLoopHVACUnitarySystem.is_initialized
        unitary = sc.to_AirLoopHVACUnitarySystem.get
        if unitary.coolingCoil.is_initialized
          clg_coil = unitary.coolingCoil.get
          # CoilCoolingDXSingleSpeed
          if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
            coil = clg_coil.to_CoilCoolingDXSingleSpeed.get
            if coil.ratedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.ratedTotalCoolingCapacity.get
            elsif coil.autosizedRatedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.autosizedRatedTotalCoolingCapacity.get
            else
              OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
            end
          # CoilCoolingDXTwoSpeed
          elsif clg_coil.to_CoilCoolingDXTwoSpeed.is_initialized  
            coil = clg_coil.to_CoilCoolingDXTwoSpeed.get
            if coil.ratedHighSpeedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.ratedHighSpeedTotalCoolingCapacity.get
            elsif coil.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
              total_cooling_capacity_w += coil.autosizedRatedHighSpeedTotalCoolingCapacity.get
            else
              OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
            end
          # CoilCoolingWater
          elsif clg_coil.to_CoilCoolingWater.is_initialized
            coil = clg_coil.to_CoilCoolingWater.get
            if coil.autosizedDesignCoilLoad.is_initialized # TODO Change to pull water coil nominal capacity instead of design load
              total_cooling_capacity_w += coil.autosizedDesignCoilLoad.get
            else
              OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
            end
          end
        end
      elsif sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
        unitary = sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
        clg_coil = unitary.coolingCoil
        # CoilCoolingDXSingleSpeed
        if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
          coil = clg_coil.to_CoilCoolingDXSingleSpeed.get
          if coil.ratedTotalCoolingCapacity.is_initialized
            total_cooling_capacity_w += coil.ratedTotalCoolingCapacity.get
          elsif coil.autosizedRatedTotalCoolingCapacity.is_initialized
            total_cooling_capacity_w += coil.autosizedRatedTotalCoolingCapacity.get
          else
            OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
          end
        # CoilCoolingDXTwoSpeed
        elsif clg_coil.to_CoilCoolingDXTwoSpeed.is_initialized  
          coil = clg_coil.to_CoilCoolingDXTwoSpeed.get
          if coil.ratedHighSpeedTotalCoolingCapacity.is_initialized
            total_cooling_capacity_w += coil.ratedHighSpeedTotalCoolingCapacity.get
          elsif coil.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
            total_cooling_capacity_w += coil.autosizedRatedHighSpeedTotalCoolingCapacity.get
          else
            OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
          end
        # CoilCoolingWater
        elsif clg_coil.to_CoilCoolingWater.is_initialized
          coil = clg_coil.to_CoilCoolingWater.get
          if coil.autosizedDesignCoilLoad.is_initialized # TODO Change to pull water coil nominal capacity instead of design load
            total_cooling_capacity_w += coil.autosizedDesignCoilLoad.get
          else
            OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
          end
        end
      elsif sc.to_CoilCoolingDXMultiSpeed.is_initialized ||
          sc.to_CoilCoolingCooledBeam.is_initialized ||
          sc.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized ||
          sc.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized ||
          sc.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized ||
          sc.to_AirLoopHVACUnitarySystem.is_initialized
        OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "#{self.name} has a cooling coil named #{sc.name}, whose type is not yet covered by economizer checks.")
        # CoilCoolingDXMultiSpeed
        # CoilCoolingCooledBeam
        # CoilCoolingWaterToAirHeatPumpEquationFit
        # AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass
        # AirLoopHVACUnitaryHeatPumpAirToAir	 
        # AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed	
        # AirLoopHVACUnitarySystem
      end
    end

    return total_cooling_capacity_w
  
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
  def is_economizer_required(template, climate_zone)
  
    economizer_required = false
    
    # A big number of btu per hr as the minimum requirement
    infinity_btu_per_hr = 999999999999
    minimum_capacity_btu_per_hr = infinity_btu_per_hr
    
    # Determine the minimum capacity that requires an economizer
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
      case climate_zone
      when 'ASHRAE 169-2006-1A',
          'ASHRAE 169-2006-1B',
          'ASHRAE 169-2006-2A',
          'ASHRAE 169-2006-3A',
          'ASHRAE 169-2006-4A'
        minimum_capacity_btu_per_hr = infinity_btu_per_hr # No requirement
      when 'ASHRAE 169-2006-2B',
          'ASHRAE 169-2006-5A',
          'ASHRAE 169-2006-6A',
          'ASHRAE 169-2006-7A',
          'ASHRAE 169-2006-7B',
          'ASHRAE 169-2006-8A',
          'ASHRAE 169-2006-8B'
        minimum_capacity_btu_per_hr = 35000
      when 'ASHRAE 169-2006-3B',
          'ASHRAE 169-2006-3C',
          'ASHRAE 169-2006-4B',
          'ASHRAE 169-2006-4C',
          'ASHRAE 169-2006-5B',
          'ASHRAE 169-2006-5C',
          'ASHRAE 169-2006-6B'
        minimum_capacity_btu_per_hr = 65000
      end
    when '90.1-2010', '90.1-2013'
      case climate_zone
      when 'ASHRAE 169-2006-1A',
          'ASHRAE 169-2006-1B'
        minimum_capacity_btu_per_hr = infinity_btu_per_hr # No requirement
      when 'ASHRAE 169-2006-2A',
          'ASHRAE 169-2006-3A',
          'ASHRAE 169-2006-4A',
          'ASHRAE 169-2006-2B',
          'ASHRAE 169-2006-5A',
          'ASHRAE 169-2006-6A',
          'ASHRAE 169-2006-7A',
          'ASHRAE 169-2006-7B',
          'ASHRAE 169-2006-8A',
          'ASHRAE 169-2006-8B',
          'ASHRAE 169-2006-3B',
          'ASHRAE 169-2006-3C',
          'ASHRAE 169-2006-4B',
          'ASHRAE 169-2006-4C',
          'ASHRAE 169-2006-5B',
          'ASHRAE 169-2006-5C',
          'ASHRAE 169-2006-6B'
        minimum_capacity_btu_per_hr = 54000
      end
    when 'NECB 2011'
      minimum_capacity_btu_per_hr =  68243      # NECB requires economizer for cooling cap > 20 kW
    end
  
    # Check whether the system requires an economizer by comparing
    # the system capacity to the minimum capacity.
    minimum_capacity_w = OpenStudio.convert(minimum_capacity_btu_per_hr, "Btu/hr", "W").get
    if self.total_cooling_capacity >= minimum_capacity_w
      economizer_required = true
    end
    
    return economizer_required
  
  end
  
  # Set the economizer limits per the standard.  Limits are based on the economizer
  # type currently specified in the ControllerOutdoorAir object on this air loop.
  #
  # @param (see #is_economizer_required)
  # @return [Bool] returns true if successful, false if not
  def set_economizer_limits(template, climate_zone)
  
    # EnergyPlus economizer types
    # 'NoEconomizer'
    # 'FixedDryBulb'
    # 'FixedEnthalpy'
    # 'DifferentialDryBulb'
    # 'DifferentialEnthalpy'
    # 'FixedDewPointAndDryBulb'
    # 'ElectronicEnthalpy'
    # 'DifferentialDryBulbAndEnthalpy'  
  
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType
    
    # Return false if no economizer is present
    if economizer_type == 'NoEconomizer'
      return false
    end
  
    # Determine the limits according to the type
    drybulb_limit_f = nil
    enthalpy_limit_btu_per_lb = nil
    dewpoint_limit_f = nil
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
      case economizer_type
      when 'FixedDryBulb'
        case climate_zone
        when 'ASHRAE 169-2006-1B',
            'ASHRAE 169-2006-2B',
            'ASHRAE 169-2006-3B',
            'ASHRAE 169-2006-3C',
            'ASHRAE 169-2006-4B',
            'ASHRAE 169-2006-4C',
            'ASHRAE 169-2006-5B',
            'ASHRAE 169-2006-5C',
            'ASHRAE 169-2006-6B',
            'ASHRAE 169-2006-7B',
            'ASHRAE 169-2006-8A',
            'ASHRAE 169-2006-8B'
          drybulb_limit_f = 75
        when 'ASHRAE 169-2006-5A',
            'ASHRAE 169-2006-6A',
            'ASHRAE 169-2006-7A'
          drybulb_limit_f = 70
        when 'ASHRAE 169-2006-1A',
            'ASHRAE 169-2006-2A',
            'ASHRAE 169-2006-3A',
            'ASHRAE 169-2006-4A'
          drybulb_limit_f = 65
        end
      when 'FixedEnthalpy'
        enthalpy_limit_btu_per_lb = 28
      when 'FixedDewPointAndDryBulb'
        drybulb_limit_f = 75
        dewpoint_limit_f = 55
      end
    when '90.1-2010', '90.1-2013'
      case economizer_type
      when 'FixedDryBulb'
        case climate_zone
        when 'ASHRAE 169-2006-1B',
            'ASHRAE 169-2006-2B',
            'ASHRAE 169-2006-3B',
            'ASHRAE 169-2006-3C',
            'ASHRAE 169-2006-4B',
            'ASHRAE 169-2006-4C',
            'ASHRAE 169-2006-5B',
            'ASHRAE 169-2006-5C',
            'ASHRAE 169-2006-6B',
            'ASHRAE 169-2006-7A',
            'ASHRAE 169-2006-7B',
            'ASHRAE 169-2006-8A',
            'ASHRAE 169-2006-8B'
          drybulb_limit_f = 75
        when 'ASHRAE 169-2006-5A',
            'ASHRAE 169-2006-6A'
          drybulb_limit_f = 70
        end
      when 'FixedEnthalpy'
        enthalpy_limit_btu_per_lb = 28
      when 'FixedDewPointAndDryBulb'
        drybulb_limit_f = 75
        dewpoint_limit_f = 55
      end
    end 
 
    # Set the limits
    case economizer_type
    when 'FixedDryBulb'
      if drybulb_limit_f
        drybulb_limit_c = OpenStudio.convert(drybulb_limit_f, 'F', 'C').get
        oa_control.setEconomizerMaximumLimitDryBulbTemperature(drybulb_limit_c)
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Economizer type = #{economizer_type}, dry bulb limit = #{drybulb_limit_f}F")
      end
    when 'FixedEnthalpy'
      if enthalpy_limit_btu_per_lb
        enthalpy_limit_j_per_kg = OpenStudio.convert(enthalpy_limit_btu_per_lb, 'Btu/lb', 'J/kg').get
        oa_control.setEconomizerMaximumLimitEnthalpy(enthalpy_limit_j_per_kg)
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Economizer type = #{economizer_type}, enthalpy limit = #{enthalpy_limit_btu_per_lb}Btu/lb")
      end
    when 'FixedDewPointAndDryBulb'
      if drybulb_limit_f && dewpoint_limit_f
        drybulb_limit_c = OpenStudio.convert(drybulb_limit_f, 'F', 'C').get
        dewpoint_limit_c = OpenStudio.convert(dewpoint_limit_f, 'F', 'C').get
        oa_control.setEconomizerMaximumLimitDryBulbTemperature(drybulb_limit_c)
        oa_control.setEconomizerMaximumLimitDewpointTemperature(dewpoint_limit_c)
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Economizer type = #{economizer_type}, dry bulb limit = #{drybulb_limit_f}F, dew-point limit = #{dewpoint_limit_f}F")
      end
    end 

    return true
    
  end

  # For systems required to have an economizer, set the economizer
  # to integrated on non-integrated per the standard.
  #
  # @note this method assumes you previously checked that an economizer is required at all
  #   via #is_economizer_required
  # @param (see #is_economizer_required)
  # @return [Bool] returns true if successful, false if not
  def set_economizer_integration(template, climate_zone)
  
    # Determine if the system is a VAV system based on the fan
    # which may be inside of a unitary system.
    is_vav = false
    self.supplyComponents.reverse.each do |comp|
      if comp.to_FanVariableVolume.is_initialized
        is_vav = true
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if fan.to_FanVariableVolume.is_initialized
          is_vav = true
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        if fan.is_initialized
          if fan.get.to_FanVariableVolume.is_initialized
            is_vav = true
          end
        end
      end  
    end

    # Determine the number of zones the system serves
    num_zones_served = self.thermalZones.size
    
    # A big number of btu per hr as the minimum requirement
    infinity_btu_per_hr = 999999999999
    minimum_capacity_btu_per_hr = infinity_btu_per_hr
    
    # Determine if an integrated economizer is required
    integrated_economizer_required = true
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'    
      minimum_capacity_btu_per_hr = 65000
      minimum_capacity_w = OpenStudio.convert(minimum_capacity_btu_per_hr, "Btu/hr", "W").get
      # 6.5.1.3 Integrated Economizer Control
      # Exception a, DX VAV systems
      if is_vav == true && num_zones_served > 1
        integrated_economizer_required = false
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: non-integrated economizer per 6.5.1.3 exception a, DX VAV system.")
        # Exception b, DX units less than 65,000 Btu/hr
      elsif self.total_cooling_capacity < minimum_capacity_w
        integrated_economizer_required = false
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: non-integrated economizer per 6.5.1.3 exception b, DX system less than #{minimum_capacity_btu_per_hr}Btu/hr.")
      else
        # Exception c, Systems in climate zones 1,2,3a,4a,5a,5b,6,7,8
        case climate_zone
        when 'ASHRAE 169-2006-1A',
            'ASHRAE 169-2006-1B',
            'ASHRAE 169-2006-2A',
            'ASHRAE 169-2006-2B',
            'ASHRAE 169-2006-3A',
            'ASHRAE 169-2006-4A',
            'ASHRAE 169-2006-5A',
            'ASHRAE 169-2006-5B',
            'ASHRAE 169-2006-6A',
            'ASHRAE 169-2006-6B',
            'ASHRAE 169-2006-7A',
            'ASHRAE 169-2006-7B',
            'ASHRAE 169-2006-8A',
            'ASHRAE 169-2006-8B'
          integrated_economizer_required = false
          OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: non-integrated economizer per 6.5.1.3 exception c, climate zone #{climate_zone}.")
        when 'ASHRAE 169-2006-3B',
            'ASHRAE 169-2006-3C',
            'ASHRAE 169-2006-4B',
            'ASHRAE 169-2006-4C',
            'ASHRAE 169-2006-5C'
          integrated_economizer_required = true
        end
      end
    when '90.1-2010', '90.1-2013'
      integrated_economizer_required = true
    when 'NECB 2011'
      # this means that compressor allowed to turn on when economizer is open
      # (NoLockout); as per 5.2.2.8(3) 
      integrated_economizer_required = true
    end
  
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir  
  
    # Apply integrated or non-integrated economizer
    if integrated_economizer_required
      oa_control.setLockoutType('NoLockout')
    else
      oa_control.setLockoutType('LockoutWithCompressor')
    end

    return true
    
  end
  
  # Add economizer to the airloop per Appendix G baseline
  #
  # @param (see #is_economizer_required)
  # @return [Bool] returns true if successful, false if not
  # @todo This method is not yet functional
  def add_baseline_economizer(template, climate_zone)
  
  end
  
  # Check the economizer type currently specified in the ControllerOutdoorAir object on this air loop
  # is acceptable per the standard.
  #
  # @param (see #is_economizer_required)
  # @return [Bool] Returns true if allowable, if the system has no economizer or no OA system.
  # Returns false if the economizer type is not allowable.
  def is_economizer_type_allowable(template, climate_zone)
  
    # EnergyPlus economizer types
    # 'NoEconomizer'
    # 'FixedDryBulb'
    # 'FixedEnthalpy'
    # 'DifferentialDryBulb'
    # 'DifferentialEnthalpy'
    # 'FixedDewPointAndDryBulb'
    # 'ElectronicEnthalpy'
    # 'DifferentialDryBulbAndEnthalpy'
    
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return true # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType
    
    # Return true if no economizer is present
    if economizer_type == 'NoEconomizer'
      return true
    end
    
    # Determine the minimum capacity that requires an economizer
    prohibited_types = []
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
      case climate_zone
      when 'ASHRAE 169-2006-1B',
          'ASHRAE 169-2006-2B',
          'ASHRAE 169-2006-3B',
          'ASHRAE 169-2006-3C',
          'ASHRAE 169-2006-4B',
          'ASHRAE 169-2006-4C',
          'ASHRAE 169-2006-5B',
          'ASHRAE 169-2006-6B',
          'ASHRAE 169-2006-7A',
          'ASHRAE 169-2006-7B',
          'ASHRAE 169-2006-8A',
          'ASHRAE 169-2006-8B'
        prohibited_types = ['FixedEnthalpy']
      when
        'ASHRAE 169-2006-1A',
          'ASHRAE 169-2006-2A',
          'ASHRAE 169-2006-3A',
          'ASHRAE 169-2006-4A'
        prohibited_types = ['DifferentialDryBulb']
      when 
        'ASHRAE 169-2006-5A',
          'ASHRAE 169-2006-6A',
          prohibited_types = []
      end
    when  '90.1-2010', '90.1-2013'
      case climate_zone
      when 'ASHRAE 169-2006-1B',
          'ASHRAE 169-2006-2B',
          'ASHRAE 169-2006-3B',
          'ASHRAE 169-2006-3C',
          'ASHRAE 169-2006-4B',
          'ASHRAE 169-2006-4C',
          'ASHRAE 169-2006-5B',
          'ASHRAE 169-2006-6B',
          'ASHRAE 169-2006-7A',
          'ASHRAE 169-2006-7B',
          'ASHRAE 169-2006-8A',
          'ASHRAE 169-2006-8B'
        prohibited_types = ['FixedEnthalpy']
      when
        'ASHRAE 169-2006-1A',
          'ASHRAE 169-2006-2A',
          'ASHRAE 169-2006-3A',
          'ASHRAE 169-2006-4A'
        prohibited_types = ['FixedDryBulb', 'DifferentialDryBulb']
      when 
        'ASHRAE 169-2006-5A',
          'ASHRAE 169-2006-6A',
          prohibited_types = []
      end
    end
    
    # Check if the specified type is allowed
    economizer_type_allowed = true
    if prohibited_types.include?(economizer_type)
      economizer_type_allowed = false
    end
    
    return economizer_type_allowed
  
  end
  
  # Check if ERV is required on this airloop.
  #
  # @param (see #is_economizer_required)
  # @return [Bool] Returns true if required, false if not.  
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def is_energy_recovery_ventilator_required(template, climate_zone)
      
    # ERV Not Applicable for AHUs that serve 
    # parking garage, warehouse, or multifamily
    # if space_types_served_names.include?('PNNL_Asset_Rating_Apartment_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_LowRiseApartment_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_ParkingGarage_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_Warehouse_Space_Type')
    # OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV not applicable because it because it serves parking garage, warehouse, or multifamily.")
    # return false
    # end
    
    # ERV Not Applicable for AHUs that have DCV
    # or that have no OA intake.    
    controller_oa = nil
    controller_mv = nil
    oa_system = nil
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      controller_mv = controller_oa.controllerMechanicalVentilation
      if controller_mv.demandControlledVentilation == true
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV not applicable because DCV enabled.")
        return false
      end
    else
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV not applicable because it has no OA intake.")
      return false
    end

    # Get the AHU design supply air flow rate
    dsn_flow_m3_per_s = nil
    if self.designSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = self.designSupplyAirFlowRate.get
    elsif self.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = self.autosizedDesignSupplyAirFlowRate.get
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{self.name} design supply air flow rate is not available, cannot apply efficiency standard.")
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
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{controller_oa.name}: minimum OA flow rate is not available, cannot apply efficiency standard.")
      return false
    end
    min_oa_flow_cfm = OpenStudio.convert(min_oa_flow_m3_per_s, 'm^3/s', 'cfm').get
    
    # Calculate the percent OA at design airflow
    pct_oa = min_oa_flow_m3_per_s/dsn_flow_m3_per_s
    
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      erv_cfm = nil # Not required
    when '90.1-2004', '90.1-2007'
      if pct_oa < 0.7
        erv_cfm = nil
      else
        erv_cfm = 5000
      end
    when '90.1-2010'
      # Table 6.5.6.1
      case climate_zone
      when 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5B'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = nil
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = nil
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = nil
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = nil
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 5000
        elsif pct_oa >= 0.8 
          erv_cfm = 5000
        end
      when 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-5C'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = nil
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = nil
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 26000
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 12000
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 5000
        elsif pct_oa >= 0.8 
          erv_cfm = 4000
        end
      when 'ASHRAE 169-2006-6B'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 11000
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 5500
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 4500
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 3500
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 2500
        elsif pct_oa >= 0.8 
          erv_cfm = 1500
        end      
      when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-6A'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 5500
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 4500
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 3500
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 2000
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 1000
        elsif pct_oa >= 0.8 
          erv_cfm = 0
        end   
      when 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 2500
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 1000
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 0
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 0
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 0
        elsif pct_oa >= 0.8 
          erv_cfm = 0
        end      
      end
    when '90.1-2013'
      # Table 6.5.6.1-2
      case climate_zone
      when 'ASHRAE 169-2006-3C'
        erv_cfm = nil
      when 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5C'
        if pct_oa < 0.1
          erv_cfm = nil
        elsif pct_oa >= 0.1 && pct_oa < 0.2
          erv_cfm = nil
        elsif pct_oa >= 0.2 && pct_oa < 0.3
          erv_cfm = 19500
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 9000
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 5000
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 4000
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 3000
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 1500
        elsif pct_oa >= 0.8 
          erv_cfm = 0
        end
      when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-4B',  'ASHRAE 169-2006-5B'
        if pct_oa < 0.1
          erv_cfm = nil
        elsif pct_oa >= 0.1 && pct_oa < 0.2
          erv_cfm = 2500
        elsif pct_oa >= 0.2 && pct_oa < 0.3
          erv_cfm = 2000
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 1000
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 500
        elsif pct_oa >= 0.5
          erv_cfm = 0
        end
      when 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B'
        if pct_oa < 0.1
          erv_cfm = nil
        elsif pct_oa >= 0.1
          erv_cfm = 0
        end
      end
    when 'NECB 2011'
      # The NECB 2011 requirement is that systems with an exhaust heat content > 150 kW require an HRV
      # The calculation for this is done below, to modify erv_required 
      # erv_cfm set to nil here as placeholder, will lead to erv_required = false
      erv_cfm = nil
    end
    
    # Determine if an ERV is required
    erv_required = nil
    if erv_cfm.nil?
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV not required based on #{(pct_oa*100).round}% OA flow, design flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}.")
      erv_required = false 
    elsif dsn_flow_cfm < erv_cfm
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV not required based on #{(pct_oa*100).round}% OA flow, design flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}. Does not exceed minimum flow requirement of #{erv_cfm}cfm.")
      erv_required = false 
    else
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV required based on #{(pct_oa*100).round}% OA flow, design flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}. Exceeds minimum flow requirement of #{erv_cfm}cfm.")
      erv_required = true 
    end
  
    # This code modifies erv_required for NECB 2011
    # Calculation of exhaust heat content and check whether it is > 150 kW
    
    if template == 'NECB 2011'     
      
      # get all zones in the model
      zones = self.thermalZones
      
      # initialize counters
      sum_zone_oa = 0.0
      sum_zoneoaTimesheatDesignT = 0.0
      
      # zone loop
      zones.each do |zone|
        
        # get design heat temperature for each zone; this is equivalent to design exhaust temperature
        zone_sizing = zone.sizingZone
        heatDesignTemp = zone_sizing.zoneHeatingDesignSupplyAirTemperature

        # initialize counter
        zone_oa = 0.0
        # outdoor defined at space level; get OA flow for all spaces within zone
        spaces = zone.spaces
                
        # space loop
        spaces.each do |space|
          if not space.designSpecificationOutdoorAir.empty?             # if empty, don't do anything
            outdoor_air = space.designSpecificationOutdoorAir.get   
            
            # in bTAP, outdoor air specified as outdoor air per person (m3/s/person)
            oa_flow_per_person = outdoor_air.outdoorAirFlowperPerson
            num_people = space.peoplePerFloorArea * space.floorArea
            oa_flow = oa_flow_per_person * num_people     # oa flow for the space
            zone_oa = zone_oa + oa_flow                   # add up oa flow for all spaces to get zone air flow
          end 
          
        end   # space loop
        
        sum_zone_oa = sum_zone_oa + zone_oa              # sum of all zone oa flows to get system oa flow
        sum_zoneoaTimesheatDesignT = sum_zoneoaTimesheatDesignT + (zone_oa * heatDesignTemp)     # calculated to get oa flow weighted average of design exhaust temperature
         
      end   # zone loop
      
      # Calculate average exhaust temperature (oa flow weighted average)
      avg_exhaust_temp = sum_zoneoaTimesheatDesignT / sum_zone_oa              
      
      # for debugging/testing     
#      puts "average exhaust temp = #{avg_exhaust_temp}"
#      puts "sum_zone_oa = #{sum_zone_oa}"
       
      # Get January winter design temperature
      # get model weather file name
      weather_file = BTAP::Environment::WeatherFile.new(self.model.weatherFile.get.path.get)
      
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
      if ( exhaust_heat_content > 150.0 ) then
        erv_required = true
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV required based on exhaust heat content.") 
      else
        erv_required = false
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV not required based on exhaust heat content.") 
      end
       
      
      
    end   # of NECB 2011 condition
    
    # for debugging/testing
#    puts "erv_required = #{erv_required}"   
    
    return erv_required
  
  end  
   
  # Add an ERV to this airloop.
  # Will be a rotary-type HX
  #
  # @param (see #is_economizer_required)
  # @return [Bool] Returns true if required, false if not.  
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def apply_energy_recovery_ventilator()

    # Get the oa system
    oa_system = nil
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
    else
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV cannot be added because the system has no OA intake.")
      return false
    end
  
    # Create an ERV
    erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(self.model)
    erv.setName("#{self.name} ERV")
    erv.setSensibleEffectivenessat100HeatingAirFlow(0.7)
    erv.setLatentEffectivenessat100HeatingAirFlow(0.6)
    erv.setSensibleEffectivenessat75HeatingAirFlow(0.7)
    erv.setLatentEffectivenessat75HeatingAirFlow(0.6)
    erv.setSensibleEffectivenessat100CoolingAirFlow(0.75)
    erv.setLatentEffectivenessat100CoolingAirFlow(0.6)
    erv.setSensibleEffectivenessat75CoolingAirFlow(0.75)
    erv.setLatentEffectivenessat75CoolingAirFlow(0.6)
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
    spm_oa_pretreat = OpenStudio::Model::SetpointManagerOutdoorAirPretreat.new(model)
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
    erv.setPrototypeNominalElectricPower
    
    return true
    
  end   
   
  # Determine if multizone vav optimization is required.
  #
  # @param (see #is_economizer_required)
  # @return [Bool] Returns true if required, false if not.  
  # @todo Add exception logic for 
  #   systems with AIA healthcare ventilation requirements
  #   dual duct systems
  def is_multizone_vav_optimization_required(template, climate_zone)

    multizone_opt_required = false
  
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
      
      # Not required before 90.1-2010
      return multizone_opt_required
      
    when '90.1-2010', '90.1-2013'
      
      # Not required for systems with fan-powered terminals
      num_fan_powered_terminals = 0
      self.demandComponents.each do |comp|
        if comp.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized || comp.to_AirTerminalSingleDuctSeriesPIUReheat.is_initialized 
          num_fan_powered_terminals += 1
        end
      end
      if num_fan_powered_terminals > 0
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{self.name}, multizone vav optimization is not required because the system has #{num_fan_powered_terminals} fan-powered terminals.")
        return multizone_opt_required
      end
      
      # Not required for systems that require an ERV
      if self.has_energy_recovery
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: multizone vav optimization is not required because the system has Energy Recovery.")
        return multizone_opt_required
      end
      
      # Get the OA intake
      controller_oa = nil
      controller_mv = nil
      oa_system = nil
      if self.airLoopHVACOutdoorAirSystem.is_initialized
        oa_system = self.airLoopHVACOutdoorAirSystem.get
        controller_oa = oa_system.getControllerOutdoorAir      
        controller_mv = controller_oa.controllerMechanicalVentilation
      else
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, multizone optimization is not applicable because system has no OA intake.")
        return multizone_opt_required
      end
      
      # Get the AHU design supply air flow rate
      dsn_flow_m3_per_s = nil
      if self.designSupplyAirFlowRate.is_initialized
        dsn_flow_m3_per_s = self.designSupplyAirFlowRate.get
      elsif self.autosizedDesignSupplyAirFlowRate.is_initialized
        dsn_flow_m3_per_s = self.autosizedDesignSupplyAirFlowRate.get
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{self.name} design supply air flow rate is not available, cannot apply efficiency standard.")
        return multizone_opt_required
      end
      dsn_flow_cfm = OpenStudio.convert(dsn_flow_m3_per_s, 'm^3/s', 'cfm').get
    
      # Get the minimum OA flow rate
      min_oa_flow_m3_per_s = nil
      if controller_oa.minimumOutdoorAirFlowRate.is_initialized
        min_oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
      elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
        min_oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{controller_oa.name}: minimum OA flow rate is not available, cannot apply efficiency standard.")
        return multizone_opt_required
      end
      min_oa_flow_cfm = OpenStudio.convert(min_oa_flow_m3_per_s, 'm^3/s', 'cfm').get
    
      # Calculate the percent OA at design airflow
      pct_oa = min_oa_flow_m3_per_s/dsn_flow_m3_per_s
    
      # Not required for systems where
      # exhaust is more than 70% of the total OA intake.
      if pct_oa > 0.7
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{controller_oa.name}: multizone optimization is not applicable because system is more than 70% OA.")
        return multizone_opt_required
      end

      # TODO Not required for dual-duct systems
      # if self.isDualDuct
        # OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{controller_oa.name}: multizone optimization is not applicable because it is a dual duct system")
        # return multizone_opt_required
      # end
      
      # If here, multizone vav optimization is required
      multizone_opt_required = true
      
      return multizone_opt_required
    
    end
   
  end      
   
  # Enable multizone vav optimization by changing the Outdoor Air Method
  # in the Controller:MechanicalVentilation object to 'VentilationRateProcedure'
  #
  # @return [Bool] Returns true if required, false if not.  
  def enable_multizone_vav_optimization
   
    # Enable multizone vav optimization
    # at each timestep.
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      controller_mv = controller_oa.controllerMechanicalVentilation
      controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{self.name}, cannot enable multizone vav optimization because the system has no OA intake.")
      return false
    end
   
  end 
   
  # Disable multizone vav optimization by changing the Outdoor Air Method
  # in the Controller:MechanicalVentilation object to 'ZoneSum'
  #
  # @return [Bool] Returns true if required, false if not.
  def disable_multizone_vav_optimization
   
    # Disable multizone vav optimization
    # at each timestep.
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      controller_mv = controller_oa.controllerMechanicalVentilation
      controller_mv.setSystemOutdoorAirMethod('ZoneSum')
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{self.name}, cannot disable multizone vav optimization because the system has no OA intake.")
      return false
    end
   
  end 

  # Set the minimum VAV damper positions to the values
  #
  # @param (see #is_economizer_required)
  # @return [Bool] Returns true if required, false if not.  
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def set_minimum_vav_damper_positions
   
    # Total uncorrected outdoor airflow rate
    v_ou = 0.0
    self.thermalZones.each do |zone|
      v_ou += zone.outdoor_airflow_rate
    end
    v_ou_cfm = OpenStudio.convert(v_ou, 'm^3/s', 'cfm').get
    
    # System primary airflow rate (whether autosized or hard-sized)
    v_ps = 0.0
    if self.autosizedDesignSupplyAirFlowRate.is_initialized
      v_ps = self.autosizedDesignSupplyAirFlowRate.get
    else
      v_ps = self.designSupplyAirFlowRate.get
    end
    v_ps_cfm = OpenStudio.convert(v_ps, 'm^3/s', 'cfm').get
    
    # Average outdoor air fraction
    x_s = v_ou / v_ps
    
    OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: v_ou = #{v_ou_cfm.round} cfm, v_ps = #{v_ps_cfm.round} cfm, x_s = #{x_s.round(2)}.")  
    
    # Determine the zone ventilation effectiveness
    # for every zone on the system.
    # When ventilation effectiveness is too low,
    # increase the minimum damper position.
    e_vzs = []
    e_vzs_adj = []
    num_zones_adj = 0
    self.thermalZones.sort.each do |zone|
      
      # Breathing zone airflow rate
      v_bz = zone.outdoor_airflow_rate 
      
      # Zone air distribution, assumed 1 per PNNL
      e_z = 1.0 
      
      # Zone airflow rate
      v_oz = v_bz / e_z 
      
      # Primary design airflow rate
      # max of heating and cooling 
      # design air flow rates
      v_pz = 0.0
      clg_dsn_flow = zone.autosizedCoolingDesignAirFlowRate
      if clg_dsn_flow.is_initialized
        clg_dsn_flow = clg_dsn_flow.get
        if clg_dsn_flow > v_pz
          v_pz = clg_dsn_flow
        end
      else
        OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: #{zone.name} clg_dsn_flow could not be found.")
      end
      htg_dsn_flow = zone.autosizedHeatingDesignAirFlowRate
      if htg_dsn_flow.is_initialized
        htg_dsn_flow = htg_dsn_flow.get
        if htg_dsn_flow > v_pz
          v_pz = htg_dsn_flow
        end
      else
        OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: #{zone.name} htg_dsn_flow could not be found.")
      end
      
      # Get the minimum damper position
      mdp = 1.0
      zone.equipment.each do |equip|
        if equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.get
          mdp = term.zoneMinimumAirFlowFraction
        elsif equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.get
          mdp = term.zoneMinimumAirFlowFraction
        elsif equip.to_AirTerminalSingleDuctVAVNoReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVNoReheat.get
          if term.constantMinimumAirFlowFraction.is_initialized
            mdp = term.constantMinimumAirFlowFraction.get
          end
        elsif equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVReheat.get
          mdp = term.constantMinimumAirFlowFraction
        end
      end
    
      # Zone minimum discharge airflow rate
      v_dz = v_pz*mdp
    
      # Zone discharge air fraction
      z_d = v_oz / v_dz
      
      # Zone ventilation effectiveness
      e_vz = 1+x_s-z_d
    
      # Store the ventilation effectiveness
      e_vzs << e_vz
    
      OpenStudio::logFree(OpenStudio::Debug, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Zone #{zone.name} v_oz = #{v_oz.round(2)} m^3/s, v_pz = #{v_pz.round(2)} m^3/s, v_dz = #{v_dz.round(2)}, z_d = #{z_d.round(2)}.")
    
      # Check the ventilation effectiveness against
      # the minimum limit per PNNL and increase
      # as necessary.
      if e_vz < 0.6
      
        # Adjusted discharge air fraction
        z_d_adj = 1+x_s-0.6
        
        # Adjusted min discharge airflow rate
        v_dz_adj = v_oz / z_d_adj
      
        # Adjusted minimum damper position
        mdp_adj = v_dz_adj / v_pz
        
        # Don't allow values > 1
        if mdp_adj > 1.0
          mdp_adj = 1.0
        end
        
        # Zone ventilation effectiveness
        e_vz_adj = 1+x_s-z_d_adj
    
        # Store the ventilation effectiveness
        e_vzs_adj << e_vz_adj
        
        # Set the adjusted minimum damper position
        zone.equipment.each do |equip|
          if equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.get
            term.setZoneMinimumAirFlowFraction(mdp_adj)
          elsif equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.get
            term.setZoneMinimumAirFlowFraction(mdp_adj)
          elsif equip.to_AirTerminalSingleDuctVAVNoReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVNoReheat.get
            term.setConstantMinimumAirFlowFraction(mdp_adj)
          elsif equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVReheat.get
            term.setConstantMinimumAirFlowFraction(mdp_adj)
          end
        end
        
        num_zones_adj += 1
        
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Zone #{zone.name} has a ventilation effectiveness of #{e_vz.round(2)}.  Increasing to #{e_vz_adj.round(2)} by increasing minimum damper position from #{mdp.round(2)} to #{mdp_adj.round(2)}.")

      else
        # Store the unadjusted value
        e_vzs_adj << e_vz
      end
  
    end
  
    # Min system zone ventilation effectiveness
    e_v = e_vzs.min
   
    # Total system outdoor intake flow rate 
    v_ot = v_ou / e_v
    v_ot_cfm = OpenStudio.convert(v_ot, 'm^3/s', 'cfm').get
    
    # Min system zone ventilation effectiveness
    e_v_adj = e_vzs_adj.min
   
    # Total system outdoor intake flow rate 
    v_ot_adj = v_ou / e_v_adj
    v_ot_adj_cfm = OpenStudio.convert(v_ot_adj, 'm^3/s', 'cfm').get
    
    # Report out the results of the multizone calculations
    if num_zones_adj > 0
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: the multizone outdoor air calculation method was applied.  A simple summation of the zone outdoor air requirements gives a value of #{v_ou_cfm.round} cfm.  Applying the multizone method gives a value of #{v_ot_cfm.round} cfm, with an original system ventilation effectiveness of #{e_v.round(2)}.  After increasing the minimum damper position in #{num_zones_adj} critical zones, the resulting requirement is #{v_ot_adj_cfm.round} cfm with a system ventilation effectiveness of #{e_v_adj.round(2)}.")
    else
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: the multizone outdoor air calculation method was applied.  A simple summation of the zone requirements gives a value of #{v_ou_cfm.round} cfm.  However, applying the multizone method requires #{v_ot_adj_cfm.round} cfm based on the ventilation effectiveness of the system.")
    end
   
    # Hard-size the sizing:system
    # object with the calculated min OA flow rate
    sizing_system = self.sizingSystem
    sizing_system.setDesignOutdoorAirFlowRate(v_ot_adj)
   
    return true
   
  end
   
  # Determine if demand control ventilation (DCV) is
  # required for this air loop.
  #
  # @param (see #is_economizer_required)
  # @return [Bool] Returns true if required, false if not.  
  # @todo Add exception logic for 
  #   systems that serve multifamily, parking garage, warehouse
  def is_demand_control_ventilation_required(template, climate_zone)
   
    dcv_required = false
   
    # Not required by the old vintages
    if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: DCV is not required for any system.")
      return dcv_required
    end
   
    # Not required for systems that require an ERV
    if self.has_energy_recovery
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: DCV is not required since the system has Energy Recovery.")
      return dcv_required
    end
   
    # Area, occupant density, and OA flow limits
    min_area_ft2 = 0
    min_occ_per_1000_ft2 = 0
    min_oa_without_economizer_cfm = 0
    min_oa_with_economizer_cfm = 0
    case template
    when '90.1-2004'
      min_area_ft2 = 0
      min_occ_per_1000_ft2 = 100
      min_oa_without_economizer_cfm = 3000
      min_oa_with_economizer_cfm = 0
    when '90.1-2007', '90.1-2010'
      min_area_ft2 = 500
      min_occ_per_1000_ft2 = 40
      min_oa_without_economizer_cfm = 3000
      min_oa_with_economizer_cfm = 1200
    when '90.1-2013'
      min_area_ft2 = 500
      min_occ_per_1000_ft2 = 25
      min_oa_without_economizer_cfm = 3000
      min_oa_with_economizer_cfm = 750
    end
    
    # Get the area served and the number of occupants
    area_served_m2 = 0
    num_people = 0
    self.thermalZones.each do |zone|
      zone.spaces.each do |space|
        area_served_m2 += space.floorArea
        num_people += space.numberOfPeople
      end
    end

    # Check the minimum area
    area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get
    if area_served_ft2 < min_area_ft2
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: DCV is not required since the system serves #{area_served_ft2.round} ft2, but the minimum size is #{min_area_ft2.round} ft2.")
      return dcv_required
    end
    
    # Check the minimum occupancy density
    occ_per_ft2 = num_people / area_served_ft2
    occ_per_1000_ft2 = occ_per_ft2*1000
    if occ_per_1000_ft2 < min_occ_per_1000_ft2
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: DCV is not required since the system occupant density is #{occ_per_1000_ft2.round} people/1000 ft2, but the minimum occupant density is #{min_occ_per_1000_ft2.round} people/1000 ft2.")
      return dcv_required
    end
    
    # Get the min OA flow rate   
    oa_flow_m3_per_s = 0
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      if controller_oa.minimumOutdoorAirFlowRate.is_initialized
        oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
      elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
        oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
      end
    else
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, DCV not applicable because it has no OA intake.")
      return dcv_required
    end
    oa_flow_cfm = OpenStudio.convert(oa_flow_m3_per_s, 'm^3/s', 'cfm').get
    
    
    # Check for min OA without an economizer OR has economizer
    if oa_flow_cfm < min_oa_without_economizer_cfm && self.has_economizer == false
      # Message if doesn't pass OA limit
      if oa_flow_cfm < min_oa_without_economizer_cfm
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: DCV is not required since the system min oa flow is #{oa_flow_cfm.round} cfm, less than the minimum of #{min_oa_without_economizer_cfm.round} cfm.")
      end
      # Message if doesn't have economizer
      if self.has_economizer == false
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: DCV is not required since the system does not have an economizer.")
      end
      return dcv_required
    end

    # If has economizer, cfm limit is lower
    if oa_flow_cfm < min_oa_with_economizer_cfm && self.has_economizer
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: DCV is not required since the system has an economizer, but the min oa flow is #{oa_flow_cfm.round} cfm, less than the minimum of #{min_oa_with_economizer_cfm.round} cfm for systems with an economizer.")
      return dcv_required
    end
   
    # If here, DCV is required
    dcv_required = true
    
    return dcv_required
   
  end    

  # Enable demand control ventilation (DCV) for this air loop.
  #
  # @return [Bool] Returns true if required, false if not.
  def enable_demand_control_ventilation()

    # Get the OA intake
    controller_oa = nil
    controller_mv = nil
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      controller_mv = controller_oa.controllerMechanicalVentilation
      if controller_mv.demandControlledVentilation == true
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: DCV was already enabled.")
        return true
      end
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Could not enable DCV since the system has no OA intake.")
      return false
    end
  
    # Change the min flow rate in the controller outdoor air
    controller_oa.setMinimumOutdoorAirFlowRate(0.0)
     
    # Enable DCV in the controller mechanical ventilation
    controller_mv.setDemandControlledVentilation(true)

    return true

  end
  
  # Determine if the system required supply air temperature
  # (SAT) reset.
  #
  # @param (see #is_economizer_required)
  # @return [Bool] Returns true if required, false if not.  
  def is_supply_air_temperature_reset_required(template, climate_zone)
  
    is_sat_reset_required = false
    
    # Only required for multizone VAV systems
    return is_sat_reset_required unless self.is_multizone_vav_system
  
    # Not required until 90.1-2010
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
      return is_sat_reset_required
    when '90.1-2010', '90.1-2013'
      case climate_zone
      when 'ASHRAE 169-2006-1A',
        'ASHRAE 169-2006-2A',
        'ASHRAE 169-2006-3A'
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Supply air temperature reset is not required per 6.5.3.4 Exception 1, the system is located in climate zone #{climate_zone}.")
      when 'ASHRAE 169-2006-1B',
        'ASHRAE 169-2006-2B',
        'ASHRAE 169-2006-3B',
        'ASHRAE 169-2006-3C',
        'ASHRAE 169-2006-4A',
        'ASHRAE 169-2006-4B',
        'ASHRAE 169-2006-4C',
        'ASHRAE 169-2006-5A',
        'ASHRAE 169-2006-5B',
        'ASHRAE 169-2006-5C',
        'ASHRAE 169-2006-6A',
        'ASHRAE 169-2006-6B',
        'ASHRAE 169-2006-7A',
        'ASHRAE 169-2006-7B',
        'ASHRAE 169-2006-8A',
        'ASHRAE 169-2006-8B'
        is_sat_reset_required = true
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Supply air temperature reset is required.") 
        return is_sat_reset_required
      end
    end
    
  end

  # Enable supply air temperature (SAT) reset based
  # on outdoor air conditions.  SAT will be kept at the
  # current design temperature when outdoor air is above 70F,
  # increased by 5F when outdoor air is below 50F, and reset
  # linearly when outdoor air is between 50F and 70F.
  #
  # @return [Bool] Returns true if successful, false if not.  
  def enable_supply_air_temperature_reset()
  
    # Get the current setpoint and calculate 
    # the new setpoint.
    sizing_system = self.sizingSystem
    sat_at_hi_oat_c = sizing_system.centralCoolingDesignSupplyAirTemperature
    sat_at_hi_oat_f = OpenStudio.convert(sat_at_hi_oat_c, 'C', 'F').get
    # 5F increase when it's cold outside,
    # and therefore less cooling capacity is likely required.
    increase_f = 5.0
    sat_at_lo_oat_f = sat_at_hi_oat_f+increase_f
    sat_at_lo_oat_c = OpenStudio.convert(sat_at_lo_oat_f, 'F', 'C').get
    
    # Define the high and low outdoor air temperatures
    lo_oat_f = 50
    lo_oat_c = OpenStudio.convert(lo_oat_f, 'F', 'C').get
    hi_oat_f = 70
    hi_oat_c = OpenStudio.convert(hi_oat_f, 'F', 'C').get
    
    # Create a setpoint manager
    sat_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
    sat_oa_reset.setName("#{self.name} SAT Reset")
    sat_oa_reset.setControlVariable('Temperature')
    sat_oa_reset.setSetpointatOutdoorLowTemperature(sat_at_lo_oat_c)
    sat_oa_reset.setOutdoorLowTemperature(lo_oat_c)
    sat_oa_reset.setSetpointatOutdoorHighTemperature(sat_at_hi_oat_c)
    sat_oa_reset.setOutdoorHighTemperature(hi_oat_c)
    
    # Attach the setpoint manager to the
    # supply outlet node of the system.
    sat_oa_reset.addToNode(self.supplyOutletNode)
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Supply air temperature reset was enabled.  When OAT > #{hi_oat_f.round}F, SAT is #{sat_at_hi_oat_f.round}F.  When OAT < #{lo_oat_f.round}F, SAT is #{sat_at_lo_oat_f.round}F.  It varies linearly in between these points.")
    
    return true
  
  end
  
  # Determine if the system has an economizer
  #
  # @return [Bool] Returns true if required, false if not.  
  def has_economizer()
  
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType
    
    # Return false if no economizer is present
    if economizer_type == 'NoEconomizer'
      return false
    else
      return true
    end
    
  end  
  
  # Determine if the system has an economizer
  #
  # @return [Bool] Returns true if required, false if not.  
  def has_economizer()
  
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType
    
    # Return false if no economizer is present
    if economizer_type == 'NoEconomizer'
      return false
    else
      return true
    end
    
  end
  
  # Determine if the system is a multizone VAV system
  #
  # @return [Bool] Returns true if required, false if not.  
  def is_multizone_vav_system()
    
    is_multizone_vav_system = false
    
    # Must serve more than 1 zone
    if self.thermalZones.size < 2
      return is_multizone_vav_system
    end
    
    # Must be a variable volume system
    has_vav_fan = false
    self.supplyComponents.each do |comp|
      if comp.to_FanVariableVolume.is_initialized
        has_vav_fan = true
      end
    end
    if has_vav_fan == false
      return is_multizone_vav_system
    end
    
    # If here, it's a multizone VAV system
    is_multizone_vav_system = true
    
    return is_multizone_vav_system

  end
  
  # Determine if the system has energy recovery already
  #
  # @return [Bool] Returns true if an ERV is present, false if not.  
  def has_energy_recovery()
    
    has_erv = false
    
    # Get the OA system
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return has_erv # No OA system
    end	
      
    # Find any ERV on the OA system
    oa_sys.oaComponents.each do |oa_comp|
      if oa_comp.to_HeatExchangerAirToAirSensibleAndLatent.is_initialized
        has_erv = true
      end
    end
    
    return has_erv

  end

  # Set the VAV damper control to single maximum or
  # dual maximum control depending on the standard.
  #
  # @return [Bool] Returns true if successful, false if not
  # @todo see if this impacts the sizing run.
  def set_vav_damper_action(template)
    damper_action = nil
    case template       
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', 'NECB 2011'
      damper_action = 'Single Maximum'
    when '90.1-2007', '90.1-2010', '90.1-2013'
      damper_action = 'Dual Maximum'
    end
    
    # Interpret this as an EnergyPlus input
    damper_action_eplus = nil
    if damper_action == 'Single Maximum'
      damper_action_eplus = 'Normal'
    elsif damper_action == 'Dual Maximum'
      damper_action_eplus = 'Reverse'
    end
    
    # Set the control for any VAV reheat terminals
    # on this airloop.
    self.demandComponents.each do |equip|
      if equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
        term = equip.to_AirTerminalSingleDuctVAVReheat.get
        term.setDamperHeatingAction(damper_action_eplus)
      end
    end    
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: VAV damper action was set to #{damper_action} control.")
    
    return true
    
  end

  # Determine if a motorized OA damper is required
  def is_motorized_oa_damper_required(template, climate_zone)
  
    is_motorized_oa_damper_required = false
  
    # If the system has an economizer, it is assumed to have
    # a motorized damper.
    if self.has_economizer
      is_motorized_oa_damper_required = false
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Because the system has an economizer, it is assumed to require a motorized damper.")
      return is_motorized_oa_damper_required
    end
  
  end
  
  # Add a motorized damper by modifying the OA schedule
  # to require zero OA during unoccupied hours.  This means
  # that even during morning warmup or nightcyling, no OA will
  # be brought into the building, lowering heating/cooling load.
  def add_motorized_oa_damper
  
    return true
    
  end  
  
  # Remove a motorized OA damper by modifying the OA schedule
  # to require full OA at all times.  Whenever the fan operates,
  # the damper will be open and OA will be brought into the building.
  # This increases building loads unnecessarily during unoccupied hours.
  def remove_motorized_oa_damper
  
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
  
    # Set the minimum OA schedule to always 1 (100%)
    oa_control.setMinimumOutdoorAirSchedule(self.model.alwaysOnDiscreteSchedule)

    return true
  
  end  

  # This method creates a schedule where the value is zero when
  # the overall occupancy for all zones on the airloop is below
  # the specified threshold, and one when the overall occupancy is
  # greater than or equal to the threshold.  This method is designed
  # to use the total number of people on the airloop, so if there is
  # a zone that is continuously occupied by a few people, but other
  # zones that are intermittently occupied by many people, the 
  # first zone doesn't drive the entire system.
  #
  # @param occupied_percentage_threshold [Double] the minimum fraction (0 to 1) that counts as occupied
  # @return [ScheduleRuleset] a ScheduleRuleset where 0 = unoccupied, 1 = occupied
  # @todo Speed up this method.  Bottleneck is ScheduleRule.getDaySchedules
  def get_occupancy_schedule(occupied_percentage_threshold = 0.05)

    # Get all the occupancy schedules in every space in every zone
    # served by this airloop.  Include people added via the SpaceType
    # in addition to people hard-assigned to the Space itself.
    occ_schedules_num_occ = {}
    max_occ_on_airloop = 0
    self.thermalZones.each do |zone|
      # Get the people objects
      zone.spaces.each do |space|
        # From the space type
        if space.spaceType.is_initialized
          space.spaceType.get.people.each do |people|
            num_ppl_sch = people.numberofPeopleSchedule
            if num_ppl_sch.is_initialized
              num_ppl_sch = num_ppl_sch.get
              num_ppl_sch = num_ppl_sch.to_ScheduleRuleset
              next if num_ppl_sch.empty? # Skip non-ruleset schedules
              num_ppl_sch = num_ppl_sch.get
              num_ppl = people.getNumberOfPeople(space.floorArea)
              if occ_schedules_num_occ[num_ppl_sch].nil?
                occ_schedules_num_occ[num_ppl_sch] = num_ppl
                max_occ_on_airloop += num_ppl     
              else
                occ_schedules_num_occ[num_ppl_sch] += num_ppl
                max_occ_on_airloop += num_ppl
              end
            end
          end
        end
        # From the space
        space.people.each do |people|
          num_ppl_sch = people.numberofPeopleSchedule
          if num_ppl_sch.is_initialized
            num_ppl_sch = num_ppl_sch.get
            num_ppl_sch = num_ppl_sch.to_ScheduleRuleset
            next if num_ppl_sch.empty? # Skip non-ruleset schedules
            num_ppl_sch = num_ppl_sch.get
            num_ppl = people.getNumberOfPeople(space.floorArea)
            if occ_schedules_num_occ[num_ppl_sch].nil?
              occ_schedules_num_occ[num_ppl_sch] = num_ppl
              max_occ_on_airloop += num_ppl     
            else
              occ_schedules_num_occ[num_ppl_sch] += num_ppl
              max_occ_on_airloop += num_ppl
            end
          end
        end
      end
    end
    
    OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "#{self.name} has #{occ_schedules_num_occ.size} unique occ schedules.")
    occ_schedules_num_occ.each do |occ_sch, num_occ|
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "   #{occ_sch.name} - #{num_occ.round} people")
    end
    OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "   Total #{max_occ_on_airloop.round} people on #{self.name}")
    
    # For each day of the year, determine
    #time_value_pairs = []
    year = self.model.getYearDescription
    yearly_data = []
    yearly_times = OpenStudio::DateTimeVector.new
    yearly_values = []
    for i in 1..365

      times_on_this_day = []
      os_date = year.makeDate(i)
      day_of_week = os_date.dayOfWeek.valueName
    
      # Get the unique time indices and corresponding day schedules
      occ_schedules_day_schs = {}
      day_sch_num_occ = {}
      occ_schedules_num_occ.each do |occ_sch, num_occ|
        
        # Get the day schedules for this day
        # (there should only be one)
        day_schs = occ_sch.getDaySchedules(os_date, os_date)
        OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "Schedule #{occ_sch.name} has #{day_schs.size} day schs") unless day_schs.size == 1
        day_schs[0].times.each do |time|
          times_on_this_day << time.toString
        end
        day_sch_num_occ[day_schs[0]] = num_occ
        
      end

      # Determine the total fraction for the airloop at each time
      daily_times = []
      daily_os_times = []
      daily_values = []
      daily_occs = []
      times_on_this_day.uniq.sort.each do |time|

        os_time = OpenStudio::Time.new(time)
        os_date_time = OpenStudio::DateTime.new(os_date, os_time)
        # Total number of people at each time
        tot_occ_at_time = 0
        day_sch_num_occ.each do |day_sch, num_occ|
          occ_frac = day_sch.getValue(os_time)
          tot_occ_at_time += occ_frac * num_occ
        end
      
        # Total fraction for the airloop at each time
        air_loop_occ_frac = tot_occ_at_time / max_occ_on_airloop
        occ_status = 0 # unoccupied
        if air_loop_occ_frac >= occupied_percentage_threshold
          occ_status = 1
        end

        # Add this data to the daily arrays
        daily_times << time
        daily_os_times << os_time
        daily_values << occ_status
        daily_occs << air_loop_occ_frac.round(2)

      end

      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "#{daily_times.join(', ')}                  #{daily_values.join(', ')}")
      
      # Simplify the daily times to eliminate intermediate
      # points with the same value as the following point.
      simple_daily_times = []
      simple_daily_os_times = []
      simple_daily_values = []
      simple_daily_occs = []
      daily_values.each_with_index do |value, i| 
        next if value == daily_values[i+1]
        simple_daily_times << daily_times[i]
        simple_daily_os_times << daily_os_times[i]
        simple_daily_values << daily_values[i]
        simple_daily_occs << daily_occs[i]
      end
      
      # OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "#{simple_daily_times.join(', ')}                  {simple_daily_values.join(', ')}")
      
      # Store the daily values
      yearly_data << {'date'=>os_date,'day_of_week'=>day_of_week,'times'=>simple_daily_times,'values'=>simple_daily_values,'daily_os_times'=>simple_daily_os_times, 'daily_occs'=>simple_daily_occs}

    end
    
    # Create a TimeSeries from the data
    #time_series = OpenStudio::TimeSeries.new(times, values, 'unitless')

    # Make a schedule ruleset
    sch_name = "#{self.name} Occ Sch"
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(self.model)
    sch_ruleset.setName("#{sch_name}")  

    # Default - All Occupied
    day_sch = sch_ruleset.defaultDaySchedule
    day_sch.setName("#{sch_name} Default")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Winter Design Day - All Occupied
    day_sch = OpenStudio::Model::ScheduleDay.new(self.model)
    sch_ruleset.setWinterDesignDaySchedule(day_sch)
    day_sch = sch_ruleset.winterDesignDaySchedule
    day_sch.setName("#{sch_name} Winter Design Day")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)     

    # Summer Design Day - All Occupied
    day_sch = OpenStudio::Model::ScheduleDay.new(self.model)
    sch_ruleset.setSummerDesignDaySchedule(day_sch)
    day_sch = sch_ruleset.summerDesignDaySchedule
    day_sch.setName("#{sch_name} Summer Design Day")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)
    
    # Create ruleset schedules, attempting to create
    # the minimum number of unique rules.
    ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].each do |day_of_week|
      OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "#{day_of_week}")
      end_of_prev_rule = yearly_data[0]['date']
      yearly_data.each_with_index do |daily_data, i|
        # Skip unless it is the day of week
        # currently under inspection
        day = daily_data['day_of_week']
        next unless day == day_of_week
        date = daily_data['date']
        times = daily_data['times']
        values = daily_data['values']
        daily_occs = daily_data['daily_occs']
        
        # If the next (Monday, Tuesday, etc.)
        # is the same as today, keep going.
        # If the next is different, or if
        # we've reached the end of the year,
        # create a new rule
        if !yearly_data[i+7].nil?
          next_day_times = yearly_data[i+7]['times']
          next_day_values = yearly_data[i+7]['values']
          next if times == next_day_times && values == next_day_values
        end
        
        daily_os_times = daily_data['daily_os_times']
        daily_occs = daily_data['daily_occs']
        
        # If here, we need to make a rule to cover from the previous
        # rule to today
        OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "Making a new rule for #{day_of_week} from #{end_of_prev_rule.to_s} to #{date}")
        sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
        sch_rule.setName("#{sch_name} #{day_of_week} Rule")
        day_sch = sch_rule.daySchedule
        day_sch.setName("#{sch_name} #{day_of_week}")
        daily_os_times.each_with_index do |time, i|
          value = values[i]
          next if value == values[i+1] # Don't add breaks if same value
          day_sch.addValue(time, value)
          OpenStudio::logFree(OpenStudio::Debug, "openstudio.standards.AirLoopHVAC", "   Adding value #{time}, #{value}")
        end
        
        # Set the dates when the rule applies
        sch_rule.setStartDate(end_of_prev_rule)
        sch_rule.setEndDate(date)

        # Individual Days
        sch_rule.setApplyMonday(true) if day_of_week == 'Monday'
        sch_rule.setApplyTuesday(true) if day_of_week == 'Tuesday'
        sch_rule.setApplyWednesday(true) if day_of_week == 'Wednesday'
        sch_rule.setApplyThursday(true) if day_of_week == 'Thursday'
        sch_rule.setApplyFriday(true) if day_of_week == 'Friday'
        sch_rule.setApplySaturday(true) if day_of_week == 'Saturday'
        sch_rule.setApplySunday(true) if day_of_week == 'Sunday'
      
        # Reset the previous rule end date
        end_of_prev_rule = date + OpenStudio::Time.new(0, 24, 0, 0)
      
      end
      
    end

    return sch_ruleset
      
  end  
  
  # Generate the EMS used to implement the economizer
  # and staging controls for packaged single zone units.
  # @note The resulting EMS doesn't actually get added to
  # the IDF yet.
  #
  def apply_single_zone_controls(template, climate_zone)
  
    # Number of stages is determined by the template
    num_stages = nil
    case template       
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', 'NECB 2011'
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: No special economizer controls were modeled.")
      return true
    when '90.1-2004', '90.1-2007'
      num_stages = 1
    when  '90.1-2010', '90.1-2013'
      num_stages = 2
    end
  
    # Scrub special characters from the system name
    sn = self.name.get.to_s
    snc = sn.gsub(/\W/,'').gsub('_','')
   
    # Get the zone name
    zone = self.thermalZones[0]
    zone_name = zone.name.get.to_s
    zn_name_clean = zone_name.gsub(/\W/,'_')
    
    # Zone air node
    zone_air_node_name = zone.zoneAirNode.name.get    
    
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    oa_control_name = oa_control.name.get
    oa_node_name = oa_sys.outboardOANode.get.name.get
    
    # Get the name of the min oa schedule
    min_oa_sch_name = nil
    if oa_control.minimumOutdoorAirSchedule.is_initialized
      min_oa_sch_name = oa_control.minimumOutdoorAirSchedule.get.name.get
    else
      min_oa_sch_name = self.model.alwaysOnDiscreteSchedule.name.get
    end
    
    # Get the supply fan
    if self.supplyFan.empty?
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: No supply fan found, cannot apply DX fan/economizer control.")
      return false
    end
    fan = self.supplyFan.get
    fan_name = fan.name.get
    
    # Supply outlet node
    sup_out_node = self.supplyOutletNode
    sup_out_node_name = sup_out_node.name.get
    
    # DX Cooling Coil
    dx_coil = nil
    self.supplyComponents.each do |equip|
      if equip.to_CoilCoolingDXSingleSpeed.is_initialized
        dx_coil = equip.to_CoilCoolingDXSingleSpeed.get
      elsif equip.to_CoilCoolingDXTwoSpeed.is_initialized
        dx_coil = equip.to_CoilCoolingDXTwoSpeed.get
      end
    end
    if dx_coil.nil?
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: No DX cooling coil found, cannot apply DX fan/economizer control.")
      return false
    end
    dx_coil_name = dx_coil.name.get
    dx_coilsys_name = "#{dx_coil_name} CoilSystem"
    
    # Heating Coil
    htg_coil = nil
    self.supplyComponents.each do |equip|
      if equip.to_CoilHeatingGas.is_initialized
        htg_coil = equip.to_CoilHeatingGas.get
      elsif equip.to_CoilHeatingElectric.is_initialized
        htg_coil = equip.to_CoilHeatingElectric.get
      elsif equip.to_CoilHeatingWater.is_initialized
        htg_coil = equip.to_CoilHeatingWater.get
      end
    end
    if htg_coil.nil?
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: No heating coil found, cannot apply DX fan/economizer control.")
      return false
    end
    htg_coil_name = htg_coil.name.get
 
    # Create an economizer maximum OA fraction schedule with
    # a maximum of 70% to reflect damper leakage per PNNL
    max_oa_sch_name = "#{snc}maxOASch"
    max_oa_sch = OpenStudio::Model::ScheduleRuleset.new(self.model)
    max_oa_sch.setName(max_oa_sch_name)
    max_oa_sch.defaultDaySchedule.setName("#{max_oa_sch_name}Default")
    max_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 0.7)
    oa_control.setMaximumFractionofOutdoorAirSchedule(max_oa_sch)
 
    ems = "
    
    ! Sensors
    
    EnergyManagementSystem:Sensor,
      #{snc}OASch,           
      #{min_oa_sch_name},         !- Output:Variable or Output:Meter Index Key Name,            
      Schedule Value;          !- Output:Variable or Output:Meter Name

    EnergyManagementSystem:Sensor,
      #{zn_name_clean}Temp,
      #{zone_air_node_name},  !- Output:Variable or Output:Meter Index Key Name
      System Node Temperature; !- Output:Variable or Output:Meter Name

    EnergyManagementSystem:Sensor,
      #{snc}OAFlowMass,     
      #{oa_node_name}, !- Output:Variable or Output:Meter Index Key Name
      System Node Mass Flow Rate;  !- Output:Variable or Output:Meter Name

    EnergyManagementSystem:Sensor,
      #{snc}HeatingRTF,     
      #{htg_coil_name},        !- Output:Variable or Output:Meter Index Key Name
      Heating Coil Runtime Fraction;  !- Output:Variable or Output:Meter Name

    EnergyManagementSystem:Sensor,
      #{snc}RTF,            
      #{dx_coil_name}, !- Output:Variable or Output:Meter Index Key Name
      Cooling Coil Runtime Fraction;  !- Output:Variable or Output:Meter Name

    EnergyManagementSystem:Sensor,
      #{snc}SpeedRatio,     
      #{dx_coilsys_name},        !- Output:Variable or Output:Meter Index Key Name
      Coil System Compressor Speed Ratio;  !- Output:Variable or Output:Meter Name

    EnergyManagementSystem:Sensor,
      #{snc}DATRqd,        
      #{sup_out_node_name},  !- Output:Variable or Output:Meter Index Key Name
      System Node Setpoint Temperature;  !- Output:Variable or Output:Meter Name

    EnergyManagementSystem:Sensor,
      #{snc}EconoStatus,   
      #{sn},              !- Output:Variable or Output:Meter Index Key Name
      Air System Outdoor Air Economizer Status;  !- Output:Variable or Output:Meter Name

    ! Internal Variables

    EnergyManagementSystem:InternalVariable,
      #{snc}FanDesignPressure,
      #{fan_name},          !- Internal Data Index Key Name
      Fan Nominal Pressure Rise;  !- Internal Data Type

    EnergyManagementSystem:InternalVariable,
      #{snc}DesignFlowMass, 
      #{oa_control_name},!- Internal Data Index Key Name
      Outdoor Air Controller Maximum Mass Flow Rate;  !- Internal Data Type

    EnergyManagementSystem:InternalVariable,
      #{snc}OADesignMass,   
      #{oa_control_name},!- Internal Data Index Key Name
      Outdoor Air Controller Minimum Mass Flow Rate;  !- Internal Data Type

    ! Actuators

    EnergyManagementSystem:Actuator,
      #{snc}FanPressure,   
      #{fan_name},          !- Actuated Component Unique Name
      Fan,                     !- Actuated Component Type
      Fan Pressure Rise;       !- Actuated Component Control Type

    EnergyManagementSystem:Actuator,
      #{snc}TimestepEconEff,!- Name
      #{max_oa_sch_name},  !- Actuated Component Unique Name
      Schedule:Year,       !- Actuated Component Type
      Schedule Value;          !- Actuated Component Control Type

    EnergyManagementSystem:GlobalVariable,
      #{snc}FanPwrExp,   !- Erl Variable 1 Name
      #{snc}Stg1Spd,      !- Erl Variable 2 Name
      #{snc}Stg2Spd,      !- Erl Variable 3 Name
      #{snc}HeatSpeed,      
      #{snc}VenSpeed,       
      #{snc}NumberofStages; 

    EnergyManagementSystem:Program,
      #{snc}EconomizerCTRLProg,
      SET #{snc}TimestepEconEff = 0.7,  
      SET #{snc}MaxE = 0.7,   
      SET #{snc}DATRqd = (#{snc}DATRqd*1.8)+32,
      SET OATF = (OATF*1.8)+32,
      SET OAwbF = (OAwbF*1.8)+32,
      IF #{snc}OAFlowMass > (#{snc}OADesignMass*#{snc}OASch),
      SET #{snc}EconoActive = 1,
      ELSE,                  
      SET #{snc}EconoActive = 0,
      ENDIF,                 
      SET #{snc}dTNeeded = 75-#{snc}DATRqd,
      SET #{snc}CoolDesdT = ((98*0.15)+(75*(1-0.15)))-55,
      SET #{snc}CoolLoad = #{snc}dTNeeded/ #{snc}CoolDesdT,
      IF #{snc}CoolLoad > 1, 
      SET #{snc}CoolLoad = 1,
      ELSEIF #{snc}CoolLoad < 0,
      SET #{snc}CoolLoad = 0,
      ENDIF,                 
      IF #{snc}EconoActive == 1,
      SET #{snc}Stage = #{snc}NumberofStages,
      IF #{snc}Stage == 2,  
      IF #{snc}CoolLoad < 0.6,
      SET #{snc}TimestepEconEff = #{snc}MaxE,
      ELSE,                  
      SET #{snc}ECOEff = 0-2.18919863612305,
      SET #{snc}ECOEff = #{snc}ECOEff+(0-0.674461284910428*#{snc}CoolLoad),
      SET #{snc}ECOEff = #{snc}ECOEff+(0.000459106275872404*(OATF^2)),
      SET #{snc}ECOEff = #{snc}ECOEff+(0-0.00000484778537945252*(OATF^3)),
      SET #{snc}ECOEff = #{snc}ECOEff+(0.182915713033586*OAwbF),
      SET #{snc}ECOEff = #{snc}ECOEff+(0-0.00382838660261133*(OAwbF^2)),
      SET #{snc}ECOEff = #{snc}ECOEff+(0.0000255567460240583*(OAwbF^3)),
      SET #{snc}TimestepEconEff = #{snc}ECOEff,
      ENDIF,                 
      ELSE,                  
      SET #{snc}ECOEff = 2.36337942464462,
      SET #{snc}ECOEff = #{snc}ECOEff+(0-0.409939515512619*#{snc}CoolLoad),
      SET #{snc}ECOEff = #{snc}ECOEff+(0-0.0565205596792225*OAwbF),
      SET #{snc}ECOEff = #{snc}ECOEff+(0-0.0000632612294169389*(OATF^2)),
      SET #{snc}TimestepEconEff = #{snc}ECOEff+(0.000571724868775081*(OAwbF^2)),
      ENDIF,                 
      IF #{snc}TimestepEconEff > #{snc}MaxE,
      SET #{snc}TimestepEconEff = #{snc}MaxE,
      ELSEIF #{snc}TimestepEconEff < (#{snc}OADesignMass*#{snc}OASch),
      SET #{snc}TimestepEconEff = (#{snc}OADesignMass*#{snc}OASch),
      ENDIF,                 
      ENDIF;                 

    EnergyManagementSystem:Program,
      #{snc}SetFanPar,    
      IF #{snc}NumberofStages == 1,  
      Return,                  
      ENDIF,                 
      SET #{snc}FanPwrExp = 2.2,
      SET #{snc}OAFrac = #{snc}OAFlowMass/#{snc}DesignFlowMass,
      IF  #{snc}OAFrac < 0.66,
      SET #{snc}VenSpeed = 0.66,
      SET #{snc}Stg1Spd = 0.66,
      ELSE,                  
      SET #{snc}VenSpeed = #{snc}OAFrac,
      SET #{snc}Stg1Spd = #{snc}OAFrac,
      ENDIF,                 
      SET #{snc}Stg2Spd = 1.0,
      SET #{snc}HeatSpeed = 1.0;

    EnergyManagementSystem:Program,
      #{snc}FanControl,    
      IF #{snc}NumberofStages == 1,  
      Return,                  
      ENDIF,                 
      IF #{snc}HeatingRTF > 0,
      SET #{snc}Heating = #{snc}HeatingRTF,
      SET #{snc}Ven = 1-#{snc}HeatingRTF,
      SET #{snc}Eco = 0,    
      SET #{snc}Stage1 = 0, 
      SET #{snc}Stage2 = 0, 
      ELSE,                  
      SET #{snc}Heating = 0,
      SET #{snc}EcoSpeed = #{snc}VenSpeed,
      IF #{snc}SpeedRatio == 0,
      IF #{snc}RTF > 0,     
      SET #{snc}Stage1 = #{snc}RTF,
      SET #{snc}Stage2 = 0, 
      SET #{snc}Ven = 1-#{snc}RTF,
      SET #{snc}Eco = 0,    
      IF #{snc}OAFlowMass > (#{snc}OADesignMass*#{snc}OASch),
      SET #{snc}Stg1Spd = 1.0,
      ENDIF,                 
      ELSE,                  
      SET #{snc}Stage1 = 0, 
      SET #{snc}Stage2 = 0, 
      IF #{snc}OAFlowMass > (#{snc}OADesignMass*#{snc}OASch),
      SET #{snc}Eco = 1.0,  
      SET #{snc}Ven = 0,           
      !Calculate the expected discharge air temperature if the system runs at its low speed      
      SET #{snc}ExpDAT = #{snc}DATRqd-(1-#{snc}VenSpeed)*#{zn_name_clean}Temp,
      SET #{snc}ExpDAT = #{snc}ExpDAT/#{snc}VenSpeed,
      IF OATF > #{snc}ExpDAT,
      SET #{snc}EcoSpeed = #{snc}Stg2Spd,
      ENDIF,                 
      ELSE,                  
      SET #{snc}Eco = 0,    
      SET #{snc}Ven = 1.0,  
      ENDIF,                 
      ENDIF,                 
      ELSE,                  
      SET #{snc}Stage1 = 1-#{snc}SpeedRatio,
      SET #{snc}Stage2 = #{snc}SpeedRatio,
      SET #{snc}Ven = 0,    
      SET #{snc}Eco = 0,    
      IF #{snc}OAFlowMass > (#{snc}OADesignMass*#{snc}OASch),
      SET #{snc}Stg1Spd = 1.0,
      ENDIF,                 
      ENDIF,                 
      ENDIF,                  
      ! For each mode, (percent time in mode)*(fanSpeer^PwrExp) is the contribution to weighted fan power over time step
      SET #{snc}FPR = #{snc}Ven*(#{snc}VenSpeed ^ #{snc}FanPwrExp),
      SET #{snc}FPR = #{snc}FPR+#{snc}Eco*(#{snc}EcoSpeed^#{snc}FanPwrExp),
      SET #{snc}FPR1 = #{snc}Stage1*(#{snc}Stg1Spd^#{snc}FanPwrExp),
      SET #{snc}FPR = #{snc}FPR+#{snc}FPR1,
      SET #{snc}FPR2 = #{snc}Stage2*(#{snc}Stg2Spd^#{snc}FanPwrExp),
      SET #{snc}FPR = #{snc}FPR+#{snc}FPR2,
      SET #{snc}FPR3 = #{snc}Heating*(#{snc}HeatSpeed^#{snc}FanPwrExp),
      SET #{snc}FanPwrRatio = #{snc}FPR+ #{snc}FPR3,
      ! system fan power is directly proportional to static pressure, so this change linearly adjusts fan energy for speed control
      SET #{snc}FanPressure = #{snc}FanDesignPressure*#{snc}FanPwrRatio;

    EnergyManagementSystem:Program,
      #{snc}SetNumberofStages,
      SET #{snc}NumberofStages =  #{num_stages};

    EnergyManagementSystem:ProgramCallingManager,
      #{snc}SetNumberofStagesCallingManager,
      BeginNewEnvironment,
      #{snc}SetNumberofStages;  !- Program Name 1

    EnergyManagementSystem:ProgramCallingManager,
      #{snc}ECOManager,    
      InsideHVACSystemIterationLoop,  !- EnergyPlus Model Calling Point
      #{snc}EconomizerCTRLProg;  !- Program Name 1

    EnergyManagementSystem:ProgramCallingManager,
      #{snc}FanParametermanager,
      BeginNewEnvironment,
      #{snc}SetFanPar;

    EnergyManagementSystem:ProgramCallingManager,
      #{snc}FanMainManager,
      BeginTimestepBeforePredictor,
      #{snc}FanControl;

    "
    
    # Write the ems out
    # File.open("#{Dir.pwd}/#{snc}_ems.idf", 'w') do |file|  
      # file.puts ems
    # end
  
    return ems
  
  end
  
  
  # Calculate the total floor area of all zones attached
  # to the air loop, in m^2.
  #
  # return [Double] the total floor area of all zones attached
  # to the air loop, in m^2.
  def floor_area_served()
  
    total_area = 0.0
  
    self.thermalZones.each do |zone|
      total_area += zone.floorArea
    end

    return total_area
  
  end

  
end

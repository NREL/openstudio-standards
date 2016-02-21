
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::PlantLoop

  # Apply all standard required controls to the plantloop
  #
  # @param (see #is_economizer_required)
  # @return [Bool] returns true if successful, false if not
  def apply_standard_controls(template, climate_zone)
    
    # Variable flow system
    if self.is_variable_flow_required(template)
      self.enable_variable_flow(template)
    end
    
    # Supply water temperature reset
    if self.is_supply_water_temperature_reset_required(template)
      self.enable_supply_water_temperature_reset
    end

  end  

  def enable_variable_flow(template)
  
  end
  
  def is_variable_flow_system
    
    variable_flow = false
    
    # Modify all the primary pumps
    self.supplyComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        variable_flow = true
      end
    end
    
    # Modify all the secondary pumps
    self.demandComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        variable_flow = true
      end
    end
    
    return variable_flow
  
  end


  # Todo: I think it makes more sense to sense the motor efficiency right there...
  # But actually it's completely irrelevant... you could set at 0.9 and just calculate the pressurise rise to have your 19 W/GPM or whatever
  def apply_performance_rating_method_baseline_pump_power(template)
    
    # Determine the pumping power per
    # flow based on loop type.
    pri_w_per_gpm = nil
    sec_w_per_gpm = nil

    sizing_plant = self.sizingPlant
    loop_type = sizing_plant.loopType    
    
    case loop_type
    when 'Heating'
    
      has_district_heating = false
      self.supplyComponents.each do |sc|
        if sc.to_DistrictHeating.is_initialized
          has_district_heating = true
        end
      end

      if has_district_heating # District HW
        pri_w_per_gpm = 14.0
      else # HW 
        pri_w_per_gpm = 19.0
      end

    when 'Cooling'
  
      has_district_cooling = false
      self.supplyComponents.each do |sc|
        if sc.to_DistrictCooling.is_initialized
          has_district_cooling = true
        end
      end
  
      has_secondary_pump = false
      self.demandComponents.each do |sc|
        if sc.to_PumpConstantSpeed.is_initialized || sc.to_PumpVariableSpeed.is_initialized
          has_secondary_pump = true
        end
      end  

      if has_district_cooling # District CHW
        pri_w_per_gpm = 16.0
      elsif has_secondary_pump # Primary/secondary CHW
        pri_w_per_gpm = 9.0
        sec_w_per_gpm = 13.0
      else # Primary only CHW
        pri_w_per_gpm = 22.0
      end

    when 'Condenser'
    
      # TODO prm condenser loop pump power
      pri_w_per_gpm = 19.0

    end
  
    # Modify all the primary pumps
    self.supplyComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
        pump.set_performance_rating_method_pressure_rise_and_motor_efficiency(pri_w_per_gpm, template)
      elsif sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump.set_performance_rating_method_pressure_rise_and_motor_efficiency(pri_w_per_gpm, template)
      end
    end
    
    # Modify all the secondary pumps
    self.demandComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
        pump.set_performance_rating_method_pressure_rise_and_motor_efficiency(sec_w_per_gpm, template)
      elsif sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump.set_performance_rating_method_pressure_rise_and_motor_efficiency(sec_w_per_gpm, template)
      end
    end
  
    return true
  
  end
  
  def apply_performance_rating_method_baseline_temperatures(template)
  
    sizing_plant = self.sizingPlant
    loop_type = sizing_plant.loopType
    case loop_type
    when 'Heating'

      # Loop properties
      # G3.1.3.3 - HW Supply at 180°F, return at 130°F
      hw_temp_f = 180
      hw_delta_t_r = 50
      min_temp_f = 50
      
      hw_temp_c = OpenStudio.convert(hw_temp_f,'F','C').get
      hw_delta_t_k = OpenStudio.convert(hw_delta_t_r,'R','K').get
      min_temp_c = OpenStudio.convert(min_temp_f,'F','C').get

      sizing_plant.setDesignLoopExitTemperature(hw_temp_c)
      sizing_plant.setLoopDesignTemperatureDifference(hw_delta_t_k)
      self.setMinimumLoopTemperature(min_temp_c)

      # ASHRAE Appendix G - G3.1.3.4 (for ASHRAE 90.1-2004, 2007 and 2010)
      # HW reset: 180°F at 20°F and below, 150°F at 50°F and above
      self.enable_supply_water_temperature_reset

      # Boiler properties
      self.supplyComponents.each do |sc|
        if sc.to_BoilerHotWater.is_initialized
          boiler = sc.to_BoilerHotWater.get
          boiler.setDesignWaterOutletTemperature(hw_temp_c)
        end
      end   
  
    when 'Cooling'
    
      # Loop properties
      # G3.1.3.8 - LWT 44 / EWT 56
      chw_temp_f = 44
      chw_delta_t_r = 12
      min_temp_f = 34
      max_temp_f = 200
      # For water-cooled chillers this is the water temperature entering the condenser (e.g., leaving the cooling tower).
      ref_cond_wtr_temp_f = 85

      chw_temp_c = OpenStudio.convert(chw_temp_f,'F','C').get
      chw_delta_t_k = OpenStudio.convert(chw_delta_t_r,'R','K').get
      min_temp_c = OpenStudio.convert(min_temp_f,'F','C').get
      max_temp_c = OpenStudio.convert(max_temp_f,'F','C').get
      ref_cond_wtr_temp_c = OpenStudio.convert(ref_cond_wtr_temp_f,'F','C').get

      sizing_plant.setDesignLoopExitTemperature(chw_temp_c)
      sizing_plant.setLoopDesignTemperatureDifference(chw_delta_t_k)
      self.setMinimumLoopTemperature(min_temp_c)
      self.setMaximumLoopTemperature(max_temp_c)

      # ASHRAE Appendix G - G3.1.3.9 (for ASHRAE 90.1-2004, 2007 and 2010)
      # ChW reset: 44°F at 80°F and above, 54°F at 60°F and below
      self.enable_supply_water_temperature_reset
      
      # Chiller properties
      self.supplyComponents.each do |sc|
        if sc.to_ChillerElectricEIR.is_initialized
          chiller = sc.to_ChillerElectricEIR.get
          chiller.setReferenceLeavingChilledWaterTemperature(chw_temp_c)
          chiller.setReferenceEnteringCondenserFluidTemperature(ref_cond_wtr_temp_c)
        end
      end
      
    when 'Condenser'
    
      # G3.1.3.11 - LCnWT 85°F or 10°F approaching design wet bulb temperature, whichever is lower
      # Design Temperature rise of 10°F => Range: 10°F
      lcnwt_f = 85   # See notes and proposed alternative below, if we want to actually check the design days...
      range_t_r = 10
      lcnwt_c = OpenStudio.convert(lcnwt_f,'F','C').get
      range_t_k = OpenStudio.convert(range_t_r,'R','K').get

      # Typical design of min temp is really around 40°F (that's what basin heaters, when used, are sized for usually)
      min_temp_f = 34
      max_temp_f = 200
      min_temp_c = OpenStudio.convert(min_temp_f,'F','C').get
      max_temp_c = OpenStudio.convert(max_temp_f,'F','C').get

      sizing_plant.setDesignLoopExitTemperature(lcnwt_c)
      sizing_plant.setLoopDesignTemperatureDifference(range_t_k)
      self.setMinimumLoopTemperature(min_temp_c)
      self.setMaximumLoopTemperature(max_temp_c)

      # G3.1.3.11 - Tower shall be controlled to maintain a 70°F LCnWT where weather permits
      # Use a SetpointManager:FollowOutdoorAirTemperature
      float_down_to_f = 70
      float_down_to_c = OpenStudio.convert(float_down_to_f,'F','C').get

      # Todo: Problem is what to set for Offset Temperature Difference (=approach):
      # * if unreasonably low approach, fan runs full blast and energy consumption is penalized
      # * if too high, you don't get as much energy savings...
      # "LCnWT 85°F or 10°F approaching design wet bulb temperature, whichever is lower" ==> approach is maximum 10, could be less depending on design conditions
      # In most cases in the US a tower will be sized on CTI conditions, 78°F WB, so usually 7°F approach.
      # Could also check the design days, but begs the question of finding the right one to begin with if you have several...
      # You'll need to deal with potentially different 'Humidity Indicating Type'
      #
      # See https://unmethours.com/question/12530/appendix-g-condenser-water-temperature-reset-in-energyplus/
      # See http://www.comnet.org/mgp/content/cooling-towers?purpose=0#footnote1_do6jpuh

      # This is an example of how jmarrec would implement checking the design days
=begin
summer_dday_wbs = []
model.getDesignDays.each do |dd|
  model.getDesignDays.each do |dd|
    if dd.dayType == 'SummerDesignDay' && dd.humidityIndicatingType == 'Wetbulb'
      summer_dday_wbs << dd.humidityIndicatingConditionsAtMaximumDryBulb
    end
  end
end

# Then take worst case condition (max), or the average?
design_inlet_wb_c = summer_dday_wbs.max
design_inlet_wb_f = OpenStudio.convert(design_inlet_wb_c,'C','F').get
lcnwt_f = 85
lcnwt_10f_approach = design_inlet_wb_f+10
lcnwt_f = lcnwt_10f_approach if lcnwt_10f_approach < 85



=end

      design_inlet_wb_f = 78
      design_approach_r = 7
      design_inlet_wb_c = OpenStudio.convert(design_inlet_wb_f,'F','C').get
      design_approach_k = OpenStudio.convert(design_approach_r,'R','K').get

      cw_t_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(self.model)
      cw_t_stpt_manager.setReferenceTemperatureType('OutdoorAirWetBulb')
      cw_t_stpt_manager.setMaximumSetpointTemperature(lcnwt_c)
      cw_t_stpt_manager.setMinimumSetpointTemperature(float_down_to_c)
      cw_t_stpt_manager.setOffsetTemperatureDifference(design_approach_k)
      cw_t_stpt_manager.addToNode(self.supplyOutletNode)

      # Cooling Tower properties
      self.supplyComponents.each do |sc|
        if sc.to_CoolingTowerSingleSpeed.is_initialized
          ct = sc.to_CoolingTowerSingleSpeed.get
          ct.setDesignInletAirWetBulbTemperature(design_inlet_wb_c)
          ct.setDesignApproachTemperature(design_approach_k)
          ct.setDesignRangeTemperature(range_t_k)
        elsif sc.to_CoolingTowerTwoSpeed.is_initialized
          ct = sc.to_CoolingTowerTwoSpeed.get
          ct.setDesignInletAirWetBulbTemperature(design_inlet_wb_c)
          ct.setDesignApproachTemperature(design_approach_k)
          ct.setDesignRangeTemperature(range_t_k)
        elsif sc.to_CoolingTowerVariableSpeed.is_initialized
          ct = sc.to_CoolingTowerVariableSpeed.get
          ct.setDesignInletAirWetBulbTemperature(design_inlet_wb_c)
          ct.setDesignApproachTemperature(design_approach_k)
          ct.setDesignRangeTemperature(range_t_k)
        elsif sc.to_CoolingTowerPerformanceYorkCalc.is_initialized
          ct = sc.to_CoolingTowerPerformanceYorkCalc.get
          ct.setDesignInletAirWetBulbTemperature(design_inlet_wb_c)
          ct.setDesignApproachTemperature(design_approach_k)
          ct.setDesignRangeTemperature(range_t_k)
        elsif sc.to_CoolingTowerPerformanceCoolTools.is_initialized
          ct = sc.to_CoolingTowerPerformanceCoolTools.get
          ct.setDesignInletAirWetBulbTemperature(design_inlet_wb_c)
          ct.setDesignApproachTemperature(design_approach_k)
          ct.setDesignRangeTemperature(range_t_k)
        end

      end

    end
  
    return true
  
  end
   
  def is_supply_water_temperature_reset_required(template)

    reset_required = false

    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      
      # Not required before 90.1-2004
      return reset_required
      
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      
      # Not required for variable flow systems
      if is_variable_flow_system
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{self.name}: supply water temperature reset not required for variable flow systems per 6.5.4.3 Exception b.")
        return reset_required
      end
      
      # Determine the capacity of the system
      heating_capacity_w = self.total_heating_capacity
      cooling_capacity_w = self.total_cooling_capacity
      
      heating_capacity_btu_per_hr = OpenStudio.convert(heating_capacity_w,'W','Btu/hr').get
      cooling_capacity_btu_per_hr = OpenStudio.convert(cooling_capacity_w,'W','Btu/hr').get
     
      # Compare against capacity minimum requirement
      min_cap_btu_per_hr = 300000
      if heating_capacity_btu_per_hr > min_cap_btu_per_hr 
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{self.name}: supply water temperature reset is required because heating capacity of #{heating_capacity_btu_per_hr.round} Btu/hr exceeds the minimum threshold of #{min_cap_btu_per_hr.round} Btu/hr.")
        reset_required = true
      elsif cooling_capacity_btu_per_hr > min_cap_btu_per_hr
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{self.name}: supply water temperature reset is required because cooling capacity of #{cooling_capacity_btu_per_hr.round} Btu/hr exceeds the minimum threshold of #{min_cap_btu_per_hr.round} Btu/hr.")
        reset_required = true
      else
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{self.name}: supply water temperature reset is not required because capacity is less than minimum of #{min_cap_btu_per_hr.round} Btu/hr.")
      end
    
    end

    return reset_required
  
  end
  
  def enable_supply_water_temperature_reset
  
    # Get the current setpoint manager on the outlet node
    # and determine if already has temperature reset
    spms = self.supplyOutletNode.setpointManagers
    spms.each do |spm|
      if spm.to_SetpointManagerOutdoorAirReset
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{self.name}: supply water temperature reset is already enabled.")
        return false
      end
    end

    # Get the design water temperature
    sizing_plant = self.sizingPlant
    design_temp_c = sizing_plant.loopDesignExitTemperature
    design_temp_f = OpenStudio.convert(design_temp_c,'C','F').get
    loop_type = self.loopType
    
    # Apply the reset, depending on the type of loop.
    case loop_type
    when 'Heating'
   
      # Hot water as-designed when cold outside
      hwt_at_lo_oat_f = design_temp_f
      hwt_at_lo_oat_c = OpenStudio.convert(hwt_at_lo_oat_f, 'F', 'C').get
      # 30F decrease when it's hot outside,
      # and therefore less heating capacity is likely required.
      decrease_f = 30.0
      hwt_at_hi_oat_f = hwt_at_lo_oat_f - decrease_f 
      hwt_at_hi_oat_c = OpenStudio.convert(hwt_at_hi_oat_f, 'C', 'F').get

      # Define the high and low outdoor air temperatures
      lo_oat_f = 20
      lo_oat_c = OpenStudio.convert(lo_oat_f, 'F', 'C').get
      hi_oat_f = 50
      hi_oat_c = OpenStudio.convert(hi_oat_f, 'F', 'C').get
      
      # Create a setpoint manager
      hwt_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(self.model)
      hwt_oa_reset.setName("#{self.name} HW Temp Reset")
      hwt_oa_reset.setControlVariable('Temperature')
      hwt_oa_reset.setSetpointatOutdoorLowTemperature(hwt_at_lo_oat_c)
      hwt_oa_reset.setOutdoorLowTemperature(lo_oat_c)
      hwt_oa_reset.setSetpointatOutdoorHighTemperature(hwt_at_hi_oat_c)
      hwt_oa_reset.setOutdoorHighTemperature(hi_oat_c)
      hwt_oa_reset.addToNode(self.supplyOutletNode)
    
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{self.name}: hot water temperature reset from #{hwt_at_lo_oat_f.round}F to #{hwt_at_hi_oat_f}F between outdoor air temps of #{lo_oat_f.round}F and #{hi_oat_f}F.")
    
    when 'Cooling'
      
      # Chilled water as-designed when hot outside
      chwt_at_hi_oat_f = design_temp_f
      chwt_at_hi_oat_c = OpenStudio.convert(chwt_at_hi_oat_f, 'F', 'C').get
      # 10F increase when it's cold outside,
      # and therefore less cooling capacity is likely required.
      increase_f = 10.0
      chwt_at_lo_oat_f = chwt_at_hi_oat_f + increase_f
      chwt_at_lo_oat_c = OpenStudio.convert(chwt_at_lo_oat_f, 'F', 'C').get
      
      # Define the high and low outdoor air temperatures
      lo_oat_f = 50
      lo_oat_c = OpenStudio.convert(lo_oat_f, 'F', 'C').get
      hi_oat_f = 70
      hi_oat_c = OpenStudio.convert(hi_oat_f, 'F', 'C').get
      
      # Create a setpoint manager
      chwt_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(self.model)
      chwt_oa_reset.setName("#{self.name} CHW Temp Reset")
      chwt_oa_reset.setControlVariable('Temperature')
      chwt_oa_reset.setSetpointatOutdoorLowTemperature(chwt_at_lo_oat_c)
      chwt_oa_reset.setOutdoorLowTemperature(lo_oat_c)
      chwt_oa_reset.setSetpointatOutdoorHighTemperature(chwt_at_hi_oat_c)
      chwt_oa_reset.setOutdoorHighTemperature(hi_oat_c)
      chwt_oa_reset.addToNode(self.supplyOutletNode)

      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{self.name}: chilled water temperature reset from #{chwt_at_hi_oat_f}F to #{chwt_at_lo_oat_f.round}F between outdoor air temps of #{hi_oat_f}F and #{lo_oat_f.round}F.")      
      
    else
      
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{self.name}: cannot enable supply water temperature reset for a #{loop_type} loop.")
      return false
    
    end
  
    return true
  
  end
  
  # Get the total cooling capacity for the plant loop
  #
  # @return [Double] total cooling capacity
  #   units = Watts (W)
  def total_cooling_capacity
  
    # Sum the cooling capacity for all cooling components
    # on the plant loop.
    total_cooling_capacity_w = 0
    self.supplyComponents.each do |sc|
      # ChillerElectricEIR
      if sc.to_ChillerElectricEIR.is_initialized
        chiller = sc.to_ChillerElectricEIR.get
        if chiller.referenceCapacity.is_initialized
          total_cooling_capacity_w += chiller.referenceCapacity.get
        elsif chiller.autosizedReferenceCapacity.is_initialized
          total_cooling_capacity_w += chiller.autosizedReferenceCapacity.get
        else
          OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{chiller.name} is not available, total cooling capacity of plant loop will be incorrect when applying standard.")
        end
      end
    end

    total_cooling_capacity_tons = OpenStudio.convert(total_cooling_capacity_w,'W','ton').get
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}, cooling capacity is #{total_cooling_capacity_tons.round} tons of refrigeration.")    
    
    return total_cooling_capacity_w
  
  end
  
  # Get the total heating capacity for the plant loop
  #
  # @return [Double] total heating capacity
  #   units = Watts (W)
  def total_heating_capacity
  
    # Sum the heating capacity for all heating components
    # on the plant loop.
    total_heating_capacity_w = 0
    self.supplyComponents.each do |sc|
      # BoilerHotWater
      if sc.to_BoilerHotWater.is_initialized
        boiler = sc.to_BoilerHotWater.get
        if boiler.nominalCapacity.is_initialized
          total_heating_capacity_w += boiler.nominalCapacity.get
        elsif boiler.autosizedNominalCapacity.is_initialized
          total_heating_capacity_w += boiler.autosizedNominalCapacity.get
        else
          OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{boiler.name} is not available, total cooling capacity of plant loop will be incorrect when applying standard.")
        end
      end
    end

    total_heating_capacity_kbtu_per_hr = OpenStudio.convert(total_heating_capacity_w,'W','tons').get
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}, heating capacity is #{total_heating_capacity_kbtu_per_hr.round} kBtu/hr.")    
    
    return total_heating_capacity_w
  
  end
  
  def total_floor_area_served
    
    sizing_plant = self.sizingPlant
    loop_type = sizing_plant.loopType
    
    # Get all the coils served by this loop
    coils = []
    case loop_type
    when 'Heating'  
      self.demandComponents.each do |dc|
        if dc.to_CoilHeatingWater.is_initialized
          coils << dc.to_CoilHeatingWater.get
        end
      end
    when 'Cooling'
      self.demandComponents.each do |dc|
        if dc.to_CoilCoolingWater.is_initialized
          coils << dc.to_CoilCoolingWater.get
        end
      end
    else
      return 0.0
    end
    
    # The coil can either be on an airloop (as a main heating coil)
    # in an HVAC Component (like a unitary system on an airloop),
    # or in a Zone HVAC Component (like a fan coil).
    zones_served = []
    coils.each do |coil|
    
      if coil.airLoopHVAC.is_initialized
        air_loop = coil.airLoopHVAC.get
        zones_served += air_loop.thermalZones
      elsif coil.containingHVACComponent.is_initialized
        containing_comp = coil.containingHVACComponent.get
        if containing_comp.airLoopHVAC.is_initialized
          air_loop = containing_comp.airLoopHVAC.get
          zones_served += air_loop.thermalZones
        end
      elsif coil.containingZoneHVACComponent.is_initialized
        zone_hvac = coil.containingZoneHVACComponent.get
        if zone_hvac.thermalZone.is_initialized
          zones_served << zone_hvac.thermalZone.get
        end
      end
    
    end    
    
    # Add up the area of all zones served.
    # Make sure to only add unique zones in
    # case the same zone is served by multiple
    # coils served by the same loop.  For example,
    # a HW and Reheat 
    area_served_m2 = 0.0
    zones_served.uniq.each do |zone|
      area_served_m2 += zone.floorArea
    end
    area_served_ft2 = OpenStudio.convert(area_served_m2,'m^2','ft^2').get

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}, serves #{area_served_ft2.round} ft^2.")
  
    return area_served_m2
  
  end

  def apply_performance_rating_method_baseline_pumping_type(template)
    
    sizing_plant = self.sizingPlant
    loop_type = sizing_plant.loopType    
    
    case loop_type
    when 'Heating'
      
      # Hot water systems
    
      # Determine the minimum area to determine
      # pumping type.
      minimum_area_ft2 = nil
      case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        minimum_area_ft2 = 120000
      end
    
      # Determine the area served
      area_served_m2 = self.total_floor_area_served
      area_served_ft2 = OpenStudio.convert(area_served_m2,'m^2','ft^2').get
    
      # Determine the pump type 
      control_type = 'Riding Curve'
      if area_served_ft2 > minimum_area_ft2
        control_type = 'VSD No Reset'
      end
      
      # Modify all the primary pumps
      self.supplyComponents.each do |sc|
        if sc.to_PumpVariableSpeed.is_initialized
          pump = sc.to_PumpVariableSpeed.get
          pump.set_control_type(control_type)
        end
      end
 
       # Report out the pumping type
      unless control_type.nil?
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}, pump type is #{control_type}.")
      end

    when 'Cooling'

      # Chilled water systems
    
      # Determine the pumping type.
      # For some templates, this is
      # based on area.  For others, it is built
      # on cooling capacity.
      pri_control_type = nil
      sec_control_type = nil
      case template
      when '90.1-2004'

        minimum_area_ft2 = 120000
        
        # Determine the area served
        area_served_m2 = self.total_floor_area_served
        area_served_ft2 = OpenStudio.convert(area_served_m2,'m^2','ft^2').get
      
        # Determine the primary pump type 
        pri_control_type = 'Riding Curve'
        
        # Determine the secondary pump type
        sec_control_type = 'Riding Curve'
        if area_served_ft2 > minimum_area_ft2
          sec_control_type = 'VSD No Reset'
        end
      
      when '90.1-2007', '90.1-2010', '90.1-2013'
        
        minimum_cap_tons = 300
        
        # Determine the capacity
        cap_w = self.total_cooling_capacity
        cap_tons = OpenStudio.convert(cap_w,'m^2','ft^2').get
      
        # Determine the primary pump type 
        pri_control_type = 'Riding Curve'
        
        # Determine the secondary pump type
        sec_control_type = 'Riding Curve'
        if cap_tons > minimum_cap_tons
          sec_control_type = 'VSD No Reset'
        end
   
      end
      
      # Report out the pumping type
      unless pri_control_type.nil?
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}, primary pump type is #{pri_control_type}.")
      end

      unless sec_control_type.nil?
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}, secondary pump type is #{sec_control_type}.")
      end      
      
      # Modify all the primary pumps
      self.supplyComponents.each do |sc|
        if sc.to_PumpVariableSpeed.is_initialized
          pump = sc.to_PumpVariableSpeed.get
          pump.set_control_type(pri_control_type)
        end
      end    
    
      # Modify all the secondary pumps
      self.demandComponents.each do |sc|
        if sc.to_PumpVariableSpeed.is_initialized
          pump = sc.to_PumpVariableSpeed.get
          pump.set_control_type(sec_control_type)
        end
      end      

    when 'Condenser'
    
      # Condenser water systems
    
      # All condenser water loops are constant flow
      control_type = 'Riding Curve'

      # Report out the pumping type
      unless control_type.nil?
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}, pump type is #{control_type}.")
      end
      
      # Modify all primary pumps
      self.supplyComponents.each do |sc|
        if sc.to_PumpVariableSpeed.is_initialized
          pump = sc.to_PumpVariableSpeed.get
          pump.set_control_type(control_type)
        end
      end

    end
    
    return true
  
  end
  
  def apply_performance_rating_method_number_of_boilers(template)
    
    # Skip non-heating plants
    return true unless self.sizingPlant.loopType == 'Heating'

    # Determine the minimum area to determine
    # number of boilers.
    minimum_area_ft2 = nil
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      minimum_area_ft2 = 15000
    end
  
    # Determine the area served
    area_served_m2 = self.total_floor_area_served
    area_served_ft2 = OpenStudio.convert(area_served_m2,'m^2','ft^2').get
  
    # Do nothing if only one boiler is required
    return true if area_served_ft2 < minimum_area_ft2

    # Get all existing boilers
    boilers = []
    self.supplyComponents.each do |sc|
      if sc.to_BoilerHotWater.is_initialized
        boilers << sc.to_BoilerHotWater.get
      end
    end
    
    # Ensure there is only 1 boiler to start
    first_boiler = nil
    if boilers.size == 0
      return true
    elsif boilers.size > 1
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{self.name}, found #{boilers.size}, cannot split up per performance rating method baseline requirements.")
    else
      first_boiler = boilers[0]
    end
    
    # Clone the existing boiler and create
    # a new branch for it
    second_boiler = first_boiler.clone(self.model)
    if second_boiler.to_BoilerHotWater.is_initialized
      second_boiler = second_boiler.to_BoilerHotWater.get
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{self.name}, could not clone boiler #{first_boiler.name}, cannot apply the performance rating method number of boilers.")
      return false
    end
    self.addSupplyBranchForComponent(second_boiler)
    final_boilers = [first_boiler, second_boiler]
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{self.name}, added a second boiler.")


    # Set the sizing factor for all boilers evenly and Rename the boilers
    sizing_factor = (1.0/final_boilers.size).round(2)
    final_boilers.each_with_index do |boiler, i|
      boiler.setSizingFactor(sizing_factor)
      boiler.setName("#{first_boiler.name} #{i+1} of #{final_boilers.size}")
    end
    
    # Set the equipment to stage sequentially
    self.setLoadDistributionScheme('SequentialLoad')
  
    return true
  
  end

  def apply_performance_rating_method_number_of_chillers(template)
    
    # Skip non-cooling plants
    return true unless self.sizingPlant.loopType == 'Cooling'

    # Determine the number and type of chillers
    num_chillers = nil
    chiller_cooling_type = nil
    chiller_compressor_type = nil
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      
      # Determine the capacity of the loop
      cap_w = self.total_cooling_capacity
      cap_tons = OpenStudio.convert(cap_w,'W','ton').get
    
      if cap_tons <= 300
        num_chillers = 1
        chiller_cooling_type = 'WaterCooled'
        chiller_compressor_type = 'Rotary Screw'
      elsif cap_tons > 300 && cap_tons < 600
        num_chillers = 2
        chiller_cooling_type = 'WaterCooled'
        chiller_compressor_type = 'Rotary Screw'
      else
        # Max capacity of a single chiller
        max_cap_ton = 800.0
        num_chillers = (cap_tons/max_cap_ton).floor + 1
        # Must be at least 2 chillers
        num_chillers +=1 if num_chillers == 1
        chiller_cooling_type = 'WaterCooled'
        chiller_compressor_type = 'Centrifugal'        
      end
  
    end
    
    # Get all existing chillers
    chillers = []
    self.supplyComponents.each do |sc|
      if sc.to_ChillerElectricEIR.is_initialized
        chillers << sc.to_ChillerElectricEIR.get
      end
    end

    # Ensure there is only 1 chiller to start
    first_chiller = nil
    if chillers.size == 0
      return true
    elsif chillers.size > 1
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{self.name}, found #{chillers.size} chillers, cannot split up per performance rating method baseline requirements.")
    else
      first_chiller = chillers[0]
    end
    
    # Determine the per-chiller capacity
    # and sizing factor
    per_chiller_sizing_factor = (1.0/num_chillers).round(2)
    # This is unused
    per_chiller_cap_tons = cap_tons / num_chillers

    # Set the sizing factor and the chiller type: could do it on the first chiller before cloning it, but renaming warrants looping on chillers anyways
    
    # Add any new chillers
    final_chillers = [first_chiller]
    (num_chillers-1).times do
      #new_chiller = OpenStudio::Model::ChillerElectricEIR.new(self.model)
      # TODO renable the cloning of the chillers after curves are shared resources
      # Should be good to go since 1.10.2 (?)
      new_chiller = first_chiller.clone(self.model)
      if new_chiller.to_ChillerElectricEIR.is_initialized
        new_chiller = new_chiller.to_ChillerElectricEIR.get
      else
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{self.name}, could not clone chiller #{first_chiller.name}, cannot apply the performance rating method number of chillers.")
        return false
      end
      self.addSupplyBranchForComponent(new_chiller)
      final_chillers << new_chiller
    end

    # Set the sizing factor and the chiller types
    final_chillers.each_with_index do |final_chiller, i|
      final_chiller.setName("#{template} #{chiller_cooling_type} #{chiller_compressor_type} Chiller #{i+1} of #{final_chillers.size}")
      final_chiller.setSizingFactor(per_chiller_sizing_factor)
      final_chiller.setCondenserType(chiller_cooling_type)
    end
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{self.name}, there are #{final_chillers.size} #{chiller_cooling_type} #{chiller_compressor_type} chillers.")
    
    # Set the equipment to stage sequentially
    self.setLoadDistributionScheme('SequentialLoad')
  
    return true
  
  end


  # Determines the total rated watts per GPM of the loop
  #
  # @return [Double] rated power consumption per flow
  #   @units Watts per GPM (W*s/m^3)
  def total_rated_w_per_gpm()
    sizing_plant = self.sizingPlant
    loop_type = sizing_plant.loopType

    # Supply W/GPM
    supply_w_per_gpm = 0
    demand_w_per_gpm = 0

    self.supplyComponents.each do |component|
      if component.to_PumpConstantSpeed.is_initialized
        pump = component.to_PumpConstantSpeed.get
        pump_rated_w_per_gpm = pump.rated_w_per_gpm
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.Pump", "'#{loop_type}' Loop #{self.name} - Primary (Supply) Constant Speed Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        supply_w_per_gpm += pump_rated_w_per_gpm
      elsif component.to_PumpVariableSpeed.is_initialized
        pump = component.to_PumpVariableSpeed.get
        pump_rated_w_per_gpm = pump.rated_w_per_gpm
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.Pump", "'#{loop_type}' Loop #{self.name} - Primary (Supply) VSD Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        supply_w_per_gpm += pump_rated_w_per_gpm
      end
    end

    # Determine if primary only or primary-secondary
    # IF there's a pump on the demand side it's primary-secondary
    demandPumps = self.demandComponents('OS_Pump_VariableSpeed'.to_IddObjectType) + self.demandComponents('OS_Pump_ConstantSpeed'.to_IddObjectType)
    demandPumps.each do |component|
      if component.to_PumpConstantSpeed.is_initialized
        pump = component.to_PumpConstantSpeed.get
        pump_rated_w_per_gpm = pump.rated_w_per_gpm
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.Pump", "'#{loop_type}' Loop #{self.name} - Secondary (Demand) Constant Speed Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        demand_w_per_gpm += pump_rated_w_per_gpm
      elsif component.to_PumpVariableSpeed.is_initialized
        pump = component.to_PumpVariableSpeed.get
        pump_rated_w_per_gpm = pump.rated_w_per_gpm
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.Pump", "'#{loop_type}' Loop #{self.name} - Secondary (Demand) VSD Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        demand_w_per_gpm += pump_rated_w_per_gpm
      end
    end


    total_rated_w_per_gpm = supply_w_per_gpm + demand_w_per_gpm

    OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.Loop", "'#{loop_type}' Loop #{self.name} - Total #{total_rated_w_per_gpm} W/GPM - Supply #{supply_w_per_gpm} W/GPM - Demand #{demand_w_per_gpm} W/GPM")

    return total_rated_w_per_gpm

  end




  
end


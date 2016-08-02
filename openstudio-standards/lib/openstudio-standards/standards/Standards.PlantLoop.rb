
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::PlantLoop
  # Apply all standard required controls to the plantloop
  #
  # @param (see #economizer_required?)
  # @return [Bool] returns true if successful, false if not
  def apply_standard_controls(template, climate_zone)
    # Variable flow system
    enable_variable_flow(template) if is_variable_flow_required(template)

    # Supply water temperature reset
    enable_supply_water_temperature_reset if supply_water_temperature_reset_required?(template)
  end

  def enable_variable_flow(template)
  end

  def variable_flow_system?
    variable_flow = false

    # Modify all the primary pumps
    supplyComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        variable_flow = true
      end
    end

    # Modify all the secondary pumps
    demandComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        variable_flow = true
      end
    end

    return variable_flow
  end

  # TODO: I think it makes more sense to sense the motor efficiency right there...
  # But actually it's completely irrelevant... you could set at 0.9 and just calculate the pressurise rise to have your 19 W/GPM or whatever
  def apply_performance_rating_method_baseline_pump_power(template)
    # Determine the pumping power per
    # flow based on loop type.
    pri_w_per_gpm = nil
    sec_w_per_gpm = nil

    sizing_plant = sizingPlant
    loop_type = sizing_plant.loopType

    case loop_type
    when 'Heating'

      has_district_heating = false
      supplyComponents.each do |sc|
        if sc.to_DistrictHeating.is_initialized
          has_district_heating = true
        end
      end

      pri_w_per_gpm = if has_district_heating # District HW
                        14.0
                      else # HW
                        19.0
                      end

    when 'Cooling'

      has_district_cooling = false
      supplyComponents.each do |sc|
        if sc.to_DistrictCooling.is_initialized
          has_district_cooling = true
        end
      end

      has_secondary_pump = false
      demandComponents.each do |sc|
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

      # TODO: prm condenser loop pump power
      pri_w_per_gpm = 19.0

    end

    # Modify all the primary pumps
    supplyComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
        pump.apply_performance_rating_method_pressure_rise_and_motor_efficiency(pri_w_per_gpm, template)
      elsif sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump.apply_performance_rating_method_pressure_rise_and_motor_efficiency(pri_w_per_gpm, template)
      end
    end

    # Modify all the secondary pumps
    demandComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
        pump.apply_performance_rating_method_pressure_rise_and_motor_efficiency(sec_w_per_gpm, template)
      elsif sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump.apply_performance_rating_method_pressure_rise_and_motor_efficiency(sec_w_per_gpm, template)
      end
    end

    return true
  end

  def apply_performance_rating_method_baseline_temperatures(template)
    sizing_plant = sizingPlant
    loop_type = sizing_plant.loopType
    case loop_type
    when 'Heating'

      # Loop properties
      # G3.1.3.3 - HW Supply at 180F, return at 130F
      hw_temp_f = 180
      hw_delta_t_r = 50
      min_temp_f = 50

      hw_temp_c = OpenStudio.convert(hw_temp_f, 'F', 'C').get
      hw_delta_t_k = OpenStudio.convert(hw_delta_t_r, 'R', 'K').get
      min_temp_c = OpenStudio.convert(min_temp_f, 'F', 'C').get

      sizing_plant.setDesignLoopExitTemperature(hw_temp_c)
      sizing_plant.setLoopDesignTemperatureDifference(hw_delta_t_k)
      setMinimumLoopTemperature(min_temp_c)

      # ASHRAE Appendix G - G3.1.3.4 (for ASHRAE 90.1-2004, 2007 and 2010)
      # HW reset: 180F at 20F and below, 150F at 50F and above
      enable_supply_water_temperature_reset

      # Boiler properties
      supplyComponents.each do |sc|
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

      chw_temp_c = OpenStudio.convert(chw_temp_f, 'F', 'C').get
      chw_delta_t_k = OpenStudio.convert(chw_delta_t_r, 'R', 'K').get
      min_temp_c = OpenStudio.convert(min_temp_f, 'F', 'C').get
      max_temp_c = OpenStudio.convert(max_temp_f, 'F', 'C').get
      ref_cond_wtr_temp_c = OpenStudio.convert(ref_cond_wtr_temp_f, 'F', 'C').get

      sizing_plant.setDesignLoopExitTemperature(chw_temp_c)
      sizing_plant.setLoopDesignTemperatureDifference(chw_delta_t_k)
      setMinimumLoopTemperature(min_temp_c)
      setMaximumLoopTemperature(max_temp_c)

      # ASHRAE Appendix G - G3.1.3.9 (for ASHRAE 90.1-2004, 2007 and 2010)
      # ChW reset: 44F at 80F and above, 54F at 60F and below
      enable_supply_water_temperature_reset

      # Chiller properties
      supplyComponents.each do |sc|
        if sc.to_ChillerElectricEIR.is_initialized
          chiller = sc.to_ChillerElectricEIR.get
          chiller.setReferenceLeavingChilledWaterTemperature(chw_temp_c)
          chiller.setReferenceEnteringCondenserFluidTemperature(ref_cond_wtr_temp_c)
        end
      end

    when 'Condenser'

      # Much of the thought in this section
      # came from @jmarrec

      # Determine the design OATwb from the design days.
      # Per https://unmethours.com/question/16698/which-cooling-design-day-is-most-common-for-sizing-rooftop-units/
      # the WB=>MDB day is used to size cooling towers.
      summer_oat_wbs_f = []
      model.getDesignDays.each do |dd|
        next unless dd.dayType == 'SummerDesignDay'
        next unless dd.name.get.to_s.include?('WB=>MDB')
        if dd.humidityIndicatingType == 'Wetbulb'
          summer_oat_wb_c = dd.humidityIndicatingConditionsAtMaximumDryBulb
          summer_oat_wbs_f << OpenStudio.convert(summer_oat_wb_c, 'C', 'F').get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{dd.name}, humidity is specified as #{dd.humidityIndicatingType}; cannot determine Twb.")
        end
      end

      # Use the value from the design days or
      # 78F, the CTI rating condition, if no
      # design day information is available.
      design_oat_wb_f = nil
      if summer_oat_wbs_f.size.zero?
        design_oat_wb_f = 78
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{name}, no design day OATwb conditions were found.  CTI rating condition of 78F OATwb will be used for sizing cooling towers.")
      else
        # Take worst case condition
        design_oat_wb_f = summer_oat_wbs_f.max
      end

      # There is an EnergyPlus model limitation
      # that the design_oat_wb_f < 80F
      # for cooling towers
      ep_max_design_oat_wb_f = 80
      if design_oat_wb_f > ep_max_design_oat_wb_f
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{name}, reduced design OATwb from #{design_oat_wb_f} F to E+ model max input of #{ep_max_design_oat_wb_f} F.")
        design_oat_wb_f = ep_max_design_oat_wb_f
      end

      # Determine the design CW temperature, approach, and range
      leaving_cw_t_f = nil
      approach_r = nil
      range_r = nil
      case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010'
        # G3.1.3.11 - CW supply temp = 85F or 10F approaching design wet bulb temperature,
        # whichever is lower.  Design range = 10F
        # Design Temperature rise of 10F => Range: 10F
        range_r = 10

        # Determine the leaving CW temp
        max_leaving_cw_t_f = 85
        leaving_cw_t_10f_approach_f = design_oat_wb_f + 10
        leaving_cw_t_f = [max_leaving_cw_t_f, leaving_cw_t_10f_approach_f].max

        # Calculate the approach
        approach_r = leaving_cw_t_f - design_oat_wb_f

      when '90.1-2013'
        # G3.1.3.11 - CW supply temp shall be evaluated at 0.4% evaporative design OATwb
        # per the formulat approach_F = 25.72 - (0.24 * OATwb_F)
        # 55F <= OATwb <= 90F
        # Design range = 10F.
        range_r = 10

        # Limit the OATwb
        if design_oat_wb_f < 55
          design_oat_wb_f = 55
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{name}, a design OATwb of 55F will be used for sizing the cooling towers because the actual design value is below the limit in G3.1.3.11.")
        elsif design_oat_wb_f > 90
          design_oat_wb_f = 90
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{name}, a design OATwb of 90F will be used for sizing the cooling towers because the actual design value is above the limit in G3.1.3.11.")
        end

        # Calculate the approach
        approach_r = 25.72 - (0.24 * design_oat_wb_f)

        # Calculate the leaving CW temp
        leaving_cw_t_f = design_oat_wb_f + approach_r

      end

      # Report out design conditions
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}, design OATwb = #{design_oat_wb_f.round(1)} F, approach = #{approach_r.round(1)} deltaF, range = #{range_r.round(1)} deltaF, leaving condenser water temperature = #{leaving_cw_t_f.round(1)} F.")

      # Convert to SI units
      leaving_cw_t_c = OpenStudio.convert(leaving_cw_t_f, 'F', 'C').get
      approach_k = OpenStudio.convert(approach_r, 'R', 'K').get
      range_k = OpenStudio.convert(range_r, 'R', 'K').get
      design_oat_wb_c = OpenStudio.convert(design_oat_wb_f, 'F', 'C').get

      # Set the CW sizing parameters
      sizing_plant.setDesignLoopExitTemperature(leaving_cw_t_c)
      sizing_plant.setLoopDesignTemperatureDifference(range_k)

      # Set Cooling Tower sizing parameters.
      # Only the variable speed cooling tower
      # in E+ allows you to set the design temperatures.
      #
      # Per the documentation
      # http://bigladdersoftware.com/epx/docs/8-4/input-output-reference/group-condenser-equipment.html#field-design-u-factor-times-area-value
      # for CoolingTowerSingleSpeed and CoolingTowerTwoSpeed
      # E+ uses the following values during sizing:
      # 95F entering water temp
      # 95F OATdb
      # 78F OATwb
      # range = loop design delta-T aka range (specified above)
      supplyComponents.each do |sc|
        if sc.to_CoolingTowerVariableSpeed.is_initialized
          ct = sc.to_CoolingTowerVariableSpeed.get
          ct.setDesignInletAirWetBulbTemperature(design_oat_wb_c)
          ct.setDesignApproachTemperature(approach_k)
          ct.setDesignRangeTemperature(range_k)
        end
      end

      # Set the min and max CW temps
      # Typical design of min temp is really around 40F
      # (that's what basin heaters, when used, are sized for usually)
      min_temp_f = 34
      max_temp_f = 200
      min_temp_c = OpenStudio.convert(min_temp_f, 'F', 'C').get
      max_temp_c = OpenStudio.convert(max_temp_f, 'F', 'C').get
      setMinimumLoopTemperature(min_temp_c)
      setMaximumLoopTemperature(max_temp_c)

      # Cooling Tower operational controls
      # G3.1.3.11 - Tower shall be controlled to maintain a 70F
      # LCnWT where weather permits,
      # floating up to leaving water at design conditions.
      float_down_to_f = 70
      float_down_to_c = OpenStudio.convert(float_down_to_f, 'F', 'C').get
      cw_t_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(model)
      cw_t_stpt_manager.setName("CW Temp Follows OATwb w/ #{approach_r} deltaF approach min #{float_down_to_f.round(1)} F to max #{leaving_cw_t_f.round(1)}")
      cw_t_stpt_manager.setReferenceTemperatureType('OutdoorAirWetBulb')
      cw_t_stpt_manager.setMaximumSetpointTemperature(leaving_cw_t_c)
      cw_t_stpt_manager.setMinimumSetpointTemperature(float_down_to_c)
      cw_t_stpt_manager.setOffsetTemperatureDifference(approach_k)
      cw_t_stpt_manager.addToNode(supplyOutletNode)

    end

    return true
  end

  def supply_water_temperature_reset_required?(template)
    reset_required = false

    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'

      # Not required before 90.1-2004
      return reset_required

    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'

      # Not required for variable flow systems
      if variable_flow_system?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}: supply water temperature reset not required for variable flow systems per 6.5.4.3 Exception b.")
        return reset_required
      end

      # Determine the capacity of the system
      heating_capacity_w = total_heating_capacity
      cooling_capacity_w = total_cooling_capacity

      heating_capacity_btu_per_hr = OpenStudio.convert(heating_capacity_w, 'W', 'Btu/hr').get
      cooling_capacity_btu_per_hr = OpenStudio.convert(cooling_capacity_w, 'W', 'Btu/hr').get

      # Compare against capacity minimum requirement
      min_cap_btu_per_hr = 300_000
      if heating_capacity_btu_per_hr > min_cap_btu_per_hr
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}: supply water temperature reset is required because heating capacity of #{heating_capacity_btu_per_hr.round} Btu/hr exceeds the minimum threshold of #{min_cap_btu_per_hr.round} Btu/hr.")
        reset_required = true
      elsif cooling_capacity_btu_per_hr > min_cap_btu_per_hr
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}: supply water temperature reset is required because cooling capacity of #{cooling_capacity_btu_per_hr.round} Btu/hr exceeds the minimum threshold of #{min_cap_btu_per_hr.round} Btu/hr.")
        reset_required = true
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}: supply water temperature reset is not required because capacity is less than minimum of #{min_cap_btu_per_hr.round} Btu/hr.")
      end

    end

    return reset_required
  end

  def enable_supply_water_temperature_reset
    # Get the current setpoint manager on the outlet node
    # and determine if already has temperature reset
    spms = supplyOutletNode.setpointManagers
    spms.each do |spm|
      if spm.to_SetpointManagerOutdoorAirReset.is_initialized
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}: supply water temperature reset is already enabled.")
        return false
      end
    end

    # Get the design water temperature
    sizing_plant = sizingPlant
    design_temp_c = sizing_plant.designLoopExitTemperature
    design_temp_f = OpenStudio.convert(design_temp_c, 'C', 'F').get
    loop_type = sizing_plant.loopType

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
      hwt_at_hi_oat_c = OpenStudio.convert(hwt_at_hi_oat_f, 'F', 'C').get

      # Define the high and low outdoor air temperatures
      lo_oat_f = 20
      lo_oat_c = OpenStudio.convert(lo_oat_f, 'F', 'C').get
      hi_oat_f = 50
      hi_oat_c = OpenStudio.convert(hi_oat_f, 'F', 'C').get

      # Create a setpoint manager
      hwt_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
      hwt_oa_reset.setName("#{name} HW Temp Reset")
      hwt_oa_reset.setControlVariable('Temperature')
      hwt_oa_reset.setSetpointatOutdoorLowTemperature(hwt_at_lo_oat_c)
      hwt_oa_reset.setOutdoorLowTemperature(lo_oat_c)
      hwt_oa_reset.setSetpointatOutdoorHighTemperature(hwt_at_hi_oat_c)
      hwt_oa_reset.setOutdoorHighTemperature(hi_oat_c)
      hwt_oa_reset.addToNode(supplyOutletNode)

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}: hot water temperature reset from #{hwt_at_lo_oat_f.round}F to #{hwt_at_hi_oat_f.round}F between outdoor air temps of #{lo_oat_f.round}F and #{hi_oat_f.round}F.")

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
      lo_oat_f = 60
      lo_oat_c = OpenStudio.convert(lo_oat_f, 'F', 'C').get
      hi_oat_f = 80
      hi_oat_c = OpenStudio.convert(hi_oat_f, 'F', 'C').get

      # Create a setpoint manager
      chwt_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
      chwt_oa_reset.setName("#{name} CHW Temp Reset")
      chwt_oa_reset.setControlVariable('Temperature')
      chwt_oa_reset.setSetpointatOutdoorLowTemperature(chwt_at_lo_oat_c)
      chwt_oa_reset.setOutdoorLowTemperature(lo_oat_c)
      chwt_oa_reset.setSetpointatOutdoorHighTemperature(chwt_at_hi_oat_c)
      chwt_oa_reset.setOutdoorHighTemperature(hi_oat_c)
      chwt_oa_reset.addToNode(supplyOutletNode)

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}: chilled water temperature reset from #{chwt_at_hi_oat_f.round}F to #{chwt_at_lo_oat_f.round}F between outdoor air temps of #{hi_oat_f.round}F and #{lo_oat_f.round}F.")

    else

      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{name}: cannot enable supply water temperature reset for a #{loop_type} loop.")
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
    supplyComponents.each do |sc|
      # ChillerElectricEIR
      if sc.to_ChillerElectricEIR.is_initialized
        chiller = sc.to_ChillerElectricEIR.get
        if chiller.referenceCapacity.is_initialized
          total_cooling_capacity_w += chiller.referenceCapacity.get
        elsif chiller.autosizedReferenceCapacity.is_initialized
          total_cooling_capacity_w += chiller.autosizedReferenceCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{name} capacity of #{chiller.name} is not available, total cooling capacity of plant loop will be incorrect when applying standard.")
        end
      end
    end

    total_cooling_capacity_tons = OpenStudio.convert(total_cooling_capacity_w, 'W', 'ton').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{name}, cooling capacity is #{total_cooling_capacity_tons.round} tons of refrigeration.")

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
    supplyComponents.each do |sc|
      # BoilerHotWater
      if sc.to_BoilerHotWater.is_initialized
        boiler = sc.to_BoilerHotWater.get
        if boiler.nominalCapacity.is_initialized
          total_heating_capacity_w += boiler.nominalCapacity.get
        elsif boiler.autosizedNominalCapacity.is_initialized
          total_heating_capacity_w += boiler.autosizedNominalCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{name} capacity of #{boiler.name} is not available, total cooling capacity of plant loop will be incorrect when applying standard.")
        end
      end
    end

    total_heating_capacity_kbtu_per_hr = OpenStudio.convert(total_heating_capacity_w, 'W', 'tons').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{name}, heating capacity is #{total_heating_capacity_kbtu_per_hr.round} kBtu/hr.")

    return total_heating_capacity_w
  end

  def total_floor_area_served
    sizing_plant = sizingPlant
    loop_type = sizing_plant.loopType

    # Get all the coils served by this loop
    coils = []
    case loop_type
    when 'Heating'
      demandComponents.each do |dc|
        if dc.to_CoilHeatingWater.is_initialized
          coils << dc.to_CoilHeatingWater.get
        end
      end
    when 'Cooling'
      demandComponents.each do |dc|
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
    area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{name}, serves #{area_served_ft2.round} ft^2.")

    return area_served_m2
  end

  def apply_performance_rating_method_baseline_pumping_type(template)
    sizing_plant = sizingPlant
    loop_type = sizing_plant.loopType

    case loop_type
    when 'Heating'

      # Hot water systems

      # Determine the minimum area to determine
      # pumping type.
      minimum_area_ft2 = nil
      case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        minimum_area_ft2 = 120_000
      end

      # Determine the area served
      area_served_m2 = total_floor_area_served
      area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get

      # Determine the pump type
      control_type = 'Riding Curve'
      if area_served_ft2 > minimum_area_ft2
        control_type = 'VSD No Reset'
      end

      # Modify all the primary pumps
      supplyComponents.each do |sc|
        if sc.to_PumpVariableSpeed.is_initialized
          pump = sc.to_PumpVariableSpeed.get
          pump.set_control_type(control_type)
        end
      end

      # Report out the pumping type
      unless control_type.nil?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{name}, pump type is #{control_type}.")
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

        minimum_area_ft2 = 120_000

        # Determine the area served
        area_served_m2 = total_floor_area_served
        area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get

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
        cap_w = total_cooling_capacity
        cap_tons = OpenStudio.convert(cap_w, 'W', 'ton').get

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
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{name}, primary pump type is #{pri_control_type}.")
      end

      unless sec_control_type.nil?
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{name}, secondary pump type is #{sec_control_type}.")
      end

      # Modify all the primary pumps
      supplyComponents.each do |sc|
        if sc.to_PumpVariableSpeed.is_initialized
          pump = sc.to_PumpVariableSpeed.get
          pump.set_control_type(pri_control_type)
        end
      end

      # Modify all the secondary pumps
      demandComponents.each do |sc|
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
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{name}, pump type is #{control_type}.")
      end

      # Modify all primary pumps
      supplyComponents.each do |sc|
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
    return true unless sizingPlant.loopType == 'Heating'

    # Determine the minimum area to determine
    # number of boilers.
    minimum_area_ft2 = nil
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      minimum_area_ft2 = 15_000
    end

    # Determine the area served
    area_served_m2 = total_floor_area_served
    area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get

    # Do nothing if only one boiler is required
    return true if area_served_ft2 < minimum_area_ft2

    # Get all existing boilers
    boilers = []
    supplyComponents.each do |sc|
      if sc.to_BoilerHotWater.is_initialized
        boilers << sc.to_BoilerHotWater.get
      end
    end

    # Ensure there is only 1 boiler to start
    first_boiler = nil
    if boilers.size.zero?
      return true
    elsif boilers.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{name}, found #{boilers.size}, cannot split up per performance rating method baseline requirements.")
    else
      first_boiler = boilers[0]
    end

    # Clone the existing boiler and create
    # a new branch for it
    second_boiler = first_boiler.clone(model)
    if second_boiler.to_BoilerHotWater.is_initialized
      second_boiler = second_boiler.to_BoilerHotWater.get
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{name}, could not clone boiler #{first_boiler.name}, cannot apply the performance rating method number of boilers.")
      return false
    end
    addSupplyBranchForComponent(second_boiler)
    final_boilers = [first_boiler, second_boiler]
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}, added a second boiler.")

    # Set the sizing factor for all boilers evenly and Rename the boilers
    sizing_factor = (1.0 / final_boilers.size).round(2)
    final_boilers.each_with_index do |boiler, i|
      boiler.setSizingFactor(sizing_factor)
      boiler.setName("#{first_boiler.name} #{i + 1} of #{final_boilers.size}")
    end

    # Set the equipment to stage sequentially
    setLoadDistributionScheme('SequentialLoad')

    return true
  end

  def apply_performance_rating_method_number_of_chillers(template)
    # Skip non-cooling plants
    return true unless sizingPlant.loopType == 'Cooling'

    # Determine the number and type of chillers
    num_chillers = nil
    chiller_cooling_type = nil
    chiller_compressor_type = nil
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'

      # Determine the capacity of the loop
      cap_w = total_cooling_capacity
      cap_tons = OpenStudio.convert(cap_w, 'W', 'ton').get

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
        num_chillers = (cap_tons / max_cap_ton).floor + 1
        # Must be at least 2 chillers
        num_chillers += 1 if num_chillers == 1
        chiller_cooling_type = 'WaterCooled'
        chiller_compressor_type = 'Centrifugal'
      end

    end

    # Get all existing chillers
    chillers = []
    supplyComponents.each do |sc|
      if sc.to_ChillerElectricEIR.is_initialized
        chillers << sc.to_ChillerElectricEIR.get
      end
    end

    # Ensure there is only 1 chiller to start
    first_chiller = nil
    if chillers.size.zero?
      return true
    elsif chillers.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{name}, found #{chillers.size} chillers, cannot split up per performance rating method baseline requirements.")
    else
      first_chiller = chillers[0]
    end

    # Determine the per-chiller capacity
    # and sizing factor
    per_chiller_sizing_factor = (1.0 / num_chillers).round(2)
    # This is unused
    per_chiller_cap_tons = cap_tons / num_chillers

    # Set the sizing factor and the chiller type: could do it on the first chiller before cloning it, but renaming warrants looping on chillers anyways

    # Add any new chillers
    final_chillers = [first_chiller]
    (num_chillers - 1).times do
      new_chiller = first_chiller.clone(model)
      if new_chiller.to_ChillerElectricEIR.is_initialized
        new_chiller = new_chiller.to_ChillerElectricEIR.get
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{name}, could not clone chiller #{first_chiller.name}, cannot apply the performance rating method number of chillers.")
        return false
      end
      # Connect the new chiller to the same CHW loop
      # as the old chiller.
      addSupplyBranchForComponent(new_chiller)
      # Connect the new chiller to the same CW loop
      # as the old chiller, if it was water-cooled.
      cw_loop = first_chiller.secondaryPlantLoop
      if cw_loop.is_initialized
        cw_loop.get.addDemandBranchForComponent(new_chiller)
      end

      final_chillers << new_chiller
    end

    # Set the sizing factor and the chiller types
    final_chillers.each_with_index do |final_chiller, i|
      final_chiller.setName("#{template} #{chiller_cooling_type} #{chiller_compressor_type} Chiller #{i + 1} of #{final_chillers.size}")
      final_chiller.setSizingFactor(per_chiller_sizing_factor)
      final_chiller.setCondenserType(chiller_cooling_type)
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}, there are #{final_chillers.size} #{chiller_cooling_type} #{chiller_compressor_type} chillers.")

    # Set the equipment to stage sequentially
    setLoadDistributionScheme('SequentialLoad')

    return true
  end

  def apply_performance_rating_method_number_of_cooling_towers(template)
    # Skip non-cooling plants
    return true unless sizingPlant.loopType == 'Condenser'

    # Determine the number of chillers
    # already in the model
    num_chillers = model.getChillerElectricEIRs.size

    # Get all existing cooling towers and pumps
    clg_twrs = []
    pumps = []
    supplyComponents.each do |sc|
      if sc.to_CoolingTowerSingleSpeed.is_initialized
        clg_twrs << sc.to_CoolingTowerSingleSpeed.get
      elsif sc.to_CoolingTowerTwoSpeed.is_initialized
        clg_twrs << sc.to_CoolingTowerTwoSpeed.get
      elsif sc.to_CoolingTowerVariableSpeed.is_initialized
        clg_twrs << sc.to_CoolingTowerVariableSpeed.get
      elsif sc.to_PumpConstantSpeed.is_initialized
        pumps << sc.to_PumpConstantSpeed.get
      elsif sc.to_PumpVariableSpeed.is_initialized
        pumps << sc.to_PumpVariableSpeed.get
      end
    end

    # Ensure there is only 1 cooling tower to start
    orig_twr = nil
    if clg_twrs.size.zero?
      return true
    elsif clg_twrs.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{name}, found #{clg_twrs.size} cooling towers, cannot split up per performance rating method baseline requirements.")
      return false
    else
      orig_twr = clg_twrs[0]
    end

    # Ensure there is only 1 pump to start
    orig_pump = nil
    if pumps.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{name}, found #{pumps.size} pumps.  A loop must have at least one pump.")
      return false
    elsif pumps.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{name}, found #{pumps.size} pumps, cannot split up per performance rating method baseline requirements.")
      return false
    else
      orig_pump = pumps[0]
    end

    # Determine the per-cooling_tower sizing factor
    clg_twr_sizing_factor = (1.0 / num_chillers).round(2)

    # Add a cooling tower for each chiller.
    # Add an accompanying CW pump for each cooling tower.
    final_twrs = [orig_twr]
    new_twr = nil
    (num_chillers - 1).times do
      if orig_twr.to_CoolingTowerSingleSpeed.is_initialized
        new_twr = orig_twr.clone(model)
        new_twr = new_twr.to_CoolingTowerSingleSpeed.get
      elsif orig_twr.to_CoolingTowerTwoSpeed.is_initialized
        new_twr = orig_twr.clone(model)
        new_twr = new_twr.to_CoolingTowerTwoSpeed.get
      elsif orig_twr.to_CoolingTowerVariableSpeed.is_initialized
        # TODO: remove workaround after resolving
        # https://github.com/NREL/OpenStudio/issues/2212
        # Workaround is to create a new tower
        # and replicate all the properties of the first tower.
        new_twr = OpenStudio::Model::CoolingTowerVariableSpeed.new(model)
        new_twr.setName(orig_twr.name.get.to_s)
        new_twr.setDesignInletAirWetBulbTemperature(orig_twr.designInletAirWetBulbTemperature.get)
        new_twr.setDesignApproachTemperature(orig_twr.designApproachTemperature.get)
        new_twr.setDesignRangeTemperature(orig_twr.designRangeTemperature.get)
        new_twr.setFractionofTowerCapacityinFreeConvectionRegime(orig_twr.fractionofTowerCapacityinFreeConvectionRegime.get)
        if orig_twr.fanPowerRatioFunctionofAirFlowRateRatioCurve.is_initialized
          new_twr.setFanPowerRatioFunctionofAirFlowRateRatioCurve(orig_twr.fanPowerRatioFunctionofAirFlowRateRatioCurve.get)
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{name}, could not clone cooling tower #{orig_twr.name}, cannot apply the performance rating method number of cooling towers.")
        return false
      end
      final_twrs << new_twr

      # spit out the curve name
      # puts new_twr.fanPowerRatioFunctionofAirFlowRateRatioCurve.get.name
      # new_curve = OpenStudio::Model::CurveCubic.new(model)
      # new_curve.setName("Net CT Curve")
      # new_twr.setFanPowerRatioFunctionofAirFlowRateRatioCurve(new_curve)
      # puts new_twr.fanPowerRatioFunctionofAirFlowRateRatioCurve.get.name

      # Connect the new cooling tower to the CW loop
      addSupplyBranchForComponent(new_twr)
      new_twr_inlet = new_twr.inletModelObject.get.to_Node.get

      # Clone the original pump for the new cooling tower
      new_pump = orig_pump.clone(model)
      if new_pump.to_PumpConstantSpeed.is_initialized
        new_pump = new_pump.to_PumpConstantSpeed.get
      elsif new_pump.to_PumpVariableSpeed.is_initialized
        new_pump = new_pump.to_PumpVariableSpeed.get
      end
      new_pump.addToNode(new_twr_inlet)
    end

    # Move the original pump onto the
    # branch of the original cooling tower
    orig_twr_inlet_node = orig_twr.inletModelObject.get.to_Node.get
    orig_pump.addToNode(orig_twr_inlet_node)

    # Set the sizing factors
    final_twrs.each do |final_cooling_tower|
      final_cooling_tower.setSizingFactor(clg_twr_sizing_factor)
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{name}, there are #{final_twrs.size} cooling towers, one for each chiller.")

    # Set the equipment to stage sequentially
    setLoadDistributionScheme('SequentialLoad')
  end

  # Determines the total rated watts per GPM of the loop
  #
  # @return [Double] rated power consumption per flow
  #   @units Watts per GPM (W*s/m^3)
  def total_rated_w_per_gpm
    sizing_plant = sizingPlant
    loop_type = sizing_plant.loopType

    # Supply W/GPM
    supply_w_per_gpm = 0
    demand_w_per_gpm = 0

    supplyComponents.each do |component|
      if component.to_PumpConstantSpeed.is_initialized
        pump = component.to_PumpConstantSpeed.get
        pump_rated_w_per_gpm = pump.rated_w_per_gpm
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "'#{loop_type}' Loop #{name} - Primary (Supply) Constant Speed Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        supply_w_per_gpm += pump_rated_w_per_gpm
      elsif component.to_PumpVariableSpeed.is_initialized
        pump = component.to_PumpVariableSpeed.get
        pump_rated_w_per_gpm = pump.rated_w_per_gpm
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "'#{loop_type}' Loop #{name} - Primary (Supply) VSD Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        supply_w_per_gpm += pump_rated_w_per_gpm
      end
    end

    # Determine if primary only or primary-secondary
    # IF there's a pump on the demand side it's primary-secondary
    demand_pumps = demandComponents('OS:Pump:VariableSpeed'.to_IddObjectType) + demandComponents('OS:Pump:ConstantSpeed'.to_IddObjectType)
    demand_pumps.each do |component|
      if component.to_PumpConstantSpeed.is_initialized
        pump = component.to_PumpConstantSpeed.get
        pump_rated_w_per_gpm = pump.rated_w_per_gpm
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "'#{loop_type}' Loop #{name} - Secondary (Demand) Constant Speed Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        demand_w_per_gpm += pump_rated_w_per_gpm
      elsif component.to_PumpVariableSpeed.is_initialized
        pump = component.to_PumpVariableSpeed.get
        pump_rated_w_per_gpm = pump.rated_w_per_gpm
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "'#{loop_type}' Loop #{name} - Secondary (Demand) VSD Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        demand_w_per_gpm += pump_rated_w_per_gpm
      end
    end

    total_rated_w_per_gpm = supply_w_per_gpm + demand_w_per_gpm

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Loop', "'#{loop_type}' Loop #{name} - Total #{total_rated_w_per_gpm} W/GPM - Supply #{supply_w_per_gpm} W/GPM - Demand #{demand_w_per_gpm} W/GPM")

    return total_rated_w_per_gpm
  end

  # find maximum_loop_flow_rate
  #
  # @return [Double]  maximum_loop_flow_rate m^3/s
  def find_maximum_loop_flow_rate
    # Get the maximum_loop_flow_rate
    maximum_loop_flow_rate = nil
    if maximumLoopFlowRate.is_initialized
      maximum_loop_flow_rate = maximumLoopFlowRate.get
    elsif autosizedMaximumLoopFlowRate.is_initialized
      maximum_loop_flow_rate = autosizedMaximumLoopFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{name} maximum loop flow rate is not available.")
    end

    return maximum_loop_flow_rate
  end
end

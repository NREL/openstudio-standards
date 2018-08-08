class Standard
  # @!group PlantLoop

  # Apply all standard required controls to the plantloop
  #
  # @param (see #economizer_required?)
  # @return [Bool] returns true if successful, false if not
  def plant_loop_apply_standard_controls(plant_loop, climate_zone)
    # Supply water temperature reset
    plant_loop_enable_supply_water_temperature_reset(plant_loop) if plant_loop_supply_water_temperature_reset_required?(plant_loop)
  end

  # Determine if the plant loop is variable flow.
  # Returns true if primary and/or secondary pumps are variable speed.
  def plant_loop_variable_flow_system?(plant_loop)
    variable_flow = false

    # Check all the primary pumps
    plant_loop.supplyComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        variable_flow = true
      end
    end

    # Check all the secondary pumps
    plant_loop.demandComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        variable_flow = true
      end
    end

    return variable_flow
  end

  # TODO: I think it makes more sense to sense the motor efficiency right there...
  # But actually it's completely irrelevant... you could set at 0.9 and just calculate the pressurise rise to have your 19 W/GPM or whatever
  def plant_loop_apply_prm_baseline_pump_power(plant_loop)
    # Determine the pumping power per
    # flow based on loop type.
    pri_w_per_gpm = nil
    sec_w_per_gpm = nil

    sizing_plant = plant_loop.sizingPlant
    loop_type = sizing_plant.loopType

    case loop_type
      when 'Heating'

        has_district_heating = false
        plant_loop.supplyComponents.each do |sc|
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
        plant_loop.supplyComponents.each do |sc|
          if sc.to_DistrictCooling.is_initialized
            has_district_cooling = true
          end
        end

        has_secondary_pump = false
        plant_loop.demandComponents.each do |sc|
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
    plant_loop.supplyComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      elsif sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      elsif sc.to_HeaderedPumpsConstantSpeed.is_initialized
        pump = sc.to_HeaderedPumpsConstantSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      elsif sc.to_HeaderedPumpsVariableSpeed.is_initialized
        pump = sc.to_HeaderedPumpsVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      end
    end

    # Modify all the secondary pumps
    plant_loop.demandComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, sec_w_per_gpm)
      elsif sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, sec_w_per_gpm)
      elsif sc.to_HeaderedPumpsConstantSpeed.is_initialized
        pump = sc.to_HeaderedPumpsConstantSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      elsif sc.to_HeaderedPumpsVariableSpeed.is_initialized
        pump = sc.to_HeaderedPumpsVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, pri_w_per_gpm)
      end
    end

    return true
  end

  # Applies the temperatures to the plant loop based on Appendix G.
  # @param [Object]  plant_loop
  # @return [TrueClass]
  def plant_loop_apply_prm_baseline_temperatures(plant_loop)
    sizing_plant = plant_loop.sizingPlant
    loop_type = sizing_plant.loopType
    case loop_type
      when 'Heating'
        plant_loop_apply_prm_baseline_hot_water_temperatures(plant_loop)
      when 'Cooling'
        plant_loop_apply_prm_baseline_chilled_water_temperatures(plant_loop)
      when 'Condenser'
        plant_loop_apply_prm_baseline_condenser_water_temperatures(plant_loop)
    end

    return true
  end

  # Applies the hot water temperatures to the plant loop based on Appendix G.
  def plant_loop_apply_prm_baseline_hot_water_temperatures(plant_loop)
    sizing_plant = plant_loop.sizingPlant

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
    plant_loop.setMinimumLoopTemperature(min_temp_c)

    # ASHRAE Appendix G - G3.1.3.4 (for ASHRAE 90.1-2004, 2007 and 2010)
    # HW reset: 180F at 20F and below, 150F at 50F and above
    plant_loop_enable_supply_water_temperature_reset(plant_loop)

    # Boiler properties
    plant_loop.supplyComponents.each do |sc|
      if sc.to_BoilerHotWater.is_initialized
        boiler = sc.to_BoilerHotWater.get
        boiler.setDesignWaterOutletTemperature(hw_temp_c)
      end
    end
    return true
  end

  # Applies the chilled water temperatures to the plant loop based on Appendix G.
  def plant_loop_apply_prm_baseline_chilled_water_temperatures(plant_loop)
    sizing_plant = plant_loop.sizingPlant

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
    plant_loop.setMinimumLoopTemperature(min_temp_c)
    plant_loop.setMaximumLoopTemperature(max_temp_c)

    # ASHRAE Appendix G - G3.1.3.9 (for ASHRAE 90.1-2004, 2007 and 2010)
    # ChW reset: 44F at 80F and above, 54F at 60F and below
    plant_loop_enable_supply_water_temperature_reset(plant_loop)

    # Chiller properties
    plant_loop.supplyComponents.each do |sc|
      if sc.to_ChillerElectricEIR.is_initialized
        chiller = sc.to_ChillerElectricEIR.get
        chiller.setReferenceLeavingChilledWaterTemperature(chw_temp_c)
        chiller.setReferenceEnteringCondenserFluidTemperature(ref_cond_wtr_temp_c)
      end
    end

    return true
  end

  # Applies the condenser water temperatures to the plant loop based on Appendix G.
  def plant_loop_apply_prm_baseline_condenser_water_temperatures(plant_loop)
    sizing_plant = plant_loop.sizingPlant

    # Much of the thought in this section
    # came from @jmarrec

    # Determine the design OATwb from the design days.
    # Per https://unmethours.com/question/16698/which-cooling-design-day-is-most-common-for-sizing-rooftop-units/
    # the WB=>MDB day is used to size cooling towers.
    summer_oat_wbs_f = []
    plant_loop.model.getDesignDays.sort.each do |dd|
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
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, no design day OATwb conditions were found.  CTI rating condition of 78F OATwb will be used for sizing cooling towers.")
    else
      # Take worst case condition
      design_oat_wb_f = summer_oat_wbs_f.max
    end

    # There is an EnergyPlus model limitation
    # that the design_oat_wb_f < 80F
    # for cooling towers
    ep_max_design_oat_wb_f = 80
    if design_oat_wb_f > ep_max_design_oat_wb_f
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, reduced design OATwb from #{design_oat_wb_f} F to E+ model max input of #{ep_max_design_oat_wb_f} F.")
      design_oat_wb_f = ep_max_design_oat_wb_f
    end

    # Determine the design CW temperature, approach, and range
    design_oat_wb_c = OpenStudio.convert(design_oat_wb_f, 'F', 'C').get
    leaving_cw_t_c, approach_k, range_k = plant_loop_prm_baseline_condenser_water_temperatures(plant_loop, design_oat_wb_c)

    # Convert to IP units
    leaving_cw_t_f = OpenStudio.convert(leaving_cw_t_c, 'C', 'F').get
    approach_r = OpenStudio.convert(approach_k, 'K', 'R').get
    range_r = OpenStudio.convert(range_k, 'K', 'R').get

    # Report out design conditions
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, design OATwb = #{design_oat_wb_f.round(1)} F, approach = #{approach_r.round(1)} deltaF, range = #{range_r.round(1)} deltaF, leaving condenser water temperature = #{leaving_cw_t_f.round(1)} F.")

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
    plant_loop.supplyComponents.each do |sc|
      if sc.to_CoolingTowerVariableSpeed.is_initialized
        ct = sc.to_CoolingTowerVariableSpeed.get
        # E+ has a minimum limit of 68F (20C) for this field.
        # Check against limit before attempting to set value.
        eplus_design_oat_wb_c_lim = 20
        if design_oat_wb_c < eplus_design_oat_wb_c_lim
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, a design OATwb of 68F will be used for sizing the cooling towers because the actual design value is below the limit EnergyPlus accepts for this input.")
          design_oat_wb_c = eplus_design_oat_wb_c_lim
        end
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
    plant_loop.setMinimumLoopTemperature(min_temp_c)
    plant_loop.setMaximumLoopTemperature(max_temp_c)

    # Cooling Tower operational controls
    # G3.1.3.11 - Tower shall be controlled to maintain a 70F
    # LCnWT where weather permits,
    # floating up to leaving water at design conditions.
    float_down_to_f = 70
    float_down_to_c = OpenStudio.convert(float_down_to_f, 'F', 'C').get
    cw_t_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(plant_loop.model)
    cw_t_stpt_manager.setName("CW Temp Follows OATwb w/ #{approach_r} plant_loop.deltaF approach min #{float_down_to_f.round(1)} F to max #{leaving_cw_t_f.round(1)}")
    cw_t_stpt_manager.setReferenceTemperatureType('OutdoorAirWetBulb')
    # At low design OATwb, it is possible to calculate
    # a maximum temperature below the minimum.  In this case,
    # make the maximum and minimum the same.
    if leaving_cw_t_c < float_down_to_c
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, the maximum leaving temperature of #{leaving_cw_t_f.round(1)} F is below the minimum of #{float_down_to_f.round(1)} F.  The maximum will be set to the same value as the minimum.")
      leaving_cw_t_c = float_down_to_c
    end
    cw_t_stpt_manager.setMaximumSetpointTemperature(leaving_cw_t_c)
    cw_t_stpt_manager.setMinimumSetpointTemperature(float_down_to_c)
    cw_t_stpt_manager.setOffsetTemperatureDifference(approach_k)
    cw_t_stpt_manager.addToNode(plant_loop.supplyOutletNode)

    return true
  end

  # Determine the performance rating method specified
  # design condenser water temperature, approach, and range
  #
  # @param plant_loop [OpenStudio::Model::PlantLoop] the condenser water loop
  # @param design_oat_wb_c [Double] the design OA wetbulb temperature (C)
  # @return [Array<Double>] [leaving_cw_t_c, approach_k, range_k]
  def plant_loop_prm_baseline_condenser_water_temperatures(plant_loop, design_oat_wb_c)
    design_oat_wb_f = OpenStudio.convert(design_oat_wb_c, 'C', 'F').get

    # G3.1.3.11 - CW supply temp = 85F or 10F approaching design wet bulb temperature,
    # whichever is lower.  Design range = 10F
    # Design Temperature rise of 10F => Range: 10F
    range_r = 10

    # Determine the leaving CW temp
    max_leaving_cw_t_f = 85
    leaving_cw_t_10f_approach_f = design_oat_wb_f + 10
    leaving_cw_t_f = [max_leaving_cw_t_f, leaving_cw_t_10f_approach_f].min

    # Calculate the approach
    approach_r = leaving_cw_t_f - design_oat_wb_f

    # Convert to SI units
    leaving_cw_t_c = OpenStudio.convert(leaving_cw_t_f, 'F', 'C').get
    approach_k = OpenStudio.convert(approach_r, 'R', 'K').get
    range_k = OpenStudio.convert(range_r, 'R', 'K').get

    return [leaving_cw_t_c, approach_k, range_k]
  end

  # Determine if temperature reset is required.
  # Required if heating or cooling capacity is greater than
  # 300,000 Btu/hr.
  def plant_loop_supply_water_temperature_reset_required?(plant_loop)
    reset_required = false

    # Not required for service water heating systems
    if plant_loop_swh_loop?(plant_loop)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}: supply water temperature reset not required for service water heating systems.")
      return reset_required
    end

    # Not required for variable flow systems
    if plant_loop_variable_flow_system?(plant_loop)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}: supply water temperature reset not required for variable flow systems per 6.5.4.3 Exception b.")
      return reset_required
    end

    # Determine the capacity of the system
    heating_capacity_w = plant_loop_total_heating_capacity(plant_loop)
    cooling_capacity_w = plant_loop_total_cooling_capacity(plant_loop)

    heating_capacity_btu_per_hr = OpenStudio.convert(heating_capacity_w, 'W', 'Btu/hr').get
    cooling_capacity_btu_per_hr = OpenStudio.convert(cooling_capacity_w, 'W', 'Btu/hr').get

    # Compare against capacity minimum requirement
    min_cap_btu_per_hr = 300_000
    if heating_capacity_btu_per_hr > min_cap_btu_per_hr
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}: supply water temperature reset is required because heating capacity of #{heating_capacity_btu_per_hr.round} Btu/hr exceeds the minimum threshold of #{min_cap_btu_per_hr.round} Btu/hr.")
      reset_required = true
    elsif cooling_capacity_btu_per_hr > min_cap_btu_per_hr
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}: supply water temperature reset is required because cooling capacity of #{cooling_capacity_btu_per_hr.round} Btu/hr exceeds the minimum threshold of #{min_cap_btu_per_hr.round} Btu/hr.")
      reset_required = true
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}: supply water temperature reset is not required because capacity is less than minimum of #{min_cap_btu_per_hr.round} Btu/hr.")
    end

    return reset_required
  end

  # Enable reset of hot or chilled water temperature
  # based on outdoor air temperature.
  # @param [Object]  plant_loop
  # @return [TrueClass]
  def plant_loop_enable_supply_water_temperature_reset(plant_loop)
    # Get the current setpoint manager on the outlet node
    # and determine if already has temperature reset
    spms = plant_loop.supplyOutletNode.setpointManagers
    spms.each do |spm|
      if spm.to_SetpointManagerOutdoorAirReset.is_initialized
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}: supply water temperature reset is already enabled.")
        return false
      end
    end

    # Get the design water temperature
    sizing_plant = plant_loop.sizingPlant
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
        hwt_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(plant_loop.model)
        hwt_oa_reset.setName("#{plant_loop.name} HW Temp Reset")
        hwt_oa_reset.setControlVariable('Temperature')
        hwt_oa_reset.setSetpointatOutdoorLowTemperature(hwt_at_lo_oat_c)
        hwt_oa_reset.setOutdoorLowTemperature(lo_oat_c)
        hwt_oa_reset.setSetpointatOutdoorHighTemperature(hwt_at_hi_oat_c)
        hwt_oa_reset.setOutdoorHighTemperature(hi_oat_c)
        hwt_oa_reset.addToNode(plant_loop.supplyOutletNode)

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}: hot water temperature reset from #{hwt_at_lo_oat_f.round}F to #{hwt_at_hi_oat_f.round}F between outdoor air temps of #{lo_oat_f.round}F and #{hi_oat_f.round}F.")

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
        chwt_oa_reset = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(plant_loop.model)
        chwt_oa_reset.setName("#{plant_loop.name} CHW Temp Reset")
        chwt_oa_reset.setControlVariable('Temperature')
        chwt_oa_reset.setSetpointatOutdoorLowTemperature(chwt_at_lo_oat_c)
        chwt_oa_reset.setOutdoorLowTemperature(lo_oat_c)
        chwt_oa_reset.setSetpointatOutdoorHighTemperature(chwt_at_hi_oat_c)
        chwt_oa_reset.setOutdoorHighTemperature(hi_oat_c)
        chwt_oa_reset.addToNode(plant_loop.supplyOutletNode)

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}: chilled water temperature reset from #{chwt_at_hi_oat_f.round}F to #{chwt_at_lo_oat_f.round}F between outdoor air temps of #{hi_oat_f.round}F and #{lo_oat_f.round}F.")

      else

        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}: cannot enable supply water temperature reset for a #{loop_type} loop.")
        return false

    end

    return true
  end

  # Get the total cooling capacity for the plant loop
  #
  # @return [Double] total cooling capacity
  #   units = Watts (W)
  # @param [Object]  plant_loop
  # @return [Fixnum]
  def plant_loop_total_cooling_capacity(plant_loop)
    # Sum the cooling capacity for all cooling components
    # on the plant loop.
    total_cooling_capacity_w = 0
    plant_loop.supplyComponents.each do |sc|
      # ChillerElectricEIR
      if sc.to_ChillerElectricEIR.is_initialized
        chiller = sc.to_ChillerElectricEIR.get
        if chiller.referenceCapacity.is_initialized
          total_cooling_capacity_w += chiller.referenceCapacity.get
        elsif chiller.autosizedReferenceCapacity.is_initialized
          total_cooling_capacity_w += chiller.autosizedReferenceCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{plant_loop.name} capacity of #{chiller.name} is not available, total cooling capacity of plant loop will be incorrect when applying standard.")
        end
        # DistrictCooling
      elsif sc.to_DistrictCooling.is_initialized
        dist_clg = sc.to_DistrictCooling.get
        if dist_clg.nominalCapacity.is_initialized
          total_cooling_capacity_w += dist_clg.nominalCapacity.get
        elsif dist_clg.autosizedNominalCapacity.is_initialized
          total_cooling_capacity_w += dist_clg.autosizedNominalCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name} capacity of DistrictCooling #{dist_clg.name} is not available, total heating capacity of plant loop will be incorrect when applying standard.")
        end
      end
    end

    total_cooling_capacity_tons = OpenStudio.convert(total_cooling_capacity_w, 'W', 'ton').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{plant_loop.name}, cooling capacity is #{total_cooling_capacity_tons.round} tons of refrigeration.")

    return total_cooling_capacity_w
  end

  # Get the total heating capacity for the plant loop
  #
  # @return [Double] total heating capacity
  #   units = Watts (W)
  # @todo Add district heating to plant loop heating capacity
  # @param [Object]  plant_loop
  # @return [Object]
  def plant_loop_total_heating_capacity(plant_loop)
    # Sum the heating capacity for all heating components
    # on the plant loop.
    total_heating_capacity_w = 0
    plant_loop.supplyComponents.each do |sc|
      # BoilerHotWater
      if sc.to_BoilerHotWater.is_initialized
        boiler = sc.to_BoilerHotWater.get
        if boiler.nominalCapacity.is_initialized
          total_heating_capacity_w += boiler.nominalCapacity.get
        elsif boiler.autosizedNominalCapacity.is_initialized
          total_heating_capacity_w += boiler.autosizedNominalCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name} capacity of Boiler:HotWater ' #{boiler.name} is not available, total heating capacity of plant loop will be incorrect when applying standard.")
        end
        # WaterHeater:Mixed
      elsif sc.to_WaterHeaterMixed.is_initialized
        water_heater = sc.to_WaterHeaterMixed.get
        if water_heater.heaterMaximumCapacity.is_initialized
          total_heating_capacity_w += water_heater.heaterMaximumCapacity.get
        elsif water_heater.autosizedHeaterMaximumCapacity.is_initialized
          total_heating_capacity_w += water_heater.autosizedHeaterMaximumCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name} capacity of WaterHeater:Mixed #{water_heater.name} is not available, total heating capacity of plant loop will be incorrect when applying standard.")
        end
        # WaterHeater:Stratified
      elsif sc.to_WaterHeaterStratified.is_initialized
        water_heater = sc.to_WaterHeaterStratified.get
        if water_heater.heater1Capacity.is_initialized
          total_heating_capacity_w += water_heater.heater1Capacity.get
        end
        if water_heater.heater2Capacity.is_initialized
          total_heating_capacity_w += water_heater.heater2Capacity.get
        end
        # DistrictHeating
      elsif sc.to_DistrictHeating.is_initialized
        dist_htg = sc.to_DistrictHeating.get
        if dist_htg.nominalCapacity.is_initialized
          total_heating_capacity_w += dist_htg.nominalCapacity.get
        elsif dist_htg.autosizedNominalCapacity.is_initialized
          total_heating_capacity_w += dist_htg.autosizedNominalCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name} capacity of DistrictHeating #{dist_htg.name} is not available, total heating capacity of plant loop will be incorrect when applying standard.")
        end
      end
    end # End loop on plant_loop.supplyComponents

    total_heating_capacity_kbtu_per_hr = OpenStudio.convert(total_heating_capacity_w, 'W', 'kBtu/hr').get
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, heating capacity is #{total_heating_capacity_kbtu_per_hr.round} kBtu/hr.")

    return total_heating_capacity_w
  end

  # Determine the total floor area served by this loop.
  # If the loop serves a coil attached to an AirLoopHVAC,
  # count the area of all zones served by that loop.
  # If the loop serves coils inside of zone equipment,
  # count the area of the zones containing the zone equipment.
  def plant_loop_total_floor_area_served(plant_loop)
    sizing_plant = plant_loop.sizingPlant
    loop_type = sizing_plant.loopType

    # Get all the coils served by this loop
    coils = []
    case loop_type
      when 'Heating'
        plant_loop.demandComponents.each do |dc|
          if dc.to_CoilHeatingWater.is_initialized
            coils << dc.to_CoilHeatingWater.get
          end
        end
      when 'Cooling'
        plant_loop.demandComponents.each do |dc|
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

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{plant_loop.name}, serves #{area_served_ft2.round} ft^2.")

    return area_served_m2
  end

  # Applies the pumping controls to the loop based on Appendix G.
  def plant_loop_apply_prm_baseline_pumping_type(plant_loop)
    sizing_plant = plant_loop.sizingPlant
    loop_type = sizing_plant.loopType

    case loop_type
      when 'Heating'
        plant_loop_apply_prm_baseline_hot_water_pumping_type(plant_loop)
      when 'Cooling'
        plant_loop_apply_prm_baseline_chilled_water_pumping_type(plant_loop)
      when 'Condenser'
        plant_loop_apply_prm_baseline_condenser_water_pumping_type(plant_loop)
    end

    return true
  end

  # Applies the chilled water pumping controls to the loop based on Appendix G.
  def plant_loop_apply_prm_baseline_chilled_water_pumping_type(plant_loop)
    # Determine the pumping type.
    minimum_cap_tons = 300

    # Determine the capacity
    cap_w = plant_loop_total_cooling_capacity(plant_loop)
    cap_tons = OpenStudio.convert(cap_w, 'W', 'ton').get

    # Determine if it a district cooling system
    has_district_cooling = false
    plant_loop.supplyComponents.each do |sc|
      if sc.to_DistrictCooling.is_initialized
        has_district_cooling = true
      end
    end

    # Determine the primary and secondary pumping types
    pri_control_type = nil
    sec_control_type = nil
    if has_district_cooling
      pri_control_type = if cap_tons > minimum_cap_tons
                           'VSD No Reset'
                         else
                           'Riding Curve'
                         end
    else
      pri_control_type = 'Constant Flow'
      sec_control_type = if cap_tons > minimum_cap_tons
                           'VSD No Reset'
                         else
                           'Riding Curve'
                         end
    end

    # Report out the pumping type
    unless pri_control_type.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{plant_loop.name}, primary pump type is #{pri_control_type}.")
    end

    unless sec_control_type.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{plant_loop.name}, secondary pump type is #{sec_control_type}.")
    end

    # Modify all the primary pumps
    plant_loop.supplyComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump_variable_speed_set_control_type(pump, pri_control_type)
      elsif sc.to_HeaderedPumpsVariableSpeed.is_initialized
        pump = sc.to_HeaderedPumpsVariableSpeed.get
        headered_pump_variable_speed_set_control_type(pump, control_type)
      end
    end

    # Modify all the secondary pumps
    plant_loop.demandComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump_variable_speed_set_control_type(pump, sec_control_type)
      elsif sc.to_HeaderedPumpsVariableSpeed.is_initialized
        pump = sc.to_HeaderedPumpsVariableSpeed.get
        headered_pump_variable_speed_set_control_type(pump, control_type)
      end
    end

    return true
  end

  # Applies the hot water pumping controls to the loop based on Appendix G.
  def plant_loop_apply_prm_baseline_hot_water_pumping_type(plant_loop)
    # Determine the minimum area to determine
    # pumping type.
    minimum_area_ft2 = 120_000

    # Determine the area served
    area_served_m2 = plant_loop_total_floor_area_served(plant_loop)
    area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get

    # Determine the pump type
    control_type = 'Riding Curve'
    if area_served_ft2 > minimum_area_ft2
      control_type = 'VSD No Reset'
    end

    # Modify all the primary pumps
    plant_loop.supplyComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump_variable_speed_set_control_type(pump, control_type)
      end
    end

    # Report out the pumping type
    unless control_type.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{plant_loop.name}, pump type is #{control_type}.")
    end

    return true
  end

  # Applies the condenser water pumping controls to the loop based on Appendix G.
  def plant_loop_apply_prm_baseline_condenser_water_pumping_type(plant_loop)
    # All condenser water loops are constant flow
    control_type = 'Constant Flow'

    # Report out the pumping type
    unless control_type.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{plant_loop.name}, pump type is #{control_type}.")
    end

    # Modify all primary pumps
    plant_loop.supplyComponents.each do |sc|
      if sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump_variable_speed_set_control_type(pump, control_type)
      elsif sc.to_HeaderedPumpsVariableSpeed.is_initialized
        pump = sc.to_HeaderedPumpsVariableSpeed.get
        headered_pump_variable_speed_set_control_type(pump, control_type)
      end
    end

    return true
  end

  # Splits the single boiler used for the initial sizing run
  # into multiple separate boilers based on Appendix G.
  def plant_loop_apply_prm_number_of_boilers(plant_loop)
    # Skip non-heating plants
    return true unless plant_loop.sizingPlant.loopType == 'Heating'

    # Determine the minimum area to determine
    # number of boilers.
    minimum_area_ft2 = 15_000

    # Determine the area served
    area_served_m2 = plant_loop_total_floor_area_served(plant_loop)
    area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get

    # Do nothing if only one boiler is required
    return true if area_served_ft2 < minimum_area_ft2

    # Get all existing boilers
    boilers = []
    plant_loop.supplyComponents.each do |sc|
      if sc.to_BoilerHotWater.is_initialized
        boilers << sc.to_BoilerHotWater.get
      end
    end

    # Ensure there is only 1 boiler to start
    first_boiler = nil
    if boilers.size.zero?
      return true
    elsif boilers.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, found #{boilers.size}, cannot split up per performance rating method baseline requirements.")
    else
      first_boiler = boilers[0]
    end

    # Clone the existing boiler and create
    # a new branch for it
    second_boiler = first_boiler.clone(plant_loop.model)
    if second_boiler.to_BoilerHotWater.is_initialized
      second_boiler = second_boiler.to_BoilerHotWater.get
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, could not clone boiler #{first_boiler.name}, cannot apply the performance rating method number of boilers.")
      return false
    end
    plant_loop.addSupplyBranchForComponent(second_boiler)
    final_boilers = [first_boiler, second_boiler]
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, added a second boiler.")

    # Set the sizing factor for all boilers evenly and Rename the boilers
    sizing_factor = (1.0 / final_boilers.size).round(2)
    final_boilers.each_with_index do |boiler, i|
      boiler.setSizingFactor(sizing_factor)
      boiler.setName("#{first_boiler.name} #{i + 1} of #{final_boilers.size}")
    end

    # Set the equipment to stage sequentially
    plant_loop.setLoadDistributionScheme('SequentialLoad')

    return true
  end

  # Splits the single chiller used for the initial sizing run
  # into multiple separate chillers based on Appendix G.
  def plant_loop_apply_prm_number_of_chillers(plant_loop)
    # Skip non-cooling plants
    return true unless plant_loop.sizingPlant.loopType == 'Cooling'

    # Determine the number and type of chillers
    num_chillers = nil
    chiller_cooling_type = nil
    chiller_compressor_type = nil

    # Determine the capacity of the loop
    cap_w = plant_loop_total_cooling_capacity(plant_loop)
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

    # Get all existing chillers and pumps
    chillers = []
    pumps = []
    plant_loop.supplyComponents.each do |sc|
      if sc.to_ChillerElectricEIR.is_initialized
        chillers << sc.to_ChillerElectricEIR.get
      elsif sc.to_PumpConstantSpeed.is_initialized
        pumps << sc.to_PumpConstantSpeed.get
      elsif sc.to_PumpVariableSpeed.is_initialized
        pumps << sc.to_PumpVariableSpeed.get
      end
    end

    # Ensure there is only 1 chiller to start
    first_chiller = nil
    if chillers.size.zero?
      return true
    elsif chillers.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, found #{chillers.size} chillers, cannot split up per performance rating method baseline requirements.")
    else
      first_chiller = chillers[0]
    end

    # Ensure there is only 1 pump to start
    orig_pump = nil
    if pumps.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, found #{pumps.size} pumps.  A loop must have at least one pump.")
      return false
    elsif pumps.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, found #{pumps.size} pumps, cannot split up per performance rating method baseline requirements.")
      return false
    else
      orig_pump = pumps[0]
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
      new_chiller = first_chiller.clone(plant_loop.model)
      if new_chiller.to_ChillerElectricEIR.is_initialized
        new_chiller = new_chiller.to_ChillerElectricEIR.get
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, could not clone chiller #{first_chiller.name}, cannot apply the performance rating method number of chillers.")
        return false
      end
      # Connect the new chiller to the same CHW loop
      # as the old chiller.
      plant_loop.addSupplyBranchForComponent(new_chiller)
      # Connect the new chiller to the same CW loop
      # as the old chiller, if it was water-cooled.
      cw_loop = first_chiller.secondaryPlantLoop
      if cw_loop.is_initialized
        cw_loop.get.addDemandBranchForComponent(new_chiller)
      end

      final_chillers << new_chiller
    end

    # If there is more than one cooling tower,
    # replace the original pump with a headered pump
    # of the same type and properties.
    if final_chillers.size > 1
      num_pumps = final_chillers.size
      new_pump = nil
      if orig_pump.to_PumpConstantSpeed.is_initialized
        new_pump = OpenStudio::Model::HeaderedPumpsConstantSpeed.new(plant_loop.model)
        new_pump.setNumberofPumpsinBank(num_pumps)
        new_pump.setName("#{orig_pump.name} Bank of #{num_pumps}")
        new_pump.setRatedPumpHead(orig_pump.ratedPumpHead)
        new_pump.setMotorEfficiency(orig_pump.motorEfficiency)
        new_pump.setFractionofMotorInefficienciestoFluidStream(orig_pump.fractionofMotorInefficienciestoFluidStream)
        new_pump.setPumpControlType(orig_pump.pumpControlType)
      elsif orig_pump.to_PumpVariableSpeed.is_initialized
        new_pump = OpenStudio::Model::HeaderedPumpsVariableSpeed.new(plant_loop.model)
        new_pump.setNumberofPumpsinBank(num_pumps)
        new_pump.setName("#{orig_pump.name} Bank of #{num_pumps}")
        new_pump.setRatedPumpHead(orig_pump.ratedPumpHead)
        new_pump.setMotorEfficiency(orig_pump.motorEfficiency)
        new_pump.setFractionofMotorInefficienciestoFluidStream(orig_pump.fractionofMotorInefficienciestoFluidStream)
        new_pump.setPumpControlType(orig_pump.pumpControlType)
        new_pump.setCoefficient1ofthePartLoadPerformanceCurve(orig_pump.coefficient1ofthePartLoadPerformanceCurve)
        new_pump.setCoefficient2ofthePartLoadPerformanceCurve(orig_pump.coefficient2ofthePartLoadPerformanceCurve)
        new_pump.setCoefficient3ofthePartLoadPerformanceCurve(orig_pump.coefficient3ofthePartLoadPerformanceCurve)
        new_pump.setCoefficient4ofthePartLoadPerformanceCurve(orig_pump.coefficient4ofthePartLoadPerformanceCurve)
      end
      # Remove the old pump
      orig_pump.remove
      # Attach the new headered pumps
      new_pump.addToNode(plant_loop.supplyInletNode)
    end

    # Set the sizing factor and the chiller types
    final_chillers.each_with_index do |final_chiller, i|
      final_chiller.setName("#{template} #{chiller_cooling_type} #{chiller_compressor_type} Chiller #{i + 1} of #{final_chillers.size}")
      final_chiller.setSizingFactor(per_chiller_sizing_factor)
      final_chiller.setCondenserType(chiller_cooling_type)
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, there are #{final_chillers.size} #{chiller_cooling_type} #{chiller_compressor_type} chillers.")

    # Set the equipment to stage sequentially
    plant_loop.setLoadDistributionScheme('SequentialLoad')

    return true
  end

  # Splits the single cooling tower used for the initial sizing run
  # into multiple separate cooling towers based on Appendix G.
  def plant_loop_apply_prm_number_of_cooling_towers(plant_loop)
    # Skip non-cooling plants
    return true unless plant_loop.sizingPlant.loopType == 'Condenser'

    # Determine the number of chillers
    # already in the model
    num_chillers = plant_loop.model.getChillerElectricEIRs.size

    # Get all existing cooling towers and pumps
    clg_twrs = []
    pumps = []
    plant_loop.supplyComponents.each do |sc|
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
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, found #{clg_twrs.size} cooling towers, cannot split up per performance rating method baseline requirements.")
      return false
    else
      orig_twr = clg_twrs[0]
    end

    # Ensure there is only 1 pump to start
    orig_pump = nil
    if pumps.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, found #{pumps.size} pumps.  A loop must have at least one pump.")
      return false
    elsif pumps.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, found #{pumps.size} pumps, cannot split up per performance rating method baseline requirements.")
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
        new_twr = orig_twr.clone(plant_loop.model)
        new_twr = new_twr.to_CoolingTowerSingleSpeed.get
      elsif orig_twr.to_CoolingTowerTwoSpeed.is_initialized
        new_twr = orig_twr.clone(plant_loop.model)
        new_twr = new_twr.to_CoolingTowerTwoSpeed.get
      elsif orig_twr.to_CoolingTowerVariableSpeed.is_initialized
        # TODO: remove workaround after resolving
        # https://github.com/NREL/OpenStudio/issues/2212
        # Workaround is to create a new tower
        # and replicate all the properties of the first tower.
        new_twr = OpenStudio::Model::CoolingTowerVariableSpeed.new(plant_loop.model)
        new_twr.setName(orig_twr.name.get.to_s)
        new_twr.setDesignInletAirWetBulbTemperature(orig_twr.designInletAirWetBulbTemperature.get)
        new_twr.setDesignApproachTemperature(orig_twr.designApproachTemperature.get)
        new_twr.setDesignRangeTemperature(orig_twr.designRangeTemperature.get)
        new_twr.setFractionofTowerCapacityinFreeConvectionRegime(orig_twr.fractionofTowerCapacityinFreeConvectionRegime.get)
        if orig_twr.fanPowerRatioFunctionofAirFlowRateRatioCurve.is_initialized
          new_twr.setFanPowerRatioFunctionofAirFlowRateRatioCurve(orig_twr.fanPowerRatioFunctionofAirFlowRateRatioCurve.get)
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, could not clone cooling tower #{orig_twr.name}, cannot apply the performance rating method number of cooling towers.")
        return false
      end

      # Connect the new cooling tower to the CW loop
      plant_loop.addSupplyBranchForComponent(new_twr)
      new_twr_inlet = new_twr.inletModelObject.get.to_Node.get

      final_twrs << new_twr
    end

    # If there is more than one cooling tower,
    # replace the original pump with a headered pump
    # of the same type and properties.
    if final_twrs.size > 1
      num_pumps = final_twrs.size
      new_pump = nil
      if orig_pump.to_PumpConstantSpeed.is_initialized
        new_pump = OpenStudio::Model::HeaderedPumpsConstantSpeed.new(plant_loop.model)
        new_pump.setNumberofPumpsinBank(num_pumps)
        new_pump.setName("#{orig_pump.name} Bank of #{num_pumps}")
        new_pump.setRatedPumpHead(orig_pump.ratedPumpHead)
        new_pump.setMotorEfficiency(orig_pump.motorEfficiency)
        new_pump.setFractionofMotorInefficienciestoFluidStream(orig_pump.fractionofMotorInefficienciestoFluidStream)
        new_pump.setPumpControlType(orig_pump.pumpControlType)
      elsif orig_pump.to_PumpVariableSpeed.is_initialized
        new_pump = OpenStudio::Model::HeaderedPumpsVariableSpeed.new(plant_loop.model)
        new_pump.setNumberofPumpsinBank(num_pumps)
        new_pump.setName("#{orig_pump.name} Bank of #{num_pumps}")
        new_pump.setRatedPumpHead(orig_pump.ratedPumpHead)
        new_pump.setMotorEfficiency(orig_pump.motorEfficiency)
        new_pump.setFractionofMotorInefficienciestoFluidStream(orig_pump.fractionofMotorInefficienciestoFluidStream)
        new_pump.setPumpControlType(orig_pump.pumpControlType)
        new_pump.setCoefficient1ofthePartLoadPerformanceCurve(orig_pump.coefficient1ofthePartLoadPerformanceCurve)
        new_pump.setCoefficient2ofthePartLoadPerformanceCurve(orig_pump.coefficient2ofthePartLoadPerformanceCurve)
        new_pump.setCoefficient3ofthePartLoadPerformanceCurve(orig_pump.coefficient3ofthePartLoadPerformanceCurve)
        new_pump.setCoefficient4ofthePartLoadPerformanceCurve(orig_pump.coefficient4ofthePartLoadPerformanceCurve)
      end
      # Remove the old pump
      orig_pump.remove
      # Attach the new headered pumps
      new_pump.addToNode(plant_loop.supplyInletNode)
    end

    # Set the sizing factors
    final_twrs.each_with_index do |final_cooling_tower, i|
      final_cooling_tower.setName("#{final_cooling_tower.name} #{i + 1} of #{final_twrs.size}")
      final_cooling_tower.setSizingFactor(clg_twr_sizing_factor)
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, there are #{final_twrs.size} cooling towers, one for each chiller.")

    # Set the equipment to stage sequentially
    plant_loop.setLoadDistributionScheme('SequentialLoad')
  end

  # Determines the total rated watts per GPM of the loop
  #
  # @return [Double] rated power consumption per flow
  #   @units Watts per GPM (W*s/m^3)
  def plant_loop_total_rated_w_per_gpm(plant_loop)
    sizing_plant = plant_loop.sizingPlant
    loop_type = sizing_plant.loopType

    # Supply W/GPM
    supply_w_per_gpm = 0
    demand_w_per_gpm = 0

    plant_loop.supplyComponents.each do |component|
      if component.to_PumpConstantSpeed.is_initialized
        pump = component.to_PumpConstantSpeed.get
        pump_rated_w_per_gpm = pump_rated_w_per_gpm(pump)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "'#{loop_type}' Loop #{plant_loop.name} - Primary (Supply) Constant Speed Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        supply_w_per_gpm += pump_rated_w_per_gpm
      elsif component.to_PumpVariableSpeed.is_initialized
        pump = component.to_PumpVariableSpeed.get
        pump_rated_w_per_gpm = pump_rated_w_per_gpm(pump)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "'#{loop_type}' Loop #{plant_loop.name} - Primary (Supply) VSD Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        supply_w_per_gpm += pump_rated_w_per_gpm
      end
    end

    # Determine if primary only or primary-secondary
    # IF there's a pump on the demand side it's primary-secondary
    demand_pumps = plant_loop.demandComponents('OS:Pump:VariableSpeed'.to_IddObjectType) + plant_loop.demandComponents('OS:Pump:ConstantSpeed'.to_IddObjectType)
    demand_pumps.each do |component|
      if component.to_PumpConstantSpeed.is_initialized
        pump = component.to_PumpConstantSpeed.get
        pump_rated_w_per_gpm = pump_rated_w_per_gpm(pump)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "'#{loop_type}' Loop #{plant_loop.name} - Secondary (Demand) Constant Speed Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        demand_w_per_gpm += pump_rated_w_per_gpm
      elsif component.to_PumpVariableSpeed.is_initialized
        pump = component.to_PumpVariableSpeed.get
        pump_rated_w_per_gpm = pump_rated_w_per_gpm(pump)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Pump', "'#{loop_type}' Loop #{plant_loop.name} - Secondary (Demand) VSD Pump '#{pump.name}' - pump_rated_w_per_gpm #{pump_rated_w_per_gpm} W/GPM")
        demand_w_per_gpm += pump_rated_w_per_gpm
      end
    end

    total_rated_w_per_gpm = supply_w_per_gpm + demand_w_per_gpm

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Loop', "'#{loop_type}' Loop #{plant_loop.name} - Total #{total_rated_w_per_gpm} W/GPM - Supply #{supply_w_per_gpm} W/GPM - Demand #{demand_w_per_gpm} W/GPM")

    return total_rated_w_per_gpm
  end

  # find maximum_loop_flow_rate
  #
  # @return [Double]  maximum_loop_flow_rate m^3/s
  def plant_loop_find_maximum_loop_flow_rate(plant_loop)
    # Get the maximum_loop_flow_rate
    maximum_loop_flow_rate = nil
    if plant_loop.maximumLoopFlowRate.is_initialized
      maximum_loop_flow_rate = plant_loop.maximumLoopFlowRate.get
    elsif plant_loop.autosizedMaximumLoopFlowRate.is_initialized
      maximum_loop_flow_rate = plant_loop.autosizedMaximumLoopFlowRate.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name} maximum loop flow rate is not available.")
    end

    return maximum_loop_flow_rate
  end

  # Determines if the loop is a Service Water Heating loop by checking if there is a WaterUseConnection on the demand side
  # or a WaterHeaterMixed on the supply side
  #
  # @return [Boolean] true if it's indeed a SHW loop, false otherwise
  def plant_loop_swh_loop?(plant_loop)
    serves_swh = false
    plant_loop.demandComponents.each do |comp|
      if comp.to_WaterUseConnections.is_initialized
        serves_swh = true
        break
      end
    end
    plant_loop.supplyComponents.each do |comp|
      if comp.to_WaterHeaterMixed.is_initialized
        serves_swh = true
        break
      end
    end

    # If there is a waterheater on the demand side,
    # check if the loop connected to that waterheater's
    # demand side is an swh loop itself
    plant_loop.demandComponents.each do |comp|
      if comp.to_WaterHeaterMixed.is_initialized
        comp = comp.to_WaterHeaterMixed.get
        if comp.plantLoop.is_initialized
          if plant_loop_swh_loop?(comp.plantLoop.get)
            serves_swh = true
            break
          end
        end
      end
    end

    return serves_swh
  end

  # Classifies the service water system and returns information
  # about fuel types, whether it serves both heating and service water heating,
  # the water storage volume, and the total heating capacity.
  #
  # @return [Array<Array<String>, Bool, Double, Double>] An array of:
  # fuel types, combination_system (true/false), storage_capacity (m^3), plant_loop_total_heating_capacity(plant_loop)  (W)
  def plant_loop_swh_system_type(plant_loop)
    combination_system = true
    storage_capacity = 0
    primary_fuels = []
    secondary_fuels = []

    # @Todo: to work correctly, plant_loop_total_heating_capacity(plantloop)  requires to have either hardsized capacities or a sizing run.
    primary_heating_capacity = plant_loop_total_heating_capacity(plant_loop)
    secondary_heating_capacity = 0

    plant_loop.supplyComponents.each do |component|
      # Get the object type
      obj_type = component.iddObjectType.valueName.to_s

      case obj_type
        when 'OS_DistrictHeating'
          primary_fuels << 'DistrictHeating'
          combination_system = false
        when 'OS_HeatPump_WaterToWater_EquationFit_Heating'
          primary_fuels << 'Electricity'
        when 'OS_SolarCollector_FlatPlate_PhotovoltaicThermal'
          primary_fuels << 'SolarEnergy'
        when 'OS_SolarCollector_FlatPlate_Water'
          primary_fuels << 'SolarEnergy'
        when 'OS_SolarCollector_IntegralCollectorStorage'
          primary_fuels << 'SolarEnergy'
        when 'OS_WaterHeater_HeatPump'
          primary_fuels << 'Electricity'
        when 'OS_WaterHeater_Mixed'
          component = component.to_WaterHeaterMixed.get
          # Check it it's actually a heater, not just a storage tank
          if component.heaterMaximumCapacity.empty? || component.heaterMaximumCapacity.get != 0
            # If it does, we add the heater Fuel Type
            primary_fuels << component.heaterFuelType
            # And in this case we'll reuse this object
            combination_system = false
          end # @Todo: not sure about whether it should be an elsif or not
          # Check the plant loop connection on the source side
          if component.secondaryPlantLoop.is_initialized
            source_plant_loop = component.secondaryPlantLoop.get
            secondary_fuels += plant_loop.model.plant_loop_heating_fuels(source_plant_loop)
            secondary_heating_capacity += plant_loop_total_heating_capacity(source_plant_loop)
          end

          # Storage capacity
          if component.tankVolume.is_initialized
            storage_capacity = component.tankVolume.get
          end

        when 'OS_WaterHeater_Stratified'
          component = component.to_WaterHeaterStratified.get

          # Check if the heater actually has a capacity (otherwise it's simply a Storage Tank)
          if component.heaterMaximumCapacity.empty? || component.heaterMaximumCapacity.get != 0
            # If it does, we add the heater Fuel Type
            primary_fuels << component.heaterFuelType
            # And in this case we'll reuse this object
            combination_system = false
          end # @Todo: not sure about whether it should be an elsif or not
          # Check the plant loop connection on the source side
          if component.secondaryPlantLoop.is_initialized
            source_plant_loop = component.secondaryPlantLoop.get
            secondary_fuels += plant_loop.model.plant_loop_heating_fuels(source_plant_loop)
            secondary_heating_capacity += plant_loop_total_heating_capacity(source_plant_loop)
          end

          # Storage capacity
          if component.tankVolume.is_initialized
            storage_capacity = component.tankVolume.get
          end

        when 'OS_HeatExchanger_FluidToFluid'
          hx = component.to_HeatExchangerFluidToFluid.get
          cooling_hx_control_types = ['CoolingSetpointModulated', 'CoolingSetpointOnOff', 'CoolingDifferentialOnOff', 'CoolingSetpointOnOffWithComponentOverride']
          cooling_hx_control_types.each(&:downcase!)
          if !cooling_hx_control_types.include?(hx.controlType.downcase) && hx.secondaryPlantLoop.is_initialized
            source_plant_loop = hx.secondaryPlantLoop.get
            secondary_fuels += plant_loop.model.plant_loop_heating_fuels(source_plant_loop)
            secondary_heating_capacity += plant_loop_total_heating_capacity(source_plant_loop)
          end

        when 'OS_Node', 'OS_Pump_ConstantSpeed', 'OS_Pump_VariableSpeed', 'OS_Connector_Splitter', 'OS_Connector_Mixer', 'OS_Pipe_Adiabatic'
        # To avoid extraneous debug messages
      end
    end

    # @Todo: decide how to handle primary and secondary stuff
    fuels = primary_fuels + secondary_fuels
    total_heating_capacity = primary_heating_capacity + secondary_heating_capacity
    # If the primary heating capacity is bigger than secondary, assume the secondary is just a backup and disregard it?
    # if primary_heating_capacity > secondary_heating_capacity
    #   plant_loop_total_heating_capacity(plant_loop)  = primary_heating_capacity
    #   fuels = primary_fuels
    # end

    return fuels.uniq.sort, combination_system, storage_capacity, total_heating_capacity
  end # end classify_swh_system_type

  # This method calculates the capacity of a plant loop by multiplying the temp difference across the loop, the maximum flow rate,
  # the fluid density, and the fluid heat capacity (currently only works with water).  This may be a little more approximate than the
  # heating and cooling capacity methods described above however is not limited to certain types of equipment and can be used for
  # condensing plant loops too.
  def plant_loop_capacity_W_by_maxflow_and_deltaT_forwater (plant_loop)
    plantloop_maxflowrate = nil
    if plant_loop.fluidType != "Water"
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "The fluid used in the plant loop named #{plant_loop.name.to_s} is not water.  The current version of this method only calculates the capacity of plant loops that use water.")
    end
    plantloop_maxflowrate = plant_loop_find_maximum_loop_flow_rate(plant_loop)
    plantloop_dt = plant_loop.sizingPlant.loopDesignTemperatureDifference.to_f
    # Plant loop capacity = temperature difference across plant loop * maximum plant loop flow rate * density of water (1000 kg/m^3) * see next line
    # Heat capacity of water (4180 J/(kg*K))
    plantloop_capacity = plantloop_dt*plantloop_maxflowrate*1000*4180
    return plantloop_capacity
  end
end
class ASHRAE901PRM < Standard
  # Keep only one cooling tower, but use one condenser pump per chiller
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

    final_twrs = [orig_twr]

    # If there is more than one chiller,
    # replace the original pump with a headered pump
    # of the same type and properties.
    if num_chillers > 1
      num_pumps = num_chillers
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
  end

  # Enable reset of hot or chilled water temperature based on outdoor air temperature.
  # This function added exception for loops running on district sources.
  #
  # @param plant_loop [OpenStudio::Model::PlantLoop] plant loop
  # @return [Bool] returns true if successful, false if not
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

      # Not tested
      # TODO develop a district system prototype building
      has_district_heating = false
      plant_loop.supplyComponents.each do |sc|
        if sc.to_DistrictHeating.is_initialized
          has_district_heating = true
        end
      end

      if has_district_heating
        return false
      end

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

      has_district_cooling = false
      plant_loop.supplyComponents.each do |sc|
        if sc.to_DistrictCooling.is_initialized
          has_district_cooling = true
        end
      end

      if has_district_cooling
        return false
      end

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
end


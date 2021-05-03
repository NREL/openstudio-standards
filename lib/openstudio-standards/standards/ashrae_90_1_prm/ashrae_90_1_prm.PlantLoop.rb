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
end

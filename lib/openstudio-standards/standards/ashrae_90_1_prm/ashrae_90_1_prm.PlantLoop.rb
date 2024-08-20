class ASHRAE901PRM < Standard
  # Keep only one cooling tower, but use one condenser pump per chiller

  # @param plant_loop [OpenStudio::Model::PlantLoop] plant loop
  # @return [Boolean] returns true if successful, false if not
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
    if clg_twrs.empty?
      return true
    elsif clg_twrs.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, found #{clg_twrs.size} cooling towers, cannot split up per performance rating method baseline requirements.")
      return false
    else
      orig_twr = clg_twrs[0]
    end

    # Ensure there is only 1 pump to start
    orig_pump = nil
    if pumps.empty?
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

    # return unless there is more than one chiller
    return true unless num_chillers > 1

    # If there is more than one chiller, replace the original pump with a headered pump of the same type and properties.
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

    return true
  end

  # Splits the single chiller used for the initial sizing run
  # into multiple separate chillers based on Appendix G.
  #
  # @param plant_loop [OpenStudio::Model::PlantLoop] chilled water loop
  # @param sizing_run_dir [String] sizing run directory
  # @return [Boolean] returns true if successful, false if not
  def plant_loop_apply_prm_number_of_chillers(plant_loop, sizing_run_dir = nil)
    # Skip non-cooling plants & secondary cooling loop
    return true unless plant_loop.sizingPlant.loopType == 'Cooling'
    # If the loop is cooling but it is a secondary loop, then skip.
    return true if plant_loop.additionalProperties.hasFeature('is_secondary_loop')

    # Determine the number and type of chillers
    num_chillers = nil
    chiller_cooling_type = nil
    chiller_compressor_type = nil

    # Set the equipment to stage sequentially or uniformload if there is secondary loop
    if plant_loop.additionalProperties.hasFeature('is_primary_loop')
      plant_loop.setLoadDistributionScheme('UniformLoad')
    else
      plant_loop.setLoadDistributionScheme('SequentialLoad')
    end

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
    return true if chillers.empty?

    if chillers.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'prm.log', "For #{plant_loop.name}, found #{chillers.size} chillers, cannot split up per performance rating method baseline requirements.")
    else
      first_chiller = chillers[0]
    end

    # Ensure there is only 1 pump to start
    orig_pump = nil
    if pumps.empty?
      OpenStudio.logFree(OpenStudio::Error, 'prm.log', "For #{plant_loop.name}, found #{pumps.size} pumps. A loop must have at least one pump.")
      return false
    elsif pumps.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'prm.log', "For #{plant_loop.name}, found #{pumps.size} pumps, cannot split up per performance rating method baseline requirements.")
      return false
    else
      orig_pump = pumps[0]
    end

    # Determine the per-chiller capacity
    # and sizing factor
    per_chiller_sizing_factor = (1.0 / num_chillers).round(2)
    # This is unused
    per_chiller_cap_tons = cap_tons / num_chillers
    per_chiller_cap_w = cap_w / num_chillers

    # Set the sizing factor and the chiller type: could do it on the first chiller before cloning it, but renaming warrants looping on chillers anyways

    # Add any new chillers
    final_chillers = [first_chiller]
    (num_chillers - 1).times do
      new_chiller = first_chiller.clone(plant_loop.model)
      if new_chiller.to_ChillerElectricEIR.is_initialized
        new_chiller = new_chiller.to_ChillerElectricEIR.get
      else
        OpenStudio.logFree(OpenStudio::Error, 'prm.log', "For #{plant_loop.name}, could not clone chiller #{first_chiller.name}, cannot apply the performance rating method number of chillers.")
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
    # add one pump to each chiller, assume chillers are equally sized
    if final_chillers.size > 1
      num_pumps = final_chillers.size
      final_chillers.each do |chiller|
        if orig_pump.to_PumpConstantSpeed.is_initialized
          new_pump = OpenStudio::Model::PumpConstantSpeed.new(plant_loop.model)
          new_pump.setName("#{chiller.name} Primary Pump")
          # Will need to adjust the pump power after a sizing run
          new_pump.setRatedPumpHead(orig_pump.ratedPumpHead / num_pumps)
          new_pump.setMotorEfficiency(0.9)
          new_pump.setPumpControlType('Intermittent')
          chiller_inlet_node = chiller.connectedObject(chiller.supplyInletPort).get.to_Node.get
          new_pump.addToNode(chiller_inlet_node)
        elsif orig_pump.to_PumpVariableSpeed.is_initialized
          new_pump = OpenStudio::Model::PumpVariableSpeed.new(plant_loop.model)
          new_pump.setName("#{chiller.name} Primary Pump")
          new_pump.setRatedPumpHead(orig_pump.ratedPumpHead / num_pumps)
          new_pump.setCoefficient1ofthePartLoadPerformanceCurve(orig_pump.coefficient1ofthePartLoadPerformanceCurve)
          new_pump.setCoefficient2ofthePartLoadPerformanceCurve(orig_pump.coefficient2ofthePartLoadPerformanceCurve)
          new_pump.setCoefficient3ofthePartLoadPerformanceCurve(orig_pump.coefficient3ofthePartLoadPerformanceCurve)
          new_pump.setCoefficient4ofthePartLoadPerformanceCurve(orig_pump.coefficient4ofthePartLoadPerformanceCurve)
          chiller_inlet_node = chiller.connectedObject(chiller.supplyInletPort).get.to_Node.get
          new_pump.addToNode(chiller_inlet_node)
        end
      end
      # Remove the old pump
      orig_pump.remove
    end

    # Set the sizing factor and the chiller types
    final_chillers.each_with_index do |final_chiller, i|
      final_chiller.setName("#{template} #{chiller_cooling_type} #{chiller_compressor_type} Chiller #{i + 1} of #{final_chillers.size}")
      final_chiller.setSizingFactor(per_chiller_sizing_factor)
      final_chiller.setReferenceCapacity(per_chiller_cap_w)
      final_chiller.setCondenserType(chiller_cooling_type)
      final_chiller.additionalProperties.setFeature('compressor_type', chiller_compressor_type)
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, there are #{final_chillers.size} #{chiller_cooling_type} #{chiller_compressor_type} chillers.")

    return true
  end

  # Apply prm baseline pump power
  # @note I think it makes more sense to sense the motor efficiency right there...
  #   But actually it's completely irrelevant...
  #   you could set at 0.9 and just calculate the pressure rise to have your 19 W/GPM or whatever
  #
  # @param plant_loop [OpenStudio::Model::PlantLoop] plant loop
  # @return [Boolean] returns true if successful, false if not
  def plant_loop_apply_prm_baseline_pump_power(plant_loop)
    hot_water_pump_power = 19 # W/gpm
    hot_water_district_pump_power = 14 # W/gpm
    chilled_water_primary_pump_power = 9 # W/gpm
    chilled_water_secondary_pump_power = 13 # W/gpm
    chilled_water_district_pump_power = 16 # W/gpm
    condenser_water_pump_power = 19 # W/gpm
    # Determine the pumping power per
    # flow based on loop type.
    w_per_gpm = nil
    chiller_counter = 0

    sizing_plant = plant_loop.sizingPlant
    loop_type = sizing_plant.loopType

    case loop_type
    when 'Heating'

      has_district_heating = false
      plant_loop.supplyComponents.each do |sc|
        if sc.iddObjectType.valueName.to_s.include?('DistrictHeating')
          has_district_heating = true
        end
      end

      w_per_gpm = if has_district_heating # District HW
                    hot_water_district_pump_power
                  else # HW
                    hot_water_pump_power
                  end

    when 'Cooling'
      has_district_cooling = false
      plant_loop.supplyComponents.each do |sc|
        if sc.to_DistrictCooling.is_initialized
          has_district_cooling = true
        elsif sc.to_ChillerElectricEIR.is_initialized
          chiller_counter += 1
        end
      end

      if has_district_cooling # District CHW
        w_per_gpm = chilled_water_district_pump_power
      elsif plant_loop.additionalProperties.hasFeature('is_primary_loop') # The primary loop of the primary/secondary CHW
        w_per_gpm = chilled_water_primary_pump_power
      elsif plant_loop.additionalProperties.hasFeature('is_secondary_loop') # The secondary loop of the primary/secondary CHW
        w_per_gpm = chilled_water_secondary_pump_power
      else # Primary only CHW combine 9W/gpm + 13W/gpm
        w_per_gpm = chilled_water_primary_pump_power + chilled_water_secondary_pump_power
      end

    when 'Condenser'
      # @todo prm condenser loop pump power
      w_per_gpm = condenser_water_pump_power
    end

    # Modify all the primary pumps
    plant_loop.supplyComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
        if chiller_counter > 0
          w_per_gpm /= chiller_counter
        end
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, w_per_gpm)
      elsif sc.to_PumpVariableSpeed.is_initialized
        pump = sc.to_PumpVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, w_per_gpm)
      elsif sc.to_HeaderedPumpsConstantSpeed.is_initialized
        pump = sc.to_HeaderedPumpsConstantSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, w_per_gpm)
      elsif sc.to_HeaderedPumpsVariableSpeed.is_initialized
        pump = sc.to_HeaderedPumpsVariableSpeed.get
        pump_apply_prm_pressure_rise_and_motor_efficiency(pump, w_per_gpm)
      end
    end
    return true
  end

  # Apply sizing and controls to chilled water loop
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param chilled_water_loop [OpenStudio::Model::PlantLoop] chilled water loop
  # @param dsgn_sup_wtr_temp [Double] design chilled water supply T
  # @param dsgn_sup_wtr_temp_delt [Double] design chilled water supply delta T
  # @return [Boolean] returns true if successful, false if not
  def chw_sizing_control(model, chilled_water_loop, dsgn_sup_wtr_temp, dsgn_sup_wtr_temp_delt)
    design_chilled_water_temperature = 44 # Loop design chilled water temperature (F)
    design_chilled_water_temperature_delta = 10.1 # Loop design chilled water temperature  (deltaF)
    chw_outdoor_temperature_high = 80 # Chilled water temperature reset at high outdoor air temperature (F)
    chw_outdoor_temperature_low = 60 # Chilled water temperature reset at low outdoor air temperature (F)
    chw_outdoor_high_setpoint = 44 # Chilled water setpoint temperature at high outdoor air temperature (F)
    chw_outdoor_low_setpoint = 54 # Chilled water setpoint temperature at low outdoor air temperature (F)
    chiller_chw_low_temp_limit = 36 # Chiller leaving chilled water lower temperature limit (F)
    chiller_chw_cond_temp = 95 # Chiller entering condenser fluid temperature (F)
    primary_pump_power = 9 # primary pump power (W/gpm)

    if dsgn_sup_wtr_temp.nil?
      dsgn_sup_wtr_temp_c = OpenStudio.convert(design_chilled_water_temperature, 'F', 'C').get
    else
      dsgn_sup_wtr_temp_c = OpenStudio.convert(dsgn_sup_wtr_temp, 'F', 'C').get
    end
    if dsgn_sup_wtr_temp_delt.nil?
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(design_chilled_water_temperature_delta, 'R', 'K').get
    else
      dsgn_sup_wtr_temp_delt_k = OpenStudio.convert(dsgn_sup_wtr_temp_delt, 'R', 'K').get
    end
    chilled_water_loop.setMinimumLoopTemperature(1.0)
    chilled_water_loop.setMaximumLoopTemperature(40.0)

    sizing_plant = chilled_water_loop.sizingPlant
    sizing_plant.setLoopType('Cooling')
    sizing_plant.setDesignLoopExitTemperature(dsgn_sup_wtr_temp_c)
    sizing_plant.setLoopDesignTemperatureDifference(dsgn_sup_wtr_temp_delt_k)
    # Use OA reset setpoint manager
    outdoor_low_temperature_c = OpenStudio.convert(chw_outdoor_temperature_low, 'F', 'C').get.round(1)
    outdoor_high_temperature_c = OpenStudio.convert(chw_outdoor_temperature_high, 'F', 'C').get.round(1)
    setpoint_temperature_outdoor_high_c = OpenStudio.convert(chw_outdoor_high_setpoint, 'F', 'C').get.round(1)
    setpoint_temperature_outdoor_low_c = OpenStudio.convert(chw_outdoor_low_setpoint, 'F', 'C').get.round(1)

    chw_stpt_manager = OpenStudio::Model::SetpointManagerOutdoorAirReset.new(model)
    chw_stpt_manager.setName("#{chilled_water_loop.name} Setpoint Manager")
    chw_stpt_manager.setOutdoorHighTemperature(outdoor_high_temperature_c) # Degrees Celsius
    chw_stpt_manager.setSetpointatOutdoorHighTemperature(setpoint_temperature_outdoor_high_c) # Degrees Celsius
    chw_stpt_manager.setOutdoorLowTemperature(outdoor_low_temperature_c) # Degrees Celsius
    chw_stpt_manager.setSetpointatOutdoorLowTemperature(setpoint_temperature_outdoor_low_c) # Degrees Celsius
    chw_stpt_manager.addToNode(chilled_water_loop.supplyOutletNode)

    return true
  end

  # Set configuration in model for chilled water primary/secondary loop interface
  # Use heat_exchanger for stable baseline
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [String] common_pipe or heat_exchanger
  def plant_loop_set_chw_pri_sec_configuration(model)
    pri_sec_config = 'heat_exchanger'
    return pri_sec_config
  end
end

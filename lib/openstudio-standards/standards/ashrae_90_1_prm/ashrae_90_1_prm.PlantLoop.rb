class ASHRAE901PRM < Standard
  HOT_WATER_PUMP_POWER = 19 # W/gpm
  HOT_WATER_DISTRICT_PUMP_POWER = 14 # W/gpm
  CHILLED_WATER_PRIMARY_PUMP_POWER = 9 # W/gpm
  CHILLED_WATER_SECONDARY_PUMP_POWER = 13 # W/gpm
  CHILLED_WATER_DISTRICT_PUMP_POWER = 16 # W/gpm
  CONDENSER_WATER_PUMP_POWER = 19 # W/gpm

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

  # Get the total cooling capacity for the plant loop
  #
  # @param plant_loop [OpenStudio::Model::PlantLoop] plant loop
  # @param [String] sizing_run_dir
  # @return [Double] total cooling capacity in watts
  def plant_loop_total_cooling_capacity(plant_loop, sizing_run_dir = Dir.pwd)
    # Sum the cooling capacity for all cooling components
    # on the plant loop.
    total_cooling_capacity_w = 0
    sizing_run_ran = false

    plant_loop.supplyComponents.each do |sc|
      # ChillerElectricEIR
      if sc.to_ChillerElectricEIR.is_initialized
        chiller = sc.to_ChillerElectricEIR.get

        # If chiller is autosized, check sizing run results. If sizing run not ran, run it first
        if chiller.isReferenceCapacityAutosized
          model = chiller.model
          sizing_run_ran = model_run_sizing_run(model, "#{sizing_run_dir}/SR_cooling_plant") if !sizing_run_ran

          if sizing_run_ran
            sizing_run_capacity = model.getAutosizedValueFromEquipmentSummary(chiller, 'Central Plant', 'Nominal Capacity', 'W').get
            chiller.setReferenceCapacity(sizing_run_capacity)
            total_cooling_capacity_w += sizing_run_capacity
          else
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name} capacity of #{chiller.name} is not available due to a sizing run failure, total cooling capacity of plant loop will be incorrect when applying standard.")
          end

        elsif chiller.referenceCapacity.is_initialized
          total_cooling_capacity_w += chiller.referenceCapacity.get
        elsif chiller.autosizedReferenceCapacity.is_initialized
          total_cooling_capacity_w += chiller.autosizedReferenceCapacity.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{plant_loop.name} capacity of #{chiller.name} is not available, total cooling capacity of plant loop will be incorrect when applying standard.")
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
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, cooling capacity is #{total_cooling_capacity_tons.round} tons of refrigeration.")

    return total_cooling_capacity_w
  end

  # Splits the single chiller used for the initial sizing run
  # into multiple separate chillers based on Appendix G.
  #
  # @param plant_loop_args [Array] chilled water loop (OpenStudio::Model::PlantLoop), sizing run directory
  # @return [Bool] returns true if successful, false if not
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
    cap_w = plant_loop_total_cooling_capacity(plant_loop, sizing_run_dir)
    cap_tons = OpenStudio.convert(cap_w, 'W', 'ton').get
    if cap_tons <= 300
      num_chillers = 1
      chiller_cooling_type = 'WaterCooled'
      chiller_compressor_type = 'Rotary Screw and Scroll'
    elsif cap_tons > 300 && cap_tons < 600
      num_chillers = 2
      chiller_cooling_type = 'WaterCooled'
      chiller_compressor_type = 'Rotary Screw and Scroll'
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
    return true if chillers.size.zero?

    if chillers.size > 1
      OpenStudio.logFree(OpenStudio::Error, 'prm.log', "For #{plant_loop.name}, found #{chillers.size} chillers, cannot split up per performance rating method baseline requirements.")
    else
      first_chiller = chillers[0]
    end

    # Ensure there is only 1 pump to start
    orig_pump = nil
    if pumps.size.zero?
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

  # apply prm baseline pump power
  # @note I think it makes more sense to sense the motor efficiency right there...
  #   But actually it's completely irrelevant...
  #   you could set at 0.9 and just calculate the pressure rise to have your 19 W/GPM or whatever
  #
  # @param plant_loop [OpenStudio::Model::PlantLoop] plant loop
  # @return [Bool] returns true if successful, false if not
  def plant_loop_apply_prm_baseline_pump_power(plant_loop)
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
        if sc.to_DistrictHeating.is_initialized
          has_district_heating = true
        end
      end

      w_per_gpm = if has_district_heating # District HW
                    HOT_WATER_DISTRICT_PUMP_POWER
                  else # HW
                    HOT_WATER_PUMP_POWER
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
        w_per_gpm = CHILLED_WATER_DISTRICT_PUMP_POWER
      elsif plant_loop.additionalProperties.hasFeature('is_primary_loop') # The primary loop of the primary/secondary CHW
        w_per_gpm = CHILLED_WATER_PRIMARY_PUMP_POWER
      elsif plant_loop.additionalProperties.hasFeature('is_secondary_loop') # The secondary loop of the primary/secondary CHW
        w_per_gpm = CHILLED_WATER_SECONDARY_PUMP_POWER
      else # Primary only CHW combine 9W/gpm + 13W/gpm
        w_per_gpm = CHILLED_WATER_PRIMARY_PUMP_POWER + CHILLED_WATER_SECONDARY_PUMP_POWER
      end

    when 'Condenser'
      # @todo prm condenser loop pump power
      w_per_gpm = CONDENSER_WATER_PUMP_POWER
    end

    # Modify all the primary pumps
    plant_loop.supplyComponents.each do |sc|
      if sc.to_PumpConstantSpeed.is_initialized
        pump = sc.to_PumpConstantSpeed.get
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
      elsif sc.to_ChillerElectricEIR.is_initialized && chiller_counter > 0
        # check if Chiller has a pump, if so, the pump need to adjusted
        chiller = sc.to_ChillerElectricEIR.get
        pump_object = chiller.connectedObject(chiller.supplyInletPort).get
        if pump_object.to_PumpConstantSpeed.is_initialized
          pump = pump_object.to_PumpConstantSpeed.get
          pump_apply_prm_pressure_rise_and_motor_efficiency(pump, w_per_gpm / chiller_counter)
        elsif pump_object.to_PumpVariableSpeed.is_initialized
          pump = pump_object.to_PumpVariableSpeed.get
          pump_apply_prm_pressure_rise_and_motor_efficiency(pump, w_per_gpm / chiller_counter)
        end
      end
    end
    return true
  end
end

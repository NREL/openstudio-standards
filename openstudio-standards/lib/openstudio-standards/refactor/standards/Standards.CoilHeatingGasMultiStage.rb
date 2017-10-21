
# open the class to add methods to return sizing values
class StandardsModel < OpenStudio::Model::Model
  def coil_heating_gas_multi_stage_apply_efficiency_and_curves(coil_heating_gas_multi_stage, standards)
    successfully_set_all_properties = true

    # Get the coil capacity
    capacity_w = nil
    htg_stages = stages
    if htg_stages.last.nominalCapacity.is_initialized
      capacity_w = htg_stages.last.nominalCapacity.get
    elsif autosizedStage4NominalCapacity.is_initialized
      capacity_w = autosizedStage4NominalCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilCoolingDXMultiSpeed', "For #{coil_heating_gas_multi_stage.name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Set number of stages for NECB 2011
    if @@template == 'NECB 2011'
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
    end

    # plf vs plr curve for furnace
    furnace_plffplr_curve = model_add_curve(model, furnace_plffplr_curve_name, standards)
    if furnace_plffplr_curve
      setPartLoadFractionCorrelationCurve(furnace_plffplr_curve)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingGasMultiStage', "For #{coil_heating_gas_multi_stage.name}, cannot find plffplr curve, will not be set.")
      successfully_set_all_properties = false
    end
  end
end

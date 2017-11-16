class ASHRAE9012013 < ASHRAE901
  # @!group PlantLoop

  # Determine the performance rating method specified
  # design condenser water temperature, approach, and range
  #
  # @param plant_loop [OpenStudio::Model::PlantLoop] the condenser water loop
  # @param design_oat_wb_c [Double] the design OA wetbulb temperature (C)
  # @return [Array<Double>] [leaving_cw_t_c, approach_k, range_k]
  def plant_loop_prm_baseline_condenser_water_temperatures(plant_loop, design_oat_wb_c)
    design_oat_wb_f = OpenStudio.convert(design_oat_wb_c, 'C', 'F').get

    # G3.1.3.11 - CW supply temp shall be evaluated at 0.4% evaporative design OATwb
    # per the formulat approach_F = 25.72 - (0.24 * OATwb_F)
    # 55F <= OATwb <= 90F
    # Design range = 10F.
    range_r = 10

    # Limit the OATwb
    if design_oat_wb_f < 55
      design_oat_wb_f = 55
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, a design OATwb of 55F will be used for sizing the cooling towers because the actual design value is below the limit in G3.1.3.11.")
    elsif design_oat_wb_f > 90
      design_oat_wb_f = 90
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.PlantLoop', "For #{plant_loop.name}, a design OATwb of 90F will be used for sizing the cooling towers because the actual design value is above the limit in G3.1.3.11.")
    end

    # Calculate the approach
    approach_r = 25.72 - (0.24 * design_oat_wb_f)

    # Calculate the leaving CW temp
    leaving_cw_t_f = design_oat_wb_f + approach_r

    # Convert to SI units
    leaving_cw_t_c = OpenStudio.convert(leaving_cw_t_f, 'F', 'C').get
    approach_k = OpenStudio.convert(approach_r, 'R', 'K').get
    range_k = OpenStudio.convert(range_r, 'R', 'K').get

    return [leaving_cw_t_c, approach_k, range_k]
  end
end

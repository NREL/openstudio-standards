class Standard
  # @!group Cooling Tower

  # Apply approach temperature sizing criteria to a condenser water loop
  #
  # @param condenser_loop [<OpenStudio::Model::PlantLoop>] a condenser loop served by a cooling tower
  # @param design_wet_bulb_c [Double] the outdoor design wetbulb conditions in degrees C
  def prototype_apply_condenser_water_temperatures(condenser_loop,
                                                   design_wet_bulb_c: nil)
    sizing_plant = condenser_loop.sizingPlant
    loop_type = sizing_plant.loopType
    return false unless loop_type == 'Condenser'

    # if values are absent, use the CTI rating condition 78F
    if design_wet_bulb_c.nil?
      design_wet_bulb_c = OpenStudio.convert(78.0, 'F', 'C').get
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Prototype.hvac_systems', "For condenser loop #{condenser_loop.name}, no design day OATwb conditions given.  CTI rating condition of 78F OATwb will be used for sizing cooling towers.")
    end

    # EnergyPlus has a minimum limit of 68F and maximum limit of 80F for cooling towers
    design_wet_bulb_f = OpenStudio.convert(design_wet_bulb_c, 'C', 'F').get
    eplus_min_design_wet_bulb_f = 68.0
    eplus_max_design_wet_bulb_f = 80.0
    if design_wet_bulb_f < eplus_min_design_wet_bulb_f
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Prototype.CoolingTower', "For condenser loop #{condenser_loop.name}, increased design OATwb from #{design_wet_bulb_f.round(1)} F to EneryPlus model minimum limit of #{eplus_min_design_wet_bulb_f} F.")
      design_wet_bulb_f = eplus_min_design_wet_bulb_f
    elsif design_wet_bulb_f > eplus_max_design_wet_bulb_f
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.Prototype.CoolingTower', "For condenser loop #{condenser_loop.name}, reduced design OATwb from #{design_wet_bulb_f.round(1)} F to EneryPlus model maximum limit of #{eplus_max_design_wet_bulb_f} F.")
      design_wet_bulb_f = eplus_max_design_wet_bulb_f
    end
    design_wet_bulb_c = OpenStudio.convert(design_wet_bulb_f, 'F', 'C').get

    # Determine the design CW temperature, approach, and range
    leaving_cw_t_c, approach_k, range_k = prototype_condenser_water_temperatures(design_wet_bulb_c)

    # Convert to IP units
    leaving_cw_t_f = OpenStudio.convert(leaving_cw_t_c, 'C', 'F').get
    approach_r = OpenStudio.convert(approach_k, 'K', 'R').get
    range_r = OpenStudio.convert(range_k, 'K', 'R').get

    # Report out design conditions
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Prototype.CoolingTower', "For condenser loop #{condenser_loop.name}, design OATwb = #{design_wet_bulb_f.round(1)} F, approach = #{approach_r.round(1)} deltaF, range = #{range_r.round(1)} deltaF, leaving condenser water temperature = #{leaving_cw_t_f.round(1)} F.")

    # Set Cooling Tower sizing parameters.
    # Only the variable speed cooling tower in E+ allows you to set the design temperatures.
    #
    # Per the documentation
    # http://bigladdersoftware.com/epx/docs/8-4/input-output-reference/group-condenser-equipment.html#field-design-u-factor-times-area-value
    # for CoolingTowerSingleSpeed and CoolingTowerTwoSpeed
    # E+ uses the following values during sizing:
    # 95F entering water temp
    # 95F OATdb
    # 78F OATwb
    # range = loop design delta-T aka range (specified above)
    condenser_loop.supplyComponents.each do |sc|
      if sc.to_CoolingTowerVariableSpeed.is_initialized
        ct = sc.to_CoolingTowerVariableSpeed.get
        ct.setDesignInletAirWetBulbTemperature(design_wet_bulb_c)
        ct.setDesignApproachTemperature(approach_k)
        ct.setDesignRangeTemperature(range_k)
      end
    end

    # Set the CW sizing parameters
    # EnergyPlus autosizing routine assumes 85F and 10F temperature difference
    energyplus_design_loop_exit_temperature_c = OpenStudio.convert(85.0, 'F', 'C').get
    sizing_plant.setDesignLoopExitTemperature(energyplus_design_loop_exit_temperature_c)
    sizing_plant.setLoopDesignTemperatureDifference(OpenStudio.convert(10.0, 'R', 'K').get)

    # Cooling Tower operational controls
    # G3.1.3.11 - Tower shall be controlled to maintain a 70F LCnWT where weather permits,
    # floating up to leaving water at design conditions.
    float_down_to_f = 70.0
    float_down_to_c = OpenStudio.convert(float_down_to_f, 'F', 'C').get

    # get or create a setpoint manager
    cw_t_stpt_manager = nil
    condenser_loop.supplyOutletNode.setpointManagers.each do |spm|
      if spm.to_SetpointManagerFollowOutdoorAirTemperature.is_initialized
        if spm.name.get.include? 'Setpoint Manager Follow OATwb'
          cw_t_stpt_manager = spm.to_SetpointManagerFollowOutdoorAirTemperature.get
        end
      end
    end
    if cw_t_stpt_manager.nil?
      cw_t_stpt_manager = OpenStudio::Model::SetpointManagerFollowOutdoorAirTemperature.new(condenser_loop.model)
      cw_t_stpt_manager.addToNode(condenser_loop.supplyOutletNode)
    end

    cw_t_stpt_manager.setName("#{condenser_loop.name} Setpoint Manager Follow OATwb with #{approach_r.round(1)}F Approach")
    cw_t_stpt_manager.setReferenceTemperatureType('OutdoorAirWetBulb')
    # At low design OATwb, it is possible to calculate
    # a maximum temperature below the minimum.  In this case,
    # make the maximum and minimum the same.
    if leaving_cw_t_c < float_down_to_c
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.PlantLoop', "For #{condenser_loop.name}, the maximum leaving temperature of #{leaving_cw_t_f.round(1)} F is below the minimum of #{float_down_to_f.round(1)} F.  The maximum will be set to the same value as the minimum.")
      leaving_cw_t_c = float_down_to_c
    end
    cw_t_stpt_manager.setMaximumSetpointTemperature(leaving_cw_t_c)
    cw_t_stpt_manager.setMinimumSetpointTemperature(float_down_to_c)
    cw_t_stpt_manager.setOffsetTemperatureDifference(approach_k)
  end

  # Determine the performance rating method specified design condenser water temperature, approach, and range
  #
  # @param design_oat_wb_c [Double] the design OA wetbulb temperature (C)
  # @return [Array<Double>] [leaving_cw_t_c, approach_k, range_k]
  def prototype_condenser_water_temperatures(design_oat_wb_c)
    design_oat_wb_f = OpenStudio.convert(design_oat_wb_c, 'C', 'F').get

    # 90.1-2010 G3.1.3.11 - CW supply temp = 85F or 10F approaching design wet bulb temperature, whichever is lower.
    # Design range = 10F
    # Design Temperature rise of 10F => Range: 10F
    range_r = 10.0

    # Determine the leaving CW temp
    max_leaving_cw_t_f = 85.0
    leaving_cw_t_10f_approach_f = design_oat_wb_f + 10.0
    leaving_cw_t_f = [max_leaving_cw_t_f, leaving_cw_t_10f_approach_f].min

    # Calculate the approach
    approach_r = leaving_cw_t_f - design_oat_wb_f

    # Convert to SI units
    leaving_cw_t_c = OpenStudio.convert(leaving_cw_t_f, 'F', 'C').get
    approach_k = OpenStudio.convert(approach_r, 'R', 'K').get
    range_k = OpenStudio.convert(range_r, 'R', 'K').get

    return [leaving_cw_t_c, approach_k, range_k]
  end
end

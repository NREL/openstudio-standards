class BTAPPRE1980
  # Check if ERV is required on this airloop.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  def air_loop_hvac_energy_recovery_ventilator_required?(air_loop_hvac, climate_zone)
    # Do not apply ERV to BTAPPRE1980 buildings.
    erv_required = false
    return erv_required
  end

  # Applies the standard efficiency ratings and typical performance curves to this object from MNECB Supplement 5.4.8.3.
  #
  # @return [Bool] true if successful, false if not
  def chiller_electric_eir_apply_efficiency_and_curves(chiller_electric_eir, clg_tower_objs)
    chillers = standards_data['chillers']

    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = chiller_electric_eir_find_search_criteria(chiller_electric_eir)
    cooling_type = search_criteria['cooling_type']
    condenser_type = search_criteria['condenser_type']
    compressor_type = search_criteria['compressor_type']

    # Get the chiller capacity
    capacity_w = chiller_electric_eir_find_capacity(chiller_electric_eir)

    # All chillers must be modulating down to 25% of their capacity
    chiller_electric_eir.setChillerFlowMode('LeavingSetpointModulated')
    chiller_electric_eir.setMinimumPartLoadRatio(0.25)
    chiller_electric_eir.setMinimumUnloadingRatio(0.25)

    if (capacity_w / 1000.0) <= 700.0
      # As per MNECB if chiller capacity <= 700 kW the compressor should be reciprocating so change the type here in
      # the name, compressor_type and search_criteria which is where the compressor type is used.
      search_criteria['compressor_type'] = "Reciprocating"
      compressor_type = search_criteria['compressor_type']
      chiller_electric_eir = replace_compressor_name(chiller: chiller_electric_eir, comp_type: compressor_type, chillers: chillers)
      if chiller_electric_eir.name.to_s.include? 'Primary Chiller'
        chiller_capacity = capacity_w
      elsif chiller_electric_eir.name.to_s.include? 'Secondary Chiller'
        chiller_capacity = 0.001
      end
    elsif ((capacity_w / 1000.0) > 700.0) && ((capacity_w / 1000.0) <= 2100.0)
      # As per MNECB if chiller capacity > 700 kW the compressor should be centrifugal so change the type here in
      # the name, compressor_type and search_criteria which is where the compressor type is used.
      search_criteria['compressor_type'] = "Centrifugal"
      compressor_type = search_criteria['compressor_type']
      chiller_electric_eir = replace_compressor_name(chiller: chiller_electric_eir, comp_type: compressor_type, chillers: chillers)
      if chiller_electric_eir.name.to_s.include? 'Primary Chiller'
        chiller_capacity = capacity_w
      elsif chiller_electric_eir.name.to_s.include? 'Secondary Chiller'
        chiller_capacity = 0.001
      end
    else
      search_criteria['compressor_type'] = "Centrifugal"
      compressor_type = search_criteria['compressor_type']
      chiller_electric_eir = replace_compressor_name(chiller: chiller_electric_eir, comp_type: compressor_type, chillers: chillers)
      chiller_capacity = capacity_w / 2.0
    end
    chiller_electric_eir.setReferenceCapacity(chiller_capacity)

    # Convert capacity to tons
    capacity_tons = OpenStudio.convert(chiller_capacity, 'W', 'ton').get

    # Get the chiller properties
    chlr_table = @standards_data['chillers']
    chlr_props = model_find_object(chlr_table, search_criteria, capacity_tons, Date.today)
    unless chlr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find chiller properties, cannot apply standard efficiencies or curves.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the CAPFT curve
    cool_cap_ft = model_add_curve(chiller_electric_eir.model, chlr_props['capft'])
    if cool_cap_ft
      chiller_electric_eir.setCoolingCapacityFunctionOfTemperature(cool_cap_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the EIRFT curve
    cool_eir_ft = model_add_curve(chiller_electric_eir.model, chlr_props['eirft'])
    if cool_eir_ft
      chiller_electric_eir.setElectricInputToCoolingOutputRatioFunctionOfTemperature(cool_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the EIRFPLR curve
    # which may be either a CurveBicubic or a CurveQuadratic based on chiller type
    cool_plf_fplr = model_add_curve(chiller_electric_eir.model, chlr_props['eirfplr'])
    if cool_plf_fplr
      chiller_electric_eir.setElectricInputToCoolingOutputRatioFunctionOfPLR(cool_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Set the efficiency value
    kw_per_ton = nil
    cop = nil
    if chlr_props['cop']
      cop = chlr_props['cop']
      kw_per_ton = cop_to_kw_per_ton(cop)
      chiller_electric_eir.setReferenceCOP(cop)
    elsif !chlr_props['cop'] && chlr_props['minimum_full_load_efficiency']
      kw_per_ton = chlr_props['minimum_full_load_efficiency']
      cop = kw_per_ton_to_cop(kw_per_ton)
      chiller_electric_eir.setReferenceCOP(cop)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find minimum full load efficiency, will not be set.")
      successfully_set_all_properties = false
    end

    # Set cooling tower properties now that the new COP of the chiller is set
    if chiller_electric_eir.name.to_s.include? 'Primary Chiller'
      # Single speed tower model assumes 25% extra for compressor power
      tower_cap = capacity_w * (1.0 + 1.0 / chiller_electric_eir.referenceCOP)
      if (tower_cap / 1000.0) < 1750
        clg_tower_objs[0].setNumberofCells(1)
      else
        clg_tower_objs[0].setNumberofCells((tower_cap / (1000 * 1750) + 0.5).round)
      end
      clg_tower_objs[0].setFanPoweratDesignAirFlowRate(0.015 * tower_cap)
    end

    # Append the name with size and kw/ton
    chiller_electric_eir.setName("#{chiller_electric_eir.name} #{capacity_tons.round}tons #{kw_per_ton.round(1)}kW/ton")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.ChillerElectricEIR', "For #{template}: #{chiller_electric_eir.name}: #{cooling_type} #{condenser_type} #{compressor_type} Capacity = #{capacity_tons.round}tons; COP = #{cop.round(1)} (#{kw_per_ton.round(1)}kW/ton)")

    return successfully_set_all_properties
  end

  # Determines the minimum pump motor efficiency and nominal size
  # for a given motor bhp.  This should be the total brake horsepower with
  # any desired safety factor already included.  This method picks
  # the next nominal motor catgory larger than the required brake
  # horsepower, and the efficiency is based on that size.  For example,
  # if the bhp = 6.3, the nominal size will be 7.5HP and the efficiency
  # for 90.1-2010 will be 91.7% from Table 10.8B.  This method assumes
  # 4-pole, 1800rpm totally-enclosed fan-cooled motors.
  #
  # @param motor_bhp [Double] motor brake horsepower (hp)
  # @return [Array<Double>] minimum motor efficiency (0.0 to 1.0), nominal horsepower
  def pump_standard_minimum_motor_efficiency_and_size(pump, motor_bhp)
    motor_eff = 0.85
    nominal_hp = motor_bhp

    # Don't attempt to look up motor efficiency
    # for zero-hp pumps (required for circulation-pump-free
    # service water heating systems).
    return [1.0, 0] if motor_bhp == 0.0

    # Lookup the minimum motor efficiency
    motors = @standards_data['motors']

    # Assuming all pump motors are 4-pole ODP
    search_criteria = {
        'motor_use' => 'PUMP',
        'number_of_poles' => 4.0,
        'type' => 'Enclosed'
    }

    motor_properties = model_find_object(motors, search_criteria, motor_bhp)
    if motor_properties.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Pump', "For #{pump.name}, could not find motor properties using search criteria: #{search_criteria}, motor_bhp = #{motor_bhp} hp.")
      return [motor_eff, nominal_hp]
    end

    motor_eff = motor_properties['nominal_full_load_efficiency']
    nominal_hp = motor_properties['maximum_capacity'].to_f.round(1)
    # Round to nearest whole HP for niceness
    if nominal_hp >= 2
      nominal_hp = nominal_hp.round
    end

    # Get the efficiency based on the nominal horsepower
    # Add 0.01 hp to avoid search errors.
    motor_properties = model_find_object(motors, search_criteria, nominal_hp + 0.01)
    if motor_properties.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Fan', "For #{pump.name}, could not find nominal motor properties using search criteria: #{search_criteria}, motor_hp = #{nominal_hp} hp.")
      return [motor_eff, nominal_hp]
    end
    motor_eff = motor_properties['nominal_full_load_efficiency']

    # Change the pump design shaft power per unit flow rate per unit head to use MNECB combined efficiency values
    apply_pump_impeller_efficiency(pump: pump, motor_eff: motor_eff)
    return [motor_eff, nominal_hp]
  end

  # Replace the chiller compressor type in the chiller name.
  def replace_compressor_name(chiller: ,comp_type:, chillers:)
    # Get the current name.
    chiller_name = chiller.name.to_s
    # Get the unique compressor types from the chiller table (from the chillers.json file.)
    chiller_types = chillers.uniq{|chill_param| chill_param['compressor_type']}
    new_name = chiller_name
    # Go through each chiller compressor type from the chiller table and see if it is in the chiller name.  If it is,
    # then replace the old compressor type in the name with the new one.
    chiller_types.each do |chill_type|
      if chiller_name.include? chill_type['compressor_type']
        new_name = chiller_name.sub(chill_type['compressor_type'], comp_type)
        break
      end
    end
    chiller.setName(new_name)
    return chiller
  end

  # Set the pump design shaft power per unit flow rate per unit head to incorporate total pump efficiency (adjusted for
  # motor efficiency).
  def apply_pump_impeller_efficiency(pump:, motor_eff:)
    # Get the pump efficiency table from the pump_efficiencies.json
    pump_data = @standards_data['pump_combined_eff']
    pump_info = nil
    # Go through the components of the plant loop the plant is attached to.  Find the type of plant loop based on the
    # equipment in it (e.g. it is a hot water loop if the loop contains a boiler supply component).  Once we know the
    # type of plant loop get the combined pump efficiency from pump_data
    pump.plantLoop.get.supplyComponents.each do |comp|
      obj_type = comp.iddObjectType.valueName.to_s
      break if pump_info = pump_data.find { |pump| pump['components'].find {|component| component.include?(obj_type)}}
    end
    return if pump_info.nil?
    # DesignShaftPowerPerUnitFlowRatePerUnitHead seems to be the inverse of an efficiency so get the inverse efficiency
    # by dividing the motor efficiency from the total pump efficiency.
    inv_impeller_eff = motor_eff/pump_info['comb_eff'].to_f
    pump.setDesignShaftPowerPerUnitFlowRatePerUnitHead(inv_impeller_eff)
  end
end

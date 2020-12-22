class Standard
  # @!group ChillerElectricEIR

  # Finds the search criteria
  #
  # @return [hash] has for search criteria to be used for find object
  def chiller_electric_eir_find_search_criteria(chiller_electric_eir)
    search_criteria = {}
    search_criteria['template'] = template

    # Determine if WaterCooled or AirCooled by
    # checking if the chiller is connected to a condenser
    # water loop or not.  Use name as fallback for exporting HVAC library.
    cooling_type = 'AirCooled'
    if chiller_electric_eir.secondaryPlantLoop.is_initialized || chiller_electric_eir.name.get.to_s.include?('WaterCooled')
      cooling_type = 'WaterCooled'
    end

    search_criteria['cooling_type'] = cooling_type

    # TODO: Standards replace this with a mechanism to store this
    # data in the chiller object itself.
    # For now, retrieve the condenser type from the name
    name = chiller_electric_eir.name.get
    condenser_type = nil
    compressor_type = nil
    if cooling_type == 'AirCooled'
      if name.include?('WithCondenser')
        condenser_type = 'WithCondenser'
      elsif name.include?('WithoutCondenser')
        condenser_type = 'WithoutCondenser'
      end
    elsif cooling_type == 'WaterCooled'
      if name.include?('Reciprocating')
        compressor_type = 'Reciprocating'
      elsif name.include?('Rotary Screw')
        compressor_type = 'Rotary Screw'
      elsif name.include?('Scroll')
        compressor_type = 'Scroll'
      elsif name.include?('Centrifugal')
        compressor_type = 'Centrifugal'
      end
    end
    unless condenser_type.nil?
      search_criteria['condenser_type'] = condenser_type
    end
    unless compressor_type.nil?
      search_criteria['compressor_type'] = compressor_type
    end

    return search_criteria
  end

  # Finds capacity in W
  #
  # @return [Double] capacity in W to be used for find object
  def chiller_electric_eir_find_capacity(chiller_electric_eir)
    if chiller_electric_eir.referenceCapacity.is_initialized
      capacity_w = chiller_electric_eir.referenceCapacity.get
    elsif chiller_electric_eir.autosizedReferenceCapacity.is_initialized
      capacity_w = chiller_electric_eir.autosizedReferenceCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name} capacity is not available, cannot apply efficiency standard.")
      return false
    end

    return capacity_w
  end

  # Finds lookup object in standards and return full load efficiency
  #
  # @return [Double] full load efficiency (COP)
  def chiller_electric_eir_standard_minimum_full_load_efficiency(chiller_electric_eir)
    # Get the chiller properties
    search_criteria = chiller_electric_eir_find_search_criteria(chiller_electric_eir)
    capacity_w = chiller_electric_eir_find_capacity(chiller_electric_eir)
    return nil unless capacity_w

    capacity_tons = OpenStudio.convert(capacity_w, 'W', 'ton').get
    chlr_props = model_find_object(standards_data['chillers'], search_criteria, capacity_tons, Date.today)

    if chlr_props.nil? || !chlr_props['minimum_full_load_efficiency']
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find minimum full load efficiency.")
      return nil
    else
      # lookup the efficiency value
      kw_per_ton = chlr_props['minimum_full_load_efficiency']
      cop = kw_per_ton_to_cop(kw_per_ton)
    end

    return cop
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
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

    # Convert capacity to tons
    capacity_tons = OpenStudio.convert(capacity_w, 'W', 'ton').get

    # Get the chiller properties
    chlr_props = model_find_object(chillers, search_criteria, capacity_tons, Date.today)
    unless chlr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find chiller properties using #{search_criteria}, cannot apply standard efficiencies or curves.")
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
    if chlr_props['minimum_full_load_efficiency']
      kw_per_ton = chlr_props['minimum_full_load_efficiency']
      cop = kw_per_ton_to_cop(kw_per_ton)
      chiller_electric_eir.setReferenceCOP(cop)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find minimum full load efficiency, will not be set.")
      successfully_set_all_properties = false
    end

    # Append the name with size and kw/ton
    chiller_electric_eir.setName("#{chiller_electric_eir.name} #{capacity_tons.round}tons #{kw_per_ton.round(1)}kW/ton")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ChillerElectricEIR', "For #{template}: #{chiller_electric_eir.name}: #{cooling_type} #{condenser_type} #{compressor_type} Capacity = #{capacity_tons.round}tons; COP = #{cop.round(1)} (#{kw_per_ton.round(1)}kW/ton)")

    return successfully_set_all_properties
  end
end

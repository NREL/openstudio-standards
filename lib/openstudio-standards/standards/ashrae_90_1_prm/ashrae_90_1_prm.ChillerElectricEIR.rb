class ASHRAE901PRM < Standard
  # @!group ChillerElectricEIR

  # Finds the search criteria
  #
  # @param chiller_electric_eir [OpenStudio::Model::ChillerElectricEIR] chiller object
  # @return [hash] has for search criteria to be used for find object
  def chiller_electric_eir_find_search_criteria(chiller_electric_eir)
    search_criteria = {}
    search_criteria['template'] = template

    # In AppG prm models, all scenarios are WaterCooled for cooling type.
    cooling_type = 'WaterCooled'

    search_criteria['cooling_type'] = cooling_type

    # TODO: Standards replace this with a mechanism to store this
    # data in the chiller object itself.
    # For now, retrieve the condenser type from the name
    name = chiller_electric_eir.name.get
    condenser_type = nil
    compressor_type = nil
    if chiller_electric_eir.additionalProperties.hasFeature('compressor_type')
      compressor_type = chiller_electric_eir.additionalProperties.getFeatureAsString('compressor_type').get
    end
    unless condenser_type.nil?
      search_criteria['condenser_type'] = condenser_type
    end
    unless compressor_type.nil?
      search_criteria['compressor_type'] = compressor_type
    end

    return search_criteria
  end

  # Applies the standard efficiency ratings to this object.
  #
  # @param chiller_electric_eir [OpenStudio::Model::ChillerElectricEIR] chiller object
  # @return [Bool] true if successful, false if not
  def chiller_electric_eir_apply_efficiency_and_curves(chiller_electric_eir)
    # Get the chiller capacity
    capacity_w = chiller_electric_eir_find_capacity(chiller_electric_eir)

    # Convert capacity to tons
    capacity_tons = OpenStudio.convert(capacity_w, 'W', 'ton').get
    
    # Set the efficiency value
    cop = chiller_electric_eir_standard_minimum_full_load_efficiency(chiller_electric_eir)
    kw_per_ton = cop_to_kw_per_ton(cop)
    if cop.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{chiller_electric_eir.name}, cannot find minimum full load efficiency, will not be set.")
      successfully_set_all_properties = false
    else
      chiller_electric_eir.setReferenceCOP(cop)
      successfully_set_all_properties = true
    end

    # Append the name with size and kw/ton
    chiller_electric_eir.setName("#{chiller_electric_eir.name} #{capacity_tons.round}tons #{kw_per_ton.round(1)}kW/ton")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ChillerElectricEIR', "For #{template}: #{chiller_electric_eir.name}: Capacity = #{capacity_tons.round}tons; COP = #{cop.round(1)} (#{kw_per_ton.round(1)}kW/ton)")

    return successfully_set_all_properties
  end
end

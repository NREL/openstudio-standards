
# Reopen the OpenStudio class to add methods to apply standards to this object
class StandardsModel < OpenStudio::Model::Model
  # Finds the search criteria
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [hash] has for search criteria to be used for find object
  def chiller_electric_eir_find_search_criteria(chiller_electric_eir, template)
    search_criteria = {}
    search_criteria['template'] = template

    # Determine if WaterCooled or AirCooled by
    # checking if the chiller is connected to a condenser
    # water loop or not.
    cooling_type = 'AirCooled'
    if secondaryPlantLoop.is_initialized
      cooling_type = 'WaterCooled'
    end

    search_criteria['cooling_type'] = cooling_type

    # TODO: Standards replace this with a mechanism to store this
    # data in the chiller object itself.
    # For now, retrieve the condenser type from the name
    name = self.name.get
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
    capacity_w = nil
    if referenceCapacity.is_initialized
      capacity_w = referenceCapacity.get
    elsif autosizedReferenceCapacity.is_initialized
      capacity_w = autosizedReferenceCapacity.get
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{name} capacity is not available, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    return capacity_w
  end

  # Finds lookup object in standards and return full load efficiency
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Double] full load efficiency (COP)
  def chiller_electric_eir_standard_minimum_full_load_efficiency(chiller_electric_eir, template)
    # Get the chiller properties
    search_criteria = coil_dx_find_search_criteria(coil_dx, template)
    capacity_tons = OpenStudio.convert(find_capacity, 'W', 'ton').get 
    chlr_props = model_find_object(model, $os_standards['chillers'], search_criteria, capacity_tons, Date.today)

    # lookup the efficiency value
    kw_per_ton = nil
    cop = nil
    if chlr_props['minimum_full_load_efficiency']
      kw_per_ton = chlr_props['minimum_full_load_efficiency']
      cop = kw_per_ton_to_cop(kw_per_ton)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{name}, cannot find minimum full load efficiency.")
    end

    return cop
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format
  # @return [Bool] true if successful, false if not
  def chiller_electric_eir_apply_efficiency_and_curves(chiller_electric_eir, template, clg_tower_objs)
    chillers = $os_standards['chillers']

    # Define the criteria to find the chiller properties
    # in the hvac standards data set.
    search_criteria = coil_dx_find_search_criteria(coil_dx, template)
    cooling_type = search_criteria['cooling_type']
    condenser_type = search_criteria['condenser_type']
    compressor_type = search_criteria['compressor_type']

    # Get the chiller capacity
    capacity_w = water_heater_mixed_find_capacity(water_heater_mixed) 

    # NECB 2011 requires that all chillers be modulating down to 25% of their capacity
    if template == 'NECB 2011'
      setChillerFlowMode('LeavingSetpointModulated')
      setMinimumPartLoadRatio(0.25)
      setMinimumUnloadingRatio(0.25)
      if (capacity_w / 1000.0) < 2100.0
        if self.name.to_s.include? 'Primary Chiller'
          chiller_capacity = capacity_w
        elsif self.name.to_s.include? 'Secondary Chiller'
          chiller_capacity = 0.001
        end
      else
        chiller_capacity = capacity_w / 2.0
      end
      setReferenceCapacity(chiller_capacity)
    end # NECB 2011

    # Convert capacity to tons
    capacity_tons = if template == 'NECB 2011'
                      OpenStudio.convert(chiller_capacity, 'W', 'ton').get
                    else
                      OpenStudio.convert(capacity_w, 'W', 'ton').get
                    end

    # Get the chiller properties
    chlr_props = model_find_object(model, chillers, search_criteria, capacity_tons, Date.today)
    unless chlr_props
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{self.name}, cannot find chiller properties, cannot apply standard efficiencies or curves.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Make the CAPFT curve
    cool_cap_ft = model_add_curve(model, chlr_props['capft'])
    if cool_cap_ft
      setCoolingCapacityFunctionOfTemperature(cool_cap_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{self.name}, cannot find cool_cap_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the EIRFT curve
    cool_eir_ft = model_add_curve(model, chlr_props['eirft'])
    if cool_eir_ft
      setElectricInputToCoolingOutputRatioFunctionOfTemperature(cool_eir_ft)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{self.name}, cannot find cool_eir_ft curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Make the EIRFPLR curve
    # which may be either a CurveBicubic or a CurveQuadratic based on chiller type
    cool_plf_fplr = model_add_curve(model, chlr_props['eirfplr'])
    if cool_plf_fplr
      setElectricInputToCoolingOutputRatioFunctionOfPLR(cool_plf_fplr)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{self.name}, cannot find cool_plf_fplr curve, will not be set.")
      successfully_set_all_properties = false
    end

    # Set the efficiency value
    kw_per_ton = nil
    cop = nil
    if chlr_props['minimum_full_load_efficiency']
      kw_per_ton = chlr_props['minimum_full_load_efficiency']
      cop = kw_per_ton_to_cop(kw_per_ton)
      setReferenceCOP(cop)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ChillerElectricEIR', "For #{self.name}, cannot find minimum full load efficiency, will not be set.")
      successfully_set_all_properties = false
    end

    # Set cooling tower properties for NECB 2011 now that the new COP of the chiller is set
    if template == 'NECB 2011'
      if self.name.to_s.include? 'Primary Chiller'
        # Single speed tower model assumes 25% extra for compressor power
        tower_cap = capacity_w * (1.0 + 1.0 / referenceCOP)
        if (tower_cap / 1000.0) < 1750
          clg_tower_objs[0].setNumberofCells(1)
        else
          clg_tower_objs[0].setNumberofCells((tower_cap / (1000 * 1750) + 0.5).round)
        end
        clg_tower_objs[0].setFanPoweratDesignAirFlowRate(0.015 * tower_cap)
      end
    end

    # Append the name with size and kw/ton
    setName("#{name} #{capacity_tons.round}tons #{kw_per_ton.round(1)}kW/ton")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.ChillerElectricEIR', "For #{template}: #{self.name}: #{cooling_type} #{condenser_type} #{compressor_type} Capacity = #{capacity_tons.round}tons; COP = #{cop.round(1)} (#{kw_per_ton.round(1)}kW/ton)")

    return successfully_set_all_properties
  end
end

class Standard
  # @!group CoilHeatingWaterToAirHeatPumpEquationFit

  # Finds capacity in W.
  # This is the cooling capacity of the paired cooling coil.
  #
  # @return [Double] capacity in W to be used for find object
  def coil_heating_water_to_air_heat_pump_find_capacity(coil_heating_water_to_air_heat_pump)
    capacity_w = nil

    # Get the paired cooling coil
    clg_coil = nil

    # Unitary and zone equipment
    if coil_heating_water_to_air_heat_pump.airLoopHVAC.empty?
      if coil_heating_water_to_air_heat_pump.containingHVACComponent.is_initialized
        containing_comp = coil_heating_water_to_air_heat_pump.containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          clg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.get.coolingCoil
        elsif containing_comp.to_AirLoopHVACUnitarySystem.is_initialized
          unitary = containing_comp.to_AirLoopHVACUnitarySystem.get
          if unitary.coolingCoil.is_initialized
            clg_coil = unitary.coolingCoil.get
          end
        end
      elsif coil_heating_water_to_air_heat_pump.containingZoneHVACComponent.is_initialized
        containing_comp = coil_heating_water_to_air_heat_pump.containingZoneHVACComponent.get
        # PTHP
        if containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          clg_coil = containing_comp.to_ZoneHVACPackagedTerminalHeatPump.get.coolingCoil
        # WSHP
        elsif containing_comp.to_ZoneHVACWaterToAirHeatPump.is_initialized
          clg_coil = containing_comp.to_ZoneHVACWaterToAirHeatPump.get.coolingCoil
        end
      end
    end

    # On AirLoop directly
    if coil_heating_water_to_air_heat_pump.airLoopHVAC.is_initialized
      air_loop = coil_heating_water_to_air_heat_pump.airLoopHVAC.get
      # Check for the presence of any other type of cooling coil
      clg_types = ['OS:Coil:Cooling:DX:SingleSpeed',
                   'OS:Coil:Cooling:DX:TwoSpeed',
                   'OS:Coil:Cooling:DX:MultiSpeed']
      clg_types.each do |ct|
        coils = air_loop.supplyComponents(ct.to_IddObjectType)
        next if coils.empty?

        clg_coil = coils[0]
        break # Stop on first cooling coil found
      end
    end

    # If no paired cooling coil was found,
    # throw an error and fall back to the heating capacity of the heating coil
    if clg_coil.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpEquationFit', "For #{coil_heating_water_to_air_heat_pump.name}, the paired cooling coil could not be found to determine capacity. Efficiency will incorrectly be based on coil's heating capacity.")
      if coil_heating_water_to_air_heat_pump.ratedTotalHeatingCapacity.is_initialized
        capacity_w = coil_heating_water_to_air_heat_pump.ratedTotalHeatingCapacity.get
      elsif coil_heating_water_to_air_heat_pump.autosizedRatedTotalHeatingCapacity.is_initialized
        capacity_w = coil_heating_water_to_air_heat_pump.autosizedRatedTotalHeatingCapacity.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpEquationFit', "For #{coil_heating_water_to_air_heat_pump.name} capacity is not available, cannot apply efficiency standard to paired heating coil.")
        return 0.0
      end
      return capacity_w
    end

    # If a coil was found, cast to the correct type
    if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
      clg_coil = clg_coil.to_CoilCoolingDXSingleSpeed.get
      capacity_w = coil_cooling_dx_single_speed_find_capacity(clg_coil)
    elsif clg_coil.to_CoilCoolingDXTwoSpeed.is_initialized
      clg_coil = clg_coil.to_CoilCoolingDXTwoSpeed.get
      capacity_w = coil_cooling_dx_two_speed_find_capacity(clg_coil)
    elsif clg_coil.to_CoilCoolingDXMultiSpeed.is_initialized
      clg_coil = clg_coil.to_CoilCoolingDXMultiSpeed.get
      capacity_w = coil_cooling_dx_multi_speed_find_capacity(clg_coil)
    elsif clg_coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized
      clg_coil = clg_coil.to_CoilCoolingWaterToAirHeatPumpEquationFit.get
      capacity_w = coil_cooling_water_to_air_heat_pump_find_capacity(clg_coil)
    end

    return capacity_w
  end

  # Finds lookup object in standards and return efficiency
  #
  # @param rename [Bool] if true, object will be renamed to include capacity and efficiency level
  # @return [Double] full load efficiency (COP)
  def coil_heating_water_to_air_heat_pump_standard_minimum_cop(coil_heating_water_to_air_heat_pump, rename = false)
    search_criteria = {}
    search_criteria['template'] = template
    capacity_w = coil_heating_water_to_air_heat_pump_find_capacity(coil_heating_water_to_air_heat_pump)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get
    capacity_kbtu_per_hr = OpenStudio.convert(capacity_w, 'W', 'kBtu/hr').get

    # Look up the efficiency characteristics
    coil_props = model_find_object(standards_data['water_source_heat_pumps_heating'], search_criteria, capacity_btu_per_hr, Date.today)

    # Check to make sure properties were found
    if coil_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpEquationFit', "For #{coil_heating_water_to_air_heat_pump.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return successfully_set_all_properties
    end

    # Get the minimum efficiency standards
    cop = nil

    # If specified as EER
    unless coil_props['minimum_coefficient_of_performance_heating'].nil?
      cop = coil_props['minimum_coefficient_of_performance_heating']
      new_comp_name = "#{coil_heating_water_to_air_heat_pump.name} #{capacity_kbtu_per_hr.round} Clg kBtu/hr #{cop.round(1)}COPH"
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpEquationFit', "For #{template}: #{coil_heating_water_to_air_heat_pump.name}: Cooling Capacity = #{capacity_kbtu_per_hr.round}kBtu/hr; COPH = #{cop}")
    end

    # Rename
    if rename
      coil_heating_water_to_air_heat_pump.setName(new_comp_name)
    end

    return cop
  end

  # Applies the standard efficiency ratings and typical performance curves to this object.
  #
  # @return [Bool] true if successful, false if not
  def coil_heating_water_to_air_heat_pump_apply_efficiency_and_curves(coil_heating_water_to_air_heat_pump, sql_db_vars_map)
    successfully_set_all_properties = true

    # Get the search criteria
    search_criteria = {}
    search_criteria['template'] = template
    capacity_w = coil_heating_water_to_air_heat_pump_find_capacity(coil_heating_water_to_air_heat_pump)
    capacity_btu_per_hr = OpenStudio.convert(capacity_w, 'W', 'Btu/hr').get

    # Look up the efficiency characteristics
    coil_props = model_find_object(standards_data['water_source_heat_pumps_heating'], search_criteria, capacity_btu_per_hr, Date.today)

    # Check to make sure properties were found
    if coil_props.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpEquationFit', "For #{coil_heating_water_to_air_heat_pump.name}, cannot find efficiency info using #{search_criteria}, cannot apply efficiency standard.")
      successfully_set_all_properties = false
      return sql_db_vars_map
    end

    # TODO: Add methods to set coefficients, and add coefficients to data spreadsheet
    # using OS defaults for now
    # heat_cap_coeff1 = coil_props['heat_cap_coeff1']
    # if heat_cap_coeff1
    #   coil_heating_water_to_air_heat_pump.setHeatingCapacityCoefficient1(heat_cap_coeff1)
    # else
    #   OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.CoilHeatingWaterToAirHeatPumpEquationFit', "For #{coil_heating_water_to_air_heat_pump.name}, cannot find heat_cap_coeff1, will not be set.")
    #   successfully_set_all_properties = false
    # end

    # Preserve the original name
    orig_name = coil_heating_water_to_air_heat_pump.name.to_s

    # Find the minimum COP and rename with efficiency rating
    cop = coil_heating_water_to_air_heat_pump_standard_minimum_cop(coil_heating_water_to_air_heat_pump, true)

    # Map the original name to the new name
    sql_db_vars_map[coil_heating_water_to_air_heat_pump.name.to_s] = orig_name

    # Set the efficiency values
    unless cop.nil?
      coil_heating_water_to_air_heat_pump.setRatedHeatingCoefficientofPerformance(cop)
    end

    return sql_db_vars_map
  end
end

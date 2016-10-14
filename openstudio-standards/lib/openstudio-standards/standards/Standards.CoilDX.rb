
# A variety of DX coil methods that are the same regardless of coil type.
# These methods are available to:
# CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
module CoilDX
  # Finds the subcategory.  Possible choices are:
  # Single Package, Split System, PTAC, or PTHP
  #
  # @return [String] the subcategory
  # @todo Add add split system vs single package to model object
  def subcategory
    sub_category = 'Single Package'

    if airLoopHVAC.empty?
      if containingZoneHVACComponent.is_initialized
        containing_comp = containingZoneHVACComponent.get
        # PTAC
        if containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          sub_category = 'PTAC'
        # PTHP
        elsif containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          sub_category = 'PTHP'
        end # TODO: Add other zone hvac systems
      end
    end

    return sub_category
  end

  # Determine if it is a heat pump
  # @return [Bool] true if it is a heat pump, false if not
  def heat_pump?
    heat_pump = false

    heating_type = nil
    if airLoopHVAC.empty?
      if containingHVACComponent.is_initialized
        containing_comp = containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          heat_pump = true
        end # TODO: Add other unitary systems
      elsif containingZoneHVACComponent.is_initialized
        containing_comp = containingZoneHVACComponent.get
        # PTHP
        if containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          heat_pump = true
        end # TODO: Add other zone hvac systems
      end
    end

    return heat_pump
  end

  # Determine the heating type.  Possible choices are:
  # Electric Resistance or None, All Other
  # @return [String] the heating type
  def heating_type
    htg_type = nil

    # If Unitary or Zone HVAC
    if airLoopHVAC.empty?
      if containingHVACComponent.is_initialized
        containing_comp = containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          htg_type = 'Electric Resistance or None'
        end # TODO: Add other unitary systems
      elsif containingZoneHVACComponent.is_initialized
        containing_comp = containingZoneHVACComponent.get
        # PTAC
        if containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          htg_coil = containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.get.heatingCoil
          if htg_coil.to_CoilHeatingElectric.is_initialized
            htg_type = 'Electric Resistance or None'
          elsif htg_coil.to_CoilHeatingWater.is_initialized || htg_coil.to_CoilHeatingGas.is_initialized
            htg_type = 'All Other'
          end
        # PTHP
        elsif containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          htg_type = 'Electric Resistance or None'
        end # TODO: Add other zone hvac systems

      end
    end

    # If on an AirLoop
    if airLoopHVAC.is_initialized
      air_loop = airLoopHVAC.get
      htg_type = if !air_loop.supplyComponents('OS:Coil:Heating:Electric'.to_IddObjectType).empty?
                       'Electric Resistance or None'
                     elsif !air_loop.supplyComponents('OS:Coil:Heating:Gas'.to_IddObjectType).empty?
                       'All Other'
                     elsif !air_loop.supplyComponents('OS:Coil:Heating:Water'.to_IddObjectType).empty?
                       'All Other'
                     elsif !air_loop.supplyComponents('OS:Coil:Heating:DX:SingleSpeed'.to_IddObjectType).empty?
                       'All Other'
                     elsif !air_loop.supplyComponents('OS:Coil:Heating:Gas:MultiStage'.to_IddObjectType).empty?
                       'All Other'
                     elsif !air_loop.supplyComponents('OS:Coil:Heating:Desuperheater'.to_IddObjectType).empty?
                       'All Other'
                     elsif !air_loop.supplyComponents('OS:Coil:Heating:WaterToAirHeatPump:EquationFit'.to_IddObjectType).empty?
                       'All Other'
                     else
                       'Electric Resistance or None'
                     end
    end
    
    return htg_type
  end

  # Finds the search criteria
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [hash] has for search criteria to be used for find object
  def find_search_criteria(template)
    search_criteria = {}
    search_criteria['template'] = template

    search_criteria['cooling_type'] = case iddObjectType.valueName.to_s
                                      when 'OS_Coil_Cooling_DX_SingleSpeed',
                                           'OS_Coil_Cooling_DX_TwoSpeed',
                                           'OS_Coil_Cooling_DX_MultiSpeed'
                                        condenserType
                                      else
                                        'AirCooled'
                                      end

    # Get the subcategory
    search_criteria['subcategory'] = subcategory

    # Add the heating type to the search criteria
    unless heating_type.nil?
      search_criteria['heating_type'] = heating_type
    end

    # Unitary heat pumps don't have a heating type
    # as part of the search
    if heat_pump?
      if airLoopHVAC.empty?
        if containingHVACComponent.is_initialized
          containing_comp = containingHVACComponent.get
          if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
            search_criteria['heating_type'] = nil
          end # TODO: Add other unitary systems
        end
      end
    end

    return search_criteria
  end
end

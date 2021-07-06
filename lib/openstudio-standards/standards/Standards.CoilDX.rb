# A variety of DX coil methods that are the same regardless of coil type.
# These methods are available to:
# CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
module CoilDX
  # @!group CoilDX

  # Finds the subcategory.  Possible choices are:
  # Single Package, Split System, PTAC, or PTHP
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @return [String] the coil_dx_subcategory(coil_dx)
  # @todo Add add split system vs single package to model object
  def coil_dx_subcategory(coil_dx)
    sub_category = 'Single Package'

    # Fallback to the name, mainly for library export
    if coil_dx.name.get.to_s.include?('Single Package')
      sub_category = 'Single Package'
    elsif coil_dx.name.get.to_s.include?('Split System')
      sub_category = 'Split System'
    elsif coil_dx.name.get.to_s.include?('Central Air Source HP')
      sub_category = 'Split System'
    elsif coil_dx.name.get.to_s.include?('Minisplit HP')
      sub_category = 'Minisplit System'
    elsif coil_dx.name.get.to_s.include?('CRAC')
      sub_category = 'CRAC'
    end

    if coil_dx.airLoopHVAC.empty?
      if coil_dx.containingZoneHVACComponent.is_initialized
        containing_comp = coil_dx.containingZoneHVACComponent.get
        # PTAC
        if containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
          sub_category = 'PTAC'
        # PTHP
        elsif containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          sub_category = 'PTHP'
        end
        # @todo Add other zone hvac systems
      end
    end

    return sub_category
  end

  # Determine if it is a heat pump
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @return [Bool] returns true if it is a heat pump, false if not
  def coil_dx_heat_pump?(coil_dx)
    heat_pump = false

    if coil_dx.airLoopHVAC.empty?
      if coil_dx.containingHVACComponent.is_initialized
        containing_comp = coil_dx.containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          heat_pump = true
        elsif containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized
          htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get.heatingCoil
          if htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized then heat_pump = true end
        end
      elsif coil_dx.containingZoneHVACComponent.is_initialized
        containing_comp = coil_dx.containingZoneHVACComponent.get
        # PTHP
        if containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized
          heat_pump = true
        end
        # @todo Add other zone hvac systems
      end
    else
      if !coil_dx.airLoopHVAC.get.supplyComponents('OS:Coil:Heating:DX:SingleSpeed'.to_IddObjectType).empty? ||
         !coil_dx.airLoopHVAC.get.supplyComponents('OS:Coil:Heating:DX:VariableSpeed'.to_IddObjectType).empty?
        heat_pump = true
      end
    end

    return heat_pump
  end

  # Determine the heating type.
  # Possible choices are: Electric Resistance or None, All Other
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @return [String] the heating type
  def coil_dx_heating_type(coil_dx)
    htg_type = nil

    # If Unitary or Zone HVAC
    if coil_dx.airLoopHVAC.empty?
      if coil_dx.containingHVACComponent.is_initialized
        containing_comp = coil_dx.containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          htg_type = 'Electric Resistance or None'
        elsif containing_comp.to_AirLoopHVACUnitarySystem.is_initialized
          if containing_comp.name.to_s.include? 'Minisplit'
            htg_type = 'All Other'
          end
        elsif containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized
          htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get.heatingCoil
          supp_htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get.supplementalHeatingCoil
          if htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized || supp_htg_coil.to_CoilHeatingElectric.is_initialized
            htg_type = 'Electric Resistance or None'
          elsif htg_coil.to_CoilHeatingGasMultiStage.is_initialized
            htg_type = 'All Other'
          end
        end
        # @todo Add other unitary systems
      elsif coil_dx.containingZoneHVACComponent.is_initialized
        containing_comp = coil_dx.containingZoneHVACComponent.get
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
        end
        # @todo Add other zone hvac systems
      end
    end

    # If on an AirLoop
    if coil_dx.airLoopHVAC.is_initialized
      air_loop = coil_dx.airLoopHVAC.get
      htg_type = if !air_loop.supplyComponents('OS:Coil:Heating:Gas'.to_IddObjectType).empty?
                   'All Other'
                 elsif !air_loop.supplyComponents('OS:Coil:Heating:Water'.to_IddObjectType).empty?
                   'All Other'
                 elsif !air_loop.supplyComponents('OS:Coil:Heating:DX:SingleSpeed'.to_IddObjectType).empty?
                   'All Other'
                 elsif !air_loop.supplyComponents('OS:Coil:Heating:DX:MultiSpeed'.to_IddObjectType).empty?
                   'All Other'
                 elsif !air_loop.supplyComponents('OS:Coil:Heating:DX:VariableSpeed'.to_IddObjectType).empty?
                   'All Other'
                 elsif !air_loop.supplyComponents('OS:Coil:Heating:Gas:MultiStage'.to_IddObjectType).empty?
                   'All Other'
                 elsif !air_loop.supplyComponents('OS:Coil:Heating:Desuperheater'.to_IddObjectType).empty?
                   'All Other'
                 elsif !air_loop.supplyComponents('OS:Coil:Heating:WaterToAirHeatPump:EquationFit'.to_IddObjectType).empty?
                   'All Other'
                 elsif !air_loop.supplyComponents('OS:Coil:Heating:Electric'.to_IddObjectType).empty?
                   'Electric Resistance or None'
                 else
                   'Electric Resistance or None'
                 end
    end

    return htg_type
  end

  # Finds the search criteria
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @return [hash] has for search criteria to be used for find object
  def coil_dx_find_search_criteria(coil_dx)
    search_criteria = {}
    search_criteria['template'] = template

    search_criteria['cooling_type'] = case coil_dx.iddObjectType.valueName.to_s
                                      when 'OS_Coil_Cooling_DX_SingleSpeed',
                                           'OS_Coil_Cooling_DX_TwoSpeed',
                                           'OS_Coil_Cooling_DX_VariableSpeed',
                                           'OS_Coil_Cooling_DX_MultiSpeed',
                                           'OS_AirConditioner_VariableRefrigerantFlow'
                                        coil_dx.condenserType
                                      else
                                        'AirCooled'
                                      end

    # Get the coil_dx_subcategory(coil_dx)
    search_criteria['subcategory'] = coil_dx_subcategory(coil_dx)

    # Add the heating type to the search criteria
    htg_type = coil_dx_heating_type(coil_dx)
    unless htg_type.nil?
      search_criteria['heating_type'] = htg_type
    end

    # The heating side of unitary heat pumps don't have a heating type
    # as part of the search
    if coil_dx.to_CoilHeatingDXSingleSpeed.is_initialized
      if coil_dx_heat_pump?(coil_dx)
        if coil_dx.airLoopHVAC.empty?
          if coil_dx.containingHVACComponent.is_initialized
            containing_comp = coil_dx.containingHVACComponent.get
            if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
              search_criteria['heating_type'] = nil
            end
            # @todo Add other unitary systems
          end
        end
      end
    end

    return search_criteria
  end
end

# A variety of DX coil methods that are the same regardless of coil type.
# These methods are available to:
# CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
module CoilDX
  # @!group CoilDX

  # Determine the heating type.
  # Possible choices are: Electric Resistance or None, All Other
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param necb_ref_hp [Boolean] for compatability with NECB ruleset only.
  # @return [String] the heating type
  def coil_dx_heating_type(coil_dx, necb_ref_hp = false)
    htg_type = nil

    # If Unitary or Zone HVAC
    if coil_dx.airLoopHVAC.empty?
      if coil_dx.containingHVACComponent.is_initialized
        containing_comp = coil_dx.containingHVACComponent.get
        if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
          htg_type = 'Electric Resistance or None'
        elsif containing_comp.to_AirLoopHVACUnitarySystem.is_initialized
          htg_coil = containing_comp.to_AirLoopHVACUnitarySystem.get.heatingCoil
          if containing_comp.name.to_s.include? 'Minisplit'
            htg_type = 'All Other'
          elsif htg_coil.is_initialized
            htg_coil = htg_coil.get
            if htg_coil.to_CoilHeatingElectric.is_initialized || htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized
              htg_type = 'Electric Resistance or None'
            elsif htg_coil.to_CoilHeatingGas.is_initialized || htg_coil.to_CoilHeatingGasMultiStage.is_initialized
              htg_type = 'All Other'
            end
          else
            htg_type = 'Electric Resistance or None'
          end
        elsif containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized
          htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get.heatingCoil
          supp_htg_coil = containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.get.supplementalHeatingCoil
          if htg_coil.to_CoilHeatingDXMultiSpeed.is_initialized || supp_htg_coil.to_CoilHeatingElectric.is_initialized
            htg_type = 'Electric Resistance or None'
          elsif htg_coil.to_CoilHeatingGasMultiStage.is_initialized || htg_coil.to_CoilHeatingGas.is_initialized
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
  # @param necb_ref_hp [Boolean] for compatability with NECB ruleset only.
  # @param equipment_type [Boolean] indicate that equipment_type should be in the search criteria.
  # @return [Hash] has for search criteria to be used for find object
  def coil_dx_find_search_criteria(coil_dx, necb_ref_hp = false, equipment_type = false)
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

    # Get the coil subcategory
    search_criteria['subcategory'] = OpenstudioStandards::HVAC.coil_dx_subcategory(coil_dx)

    # Add the heating type to the search criteria
    htg_type = coil_dx_heating_type(coil_dx)
    unless htg_type.nil?
      search_criteria['heating_type'] = htg_type
    end

    # The heating side of unitary heat pumps don't have a heating type as part of the search
    if coil_dx.to_CoilHeatingDXSingleSpeed.is_initialized &&
      OpenstudioStandards::HVAC.coil_dx_heat_pump?(coil_dx) &&
       coil_dx.airLoopHVAC.empty? && coil_dx.containingHVACComponent.is_initialized
      containing_comp = coil_dx.containingHVACComponent.get
      if containing_comp.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
        search_criteria['heating_type'] = nil
      end
      # @todo Add other unitary systems
    end

    # Get the equipment type
    if equipment_type && coil_dx.airLoopHVAC.empty? && coil_dx.containingZoneHVACComponent.is_initialized
      containing_comp = coil_dx.containingZoneHVACComponent.get
      # PTAC
      if containing_comp.to_ZoneHVACPackagedTerminalAirConditioner.is_initialized
        search_criteria['equipment_type'] = 'PTAC'
        search_criteria['subcategory'] = nil
        unless (template == 'NECB2011') || (template == 'NECB2015') || (template == 'NECB2017') || (template == 'NECB2020') || (template == 'BTAPPRE1980') ||
               (template == 'BTAP1980TO2010')
          search_criteria['heating_type'] = nil
        end
      end
    end

    return search_criteria
  end

  # Determine what application to use for looking up the minimum efficiency requirements of PTACs
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @return [String] PTAC application
  def coil_dx_ptac_application(coil_dx)
    case template
    when '90.1-2004', '90.1-2007'
      return 'New Construction'
    when '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
      return 'Standard Size'
    end
  end

  # Determine what capacity curve to use to represent the change of the coil's capacity as a function of changes in temperatures
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @return [String] PTAC application
  def coil_dx_cap_ft(coil_dx, equipment_type = 'Air Conditioners')
    case equipment_type
    when 'PTAC'
      return 'PSZ-Fine Storage DX Coil Cap-FT'
    else
      return 'CoilClgDXQRatio_fTwbToadbSI'
    end
  end

  # Determine what capacity curve to use to represent the change of the coil's capacity as a function of changes in airflow fraction
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @return [String] PTAC application
  def coil_dx_cap_fff(coil_dx, equipment_type = 'Air Conditioners')
    case equipment_type
    when 'PTAC'
      return 'DX Coil Cap-FF'
    else
      return 'CoilClgDXSnglQRatio_fCFMRatio'
    end
  end

  # Determine what EIR curve to use to represent the change of the coil's EIR as a function of changes in temperatures
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @return [String] PTAC application
  def coil_dx_eir_ft(coil_dx, equipment_type = 'Air Conditioners')
    case equipment_type
    when 'PTAC'
      return 'PSZ-AC DX Coil EIR-FT'
    else
      return 'CoilClgDXEIRRatio_fTwbToadbSI'
    end
  end

  # Determine what EIR curve to use to represent the change of the coil's EIR as a function of changes in airflow fraction
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @return [String] PTAC application
  def coil_dx_eir_fff(coil_dx, equipment_type = 'Air Conditioners')
    case equipment_type
    when 'PTAC'
      return 'Split DX Coil EIR-FF'
    else
      return 'CoilClgDXSnglEIRRatio_fCFMRatio'
    end
  end

  # Determine what PLF curve to use to represent the change of the coil's PLR as a function of changes in PLR
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @return [String] PTAC application
  def coil_dx_plf_fplr(coil_dx, equipment_type = 'Air Conditioners')
    case equipment_type
    when 'PTAC'
      return 'HPACCOOLPLFFPLR'
    else
      return 'CoilClgDXEIRRatio_fQFrac'
    end
  end
end

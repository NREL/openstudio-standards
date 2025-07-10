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
    elsif coil_dx.name.get.to_s.include?('Split System') ||
          coil_dx.name.get.to_s.include?('Central Air Source HP')
      sub_category = 'Split System'
    elsif coil_dx.name.get.to_s.include?('Minisplit HP')
      sub_category = 'Minisplit System'
    elsif coil_dx.name.get.to_s.include?('CRAC')
      sub_category = 'CRAC'
    end

    return sub_category
  end

  # Determine if it is a heat pump
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object
  # @return [Boolean] returns true if it is a heat pump, false if not
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

    # Cooling type
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

    # Subcategory
    search_criteria['subcategory'] = coil_dx_subcategory(coil_dx)

    # Add the heating type to the search criteria
    case coil_dx.iddObjectType.valueName.to_s
    when 'OS_Coil_Cooling_DX_SingleSpeed',
         'OS_Coil_Cooling_DX_TwoSpeed',
         'OS_Coil_Cooling_DX_VariableSpeed',
         'OS_Coil_Cooling_DX_MultiSpeed',
         'OS_AirConditioner_VariableRefrigerantFlow'
      htg_type = coil_dx_heating_type(coil_dx, necb_ref_hp)
      unless htg_type.nil?
        search_criteria['heating_type'] = htg_type
      end
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
      # PTHP
      if containing_comp.to_ZoneHVACPackagedTerminalHeatPump.is_initialized && !((template == 'NECB2011') || (template == 'NECB2015') || (template == 'NECB2017') || (template == 'NECB2020') || (template == 'BTAPPRE1980') ||
               (template == 'BTAP1980TO2010'))
        search_criteria['subcategory'] = nil
        search_criteria['heating_type'] = nil
        search_criteria['equipment_type'] = 'PTHP'
      end
    end

    return search_criteria
  end

  # Determine what application to use for looking up the minimum efficiency requirements of PTACs
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @return [String] PTAC application
  def coil_dx_packaged_terminal_application(coil_dx)
    case template
    when '90.1-2004', '90.1-2007'
      return 'New Construction'
    when '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
      return 'Standard Size'
    end
  end

  # Determine what electric power phase value should be used for efficiency lookups for DX coils
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @return [String] Electric power phase
  def coil_dx_electric_power_phase(coil_dx)
    case template
    when '90.1-2019', '90.1-2016'
      return 3
    else
      return nil
    end
  end

  # Determine what capacity curve to use to represent the change of the coil's capacity as a function of changes in temperatures
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @param heating [Boolean] Specify if the curve to return is for heating operation
  # @return [String] Curve name
  def coil_dx_cap_ft(coil_dx, equipment_type = 'Air Conditioners', heating = false)
    case equipment_type
    when 'PTAC'
      return 'PSZ-Fine Storage DX Coil Cap-FT'
    when 'PSZ-AC', 'Air Conditioners'
      return 'CoilClgDXQRatio_fTwbToadbSI'
    when 'PTHP'
      return 'DXHEAT-NECB2011-REF-CAPFT'
    when 'PSZ-HP', 'Heat Pumps'
      return 'HPACHeatCapFT' if heating

      return 'HPACCoolCapFT'
    else
      return 'CoilClgDXQRatio_fTwbToadbSI'
    end
  end

  # Determine what capacity curve to use to represent the change of the coil's capacity as a function of changes in airflow fraction
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @param heating [Boolean] Specify if the curve to return is for heating operation
  # @return [String] Curve name
  def coil_dx_cap_fflow(coil_dx, equipment_type = 'Air Conditioners', heating = false)
    case equipment_type
    when 'PTAC'
      return 'DX Coil Cap-FF'
    when 'PSZ-AC', 'Air Conditioners'
      return 'CoilClgDXSnglQRatio_fCFMRatio'
    when 'PTHP'
      return 'DXHEAT-NECB2011-REF-CAPFFLOW'
    when 'PSZ-HP', 'Heat Pumps'
      return 'HPACHeatCapFFF' if heating

      return 'HPACCoolCapFFF'
    else
      return 'CoilClgDXSnglQRatio_fCFMRatio'
    end
  end

  # Determine what EIR curve to use to represent the change of the coil's EIR as a function of changes in temperatures
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @param heating [Boolean] Specify if the curve to return is for heating operation
  # @return [String] Curve name
  def coil_dx_eir_ft(coil_dx, equipment_type = 'Air Conditioners', heating = false)
    case equipment_type
    when 'PTAC'
      return 'PSZ-AC DX Coil EIR-FT'
    when 'PSZ-AC', 'Air Conditioners'
      return 'CoilClgDXEIRRatio_fTwbToadbSI'
    when 'PTHP'
      return 'DXHEAT-NECB2011-REF-EIRFT'
    when 'PSZ-HP', 'Heat Pumps'
      return 'HPACHeatEIRFT' if heating

      return 'HPACCoolEIRFT'
    else
      return 'CoilClgDXEIRRatio_fTwbToadbSI'
    end
  end

  # Determine what EIR curve to use to represent the change of the coil's EIR as a function of changes in airflow fraction
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @param heating [Boolean] Specify if the curve to return is for heating operation
  # @return [String] Curve name
  def coil_dx_eir_fflow(coil_dx, equipment_type = 'Air Conditioners', heating = false)
    case equipment_type
    when 'PTAC'
      return 'Split DX Coil EIR-FF'
    when 'PSZ-AC', 'Air Conditioners'
      return 'CoilClgDXSnglEIRRatio_fCFMRatio'
    when 'PTHP'
      return 'DXHEAT-NECB2011-REF-EIRFFLOW'
    when 'PSZ-HP', 'Heat Pumps'
      return 'HPACHeatEIRFFF' if heating

      return 'HPACCoolEIRFFF'
    else
      return 'CoilClgDXSnglEIRRatio_fCFMRatio'
    end
  end

  # Determine what PLF curve to use to represent the change of the coil's PLR as a function of changes in PLR
  #
  # @param coil_dx [OpenStudio::Model::StraightComponent] coil cooling object, allowable types:
  #   CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, CoilCoolingDXMultiSpeed
  # @param equipment_type [String] Type of equipment
  # @param heating [Boolean] Specify if the curve to return is for heating operation
  # @return [String] Curve name
  def coil_dx_plf_fplr(coil_dx, equipment_type = 'Air Conditioners', heating = false)
    case equipment_type
    when 'PTAC'
      return 'HPACCOOLPLFFPLR'
    when 'PSZ-AC', 'Air Conditioners'
      return 'CoilClgDXEIRRatio_fQFrac'
    when 'PTHP'
      return 'DXHEAT-NECB2011-REF-PLFFPLR'
    when 'PSZ-HP', 'Heat Pumps'
      return 'HPACCOOLPLFFPLR'
    else
      return 'CoilClgDXEIRRatio_fQFrac'
    end
  end
end

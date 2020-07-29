class ECMS

  def apply_erv_ecm(model:, erv_package: nil)
    # If erv is nil.. do nothing.
    return if erv_package.nil?
    model.getAirLoopHVACs.each do |air_loop|
      # Adds default erv to all air_loops
      air_loop_hvac_apply_energy_recovery_ventilator(air_loop, nil)
    end
  end


  # Sets the minimum effectiveness of the heat exchanger
  def heat_exchanger_air_to_air_sensible_and_latent_apply_efficiency(heat_exchanger_air_to_air_sensible_and_latent)
    # Assumed to be sensible and latent at all flow
    heat_exchanger_type = heat_exchanger_air_to_air_sensible_and_latent.heatExchangerType

    if heat_exchanger_type == 'Plate'
      heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100HeatingAirFlow(0.755)
      heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100HeatingAirFlow(0.564)
      heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75HeatingAirFlow(0.791)
      heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75HeatingAirFlow(0.625)
      heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100CoolingAirFlow(0.755)
      heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100CoolingAirFlow(0.564)
      heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75CoolingAirFlow(0.791)
      heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75CoolingAirFlow(0.625)
      heat_exchanger_air_to_air_sensible_and_latent.setNominalElectricPower(0.0)
    else # Rotary
      heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100HeatingAirFlow(0.75)
      heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100HeatingAirFlow(0.74)
      heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75HeatingAirFlow(0.79)
      heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75HeatingAirFlow(0.79)
      heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100CoolingAirFlow(0.75)
      heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100CoolingAirFlow(0.74)
      heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75CoolingAirFlow(0.78)
      heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75CoolingAirFlow(0.78)

    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.ze_aedg_multifamily.HeatExchangerAirToAirSensibleAndLatent', "For #{heat_exchanger_air_to_air_sensible_and_latent.name}, set sensible and latent effectiveness to #{heat_exchanger_type} values.")

    return true
  end


  # Check if ERV is required on this airloop.
  #
  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def air_loop_hvac_energy_recovery_ventilator_required?(air_loop_hvac, climate_zone)
    return true
  end


  # @param (see #economizer_required?)
  # @return [Bool] Returns true if required, false if not.
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def air_loop_hvac_apply_energy_recovery_ventilator(air_loop_hvac, climate_zone)
    # Get the OA system
    oa_system = nil
    if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV cannot be added because the system has no OA intake.")
      return false
    end

    # Create an ERV and add it to the OA system
    erv = OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent.new(air_loop_hvac.model)
    erv.addToNode(oa_system.outboardOANode.get)

    # Determine whether to use an ERV and HRV and heat exchanger style
    erv_type = air_loop_hvac_energy_recovery_ventilator_type(air_loop_hvac, climate_zone)
    heat_exchanger_type = air_loop_hvac_energy_recovery_ventilator_heat_exchanger_type(air_loop_hvac)
    erv.setName("#{air_loop_hvac.name} #{erv_type}")
    erv.setHeatExchangerType(heat_exchanger_type)

    # apply heat exchanger efficiencies
    air_loop_hvac_apply_energy_recovery_ventilator_efficiency(erv, erv_type: erv_type, heat_exchanger_type: heat_exchanger_type)

    # Apply the prototype heat exchanger power assumptions for rotary style heat exchangers
    heat_exchanger_air_to_air_sensible_and_latent_apply_prototype_nominal_electric_power(erv)

    # add economizer lockout
    erv.setSupplyAirOutletTemperatureControl(false)
    erv.setEconomizerLockout(true)

    # add defrost
    erv.setFrostControlType('ExhaustOnly')
    erv.setThresholdTemperature(-23.3) # -10F
    erv.setInitialDefrostTimeFraction(0.167)
    erv.setRateofDefrostTimeFractionIncrease(1.44)

    # Add a setpoint manager OA pretreat to control the ERV
    spm_oa_pretreat = OpenStudio::Model::SetpointManagerOutdoorAirPretreat.new(air_loop_hvac.model)
    spm_oa_pretreat.setMinimumSetpointTemperature(-99.0)
    spm_oa_pretreat.setMaximumSetpointTemperature(99.0)
    spm_oa_pretreat.setMinimumSetpointHumidityRatio(0.00001)
    spm_oa_pretreat.setMaximumSetpointHumidityRatio(1.0)
    # Reference setpoint node and mixed air stream node are outlet node of the OA system
    mixed_air_node = oa_system.mixedAirModelObject.get.to_Node.get
    spm_oa_pretreat.setReferenceSetpointNode(mixed_air_node)
    spm_oa_pretreat.setMixedAirStreamNode(mixed_air_node)
    # Outdoor air node is the outboard OA node of the OA system
    spm_oa_pretreat.setOutdoorAirStreamNode(oa_system.outboardOANode.get)
    # Return air node is the inlet node of the OA system
    return_air_node = oa_system.returnAirModelObject.get.to_Node.get
    spm_oa_pretreat.setReturnAirStreamNode(return_air_node)
    # Attach to the outlet of the ERV
    erv_outlet = erv.primaryAirOutletModelObject.get.to_Node.get
    spm_oa_pretreat.addToNode(erv_outlet)

    # Determine if the system is a DOAS based on whether there is 100% OA in heating and cooling sizing.
    is_doas = false
    sizing_system = air_loop_hvac.sizingSystem
    if sizing_system.allOutdoorAirinCooling && sizing_system.allOutdoorAirinHeating
      is_doas = true
    end

    # Set the bypass control type
    # If DOAS system, BypassWhenWithinEconomizerLimits
    # to disable ERV during economizing.
    # Otherwise, BypassWhenOAFlowGreaterThanMinimum
    # to disable ERV during economizing and when OA
    # is also greater than minimum.
    bypass_ctrl_type = if is_doas
                         'BypassWhenWithinEconomizerLimits'
                       else
                         'BypassWhenOAFlowGreaterThanMinimum'
                       end
    oa_system.getControllerOutdoorAir.setHeatRecoveryBypassControlType(bypass_ctrl_type)

    return true
  end

  # Apply efficiency values to the erv
  #
  # @param erv [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] erv to apply efficiency values
  # @param erv_type [String] erv type ERV or HRV
  # @param heat_exchanger_type [String] heat exchanger type Rotary or Plate
  # @return erv [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] erv to apply efficiency values
  def air_loop_hvac_apply_energy_recovery_ventilator_efficiency(erv, erv_type: 'ERV', heat_exchanger_type: 'Rotary')
    erv.setSensibleEffectivenessat100HeatingAirFlow(0.7)
    erv.setLatentEffectivenessat100HeatingAirFlow(0.6)
    erv.setSensibleEffectivenessat75HeatingAirFlow(0.7)
    erv.setLatentEffectivenessat75HeatingAirFlow(0.6)
    erv.setSensibleEffectivenessat100CoolingAirFlow(0.75)
    erv.setLatentEffectivenessat100CoolingAirFlow(0.6)
    erv.setSensibleEffectivenessat75CoolingAirFlow(0.75)
    erv.setLatentEffectivenessat75CoolingAirFlow(0.6)
    return erv
  end


end
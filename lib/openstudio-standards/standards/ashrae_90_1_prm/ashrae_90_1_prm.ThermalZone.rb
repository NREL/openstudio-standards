class ASHRAE901PRM < Standard
  # @!group ThermalZone

  # Determine the fan power limitation pressure drop adjustment
  # Per Table 6.5.3.1-2 (90.1-2019)
  #
  # @param thermal_zone
  def thermal_zone_get_fan_power_limitations(thermal_zone, is_energy_recovery_required)
    fan_pwr_adjustment_in_wc = 0

    # error if zone design air flow rate is not available
    if thermal_zone.model.version < OpenStudio::VersionString.new('3.6.0')
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.ThermalZone', 'Required ThermalZone method .autosizedDesignAirFlowRate is not available in pre-OpenStudio 3.6.0 versions. Use a more recent version of OpenStudio.')
    end

    # Get autosized zone design supply air flow rate
    dsn_zone_air_flow_m3_per_s = thermal_zone.autosizedDesignAirFlowRate.to_f
    dsn_zone_air_flow_cfm = OpenStudio.convert(dsn_zone_air_flow_m3_per_s, 'm^3/s', 'cfm').get

    # Retrieve credits from zone additional features
    # Fully ducted return and/or exhaust air systems
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_credit_fully_ducted')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_credit_fully_ducted').to_f
      adj_in_wc = 0.5 * mult
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for fully ducted return and/or exhaust air systems")
    end

    # Return and/or exhaust airflow control devices
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_credit_return_or_exhaust_flow_control')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_credit_return_or_exhaust_flow_control').to_f
      adj_in_wc = 0.5 * mult
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for return and/or exhaust airflow control devices")
    end

    # Exhaust filters, scrubbers, or other exhaust treatment
    if thermal_zone.additionalProperties.hasFeature('fan_power_credit_exhaust_treatment')
      adj_in_wc = thermal_zone.additionalProperties.getFeatureAsDouble('fan_power_credit_exhaust_treatment').to_f
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for exhaust filters, scrubbers, or other exhaust treatment")
    end

    # MERV 9 through 12
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_credit_filtration_m9to12')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_credit_filtration_m9to12').to_f
      adj_in_wc = 0.5 * mult
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for particulate Filtration Credit: MERV 9 through 12")
    end

    # MERV 13 through 15
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_credit_filtration_m13to15')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_credit_filtration_m13to15').to_f
      adj_in_wc = 0.9 * mult
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for particulate Filtration Credit: MERV 13 through 15")
    end

    # MERV 16 and greater and electronically enhanced filters
    if thermal_zone.additionalProperties.hasFeature('clean_filter_pressure_drop_for_fan_power_credit_filtration_m16plus')
      adj_in_wc = thermal_zone.additionalProperties.getFeatureAsDouble('clean_filter_pressure_drop_for_fan_power_credit_filtration_m16plus').to_f
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for particulate Filtration Credit: MERV 16 and greater and electronically enhanced filters")
    end

    # Carbon and other gas-phase air cleaners
    if thermal_zone.additionalProperties.hasFeature('fan_power_credit_gas_phase_cleaners')
      adj_in_wc = thermal_zone.additionalProperties.getFeatureAsDouble('fan_power_credit_gas_phase_cleaners').to_f
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for carbon and other gas-phase air cleaners")
    end

    # Biosafety cabinet
    if thermal_zone.additionalProperties.hasFeature('fan_power_credit_biosafety')
      adj_in_wc = thermal_zone.additionalProperties.getFeatureAsDouble('fan_power_credit_biosafety').to_f
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for biosafety cabinet")
    end

    # Energy recovery device, other than coil runaround loop
    if thermal_zone.additionalProperties.hasFeature('fan_power_credit_other_than_coil_runaround') && is_energy_recovery_required
      adj_in_wc = thermal_zone.additionalProperties.getFeatureAsDouble('fan_power_credit_other_than_coil_runaround').to_f
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for energy recovery device other than coil runaround loop")
    end

    # Coil runaround loop
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_credit_coil_runaround') && is_energy_recovery_required
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_credit_coil_runaround').to_f
      adj_in_wc = 0.6 * 2 * mult # for each stream
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for coil runaround loop")
    end

    # Evaporative humidifier/cooler in series with another cooling coil
    if thermal_zone.additionalProperties.hasFeature('fan_power_credit_evaporative_humidifier_or_cooler')
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', '--Added 0 in wc for evaporative humidifier/cooler in series with another coil as per Table G3.1.2.9 Note 2')
    end

    # Sound attenuation section (fans serving spoaces with design background noise goals below NC35)
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_credit_sound_attenuation')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_credit_sound_attenuation').to_f
      adj_in_wc = 0.15 * mult
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for sound attenuation section")
    end

    # Exhaust system serving fume hoods
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_credit_exhaust_serving_fume_hoods')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_credit_exhaust_serving_fume_hoods').to_f
      adj_in_wc = 0.35 * mult
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for exhaust system serving fume hoods")
    end

    # Laboratory and vivarium exhaust systems in high-rise buildings
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_credit_lab_or_vivarium_highrise_vertical_duct')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_credit_lab_or_vivarium_highrise_vertical_duct').to_f
      adj_in_wc = 0.35 * mult
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Added #{adj_in_wc} in wc for laboratory and vivarium exhaust systems in high-rise buildings")
    end

    # Deductions
    # Systems without central cooling device
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_deduction_system_without_central_cooling_device')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_deduction_system_without_central_cooling_device').to_f
      adj_in_wc = 0.60 * mult
      fan_pwr_adjustment_in_wc -= adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Removed #{adj_in_wc} in wc for system without central cooling device")
    end

    # Systems without central heating device
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_deduction_system_without_central_heating_device')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_deduction_system_without_central_heating_device').to_f
      adj_in_wc = 0.30 * mult
      fan_pwr_adjustment_in_wc -= adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Removed #{adj_in_wc} in wc for system without central heating device")
    end

    # Systems with central electric resistance heat
    if thermal_zone.additionalProperties.hasFeature('has_fan_power_deduction_system_with_central_electric_resistance_heat')
      mult = thermal_zone.additionalProperties.getFeatureAsDouble('has_fan_power_deduction_system_with_central_electric_resistance_heat').to_f
      adj_in_wc = 0.20 * mult
      fan_pwr_adjustment_in_wc -= adj_in_wc
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "--Removed #{adj_in_wc} in wc for system with central electric resistance heat")
    end

    # Convert the pressure drop adjustment to brake horsepower (bhp)
    # assuming that all supply air passes through all devices
    return fan_pwr_adjustment_in_wc * dsn_zone_air_flow_cfm / 4131
  end

  # Identify if zone has district energy for occ_and_fuel_type method
  # @param thermal_zone
  # @return [String with applicable DistrictHeating and/or DistrictCooling
  def thermal_zone_get_zone_fuels_for_occ_and_fuel_type(thermal_zone)
    zone_fuels = ''

    # error if HVACComponent heating fuels method is not available
    if thermal_zone.model.version < OpenStudio::VersionString.new('3.6.0')
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.ashrae_90_1_prm.ThermalZone', 'Required HVACComponent methods .heatingFuelTypes and .coolingFuelTypes are not available in pre-OpenStudio 3.6.0 versions. Use a more recent version of OpenStudio.')
    end

    htg_fuels = thermal_zone.heatingFuelTypes.map(&:valueName)
    if htg_fuels.include?('DistrictHeating')
      zone_fuels = 'DistrictHeating'
    end
    clg_fuels = thermal_zone.coolingFuelTypes.map(&:valueName)
    if clg_fuels.include?('DistrictCooling')
      zone_fuels += 'DistrictCooling'
    end
    return zone_fuels
  end
end

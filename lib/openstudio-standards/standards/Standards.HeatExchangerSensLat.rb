class Standard
  # @!group HeatExchangerSensLat

  # Sets the minimum effectiveness of the heat exchanger per the standard.
  #
  # @param heat_exchanger_air_to_air_sensible_and_latent [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] the heat exchanger
  # @return [Bool] returns true if successful, false if not
  def heat_exchanger_air_to_air_sensible_and_latent_apply_effectiveness(heat_exchanger_air_to_air_sensible_and_latent)
    # Assumed to be sensible and latent at all flow
    full_htg_sens_eff, full_htg_lat_eff, part_htg_sens_eff, part_htg_lat_eff, full_cool_sens_eff, full_cool_lat_eff, part_cool_sens_eff, part_cool_lat_eff = heat_exchanger_air_to_air_sensible_and_latent_minimum_effectiveness(heat_exchanger_air_to_air_sensible_and_latent)

    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100HeatingAirFlow(full_htg_sens_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100HeatingAirFlow(full_htg_lat_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75HeatingAirFlow(part_htg_sens_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75HeatingAirFlow(part_htg_lat_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100CoolingAirFlow(full_cool_sens_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100CoolingAirFlow(full_cool_lat_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75CoolingAirFlow(part_cool_sens_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75CoolingAirFlow(part_cool_lat_eff)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.HeatExchangerSensLat', "For #{heat_exchanger_air_to_air_sensible_and_latent.name}: Set sensible and latent effectiveness.")

    return true
  end

  # Defines the minimum sensible and latent effectiveness of the heat exchanger.
  # Assumed to apply to sensible and latent effectiveness at all flow rates.
  #
  # @param heat_exchanger_air_to_air_sensible_and_latent [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] the heat exchanger
  # @return [Array] List of full and part load heat echanger effectiveness
  def heat_exchanger_air_to_air_sensible_and_latent_minimum_effectiveness(heat_exchanger_air_to_air_sensible_and_latent)
    full_htg_sens_eff = 0.5
    full_htg_lat_eff = 0.5
    part_htg_sens_eff = 0.5
    part_htg_lat_eff = 0.5
    full_cool_sens_eff = 0.5
    full_cool_lat_eff = 0.5
    part_cool_sens_eff = 0.5
    part_cool_lat_eff = 0.5

    return full_htg_sens_eff, full_htg_lat_eff, part_htg_sens_eff, part_htg_lat_eff, full_cool_sens_eff, full_cool_lat_eff, part_cool_sens_eff, part_cool_lat_eff
  end

  # Adjust ERR from design conditions to ERR for typical conditions.
  # This is only applies to the 2B and 3B climate zones. In these
  # climate zones a 50% ERR at typical condition leads a ERR > 50%,
  # the ERR is thus scaled down.
  #
  # @param enthalpy_recovery_ratio [float] Enthalpy Recovery Ratio (ERR)
  # @param climate_zone [String] climate zone
  # @return [float] adjusted ERR
  def enthalpy_recovery_ratio_design_to_typical_adjustment(enthalpy_recovery_ratio, climate_zone)
    if climate_zone.include? '2B'
      enthalpy_recovery_ratio /= 0.65 / 0.55
    elsif climate_zone.include? '3B'
      enthalpy_recovery_ratio /= 0.62 / 0.55
    end

    return enthalpy_recovery_ratio
  end

  # Calculate a heat exchanger's effectiveness for a specific ERR and design conditions.
  # Regressions were determined based available manufacturer data.
  #
  # @param enthalpy_recovery_ratio [float] Enthalpy Recovery Ratio (ERR)
  # @param design_conditions [String] design_conditions for effectiveness calculation, either 'cooling' or 'heating'
  # @return [Array] heating and cooling heat exchanger effectiveness at 100% and 75% nominal airflow
  def heat_exchanger_air_to_air_sensible_and_latent_enthalpy_recovery_ratio_to_effectiveness(enthalpy_recovery_ratio, design_conditions)
    case design_conditions
      when 'cooling'
        full_htg_sens_eff = (20.707 * enthalpy_recovery_ratio**2 + 41.354 * enthalpy_recovery_ratio + 40.755) / 100
        full_htg_lat_eff = (127.45 * enthalpy_recovery_ratio - 18.625) / 100
        part_htg_sens_eff = (-0.1214 * enthalpy_recovery_ratio + 1.111) * full_htg_sens_eff
        part_htg_lat_eff = (-0.3405 * enthalpy_recovery_ratio + 1.2732) * full_htg_lat_eff
        full_cool_sens_eff = (70.689 * enthalpy_recovery_ratio + 30.789) / 100
        full_cool_lat_eff = (48.054 * enthalpy_recovery_ratio**2 + 83.082 * enthalpy_recovery_ratio - 12.881) / 100
        part_cool_sens_eff = (-0.1214 * enthalpy_recovery_ratio + 1.111) * full_cool_sens_eff
        part_cool_lat_eff = (-0.3982 * enthalpy_recovery_ratio  + 1.3151) * full_cool_lat_eff
      when 'heating'
        full_htg_sens_eff = enthalpy_recovery_ratio
        full_htg_lat_eff = 0.0
        part_htg_sens_eff = (-0.1214 * enthalpy_recovery_ratio + 1.111) * full_htg_sens_eff
        part_htg_lat_eff = 0.0
        full_cool_sens_eff = enthalpy_recovery_ratio * (70.689 * enthalpy_recovery_ratio + 30.789) / (20.707 * enthalpy_recovery_ratio**2 + 41.354 * enthalpy_recovery_ratio + 40.755)
        full_cool_lat_eff = 0.0
        part_cool_sens_eff = (-0.1214 * enthalpy_recovery_ratio + 1.111) * full_cool_sens_eff
        part_cool_lat_eff = 0.0
    end

    return full_htg_sens_eff, full_htg_lat_eff, part_htg_sens_eff, part_htg_lat_eff, full_cool_sens_eff, full_cool_lat_eff, part_cool_sens_eff, part_cool_lat_eff
  end
end

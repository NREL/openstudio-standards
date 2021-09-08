class ASHRAE9012019 < ASHRAE901
  # @!group Model

  # Set sensible and latent effectiveness at 100 and 75 heating and cooling airflow;
  # The values are calculated by using ERR, which is introduced in 90.1-2016 Addendum CE
  #
  # This function is only used for nontransient dwelling units (Mid-rise and High-rise Apartment)
  # @param [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] heat exchanger air to air sensible and latent
  # @param [String] err
  # @param [String] err basis (Cooling/Heating)
  # @param [String] climate zone
  def heat_exchanger_air_to_air_sensible_and_latent_apply_prototype_efficiency_err(heat_exchanger_air_to_air_sensible_and_latent, err, basis, climate_zone)
    # Assumed to be sensible and latent at all flow
    err = enthalpy_recovery_ratio_design_to_typical_adjustment(err, climate_zone)
    full_htg_sens_eff, full_htg_lat_eff, part_htg_sens_eff, part_htg_lat_eff, full_cool_sens_eff, full_cool_lat_eff, part_cool_sens_eff, part_cool_lat_eff = heat_exchanger_air_to_air_sensible_and_latent_enthalpy_recovery_ratio_to_effectiveness(err, basis)

    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100HeatingAirFlow(full_htg_sens_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100HeatingAirFlow(full_htg_lat_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75HeatingAirFlow(part_htg_sens_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75HeatingAirFlow(part_htg_lat_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100CoolingAirFlow(full_cool_sens_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100CoolingAirFlow(full_cool_lat_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75CoolingAirFlow(part_cool_sens_eff)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75CoolingAirFlow(part_cool_lat_eff)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.HeatExchangerSensLat', "For #{heat_exchanger_air_to_air_sensible_and_latent.name}: Set sensible and latent effectiveness calculated by using ERR.")
    return true
  end
end

class Standard
  # @!group HeatExchangerSensLat

  # Sets the minimum effectiveness of the heat exchanger per
  # the standard.
  def heat_exchanger_air_to_air_sensible_and_latent_apply_efficiency(heat_exchanger_air_to_air_sensible_and_latent)
    # Assumed to be sensible and latent at all flow
    min_effct = heat_exchanger_air_to_air_sensible_and_latent_minimum_efficiency(heat_exchanger_air_to_air_sensible_and_latent)

    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100HeatingAirFlow(min_effct)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100HeatingAirFlow(min_effct)
    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75HeatingAirFlow(min_effct)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75HeatingAirFlow(min_effct)
    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat100CoolingAirFlow(min_effct)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat100CoolingAirFlow(min_effct)
    heat_exchanger_air_to_air_sensible_and_latent.setSensibleEffectivenessat75CoolingAirFlow(min_effct)
    heat_exchanger_air_to_air_sensible_and_latent.setLatentEffectivenessat75CoolingAirFlow(min_effct)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.HeatExchangerSensLat', "For #{heat_exchanger_air_to_air_sensible_and_latent.name}: Set sensible and latent effectiveness to #{(min_effct * 100).round}%.")

    return true
  end

  # Defines the minimum sensible and latent effectiveness of
  # the heat exchanger.  Assumed to apply to sensible and latent
  # effectiveness at all flow rates.
  #
  # @param heat_exchanger_air_to_air_sensible_and_latent [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] the heat exchanger
  def heat_exchanger_air_to_air_sensible_and_latent_minimum_efficiency(heat_exchanger_air_to_air_sensible_and_latent)
    min_effct = 0.5
    return min_effct
  end
end

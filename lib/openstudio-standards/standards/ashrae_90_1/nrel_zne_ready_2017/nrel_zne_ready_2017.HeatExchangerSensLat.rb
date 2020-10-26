class NRELZNEReady2017 < ASHRAE901
  # @!group HeatExchangerSensLat

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
end

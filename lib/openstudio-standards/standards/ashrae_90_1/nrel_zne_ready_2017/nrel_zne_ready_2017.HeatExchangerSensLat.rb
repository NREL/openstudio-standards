class NRELZNEReady2017 < ASHRAE901
  # Defines the minimum sensible and latent effectiveness of
  # the heat exchanger.  Assumed to apply to sensible and latent
  # effectiveness at all flow rates.  For NREL ZNE Ready 2017, assume
  # 70% effectiveness, as this is higher than the typical 90.1 minimum of 50%,
  # and is easily achievable with an enthalpy wheel.
  #
  # @param heat_exchanger_air_to_air_sensible_and_latent [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] the heat exchanger
  def heat_exchanger_air_to_air_sensible_and_latent_minimum_efficiency(heat_exchanger_air_to_air_sensible_and_latent)
    min_effct = 0.7
    return min_effct
  end
end

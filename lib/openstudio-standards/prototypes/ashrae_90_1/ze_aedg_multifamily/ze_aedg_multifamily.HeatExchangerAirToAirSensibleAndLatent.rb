class ZEAEDGMultifamily < ASHRAE901
  # @!group HeatExchangerAirToAirSensibleAndLatent

  # Default fan efficiency assumption for the prm added fan power
  def heat_exchanger_air_to_air_sensible_and_latent_prototype_default_fan_efficiency
    default_fan_efficiency = 0.55
    return default_fan_efficiency
  end
end

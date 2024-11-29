class ASHRAE901PRM < Standard
  # @!group HeatExchangerSensLat

  # Defines the minimum sensible and latent effectiveness of the heat exchanger.
  # Assumed to apply to sensible and latent effectiveness at all flow rates.
  #
  # @param heat_exchanger_air_to_air_sensible_and_latent [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] OpenStudio heat exchanger object
  # @return [Array] List of full and part load heat exchanger effectiveness
  def heat_exchanger_air_to_air_sensible_and_latent_minimum_effectiveness(heat_exchanger_air_to_air_sensible_and_latent)
    # Get required ERR
    enthalpy_recovery_ratio = heat_exchanger_air_to_air_sensible_and_latent_enthalpy_recovery_ratio(heat_exchanger_air_to_air_sensible_and_latent)

    # Get design condition for climate zones
    climate_zone = OpenstudioStandards::Weather.model_get_climate_zone(heat_exchanger_air_to_air_sensible_and_latent.model)
    design_conditions = heat_exchanger_air_to_air_sensible_and_latent_design_conditions(heat_exchanger_air_to_air_sensible_and_latent, climate_zone)

    # Adjust, and convert ERR to Effectiveness for input to the model
    enthalpy_recovery_ratio = enthalpy_recovery_ratio_design_to_typical_adjustment(enthalpy_recovery_ratio, climate_zone)
    full_htg_sens_eff, full_htg_lat_eff, part_htg_sens_eff, part_htg_lat_eff, full_cool_sens_eff, full_cool_lat_eff, part_cool_sens_eff, part_cool_lat_eff = heat_exchanger_air_to_air_sensible_and_latent_enthalpy_recovery_ratio_to_effectiveness(enthalpy_recovery_ratio, design_conditions)

    return full_htg_sens_eff, full_htg_lat_eff, part_htg_sens_eff, part_htg_lat_eff, full_cool_sens_eff, full_cool_lat_eff, part_cool_sens_eff, part_cool_lat_eff
  end

  # Determine the heat exchanger design conditions for a specific climate zones
  #
  # @param heat_exchanger_air_to_air_sensible_and_latent [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] OpenStudio heat exchanger object
  # @param climate_zone [String] Climate zone used to generate the model
  # @return [String] Heat exchanger design conditions
  def heat_exchanger_air_to_air_sensible_and_latent_design_conditions(heat_exchanger_air_to_air_sensible_and_latent, climate_zone)
    case climate_zone
    when 'ASHRAE 169-2006-6B',
      'ASHRAE 169-2013-6B',
      'ASHRAE 169-2006-7A',
      'ASHRAE 169-2013-7A',
      'ASHRAE 169-2006-7B',
      'ASHRAE 169-2013-7B',
      'ASHRAE 169-2006-8A',
      'ASHRAE 169-2013-8A',
      'ASHRAE 169-2006-8B',
      'ASHRAE 169-2013-8B'
      design_conditions = 'heating'
    else
      design_conditions = 'cooling'
    end
    return design_conditions
  end

  # Determine the required enthalpy recovery ratio (ERR)
  #
  # @param heat_exchanger_air_to_air_sensible_and_latent [OpenStudio::Model::HeatExchangerAirToAirSensibleAndLatent] OpenStudio heat exchanger object
  # @return [Double] enthalpy recovery ratio
  def heat_exchanger_air_to_air_sensible_and_latent_enthalpy_recovery_ratio(heat_exchanger_air_to_air_sensible_and_latent)
    return 0.5
  end
end

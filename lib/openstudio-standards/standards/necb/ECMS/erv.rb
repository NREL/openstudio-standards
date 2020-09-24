class ECMS
  # This method will add a skeleton erv to all air loops.
  def apply_erv_ecm(model:, erv_package: nil)
    # If erv is nil.. do nothing.
    return if erv_package.nil? || erv_package == 'none' || erv_package == 'NECB_Default'

    model.getAirLoopHVACs.each do |air_loop|
      # Adds default erv to all air_loops
      air_loop_hvac_apply_energy_recovery_ventilator(air_loop, nil)
    end
  end

  # This method will set the properties of the ERV that was added above. Must be run after the standard efficiency is complete as this will overwrite
  # those values. See data/erv.json to view/add different erv packages.
  def apply_erv_ecm_efficiency(model:, erv_package: nil)
    # If erv is nil.. do nothing.
    return if erv_package.nil? || erv_package == 'none' || erv_package == 'NECB_Default'

    # This calls the NECB2011 implementation of the method.
    model.getHeatExchangerAirToAirSensibleAndLatents.each { |erv| heat_exchanger_air_to_air_sensible_and_latent_apply_efficiency(erv, erv_package) }
  end
end
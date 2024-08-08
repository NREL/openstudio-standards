class ACM179dASHRAE9012007
  # @!group AirLoopHVAC

  # Set default fan curve to be VSD with static pressure reset
  # NOTE: 179D overrides it because we want the use the proper fan coefs, 
  # and not the ones from 'Multi Zone VAV with VSD and SP Setpoint Reset'
  # @return [string] name of appropriate curve for this code version
  def air_loop_hvac_set_vsd_curve_type
    return 'Multi Zone VAV with VSD and Fixed SP Setpoint'
  end

end

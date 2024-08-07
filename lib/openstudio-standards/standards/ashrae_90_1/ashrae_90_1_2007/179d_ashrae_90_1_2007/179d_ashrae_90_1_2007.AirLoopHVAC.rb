class ACM179dASHRAE9012007
  # @!group AirLoopHVAC

  # Set default fan curve to be VSD with static pressure reset
  # @return [string] name of appropriate curve for this code version
  def air_loop_hvac_set_vsd_curve_type
    return 'Multi Zone VAV with VSD and Fixed SP Setpoint'
  end

end

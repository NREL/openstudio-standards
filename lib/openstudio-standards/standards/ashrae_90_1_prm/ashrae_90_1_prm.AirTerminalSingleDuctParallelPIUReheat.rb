class ASHRAE901PRM < Standard
  # @!group AirTerminalSingleDuctParallelPIUReheat

  # Return the fan on flow fraction for a parallel PIU terminal
  #
  # @return [Double] returns nil or a float representing the fraction
  def air_terminal_single_duct_parallel_piu_reheat_fan_on_flow_fraction
    return 0.0 # will make the secondary fans run for heating loads
  end
end

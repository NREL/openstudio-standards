class NRELZNEReady2017_Model < A90_1_Model
  # Determine which type of fan the cooling tower
  # will have.  Variable Speed Fan for NREL ZNE Ready 2017.
  # @return [String] the fan type: TwoSpeed Fan, Variable Speed Fan
  def model_cw_loop_cooling_tower_fan_type(model)
    fan_type = 'Variable Speed Fan'
    return fan_type
  end
end

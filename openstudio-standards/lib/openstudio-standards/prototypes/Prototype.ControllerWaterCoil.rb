
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::ControllerWaterCoil

  # Sets the convergence tolerance to 0.0001 deltaC
  # for all hot water coils.
  # 
  # @return [Bool] returns true if successful, false if not
  # @todo Figure out what the reason for this is,
  # because it seems like a workaround for an E+ bug
  # that was probably addressed long ago.
  def set_convergence_limits()
 
    controller_action = self.action
    if controller_action.is_initialized
      if controller_action.get == 'Normal'
        self.setControllerConvergenceTolerance(0.0001)
      end
    end
    
    return true
    
  end

end

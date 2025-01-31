class Standard
  # @!group ControllerWaterCoil

  # Sets the convergence tolerance to 0.0001 deltaC for all hot water coils.
  #
  # @param controller_water_coil [OpenStudio::Model::ControllerWaterCoil] controller water coil object
  # @return [Boolean] returns true if successful, false if not
  # @todo Figure out what the reason for this is, because it seems like a workaround for an E+ bug that was probably addressed long ago.
  def controller_water_coil_set_convergence_limits(controller_water_coil)
    controller_action = controller_water_coil.action
    if controller_action.is_initialized && controller_action.get == 'Normal'
      controller_water_coil.setControllerConvergenceTolerance(0.0001)
    end

    return true
  end
end

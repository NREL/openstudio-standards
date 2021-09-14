class CBES < Standard
  # @!group PlantLoop

  # Determine if temperature reset is required.
  # Not required for CBES.
  #
  # @param plant_loop [OpenStudio::Model::PlantLoop] plant loop
  # @return [Bool] returns true if required, false if not
  def plant_loop_supply_water_temperature_reset_required?(plant_loop)
    reset_required = false
    return reset_required
  end
end

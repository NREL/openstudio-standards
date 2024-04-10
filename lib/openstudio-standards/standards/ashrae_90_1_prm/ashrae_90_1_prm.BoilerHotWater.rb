class ASHRAE901PRM < Standard
  # @!group BoilerHotWater

  # Applies the standard efficiency ratings to this object.
  #
  # @param boiler_hot_water [OpenStudio::Model::BoilerHotWater] hot water boiler object
  # @return [Boolean] returns true if successful, false if not
  def boiler_hot_water_apply_efficiency_and_curves(boiler_hot_water)
    # Get the minimum efficiency standards
    thermal_eff = boiler_hot_water_standard_minimum_thermal_efficiency(boiler_hot_water)

    # Set the efficiency values
    unless thermal_eff.nil?
      boiler_hot_water.setNominalThermalEfficiency(thermal_eff)
    end
    return true
  end
end

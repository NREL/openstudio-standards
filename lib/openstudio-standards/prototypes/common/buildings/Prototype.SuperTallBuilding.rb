
# Custom changes for the TallBuilding prototype.
# These are changes that are inconsistent with other prototype
# building types.
module SuperTallBuilding
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')


    # TODO


    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end


  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)






    return true
  end
end

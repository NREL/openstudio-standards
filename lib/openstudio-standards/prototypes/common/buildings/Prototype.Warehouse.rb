
# Custom changes for the Warehouse prototype.
# These are changes that are inconsistent with other prototype
# building types.
module Warehouse
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    return true
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)

    return true
  end
end

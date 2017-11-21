
# Custom changes for the Warehouse prototype.
# These are changes that are inconsistent with other prototype
# building types.
module Warehouse
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    return true
  end

  def update_waterheater_loss_coefficient(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
        end
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(model)
    return true
  end
end

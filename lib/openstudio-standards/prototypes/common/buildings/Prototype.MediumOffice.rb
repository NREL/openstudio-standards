
# Custom changes for the MediumOffice prototype.
# These are changes that are inconsistent with other prototype
# building types.
module MediumOffice
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    model.getSpaces.sort.each do |space|
      if space.name.get.to_s == 'Core_bottom'
        model_add_elevator(model,
                           space,
                           prototype_input['number_of_elevators'],
                           prototype_input['elevator_type'],
                           prototype_input['elevator_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           building_type)
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    # add extra infiltration for entry door
    add_door_infiltration(climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added door infiltration')

    return true
  end

  # add hvac

  def add_door_infiltration(climate_zone, model)
    # add extra infiltration for entry door in m3/s (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      entry_space = model.getSpaceByName('Perimeter_bot_ZN_1').get
      infiltration_entrydoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entrydoor.setName('entry door Infiltration')
      infiltration_per_zone_entrydoor = 0
      if template == '90.1-2004'
        infiltration_per_zone_entrydoor = 1.04300287
        infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeMedium INFIL_Door_Opening_SCH'))
      elsif template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2B'
            infiltration_per_zone_entrydoor = 1.04300287
            infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeMedium INFIL_Door_Opening_SCH'))
          else
            infiltration_per_zone_entrydoor = 0.678659786
            infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeMedium INFIL_Door_Opening_SCH'))
        end
      end
      infiltration_entrydoor.setDesignFlowRate(infiltration_per_zone_entrydoor)
      infiltration_entrydoor.setSpace(entry_space)
    end
  end

  def update_waterheater_loss_coefficient(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
        end
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(model)

    return true
  end
end

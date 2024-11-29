# Custom changes for the Courthouse prototype.
# These are changes that are inconsistent with other prototype building types.
module Courthouse
  # hvac adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String] the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_hvac_tweaks(model, building_type, climate_zone, prototype_input)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    model.getSpaces.each do |space|
      if space.name.get.to_s == 'ELEVATOR_LOBBY_FLR_1'
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

  # add door infiltration
  #
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] returns true if successful, false if not
  def add_door_infiltration(climate_zone, model)
    # add extra infiltration for entry door in m3/s (there is no attic in 'DOE Ref Pre-1980')
    return false if template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'

    entry_space = model.getSpaceByName('SECURITY_SCREENING_FLR_1').get
    infiltration_entrydoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
    infiltration_entrydoor.setName('entry door Infiltration')
    infiltration_per_zone_entrydoor = 0
    if template == '90.1-2004'
      infiltration_per_zone_entrydoor = 3.242751
      infiltration_entrydoor.setSchedule(model_add_schedule(model, 'Courthouse INFIL_Door_Opening_SCH'))
    elsif template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013'
      case climate_zone
      when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2B'
        infiltration_per_zone_entrydoor = 3.242751
        infiltration_entrydoor.setSchedule(model_add_schedule(model, 'Courthouse INFIL_Door_Opening_SCH'))
      else
        infiltration_per_zone_entrydoor = 2.220041
        infiltration_entrydoor.setSchedule(model_add_schedule(model, 'Courthouse INFIL_Door_Opening_SCH'))
      end
    end
    infiltration_entrydoor.setDesignFlowRate(infiltration_per_zone_entrydoor)
    infiltration_entrydoor.setSpace(entry_space)
    return true
  end

  # update water heater loss coefficient
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] returns true if successful, false if not
  def update_waterheater_loss_coefficient(model)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      model.getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
      end
    end
    return true
  end

  # swh adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String] the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(model)

    return true
  end

  # geometry adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String] the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_geometry_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end
end

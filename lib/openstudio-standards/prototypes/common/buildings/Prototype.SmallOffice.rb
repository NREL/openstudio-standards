# Custom changes for the SmallOffice prototype.
# These are changes that are inconsistent with other prototype building types.
module SmallOffice
  # hvac adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_hvac_tweaks(model, building_type, climate_zone, prototype_input)
    # add extra infiltration for entry door
    add_door_infiltration(climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added door infiltration')

    # add extra infiltration for attic
    add_attic_infiltration(template, climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added attic infiltration')

    # reset defrost time fraction
    # @todo set this to a reasonable defrost time fraction based on research and implement in Prototype.CoilHeatingDXSingleSpeed
    model.getCoilHeatingDXSingleSpeeds.each(&:resetDefrostTimePeriodFraction)
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

    entry_space = model.getSpaceByName('Perimeter_ZN_1').get
    infiltration_entrydoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
    infiltration_entrydoor.setName('entry door Infiltration')
    infiltration_per_zone_entrydoor = 0
    if template == '90.1-2004'
      infiltration_per_zone_entrydoor = 0.129785425
      infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeSmall INFIL_Door_Opening_SCH'))
    elsif template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013' || template == '90.1-2016' || template == '90.1-2019'
      case climate_zone
      when 'ASHRAE 169-2006-0A',
           'ASHRAE 169-2006-1A',
           'ASHRAE 169-2006-0B',
           'ASHRAE 169-2006-1B',
           'ASHRAE 169-2006-2A',
           'ASHRAE 169-2006-2B',
           'ASHRAE 169-2013-0A',
           'ASHRAE 169-2013-1A',
           'ASHRAE 169-2013-0B',
           'ASHRAE 169-2013-1B',
           'ASHRAE 169-2013-2A',
           'ASHRAE 169-2013-2B'
        infiltration_per_zone_entrydoor = 0.129785425
        infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeSmall INFIL_Door_Opening_SCH'))
      else
        infiltration_per_zone_entrydoor = 0.076455414
        infiltration_entrydoor.setSchedule(model_add_schedule(model, 'OfficeSmall INFIL_Door_Opening_SCH_2013'))
      end
    end
    infiltration_entrydoor.setDesignFlowRate(infiltration_per_zone_entrydoor)
    infiltration_entrydoor.setConstantTermCoefficient(1.0)
    infiltration_entrydoor.setTemperatureTermCoefficient(0.0)
    infiltration_entrydoor.setVelocityTermCoefficient(0.0)
    infiltration_entrydoor.setVelocitySquaredTermCoefficient(0.0)
    infiltration_entrydoor.setSpace(entry_space)
    return true
  end

  # add attic infiltration
  #
  # @param template [String] the model template
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] returns true if successful, false if not
  def add_attic_infiltration(template, climate_zone, model)
    # add extra infiltration for attic in m3/s (there is no attic in 'DOE Ref Pre-1980')
    return false if template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'

    entry_space = model.getSpaceByName('Attic').get
    infiltration_attic = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
    infiltration_attic.setName('attic Infiltration')
    infiltration_per_zone_attic = 0.2001
    infiltration_attic.setSchedule(model_add_schedule(model, 'Always On'))
    infiltration_attic.setDesignFlowRate(infiltration_per_zone_attic)
    infiltration_attic.setConstantTermCoefficient(1.0)
    infiltration_attic.setTemperatureTermCoefficient(0.0)
    infiltration_attic.setVelocityTermCoefficient(0.0)
    infiltration_attic.setVelocitySquaredTermCoefficient(0.0)
    infiltration_attic.setSpace(entry_space)
    return true
  end

  def model_custom_daylighting_tweaks(building_type, climate_zone, prototype_input, model)
    return true
  end

  # swh adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  # geometry adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_geometry_tweaks(model, building_type, climate_zone, prototype_input)
    # Set original building North axis
    OpenstudioStandards::Geometry.model_set_building_north_axis(model, 0.0)
    return true
  end
end

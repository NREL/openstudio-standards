# Custom changes for the College prototype.
# These are changes that are inconsistent with other prototype building types.
module College
  # hvac adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [string] the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Bool] returns true if successful, false if not
  def model_custom_hvac_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  def add_door_infiltration(climate_zone, model)
    # add extra infiltration for entry door in m3/s (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      entry_space = model.getSpaceByName('CB_ENTRANCE_LOBBY_F1').get
      infiltration_entrydoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entrydoor.setName('entry door Infiltration')
      infiltration_per_zone_entrydoor = 0
      if template == '90.1-2004'
        infiltration_per_zone_entrydoor = 7.678585
        infiltration_entrydoor.setSchedule(model_add_schedule(model, 'College INFIL_Door_Opening_SCH'))
      elsif template == '90.1-2007'
        case climate_zone
        when 'ASHRAE 169-2006-3A','ASHRAE 169-2006-3B','ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A','ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C'
          infiltration_per_zone_entrydoor = 5.600600
          infiltration_entrydoor.setSchedule(model_add_schedule(model, 'College INFIL_Door_Opening_SCH'))
        else
          infiltration_per_zone_entrydoor = 7.678585
          infiltration_entrydoor.setSchedule(model_add_schedule(model, 'College INFIL_Door_Opening_SCH'))
        end        
      elsif template == '90.1-2010' || template == '90.1-2013'
        case climate_zone
        when 'ASHRAE 169-2006-3A','ASHRAE 169-2006-3B','ASHRAE 169-2006-3C'
          infiltration_per_zone_entrydoor = 5.600600
          infiltration_entrydoor.setSchedule(model_add_schedule(model, 'College INFIL_Door_Opening_SCH'))
        else
         infiltration_per_zone_entrydoor = 7.678585
         infiltration_entrydoor.setSchedule(model_add_schedule(model, 'College INFIL_Door_Opening_SCH'))
        end
      end
    end
  end


  # swh adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [string] the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Bool] returns true if successful, false if not
  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  # geometry adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [string] the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Bool] returns true if successful, false if not
  def model_custom_geometry_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end
end

# Custom changes for the SuperMarket prototype.
# These are changes that are inconsistent with other prototype building types.
module SuperMarket
  # hvac adjustments specific to the prototype model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param building_type [String the building type
  # @param climate_zone [String] ASHRAE climate zone, e.g. 'ASHRAE 169-2013-4A'
  # @param prototype_input [Hash] hash of prototype inputs
  # @return [Boolean] returns true if successful, false if not
  def model_custom_hvac_tweaks(model, building_type, climate_zone, prototype_input)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add humidistat to all spaces
    add_humidistat(model)

    # additional kitchen loads
    add_extra_equip_kitchen(model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # define additional kitchen loads based on AEDG baseline model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] returns true if successful, false if not
  def add_extra_equip_kitchen(model)
    space_names = ['Deli', 'Bakery']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      kitchen_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      kitchen_definition.setName('kitchen load')
      kitchen_definition.setDesignLevel(11674.5)
      kitchen_definition.setFractionLatent(0.25)
      kitchen_definition.setFractionRadiant(0.3)
      kitchen_definition.setFractionLost(0.2)

      kitchen_equipment = OpenStudio::Model::ElectricEquipment.new(kitchen_definition)
      kitchen_equipment.setName('kitchen equipment')
      kitchen_sch = model_add_schedule(model, 'SuperMarketEle Kit Equip Sch')
      kitchen_equipment.setSchedule(kitchen_sch)
      kitchen_equipment.setSpace(space)
    end
    return true
  end

  # add humidistat to all spaces
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] returns true if successful, false if not
  def add_humidistat(model)
    space_names = ['Main Sales', 'Produce', 'West Perimeter Sales', 'East Perimeter Sales', 'Deli', 'Bakery',
                   'Enclosed Office', 'Meeting Room', 'Dining Room', 'Restroom', 'Mechanical Room', 'Corridor', 'Vestibule', 'Active Storage']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      zone = space.thermalZone.get
      humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
      humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'SuperMarket MinRelHumSetSch'))
      humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(model_add_schedule(model, 'SuperMarket MaxRelHumSetSch'))
      zone.setZoneControlHumidistat(humidistat)
    end
    return true
  end

  # update exhuast fan efficiency
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] returns true if successful, false if not
  def model_update_exhaust_fan_efficiency(model)
    model.getFanZoneExhausts.sort.each do |exhaust_fan|
      exhaust_fan.setFanEfficiency(0.45)
      exhaust_fan.setPressureRise(125)
    end
    return true
  end

  # update water heater loss coefficient
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Boolean] returns true if successful, false if not
  def update_waterheater_loss_coefficient(model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019', 'NECB2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
        end
    end
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
    update_waterheater_loss_coefficient(model)

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
    return true
  end
end

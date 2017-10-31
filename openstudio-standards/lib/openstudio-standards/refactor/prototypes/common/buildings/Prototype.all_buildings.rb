require 'openstudio'
require_relative '../objects/Prototype.utilities'
# Modules for building-type specific methods

module FullServiceRestaurant


  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add extra equipment for kitchen
    self.add_extra_equip_kitchen(template, model)
    # add extra infiltration for dining room door and attic
    self.add_door_infiltration(template, climate_zone, model)
    # add zone_mixing between kitchen and dining
    self.add_zone_mixing(template, model)
    # Update Sizing Zone
    self.update_sizing_zone(template, model)
    # adjust the cooling setpoint
    self.adjust_clg_setpoint(template, climate_zone, model)
    # reset the design OA of kitchen
    self.reset_kitchen_oa(template, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # add hvac

  def add_door_infiltration(template, climate_zone, model)
    # add extra infiltration for dining room door and attic (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980' || template == 'NECB 2011'
      dining_space = model.getSpaceByName('Dining').get
      attic_space = model.getSpaceByName('Attic').get
      infiltration_diningdoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_attic = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_diningdoor.setName('Dining door Infiltration')
      infiltration_per_zone_diningdoor = 0
      infiltration_per_zone_attic = 0.2378
      if template == '90.1-2004'
        infiltration_per_zone_diningdoor = 0.614474994
        infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown DOOR_INFIL_SCH'))
      elsif template == '90.1-2007'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B',
              'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C'
            infiltration_per_zone_diningdoor = 0.614474994
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.389828222
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown VESTIBULE_DOOR_INFIL_SCH'))
        end
      elsif template == '90.1-2010' || template == '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C'
            infiltration_per_zone_diningdoor = 0.614474994
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.389828222
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown VESTIBULE_DOOR_INFIL_SCH'))
        end
      end
      infiltration_diningdoor.setDesignFlowRate(infiltration_per_zone_diningdoor)
      infiltration_diningdoor.setSpace(dining_space)
      infiltration_attic.setDesignFlowRate(infiltration_per_zone_attic)
      infiltration_attic.setSchedule(model.add_schedule('Always On'))
      infiltration_attic.setSpace(attic_space)
    end
  end

  def update_exhaust_fan_efficiency(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          fan_name = exhaust_fan.name.to_s
          if fan_name.include? 'Dining'
            exhaust_fan.setFanEfficiency(1)
            exhaust_fan.setPressureRise(0)
          end
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(1)
          exhaust_fan.setPressureRise(0.000001)
        end
    end
  end

  def add_zone_mixing(template, model)
    # add zone_mixing between kitchen and dining
    space_kitchen = model.getSpaceByName('Kitchen').get
    zone_kitchen = space_kitchen.thermalZone.get
    space_dining = model.getSpaceByName('Dining').get
    zone_dining = space_dining.thermalZone.get
    zone_mixing_kitchen = OpenStudio::Model::ZoneMixing.new(zone_kitchen)
    zone_mixing_kitchen.setSchedule(model.add_schedule('RestaurantSitDown Hours_of_operation'))
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        zone_mixing_kitchen.setDesignFlowRate(1.828)
      when '90.1-2007', '90.1-2010', '90.1-2013'
        zone_mixing_kitchen.setDesignFlowRate(1.33143208)
      when '90.1-2004'
        zone_mixing_kitchen.setDesignFlowRate(2.64397817)
    end
    zone_mixing_kitchen.setSourceZone(zone_dining)
    zone_mixing_kitchen.setDeltaTemperature(0)
  end

  # add extra equipment for kitchen
  def add_extra_equip_kitchen(template, model)
    kitchen_space = model.getSpaceByName('Kitchen')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(457.5)
          elec_equip_def2.setDesignLevel(570)
        else
          elec_equip_def1.setDesignLevel(515.917)
          elec_equip_def2.setDesignLevel(851.67)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('RestaurantSitDown ALWAYS_ON'))
        elec_equip2.setSchedule(model.add_schedule('RestaurantSitDown ALWAYS_ON'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip_def1.setDesignLevel(699)
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(1)
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip1.setName('Kitchen_ExhFan_Equip')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('RestaurantSitDown Kitchen_Exhaust_SCH'))
    end
  end

  def update_sizing_zone(template, model)
    case template
      when '90.1-2007', '90.1-2010', '90.1-2013'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.003581176)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
      when '90.1-2004'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.007111554)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
    end
  end

  def adjust_clg_setpoint(template, climate_zone, model)
    ['Dining', 'Kitchen'].each do |space_name|
      space_type_name = model.getSpaceByName(space_name).get.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010'
          if climate_zone == 'ASHRAE 169-2006-2B' || climate_zone == 'ASHRAE 169-2006-1B' || climate_zone == 'ASHRAE 169-2006-3B'
            case space_name
              when 'Dining'
                thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('RestaurantSitDown CLGSETP_SCH_NO_OPTIMUM'))
              when 'Kitchen'
                thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('RestaurantSitDown CLGSETP_KITCHEN_SCH_NO_OPTIMUM'))
            end
          end
      end
    end
  end

  # In order to provide sufficient OSA to replace exhaust flow through kitchen hoods (3,300 cfm),
  # modeled OSA to kitchen is different from OSA determined based on ASHRAE  62.1.
  # It takes into account the available OSA in dining as transfer air.
  def reset_kitchen_oa(template, model)
    space_kitchen = model.getSpaceByName('Kitchen').get
    ventilation = space_kitchen.designSpecificationOutdoorAir.get
    ventilation.setOutdoorAirFlowperPerson(0)
    ventilation.setOutdoorAirFlowperFloorArea(0)
    case template
      when '90.1-2010', '90.1-2013'
        ventilation.setOutdoorAirFlowRate(1.21708392)
      when '90.1-2007'
        ventilation.setOutdoorAirFlowRate(1.50025792)
      when '90.1-2004'
        ventilation.setOutdoorAirFlowRate(1.87711831)
    end
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          if water_heater.name.to_s.include?('Booster')
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
          else
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(9.643286505)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(9.643286505)
          end
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)

    return true
  end
end


# Modules for building-type specific methods

module HighriseApartment

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    # add elevator and lights&fans for the ground floor corridor
    self.add_extra_equip_corridor(template, model)
    # add extra infiltration for ground floor corridor
    self.add_door_infiltration(template, climate_zone, model)

    return true
  end

  # add hvac

  # add elevator and lights&fans for the top floor corridor
  def add_extra_equip_corridor(template, model)
    corridor_top_space = model.getSpaceByName('T Corridor').get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('T Corridor Electric Equipment Definition1')
    elec_equip_def2.setName('T Corridor Electric Equipment Definition2')
    elec_equip_def1.setFractionLatent(0)
    elec_equip_def1.setFractionRadiant(0)
    elec_equip_def1.setFractionLost(0.95)
    elec_equip_def2.setFractionLatent(0)
    elec_equip_def2.setFractionRadiant(0)
    elec_equip_def2.setFractionLost(0.95)
    elec_equip_def1.setDesignLevel(20_370)
    case template
      when '90.1-2013'
        elec_equip_def2.setDesignLevel(63)
      when '90.1-2010'
        elec_equip_def2.setDesignLevel(105.9)
      when '90.1-2004', '90.1-2007'
        elec_equip_def2.setDesignLevel(161.9)
    end
    # Create the electric equipment instance and hook it up to the space type
    elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
    elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
    elec_equip1.setName('T Corridor_Elevators_Equip')
    elec_equip2.setName('Elevators_Lights_Fan')
    elec_equip1.setSpace(corridor_top_space)
    elec_equip2.setSpace(corridor_top_space)
    elec_equip1.setSchedule(model.add_schedule('ApartmentMidRise BLDG_ELEVATORS'))
    case template
      when '90.1-2004', '90.1-2007'
        elec_equip2.setSchedule(model.add_schedule('ApartmentMidRise ELEV_LIGHT_FAN_SCH_24_7'))
      when '90.1-2010', '90.1-2013'
        elec_equip2.setSchedule(model.add_schedule('ApartmentMidRise ELEV_LIGHT_FAN_SCH_ADD_DF'))
    end
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(46.288874618)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(46.288874618)
        end
    end
  end

  # add extra infiltration for ground floor corridor
  def add_door_infiltration(template, climate_zone, model)
    g_corridor = model.getSpaceByName('G Corridor').get
    infiltration_g_corridor_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
    infiltration_g_corridor_door.setName('G Corridor door Infiltration')
    infiltration_g_corridor_door.setSpace(g_corridor)
    case template
      when '90.1-2004'
        infiltration_g_corridor_door.setDesignFlowRate(1.523916863)
        infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentHighRise INFIL_Door_Opening_SCH_0.144'))
      when '90.1-2007', '90.1-2010', '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
            infiltration_g_corridor_door.setDesignFlowRate(1.523916863)
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentHighRise INFIL_Door_Opening_SCH_0.144'))
          else
            infiltration_g_corridor_door.setDesignFlowRate(1.008078792)
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentHighRise INFIL_Door_Opening_SCH_0.131'))
        end
    end
  end

  def update_fan_efficiency(model)
    model.getFanOnOffs.sort.each do |fan_onoff|
      fan_onoff.setFanEfficiency(0.53625)
      fan_onoff.setMotorEfficiency(0.825)
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)

    return true
  end
end


# Modules for building-type specific methods

module Hospital



  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')

    # add extra equipment for kitchen
    self.add_extra_equip_kitchen(template, model)


    system_to_space_map = self.define_hvac_system_map(building_type, template, climate_zone)

    hot_water_loop = nil
    model.getPlantLoops.sort.each do |loop|
      # If it has a boiler:hotwater, it is the correct loop
      unless loop.supplyComponents('OS:Boiler:HotWater'.to_IddObjectType).empty?
        hot_water_loop = loop
      end
    end
    if hot_water_loop
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          space_names = ['ER_Exam3_Mult4_Flr_1', 'OR2_Mult5_Flr_2', 'ICU_Flr_2', 'PatRoom5_Mult10_Flr_4', 'Lab_Flr_3']
          space_names.each do |space_name|
            self.add_humidifier(space_name, template, hot_water_loop, model)
          end
        when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
          space_names = ['ER_Exam3_Mult4_Flr_1', 'OR2_Mult5_Flr_2']
          space_names.each do |space_name|
            self.add_humidifier(space_name, template, hot_water_loop, model)
          end
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Could not find hot water loop to attach humidifier to.')
    end

    self.reset_kitchen_oa(template, model)
    self.update_exhaust_fan_efficiency(template, model)
    self.reset_or_room_vav_minimum_damper(prototype_input, template, model)

    return true
  end

  # add extra equipment for kitchen
  def add_extra_equip_kitchen(template, model)
    kitchen_space = model.getSpaceByName('Kitchen_Flr_5')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(915)
          elec_equip_def2.setDesignLevel(855)
        else
          elec_equip_def1.setDesignLevel(99999.88)
          elec_equip_def2.setDesignLevel(99999.99)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('Hospital ALWAYS_ON'))
        elec_equip2.setSchedule(model.add_schedule('Hospital ALWAYS_ON'))
    end
  end


  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          if water_heater.name.to_s.include?('Booster')
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
          else
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(15.60100708)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(15.60100708)
          end
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)
    return true
  end

  # add swh

  def reset_kitchen_oa(template, model)
    space_kitchen = model.getSpaceByName('Kitchen_Flr_5').get
    ventilation = space_kitchen.designSpecificationOutdoorAir.get
    ventilation.setOutdoorAirFlowperPerson(0)
    ventilation.setOutdoorAirFlowperFloorArea(0)
    case template
      when '90.1-2010', '90.1-2013'
        ventilation.setOutdoorAirFlowRate(3.398)
      when '90.1-2004', '90.1-2007', 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        ventilation.setOutdoorAirFlowRate(3.776)
    end
  end

  def update_exhaust_fan_efficiency(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.16)
          exhaust_fan.setPressureRise(125)
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.338)
          exhaust_fan.setPressureRise(125)
        end
    end
  end

  def add_humidifier(space_name, template, hot_water_loop, model)
    space = model.getSpaceByName(space_name).get
    zone = space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('Hospital MaxRelHumSetSch'))
    zone.setZoneControlHumidistat(humidistat)

    model.getAirLoopHVACs.sort.each do |air_loop|
      if air_loop.thermalZones.include? zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100_000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject.get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
        case template
          when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
            extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
            extra_elec_htg_coil.setName("#{space_name} Electric Htg Coil")
            extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
            extra_water_htg_coil.setName("#{space_name} Water Htg Coil")
            hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
            extra_elec_htg_coil.addToNode(supply_outlet_node)
            extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)
        humidity_spm.setControlZone(zone)
      end
    end
  end

  def add_daylighting_controls(template, model)
    space_names = ['Office1_Flr_5', 'Office3_Flr_5', 'Lobby_Records_Flr_1']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      space.add_daylighting_controls(template, false, false)
    end
  end

  def reset_or_room_vav_minimum_damper(prototype_input, template, model)
    case template
      when '90.1-2004', '90.1-2007'
        return true
      when '90.1-2010', '90.1-2013'
        model.getAirTerminalSingleDuctVAVReheats.sort.each do |airterminal|
          airterminal_name = airterminal.name.get
          if airterminal_name.include?('OR1') || airterminal_name.include?('OR2') || airterminal_name.include?('OR3') || airterminal_name.include?('OR4')
            airterminal.setZoneMinimumAirFlowMethod('Scheduled')
            airterminal.setMinimumAirFlowFractionSchedule(model.add_schedule('Hospital OR_MinSA_Sched'))
          end
        end
    end
  end

  def modify_oa_controller(template, model)
    model.getAirLoopHVACs.sort.each do |air_loop|
      oa_sys = air_loop.airLoopHVACOutdoorAirSystem.get
      oa_control = oa_sys.getControllerOutdoorAir
      case air_loop.name.get
        when 'VAV_ER', 'VAV_ICU', 'VAV_LABS', 'VAV_OR', 'VAV_PATRMS', 'CAV_1', 'CAV_2'
          oa_control.setEconomizerControlType('NoEconomizer')
      end
    end
  end
end


# Modules for building-type specific methods

module LargeHotel

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add extra equipment for kitchen
    self.add_extra_equip_kitchen(template, model)


    # Add Exhaust Fan
    space_type_map = model.define_space_type_map(building_type, template, climate_zone)
    exhaust_fan_space_types = []
    case template
      when '90.1-2004', '90.1-2007'
        exhaust_fan_space_types = ['Kitchen', 'Laundry']
      else
        exhaust_fan_space_types = ['Banquet', 'Kitchen', 'Laundry']
    end

    exhaust_fan_space_types.each do |space_type_name|
      space_type_data = model.find_object($os_standards['space_types'], 'template' => template, 'building_type' => building_type, 'space_type' => space_type_name)
      if space_type_data.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find space type #{template}-#{building_type}-#{space_type_name}")
        return false
      end

      exhaust_schedule = model.add_schedule(space_type_data['exhaust_schedule'])
      if exhaust_schedule.class.to_s == 'NilClass'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find Exhaust Schedule for space type #{template}-#{building_type}-#{space_type_name}")
        return false
      end

      balanced_exhaust_schedule = model.add_schedule(space_type_data['balanced_exhaust_fraction_schedule'])

      space_names = space_type_map[space_type_name]
      space_names.each do |space_name|
        space = model.getSpaceByName(space_name).get
        thermal_zone = space.thermalZone.get

        zone_exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(model)
        zone_exhaust_fan.setName(space.name.to_s + ' Exhaust Fan')
        zone_exhaust_fan.setAvailabilitySchedule(exhaust_schedule)
        zone_exhaust_fan.setFanEfficiency(space_type_data['exhaust_fan_efficiency'])
        zone_exhaust_fan.setPressureRise(space_type_data['exhaust_fan_pressure_rise'])
        maximum_flow_rate = OpenStudio.convert(space_type_data['exhaust_fan_maximum_flow_rate'], 'cfm', 'm^3/s').get

        zone_exhaust_fan.setMaximumFlowRate(maximum_flow_rate)
        if balanced_exhaust_schedule.class.to_s != 'NilClass'
          zone_exhaust_fan.setBalancedExhaustFractionSchedule(balanced_exhaust_schedule)
        end
        zone_exhaust_fan.setEndUseSubcategory('Zone Exhaust Fans')
        zone_exhaust_fan.addToThermalZone(thermal_zone)

        if !space_type_data['exhaust_fan_power'].nil? && space_type_data['exhaust_fan_power'].to_f.nonzero?
          # Create the electric equipment definition
          exhaust_fan_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
          exhaust_fan_equip_def.setName("#{space_name} Electric Equipment Definition")
          exhaust_fan_equip_def.setDesignLevel(space_type_data['exhaust_fan_power'].to_f)
          exhaust_fan_equip_def.setFractionLatent(0)
          exhaust_fan_equip_def.setFractionRadiant(0)
          exhaust_fan_equip_def.setFractionLost(1)

          # Create the electric equipment instance and hook it up to the space type
          exhaust_fan_elec_equip = OpenStudio::Model::ElectricEquipment.new(exhaust_fan_equip_def)
          exhaust_fan_elec_equip.setName("#{space_name} Exhaust Fan Equipment")
          exhaust_fan_elec_equip.setSchedule(exhaust_schedule)
          exhaust_fan_elec_equip.setSpaceType(space.spaceType.get)
        end
      end
    end

    # Update Sizing Zone
    zone_sizing = model.getSpaceByName('Kitchen_Flr_6').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlowFraction(0.7)

    zone_sizing = model.getSpaceByName('Laundry_Flr_1').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlow(0.23567919336)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # add hvac


  # add extra equipment for kitchen
  def add_extra_equip_kitchen(template, model)
    kitchen_space = model.getSpaceByName('Kitchen_Flr_6')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(457.7)
          elec_equip_def2.setDesignLevel(285)
        else
          elec_equip_def1.setDesignLevel(99999.88)
          elec_equip_def2.setDesignLevel(99999.99)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('HotelLarge ALWAYS_ON'))
        elec_equip2.setSchedule(model.add_schedule('HotelLarge ALWAYS_ON'))
      # elec_equip2.setSchedule(model.alwaysOnDiscreteSchedule)
      # elec_equip2.setSchedule(model.alwaysOffDiscreteSchedule)
    end
  end


  # Add the daylighting controls for lobby, cafe, dinning and banquet
  def add_daylighting_controls(template, model)
    space_names = ['Banquet_Flr_6', 'Dining_Flr_6', 'Cafe_Flr_1', 'Lobby_Flr_1']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      space.add_daylighting_controls(template, false, false)
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end


# Modules for building-type specific methods

module LargeOffice

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    system_to_space_map = define_hvac_system_map(building_type, template, climate_zone)

    system_to_space_map.each do |system|
      # find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = model.getSpaceByName(space_name)
        if space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
          return false
        end
        thermal_zones << zone.get
      end

      return_plenum = nil
      unless system['return_plenum'].nil?
        return_plenum_space = model.getSpaceByName(system['return_plenum'])
        if return_plenum_space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model")
          return false
        end
        return_plenum_space = return_plenum_space.get
        return_plenum = return_plenum_space.thermalZone
        if return_plenum.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{system['return_plenum']}")
          return false
        end
        return_plenum = return_plenum.get
      end
    end

    return true
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(11.25413987)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(11.25413987)
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)
    return true
  end
end


# Modules for building-type specific methods

module MediumOffice

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    model.getSpaces.sort.each do |space|
      if space.name.get.to_s == 'Core_bottom'
        model.add_elevator(template,
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
    self.add_door_infiltration(template, climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added door infiltration')

    return true
  end

  # add hvac

  def add_door_infiltration(template, climate_zone, model)
    # add extra infiltration for entry door in m3/s (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      entry_space = model.getSpaceByName('Perimeter_bot_ZN_1').get
      infiltration_entrydoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entrydoor.setName('entry door Infiltration')
      infiltration_per_zone_entrydoor = 0
      if template == '90.1-2004'
        infiltration_per_zone_entrydoor = 1.04300287
        infiltration_entrydoor.setSchedule(model.add_schedule('OfficeMedium INFIL_Door_Opening_SCH'))
      elsif template == '90.1-2007' || template == '90.1-2010'|| template == '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2B'
            infiltration_per_zone_entrydoor = 1.04300287
            infiltration_entrydoor.setSchedule(model.add_schedule('OfficeMedium INFIL_Door_Opening_SCH'))
          else
            infiltration_per_zone_entrydoor = 0.678659786
            infiltration_entrydoor.setSchedule(model.add_schedule('OfficeMedium INFIL_Door_Opening_SCH'))
        end
      end
      infiltration_entrydoor.setDesignFlowRate(infiltration_per_zone_entrydoor)
      infiltration_entrydoor.setSpace(entry_space)
    end
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)

    return true
  end
end


# Modules for building-type specific methods

module MidriseApartment


  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # adjust the cooling setpoint
    self.adjust_clg_setpoint(template, climate_zone, model)
    # add elevator and lights&fans for the ground floor corridor
    self.add_extra_equip_corridor(template, model)
    # add extra infiltration for ground floor corridor
    self.add_door_infiltration(template, climate_zone, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def adjust_clg_setpoint(template, climate_zone, model)
    space_name = 'Office'
    space_type_name = model.getSpaceByName(space_name).get.spaceType.get.name.get
    thermostat_name = space_type_name + ' Thermostat'
    thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010'
        case climate_zone
          when 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-3B'
            thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('ApartmentMidRise CLGSETP_OFF_SCH_NO_OPTIMUM'))
        end
    end
  end

  # add elevator and lights&fans for the ground floor corridor
  def add_extra_equip_corridor(template, model)
    corridor_ground_space = model.getSpaceByName('G Corridor').get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Ground Corridor Electric Equipment Definition1')
    elec_equip_def2.setName('Ground Corridor Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(0.95)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0)
        elec_equip_def2.setFractionLost(0.95)
        elec_equip_def1.setDesignLevel(16_055)
        if template == '90.1-2013'
          elec_equip_def2.setDesignLevel(63)
        elsif template == '90.1-2010'
          elec_equip_def2.setDesignLevel(105.9)
        else
          elec_equip_def2.setDesignLevel(161.9)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('G Corridor_Elevators_Equip')
        elec_equip2.setName('Elevators_Lights_Fan')
        elec_equip1.setSpace(corridor_ground_space)
        elec_equip2.setSpace(corridor_ground_space)
        elec_equip1.setSchedule(model.add_schedule('ApartmentMidRise BLDG_ELEVATORS'))
        case template
          when '90.1-2004', '90.1-2007'
            elec_equip2.setSchedule(model.add_schedule('ApartmentMidRise ELEV_LIGHT_FAN_SCH_24_7'))
          when '90.1-2010', '90.1-2013'
            elec_equip2.setSchedule(model.add_schedule('ApartmentMidRise ELEV_LIGHT_FAN_SCH_ADD_DF'))
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip_def1.setDesignLevel(16_055)
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(0.95)
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip1.setName('G Corridor_Elevators_Equip')
        elec_equip1.setSpace(corridor_ground_space)
        elec_equip1.setSchedule(model.add_schedule('ApartmentMidRise BLDG_ELEVATORS Pre2004'))
    end
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(46.288874618)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(46.288874618)
        end
    end
  end

  # add extra infiltration for ground floor corridor
  def add_door_infiltration(template, climate_zone, model)
    case template
      when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
        # no door infiltration in these two vintages
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        g_corridor = model.getSpaceByName('G Corridor').get
        infiltration_g_corridor_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_g_corridor_door.setName('G Corridor door Infiltration')
        infiltration_g_corridor_door.setSpace(g_corridor)
        case template
          when '90.1-2004'
            infiltration_g_corridor_door.setDesignFlowRate(0.520557541)
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentMidRise INFIL_Door_Opening_SCH_2004_2007'))
          when '90.1-2007'
            case climate_zone
              when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
                infiltration_g_corridor_door.setDesignFlowRate(0.520557541)
              else
                infiltration_g_corridor_door.setDesignFlowRate(0.327531218)
            end
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentMidRise INFIL_Door_Opening_SCH_2004_2007'))
          when '90.1-2010', '90.1-2013'
            case climate_zone
              when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
                infiltration_g_corridor_door.setDesignFlowRate(0.520557541)
              else
                infiltration_g_corridor_door.setDesignFlowRate(0.327531218)
            end
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentMidRise INFIL_Door_Opening_SCH_2010_2013'))
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)

    return true
  end
end


# Modules for building-type specific methods

module Outpatient

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')

    system_to_space_map = self.define_hvac_system_map(building_type, template, climate_zone)

    # add elevator for the elevator pump room (the fan&lights are already added via standard spreadsheet)
    self.add_extra_equip_elevator_pump_room(template, model)
    # adjust cooling setpoint at vintages 1B,2B,3B
    self.adjust_clg_setpoint(template, climate_zone, model)
    # Get the hot water loop
    hot_water_loop = nil
    model.getPlantLoops.sort.each do |loop|
      # If it has a boiler:hotwater, it is the correct loop
      unless loop.supplyComponents('OS:Boiler:HotWater'.to_IddObjectType).empty?
        hot_water_loop = loop
      end
    end
    # add humidifier to AHU1 (contains operating room 1)
    if hot_water_loop
      self.add_humidifier(template, hot_water_loop, model)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Could not find hot water loop to attach humidifier to.')
    end
    # adjust infiltration for vintages 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
    self.adjust_infiltration(template, model)
    # add door infiltration for vertibule
    self.add_door_infiltration(template, climate_zone, model)
    # reset boiler sizing factor to 0.3 (default 1)
    self.reset_boiler_sizing_factor(model)
    # assign the minimum total air changes to the cooling minimum air flow in Sizing:Zone
    self.apply_minimum_total_ach(building_type, template, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')

    return true
  end

  def add_extra_equip_elevator_pump_room(template, model)
    elevator_pump_room = model.getSpaceByName('Floor 1 Elevator Pump Room').get
    elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def.setName('Elevator Pump Room Electric Equipment Definition')
    elec_equip_def.setFractionLatent(0)
    elec_equip_def.setFractionRadiant(0.1)
    elec_equip_def.setFractionLost(0.9)
    elec_equip_def.setDesignLevel(48_165)
    elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
    elec_equip.setName('Elevator Pump Room Elevator Equipment')
    elec_equip.setSpace(elevator_pump_room)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip.setSchedule(model.add_schedule('OutPatientHealthCare BLDG_ELEVATORS'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip.setSchedule(model.add_schedule('OutPatientHealthCare BLDG_ELEVATORS_Pre2004'))
    end
    return true
  end

  def adjust_clg_setpoint(template, climate_zone, model)
    model.getSpaceTypes.sort.each do |space_type|
      space_type_name = space_type.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010'
          case climate_zone
            when 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-3B'
              thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('OutPatientHealthCare CLGSETP_SCH_YES_OPTIMUM'))
          end
      end
    end
    return true
  end

  def adjust_infiltration(template, model)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getSpaces.sort.each do |space|
          space_type = space.spaceType.get
          # Skip interior spaces
          next if space.exterior_wall_and_window_area <= 0
          # Skip spaces that have no infiltration objects to adjust
          next if space_type.spaceInfiltrationDesignFlowRates.size <= 0

          # get the infiltration information from the space type infiltration
          infiltration_space_type = space_type.spaceInfiltrationDesignFlowRates[0]
          infil_sch = infiltration_space_type.schedule.get
          infil_rate = nil
          infil_ach = nil
          if infiltration_space_type.flowperExteriorWallArea.is_initialized
            infil_rate = infiltration_space_type.flowperExteriorWallArea.get
          elsif infiltration_space_type.airChangesperHour.is_initialized
            infil_ach = infiltration_space_type.airChangesperHour.get
          end
          # Create an infiltration rate object for this space
          infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
          infiltration.setName("#{space.name} Infiltration")
          infiltration.setFlowperExteriorSurfaceArea(infil_rate) unless infil_rate.nil? || infil_rate.to_f.zero?
          infiltration.setAirChangesperHour(infil_ach) unless infil_ach.nil? || infil_ach.to_f.zero?
          infiltration.setSchedule(infil_sch)
          infiltration.setSpace(space)
        end
        model.getSpaceTypes.sort.each do |space_type|
          space_type.spaceInfiltrationDesignFlowRates.each(&:remove)
        end
      else
        return true
    end
  end

  def add_door_infiltration(template, climate_zone, model)
    # add extra infiltration for vestibule door
    case template
      when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
        return true
      else
        vestibule_space = model.getSpaceByName('Floor 1 Vestibule').get
        infiltration_vestibule_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_vestibule_door.setName('Vestibule door Infiltration')
        infiltration_rate_vestibule_door = 0
        case template
          when '90.1-2004'
            infiltration_rate_vestibule_door = 1.186002811
            infiltration_vestibule_door.setSchedule(model.add_schedule('OutPatientHealthCare INFIL_Door_Opening_SCH_0.144'))
          when '90.1-2007', '90.1-2010', '90.1-2013'
            case climate_zone
              when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
                infiltration_rate_vestibule_door = 1.186002811
                infiltration_vestibule_door.setSchedule(model.add_schedule('OutPatientHealthCare INFIL_Door_Opening_SCH_0.144'))
              else
                infiltration_rate_vestibule_door = 0.776824762
                infiltration_vestibule_door.setSchedule(model.add_schedule('OutPatientHealthCare INFIL_Door_Opening_SCH_0.131'))
            end
        end
        infiltration_vestibule_door.setDesignFlowRate(infiltration_rate_vestibule_door)
        infiltration_vestibule_door.setSpace(vestibule_space)
    end
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          if water_heater.name.to_s.include?('Booster')
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
          else
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(9.643286505)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(9.643286505)
          end
        end
    end
  end

  # add humidifier to AHU1 (contains operating room1)
  def add_humidifier(template, hot_water_loop, model)
    operatingroom1_space = model.getSpaceByName('Floor 1 Operating Room 1').get
    operatingroom1_zone = operatingroom1_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('OutPatientHealthCare MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('OutPatientHealthCare MaxRelHumSetSch'))
    operatingroom1_zone.setZoneControlHumidistat(humidistat)
    model.getAirLoopHVACs.sort.each do |air_loop|
      if air_loop.thermalZones.include? operatingroom1_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100_000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject.get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
        case template
          when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
            extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
            extra_elec_htg_coil.setName('AHU1 extra Electric Htg Coil')
            extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
            extra_water_htg_coil.setName('AHU1 extra Water Htg Coil')
            hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
            extra_elec_htg_coil.addToNode(supply_outlet_node)
            extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)
        humidity_spm.setControlZone(operatingroom1_zone)
      end
    end
  end

  # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
  # AHU1 doesn't have economizer
  def modify_oa_controller(template, model)
    model.getAirLoopHVACs.sort.each do |air_loop|
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      # AHU1 OA doesn't have controller:mechanicalventilation
      if air_loop.name.to_s.include? 'Outpatient F1'
        controller_mv.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
        # add minimum fraction of outdoor air schedule to AHU1
        controller_oa.setMinimumFractionofOutdoorAirSchedule(model.add_schedule('OutPatientHealthCare AHU-1_OAminOAFracSchedule'))
        # for AHU2, at vintages '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', the minimum OA schedule is not the same as
        # airloop availability schedule, but separately assigned.
      elsif template == '90.1-2004' || template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013'
        controller_oa.setMinimumOutdoorAirSchedule(model.add_schedule('OutPatientHealthCare BLDG_OA_SCH'))
        # add minimum fraction of outdoor air schedule to AHU2
        controller_oa.setMinimumFractionofOutdoorAirSchedule(model.add_schedule('OutPatientHealthCare BLDG_OA_FRAC_SCH'))
      end
    end
  end

  # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
  def reset_or_room_vav_minimum_damper(prototype_input, template, model)
    case template
      when '90.1-2004', '90.1-2007'
        return true
      when '90.1-2010', '90.1-2013'
        model.getAirTerminalSingleDuctVAVReheats.sort.each do |airterminal|
          airterminal_name = airterminal.name.get
          if airterminal_name.include?('Floor 1 Operating Room 1') || airterminal_name.include?('Floor 1 Operating Room 2')
            airterminal.setZoneMinimumAirFlowMethod('Scheduled')
            airterminal.setMinimumAirFlowFractionSchedule(model.add_schedule('OutPatientHealthCare OR_MinSA_Sched'))
          end
        end
    end
  end

  def reset_boiler_sizing_factor(model)
    model.getBoilerHotWaters.sort.each do |boiler|
      boiler.setSizingFactor(0.3)
    end
  end

  def update_exhaust_fan_efficiency(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          fan_name = exhaust_fan.name.to_s
          if (fan_name.include? 'X-Ray') || (fan_name.include? 'MRI Room')
            exhaust_fan.setFanEfficiency(0.16)
            exhaust_fan.setPressureRise(125)
          else
            exhaust_fan.setFanEfficiency(0.31)
            exhaust_fan.setPressureRise(249)
          end
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.338)
          exhaust_fan.setPressureRise(125)
        end
    end
  end

  # assign the minimum total air changes to the cooling minimum air flow in Sizing:Zone
  def apply_minimum_total_ach(building_type, template, model)
    model.getSpaces.sort.each do |space|
      space_type_name = space.spaceType.get.standardsSpaceType.get
      search_criteria = {
          'template' => template,
          'building_type' => building_type,
          'space_type' => space_type_name
      }
      data = model.find_object($os_standards['space_types'], search_criteria)

      if data.nil? ###
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Could not find data for #{search_criteria}")
        next
      end

      # skip space type without minimum total air changes
      next if data['minimum_total_air_changes'].nil?

      # calculate the minimum total air flow
      minimum_total_ach = data['minimum_total_air_changes'].to_f
      space_volume = space.volume
      space_area = space.floorArea
      minimum_airflow_per_zone = minimum_total_ach * space_volume / 3600
      minimum_airflow_per_zone_floor_area = minimum_airflow_per_zone / space_area
      # add minimum total air flow limit to sizing:zone
      zone = space.thermalZone.get
      sizingzone = zone.sizingZone
      sizingzone.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
      case template
        when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
          sizingzone.setCoolingMinimumAirFlow(minimum_airflow_per_zone)
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          sizingzone.setCoolingMinimumAirFlowperZoneFloorArea(minimum_airflow_per_zone_floor_area)
      end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)

    return true
  end
end


# Modules for building-type specific methods

module PrimarySchool

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    #
    # add extra equipment for kitchen
    self.add_extra_equip_kitchen(template, model)
    return true
  end


  # add extra equipment for kitchen
  def add_extra_equip_kitchen(template, model)
    kitchen_space = model.getSpaceByName('Kitchen_ZN_1_FLR_1')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(915)
          elec_equip_def2.setDesignLevel(570)
        else
          elec_equip_def1.setDesignLevel(99999.88)
          elec_equip_def2.setDesignLevel(99999.99)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('SchoolPrimary ALWAYS_ON'))
        elec_equip2.setSchedule(model.add_schedule('SchoolPrimary ALWAYS_ON'))
    end
  end


  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end


# Modules for building-type specific methods

module QuickServiceRestaurant

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add extra equipment for kitchen
    self.add_extra_equip_kitchen(template, model)
    # add extra infiltration for dining room door and attic
    self.add_door_infiltration(template, climate_zone, model)
    # add zone_mixing between kitchen and dining
    self.add_zone_mixing(template, model)
    # Update Sizing Zone
    self.update_sizing_zone(template, model)
    # adjust the cooling setpoint
    self.adjust_clg_setpoint(template, climate_zone, model)
    # reset the design OA of kitchen
    self.reset_kitchen_oa(template, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def add_door_infiltration(template, climate_zone, model)
    # add extra infiltration for dining room door and attic (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      dining_space = model.getSpaceByName('Dining').get
      attic_space = model.getSpaceByName('Attic').get
      infiltration_diningdoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_attic = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_diningdoor.setName('Dining door Infiltration')
      infiltration_per_zone_diningdoor = 0
      infiltration_per_zone_attic = 0.0729
      if template == '90.1-2004'
        infiltration_per_zone_diningdoor = 0.902834611
        infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood DOOR_INFIL_SCH'))
      elsif template == '90.1-2007'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B',
              'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C'
            infiltration_per_zone_diningdoor = 0.902834611
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.583798439
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood VESTIBULE_DOOR_INFIL_SCH'))
        end
      elsif template == '90.1-2010' || template == '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C'
            infiltration_per_zone_diningdoor = 0.902834611
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.583798439
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood VESTIBULE_DOOR_INFIL_SCH'))
        end
      end
      infiltration_diningdoor.setDesignFlowRate(infiltration_per_zone_diningdoor)
      infiltration_diningdoor.setSpace(dining_space)
      infiltration_attic.setDesignFlowRate(infiltration_per_zone_attic)
      infiltration_attic.setSchedule(model.add_schedule('Always On'))
      infiltration_attic.setSpace(attic_space)
    end
  end

  # add extra equipment for kitchen
  def add_extra_equip_kitchen(template, model)
    kitchen_space = model.getSpaceByName('Kitchen')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(457.5)
          elec_equip_def2.setDesignLevel(570)
        else
          elec_equip_def1.setDesignLevel(515.917)
          elec_equip_def2.setDesignLevel(851.67)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('RestaurantFastFood ALWAYS_ON'))
        elec_equip2.setSchedule(model.add_schedule('RestaurantFastFood ALWAYS_ON'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip_def1.setDesignLevel(577)
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(1)
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip1.setName('Kitchen_ExhFan_Equip')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('RestaurantFastFood Kitchen_Exhaust_SCH'))
    end
  end

  def update_sizing_zone(template, model)
    case template
      when '90.1-2007', '90.1-2010', '90.1-2013'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.003581176)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
      when '90.1-2004'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.007111554)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
    end
  end

  def adjust_clg_setpoint(template, climate_zone, model)
    ['Dining', 'Kitchen'].each do |space_name|
      space_type_name = model.getSpaceByName(space_name).get.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010'
          if climate_zone == 'ASHRAE 169-2006-2B' || climate_zone == 'ASHRAE 169-2006-1B' || climate_zone == 'ASHRAE 169-2006-3B'
            case space_name
              when 'Dining'
                thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('RestaurantFastFood CLGSETP_SCH_NO_OPTIMUM'))
              when 'Kitchen'
                thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('RestaurantFastFood CLGSETP_KITCHEN_SCH_NO_OPTIMUM'))
            end
          end
      end
    end
  end

  # In order to provide sufficient OSA to replace exhaust flow through kitchen hoods (3,300 cfm),
  # modeled OSA to kitchen is different from OSA determined based on ASHRAE  62.1.
  # It takes into account the available OSA in dining as transfer air.
  def reset_kitchen_oa(template, model)
    space_kitchen = model.getSpaceByName('Kitchen').get
    ventilation = space_kitchen.designSpecificationOutdoorAir.get
    ventilation.setOutdoorAirFlowperPerson(0)
    ventilation.setOutdoorAirFlowperFloorArea(0)
    case template
      when '90.1-2007', '90.1-2010', '90.1-2013'
        ventilation.setOutdoorAirFlowRate(1.14135966)
      when '90.1-2004', 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        ventilation.setOutdoorAirFlowRate(0.7312)
    end
  end

  def update_exhaust_fan_efficiency(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          fan_name = exhaust_fan.name.to_s
          if fan_name.include? 'Dining'
            exhaust_fan.setFanEfficiency(1)
            exhaust_fan.setPressureRise(0)
          end
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(1)
          exhaust_fan.setPressureRise(0.000001)
        end
    end
  end

  def add_zone_mixing(template, model)
    # add zone_mixing between kitchen and dining
    space_kitchen = model.getSpaceByName('Kitchen').get
    zone_kitchen = space_kitchen.thermalZone.get
    space_dining = model.getSpaceByName('Dining').get
    zone_dining = space_dining.thermalZone.get
    zone_mixing_kitchen = OpenStudio::Model::ZoneMixing.new(zone_kitchen)
    zone_mixing_kitchen.setSchedule(model.add_schedule('RestaurantFastFood Hours_of_operation'))
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        zone_mixing_kitchen.setDesignFlowRate(0.834532374)
      when '90.1-2007', '90.1-2010', '90.1-2013'
        zone_mixing_kitchen.setDesignFlowRate(0.416067345)
      when '90.1-2004'
        zone_mixing_kitchen.setDesignFlowRate(0.826232888)
    end
    zone_mixing_kitchen.setSourceZone(zone_dining)
    zone_mixing_kitchen.setDeltaTemperature(0)
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)

    return true
  end
end


# Extend the class to add Medium Office specific stuff

module RetailStandalone
  # TODO: The ElectricEquipment schedules are wrong in OpenStudio Standards... It needs to be 'RetailStandalone BLDG_EQUIP_SCH' for 90.1-2010 at least but probably all
  # TODO: There is an OpenStudio bug where two heat exchangers are on the equipment list and it references the same single heat exchanger for both. This doubles the heat recovery energy.
  # TODO: The HeatExchangerAirToAir is not calculating correctly. It does not equal the legacy IDF and has higher energy usage due to that.
  # TODO: Need to determine if WaterHeater can be alone or if we need to 'fake' it.



  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # Add the door infiltration for template 2004,2007,2010,2013
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        entry_space = model.getSpaceByName('Front_Entry').get
        infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_entry.setName('Entry door Infiltration')
        infiltration_per_zone = 1.418672682
        infiltration_entry.setDesignFlowRate(infiltration_per_zone)
        infiltration_entry.setSchedule(model.add_schedule('RetailStandalone INFIL_Door_Opening_SCH'))
        infiltration_entry.setSpace(entry_space)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(4.10807252)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(4.10807252)
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)

    return true
  end
end


# Modules for building-type specific methods

module RetailStripmall

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    system_to_space_map = self.define_hvac_system_map(building_type, template, climate_zone)

    # Add infiltration door opening
    # Spaces names to design infiltration rates (m3/s)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        door_infiltration_map = {['LGstore1', 'LGstore2'] => 0.388884328,
                                 ['SMstore1', 'SMstore2', 'SMstore3', 'SMstore4', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8'] => 0.222287037}

        door_infiltration_map.each_pair do |space_names, infiltration_design_flowrate|
          space_names.each do |space_name|
            space = model.getSpaceByName(space_name).get
            # Create the infiltration object and hook it up to the space type
            infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
            infiltration.setName("#{space_name} Door Open Infiltration")
            infiltration.setSpace(space)
            infiltration.setDesignFlowRate(infiltration_design_flowrate)
            infiltration_schedule = model.add_schedule('RetailStripmall INFIL_Door_Opening_SCH')
            if infiltration_schedule.nil?
              OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Can't find schedule (RetailStripmall INFIL_Door_Opening_SCH).")
              return false
            else
              infiltration.setSchedule(infiltration_schedule)
            end
          end
        end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')
    return true
  end

  # add hvac

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.205980747)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.205980747)
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)

    return true
  end
end


# Modules for building-type specific methods

module SecondarySchool

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    #
    # add extra equipment for kitchen
    self.add_extra_equip_kitchen(template, model)

    model.getSpaces.sort.each do |space|
      if space.name.get.to_s == 'Mech_ZN_1_FLR_1'
        model.add_elevator(template,
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

    return true
  end

  # add extra equipment for kitchen
  def add_extra_equip_kitchen(template, model)
    kitchen_space = model.getSpaceByName('Kitchen_ZN_1_FLR_1')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(915)
          elec_equip_def2.setDesignLevel(570)
        else
          elec_equip_def1.setDesignLevel(99999.88)
          elec_equip_def2.setDesignLevel(99999.99)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('SchoolSecondary ALWAYS_ON'))
        elec_equip2.setSchedule(model.add_schedule('SchoolSecondary ALWAYS_ON'))
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end


# Modules for building-type specific methods

module SmallHotel

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add elevator for the elevator coreflr1  (the elevator lift already added via standard spreadsheet)
    self.add_extra_equip_elevator_coreflr1(template, model)

    # add extra infiltration for corridor1 door
    corridor_space = model.getSpaceByName('CorridorFlr1')
    corridor_space = corridor_space.get
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      infiltration_corridor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_corridor.setName('Corridor1 door Infiltration')
      infiltration_per_zone = 0
      infiltration_per_zone = if template == '90.1-2010' || template == '90.1-2007'
                                0.591821538
                              else
                                0.91557718
                              end
      infiltration_corridor.setDesignFlowRate(infiltration_per_zone)
      infiltration_corridor.setSchedule(model.add_schedule('HotelSmall INFIL_Door_Opening_SCH'))
      infiltration_corridor.setSpace(corridor_space)
    end

    # hardsize corridor1. put in standards in the future  #TODO
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      model.getZoneHVACPackagedTerminalAirConditioners.sort.each do |ptac|
        zone = ptac.thermalZone.get
        if zone.spaces.include?(corridor_space)
          ptac.setSupplyAirFlowRateDuringCoolingOperation(0.13)
          ptac.setSupplyAirFlowRateDuringHeatingOperation(0.13)
          ptac.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(0.13)
          ccoil = ptac.coolingCoil
          if ccoil.to_CoilCoolingDXSingleSpeed.is_initialized
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedTotalCoolingCapacity(2638) # Unit: W
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedAirFlowRate(0.13)
          end
        end
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # add this for elevator lights/fans (elevator lift is implemented through standard lookup)
  def add_extra_equip_elevator_coreflr1(template, model)
    elevator_coreflr1 = model.getSpaceByName('ElevatorCoreFlr1').get
    elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def.setName('Elevator CoreFlr1 Electric Equipment Definition')
    elec_equip_def.setFractionLatent(0)
    elec_equip_def.setFractionRadiant(0.5)
    elec_equip_def.setFractionLost(0.0)
    elec_equip_def.setDesignLevel(125)
    elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
    elec_equip.setName('Elevator Coreflr1 Elevator Lights/Fans Equipment')
    elec_equip.setSpace(elevator_coreflr1)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip.setSchedule(model.add_schedule('HotelSmall ELEV_LIGHT_FAN_SCH_ADD_DF'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip.setSchedule(model.add_schedule('HotelSmall ELEV_LIGHT_FAN_SCH_ADD_DF'))
    end
    return true
  end


  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end


# Extend the class to add Small Office specific stuff

module SmallOffice

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end


# Modules for building-type specific methods

module SuperMarket

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add humidistat to all spaces
    self.add_humidistat(template, model)

    # additional kitchen loads
    self.add_extra_equip_kitchen(template, model)

    # reset bakery & deli OA reset
    self.reset_bakery_deli_oa(template, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  # define additional kitchen loads based on AEDG baseline model
  def add_extra_equip_kitchen(template, model)
    space_names = ['Deli', 'Bakery']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      kitchen_definition = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
      kitchen_definition.setName("kitchen load")
      kitchen_definition.setDesignLevel(11674.5)
      kitchen_definition.setFractionLatent(0.25)
      kitchen_definition.setFractionRadiant(0.3)
      kitchen_definition.setFractionLost(0.2)

      kitchen_equipment = OpenStudio::Model::ElectricEquipment.new(kitchen_definition)
      kitchen_equipment.setName("kitchen equipment")
      kitchen_sch = model.add_schedule("SuperMarketEle Kit Equip Sch")
      kitchen_equipment.setSchedule(kitchen_sch)
      kitchen_equipment.setSpace(space)
    end
  end

  # add humidistat to all spaces
  def add_humidistat(template, model)
    space_names = ['Main Sales', 'Produce', 'West Perimeter Sales', 'East Perimeter Sales', 'Deli', 'Bakery',
                   'Enclosed Office', 'Meeting Room', 'Dining Room', 'Restroom', 'Mechanical Room', 'Corridor', 'Vestibule', 'Active Storage']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      zone = space.thermalZone.get
      humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
      humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('SuperMarket MinRelHumSetSch'))
      humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('SuperMarket MaxRelHumSetSch'))
      zone.setZoneControlHumidistat(humidistat)
    end
  end

  # Update exhuast fan efficiency
  def update_exhaust_fan_efficiency(template, model)
    model.getFanZoneExhausts.sort.each do |exhaust_fan|
      exhaust_fan.setFanEfficiency(0.45)
      exhaust_fan.setPressureRise(125)
    end
  end

  #reset bakery & deli OA from AEDG baseline model
  def reset_bakery_deli_oa(template, model)
    space_names = ['Deli', 'Bakery']
    space_names.each do |space_name|
      space_kitchen = model.getSpaceByName(space_name).get
      ventilation = space_kitchen.designSpecificationOutdoorAir.get
      ventilation.setOutdoorAirFlowperPerson(0)
      ventilation.setOutdoorAirFlowperFloorArea(0.0015)
      #case template
      #when '90.1-2004','90.1-2007','90.1-2010', '90.1-2013'
      #  ventilation.setOutdoorAirFlowRate(4.27112436)
      #end
    end
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)

    return true
  end
end


# Modules for building-type specific methods

module Warehouse

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end

  def update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
        end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    self.update_waterheater_loss_coefficient(template, model)
    return true
  end
end


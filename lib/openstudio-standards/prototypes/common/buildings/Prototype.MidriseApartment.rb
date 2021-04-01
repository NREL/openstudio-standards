# Custom changes for the MidriseApartment prototype.
# These are changes that are inconsistent with other prototype
# building types.
module MidriseApartment
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # adjust the cooling setpoint
    adjust_clg_setpoint(climate_zone, model)
    # add elevator and lights&fans for the ground floor corridor
    add_extra_equip_corridor(model)
    # add extra infiltration for ground floor corridor
    add_door_infiltration(climate_zone, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def adjust_clg_setpoint(climate_zone, model)
    space_name = 'Office'
    space_type_name = model.getSpaceByName(space_name).get.spaceType.get.name.get
    thermostat_name = space_type_name + ' Thermostat'
    thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010'
        case climate_zone
          when 'ASHRAE 169-2006-0B',
               'ASHRAE 169-2006-1B',
               'ASHRAE 169-2006-2B',
               'ASHRAE 169-2006-3B',
               'ASHRAE 169-2013-0B',
               'ASHRAE 169-2013-1B',
               'ASHRAE 169-2013-2B',
               'ASHRAE 169-2013-3B'
            thermostat.setCoolingSetpointTemperatureSchedule(model_add_schedule(model, 'ApartmentMidRise CLGSETP_OFF_SCH_NO_OPTIMUM'))
        end
    end
  end

  # add elevator and lights&fans for the ground floor corridor
  def add_extra_equip_corridor(model)
    corridor_ground_space = model.getSpaceByName('G Corridor').get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Ground Corridor Electric Equipment Definition1')
    elec_equip_def2.setName('Ground Corridor Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(0.95)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0)
        elec_equip_def2.setFractionLost(0.95)
        elec_equip_def1.setDesignLevel(16_055)
        if template == '90.1-2013' || template == '90.1-2016' || template == '90.1-2019'
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
        elec_equip1.setSchedule(model_add_schedule(model, 'ApartmentMidRise BLDG_ELEVATORS'))
        case template
          when '90.1-2004', '90.1-2007'
            elec_equip2.setSchedule(model_add_schedule(model, 'ApartmentMidRise ELEV_LIGHT_FAN_SCH_24_7'))
          when '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
            elec_equip2.setSchedule(model_add_schedule(model, 'ApartmentMidRise ELEV_LIGHT_FAN_SCH_ADD_DF'))
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
        elec_equip1.setSchedule(model_add_schedule(model, 'ApartmentMidRise BLDG_ELEVATORS Pre2004'))
    end
  end

  # add extra infiltration for ground floor corridor
  def add_door_infiltration(climate_zone, model)
    case template
      when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
        # no door infiltration in these two vintages
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
        g_corridor = model.getSpaceByName('G Corridor').get
        infiltration_g_corridor_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_g_corridor_door.setName('G Corridor door Infiltration')
        infiltration_g_corridor_door.setSpace(g_corridor)
        case template
          when '90.1-2004'
            infiltration_g_corridor_door.setDesignFlowRate(0.520557541)
            infiltration_g_corridor_door.setSchedule(model_add_schedule(model, 'ApartmentMidRise INFIL_Door_Opening_SCH_2004_2007'))
          when '90.1-2007'
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
                infiltration_g_corridor_door.setDesignFlowRate(0.520557541)
              else
                infiltration_g_corridor_door.setDesignFlowRate(0.327531218)
            end
            infiltration_g_corridor_door.setSchedule(model_add_schedule(model, 'ApartmentMidRise INFIL_Door_Opening_SCH_2004_2007'))
          when '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019'
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
                infiltration_g_corridor_door.setDesignFlowRate(0.520557541)
              else
                infiltration_g_corridor_door.setDesignFlowRate(0.327531218)
            end
            infiltration_g_corridor_door.setSchedule(model_add_schedule(model, 'ApartmentMidRise INFIL_Door_Opening_SCH_2010_2013'))
        end

        # Door infiltration in model not impacted by wind or temperature
        infiltration_g_corridor_door.setConstantTermCoefficient(1.0)
        infiltration_g_corridor_door.setTemperatureTermCoefficient(0.0)
        infiltration_g_corridor_door.setVelocityTermCoefficient(0.0)
        infiltration_g_corridor_door.setVelocitySquaredTermCoefficient(0.0)
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)
    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)
    # Set original building North axis
    model_set_building_north_axis(model, 0.0)

    return true
  end
end

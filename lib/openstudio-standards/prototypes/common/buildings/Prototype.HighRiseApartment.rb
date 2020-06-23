
# Custom changes for the HighriseApartment prototype.
# These are changes that are inconsistent with other prototype
# building types.
module HighriseApartment
  def model_custom_hvac_tweaks(building_type, climate_zone, prototype_input, model)
    # add elevator and lights&fans for the ground floor corridor
    add_extra_equip_corridor(model)
    # add extra infiltration for ground floor corridor
    add_door_infiltration(climate_zone, model)

    # add transformer
    case template
    when '90.1-2004', '90.1-2007'
      transformer_efficiency = 0.966
    when '90.1-2010', '90.1-2013'
      transformer_efficiency = 0.98
    end

    model_add_transformer(model,
                          wired_lighting_frac: 0.0015,
                          transformer_size: 75000,
                          transformer_efficiency: transformer_efficiency,
                          excluded_interiorequip_key: 'T Corridor_Elevators_Equip',
                          excluded_interiorequip_meter: 'Electric Equipment Electric Energy')

    return true
  end

  # add hvac

  # add elevator and lights&fans for the top floor corridor
  def add_extra_equip_corridor(model)
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
    elec_equip1.setSchedule(model_add_schedule(model, 'ApartmentMidRise BLDG_ELEVATORS'))
    case template
      when '90.1-2004', '90.1-2007'
        elec_equip2.setSchedule(model_add_schedule(model, 'ApartmentMidRise ELEV_LIGHT_FAN_SCH_24_7'))
      when '90.1-2010', '90.1-2013'
        elec_equip2.setSchedule(model_add_schedule(model, 'ApartmentMidRise ELEV_LIGHT_FAN_SCH_ADD_DF'))
    end
  end

  # add extra infiltration for ground floor corridor
  def add_door_infiltration(climate_zone, model)
    g_corridor = model.getSpaceByName('G Corridor').get
    infiltration_g_corridor_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
    infiltration_g_corridor_door.setName('G Corridor door Infiltration')
    infiltration_g_corridor_door.setSpace(g_corridor)
    case template
      when '90.1-2004'
        infiltration_g_corridor_door.setDesignFlowRate(1.523916863)
        infiltration_g_corridor_door.setSchedule(model_add_schedule(model, 'ApartmentHighRise INFIL_Door_Opening_SCH_0.144'))
      when '90.1-2007', '90.1-2010', '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A',
               'ASHRAE 169-2006-2A',
               'ASHRAE 169-2006-2B',
               'ASHRAE 169-2013-1A',
               'ASHRAE 169-2013-2A',
               'ASHRAE 169-2013-2B'
            infiltration_g_corridor_door.setDesignFlowRate(1.523916863)
            infiltration_g_corridor_door.setSchedule(model_add_schedule(model, 'ApartmentHighRise INFIL_Door_Opening_SCH_0.144'))
          else
            infiltration_g_corridor_door.setDesignFlowRate(1.008078792)
            infiltration_g_corridor_door.setSchedule(model_add_schedule(model, 'ApartmentHighRise INFIL_Door_Opening_SCH_0.131'))
        end
    end
  end

  def model_update_fan_efficiency(model)
    model.getFanOnOffs.sort.each do |fan_onoff|
      fan_onoff.setFanEfficiency(0.53625)
      fan_onoff.setMotorEfficiency(0.825)
    end
  end

  def model_custom_swh_tweaks(model, building_type, climate_zone, prototype_input)

    return true
  end

  def model_custom_geometry_tweaks(building_type, climate_zone, prototype_input, model)

    return true
  end
end

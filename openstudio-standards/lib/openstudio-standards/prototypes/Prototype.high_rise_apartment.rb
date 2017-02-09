
# Modules for building-type specific methods
module PrototypeBuilding
module HighriseApartment
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template

    when 'NECB 2011'
      space_type_map = {
        'Office - enclosed' => ['Office'],
        "Corr. < 2.4m wide-sch-#{sch}" => ['T Corridor', 'G Corridor', 'F2 Corridor', 'F3 Corridor', 'F4 Corridor', 'M Corridor', 'F6 Corridor', 'F7 Corridor', 'F8 Corridor', 'F9 Corridor'],
        'Dwelling Unit(s)' => [
          'G SW Apartment',
          'G NW Apartment',
          'G NE Apartment',
          'G N1 Apartment',
          'G N2 Apartment',
          'G S1 Apartment',
          'G S2 Apartment',
          'F2 SW Apartment',
          'F2 NW Apartment',
          'F2 SE Apartment',
          'F2 NE Apartment',
          'F2 N1 Apartment',
          'F2 N2 Apartment',
          'F2 S1 Apartment',
          'F2 S2 Apartment',
          'F3 SW Apartment',
          'F3 NW Apartment',
          'F3 SE Apartment',
          'F3 NE Apartment',
          'F3 N1 Apartment',
          'F3 N2 Apartment',
          'F3 S1 Apartment',
          'F3 S2 Apartment',
          'F4 SW Apartment',
          'F4 NW Apartment',
          'F4 SE Apartment',
          'F4 NE Apartment',
          'F4 N1 Apartment',
          'F4 N2 Apartment',
          'F4 S1 Apartment',
          'F4 S2 Apartment',
          'M SW Apartment',
          'M NW Apartment',
          'M SE Apartment',
          'M NE Apartment',
          'M N1 Apartment',
          'M N2 Apartment',
          'M S1 Apartment',
          'M S2 Apartment',
          'F6 SW Apartment',
          'F6 NW Apartment',
          'F6 SE Apartment',
          'F6 NE Apartment',
          'F6 N1 Apartment',
          'F6 N2 Apartment',
          'F6 S1 Apartment',
          'F6 S2 Apartment',
          'F7 SW Apartment',
          'F7 NW Apartment',
          'F7 SE Apartment',
          'F7 NE Apartment',
          'F7 N1 Apartment',
          'F7 N2 Apartment',
          'F7 S1 Apartment',
          'F7 S2 Apartment',
          'F8 SW Apartment',
          'F8 NW Apartment',
          'F8 SE Apartment',
          'F8 NE Apartment',
          'F8 N1 Apartment',
          'F8 N2 Apartment',
          'F8 S1 Apartment',
          'F8 S2 Apartment',
          'F9 SW Apartment',
          'F9 NW Apartment',
          'F9 SE Apartment',
          'F9 NE Apartment',
          'F9 N1 Apartment',
          'F9 N2 Apartment',
          'F9 S1 Apartment',
          'F9 S2 Apartment',
          'T SW Apartment',
          'T NW Apartment',
          'T SE Apartment',
          'T NE Apartment',
          'T N1 Apartment',
          'T N2 Apartment',
          'T S1 Apartment',
          'T S2 Apartment'
        ]
      }

    else
      space_type_map = {
        'Office' => ['Office'],
        'Corridor' => ['G Corridor', 'F2 Corridor', 'F3 Corridor', 'F4 Corridor', 'M Corridor', 'F6 Corridor', 'F7 Corridor', 'F8 Corridor', 'F9 Corridor'],
        'Corridor_topfloor' => ['T Corridor'],
        'Apartment' => [
          'G SW Apartment',
          'G NW Apartment',
          'G NE Apartment',
          'G N1 Apartment',
          'G N2 Apartment',
          'G S1 Apartment',
          'G S2 Apartment',
          'F2 SW Apartment',
          'F2 NW Apartment',
          'F2 SE Apartment',
          'F2 NE Apartment',
          'F2 N1 Apartment',
          'F2 N2 Apartment',
          'F2 S1 Apartment',
          'F2 S2 Apartment',
          'F3 SW Apartment',
          'F3 NW Apartment',
          'F3 SE Apartment',
          'F3 NE Apartment',
          'F3 N1 Apartment',
          'F3 N2 Apartment',
          'F3 S1 Apartment',
          'F3 S2 Apartment',
          'F4 SW Apartment',
          'F4 NW Apartment',
          'F4 SE Apartment',
          'F4 NE Apartment',
          'F4 N1 Apartment',
          'F4 N2 Apartment',
          'F4 S1 Apartment',
          'F4 S2 Apartment',
          'M SW Apartment',
          'M NW Apartment',
          'M SE Apartment',
          'M NE Apartment',
          'M N1 Apartment',
          'M N2 Apartment',
          'M S1 Apartment',
          'M S2 Apartment',
          'F6 SW Apartment',
          'F6 NW Apartment',
          'F6 SE Apartment',
          'F6 NE Apartment',
          'F6 N1 Apartment',
          'F6 N2 Apartment',
          'F6 S1 Apartment',
          'F6 S2 Apartment',
          'F7 SW Apartment',
          'F7 NW Apartment',
          'F7 SE Apartment',
          'F7 NE Apartment',
          'F7 N1 Apartment',
          'F7 N2 Apartment',
          'F7 S1 Apartment',
          'F7 S2 Apartment',
          'F8 SW Apartment',
          'F8 NW Apartment',
          'F8 SE Apartment',
          'F8 NE Apartment',
          'F8 N1 Apartment',
          'F8 N2 Apartment',
          'F8 S1 Apartment',
          'F8 S2 Apartment',
          'F9 SW Apartment',
          'F9 NW Apartment',
          'F9 SE Apartment',
          'F9 NE Apartment',
          'F9 N1 Apartment',
          'F9 N2 Apartment',
          'F9 S1 Apartment',
          'F9 S2 Apartment'
        ],
        'Apartment_topfloor_WE' => [
          'T SW Apartment',
          'T NW Apartment',
          'T SE Apartment',
          'T NE Apartment'
        ],
        'Apartment_topfloor_NS' => [
          'T N1 Apartment',
          'T N2 Apartment',
          'T S1 Apartment',
          'T S2 Apartment'
        ]
      }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
      { 'type' => 'PSZ-AC',
        'space_names' => ['G SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['G NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['G NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['G N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['G N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['G S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['G S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F2 SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F2 NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F2 SE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F2 NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F2 N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F2 N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F2 S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F2 S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F3 SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F3 NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F3 SE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F3 NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F3 N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F3 N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F3 S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F3 S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F4 SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F4 NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F4 SE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F4 NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F4 N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F4 N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F4 S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F4 S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['M SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['M NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['M SE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['M NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['M N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['M N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['M S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['M S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F6 SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F6 NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F6 SE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F6 NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F6 N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F6 N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F6 S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F6 S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F7 SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F7 NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F7 SE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F7 NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F7 N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F7 N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F7 S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F7 S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F8 SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F8 NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F8 SE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F8 NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F8 N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F8 N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F8 S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F8 S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F9 SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F9 NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F9 SE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F9 NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F9 N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F9 N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F9 S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['F9 S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['T SW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['T NW Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['T SE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['T NE Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['T N1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['T N2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['T S1 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['T S2 Apartment'] },
      { 'type' => 'PSZ-AC',
        'space_names' => ['Office'] }
    ]

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    # add elevator and lights&fans for the ground floor corridor
    PrototypeBuilding::HighriseApartment.add_extra_equip_corridor(template, model)
    # add extra infiltration for ground floor corridor
    PrototypeBuilding::HighriseApartment.add_door_infiltration(template, climate_zone, model)

    return true
  end # add hvac

  # add elevator and lights&fans for the top floor corridor
  def self.add_extra_equip_corridor(template, model)
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

  def self.update_waterheater_loss_coefficient(template, model)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      model.getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(46.288874618)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(46.288874618)
      end
    end
  end

  # add extra infiltration for ground floor corridor
  def self.add_door_infiltration(template, climate_zone, model)
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

  def self.update_fan_efficiency(model)
    model.getFanOnOffs.sort.each do |fan_onoff|
      fan_onoff.setFanEfficiency(0.53625)
      fan_onoff.setMotorEfficiency(0.825)
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::HighriseApartment.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
end

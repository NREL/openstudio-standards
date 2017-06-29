
# Modules for building-type specific methods
module PrototypeBuilding
module MidriseApartment
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil

    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      space_type_map = {
        'Office' => ['Office'],
        'Corridor' => ['G Corridor', 'M Corridor'],
        'Corridor_topfloor' => ['T Corridor'],
        'Apartment' => [
          'G SW Apartment',
          'G NW Apartment',
          'G NE Apartment',
          'G N1 Apartment',
          'G N2 Apartment',
          'G S1 Apartment',
          'G S2 Apartment',
          'M SW Apartment',
          'M NW Apartment',
          'M SE Apartment',
          'M NE Apartment',
          'M N1 Apartment',
          'M N2 Apartment',
          'M S1 Apartment',
          'M S2 Apartment'
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
    when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
      space_type_map = {
        'Office' => ['Office'],
        'Corridor' => ['G Corridor', 'M Corridor', 'T Corridor'],
        'Apartment' => [
          'G SW Apartment',
          'G NW Apartment',
          'G NE Apartment',
          'G N1 Apartment',
          'G N2 Apartment',
          'G S1 Apartment',
          'G S2 Apartment',
          'M SW Apartment',
          'M NW Apartment',
          'M SE Apartment',
          'M NE Apartment',
          'M N1 Apartment',
          'M N2 Apartment',
          'M S1 Apartment',
          'M S2 Apartment',
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

    when 'NECB 2011'
      sch = 'G'
      space_type_map = {
        "Corr. < 2.4m wide-sch-#{sch}" => ['G Corridor', 'M Corridor', 'T Corridor'],

        'Dwelling Unit(s)' => ['G N1 Apartment', 'G N2 Apartment', 'G NE Apartment',
                               'G NW Apartment', 'G S1 Apartment', 'G S2 Apartment',
                               'G SW Apartment', 'M N1 Apartment', 'M N2 Apartment',
                               'M NE Apartment', 'M NW Apartment', 'M S1 Apartment',
                               'M S2 Apartment', 'M SE Apartment', 'M SW Apartment',
                               'T N1 Apartment', 'T N2 Apartment', 'T NE Apartment',
                               'T NW Apartment', 'T S1 Apartment', 'T S2 Apartment',
                               'T SE Apartment', 'T SW Apartment'],
        'Conf./meet./multi-purpose' => ['Office']
      }
    end

    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
      { 'type' => 'SAC',
        'space_names' => ['G SW Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['G NW Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['G NE Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['G N1 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['G N2 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['G S1 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['G S2 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['M SW Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['M NW Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['M SE Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['M NE Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['M N1 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['M N2 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['M S1 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['M S2 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['T SW Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['T NW Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['T SE Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['T NE Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['T N1 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['T N2 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['T S1 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['T S2 Apartment'] },
      { 'type' => 'SAC',
        'space_names' => ['Office'] }
    ]

    case template
    when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
      system_to_space_map.push('type' => 'UnitHeater', 'space_names' => ['G Corridor'])
      system_to_space_map.push('type' => 'UnitHeater', 'space_names' => ['M Corridor'])
      system_to_space_map.push('type' => 'UnitHeater', 'space_names' => ['T Corridor'])
    end

    return system_to_space_map
  end

  def self.define_space_multiplier
    building_type = 'MidriseApartment'
    # This map define the multipliers for spaces with multipliers not equals to 1
    space_multiplier_map = JSON.parse(File.read(File.join(File.dirname(__FILE__),"../../../data/geometry/archetypes/#{building_type}.json")))[building_type]['space_multiplier_map']
    return space_multiplier_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # adjust the cooling setpoint
    PrototypeBuilding::MidriseApartment.adjust_clg_setpoint(template, climate_zone, model)
    # add elevator and lights&fans for the ground floor corridor
    PrototypeBuilding::MidriseApartment.add_extra_equip_corridor(template, model)
    # add extra infiltration for ground floor corridor
    PrototypeBuilding::MidriseApartment.add_door_infiltration(template, climate_zone, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def self.adjust_clg_setpoint(template, climate_zone, model)
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
  def self.add_extra_equip_corridor(template, model)
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

  def self.update_waterheater_loss_coefficient(template, model)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      model.getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(46.288874618)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(46.288874618)
      end
    end
  end

  # add extra infiltration for ground floor corridor
  def self.add_door_infiltration(template, climate_zone, model)
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

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::MidriseApartment.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
end

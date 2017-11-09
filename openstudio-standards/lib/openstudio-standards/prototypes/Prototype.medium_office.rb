
# Modules for building-type specific methods
module PrototypeBuilding
module MediumOffice
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    space_type_map = case template
    when 'NECB 2011'
      {
        '- undefined -' => ['FirstFloor_Plenum', 'TopFloor_Plenum', 'MidFloor_Plenum'],
        'Office - open plan' => ['Core_bottom', 'Core_mid', 'Core_top', 'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4']

      }
    else
      { 
        'WholeBuilding - Md Office' => ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom', 'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid', 'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'],
    '- undefined -' => ['FirstFloor_Plenum', 'TopFloor_Plenum', 'MidFloor_Plenum']
      }
                     end
    return space_type_map.sort.to_h
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = case template
    when 'DOE Ref Pre-1980'
      [
        {
          'type' => 'PSZ-AC',

          'space_names' =>
              ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom', 'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid', 'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top']
        }
      ]
    else
      [
        {
          'type' => 'PVAV',
          'space_names' =>
            ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom'],
          'return_plenum' => 'FirstFloor_Plenum'
        },
        {
          'type' => 'PVAV',
          'space_names' =>
            ['Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid'],
          'return_plenum' => 'MidFloor_Plenum'
        },
        {
          'type' => 'PVAV',
          'space_names' =>
            ['Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'],
          'return_plenum' => 'TopFloor_Plenum'
        }
      ]
                          end
    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
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
    PrototypeBuilding::MediumOffice.add_door_infiltration(template, climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Added door infiltration')
  
    return true
  end # add hvac

  def self.add_door_infiltration(template, climate_zone, model)
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

  def self.update_waterheater_loss_coefficient(template, model)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      model.getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
      end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::MediumOffice.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
end

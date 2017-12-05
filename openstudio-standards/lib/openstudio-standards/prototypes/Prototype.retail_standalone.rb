
# Extend the class to add Medium Office specific stuff
module PrototypeBuilding
module RetailStandalone
  # TODO: The ElectricEquipment schedules are wrong in OpenStudio Standards... It needs to be 'RetailStandalone BLDG_EQUIP_SCH' for 90.1-2010 at least but probably all
  # TODO: There is an OpenStudio bug where two heat exchangers are on the equipment list and it references the same single heat exchanger for both. This doubles the heat recovery energy.
  # TODO: The HeatExchangerAirToAir is not calculating correctly. It does not equal the legacy IDF and has higher energy usage due to that.
  # TODO: Need to determine if WaterHeater can be alone or if we need to 'fake' it.

  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
    when 'NECB 2011'
      sch = 'C'
      space_type_map = {
        'Storage area' => ['Back_Space'],
        'Retail - sales' => ['Core_Retail', 'Front_Retail', 'Point_Of_Sale'],
        'Lobby - elevator' => ['Front_Entry']
      }

    else
      space_type_map = {
        'Back_Space' => ['Back_Space'],
        'Entry' => ['Front_Entry'],
        'Point_of_Sale' => ['Point_Of_Sale'],
        'Core_Retail' => ['Core_Retail'],
        'Front_Retail' => ['Front_Retail']
      }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
      {
        'type' => 'PSZ-AC',
        'space_names' => ['Back_Space', 'Core_Retail', 'Point_Of_Sale', 'Front_Retail']
      },
      {
        'type' => 'UnitHeater',
        'space_names' => ['Front_Entry']
      }
    ]
    return system_to_space_map
  end


  # def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    # OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # # Add the door infiltration for template 2004,2007,2010,2013
    # case template
    # when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      # entry_space = model.getSpaceByName('Front_Entry').get
      # infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      # infiltration_entry.setName('Entry door Infiltration')
      # infiltration_per_zone = 1.418672682
      # infiltration_entry.setDesignFlowRate(infiltration_per_zone)
      # infiltration_entry.setSchedule(model.add_schedule('RetailStandalone INFIL_Door_Opening_SCH'))
      # infiltration_entry.setSpace(entry_space)
    # end

    # OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    # return true
  # end
  
  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # Add the door infiltration for template 2004,2007,2010,2013
    case template
    when '90.1-2004'
      entry_space = model.getSpaceByName('Front_Entry').get
      infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entry.setName('Entry door Infiltration')
      infiltration_per_zone = 1.418672682
      infiltration_entry.setDesignFlowRate(infiltration_per_zone)
      infiltration_entry.setSchedule(model.add_schedule('RetailStandalone INFIL_Door_Opening_SCH'))        
      infiltration_entry.setSpace(entry_space)
    
    # temporal solution for CZ dependent door infiltration rate.  In fact other standards need similar change as well
    when '90.1-2007', '90.1-2010', '90.1-2013'
      entry_space = model.getSpaceByName('Front_Entry').get
      infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_entry.setName('Entry door Infiltration')
      case climate_zone
      when 'ASHRAE 169-2006-1A','ASHRAE 169-2006-1B','ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
        infiltration_per_zone = 1.418672682    
        infiltration_entry.setSchedule(model.add_schedule('RetailStandalone INFIL_Door_Opening_SCH')) 
      else
        infiltration_per_zone = 0.937286742
        infiltration_entry.setSchedule(model.add_schedule('RetailStandalone INFIL_Door_Opening_SCH_2013')) 
      end
      infiltration_entry.setDesignFlowRate(infiltration_per_zone)               
      infiltration_entry.setSpace(entry_space)    
    end
    
    # add these additional coefficient inputs
    infiltration_entry.setConstantTermCoefficient(1.0)
    infiltration_entry.setTemperatureTermCoefficient(0.0)
    infiltration_entry.setVelocityTermCoefficient(0.0)
    infiltration_entry.setVelocitySquaredTermCoefficient(0.0)    

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      model.getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(4.10807252)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(4.10807252)
      end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::RetailStandalone.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
end

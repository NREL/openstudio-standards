
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  # TODO: The ElectricEquipment schedules are wrong in OpenStudio Standards... It needs to be 'RetailStandalone BLDG_EQUIP_SCH' for 90.1-2010 at least but probably all
  # TODO: There is an OpenStudio bug where two heat exchangers are on the equipment list and it references the same single heat exchanger for both. This doubles the heat recovery energy.
  # TODO: The HeatExchangerAirToAir is not calculating correctly. It does not equal the legacy IDF and has higher energy usage due to that.
  # TODO: Need to determine if WaterHeater can be alone or if we need to 'fake' it.

  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {
      'Back_Space' => ['Back_Space'],
      'Entry' => ['Front_Entry'],
      'Point_of_Sale' => ['Point_Of_Sale'],
      'Retail' => ['Core_Retail', 'Front_Retail']
    }
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
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
     
  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # Add the door infiltration for vintage 2004,2007,2010,2013
    case building_vintage
      when '90.1-2004','90.1-2007','90.1-2010','90.1-2013'
        entry_space = self.getSpaceByName('Front_Entry').get
        infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(self)
        infiltration_entry.setName("Entry door Infiltration")
        infiltration_per_zone = 1.418672682
        infiltration_entry.setDesignFlowRate(infiltration_per_zone)
        infiltration_entry.setSchedule(add_schedule('RetailStandalone INFIL_Door_Opening_SCH'))
        infiltration_entry.setSpace(entry_space)
      else
        # do nothing
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')
    
    return true
    
  end

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    # water_heater = add_water_heater(prototype_input, hvac_standards, 'main', true)
    # water_heater.setOffCycleParasiticFuelConsumptionRate(1860)
    # water_heater.setOnCycleParasiticFuelConsumptionRate(1860)
    # water_heater.setOffCycleLossCoefficienttoAmbientTemperature(4.10807252)
    # water_heater.setOnCycleLossCoefficienttoAmbientTemperature(4.10807252)
    # water_heater.setOffCycleParasiticHeatFractiontoTank(0)
    case building_vintage
      when '90.1-2004','90.1-2007','90.1-2010','90.1-2013'
        main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
        self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
        water_heaters = main_swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)

        water_heaters.each do |water_heater|
          water_heater = water_heater.to_WaterHeaterMixed.get
          # water_heater.setAmbientTemperatureIndicator('Zone')
          # water_heater.setAmbientTemperatureThermalZone(default_water_heater_ambient_temp_sch)
          water_heater.setOffCycleParasiticFuelConsumptionRate(1860)
          water_heater.setOnCycleParasiticFuelConsumptionRate(1860)
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(4.10807252)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(4.10807252)
        end
        OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
      else
        # No Water heater for pre1980 and post1980-2004 vintages
    end

    return true
    
  end #add swh
  
end

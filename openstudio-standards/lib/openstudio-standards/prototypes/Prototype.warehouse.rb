
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model

  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {
      'Bulk' => ['Zone3 Bulk Storage'],
      'Fine' => ['Zone2 Fine Storage'],
      'Office' => ['Zone1 Office']
    }
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    system_to_space_map = [
      {
          'type' => 'CAV',
          'name' => 'HVAC_1',
          'space_names' => ['Zone1 Office']
      },
      {
          'type' => 'CAV',
          'name' => 'HVAC_2',
          'space_names' => ['Zone2 Fine Storage']
      },
      {
          'type' => 'UnitHeater',
          'name' => 'HVAC_3',
          'space_names' => ['Zone3 Bulk Storage']
      }
    ]
    return system_to_space_map
  end

  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    return true

  end

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
    case building_vintage
    when 'DOE Ref Pre-1980','DOE Ref 1980-2004','DOE Ref 2004'
      # no SWH system
    else

      OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

      main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
      water_heaters = main_swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)

      water_heaters.each do |water_heater|
        water_heater = water_heater.to_WaterHeaterMixed.get
        # water_heater.setAmbientTemperatureIndicator('Zone')
        # water_heater.setAmbientTemperatureThermalZone(default_water_heater_ambient_temp_sch)
        water_heater.setOffCycleParasiticFuelConsumptionRate(481)
        water_heater.setOnCycleParasiticFuelConsumptionRate(481)
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
      end

      self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')

      OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")

    end

    return true

  end #add swh

end

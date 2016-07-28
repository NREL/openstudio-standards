
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
  def define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil

    space_type_map = case template

    when 'NECB 2011'
      # dom =A
      {
        'Warehouse - med/blk' => ['Zone3 Bulk Storage'],
        'Warehouse - fine' => ['Zone2 Fine Storage'],
        'Office - enclosed' => ['Zone1 Office']
      }
    else
      {
        'Bulk' => ['Zone3 Bulk Storage'],
        'Fine' => ['Zone2 Fine Storage'],
        'Office' => ['Zone1 Office']
      }
                     end
    return space_type_map
  end

  def define_hvac_system_map(building_type, template, climate_zone)
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      system_to_space_map = [
        {
          'type' => 'PSZ-AC',
          'name' => 'HVAC_1',
          'space_names' => ['Zone1 Office']
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'HVAC_2',
          'space_names' => ['Zone2 Fine Storage']
        },
        {
          'type' => 'UnitHeater',
          'name' => 'HVAC_3',
          'space_names' => ['Zone3 Bulk Storage']
        },
        {
          'type' => 'Zone Ventilation',
          'name' => 'Bulk Storage Zone Ventilation - Intake',
          'availability_sch_name' => 'Warehouse MinOA_Sched',
          'flow_rate' => 0.00025, # in m^3/s-m^2
          'ventilation_type' => 'Intake',
          'space_names' => ['Zone3 Bulk Storage']
        }
      ]
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      system_to_space_map = [
        {
          'type' => 'PSZ-AC',
          'name' => 'HVAC_1',
          'space_names' => ['Zone1 Office']
        },
        {
          'type' => 'PSZ-AC',
          'name' => 'HVAC_2',
          'space_names' => ['Zone2 Fine Storage']
        },
        {
          'type' => 'UnitHeater',
          'name' => 'HVAC_3',
          'space_names' => ['Zone3 Bulk Storage']
        },
        {
          'type' => 'Zone Ventilation',
          'name' => 'Bulk Storage Zone Ventilation - Exhaust',
          'availability_sch_name' => 'Always On',
          'flow_rate' => OpenStudio.convert(80008.9191, 'cfm', 'm^3/s').get,
          'ventilation_type' => 'Exhaust',
          'space_names' => ['Zone3 Bulk Storage']
        },
        {
          'type' => 'Zone Ventilation',
          'name' => 'Bulk Storage Zone Ventilation - Natural',
          'availability_sch_name' => 'Always On',
          'flow_rate' => OpenStudio.convert(2000, 'cfm', 'm^3/s').get,
          'ventilation_type' => 'Natural',
          'space_names' => ['Zone3 Bulk Storage']
        }
      ]
    end

    return system_to_space_map
  end

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input)
    return true
  end

  def update_waterheater_loss_coefficient(template)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
      end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(template)

    return true
  end
end

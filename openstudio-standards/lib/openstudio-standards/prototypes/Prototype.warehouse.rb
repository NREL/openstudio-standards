
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model

  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = nil
    
    case building_vintage
  
    when 'NECB 2011'
      space_type_map ={
        "Warehouse - med/blk" => ["Zone3 Bulk Storage"],
        "Warehouse - fine" => ["Zone2 Fine Storage"],
        "Office - enclosed" => ["Zone1 Office"]
      }
    else
      space_type_map = {
        'Bulk' => ['Zone3 Bulk Storage'],
        'Fine' => ['Zone2 Fine Storage'],
        'Office' => ['Zone1 Office']
      }
    end
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
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
      }
    ]
    return system_to_space_map
  end

  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    return true

  end

  def update_waterheater_loss_coefficient(building_vintage)
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      self.getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
      end
    end      
  end  
  
  def custom_swh_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    self.update_waterheater_loss_coefficient(building_vintage)
  
    return true

  end


end

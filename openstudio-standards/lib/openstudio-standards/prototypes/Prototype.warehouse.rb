
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model

  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = nil
    
    case building_vintage
  
    when 'NECB 2011'
      space_type_map ={
        "Warehouse - med/blk" => ["BulkStorage"],
        "Warehouse - fine" => ["FineStorage"],
        "Office - enclosed" => ["Office"]
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
<<<<<<< HEAD
        'type' => 'CAV',
        'space_names' => ['Zone1 Office']
      },
      {
        'type' => 'CAV',
        'space_names' => ['Zone2 Fine Storage']
      },
      {
        'type' => 'Unit_Heater',
        'space_names' => ['Zone3 Bulk Storage']
=======
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
>>>>>>> remotes/origin/master
      }
    ]
    return system_to_space_map
  end

  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    return true

  end

  def update_waterheater_loss_coefficient(building_vintage)
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      self.getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
      end
    end      
  end  
  
  def custom_swh_tweaks(building_type, building_vintage, climate_zone, prototype_input)

    self.update_waterheater_loss_coefficient(building_vintage)
  
    return true
<<<<<<< HEAD
    
  end #add hvac

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")
=======
>>>>>>> remotes/origin/master

  end

<<<<<<< HEAD
    case building_vintage
    when 'NECB 2011'
      space_type_map.each do |space_type_name, space_names|
        space_names.each do |space_name|
          space = self.getSpaceByName(space_name).get
          space_multiplier = space.multiplier
          self.add_swh_end_uses_by_space('Space Function', building_vintage, climate_zone, main_swh_loop, space_type_name, space_name, space_multiplier)
        end   
      end        
    end
      
      
    # for i in 0..13
    #   self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    # end
    # self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh
  
=======
>>>>>>> remotes/origin/master
end

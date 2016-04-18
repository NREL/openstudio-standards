
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = nil
    case building_vintage 
    when 'NECB 2011'
      space_type_map ={
        "Office - open plan" => ["Core_bottom", "Core_mid", "Core_top", 
          "Perimeter_bot_ZN_1", "Perimeter_bot_ZN_2", "Perimeter_bot_ZN_3", 
          "Perimeter_bot_ZN_4", "Perimeter_mid_ZN_1", "Perimeter_mid_ZN_2", 
          "Perimeter_mid_ZN_3", "Perimeter_mid_ZN_4", "Perimeter_top_ZN_1", 
          "Perimeter_top_ZN_2", "Perimeter_top_ZN_3", "Perimeter_top_ZN_4"],
        
        "- undefined -" => ["FirstFloor_Plenum", "TopFloor_Plenum", "MidFloor_Plenum"]
      }
    else
      space_type_map = {
        'WholeBuilding - Md Office' => [
          'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom',
          'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid',
          'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'
        ]
      }
    end
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    case building_vintage
    when 'DOE Ref Pre-1980'
      system_to_space_map = [
<<<<<<< HEAD
        {
          'type' => 'PSZ',
=======
      {
          'type' => 'PSZ-AC',
>>>>>>> remotes/origin/master
          'space_names' =>
            [
            'Perimeter_bot_ZN_1',
            'Perimeter_bot_ZN_2',
            'Perimeter_bot_ZN_3',
            'Perimeter_bot_ZN_4',
            'Core_bottom',
            'Perimeter_mid_ZN_1',
            'Perimeter_mid_ZN_2',
            'Perimeter_mid_ZN_3',
            'Perimeter_mid_ZN_4',
            'Core_mid',
            'Perimeter_top_ZN_1',
            'Perimeter_top_ZN_2',
            'Perimeter_top_ZN_3',
            'Perimeter_top_ZN_4',
            'Core_top'
          ]
        }
      ]
    else
      system_to_space_map = [
        {
          'type' => 'PVAV',
          'space_names' =>
            [
            'Perimeter_bot_ZN_1',
            'Perimeter_bot_ZN_2',
            'Perimeter_bot_ZN_3',
            'Perimeter_bot_ZN_4',
            'Core_bottom'
          ],
          'return_plenum' => 'FirstFloor_Plenum'
        },
        {
          'type' => 'PVAV',
          'space_names' =>
            [
            'Perimeter_mid_ZN_1',
            'Perimeter_mid_ZN_2',
            'Perimeter_mid_ZN_3',
            'Perimeter_mid_ZN_4',
            'Core_mid'
          ],
          'return_plenum' => 'MidFloor_Plenum'
        },
        {
          'type' => 'PVAV',
          'space_names' =>
            [
            'Perimeter_top_ZN_1',
            'Perimeter_top_ZN_2',
            'Perimeter_top_ZN_3',
            'Perimeter_top_ZN_4',
            'Core_top'
          ],
          'return_plenum' => 'TopFloor_Plenum'
        }
      ]
    end
    return system_to_space_map
  end
     
  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')
    
    self.getSpaces.each do |space|
    
      if space.name.get.to_s == "Core_bottom"
        self.add_elevator(building_vintage,
                         space,
                         prototype_input['number_of_elevators'],
                         prototype_input['elevator_type'],
                         prototype_input['elevator_schedule'],
                         prototype_input['elevator_fan_schedule'],
                         prototype_input['elevator_fan_schedule'],
                         building_type)
      end    
    
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')
    
    return true
    
  end #add hvac

  def update_waterheater_loss_coefficient(building_vintage)
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      self.getWaterHeaterMixeds.sort.each do |water_heater|
        water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
        water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
      end
<<<<<<< HEAD
    end

    # spaces = define_space_type_map(building_type, building_vintage, climate_zone)['WholeBuilding - Md Office']

    unless building_vintage == 'NECB 2011'
    
      space_type_map.each do |space_type_name, space_names|
        space_names.each do |space_name|
          if building_vintage == 'DOE Ref 1980-2004' or building_vintage == 'DOE Ref Pre-1980'
            if space_name == 'Core_bottom' || space_name == 'Core_mid' || space_name == 'Core_top'
              self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
            end
          else
            self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
          end
        end
      end
    
    end

    if building_vintage == 'NECB 2011'  
      space_type_map.each do |space_type_name, space_names|
        space_names.each do |space_name|
          space = self.getSpaceByName(space_name).get
          space_multiplier = space.multiplier
          self.add_swh_end_uses_by_space('Space Function', building_vintage, climate_zone, main_swh_loop, space_type_name, space_name, space_multiplier)
        end   
      end
    end
    
    
    # spaces.each do |space|
    #   self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    # end

    # for i in 0..13
    #   self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    # end
    # self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
=======
    end      
  end  
   
  def custom_swh_tweaks(building_type, building_vintage, climate_zone, prototype_input)
   
    self.update_waterheater_loss_coefficient(building_vintage)
>>>>>>> remotes/origin/master
    
    return true
    
  end

end

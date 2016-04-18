
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = nil
    case building_vintage
    when 'NECB 2011'
      space_type_map ={
        "Electrical/Mechanical" => ["Basement"],
        "Corr. >= 2.4m wide" => ["Corridor_Flr_1", "Corridor_Flr_2", "Corridor_Flr_5", "Corridor_NW_Flr_3", "Corridor_NW_Flr_4", "Corridor_SE_Flr_3", "Corridor_SE_Flr_4"],
        "Dining - bar lounge/leisure" => ["Dining_Flr_5"],
        "Hospital - emergency" => ["ER_Exam1_Mult4_Flr_1", "ER_Exam3_Mult4_Flr_1", "ER_Trauma1_Flr_1", "ER_Trauma2_Flr_1", "ER_Triage_Mult4_Flr_1"],
        "Hospital - nurses' station" => ["ER_NurseStn_Lobby_Flr_1", "ICU_NurseStn_Lobby_Flr_2", "NurseStn_Lobby_Flr_3", "NurseStn_Lobby_Flr_4", "NurseStn_Lobby_Flr_5", "OR_NurseStn_Lobby_Flr_2"],
        "Hospital - patient room" => ["IC_PatRoom1_Mult5_Flr_2", "IC_PatRoom2_Flr_2", "IC_PatRoom3_Mult6_Flr_2", "PatRoom1_Mult10_Flr_3", "PatRoom1_Mult10_Flr_4", "PatRoom2_Flr_3", "PatRoom2_Flr_4", "PatRoom3_Mult10_Flr_3", "PatRoom3_Mult10_Flr_4", "PatRoom4_Flr_3", "PatRoom4_Flr_4", "PatRoom5_Mult10_Flr_3", "PatRoom5_Mult10_Flr_4", "PatRoom6_Flr_3", "PatRoom6_Flr_4", "PatRoom7_Mult10_Flr_3", "PatRoom7_Mult10_Flr_4", "PatRoom8_Flr_3", "PatRoom8_Flr_4"],
        "Hospital - recovery" => ["ICU_Flr_2"],
        "Food preparation" => ["Kitchen_Flr_5"],
        "Lab - research" => ["Lab_Flr_3", "Lab_Flr_4"],
        "Office - enclosed" => ["Lobby_Records_Flr_1", "Office1_Flr_5", "Office1_Mult4_Flr_1", "Office2_Mult5_Flr_5", "Office3_Flr_5", "Office4_Mult6_Flr_5"],
        "Hospital - operating room" => ["OR1_Flr_2", "OR2_Mult5_Flr_2", "OR3_Flr_2", "OR4_Flr_2"],
        "Hospital - physical therapy" => ["PhysTherapy_Flr_3"],
        "Hospital - radiology/imaging" => ["Radiology_Flr_4"]
      }
    
    else
      space_type_map = {
        # 'Basement', 'ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1', 'Office1_Mult4_Flr_1', 'Lobby_Records_Flr_1', 'Corridor_Flr_1', 'ER_NurseStn_Lobby_Flr_1', 'OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2', 'IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', 'ICU_Flr_2', 'ICU_NurseStn_Lobby_Flr_2', 'Corridor_Flr_2', 'OR_NurseStn_Lobby_Flr_2', 'PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PhysTherapy_Flr_3', 'PatRoom6_Flr_3', 'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'NurseStn_Lobby_Flr_3', 'Lab_Flr_3', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 'PatRoom5_Mult10_Flr_4', 'Radiology_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4', 'NurseStn_Lobby_Flr_4', 'Lab_Flr_4', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Dining_Flr_5', 'NurseStn_Lobby_Flr_5', 'Kitchen_Flr_5', 'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Corridor_Flr_5'
        'Corridor' => ['Corridor_Flr_1', 'Corridor_Flr_2', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Corridor_Flr_5'],
        'Dining' => ['Dining_Flr_5', ],
        'ER_Exam' => ['ER_Exam1_Mult4_Flr_1', 'ER_Exam3_Mult4_Flr_1', ],
        'ER_NurseStn' => ['ER_NurseStn_Lobby_Flr_1', ],
        'ER_Trauma' => ['ER_Trauma1_Flr_1', 'ER_Trauma2_Flr_1', ],
        'ER_Triage' => ['ER_Triage_Mult4_Flr_1', ],
        'ICU_NurseStn' => ['ICU_NurseStn_Lobby_Flr_2', ],
        'ICU_Open' => ['ICU_Flr_2', ],
        'ICU_PatRm' => ['IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', ],
        'Kitchen' => ['Kitchen_Flr_5', ],
        'Lab' => ['Lab_Flr_3', 'Lab_Flr_4', ],
        'Lobby' => ['Lobby_Records_Flr_1', ],
        'NurseStn' => ['OR_NurseStn_Lobby_Flr_2', 'NurseStn_Lobby_Flr_3', 'NurseStn_Lobby_Flr_4', 'NurseStn_Lobby_Flr_5', ],
        'OR' => ['OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2', ],
        'Office' => ['Office1_Mult4_Flr_1', 'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Basement', ], # I don't know where to put Basement
        # 'PatCorridor' => [],
        'PatRoom' => ['PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PatRoom6_Flr_3', 
          'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 'PatRoom5_Mult10_Flr_4', 
          'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4', ],
        'PhysTherapy' => ['PhysTherapy_Flr_3', ],
        'Radiology' => ['Radiology_Flr_4', ]
      }
    end
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    system_to_space_map = [
      {
        'type' => 'VAV',
        'space_names' => [
          'Basement', 'Office1_Mult4_Flr_1', 'Lobby_Records_Flr_1', 'Corridor_Flr_1', 'ER_NurseStn_Lobby_Flr_1', 
          'ICU_NurseStn_Lobby_Flr_2', 'Corridor_Flr_2', 'OR_NurseStn_Lobby_Flr_2'
        ]
      },
      {
        'type' => 'VAV',
        'space_names' => [
          'ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1'
        ]
      },
      {
        'type' => 'VAV',
        'space_names' => [
          'OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2'
        ]
      },
      {
        'type' => 'VAV',
        'space_names' => [
          'IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', 'ICU_Flr_2'
        ]
      },
      {
        'type' => 'VAV',
        'space_names' => [
          'PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PatRoom6_Flr_3', 
          'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 
          'PatRoom5_Mult10_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4'
        ]
      },
      {
        'type' => 'VAV',
        'space_names' => [
          'PhysTherapy_Flr_3', 'NurseStn_Lobby_Flr_3', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'Radiology_Flr_4', 
          'NurseStn_Lobby_Flr_4', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Dining_Flr_5', 'NurseStn_Lobby_Flr_5', 
          'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Corridor_Flr_5'
        ]
      },
      {
        'type' => 'VAV',
        'space_names' => [
          'Lab_Flr_3', 'Lab_Flr_4'
        ]
      },
      {
        'type' => 'CAV',
        'space_names' => [
          'Kitchen_Flr_5'
        ]
      }
    ]
    return system_to_space_map
  end
     
  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)
   
    return true
    
  end

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
    water_heaters = main_swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)
    
    water_heaters.each do |water_heater|
      water_heater = water_heater.to_WaterHeaterMixed.get
      # water_heater.setAmbientTemperatureIndicator('Zone')
      # water_heater.setAmbientTemperatureThermalZone(default_water_heater_ambient_temp_sch)
      water_heater.setOffCycleParasiticFuelConsumptionRate(720)
      water_heater.setOnCycleParasiticFuelConsumptionRate(720)
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
    end

    self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh    

end

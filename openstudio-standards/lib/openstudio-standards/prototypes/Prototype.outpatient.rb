
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {
      # 'Floor 1 Anesthesia', 'Floor 1 Bio Haz', 'Floor 1 Cafe', 'Floor 1 Clean', 'Floor 1 Clean Work', 'Floor 1 Dictation', 'Floor 1 Dressing Room', 'Floor 1 Electrical Room', 'Floor 1 Elevator Pump Room', 'Floor 1 Humid', 'Floor 1 IT Hall', 'Floor 1 IT Room', 'Floor 1 Lobby', 'Floor 1 Lobby Hall', 'Floor 1 Lobby Toilet', 'Floor 1 Locker Room', 'Floor 1 Locker Room Hall', 'Floor 1 Lounge', 'Floor 1 Med Gas', 'Floor 1 MRI Control Room', 'Floor 1 MRI Hall', 'Floor 1 MRI Room', 'Floor 1 MRI Toilet', 'Floor 1 Nourishment', 'Floor 1 Nurse Hall', 'Floor 1 Nurse Janitor', 'Floor 1 Nurse Station', 'Floor 1 Nurse Toilet', 'Floor 1 Office', 'Floor 1 Operating Room 1', 'Floor 1 Operating Room 2', 'Floor 1 Operating Room 3', 'Floor 1 PACU', 'Floor 1 Pre-Op Hall', 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2', 'Floor 1 Pre-Op Toilet', 'Floor 1 Procedure Room', 'Floor 1 Reception', 'Floor 1 Reception Hall', 'Floor 1 Recovery Room', 'Floor 1 Scheduling', 'Floor 1 Scrub', 'Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work', 'Floor 1 Step Down', 'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Storage', 'Floor 1 Sub-Sterile', 'Floor 1 Utility Hall', 'Floor 1 Utility Janitor', 'Floor 1 Utility Room', 'Floor 1 Vestibule', 'Floor 2 Conference', 'Floor 2 Conference Toilet', 'Floor 2 Dictation', 'Floor 2 Exam 1', 'Floor 2 Exam 2', 'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7', 'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Janitor', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1', 'Floor 2 Nurse Station 2', 'Floor 2 Office', 'Floor 2 Office Hall', 'Floor 2 Reception', 'Floor 2 Reception Hall', 'Floor 2 Reception Toilet', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', 'Floor 2 Storage 1', 'Floor 2 Storage 2', 'Floor 2 Storage 3', 'Floor 2 Utility', 'Floor 2 Work', 'Floor 2 Work Hall', 'Floor 2 Work Toilet', 'Floor 2 X-Ray', 'Floor 3 Dressing Room', 'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Janitor', 'Floor 3 Locker', 'Floor 3 Lounge', 'Floor 3 Lounge Toilet', 'Floor 3 Mechanical', 'Floor 3 Mechanical Hall', 'Floor 3 Office', 'Floor 3 Office Hall', 'Floor 3 Office Toilet', 'Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2', 'Floor 3 Physical Therapy Toilet', 'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Treatment', 'Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2', 'Floor 3 Utility', 'Floor 3 Work', 'NE Stair', 'NW Elevator', 'NW Stair', 'SW Stair'
      
      # TODO: still need to put these into their space types...
      # 'Floor 1 Dictation', 'Floor 1 Humid', 'Floor 1 Nourishment', 'Floor 1 Nurse Hall', 'Floor 1 Nurse Janitor', 'Floor 1 Nurse Station', 'Floor 1 Nurse Toilet', 'Floor 1 Office', 'Floor 1 Operating Room 1', 'Floor 1 Operating Room 2', 'Floor 1 Operating Room 3', 'Floor 1 PACU', 'Floor 1 Pre-Op Hall', 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2', 'Floor 1 Pre-Op Toilet', 'Floor 1 Procedure Room', 'Floor 1 Reception', 'Floor 1 Reception Hall', 'Floor 1 Recovery Room', 'Floor 1 Scheduling', 'Floor 1 Scrub', 'Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work', 'Floor 1 Step Down', 'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Storage', 'Floor 1 Sub-Sterile', 'Floor 1 Utility Hall', 'Floor 1 Utility Janitor', 'Floor 1 Utility Room', 'Floor 1 Vestibule', 'Floor 2 Conference', 'Floor 2 Conference Toilet', 'Floor 2 Dictation', 'Floor 2 Exam 1', 'Floor 2 Exam 2', 'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7', 'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Janitor', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1', 'Floor 2 Nurse Station 2', 'Floor 2 Office', 'Floor 2 Office Hall', 'Floor 2 Reception', 'Floor 2 Reception Hall', 'Floor 2 Reception Toilet', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', 'Floor 2 Storage 1', 'Floor 2 Storage 2', 'Floor 2 Storage 3', 'Floor 2 Utility', 'Floor 2 Work', 'Floor 2 Work Hall', 'Floor 2 Work Toilet', 'Floor 2 X-Ray', 'Floor 3 Dressing Room', 'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Janitor', 'Floor 3 Locker', 'Floor 3 Lounge', 'Floor 3 Lounge Toilet', 'Floor 3 Mechanical', 'Floor 3 Mechanical Hall', 'Floor 3 Office', 'Floor 3 Office Hall', 'Floor 3 Office Toilet', 'Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2', 'Floor 3 Physical Therapy Toilet', 'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Treatment', 'Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2', 'Floor 3 Utility', 'Floor 3 Work', 'NE Stair', 'NW Elevator', 'NW Stair', 'SW Stair'
      
      'Anesthesia' => ['Floor 1 Anesthesia', ],
      'BioHazard' => ['Floor 1 Bio Haz', ],
      'Cafe' => ['Floor 1 Cafe', ],
      'CleanWork' => ['Floor 1 Clean', 'Floor 1 Clean Work', ],
      'Conference' => [],
      'DressingRoom' => ['Floor 1 Dressing Room', ],
      'Elec/MechRoom' => ['Floor 1 Electrical Room', 'Floor 1 Elevator Pump Room', ],
      'Exam' => [],
      'Hall' => [],
      'IT_Room' => ['Floor 1 IT Hall', 'Floor 1 IT Room', ],
      'Janitor' => [],
      'Lobby' => ['Floor 1 Lobby', 'Floor 1 Lobby Hall', ],
      'LockerRoom' => ['Floor 1 Locker Room', 'Floor 1 Locker Room Hall', ],
      'Lounge' => ['Floor 1 Lounge', ],
      'MRI' => ['Floor 1 MRI Hall', 'Floor 1 MRI Room', ],
      'MRI_Control' => ['Floor 1 MRI Control Room', ],
      'MedGas' => ['Floor 1 Med Gas', ],
      'NurseStation' => [],
      'OR' => [],
      'Office' => [],
      'PACU' => [],
      'PhysicalTherapy' => [],
      'PreOp' => [],
      'ProcedureRoom' => [],
      'Soil Work' => [],
      'Stair' => [],
      'Toilet' => ['Floor 1 Lobby Toilet', 'Floor 1 MRI Toilet', ],
      'Xray' => []
    }
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    system_to_space_map = [
      {
          'type' => 'VAV',
          'space_names' => [
            'Floor 1 Anesthesia', 'Floor 1 Bio Haz', 'Floor 1 Cafe', 'Floor 1 Clean', 'Floor 1 Clean Work', 'Floor 1 Dictation', 
            'Floor 1 Dressing Room', 'Floor 1 Electrical Room', 'Floor 1 Elevator Pump Room', 'Floor 1 Humid', 'Floor 1 IT Hall', 
            'Floor 1 IT Room', 'Floor 1 Lobby', 'Floor 1 Lobby Hall', 'Floor 1 Lobby Toilet', 'Floor 1 Locker Room', 
            'Floor 1 Locker Room Hall', 'Floor 1 Lounge', 'Floor 1 Med Gas', 'Floor 1 MRI Control Room', 'Floor 1 MRI Hall', 
            'Floor 1 MRI Room', 'Floor 1 MRI Toilet', 'Floor 1 Nourishment', 'Floor 1 Nurse Hall', 'Floor 1 Nurse Janitor', 
            'Floor 1 Nurse Station', 'Floor 1 Nurse Toilet', 'Floor 1 Office', 'Floor 1 Operating Room 1', 'Floor 1 Operating Room 2', 
            'Floor 1 Operating Room 3', 'Floor 1 PACU', 'Floor 1 Pre-Op Hall', 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2', 
            'Floor 1 Pre-Op Toilet', 'Floor 1 Procedure Room', 'Floor 1 Reception', 'Floor 1 Reception Hall', 'Floor 1 Recovery Room', 
            'Floor 1 Scheduling', 'Floor 1 Scrub', 'Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work', 'Floor 1 Step Down', 
            'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Storage', 'Floor 1 Sub-Sterile', 'Floor 1 Utility Hall', 
            'Floor 1 Utility Janitor', 'Floor 1 Utility Room', 'Floor 1 Vestibule'
          ]
      },
      {
          'type' => 'VAV',
          'space_names' => [
            'Floor 2 Conference', 'Floor 2 Conference Toilet', 'Floor 2 Dictation', 'Floor 2 Exam 1', 'Floor 2 Exam 2', 
            'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7', 'Floor 2 Exam 8', 
            'Floor 2 Exam 9', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4', 
            'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Janitor', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1', 
            'Floor 2 Nurse Station 2', 'Floor 2 Office', 'Floor 2 Office Hall', 'Floor 2 Reception', 'Floor 2 Reception Hall', 
            'Floor 2 Reception Toilet', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', 'Floor 2 Storage 1', 'Floor 2 Storage 2', 
            'Floor 2 Storage 3', 'Floor 2 Utility', 'Floor 2 Work', 'Floor 2 Work Hall', 'Floor 2 Work Toilet', 'Floor 2 X-Ray', 
            'Floor 3 Dressing Room', 'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Janitor', 'Floor 3 Locker', 'Floor 3 Lounge', 
            'Floor 3 Lounge Toilet', 'Floor 3 Mechanical', 'Floor 3 Mechanical Hall', 'Floor 3 Office', 'Floor 3 Office Hall', 
            'Floor 3 Office Toilet', 'Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2', 'Floor 3 Physical Therapy Toilet', 
            'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Treatment', 'Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2', 
            'Floor 3 Utility', 'Floor 3 Work', 'NE Stair', 'NW Elevator', 'NW Stair', 'SW Stair'
          ]
      }
    ]
    return system_to_space_map
  end
     
  def add_hvac(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    chilled_water_loop = self.add_chw_loop(prototype_input, hvac_standards)

    hot_water_loop = self.add_hw_loop(prototype_input, hvac_standards)
    
    system_to_space_map.each do |system|

      #find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = self.getSpaceByName(space_name)
        if space.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
          return false
        end
        thermal_zones << zone.get
      end

      case system['type']
      when 'VAV'
        self.add_vav(prototype_input, hvac_standards, hot_water_loop, chilled_water_loop, thermal_zones)
      end

    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    
    return true
    
  end #add hvac

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')
    water_heaters = main_swh_loop.supplyComponents(OpenStudio::Model::WaterHeaterMixed::iddObjectType)
    
    water_heaters.each do |water_heater|
      water_heater = water_heater.to_WaterHeaterMixed.get
      # water_heater.setAmbientTemperatureIndicator('Zone')
      # water_heater.setAmbientTemperatureThermalZone(default_water_heater_ambient_temp_sch)
      water_heater.setOffCycleParasiticFuelConsumptionRate(1488)
      water_heater.setOnCycleParasiticFuelConsumptionRate(1488)
      water_heater.setOffCycleLossCoefficienttoAmbientTemperature(9.643286184)
      water_heater.setOnCycleLossCoefficienttoAmbientTemperature(9.643286184)
    end

    self.add_swh_end_uses(prototype_input, hvac_standards, main_swh_loop, 'main')
    
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh    
  
  def add_refrigeration(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
       
    return false
    
  end #add refrigeration
  
end

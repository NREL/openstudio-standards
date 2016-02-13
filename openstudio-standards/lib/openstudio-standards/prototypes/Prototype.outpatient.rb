
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
 
  def define_space_type_map(building_type, building_vintage, climate_zone)
    space_type_map = {
      # 'Floor 1 Anesthesia', 'Floor 1 Bio Haz', 'Floor 1 Cafe', 'Floor 1 Clean', 'Floor 1 Clean Work', 'Floor 1 Dictation', 'Floor 1 Dressing Room', 'Floor 1 Electrical Room', 'Floor 1 Elevator Pump Room', 'Floor 1 Humid', 'Floor 1 IT Hall', 'Floor 1 IT Room', 'Floor 1 Lobby', 'Floor 1 Lobby Hall', 'Floor 1 Lobby Toilet', 'Floor 1 Locker Room', 'Floor 1 Locker Room Hall', 'Floor 1 Lounge', 'Floor 1 Med Gas', 'Floor 1 MRI Control Room', 'Floor 1 MRI Hall', 'Floor 1 MRI Room', 'Floor 1 MRI Toilet', 'Floor 1 Nourishment', 'Floor 1 Nurse Hall', 'Floor 1 Nurse Janitor', 'Floor 1 Nurse Station', 'Floor 1 Nurse Toilet', 'Floor 1 Office', 'Floor 1 Operating Room 1', 'Floor 1 Operating Room 2', 'Floor 1 Operating Room 3', 'Floor 1 PACU', 'Floor 1 Pre-Op Hall', 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2', 'Floor 1 Pre-Op Toilet', 'Floor 1 Procedure Room', 'Floor 1 Reception', 'Floor 1 Reception Hall', 'Floor 1 Recovery Room', 'Floor 1 Scheduling', 'Floor 1 Scrub', 'Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work', 'Floor 1 Step Down', 'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Storage', 'Floor 1 Sub-Sterile', 'Floor 1 Utility Hall', 'Floor 1 Utility Janitor', 'Floor 1 Utility Room', 'Floor 1 Vestibule', 'Floor 2 Conference', 'Floor 2 Conference Toilet', 'Floor 2 Dictation', 'Floor 2 Exam 1', 'Floor 2 Exam 2', 'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7', 'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Janitor', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1', 'Floor 2 Nurse Station 2', 'Floor 2 Office', 'Floor 2 Office Hall', 'Floor 2 Reception', 'Floor 2 Reception Hall', 'Floor 2 Reception Toilet', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', 'Floor 2 Storage 1', 'Floor 2 Storage 2', 'Floor 2 Storage 3', 'Floor 2 Utility', 'Floor 2 Work', 'Floor 2 Work Hall', 'Floor 2 Work Toilet', 'Floor 2 X-Ray', 'Floor 3 Dressing Room', 'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Janitor', 'Floor 3 Locker', 'Floor 3 Lounge', 'Floor 3 Lounge Toilet', 'Floor 3 Mechanical', 'Floor 3 Mechanical Hall', 'Floor 3 Office', 'Floor 3 Office Hall', 'Floor 3 Office Toilet', 'Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2', 'Floor 3 Physical Therapy Toilet', 'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Treatment', 'Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2', 'Floor 3 Utility', 'Floor 3 Work', 'NE Stair', 'NW Elevator', 'NW Stair', 'SW Stair'
      
      # TODO: still need to put these into their space types...
      #  all zones mapped
      
      'Anesthesia' => ['Floor 1 Anesthesia'],
      'BioHazard' => ['Floor 1 Bio Haz'],
      'Cafe' => ['Floor 1 Cafe'],
      'CleanWork' => ['Floor 1 Clean', 'Floor 1 Clean Work', ],
      'Conference' => ['Floor 2 Conference'],
      'DressingRoom' => ['Floor 1 Dressing Room', 'Floor 3 Dressing Room'],
      'Elec/MechRoom' => ['Floor 1 Electrical Room', 'Floor 3 Mechanical', 'NW Elevator'],
      'ElevatorPumpRoom' => ['Floor 1 Elevator Pump Room'],
      # 'Floor 3 Treatment' same as 'Exam'
      'Exam' => ['Floor 2 Exam 1', 'Floor 2 Exam 2', 'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7', 
        'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 3 Treatment'],
      # 'Floor 1 Scrub', 'Floor 1 Sub-Sterile', 'Floor 1 Vestibule' same as 'Hall'
      'Hall' => ['Floor 1 IT Hall', 'Floor 1 Lobby Hall', 'Floor 1 Locker Room Hall', 'Floor 1 MRI Hall', 'Floor 1 Nurse Hall', 'Floor 1 Pre-Op Hall',
        'Floor 1 Reception Hall', 'Floor 1 Sterile Hall', 'Floor 1 Utility Hall', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3',
        'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Office Hall', 'Floor 2 Reception Hall', 'Floor 2 Work Hall', 
        'Floor 3 Elevator Hall', 'Floor 3 Mechanical Hall', 'Floor 3 Office Hall', 'Floor 1 Scrub', 'Floor 1 Sub-Sterile', 'Floor 1 Vestibule'],
      'IT_Room' => ['Floor 1 IT Room'],
      # ['Floor 1 Sterile Storage', 'Floor 1 Storage', 'Floor 1 Utility Room', 'Floor 2 Storage 1', 'Floor 2 Storage 2', 'Floor 2 Storage 3', ...
      # 'Floor 2 Utility', 'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Utility'] same as 'Janitor'
      'Janitor' => ['Floor 1 Nurse Janitor', 'Floor 1 Utility Janitor', 'Floor 2 Janitor', 'Floor 3 Janitor', 'Floor 1 Sterile Storage', 
        'Floor 1 Storage', 'Floor 1 Utility Room', 'Floor 2 Storage 1', 'Floor 2 Storage 2', 'Floor 2 Storage 3', 'Floor 2 Utility', 
        'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Utility'],
      'Lobby' => ['Floor 1 Lobby'],
      'LockerRoom' => ['Floor 1 Locker Room', 'Floor 3 Locker'],
      'Lounge' => ['Floor 1 Lounge', 'Floor 2 Lounge', 'Floor 3 Lounge'],
      'MRI' => ['Floor 1 MRI Room'],
      'MRI_Control' => ['Floor 1 MRI Control Room'],
      'MedGas' => ['Floor 1 Med Gas'],
      # 'Floor 1 Nourishment' same as 'NurseStation'
      'NurseStation' => ['Floor 1 Nurse Station', 'Floor 1 Nourishment', 'Floor 2 Nurse Station 1', 'Floor 2 Nurse Station 2'],
      'OR' => ['Floor 1 Operating Room 1', 'Floor 1 Operating Room 2', 'Floor 1 Operating Room 3'],
      # ['Floor 1 Dictation', 'Floor 1 Humid','Floor 1 Scheduling', 'Floor 2 Dictation', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', ...
      # 'Floor 2 Work', 'Floor 3 Humid', 'Floor 3 Work'] same as 'Office', 'IT Room' and 'Dressing Room'
      # TODO 'Floor 2 Work' has slightly different equipment density
      'Office' => ['Floor 1 Office', 'Floor 2 Office', 'Floor 3 Office', 'Floor 1 Dictation', 'Floor 1 Humid', 'Floor 1 Scheduling', 
        'Floor 2 Dictation', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', 'Floor 2 Work', 'Floor 3 Humid', 'Floor 3 Work'],
      # 'Floor 1 Recovery Room' and 'Floor 1 Step Down' same as 'PACU'
      'PACU' => ['Floor 1 PACU', 'Floor 1 Recovery Room', 'Floor 1 Step Down'],
      'PhysicalTherapy' => ['Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2'],
      'PreOp' => ['Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2'],
      'ProcedureRoom' => ['Floor 1 Procedure Room'],
      'Soil Work' => ['Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work'],
      'Stair' => ['NE Stair', 'NW Stair', 'SW Stair'],
      'Toilet' => ['Floor 1 Nurse Toilet', 'Floor 1 Pre-Op Toilet', 'Floor 1 Lobby Toilet', 'Floor 1 MRI Toilet', 'Floor 2 Conference Toilet', 
        'Floor 2 Reception Toilet', 'Floor 2 Work Toilet', 'Floor 3 Lounge Toilet', 'Floor 3 Office Toilet', 'Floor 3 Physical Therapy Toilet'],
      'Xray' => ['Floor 2 X-Ray'],
      # Add new space type 'Reception'
      'Reception' => ['Floor 1 Reception', 'Floor 2 Reception'],
      # Add new space type 'Undeveloped'
      'Undeveloped' => ['Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2'] 
    }
    return space_type_map
  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      system_to_space_map = [
        {
            'type' => 'PVAV',
            'name' => 'PVAV Outpatient F1',
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
            'type' => 'PVAV',
            'name' => 'PVAV Outpatient F2 F3',
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
    
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      system_to_space_map = [
        {
            'type' => 'PVAV',
            'name' => 'PVAV Outpatient F1',
            'space_names' => [
              'Floor 1 Anesthesia', 'Floor 1 Bio Haz', 'Floor 1 Cafe', 'Floor 1 Clean', 'Floor 1 Clean Work', 'Floor 1 Dictation', 
              'Floor 1 Dressing Room', 'Floor 1 Humid', 'Floor 1 IT Hall', 
              'Floor 1 IT Room', 'Floor 1 Lobby', 'Floor 1 Lobby Hall', 'Floor 1 Locker Room', 
              'Floor 1 Locker Room Hall', 'Floor 1 Lounge', 'Floor 1 Med Gas', 'Floor 1 MRI Control Room', 'Floor 1 MRI Hall', 
              'Floor 1 MRI Room', 'Floor 1 Nourishment', 'Floor 1 Nurse Hall', 
              'Floor 1 Nurse Station', 'Floor 1 Office', 'Floor 1 Operating Room 1', 'Floor 1 Operating Room 2', 
              'Floor 1 Operating Room 3', 'Floor 1 PACU', 'Floor 1 Pre-Op Hall', 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2', 
              'Floor 1 Procedure Room', 'Floor 1 Reception', 'Floor 1 Reception Hall', 'Floor 1 Recovery Room', 
              'Floor 1 Scheduling', 'Floor 1 Scrub', 'Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work', 'Floor 1 Step Down', 
              'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Sub-Sterile', 'Floor 1 Utility Hall', 
              'Floor 1 Vestibule'
            ]
        },
        {
            'type' => 'PVAV',
            'name' => 'PVAV Outpatient F2 F3',
            'space_names' => [
              'Floor 2 Conference', 'Floor 2 Dictation', 'Floor 2 Exam 1', 'Floor 2 Exam 2', 
              'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7', 'Floor 2 Exam 8', 
              'Floor 2 Exam 9', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4', 
              'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1', 
              'Floor 2 Nurse Station 2', 'Floor 2 Office', 'Floor 2 Office Hall', 'Floor 2 Reception', 'Floor 2 Reception Hall', 
              'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', 
              'Floor 2 Work', 'Floor 2 Work Hall', 'Floor 2 X-Ray', 
              'Floor 3 Dressing Room', 'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Locker', 'Floor 3 Lounge', 
              'Floor 3 Mechanical Hall', 'Floor 3 Office', 'Floor 3 Office Hall', 
              'Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2', 
              'Floor 3 Treatment', 'Floor 3 Work'
            ]
        }
      ]      
    end
    

    return system_to_space_map
  end
     
  def custom_hvac_tweaks(building_type, building_vintage, climate_zone, prototype_input)
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')
    
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)

    # add elevator for the elevator pump room (the fan&lights are already added via standard spreadsheet)
    self.add_extra_equip_elevator_pump_room(building_vintage)
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')
    
    return true
    
  end

  def add_extra_equip_elevator_pump_room(building_vintage)
    elevator_pump_room = self.getSpaceByName('Floor 1 Elevator Pump Room').get
    elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
    elec_equip_def.setName("Elevator Pump Room Electric Equipment Definition")
    elec_equip_def.setFractionLatent(0)
    elec_equip_def.setFractionRadiant(0.1)
    elec_equip_def.setFractionLost(0.9)
    elec_equip_def.setDesignLevel(48165)
    elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
    elec_equip.setName("Elevator Pump Room Elevator Equipment")
    elec_equip.setSpace(elevator_pump_room)
    case building_vintage
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      elec_equip.setSchedule(add_schedule("OutPatientHealthCare BLDG_ELEVATORS"))
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      elec_equip.setSchedule(add_schedule("OutPatientHealthCare BLDG_ELEVATORS_Pre2004"))
    end
  end

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")

    main_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'main')

    space_type_map.each do |space_type_name, space_names|
      data = nil
      search_criteria = {
        'template' => building_vintage,
        'building_type' => building_type,
        'space_type' => space_type_name
      }
      data = find_object(self.standards['space_types'],search_criteria)
      
      if data['service_water_heating_peak_flow_rate'].nil?
        next
      else
        space_names.each do |space_name|
          self.add_swh_end_uses_by_space(building_type, building_vintage, climate_zone, main_swh_loop, space_type_name, space_name)
        end
      end
    end
     
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh    

end

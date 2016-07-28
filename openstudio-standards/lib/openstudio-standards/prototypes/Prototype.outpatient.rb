
# Extend the class to add Medium Office specific stuff
class OpenStudio::Model::Model
  def define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
    when 'NECB 2011'
      # Dom is G
      space_type_map = {
        'Dormitory - living quarters' => ['Floor 1 Anesthesia', 'Floor 1 Bio Haz', 'Floor 1 Cafe',
                                          'Floor 1 Clean', 'Floor 1 Clean Work', 'Floor 1 Dictation',
                                          'Floor 1 Dressing Room', 'Floor 1 Electrical Room', 'Floor 1 Elevator Pump Room',
                                          'Floor 1 Operating Room 1', 'Floor 1 Operating Room 2', 'Floor 1 Operating Room 3',
                                          'Floor 1 Humid', 'Floor 1 IT Hall', 'Floor 1 IT Room', 'Floor 1 Lobby Hall',
                                          'Floor 1 Lobby', 'Floor 1 Lobby Toilet', 'Floor 1 Locker Room Hall',
                                          'Floor 1 Locker Room', 'Floor 1 Lounge', 'Floor 1 Med Gas',
                                          'Floor 1 MRI Control Room', 'Floor 1 MRI Hall', 'Floor 1 MRI Room', 'Floor 1 MRI Toilet',
                                          'Floor 1 Nourishment', 'Floor 1 Nurse Hall', 'Floor 1 Nurse Janitor',
                                          'Floor 1 Nurse Station', 'Floor 1 Nurse Toilet', 'Floor 1 Office',
                                          'Floor 1 PACU', 'Floor 1 Pre-Op Hall', 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2',
                                          'Floor 1 Pre-Op Toilet', 'Floor 1 Procedure Room', 'Floor 1 Reception Hall',
                                          'Floor 1 Reception', 'Floor 1 Recovery Room', 'Floor 1 Scheduling', 'Floor 1 Scrub',
                                          'Floor 1 Soil Hold', 'Floor 1 Soil', 'Floor 1 Soil Work', 'Floor 1 Step Down',
                                          'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Storage',
                                          'Floor 1 Sub-Sterile', 'Floor 1 Utility Hall', 'Floor 1 Utility Janitor',
                                          'Floor 1 Utility Room', 'Floor 1 Vestibule', 'Floor 2 Conference',
                                          'Floor 2 Conference Toilet', 'Floor 2 Dictation', 'Floor 2 Exam 1', 'Floor 2 Exam 2',
                                          'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7',
                                          'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2',
                                          'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5',
                                          'Floor 2 Exam Hall 6', 'Floor 2 Janitor', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1',
                                          'Floor 2 Nurse Station 2', 'Floor 2 Office Hall', 'Floor 2 Office', 'Floor 2 Reception Hall',
                                          'Floor 2 Reception', 'Floor 2 Reception Toilet', 'Floor 2 Scheduling 1',
                                          'Floor 2 Scheduling 2', 'Floor 2 Storage 1', 'Floor 2 Storage 2',
                                          'Floor 2 Storage 3', 'Floor 2 Utility', 'Floor 2 Work Hall',
                                          'Floor 2 Work', 'Floor 2 Work Toilet', 'Floor 2 X-Ray', 'Floor 3 Dressing Room',
                                          'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Janitor', 'Floor 3 Locker',
                                          'Floor 3 Lounge', 'Floor 3 Lounge Toilet', 'Floor 3 Mechanical Hall',
                                          'Floor 3 Mechanical', 'Floor 3 Office Hall', 'Floor 3 Office', 'Floor 3 Office Toilet',
                                          'Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2', 'Floor 3 Physical Therapy Toilet',
                                          'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Treatment',
                                          'Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2',
                                          'Floor 3 Utility', 'Floor 3 Work', 'NE Stair', 'NW Elevator', 'NW Stair', 'SW Stair']
      }
    else
      space_type_map = {
        # 'Floor 1 Anesthesia', 'Floor 1 Bio Haz', 'Floor 1 Cafe', 'Floor 1 Clean', 'Floor 1 Clean Work',
        # 'Floor 1 Dictation', 'Floor 1 Dressing Room', 'Floor 1 Electrical Room', 'Floor 1 Elevator Pump Room',
        # 'Floor 1 Humid', 'Floor 1 IT Hall', 'Floor 1 IT Room', 'Floor 1 Lobby', 'Floor 1 Lobby Hall',
        # 'Floor 1 Lobby Toilet', 'Floor 1 Locker Room', 'Floor 1 Locker Room Hall', 'Floor 1 Lounge',
        # 'Floor 1 Med Gas', 'Floor 1 MRI Control Room', 'Floor 1 MRI Hall', 'Floor 1 MRI Room',
        # 'Floor 1 MRI Toilet', 'Floor 1 Nourishment', 'Floor 1 Nurse Hall', 'Floor 1 Nurse Janitor',
        # 'Floor 1 Nurse Station', 'Floor 1 Nurse Toilet', 'Floor 1 Office', 'Floor 1 Operating Room 1',
        # 'Floor 1 Operating Room 2', 'Floor 1 Operating Room 3', 'Floor 1 PACU', 'Floor 1 Pre-Op Hall',
        # 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2', 'Floor 1 Pre-Op Toilet', 'Floor 1 Procedure Room',
        # 'Floor 1 Reception', 'Floor 1 Reception Hall', 'Floor 1 Recovery Room', 'Floor 1 Scheduling',
        # 'Floor 1 Scrub', 'Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work', 'Floor 1 Step Down',
        # 'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Storage', 'Floor 1 Sub-Sterile',
        # 'Floor 1 Utility Hall', 'Floor 1 Utility Janitor', 'Floor 1 Utility Room', 'Floor 1 Vestibule',
        # 'Floor 2 Conference', 'Floor 2 Conference Toilet', 'Floor 2 Dictation', 'Floor 2 Exam 1',
        # 'Floor 2 Exam 2', 'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6',
        # 'Floor 2 Exam 7', 'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 2 Exam Hall 1',
        # 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5',
        # 'Floor 2 Exam Hall 6', 'Floor 2 Janitor', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1',
        # 'Floor 2 Nurse Station 2', 'Floor 2 Office', 'Floor 2 Office Hall', 'Floor 2 Reception',
        # 'Floor 2 Reception Hall', 'Floor 2 Reception Toilet', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2',
        # 'Floor 2 Storage 1', 'Floor 2 Storage 2', 'Floor 2 Storage 3', 'Floor 2 Utility', 'Floor 2 Work',
        # 'Floor 2 Work Hall', 'Floor 2 Work Toilet', 'Floor 2 X-Ray', 'Floor 3 Dressing Room',
        # 'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Janitor', 'Floor 3 Locker',
        # 'Floor 3 Lounge', 'Floor 3 Lounge Toilet', 'Floor 3 Mechanical', 'Floor 3 Mechanical Hall',
        # 'Floor 3 Office', 'Floor 3 Office Hall', 'Floor 3 Office Toilet', 'Floor 3 Physical Therapy 1',
        # 'Floor 3 Physical Therapy 2', 'Floor 3 Physical Therapy Toilet', 'Floor 3 Storage 1',
        # 'Floor 3 Storage 2', 'Floor 3 Treatment', 'Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2',
        # 'Floor 3 Utility', 'Floor 3 Work', 'NE Stair', 'NW Elevator', 'NW Stair', 'SW Stair'

        # TODO: still need to put these into their space types...
        #  all zones mapped

        'Anesthesia' => ['Floor 1 Anesthesia'],
        'BioHazard' => ['Floor 1 Bio Haz'],
        'Cafe' => ['Floor 1 Cafe'],
        'CleanWork' => ['Floor 1 Clean', 'Floor 1 Clean Work'],
        'Conference' => ['Floor 2 Conference'],
        'DressingRoom' => ['Floor 1 Dressing Room', 'Floor 3 Dressing Room'],
        'Elec/MechRoom' => ['Floor 1 Electrical Room', 'Floor 3 Mechanical'],
        'ElevatorPumpRoom' => ['Floor 1 Elevator Pump Room'],
        # 'Floor 3 Treatment' same as 'Exam'
        'Exam' => ['Floor 2 Exam 1', 'Floor 2 Exam 2', 'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7',
                   'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 3 Treatment'],
        # 'Floor 1 Scrub', 'Floor 1 Sub-Sterile', 'Floor 1 Vestibule' same as 'Hall'
        'Hall' => ['Floor 1 IT Hall', 'Floor 1 Lobby Hall', 'Floor 1 Locker Room Hall', 'Floor 1 MRI Hall', 'Floor 1 Nurse Hall', 'Floor 1 Pre-Op Hall',
                   'Floor 1 Reception Hall', 'Floor 1 Sterile Hall', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3',
                   'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Office Hall', 'Floor 2 Reception Hall', 'Floor 2 Work Hall',
                   'Floor 3 Mechanical Hall', 'Floor 1 Scrub'],
        'Hall_infil' => ['Floor 1 Utility Hall', 'Floor 1 Sub-Sterile', 'Floor 1 Vestibule', 'Floor 3 Elevator Hall', 'Floor 3 Office Hall'],
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
        'Stair' => ['NE Stair', 'NW Stair', 'SW Stair', 'NW Elevator'],
        'Toilet' => ['Floor 1 Nurse Toilet', 'Floor 1 Pre-Op Toilet', 'Floor 1 Lobby Toilet', 'Floor 1 MRI Toilet', 'Floor 2 Conference Toilet',
                     'Floor 2 Reception Toilet', 'Floor 2 Work Toilet', 'Floor 3 Lounge Toilet', 'Floor 3 Office Toilet', 'Floor 3 Physical Therapy Toilet'],
        'Xray' => ['Floor 2 X-Ray'],
        # Add new space type 'Reception'
        'Reception' => ['Floor 1 Reception', 'Floor 2 Reception'],
        # Add new space type 'Undeveloped'
        'Undeveloped' => ['Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2']
      }
    end

    return space_type_map
  end

  def define_hvac_system_map(building_type, template, climate_zone)
    case template
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
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Outpatient AHU1 Exhaust Fans',
          'availability_sch_name' => 'OutPatientHealthCare Hours_of_operation',
          'flow_rate' =>
            [
              6.79561743E-02,    # Floor 1 Anesthesia
              4.24726077E-02,    # Floor 1 Lobby Toilet
              0.1586,            # Floor 1 MRI Control Room
              0.4153,            # Floor 1 MRI Room
              4.24726077E-02,    # Floor 1 MRI Toilet
              4.24726077E-02,    # Floor 1 Nurse Toilet
              4.24726077E-02,    # Floor 1 Pre-Op Toilet
              9.91027512E-02,    # Floor 1 Soil
              4.40456672E-02,    # Floor 1 Soil Hold
              1.41575359E-01,    # Floor 1 Soil Work
            ],
          'flow_fraction_schedule_name' => nil,
          'balanced_exhaust_fraction_schedule_name' => nil,
          'space_names' =>
            [
              'Floor 1 Anesthesia',
              'Floor 1 Lobby Toilet',
              'Floor 1 MRI Control Room',
              'Floor 1 MRI Room',
              'Floor 1 MRI Toilet',
              'Floor 1 Nurse Toilet',
              'Floor 1 Pre-Op Toilet',
              'Floor 1 Soil',
              'Floor 1 Soil Hold',
              'Floor 1 Soil Work'
            ]
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Outpatient AHU2&3 Exhaust Fans',
          'availability_sch_name' => 'OutPatientHealthCare BLDG_OA_SCH',
          'flow_rate' =>
            [
              5.03379054E-02,    # Floor 2 Conference Toilet
              9.91027512E-02,    # Floor 2 Reception Toilet
              4.24726077E-02,    # Floor 2 Work Toilet
              0.8495,            # Floor 2 X-Ray
              1.51013716E-01,    # Floor 3 Lounge Toilet
              4.24726077E-02,    # Floor 3 Office Toilet
              6.60685008E-02,    # Floor 3 Physical Therapy Toilet
            ],
          'flow_fraction_schedule_name' => nil,
          'balanced_exhaust_fraction_schedule_name' => nil,
          'space_names' =>
            [
              'Floor 2 Conference Toilet',
              'Floor 2 Reception Toilet',
              'Floor 2 Work Toilet',
              'Floor 2 X-Ray',
              'Floor 3 Lounge Toilet',
              'Floor 3 Office Toilet',
              'Floor 3 Physical Therapy Toilet'
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
        },
        {
          'type' => 'Exhaust Fan',
          'name' => 'Outpatient AHU1 Exhaust Fans',
          'availability_sch_name' => 'OutPatientHealthCare AHU1-Fan_Pre2004',
          'flow_rate' =>
            [
              0.068,      # Floor 1 Anesthesia
              0.0793,     # Floor 1 MRI Control Room
              0.2077,     # Floor 1 MRI Room
              0.0991,     # Floor 1 Soil
              0.044,      # Floor 1 Soil Hold
              0.1416,     # Floor 1 Soil Work
            ],
          'flow_fraction_schedule_name' => nil,
          'balanced_exhaust_fraction_schedule_name' => nil,
          'space_names' =>
            [
              'Floor 1 Anesthesia',
              'Floor 1 MRI Control Room',
              'Floor 1 MRI Room',
              'Floor 1 Soil',
              'Floor 1 Soil Hold',
              'Floor 1 Soil Work'
            ]
        }
      ]
    end

    return system_to_space_map
  end

  def custom_hvac_tweaks(building_type, template, climate_zone, prototype_input)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')

    system_to_space_map = define_hvac_system_map(building_type, template, climate_zone)

    # add elevator for the elevator pump room (the fan&lights are already added via standard spreadsheet)
    add_extra_equip_elevator_pump_room(template)
    # adjust cooling setpoint at vintages 1B,2B,3B
    adjust_clg_setpoint(template, climate_zone)
    # Get the hot water loop
    hot_water_loop = nil
    getPlantLoops.each do |loop|
      # If it has a boiler:hotwater, it is the correct loop
      unless loop.supplyComponents('OS:Boiler:HotWater'.to_IddObjectType).empty?
        hot_water_loop = loop
      end
    end
    # add humidifier to AHU1 (contains operating room 1)
    if hot_water_loop
      add_humidifier(template, hot_water_loop)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Could not find hot water loop to attach humidifier to.')
    end
    # adjust infiltration for vintages 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
    adjust_infiltration(template)
    # add door infiltration for vertibule
    add_door_infiltration(template, climate_zone)
    # reset boiler sizing factor to 0.3 (default 1)
    reset_boiler_sizing_factor
    # assign the minimum total air changes to the cooling minimum air flow in Sizing:Zone
    apply_minimum_total_ach(building_type, template)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')

    return true
  end

  def add_extra_equip_elevator_pump_room(template)
    elevator_pump_room = getSpaceByName('Floor 1 Elevator Pump Room').get
    elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(self)
    elec_equip_def.setName('Elevator Pump Room Electric Equipment Definition')
    elec_equip_def.setFractionLatent(0)
    elec_equip_def.setFractionRadiant(0.1)
    elec_equip_def.setFractionLost(0.9)
    elec_equip_def.setDesignLevel(48165)
    elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
    elec_equip.setName('Elevator Pump Room Elevator Equipment')
    elec_equip.setSpace(elevator_pump_room)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      elec_equip.setSchedule(add_schedule('OutPatientHealthCare BLDG_ELEVATORS'))
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      elec_equip.setSchedule(add_schedule('OutPatientHealthCare BLDG_ELEVATORS_Pre2004'))
    end
    return true
  end

  def adjust_clg_setpoint(template, climate_zone)
    getSpaceTypes.sort.each do |space_type|
      space_type_name = space_type.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = getThermostatSetpointDualSetpointByName(thermostat_name).get
      case template
      when '90.1-2004', '90.1-2007', '90.1-2010'
        case climate_zone
        when 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-3B'
          thermostat.setCoolingSetpointTemperatureSchedule(add_schedule('OutPatientHealthCare CLGSETP_SCH_YES_OPTIMUM'))
        end
      end
    end
    return true
  end

  def adjust_infiltration(template)
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      getSpaces.sort.each do |space|
        space_type = space.spaceType.get
        # Skip interior spaces
        next if space.exterior_wall_and_window_area <= 0
        # Skip spaces that have no infiltration objects to adjust
        next if space_type.spaceInfiltrationDesignFlowRates.size <= 0

        # get the infiltration information from the space type infiltration
        infiltration_space_type = space_type.spaceInfiltrationDesignFlowRates[0]
        infil_sch = infiltration_space_type.schedule.get
        infil_rate = nil
        infil_ach = nil
        if infiltration_space_type.flowperExteriorWallArea.is_initialized
          infil_rate = infiltration_space_type.flowperExteriorWallArea.get
        elsif infiltration_space_type.airChangesperHour.is_initialized
          infil_ach = infiltration_space_type.airChangesperHour.get
        end
        # Create an infiltration rate object for this space
        infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(self)
        infiltration.setName("#{space.name} Infiltration")
        infiltration.setFlowperExteriorSurfaceArea(infil_rate) unless infil_rate.nil? || infil_rate.to_f.zero?
        infiltration.setAirChangesperHour(infil_ach) unless infil_ach.nil? || infil_ach.to_f.zero?
        infiltration.setSchedule(infil_sch)
        infiltration.setSpace(space)
      end
      getSpaceTypes.each do |space_type|
        space_type.spaceInfiltrationDesignFlowRates.each(&:remove)
      end
    else
      return true
    end
  end

  def add_door_infiltration(template, climate_zone)
    # add extra infiltration for vestibule door
    case template
    when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
      return true
    else
      vestibule_space = getSpaceByName('Floor 1 Vestibule').get
      infiltration_vestibule_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(self)
      infiltration_vestibule_door.setName('Vestibule door Infiltration')
      infiltration_rate_vestibule_door = 0
      case template
      when '90.1-2004'
        infiltration_rate_vestibule_door = 1.186002811
        infiltration_vestibule_door.setSchedule(add_schedule('OutPatientHealthCare INFIL_Door_Opening_SCH_0.144'))
      when '90.1-2007', '90.1-2010', '90.1-2013'
        case climate_zone
        when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
          infiltration_rate_vestibule_door = 1.186002811
          infiltration_vestibule_door.setSchedule(add_schedule('OutPatientHealthCare INFIL_Door_Opening_SCH_0.144'))
        else
          infiltration_rate_vestibule_door = 0.776824762
          infiltration_vestibule_door.setSchedule(add_schedule('OutPatientHealthCare INFIL_Door_Opening_SCH_0.131'))
        end
      end
      infiltration_vestibule_door.setDesignFlowRate(infiltration_rate_vestibule_door)
      infiltration_vestibule_door.setSpace(vestibule_space)
    end
  end

  def update_waterheater_loss_coefficient(template)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
      getWaterHeaterMixeds.sort.each do |water_heater|
        if water_heater.name.to_s.include?('Booster')
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
        else
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(9.643286505)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(9.643286505)
        end
      end
    end
  end

  # add humidifier to AHU1 (contains operating room1)
  def add_humidifier(template, hot_water_loop)
    operatingroom1_space = getSpaceByName('Floor 1 Operating Room 1').get
    operatingroom1_zone = operatingroom1_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(self)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(add_schedule('OutPatientHealthCare MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(add_schedule('OutPatientHealthCare MaxRelHumSetSch'))
    operatingroom1_zone.setZoneControlHumidistat(humidistat)
    getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? operatingroom1_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(self)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject.get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(self)
        case template
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(self, alwaysOnDiscreteSchedule)
          extra_elec_htg_coil.setName('AHU1 extra Electric Htg Coil')
          extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(self, alwaysOnDiscreteSchedule)
          extra_water_htg_coil.setName('AHU1 extra Water Htg Coil')
          hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
          extra_elec_htg_coil.addToNode(supply_outlet_node)
          extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)
        humidity_spm.setControlZone(operatingroom1_zone)
      end
    end
  end

  # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
  # AHU1 doesn't have economizer
  def modify_oa_controller(template)
    getAirLoopHVACs.each do |air_loop|
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      # AHU1 OA doesn't have controller:mechanicalventilation
      if air_loop.name.to_s.include? 'Outpatient F1'
        controller_mv.setAvailabilitySchedule(alwaysOffDiscreteSchedule)
        # add minimum fraction of outdoor air schedule to AHU1
        controller_oa.setMinimumFractionofOutdoorAirSchedule(add_schedule('OutPatientHealthCare AHU-1_OAminOAFracSchedule'))
      # for AHU2, at vintages '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', the minimum OA schedule is not the same as
      # airloop availability schedule, but separately assigned.
      elsif template == '90.1-2004' || template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013'
        controller_oa.setMinimumOutdoorAirSchedule(add_schedule('OutPatientHealthCare BLDG_OA_SCH'))
        # add minimum fraction of outdoor air schedule to AHU2
        controller_oa.setMinimumFractionofOutdoorAirSchedule(add_schedule('OutPatientHealthCare BLDG_OA_FRAC_SCH'))
      end
    end
  end

  # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
  def reset_or_room_vav_minimum_damper(prototype_input, template)
    case template
    when '90.1-2004', '90.1-2007'
      return true
    when '90.1-2010', '90.1-2013'
      getAirTerminalSingleDuctVAVReheats.sort.each do |airterminal|
        airterminal_name = airterminal.name.get
        if airterminal_name.include?('Floor 1 Operating Room 1') || airterminal_name.include?('Floor 1 Operating Room 2')
          airterminal.setZoneMinimumAirFlowMethod('Scheduled')
          airterminal.setMinimumAirFlowFractionSchedule(add_schedule('OutPatientHealthCare OR_MinSA_Sched'))
        end
      end
    end
  end

  def reset_boiler_sizing_factor
    getBoilerHotWaters.sort.each do |boiler|
      boiler.setSizingFactor(0.3)
    end
  end

  def update_exhaust_fan_efficiency(template)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      getFanZoneExhausts.sort.each do |exhaust_fan|
        fan_name = exhaust_fan.name.to_s
        if (fan_name.include? 'X-Ray') || (fan_name.include? 'MRI Room')
          exhaust_fan.setFanEfficiency(0.16)
          exhaust_fan.setPressureRise(125)
        else
          exhaust_fan.setFanEfficiency(0.31)
          exhaust_fan.setPressureRise(249)
        end
      end
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      getFanZoneExhausts.sort.each do |exhaust_fan|
        exhaust_fan.setFanEfficiency(0.338)
        exhaust_fan.setPressureRise(125)
      end
    end
  end

  # assign the minimum total air changes to the cooling minimum air flow in Sizing:Zone
  def apply_minimum_total_ach(building_type, template)
    getSpaces.each do |space|
      space_type_name = space.spaceType.get.standardsSpaceType.get
      search_criteria = {
        'template' => template,
        'building_type' => building_type,
        'space_type' => space_type_name
      }
      data = find_object($os_standards['space_types'], search_criteria)

      # skip space type without minimum total air changes
      next if data['minimum_total_air_changes'].nil?

      # calculate the minimum total air flow
      minimum_total_ach = data['minimum_total_air_changes'].to_f
      space_volume = space.volume
      space_area = space.floorArea
      minimum_airflow_per_zone = minimum_total_ach * space_volume / 3600
      minimum_airflow_per_zone_floor_area = minimum_airflow_per_zone / space_area
      # add minimum total air flow limit to sizing:zone
      zone = space.thermalZone.get
      sizingzone = zone.sizingZone
      sizingzone.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
      case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        sizingzone.setCoolingMinimumAirFlow(minimum_airflow_per_zone)
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        sizingzone.setCoolingMinimumAirFlowperZoneFloorArea(minimum_airflow_per_zone_floor_area)
      end
    end
  end

  def custom_swh_tweaks(building_type, template, climate_zone, prototype_input)
    update_waterheater_loss_coefficient(template)

    return true
  end
end

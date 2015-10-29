
# Extend the class to add Small Hotel specific stuff
class OpenStudio::Model::Model

  def define_space_type_map(building_type, building_vintage, climate_zone)

    space_type_map = nil
    
    case building_vintage
    when 'DOE Ref Pre-1980'
      space_type_map = {
        'Corridor' => ['CorridorFlr1','CorridorFlr2','CorridorFlr3','CorridorFlr4'],
        'Elec/MechRoom' => ['ElevatorCoreFlr1'],
        'ElevatorCore' => ['ElevatorCoreFlr2','ElevatorCoreFlr3','ElevatorCoreFlr4'],
        'StaffLounge' => ['EmployeeLoungeFlr1'],
        'Exercise' => ['ExerciseCenterFlr1'],
        'GuestLounge' => ['FrontLoungeFlr1'],
        'Office' => ['FrontOfficeFlr1'],
        'Stair' => ['FrontStairsFlr1','FrontStairsFlr2','FrontStairsFlr3','FrontStairsFlr4',
                     'RearStairsFlr1','RearStairsFlr2','RearStairsFlr3','RearStairsFlr4'],
        'Storage' => ['FrontStorageFlr1','FrontStorageFlr2','FrontStorageFlr3','FrontStorageFlr4',
                      'RearStorageFlr1','RearStorageFlr2','RearStorageFlr3','RearStorageFlr4'],
        'GuestRoom' => ['GuestRoom101','GuestRoom102','GuestRoom103','GuestRoom104','GuestRoom105',
                        'GuestRoom201','GuestRoom202_205','GuestRoom206_208','GuestRoom209_212','GuestRoom213',
                        'GuestRoom214','GuestRoom215_218','GuestRoom219','GuestRoom220_223','GuestRoom224',
                        'GuestRoom301','GuestRoom302_305','GuestRoom306_308','GuestRoom309_312','GuestRoom313',
                        'GuestRoom314','GuestRoom315_318','GuestRoom319','GuestRoom320_323','GuestRoom324',
                        'GuestRoom401','GuestRoom402_405','GuestRoom406_408','GuestRoom409_412','GuestRoom413',
                        'GuestRoom414','GuestRoom415_418','GuestRoom419','GuestRoom420_423','GuestRoom424'],
        'Laundry' => ['LaundryRoomFlr1'],
        'Mechanical' => ['MechanicalRoomFlr1'],
        'Meeting' => ['MeetingRoomFlr1'],
        'PublicRestroom' => ['RestroomFlr1'],
        'Attic' => ['Attic']
      }
    when 'DOE Ref 1980-2004'
      space_type_map = {
        'Corridor' => ['CorridorFlr1','CorridorFlr2','CorridorFlr3','CorridorFlr4'],
        # 'ElevatorCore' => ['ElevatorCoreFlr1','ElevatorCoreFlr2','ElevatorCoreFlr3','ElevatorCoreFlr4'],  #TODO put elevators into Mechanical type temperarily
        'Elec/MechRoom' => ['ElevatorCoreFlr1'],
        'ElevatorCore' => ['ElevatorCoreFlr2','ElevatorCoreFlr3','ElevatorCoreFlr4'],
        'StaffLounge' => ['EmployeeLoungeFlr1'],
        'Exercise' => ['ExerciseCenterFlr1'],
        'GuestLounge' => ['FrontLoungeFlr1'],
        'Office' => ['FrontOfficeFlr1'],
        'Stair' => ['FrontStairsFlr1','FrontStairsFlr2','FrontStairsFlr3','FrontStairsFlr4',
                     'RearStairsFlr1','RearStairsFlr2','RearStairsFlr3','RearStairsFlr4'],
        'Storage' => ['FrontStorageFlr1','FrontStorageFlr2','FrontStorageFlr3','FrontStorageFlr4',
                      'RearStorageFlr1','RearStorageFlr2','RearStorageFlr3','RearStorageFlr4'],
        'GuestRoom' => ['GuestRoom101','GuestRoom102','GuestRoom103','GuestRoom104','GuestRoom105',
                        'GuestRoom201','GuestRoom202_205','GuestRoom206_208','GuestRoom209_212','GuestRoom213',
                        'GuestRoom214','GuestRoom215_218','GuestRoom219','GuestRoom220_223','GuestRoom224',
                        'GuestRoom301','GuestRoom302_305','GuestRoom306_308','GuestRoom309_312','GuestRoom313',
                        'GuestRoom314','GuestRoom315_318','GuestRoom319','GuestRoom320_323','GuestRoom324',
                        'GuestRoom401','GuestRoom402_405','GuestRoom406_408','GuestRoom409_412','GuestRoom413',
                        'GuestRoom414','GuestRoom415_418','GuestRoom419','GuestRoom420_423','GuestRoom424'],
        'Laundry' => ['LaundryRoomFlr1'],
        'Mechanical' => ['MechanicalRoomFlr1'],
        'Meeting' => ['MeetingRoomFlr1'],
        'PublicRestroom' => ['RestroomFlr1'],
        'Attic' => ['Attic']
      }
    when '90.1-2010','90.1-2007','90.1-2004','90.1-2013'
      space_type_map = {
        'Corridor' => ['CorridorFlr1','CorridorFlr2','CorridorFlr3'],
        'Corridor4' => ['CorridorFlr4'],
        'Elec/MechRoom' => ['ElevatorCoreFlr1'],
        'ElevatorCore' => ['ElevatorCoreFlr2','ElevatorCoreFlr3'],
        'ElevatorCore4' => ['ElevatorCoreFlr4'],
        'StaffLounge' => ['EmployeeLoungeFlr1'],
        'Exercise' => ['ExerciseCenterFlr1'],
        'GuestLounge' => ['FrontLoungeFlr1'],
        'Office' => ['FrontOfficeFlr1'],
        'Stair' => ['FrontStairsFlr1','FrontStairsFlr2','FrontStairsFlr3',
                     'RearStairsFlr1','RearStairsFlr2','RearStairsFlr3'],
        'Stair4' => ['FrontStairsFlr4','RearStairsFlr4'],
        'Storage' => ['FrontStorageFlr1','FrontStorageFlr2','FrontStorageFlr3',
                      'RearStorageFlr1','RearStorageFlr2','RearStorageFlr3'],
        'Storage4Front' => ['FrontStorageFlr4'],
        'Storage4Rear' => ['RearStorageFlr4'],
        'GuestRoom123Occ' => ['GuestRoom103','GuestRoom104','GuestRoom105','GuestRoom202_205','GuestRoom206_208',
                        'GuestRoom209_212','GuestRoom213','GuestRoom214','GuestRoom219','GuestRoom220_223',
                        'GuestRoom224','GuestRoom309_312','GuestRoom314','GuestRoom315_318','GuestRoom320_323'],
        'GuestRoom123Vac' => ['GuestRoom101','GuestRoom102','GuestRoom201','GuestRoom215_218','GuestRoom301',
                          'GuestRoom302_305','GuestRoom306_308','GuestRoom313','GuestRoom319','GuestRoom324'],
        'GuestRoom4Occ' => ['GuestRoom401','GuestRoom409_412','GuestRoom415_418','GuestRoom419','GuestRoom420_423','GuestRoom424'],
        'GuestRoom4Vac' => ['GuestRoom402_405','GuestRoom406_408','GuestRoom413','GuestRoom414'],
        'Laundry' => ['LaundryRoomFlr1'],
        'Mechanical' => ['MechanicalRoomFlr1'],
        'Meeting' => ['MeetingRoomFlr1'],
        'PublicRestroom' => ['RestroomFlr1'],
        # 'Attic' => ['Attic']

      }
      
    end  

    return space_type_map

  end

  def define_hvac_system_map(building_type, building_vintage, climate_zone)

    system_to_space_map = nil
    
    case building_vintage
    when 'DOE Ref Pre-1980'
      system_to_space_map = [
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom101']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom102']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom103']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom104']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom105']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom201']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom202_205']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom206_208']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom209_212']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom213']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom214']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom215_218']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom219']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom220_223']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom224']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom301']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom302_305']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom306_308']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom309_312']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom313']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom314']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom315_318']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom319']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom320_323']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom324']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom401']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom402_405']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom406_408']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom409_412']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom413']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom414']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom415_418']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom419']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom420_423']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom424']},
        {'type' => 'PTAC',
        'space_names' => ['CorridorFlr1']},
        {'type' => 'PTAC',
        'space_names' => ['CorridorFlr2']},
        {'type' => 'PTAC',
        'space_names' => ['CorridorFlr3']},
        {'type' => 'PTAC',
        'space_names' => ['CorridorFlr4']},
        {'type' => 'PTAC',
        'space_names' => ['EmployeeLoungeFlr1']},
        {'type' => 'PTAC',
        'space_names' => ['ExerciseCenterFlr1']},
        {'type' => 'PTAC',
        'space_names' => ['FrontLoungeFlr1']},
        {'type' => 'PTAC',
        'space_names' => ['FrontOfficeFlr1']},
        {'type' => 'PTAC',
        'space_names' => ['LaundryRoomFlr1']},
        {'type' => 'PTAC',
        'space_names' => ['MechanicalRoomFlr1']},
        {'type' => 'PTAC',
        'space_names' => ['MeetingRoomFlr1']},
        {'type' => 'PTAC',
        'space_names' => ['RestroomFlr1']},

        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr4']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr4']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStorageFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStorageFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStorageFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStorageFlr4']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStorageFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStorageFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStorageFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStorageFlr4']}
      ]
    when 'DOE Ref 1980-2004'
     system_to_space_map = [
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom101']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom102']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom103']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom104']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom105']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom201']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom202_205']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom206_208']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom209_212']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom213']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom214']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom215_218']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom219']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom220_223']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom224']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom301']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom302_305']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom306_308']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom309_312']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom313']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom314']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom315_318']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom319']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom320_323']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom324']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom401']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom402_405']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom406_408']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom409_412']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom413']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom414']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom415_418']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom419']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom420_423']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom424']},
        
        {'type' => 'PSZ-AC',
        'space_names' => ['CorridorFlr1']},
        {'type' => 'PSZ-AC',
        'space_names' => ['CorridorFlr2']},
        {'type' => 'PSZ-AC',
        'space_names' => ['CorridorFlr3']},
        {'type' => 'PSZ-AC',
        'space_names' => ['CorridorFlr4']},
        {'type' => 'PSZ-AC',
        'space_names' => ['EmployeeLoungeFlr1']},
        {'type' => 'PSZ-AC',
        'space_names' => ['ExerciseCenterFlr1']},
        {'type' => 'PSZ-AC',
        'space_names' => ['FrontLoungeFlr1']},
        {'type' => 'PSZ-AC',
        'space_names' => ['FrontOfficeFlr1']},
        {'type' => 'PSZ-AC',
        'space_names' => ['LaundryRoomFlr1']},
        {'type' => 'PSZ-AC',
        'space_names' => ['MechanicalRoomFlr1']},
        {'type' => 'PSZ-AC',
        'space_names' => ['MeetingRoomFlr1']},
        {'type' => 'PSZ-AC',
        'space_names' => ['RestroomFlr1']},

        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr4']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr4']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStorageFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStorageFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStorageFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStorageFlr4']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStorageFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStorageFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStorageFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStorageFlr4']}
      ] 
    when '90.1-2010','90.1-2007','90.1-2004','90.1-2013'
      system_to_space_map = [
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom101']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom102']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom103']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom104']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom105']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom201']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom202_205']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom206_208']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom209_212']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom213']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom214']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom215_218']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom219']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom220_223']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom224']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom301']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom302_305']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom306_308']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom309_312']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom313']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom314']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom315_318']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom319']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom320_323']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom324']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom401']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom402_405']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom406_408']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom409_412']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom413']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom414']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom415_418']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom419']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom420_423']},
        {'type' => 'PTAC',
        'space_names' => ['GuestRoom424']},
        {'type' => 'PTAC',
        'space_names' => ['CorridorFlr1']},
        {'type' => 'PTAC',
        'space_names' => ['CorridorFlr2']},
        {'type' => 'PTAC',
        'space_names' => ['CorridorFlr3']},
        {'type' => 'PTAC',
        'space_names' => ['CorridorFlr4']},

        {'type' => 'SAC',
        'space_names' => ['ExerciseCenterFlr1','EmployeeLoungeFlr1','RestroomFlr1']},
        {'type' => 'SAC',
        'space_names' => ['FrontLoungeFlr1']},
        {'type' => 'SAC',
        'space_names' => ['FrontOfficeFlr1']},
        {'type' => 'SAC',
        'space_names' => ['MeetingRoomFlr1']},

        {'type' => 'UnitHeater',
        'space_names' => ['MechanicalRoomFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['FrontStairsFlr4']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr1']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr2']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr3']},
        {'type' => 'UnitHeater',
        'space_names' => ['RearStairsFlr4']},
      ]
    end

    return system_to_space_map

  end

  def define_building_story_map(building_type, building_vintage, climate_zone)
    
    building_story_map = nil
      
    building_story_map = {
      'BuildingStory1' => [
                          'GuestRoom101','GuestRoom102','GuestRoom103','GuestRoom104','GuestRoom105',
                          'CorridorFlr1','ElevatorCoreFlr1','EmployeeLoungeFlr1','ExerciseCenterFlr1',
                          'FrontLoungeFlr1','FrontOfficeFlr1','FrontStairsFlr1','RearStairsFlr1',
                          'FrontStorageFlr1','RearStorageFlr1','LaundryRoomFlr1','MechanicalRoomFlr1',
                          'MeetingRoomFlr1','RestroomFlr1'],
      'BuildingStory2' => [
                          'GuestRoom201','GuestRoom202_205','GuestRoom206_208','GuestRoom209_212','GuestRoom213',
                          'GuestRoom214','GuestRoom215_218','GuestRoom219','GuestRoom220_223','GuestRoom224',
                          'CorridorFlr2','FrontStairsFlr2','RearStairsFlr2','FrontStorageFlr2','RearStorageFlr2','ElevatorCoreFlr2'],
      'BuildingStory3' => [
                          'GuestRoom301','GuestRoom302_305','GuestRoom306_308','GuestRoom309_312','GuestRoom313',
                          'GuestRoom314','GuestRoom315_318','GuestRoom319','GuestRoom320_323','GuestRoom324',
                          'CorridorFlr3','FrontStairsFlr3','RearStairsFlr3','FrontStorageFlr3','RearStorageFlr3','ElevatorCoreFlr3'],
      'BuildingStory4' => [
                          'GuestRoom401','GuestRoom402_405','GuestRoom406_408','GuestRoom409_412','GuestRoom413',
                          'GuestRoom414','GuestRoom415_418','GuestRoom419','GuestRoom420_423','GuestRoom424',
                          'CorridorFlr4','FrontStairsFlr4','RearStairsFlr4','FrontStorageFlr4','RearStorageFlr4','ElevatorCoreFlr4']
       }
      
      # attic only applies to the two DOE vintages.
      puts "building_vintage = #{building_vintage}"
      if building_vintage == 'DOE Ref Pre-1980' or building_vintage == 'DOE Ref 1980-2004'
        building_story_map['AtticStory'] = ['Attic'] 
      end        
    return building_story_map
  end

  def add_hvac(building_type, building_vintage, climate_zone, prototype_input, hvac_standards)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding HVAC")
    
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)
        
    system_to_space_map.each do |system|

      #find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = self.getSpaceByName(space_name)
        if space.empty?
          OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "No thermal zone created for space called #{space_name} was found in the model")
          return false
        end
        thermal_zones << zone.get
      end

      case system['type']
      when 'PTAC'
        self.add_ptac(prototype_input, hvac_standards, thermal_zones)
      when 'UnitHeater'
        self.add_unitheater(prototype_input, hvac_standards, thermal_zones)
      when 'PSZ-AC'
        self.add_psz_ac(prototype_input, hvac_standards, system['name'], thermal_zones)
      when 'SAC'
        self.add_split_AC(prototype_input, hvac_standards, thermal_zones)  
      end

    end

    # add extra infiltration for corridor1 door
    corridor_space = self.getSpaceByName('CorridorFlr1')
    corridor_space = corridor_space.get
    unless building_vintage == 'DOE Ref 1980-2004' or building_vintage == 'DOE Ref Pre-1980'
      infiltration_corridor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(self)
      infiltration_corridor.setName("Corridor1 door Infiltration")
      infiltration_per_zone = 0
      if building_vintage == '90.1-2010' or building_vintage == '90.1-2007'
        infiltration_per_zone = 0.591821538
      else
        infiltration_per_zone = 0.91557718
      end
      infiltration_corridor.setDesignFlowRate(infiltration_per_zone)
      infiltration_corridor.setSchedule(add_schedule('HotelSmall INFIL_Door_Opening_SCH'))
      infiltration_corridor.setSpace(corridor_space)
    end
    
    # hardsize corridor1. put in standards in the future  #TODO
    unless building_vintage == 'DOE Ref 1980-2004' or building_vintage == 'DOE Ref Pre-1980' 
      self.getZoneHVACPackagedTerminalAirConditioners.sort.each do |ptac|
        zone = ptac.thermalZone.get
        if zone.spaces.include?(corridor_space)
          ptac.setSupplyAirFlowRateDuringCoolingOperation(0.13)
          ptac.setSupplyAirFlowRateDuringHeatingOperation(0.13)
          ptac.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(0.13)
          ccoil = ptac.coolingCoil
          if ccoil.to_CoilCoolingDXSingleSpeed.is_initialized
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedTotalCoolingCapacity(2638)  # Unit: W
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedAirFlowRate(0.13)
          end
        end
      end
    end  

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding HVAC")
    
    return true
    
  end #add hvac

  def add_swh(building_type, building_vintage, climate_zone, prototype_input, hvac_standards, space_type_map)
   
    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Started Adding SWH")
    
    # the main service water loop except laundry
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
      elsif space_type_name == "Laundry" and building_vintage != 'DOE Ref 1980-2004' and building_vintage != 'DOE Ref Pre-1980'
        next
      else
        space_names.each do |space_name|
          self.add_swh_end_uses_by_space(building_type, building_vintage, climate_zone, main_swh_loop, space_type_name, space_name)
        end
      end
    end
    
    unless building_vintage == 'DOE Ref 1980-2004' or building_vintage == 'DOE Ref Pre-1980'
      laundry_swh_loop = self.add_swh_loop(prototype_input, hvac_standards, 'laundry')
      self.add_swh_end_uses(prototype_input, hvac_standards, laundry_swh_loop, 'laundry')
    end

    OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Model", "Finished adding SWH")
    
    return true
    
  end #add swh  
  
end


# Modules for building-type specific methods
module PrototypeBuilding
module SmallHotel
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil

    case template
    when 'DOE Ref Pre-1980'
      space_type_map = {
        'Corridor' => ['CorridorFlr1', 'CorridorFlr2', 'CorridorFlr3', 'CorridorFlr4'],
        'Elec/MechRoom' => ['ElevatorCoreFlr1'],
        'ElevatorCore' => ['ElevatorCoreFlr2', 'ElevatorCoreFlr3', 'ElevatorCoreFlr4'],
        'StaffLounge' => ['EmployeeLoungeFlr1'],
        'Exercise' => ['ExerciseCenterFlr1'],
        'GuestLounge' => ['FrontLoungeFlr1'],
        'Office' => ['FrontOfficeFlr1'],
        'Stair' => ['FrontStairsFlr1', 'FrontStairsFlr2', 'FrontStairsFlr3', 'FrontStairsFlr4', 'RearStairsFlr1', 'RearStairsFlr2', 'RearStairsFlr3', 'RearStairsFlr4'],
        'Storage' => ['FrontStorageFlr1', 'FrontStorageFlr2', 'FrontStorageFlr3', 'FrontStorageFlr4', 'RearStorageFlr1', 'RearStorageFlr2', 'RearStorageFlr3', 'RearStorageFlr4'],
        'GuestRoom' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'GuestRoom201', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom215_218', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom309_312', 'GuestRoom313', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom319', 'GuestRoom320_323', 'GuestRoom324', 'GuestRoom401', 'GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom409_412', 'GuestRoom413', 'GuestRoom414', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424'],
        'Laundry' => ['LaundryRoomFlr1'],
        'Mechanical' => ['MechanicalRoomFlr1'],
        'Meeting' => ['MeetingRoomFlr1'],
        'PublicRestroom' => ['RestroomFlr1'],
        'Attic' => ['Attic']
      }
    when 'DOE Ref 1980-2004'
      space_type_map = {
        'Corridor' => ['CorridorFlr1', 'CorridorFlr2', 'CorridorFlr3', 'CorridorFlr4'],
        # 'ElevatorCore' => ['ElevatorCoreFlr1','ElevatorCoreFlr2','ElevatorCoreFlr3','ElevatorCoreFlr4'],  #TODO put elevators into Mechanical type temperarily
        'Elec/MechRoom' => ['ElevatorCoreFlr1'],
        'ElevatorCore' => ['ElevatorCoreFlr2', 'ElevatorCoreFlr3', 'ElevatorCoreFlr4'],
        'StaffLounge' => ['EmployeeLoungeFlr1'],
        'Exercise' => ['ExerciseCenterFlr1'],
        'GuestLounge' => ['FrontLoungeFlr1'],
        'Office' => ['FrontOfficeFlr1'],
        'Stair' => ['FrontStairsFlr1', 'FrontStairsFlr2', 'FrontStairsFlr3', 'FrontStairsFlr4', 'RearStairsFlr1', 'RearStairsFlr2', 'RearStairsFlr3', 'RearStairsFlr4'],
        'Storage' => ['FrontStorageFlr1', 'FrontStorageFlr2', 'FrontStorageFlr3', 'FrontStorageFlr4', 'RearStorageFlr1', 'RearStorageFlr2', 'RearStorageFlr3', 'RearStorageFlr4'],
        'GuestRoom' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'GuestRoom201', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom215_218', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom309_312', 'GuestRoom313', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom319', 'GuestRoom320_323', 'GuestRoom324', 'GuestRoom401', 'GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom409_412', 'GuestRoom413', 'GuestRoom414', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424'],
        'Laundry' => ['LaundryRoomFlr1'],
        'Mechanical' => ['MechanicalRoomFlr1'],
        'Meeting' => ['MeetingRoomFlr1'],
        'PublicRestroom' => ['RestroomFlr1'],
        'Attic' => ['Attic']
      }
    when '90.1-2010', '90.1-2007', '90.1-2004', '90.1-2013'
      space_type_map = {
        'Corridor' => ['CorridorFlr1', 'CorridorFlr2', 'CorridorFlr3'],
        'Corridor4' => ['CorridorFlr4'],
        'Elec/MechRoom' => ['ElevatorCoreFlr1'],
        'ElevatorCore' => ['ElevatorCoreFlr2', 'ElevatorCoreFlr3'],
        'ElevatorCore4' => ['ElevatorCoreFlr4'],
        'StaffLounge' => ['EmployeeLoungeFlr1'],
        'Exercise' => ['ExerciseCenterFlr1'],
        'GuestLounge' => ['FrontLoungeFlr1'],
        'Office' => ['FrontOfficeFlr1'],
        'Stair' => ['FrontStairsFlr1', 'FrontStairsFlr2', 'FrontStairsFlr3', 'RearStairsFlr1', 'RearStairsFlr2', 'RearStairsFlr3'],
        'Stair4' => ['FrontStairsFlr4', 'RearStairsFlr4'],
        'Storage' => ['FrontStorageFlr1', 'FrontStorageFlr2', 'FrontStorageFlr3', 'RearStorageFlr1', 'RearStorageFlr2', 'RearStorageFlr3'],
        'Storage4Front' => ['FrontStorageFlr4'],
        'Storage4Rear' => ['RearStorageFlr4'],
        'GuestRoom123Occ' => ['GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'GuestRoom309_312', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom320_323'],
        'GuestRoom123Vac' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom201', 'GuestRoom215_218', 'GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom313', 'GuestRoom319', 'GuestRoom324'],
        'GuestRoom4Occ' => ['GuestRoom401', 'GuestRoom409_412', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424'],
        'GuestRoom4Vac' => ['GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom413', 'GuestRoom414'],
        'Laundry' => ['LaundryRoomFlr1'],
        'Mechanical' => ['MechanicalRoomFlr1'],
        'Meeting' => ['MeetingRoomFlr1'],
        'PublicRestroom' => ['RestroomFlr1'],
        # 'Attic' => ['Attic']

      }
    when 'NECB 2011'
      sch = 'F'
      space_type_map = {
        "Corr. >= 2.4m wide-sch-#{sch}" => ['CorridorFlr1', 'CorridorFlr2', 'CorridorFlr3', 'CorridorFlr4'],
        'Lobby - elevator' => ['ElevatorCoreFlr1', 'ElevatorCoreFlr2', 'ElevatorCoreFlr3', 'ElevatorCoreFlr4'],
        'Lounge/recreation' => ['EmployeeLoungeFlr1'],
        'Gym - fitness' => ['ExerciseCenterFlr1'],
        'Hotel/Motel - lobby' => ['FrontLoungeFlr1'],
        'Office - enclosed' => ['FrontOfficeFlr1'],
        "Stairway-sch-#{sch}" => ['FrontStairsFlr1', 'FrontStairsFlr2', 'FrontStairsFlr3', 'FrontStairsFlr4', 'RearStairsFlr1', 'RearStairsFlr2', 'RearStairsFlr3', 'RearStairsFlr4'],
        'Storage area' => ['FrontStorageFlr1', 'FrontStorageFlr2', 'FrontStorageFlr3', 'FrontStorageFlr4', 'LaundryRoomFlr1', 'RearStorageFlr1', 'RearStorageFlr2', 'RearStorageFlr3', 'RearStorageFlr4'],
        'Hway lodging - rooms' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'GuestRoom201', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom215_218', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom309_312', 'GuestRoom313', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom319', 'GuestRoom320_323', 'GuestRoom324', 'GuestRoom401', 'GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom409_412', 'GuestRoom413', 'GuestRoom414', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424'],
        "Electrical/Mechanical-sch-#{sch}" => ['MechanicalRoomFlr1', 'MeetingRoomFlr1'],
        "Washroom-sch-#{sch}" => ['RestroomFlr1']
      }

    end

    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = nil

    case template
    when 'DOE Ref Pre-1980'
      system_to_space_map = [
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom101'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom102'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom103'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom104'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom105'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom201'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom202_205'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom206_208'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom209_212'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom213'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom214'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom215_218'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom219'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom220_223'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom224'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom301'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom302_305'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom306_308'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom309_312'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom313'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom314'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom315_318'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom319'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom320_323'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom324'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom401'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom402_405'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom406_408'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom409_412'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom413'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom414'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom415_418'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom419'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom420_423'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom424'] },
        { 'type' => 'PTAC',
          'space_names' => ['CorridorFlr1'] },
        { 'type' => 'PTAC',
          'space_names' => ['CorridorFlr2'] },
        { 'type' => 'PTAC',
          'space_names' => ['CorridorFlr3'] },
        { 'type' => 'PTAC',
          'space_names' => ['CorridorFlr4'] },
        { 'type' => 'PTAC',
          'space_names' => ['EmployeeLoungeFlr1'] },
        { 'type' => 'PTAC',
          'space_names' => ['ExerciseCenterFlr1'] },
        { 'type' => 'PTAC',
          'space_names' => ['FrontLoungeFlr1'] },
        { 'type' => 'PTAC',
          'space_names' => ['FrontOfficeFlr1'] },
        { 'type' => 'PTAC',
          'space_names' => ['LaundryRoomFlr1'] },
        { 'type' => 'PTAC',
          'space_names' => ['MechanicalRoomFlr1'] },
        { 'type' => 'PTAC',
          'space_names' => ['MeetingRoomFlr1'] },
        { 'type' => 'PTAC',
          'space_names' => ['RestroomFlr1'] },

        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr4'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr4'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStorageFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStorageFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStorageFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStorageFlr4'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStorageFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStorageFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStorageFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStorageFlr4'] }
      ]
    when 'DOE Ref 1980-2004'
      system_to_space_map = [
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom101'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom102'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom103'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom104'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom105'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom201'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom202_205'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom206_208'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom209_212'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom213'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom214'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom215_218'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom219'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom220_223'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom224'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom301'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom302_305'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom306_308'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom309_312'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom313'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom314'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom315_318'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom319'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom320_323'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom324'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom401'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom402_405'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom406_408'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom409_412'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom413'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom414'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom415_418'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom419'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom420_423'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom424'] },

        { 'type' => 'PSZ-AC',
          'space_names' => ['CorridorFlr1'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['CorridorFlr2'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['CorridorFlr3'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['CorridorFlr4'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['EmployeeLoungeFlr1'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['ExerciseCenterFlr1'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['FrontLoungeFlr1'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['FrontOfficeFlr1'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['LaundryRoomFlr1'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['MechanicalRoomFlr1'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['MeetingRoomFlr1'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['RestroomFlr1'] },

        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr4'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr4'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStorageFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStorageFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStorageFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStorageFlr4'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStorageFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStorageFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStorageFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStorageFlr4'] }
      ]
    when '90.1-2010', '90.1-2007', '90.1-2004', '90.1-2013'
      system_to_space_map = [
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom101'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom102'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom103'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom104'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom105'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom201'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom202_205'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom206_208'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom209_212'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom213'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom214'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom215_218'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom219'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom220_223'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom224'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom301'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom302_305'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom306_308'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom309_312'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom313'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom314'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom315_318'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom319'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom320_323'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom324'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom401'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom402_405'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom406_408'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom409_412'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom413'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom414'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom415_418'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom419'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom420_423'] },
        { 'type' => 'PTAC',
          'space_names' => ['GuestRoom424'] },
        { 'type' => 'PTAC',
          'space_names' => ['CorridorFlr1'] },
        { 'type' => 'PTAC',
          'space_names' => ['CorridorFlr2'] },
        { 'type' => 'PTAC',
          'space_names' => ['CorridorFlr3'] },
        { 'type' => 'PTAC',
          'space_names' => ['CorridorFlr4'] },

        { 'type' => 'SAC',
          'space_names' => ['ExerciseCenterFlr1', 'EmployeeLoungeFlr1', 'RestroomFlr1'] },
        { 'type' => 'SAC',
          'space_names' => ['FrontLoungeFlr1'] },
        { 'type' => 'SAC',
          'space_names' => ['FrontOfficeFlr1'] },
        { 'type' => 'SAC',
          'space_names' => ['MeetingRoomFlr1'] },

        { 'type' => 'UnitHeater',
          'space_names' => ['MechanicalRoomFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['FrontStairsFlr4'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr1'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr2'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr3'] },
        { 'type' => 'UnitHeater',
          'space_names' => ['RearStairsFlr4'] }
      ]
    end

    return system_to_space_map
  end

  def self.define_building_story_map(building_type, template, climate_zone)
    building_story_map = nil

    building_story_map = {
      'BuildingStory1' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'CorridorFlr1', 'ElevatorCoreFlr1', 'EmployeeLoungeFlr1', 'ExerciseCenterFlr1', 'FrontLoungeFlr1', 'FrontOfficeFlr1', 'FrontStairsFlr1', 'RearStairsFlr1', 'FrontStorageFlr1', 'RearStorageFlr1', 'LaundryRoomFlr1', 'MechanicalRoomFlr1', 'MeetingRoomFlr1', 'RestroomFlr1'],
      'BuildingStory2' => ['GuestRoom201', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom215_218', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'CorridorFlr2', 'FrontStairsFlr2', 'RearStairsFlr2', 'FrontStorageFlr2', 'RearStorageFlr2', 'ElevatorCoreFlr2'],
      'BuildingStory3' => ['GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom309_312', 'GuestRoom313', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom319', 'GuestRoom320_323', 'GuestRoom324', 'CorridorFlr3', 'FrontStairsFlr3', 'RearStairsFlr3', 'FrontStorageFlr3', 'RearStorageFlr3', 'ElevatorCoreFlr3'],
      'BuildingStory4' => ['GuestRoom401', 'GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom409_412', 'GuestRoom413', 'GuestRoom414', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424', 'CorridorFlr4', 'FrontStairsFlr4', 'RearStairsFlr4', 'FrontStorageFlr4', 'RearStorageFlr4', 'ElevatorCoreFlr4']
    }

    # attic only applies to the two DOE vintages.
    if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'
      building_story_map['AtticStory'] = ['Attic']
    end
    return building_story_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add elevator for the elevator coreflr1  (the elevator lift already added via standard spreadsheet)
    PrototypeBuilding::SmallHotel.add_extra_equip_elevator_coreflr1(template, model)
    
    # add extra infiltration for corridor1 door
    corridor_space = model.getSpaceByName('CorridorFlr1')
    corridor_space = corridor_space.get
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      infiltration_corridor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_corridor.setName('Corridor1 door Infiltration')
      infiltration_per_zone = 0
      infiltration_per_zone = if template == '90.1-2010' || template == '90.1-2007'
                                0.591821538
                              else
                                0.91557718
                              end
      infiltration_corridor.setDesignFlowRate(infiltration_per_zone)
      infiltration_corridor.setSchedule(model.add_schedule('HotelSmall INFIL_Door_Opening_SCH'))
      infiltration_corridor.setSpace(corridor_space)
    end

    # hardsize corridor1. put in standards in the future  #TODO
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      model.getZoneHVACPackagedTerminalAirConditioners.sort.each do |ptac|
        zone = ptac.thermalZone.get
        if zone.spaces.include?(corridor_space)
          ptac.setSupplyAirFlowRateDuringCoolingOperation(0.13)
          ptac.setSupplyAirFlowRateDuringHeatingOperation(0.13)
          ptac.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(0.13)
          ccoil = ptac.coolingCoil
          if ccoil.to_CoilCoolingDXSingleSpeed.is_initialized
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedTotalCoolingCapacity(2638) # Unit: W
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedAirFlowRate(0.13)
          end
        end
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end
  
  # add this for elevator lights/fans (elevator lift is implemented through standard lookup)
  def self.add_extra_equip_elevator_coreflr1(template, model)
    elevator_coreflr1 = model.getSpaceByName('ElevatorCoreFlr1').get
    elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def.setName('Elevator CoreFlr1 Electric Equipment Definition')
    elec_equip_def.setFractionLatent(0)
    elec_equip_def.setFractionRadiant(0.5)
    elec_equip_def.setFractionLost(0.0)
    elec_equip_def.setDesignLevel(125)
    elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
    elec_equip.setName('Elevator Coreflr1 Elevator Lights/Fans Equipment')
    elec_equip.setSpace(elevator_coreflr1)
    case template
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      elec_equip.setSchedule(model.add_schedule('HotelSmall ELEV_LIGHT_FAN_SCH_ADD_DF'))
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      elec_equip.setSchedule(model.add_schedule('HotelSmall ELEV_LIGHT_FAN_SCH_ADD_DF'))
    end
    return true
  end

  

  
  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end
end

require_relative '../../../test/helpers/minitest_helper'

require 'json'

# load json
nrel_building_types = [
  'FullServiceRestaurant',
  'Hospital',
  'HighriseApartment',
  'LargeHotel',
  'LargeOffice',
  'MediumOffice',
  'LargeOfficeDetailed',
  'MediumOfficeDetailed',
  'MidriseApartment',
  'Outpatient',
  'PrimarySchool',
  'QuickServiceRestaurant',
  'RetailStandalone',
  'SecondarySchool',
  'SmallHotel',
  'SmallOffice',
  'SmallOfficeDetailed',
  'RetailStripmall',
  'Warehouse'

]

templates = ['90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2016', '90.1-2019', 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', 'NECB2011']
new_templates = ['ASHRAE9012004', 'ASHRAE9012007', 'ASHRAE9012010', 'ASHRAE9012013', 'ASHRAE9012016', 'ASHRAE9012019', 'DOERefPre1980', 'DOERef1980to2004', 'NECB2011']

array = []
Dir.glob('/home/osdev/openstudio-standards/openstudio-standards/data/geometry/archetypes//**/*.json').each do |filename|
  building_name = File.basename(filename, '.json')
  data = JSON.parse(File.read(filename))

  templates.each_with_index do |template, i|
    space_type_map = nil
    # puts data[building_name]['space_map']
    data[building_name]['space_map'].each do |space_map|
      if space_map['template'].include?(template)
        space_type_map = space_map['space_type_map']
      end
    end
    system_to_space_map = {}

    eval <<DYNAMICCLASS
system_to_space_map =  PrototypeBuilding::#{building_name}.define_hvac_system_map("#{building_name}", "#{template}", nil)
DYNAMICCLASS

    array << info = {}

    info['class_name'] = "#{new_templates[i]}#{building_name}"
    info['template'] = template
    info['building_type'] = building_name
    info['geometry'] = data[building_name]['geometry'][template]
    info['space_type_map'] = space_type_map
    info['space_multiplier_map'] = data[building_name]['space_multiplier_map']
    info['system_to_space_map'] = system_to_space_map

    if building_name == 'SmallHotel'
      info['building_story_map'] = {
        'BuildingStory1' => [
          'GuestRoom101',
          'GuestRoom102',
          'GuestRoom103',
          'GuestRoom104',
          'GuestRoom105',
          'CorridorFlr1',
          'ElevatorCoreFlr1',
          'EmployeeLoungeFlr1',
          'ExerciseCenterFlr1',
          'FrontLoungeFlr1',
          'FrontOfficeFlr1',
          'FrontStairsFlr1',
          'RearStairsFlr1',
          'FrontStorageFlr1',
          'RearStorageFlr1',
          'LaundryRoomFlr1',
          'MechanicalRoomFlr1',
          'MeetingRoomFlr1',
          'RestroomFlr1'
        ],
        'BuildingStory2' => [
          'GuestRoom201',
          'GuestRoom202_205',
          'GuestRoom206_208',
          'GuestRoom209_212',
          'GuestRoom213',
          'GuestRoom214',
          'GuestRoom215_218',
          'GuestRoom219',
          'GuestRoom220_223',
          'GuestRoom224',
          'CorridorFlr2',
          'FrontStairsFlr2',
          'RearStairsFlr2',
          'FrontStorageFlr2',
          'RearStorageFlr2',
          'ElevatorCoreFlr2'
        ],
        'BuildingStory3' => [
          'GuestRoom301',
          'GuestRoom302_305',
          'GuestRoom306_308',
          'GuestRoom309_312',
          'GuestRoom313',
          'GuestRoom314',
          'GuestRoom315_318',
          'GuestRoom319',
          'GuestRoom320_323',
          'GuestRoom324',
          'CorridorFlr3',
          'FrontStairsFlr3',
          'RearStairsFlr3',
          'FrontStorageFlr3',
          'RearStorageFlr3',
          'ElevatorCoreFlr3'
        ],
        'BuildingStory4' => [
          'GuestRoom401',
          'GuestRoom402_405',
          'GuestRoom406_408',
          'GuestRoom409_412',
          'GuestRoom413',
          'GuestRoom414',
          'GuestRoom415_418',
          'GuestRoom419',
          'GuestRoom420_423',
          'GuestRoom424',
          'CorridorFlr4',
          'FrontStairsFlr4',
          'RearStairsFlr4',
          'FrontStorageFlr4',
          'RearStorageFlr4',
          'ElevatorCoreFlr4'
        ]
      }
      if ['DOE Ref Pre-1980', 'DOE Ref 1980-2004'].include?(template)
        info['building_story_map']['AtticStory'] = ['Attic']
      end
    end
  end
end
array.sort_by! { |k| k['class_name'] }
puts array
File.write("#{File.dirname(__FILE__)}/../refactor/prototypes/common/data/prototype_database.json", JSON.pretty_generate(array))
puts array = JSON.parse(File.read("#{File.dirname(__FILE__)}/../refactor/prototypes/common/data/prototype_database.json"))
puts array.size

# OnDemand Generator script takes 4 arguments in json format
# and returns 1 osm file and 1 osc file and 1 json file of output arguments

# description xml: test_generator2.xml
# IMPORTANT:  for json use double quotes for individual arguments and single quotes to wrap the whole thing (json does not like single quotes)
# command line arguments syntax (json):  '{"test_argument1": "Hot Tub", "test_argument2":2}'

# Upon update, make sure to update the gem version of openstudio AND the openstudio generated files at the
# bottom of this file

require 'rubygems'
require 'json'
require 'fileutils'

gem 'bcl', '~>0.2.3'
require 'bcl.rb'

gem 'openstudio', '=0.9.3'
require 'openstudio.rb'

# SETUP STATUS CODE
status_code = 1

# GET SCRIPT ARGUMNENTS (always a json string to be parsed by the script)
vals = ARGV[0]
args_hash = JSON.parse(vals)

# PARSE ARGUMENTS
if args_hash.key? 'ondemand_uid'
  ondemand_uid = args_hash['ondemand_uid']
else
  ondemand_uid = ''
  # missing argument
  status_code = 0
end
puts "ondemand_uid is: #{ondemand_uid}"

if args_hash.key? 'ondemand_vid'
  ondemand_vid = args_hash['ondemand_vid']
else
  ondemand_vid = ''
  # missing argument
  status_code = 0
end
puts "ondemand_vid is: #{ondemand_vid}"

if args_hash.key? 'apikey'
  apikey = args_hash['apikey']
else
  apikey = ''
  # missing argument
  status_code = 0
end
puts "apikey is: #{apikey}"

if args_hash.key? 'NREL_reference_building_vintage'
  std = args_hash['NREL_reference_building_vintage']
else
  std = ''
  # missing argument
  status_code = 0
end
puts "NREL_reference_building_vintage is: #{std}"

if args_hash.key? 'Climate_zone'
  clim = args_hash['Climate_zone']
else
  clim = ''
  # missing argument
  status_code = 0
end
puts "Climate_zone is: #{clim}"

if args_hash.key? 'NREL_reference_building_primary_space_type'
  ref_bldg_pri_spc_type = args_hash['NREL_reference_building_primary_space_type']
else
  ref_bldg_pri_spc_type = ''
  # missing argument
  status_code = 0
end
puts "NREL_reference_building_primary_space_type is: #{ref_bldg_pri_spc_type}"

if args_hash.key? 'NREL_reference_building_secondary_space_type'
  ref_bldg_sec_spc_type = args_hash['NREL_reference_building_secondary_space_type']
else
  ref_bldg_sec_spc_type = ''
  # missing argument
  status_code = 0
end
puts "NREL_reference_building_secondary_space_type is: #{ref_bldg_sec_spc_type}"

# load the data from the JSON file into a ruby hash
$nrel_spc_types = {}
temp = File.read('lib/nrel_ref_bldg_space_types.json')
$nrel_spc_types = JSON.parse(temp)

# check that the data was loaded correctly
check_data = $nrel_spc_types['ASHRAE_189.1-2009']['ClimateZone 1-3']['Hospital']['Radiology']['lighting_w_per_area']
unless check_data == 0.36
  puts 'Something is wrong with the lookup.'
  # TODO maybe put an exit here?
end

# load up the osm with all the reference building schedules
schedule_library_path = OpenStudio::Path.new("#{Dir.pwd}/lib/Master_Schedules.osm")
$schedule_library = OpenStudio::Model::Model.load(schedule_library_path).get

# make a new openstudio model to hold the space type
$model = OpenStudio::Model::Model.new

# method for converting from IP to SI if you know the strings of the input and the output
def ip_to_si(number, ip_unit_string, si_unit_string)
  ip_unit = OpenStudio.createUnit(ip_unit_string, 'IP'.to_UnitSystem).get
  si_unit = OpenStudio.createUnit(si_unit_string, 'SI'.to_UnitSystem).get
  # puts "#{ip_unit} --> #{si_unit}"
  ip_quantity = OpenStudio::Quantity.new(number, ip_unit)
  si_quantity = OpenStudio.convert(ip_quantity, si_unit).get
  # puts "#{ip_quantity} = #{si_quantity}"
  return si_quantity.value
end

# grabs a schedule with a specific name from the library, clones it into the space type model, and returns itself to the user
def get_sch_from_lib(sch_name)
  # get the correct space type from the library file
  sch = $schedule_library.getObjectByTypeAndName('OS_Schedule_Ruleset'.to_IddObjectType, sch_name)
  # clone the space type from the library model into the space type model
  clone_of_sch = sch.get.to_Schedule.get.clone($model)
  new_sch = clone_of_sch.to_ScheduleRuleset.get
  return new_sch
end

# create a new space type and name it
space_type = OpenStudio::Model::SpaceType.new($model)
space_type.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type}")

# create the schedule set for the space type
default_sch_set = OpenStudio::Model::DefaultScheduleSet.new($model)
default_sch_set.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Schedule Set")
space_type.setDefaultScheduleSet(default_sch_set)

# lighting

make_lighting = false
lighting_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['lighting_w_per_area']
lighting_per_person = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['lighting_w_per_person']
unless lighting_per_area == 0 || lighting_per_area.nil? then make_lighting = true end
unless lighting_per_person == 0 || lighting_per_person.nil? then make_lighting = true end

if make_lighting == true

  # create the lighting definition
  lights_def = OpenStudio::Model::LightsDefinition.new($model)
  lights_def.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Lights Definition")
  unless  lighting_per_area == 0 || lighting_per_area.nil?
    lights_def.setWattsperSpaceFloorArea(ip_to_si(lighting_per_area, 'W/ft^2', 'W/m^2'))
  end
  unless lighting_per_person == 0 || lighting_per_person.nil?
    lights_def.setWattsperPerson(ip_to_si(lighting_per_person, 'W/person', 'W/person'))
  end

  # create the lighting instance and hook it up to the space type
  lights = OpenStudio::Model::Lights.new(lights_def)
  lights.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Lights")
  lights.setSpaceType(space_type)

  # get the lighting schedule and set it as the default
  lighting_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['lighting_sch']
  unless lighting_sch.nil?
    default_sch_set.setLightingSchedule(get_sch_from_lib(lighting_sch))
  end

 end

# ventilation

make_ventilation = false
ventilation_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['ventilation_per_area']
ventilation_per_person = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['ventilation_per_person']
ventilation_ach = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['ventilation_ach']
unless ventilation_per_area  == 0 || ventilation_per_area.nil? then make_ventilation = true  end
unless ventilation_per_person == 0 || ventilation_per_person.nil? then make_ventilation = true end
unless ventilation_ach == 0 || ventilation_ach.nil? then make_ventilation = true end

if make_ventilation == true

  # create the ventilation object and hook it up to the space type
  ventilation = OpenStudio::Model::DesignSpecificationOutdoorAir.new($model)
  ventilation.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Ventilation")
  space_type.setDesignSpecificationOutdoorAir(ventilation)
  ventilation.setOutdoorAirMethod('Sum')
  unless ventilation_per_area  == 0 || ventilation_per_area.nil?
    ventilation.setOutdoorAirFlowperFloorArea(ip_to_si(ventilation_per_area, 'ft^3/min*ft^2', 'm^3/s*m^2'))
  end
  unless ventilation_per_person == 0 || ventilation_per_person.nil?
    ventilation.setOutdoorAirFlowperPerson(ip_to_si(ventilation_per_person, 'ft^3/min*person', 'm^3/s*person'))
  end
  unless ventilation_ach == 0 || ventilation_ach.nil?
    ventilation.setOutdoorAirFlowAirChangesperHour(ventilation_ach)
  end

end

# occupancy

make_people = false
occupancy_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['occupancy_per_area']
unless occupancy_per_area == 0 || occupancy_per_area.nil? then make_people = true end

if make_people == true

  # create the people definition
  people_def = OpenStudio::Model::PeopleDefinition.new($model)
  people_def.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} People Definition")
  unless  occupancy_per_area == 0 || occupancy_per_area.nil?
    people_def.setPeopleperSpaceFloorArea(ip_to_si(occupancy_per_area / 1000, 'people/ft^2', 'people/m^2'))
  end

  # create the people instance and hook it up to the space type
  people = OpenStudio::Model::People.new(people_def)
  people.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} People")
  people.setSpaceType(space_type)

  # get the occupancy and occupant activity schedules from the library and set as the default
  occupancy_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['occupancy_sch']
  unless occupancy_sch.nil?
    default_sch_set.setNumberofPeopleSchedule(get_sch_from_lib(occupancy_sch))
  end
  occupancy_activity_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['occupancy_activity_sch']
  unless occupancy_activity_sch.nil?
    default_sch_set.setPeopleActivityLevelSchedule(get_sch_from_lib(occupancy_activity_sch))
  end

end

# infiltration

make_infiltration = false
infiltration_per_area_ext = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['infiltration_per_area_ext']
unless infiltration_per_area_ext == 0 || infiltration_per_area_ext.nil? then make_infiltration = true end

if make_infiltration == true

  # create the infiltration object and hook it up to the space type
  infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new($model)
  infiltration.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Infiltration")
  infiltration.setSpaceType(space_type)
  unless infiltration_per_area_ext == 0 || infiltration_per_area_ext.nil?
    infiltration.setFlowperExteriorSurfaceArea(ip_to_si(infiltration_per_area_ext, 'ft^3/min*ft^2', 'm^3/s*m^2'))
  end

  # get the infiltration schedule from the library and set as the default
  infiltration_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['infiltration_sch']
  unless infiltration_sch.nil?
    default_sch_set.setInfiltrationSchedule(get_sch_from_lib(infiltration_sch))
  end

end

# electric equipment

make_electric_equipment = false
elec_equip_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['elec_equip_per_area']
unless elec_equip_per_area == 0 || elec_equip_per_area.nil? then make_electric_equipment = true end

if make_electric_equipment == true

  # create the electric equipment definition
  elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new($model)
  elec_equip_def.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Electric Equipment Definition")
  unless  elec_equip_per_area == 0 || elec_equip_per_area.nil?
    elec_equip_def.setWattsperSpaceFloorArea(ip_to_si(elec_equip_per_area, 'W/ft^2', 'W/m^2'))
  end

  # create the electric equipment instance and hook it up to the space type
  elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
  elec_equip.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Electric Equipment")
  elec_equip.setSpaceType(space_type)

  # get the electric equipment schedule from the library and set as the default
  elec_equip_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['elec_equip_sch']
  unless elec_equip_sch.nil?
    default_sch_set.setElectricEquipmentSchedule(get_sch_from_lib(elec_equip_sch))
  end

end

# gas equipment

make_gas_equipment = false
gas_equip_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['gas_equip_per_area']
unless  gas_equip_per_area == 0 || gas_equip_per_area.nil? then make_gas_equipment = true end

if make_gas_equipment == true

  # create the gas equipment definition
  gas_equip_def = OpenStudio::Model::GasEquipmentDefinition.new($model)
  gas_equip_def.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Gas Equipment Definition")
  unless  gas_equip_per_area == 0 || gas_equip_per_area.nil?
    gas_equip_def.setWattsperSpaceFloorArea(ip_to_si(gas_equip_per_area, 'Btu/hr*ft^2', 'W/m^2'))
  end

  # create the gas equipment instance and hook it up to the space type
  gas_equip = OpenStudio::Model::GasEquipment.new(gas_equip_def)
  gas_equip.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Gas Equipment")
  gas_equip.setSpaceType(space_type)

  # get the gas equipment schedule from the library and set as the default
  gas_equip_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['gas_equip_sch']
  unless gas_equip_sch.nil?
    default_sch_set.setGasEquipmentSchedule(get_sch_from_lib(gas_equip_sch))
  end

end

# component name
component_name = space_type.name.get

# setup the file names and save paths that will be used
file_name = 'nrel_ref_bldg_space_type'
component_dir = "#{Dir.pwd}/#{component_name}"
osm_file_path = OpenStudio::Path.new("#{component_dir}/files/#{file_name}.osm")
osc_file_path = OpenStudio::Path.new("#{component_dir}/files/#{file_name}.osc")

# puts "component_dir = #{component_dir}"

puts 'creating directories'
FileUtils.rm_rf(component_dir) if File.exist?(component_dir) && File.directory?(component_dir)
FileUtils.mkdir_p(component_dir)
FileUtils.mkdir_p("#{component_dir}/files/")

# save the space type as a .osm
# puts "saving osm to #{osm_file_path}"
$model.toIdfFile.save(osm_file_path, true)

# componentize the space type
space_type_component = space_type.createComponent
puts "space_type_component = #{space_type_component}"

# save the componentized space type as a .osc
# puts "saving osc to #{osc_file_path}"
space_type_component.toIdfFile.save(osc_file_path, true)

# make the component
puts 'creating BCL component'
component = BCL::Component.new(component_dir)
puts "created uid = #{component.uuid}"

component.name = component_name
component.description = 'This on-demand generator returns space types that represent spaces in typical commercial buildings in the United States.  The information to create these space types was taken from the DOE Commercial Reference Building Models, which can be found at http://www1.eere.energy.gov/buildings/commercial_initiative/reference_buildings.html.  These space types include plug loads, gas equipment loads (cooking, etc), occupancy, infiltration, and ventilation rates, as well as schedules.  These space types should be viewed as starting points, and should be reviewed before being used to make decisions.'
component.source_manufacturer = 'DOE'
component.source_url = 'http://www1.eere.energy.gov/buildings/commercial_initiative/reference_buildings.html'
component.add_provenance('dgoldwas', Time.now.gmtime.strftime('%Y-%m-%dT%H:%M:%SZ'), '')
component.add_tag('Space Types') # todo: what is the taxonomy string for space type? is there one?

# generator description as attribute
component.add_attribute('OnDemandGenerator UID', ondemand_uid, '')
component.add_attribute('OnDemandGenerator VID', ondemand_vid, '')

# add arguments as attributes
component.add_attribute('NREL_reference_building_vintage', std, '')
component.add_attribute('Climate_zone', clim, '')
component.add_attribute('NREL_reference_building_primary_space_type', ref_bldg_pri_spc_type, '')
component.add_attribute('NREL_reference_building_secondary_space_type', ref_bldg_sec_spc_type, '')

# openstudio type attribute
component.add_attribute('OpenStudio Type', space_type.iddObjectType.valueDescription, '')

# add other attributes
component.add_attribute('Lighting Standard',  $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['lighting_standard'], '')
component.add_attribute('Lighting Primary Space Type',  $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['lighting_pri_spc_type'], '')
component.add_attribute('Lighting Secondary Space Type',  $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['lighting_sec_spc_type'], '')

component.add_attribute('Ventilation Standard',  $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['ventilation_standard'], '')
component.add_attribute('Ventilation Primary Space Type',  $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['ventilation_pri_spc_type'], '')
component.add_attribute('Ventilation Secondary Space Type',  $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]['ventilation_sec_spc_type'], '')

component.add_attribute('Occupancy Standard',  'NREL reference buildings', '')
component.add_attribute('Occupancy Primary Space Type',  ref_bldg_pri_spc_type, '')
component.add_attribute('Occupancy Secondary Space Type',  ref_bldg_sec_spc_type, '')

component.add_attribute('Infiltration, Gas Equipment, Electric Equipment, and Schedules Standard',  'NREL reference buildings', '')
component.add_attribute('Infiltration, Gas Equipment, Electric Equipment, and Schedules Primary Space Type',  ref_bldg_pri_spc_type, '')
component.add_attribute('Infiltration, Gas Equipment, Electric Equipment, and Schedules Secondary Space Type',  ref_bldg_sec_spc_type, '')

component.add_file('OpenStudio', '0.9.3',  osm_file_path.to_s, "#{file_name}.osm", 'osm')
component.add_file('OpenStudio', '0.9.3',  osc_file_path.to_s, "#{file_name}.osc", 'osc')

# puts "saving component to #{component_dir}"
component.save_component_xml(component_dir)

# ALWAYS DISPLAY STATUS CODE AS THE LAST LINE
puts "STATUS:#{status_code}"

#OnDemand Generator script takes 4 arguments in json format
#and returns 1 osm file and 1 osc file and 1 json file of output arguments

#description xml: test_generator2.xml
#IMPORTANT:  for json use double quotes for individual arguments and single quotes to wrap the whole thing (json does not like single quotes)
#command line arguments syntax (json):  '{"test_argument1": "Hot Tub", "test_argument2":2}'

require 'rubygems'
require 'json'
#require '/var/openstudio/current/openstudio.rb'
require 'openstudio.rb'


#SETUP STATUS CODE
status_code = 1

#GET SCRIPT ARGUMNENTS (always a json string to be parsed by the script)
vals = ARGV[0]
args_hash = JSON.parse(vals)

#PARSE ARGUMENTS
if args_hash.has_key? "NREL_reference_building_vintage"
  std = args_hash["NREL_reference_building_vintage"]
else
  std = ""
  #missing argument
  status_code = 0
end
puts "NREL_reference_building_vintage is: #{std}"

if args_hash.has_key? "Climate_zone"
  clim = args_hash["Climate_zone"]
else
  clim = ""
  #missing argument
  status_code = 0
end
puts "Climate_zone is: #{clim}"

if args_hash.has_key? "NREL_reference_building_primary_space_type"
  ref_bldg_pri_spc_type = args_hash["NREL_reference_building_primary_space_type"]
else
  ref_bldg_pri_spc_type = ""
  #missing argument
  status_code = 0
end
puts "NREL_reference_building_primary_space_type is: #{ref_bldg_pri_spc_type}"

if args_hash.has_key? "NREL_reference_building_secondary_space_type"
  ref_bldg_sec_spc_type = args_hash["NREL_reference_building_secondary_space_type"]
else
  ref_bldg_sec_spc_type = ""
  #missing argument
  status_code = 0
end
puts "NREL_reference_building_secondary_space_type is: #{ref_bldg_sec_spc_type}"


#load the data from the JSON file into a ruby hash
$nrel_spc_types = {}
temp = File.read('lib/nrel_ref_bldg_space_types.json')
$nrel_spc_types = JSON.parse(temp)

#check that the data was loaded correctly
check_data = $nrel_spc_types["ASHRAE_189.1-2009"]["ClimateZone 1-3"]["Hospital"]["Radiology"]["lighting_w_per_area"]
unless check_data == 0.36
  puts "Something is wrong with the lookup."
  #TODO maybe put an exit here?
end

#load up the osm with all the reference building schedules
schedule_library_path = OpenStudio::Path.new("#{Dir.pwd}/lib/Master_Schedules.osm")
$schedule_library = OpenStudio::Model::Model::load(schedule_library_path).get  

#make a new openstudio model to hold the space type
$model = OpenStudio::Model::Model.new

#method for converting from IP to SI if you know the strings of the input and the output
def ip_to_si(number, ip_unit_string, si_unit_string)     
  ip_unit = OpenStudio::createUnit(ip_unit_string, "IP".to_UnitSystem).get
  si_unit = OpenStudio::createUnit(si_unit_string, "SI".to_UnitSystem).get
  #puts "#{ip_unit} --> #{si_unit}"
  ip_quantity = OpenStudio::Quantity.new(number, ip_unit)
  si_quantity = OpenStudio::convert(ip_quantity, si_unit).get
  puts "#{ip_quantity} = #{si_quantity}" 
  return si_quantity.value
end

#grabs a schedule with a specific name from the library, clones it into the space type model, and returns itself to the user
def get_sch_from_lib(sch_name)
  #get the correct space type from the library file
  sch = $schedule_library.getObjectByTypeAndName("OS_Schedule_Ruleset".to_IddObjectType,sch_name)
  #clone the space type from the library model into the space type model
  clone_of_sch = sch.get.to_Schedule.get.clone($model)
  new_sch = clone_of_sch.to_ScheduleRuleset.get
  return new_sch
end

#create a new space type and name it
space_type = OpenStudio::Model::SpaceType.new($model)
space_type.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type}")

#create the schedule set for the space type
default_sch_set = OpenStudio::Model::DefaultScheduleSet.new($model)
space_type.setDefaultScheduleSet(default_sch_set)

#lighting  

  #create the lighting definition 
  lights_def = OpenStudio::Model::LightsDefinition.new($model)
  lights_def.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Lights Definition")
  lighting_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_w_per_area"]
    unless  lighting_per_area == 0 or lighting_per_area.nil?
      lights_def.setWattsperSpaceFloorArea(ip_to_si(lighting_per_area,"W/ft^2","W/m^2"))
    end
  lighting_per_person = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_w_per_person"]
    unless lighting_per_person == 0 or lighting_per_person.nil?
      lights_def.setWattsperPerson(ip_to_si(lighting_per_person,"W/person","W/person"))
    end

  #create the lighting instance and hook it up to the space type
  lights = OpenStudio::Model::Lights.new(lights_def)
  lights.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Lights")
  lighting_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_sch"]
    unless lighting_sch.nil?
      default_sch_set.setLightingSchedule(get_sch_from_lib(lighting_sch))
    end
  lights.setSpaceType(space_type)
    
#ventilation

  #create the ventilation object and hook it up to the space type
  ventilation = OpenStudio::Model::DesignSpecificationOutdoorAir.new($model)
  ventilation.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Ventilation")
  ventilation_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_per_area"]
    unless ventilation_per_area  == 0 or ventilation_per_area.nil? 
      ventilation.setOutdoorAirFlowperFloorArea(ip_to_si(ventilation_per_area,"ft^3/min*ft^2","m^3/s*m^2"))
    end
  ventilation_per_person = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_per_person"]
    unless ventilation_per_person == 0 or ventilation_per_person.nil?
      ventilation.setOutdoorAirFlowperFloorArea(ip_to_si(ventilation_per_person,"ft^3/min*person","m^3/s*person"))
    end
  ventilation_ach = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_ach"]
    unless ventilation_ach == 0 or ventilation_ach.nil?
      ventilation.setOutdoorAirFlowAirChangesperHour(ventilation_ach)
    end
  ventilation.setOutdoorAirMethod("Sum")
  space_type.setDesignSpecificationOutdoorAir(ventilation)

#occupancy

  #create the people definition
  people_def = OpenStudio::Model::PeopleDefinition.new($model)
  people_def.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} People Definition")
  occupancy_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["occupancy_per_area"]
    unless  occupancy_per_area == 0 or occupancy_per_area.nil?
      people_def.setPeopleperSpaceFloorArea(ip_to_si(occupancy_per_area/1000,"people/ft^2","people/m^2"))
    end

  #create the people instance and hook it up to the space type
  people = OpenStudio::Model::People.new(people_def)
  people.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} People")
  occupancy_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["occupancy_sch"]
    unless occupancy_sch.nil?
      default_sch_set.setNumberofPeopleSchedule(get_sch_from_lib(occupancy_sch))
    end
  occupancy_activity_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["occupancy_activity_sch"]  
    unless occupancy_activity_sch.nil?
      default_sch_set.setPeopleActivityLevelSchedule(get_sch_from_lib(occupancy_activity_sch))
    end
    
#infiltration

  #create the infiltration object and hook it up to the space type
  infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new($model)
  infiltration.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Infiltration")
  infiltration_per_area_ext = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["infiltration_per_area_ext"]      
    unless infiltration_per_area_ext == 0 or infiltration_per_area_ext.nil?
      infiltration.setFlowperExteriorSurfaceArea(ip_to_si(infiltration_per_area_ext,"ft^3/min*ft^2","m^3/s*m^2"))
    end
  infiltration.setSpaceType(space_type)
  infiltration_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["infiltration_sch"]
    unless infiltration_sch.nil?
      default_sch_set.setInfiltrationSchedule(get_sch_from_lib(infiltration_sch))
    end
    
#gas equipment
  
  #creat the gas equipment definition
  gas_equip_def = OpenStudio::Model::GasEquipmentDefinition.new($model)
  gas_equip_def.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Gas Equipment Definition")
  gas_equip_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["gas_equip_per_area"]
    unless  gas_equip_per_area == 0 or gas_equip_per_area.nil?
      gas_equip_def.setWattsperSpaceFloorArea(ip_to_si(gas_equip_per_area,"btu/hr*ft^2","W/m^2"))
    end
  
  #create the gas equipment instance and hook it up to the space type
  gas_equip = OpenStudio::Model::GasEquipment.new(gas_equip_def)
  gas_equip.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Gas Equipment")
  gas_equip_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["gas_equip_sch"]
    unless gas_equip_sch.nil?
      default_sch_set.setGasEquipmentSchedule(get_sch_from_lib())
    end
    
#electric equipment

  #create the electric equipment definition
  elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new($model)
  elec_equip_def.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Electric Equipment Definition")
  elec_equip_per_area = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["elec_equip_per_area"]
    unless  elec_equip_per_area == 0 or elec_equip_per_area.nil?
      elec_equip_def.setWattsperSpaceFloorArea(ip_to_si(elec_equip_per_area,"W/ft^2","W/m^2"))
    end
    
  #create the electric equipment instance and hook it up to the space type
  elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
  elec_equip.setName("#{std} #{clim} #{ref_bldg_pri_spc_type} #{ref_bldg_sec_spc_type} Electric Equipment")
  elec_equip_sch = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["elec_equip_sch"]
    unless elec_equip_sch.nil?
      default_sch_set.setElectricEquipmentSchedule(get_sch_from_lib(elec_equip_sch))
    end

#setup the file names and save paths that will be used
file_name = "nrel_ref_bldg_space_type"
osm_file_path = OpenStudio::Path.new("#{Dir.pwd}/#{file_name}.osm")
osc_file_path = OpenStudio::Path.new("#{Dir.pwd}/#{file_name}.osc")

#save the space type as a .osm
$model.toIdfFile().save(osm_file_path,true)
puts "*************start .osm*************"
#puts $model
puts "*************end .osm*************"

#componentize the space type
space_type_component = space_type.createComponent
puts "*************start componentized space type*************"
puts space_type_component
puts "*************end componentized space type*************"

#save the componentized space type as a .osc
$model.toIdfFile().save(osc_file_path,true)
puts "*************start .osc*************"
#puts $model
puts "*************end .osc*************"
  
        
#make a file of json output attributes to add to the xml
#this will store information like the source for lighting, ventilation, occupancy, infiltration, plug/process loads, and schedules

#create a nested hash to store all the output attributes
output_attr = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

#lighting information source
  #lighting standard
  output_attr["output attributes"]["attribute"]["name"] = "lighting standard"
  output_attr["output attributes"]["attribute"]["value"] = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_standard"]
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"

  #lighting primary space type
  output_attr["output attributes"]["attribute"]["name"] = "lighting primary space type"
  output_attr["output attributes"]["attribute"]["value"] = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_pri_spc_type"]
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"

  #lighting secondary space type
  output_attr["output attributes"]["attribute"]["name"] = "lighting secondary space type"
  output_attr["output attributes"]["attribute"]["value"] = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_sec_spc_type"]
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"
  
#ventilation information source
  #ventilation standard
  output_attr["output attributes"]["attribute"]["name"] = "ventilation standard"
  output_attr["output attributes"]["attribute"]["value"] = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_standard"]
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"

  #ventilation primary space type
  output_attr["output attributes"]["attribute"]["name"] = "ventilation primary space type"
  output_attr["output attributes"]["attribute"]["value"] = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_pri_spc_type"]
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"

  #ventilation secondary space type
  output_attr["output attributes"]["attribute"]["name"] = "ventilation secondary space type"
  output_attr["output attributes"]["attribute"]["value"] = $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_sec_spc_type"]
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"  

#occupancy information source
  #occupancy standard
  output_attr["output attributes"]["attribute"]["name"] = "occupancy standard"
  output_attr["output attributes"]["attribute"]["value"] = "NREL reference buildings"
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"

  #occupancy primary space type
  output_attr["output attributes"]["attribute"]["name"] = "occupancy primary space type"
  output_attr["output attributes"]["attribute"]["value"] = ref_bldg_pri_spc_type
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"

  #occupancy secondary space type
  output_attr["output attributes"]["attribute"]["name"] = "occupancy secondary space type"
  output_attr["output attributes"]["attribute"]["value"] = ref_bldg_sec_spc_type
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"   

#infiltration, gas equipment, electric equipment, and schedules information source
  #occupancy standard
  output_attr["output attributes"]["attribute"]["name"] = "infiltration, gas equipment, electric equipment, and schedules standard"
  output_attr["output attributes"]["attribute"]["value"] = "NREL reference buildings"
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"

  #occupancy primary space type
  output_attr["output attributes"]["attribute"]["name"] = "infiltration, gas equipment, electric equipment, and schedules primary space type"
  output_attr["output attributes"]["attribute"]["value"] = ref_bldg_pri_spc_type
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"

  #occupancy secondary space type
  output_attr["output attributes"]["attribute"]["name"] = "infiltration, gas equipment, electric equipment, and schedules secondary space type"
  output_attr["output attributes"]["attribute"]["value"] = ref_bldg_sec_spc_type
  output_attr["output attributes"]["attribute"]["units"] = ""
  output_attr["output attributes"]["attribute"]["datatype"] = "string"  

f = File.open('outputs.json', 'w')
f.write(output_attr.to_json)
f.close

#ALWAYS DISPLAY STATUS CODE AS THE LAST LINE
puts "STATUS:#{status_code}"




















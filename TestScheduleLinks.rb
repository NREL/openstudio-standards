require 'openstudio'
require 'rubygems'
require 'json'

path_to_standards_json = ARGV[0]
path_to_master_schedules_library = ARGV[1]

#load the data from the JSON file into a ruby hash
standards = {}
temp = File.read(path_to_standards_json)
standards = JSON.parse(temp)
spc_types = standards["space_types"]

vt = OpenStudio::OSVersion::VersionTranslator.new
schedule_library = vt.loadModel(OpenStudio::Path.new(path_to_master_schedules_library)).get  

def find_sch(data, key, model, not_found_names)
  value = data[key]
  if not value
    puts "********#{key} is nil"
    return
  end
  find_sch_from_lib(value, model, not_found_names)
end
  
def find_sch_from_lib(sch_name, model, not_found_names)
  sch = model.getObjectByTypeAndName("OS_Schedule_Ruleset".to_IddObjectType, sch_name)
  if not sch.empty?
    return nil
  end
  not_found_names << sch_name
  return sch_name
end

not_found_names = []
for template in spc_types.keys.sort
  puts "#{template}"
  for clim in spc_types[template].keys.sort
    puts "**#{clim}"
    for building_type in spc_types[template][clim].keys.sort
      puts "****#{building_type}"
      for spc_type in spc_types[template][clim][building_type].keys.sort
        puts "******#{spc_type}"
        data = spc_types[template][clim][building_type][spc_type]
        find_sch(data, "lighting_sch", schedule_library, not_found_names)
        find_sch(data, "occupancy_sch", schedule_library, not_found_names)
        find_sch(data, "occupancy_activity_sch", schedule_library, not_found_names)
        find_sch(data, "infiltration_sch", schedule_library, not_found_names)
        find_sch(data, "elec_equip_sch", schedule_library, not_found_names)
        find_sch(data, "gas_equip_sch", schedule_library, not_found_names)
        find_sch(data, "heating_setpoint_sch", schedule_library, not_found_names)
        find_sch(data, "cooling_setpoint_sch", schedule_library, not_found_names)
      end
    end
  end
end

not_found_names.uniq.each do |name|
  puts "Could not find schedule '#{name}'"
end
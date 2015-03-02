require 'openstudio'
require 'rubygems'
require 'json'

path_to_standards_json = "build/OpenStudio_Standards.json"

# load the data from the JSON file into a ruby hash
standards = {}
temp = File.read(path_to_standards_json)
standards = JSON.parse(temp)
space_types = standards['space_types']
schedules = standards['schedules']

def find_sch(key, space_type, schedules, not_found_names)
  name = space_type[key]
  unless name
    puts "********#{key} is nil"
    return false
  end
  
  schedule = schedules.find {|x| x['name'] == name }
  if !schedule
    not_found_names << name
    return false
  end
  
  return true
end


not_found_names = []
space_types.each do |space_type|
  puts "'#{space_type['template']}', '#{space_type['climate_zone_set']}', '#{space_type['building_type']}', '#{space_type['space_type']}'"
  result = true
  result = find_sch('lighting_schedule', space_type, schedules, not_found_names) && result
  result = find_sch('occupancy_schedule', space_type, schedules, not_found_names) && result
  result = find_sch('occupancy_activity_schedule', space_type, schedules, not_found_names) && result
  result = find_sch('infiltration_schedule', space_type, schedules, not_found_names) && result
  result = find_sch('electric_equipment_schedule', space_type, schedules, not_found_names) && result
  result = find_sch('gas_equipment_schedule', space_type, schedules, not_found_names) && result
  result = find_sch('heating_setpoint_schedule', space_type, schedules, not_found_names) && result
  result = find_sch('cooling_setpoint_schedule', space_type, schedules, not_found_names) && result

end

puts
puts 'NOT FOUND SCHEDULES'
not_found_names.uniq.each do |name|
  puts "Could not find schedule '#{name}'"
end

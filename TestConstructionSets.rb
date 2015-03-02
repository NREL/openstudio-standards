require 'openstudio'
require 'rubygems'
require 'json'

path_to_standards_json = "#{Dir.pwd}/build/OpenStudio_Standards.json"

# load the data from the JSON file into a ruby hash
standards = {}
temp = File.read(path_to_standards_json)
standards = JSON.parse(temp)
constructions = standards['constructions']
construction_sets = standards['construction_sets']

def check_reverse_equal(left, right, construction_set, constructions)

  left_construction = construction_set[left]
  right_construction = construction_set[right]
  if left_construction.nil? || right_construction.nil?
    puts "Cannot find #{left} or #{right} in construction set"
    return false
  end
  
  left_construction = constructions.find{|x| x['name'] == left_construction}
  right_construction = constructions.find{|x| x['name'] == right_construction}
  if left_construction.nil? || right_construction.nil?
    puts "Cannot find #{left} or #{right} in constructions"
    return false
  end
  
  left_layers = left_construction['materials']
  right_layers = right_construction['materials']
  unless (left_layers.join(',') == right_layers.reverse.join(','))
    puts "Layers are not reverse equal, #{left} vs #{right}"
    return false
  end

  return true
end

def check_construction_set(construction_set, constructions)
  result = true
  
  if construction_set['space_type'] != "Attic"
    # check that interior surfaces have reversed pairs
    result = check_reverse_equal('interior_operable_windows', 'interior_operable_windows', construction_set, constructions) && result
    result = check_reverse_equal('interior_fixed_windows', 'interior_fixed_windows', construction_set, constructions) && result
    result = check_reverse_equal('interior_walls', 'interior_walls', construction_set, constructions) && result
    result = check_reverse_equal('interior_doors', 'interior_doors', construction_set, constructions) && result
    result = check_reverse_equal('interior_floors', 'interior_ceilings', construction_set, constructions) && result
  end
  
  return result
end

for construction_set in construction_sets
  puts "'#{construction_set['template']}', '#{construction_set['climate_zone_set']}', '#{construction_set['building_type']}', '#{construction_set['space_type']}'"
  result = check_construction_set(construction_set, constructions)
  if result then puts "Passed" else puts "Failed" end
end

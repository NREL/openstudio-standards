require 'openstudio'
require 'rubygems'
require 'json'

path_to_standards_json = "#{Dir.pwd}/OpenStudio_Standards.json"

#load the data from the JSON file into a ruby hash
standards = {}
temp = File.read(path_to_standards_json)
standards = JSON.parse(temp)
constructions = standards["constructions"]
construction_sets = standards["construction_sets"]

def check_reverse_equal(left, right, construction_set, constructions)
  left_construction = construction_set[left]
  right_construction = construction_set[right]
  if left_construction.nil? or right_construction.nil?
    puts "Cannot find #{left} or #{right}"
    return false
  end
  
  left_layers = constructions[left_construction]["materials"]
  right_layers = constructions[right_construction]["materials"]
  if not (left_layers.join(",") == right_layers.reverse.join(","))
    puts "Layers are not reverse equal, #{left} vs #{right}"
    return false
  end
  
  return true
end

def check_construction_set(construction_set, constructions)
  # check that interior surfaces have reversed pairs
  check_reverse_equal("interior_operable_window", "interior_operable_window", construction_set, constructions)
  check_reverse_equal("interior_fixed_window", "interior_fixed_window", construction_set, constructions)
  check_reverse_equal("interior_wall", "interior_wall", construction_set, constructions)
  check_reverse_equal("interior_door", "interior_door", construction_set, constructions)
  check_reverse_equal("interior_floor", "interior_ceiling", construction_set, constructions)
end

for template in construction_sets.keys.sort
  puts "#{template}"
  for clim in construction_sets[template].keys.sort
    puts "**#{clim}"
    for bldg_type in construction_sets[template][clim].keys.sort
      puts "****#{bldg_type}"
      for space_type in construction_sets[template][clim][bldg_type].keys.sort
        puts "******#{space_type}"      
        check_construction_set(construction_sets[template][clim][bldg_type][space_type], constructions)
      end
    end
  end
end

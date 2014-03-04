#this script creates the OpenStudio template models
#using the information from the OpenStudio_space_types_and_standards json file
#and the MasterSchedules.osm library

require 'openstudio'
require 'SpaceTypeGenerator.rb'
require 'profiler'

path_to_space_type_json = "#{Dir.pwd}/OpenStudio_space_types_and_standards.json"
path_to_master_schedules_library = "#{Dir.pwd}/Master_Schedules.osm"
path_to_office_schedules_library = "#{Dir.pwd}/Jan2014_OfficeSchedules.osm"

#create a new space type generator
generator = SpaceTypeGenerator.new(path_to_space_type_json, path_to_master_schedules_library, path_to_office_schedules_library)

#load the data from the JSON file into a ruby hash
spc_types = {}
temp = File.read(path_to_space_type_json)
spc_types = JSON.parse(temp)

#create a list of unique building types
building_types = []
for template in spc_types.keys.sort
  next if template == "todo"
  for climate in spc_types[template].keys.sort
    for building_type in spc_types[template][climate].keys.sort
      building_types << building_type
    end
  end
end
#puts building_types.size
building_types = building_types.uniq.sort
#puts building_types.size

#create a template model for each building type
#space types will be added to the appropriate model
#as they are generated
template_models = {}
building_types.each do |building_type|
  template_models[building_type] = OpenStudio::Model::Model.new
end

#create each space type and put it into the appropriate
#template model
for template in spc_types.keys.sort
  next if template == "todo"
  puts "#{template}"
  for climate in spc_types[template].keys.sort
    puts "**#{climate}"
    Profiler__::start_profile
    for building_type in spc_types[template][climate].keys.sort
      puts "****#{building_type}"
      for spc_type in spc_types[template][climate][building_type].keys.sort
        
        #generate the space type
        space_type = generator.generate_space_type(template, climate, building_type, spc_type)[0]
        #clone the space type into the appropriate template
        template_model = template_models[building_type]
        
        #space_type.clone(template_model)
      end #next space type
    end #next building
    Profiler__::stop_profile
    Profiler__::print_profile($stderr)
    exit
  end #next climate
end #next template
  
#save the template models
template_models.each do |building_type, template_model|
  template_file_save_path = OpenStudio::Path.new("#{Dir.pwd}/templates/#{building_type}.osm")
  template_model.toIdfFile().save(template_file_save_path,true)
end


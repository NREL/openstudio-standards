#this script creates the OpenStudio template models
#using the information from the OpenStudio_space_types_and_standards json file
#and the MasterSchedules.osm library

require 'openstudio'
require 'SpaceTypeGenerator.rb'

do_profile = false
if do_profile
  require 'profiler'
end

path_to_standards_json = "#{Dir.pwd}/OpenStudio_Standards.json"
path_to_master_schedules_library = "#{Dir.pwd}/Master_Schedules.osm"

#create a new space type generator
space_type_generator = SpaceTypeGenerator.new(path_to_standards_json, path_to_master_schedules_library)

#load the data from the JSON file into a ruby hash
standards = {}
temp = File.read(path_to_standards_json)
standards = JSON.parse(temp)
spc_types = standards["space_types"]

#create a list of unique building types
templates = []
climates = []
building_types = []
for template in spc_types.keys.sort
  next if template == "todo"
  templates << template
  for climate in spc_types[template].keys.sort
    climates << climate
    for building_type in spc_types[template][climate].keys.sort
      building_types << building_type
    end
  end
end
templates = templates.uniq.sort
climates = climates.uniq.sort
building_types = building_types.uniq.sort
#puts templates
#puts climates
#puts building_types

#create a template model for each building type
#space types will be added to the appropriate model
#as they are generated
template_models = {}
building_types.each do |building_type|
  template_models[building_type] = OpenStudio::Model::Model.new
end

begin
  #create each space type and put it into the appropriate
  #template model
  for template in templates
    puts "#{template}"
    
    for climate in spc_types[template].keys.sort
      puts "**#{climate}"
      
      if do_profile
        Profiler__::start_profile
      end
      
      for building_type in spc_types[template][climate].keys.sort
        puts "****#{building_type}"
        
        template_model = template_models[building_type]
        
        for spc_type in spc_types[template][climate][building_type].keys.sort
          #puts "******#{spc_type}"
          
          #generate the space type into the appropriate template
          space_type_generator.generate_space_type(template, climate, building_type, spc_type, template_model)

        end #next space type
      end #next building type
      
      if do_profile
        Profiler__::stop_profile
        Profiler__::print_profile($stderr)
        exit
      end
      
    end #next climate
  end #next template
  
rescue => e
  stack = e.backtrace.join("\n")
  puts "error #{e}, #{e.backtrace}"
end

#save the template models
template_models.each do |building_type, template_model|
  template_file_save_path = OpenStudio::Path.new("#{Dir.pwd}/templates/#{building_type}.osm")
  template_model.toIdfFile().save(template_file_save_path,true)
end


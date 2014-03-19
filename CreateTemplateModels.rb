#this script creates the OpenStudio template models
#using the information from the OpenStudio_space_types_and_standards json file
#and the MasterSchedules.osm library

require 'openstudio'
require 'SpaceTypeGenerator.rb'
require 'ConstructionSetGenerator.rb'

path_to_standards_json = "#{Dir.pwd}/OpenStudio_Standards.json"
path_to_master_schedules_library = "#{Dir.pwd}/Master_Schedules.osm"

#create generators
space_type_generator = SpaceTypeGenerator.new(path_to_standards_json, path_to_master_schedules_library)
construction_set_generator = ConstructionSetGenerator.new(path_to_standards_json)

#load the data from the JSON file into a ruby hash
standards = {}
temp = File.read(path_to_standards_json)
standards = JSON.parse(temp)
space_types = standards["space_types"]
construction_sets = standards["construction_sets"]

#create a template model for each building type
#space types will be added to the appropriate model
#as they are generated
template_models = {}
master_template = OpenStudio::Model::Model.new
minimal_template = OpenStudio::Model::Model.new
construction_set_generator.generate_all_constructions(master_template)

default_space_type = Hash.new
default_space_type["FullServiceRestaurant"] = "Dining"
default_space_type["Hospital"] = "PatRoom"
default_space_type["LargeHotel"] = "GuestRoom"
default_space_type["MidriseApartment"] = "Apartment"
default_space_type["Office"] = "OpenOffice"
default_space_type["Outpatient"] = "Exam"
default_space_type["PrimarySchool"] = "Classroom"
default_space_type["QuickServiceRestaurant"] = "Dining"
default_space_type["Retail"] = "Retail"
default_space_type["SecondarySchool"] = "Classroom"
default_space_type["SmallHotel"] = "GuestRoom"
default_space_type["StripMall"] = "WholeBuilding"
default_space_type["SuperMarket"] = "Sales/Produce"
default_space_type["Warehouse"] = "Bulk"

begin

  #create each space type and put it into the appropriate template model
  puts "Creating Space Types"
  for template in space_types.keys.sort
    puts "#{template}"
    for climate in space_types[template].keys.sort
      puts "**#{climate}"
      for building_type in space_types[template][climate].keys.sort
        puts "****#{building_type}"
        
        #next if not building_type == "Office"
        
        template_model = template_models[building_type]
        if template_model.nil?
          template_model = OpenStudio::Model::Model.new
          construction_set_generator.generate_all_constructions(template_model)
          template_models[building_type] = template_model
        end
        
        for space_type in space_types[template][climate][building_type].keys.sort
          #generate into the templates
          space_type_generator.generate_space_type(template, climate, building_type, space_type, master_template)
          result = space_type_generator.generate_space_type(template, climate, building_type, space_type, template_model)

          if template == "189.1-2009" and default_space_type[building_type] == space_type
            # set building level defaults
            building = template_model.getBuilding
            building.setSpaceType(result[0])
          end
          
          if template == "189.1-2009" and building_type == "Office"
            result = space_type_generator.generate_space_type(template, climate, building_type, space_type, minimal_template)
            if default_space_type[building_type] == space_type
              minimal_template.getBuilding.setSpaceType(result[0])
            end
          end

        end #next space type
      end #next building type 
    end #next climate
  end #next template

  #create each space type and put it into the appropriate template model
  puts "Creating Construction Sets"
  for template in construction_sets.keys.sort
    puts "#{template}"
    for climate in construction_sets[template].keys.sort
      puts "**#{climate}" 
      for building_type in construction_sets[template][climate].keys.sort
        next if building_type.empty?
        puts "****#{building_type}"
        
        #next if not (building_type == "Office" or building_type == "")

        template_model = template_models[building_type]
        if template_model.nil?
          template_model = OpenStudio::Model::Model.new
          construction_set_generator.generate_all_constructions(template_model)
          template_models[building_type] = template_model
        end
      
        for space_type in construction_sets[template][climate][building_type].keys.sort
          #generate into the templates
          construction_set_generator.generate_construction_set(template, climate, building_type, space_type, master_template)
          result = construction_set_generator.generate_construction_set(template, climate, building_type, space_type, template_model)

          if template == "189.1-2009" and (climate == "ClimateZone 5" or climate == "ClimateZone 4-5" or climate == "ClimateZone 5-6")
            # set building level defaults
            building = template_model.getBuilding
            building.setDefaultConstructionSet(result[0])
          end
          
          if template == "189.1-2009" and building_type == "Office"
            result = construction_set_generator.generate_construction_set(template, climate, building_type, space_type, minimal_template)
            if (climate == "ClimateZone 5" or climate == "ClimateZone 4-5" or climate == "ClimateZone 5-6")
              minimal_template.getBuilding.setDefaultConstructionSet(result[0])
            end
          end
          
        end #next space type
      end #next building type 
      
      if generic_construction_set = construction_sets[template][climate].delete("")
        puts "****Generic Building Type"
        for building_type in construction_sets[template][climate].keys.sort
          puts "******#{building_type}"
          template_model = template_models[building_type]
          for space_type in generic_construction_set.keys.sort
            #generate into the templates
            construction_set_generator.generate_construction_set(template, climate, "", space_type, master_template)
            construction_set_generator.generate_construction_set(template, climate, "", space_type, template_model)
          end
        end
      end
    end #next climate
  end #next template
  
rescue => e
  stack = e.backtrace.join("\n")
  puts "error #{e}, #{e.backtrace}"
end

puts space_type_generator.longest_name
puts space_type_generator.longest_name.size
puts construction_set_generator.longest_name
puts construction_set_generator.longest_name.size

#save the template models
template_models.each do |building_type, template_model|
  puts "Writing #{building_type}.osm"
  
  if template_model.getOptionalBuilding
    if template_model.getBuilding.defaultConstructionSet.empty?
      puts "#{building_type} template has no default construction set" 
    end
    if template_model.getBuilding.spaceType.empty?
      puts "#{building_type} template has no default space type" 
    end
  else
    puts "#{building_type} template has no building object"
  end
  
  template_file_save_path = OpenStudio::Path.new("#{Dir.pwd}/templates/#{building_type}.osm")
  template_model.toIdfFile().save(template_file_save_path,true)
end

master_template_save_path = OpenStudio::Path.new("#{Dir.pwd}/templates/MasterTemplate.osm")
master_template.toIdfFile().save(master_template_save_path,true)

minimal_template_save_path = OpenStudio::Path.new("#{Dir.pwd}/templates/MinimalTemplate.osm")
minimal_template.toIdfFile().save(minimal_template_save_path,true)
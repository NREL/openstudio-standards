# This script creates the OpenStudio template models
# using the information from the openstudio_standards.json file
# require 'profile'
require 'openstudio'
require_relative 'Standards.Model.2'

@path_to_standards_json = './build/openstudio_standards.json'

def create_template_models
  # Define the default template
  default_template = '90.1-2010'

  # Define the default building type for the master template
  default_building_type = 'Office'

  # Define the default climate zone set
  default_climate_zone_set = 'TODO'

  # Define which space type is the default for each building type
  default_space_type = {}
  default_space_type['FullServiceRestaurant'] = 'Dining'
  default_space_type['Hospital'] = 'PatRoom'
  default_space_type['LargeHotel'] = 'GuestRoom'
  default_space_type['MidriseApartment'] = 'Apartment'
  default_space_type['Office'] = 'OpenOffice'
  default_space_type['Outpatient'] = 'Exam'
  default_space_type['PrimarySchool'] = 'Classroom'
  default_space_type['QuickServiceRestaurant'] = 'Dining'
  default_space_type['Retail'] = 'Retail'
  default_space_type['SecondarySchool'] = 'Classroom'
  default_space_type['SmallHotel'] = 'GuestRoom'
  default_space_type['StripMall'] = 'WholeBuilding'
  default_space_type['SuperMarket'] = 'Sales/Produce'
  default_space_type['Warehouse'] = 'Bulk'

  # Create a master model that will contain all space types
  master_model = OpenStudio::Model::Model.new

  # Load the standards JSON for the master model
  master_model.load_openstudio_standards_json(@path_to_standards_json)

  # Get the list of unique building type names
  building_type_names = []
  master_model.standards['space_types'].each do |space_type|
    building_type_name = space_type['building_type']
    if building_type_name
      building_type_names << space_type['building_type']
    end
  end
  building_type_names = building_type_names.uniq

  # Create a template model for each building type,
  # including all space types, vintages, and construction sets.
  template_models = {}
  building_type_names.each do |building_type_name|
    # Create the model for this building type
    template_model = OpenStudio::Model::Model.new

    # Load the standards JSON for this model
    template_model.load_openstudio_standards_json(@path_to_standards_json)

    # Find all space types associated with this building type
    space_types = template_model.find_objects(template_model.standards['space_types'], 'building_type' => building_type_name)
    puts "Found #{space_types.size} space types for building type #{building_type_name}"
    next if space_types.size == 0

    # Add each of these space types to the model and
    # to the master template model
    space_types.each do |space_type|
      #     template_model_spc_type = template_model.add_space_type(space_type['template'], space_type['climate_zone_set'], space_type['building_type'], space_type['space_type'])
      #       master_model_spc_type = master_model.add_space_type(space_type['template'], space_type['climate_zone_set'], space_type['building_type'], space_type['space_type'])
      #
      #       # Set building level defaults for the template
      #       if space_type['template'] == default_template && space_type['space_type'] == default_space_type[space_type['building_type']]
      #         template_model.getBuilding.setSpaceType(template_model_spc_type)
      #         # If this is the master template, set Office as the default
      #         if space_type['building_type'] == default_building_type
      #           master_model.getBuilding.setSpaceType(master_model_spc_type)
      #         end
      #       end
      # =e
    end

    # Find all construction sets associated with this building type
    construction_sets = template_model.find_objects(template_model.standards['construction_sets'], 'building_type' => building_type_name)
    puts "Found #{construction_sets.size} construction sets for building type #{building_type_name}"
    next if construction_sets.size == 0

    # Add each of the construction sets to the model
    construction_sets.each do |construction_set|
      template_model_cons_set = template_model.add_construction_set(construction_set['template'], construction_set['climate_zone_set'], construction_set['building_type'], construction_set['space_type'])
      master_model_cons_set = master_model.add_construction_set(construction_set['template'], construction_set['climate_zone_set'], construction_set['building_type'], construction_set['space_type'])

      # Set building level defaults for the template
      if construction_set['template'] == default_template
        if template_model_cons_set.is_initialized
          template_model.getBuilding.setDefaultConstructionSet(template_model_cons_set.get)
        end
        # If this is the master template, set Office as the default
        if construction_set['building_type'] == default_building_type
          if master_model_cons_set.is_initialized
            master_model.getBuilding.setDefaultConstructionSet(master_model_cons_set.get)
          end
        end
      end
    end

    # Make sure that the air wall is included in the template
    ensure_air_wall(template_model)

    # Save the template model
    template_file_save_path = OpenStudio::Path.new("#{Dir.pwd}/templates/#{building_type_name}.osm")
    template_model.toIdfFile.save(template_file_save_path, true)
  end

  # master_template_save_path = OpenStudio::Path.new("#{Dir.pwd}/templates/MasterTemplate.osm")
  # ensure_air_wall(master_template)
  # master_template.toIdfFile.save(master_template_save_path, true)

  # minimal_template_save_path = OpenStudio::Path.new("#{Dir.pwd}/templates/MinimalTemplate.osm")
  # ensure_air_wall(minimal_template)
  # minimal_template.toIdfFile.save(minimal_template_save_path, true)
end

def ensure_air_wall(model)
  air_wall_construction = nil
  model.getConstructions.each do |construction|
    if construction.name.get == 'Air Wall'
      air_wall_construction = construction
      break
    end
  end
  unless air_wall_construction
    air_wall_material = OpenStudio::Model::AirWallMaterial.new(model)
    air_wall_material.setName('Air Wall Material')
    air_wall_construction = OpenStudio::Model::Construction.new(air_wall_material)
    air_wall_construction.setName('Air Wall')
  end
  return air_wall_construction
end

def generate_cec_template
  # Create a master model that will contain all space types
  template_model = OpenStudio::Model::Model.new

  # Load the standards JSON for the master model
  template_model.load_openstudio_standards_json(@path_to_standards_json)

  # Get a list of all materials and add them to the model
  template_model.standards['materials'].each do |material_data|
    # Skip non-CEC materials
    next unless material_data['material_standard'] == 'CEC Title24-2013'

    # Add the material to the template
    template_model.add_material(material_data['name'])
  end

  # Make sure that the air wall is included in the template
  ensure_air_wall(template_model)

  # Save the template model
  template_file_save_path = OpenStudio::Path.new("#{Dir.pwd}/templates/CEC Materials Template.osm")
  template_model.toIdfFile.save(template_file_save_path, true)
end

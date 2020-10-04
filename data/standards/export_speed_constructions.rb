require 'openstudio'
require 'openstudio-standards'
require 'json'
require_relative 'speed_constructions'

# Standards to export
templates = ['90.1-2007', '90.1-2010', '90.1-2013']

# Surface types to export
intended_surface_types = ['ExteriorRoof', 'ExteriorWall', 'GroundContactFloor', 'ExteriorWindow']

# Building categories to export
building_category = 'Nonresidential'

# Store the results
inputs = {}
csv_rows = []
model = OpenStudio::Model::Model.new

# Export each standard to JSON and OSM simultaneously
templates.each do |template|
  puts ''
  puts "*** Exporting constructions for #{template} ***"
  template_data = {} # Hash to store data for JSON level
  std = Standard.build(template)

  # Loop through climate zones
  (1..8).each do |climate_zone|
    climate_zone = climate_zone.to_s
    cz_data = {} # Hash to store data for JSON level

    # Find the climate zone set that this climate zone falls into
    climate_zone_set = "ClimateZone #{climate_zone}"

    # Loop through surface types
    intended_surface_types.each do |intended_surface_type|
      surf_type_data = {} # Hash to store data for JSON level

      # Downselect construction properties to this template/climate_zone/surface type combination
      search_criteria = {
        'template' => template,
        'climate_zone_set' => climate_zone_set,
        'intended_surface_type' => intended_surface_type,
        'building_category' => building_category
      }
      const_props = std.model_find_objects(std.standards_data['construction_properties'], search_criteria)

      # Get unique set of standards construction types (mass, wood-framed, etc.) for this surface type
      standards_construction_types = []
      const_props.each do |props|
        standards_construction_type = props['standards_construction_type']
        if standards_construction_types.include?(standards_construction_type)
          # Warn if there is more than one construction properties for a given standards_construction_type
          puts "ERROR There is more than one construction_properties entry for #{standards_construction_type} for: #{template}-#{climate_zone_set}-#{intended_surface_type}-#{building_category}"
          const_props.each do |cp|
            puts "...#{cp}"
          end
          next
        else
          standards_construction_types << standards_construction_type
        end
      end

      # Only export Unheated GroundContactFloor
      if intended_surface_type == 'GroundContactFloor'
        # puts("INFO only making Unheated GroundContactFloor constructions")
        standards_construction_types = ['Unheated']
      end

      # Make multiple constructions (default and upgrades) for each construction type
      standards_construction_types.sort.each do |standards_construction_type|
        const_type_data = {} # Hash to store data for JSON level

        # Downselect construction properties to this standards_construction_type (should just be 1)
        search_criteria = {
          'template' => template,
          'climate_zone_set' => climate_zone_set,
          'intended_surface_type' => intended_surface_type,
          'standards_construction_type' => standards_construction_type,
          'building_category' => building_category
        }
        props = std.model_find_object(std.standards_data['construction_properties'], search_criteria)

        # Make sure that a construction is specified
        if props['construction'].nil?
          puts "ERROR No typical construction is specified for construction properties of: #{template}-#{climate_zone_set}-#{intended_surface_type}-#{standards_construction_type}-#{building_category}, cannot add constructions for this combination."
          next
        end

        # Each type of surface is generated differently
        case intended_surface_type
        when 'ExteriorRoof', 'ExteriorWall'
          type_data = {'Default' => '', 'Options' => []}
          r_val_data = {'Default' => '', 'Options' => []}

          # Make the default construction
          default = SpeedConstructions.model_add_construction(std, model, props['construction'], props, climate_zone)
          # Prepend "Typical" for the default construction
          default_name = "Typical #{default.name}"
          if model.getConstructionByName(default_name).empty?
            default.setName(default_name)
          else
            default = model.getConstructionByName(default_name).get
          end
          # Get the R-value
          target_r_value_ip = 1.0 / props['assembly_maximum_u_value'].to_f
          # Add as the default
          type_data['Default'] = default.name.get.to_s
          r_val_data['Default'] = target_r_value_ip.round(0)
          # Add to the options
          type_data['Options'] << default.name.get.to_s
          r_val_data['Options'] << target_r_value_ip.round(0)

          # Make four incrementally better constructions
          r_val_ip_increases = case intended_surface_type
                               when 'ExteriorWall'
                                 [5.0, 10.0, 15.0, 20.0]
                               when 'ExteriorRoof'
                                 [10.0, 15.0, 20.0, 25.0]
                               end

          r_val_ip_increases.each do |r_val_increase_ip|
            upgraded_props = SpeedConstructions.upgrade_opaque_construction_properties(props, r_val_increase_ip)
            upgrade = SpeedConstructions.model_add_construction(std, model, upgraded_props['construction'], upgraded_props, climate_zone)
            # Get the modified R-value
            upgrade_r_value_ip = 1.0 / upgraded_props['assembly_maximum_u_value'].to_f
            # Add to the options
            type_data['Options'] << upgrade.name.get.to_s
            r_val_data['Options'] << upgrade_r_value_ip.round(0)
          end

          # Store the outputs
          const_type_data[SpeedConstructions.speed_enum(intended_surface_type, 'method') + '_Type'] = type_data
          const_type_data[SpeedConstructions.speed_enum(intended_surface_type, 'method') + '_R_Value'] = r_val_data
        when 'GroundContactFloor'
          type_data = {'Default' => '', 'Options' => []}

          # Make the default construction
          default = SpeedConstructions.model_add_construction(std, model, props['construction'], props, climate_zone)
          # Prepend "Typical" for the default construction
          default_name = "Typical #{default.name}"
          if model.getConstructionByName(default_name).empty?
            default.setName(default_name)
          else
            default = model.getConstructionByName(default_name).get
          end
          # Get the F-Factor
          target_f_factor_ip = props['assembly_maximum_f_factor']
          # Infer U-Value
          target_u_value_ip = SpeedConstructions.infer_slab_u_value_from_f_factor(target_f_factor_ip)
          # Set the U-value of the construction properties
          props['assembly_maximum_u_value'] = target_u_value_ip
          # Add as the default
          type_data['Default'] = default.name.get.to_s
          # Add to the options
          type_data['Options'] << default.name.get.to_s

          # No options for GroundContactFloor

          # Store the outputs
          const_type_data = type_data
        when 'ExteriorWindow'
          type_data = {'Default' => '', 'Options' => []}

          # Make the default construction, using SimpleGlazing
          props['convert_to_simple_glazing'] = 'yes'
          default = SpeedConstructions.model_add_construction(std, model, props['construction'], props, climate_zone)
          # Prepend "Typical" for the default construction
          default_name = "Typical #{default.name}"
          if model.getConstructionByName(default_name).empty?
            default.setName(default_name)
          else
            default = model.getConstructionByName(default_name).get
          end
          # Add as the default
          type_data['Default'] = default.name.get.to_s
          # Add to the options
          type_data['Options'] << default.name.get.to_s

          # Make four incrementally better constructions
          shgc_decreases = [0.1, 0.2, 0.3, 0.4]
          u_val_decreases = [0.2, 0.3, 0.4, 0.5]

          shgc_decreases.zip(u_val_decreases).each do |shgc_decrease, u_val_decrease|
            upgraded_props = SpeedConstructions.upgrade_window_construction_properties(props, shgc_decrease, u_val_decrease)
            # Use SimpleGlazing for the beyond-code options
            upgraded_props['convert_to_simple_glazing'] = 'yes'
            upgrade = SpeedConstructions.model_add_construction(std, model, upgraded_props['construction'], upgraded_props, climate_zone)
            # Add to the options
            type_data['Options'] << upgrade.name.get.to_s
          end

          # Store the outputs
          const_type_data[SpeedConstructions.speed_enum(intended_surface_type, 'method') + '_Type'] = type_data
        end

        surf_type_data[SpeedConstructions.speed_enum(standards_construction_type)] = const_type_data
      end
      cz_data[SpeedConstructions.speed_enum(intended_surface_type)] = surf_type_data
    end

    # Add one type of default Interior Walls
    intended_surface_type = 'InteriorWall'
    surf_type_data = {} # Hash to store data for JSON level
    method_data = {} # Hash to store data for JSON level
    default = SpeedConstructions.model_add_construction(std, model, 'Typical Interior Wall')
    method_data['Default'] = default.name.get.to_s
    method_data['Options'] = [default.name.get.to_s]
    method_type = SpeedConstructions.speed_enum(intended_surface_type, 'method') + '_Type'
    surf_type_data[method_type] = method_data
    cz_data[SpeedConstructions.speed_enum(intended_surface_type)] = surf_type_data

    # Add one type of default Interior Floors
    intended_surface_type = 'InteriorFloor'
    surf_type_data = {} # Hash to store data for JSON level
    method_data = {} # Hash to store data for JSON level
    default = SpeedConstructions.model_add_construction(std, model, 'Typical Interior Floor')
    method_data['Default'] = default.name.get.to_s
    method_data['Options'] = [default.name.get.to_s]
    method_type = SpeedConstructions.speed_enum(intended_surface_type, 'method') + '_Type'
    surf_type_data[method_type] = method_data
    cz_data[SpeedConstructions.speed_enum(intended_surface_type)] = surf_type_data

    template_data[SpeedConstructions.speed_enum(climate_zone)] = cz_data
  end
  inputs[SpeedConstructions.speed_enum(template)] = template_data
end
# Add the Constructions key as the top level of the hash
inputs = {'Constructions' => inputs}

# Do a sizing run to calculate window properties with E+ using hard-coded VT values
puts ''
puts '*** Performing a sizing run to calculate window properties using E+ ***'
std = Standard.build('90.1-2007') # doesn't matter which one, properties aren't used
SpeedConstructions.do_window_property_sizing_run(std, model)

# Check the window construction properties in the name vs. the E+ properties
window_tol = 3.0
puts ''
puts "*** Checking window construction properties in names against E+ calculations using tolerance of #{window_tol}% ***"
SpeedConstructions.compare_window_construction_properties(std, model, window_tol)

# Check the opaque construction properties in the name vs. the E+ properties
r_tol = 3.0
puts ''
puts "*** Checking opaque construction properties in names against model inputs using tolerance of #{r_tol}% ***"
SpeedConstructions.compare_opaque_contruction_properties(std, model, r_tol)

# Inputs JSON
File.open("#{__dir__}/construction_inputs_new.json", 'w') do |f|
  f.write(JSON.pretty_generate(inputs, {:indent => "    "}))
end

# OSM library
model.save(SpeedConstructions.construction_lib_path, true)

# Save CSV that can be used to fill in cost data
construction_csv = []
construction_csv << ['energy_code', 'climate_zone', 'surface_type', 'assembly_type', 'construction_name']
constructions = inputs['Constructions']
constructions.keys.each do |energy_code_key|
  energy_code = constructions[energy_code_key]
  energy_code.keys.each do |climate_zone_key|
    climate_zone = energy_code[climate_zone_key]
    climate_zone.keys.each do |surface_type_key|
      surface_type = climate_zone[surface_type_key]
      surface_type.keys.each do |assembly_or_type_key|
        if /.*_Type/.match(assembly_or_type_key)
          type = surface_type[assembly_or_type_key]
          options = type['Options']
          next unless options
          options.each do |construction_name|
            construction_csv << [energy_code_key, climate_zone_key, surface_type_key, '', construction_name]
          end
        else
          assembly_type = surface_type[assembly_or_type_key]
          assembly_type.keys.each do |type_key|
            next unless /.*_Type/.match(type_key)
            type = assembly_type[type_key]
            options = type['Options']
            next unless options
            options.each do |construction_name|
              construction_csv << [energy_code_key, climate_zone_key, surface_type_key, assembly_or_type_key, construction_name]
            end
          end
        end
      end
    end
  end
end

File.open("#{__dir__}/constructions_list.csv", 'w') do |f|
  construction_csv.each do |line|
    f.puts line.join(',')
  end
end





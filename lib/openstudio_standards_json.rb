# this script reads the OpenStudio_space_types_and_standards.xlsx spreadsheet
# and creates a JSON file containing all the information on the SpaceTypes tab

require 'rubygems'
require 'json'
require 'rubyXL'

class Hash
  def sort_by_key(recursive = false, &block)
    keys.sort(&block).reduce({}) do |seed, key|
      seed[key] = self[key]
      if recursive && seed[key].is_a?(Hash)
        seed[key] = seed[key].sort_by_key(true, &block)
      end
      seed
    end
  end
end

module OpenStudio
  class StandardsJson
    def initialize(version=1, excel_file=nil)

      # load in the space types
      @version = version
      xlsx_path = excel_file ? excel_file : 'resources/OpenStudio_Standards.xlsx'

      wb = RubyXL::Parser.parse(xlsx_path)
      begin
        standards = {}
        standards['file_version'] = @version
        standards['templates'] = get_templates_hash(wb)
        standards['climate_zones'] = get_climate_zones_hash(wb)
        standards['climate_zone_sets'] = get_climate_zone_sets_hash(wb)
        standards['standards'] = get_standards_hash(wb)
        standards['space_types'] = get_space_types_hash(wb)
        standards['construction_sets'] = get_construction_sets_hash(wb)
        standards['constructions'] = get_constructions_hash(wb)
        standards['materials'] = get_materials_hash(wb)

        # create any other views that would be useful

        if @version == 1
          standards = standards.sort_by_key(true) { |x, y| x.to_s <=> y.to_s }

          # write the space types hash to a JSON file
          save_file = 'build/OpenStudio_Standards.json'
          File.open(save_file, 'w') do |file|
            # file << standards.to_json
            file << JSON.pretty_generate(standards)
          end
          puts "Successfully generated #{save_file}"
        elsif @version == 2
          save_file = 'build/openstudio_standards_version_2.json'
          File.open(save_file, 'w') do |file|
            # file << standards.to_json
            file << JSON.pretty_generate(standards)
          end
          puts "Successfully generated #{save_file}"

        end
      rescue => e
        puts e.message
        puts e.backtrace.join "\n"
      ensure
        # Do nothing
      end
    end

    def self.create(version=1, excel_file=nil)
      return OpenStudio::StandardsJson.new version, excel_file
    end

    # read the Templates tab and put into a Hash
    def get_templates_hash(workbook)
      # compound key for this sheet is [template]

      # specify worksheet
      worksheet = workbook['Templates']

      # Add new headers as needed.
      header = %w(Name Notes)

      # Parse the worksheet. Set last header to something pointless so that it parses all the header rows
      data = worksheet.get_table(header, last_header: 'do_not_parse_after_me')

      # define the columns where the data live in the spreadsheet
      standard_col = 'Name'

      templates = nil
      if @version == 1
        # create a nested hash to store all the data
        templates = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          # If a value does not exist in the cell, then it doesn't exist in the table. Accessor will return nil
          template = row[standard_col].strip
          templates[template]['notes'] = row['Notes']
        end
      elsif @version == 2
        templates = []

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          h = {}

          h[standard_col.downcase] = row[standard_col].strip
          h['notes'] = row['Notes']

          templates << h
        end
      else
        fail "Don't know how to process #{__method__} for version #{@version}"
      end

      return templates
    end

    # read the Standards tab and put into a Hash
    def get_standards_hash(workbook)
      # compound key for this sheet is [standard]

      # specify worksheet
      worksheet = workbook['Standards']

      # Add new headers as needed.
      header = ['Name']

      # Parse the worksheet. Set last header to something pointless so that it parses all the header rows
      data = worksheet.get_table(header, last_header: 'do_not_parse_after_me')

      # define the columns where the data live in the spreadsheet
      standard_col = 'Name'

      standards = nil
      if @version == 1
        # create a nested hash to store all the data
        standards = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          # If a value does not exist in the cell, then it doesn't exist in the table. Accessor will return nil
          standard = row[standard_col].strip
          standards[standard]
        end
      elsif @version == 2
        standards = []

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          standards << row[standard_col].strip
        end
      else
        fail "Don't know how to process #{__method__} for version #{@version}"
      end

      return standards
    end

    # read the ClimateZones tab and put into a Hash
    def get_climate_zones_hash(workbook)
      # compound key for this sheet is [climate_zone]

      # specify worksheet
      worksheet = workbook['ClimateZones']

      # Add new headers as needed.
      header = ['Name', 'Standard', 'Representative City', 'BCL Weather Component ID']

      # Parse the worksheet. Set last header to something pointless so that it parses all the header rows
      data = worksheet.get_table(header, last_header: 'do_not_parse_after_me')

      # define the columns where the data live in the spreadsheet
      climate_zone_col = 'Name'
      standard_col = 'Standard'
      representative_city_col = 'Representative City'
      bcl_weather_component_id_col = 'BCL Weather Component ID'

      climate_zones = nil
      if @version == 1
        # create a nested hash to store all the data
        climate_zones = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          climate_zone = row[climate_zone_col].strip
          climate_zones[climate_zone]['standard'] = row[standard_col]
          climate_zones[climate_zone]['representative_city'] = row[representative_city_col]
          climate_zones[climate_zone]['bcl_weather_component_id'] = row[bcl_weather_component_id_col]
        end
      elsif @version == 2
        climate_zones = []

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          h = {}

          h['name'] = row[climate_zone_col].strip
          h['standard'] = row[standard_col]
          h['representative_city'] = row[representative_city_col]
          h['bcl_weather_component_id'] = row[bcl_weather_component_id_col]

          climate_zones << h
        end
      else
        fail "Don't know how to process #{__method__} for version #{@version}"
      end

      return climate_zones
    end

    # read the ClimateZoneSets tab and put into a Hash
    def get_climate_zone_sets_hash(workbook)
      # compound key for this sheet is [climate_zone_set]

      # specify worksheet
      worksheet = workbook['ClimateZoneSets']

      # Add new headers as needed.
      header = ['Name', 'Climate Zone']

      # Parse the worksheet. Set last header to something pointless so that it parses all the header rows
      data = worksheet.get_table(header, last_header: 'do_not_parse_after_me')

      # define the columns where the data live in the spreadsheet
      climate_zone_set_col = 'Name'
      climate_zone_col_prefix = 'Climate Zone'


      climate_zone_sets = nil
      if @version == 1
        # create a nested hash to store all the data
        climate_zone_sets = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          climate_zone_set = row[climate_zone_set_col].strip
          climate_zones = row.select { |k, v| k =~ /#{climate_zone_col_prefix}.*/ }.values
          climate_zone_sets[climate_zone_set]['climate_zones'] = climate_zones
        end
      elsif @version == 2
        climate_zone_sets = []

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          h = {}

          h['name'] = row[climate_zone_set_col].strip
          h['climate_zones'] = row.select { |k, v| k =~ /#{climate_zone_col_prefix}.*/ }.values

          climate_zone_sets << h
        end
      else
        fail "Don't know how to process #{__method__} for version #{@version}"
      end


      return climate_zone_sets
    end

    # read the SpaceTypes tab and put into a Hash
    def get_space_types_hash(workbook)
      # compound key for this sheet is [template][climate_zone_set][building_type][space_type]

      # specify worksheet
      worksheet = workbook['SpaceTypes']

      # Add new headers as needed.
      header = ['Template', 'Climate Zone Set', 'BuildingType', 'SpaceType', 'R_G_B', 'Lighting Standard', 'Lighting Primary Space Type']

      # Parse the worksheet. Set last header to something pointless so that it parses all the header rows
      data = worksheet.get_table(header, last_header: 'do_not_parse_after_me')

      # define the columns where the data live in the spreadsheet
      # basic information
      template_col = 'Template'
      climate_col = 'Climate Zone Set'
      building_type_col = 'BuildingType'
      space_type_col = 'SpaceType'

      # RGB color
      rgb_col = 'R_G_B'

      # lighting
      lighting_standard_col = 'Lighting Standard'
      lighting_pri_spc_type_col = 'Lighting Primary Space Type'
      lighting_sec_spc_type_col = 'Lighting Secondary Space Type'
      lighting_w_per_area_col = 'STD Lighting (W/ft^2)'
      lighting_w_per_person_col = 'STD Lighting (W/person)'
      lighting_w_per_linear_col = 'STD Lighting (W/ft)'
      lighting_sch_col = 'Lighting Sch'

      # ventilation
      ventilation_standard_col = 'Ventilation Standard'
      ventilation_pri_spc_type_col = 'Ventilation Primary Space Type'
      ventilation_sec_spc_type_col = 'Ventilation Secondary Space Type'
      ventilation_per_area_col = 'STD Ventilation (ft^3/min*ft^2)'
      ventilation_per_person_col = 'STD Ventilation (ft^3/min*person)'
      ventilation_ach_col = 'STD Ventilation (ach)'
      # ventilation_sch_col = 25 #TODO: David where did this col go?

      # occupancy
      occupancy_per_area_col = 'OSM Occupancy (people/1000 ft^2)2'
      occupancy_sch_col = 'Occupancy Sch'
      occupancy_activity_sch_col = 'Activity Sch'

      # infiltration
      infiltration_per_area_ext_col = 'Infiltration (ft^3/min*ft^2 ext)'
      infiltration_sch_col = 'Infiltration Sch'

      # gas equipment
      gas_equip_per_area_col = 'OSM Gas Equipment (Btu/hr*ft^2)'
      # TODO: read fraction fields
      gas_equip_sch_col = 'Gas Equipment Sch'

      # electric equipment
      elec_equip_per_area_col = 'OSM Electric Equipment (W/ft^2)'
      # TODO: read fraction fields
      elec_equip_sch_col = 'Electric Equipment Sch'

      # thermostats
      heating_setpoint_sch_col = 'Heating Setpoint Schedule'
      cooling_setpoint_sch_col = 'Cooling Setpoint Schedule'

      # TODO: read service hot water

      # TODO: this needs to be cleaned up

      space_types = nil
      if @version == 1
        # create a nested hash to store all the data
        space_types = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

        # loop through all the ref bldg space types and put them into a nested hash
        data[:table].each do |row|
          template = row[template_col].strip
          climate = row[climate_col].strip
          building_type = row[building_type_col].strip
          space_type = row[space_type_col].strip

          # RGB color
          space_types[template][climate][building_type][space_type]['rgb'] = row[rgb_col]

          # lighting
          space_types[template][climate][building_type][space_type]['lighting_standard'] = row[lighting_standard_col]
          space_types[template][climate][building_type][space_type]['lighting_pri_spc_type'] = row[lighting_pri_spc_type_col]
          space_types[template][climate][building_type][space_type]['lighting_sec_spc_type'] = row[lighting_sec_spc_type_col]
          space_types[template][climate][building_type][space_type]['lighting_w_per_area'] = row[lighting_w_per_area_col] ? row[lighting_w_per_area_col].to_f : nil
          space_types[template][climate][building_type][space_type]['lighting_w_per_person'] = row[lighting_w_per_person_col] ? row[lighting_w_per_person_col].to_f : nil
          space_types[template][climate][building_type][space_type]['lighting_sch'] = row[lighting_sch_col]

          # ventilation
          space_types[template][climate][building_type][space_type]['ventilation_standard'] = row[ventilation_standard_col]
          space_types[template][climate][building_type][space_type]['ventilation_pri_spc_type'] = row[ventilation_pri_spc_type_col]
          space_types[template][climate][building_type][space_type]['ventilation_sec_spc_type'] = row[ventilation_sec_spc_type_col]
          space_types[template][climate][building_type][space_type]['ventilation_per_area'] = row[ventilation_per_area_col].to_f
          space_types[template][climate][building_type][space_type]['ventilation_per_person'] = row[ventilation_per_person_col].to_f
          space_types[template][climate][building_type][space_type]['ventilation_ach'] = row[ventilation_ach_col].to_f
          # space_types[template][climate][building_type][space_type]["ventilation_sch"] = row[ventilation_sch_col]

          # occupancy
          space_types[template][climate][building_type][space_type]['occupancy_per_area'] = row[occupancy_per_area_col] ? row[occupancy_per_area_col].to_f : nil
          space_types[template][climate][building_type][space_type]['occupancy_sch'] = row[occupancy_sch_col]
          space_types[template][climate][building_type][space_type]['occupancy_activity_sch'] = row[occupancy_activity_sch_col]

          # infiltration
          space_types[template][climate][building_type][space_type]['infiltration_per_area_ext'] = row[infiltration_per_area_ext_col].to_f
          space_types[template][climate][building_type][space_type]['infiltration_sch'] = row[infiltration_sch_col]

          # gas equipment
          space_types[template][climate][building_type][space_type]['gas_equip_per_area'] = row[gas_equip_per_area_col] ? row[gas_equip_per_area_col].to_f : nil
          space_types[template][climate][building_type][space_type]['gas_equip_sch'] = row[gas_equip_sch_col]

          # electric equipment
          space_types[template][climate][building_type][space_type]['elec_equip_per_area'] = row[elec_equip_per_area_col].to_f
          space_types[template][climate][building_type][space_type]['elec_equip_sch'] = row[elec_equip_sch_col]

          # thermostats
          space_types[template][climate][building_type][space_type]['heating_setpoint_sch'] = row[heating_setpoint_sch_col]
          space_types[template][climate][building_type][space_type]['cooling_setpoint_sch'] = row[cooling_setpoint_sch_col]
        end
      elsif @version == 2
        space_types = []
        data[:table].each do |row|
          h = {}

          h['template'] = row[template_col].strip
          h['climate_zone'] = row[climate_col].strip
          h['building_type'] = row[building_type_col].strip
          h['space_type'] = row[space_type_col].strip


          # RGB color
          h['rgb'] = row[rgb_col]

          # lighting
          h['lighting_standard'] = row[lighting_standard_col]
          h['lighting_pri_spc_type'] = row[lighting_pri_spc_type_col]
          h['lighting_sec_spc_type'] = row[lighting_sec_spc_type_col]
          h['lighting_w_per_area'] = row[lighting_w_per_area_col] ? row[lighting_w_per_area_col].to_f : nil
          h['lighting_w_per_person'] = row[lighting_w_per_person_col] ? row[lighting_w_per_person_col].to_f : nil
          h['lighting_sch'] = row[lighting_sch_col]

          # ventilation
          h['ventilation_standard'] = row[ventilation_standard_col]
          h['ventilation_pri_spc_type'] = row[ventilation_pri_spc_type_col]
          h['ventilation_sec_spc_type'] = row[ventilation_sec_spc_type_col]
          h['ventilation_per_area'] = row[ventilation_per_area_col].to_f
          h['ventilation_per_person'] = row[ventilation_per_person_col].to_f
          h['ventilation_ach'] = row[ventilation_ach_col].to_f
          # h["ventilation_sch"] = row[ventilation_sch_col]

          # occupancy
          h['occupancy_per_area'] = row[occupancy_per_area_col] ? row[occupancy_per_area_col].to_f : nil
          h['occupancy_sch'] = row[occupancy_sch_col]
          h['occupancy_activity_sch'] = row[occupancy_activity_sch_col]

          # infiltration
          h['infiltration_per_area_ext'] = row[infiltration_per_area_ext_col].to_f
          h['infiltration_sch'] = row[infiltration_sch_col]

          # gas equipment
          h['gas_equip_per_area'] = row[gas_equip_per_area_col] ? row[gas_equip_per_area_col].to_f : nil
          h['gas_equip_sch'] = row[gas_equip_sch_col]

          # electric equipment
          h['elec_equip_per_area'] = row[elec_equip_per_area_col].to_f
          h['elec_equip_sch'] = row[elec_equip_sch_col]

          # thermostats
          h['heating_setpoint_sch'] = row[heating_setpoint_sch_col]
          h['cooling_setpoint_sch'] = row[cooling_setpoint_sch_col]


          space_types << h
        end
      else
        fail "Don't know how to process #{__method__} for version #{@version}"
      end

      return space_types
    end

    # read the ConstructionSets tab and put into a Hash
    def get_construction_sets_hash(workbook)
      # compound key for this sheet is [template][climate_zone_set][building_type][space_type]
      # building_type may be null to indicate all building types
      # space_type may be null to indicate all space types

      # specify worksheet
      worksheet = workbook['ConstructionSets']

      # Add new headers as needed.
      header = ['Template', 'Building Type', 'Space Type', 'Climate Zone Set', 'Exterior Walls']

      # Parse the worksheet. Set last header to something pointless so that it parses all the header rows
      data = worksheet.get_table(header, last_header: 'do_not_parse_after_me')

      # define the columns where the data live in the spreadsheet
      # basic information
      template_col = 'Template'
      building_type_col = 'Building Type'
      space_type_col = 'Space Type'
      climate_col = 'Climate Zone Set'

      # exterior surfaces
      exterior_wall_col = 'Exterior Walls'
      exterior_floor_col = 'Exterior Floors'
      exterior_roof_col = 'Exterior Roofs'

      # interior surfaces
      interior_wall_col = 'Interior Walls'
      interior_floor_col = 'Interior Floors'
      interior_ceiling_col = 'Interior Ceilings'

      # ground_contact surfaces
      ground_contact_wall_col = 'Ground Contact Walls'
      ground_contact_floor_col = 'Ground Contact Floors'
      ground_contact_ceiling_col = 'Ground Contact Ceilings'

      # exterior sub surfaces
      exterior_fixed_window_col = 'Exterior Fixed Windows'
      exterior_operable_window_col = 'Exterior Operable Windows'
      exterior_door_col = 'Exterior Doors'
      exterior_glass_door_col = 'Exterior Glass Doors'
      exterior_overhead_door_col = 'Exterior Overhead Doors'
      exterior_skylight_col = 'Exterior Skylights'
      tubular_daylight_dome_col = 'Tubular Daylight Domes'
      tubular_daylight_diffuser_col = 'Tubular Daylight Diffusers'

      # interior sub surfaces
      interior_fixed_window_col = 'Interior Fixed Windows'
      interior_operable_window_col = 'Interior Operable Windows'
      interior_door_col = 'Interior Doors'

      # other
      space_shading_col = 'Space Shading'
      building_shading_col = 'Building Shading'
      site_shading_col = 'Site Shading'
      interior_partition_col = 'Interior Partitions'

      construction_sets = nil
      if @version == 1
        # create a nested hash to store all the data
        construction_sets = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

        # loop through all the ref bldg space types and put them into a nested hash
        data[:table].each do |row|
          template = row[template_col].strip
          building_type = row[building_type_col]
          building_type = building_type.strip unless building_type.nil?
          space_type = row[space_type_col]
          space_type = space_type.strip unless space_type.nil?
          climate = row[climate_col].strip

          # exterior surfaces
          construction_sets[template][climate][building_type][space_type]['exterior_wall'] = row[exterior_wall_col]
          construction_sets[template][climate][building_type][space_type]['exterior_floor'] = row[exterior_floor_col]
          construction_sets[template][climate][building_type][space_type]['exterior_roof'] = row[exterior_roof_col]

          # interior surfaces
          construction_sets[template][climate][building_type][space_type]['interior_wall'] = row[interior_wall_col]
          construction_sets[template][climate][building_type][space_type]['interior_floor'] = row[interior_floor_col]
          construction_sets[template][climate][building_type][space_type]['interior_ceiling'] = row[interior_ceiling_col]

          # ground_contact surfaces
          construction_sets[template][climate][building_type][space_type]['ground_contact_wall'] = row[ground_contact_wall_col]
          construction_sets[template][climate][building_type][space_type]['ground_contact_floor'] = row[ground_contact_floor_col]
          construction_sets[template][climate][building_type][space_type]['ground_contact_ceiling'] = row[ground_contact_ceiling_col]

          # exterior sub surfaces
          construction_sets[template][climate][building_type][space_type]['exterior_fixed_window'] = row[exterior_fixed_window_col]
          construction_sets[template][climate][building_type][space_type]['exterior_operable_window'] = row[exterior_operable_window_col]
          construction_sets[template][climate][building_type][space_type]['exterior_door'] = row[exterior_door_col]
          construction_sets[template][climate][building_type][space_type]['exterior_glass_door'] = row[exterior_glass_door_col]
          construction_sets[template][climate][building_type][space_type]['exterior_overhead_door'] = row[exterior_overhead_door_col]
          construction_sets[template][climate][building_type][space_type]['exterior_skylight'] = row[exterior_skylight_col]
          construction_sets[template][climate][building_type][space_type]['tubular_daylight_dome'] = row[tubular_daylight_dome_col]
          construction_sets[template][climate][building_type][space_type]['tubular_daylight_diffuser'] = row[tubular_daylight_diffuser_col]

          # interior sub surfaces
          construction_sets[template][climate][building_type][space_type]['interior_fixed_window'] = row[interior_fixed_window_col]
          construction_sets[template][climate][building_type][space_type]['interior_operable_window'] = row[interior_operable_window_col]
          construction_sets[template][climate][building_type][space_type]['interior_door'] = row[interior_door_col]

          # other
          construction_sets[template][climate][building_type][space_type]['space_shading'] = row[space_shading_col]
          construction_sets[template][climate][building_type][space_type]['building_shading'] = row[building_shading_col]
          construction_sets[template][climate][building_type][space_type]['site_shading'] = row[site_shading_col]
          construction_sets[template][climate][building_type][space_type]['interior_partition'] = row[interior_partition_col]

        end

      elsif @version == 2
        construction_sets = []

        # loop through all the ref bldg space types and put them into a nested hash
        data[:table].each do |row|
          h = {}

          h['template'] = row[template_col].strip
          h['building_type'] = row[building_type_col] ? row[building_type_col].strip : nil
          h['space_type'] = row[space_type_col] ? row[space_type_col].strip : nil
          h['climate_zone'] = row[climate_col].strip

          # exterior surfaces
          h['exterior_wall'] = row[exterior_wall_col]
          h['exterior_floor'] = row[exterior_floor_col]
          h['exterior_roof'] = row[exterior_roof_col]

          # interior surfaces
          h['interior_wall'] = row[interior_wall_col]
          h['interior_floor'] = row[interior_floor_col]
          h['interior_ceiling'] = row[interior_ceiling_col]

          # ground_contact surfaces
          h['ground_contact_wall'] = row[ground_contact_wall_col]
          h['ground_contact_floor'] = row[ground_contact_floor_col]
          h['ground_contact_ceiling'] = row[ground_contact_ceiling_col]

          # exterior sub surfaces
          h['exterior_fixed_window'] = row[exterior_fixed_window_col]
          h['exterior_operable_window'] = row[exterior_operable_window_col]
          h['exterior_door'] = row[exterior_door_col]
          h['exterior_glass_door'] = row[exterior_glass_door_col]
          h['exterior_overhead_door'] = row[exterior_overhead_door_col]
          h['exterior_skylight'] = row[exterior_skylight_col]
          h['tubular_daylight_dome'] = row[tubular_daylight_dome_col]
          h['tubular_daylight_diffuser'] = row[tubular_daylight_diffuser_col]

          # interior sub surfaces
          h['interior_fixed_window'] = row[interior_fixed_window_col]
          h['interior_operable_window'] = row[interior_operable_window_col]
          h['interior_door'] = row[interior_door_col]

          # other
          h['space_shading'] = row[space_shading_col]
          h['building_shading'] = row[building_shading_col]
          h['site_shading'] = row[site_shading_col]
          h['interior_partition'] = row[interior_partition_col]

          construction_sets << h
        end
      else
        fail "Don't know how to process #{__method__} for version #{@version}"
      end
      return construction_sets
    end

    # read the Constructions tab and put into a Hash
    def get_constructions_hash(workbook)
      # compound key for this sheet is [construction]

      # specify worksheet
      worksheet = workbook['Constructions']

      # Add new headers as needed.
      header = ['Name', 'Construction Standard', 'Climate Zone Set', 'Intended Surface Type', 'Standards Construction Type', 'Material 1']

      # Parse the worksheet. Set last header to something pointless so that it parses all the header rows
      data = worksheet.get_table(header, last_header: 'do_not_parse_after_me')

      # define the columns where the data live in the spreadsheet
      # basic information
      construction_col = 'Name'
      construction_standard_col = 'Construction Standard'
      climate_zone_set_col = 'Climate Zone Set'
      intended_surface_type_col = 'Intended Surface Type'
      standards_construction_type_col = 'Standards Construction Type'
      material_col_prefix = 'Material'

      constructions = nil
      if @version == 1
        # create a nested hash to store all the data
        constructions = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          construction = row[construction_col].strip

          constructions[construction]['construction_standard'] = row[construction_standard_col]
          constructions[construction]['climate_zone_set'] = row[climate_zone_set_col]
          constructions[construction]['intended_surface_type'] = row[intended_surface_type_col]
          constructions[construction]['standards_construction_type'] = row[standards_construction_type_col]

          materials = row.select { |k, v| k =~ /#{material_col_prefix}.*/ }.values
          constructions[construction]['materials'] = materials
        end

      elsif @version == 2
        constructions = []

        # loop through all the templates and put them into a nested hash
        data[:table].each do |row|
          h = {}

          h['name'] = row[construction_col].strip

          h['construction_standard'] = row[construction_standard_col]
          h['climate_zone_set'] = row[climate_zone_set_col]
          h['intended_surface_type'] = row[intended_surface_type_col]
          h['standards_construction_type'] = row[standards_construction_type_col]
          h['materials'] = row.select { |k, v| k =~ /#{material_col_prefix}.*/ }.values

          constructions << h
        end
      else
        fail "Don't know how to process #{__method__} for version #{@version}"
      end
      return constructions
    end

    # read the Materials tab and put into a Hash
    def get_materials_hash(workbook)
      # compound key for this sheet is [material]

      # specify worksheet
      worksheet = workbook['Materials']

      # Add new headers as needed.
      header = ['Name', 'Material Type', 'Roughness']

      # Parse the worksheet. Set last header to something pointless so that it parses all the header rows
      data = worksheet.get_table(header, last_header: 'do_not_parse_after_me')

      # define the columns where the data live in the spreadsheet
      material_col = 'Name'
      material_type_col = 'Material Type'
      roughness_col = 'Roughness' # in
      thickness_col = 'Thickness (in)' # in
      conductivity_col = 'Conductivity (Btu*in/hr*ft^2*F)' # Btu*in/hr*ft^2*F	R
      resistance_col = 'Resistance (hr*ft^2*F/Btu)' # hr*ft^2*F/Btu
      density_col = 'Density (lb/ft^3)' # lb/ft^3
      specific_heat_col = 'Specific Heat (Btu/lbm*F)' # Btu/lbm*F
      thermal_absorptance_col = 'Thermal Absorptance'
      solar_absorptance_col = 'Solar Absorptance'
      visible_absorptance_col = 'Visible Absorptance'
      gas_type_col = 'Gas Type'
      u_factor_col = 'U-Factor (Btu/hr*ft^2*F)' # Btu/hr*ft^2*F
      solar_heat_gain_coefficient_col = 'Solar Heat Gain Coefficient'
      visible_transmittance_col = 'Visible Transmittance'
      optical_data_type_col = 'Optical Data Type'
      solar_transmittance_at_normal_incidence_col = 'Solar Transmittance At Normal Incidence'
      front_side_solar_reflectance_at_normal_incidence_col = 'Front Side Solar Reflectance At Normal Incidence'
      back_side_solar_relectance_at_normal_incidence_col = 'Back Side Solar Relectance At Normal Incidence'
      visible_transmittance_at_normal_incidence_col = 'Visible Transmittance At Normal Incidence'
      front_side_visible_reflectance_at_normal_incidence_col = 'Front Side Visible Reflectance At Normal Incidence'
      back_side_visible_relectance_at_normal_incidence_col = 'Back Side Visible Relectance At Normal Incidence'
      infrared_transmittance_at_normal_incidence_col = 'Infrared Transmittance At Normal Incidence'
      front_side_infrared_hemispherical_emissivity_col = 'Front Side Infrared Hemispherical Emissivity'
      back_side_infrared_hemispherical_emissivity_col = 'Back Side Infrared Hemispherical Emissivity'
      dirt_correction_factor_for_solar_and_visible_transmittance_col = 'Dirt Correction Factor For Solar And Visible Transmittance'
      solar_diffusing_col = 'Solar Diffusing'


      materials = nil
      if @version == 1
        # create a nested hash to store all the data
        materials = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

        # loop through all the ref bldg space types and put them into a nested hash
        data[:table].each do |row|
          material = row[material_col].strip

          # exterior surfaces
          materials[material]['material_type'] = row[material_type_col]
          materials[material]['roughness'] = row[roughness_col]
          materials[material]['thickness'] = row[thickness_col] ? row[thickness_col].to_f : nil
          materials[material]['conductivity'] = row[conductivity_col] ? row[conductivity_col].to_f : nil
          materials[material]['resistance'] = row[resistance_col]
          materials[material]['density'] = row[density_col]
          materials[material]['specific_heat'] = row[specific_heat_col]
          materials[material]['thermal_absorptance'] = row[thermal_absorptance_col]
          materials[material]['solar_absorptance'] = row[solar_absorptance_col]
          materials[material]['visible_absorptance'] = row[visible_absorptance_col]
          materials[material]['gas_type'] = row[gas_type_col]
          materials[material]['u_factor'] = row[u_factor_col]
          materials[material]['solar_heat_gain_coefficient'] = row[solar_heat_gain_coefficient_col]
          materials[material]['visible_transmittance'] = row[visible_transmittance_col]
          materials[material]['optical_data_type'] = row[optical_data_type_col]
          materials[material]['solar_transmittance_at_normal_incidence'] = row[solar_transmittance_at_normal_incidence_col]
          materials[material]['front_side_solar_reflectance_at_normal_incidence'] = row[front_side_solar_reflectance_at_normal_incidence_col]
          materials[material]['back_side_solar_relectance_at_normal_incidence'] = return_cell_value(row, back_side_solar_relectance_at_normal_incidence_col)
          materials[material]['visible_transmittance_at_normal_incidence'] = return_cell_value(row, visible_transmittance_at_normal_incidence_col)
          materials[material]['front_side_visible_reflectance_at_normal_incidence'] = return_cell_value(row, front_side_visible_reflectance_at_normal_incidence_col)
          materials[material]['back_side_visible_relectance_at_normal_incidence'] = return_cell_value(row, back_side_visible_relectance_at_normal_incidence_col)
          materials[material]['infrared_transmittance_at_normal_incidence'] = return_cell_value(row, infrared_transmittance_at_normal_incidence_col)
          materials[material]['front_side_infrared_hemispherical_emissivity'] = return_cell_value(row, front_side_infrared_hemispherical_emissivity_col)
          materials[material]['back_side_infrared_hemispherical_emissivity'] = return_cell_value(row, back_side_infrared_hemispherical_emissivity_col)
          materials[material]['dirt_correction_factor_for_solar_and_visible_transmittance'] = return_cell_value(row, dirt_correction_factor_for_solar_and_visible_transmittance_col)
          materials[material]['solar_diffusing'] = return_cell_value(row, solar_diffusing_col, 'boolean')
        end
      elsif @version == 2
        materials = []

        # loop through all the ref bldg space types and put them into a nested hash
        data[:table].each do |row|
          h = {}
          h['name'] = row[material_col].strip

          # exterior surfaces
          h['material_type'] = row[material_type_col]
          h['roughness'] = row[roughness_col]
          h['thickness'] = row[thickness_col] ? row[thickness_col].to_f : nil
          h['conductivity'] = row[conductivity_col] ? row[conductivity_col].to_f : nil
          h['resistance'] = row[resistance_col]
          h['density'] = row[density_col]
          h['specific_heat'] = row[specific_heat_col]
          h['thermal_absorptance'] = row[thermal_absorptance_col]
          h['solar_absorptance'] = row[solar_absorptance_col]
          h['visible_absorptance'] = row[visible_absorptance_col]
          h['gas_type'] = row[gas_type_col]
          h['u_factor'] = row[u_factor_col]
          h['solar_heat_gain_coefficient'] = row[solar_heat_gain_coefficient_col]
          h['visible_transmittance'] = row[visible_transmittance_col]
          h['optical_data_type'] = row[optical_data_type_col]
          h['solar_transmittance_at_normal_incidence'] = row[solar_transmittance_at_normal_incidence_col]
          h['front_side_solar_reflectance_at_normal_incidence'] = row[front_side_solar_reflectance_at_normal_incidence_col]
          h['back_side_solar_relectance_at_normal_incidence'] = return_cell_value(row, back_side_solar_relectance_at_normal_incidence_col)
          h['visible_transmittance_at_normal_incidence'] = return_cell_value(row, visible_transmittance_at_normal_incidence_col)
          h['front_side_visible_reflectance_at_normal_incidence'] = return_cell_value(row, front_side_visible_reflectance_at_normal_incidence_col)
          h['back_side_visible_relectance_at_normal_incidence'] = return_cell_value(row, back_side_visible_relectance_at_normal_incidence_col)
          h['infrared_transmittance_at_normal_incidence'] = return_cell_value(row, infrared_transmittance_at_normal_incidence_col)
          h['front_side_infrared_hemispherical_emissivity'] = return_cell_value(row, front_side_infrared_hemispherical_emissivity_col)
          h['back_side_infrared_hemispherical_emissivity'] = return_cell_value(row, back_side_infrared_hemispherical_emissivity_col)
          h['dirt_correction_factor_for_solar_and_visible_transmittance'] = return_cell_value(row, dirt_correction_factor_for_solar_and_visible_transmittance_col)
          h['solar_diffusing'] = return_cell_value(row, solar_diffusing_col, 'boolean')

          materials << h
        end
      else
        fail "Don't know how to process #{__method__} for version #{@version}"
      end

      return materials
    end

    private

    # Return the value of the cell of a row or null. If not null, then it will convert to float / integer
    def return_cell_value(row, cell_id, type = 'float')
      return nil unless row[cell_id]

      r = row[cell_id]
      case type
        when 'float'
          r = row[cell_id].to_f
        when 'int', 'integer'
          r = row[cell_id].to_i
        when 'string'
          r = row[cell_id].to_s
        when 'bool', 'boolean'
          case row[cell_id]
            when '1', 1, true, /true/i
              r = true
            else
              r = false
          end
      end

      r
    end
  end
end

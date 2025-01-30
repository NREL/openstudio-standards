module OpenstudioStandards
  # The Exterior Lighting module provides methods create, modify, and get information about model exterior lighting
  module ExteriorLighting
    # @!group Information

    # get exterior lighting areas, distances, and counts
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Hash] hash of exterior lighting value types and building type and model specific values
    def self.model_get_exterior_lighting_areas(model)
      # load parking file and convert to hash table
      parking_csv = "#{__dir__}/data/parking.csv"
      unless File.exist?(parking_csv)
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ExteriorLighting', "Unable to find file: #{parking_csv}")
        return false
      end
      parking_tbl = CSV.table(parking_csv, encoding: "ISO8859-1:utf-8" )
      parking_hsh = parking_tbl.map(&:to_hash)

      # load parking file and convert to hash table
      entryways_csv = "#{__dir__}/data/entryways.csv"
      unless File.exist?(entryways_csv)
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.ExteriorLighting', "Unable to find file: #{entryways_csv}")
        return false
      end
      entryways_tbl = CSV.table(entryways_csv, encoding: "ISO8859-1:utf-8" )
      entryways_hsh = entryways_tbl.map(&:to_hash)

      # get space properties from the model
      space_type_hash = OpenstudioStandards::CreateTypical.model_get_space_type_information(model)

      # populate building_type_hashes from space_type_hash
      building_type_hashes = {}
      space_type_hash.each do |space_type, hash|
        # if space type standards building type already exists,
        # add data to that standards building type in building_type_hashes
        if building_type_hashes.key?(hash[:standards_building_type])
          building_type_hashes[hash[:standards_building_type]][:effective_number_of_spaces] += hash[:effective_number_of_spaces]
          building_type_hashes[hash[:standards_building_type]][:floor_area] += hash[:floor_area]
          building_type_hashes[hash[:standards_building_type]][:number_of_people] += hash[:number_of_people]
          building_type_hashes[hash[:standards_building_type]][:number_of_students] += hash[:number_of_students]
          building_type_hashes[hash[:standards_building_type]][:number_of_units] += hash[:number_of_units]
          building_type_hashes[hash[:standards_building_type]][:number_of_beds] += hash[:number_of_beds]
        else
          # initialize hash for this building type
          building_type_hash = {}
          building_type_hash[:effective_number_of_spaces] = hash[:effective_number_of_spaces]
          building_type_hash[:floor_area] = hash[:floor_area]
          building_type_hash[:number_of_people] = hash[:number_of_people]
          building_type_hash[:number_of_students] = hash[:number_of_students]
          building_type_hash[:number_of_units] = hash[:number_of_units]
          building_type_hash[:number_of_beds] = hash[:number_of_beds]
          building_type_hashes[hash[:standards_building_type]] = building_type_hash
        end
      end

      # rename Office to SmallOffice, MediumOffice or LargeOffice depending on size
      if building_type_hashes.key?('Office')
        floor_area = building_type_hashes['Office'][:floor_area]
        office_type = if floor_area < 2750
                        'SmallOffice'
                      elsif floor_area < 25_250
                        'MediumOffice'
                      else
                        'LargeOffice'
                      end
        building_type_hashes[office_type] = building_type_hashes.delete('Office')
      end

      # initialize parking areas and drives area variables
      parking_area_and_drives_area = 0.0
      main_entries = 0.0
      other_doors = 0.0
      rollup_doors = 0.0
      drive_through_windows = 0.0
      canopy_entry_area = 0.0
      canopy_emergency_area = 0.0
      ground_story_ext_wall_area = 0.0

      # temporary std for model_effective_num_stories method
      std = Standard.build('90.1-2013')

      # calculate exterior lighting properties for each building type
      building_type_hashes.each do |building_type, hash|
        # calculate floor area and ground floor area in IP units
        floor_area_ft2 = OpenStudio.convert(hash[:floor_area], 'm^2', 'ft^2').get
        effective_num_stories = std.model_effective_num_stories(model)
        ground_floor_area_ft2 = floor_area_ft2 / effective_num_stories[:above_grade]

        # load parking area properties for standards building type
        parking_properties = parking_hsh.select { |h| h[:building_type] == building_type }

        if parking_properties.nil? || parking_properties.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.ExteriorLighting', "Could not find parking data for #{building_type}.")
          return {}
        end
        parking_properties = parking_properties[0]

        # calculate number of parking spots
        num_spots = 0.0
        if !parking_properties[:building_area_per_spot].nil?
          num_spots += floor_area_ft2 / parking_properties[:building_area_per_spot].to_f
        elsif !parking_properties[:units_per_spot].nil?
          num_spots += hash[:number_of_units] / parking_properties[:units_per_spot].to_f
        elsif !parking_properties[:students_per_spot].nil?
          num_spots += hash[:number_of_students] / parking_properties[:students_per_spot].to_f
        elsif !parking_properties[:beds_per_spot].nil?
          num_spots += hash[:number_of_beds] / parking_properties[:beds_per_spot].to_f
        else
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Unexpected key, can't calculate number of parking spots from #{parking_properties.keys.first}.")
        end

        # add to cumulative parking area
        parking_area_and_drives_area += num_spots * parking_properties[:parking_area_per_spot]

        # load entryways properties for standards building type
        entryways_properties = entryways_hsh.select { |hash| hash[:building_type] == building_type }

        if entryways_properties.nil? || entryways_properties.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.ExteriorLighting', "Could not find entryway data for #{building_type}.")
          return {}
        end
        entryways_properties = entryways_properties[0]

        # calculate door, window, and canopy length properties for exterior lighting
        # main entries
        unless entryways_properties[:entrance_doors_per_10000_ft2].nil?
          main_entries += (ground_floor_area_ft2 / 10_000.0) * entryways_properties[:entrance_doors_per_10000_ft2]
        end

        # other doors
        unless entryways_properties[:other_doors_per_10000_ft2].nil?
          other_doors += (ground_floor_area_ft2 / 10_000.0) * entryways_properties[:other_doors_per_10000_ft2]
        end

        # rollup doors
        unless entryways_properties[:rollup_doors_per_10000_ft2].nil?
          rollup_doors += (ground_floor_area_ft2 / 10_000.0) / entryways_properties[:rollup_doors_per_10000_ft2].to_f
        end

        # drive through windows
        unless entryways_properties[:floor_area_per_drive_through_window].nil?
          drive_through_windows += ground_floor_area_ft2 / entryways_properties[:floor_area_per_drive_through_window].to_f
        end

        # entrance canopies
        if !entryways_properties[:entrance_canopies].nil? && !entryways_properties[:canopy_size].nil?
          canopy_entry_area += entryways_properties[:entrance_canopies] * entryways_properties[:canopy_size]
        end

        # emergency canopies
        if !entryways_properties[:emergency_canopies].nil? && !entryways_properties[:canopy_size].nil?
          canopy_emergency_area += entryways_properties[:emergency_canopies] * entryways_properties[:canopy_size]
        end

        # building_facades
        # determine effective number of stories to find first above grade story exterior wall area
        ground_story = effective_num_stories[:story_hash].keys[effective_num_stories[:below_grade]]
        ground_story_ext_wall_area_m2 = effective_num_stories[:story_hash][ground_story][:ext_wall_area]
        ground_story_ext_wall_area += OpenStudio.convert(ground_story_ext_wall_area_m2, 'm^2', 'ft^2').get
      end

      # no source for width of different entry types
      main_entry_width_ft = 8.0
      other_doors_width_ft = 4.0
      rollup_door_width_ft = 8.0

      # ensure the building has at least 1 main entry
      main_entries = 1.0 if main_entries > 0 && main_entries < 1

      # populate hash
      area_length_count_hash = {}
      area_length_count_hash[:parking_area_and_drives_area] = parking_area_and_drives_area
      area_length_count_hash[:main_entries] = main_entries * main_entry_width_ft
      area_length_count_hash[:other_doors] = other_doors * other_doors_width_ft
      area_length_count_hash[:rollup_doors] = rollup_doors * rollup_door_width_ft
      area_length_count_hash[:drive_through_windows] = drive_through_windows
      area_length_count_hash[:canopy_entry_area] = canopy_entry_area
      area_length_count_hash[:canopy_emergency_area] = canopy_emergency_area
      area_length_count_hash[:building_facades] = ground_story_ext_wall_area

      return area_length_count_hash
    end
  end
end

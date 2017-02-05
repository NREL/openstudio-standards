# open the class to add methods to add exterior lighting
class OpenStudio::Model::Model

  # Add exterior lighting to the model
  #
  # @param template [String] Valid choices are
  # @param exterior_lighting_zone_number [Integer] Valid choices are
  # @return [Hash] the resulting elevator
  # @todo - would be nice to add argument for some building types (SmallHotel, MidriseApartment, PrimarySchool, SecondarySchool, RetailStripmall) if it has interior or exterior circulation.
  def add_typical_exterior_lights(template,exterior_lighting_zone_number,onsite_parking_fraction = 1.0, add_base_site_allowance = false, use_model_for_entries_and_canopies = false)

    exterior_lights = {}

    # populate search hash
    search_criteria = {
        'template' => template,
        'exterior_lighting_zone_number' => exterior_lighting_zone_number,
    }
    
    # load exterior_lighting_properties
    exterior_lighting_properties = self.find_object($os_standards['exterior_lighting'], search_criteria)
    puts "hello1"
    puts exterior_lighting_properties

    # get building types and ratio (needed to get correct schedules, parking area, and entires)
    space_type_hash = self.create_space_type_hash(template)
    puts "hello2"
    puts space_type_hash

    # todo - get model specific values to map to exterior_lighting_properties
    area_length_count_hash = self.create_exterior_lighting_area_length_count_hash(template,space_type_hash,onsite_parking_fraction,use_model_for_entries_and_canopies)
    puts "hello3"
    puts area_length_count_hash

    # todo - lookup appropriate schedules (there may be up to three, one of which may be always on)


    # todo - determine the area and linear feet values needed to apply codes


    # todo - add building type specific logic based on assumptions from prototype models


    # todo - add exterior lights


    return exterior_lights

  end

  # get exterior lighting area's, distances, and counts
  #
  # @return [hash] hash of exterior lighting value types and building type and model specific values
  # @todo - add code in to determine number of entries and canopy area from model geoemtry
  def create_exterior_lighting_area_length_count_hash(template,space_type_hash,onsite_parking_fraction,use_model_for_entries_and_canopies)

    area_length_count_hash = {}

    # populate building_type_hash, used to remap office
    building_type_hash = {}
    space_type_hash.each do |space_type,hash|

      # update building_type_hash
      if building_type_hash.has_key?(hash[:stds_bldg_type])
        building_type_hash[hash[:stds_bldg_type]] += hash[:floor_area]
      else
        building_type_hash[hash[:stds_bldg_type]] = hash[:floor_area]
      end
    end
    # rename Office to SmallOffice MediumOffice or LargeOffice
    office_type = nil
    if building_type_hash.has_key?("Office")
      office_type = self.remap_office(building_type_hash["Office"])
    end

    # parking areas and drives area
    parking_area_and_drives_area = 0.0
    main_entries = 0.0
    other_doors = 0.0
    canopy_entry_area = 0.0
    canopy_emergency_area = 0.0
    drive_through_windows = 0.0
    # run space_type_hash to get number of students and units and building type floor area totals
    space_type_hash.each do |space_type,hash|

      # rename space types as needed
      if hash[:stds_bldg_type] == "Office"
        building_type = office_type
      else
        building_type = hash[:stds_bldg_type]
      end

      # store floor area ip
      floor_area_ip = OpenStudio::convert(hash[:floor_area],"m^2","ft^2").get
      num_spots = 0.0

      # load illuninated_parking_area_properties
      search_criteria = {'building_type' => building_type}
      illuminated_parking_area_lookup = self.find_object($os_standards['illuminated_parking_area'], search_criteria)
      if not illuminated_parking_area_lookup["building_area_per_spot"].nil?
        num_spots += floor_area_ip / illuminated_parking_area_lookup["building_area_per_spot"].to_f
      elsif not illuminated_parking_area_lookup["units_per_spot"].nil?
        num_spots += hash[:num_units] / illuminated_parking_area_lookup["units_per_spot"].to_f
      elsif not illuminated_parking_area_lookup["students_per_spot"].nil?
        num_spots += hash[:num_students] / illuminated_parking_area_lookup["students_per_spot"].to_f
      elsif not illuminated_parking_area_lookup["beds_per_spot"].nil?
        num_spots += hash[:num_beds] / illuminated_parking_area_lookup["beds_per_spot"].to_f
      else
        OpenStudio.logFree(OpenStudio::Info, 'Prototype.Model.exterior_lights', "Unexpected key, can't calculate number of parking spots from #{illuminated_parking_area_lookup.keys.first}.")
      end
      parking_area_and_drives_area += num_spots * illuminated_parking_area_lookup["parking_area_per_spot"]

      # load illuninated_parking_area_properties
      search_criteria = {'building_type' => building_type}
      exterior_lighting_assumptions_lookup = self.find_object($os_standards['exterior_lighting_assumptions'], search_criteria)
      puts exterior_lighting_assumptions_lookup

      # lookup doors
      if use_model_for_entries_and_canopies
        # todo - get number of entries and canopy size from model geometry
      else
        # rollup not used
        main_entries += (floor_area_ip/10000.0) * exterior_lighting_assumptions_lookup["entrance_doors_per_10,000"]
        other_doors += (floor_area_ip/10000.0) * exterior_lighting_assumptions_lookup["others_doors_per_10,000"]
        if not exterior_lighting_assumptions_lookup["floor_area_per_drive_through_window"].nil?
          drive_through_windows += floor_area_ip / exterior_lighting_assumptions_lookup["floor_area_per_drive_through_window"].to_f
        end


        # if any space types of building type that has canopy, then use that value, don't add to count for additional space types
        if not exterior_lighting_assumptions_lookup["entrance_canopies"].nil? and not exterior_lighting_assumptions_lookup["canopy_size"].nil?
          canopy_entry_area = exterior_lighting_assumptions_lookup["entrance_canopies"] * exterior_lighting_assumptions_lookup["canopy_size"]
        end
        if not exterior_lighting_assumptions_lookup["emergency_canopies"].nil? and not exterior_lighting_assumptions_lookup["canopy_size"].nil?
          canopy_emergency_area = exterior_lighting_assumptions_lookup["emergency_canopies"]* exterior_lighting_assumptions_lookup["canopy_size"]
        end

      end

    end

    # populate hash
    area_length_count_hash[:parking_area_and_drives_area] = parking_area_and_drives_area
    area_length_count_hash[:main_entries] = main_entries
    area_length_count_hash[:other_doors] = other_doors
    area_length_count_hash[:canopy_entry_area] = canopy_entry_area
    area_length_count_hash[:canopy_emergency_area] = canopy_emergency_area
    area_length_count_hash[:drive_through_windows] = drive_through_windows

    # determine effective number of stories to find first above grade story exterior wall area
    effective_num_stories = self.effective_num_stories
    ground_story = effective_num_stories[:story_hash].keys[effective_num_stories[:below_grade]]
    ground_story_ext_wall_area_si = effective_num_stories[:story_hash][ground_story][:ext_wall_area]
    ground_story_ext_wall_area_ip = OpenStudio::convert(ground_story_ext_wall_area_si,"m^2","ft^2").get

    # building_facades
    # reference buildings uses first story and plenum area all around
    # prototype uses Table 4.19 by building type lit facde vs. total facade.
    area_length_count_hash[:building_facades] = ground_story_ext_wall_area_ip


    return area_length_count_hash

  end

end
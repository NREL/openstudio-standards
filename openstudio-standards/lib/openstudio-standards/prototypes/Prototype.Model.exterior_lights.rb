# open the class to add methods to add exterior lighting
class OpenStudio::Model::Model

  # Add exterior lighting to the model
  #
  # @param template [String] Valid choices are
  # @param exterior_lighting_zone_number [Integer] Valid choices are
  # @return [Hash] the resulting exterior lights
  # @todo - would be nice to add argument for some building types (SmallHotel, MidriseApartment, PrimarySchool, SecondarySchool, RetailStripmall) if it has interior or exterior circulation.
  def add_typical_exterior_lights(template,exterior_lighting_zone_number,onsite_parking_fraction = 1.0, add_base_site_allowance = false, use_model_for_entries_and_canopies = false)

    exterior_lights = {}
    installed_power = 0.0

    # populate search hash
    search_criteria = {
        'template' => template,
        'exterior_lighting_zone_number' => exterior_lighting_zone_number,
    }
    
    # load exterior_lighting_properties
    exterior_lighting_properties = self.find_object($os_standards['exterior_lighting'], search_criteria)

    # make sure lighting properties were found
    if exterior_lighting_properties.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.exterior_lights', "Exterior lighting properties not found for #{template}, ext lighting zone #{exterior_lighting_zone_number}, none will be added to model.")
      return exterior_lights
    end

    # get building types and ratio (needed to get correct schedules, parking area, entries, canopies, and drive throughs)
    space_type_hash = self.create_space_type_hash(template)

    # get model specific values to map to exterior_lighting_properties
    area_length_count_hash = self.create_exterior_lighting_area_length_count_hash(template,space_type_hash,use_model_for_entries_and_canopies)

    # using midnight to 6am setback or shutdown
    start_setback_shutoff = {:hr => 24, :min => 0}
    end_setback_shutoff = {:hr => 6, :min => 0}
    shuttoff = false
    setback = false
    if exterior_lighting_properties["building_facade_and_landscape_automatic_shut_off"] == 1
      ext_lights_sch_facade_and_landscape = OpenStudio::Model::ScheduleRuleset.new(self)
      default_day = ext_lights_sch_facade_and_landscape.defaultDaySchedule
      default_day.addValue(OpenStudio::Time.new(0, end_setback_shutoff[:hr], end_setback_shutoff[:min], 0), 0.0)
      default_day.addValue(OpenStudio::Time.new(0, start_setback_shutoff[:hr], start_setback_shutoff[:min], 0), 1.0)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Facade and Landscape exterior lights shut off from #{start_setback_shutoff} to #{end_setback_shutoff}")
    else
      ext_lights_sch_facade_and_landscape = self.alwaysOnDiscreteSchedule
    end
    if not exterior_lighting_properties["occupancy_setback_reduction"].nil? and exterior_lighting_properties["occupancy_setback_reduction"] > 0.0
      ext_lights_sch_other = OpenStudio::Model::ScheduleRuleset.new(self)
      setback_value = 1.0 - exterior_lighting_properties["occupancy_setback_reduction"]
      default_day = ext_lights_sch_other.defaultDaySchedule
      default_day.addValue(OpenStudio::Time.new(0, end_setback_shutoff[:hr], end_setback_shutoff[:min], 0), setback_value)
      default_day.addValue(OpenStudio::Time.new(0, start_setback_shutoff[:hr], start_setback_shutoff[:min], 0), 1.0)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Non Facade and Landscape lights reduce by #{exterior_lighting_properties["occupancy_setback_reduction"]*100} % from #{start_setback_shutoff} to #{end_setback_shutoff}")
    else
      ext_lights_sch_other = self.alwaysOnDiscreteSchedule
    end

    # add exterior lights for parking area
    if area_length_count_hash[:parking_area_and_drives_area] > 0

      # lighting values
      multiplier = area_length_count_hash[:parking_area_and_drives_area] * onsite_parking_fraction
      power = exterior_lighting_properties["parking_areas_and_drives"]
      name_prefix = "Parking Areas and Drives"

      # create ext light def
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/ft^2 of lighting for #{multiplier} ft^2 of parking area.")
      ext_lights_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      ext_lights_def.setName("#{name_prefix} Def (W/ft^2)")
      ext_lights_def.setDesignLevel(power)

      # create ext light inst
      #creating exterior lights object
      ext_lights = OpenStudio::Model::ExteriorLights.new(ext_lights_def,ext_lights_sch_other)
      ext_lights.setMultiplier(multiplier)
      ext_lights.setName(name_prefix)
      ext_lights.setControlOption(exterior_lighting_properties["control_option"])
      ext_lights.setEndUseSubcategory(name_prefix)
      exterior_lights[name_prefix] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for facades
    if area_length_count_hash[:building_facades] > 0

      # lighting values
      multiplier = area_length_count_hash[:building_facades]
      power = exterior_lighting_properties["building_facades"]
      name_prefix = "Building Facades"

      # create ext light def
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/ft^2 of lighting for #{multiplier} ft^2 of building facade area.")
      ext_lights_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      ext_lights_def.setName("#{name_prefix} Def (W/ft^2)")
      ext_lights_def.setDesignLevel(power)

      # create ext light inst
      #creating exterior lights object
      ext_lights = OpenStudio::Model::ExteriorLights.new(ext_lights_def,ext_lights_sch_facade_and_landscape)
      ext_lights.setMultiplier(multiplier)
      ext_lights.setName(name_prefix)
      ext_lights.setControlOption(exterior_lighting_properties["control_option"])
      ext_lights.setEndUseSubcategory(name_prefix)
      exterior_lights[name_prefix] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for main entries
    if area_length_count_hash[:main_entries] > 0

      # lighting values
      multiplier = area_length_count_hash[:main_entries]
      power = exterior_lighting_properties["main_entries"]
      name_prefix = "Main Entries"

      # create ext light def
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/ft of lighting for #{multiplier} ft of main entry length.")
      ext_lights_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      ext_lights_def.setName("#{name_prefix} Def (W/ft)")
      ext_lights_def.setDesignLevel(power)

      # create ext light inst
      #creating exterior lights object
      ext_lights = OpenStudio::Model::ExteriorLights.new(ext_lights_def,ext_lights_sch_other)
      ext_lights.setMultiplier(multiplier)
      ext_lights.setName(name_prefix)
      ext_lights.setControlOption(exterior_lighting_properties["control_option"])
      ext_lights.setEndUseSubcategory(name_prefix)
      exterior_lights[name_prefix] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for other doors
    if area_length_count_hash[:other_doors] > 0

      # lighting values
      multiplier = area_length_count_hash[:other_doors]
      power = exterior_lighting_properties["other_doors"]
      name_prefix = "Other Doors"

      # create ext light def
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/ft of lighting for #{multiplier} ft of other doors.")
      ext_lights_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      ext_lights_def.setName("#{name_prefix} Def (W/ft)")
      ext_lights_def.setDesignLevel(power)

      # create ext light inst
      #creating exterior lights object
      ext_lights = OpenStudio::Model::ExteriorLights.new(ext_lights_def,ext_lights_sch_other)
      ext_lights.setMultiplier(multiplier)
      ext_lights.setName(name_prefix)
      ext_lights.setControlOption(exterior_lighting_properties["control_option"])
      ext_lights.setEndUseSubcategory(name_prefix)
      exterior_lights[name_prefix] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for entry canopies
    if area_length_count_hash[:canopy_entry_area] > 0

      # lighting values
      multiplier = area_length_count_hash[:canopy_entry_area]
      power = exterior_lighting_properties["entry_canopies"]
      name_prefix = "Entry Canopies"

      # create ext light def
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/ft^2 of lighting for #{multiplier} ft^2 of building entry canopies.")
      ext_lights_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      ext_lights_def.setName("#{name_prefix} Def (W/ft^2)")
      ext_lights_def.setDesignLevel(power)

      # create ext light inst
      #creating exterior lights object
      ext_lights = OpenStudio::Model::ExteriorLights.new(ext_lights_def,ext_lights_sch_other)
      ext_lights.setMultiplier(multiplier)
      ext_lights.setName(name_prefix)
      ext_lights.setControlOption(exterior_lighting_properties["control_option"])
      ext_lights.setEndUseSubcategory(name_prefix)
      exterior_lights[name_prefix] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for emergency canopies
    if area_length_count_hash[:canopy_emergency_area] > 0

      # lighting values
      multiplier = area_length_count_hash[:canopy_emergency_area]
      power = exterior_lighting_properties["loading_areas_for_emergency_vehicles"]
      name_prefix = "Emergency Canopies"

      # create ext light def
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/ft^2 of lighting for #{multiplier} ft^2 of building emergency canopies.")
      ext_lights_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      ext_lights_def.setName("#{name_prefix} Def (W/ft^2)")
      ext_lights_def.setDesignLevel(power)

      # create ext light inst
      #creating exterior lights object
      ext_lights = OpenStudio::Model::ExteriorLights.new(ext_lights_def,ext_lights_sch_other)
      ext_lights.setMultiplier(multiplier)
      ext_lights.setName(name_prefix)
      ext_lights.setControlOption(exterior_lighting_properties["control_option"])
      ext_lights.setEndUseSubcategory(name_prefix)
      exterior_lights[name_prefix] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for drive through windows
    if area_length_count_hash[:drive_through_windows] > 0

      # lighting values
      multiplier = area_length_count_hash[:drive_through_windows]
      power = exterior_lighting_properties["drive_through_windows_and_doors"]
      name_prefix = "Drive Through Windows"

      # create ext light def
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/drive through window of lighting for #{multiplier} drie through windows.")
      ext_lights_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      ext_lights_def.setName("#{name_prefix} Def (W/ft^2)")
      ext_lights_def.setDesignLevel(power)

      # create ext light inst
      #creating exterior lights object
      ext_lights = OpenStudio::Model::ExteriorLights.new(ext_lights_def,ext_lights_sch_other)
      ext_lights.setMultiplier(multiplier)
      ext_lights.setName(name_prefix)
      ext_lights.setControlOption(exterior_lighting_properties["control_option"])
      ext_lights.setEndUseSubcategory(name_prefix)
      exterior_lights[name_prefix] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # todo - add_base_site_lighting_allowance (non landscaping tradable lighting)
    # add exterior lights for drive through windows
    if add_base_site_allowance

      # lighting values
      if not exterior_lighting_properties["base_site_allowance_power"].nil?
        power = exterior_lighting_properties["base_site_allowance_power"]
      elsif not exterior_lighting_properties["base_site_allowance_fraction"].nil?
        power = exterior_lighting_properties["base_site_allowance_fraction"] * installed_power # shold be of allowed vs. installed, but hard to calculate
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Cannot determine target base site allowance power, will set to 0 W.")
        power = 0.0
      end
      name_prefix = "Base Site Allowance"

      # create ext light def
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W of non landscape tradable exterior lighting. Wil follow occupancy setback reduction.")
      ext_lights_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      ext_lights_def.setName("#{name_prefix} Def (W)")
      ext_lights_def.setDesignLevel(power)

      # create ext light inst
      #creating exterior lights object
      ext_lights = OpenStudio::Model::ExteriorLights.new(ext_lights_def,ext_lights_sch_other)
      ext_lights.setName(name_prefix)
      ext_lights.setControlOption(exterior_lighting_properties["control_option"])
      ext_lights.setEndUseSubcategory(name_prefix)
      exterior_lights[name_prefix] = ext_lights

      # don't need to update installed power for this
    end

    return exterior_lights

  end

  # get exterior lighting area's, distances, and counts
  #
  # @return [hash] hash of exterior lighting value types and building type and model specific values
  # @todo - add code in to determine number of entries and canopy area from model geoemtry
  # @todo - come up with better logic for entry widths
  def create_exterior_lighting_area_length_count_hash(template,space_type_hash,use_model_for_entries_and_canopies)

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

      # load illuminated_parking_area_properties
      search_criteria = {'building_type' => building_type}
      illuminated_parking_area_lookup = self.find_object($os_standards['parking'], search_criteria)
      if not illuminated_parking_area_lookup["building_area_per_spot"].nil?
        num_spots += floor_area_ip / illuminated_parking_area_lookup["building_area_per_spot"].to_f
      elsif not illuminated_parking_area_lookup["units_per_spot"].nil?
        num_spots += hash[:num_units] / illuminated_parking_area_lookup["units_per_spot"].to_f
      elsif not illuminated_parking_area_lookup["students_per_spot"].nil?
        num_spots += hash[:num_students] / illuminated_parking_area_lookup["students_per_spot"].to_f
      elsif not illuminated_parking_area_lookup["beds_per_spot"].nil?
        num_spots += hash[:num_beds] / illuminated_parking_area_lookup["beds_per_spot"].to_f
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Unexpected key, can't calculate number of parking spots from #{illuminated_parking_area_lookup.keys.first}.")
      end
      parking_area_and_drives_area += num_spots * illuminated_parking_area_lookup["parking_area_per_spot"]

      # load illuninated_parking_area_properties
      search_criteria = {'building_type' => building_type}
      exterior_lighting_assumptions_lookup = self.find_object($os_standards['entryways'], search_criteria)

      # lookup doors
      if use_model_for_entries_and_canopies
        # todo - get number of entries and canopy size from model geometry
      else

        # no source for width of different entry types
        main_entry_width_ip = 8 # ft
        other_doors_width_ip = 4 # ft

        # rollup not used
        main_entries += (floor_area_ip/10000.0) * exterior_lighting_assumptions_lookup["entrance_doors_per_10,000"] * main_entry_width_ip
        other_doors += (floor_area_ip/10000.0) * exterior_lighting_assumptions_lookup["others_doors_per_10,000"] * other_doors_width_ip
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
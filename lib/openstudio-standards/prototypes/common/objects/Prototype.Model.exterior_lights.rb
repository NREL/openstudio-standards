class Standard
  # Add exterior lighting to the model
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param exterior_lighting_zone_number [Integer] exterior lighting zone number, 0-4
  # @param onsite_parking_fraction [Double] onsite parking fraction, 0-1
  # @param add_base_site_allowance [Boolean] whether to include the base site allowance
  # @param use_model_for_entries_and_canopies [Boolean] use building geometry for number of entries and canopy size
  # @return [Hash] a hash of OpenStudio::Model::ExteriorLights objects
  # @todo would be nice to add argument for some building types (SmallHotel, MidriseApartment, PrimarySchool, SecondarySchool, RetailStripmall) if it has interior or exterior circulation.
  def model_add_typical_exterior_lights(model, exterior_lighting_zone_number, onsite_parking_fraction = 1.0, add_base_site_allowance = false, use_model_for_entries_and_canopies = false)
    exterior_lights = {}
    installed_power = 0.0

    # populate search hash
    search_criteria = {
      'template' => template,
      'exterior_lighting_zone_number' => exterior_lighting_zone_number
    }

    # load exterior_lighting_properties
    exterior_lighting_properties = standards_lookup_table_first(table_name: 'exterior_lighting', search_criteria: search_criteria)

    # make sure lighting properties were found
    if exterior_lighting_properties.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.exterior_lights', "Exterior lighting properties not found for #{template}, ext lighting zone #{exterior_lighting_zone_number}, none will be added to model.")
      return exterior_lights
    end

    # get model specific areas to for exterior lighting
    area_length_count_hash = OpenstudioStandards::ExteriorLighting.model_get_exterior_lighting_areas(model)

    # using midnight to 6am setback or shutdown
    start_setback_shutoff = { hr: 24, min: 0 }
    end_setback_shutoff = { hr: 6, min: 0 }
    shuttoff = false
    setback = false
    if exterior_lighting_properties['building_facade_and_landscape_automatic_shut_off'] == 1
      ext_lights_sch_facade_and_landscape = OpenStudio::Model::ScheduleRuleset.new(model)
      default_day = ext_lights_sch_facade_and_landscape.defaultDaySchedule
      default_day.addValue(OpenStudio::Time.new(0, end_setback_shutoff[:hr], end_setback_shutoff[:min], 0), 0.0)
      default_day.addValue(OpenStudio::Time.new(0, start_setback_shutoff[:hr], start_setback_shutoff[:min], 0), 1.0)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Facade and Landscape exterior lights shut off from #{start_setback_shutoff} to #{end_setback_shutoff}")
    else
      ext_lights_sch_facade_and_landscape = model.alwaysOnDiscreteSchedule
    end
    if !exterior_lighting_properties['occupancy_setback_reduction'].nil? && (exterior_lighting_properties['occupancy_setback_reduction'] > 0.0)
      ext_lights_sch_other = OpenStudio::Model::ScheduleRuleset.new(model)
      setback_value = 1.0 - exterior_lighting_properties['occupancy_setback_reduction']
      default_day = ext_lights_sch_other.defaultDaySchedule
      default_day.addValue(OpenStudio::Time.new(0, end_setback_shutoff[:hr], end_setback_shutoff[:min], 0), setback_value)
      default_day.addValue(OpenStudio::Time.new(0, start_setback_shutoff[:hr], start_setback_shutoff[:min], 0), 1.0)
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Non Facade and Landscape lights reduce by #{exterior_lighting_properties['occupancy_setback_reduction'] * 100} % from #{start_setback_shutoff} to #{end_setback_shutoff}")
    else
      ext_lights_sch_other = model.alwaysOnDiscreteSchedule
    end

    # add exterior lights for parking area
    if !area_length_count_hash[:parking_area_and_drives_area].nil? && area_length_count_hash[:parking_area_and_drives_area] > 0

      # lighting values
      multiplier = area_length_count_hash[:parking_area_and_drives_area] * onsite_parking_fraction
      power = exterior_lighting_properties['parking_areas_and_drives']
      name_prefix = 'Parking Areas and Drives'

      # create exterior lights
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power.round(2)} W/ft^2 of lighting for #{multiplier} ft^2 of parking area.")
      ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                      name: 'Parking Areas and Drives',
                                                                                      power: power,
                                                                                      units: 'W/ft^2',
                                                                                      multiplier: multiplier,
                                                                                      schedule: ext_lights_sch_other,
                                                                                      control_option: exterior_lighting_properties['control_option'])
      exterior_lights['Parking Areas and Drives'] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for facades
    if !area_length_count_hash[:building_facades].nil? && area_length_count_hash[:building_facades] > 0

      # lighting values
      multiplier = area_length_count_hash[:building_facades]
      power = exterior_lighting_properties['building_facades']
      name_prefix = 'Building Facades'

      # create exterior lights
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power.round(2)} W/ft^2 of lighting for #{multiplier} ft^2 of building facade area.")
      ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                      name: 'Building Facades',
                                                                                      power: power,
                                                                                      units: 'W/ft^2',
                                                                                      multiplier: multiplier,
                                                                                      schedule: ext_lights_sch_facade_and_landscape,
                                                                                      control_option: exterior_lighting_properties['control_option'])
      exterior_lights['Building Facades'] = ext_lights


      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for main entries
    if !area_length_count_hash[:main_entries].nil? && area_length_count_hash[:main_entries] > 0

      # lighting values
      multiplier = area_length_count_hash[:main_entries]
      power = exterior_lighting_properties['main_entries']
      name_prefix = 'Main Entries'

      # create exterior lights
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power.round(2)} W/ft of lighting for #{multiplier} ft of main entry length.")
      ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                      name: 'Main Entries',
                                                                                      power: power,
                                                                                      units: 'W/ft',
                                                                                      multiplier: multiplier,
                                                                                      schedule: ext_lights_sch_other,
                                                                                      control_option: exterior_lighting_properties['control_option'])
      exterior_lights['Main Entries'] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for other doors
    if !area_length_count_hash[:other_doors].nil? && area_length_count_hash[:other_doors] > 0

      # lighting values
      multiplier = area_length_count_hash[:other_doors]
      power = exterior_lighting_properties['other_doors']
      name_prefix = 'Other Doors'

      # create exterior lights
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power.round(2)} W/ft of lighting for #{multiplier} ft of other doors.")
      ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                      name: 'Other Doors',
                                                                                      power: power,
                                                                                      units: 'W/ft',
                                                                                      multiplier: multiplier,
                                                                                      schedule: ext_lights_sch_other,
                                                                                      control_option: exterior_lighting_properties['control_option'])
      exterior_lights['Other Doors'] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for entry canopies
    if !area_length_count_hash[:canopy_entry_area].nil? && area_length_count_hash[:canopy_entry_area] > 0

      # lighting values
      multiplier = area_length_count_hash[:canopy_entry_area]
      power = exterior_lighting_properties['entry_canopies']
      name_prefix = 'Entry Canopies'

      # create exterior lights
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/ft^2 of lighting for #{multiplier} ft^2 of building entry canopies.")
      ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                      name: 'Entry Canopies',
                                                                                      power: power,
                                                                                      units: 'W/ft^2',
                                                                                      multiplier: multiplier,
                                                                                      schedule: ext_lights_sch_other,
                                                                                      control_option: exterior_lighting_properties['control_option'])
      exterior_lights['Entry Canopies'] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for emergency canopies
    if !area_length_count_hash[:canopy_emergency_area].nil? && area_length_count_hash[:canopy_emergency_area] > 0

      # lighting values
      multiplier = area_length_count_hash[:canopy_emergency_area]
      power = exterior_lighting_properties['loading_areas_for_emergency_vehicles']
      name_prefix = 'Emergency Canopies'

      # create exterior lights
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/ft^2 of lighting for #{multiplier} ft^2 of building emergency canopies.")
      ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                      name: 'Emergency Canopies',
                                                                                      power: power,
                                                                                      units: 'W/ft^2',
                                                                                      multiplier: multiplier,
                                                                                      schedule: ext_lights_sch_other,
                                                                                      control_option: exterior_lighting_properties['control_option'])
      exterior_lights['Emergency Canopies'] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # add exterior lights for drive through windows
    if !area_length_count_hash[:drive_through_windows].nil? && area_length_count_hash[:drive_through_windows] > 0

      # lighting values
      multiplier = area_length_count_hash[:drive_through_windows]
      power = exterior_lighting_properties['drive_through_windows_and_doors']

      # create exterior lights
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W/drive through window of lighting for #{multiplier} drive through windows.")
      ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                      name: 'Drive Through Windows',
                                                                                      power: power,
                                                                                      units: 'W/ft^2',
                                                                                      multiplier: multiplier,
                                                                                      schedule: ext_lights_sch_other,
                                                                                      control_option: exterior_lighting_properties['control_option'])
      exterior_lights['Drive Through Windows'] = ext_lights

      # update installed power
      installed_power += power * multiplier
    end

    # @todo - add_base_site_lighting_allowance (non landscaping tradable lighting)
    # add exterior lights for drive through windows
    if add_base_site_allowance

      # lighting values
      if !exterior_lighting_properties['base_site_allowance_power'].nil?
        power = exterior_lighting_properties['base_site_allowance_power']
      elsif !exterior_lighting_properties['base_site_allowance_fraction'].nil?
        power = exterior_lighting_properties['base_site_allowance_fraction'] * installed_power # shold be of allowed vs. installed, but hard to calculate
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', 'Cannot determine target base site allowance power, will set to 0 W.')
        power = 0.0
      end

      # create exterior lights
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.exterior_lights', "Added #{power} W of non landscape tradable exterior lighting. Will follow occupancy setback reduction.")
      ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                      name: 'Base Site Allowance',
                                                                                      power: power,
                                                                                      units: 'W',
                                                                                      multiplier: 1.0,
                                                                                      schedule: ext_lights_sch_other,
                                                                                      control_option: exterior_lighting_properties['control_option'])
      exterior_lights['Base Site Allowance'] = ext_lights

      # don't need to update installed power for this
    end

    return exterior_lights
  end
end

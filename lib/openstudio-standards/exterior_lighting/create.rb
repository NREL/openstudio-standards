module OpenstudioStandards
  # The Exterior Lighting module provides methods create, modify, and get information about model exterior lighting
  module ExteriorLighting
    # @!group Create

    # create an ExtertiorLights object from inputs
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param name [String] the name of the exterior lights
    # @param power [Double] the watts value, can be watts or watts per area or length
    # @param units [String] units for the power, either 'W', 'W/ft' or 'W/ft^2'
    # @param multiplier [Double] the multiplier for the lighting, representing ft or ft^2
    # @param schedule [OpenStudio::Model::Schedule] OpenStudio Schedule object. If nil, will default to always on.
    # @param control_option [String] Options are 'ScheduleNameOnly' and 'AstronomicalClock'.
    #   'ScheduleNameOnly' will follow the schedule. 'AstronomicalClock' will follow the schedule, but turn off lights when the sun is up.
    # @return [OpenStudio::Model::ExteriorLights] OpenStudio ExteriorLights object
    def self.model_create_exterior_lights(model,
                                          name: nil,
                                          power: 1.0,
                                          units: 'W',
                                          multiplier: 1.0,
                                          schedule: nil,
                                          control_option: 'AstronomicalClock')
      # default name
      name = "Exterior Lights #{power.round(0)}" if name.nil?

      # default schedule
      schedule = model.alwaysOnDiscreteSchedule if schedule.nil?

      # create exterior light definition
      exterior_lights_definition = OpenStudio::Model::ExteriorLightsDefinition.new(model)
      exterior_lights_definition.setName("#{name} Def (#{units})")
      exterior_lights_definition.setDesignLevel(power)

      # creating exterior lights object
      exterior_lights = OpenStudio::Model::ExteriorLights.new(exterior_lights_definition, schedule)
      exterior_lights.setMultiplier(multiplier)
      exterior_lights.setName(name)
      exterior_lights.setControlOption(control_option)
      exterior_lights.setEndUseSubcategory(name)

      return exterior_lights
    end

    # Create typical exterior lighting in a model
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param standard [Standard] standard object to use for lighting properties. If set, will override lighting_generation.
    # @param lighting_generation [String] lighting generation to use for lighting properties.
    # @param exterior_lighting_zone_number [Integer] exterior lighting zone number, 0-4
    # @param onsite_parking_fraction [Double] onsite parking fraction, 0-1
    # @param add_base_site_allowance [Boolean] whether to include the base site allowance
    # @param use_model_for_entries_and_canopies [Boolean] use building geometry for number of entries and canopy size
    # @return [Array<OpenStudio::Model::ExteriorLights>] Array of OpenStudio ExteriorLights object
    def self.model_create_typical_exterior_lighting(model,
                                                    standard: nil,
                                                    lighting_generation: 'gen4_led',
                                                    exterior_lighting_zone_number: 3,
                                                    onsite_parking_fraction: 1.0,
                                                    add_base_site_allowance: false,
                                                    use_model_for_entries_and_canopies: false,
                                                    control_option: 'AstronomicalClock')
      exterior_lights = []
      installed_power = 0.0
      # get the exterior lighting properties from standard or the lighting_generation
      unless standard.nil?
        search_criteria = {
          'exterior_lighting_zone_number' => exterior_lighting_zone_number
        }
        exterior_lighting_properties = standard.standards_lookup_table_first(table_name: 'exterior_lighting', search_criteria: search_criteria)
        lookup_key = standard.template

      else
        lookup_key = lighting_generation
      end

      # make sure lighting properties were found
      if exterior_lighting_properties.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.ExteriorLighting', "Exterior lighting properties not found for #{lookup_key}, ext lighting zone #{exterior_lighting_zone_number}, none will be added to model.")
        return exterior_lights
      end

      # default control_option
      if exterior_lighting_properties['control_option'].nil?
        control_option = 'AstronomicalClock'
      else
        control_option = exterior_lighting_properties['control_option']
      end

      # get model specific areas to for exterior lighting
      area_length_count_hash = OpenstudioStandards::ExteriorLighting.model_get_exterior_lighting_areas(model)

      # create schedules for exterior lighting objects using midnight to 6am setback or shutdown
      start_setback_shutoff = { hr: 24, min: 0 }
      end_setback_shutoff = { hr: 6, min: 0 }
      shuttoff = false
      setback = false
      if !exterior_lighting_properties['building_facade_and_landscape_automatic_shut_off'].nil? && exterior_lighting_properties['building_facade_and_landscape_automatic_shut_off'] == 1
        ext_lights_sch_facade_and_landscape = OpenStudio::Model::ScheduleRuleset.new(model)
        default_day = ext_lights_sch_facade_and_landscape.defaultDaySchedule
        default_day.addValue(OpenStudio::Time.new(0, end_setback_shutoff[:hr], end_setback_shutoff[:min], 0), 0.0)
        default_day.addValue(OpenStudio::Time.new(0, start_setback_shutoff[:hr], start_setback_shutoff[:min], 0), 1.0)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Facade and Landscape exterior lights shut off from #{start_setback_shutoff} to #{end_setback_shutoff}")
      else
        ext_lights_sch_facade_and_landscape = model.alwaysOnDiscreteSchedule
      end
      if !exterior_lighting_properties['occupancy_setback_reduction'].nil? && (exterior_lighting_properties['occupancy_setback_reduction'] > 0.0)
        ext_lights_sch_other = OpenStudio::Model::ScheduleRuleset.new(model)
        setback_value = 1.0 - exterior_lighting_properties['occupancy_setback_reduction']
        default_day = ext_lights_sch_other.defaultDaySchedule
        default_day.addValue(OpenStudio::Time.new(0, end_setback_shutoff[:hr], end_setback_shutoff[:min], 0), setback_value)
        default_day.addValue(OpenStudio::Time.new(0, start_setback_shutoff[:hr], start_setback_shutoff[:min], 0), 1.0)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Non Facade and Landscape lights reduce by #{exterior_lighting_properties['occupancy_setback_reduction'] * 100} % from #{start_setback_shutoff} to #{end_setback_shutoff}")
      else
        ext_lights_sch_other = model.alwaysOnDiscreteSchedule
      end

      # add exterior lights for parking area
      if !area_length_count_hash[:parking_area_and_drives_area].nil? && area_length_count_hash[:parking_area_and_drives_area] > 0
        # lighting values
        multiplier = area_length_count_hash[:parking_area_and_drives_area] * onsite_parking_fraction
        power = exterior_lighting_properties['parking_areas_and_drives']

        # create exterior lights
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Added #{power.round(2)} W/ft^2 of lighting for #{multiplier} ft^2 of parking area.")
        ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                        name: 'Parking Areas and Drives',
                                                                                        power: power,
                                                                                        units: 'W/ft^2',
                                                                                        multiplier: multiplier,
                                                                                        schedule: ext_lights_sch_other,
                                                                                        control_option: control_option)
        exterior_lights <<  ext_lights
        installed_power += power * multiplier
      end

      # add exterior lights for facades
      if !area_length_count_hash[:building_facades].nil? && area_length_count_hash[:building_facades] > 0
        # lighting values
        multiplier = area_length_count_hash[:building_facades]
        power = exterior_lighting_properties['building_facades']

        # create exterior lights
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Added #{power.round(2)} W/ft^2 of lighting for #{multiplier} ft^2 of building facade area.")
        ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                        name: 'Building Facades',
                                                                                        power: power,
                                                                                        units: 'W/ft^2',
                                                                                        multiplier: multiplier,
                                                                                        schedule: ext_lights_sch_facade_and_landscape,
                                                                                        control_option: control_option)
        exterior_lights <<  ext_lights
        installed_power += power * multiplier
      end

      # add exterior lights for main entries
      if !area_length_count_hash[:main_entries].nil? && area_length_count_hash[:main_entries] > 0
        # lighting values
        multiplier = area_length_count_hash[:main_entries]
        power = exterior_lighting_properties['main_entries']

        # create exterior lights
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Added #{power.round(2)} W/ft of lighting for #{multiplier} ft of main entry length.")
        ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                        name: 'Main Entries',
                                                                                        power: power,
                                                                                        units: 'W/ft',
                                                                                        multiplier: multiplier,
                                                                                        schedule: ext_lights_sch_other,
                                                                                        control_option: control_option)
        exterior_lights <<  ext_lights
        installed_power += power * multiplier
      end

      # add exterior lights for other doors
      if !area_length_count_hash[:other_doors].nil? && area_length_count_hash[:other_doors] > 0
        # lighting values
        multiplier = area_length_count_hash[:other_doors]
        power = exterior_lighting_properties['other_doors']

        # create exterior lights
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Added #{power.round(2)} W/ft of lighting for #{multiplier} ft of other doors.")
        ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                        name: 'Other Doors',
                                                                                        power: power,
                                                                                        units: 'W/ft',
                                                                                        multiplier: multiplier,
                                                                                        schedule: ext_lights_sch_other,
                                                                                        control_option: control_option)
        exterior_lights <<  ext_lights
        installed_power += power * multiplier
      end

      # add exterior lights for entry canopies
      if !area_length_count_hash[:canopy_entry_area].nil? && area_length_count_hash[:canopy_entry_area] > 0
        # lighting values
        multiplier = area_length_count_hash[:canopy_entry_area]
        power = exterior_lighting_properties['entry_canopies']

        # create exterior lights
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Added #{power} W/ft^2 of lighting for #{multiplier} ft^2 of building entry canopies.")
        ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                        name: 'Entry Canopies',
                                                                                        power: power,
                                                                                        units: 'W/ft^2',
                                                                                        multiplier: multiplier,
                                                                                        schedule: ext_lights_sch_other,
                                                                                        control_option: control_option)
        exterior_lights <<  ext_lights
        installed_power += power * multiplier
      end

      # add exterior lights for emergency canopies
      if !area_length_count_hash[:canopy_emergency_area].nil? && area_length_count_hash[:canopy_emergency_area] > 0
        # lighting values
        multiplier = area_length_count_hash[:canopy_emergency_area]
        power = exterior_lighting_properties['loading_areas_for_emergency_vehicles']

        # create exterior lights
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Added #{power} W/ft^2 of lighting for #{multiplier} ft^2 of building emergency canopies.")
        ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                        name: 'Emergency Canopies',
                                                                                        power: power,
                                                                                        units: 'W/ft^2',
                                                                                        multiplier: multiplier,
                                                                                        schedule: ext_lights_sch_other,
                                                                                        control_option: control_option)
        exterior_lights <<  ext_lights
        installed_power += power * multiplier
      end

      # add exterior lights for drive through windows
      if !area_length_count_hash[:drive_through_windows].nil? && area_length_count_hash[:drive_through_windows] > 0
        # lighting values
        multiplier = area_length_count_hash[:drive_through_windows]
        power = exterior_lighting_properties['drive_through_windows_and_doors']

        # create exterior lights
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Added #{power} W/drive through window of lighting for #{multiplier} drive through windows.")
        ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                        name: 'Drive Through Windows',
                                                                                        power: power,
                                                                                        units: 'W/ft^2',
                                                                                        multiplier: multiplier,
                                                                                        schedule: ext_lights_sch_other,
                                                                                        control_option: control_option)
        exterior_lights <<  ext_lights
        installed_power += power * multiplier
      end

      # add base site allowance
      if add_base_site_allowance
        # lighting values
        if !exterior_lighting_properties['base_site_allowance_power'].nil?
          power = exterior_lighting_properties['base_site_allowance_power']
        elsif !exterior_lighting_properties['base_site_allowance_fraction'].nil?
          power = exterior_lighting_properties['base_site_allowance_fraction'] * installed_power # should be of allowed vs. installed, but hard to calculate
        else
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', 'Cannot determine target base site allowance power, will set to 0 W.')
          power = 0.0
        end

        # create exterior lights
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.ExteriorLighting', "Added #{power} W of non landscape tradable exterior lighting. Will follow occupancy setback reduction.")
        ext_lights = OpenstudioStandards::ExteriorLighting.model_create_exterior_lights(model,
                                                                                        name: 'Base Site Allowance',
                                                                                        power: power,
                                                                                        units: 'W',
                                                                                        multiplier: 1.0,
                                                                                        schedule: ext_lights_sch_other,
                                                                                        control_option: control_option)
        exterior_lights << ext_lights
      end

      return exterior_lights
    end
  end
end

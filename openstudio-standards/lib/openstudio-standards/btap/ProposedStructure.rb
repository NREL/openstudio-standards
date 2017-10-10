class Standards_Model < OpenStudio::Model::Model
  # Load the helper libraries for
  require_relative 'Prototype.Fan'
  require_relative 'Prototype.FanConstantVolume'
  require_relative 'Prototype.FanVariableVolume'
  require_relative 'Prototype.FanOnOff'
  require_relative 'Prototype.FanZoneExhaust'
  require_relative 'Prototype.HeatExchangerAirToAirSensibleAndLatent'
  require_relative 'Prototype.ControllerWaterCoil'
  require_relative 'Prototype.Model.hvac'
  require_relative 'Prototype.Model.swh'
  require_relative '../standards/Standards.Model'
  require_relative 'Prototype.building_specific_methods'
  require_relative 'Prototype.Model.elevators'
  require_relative 'Prototype.Model.exterior_lights'

  # Creates a DOE prototype building model and replaces
  # the current model with this model.
  #
  # @param building_type [String] the building type
  # @param template [String] the template
  # @param climate_zone [String] the climate zone
  # @param debug [Boolean] If true, will report out more detailed debugging output
  # @return [Bool] returns true if successful, false if not
  # @example Create a Small Office, 90.1-2010, in ASHRAE Climate Zone 5A (Chicago)
  #   model.create_prototype_building('SmallOffice', '90.1-2010', 'ASHRAE 169-2006-5A')

  def create_prototype_building(building_type, template, climate_zone, epw_file, sizing_run_dir = Dir.pwd, debug = false)

    osm_file_increment = 0
    # There are no reference models for HighriseApartment at vintages Pre-1980 and 1980-2004, nor for NECB 2011. This is a quick check.
    if building_type == 'HighriseApartment' && (template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004')
        OpenStudio.logFree(OpenStudio::Error, 'Not available', "DOE Reference models for #{building_type} at template #{template} are not available, the measure is disabled for this specific type.")
        return false
    end

    lookup_building_type = get_lookup_name(building_type)

    # Retrieve the Prototype Inputs from JSON
    search_criteria = {
        'template' => template,
        'building_type' => building_type
    }

    prototype_input = find_object($os_standards['prototype_inputs'], search_criteria, nil)

    if prototype_input.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find prototype inputs for #{search_criteria}, cannot create model.")
      return false
    end

    case template
      when 'NECB 2011'


        debug_incremental_changes = false
        load_building_type_methods(building_type)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_load_building_type_methods.osm") if debug_incremental_changes

        # Ensure that surfaces are intersected properly.
        load_geometry(building_type, template)
        getSpaces.each {|space1| getSpaces.each {|space2| space1.intersectSurfaces(space2)}}
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_load_geometry.osm") if debug_incremental_changes

        add_design_days_and_weather_file(climate_zone, epw_file)
        add_ground_temperatures(building_type, climate_zone, template)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_add_design_days_and_weather_file.osm") if debug_incremental_changes
        puts weatherFile.get.path.get.to_s
        if weatherFile.empty? or weatherFile.get.path.empty? or not File.exists?(weatherFile.get.path.get.to_s)
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Weatherfile is not defined.")
          raise()
        end

        getBuilding.setName("#{template}-#{building_type}-#{climate_zone}-#{epw_file} created: #{Time.new}")
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_set_name.osm") if debug_incremental_changes

        space_type_map = define_space_type_map(building_type, template, climate_zone)
        File.open("#{sizing_run_dir}/space_type_map.json", 'w') {|f| f.write(JSON.pretty_generate(space_type_map))}

        assign_space_type_stubs('Space Function', template, space_type_map) # TO DO: add support for defining NECB 2011 archetype by building type (versus space function)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_assign_space_type_stubs.osm") if debug_incremental_changes

        add_loads(template)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_add_loads.osm") if debug_incremental_changes

        apply_infiltration_standard(template)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_apply_infiltration.osm") if debug_incremental_changes

        modify_surface_convection_algorithm(template)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_modify_surface_convection_algorithm.osm") if debug_incremental_changes

        add_constructions(building_type, template, climate_zone)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_add_constructions.osm") if debug_incremental_changes

        # Modify Constructions to NECB reference levels
        apply_prm_construction_types(template)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_add_constructions.osm") if debug_incremental_changes

        # Reduce the WWR and SRR, if necessary
        apply_prm_baseline_window_to_wall_ratio(template, nil)
        apply_prm_baseline_skylight_to_roof_ratio(template)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_add_fdwr_srr_rules.osm") if debug_incremental_changes

        create_thermal_zones(building_type, template, climate_zone)
        # For some building types, stories are defined explicitly
        if building_type == 'SmallHotel' && template != 'NECB 2011'
          getBuildingStorys.each {|item| item.remove}
          building_story_map = PrototypeBuilding::SmallHotel::define_building_story_map(building_type, template, climate_zone)
          assign_building_story(building_type, template, climate_zone, building_story_map)
        end
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_create_thermal_zones.osm") if debug_incremental_changes


        return false if runSizingRun("#{sizing_run_dir}/SR0") == false
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_sizing_run_0.osm") if debug_incremental_changes

        add_hvac(building_type, template, climate_zone, prototype_input, epw_file)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_add_hvac.osm") if debug_incremental_changes

        osm_file_increment += 1
        add_swh(building_type, template, climate_zone, prototype_input, epw_file)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_swh.osm") if debug_incremental_changes

        apply_sizing_parameters(building_type, template)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_apply_sizing_paramaters.osm") if debug_incremental_changes

        yearDescription.get.setDayofWeekforStartDay('Sunday')
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_setDayofWeekforStartDay.osm") if debug_incremental_changes

        #set a larger tolerance for unmet hours from default 0.2 to 1.0C
        getOutputControlReportingTolerances.setToleranceforTimeHeatingSetpointNotMet(1.0)
        getOutputControlReportingTolerances.setToleranceforTimeCoolingSetpointNotMet(1.0)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(self, "#{sizing_run_dir}/post_#{osm_file_increment}_setTolerances.osm") if debug_incremental_changes

      else
        #optionally  determine the climate zone from the epw and stat files.
        if climate_zone == 'NECB HDD Method'
          climate_zone = BTAP::Environment::WeatherFile.new(epw_file).a169_2006_climate_zone()
        else
          #this is required to be blank otherwise it may cause side effects.
          epw_file = ""
        end
        load_building_type_methods(building_type)
        load_geometry(building_type, template)
        getBuilding.setName("#{template}-#{building_type}-#{climate_zone} created: #{Time.new}")
        space_type_map = define_space_type_map(building_type, template, climate_zone)
        assign_space_type_stubs(lookup_building_type, template, space_type_map)
        add_loads(template)
        apply_infiltration_standard(template)
        modify_infiltration_coefficients(building_type, template, climate_zone)
        modify_surface_convection_algorithm(template)
        add_constructions(building_type, template, climate_zone)
        create_thermal_zones(building_type, template, climate_zone)
        add_hvac(building_type, template, climate_zone, prototype_input, epw_file)
        custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, self)
        add_swh(building_type, template, climate_zone, prototype_input, epw_file)
        custom_swh_tweaks(building_type, template, climate_zone, prototype_input, self)
        add_exterior_lights(building_type, template, climate_zone, prototype_input)
        add_occupancy_sensors(building_type, template, climate_zone)
        add_design_days_and_weather_file(climate_zone, epw_file)
        add_ground_temperatures(building_type, climate_zone, template)

        apply_sizing_parameters(building_type, template)
        yearDescription.get.setDayofWeekforStartDay('Sunday')

    end
    # set climate zone and building type
    getBuilding.setStandardsBuildingType(building_type)
    if climate_zone.include? 'ASHRAE 169-2006-'
      getClimateZones.setClimateZone('ASHRAE', climate_zone.gsub('ASHRAE 169-2006-', ''))
    end

    # For some building types, stories are defined explicitly
    if building_type == 'SmallHotel'
      getBuildingStorys.each {|item| item.remove}
      building_story_map = PrototypeBuilding::SmallHotel.define_building_story_map(building_type, template, climate_zone)
      assign_building_story(building_type, template, climate_zone, building_story_map)
    end

    # Assign building stories to spaces in the building
    # where stories are not yet assigned.
    assign_spaces_to_stories

    # Perform a sizing run
    if runSizingRun("#{sizing_run_dir}/SR1") == false
      return false
    end

    # If there are any multizone systems, reset damper positions
    # to achieve a 60% ventilation effectiveness minimum for the system
    # following the ventilation rate procedure from 62.1
    apply_multizone_vav_outdoor_air_sizing(template)

    # This is needed for NECB 2011 as a workaround for sizing the reheat boxes
    if template == 'NECB 2011'
      getAirTerminalSingleDuctVAVReheats.each {|iobj| iobj.set_heating_cap}
    end

    # Apply the prototype HVAC assumptions
    # which include sizing the fan pressure rises based
    # on the flow rate of the system.
    apply_prototype_hvac_assumptions(building_type, template, climate_zone)

    # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
    # AHU1 doesn't have economizer
    if building_type == 'Outpatient'
      PrototypeBuilding::Outpatient.modify_oa_controller(template, self)
      # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
      PrototypeBuilding::Outpatient.reset_or_room_vav_minimum_damper(prototype_input, template, self)
    end

    if building_type == 'Hospital'
      PrototypeBuilding::Hospital.modify_hospital_oa_controller(template, self)
    end

    # Apply the HVAC efficiency standard
    apply_hvac_efficiency_standard(template, climate_zone)

    # Add daylighting controls per standard
    # only four zones in large hotel have daylighting controls
    # todo: YXC to merge to the main function
    if building_type == 'LargeHotel'
      PrototypeBuilding::LargeHotel.large_hotel_add_daylighting_controls(template, self)
    elsif building_type == 'Hospital'
      PrototypeBuilding::Hospital.hospital_add_daylighting_controls(template, self)
    else
      add_daylighting_controls(template)
    end

    if building_type == 'QuickServiceRestaurant'
      PrototypeBuilding::QuickServiceRestaurant.update_exhaust_fan_efficiency(template, self)
    elsif building_type == 'FullServiceRestaurant'
      PrototypeBuilding::FullServiceRestaurant.update_exhaust_fan_efficiency(template, self)
    elsif building_type == 'Outpatient'
      PrototypeBuilding::Outpatient.update_exhaust_fan_efficiency(template, self)
    end

    if building_type == 'HighriseApartment'
      PrototypeBuilding::HighriseApartment.update_fan_efficiency(self)
    end

    # Add output variables for debugging
    if debug
      request_timeseries_outputs
    end

    # Finished
    model_status = 'final'
    save(OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.osm"), true)

    return true
  end

  # Get the name of the building type used in lookups
  #
  # @param building_type [String] the building type
  # @return [String] returns the lookup name as a string
  # @todo Unify the lookup names and eliminate this method
  def get_lookup_name(building_type)
    lookup_name = building_type

    case building_type
      when 'SmallOffice'
        lookup_name = 'Office'
      when 'MediumOffice'
        lookup_name = 'Office'
      when 'LargeOffice'
        lookup_name = 'Office'
      when 'RetailStandalone'
        lookup_name = 'Retail'
      when 'RetailStripmall'
        lookup_name = 'StripMall'
      when 'Office'
        lookup_name = 'Office'
    end

    return lookup_name
  end

  # Loads the library of methods specific to this building type
  #
  # @param building_type [String] the building type
  # @param template [String] the template
  # @param climate_zone [String] the climate zone
  # @return [Bool] returns true if successful, false if not
  def load_building_type_methods(building_type)
    building_methods = nil

    case building_type
      when 'SecondarySchool'
        building_methods = 'Prototype.secondary_school'
      when 'PrimarySchool'
        building_methods = 'Prototype.primary_school'
      when 'SmallOffice'
        building_methods = 'Prototype.small_office'
      when 'MediumOffice'
        building_methods = 'Prototype.medium_office'
      when 'LargeOffice'
        building_methods = 'Prototype.large_office'
      when 'SmallHotel'
        building_methods = 'Prototype.small_hotel'
      when 'LargeHotel'
        building_methods = 'Prototype.large_hotel'
      when 'Warehouse'
        building_methods = 'Prototype.warehouse'
      when 'RetailStandalone'
        building_methods = 'Prototype.retail_standalone'
      when 'RetailStripmall'
        building_methods = 'Prototype.retail_stripmall'
      when 'QuickServiceRestaurant'
        building_methods = 'Prototype.quick_service_restaurant'
      when 'FullServiceRestaurant'
        building_methods = 'Prototype.full_service_restaurant'
      when 'Hospital'
        building_methods = 'Prototype.hospital'
      when 'Outpatient'
        building_methods = 'Prototype.outpatient'
      when 'MidriseApartment'
        building_methods = 'Prototype.mid_rise_apartment'
      when 'HighriseApartment'
        building_methods = 'Prototype.high_rise_apartment'
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Building Type = #{building_type} not recognized")
        return false
    end

    require_relative "#{building_methods}"

    return true
  end

  # Loads a geometry-only .osm as a starting point.
  #
  # @param building_type [String] the building type
  # @param template [String] the template
  # @param climate_zone [String] the climate zone
  # @return [Bool] returns true if successful, false if not
  def load_geometry(building_type, template)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started adding geometry')

    # Determine which geometry file to use
    # based on building_type and template
    # NECB 2011 geometry is not explicitly defined; for NECB 2011 template, latest ASHRAE 90.1 geometry file is assigned (implicitly)

    building_type_to_geometry_json = File.join(File.dirname(__FILE__), "../../../data/geometry/archetypes/#{building_type}.json")
    puts "\n#{building_type_to_geometry_json}\nEXIST: #{File.exists?(building_type_to_geometry_json)}\n"
    begin
      building_type_to_geometry = JSON.parse(File.read(building_type_to_geometry_json))
    rescue JSON::ParserError => e
      puts "THE CONTENTS OF THE JSON FILE AT #{building_type_to_geometry_json} IS NOT VALID"
      raise e
    end

    if building_type_to_geometry.has_key?(building_type)
      if building_type_to_geometry[building_type]['geometry'].has_key?(template)
        puts building_type_to_geometry[building_type]['geometry'][template]
        geometry_file = building_type_to_geometry[building_type]['geometry'][template]
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model.define_space_type_map', "Template = [#{building_type}] was not found for Building Type = [#{building_type}] at #{building_type_to_geometry_json}.")
        return false
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model.define_space_type_map', "Building Type = #{building_type} was not found at #{building_type_to_geometry_json}")
      return false
    end

    # Load the geometry .osm
    geom_dir = "../../../data/geometry"
    replace_model("#{geom_dir}/#{geometry_file}")

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding geometry')
    #ensure that model is intersected correctly.
    getSpaces.each {|space1| getSpaces.each {|space2| space1.intersectSurfaces(space2)}}
    return true
  end

  # Replaces all objects in the current model
  # with the objects in the .osm.  Typically used to
  # load a model as a starting point.
  #
  # @param rel_path_to_osm [String] the path to an .osm file, relative to this file
  # @return [Bool] returns true if successful, false if not
  def replace_model(rel_path_to_osm)
    # Take the existing model and remove all the objects
    # (this is cheesy), but need to keep the same memory block
    handles = OpenStudio::UUIDVector.new
    objects.each {|o| handles << o.handle}
    removeObjects(handles)

    model = nil
    if File.dirname(__FILE__)[0] == ':'
      # running from embedded location

      # Load geometry from the saved geometry.osm
      geom_model_string = load_resource_relative(rel_path_to_osm)

      # version translate from string
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = version_translator.loadModelFromString(geom_model_string)
    else
      abs_path = File.join(File.dirname(__FILE__), rel_path_to_osm)

      # version translate from string
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = version_translator.loadModel(abs_path)
    end

    if model.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Version translation failed for #{rel_path_to_osm}")
      return false
    end
    model = model.get

    # Add the objects from the geometry model to the working model
    addObjects(model.toIdfFile.objects)

    return true
  end

  # Reads in a mapping between names of space types and
  # names of spaces in the model, creates an empty OpenStudio::Model::SpaceType
  # (no loads, occupants, schedules, etc.) for each space type, and assigns this
  # space type to the list of spaces named.  Later on, these empty space types
  # can be used as keys in a lookup to add loads, schedules, and
  # other inputs that are either typical or governed by a standard.
  #
  # @param building_type [String] the name of the building type
  # @param space_type_map [Hash] a hash where the key is the space type name
  #   and the value is a vector of space names that should be assigned this space type.
  #   The hash for each building is defined inside the Prototype.building_name
  #   e.g. (Prototype.secondary_school.rb) file.
  # @return [Bool] returns true if successful, false if not
  def assign_space_type_stubs(building_type, template, space_type_map)
    space_type_map.each do |space_type_name, space_names|
      # Create a new space type
      stub_space_type = OpenStudio::Model::SpaceType.new(self)
      stub_space_type.setStandardsBuildingType(building_type)
      stub_space_type.setStandardsSpaceType(space_type_name)
      stub_space_type.setName("#{building_type} #{space_type_name}")
      stub_space_type.apply_rendering_color(template)

      stub_space_type_occsens = nil
      occsensSpaceTypeCreated = false # Flag to determine need for another space type
      occsensSpaceTypeCount = 0

      space_names.each do |space_name|
        space = getSpaceByName(space_name)
        next if space.empty?
        space = space.get

        occsensSpaceTypeUsed = false

        if template == "NECB 2011"
          # Check if space type for this space matches NECB 2011 specific space type
          # for occupancy sensor that is area dependent. Note: space.floorArea in m2.
          space_type_name_occsens = space_type_name + " - occsens"
          if ((space_type_name=='Storage area' && space.floorArea < 100) ||
              (space_type_name=='Storage area - refrigerated' && space.floorArea < 100) ||
              (space_type_name=='Hospital - medical supply' && space.floorArea < 100) ||
              (space_type_name=='Office - enclosed' && space.floorArea < 25))
            # If there is only one space assigned to this space type, then reassign this stub
            # to the template duplicate with appendage " - occsens", otherwise create a new stub
            # for this space. Required to use reduced LPD by NECB 2011 0.9 factor.
            occsensSpaceTypeUsed = true
            if !occsensSpaceTypeCreated
              # create a new space type just once for space_type_name appended with " - occsens"
              stub_space_type_occsens = OpenStudio::Model::SpaceType.new(self)
              stub_space_type_occsens.setStandardsBuildingType(building_type)
              stub_space_type_occsens.setStandardsSpaceType(space_type_name_occsens)
              stub_space_type_occsens.setName("#{building_type} #{space_type_name_occsens}")
              stub_space_type_occsens.apply_rendering_color(template)
              occsensSpaceTypeCreated = true
              occsensSpaceTypeCount += 1
            else
              # reassign occsens space type stub already created...
              stub_space_type_occsens.setStandardsSpaceType(space_type_name_occsens)
              stub_space_type_occsens.setName("#{building_type} #{space_type_name_occsens}")
              occsensSpaceTypeCount += 1
            end
          end
        end

        if occsensSpaceTypeUsed
          space.setSpaceType(stub_space_type_occsens)
        else
          space.setSpaceType(stub_space_type)
        end

        if occsensSpaceTypeCount == space_names.length
          # delete the stub_space_type since all spaces were reassigned to stub_space_type_occsens
          stub_space_type.remove
        end

        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Setting #{space.name} to #{building_type}.#{space_type_name}")
      end
    end
    return true
  end

  def add_full_space_type_libs(template)
    space_type_properties_list = find_objects($os_standards['space_types'], 'template' => 'NECB 2011')
    space_type_properties_list.each do |space_type_property|
      stub_space_type = OpenStudio::Model::SpaceType.new(self)
      stub_space_type.setStandardsBuildingType(space_type_property['building_type'])
      stub_space_type.setStandardsSpaceType(space_type_property['space_type'])
      stub_space_type.setName("#{template}-#{space_type_property['building_type']}-#{space_type_property['space_type']}")
      stub_space_type.apply_rendering_color(template)
    end
    add_loads(template)
  end

  def assign_building_story(building_type, template, climate_zone, building_story_map)
    building_story_map.each do |building_story_name, space_names|
      stub_building_story = OpenStudio::Model::BuildingStory.new(self)
      stub_building_story.setName(building_story_name)

      space_names.each do |space_name|
        space = getSpaceByName(space_name)
        next if space.empty?
        space = space.get
        space.setBuildingStory(stub_building_story)
      end
    end
    return true
  end

  # Adds the loads and associated schedules for each space type
  # as defined in the OpenStudio_Standards_space_types.json file.
  # This includes lights, plug loads, occupants, ventilation rate requirements,
  # infiltration, gas equipment (for kitchens, etc.) and typical schedules for each.
  # Some loads are governed by the standard, others are typical values
  # pulled from sources such as the DOE Reference and DOE Prototype Buildings.
  #
  # @param template [String] the template to draw data from
  # @param climate_zone [String] the name of the climate zone the building is in
  # @return [Bool] returns true if successful, false if not

  def add_loads(template)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying space types (loads)')

    # Loop through all the space types currently in the model,
    # which are placeholders, and give them appropriate loads and schedules
    getSpaceTypes.sort.each do |space_type|
      # Rendering color
      space_type.apply_rendering_color(template)

      # Loads
      space_type.apply_internal_loads(template, true, true, true, true, true, true)

      # Schedules
      space_type.apply_internal_load_schedules(template, true, true, true, true, true, true, true)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying space types (loads)')

    return true
  end

  # Adds code-minimum constructions based on the building type
  # as defined in the OpenStudio_Standards_construction_sets.json file.
  # Where there is a separate construction set specified for the
  # individual space type, this construction set will be created and applied
  # to this space type, overriding the whole-building construction set.
  #
  # @param building_type [String] the type of building
  # @param template [String] the template to draw data from
  # @param climate_zone [String] the name of the climate zone the building is in
  # @return [Bool] returns true if successful, false if not
  def add_constructions(building_type, template, climate_zone)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying constructions')
    is_residential = 'No' # default is nonresidential for building level

    # The constructions lookup table uses a slightly different list of
    # building types.
    lookup_building_type = get_lookup_name(building_type)

    # Assign construction to adiabatic construction
    # Assign a material to all internal mass objects
    cp02_carpet_pad = OpenStudio::Model::MasslessOpaqueMaterial.new(self)
    cp02_carpet_pad.setName('CP02 CARPET PAD')
    cp02_carpet_pad.setRoughness('VeryRough')
    cp02_carpet_pad.setThermalResistance(0.21648)
    cp02_carpet_pad.setThermalAbsorptance(0.9)
    cp02_carpet_pad.setSolarAbsorptance(0.7)
    cp02_carpet_pad.setVisibleAbsorptance(0.8)

    normalweight_concrete_floor = OpenStudio::Model::StandardOpaqueMaterial.new(self)
    normalweight_concrete_floor.setName('100mm Normalweight concrete floor')
    normalweight_concrete_floor.setRoughness('MediumSmooth')
    normalweight_concrete_floor.setThickness(0.1016)
    normalweight_concrete_floor.setConductivity(2.31)
    normalweight_concrete_floor.setDensity(2322)
    normalweight_concrete_floor.setSpecificHeat(832)

    nonres_floor_insulation = OpenStudio::Model::MasslessOpaqueMaterial.new(self)
    nonres_floor_insulation.setName('Nonres_Floor_Insulation')
    nonres_floor_insulation.setRoughness('MediumSmooth')
    nonres_floor_insulation.setThermalResistance(2.88291975297193)
    nonres_floor_insulation.setThermalAbsorptance(0.9)
    nonres_floor_insulation.setSolarAbsorptance(0.7)
    nonres_floor_insulation.setVisibleAbsorptance(0.7)

    floor_adiabatic_construction = OpenStudio::Model::Construction.new(self)
    floor_adiabatic_construction.setName('Floor Adiabatic construction')
    floor_layers = OpenStudio::Model::MaterialVector.new
    floor_layers << cp02_carpet_pad
    floor_layers << normalweight_concrete_floor
    floor_layers << nonres_floor_insulation
    floor_adiabatic_construction.setLayers(floor_layers)

    g01_13mm_gypsum_board = OpenStudio::Model::StandardOpaqueMaterial.new(self)
    g01_13mm_gypsum_board.setName('G01 13mm gypsum board')
    g01_13mm_gypsum_board.setRoughness('Smooth')
    g01_13mm_gypsum_board.setThickness(0.0127)
    g01_13mm_gypsum_board.setConductivity(0.1600)
    g01_13mm_gypsum_board.setDensity(800)
    g01_13mm_gypsum_board.setSpecificHeat(1090)
    g01_13mm_gypsum_board.setThermalAbsorptance(0.9)
    g01_13mm_gypsum_board.setSolarAbsorptance(0.7)
    g01_13mm_gypsum_board.setVisibleAbsorptance(0.5)

    wall_adiabatic_construction = OpenStudio::Model::Construction.new(self)
    wall_adiabatic_construction.setName('Wall Adiabatic construction')
    wall_layers = OpenStudio::Model::MaterialVector.new
    wall_layers << g01_13mm_gypsum_board
    wall_layers << g01_13mm_gypsum_board
    wall_adiabatic_construction.setLayers(wall_layers)

    m10_200mm_concrete_block_basement_wall = OpenStudio::Model::StandardOpaqueMaterial.new(self)
    m10_200mm_concrete_block_basement_wall.setName('M10 200mm concrete block basement wall')
    m10_200mm_concrete_block_basement_wall.setRoughness('MediumRough')
    m10_200mm_concrete_block_basement_wall.setThickness(0.2032)
    m10_200mm_concrete_block_basement_wall.setConductivity(1.326)
    m10_200mm_concrete_block_basement_wall.setDensity(1842)
    m10_200mm_concrete_block_basement_wall.setSpecificHeat(912)

    basement_wall_construction = OpenStudio::Model::Construction.new(self)
    basement_wall_construction.setName('Basement Wall construction')
    basement_wall_layers = OpenStudio::Model::MaterialVector.new
    basement_wall_layers << m10_200mm_concrete_block_basement_wall
    basement_wall_construction.setLayers(basement_wall_layers)

    basement_floor_construction = OpenStudio::Model::Construction.new(self)
    basement_floor_construction.setName('Basement Floor construction')
    basement_floor_layers = OpenStudio::Model::MaterialVector.new
    basement_floor_layers << m10_200mm_concrete_block_basement_wall
    basement_floor_layers << cp02_carpet_pad
    basement_floor_construction.setLayers(basement_floor_layers)

    getSurfaces.each do |surface|
      if surface.outsideBoundaryCondition.to_s == 'Adiabatic'
        if surface.surfaceType.to_s == 'Wall'
          surface.setConstruction(wall_adiabatic_construction)
        else
          surface.setConstruction(floor_adiabatic_construction)
        end
      elsif surface.outsideBoundaryCondition.to_s == 'OtherSideCoefficients'
        # Ground
        if surface.surfaceType.to_s == 'Wall'
          surface.setOutsideBoundaryCondition('Ground')
          surface.setConstruction(basement_wall_construction)
        else
          surface.setOutsideBoundaryCondition('Ground')
          surface.setConstruction(basement_floor_construction)
        end
      end
    end

    # Make the default construction set for the building
    bldg_def_const_set = add_construction_set(template, climate_zone, lookup_building_type, nil, is_residential)

    if bldg_def_const_set.is_initialized
      getBuilding.setDefaultConstructionSet(bldg_def_const_set.get)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not create default construction set for the building.')
      return false
    end

    # Make a construction set for each space type, if one is specified
    getSpaceTypes.each do |space_type|
      # Get the standards building type
      stds_building_type = nil
      if space_type.standardsBuildingType.is_initialized
        stds_building_type = space_type.standardsBuildingType.get
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Space type called '#{space_type.name}' has no standards building type.")
      end

      # Get the standards space type
      stds_spc_type = nil
      if space_type.standardsSpaceType.is_initialized
        stds_spc_type = space_type.standardsSpaceType.get
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Space type called '#{space_type.name}' has no standards space type.")
      end

      # If the standards space type is Attic,
      # the building type should be blank.
      if stds_spc_type == 'Attic'
        stds_building_type = ''
      end

      # Attempt to make a construction set for this space type
      # and assign it if it can be created.
      spc_type_const_set = add_construction_set(template, climate_zone, stds_building_type, stds_spc_type, is_residential)
      if spc_type_const_set.is_initialized
        space_type.setDefaultConstructionSet(spc_type_const_set.get)
      end
    end

    # Add construction from story level, especially for the case when there are residential and nonresidential construction in the same building
    if lookup_building_type == 'SmallHotel' && template != 'NECB 2011'
      getBuildingStorys.each do |story|
        next if story.name.get == 'AtticStory'
        puts "story = #{story.name}"
        is_residential = 'No' # default for building story level
        exterior_spaces_area = 0
        story_exterior_residential_area = 0

        # calculate the propotion of residential area in exterior spaces, see if this story is residential or not
        story.spaces.each do |space|
          next if space.exteriorWallArea.zero?
          space_type = space.spaceType.get
          if space_type.standardsSpaceType.is_initialized
            space_type_name = space_type.standardsSpaceType.get
          end
          data = find_object($os_standards['space_types'], 'template' => template, 'building_type' => lookup_building_type, 'space_type' => space_type_name)
          exterior_spaces_area += space.floorArea
          story_exterior_residential_area += space.floorArea if data['is_residential'] == 'Yes' # "Yes" is residential, "No" or nil is nonresidential
        end
        is_residential = 'Yes' if story_exterior_residential_area / exterior_spaces_area >= 0.5
        next if is_residential == 'No'

        # if the story is identified as residential, assign residential construction set to the spaces on this story.
        building_story_const_set = add_construction_set(template, climate_zone, lookup_building_type, nil, is_residential)
        if building_story_const_set.is_initialized
          story.spaces.each do |space|
            space.setDefaultConstructionSet(building_story_const_set.get)
          end
        end
      end
      # Standars: For whole buildings or floors where 50% or more of the spaces adjacent to exterior walls are used primarily for living and sleeping quarters

    end

    # Make skylights have the same construction as fixed windows
    # sub_surface = self.getBuilding.defaultConstructionSet.get.defaultExteriorSubSurfaceConstructions.get
    # window_construction = sub_surface.fixedWindowConstruction.get
    # sub_surface.setSkylightConstruction(window_construction)

    # Assign a material to all internal mass objects
    material = OpenStudio::Model::StandardOpaqueMaterial.new(self)
    material.setName('Std Wood 6inch')
    material.setRoughness('MediumSmooth')
    material.setThickness(0.15)
    material.setConductivity(0.12)
    material.setDensity(540)
    material.setSpecificHeat(1210)
    material.setThermalAbsorptance(0.9)
    material.setSolarAbsorptance(0.7)
    material.setVisibleAbsorptance(0.7)
    construction = OpenStudio::Model::Construction.new(self)
    construction.setName('InteriorFurnishings')
    layers = OpenStudio::Model::MaterialVector.new
    layers << material
    construction.setLayers(layers)

    # Assign the internal mass construction to existing internal mass objects
    getSpaces.each do |space|
      internal_masses = space.internalMass
      internal_masses.each do |internal_mass|
        internal_mass.internalMassDefinition.setConstruction(construction)
      end
    end

    # get all the space types that are conditioned

    # not required for NECB 2011
    unless template == 'NECB 2011'
      conditioned_space_names = find_conditioned_space_names(building_type, template, climate_zone)
    end

    # add internal mass
    # not required for NECB 2011
    unless (template == 'NECB 2011') ||
        ((building_type == 'SmallHotel') &&
            (template == '90.1-2004' || template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013'))
      internal_mass_def = OpenStudio::Model::InternalMassDefinition.new(self)
      internal_mass_def.setSurfaceAreaperSpaceFloorArea(2.0)
      internal_mass_def.setConstruction(construction)
      conditioned_space_names.each do |conditioned_space_name|
        space = getSpaceByName(conditioned_space_name)
        if space.is_initialized
          space = space.get
          internal_mass = OpenStudio::Model::InternalMass.new(internal_mass_def)
          internal_mass.setName("#{space.name} Mass")
          internal_mass.setSpace(space)
        end
      end
    end


    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying constructions')

    return true
  end

  # Get the list of all conditioned spaces, as defined for each building in the
  # system_to_space_map inside the Prototype.building_name
  # e.g. (Prototype.secondary_school.rb) file.
  #
  # @param (see #add_constructions)
  # @return [Array<String>] returns an array of space names as strings
  def find_conditioned_space_names(building_type, template, climate_zone)
    system_to_space_map = define_hvac_system_map(building_type, template, climate_zone)
    conditioned_space_names = OpenStudio::StringVector.new
    system_to_space_map.each do |system|
      system['space_names'].each do |space_name|
        conditioned_space_names << space_name
      end
    end
    return conditioned_space_names
  end

  # Creates thermal zones to contain each space, as defined for each building in the
  # system_to_space_map inside the Prototype.building_name
  # e.g. (Prototype.secondary_school.rb) file.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  def create_thermal_zones(building_type, template, climate_zone)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started creating thermal zones')

    # Remove any Thermal zones assigned
    getThermalZones.each(&:remove)

    # This map define the multipliers for spaces with multipliers not equals to 1
    case building_type
      when 'LargeHotel'
        space_multiplier_map = PrototypeBuilding::LargeHotel.define_space_multiplier
      when 'MidriseApartment'
        space_multiplier_map = PrototypeBuilding::MidriseApartment.define_space_multiplier
      when 'LargeOffice'
        space_multiplier_map = PrototypeBuilding::LargeOffice.define_space_multiplier
      when 'Hospital'
        space_multiplier_map = PrototypeBuilding::Hospital.define_space_multiplier
      else
        space_multiplier_map = {}
    end

    # Create a thermal zone for each space in the self
    getSpaces.each do |space|
      zone = OpenStudio::Model::ThermalZone.new(self)
      zone.setName("#{space.name} ZN")
      unless space_multiplier_map[space.name.to_s].nil?
        zone.setMultiplier(space_multiplier_map[space.name.to_s])
      end
      space.setThermalZone(zone)

      # Skip thermostat for spaces with no space type
      next if space.spaceType.empty?

      # Add a thermostat
      space_type_name = space.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostat_clone = thermostat.get.clone(self).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostat_clone)
        if template == 'NECB 2011'
          #Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
          ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(self)
          ideal_loads.addToThermalZone(zone)
        end
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished creating thermal zones')
  end

  # Loop through thermal zones and run thermal_zone.add_exhaust
  # If kitchen_makeup is "None" then exhaust will be modeled in every kitchen zone without makeup air
  # If kitchen_makeup is "Adjacent" then exhaust will be modeled in every kitchen zone. Makeup air will be provided when there as an adjacent dining,cafe, or cafeteria zone of the same buidling type.
  # If kitchen_makeup is "Largest Zone" then exhaust will only be modeled in the largest kitchen zone, but the flow rate will be based on the kitchen area for all zones. Makeup air will be modeled in the largest dining,cafe, or cafeteria zone of the same building type.
  #
  # @param template [String] Valid choices are
  # @param kitchen_makeup [String] Valid choices are
  # @return [Hash] Hash of newly made exhaust fan objects along with secondary exhaust and zone mixing objects
  def add_exhaust(template, kitchen_makeup = "Adjacent") # kitchen_makeup options are (None, Largest Zone, Adjacent)

    zone_exhaust_fans = {}

    # apply use specified kitchen_makup logic
    if not ["Adjacent", "Largest Zone"].include?(kitchen_makeup)

      if not kitchen_makeup == "None"
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "#{kitchen_makeup} is an unexpected value for kitchen_makup arg, will use None.")
      end

      # loop through thermal zones
      self.getThermalZones.each do |thermal_zone|
        zone_exhaust_hash = thermal_zone.add_exhaust(template)

        # populate zone_exhaust_fans
        zone_exhaust_fans.merge!(zone_exhaust_hash)
      end

    else # common code for Adjacent and Largest Zone

      # populate standard_space_types_with_makup_air
      standard_space_types_with_makup_air = {}
      standard_space_types_with_makup_air[["FullServiceRestaurant", "Kitchen"]] = ["FullServiceRestaurant", "Dining"]
      standard_space_types_with_makup_air[["QuickServiceRestaurant", "Kitchen"]] = ["QuickServiceRestaurant", "Dining"]
      standard_space_types_with_makup_air[["Hospital", "Kitchen"]] = ["Hospital", "Dining"]
      standard_space_types_with_makup_air[["SecondarySchool", "Kitchen"]] = ["SecondarySchool", "Cafeteria"]
      standard_space_types_with_makup_air[["PrimarySchool", "Kitchen"]] = ["PrimarySchool", "Cafeteria"]
      standard_space_types_with_makup_air[["LargeHotel", "Kitchen"]] = ["LargeHotel", "Cafe"]

      # gather information on zones organized by standards building type and space type. zone may be in this multiple times if it has multiple space types
      zones_by_standards = {}

      self.getThermalZones.each do |thermal_zone|

        # get space type ratio for spaces in zone
        space_type_hash = {} # key is  space type,  value hash with floor area, standards building type, standards space type, and array of adjacent zones
        thermal_zone.spaces.each do |space|
          next if not space.spaceType.is_initialized
          next if not space.partofTotalFloorArea
          space_type = space.spaceType.get
          next if not space_type.standardsBuildingType.is_initialized
          next if not space_type.standardsSpaceType.is_initialized

          # add entry in hash for space_type_standardsif it doesn't already exist
          if not space_type_hash.has_key?(space_type)
            space_type_hash[space_type] = {}
            space_type_hash[space_type][:effective_floor_area] = 0.0
            space_type_hash[space_type][:standards_array] =[space_type.standardsBuildingType.get, space_type.standardsSpaceType.get]
            if kitchen_makeup == "Adjacent"
              space_type_hash[space_type][:adjacent_zones] = []
            end
          end

          # populate floor area
          space_type_hash[space_type][:effective_floor_area] += space.floorArea * space.multiplier

          # todo - populate adjacent zones (need to add methods to space and zone for this)
          if kitchen_makeup == "Adjacent"
            space_type_hash[space_type][:adjacent_zones] << nil
          end

          # populate zones_by_standards
          if not zones_by_standards.has_key?(space_type_hash[space_type][:standards_array])
            zones_by_standards[space_type_hash[space_type][:standards_array]] = {}
          end
          zones_by_standards[space_type_hash[space_type][:standards_array]][thermal_zone] = space_type_hash

        end

      end

      if kitchen_makeup == "Largest Zone"

        zones_applied = [] # add thermal zones to this ones they have had thermal_zone.add_exhaust run on it

        # loop through standard_space_types_with_makup_air
        standard_space_types_with_makup_air.each do |makeup_target, makeup_source|

          # hash to manage lookups
          markup_target_effective_floor_area = {}
          markup_source_effective_floor_area = {}

          if zones_by_standards.has_key?(makeup_target)

            # process zones of each makeup_target
            zones_by_standards[makeup_target].each do |thermal_zone, space_type_hash|
              effective_floor_area = 0.0
              space_type_hash.each do |space_type, hash|
                effective_floor_area += space_type_hash[space_type][:effective_floor_area]
              end
              markup_target_effective_floor_area[thermal_zone] = effective_floor_area
            end

            # find zone with largest effective area of this space type
            largest_target_zone = markup_target_effective_floor_area.key(markup_target_effective_floor_area.values.max)

            # find total effective area to calculate exhaust, then divide by zone multiplier when add exhaust
            target_effective_floor_area = markup_target_effective_floor_area.values.reduce(0, :+)

            # find zones that match makeup_target with makeup_source
            if zones_by_standards.has_key?(makeup_source)

              # process zones of each makeup_source
              zones_by_standards[makeup_source].each do |thermal_zone, space_type_hash|
                effective_floor_area = 0.0
                space_type_hash.each do |space_type, hash|
                  effective_floor_area += space_type_hash[space_type][:effective_floor_area]
                end

                markup_source_effective_floor_area[thermal_zone] = effective_floor_area
              end
              # find zone with largest effective area of this space type
              largest_source_zone = markup_source_effective_floor_area.key(markup_source_effective_floor_area.values.max)
            else

              # issue warning that makeup air wont be made but still make exhaust
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Model has zone with #{makeup_target} but not #{makeup_source}. Exhaust will be added, but no makeup air.")
              next

            end

            OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Largest #{makeup_target} is #{largest_target_zone.name} which will provide exahust for #{target_effective_floor_area} m^2")
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Largest #{makeup_source} is #{largest_source_zone.name} which will provide makeup air for #{makeup_target}")

            # add in extra arguments for makeup air
            exhaust_makeup_inputs = {}
            exhaust_makeup_inputs[makeup_target] = {} # for now only one makeup target per zone, but method could have multiple
            exhaust_makeup_inputs[makeup_target][:target_effective_floor_area] = target_effective_floor_area
            exhaust_makeup_inputs[makeup_target][:source_zone] = largest_source_zone


            # add exhaust
            next if zones_applied.include?(largest_target_zone) # would only hit this if zone has two space types each requesting makeup air
            zone_exhaust_hash = largest_target_zone.add_exhaust(template, exhaust_makeup_inputs)
            zones_applied << largest_target_zone
            zone_exhaust_fans.merge!(zone_exhaust_hash)

          end

        end

        # add exhaust to zones that did not contain space types with standard_space_types_with_makup_air
        zones_by_standards.each do |standards_array, zones_hash|
          next if standard_space_types_with_makup_air.has_key?(standards_array)

          # loop through zones adding exhaust
          zones_hash.each do |thermal_zone, space_type_hash|
            next if zones_applied.include?(thermal_zone)

            # add exhaust
            zone_exhaust_hash = thermal_zone.add_exhaust(template)
            zones_applied << thermal_zone
            zone_exhaust_fans.merge!(zone_exhaust_hash)
          end

        end


      else #kitchen_makeup == "Adjacent"

        zones_applied = [] # add thermal zones to this ones they have had thermal_zone.add_exhaust run on it

        standard_space_types_with_makup_air.each do |makeup_target, makeup_source|
          if zones_by_standards.has_key?(makeup_target)
            # process zones of each makeup_target
            zones_by_standards[makeup_target].each do |thermal_zone, space_type_hash|

              # get adjacent zones
              adjacent_zones = thermal_zone.get_adjacent_zones_with_shared_wall_areas

              # find adjacent zones matching key and value from standard_space_types_with_makup_air
              first_adjacent_makeup_source = nil
              adjacent_zones.each do |adjacent_zone|

                next if not first_adjacent_makeup_source.nil?

                if zones_by_standards.has_key?(makeup_source) and zones_by_standards[makeup_source].has_key?(adjacent_zone)
                  first_adjacent_makeup_source = adjacent_zone

                  # todo - add in extra arguments for makeup air
                  exhaust_makeup_inputs = {}
                  exhaust_makeup_inputs[makeup_target] = {} # for now only one makeup target per zone, but method could have multiple
                  exhaust_makeup_inputs[makeup_target][:source_zone] = first_adjacent_makeup_source

                  # add exhaust
                  zone_exhaust_hash = thermal_zone.add_exhaust(template, exhaust_makeup_inputs)
                  zones_applied << thermal_zone
                  zone_exhaust_fans.merge!(zone_exhaust_hash)
                end

              end

              if first_adjacent_makeup_source.nil?

                # issue warning that makeup air wont be made but still make exhaust
                OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Model has zone with #{makeup_target} but no adjacent zone with #{makeup_source}. Exhaust will be added, but no makeup air.")

                # add exhaust
                zone_exhaust_hash = thermal_zone.add_exhaust(template)
                zones_applied << thermal_zone
                zone_exhaust_fans.merge!(zone_exhaust_hash)

              end

            end

          end
        end

        # add exhaust for rest of zones
        self.getThermalZones.each do |thermal_zone|
          next if zones_applied.include?(thermal_zone)

          # add exhaust
          zone_exhaust_hash = thermal_zone.add_exhaust(template)
          zone_exhaust_fans.merge!(zone_exhaust_hash)
        end

      end

    end

    return zone_exhaust_fans

  end

  # Adds occupancy sensors to certain space types per
  # the PNNL documentation.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  # @todo genericize and move this method to Standards.Space
  def add_occupancy_sensors(building_type, template, climate_zone)
    # Only add occupancy sensors for 90.1-2010
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
        return true
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Occupancy Sensors')

    space_type_reduction_map = {
        'SecondarySchool' => {'Classroom' => 0.32, 'Restroom' => 0.34, 'Office' => 0.22},
        'PrimarySchool' => {'Classroom' => 0.32, 'Restroom' => 0.34, 'Office' => 0.22}
    }

    # Loop through all the space types and reduce lighting operation schedule fractions as-specified
    getSpaceTypes.each do |space_type|
      # Skip space types with no standards building type
      next if space_type.standardsBuildingType.empty?
      stds_bldg_type = space_type.standardsBuildingType.get

      # Skip space types with no standards space type
      next if space_type.standardsSpaceType.empty?
      stds_spc_type = space_type.standardsSpaceType.get

      # Skip building types and space types that aren't listed in the hash
      next unless space_type_reduction_map.key?(stds_bldg_type)
      next unless space_type_reduction_map[stds_bldg_type].key?(stds_spc_type)

      # Get the reduction fraction multiplier
      red_multiplier = 1 - space_type_reduction_map[stds_bldg_type][stds_spc_type]

      lights_sch_names = []
      lights_schs = {}
      reduced_lights_schs = {}

      # Get all of the lights in this space type
      # and determine the list of schedules they use.
      space_type.lights.each do |light|
        # Skip lights that don't have a schedule
        next if light.schedule.empty?
        lights_sch = light.schedule.get
        lights_schs[lights_sch.name.to_s] = lights_sch
        lights_sch_names << lights_sch.name.to_s
      end

      # Loop through the unique list of lighting schedules, cloning
      # and reducing schedule fraction before and after the specified times
      lights_sch_names.uniq.each do |lights_sch_name|
        lights_sch = lights_schs[lights_sch_name]
        # Skip non-ruleset schedules
        next if lights_sch.to_ScheduleRuleset.empty?

        # Clone the schedule (so that we don't mess with lights in
        # other space types that might be using the same schedule).
        new_lights_sch = lights_sch.clone(self).to_ScheduleRuleset.get
        new_lights_sch.setName("#{lights_sch_name} OccSensor Reduction")
        reduced_lights_schs[lights_sch_name] = new_lights_sch

        # Reduce default day schedule
        multiply_schedule(new_lights_sch.defaultDaySchedule, red_multiplier, 0.25)

        # Reduce all other rule schedules
        new_lights_sch.scheduleRules.each do |sch_rule|
          multiply_schedule(sch_rule.daySchedule, red_multiplier, 0.25)
        end
      end # end of lights_sch_names.uniq.each do

      # Loop through all lights instances, replacing old lights
      # schedules with the reduced schedules.
      space_type.lights.each do |light|
        # Skip lights that don't have a schedule
        next if light.schedule.empty?
        old_lights_sch_name = light.schedule.get.name.to_s
        if reduced_lights_schs[old_lights_sch_name]
          light.setSchedule(reduced_lights_schs[old_lights_sch_name])
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Occupancy sensor reduction added to '#{light.name}'")
        end
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished Adding Occupancy Sensors')

    return true
  end

  # add occupancy sensors

  # Adds exterior lights to the building, as specified
  # in OpenStudio_Standards_prototype_inputs
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  # @todo translate w/linear foot of facade, door, parking, etc
  #   into lookup table and implement that way instead of hard-coding as
  #   inputs in the spreadsheet.
  def add_exterior_lights(building_type, template, climate_zone, prototype_input)
    # TODO: Standards - translate w/linear foot of facade, door, parking, etc
    # into lookup table and implement that way instead of hard-coding as
    # inputs in the spreadsheet.
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started adding exterior lights')

    # Occupancy Sensing Exterior Lights
    # which reduce to 70% power when no one is around.
    unless prototype_input['occ_sensing_exterior_lighting_power'].nil?
      occ_sens_ext_lts_power = prototype_input['occ_sensing_exterior_lighting_power']
      occ_sens_ext_lts_sch_name = prototype_input['occ_sensing_exterior_lighting_schedule']
      occ_sens_ext_lts_name = 'Occ Sensing Exterior Lights'
      occ_sens_ext_lts_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      occ_sens_ext_lts_def.setName("#{occ_sens_ext_lts_name} Def")
      occ_sens_ext_lts_def.setDesignLevel(occ_sens_ext_lts_power)
      occ_sens_ext_lts_sch = add_schedule(occ_sens_ext_lts_sch_name)
      occ_sens_ext_lts = OpenStudio::Model::ExteriorLights.new(occ_sens_ext_lts_def, occ_sens_ext_lts_sch)
      occ_sens_ext_lts.setName("#{occ_sens_ext_lts_name} Def")
      occ_sens_ext_lts.setControlOption('AstronomicalClock')
    end

    # Building Facade and Landscape Lights
    # that don't dim at all at night.
    unless prototype_input['nondimming_exterior_lighting_power'].nil?
      nondimming_ext_lts_power = prototype_input['nondimming_exterior_lighting_power']
      nondimming_ext_lts_sch_name = prototype_input['nondimming_exterior_lighting_schedule']
      nondimming_ext_lts_name = 'NonDimming Exterior Lights'
      nondimming_ext_lts_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      nondimming_ext_lts_def.setName("#{nondimming_ext_lts_name} Def")
      nondimming_ext_lts_def.setDesignLevel(nondimming_ext_lts_power)
      nondimming_ext_lts_sch = add_schedule(nondimming_ext_lts_sch_name)
      nondimming_ext_lts = OpenStudio::Model::ExteriorLights.new(nondimming_ext_lts_def, nondimming_ext_lts_sch)
      nondimming_ext_lts.setName("#{nondimming_ext_lts_name} Def")
      nondimming_ext_lts.setControlOption('AstronomicalClock')
    end

    # Fuel Equipment, As Exterior:FuelEquipment is not supported by OpenStudio yet,
    # temporarily use Exterior:Lights and set the control option to ScheduleNameOnly
    # todo: change it to Exterior:FuelEquipment when OpenStudio supported it.
    unless prototype_input['exterior_fuel_equipment1_power'].nil?
      fuel_ext_power = prototype_input['exterior_fuel_equipment1_power']
      fuel_ext_sch_name = prototype_input['exterior_fuel_equipment1_schedule']
      fuel_ext_name = 'Fuel equipment 1'
      fuel_ext_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      fuel_ext_def.setName("#{fuel_ext_name} Def")
      fuel_ext_def.setDesignLevel(fuel_ext_power)
      fuel_ext_sch = add_schedule(fuel_ext_sch_name)
      fuel_ext_lts = OpenStudio::Model::ExteriorLights.new(fuel_ext_def, fuel_ext_sch)
      fuel_ext_lts.setName(fuel_ext_name.to_s)
      fuel_ext_lts.setControlOption('ScheduleNameOnly')
    end

    unless prototype_input['exterior_fuel_equipment2_power'].nil?
      fuel_ext_power = prototype_input['exterior_fuel_equipment2_power']
      fuel_ext_sch_name = prototype_input['exterior_fuel_equipment2_schedule']
      fuel_ext_name = 'Fuel equipment 2'
      fuel_ext_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      fuel_ext_def.setName("#{fuel_ext_name} Def")
      fuel_ext_def.setDesignLevel(fuel_ext_power)
      fuel_ext_sch = add_schedule(fuel_ext_sch_name)
      fuel_ext_lts = OpenStudio::Model::ExteriorLights.new(fuel_ext_def, fuel_ext_sch)
      fuel_ext_lts.setName(fuel_ext_name.to_s)
      fuel_ext_lts.setControlOption('ScheduleNameOnly')
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding exterior lights')

    return true
  end

  # add exterior lights

  # Changes the infiltration coefficients for the prototype vintages.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  # @todo Consistency - make prototype and reference vintages consistent
  # @todo Add 90.1-2013?
  def modify_infiltration_coefficients(building_type, template, climate_zone)
    # Select the terrain type, which
    # impacts wind speed, and in turn infiltration
    terrain = 'City'
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        case building_type
          when 'Warehouse'
            terrain = 'Urban'
          when 'SmallHotel'
            terrain = 'Suburbs'
        end
    end
    # Set the terrain type
    getSite.setTerrain(terrain)

    # modify the infiltration coefficients for 90.1-2004, 90.1-2007, 90.1-2010, 90.1-2013
    return true unless template == '90.1-2004' || template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013' || template == 'NECB 2011'

    # The pre-1980 and 1980-2004 buildings have this:
    # 1.0000,                  !- Constant Term Coefficient
    # 0.0000,                  !- Temperature Term Coefficient
    # 0.0000,                  !- Velocity Term Coefficient
    # 0.0000;                  !- Velocity Squared Term Coefficient
    # The 90.1-2010 buildings have this:
    # 0.0000,                  !- Constant Term Coefficient
    # 0.0000,                  !- Temperature Term Coefficient
    # 0.224,                   !- Velocity Term Coefficient
    # 0.0000;                  !- Velocity Squared Term Coefficient
    getSpaceInfiltrationDesignFlowRates.each do |infiltration|
      infiltration.setConstantTermCoefficient(0.0)
      infiltration.setTemperatureTermCoefficient(0.0)
      infiltration.setVelocityTermCoefficient(0.224)
      infiltration.setVelocitySquaredTermCoefficient(0.0)
    end
  end

  # Sets the inside and outside convection algorithms for different vintages
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  # @todo Consistency - make prototype and reference vintages consistent
  def modify_surface_convection_algorithm(template)
    inside = getInsideSurfaceConvectionAlgorithm
    outside = getOutsideSurfaceConvectionAlgorithm

    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        inside.setAlgorithm('TARP')
        outside.setAlgorithm('DOE-2')
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        inside.setAlgorithm('TARP')
        outside.setAlgorithm('TARP')
    end
  end

  # Changes the infiltration coefficients for the prototype vintages.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  # @todo Consistency - make sizing factors consistent
  #   between building types, climate zones, and vintages?
  def apply_sizing_parameters(building_type, template)
    # Default unless otherwise specified
    clg = 1.2
    htg = 1.2
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        case building_type
          when 'PrimarySchool', 'SecondarySchool', 'Outpatient'
            clg = 1.5
            htg = 1.5
          when 'LargeHotel'
            clg = 1.33
            htg = 1.33
        end
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        case building_type
          when 'Hospital', 'LargeHotel', 'MediumOffice', 'LargeOffice', 'Outpatient', 'PrimarySchool'
            clg = 1.0
            htg = 1.0
        end
      when 'NECB 2011'
        clg = 1.3
        htg = 1.3
    end

    sizing_params = getSizingParameters
    sizing_params.setHeatingSizingFactor(htg)
    sizing_params.setCoolingSizingFactor(clg)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Set sizing factors to #{htg} for heating and #{clg} for cooling.")
  end

  def apply_prototype_hvac_assumptions(building_type, template, climate_zone)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying prototype HVAC assumptions.')

    ##### Apply equipment efficiencies

    # Fans
    # Pressure Rise
    getFanConstantVolumes.sort.each {|obj| obj.apply_prototype_fan_pressure_rise(building_type, template, climate_zone)}
    getFanVariableVolumes.sort.each {|obj| obj.apply_prototype_fan_pressure_rise(building_type, template, climate_zone)}
    getFanOnOffs.sort.each {|obj| obj.apply_prototype_fan_pressure_rise(building_type, template, climate_zone)}
    getFanZoneExhausts.sort.each(&:apply_prototype_fan_pressure_rise)

    # Motor Efficiency
    getFanConstantVolumes.sort.each {|obj| obj.apply_prototype_fan_efficiency(template)}
    getFanVariableVolumes.sort.each {|obj| obj.apply_prototype_fan_efficiency(template)}
    getFanOnOffs.sort.each {|obj| obj.apply_prototype_fan_efficiency(template)}
    getFanZoneExhausts.sort.each {|obj| obj.apply_prototype_fan_efficiency(template)}

    ##### Add Economizers

    if template != 'NECB 2011'
      # Create an economizer maximum OA fraction of 70%
      # to reflect damper leakage per PNNL
      econ_max_70_pct_oa_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      econ_max_70_pct_oa_sch.setName('Economizer Max OA Fraction 70 pct')
      econ_max_70_pct_oa_sch.defaultDaySchedule.setName('Economizer Max OA Fraction 70 pct Default')
      econ_max_70_pct_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.7)
    else
      # NECB 2011 prescribes ability to provide 100% OA (5.2.2.7-5.2.2.9)
      econ_max_100_pct_oa_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      econ_max_100_pct_oa_sch.setName('Economizer Max OA Fraction 100 pct')
      econ_max_100_pct_oa_sch.defaultDaySchedule.setName('Economizer Max OA Fraction 100 pct Default')
      econ_max_100_pct_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1.0)
    end

    # Check each airloop
    getAirLoopHVACs.each do |air_loop|
      if air_loop.economizer_required?(template, climate_zone) == true
        # If an economizer is required, determine the economizer type
        # in the prototype buildings, which depends on climate zone.
        economizer_type = nil
        case template
          when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
            economizer_type = 'DifferentialDryBulb'
          when '90.1-2010', '90.1-2013'
            case climate_zone
              when 'ASHRAE 169-2006-1A',
                  'ASHRAE 169-2006-2A',
                  'ASHRAE 169-2006-3A',
                  'ASHRAE 169-2006-4A'
                economizer_type = 'DifferentialEnthalpy'
              else
                economizer_type = 'DifferentialDryBulb'
            end
          when 'NECB 2011'
            # NECB 5.2.2.8 states that economizer can be controlled based on difference betweeen
            # return air temperature and outside air temperature OR return air enthalpy
            # and outside air enthalphy; latter chosen to be consistent with MNECB and CAN-QUEST implementation
            economizer_type = 'DifferentialEnthalpy'
        end

        # Set the economizer type
        # Get the OA system and OA controller
        oa_sys = air_loop.airLoopHVACOutdoorAirSystem
        if oa_sys.is_initialized
          oa_sys = oa_sys.get
        else
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.Model', "#{air_loop.name} is required to have an economizer, but it has no OA system.")
          next
        end
        oa_control = oa_sys.getControllerOutdoorAir
        oa_control.setEconomizerControlType(economizer_type)
        if template != 'NECB 2011'
          # oa_control.setMaximumFractionofOutdoorAirSchedule(econ_max_70_pct_oa_sch)
        end

        # Check that the economizer type set by the prototypes
        # is not prohibited by code.  If it is, change to no economizer.
        unless air_loop.economizer_type_allowable?(template, climate_zone)
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.Model', "#{air_loop.name} is required to have an economizer, but the type chosen, #{economizer_type} is prohibited by code for #{template}, climate zone #{climate_zone}.  Economizer type will be switched to No Economizer.")
          oa_control.setEconomizerControlType('NoEconomizer')
        end

      end
    end

    # TODO: What is the logic behind hard-sizing
    # hot water coil convergence tolerances?
    getControllerWaterCoils.sort.each(&:set_convergence_limits)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying prototype HVAC assumptions.')
  end

  def add_debugging_variables(type)
    # 'detailed'
    # 'timestep'
    # 'hourly'
    # 'daily'
    # 'monthly'

    vars = []
    case type
      when 'service_water_heating'
        var_names << ['Water Heater Water Volume Flow Rate', 'timestep']
        var_names << ['Water Use Equipment Hot Water Volume Flow Rate', 'timestep']
        var_names << ['Water Use Equipment Cold Water Volume Flow Rate', 'timestep']
        var_names << ['Water Use Equipment Hot Water Temperature', 'timestep']
        var_names << ['Water Use Equipment Cold Water Temperature', 'timestep']
        var_names << ['Water Use Equipment Mains Water Volume', 'timestep']
        var_names << ['Water Use Equipment Target Water Temperature', 'timestep']
        var_names << ['Water Use Equipment Mixed Water Temperature', 'timestep']
        var_names << ['Water Heater Tank Temperature', 'timestep']
        var_names << ['Water Heater Use Side Mass Flow Rate', 'timestep']
        var_names << ['Water Heater Heating Rate', 'timestep']
        var_names << ['Water Heater Water Volume Flow Rate', 'timestep']
        var_names << ['Water Heater Water Volume', 'timestep']
    end

    var_names.each do |var_name, reporting_frequency|
      output_var = OpenStudio::Model::OutputVariable.new(var_name, self)
      output_var.setReportingFrequency(reporting_frequency)
    end
  end

  def run(run_dir = "#{Dir.pwd}/Run")
    # If the run directory is not specified
    # run in the current working directory

    # Make the directory if it doesn't exist
    unless Dir.exist?(run_dir)
      Dir.mkdir(run_dir)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Started simulation in '#{run_dir}'")

    # Change the simulation to only run the weather file
    # and not run the sizing day simulations
    sim_control = getSimulationControl
    sim_control.setRunSimulationforSizingPeriods(false)
    sim_control.setRunSimulationforWeatherFileRunPeriods(true)

    # Save the model to energyplus idf
    idf_name = 'in.idf'
    osm_name = 'in.osm'
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(self)
    idf_path = OpenStudio::Path.new("#{run_dir}/#{idf_name}")
    osm_path = OpenStudio::Path.new("#{run_dir}/#{osm_name}")
    idf.save(idf_path, true)
    save(osm_path, true)

    # Set up the sizing simulation
    # Find the weather file
    epw_path = nil
    if weatherFile.is_initialized
      epw_path = weatherFile.get.path
      if epw_path.is_initialized
        if File.exist?(epw_path.get.to_s)
          epw_path = epw_path.get
        else
          # If this is an always-run Measure, need to check a different path
          alt_weath_path = File.expand_path(File.join(File.dirname(__FILE__), '../../../resources'))
          alt_epw_path = File.expand_path(File.join(alt_weath_path, epw_path.get.to_s))
          if File.exist?(alt_epw_path)
            epw_path = OpenStudio::Path.new(alt_epw_path)
          else
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.Model', "Model has been assigned a weather file, but the file is not in the specified location of '#{epw_path.get}'.")
            return false
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.Model', 'Model has a weather file assigned, but the weather file path has been deleted.')
        return false
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.Model', 'Model has not been assigned a weather file.3')
      return false
    end

    # If running on a regular desktop, use RunManager.
    # If running on OpenStudio Server, use WorkFlowMananger
    # to avoid slowdown from the sizing run.
    use_runmanager = true

    begin
      require 'openstudio-workflow'
      use_runmanager = false
    rescue LoadError
      use_runmanager = true
    end

    sql_path = nil
    if use_runmanager == true
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', 'Running sizing run with RunManager.')

      # Find EnergyPlus
      ep_dir = OpenStudio.getEnergyPlusDirectory
      ep_path = OpenStudio.getEnergyPlusExecutable
      ep_tool = OpenStudio::Runmanager::ToolInfo.new(ep_path)
      idd_path = OpenStudio::Path.new(ep_dir.to_s + '/Energy+.idd')
      output_path = OpenStudio::Path.new("#{run_dir}/")

      # Make a run manager and queue up the sizing run
      run_manager_db_path = OpenStudio::Path.new("#{run_dir}/run.db")
      run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_db_path, true, false, false, false)
      job = OpenStudio::Runmanager::JobFactory.createEnergyPlusJob(ep_tool,
                                                                   idd_path,
                                                                   idf_path,
                                                                   epw_path,
                                                                   output_path)

      run_manager.enqueue(job, true)

      # Start the sizing run and wait for it to finish.
      while run_manager.workPending
        sleep 1
        OpenStudio::Application.instance.processEvents
      end

      sql_path = OpenStudio::Path.new("#{run_dir}/Energyplus/eplusout.sql")

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Finished sizing run in #{(Time.new - start_time).round}sec.")

    else # Use the openstudio-workflow gem
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', 'Running sizing run with openstudio-workflow gem.')

      # Copy the weather file to this directory
      FileUtils.copy(epw_path.to_s, run_dir)

      # Run the simulation
      sim = OpenStudio::Workflow.run_energyplus('Local', run_dir)
      final_state = sim.run

      if final_state == :finished
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Finished sizing run in #{(Time.new - start_time).round}sec.")
      end

      sql_path = OpenStudio::Path.new("#{run_dir}/run/eplusout.sql")

    end

    # Load the sql file created by the sizing run
    sql_path = OpenStudio::Path.new("#{run_dir}/Energyplus/eplusout.sql")
    if OpenStudio.exists(sql_path)
      sql = OpenStudio::SqlFile.new(sql_path)
      # Check to make sure the sql file is readable,
      # which won't be true if EnergyPlus crashed during simulation.
      unless sql.connectionOpen
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed.  Look at the eplusout.err file in #{File.dirname(sql_path.to_s)} to see the cause.")
        return false
      end
      # Attach the sql file from the run to the sizing model
      setSqlFile(sql)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Results for the sizing run couldn't be found here: #{sql_path}.")
      return false
    end

    # Check that the run finished without severe errors
    error_query = "SELECT ErrorMessage
        FROM Errors
        WHERE ErrorType='1'"

    errs = sqlFile.get.execAndReturnVectorOfString(error_query)
    if errs.is_initialized
      errs = errs.get
      unless errs.empty?
        errs = errs.get
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed with the following severe errors: #{errs.join('\n')}.")
        return false
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Finished simulation in '#{run_dir}'")

    return true
  end

  def request_timeseries_outputs
    # "detailed"
    # "timestep"
    # "hourly"
    # "daily"
    # "monthly"

    vars = []
    # vars << ['Heating Coil Gas Rate', 'detailed']
    # vars << ['Zone Thermostat Air Temperature', 'detailed']
    # vars << ['Zone Thermostat Heating Setpoint Temperature', 'detailed']
    # vars << ['Zone Thermostat Cooling Setpoint Temperature', 'detailed']
    # vars << ['Zone Air System Sensible Heating Rate', 'detailed']
    # vars << ['Zone Air System Sensible Cooling Rate', 'detailed']
    # vars << ['Fan Electric Power', 'detailed']
    # vars << ['Zone Mechanical Ventilation Standard Density Volume Flow Rate', 'detailed']
    # vars << ['Air System Outdoor Air Mass Flow Rate', 'detailed']
    # vars << ['Air System Outdoor Air Flow Fraction', 'detailed']
    # vars << ['Air System Outdoor Air Minimum Flow Fraction', 'detailed']

    # vars << ['Water Use Equipment Hot Water Volume Flow Rate', 'hourly']
    # vars << ['Water Use Equipment Cold Water Volume Flow Rate', 'hourly']
    # vars << ['Water Use Equipment Total Volume Flow Rate', 'hourly']
    # vars << ['Water Use Equipment Hot Water Temperature', 'hourly']
    # vars << ['Water Use Equipment Cold Water Temperature', 'hourly']
    # vars << ['Water Use Equipment Target Water Temperature', 'hourly']
    # vars << ['Water Use Equipment Mixed Water Temperature', 'hourly']

    # vars << ['Water Use Connections Hot Water Volume Flow Rate', 'hourly']
    # vars << ['Water Use Connections Cold Water Volume Flow Rate', 'hourly']
    # vars << ['Water Use Connections Total Volume Flow Rate', 'hourly']
    # vars << ['Water Use Connections Hot Water Temperature', 'hourly']
    # vars << ['Water Use Connections Cold Water Temperature', 'hourly']
    # vars << ['Water Use Connections Plant Hot Water Energy', 'hourly']
    # vars << ['Water Use Connections Return Water Temperature', 'hourly']

    # vars << ['Air System Outdoor Air Economizer Status','timestep']
    # vars << ['Air System Outdoor Air Heat Recovery Bypass Status','timestep']
    # vars << ['Air System Outdoor Air High Humidity Control Status','timestep']
    # vars << ['Air System Outdoor Air Flow Fraction','timestep']
    # vars << ['Air System Outdoor Air Minimum Flow Fraction','timestep']
    # vars << ['Air System Outdoor Air Mass Flow Rate','timestep']
    # vars << ['Air System Mixed Air Mass Flow Rate','timestep']

    # vars << ['Heating Coil Gas Rate','timestep']
    vars << ['Boiler Part Load Ratio', 'timestep']
    vars << ['Boiler Gas Rate', 'timestep']
    # vars << ['Boiler Gas Rate','timestep']
    # vars << ['Fan Electric Power','timestep']

    vars << ['Pump Electric Power', 'timestep']
    vars << ['Pump Outlet Temperature', 'timestep']
    vars << ['Pump Mass Flow Rate', 'timestep']

    # vars << ['Zone Air Terminal VAV Damper Position','timestep']
    # vars << ['Zone Air Terminal Minimum Air Flow Fraction','timestep']
    # vars << ['Zone Air Terminal Outdoor Air Volume Flow Rate','timestep']
    # vars << ['Zone Lights Electric Power','hourly']
    # vars << ['Daylighting Lighting Power Multiplier','hourly']
    # vars << ['Schedule Value','hourly']

    vars.each do |var, freq|
      output_var = OpenStudio::Model::OutputVariable.new(var, self)
      output_var.setReportingFrequency(freq)
    end
  end

  def clear_and_set_example_constructions
    # Define Materials
    name = 'opaque material'
    thickness = 0.012700
    conductivity = 0.160000
    opaque_mat = BTAP::Resources::Envelope::Materials::Opaque.create_opaque_material(self, name, thickness, conductivity)

    name = 'insulation material'
    thickness = 0.050000
    conductivity = 0.043000
    insulation_mat = BTAP::Resources::Envelope::Materials::Opaque.create_opaque_material(self, name, thickness, conductivity)

    name = 'simple glazing test'
    shgc = 0.250000
    ufactor = 3.236460
    thickness = 0.003000
    visible_transmittance = 0.160000
    simple_glazing_mat = BTAP::Resources::Envelope::Materials::Fenestration.create_simple_glazing(self, name, shgc, ufactor, thickness, visible_transmittance)

    name = 'Standard Glazing Test'
    thickness = 0.003
    conductivity = 0.9
    solar_trans_normal = 0.84
    front_solar_ref_normal = 0.075
    back_solar_ref_normal = 0.075
    vlt = 0.9
    front_vis_ref_normal = 0.081
    back_vis_ref_normal = 0.081
    ir_trans_normal = 0.0
    front_ir_emis = 0.84
    back_ir_emis = 0.84
    optical_data_type = 'SpectralAverage'
    dirt_correction_factor = 1.0
    is_solar_diffusing = false

    standard_glazing_mat = BTAP::Resources::Envelope::Materials::Fenestration.create_standard_glazing(self,
                                                                                                      name,
                                                                                                      thickness,
                                                                                                      conductivity,
                                                                                                      solar_trans_normal,
                                                                                                      front_solar_ref_normal,
                                                                                                      back_solar_ref_normal, vlt,
                                                                                                      front_vis_ref_normal,
                                                                                                      back_vis_ref_normal,
                                                                                                      ir_trans_normal,
                                                                                                      front_ir_emis,
                                                                                                      back_ir_emis,
                                                                                                      optical_data_type,
                                                                                                      dirt_correction_factor,
                                                                                                      is_solar_diffusing)

    # Define Constructions
    # # Surfaces
    ext_wall = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionExtWall', [opaque_mat, insulation_mat], insulation_mat)
    ext_roof = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionExtRoof', [opaque_mat, insulation_mat], insulation_mat)
    ext_floor = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionExtFloor', [opaque_mat, insulation_mat], insulation_mat)
    grnd_wall = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionGrndWall', [opaque_mat, insulation_mat], insulation_mat)
    grnd_roof = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionGrndRoof', [opaque_mat, insulation_mat], insulation_mat)
    grnd_floor = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionGrndFloor', [opaque_mat, insulation_mat], insulation_mat)
    int_wall = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionIntWall', [opaque_mat, insulation_mat], insulation_mat)
    int_roof = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionIntRoof', [opaque_mat, insulation_mat], insulation_mat)
    int_floor = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionIntFloor', [opaque_mat, insulation_mat], insulation_mat)
    # # Subsurfaces
    fixed_window = BTAP::Resources::Envelope::Constructions.create_construction(self, 'FenestrationConstructionFixed', [simple_glazing_mat])
    operable_window = BTAP::Resources::Envelope::Constructions.create_construction(self, 'FenestrationConstructionOperable', [simple_glazing_mat])
    glass_door = BTAP::Resources::Envelope::Constructions.create_construction(self, 'FenestrationConstructionDoor', [standard_glazing_mat])
    door = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionDoor', [opaque_mat, insulation_mat], insulation_mat)
    overhead_door = BTAP::Resources::Envelope::Constructions.create_construction(self, 'OpaqueConstructionOverheadDoor', [opaque_mat, insulation_mat], insulation_mat)
    skylt = BTAP::Resources::Envelope::Constructions.create_construction(self, 'FenestrationConstructionSkylight', [standard_glazing_mat])
    daylt_dome = BTAP::Resources::Envelope::Constructions.create_construction(self, 'FenestrationConstructionDomeConstruction', [standard_glazing_mat])
    daylt_diffuser = BTAP::Resources::Envelope::Constructions.create_construction(self, 'FenestrationConstructionDiffuserConstruction', [standard_glazing_mat])

    # Define Construction Sets
    # # Surface
    exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_surface_constructions(self, 'ExteriorSet', ext_wall, ext_roof, ext_floor)
    interior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_surface_constructions(self, 'InteriorSet', int_wall, int_roof, int_floor)
    ground_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_surface_constructions(self, 'GroundSet', grnd_wall, grnd_roof, grnd_floor)

    # # Subsurface
    subsurface_exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_subsurface_construction_set(self, fixed_window, operable_window, door, glass_door, overhead_door, skylt, daylt_dome, daylt_diffuser)
    subsurface_interior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_subsurface_construction_set(self, fixed_window, operable_window, door, glass_door, overhead_door, skylt, daylt_dome, daylt_diffuser)

    # Define default construction sets.
    name = 'Construction Set 1'
    default_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_construction_set(self, name, exterior_construction_set, interior_construction_set, ground_construction_set, subsurface_exterior_construction_set, subsurface_interior_construction_set)

    # Assign default to the model.
    getBuilding.setDefaultConstructionSet(default_construction_set)

    return default_construction_set
  end

  private

  # Method to multiply the values in a day schedule by a specified value
  # but only when the existing value is higher than a specified lower limit.
  # This limit prevents occupancy sensors from affecting unoccupied hours.
  def multiply_schedule(day_sch, multiplier, limit)
    # Record the original times and values
    times = day_sch.times
    values = day_sch.values

    # Remove the original times and values
    day_sch.clearValues

    # Create new values by using the multiplier on the original values
    new_values = []
    values.each do |value|
      new_values << if value > limit
                      value * multiplier
                    else
                      value
                    end
    end

    # Add the revised time/value pairs to the schedule
    new_values.each_with_index do |new_value, i|
      day_sch.addValue(times[i], new_value)
    end
  end

  # end reduce schedule

  def initialize()
    super()
    @standard = nil
  end

  def apply_standard(model)
    replace_model(proposed)
    check_weatherfile_is_valid()
    check_geometry()
    check_standard_space_types()
    check_spaces()
    #Apply Standard.
    standards_apply_loads()
    standards_apply_envelope()
    standards_apply_hvac()
    standards_apply_plant_and_shw()
    validation()
    return self
  end

  def generate_standard_prototype(building_type: :LargeOffice)
    extend const_get(type.capitalize)
    @building_type = building_type
    @epw_file = epw_file
    @climate_zone = climate_zone
    assign_climate()
    create_geometry()
    create_standard_spacetypes_to_spaces()
    #conductances will be set later.
    create_construction()
    create_standard_loads()
    create_standard_envelope()
    create_standard_hvac()
    create_standards_plant_and_shw()
    apply_reference_standard(self)
  end
end


module LargeOffice
  def supported_standards()
    return ['NECB 2011', 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']
  end

  def create_geometry()
    super()
  end

  def create_standard_spacetypes_to_spaces()
    # Uses lookup table
    super()
  end

  def create_standard_loads()
    super()
  end

  def create_standard_envelope()
    super()
  end

  def create_standard_hvac()
    super()
  end

  def create_standards_plant_and_shw()
    super()
  end


  def self.define_space_type_map(building_type, template, climate_zone)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        space_type_map = {
            'WholeBuilding - Lg Office' => [
                'Basement', 'Core_bottom', 'Core_mid', 'Core_top', # 'GroundFloor_Plenum', 'MidFloor_Plenum', 'TopFloor_Plenum',
                'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4',
                'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4',
                'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4'
            ]
        }
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        space_type_map = {
            'WholeBuilding - Lg Office' => [
                'Basement', 'Core_bottom', 'Core_mid', 'Core_top', # 'GroundFloor_Plenum', 'MidFloor_Plenum', 'TopFloor_Plenum',
                'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4',
                'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4',
                'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4'
            ],
            'OfficeLarge Data Center' => ['DataCenter_bot_ZN_6', 'DataCenter_mid_ZN_6', 'DataCenter_top_ZN_6'],
            'OfficeLarge Main Data Center' => [
                'DataCenter_basement_ZN_6'
            ]
        }
      when 'NECB 2011'
        # Dom is A
        space_type_map = {
            'Electrical/Mechanical-sch-A' => ['Basement'],

            'Office - open plan' => ['Core_bottom', 'Core_mid', 'Core_top', 'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'DataCenter_basement_ZN_6', 'DataCenter_bot_ZN_6', 'DataCenter_mid_ZN_6', 'DataCenter_top_ZN_6'],
            '- undefined -' => ['GroundFloor_Plenum', 'TopFloor_Plenum', 'MidFloor_Plenum']
        }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        system_to_space_map = [
            {
                'type' => 'VAV',
                'name' => 'VAV_1',
                'space_names' =>
                    ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom'],
                'return_plenum' => 'GroundFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_2',
                'space_names' =>
                    ['Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid'],
                'return_plenum' => 'MidFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_3',
                'space_names' =>
                    ['Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'],
                'return_plenum' => 'TopFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_5',
                'space_names' =>
                    [
                        'Basement'
                    ]
            }
        ]
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        system_to_space_map = [
            {
                'type' => 'VAV',
                'name' => 'VAV_bot WITH REHEAT',
                'space_names' =>
                    ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom'],
                'return_plenum' => 'GroundFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_mid WITH REHEAT',
                'space_names' =>
                    ['Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid'],
                'return_plenum' => 'MidFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_top WITH REHEAT',
                'space_names' =>
                    ['Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'],
                'return_plenum' => 'TopFloor_Plenum'
            },
            {

                'type' => 'CAV',
                'name' => 'CAV_bas',
                'space_names' =>
                    [
                        'Basement'
                    ]
            },
            {
                'type' => 'DC',
                'space_names' =>
                    [
                        'DataCenter_basement_ZN_6'
                    ],
                'load' => 484.423246742185,
                'main_data_center' => true
            },
            {
                'type' => 'DC',
                'space_names' =>
                    [
                        'DataCenter_bot_ZN_6'
                    ],
                'load' => 215.299220774304,
                'main_data_center' => false
            },
            {
                'type' => 'DC',
                'space_names' =>
                    [
                        'DataCenter_mid_ZN_6'
                    ],
                'load' => 215.299220774304,
                'main_data_center' => false
            },
            {
                'type' => 'DC',
                'space_names' =>
                    [
                        'DataCenter_top_ZN_6'
                    ],
                'load' => 215.299220774304,
                'main_data_center' => false
            }
        ]

    end

    return system_to_space_map
  end

  def self.define_space_multiplier
    building_type = 'LargeOffice'
    # This map define the multipliers for spaces with multipliers not equals to 1
    space_multiplier_map = JSON.parse(File.read(File.join(File.dirname(__FILE__), "../../../data/geometry/archetypes/#{building_type}.json")))[building_type]['space_multiplier_map']
    return space_multiplier_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    system_to_space_map = define_hvac_system_map(building_type, template, climate_zone)

    system_to_space_map.each do |system|
      # find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = model.getSpaceByName(space_name)
        if space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
          return false
        end
        thermal_zones << zone.get
      end

      return_plenum = nil
      unless system['return_plenum'].nil?
        return_plenum_space = model.getSpaceByName(system['return_plenum'])
        if return_plenum_space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model")
          return false
        end
        return_plenum_space = return_plenum_space.get
        return_plenum = return_plenum_space.thermalZone
        if return_plenum.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{system['return_plenum']}")
          return false
        end
        return_plenum = return_plenum.get
      end
    end

    return true
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(11.25413987)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(11.25413987)
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::LargeOffice.update_waterheater_loss_coefficient(template, model)
    return true
  end
end
module FullServiceRestaurant
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
      when 'DOE Ref Pre-1980'
        space_type_map = {
            'Dining' => ['Dining'],
            'Kitchen' => ['Kitchen']
        }
      when 'DOE Ref 1980-2004', '90.1-2010', '90.1-2007', '90.1-2004', '90.1-2013'
        space_type_map = {
            'Dining' => ['Dining'],
            'Kitchen' => ['Kitchen'],
            'Attic' => ['attic']
        }

      when 'NECB 2011'
        space_type_map = {
            '- undefined -' => ['attic'],
            'Dining - family space' => ['Dining'],
            'Food preparation' => ['Kitchen']
        }
    end

    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 1.828,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 0.06,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 74,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'FullServiceRestaurant Bldg Light',
                'defrost_pwr_per_length' => 820,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 66,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'FullServiceRestaurant Bldg Light',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]
      when '90.1-2004'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 2.644,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 2.83169,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 74,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
                'defrost_pwr_per_length' => 820,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 66,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]
      when '90.1-2007'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 1.331432,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 2.83169,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 74,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
                'defrost_pwr_per_length' => 820,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 66,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]
      when '90.1-2007'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 1.331432,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 2.83169,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 74,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
                'defrost_pwr_per_length' => 820,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 66,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]
      when '90.1-2010'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 1.331432,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 2.548516,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 74,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
                'defrost_pwr_per_length' => 820,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 66,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'RestaurantSitDown BLDG_LIGHT_KITCHEN_SCH_2004_2007',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]
      when '90.1-2013'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 1.331432,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantSitDown HVACOperationSchd',
                'flow_rate' => 2.548516,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 21.14286,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'RestaurantSitDown walkin_occ_lght_SCH',
                'defrost_pwr_per_length' => 820,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 18.85714,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'RestaurantSitDown walkin_occ_lght_SCH',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantSitDown Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]

    end

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add extra equipment for kitchen
    PrototypeBuilding::FullServiceRestaurant.add_extra_equip_kitchen(template, model)
    # add extra infiltration for dining room door and attic
    PrototypeBuilding::FullServiceRestaurant.add_door_infiltration(template, climate_zone, model)
    # add zone_mixing between kitchen and dining
    PrototypeBuilding::FullServiceRestaurant.add_zone_mixing(template, model)
    # Update Sizing Zone
    PrototypeBuilding::FullServiceRestaurant.update_sizing_zone(template, model)
    # adjust the cooling setpoint
    PrototypeBuilding::FullServiceRestaurant.adjust_clg_setpoint(template, climate_zone, model)
    # reset the design OA of kitchen
    PrototypeBuilding::FullServiceRestaurant.reset_kitchen_oa(template, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end # add hvac

  def self.add_door_infiltration(template, climate_zone, model)
    # add extra infiltration for dining room door and attic (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980' || template == 'NECB 2011'
      dining_space = model.getSpaceByName('Dining').get
      attic_space = model.getSpaceByName('Attic').get
      infiltration_diningdoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_attic = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_diningdoor.setName('Dining door Infiltration')
      infiltration_per_zone_diningdoor = 0
      infiltration_per_zone_attic = 0.2378
      if template == '90.1-2004'
        infiltration_per_zone_diningdoor = 0.614474994
        infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown DOOR_INFIL_SCH'))
      elsif template == '90.1-2007'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B',
              'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C'
            infiltration_per_zone_diningdoor = 0.614474994
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.389828222
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown VESTIBULE_DOOR_INFIL_SCH'))
        end
      elsif template == '90.1-2010' || template == '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C'
            infiltration_per_zone_diningdoor = 0.614474994
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.389828222
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantSitDown VESTIBULE_DOOR_INFIL_SCH'))
        end
      end
      infiltration_diningdoor.setDesignFlowRate(infiltration_per_zone_diningdoor)
      infiltration_diningdoor.setSpace(dining_space)
      infiltration_attic.setDesignFlowRate(infiltration_per_zone_attic)
      infiltration_attic.setSchedule(model.add_schedule('Always On'))
      infiltration_attic.setSpace(attic_space)
    end
  end

  def self.update_exhaust_fan_efficiency(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          fan_name = exhaust_fan.name.to_s
          if fan_name.include? 'Dining'
            exhaust_fan.setFanEfficiency(1)
            exhaust_fan.setPressureRise(0)
          end
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(1)
          exhaust_fan.setPressureRise(0.000001)
        end
    end
  end

  def self.add_zone_mixing(template, model)
    # add zone_mixing between kitchen and dining
    space_kitchen = model.getSpaceByName('Kitchen').get
    zone_kitchen = space_kitchen.thermalZone.get
    space_dining = model.getSpaceByName('Dining').get
    zone_dining = space_dining.thermalZone.get
    zone_mixing_kitchen = OpenStudio::Model::ZoneMixing.new(zone_kitchen)
    zone_mixing_kitchen.setSchedule(model.add_schedule('RestaurantSitDown Hours_of_operation'))
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        zone_mixing_kitchen.setDesignFlowRate(1.828)
      when '90.1-2007', '90.1-2010', '90.1-2013'
        zone_mixing_kitchen.setDesignFlowRate(1.33143208)
      when '90.1-2004'
        zone_mixing_kitchen.setDesignFlowRate(2.64397817)
    end
    zone_mixing_kitchen.setSourceZone(zone_dining)
    zone_mixing_kitchen.setDeltaTemperature(0)
  end

  # add extra equipment for kitchen
  def self.add_extra_equip_kitchen(template, model)
    kitchen_space = model.getSpaceByName('Kitchen')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(457.5)
          elec_equip_def2.setDesignLevel(570)
        else
          elec_equip_def1.setDesignLevel(515.917)
          elec_equip_def2.setDesignLevel(851.67)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('RestaurantSitDown ALWAYS_ON'))
        elec_equip2.setSchedule(model.add_schedule('RestaurantSitDown ALWAYS_ON'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip_def1.setDesignLevel(699)
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(1)
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip1.setName('Kitchen_ExhFan_Equip')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('RestaurantSitDown Kitchen_Exhaust_SCH'))
    end
  end

  def self.update_sizing_zone(template, model)
    case template
      when '90.1-2007', '90.1-2010', '90.1-2013'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.003581176)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
      when '90.1-2004'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.007111554)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
    end
  end

  def self.adjust_clg_setpoint(template, climate_zone, model)
    ['Dining', 'Kitchen'].each do |space_name|
      space_type_name = model.getSpaceByName(space_name).get.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010'
          if climate_zone == 'ASHRAE 169-2006-2B' || climate_zone == 'ASHRAE 169-2006-1B' || climate_zone == 'ASHRAE 169-2006-3B'
            case space_name
              when 'Dining'
                thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('RestaurantSitDown CLGSETP_SCH_NO_OPTIMUM'))
              when 'Kitchen'
                thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('RestaurantSitDown CLGSETP_KITCHEN_SCH_NO_OPTIMUM'))
            end
          end
      end
    end
  end

  # In order to provide sufficient OSA to replace exhaust flow through kitchen hoods (3,300 cfm),
  # modeled OSA to kitchen is different from OSA determined based on ASHRAE  62.1.
  # It takes into account the available OSA in dining as transfer air.
  def self.reset_kitchen_oa(template, model)
    space_kitchen = model.getSpaceByName('Kitchen').get
    ventilation = space_kitchen.designSpecificationOutdoorAir.get
    ventilation.setOutdoorAirFlowperPerson(0)
    ventilation.setOutdoorAirFlowperFloorArea(0)
    case template
      when '90.1-2010', '90.1-2013'
        ventilation.setOutdoorAirFlowRate(1.21708392)
      when '90.1-2007'
        ventilation.setOutdoorAirFlowRate(1.50025792)
      when '90.1-2004'
        ventilation.setOutdoorAirFlowRate(1.87711831)
    end
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          if water_heater.name.to_s.include?('Booster')
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
          else
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(9.643286505)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(9.643286505)
          end
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::FullServiceRestaurant.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
module HighriseApartment
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template

      when 'NECB 2011'
        sch = 'G'
        space_type_map = {
            'Office - enclosed' => ['Office'],
            "Corr. < 2.4m wide-sch-#{sch}" => ['T Corridor', 'G Corridor', 'F2 Corridor', 'F3 Corridor', 'F4 Corridor', 'M Corridor', 'F6 Corridor', 'F7 Corridor', 'F8 Corridor', 'F9 Corridor'],
            'Dwelling Unit(s)' => [
                'G SW Apartment',
                'G NW Apartment',
                'G NE Apartment',
                'G N1 Apartment',
                'G N2 Apartment',
                'G S1 Apartment',
                'G S2 Apartment',
                'F2 SW Apartment',
                'F2 NW Apartment',
                'F2 SE Apartment',
                'F2 NE Apartment',
                'F2 N1 Apartment',
                'F2 N2 Apartment',
                'F2 S1 Apartment',
                'F2 S2 Apartment',
                'F3 SW Apartment',
                'F3 NW Apartment',
                'F3 SE Apartment',
                'F3 NE Apartment',
                'F3 N1 Apartment',
                'F3 N2 Apartment',
                'F3 S1 Apartment',
                'F3 S2 Apartment',
                'F4 SW Apartment',
                'F4 NW Apartment',
                'F4 SE Apartment',
                'F4 NE Apartment',
                'F4 N1 Apartment',
                'F4 N2 Apartment',
                'F4 S1 Apartment',
                'F4 S2 Apartment',
                'M SW Apartment',
                'M NW Apartment',
                'M SE Apartment',
                'M NE Apartment',
                'M N1 Apartment',
                'M N2 Apartment',
                'M S1 Apartment',
                'M S2 Apartment',
                'F6 SW Apartment',
                'F6 NW Apartment',
                'F6 SE Apartment',
                'F6 NE Apartment',
                'F6 N1 Apartment',
                'F6 N2 Apartment',
                'F6 S1 Apartment',
                'F6 S2 Apartment',
                'F7 SW Apartment',
                'F7 NW Apartment',
                'F7 SE Apartment',
                'F7 NE Apartment',
                'F7 N1 Apartment',
                'F7 N2 Apartment',
                'F7 S1 Apartment',
                'F7 S2 Apartment',
                'F8 SW Apartment',
                'F8 NW Apartment',
                'F8 SE Apartment',
                'F8 NE Apartment',
                'F8 N1 Apartment',
                'F8 N2 Apartment',
                'F8 S1 Apartment',
                'F8 S2 Apartment',
                'F9 SW Apartment',
                'F9 NW Apartment',
                'F9 SE Apartment',
                'F9 NE Apartment',
                'F9 N1 Apartment',
                'F9 N2 Apartment',
                'F9 S1 Apartment',
                'F9 S2 Apartment',
                'T SW Apartment',
                'T NW Apartment',
                'T SE Apartment',
                'T NE Apartment',
                'T N1 Apartment',
                'T N2 Apartment',
                'T S1 Apartment',
                'T S2 Apartment'
            ]
        }

      else
        space_type_map = {
            'Office' => ['Office'],
            'Corridor' => ['G Corridor', 'F2 Corridor', 'F3 Corridor', 'F4 Corridor', 'M Corridor', 'F6 Corridor', 'F7 Corridor', 'F8 Corridor', 'F9 Corridor'],
            'Corridor_topfloor' => ['T Corridor'],
            'Apartment' => [
                'G SW Apartment',
                'G NW Apartment',
                'G NE Apartment',
                'G N1 Apartment',
                'G N2 Apartment',
                'G S1 Apartment',
                'G S2 Apartment',
                'F2 SW Apartment',
                'F2 NW Apartment',
                'F2 SE Apartment',
                'F2 NE Apartment',
                'F2 N1 Apartment',
                'F2 N2 Apartment',
                'F2 S1 Apartment',
                'F2 S2 Apartment',
                'F3 SW Apartment',
                'F3 NW Apartment',
                'F3 SE Apartment',
                'F3 NE Apartment',
                'F3 N1 Apartment',
                'F3 N2 Apartment',
                'F3 S1 Apartment',
                'F3 S2 Apartment',
                'F4 SW Apartment',
                'F4 NW Apartment',
                'F4 SE Apartment',
                'F4 NE Apartment',
                'F4 N1 Apartment',
                'F4 N2 Apartment',
                'F4 S1 Apartment',
                'F4 S2 Apartment',
                'M SW Apartment',
                'M NW Apartment',
                'M SE Apartment',
                'M NE Apartment',
                'M N1 Apartment',
                'M N2 Apartment',
                'M S1 Apartment',
                'M S2 Apartment',
                'F6 SW Apartment',
                'F6 NW Apartment',
                'F6 SE Apartment',
                'F6 NE Apartment',
                'F6 N1 Apartment',
                'F6 N2 Apartment',
                'F6 S1 Apartment',
                'F6 S2 Apartment',
                'F7 SW Apartment',
                'F7 NW Apartment',
                'F7 SE Apartment',
                'F7 NE Apartment',
                'F7 N1 Apartment',
                'F7 N2 Apartment',
                'F7 S1 Apartment',
                'F7 S2 Apartment',
                'F8 SW Apartment',
                'F8 NW Apartment',
                'F8 SE Apartment',
                'F8 NE Apartment',
                'F8 N1 Apartment',
                'F8 N2 Apartment',
                'F8 S1 Apartment',
                'F8 S2 Apartment',
                'F9 SW Apartment',
                'F9 NW Apartment',
                'F9 SE Apartment',
                'F9 NE Apartment',
                'F9 N1 Apartment',
                'F9 N2 Apartment',
                'F9 S1 Apartment',
                'F9 S2 Apartment'
            ],
            'Apartment_topfloor_WE' => [
                'T SW Apartment',
                'T NW Apartment',
                'T SE Apartment',
                'T NE Apartment'
            ],
            'Apartment_topfloor_NS' => [
                'T N1 Apartment',
                'T N2 Apartment',
                'T S1 Apartment',
                'T S2 Apartment'
            ]
        }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
        { 'type' => 'PSZ-AC',
          'space_names' => ['G SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['G NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['G NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['G N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['G N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['G S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['G S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F2 SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F2 NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F2 SE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F2 NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F2 N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F2 N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F2 S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F2 S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F3 SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F3 NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F3 SE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F3 NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F3 N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F3 N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F3 S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F3 S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F4 SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F4 NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F4 SE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F4 NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F4 N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F4 N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F4 S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F4 S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['M SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['M NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['M SE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['M NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['M N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['M N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['M S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['M S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F6 SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F6 NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F6 SE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F6 NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F6 N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F6 N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F6 S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F6 S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F7 SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F7 NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F7 SE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F7 NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F7 N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F7 N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F7 S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F7 S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F8 SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F8 NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F8 SE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F8 NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F8 N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F8 N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F8 S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F8 S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F9 SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F9 NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F9 SE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F9 NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F9 N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F9 N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F9 S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['F9 S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['T SW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['T NW Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['T SE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['T NE Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['T N1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['T N2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['T S1 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['T S2 Apartment'] },
        { 'type' => 'PSZ-AC',
          'space_names' => ['Office'] }
    ]

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    # add elevator and lights&fans for the ground floor corridor
    PrototypeBuilding::HighriseApartment.add_extra_equip_corridor(template, model)
    # add extra infiltration for ground floor corridor
    PrototypeBuilding::HighriseApartment.add_door_infiltration(template, climate_zone, model)

    return true
  end # add hvac

  # add elevator and lights&fans for the top floor corridor
  def self.add_extra_equip_corridor(template, model)
    corridor_top_space = model.getSpaceByName('T Corridor').get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('T Corridor Electric Equipment Definition1')
    elec_equip_def2.setName('T Corridor Electric Equipment Definition2')
    elec_equip_def1.setFractionLatent(0)
    elec_equip_def1.setFractionRadiant(0)
    elec_equip_def1.setFractionLost(0.95)
    elec_equip_def2.setFractionLatent(0)
    elec_equip_def2.setFractionRadiant(0)
    elec_equip_def2.setFractionLost(0.95)
    elec_equip_def1.setDesignLevel(20_370)
    case template
      when '90.1-2013'
        elec_equip_def2.setDesignLevel(63)
      when '90.1-2010'
        elec_equip_def2.setDesignLevel(105.9)
      when '90.1-2004', '90.1-2007'
        elec_equip_def2.setDesignLevel(161.9)
    end
    # Create the electric equipment instance and hook it up to the space type
    elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
    elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
    elec_equip1.setName('T Corridor_Elevators_Equip')
    elec_equip2.setName('Elevators_Lights_Fan')
    elec_equip1.setSpace(corridor_top_space)
    elec_equip2.setSpace(corridor_top_space)
    elec_equip1.setSchedule(model.add_schedule('ApartmentMidRise BLDG_ELEVATORS'))
    case template
      when '90.1-2004', '90.1-2007'
        elec_equip2.setSchedule(model.add_schedule('ApartmentMidRise ELEV_LIGHT_FAN_SCH_24_7'))
      when '90.1-2010', '90.1-2013'
        elec_equip2.setSchedule(model.add_schedule('ApartmentMidRise ELEV_LIGHT_FAN_SCH_ADD_DF'))
    end
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(46.288874618)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(46.288874618)
        end
    end
  end

  # add extra infiltration for ground floor corridor
  def self.add_door_infiltration(template, climate_zone, model)
    g_corridor = model.getSpaceByName('G Corridor').get
    infiltration_g_corridor_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
    infiltration_g_corridor_door.setName('G Corridor door Infiltration')
    infiltration_g_corridor_door.setSpace(g_corridor)
    case template
      when '90.1-2004'
        infiltration_g_corridor_door.setDesignFlowRate(1.523916863)
        infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentHighRise INFIL_Door_Opening_SCH_0.144'))
      when '90.1-2007', '90.1-2010', '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
            infiltration_g_corridor_door.setDesignFlowRate(1.523916863)
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentHighRise INFIL_Door_Opening_SCH_0.144'))
          else
            infiltration_g_corridor_door.setDesignFlowRate(1.008078792)
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentHighRise INFIL_Door_Opening_SCH_0.131'))
        end
    end
  end

  def self.update_fan_efficiency(model)
    model.getFanOnOffs.sort.each do |fan_onoff|
      fan_onoff.setFanEfficiency(0.53625)
      fan_onoff.setMotorEfficiency(0.825)
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::HighriseApartment.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
module Hospital
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
      when 'NECB 2011'
        sch = 'B'
        space_type_map = {

            "Hospital corr. >= 2.4m-sch-#{sch}" => ['Corridor_Flr_1', 'Corridor_Flr_2', 'Corridor_Flr_5', 'Corridor_NW_Flr_3', 'Corridor_NW_Flr_4', 'Corridor_SE_Flr_3', 'Corridor_SE_Flr_4'],
            'Dining - bar lounge/leisure' => ['Dining_Flr_5'],
            'Hospital - emergency' => ['ER_Exam1_Mult4_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1'],
            "Hospital - nurses' station" => ['ER_NurseStn_Lobby_Flr_1', 'ICU_NurseStn_Lobby_Flr_2', 'NurseStn_Lobby_Flr_3', 'NurseStn_Lobby_Flr_4', 'NurseStn_Lobby_Flr_5', 'OR_NurseStn_Lobby_Flr_2'],
            'Hospital - patient room' => ['IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', 'PatRoom1_Mult10_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_3', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_3', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_3', 'PatRoom4_Flr_4', 'PatRoom5_Mult10_Flr_3', 'PatRoom5_Mult10_Flr_4', 'PatRoom6_Flr_3', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_3', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_3', 'PatRoom8_Flr_4'],
            'Hospital - recovery' => ['ICU_Flr_2'],
            'Food preparation' => ['Kitchen_Flr_5'],
            'Lab - research' => ['Lab_Flr_3', 'Lab_Flr_4','Basement'],
            'Office - enclosed' => ['Lobby_Records_Flr_1', 'Office1_Flr_5', 'Office1_Mult4_Flr_1', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5'],
            'Hospital - operating room' => ['OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2'],
            'Hospital - physical therapy' => ['PhysTherapy_Flr_3'],
            'Hospital - radiology/imaging' => ['Radiology_Flr_4']
        }

      else
        space_type_map = {
            # 'Basement', 'ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1',
            # 'ER_Triage_Mult4_Flr_1', 'Office1_Mult4_Flr_1', 'Lobby_Records_Flr_1', 'Corridor_Flr_1',
            # 'ER_NurseStn_Lobby_Flr_1', 'OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2',
            # 'IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', 'ICU_Flr_2',
            # 'ICU_NurseStn_Lobby_Flr_2', 'Corridor_Flr_2', 'OR_NurseStn_Lobby_Flr_2', 'PatRoom1_Mult10_Flr_3',
            # 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3',
            # 'PhysTherapy_Flr_3', 'PatRoom6_Flr_3', 'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3',
            # 'NurseStn_Lobby_Flr_3', 'Lab_Flr_3', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3',
            # 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4',
            # 'PatRoom5_Mult10_Flr_4', 'Radiology_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4',
            # 'PatRoom8_Flr_4', 'NurseStn_Lobby_Flr_4', 'Lab_Flr_4', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4',
            # 'Dining_Flr_5', 'NurseStn_Lobby_Flr_5', 'Kitchen_Flr_5', 'Office1_Flr_5', 'Office2_Mult5_Flr_5',
            # 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Corridor_Flr_5'
            'Corridor' => ['Corridor_Flr_1', 'Corridor_Flr_2', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Corridor_Flr_5'],
            'Dining' => ['Dining_Flr_5'],
            'ER_Exam' => ['ER_Exam1_Mult4_Flr_1', 'ER_Exam3_Mult4_Flr_1'],
            'ER_NurseStn' => ['ER_NurseStn_Lobby_Flr_1'],
            'ER_Trauma' => ['ER_Trauma1_Flr_1', 'ER_Trauma2_Flr_1'],
            'ER_Triage' => ['ER_Triage_Mult4_Flr_1'],
            'ICU_NurseStn' => ['ICU_NurseStn_Lobby_Flr_2'],
            'ICU_Open' => ['ICU_Flr_2'],
            'ICU_PatRm' => ['IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2'],
            'Kitchen' => ['Kitchen_Flr_5'],
            'Lab' => ['Lab_Flr_3', 'Lab_Flr_4'],
            'Lobby' => ['Lobby_Records_Flr_1'],
            'NurseStn' => ['OR_NurseStn_Lobby_Flr_2', 'NurseStn_Lobby_Flr_3', 'NurseStn_Lobby_Flr_4', 'NurseStn_Lobby_Flr_5'],
            'OR' => ['OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2'],
            'Office' => ['Office1_Mult4_Flr_1', 'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5'],
            'Basement' => ['Basement'], # 'PatCorridor' => [],
            'PatRoom' => ['PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PatRoom6_Flr_3', 'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 'PatRoom5_Mult10_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4'],
            'PhysTherapy' => ['PhysTherapy_Flr_3'],
            'Radiology' => ['Radiology_Flr_4'] # total number of zones: 55 - equals to the IDF
        }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    case template
      when '90.1-2010', '90.1-2013'
        exhaust_flow = 7200
      when '90.1-2004', '90.1-2007'
        exhaust_flow = 8000
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        exhaust_flow = 3710
        exhaust_flow_dining = 1589
    end

    case template
      when '90.1-2010', '90.1-2013', '90.1-2004', '90.1-2007'
        system_to_space_map = [
            {
                'type' => 'VAV',
                'name' => 'VAV_1',
                'space_names' => ['Basement', 'Office1_Mult4_Flr_1', 'Lobby_Records_Flr_1', 'Corridor_Flr_1', 'ER_NurseStn_Lobby_Flr_1', 'ICU_NurseStn_Lobby_Flr_2', 'Corridor_Flr_2', 'OR_NurseStn_Lobby_Flr_2']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_ER',
                'space_names' => ['ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_OR',
                'space_names' => ['OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_ICU',
                'space_names' => ['IC_PatRoom1_Mult5_Flr_2', 'IC_PatRoom2_Flr_2', 'IC_PatRoom3_Mult6_Flr_2', 'ICU_Flr_2']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_PATRMS',
                'space_names' => ['PatRoom1_Mult10_Flr_3', 'PatRoom2_Flr_3', 'PatRoom3_Mult10_Flr_3', 'PatRoom4_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PatRoom6_Flr_3', 'PatRoom7_Mult10_Flr_3', 'PatRoom8_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom2_Flr_4', 'PatRoom3_Mult10_Flr_4', 'PatRoom4_Flr_4', 'PatRoom5_Mult10_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4', 'PatRoom8_Flr_4']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_2',
                'space_names' => ['PhysTherapy_Flr_3', 'NurseStn_Lobby_Flr_3', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'Radiology_Flr_4', 'NurseStn_Lobby_Flr_4', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Dining_Flr_5', 'NurseStn_Lobby_Flr_5', 'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Corridor_Flr_5']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_LABS',
                'space_names' => ['Lab_Flr_3', 'Lab_Flr_4']
            },
            {
                'type' => 'CAV',
                'name' => 'CAV_KITCHEN',
                'space_names' => [
                    'Kitchen_Flr_5'
                ] # 55 spaces assigned.
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen_Flr_5 Exhaust Fan',
                'availability_sch_name' => 'Hospital Kitchen_Exhaust_SCH',
                'flow_rate' => OpenStudio.convert(exhaust_flow, 'cfm', 'm^3/s').get,
                'balanced_exhaust_fraction_schedule_name' => 'Hospital Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule',
                'space_names' =>
                    [
                        'Kitchen_Flr_5'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 734,
                'length' => 10.98,
                'evaporator_fan_pwr_per_length' => 69,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'Hospital BLDG_LIGHT_SCH',
                'defrost_pwr_per_length' => 364,
                'restocking_sch_name' => 'Hospital Kitchen_Flr_5_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 1000,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen_Flr_5'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 886.5,
                'length' => 8.93,
                'evaporator_fan_pwr_per_length' => 67,
                'lighting_per_length' => 40,
                'lighting_sch_name' => 'Hospital BLDG_LIGHT_SCH',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'Hospital Kitchen_Flr_5_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 1000,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen_Flr_5'
                    ]
            }
        ]
        return system_to_space_map
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        system_to_space_map = [
            {
                'type' => 'VAV',
                'name' => 'CAV_1',
                'space_names' => ['ER_Exam1_Mult4_Flr_1', 'ER_Trauma1_Flr_1', 'ER_Exam3_Mult4_Flr_1', 'ER_Trauma2_Flr_1', 'ER_Triage_Mult4_Flr_1', 'IC_PatRoom1_Mult5_Flr_2', 'PatRoom1_Mult10_Flr_3', 'PatRoom5_Mult10_Flr_3', 'PatRoom7_Mult10_Flr_3', 'PatRoom3_Mult10_Flr_4', 'PatRoom5_Mult10_Flr_4', 'PatRoom6_Flr_4', 'PatRoom7_Mult10_Flr_4']
            },
            {
                'type' => 'VAV',
                'name' => 'CAV_2',
                'space_names' => ['OR1_Flr_2', 'OR2_Mult5_Flr_2', 'OR3_Flr_2', 'OR4_Flr_2', 'IC_PatRoom2_Flr_2', 'PatRoom2_Flr_3', 'PatRoom6_Flr_3', 'PatRoom8_Flr_3', 'PatRoom4_Flr_4']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_1',
                'space_names' => ['Office1_Mult4_Flr_1', 'Lobby_Records_Flr_1', 'Corridor_Flr_1', 'ER_NurseStn_Lobby_Flr_1', 'IC_PatRoom3_Mult6_Flr_2', 'ICU_NurseStn_Lobby_Flr_2', 'Corridor_Flr_2', 'OR_NurseStn_Lobby_Flr_2', 'PatRoom3_Mult10_Flr_3', 'Lab_Flr_3', 'PatRoom1_Mult10_Flr_4', 'PatRoom8_Flr_4']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_2',
                'space_names' => ['ICU_Flr_2', 'PatRoom4_Flr_3', 'PhysTherapy_Flr_3', 'NurseStn_Lobby_Flr_3', 'Corridor_SE_Flr_3', 'Corridor_NW_Flr_3', 'PatRoom2_Flr_4', 'Radiology_Flr_4', 'NurseStn_Lobby_Flr_4', 'Lab_Flr_4', 'Corridor_SE_Flr_4', 'Corridor_NW_Flr_4', 'Dining_Flr_5', 'NurseStn_Lobby_Flr_5', 'Kitchen_Flr_5', 'Office1_Flr_5', 'Office2_Mult5_Flr_5', 'Office3_Flr_5', 'Office4_Mult6_Flr_5', 'Corridor_Flr_5']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen_Flr_5 Exhaust Fan',
                'availability_sch_name' => 'Hospital HVACOperationSchd',
                'flow_rate' => OpenStudio.convert(exhaust_flow, 'cfm', 'm^3/s').get,
                'space_names' =>
                    [
                        'Kitchen_Flr_5'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining_Flr_5 Exhaust Fan',
                'availability_sch_name' => 'Hospital HVACOperationSchd',
                'flow_rate' => OpenStudio.convert(exhaust_flow_dining, 'cfm', 'm^3/s').get,
                'space_names' =>
                    [
                        'Dining_Flr_5'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 734,
                'length' => 10.98,
                'evaporator_fan_pwr_per_length' => 69,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'Hospital BLDG_LIGHT_SCH',
                'defrost_pwr_per_length' => 364,
                'restocking_sch_name' => 'Hospital Kitchen_Flr_5_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 1000,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen_Flr_5'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 886.5,
                'length' => 8.93,
                'evaporator_fan_pwr_per_length' => 67,
                'lighting_per_length' => 40,
                'lighting_sch_name' => 'Hospital BLDG_LIGHT_SCH',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'Hospital Kitchen_Flr_5_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 1000,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen_Flr_5'
                    ]
            }
        ]
        return system_to_space_map
    end
  end

  def self.define_space_multiplier
    building_type = 'Hospital'
    # This map define the multipliers for spaces with multipliers not equals to 1
    space_multiplier_map = JSON.parse(File.read(File.join(File.dirname(__FILE__),"../../../data/geometry/archetypes/#{building_type}.json")))[building_type]['space_multiplier_map']
    return space_multiplier_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')

    system_to_space_map = PrototypeBuilding::Hospital.define_hvac_system_map(building_type, template, climate_zone)

    hot_water_loop = nil
    model.getPlantLoops.each do |loop|
      # If it has a boiler:hotwater, it is the correct loop
      unless loop.supplyComponents('OS:Boiler:HotWater'.to_IddObjectType).empty?
        hot_water_loop = loop
      end
    end
    if hot_water_loop
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          space_names = ['ER_Exam3_Mult4_Flr_1', 'OR2_Mult5_Flr_2', 'ICU_Flr_2', 'PatRoom5_Mult10_Flr_4', 'Lab_Flr_3']
          space_names.each do |space_name|
            PrototypeBuilding::Hospital.add_humidifier(space_name, template, hot_water_loop, model)
          end
        when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
          space_names = ['ER_Exam3_Mult4_Flr_1', 'OR2_Mult5_Flr_2']
          space_names.each do |space_name|
            PrototypeBuilding::Hospital.add_humidifier(space_name, template, hot_water_loop, model)
          end
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Could not find hot water loop to attach humidifier to.')
    end

    PrototypeBuilding::Hospital.reset_kitchen_oa(template, model)
    PrototypeBuilding::Hospital.update_exhaust_fan_efficiency(template, model)
    PrototypeBuilding::Hospital.reset_or_room_vav_minimum_damper(prototype_input, template, model)

    return true
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          if water_heater.name.to_s.include?('Booster')
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
          else
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(15.60100708)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(15.60100708)
          end
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::Hospital.update_waterheater_loss_coefficient(template, model)
    return true
  end # add swh

  def self.reset_kitchen_oa(template, model)
    space_kitchen = model.getSpaceByName('Kitchen_Flr_5').get
    ventilation = space_kitchen.designSpecificationOutdoorAir.get
    ventilation.setOutdoorAirFlowperPerson(0)
    ventilation.setOutdoorAirFlowperFloorArea(0)
    case template
      when '90.1-2010', '90.1-2013'
        ventilation.setOutdoorAirFlowRate(3.398)
      when '90.1-2004', '90.1-2007', 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        ventilation.setOutdoorAirFlowRate(3.776)
    end
  end

  def self.update_exhaust_fan_efficiency(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.16)
          exhaust_fan.setPressureRise(125)
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.338)
          exhaust_fan.setPressureRise(125)
        end
    end
  end

  def self.add_humidifier(space_name, template, hot_water_loop, model)
    space = model.getSpaceByName(space_name).get
    zone = space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('Hospital MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('Hospital MaxRelHumSetSch'))
    zone.setZoneControlHumidistat(humidistat)

    model.getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100_000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject.get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
        case template
          when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
            extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
            extra_elec_htg_coil.setName("#{space_name} Electric Htg Coil")
            extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
            extra_water_htg_coil.setName("#{space_name} Water Htg Coil")
            hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
            extra_elec_htg_coil.addToNode(supply_outlet_node)
            extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)
        humidity_spm.setControlZone(zone)
      end
    end
  end

  def self.hospital_add_daylighting_controls(template, model)
    space_names = ['Office1_Flr_5', 'Office3_Flr_5', 'Lobby_Records_Flr_1']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      space.add_daylighting_controls(template, false, false)
    end
  end

  def self.reset_or_room_vav_minimum_damper(prototype_input, template, model)
    case template
      when '90.1-2004', '90.1-2007'
        return true
      when '90.1-2010', '90.1-2013'
        model.getAirTerminalSingleDuctVAVReheats.sort.each do |airterminal|
          airterminal_name = airterminal.name.get
          if airterminal_name.include?('OR1') || airterminal_name.include?('OR2') || airterminal_name.include?('OR3') || airterminal_name.include?('OR4')
            airterminal.setZoneMinimumAirFlowMethod('Scheduled')
            airterminal.setMinimumAirFlowFractionSchedule(model.add_schedule('Hospital OR_MinSA_Sched'))
          end
        end
    end
  end

  def self.modify_hospital_oa_controller(template, model)
    model.getAirLoopHVACs.each do |air_loop|
      oa_sys = air_loop.airLoopHVACOutdoorAirSystem.get
      oa_control = oa_sys.getControllerOutdoorAir
      case air_loop.name.get
        when 'VAV_ER', 'VAV_ICU', 'VAV_LABS', 'VAV_OR', 'VAV_PATRMS', 'CAV_1', 'CAV_2'
          oa_control.setEconomizerControlType('NoEconomizer')
      end
    end
  end
end
module LargeHotel
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
      when 'NECB 2011'
        # Building Schedule
        sch = 'E'
        space_type_map = {
            'Hotel/Motel - dining' => ['Banquet_Flr_6', 'Dining_Flr_6'],
            'Storage area' => ['Basement', 'Storage_Flr_1'],
            'Retail - mall concourse' => ['Cafe_Flr_1'],
            "Corr. >= 2.4m wide-sch-#{sch}" => ['Corridor_Flr_3', 'Corridor_Flr_6'],
            'Food preparation' => ['Kitchen_Flr_6'],
            'Hospital - laundry/washing' => ['Laundry_Flr_1'],
            'Hotel/Motel - lobby' => ['Lobby_Flr_1'],
            "Electrical/Mechanical-sch-#{sch}" => ['Mech_Flr_1'],
            'Retail - sales' => ['Retail_1_Flr_1', 'Retail_2_Flr_1'],
            'Hotel/Motel - rooms' => ['Room_1_Flr_3', 'Room_1_Flr_6', 'Room_2_Flr_3', 'Room_2_Flr_6', 'Room_3_Mult19_Flr_3', 'Room_3_Mult9_Flr_6', 'Room_4_Mult19_Flr_3', 'Room_5_Flr_3', 'Room_6_Flr_3']
        }
      else
        space_type_map = {
            'Banquet' => ['Banquet_Flr_6', 'Dining_Flr_6'],
            'Basement' => ['Basement'],
            'Cafe' => ['Cafe_Flr_1'],
            'Corridor' => ['Corridor_Flr_6'],
            'Corridor2' => ['Corridor_Flr_3'],
            'GuestRoom' => ['Room_1_Flr_3', 'Room_2_Flr_3', 'Room_5_Flr_3', 'Room_6_Flr_3'],
            'GuestRoom2' => ['Room_3_Mult19_Flr_3', 'Room_4_Mult19_Flr_3'],
            'GuestRoom3' => ['Room_1_Flr_6', 'Room_2_Flr_6'],
            'GuestRoom4' => ['Room_3_Mult9_Flr_6'],
            'Kitchen' => ['Kitchen_Flr_6'],
            'Laundry' => ['Laundry_Flr_1'],
            'Lobby' => ['Lobby_Flr_1'],
            'Mechanical' => ['Mech_Flr_1'],
            'Retail' => ['Retail_1_Flr_1'],
            'Retail2' => ['Retail_2_Flr_1'],
            'Storage' => ['Storage_Flr_1']
        }
    end

    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
        {
            'type' => 'VAV',
            'name' => 'VAV WITH REHEAT',
            'space_names' =>
                ['Basement', 'Retail_1_Flr_1', 'Retail_2_Flr_1', 'Mech_Flr_1', 'Storage_Flr_1', 'Laundry_Flr_1', 'Cafe_Flr_1', 'Lobby_Flr_1', 'Corridor_Flr_3', 'Banquet_Flr_6', 'Dining_Flr_6', 'Corridor_Flr_6', 'Kitchen_Flr_6']
        },
        {
            'type' => 'DOAS',
            'space_names' =>
                ['Room_1_Flr_3', 'Room_2_Flr_3', 'Room_3_Mult19_Flr_3', 'Room_4_Mult19_Flr_3', 'Room_5_Flr_3', 'Room_6_Flr_3', 'Room_1_Flr_6', 'Room_2_Flr_6', 'Room_3_Mult9_Flr_6']
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Walkin Freezer',
            'cooling_capacity_per_length' => 367.0,
            'length' => 7.32,
            'evaporator_fan_pwr_per_length' => 34.0,
            'lighting_per_length' => 16.4,
            'lighting_sch_name' => 'HotelLarge BLDG_LIGHT_SCH',
            'defrost_pwr_per_length' => 273.0,
            'restocking_sch_name' => 'HotelLarge Kitchen_Flr_6_Case:1_WALKINFREEZER_WalkInStockingSched',
            'cop' => 1.5,
            'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
            'condenser_fan_pwr' => 350.0,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
                [
                    'Kitchen_Flr_6'
                ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Display Case',
            'cooling_capacity_per_length' => 734.0,
            'length' => 3.66,
            'evaporator_fan_pwr_per_length' => 55.0,
            'lighting_per_length' => 33.0,
            'lighting_sch_name' => 'HotelLarge BLDG_LIGHT_SCH',
            'defrost_pwr_per_length' => 0.0,
            'restocking_sch_name' => 'HotelLarge Kitchen_Flr_6_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
            'cop' => 3.0,
            'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
            'condenser_fan_pwr' => 750.0,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
                [
                    'Kitchen_Flr_6'
                ]
        }
    ]
    return system_to_space_map
  end

  def self.define_space_multiplier
    building_type = 'LargeHotel'
    # This map define the multipliers for spaces with multipliers not equals to 1
    space_multiplier_map = JSON.parse(File.read(File.join(File.dirname(__FILE__),"../../../data/geometry/archetypes/#{building_type}.json")))[building_type]['space_multiplier_map']
    return space_multiplier_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # Add Exhaust Fan
    space_type_map = model.define_space_type_map(building_type, template, climate_zone)
    exhaust_fan_space_types = []
    case template
      when '90.1-2004', '90.1-2007'
        exhaust_fan_space_types = ['Kitchen', 'Laundry']
      else
        exhaust_fan_space_types = ['Banquet', 'Kitchen', 'Laundry']
    end

    exhaust_fan_space_types.each do |space_type_name|
      space_type_data = model.find_object($os_standards['space_types'], 'template' => template, 'building_type' => building_type, 'space_type' => space_type_name)
      if space_type_data.nil?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find space type #{template}-#{building_type}-#{space_type_name}")
        return false
      end

      exhaust_schedule = model.add_schedule(space_type_data['exhaust_schedule'])
      if exhaust_schedule.class.to_s == 'NilClass'
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Unable to find Exhaust Schedule for space type #{template}-#{building_type}-#{space_type_name}")
        return false
      end

      balanced_exhaust_schedule = model.add_schedule(space_type_data['balanced_exhaust_fraction_schedule'])

      space_names = space_type_map[space_type_name]
      space_names.each do |space_name|
        space = model.getSpaceByName(space_name).get
        thermal_zone = space.thermalZone.get

        zone_exhaust_fan = OpenStudio::Model::FanZoneExhaust.new(model)
        zone_exhaust_fan.setName(space.name.to_s + ' Exhaust Fan')
        zone_exhaust_fan.setAvailabilitySchedule(exhaust_schedule)
        zone_exhaust_fan.setFanEfficiency(space_type_data['exhaust_fan_efficiency'])
        zone_exhaust_fan.setPressureRise(space_type_data['exhaust_fan_pressure_rise'])
        maximum_flow_rate = OpenStudio.convert(space_type_data['exhaust_fan_maximum_flow_rate'], 'cfm', 'm^3/s').get

        zone_exhaust_fan.setMaximumFlowRate(maximum_flow_rate)
        if balanced_exhaust_schedule.class.to_s != 'NilClass'
          zone_exhaust_fan.setBalancedExhaustFractionSchedule(balanced_exhaust_schedule)
        end
        zone_exhaust_fan.setEndUseSubcategory('Zone Exhaust Fans')
        zone_exhaust_fan.addToThermalZone(thermal_zone)

        if !space_type_data['exhaust_fan_power'].nil? && space_type_data['exhaust_fan_power'].to_f.nonzero?
          # Create the electric equipment definition
          exhaust_fan_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
          exhaust_fan_equip_def.setName("#{space_name} Electric Equipment Definition")
          exhaust_fan_equip_def.setDesignLevel(space_type_data['exhaust_fan_power'].to_f)
          exhaust_fan_equip_def.setFractionLatent(0)
          exhaust_fan_equip_def.setFractionRadiant(0)
          exhaust_fan_equip_def.setFractionLost(1)

          # Create the electric equipment instance and hook it up to the space type
          exhaust_fan_elec_equip = OpenStudio::Model::ElectricEquipment.new(exhaust_fan_equip_def)
          exhaust_fan_elec_equip.setName("#{space_name} Exhaust Fan Equipment")
          exhaust_fan_elec_equip.setSchedule(exhaust_schedule)
          exhaust_fan_elec_equip.setSpaceType(space.spaceType.get)
        end
      end
    end

    # Update Sizing Zone
    zone_sizing = model.getSpaceByName('Kitchen_Flr_6').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlowFraction(0.7)

    zone_sizing = model.getSpaceByName('Laundry_Flr_1').get.thermalZone.get.sizingZone
    zone_sizing.setCoolingMinimumAirFlow(0.23567919336)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end # add hvac

  # Add the daylighting controls for lobby, cafe, dinning and banquet
  def self.large_hotel_add_daylighting_controls(template, model)
    space_names = ['Banquet_Flr_6', 'Dining_Flr_6', 'Cafe_Flr_1', 'Lobby_Flr_1']
    space_names.each do |space_name|
      space = model.getSpaceByName(space_name).get
      space.add_daylighting_controls(template, false, false)
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end
module LargeOffice
  def self.define_space_type_map(building_type, template, climate_zone)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        space_type_map = {
            'WholeBuilding - Lg Office' => [
                'Basement', 'Core_bottom', 'Core_mid', 'Core_top', # 'GroundFloor_Plenum', 'MidFloor_Plenum', 'TopFloor_Plenum',
                'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4',
                'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4',
                'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4'
            ]
        }
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        space_type_map = {
            'WholeBuilding - Lg Office' => [
                'Basement', 'Core_bottom', 'Core_mid', 'Core_top', # 'GroundFloor_Plenum', 'MidFloor_Plenum', 'TopFloor_Plenum',
                'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4',
                'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4',
                'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4'
            ],
            'OfficeLarge Data Center' => ['DataCenter_bot_ZN_6', 'DataCenter_mid_ZN_6', 'DataCenter_top_ZN_6'],
            'OfficeLarge Main Data Center' => [
                'DataCenter_basement_ZN_6'
            ]
        }
      when 'NECB 2011'
        # Dom is A
        space_type_map = {
            'Electrical/Mechanical-sch-A' => ['Basement'],

            'Office - open plan' => ['Core_bottom', 'Core_mid', 'Core_top', 'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'DataCenter_basement_ZN_6', 'DataCenter_bot_ZN_6', 'DataCenter_mid_ZN_6', 'DataCenter_top_ZN_6'],
            '- undefined -' => ['GroundFloor_Plenum', 'TopFloor_Plenum', 'MidFloor_Plenum']
        }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        system_to_space_map = [
            {
                'type' => 'VAV',
                'name' => 'VAV_1',
                'space_names' =>
                    ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom'],
                'return_plenum' => 'GroundFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_2',
                'space_names' =>
                    ['Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid'],
                'return_plenum' => 'MidFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_3',
                'space_names' =>
                    ['Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'],
                'return_plenum' => 'TopFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_5',
                'space_names' =>
                    [
                        'Basement'
                    ]
            }
        ]
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        system_to_space_map = [
            {
                'type' => 'VAV',
                'name' => 'VAV_bot WITH REHEAT',
                'space_names' =>
                    ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom'],
                'return_plenum' => 'GroundFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_mid WITH REHEAT',
                'space_names' =>
                    ['Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid'],
                'return_plenum' => 'MidFloor_Plenum'
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_top WITH REHEAT',
                'space_names' =>
                    ['Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'],
                'return_plenum' => 'TopFloor_Plenum'
            },
            {

                'type' => 'CAV',
                'name' => 'CAV_bas',
                'space_names' =>
                    [
                        'Basement'
                    ]
            },
            {
                'type' => 'DC',
                'space_names' =>
                    [
                        'DataCenter_basement_ZN_6'
                    ],
                'load' => 484.423246742185,
                'main_data_center' => true
            },
            {
                'type' => 'DC',
                'space_names' =>
                    [
                        'DataCenter_bot_ZN_6'
                    ],
                'load' => 215.299220774304,
                'main_data_center' => false
            },
            {
                'type' => 'DC',
                'space_names' =>
                    [
                        'DataCenter_mid_ZN_6'
                    ],
                'load' => 215.299220774304,
                'main_data_center' => false
            },
            {
                'type' => 'DC',
                'space_names' =>
                    [
                        'DataCenter_top_ZN_6'
                    ],
                'load' => 215.299220774304,
                'main_data_center' => false
            }
        ]

    end

    return system_to_space_map
  end

  def self.define_space_multiplier
    building_type = 'LargeOffice'
    # This map define the multipliers for spaces with multipliers not equals to 1
    space_multiplier_map = JSON.parse(File.read(File.join(File.dirname(__FILE__),"../../../data/geometry/archetypes/#{building_type}.json")))[building_type]['space_multiplier_map']
    return space_multiplier_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    system_to_space_map = define_hvac_system_map(building_type, template, climate_zone)

    system_to_space_map.each do |system|
      # find all zones associated with these spaces
      thermal_zones = []
      system['space_names'].each do |space_name|
        space = model.getSpaceByName(space_name)
        if space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{space_name} was found in the model")
          return false
        end
        space = space.get
        zone = space.thermalZone
        if zone.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{space_name}")
          return false
        end
        thermal_zones << zone.get
      end

      return_plenum = nil
      unless system['return_plenum'].nil?
        return_plenum_space = model.getSpaceByName(system['return_plenum'])
        if return_plenum_space.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No space called #{system['return_plenum']} was found in the model")
          return false
        end
        return_plenum_space = return_plenum_space.get
        return_plenum = return_plenum_space.thermalZone
        if return_plenum.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "No thermal zone was created for the space called #{system['return_plenum']}")
          return false
        end
        return_plenum = return_plenum.get
      end
    end

    return true
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(11.25413987)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(11.25413987)
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::LargeOffice.update_waterheater_loss_coefficient(template, model)
    return true
  end
end
module MediumOffice
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    space_type_map = case template
                       when 'NECB 2011'
                         {
                             '- undefined -' => ['FirstFloor_Plenum', 'TopFloor_Plenum', 'MidFloor_Plenum'],
                             'Office - open plan' => ['Core_bottom', 'Core_mid', 'Core_top', 'Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4']

                         }
                       else
                         {
                             'WholeBuilding - Md Office' => ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom', 'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid', 'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top']
                         }
                     end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = case template
                            when 'DOE Ref Pre-1980'
                              [
                                  {
                                      'type' => 'PSZ-AC',

                                      'space_names' =>
                                          ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom', 'Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid', 'Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top']
                                  }
                              ]
                            else
                              [
                                  {
                                      'type' => 'PVAV',
                                      'space_names' =>
                                          ['Perimeter_bot_ZN_1', 'Perimeter_bot_ZN_2', 'Perimeter_bot_ZN_3', 'Perimeter_bot_ZN_4', 'Core_bottom'],
                                      'return_plenum' => 'FirstFloor_Plenum'
                                  },
                                  {
                                      'type' => 'PVAV',
                                      'space_names' =>
                                          ['Perimeter_mid_ZN_1', 'Perimeter_mid_ZN_2', 'Perimeter_mid_ZN_3', 'Perimeter_mid_ZN_4', 'Core_mid'],
                                      'return_plenum' => 'MidFloor_Plenum'
                                  },
                                  {
                                      'type' => 'PVAV',
                                      'space_names' =>
                                          ['Perimeter_top_ZN_1', 'Perimeter_top_ZN_2', 'Perimeter_top_ZN_3', 'Perimeter_top_ZN_4', 'Core_top'],
                                      'return_plenum' => 'TopFloor_Plenum'
                                  }
                              ]
                          end
    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    model.getSpaces.each do |space|
      if space.name.get.to_s == 'Core_bottom'
        model.add_elevator(template,
                           space,
                           prototype_input['number_of_elevators'],
                           prototype_input['elevator_type'],
                           prototype_input['elevator_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           building_type)
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end # add hvac

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::MediumOffice.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
module MidriseApartment
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil

    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        space_type_map = {
            'Office' => ['Office'],
            'Corridor' => ['G Corridor', 'M Corridor'],
            'Corridor_topfloor' => ['T Corridor'],
            'Apartment' => [
                'G SW Apartment',
                'G NW Apartment',
                'G NE Apartment',
                'G N1 Apartment',
                'G N2 Apartment',
                'G S1 Apartment',
                'G S2 Apartment',
                'M SW Apartment',
                'M NW Apartment',
                'M SE Apartment',
                'M NE Apartment',
                'M N1 Apartment',
                'M N2 Apartment',
                'M S1 Apartment',
                'M S2 Apartment'
            ],
            'Apartment_topfloor_WE' => [
                'T SW Apartment',
                'T NW Apartment',
                'T SE Apartment',
                'T NE Apartment'
            ],
            'Apartment_topfloor_NS' => [
                'T N1 Apartment',
                'T N2 Apartment',
                'T S1 Apartment',
                'T S2 Apartment'
            ]
        }
      when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
        space_type_map = {
            'Office' => ['Office'],
            'Corridor' => ['G Corridor', 'M Corridor', 'T Corridor'],
            'Apartment' => [
                'G SW Apartment',
                'G NW Apartment',
                'G NE Apartment',
                'G N1 Apartment',
                'G N2 Apartment',
                'G S1 Apartment',
                'G S2 Apartment',
                'M SW Apartment',
                'M NW Apartment',
                'M SE Apartment',
                'M NE Apartment',
                'M N1 Apartment',
                'M N2 Apartment',
                'M S1 Apartment',
                'M S2 Apartment',
                'T SW Apartment',
                'T NW Apartment',
                'T SE Apartment',
                'T NE Apartment',
                'T N1 Apartment',
                'T N2 Apartment',
                'T S1 Apartment',
                'T S2 Apartment'
            ]
        }

      when 'NECB 2011'
        sch = 'G'
        space_type_map = {
            "Corr. < 2.4m wide-sch-#{sch}" => ['G Corridor', 'M Corridor', 'T Corridor'],

            'Dwelling Unit(s)' => ['G N1 Apartment', 'G N2 Apartment', 'G NE Apartment',
                                   'G NW Apartment', 'G S1 Apartment', 'G S2 Apartment',
                                   'G SW Apartment', 'M N1 Apartment', 'M N2 Apartment',
                                   'M NE Apartment', 'M NW Apartment', 'M S1 Apartment',
                                   'M S2 Apartment', 'M SE Apartment', 'M SW Apartment',
                                   'T N1 Apartment', 'T N2 Apartment', 'T NE Apartment',
                                   'T NW Apartment', 'T S1 Apartment', 'T S2 Apartment',
                                   'T SE Apartment', 'T SW Apartment'],
            'Conf./meet./multi-purpose' => ['Office']
        }
    end

    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
        { 'type' => 'SAC',
          'space_names' => ['G SW Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['G NW Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['G NE Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['G N1 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['G N2 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['G S1 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['G S2 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['M SW Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['M NW Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['M SE Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['M NE Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['M N1 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['M N2 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['M S1 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['M S2 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['T SW Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['T NW Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['T SE Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['T NE Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['T N1 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['T N2 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['T S1 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['T S2 Apartment'] },
        { 'type' => 'SAC',
          'space_names' => ['Office'] }
    ]

    case template
      when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
        system_to_space_map.push('type' => 'UnitHeater', 'space_names' => ['G Corridor'])
        system_to_space_map.push('type' => 'UnitHeater', 'space_names' => ['M Corridor'])
        system_to_space_map.push('type' => 'UnitHeater', 'space_names' => ['T Corridor'])
    end

    return system_to_space_map
  end

  def self.define_space_multiplier
    building_type = 'MidriseApartment'
    # This map define the multipliers for spaces with multipliers not equals to 1
    space_multiplier_map = JSON.parse(File.read(File.join(File.dirname(__FILE__),"../../../data/geometry/archetypes/#{building_type}.json")))[building_type]['space_multiplier_map']
    return space_multiplier_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # adjust the cooling setpoint
    PrototypeBuilding::MidriseApartment.adjust_clg_setpoint(template, climate_zone, model)
    # add elevator and lights&fans for the ground floor corridor
    PrototypeBuilding::MidriseApartment.add_extra_equip_corridor(template, model)
    # add extra infiltration for ground floor corridor
    PrototypeBuilding::MidriseApartment.add_door_infiltration(template, climate_zone, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def self.adjust_clg_setpoint(template, climate_zone, model)
    space_name = 'Office'
    space_type_name = model.getSpaceByName(space_name).get.spaceType.get.name.get
    thermostat_name = space_type_name + ' Thermostat'
    thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010'
        case climate_zone
          when 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-3B'
            thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('ApartmentMidRise CLGSETP_OFF_SCH_NO_OPTIMUM'))
        end
    end
  end

  # add elevator and lights&fans for the ground floor corridor
  def self.add_extra_equip_corridor(template, model)
    corridor_ground_space = model.getSpaceByName('G Corridor').get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Ground Corridor Electric Equipment Definition1')
    elec_equip_def2.setName('Ground Corridor Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(0.95)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0)
        elec_equip_def2.setFractionLost(0.95)
        elec_equip_def1.setDesignLevel(16_055)
        if template == '90.1-2013'
          elec_equip_def2.setDesignLevel(63)
        elsif template == '90.1-2010'
          elec_equip_def2.setDesignLevel(105.9)
        else
          elec_equip_def2.setDesignLevel(161.9)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('G Corridor_Elevators_Equip')
        elec_equip2.setName('Elevators_Lights_Fan')
        elec_equip1.setSpace(corridor_ground_space)
        elec_equip2.setSpace(corridor_ground_space)
        elec_equip1.setSchedule(model.add_schedule('ApartmentMidRise BLDG_ELEVATORS'))
        case template
          when '90.1-2004', '90.1-2007'
            elec_equip2.setSchedule(model.add_schedule('ApartmentMidRise ELEV_LIGHT_FAN_SCH_24_7'))
          when '90.1-2010', '90.1-2013'
            elec_equip2.setSchedule(model.add_schedule('ApartmentMidRise ELEV_LIGHT_FAN_SCH_ADD_DF'))
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip_def1.setDesignLevel(16_055)
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(0.95)
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip1.setName('G Corridor_Elevators_Equip')
        elec_equip1.setSpace(corridor_ground_space)
        elec_equip1.setSchedule(model.add_schedule('ApartmentMidRise BLDG_ELEVATORS Pre2004'))
    end
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(46.288874618)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(46.288874618)
        end
    end
  end

  # add extra infiltration for ground floor corridor
  def self.add_door_infiltration(template, climate_zone, model)
    case template
      when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
        # no door infiltration in these two vintages
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        g_corridor = model.getSpaceByName('G Corridor').get
        infiltration_g_corridor_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_g_corridor_door.setName('G Corridor door Infiltration')
        infiltration_g_corridor_door.setSpace(g_corridor)
        case template
          when '90.1-2004'
            infiltration_g_corridor_door.setDesignFlowRate(0.520557541)
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentMidRise INFIL_Door_Opening_SCH_2004_2007'))
          when '90.1-2007'
            case climate_zone
              when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
                infiltration_g_corridor_door.setDesignFlowRate(0.520557541)
              else
                infiltration_g_corridor_door.setDesignFlowRate(0.327531218)
            end
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentMidRise INFIL_Door_Opening_SCH_2004_2007'))
          when '90.1-2010', '90.1-2013'
            case climate_zone
              when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
                infiltration_g_corridor_door.setDesignFlowRate(0.520557541)
              else
                infiltration_g_corridor_door.setDesignFlowRate(0.327531218)
            end
            infiltration_g_corridor_door.setSchedule(model.add_schedule('ApartmentMidRise INFIL_Door_Opening_SCH_2010_2013'))
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::MidriseApartment.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
module Outpatient
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
      when 'NECB 2011'
        # Dom is G
        space_type_map = {
            "Hospital - operating room" => ['Floor 1 Anesthesia', 'Floor 1 Operating Room 1',
                                            'Floor 1 Operating Room 2', 'Floor 1 Operating Room 3', 'Floor 1 Procedure Room'],

            "Hospital - patient room" => ['Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2'],

            "Hospital - exam" => ['Floor 2 Exam 1', 'Floor 2 Exam 2', 'Floor 2 Exam 3', 'Floor 2 Exam 4',
                                  'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7', 'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 3 Treatment'],

            "Hospital corr. >= 2.4m-sch-H"  => ['Floor 1 IT Hall', 'Floor 1 Lobby Hall', 'Floor 1 Vestibule', 'Floor 1 Locker Room Hall',
                                                'Floor 1 MRI Hall', 'Floor 1 Nurse Hall', 'Floor 1 Pre-Op Hall', 'Floor 1 Reception Hall',
                                                'Floor 1 Sterile Hall', 'Floor 1 Scrub', 'Floor 1 Utility Hall', 'Floor 2 Exam Hall 1',
                                                'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5',
                                                'Floor 2 Exam Hall 6', 'Floor 2 Office Hall', 'Floor 2 Reception Hall', 'Floor 2 Work Hall',
                                                'Floor 3 Elevator Hall', 'Floor 3 Mechanical Hall', 'Floor 3 Office Hall'],

            "Hospital - lounge/recreation" => ['Floor 1 Lounge', 'Floor 2 Lounge', 'Floor 3 Lounge', 'Floor 1 Step Down'],

            "Hospital - nurses' station" => ['Floor 1 Nurse Station', 'Floor 2 Nurse Station 2', 'Floor 2 Nurse Station 1', 'Floor 1 Nourishment'],

            "Hospital - radiology/imaging" => ['Floor 1 MRI Control Room', 'Floor 1 MRI Room', 'Floor 2 X-Ray'],

            "Locker room-sch-H" => ['Floor 3 Locker', 'Floor 1 Locker Room', 'Floor 1 PACU'],

            "Lobby - elevator"  => ['NW Elevator', 'Floor 1 Lobby'],

            "Office - enclosed" => ['Floor 1 Office','Floor 1 Scheduling', 'Floor 2 Office', 'Floor 2 Scheduling 1',
                                    'Floor 2 Scheduling 2', 'Floor 3 Office', 'Floor 1 Dictation','Floor 1 Dressing Room', 'Floor 1 IT Room',
                                    'Floor 2 Dictation', 'Floor 3 Dressing Room', 'Floor 2 Work', 'Floor 3 Work', 'Floor 1 Humid', 'Floor 3 Humid'],

            "Stairway-sch-H" => ['NE Stair', 'NW Stair', 'SW Stair'],

            "Washroom-sch-H" => ['Floor 1 Lobby Toilet', 'Floor 1 MRI Toilet', 'Floor 1 Nurse Toilet', 'Floor 1 Pre-Op Toilet',
                                 'Floor 2 Conference Toilet', 'Floor 2 Reception Toilet', 'Floor 2 Work Toilet', 'Floor 3 Lounge Toilet',
                                 'Floor 3 Office Toilet', 'Floor 3 Physical Therapy Toilet'],

            "Storage area" => ['Floor 1 Bio Haz', 'Floor 1 Med Gas', 'Floor 1 Nurse Janitor', 'Floor 1 Sterile Storage', 'Floor 1 Storage',
                               'Floor 1 Sub-Sterile', 'Floor 1 Utility Janitor', 'Floor 2 Janitor', 'Floor 3 Janitor', 'Floor 2 Storage 1',
                               'Floor 2 Storage 2', 'Floor 2 Storage 3', 'Floor 1 Utility Room', 'Floor 2 Utility', 'Floor 3 Utility',
                               'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2'],

            "Hospital - physical therapy" => ['Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2'],

            "Hospital - recovery" => ['Floor 1 Recovery Room'],

            "Hospital - laundry/washing" => ['Floor 1 Clean', 'Floor 1 Clean Work', 'Floor 1 Soil Hold', 'Floor 1 Soil', 'Floor 1 Soil Work'],

            "Conf./meet./multi-purpose" => ['Floor 1 Reception', 'Floor 2 Reception', 'Floor 2 Conference'],

            "Electrical/Mechanical-sch-H" => ['Floor 1 Electrical Room', 'Floor 1 Elevator Pump Room', 'Floor 3 Mechanical'],

            "Dining - bar lounge/leisure" => ['Floor 1 Cafe']
        }
      else
        space_type_map = {
            # 'Floor 1 Anesthesia', 'Floor 1 Bio Haz', 'Floor 1 Cafe', 'Floor 1 Clean', 'Floor 1 Clean Work',
            # 'Floor 1 Dictation', 'Floor 1 Dressing Room', 'Floor 1 Electrical Room', 'Floor 1 Elevator Pump Room',
            # 'Floor 1 Humid', 'Floor 1 IT Hall', 'Floor 1 IT Room', 'Floor 1 Lobby', 'Floor 1 Lobby Hall',
            # 'Floor 1 Lobby Toilet', 'Floor 1 Locker Room', 'Floor 1 Locker Room Hall', 'Floor 1 Lounge',
            # 'Floor 1 Med Gas', 'Floor 1 MRI Control Room', 'Floor 1 MRI Hall', 'Floor 1 MRI Room',
            # 'Floor 1 MRI Toilet', 'Floor 1 Nourishment', 'Floor 1 Nurse Hall', 'Floor 1 Nurse Janitor',
            # 'Floor 1 Nurse Station', 'Floor 1 Nurse Toilet', 'Floor 1 Office', 'Floor 1 Operating Room 1',
            # 'Floor 1 Operating Room 2', 'Floor 1 Operating Room 3', 'Floor 1 PACU', 'Floor 1 Pre-Op Hall',
            # 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2', 'Floor 1 Pre-Op Toilet', 'Floor 1 Procedure Room',
            # 'Floor 1 Reception', 'Floor 1 Reception Hall', 'Floor 1 Recovery Room', 'Floor 1 Scheduling',
            # 'Floor 1 Scrub', 'Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work', 'Floor 1 Step Down',
            # 'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Storage', 'Floor 1 Sub-Sterile',
            # 'Floor 1 Utility Hall', 'Floor 1 Utility Janitor', 'Floor 1 Utility Room', 'Floor 1 Vestibule',
            # 'Floor 2 Conference', 'Floor 2 Conference Toilet', 'Floor 2 Dictation', 'Floor 2 Exam 1',
            # 'Floor 2 Exam 2', 'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6',
            # 'Floor 2 Exam 7', 'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 2 Exam Hall 1',
            # 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5',
            # 'Floor 2 Exam Hall 6', 'Floor 2 Janitor', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1',
            # 'Floor 2 Nurse Station 2', 'Floor 2 Office', 'Floor 2 Office Hall', 'Floor 2 Reception',
            # 'Floor 2 Reception Hall', 'Floor 2 Reception Toilet', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2',
            # 'Floor 2 Storage 1', 'Floor 2 Storage 2', 'Floor 2 Storage 3', 'Floor 2 Utility', 'Floor 2 Work',
            # 'Floor 2 Work Hall', 'Floor 2 Work Toilet', 'Floor 2 X-Ray', 'Floor 3 Dressing Room',
            # 'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Janitor', 'Floor 3 Locker',
            # 'Floor 3 Lounge', 'Floor 3 Lounge Toilet', 'Floor 3 Mechanical', 'Floor 3 Mechanical Hall',
            # 'Floor 3 Office', 'Floor 3 Office Hall', 'Floor 3 Office Toilet', 'Floor 3 Physical Therapy 1',
            # 'Floor 3 Physical Therapy 2', 'Floor 3 Physical Therapy Toilet', 'Floor 3 Storage 1',
            # 'Floor 3 Storage 2', 'Floor 3 Treatment', 'Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2',
            # 'Floor 3 Utility', 'Floor 3 Work', 'NE Stair', 'NW Elevator', 'NW Stair', 'SW Stair'

            # TODO: still need to put these into their space types...
            #  all zones mapped

            'Anesthesia' => ['Floor 1 Anesthesia'],
            'BioHazard' => ['Floor 1 Bio Haz'],
            'Cafe' => ['Floor 1 Cafe'],
            'CleanWork' => ['Floor 1 Clean', 'Floor 1 Clean Work'],
            'Conference' => ['Floor 2 Conference'],
            'DressingRoom' => ['Floor 1 Dressing Room', 'Floor 3 Dressing Room'],
            'Elec/MechRoom' => ['Floor 1 Electrical Room', 'Floor 3 Mechanical'],
            'ElevatorPumpRoom' => ['Floor 1 Elevator Pump Room'],
            # 'Floor 3 Treatment' same as 'Exam'
            'Exam' => ['Floor 2 Exam 1', 'Floor 2 Exam 2', 'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7',
                       'Floor 2 Exam 8', 'Floor 2 Exam 9', 'Floor 3 Treatment'],
            # 'Floor 1 Scrub', 'Floor 1 Sub-Sterile', 'Floor 1 Vestibule' same as 'Hall'
            'Hall' => ['Floor 1 IT Hall', 'Floor 1 Lobby Hall', 'Floor 1 Locker Room Hall', 'Floor 1 MRI Hall', 'Floor 1 Nurse Hall', 'Floor 1 Pre-Op Hall',
                       'Floor 1 Reception Hall', 'Floor 1 Sterile Hall', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3',
                       'Floor 2 Exam Hall 4', 'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Office Hall', 'Floor 2 Reception Hall', 'Floor 2 Work Hall',
                       'Floor 3 Mechanical Hall', 'Floor 1 Scrub'],
            'Hall_infil' => ['Floor 1 Utility Hall', 'Floor 1 Sub-Sterile', 'Floor 1 Vestibule', 'Floor 3 Elevator Hall', 'Floor 3 Office Hall'],
            'IT_Room' => ['Floor 1 IT Room'],
            # ['Floor 1 Sterile Storage', 'Floor 1 Storage', 'Floor 1 Utility Room', 'Floor 2 Storage 1', 'Floor 2 Storage 2', 'Floor 2 Storage 3', ...
            # 'Floor 2 Utility', 'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Utility'] same as 'Janitor'
            'Janitor' => ['Floor 1 Nurse Janitor', 'Floor 1 Utility Janitor', 'Floor 2 Janitor', 'Floor 3 Janitor', 'Floor 1 Sterile Storage',
                          'Floor 1 Storage', 'Floor 1 Utility Room', 'Floor 2 Storage 1', 'Floor 2 Storage 2', 'Floor 2 Storage 3', 'Floor 2 Utility',
                          'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Utility'],
            'Lobby' => ['Floor 1 Lobby'],
            'LockerRoom' => ['Floor 1 Locker Room', 'Floor 3 Locker'],
            'Lounge' => ['Floor 1 Lounge', 'Floor 2 Lounge', 'Floor 3 Lounge'],
            'MRI' => ['Floor 1 MRI Room'],
            'MRI_Control' => ['Floor 1 MRI Control Room'],
            'MedGas' => ['Floor 1 Med Gas'],
            # 'Floor 1 Nourishment' same as 'NurseStation'
            'NurseStation' => ['Floor 1 Nurse Station', 'Floor 1 Nourishment', 'Floor 2 Nurse Station 1', 'Floor 2 Nurse Station 2'],
            'OR' => ['Floor 1 Operating Room 1', 'Floor 1 Operating Room 2', 'Floor 1 Operating Room 3'],
            # ['Floor 1 Dictation', 'Floor 1 Humid','Floor 1 Scheduling', 'Floor 2 Dictation', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', ...
            # 'Floor 2 Work', 'Floor 3 Humid', 'Floor 3 Work'] same as 'Office', 'IT Room' and 'Dressing Room'
            # TODO 'Floor 2 Work' has slightly different equipment density
            'Office' => ['Floor 1 Office', 'Floor 2 Office', 'Floor 3 Office', 'Floor 1 Dictation', 'Floor 1 Humid', 'Floor 1 Scheduling',
                         'Floor 2 Dictation', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', 'Floor 2 Work', 'Floor 3 Humid', 'Floor 3 Work'],
            # 'Floor 1 Recovery Room' and 'Floor 1 Step Down' same as 'PACU'
            'PACU' => ['Floor 1 PACU', 'Floor 1 Recovery Room', 'Floor 1 Step Down'],
            'PhysicalTherapy' => ['Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2'],
            'PreOp' => ['Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2'],
            'ProcedureRoom' => ['Floor 1 Procedure Room'],
            'Soil Work' => ['Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work'],
            'Stair' => ['NE Stair', 'NW Stair', 'SW Stair', 'NW Elevator'],
            'Toilet' => ['Floor 1 Nurse Toilet', 'Floor 1 Pre-Op Toilet', 'Floor 1 Lobby Toilet', 'Floor 1 MRI Toilet', 'Floor 2 Conference Toilet',
                         'Floor 2 Reception Toilet', 'Floor 2 Work Toilet', 'Floor 3 Lounge Toilet', 'Floor 3 Office Toilet', 'Floor 3 Physical Therapy Toilet'],
            'Xray' => ['Floor 2 X-Ray'],
            # Add new space type 'Reception'
            'Reception' => ['Floor 1 Reception', 'Floor 2 Reception'],
            # Add new space type 'Undeveloped'
            'Undeveloped' => ['Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2']
        }
    end

    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        system_to_space_map = [
            {
                'type' => 'PVAV',
                'name' => 'PVAV Outpatient F1',
                'space_names' => [
                    'Floor 1 Anesthesia', 'Floor 1 Bio Haz', 'Floor 1 Cafe', 'Floor 1 Clean', 'Floor 1 Clean Work', 'Floor 1 Dictation',
                    'Floor 1 Dressing Room', 'Floor 1 Electrical Room', 'Floor 1 Elevator Pump Room', 'Floor 1 Humid', 'Floor 1 IT Hall',
                    'Floor 1 IT Room', 'Floor 1 Lobby', 'Floor 1 Lobby Hall', 'Floor 1 Lobby Toilet', 'Floor 1 Locker Room',
                    'Floor 1 Locker Room Hall', 'Floor 1 Lounge', 'Floor 1 Med Gas', 'Floor 1 MRI Control Room', 'Floor 1 MRI Hall',
                    'Floor 1 MRI Room', 'Floor 1 MRI Toilet', 'Floor 1 Nourishment', 'Floor 1 Nurse Hall', 'Floor 1 Nurse Janitor',
                    'Floor 1 Nurse Station', 'Floor 1 Nurse Toilet', 'Floor 1 Office', 'Floor 1 Operating Room 1', 'Floor 1 Operating Room 2',
                    'Floor 1 Operating Room 3', 'Floor 1 PACU', 'Floor 1 Pre-Op Hall', 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2',
                    'Floor 1 Pre-Op Toilet', 'Floor 1 Procedure Room', 'Floor 1 Reception', 'Floor 1 Reception Hall', 'Floor 1 Recovery Room',
                    'Floor 1 Scheduling', 'Floor 1 Scrub', 'Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work', 'Floor 1 Step Down',
                    'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Storage', 'Floor 1 Sub-Sterile', 'Floor 1 Utility Hall',
                    'Floor 1 Utility Janitor', 'Floor 1 Utility Room', 'Floor 1 Vestibule'
                ]
            },
            {
                'type' => 'PVAV',
                'name' => 'PVAV Outpatient F2 F3',
                'space_names' => [
                    'Floor 2 Conference', 'Floor 2 Conference Toilet', 'Floor 2 Dictation', 'Floor 2 Exam 1', 'Floor 2 Exam 2',
                    'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7', 'Floor 2 Exam 8',
                    'Floor 2 Exam 9', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4',
                    'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Janitor', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1',
                    'Floor 2 Nurse Station 2', 'Floor 2 Office', 'Floor 2 Office Hall', 'Floor 2 Reception', 'Floor 2 Reception Hall',
                    'Floor 2 Reception Toilet', 'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2', 'Floor 2 Storage 1', 'Floor 2 Storage 2',
                    'Floor 2 Storage 3', 'Floor 2 Utility', 'Floor 2 Work', 'Floor 2 Work Hall', 'Floor 2 Work Toilet', 'Floor 2 X-Ray',
                    'Floor 3 Dressing Room', 'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Janitor', 'Floor 3 Locker', 'Floor 3 Lounge',
                    'Floor 3 Lounge Toilet', 'Floor 3 Mechanical', 'Floor 3 Mechanical Hall', 'Floor 3 Office', 'Floor 3 Office Hall',
                    'Floor 3 Office Toilet', 'Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2', 'Floor 3 Physical Therapy Toilet',
                    'Floor 3 Storage 1', 'Floor 3 Storage 2', 'Floor 3 Treatment', 'Floor 3 Undeveloped 1', 'Floor 3 Undeveloped 2',
                    'Floor 3 Utility', 'Floor 3 Work', 'NE Stair', 'NW Elevator', 'NW Stair', 'SW Stair'
                ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Outpatient AHU1 Exhaust Fans',
                'availability_sch_name' => 'OutPatientHealthCare Hours_of_operation',
                'flow_rate' =>
                    [
                        6.79561743E-02,    # Floor 1 Anesthesia
                        4.24726077E-02,    # Floor 1 Lobby Toilet
                        0.1586,            # Floor 1 MRI Control Room
                        0.4153,            # Floor 1 MRI Room
                        4.24726077E-02,    # Floor 1 MRI Toilet
                        4.24726077E-02,    # Floor 1 Nurse Toilet
                        4.24726077E-02,    # Floor 1 Pre-Op Toilet
                        9.91027512E-02,    # Floor 1 Soil
                        4.40456672E-02,    # Floor 1 Soil Hold
                        1.41575359E-01,    # Floor 1 Soil Work
                    ],
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Floor 1 Anesthesia',
                        'Floor 1 Lobby Toilet',
                        'Floor 1 MRI Control Room',
                        'Floor 1 MRI Room',
                        'Floor 1 MRI Toilet',
                        'Floor 1 Nurse Toilet',
                        'Floor 1 Pre-Op Toilet',
                        'Floor 1 Soil',
                        'Floor 1 Soil Hold',
                        'Floor 1 Soil Work'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Outpatient AHU2&3 Exhaust Fans',
                'availability_sch_name' => 'OutPatientHealthCare BLDG_OA_SCH',
                'flow_rate' =>
                    [
                        5.03379054E-02,    # Floor 2 Conference Toilet
                        9.91027512E-02,    # Floor 2 Reception Toilet
                        4.24726077E-02,    # Floor 2 Work Toilet
                        0.8495,            # Floor 2 X-Ray
                        1.51013716E-01,    # Floor 3 Lounge Toilet
                        4.24726077E-02,    # Floor 3 Office Toilet
                        6.60685008E-02,    # Floor 3 Physical Therapy Toilet
                    ],
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Floor 2 Conference Toilet',
                        'Floor 2 Reception Toilet',
                        'Floor 2 Work Toilet',
                        'Floor 2 X-Ray',
                        'Floor 3 Lounge Toilet',
                        'Floor 3 Office Toilet',
                        'Floor 3 Physical Therapy Toilet'
                    ]
            }

        ]

      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        system_to_space_map = [
            {
                'type' => 'PVAV',
                'name' => 'PVAV Outpatient F1',
                'space_names' => [
                    'Floor 1 Anesthesia', 'Floor 1 Bio Haz', 'Floor 1 Cafe', 'Floor 1 Clean', 'Floor 1 Clean Work', 'Floor 1 Dictation',
                    'Floor 1 Dressing Room', 'Floor 1 Humid', 'Floor 1 IT Hall',
                    'Floor 1 IT Room', 'Floor 1 Lobby', 'Floor 1 Lobby Hall', 'Floor 1 Locker Room',
                    'Floor 1 Locker Room Hall', 'Floor 1 Lounge', 'Floor 1 Med Gas', 'Floor 1 MRI Control Room', 'Floor 1 MRI Hall',
                    'Floor 1 MRI Room', 'Floor 1 Nourishment', 'Floor 1 Nurse Hall',
                    'Floor 1 Nurse Station', 'Floor 1 Office', 'Floor 1 Operating Room 1', 'Floor 1 Operating Room 2',
                    'Floor 1 Operating Room 3', 'Floor 1 PACU', 'Floor 1 Pre-Op Hall', 'Floor 1 Pre-Op Room 1', 'Floor 1 Pre-Op Room 2',
                    'Floor 1 Procedure Room', 'Floor 1 Reception', 'Floor 1 Reception Hall', 'Floor 1 Recovery Room',
                    'Floor 1 Scheduling', 'Floor 1 Scrub', 'Floor 1 Soil', 'Floor 1 Soil Hold', 'Floor 1 Soil Work', 'Floor 1 Step Down',
                    'Floor 1 Sterile Hall', 'Floor 1 Sterile Storage', 'Floor 1 Sub-Sterile', 'Floor 1 Utility Hall',
                    'Floor 1 Vestibule'
                ]
            },
            {
                'type' => 'PVAV',
                'name' => 'PVAV Outpatient F2 F3',
                'space_names' => [
                    'Floor 2 Conference', 'Floor 2 Dictation', 'Floor 2 Exam 1', 'Floor 2 Exam 2',
                    'Floor 2 Exam 3', 'Floor 2 Exam 4', 'Floor 2 Exam 5', 'Floor 2 Exam 6', 'Floor 2 Exam 7', 'Floor 2 Exam 8',
                    'Floor 2 Exam 9', 'Floor 2 Exam Hall 1', 'Floor 2 Exam Hall 2', 'Floor 2 Exam Hall 3', 'Floor 2 Exam Hall 4',
                    'Floor 2 Exam Hall 5', 'Floor 2 Exam Hall 6', 'Floor 2 Lounge', 'Floor 2 Nurse Station 1',
                    'Floor 2 Nurse Station 2', 'Floor 2 Office', 'Floor 2 Office Hall', 'Floor 2 Reception', 'Floor 2 Reception Hall',
                    'Floor 2 Scheduling 1', 'Floor 2 Scheduling 2',
                    'Floor 2 Work', 'Floor 2 Work Hall', 'Floor 2 X-Ray',
                    'Floor 3 Dressing Room', 'Floor 3 Elevator Hall', 'Floor 3 Humid', 'Floor 3 Locker', 'Floor 3 Lounge',
                    'Floor 3 Mechanical Hall', 'Floor 3 Office', 'Floor 3 Office Hall',
                    'Floor 3 Physical Therapy 1', 'Floor 3 Physical Therapy 2',
                    'Floor 3 Treatment', 'Floor 3 Work'
                ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Outpatient AHU1 Exhaust Fans',
                'availability_sch_name' => 'OutPatientHealthCare AHU1-Fan_Pre2004',
                'flow_rate' =>
                    [
                        0.068,      # Floor 1 Anesthesia
                        0.0793,     # Floor 1 MRI Control Room
                        0.2077,     # Floor 1 MRI Room
                        0.0991,     # Floor 1 Soil
                        0.044,      # Floor 1 Soil Hold
                        0.1416,     # Floor 1 Soil Work
                    ],
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Floor 1 Anesthesia',
                        'Floor 1 MRI Control Room',
                        'Floor 1 MRI Room',
                        'Floor 1 Soil',
                        'Floor 1 Soil Hold',
                        'Floor 1 Soil Work'
                    ]
            }
        ]
    end

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding HVAC')

    system_to_space_map = PrototypeBuilding::Outpatient.define_hvac_system_map(building_type, template, climate_zone)

    # add elevator for the elevator pump room (the fan&lights are already added via standard spreadsheet)
    PrototypeBuilding::Outpatient.add_extra_equip_elevator_pump_room(template, model)
    # adjust cooling setpoint at vintages 1B,2B,3B
    PrototypeBuilding::Outpatient.adjust_clg_setpoint(template, climate_zone, model)
    # Get the hot water loop
    hot_water_loop = nil
    model.getPlantLoops.each do |loop|
      # If it has a boiler:hotwater, it is the correct loop
      unless loop.supplyComponents('OS:Boiler:HotWater'.to_IddObjectType).empty?
        hot_water_loop = loop
      end
    end
    # add humidifier to AHU1 (contains operating room 1)
    if hot_water_loop
      PrototypeBuilding::Outpatient.add_humidifier(template, hot_water_loop, model)
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Could not find hot water loop to attach humidifier to.')
    end
    # adjust infiltration for vintages 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
    PrototypeBuilding::Outpatient.adjust_infiltration(template, model)
    # add door infiltration for vertibule
    PrototypeBuilding::Outpatient.add_door_infiltration(template, climate_zone, model)
    # reset boiler sizing factor to 0.3 (default 1)
    PrototypeBuilding::Outpatient.reset_boiler_sizing_factor(model)
    # assign the minimum total air changes to the cooling minimum air flow in Sizing:Zone
    PrototypeBuilding::Outpatient.apply_minimum_total_ach(building_type, template, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding HVAC')

    return true
  end

  def self.add_extra_equip_elevator_pump_room(template, model)
    elevator_pump_room = model.getSpaceByName('Floor 1 Elevator Pump Room').get
    elec_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def.setName('Elevator Pump Room Electric Equipment Definition')
    elec_equip_def.setFractionLatent(0)
    elec_equip_def.setFractionRadiant(0.1)
    elec_equip_def.setFractionLost(0.9)
    elec_equip_def.setDesignLevel(48_165)
    elec_equip = OpenStudio::Model::ElectricEquipment.new(elec_equip_def)
    elec_equip.setName('Elevator Pump Room Elevator Equipment')
    elec_equip.setSpace(elevator_pump_room)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip.setSchedule(model.add_schedule('OutPatientHealthCare BLDG_ELEVATORS'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip.setSchedule(model.add_schedule('OutPatientHealthCare BLDG_ELEVATORS_Pre2004'))
    end
    return true
  end

  def self.adjust_clg_setpoint(template, climate_zone, model)
    model.getSpaceTypes.sort.each do |space_type|
      space_type_name = space_type.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010'
          case climate_zone
            when 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-3B'
              thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('OutPatientHealthCare CLGSETP_SCH_YES_OPTIMUM'))
          end
      end
    end
    return true
  end

  def self.adjust_infiltration(template, model)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getSpaces.sort.each do |space|
          space_type = space.spaceType.get
          # Skip interior spaces
          next if space.exterior_wall_and_window_area <= 0
          # Skip spaces that have no infiltration objects to adjust
          next if space_type.spaceInfiltrationDesignFlowRates.size <= 0

          # get the infiltration information from the space type infiltration
          infiltration_space_type = space_type.spaceInfiltrationDesignFlowRates[0]
          infil_sch = infiltration_space_type.schedule.get
          infil_rate = nil
          infil_ach = nil
          if infiltration_space_type.flowperExteriorWallArea.is_initialized
            infil_rate = infiltration_space_type.flowperExteriorWallArea.get
          elsif infiltration_space_type.airChangesperHour.is_initialized
            infil_ach = infiltration_space_type.airChangesperHour.get
          end
          # Create an infiltration rate object for this space
          infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
          infiltration.setName("#{space.name} Infiltration")
          infiltration.setFlowperExteriorSurfaceArea(infil_rate) unless infil_rate.nil? || infil_rate.to_f.zero?
          infiltration.setAirChangesperHour(infil_ach) unless infil_ach.nil? || infil_ach.to_f.zero?
          infiltration.setSchedule(infil_sch)
          infiltration.setSpace(space)
        end
        model.getSpaceTypes.each do |space_type|
          space_type.spaceInfiltrationDesignFlowRates.each(&:remove)
        end
      else
        return true
    end
  end

  def self.add_door_infiltration(template, climate_zone, model)
    # add extra infiltration for vestibule door
    case template
      when 'DOE Ref 1980-2004', 'DOE Ref Pre-1980'
        return true
      else
        vestibule_space = model.getSpaceByName('Floor 1 Vestibule').get
        infiltration_vestibule_door = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_vestibule_door.setName('Vestibule door Infiltration')
        infiltration_rate_vestibule_door = 0
        case template
          when '90.1-2004'
            infiltration_rate_vestibule_door = 1.186002811
            infiltration_vestibule_door.setSchedule(model.add_schedule('OutPatientHealthCare INFIL_Door_Opening_SCH_0.144'))
          when '90.1-2007', '90.1-2010', '90.1-2013'
            case climate_zone
              when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B'
                infiltration_rate_vestibule_door = 1.186002811
                infiltration_vestibule_door.setSchedule(model.add_schedule('OutPatientHealthCare INFIL_Door_Opening_SCH_0.144'))
              else
                infiltration_rate_vestibule_door = 0.776824762
                infiltration_vestibule_door.setSchedule(model.add_schedule('OutPatientHealthCare INFIL_Door_Opening_SCH_0.131'))
            end
        end
        infiltration_vestibule_door.setDesignFlowRate(infiltration_rate_vestibule_door)
        infiltration_vestibule_door.setSpace(vestibule_space)
    end
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          if water_heater.name.to_s.include?('Booster')
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.053159296)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.053159296)
          else
            water_heater.setOffCycleLossCoefficienttoAmbientTemperature(9.643286505)
            water_heater.setOnCycleLossCoefficienttoAmbientTemperature(9.643286505)
          end
        end
    end
  end

  # add humidifier to AHU1 (contains operating room1)
  def self.add_humidifier(template, hot_water_loop, model)
    operatingroom1_space = model.getSpaceByName('Floor 1 Operating Room 1').get
    operatingroom1_zone = operatingroom1_space.thermalZone.get
    humidistat = OpenStudio::Model::ZoneControlHumidistat.new(model)
    humidistat.setHumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('OutPatientHealthCare MinRelHumSetSch'))
    humidistat.setDehumidifyingRelativeHumiditySetpointSchedule(model.add_schedule('OutPatientHealthCare MaxRelHumSetSch'))
    operatingroom1_zone.setZoneControlHumidistat(humidistat)
    model.getAirLoopHVACs.each do |air_loop|
      if air_loop.thermalZones.include? operatingroom1_zone
        humidifier = OpenStudio::Model::HumidifierSteamElectric.new(model)
        humidifier.setRatedCapacity(3.72E-5)
        humidifier.setRatedPower(100_000)
        humidifier.setName("#{air_loop.name.get} Electric Steam Humidifier")
        # get the water heating coil and add humidifier to the outlet of heating coil (right before fan)
        htg_coil = nil
        air_loop.supplyComponents.each do |equip|
          if equip.to_CoilHeatingWater.is_initialized
            htg_coil = equip.to_CoilHeatingWater.get
          end
        end
        heating_coil_outlet_node = htg_coil.airOutletModelObject.get.to_Node.get
        supply_outlet_node = air_loop.supplyOutletNode
        humidifier.addToNode(heating_coil_outlet_node)
        humidity_spm = OpenStudio::Model::SetpointManagerSingleZoneHumidityMinimum.new(model)
        case template
          when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
            extra_elec_htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model, model.alwaysOnDiscreteSchedule)
            extra_elec_htg_coil.setName('AHU1 extra Electric Htg Coil')
            extra_water_htg_coil = OpenStudio::Model::CoilHeatingWater.new(model, model.alwaysOnDiscreteSchedule)
            extra_water_htg_coil.setName('AHU1 extra Water Htg Coil')
            hot_water_loop.addDemandBranchForComponent(extra_water_htg_coil)
            extra_elec_htg_coil.addToNode(supply_outlet_node)
            extra_water_htg_coil.addToNode(supply_outlet_node)
        end
        # humidity_spm.addToNode(supply_outlet_node)
        humidity_spm.addToNode(humidifier.outletModelObject.get.to_Node.get)
        humidity_spm.setControlZone(operatingroom1_zone)
      end
    end
  end

  # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
  # AHU1 doesn't have economizer
  def self.modify_oa_controller(template, model)
    model.getAirLoopHVACs.each do |air_loop|
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir
      controller_mv = controller_oa.controllerMechanicalVentilation
      # AHU1 OA doesn't have controller:mechanicalventilation
      if air_loop.name.to_s.include? 'Outpatient F1'
        controller_mv.setAvailabilitySchedule(model.alwaysOffDiscreteSchedule)
        # add minimum fraction of outdoor air schedule to AHU1
        controller_oa.setMinimumFractionofOutdoorAirSchedule(model.add_schedule('OutPatientHealthCare AHU-1_OAminOAFracSchedule'))
        # for AHU2, at vintages '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', the minimum OA schedule is not the same as
        # airloop availability schedule, but separately assigned.
      elsif template == '90.1-2004' || template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013'
        controller_oa.setMinimumOutdoorAirSchedule(model.add_schedule('OutPatientHealthCare BLDG_OA_SCH'))
        # add minimum fraction of outdoor air schedule to AHU2
        controller_oa.setMinimumFractionofOutdoorAirSchedule(model.add_schedule('OutPatientHealthCare BLDG_OA_FRAC_SCH'))
      end
    end
  end

  # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
  def self.reset_or_room_vav_minimum_damper(prototype_input, template, model)
    case template
      when '90.1-2004', '90.1-2007'
        return true
      when '90.1-2010', '90.1-2013'
        model.getAirTerminalSingleDuctVAVReheats.sort.each do |airterminal|
          airterminal_name = airterminal.name.get
          if airterminal_name.include?('Floor 1 Operating Room 1') || airterminal_name.include?('Floor 1 Operating Room 2')
            airterminal.setZoneMinimumAirFlowMethod('Scheduled')
            airterminal.setMinimumAirFlowFractionSchedule(model.add_schedule('OutPatientHealthCare OR_MinSA_Sched'))
          end
        end
    end
  end

  def self.reset_boiler_sizing_factor(model)
    model.getBoilerHotWaters.sort.each do |boiler|
      boiler.setSizingFactor(0.3)
    end
  end

  def self.update_exhaust_fan_efficiency(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          fan_name = exhaust_fan.name.to_s
          if (fan_name.include? 'X-Ray') || (fan_name.include? 'MRI Room')
            exhaust_fan.setFanEfficiency(0.16)
            exhaust_fan.setPressureRise(125)
          else
            exhaust_fan.setFanEfficiency(0.31)
            exhaust_fan.setPressureRise(249)
          end
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(0.338)
          exhaust_fan.setPressureRise(125)
        end
    end
  end

  # assign the minimum total air changes to the cooling minimum air flow in Sizing:Zone
  def self.apply_minimum_total_ach(building_type, template, model)
    model.getSpaces.each do |space|
      space_type_name = space.spaceType.get.standardsSpaceType.get
      search_criteria = {
          'template' => template,
          'building_type' => building_type,
          'space_type' => space_type_name
      }
      data = model.find_object($os_standards['space_types'], search_criteria)

      # skip space type without minimum total air changes
      next if data['minimum_total_air_changes'].nil?

      # calculate the minimum total air flow
      minimum_total_ach = data['minimum_total_air_changes'].to_f
      space_volume = space.volume
      space_area = space.floorArea
      minimum_airflow_per_zone = minimum_total_ach * space_volume / 3600
      minimum_airflow_per_zone_floor_area = minimum_airflow_per_zone / space_area
      # add minimum total air flow limit to sizing:zone
      zone = space.thermalZone.get
      sizingzone = zone.sizingZone
      sizingzone.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
      case template
        when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
          sizingzone.setCoolingMinimumAirFlow(minimum_airflow_per_zone)
        when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
          sizingzone.setCoolingMinimumAirFlowperZoneFloorArea(minimum_airflow_per_zone_floor_area)
      end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::Outpatient.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
module PrimarySchool
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
      when 'NECB 2011'
        sch = 'D'
        space_type_map = {
            "Washroom-sch-#{sch}" => ['Bath_ZN_1_FLR_1'],
            'Conf./meet./multi-purpose' => ['Cafeteria_ZN_1_FLR_1'],
            'Classroom/lecture/training' => ['Computer_Class_ZN_1_FLR_1','Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Corner_Class_1_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_1'],
            "Corr. >= 2.4m wide-sch-#{sch}" => ['Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_1', 'Main_Corridor_ZN_1_FLR_1'],
            'Gym - play' => ['Gym_ZN_1_FLR_1'],
            'Food preparation' => ['Kitchen_ZN_1_FLR_1'],
            'Library - reading' => ['Library_Media_Center_ZN_1_FLR_1'],
            'Lobby - elevator' => ['Lobby_ZN_1_FLR_1'],
            "Electrical/Mechanical-sch-#{sch}" => ['Mech_ZN_1_FLR_1'],
            'Office - enclosed' => ['Offices_ZN_1_FLR_1']
        }
      else
        space_type_map = {
            'Office' => ['Offices_ZN_1_FLR_1'],
            'Lobby' => ['Lobby_ZN_1_FLR_1'],
            'Gym' => ['Gym_ZN_1_FLR_1'],
            'Mechanical' => ['Mech_ZN_1_FLR_1'],
            'Cafeteria' => ['Cafeteria_ZN_1_FLR_1'],
            'Kitchen' => ['Kitchen_ZN_1_FLR_1'],
            'Restroom' => ['Bath_ZN_1_FLR_1', 'Bathrooms_ZN_1_FLR_1'],
            'Corridor' => ['Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_1', 'Main_Corridor_ZN_1_FLR_1'],
            'Classroom' => ['Computer_Class_ZN_1_FLR_1', 'Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Corner_Class_1_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Library_Media_Center_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_1']
        }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = nil

    system_to_space_map = [
        {
            'type' => 'PVAV',
            'name' => 'PVAV_POD_1',
            'space_names' =>
                ['Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_1']
        },
        {
            'type' => 'PVAV',
            'name' => 'PVAV_POD_2',
            'space_names' =>
                ['Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_2_ZN_1_FLR_1']
        },
        {
            'type' => 'PVAV',
            'name' => 'PVAV_POD_3',
            'space_names' =>
                ['Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_1']
        },
        {
            'type' => 'PVAV',
            'name' => 'PVAV_OTHER',
            'space_names' =>
                ['Computer_Class_ZN_1_FLR_1', 'Main_Corridor_ZN_1_FLR_1', 'Lobby_ZN_1_FLR_1', 'Mech_ZN_1_FLR_1', 'Bath_ZN_1_FLR_1', 'Offices_ZN_1_FLR_1', 'Library_Media_Center_ZN_1_FLR_1']
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_1-6',
            'space_names' =>
                [
                    'Kitchen_ZN_1_FLR_1'
                ]
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_2-5',
            'space_names' =>
                [
                    'Gym_ZN_1_FLR_1'
                ]
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_2-7',
            'space_names' =>
                [
                    'Cafeteria_ZN_1_FLR_1'
                ]
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Kitchen Exhaust Fan',
            'availability_sch_name' => 'SchoolPrimary Kitchen_Exhaust_SCH',
            'flow_rate' => OpenStudio.convert(4500, 'cfm', 'm^3/s').get,
            'flow_fraction_schedule_name' => 'SchoolSecondary Kitchen_Exhaust_SCH_DCV',
            'balanced_exhaust_fraction_schedule_name' => 'SchoolSecondary Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule',
            'space_names' =>
                [
                    'Kitchen_ZN_1_FLR_1'
                ]
        },
        {
            'type' => 'Exhaust Fan',
            'name' => 'Bathrooms_ZN_1_FLR_1',
            'availability_sch_name' => 'SchoolPrimary Hours_of_operation',
            'flow_rate' => OpenStudio.convert(600, 'cfm', 'm^3/s').get,
            'space_names' =>
                [
                    'Bath_ZN_1_FLR_1'
                ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Walkin Freezer',
            'cooling_capacity_per_length' => 734.0,
            'length' => 3.66,
            'evaporator_fan_pwr_per_length' => 68.3,
            'lighting_per_length' => 33.0,
            'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
            'defrost_pwr_per_length' => 410.0,
            'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
            'cop' => 1.5,
            'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
            'condenser_fan_pwr' => 750.0,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
                [
                    'Kitchen_ZN_1_FLR_1'
                ]
        },
        {
            'type' => 'Refrigeration',
            'case_type' => 'Display Case',
            'cooling_capacity_per_length' => 734.0,
            'length' => 3.66,
            'evaporator_fan_pwr_per_length' => 55.0,
            'lighting_per_length' => 33.0,
            'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
            'defrost_pwr_per_length' => 0.0,
            'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
            'cop' => 3.0,
            'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
            'condenser_fan_pwr' => 750.0,
            'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
            'space_names' =>
                [
                    'Kitchen_ZN_1_FLR_1'
                ]
        }
    ]

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end
module QuickServiceRestaurant
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
      when 'DOE Ref Pre-1980'
        space_type_map = {
            'Dining' => ['Dining'],
            'Kitchen' => ['Kitchen']
        }
      when 'DOE Ref 1980-2004', '90.1-2010', '90.1-2007', '90.1-2004', '90.1-2013'
        space_type_map = {
            'Dining' => ['Dining'],
            'Kitchen' => ['Kitchen'],
            'Attic' => ['attic']
        }
      when 'NECB 2011'
        # dom = B
        space_type_map = {
            '- undefined -' => ['attic'],
            'Dining - bar lounge/leisure' => ['Dining'],
            'Food preparation' => ['Kitchen']
        }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantFastFood HVACOperationSchd',
                'flow_rate' => 0.834532374,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantFastFood HVACOperationSchd',
                'flow_rate' => 0.722467626,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 74,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'QuickServiceRestaurant Bldg Light',
                'defrost_pwr_per_length' => 1291.7,
                'restocking_sch_name' => 'RestaurantFastFood Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 66,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'QuickServiceRestaurant Bldg Light',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantFastFood Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]
      when '90.1-2004'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantFastFood Hours_of_operation',
                'flow_rate' => 1.557427,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => 'RestaurantFastFood Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule_2004',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantFastFood Hours_of_operation',
                'flow_rate' => 0.826233,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 74,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'RestaurantFastFood BLDG_LIGHT_DINING_SCH_2004_2007',
                'defrost_pwr_per_length' => 1291.7,
                'restocking_sch_name' => 'RestaurantFastFood Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 66,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'RestaurantFastFood BLDG_LIGHT_DINING_SCH_2004_2007',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantFastFood Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]
      when '90.1-2007', '90.1-2010'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantFastFood Hours_of_operation',
                'flow_rate' => 1.557427,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => 'RestaurantFastFood Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule_2007_2010_2013',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantFastFood Hours_of_operation',
                'flow_rate' => 0.416,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 74,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'RestaurantFastFood BLDG_LIGHT_DINING_SCH_2004_2007',
                'defrost_pwr_per_length' => 1291.7,
                'restocking_sch_name' => 'RestaurantFastFood Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 66,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'RestaurantFastFood BLDG_LIGHT_DINING_SCH_2004_2007',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantFastFood Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]
      when '90.1-2013'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'space_names' => ['Dining', 'Kitchen']
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'RestaurantFastFood Hours_of_operation',
                'flow_rate' => 1.557427,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => 'RestaurantFastFood Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule_2007_2010_2013',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Dining Exhaust Fan',
                'availability_sch_name' => 'RestaurantFastFood Hours_of_operation',
                'flow_rate' => 0.416,
                'flow_fraction_schedule_name' => nil,
                'balanced_exhaust_fraction_schedule_name' => nil,
                'space_names' =>
                    [
                        'Dining'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 688,
                'length' => 2.44,
                'evaporator_fan_pwr_per_length' => 21.143,
                'lighting_per_length' => 33,
                'lighting_sch_name' => 'RestaurantFastFood walkin_occ_lght_SCH',
                'defrost_pwr_per_length' => 1291.7,
                'restocking_sch_name' => 'RestaurantFastFood Kitchen_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 3.05,
                'evaporator_fan_pwr_per_length' => 18.857,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'RestaurantFastFood walkin_occ_lght_SCH',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'RestaurantFastFood Kitchen_Case:2_SELFCONTAINEDDISPLAYCASE_CaseStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 330,
                'condenser_fan_pwr_curve_name' => nil,
                'space_names' =>
                    [
                        'Kitchen'
                    ]
            }
        ]
    end

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add extra equipment for kitchen
    PrototypeBuilding::QuickServiceRestaurant.add_extra_equip_kitchen(template, model)
    # add extra infiltration for dining room door and attic
    PrototypeBuilding::QuickServiceRestaurant.add_door_infiltration(template, climate_zone, model)
    # add zone_mixing between kitchen and dining
    PrototypeBuilding::QuickServiceRestaurant.add_zone_mixing(template, model)
    # Update Sizing Zone
    PrototypeBuilding::QuickServiceRestaurant.update_sizing_zone(template, model)
    # adjust the cooling setpoint
    PrototypeBuilding::QuickServiceRestaurant.adjust_clg_setpoint(template, climate_zone, model)
    # reset the design OA of kitchen
    PrototypeBuilding::QuickServiceRestaurant.reset_kitchen_oa(template, model)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def self.add_door_infiltration(template, climate_zone, model)
    # add extra infiltration for dining room door and attic (there is no attic in 'DOE Ref Pre-1980')
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      dining_space = model.getSpaceByName('Dining').get
      attic_space = model.getSpaceByName('Attic').get
      infiltration_diningdoor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_attic = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_diningdoor.setName('Dining door Infiltration')
      infiltration_per_zone_diningdoor = 0
      infiltration_per_zone_attic = 0.0729
      if template == '90.1-2004'
        infiltration_per_zone_diningdoor = 0.902834611
        infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood DOOR_INFIL_SCH'))
      elsif template == '90.1-2007'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B',
              'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C'
            infiltration_per_zone_diningdoor = 0.902834611
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.583798439
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood VESTIBULE_DOOR_INFIL_SCH'))
        end
      elsif template == '90.1-2010' || template == '90.1-2013'
        case climate_zone
          when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C'
            infiltration_per_zone_diningdoor = 0.902834611
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood DOOR_INFIL_SCH'))
          else
            infiltration_per_zone_diningdoor = 0.583798439
            infiltration_diningdoor.setSchedule(model.add_schedule('RestaurantFastFood VESTIBULE_DOOR_INFIL_SCH'))
        end
      end
      infiltration_diningdoor.setDesignFlowRate(infiltration_per_zone_diningdoor)
      infiltration_diningdoor.setSpace(dining_space)
      infiltration_attic.setDesignFlowRate(infiltration_per_zone_attic)
      infiltration_attic.setSchedule(model.add_schedule('Always On'))
      infiltration_attic.setSpace(attic_space)
    end
  end

  # add extra equipment for kitchen
  def self.add_extra_equip_kitchen(template, model)
    kitchen_space = model.getSpaceByName('Kitchen')
    kitchen_space = kitchen_space.get
    kitchen_space_type = kitchen_space.spaceType.get
    elec_equip_def1 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    elec_equip_def1.setName('Kitchen Electric Equipment Definition1')
    elec_equip_def2.setName('Kitchen Electric Equipment Definition2')
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0.25)
        elec_equip_def1.setFractionLost(0)
        elec_equip_def2.setFractionLatent(0)
        elec_equip_def2.setFractionRadiant(0.25)
        elec_equip_def2.setFractionLost(0)
        if template == '90.1-2013'
          elec_equip_def1.setDesignLevel(457.5)
          elec_equip_def2.setDesignLevel(570)
        else
          elec_equip_def1.setDesignLevel(515.917)
          elec_equip_def2.setDesignLevel(851.67)
        end
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip2 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def2)
        elec_equip1.setName('Kitchen_Reach-in-Freezer')
        elec_equip2.setName('Kitchen_Reach-in-Refrigerator')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip2.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('RestaurantFastFood ALWAYS_ON'))
        elec_equip2.setSchedule(model.add_schedule('RestaurantFastFood ALWAYS_ON'))
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        elec_equip_def1.setDesignLevel(577)
        elec_equip_def1.setFractionLatent(0)
        elec_equip_def1.setFractionRadiant(0)
        elec_equip_def1.setFractionLost(1)
        # Create the electric equipment instance and hook it up to the space type
        elec_equip1 = OpenStudio::Model::ElectricEquipment.new(elec_equip_def1)
        elec_equip1.setName('Kitchen_ExhFan_Equip')
        elec_equip1.setSpaceType(kitchen_space_type)
        elec_equip1.setSchedule(model.add_schedule('RestaurantFastFood Kitchen_Exhaust_SCH'))
    end
  end

  def self.update_sizing_zone(template, model)
    case template
      when '90.1-2007', '90.1-2010', '90.1-2013'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.003581176)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
      when '90.1-2004'
        zone_sizing = model.getSpaceByName('Dining').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0.007111554)
        zone_sizing = model.getSpaceByName('Kitchen').get.thermalZone.get.sizingZone
        zone_sizing.setCoolingDesignAirFlowMethod('DesignDayWithLimit')
        zone_sizing.setCoolingMinimumAirFlowperZoneFloorArea(0)
    end
  end

  def self.adjust_clg_setpoint(template, climate_zone, model)
    ['Dining', 'Kitchen'].each do |space_name|
      space_type_name = model.getSpaceByName(space_name).get.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name).get
      case template
        when '90.1-2004', '90.1-2007', '90.1-2010'
          if climate_zone == 'ASHRAE 169-2006-2B' || climate_zone == 'ASHRAE 169-2006-1B' || climate_zone == 'ASHRAE 169-2006-3B'
            case space_name
              when 'Dining'
                thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('RestaurantFastFood CLGSETP_SCH_NO_OPTIMUM'))
              when 'Kitchen'
                thermostat.setCoolingSetpointTemperatureSchedule(model.add_schedule('RestaurantFastFood CLGSETP_KITCHEN_SCH_NO_OPTIMUM'))
            end
          end
      end
    end
  end

  # In order to provide sufficient OSA to replace exhaust flow through kitchen hoods (3,300 cfm),
  # modeled OSA to kitchen is different from OSA determined based on ASHRAE  62.1.
  # It takes into account the available OSA in dining as transfer air.
  def self.reset_kitchen_oa(template, model)
    space_kitchen = model.getSpaceByName('Kitchen').get
    ventilation = space_kitchen.designSpecificationOutdoorAir.get
    ventilation.setOutdoorAirFlowperPerson(0)
    ventilation.setOutdoorAirFlowperFloorArea(0)
    case template
      when '90.1-2007', '90.1-2010', '90.1-2013'
        ventilation.setOutdoorAirFlowRate(1.14135966)
      when '90.1-2004', 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        ventilation.setOutdoorAirFlowRate(0.7312)
    end
  end

  def self.update_exhaust_fan_efficiency(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          fan_name = exhaust_fan.name.to_s
          if fan_name.include? 'Dining'
            exhaust_fan.setFanEfficiency(1)
            exhaust_fan.setPressureRise(0)
          end
        end
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        model.getFanZoneExhausts.sort.each do |exhaust_fan|
          exhaust_fan.setFanEfficiency(1)
          exhaust_fan.setPressureRise(0.000001)
        end
    end
  end

  def self.add_zone_mixing(template, model)
    # add zone_mixing between kitchen and dining
    space_kitchen = model.getSpaceByName('Kitchen').get
    zone_kitchen = space_kitchen.thermalZone.get
    space_dining = model.getSpaceByName('Dining').get
    zone_dining = space_dining.thermalZone.get
    zone_mixing_kitchen = OpenStudio::Model::ZoneMixing.new(zone_kitchen)
    zone_mixing_kitchen.setSchedule(model.add_schedule('RestaurantFastFood Hours_of_operation'))
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        zone_mixing_kitchen.setDesignFlowRate(0.834532374)
      when '90.1-2007', '90.1-2010', '90.1-2013'
        zone_mixing_kitchen.setDesignFlowRate(0.416067345)
      when '90.1-2004'
        zone_mixing_kitchen.setDesignFlowRate(0.826232888)
    end
    zone_mixing_kitchen.setSourceZone(zone_dining)
    zone_mixing_kitchen.setDeltaTemperature(0)
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(7.561562668)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(7.561562668)
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::QuickServiceRestaurant.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
module RetailStandalone
  # TODO: The ElectricEquipment schedules are wrong in OpenStudio Standards... It needs to be 'RetailStandalone BLDG_EQUIP_SCH' for 90.1-2010 at least but probably all
  # TODO: There is an OpenStudio bug where two heat exchangers are on the equipment list and it references the same single heat exchanger for both. This doubles the heat recovery energy.
  # TODO: The HeatExchangerAirToAir is not calculating correctly. It does not equal the legacy IDF and has higher energy usage due to that.
  # TODO: Need to determine if WaterHeater can be alone or if we need to 'fake' it.

  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template
      when 'NECB 2011'
        sch = 'C'
        space_type_map = {
            'Storage area' => ['Back_Space'],
            'Retail - sales' => ['Core_Retail', 'Front_Retail', 'Point_Of_Sale'],
            'Lobby - elevator' => ['Front_Entry']
        }

      else
        space_type_map = {
            'Back_Space' => ['Back_Space'],
            'Entry' => ['Front_Entry'],
            'Point_of_Sale' => ['Point_Of_Sale'],
            'Retail' => ['Core_Retail', 'Front_Retail']
        }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
        {
            'type' => 'PSZ-AC',
            'space_names' => ['Back_Space', 'Core_Retail', 'Point_Of_Sale', 'Front_Retail']
        },
        {
            'type' => 'UnitHeater',
            'space_names' => ['Front_Entry']
        }
    ]
    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # Add the door infiltration for template 2004,2007,2010,2013
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        entry_space = model.getSpaceByName('Front_Entry').get
        infiltration_entry = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
        infiltration_entry.setName('Entry door Infiltration')
        infiltration_per_zone = 1.418672682
        infiltration_entry.setDesignFlowRate(infiltration_per_zone)
        infiltration_entry.setSchedule(model.add_schedule('RetailStandalone INFIL_Door_Opening_SCH'))
        infiltration_entry.setSpace(entry_space)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(4.10807252)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(4.10807252)
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::RetailStandalone.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
module RetailStripmall
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil
    case template

      when 'NECB 2011'
        sch = 'C'
        space_type_map = {
            'Retail - sales' => ['LGstore1', 'LGstore2', 'SMstore1', 'SMstore2', 'SMstore3', 'SMstore4', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8']
        }
      else
        space_type_map = {
            'Strip mall - type 1' => ['LGstore1', 'SMstore1'],
            'Strip mall - type 2' => ['SMstore2', 'SMstore3', 'SMstore4'],
            'Strip mall - type 3' => ['LGstore2', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8']
        }
    end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_1',
            'space_names' => ['LGSTORE1'],
            'hvac_op_sch_index' => 1
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_2',
            'space_names' => ['SMstore1'],
            'hvac_op_sch_' => 1
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_3',
            'space_names' => ['SMstore2'],
            'hvac_op_sch_index' => 2
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_4',
            'space_names' => ['SMstore3'],
            'hvac_op_sch_index' => 2
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_5',
            'space_names' => ['SMstore4'],
            'hvac_op_sch_index' => 2
        }, {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_6',
            'space_names' => ['LGSTORE2'],
            'hvac_op_sch_index' => 3
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_7',
            'space_names' => ['SMstore5'],
            'hvac_op_sch_index' => 3
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_8',
            'space_names' => ['SMstore6'],
            'hvac_op_sch_index' => 3
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_9',
            'space_names' => ['SMstore7'],
            'hvac_op_sch_index' => 3
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC_10',
            'space_names' => ['SMstore8']
        }
    ]
    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    system_to_space_map = PrototypeBuilding::RetailStripmall.define_hvac_system_map(building_type, template, climate_zone)

    # Add infiltration door opening
    # Spaces names to design infiltration rates (m3/s)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        door_infiltration_map = { ['LGstore1', 'LGstore2'] => 0.388884328,
                                  ['SMstore1', 'SMstore2', 'SMstore3', 'SMstore4', 'SMstore5', 'SMstore6', 'SMstore7', 'SMstore8'] => 0.222287037 }

        door_infiltration_map.each_pair do |space_names, infiltration_design_flowrate|
          space_names.each do |space_name|
            space = model.getSpaceByName(space_name).get
            # Create the infiltration object and hook it up to the space type
            infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
            infiltration.setName("#{space_name} Door Open Infiltration")
            infiltration.setSpace(space)
            infiltration.setDesignFlowRate(infiltration_design_flowrate)
            infiltration_schedule = model.add_schedule('RetailStripmall INFIL_Door_Opening_SCH')
            if infiltration_schedule.nil?
              OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Can't find schedule (RetailStripmall INFIL_Door_Opening_SCH).")
              return false
            else
              infiltration.setSchedule(infiltration_schedule)
            end
          end
        end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')
    return true
  end # add hvac

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(1.205980747)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(1.205980747)
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::RetailStripmall.update_waterheater_loss_coefficient(template, model)

    return true
  end
end
module SecondarySchool
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil

    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        space_type_map = {
            'Office' => ['Offices_ZN_1_FLR_1', 'Offices_ZN_1_FLR_2'],
            'Lobby' => ['Lobby_ZN_1_FLR_2', 'Lobby_ZN_1_FLR_1'],
            'Gym' => ['Gym_ZN_1_FLR_1'],
            'Gym - audience' => ['Aux_Gym_ZN_1_FLR_1'],
            'Mechanical' => ['Mech_ZN_1_FLR_2', 'Mech_ZN_1_FLR_1'],
            'Cafeteria' => ['Cafeteria_ZN_1_FLR_1'],
            'Kitchen' => ['Kitchen_ZN_1_FLR_1'],
            'Restroom' => ['Bathrooms_ZN_1_FLR_2', 'Bathrooms_ZN_1_FLR_1'],
            'Auditorium' => ['Auditorium_ZN_1_FLR_1'],
            'Library' => ['LIBRARY_MEDIA_CENTER_ZN_1_FLR_2'],
            'Corridor' => ['Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_2', 'Main_Corridor_ZN_1_FLR_2', 'Main_Corridor_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_1', 'Corridor_Pod_1_ZN_1_FLR_2', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_2'],
            'Classroom' => ['Mult_Class_2_Pod_2_ZN_1_FLR_2', 'Mult_Class_2_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_2', 'Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_2', 'Corner_Class_1_Pod_2_ZN_1_FLR_2', 'Mult_Class_1_Pod_1_ZN_1_FLR_2', 'Corner_Class_2_Pod_2_ZN_1_FLR_2', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_2', 'Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_2_ZN_1_FLR_2', 'Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Corner_Class_1_Pod_1_ZN_1_FLR_2', 'Corner_Class_1_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_3_ZN_1_FLR_2', 'Mult_Class_1_Pod_3_ZN_1_FLR_2', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_2']
        }
      when 'NECB 2011'
        sch = 'D'
        space_type_map = {
            'Audience - auditorium' => ['Auditorium_ZN_1_FLR_1'],
            'Gym - play' => ['Aux_Gym_ZN_1_FLR_1', 'Gym_ZN_1_FLR_1'],
            "Washroom-sch-#{sch}" => ['Bathrooms_ZN_1_FLR_1', 'Bathrooms_ZN_1_FLR_2'],
            'Conf./meet./multi-purpose' => ['Cafeteria_ZN_1_FLR_1'],
            'Classroom/lecture/training' => ['Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Corner_Class_1_Pod_1_ZN_1_FLR_2', 'Corner_Class_1_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_2_ZN_1_FLR_2', 'Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Corner_Class_1_Pod_3_ZN_1_FLR_2', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_2', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_2', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_2', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_2', 'Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Mult_Class_1_Pod_2_ZN_1_FLR_2', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_2', 'Mult_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_2', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_2_ZN_1_FLR_2', 'Mult_Class_2_Pod_3_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_2'],
            "Corr. >= 2.4m wide-sch-#{sch}" => ['Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_1_ZN_1_FLR_2', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_2', 'Corridor_Pod_3_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_2', 'Main_Corridor_ZN_1_FLR_1', 'Main_Corridor_ZN_1_FLR_2'],
            'Food preparation' => ['Kitchen_ZN_1_FLR_1'],
            'Library - reading' => ['LIBRARY_MEDIA_CENTER_ZN_1_FLR_2'],
            'Lobby - elevator' => ['Lobby_ZN_1_FLR_1', 'Lobby_ZN_1_FLR_2'],
            "Electrical/Mechanical-sch-#{sch}" => ['Mech_ZN_1_FLR_1', 'Mech_ZN_1_FLR_2'],
            'Office - enclosed' => ['Offices_ZN_1_FLR_1', 'Offices_ZN_1_FLR_2']
        }
      else
        space_type_map = {
            'Office' => ['Offices_ZN_1_FLR_1', 'Offices_ZN_1_FLR_2'],
            'Lobby' => ['Lobby_ZN_1_FLR_2', 'Lobby_ZN_1_FLR_1'],
            'Gym' => ['Gym_ZN_1_FLR_1', 'Aux_Gym_ZN_1_FLR_1'],
            'Mechanical' => ['Mech_ZN_1_FLR_2', 'Mech_ZN_1_FLR_1'],
            'Cafeteria' => ['Cafeteria_ZN_1_FLR_1'],
            'Kitchen' => ['Kitchen_ZN_1_FLR_1'],
            'Restroom' => ['Bathrooms_ZN_1_FLR_2', 'Bathrooms_ZN_1_FLR_1'],
            'Auditorium' => ['Auditorium_ZN_1_FLR_1'],
            'Library' => ['LIBRARY_MEDIA_CENTER_ZN_1_FLR_2'],
            'Corridor' => ['Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_2', 'Main_Corridor_ZN_1_FLR_2', 'Main_Corridor_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_1', 'Corridor_Pod_1_ZN_1_FLR_2', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_2'],
            'Classroom' => ['Mult_Class_2_Pod_2_ZN_1_FLR_2', 'Mult_Class_2_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_2', 'Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_2', 'Corner_Class_1_Pod_2_ZN_1_FLR_2', 'Mult_Class_1_Pod_1_ZN_1_FLR_2', 'Corner_Class_2_Pod_2_ZN_1_FLR_2', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_2', 'Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_2_ZN_1_FLR_2', 'Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Corner_Class_1_Pod_1_ZN_1_FLR_2', 'Corner_Class_1_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_3_ZN_1_FLR_2', 'Mult_Class_1_Pod_3_ZN_1_FLR_2', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_2']
        }
    end

    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = nil

    case template
      when 'DOE Ref Pre-1980'
        system_to_space_map = [
            {
                'type' => 'CAV',
                'name' => 'CAV_POD_1',
                'space_names' =>
                    ['Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Corner_Class_1_Pod_1_ZN_1_FLR_2', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_2', 'Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_1_ZN_1_FLR_2', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_2', 'Mult_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_2']
            },
            {
                'type' => 'CAV',
                'name' => 'CAV_POD_2',
                'space_names' =>
                    ['Corner_Class_1_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_2_ZN_1_FLR_2', 'Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Mult_Class_1_Pod_2_ZN_1_FLR_2', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_2', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_2', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_2_ZN_1_FLR_2']
            },
            {
                'type' => 'CAV',
                'name' => 'CAV_POD_3',
                'space_names' =>
                    ['Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Corner_Class_1_Pod_3_ZN_1_FLR_2', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_2', 'Corridor_Pod_3_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_2', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_2', 'Mult_Class_2_Pod_3_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_2']
            },
            {
                'type' => 'CAV',
                'name' => 'CAV_OTHER',
                'space_names' =>
                    ['Main_Corridor_ZN_1_FLR_1', 'Main_Corridor_ZN_1_FLR_2', 'Lobby_ZN_1_FLR_1', 'Lobby_ZN_1_FLR_2', 'Bathrooms_ZN_1_FLR_1', 'Bathrooms_ZN_1_FLR_2', 'Offices_ZN_1_FLR_1', 'Offices_ZN_1_FLR_2', 'LIBRARY_MEDIA_CENTER_ZN_1_FLR_2', 'Mech_ZN_1_FLR_1', 'Mech_ZN_1_FLR_2']
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_1-5',
                'space_names' =>
                    [
                        'Gym_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_2-6',
                'space_names' =>
                    [
                        'Aux_Gym_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_3-7',
                'space_names' =>
                    [
                        'Auditorium_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_4-8',
                'space_names' =>
                    [
                        'Kitchen_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_5-9',
                'space_names' =>
                    [
                        'Cafeteria_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'SchoolSecondary Kitchen_Exhaust_SCH',
                'flow_rate' => OpenStudio.convert(5400, 'cfm', 'm^3/s').get,
                'flow_fraction_schedule_name' => 'SchoolSecondary Kitchen_Exhaust_SCH_DCV',
                'balanced_exhaust_fraction_schedule_name' => 'SchoolSecondary Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule',
                'space_names' =>
                    [
                        'Kitchen_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Bathrooms_ZN_1_FLR_1',
                'availability_sch_name' => 'SchoolSecondary Hours_of_operation',
                'flow_rate' => OpenStudio.convert(600, 'cfm', 'm^3/s').get,
                'space_names' =>
                    [
                        'Bathrooms_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Bathrooms_ZN_1_FLR_2',
                'availability_sch_name' => 'SchoolSecondary Hours_of_operation',
                'flow_rate' => OpenStudio.convert(600, 'cfm', 'm^3/s').get,
                'space_names' =>
                    [
                        'Bathrooms_ZN_1_FLR_2'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 734.0,
                'length' => 7.32,
                'evaporator_fan_pwr_per_length' => 68.3,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
                'defrost_pwr_per_length' => 410.0,
                'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 750.0,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 7.32,
                'evaporator_fan_pwr_per_length' => 55.0,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 750.0,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen_ZN_1_FLR_1'
                    ]
            }
        ]
      else
        system_to_space_map = [
            {
                'type' => 'VAV',
                'name' => 'VAV_POD_1',
                'space_names' =>
                    ['Corner_Class_1_Pod_1_ZN_1_FLR_1', 'Corner_Class_1_Pod_1_ZN_1_FLR_2', 'Mult_Class_1_Pod_1_ZN_1_FLR_1', 'Mult_Class_1_Pod_1_ZN_1_FLR_2', 'Corridor_Pod_1_ZN_1_FLR_1', 'Corridor_Pod_1_ZN_1_FLR_2', 'Corner_Class_2_Pod_1_ZN_1_FLR_1', 'Corner_Class_2_Pod_1_ZN_1_FLR_2', 'Mult_Class_2_Pod_1_ZN_1_FLR_1', 'Mult_Class_2_Pod_1_ZN_1_FLR_2']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_POD_2',
                'space_names' =>
                    ['Corner_Class_1_Pod_2_ZN_1_FLR_1', 'Corner_Class_1_Pod_2_ZN_1_FLR_2', 'Mult_Class_1_Pod_2_ZN_1_FLR_1', 'Mult_Class_1_Pod_2_ZN_1_FLR_2', 'Corridor_Pod_2_ZN_1_FLR_1', 'Corridor_Pod_2_ZN_1_FLR_2', 'Corner_Class_2_Pod_2_ZN_1_FLR_1', 'Corner_Class_2_Pod_2_ZN_1_FLR_2', 'Mult_Class_2_Pod_2_ZN_1_FLR_1', 'Mult_Class_2_Pod_2_ZN_1_FLR_2']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_POD_3',
                'space_names' =>
                    ['Corner_Class_1_Pod_3_ZN_1_FLR_1', 'Corner_Class_1_Pod_3_ZN_1_FLR_2', 'Mult_Class_1_Pod_3_ZN_1_FLR_1', 'Mult_Class_1_Pod_3_ZN_1_FLR_2', 'Corridor_Pod_3_ZN_1_FLR_1', 'Corridor_Pod_3_ZN_1_FLR_2', 'Corner_Class_2_Pod_3_ZN_1_FLR_1', 'Corner_Class_2_Pod_3_ZN_1_FLR_2', 'Mult_Class_2_Pod_3_ZN_1_FLR_1', 'Mult_Class_2_Pod_3_ZN_1_FLR_2']
            },
            {
                'type' => 'VAV',
                'name' => 'VAV_OTHER',
                'space_names' =>
                    ['Main_Corridor_ZN_1_FLR_1', 'Main_Corridor_ZN_1_FLR_2', 'Lobby_ZN_1_FLR_1', 'Lobby_ZN_1_FLR_2', 'Bathrooms_ZN_1_FLR_1', 'Bathrooms_ZN_1_FLR_2', 'Offices_ZN_1_FLR_1', 'Offices_ZN_1_FLR_2', 'LIBRARY_MEDIA_CENTER_ZN_1_FLR_2', 'Mech_ZN_1_FLR_1', 'Mech_ZN_1_FLR_2']
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_1-5',
                'space_names' =>
                    [
                        'Gym_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_2-6',
                'space_names' =>
                    [
                        'Aux_Gym_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_3-7',
                'space_names' =>
                    [
                        'Auditorium_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_4-8',
                'space_names' =>
                    [
                        'Kitchen_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'PSZ-AC_5-9',
                'space_names' =>
                    [
                        'Cafeteria_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Kitchen Exhaust Fan',
                'availability_sch_name' => 'SchoolSecondary Kitchen_Exhaust_SCH',
                'flow_rate' => OpenStudio.convert(5400, 'cfm', 'm^3/s').get,
                'flow_fraction_schedule_name' => 'SchoolSecondary Kitchen_Exhaust_SCH_DCV',
                'balanced_exhaust_fraction_schedule_name' => 'SchoolSecondary Kitchen Exhaust Fan Balanced Exhaust Fraction Schedule',
                'space_names' =>
                    [
                        'Kitchen_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Bathrooms_ZN_1_FLR_1',
                'availability_sch_name' => 'SchoolSecondary Hours_of_operation',
                'flow_rate' => OpenStudio.convert(600, 'cfm', 'm^3/s').get,
                'space_names' =>
                    [
                        'Bathrooms_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'Exhaust Fan',
                'name' => 'Bathrooms_ZN_1_FLR_2',
                'availability_sch_name' => 'SchoolSecondary Hours_of_operation',
                'flow_rate' => OpenStudio.convert(600, 'cfm', 'm^3/s').get,
                'space_names' =>
                    [
                        'Bathrooms_ZN_1_FLR_2'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Walkin Freezer',
                'cooling_capacity_per_length' => 734.0,
                'length' => 7.32,
                'evaporator_fan_pwr_per_length' => 68.3,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
                'defrost_pwr_per_length' => 410.0,
                'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 1.5,
                'cop_f_of_t_curve_name' => 'RACK1_RackCOPfTCurve',
                'condenser_fan_pwr' => 750.0,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen_ZN_1_FLR_1'
                    ]
            },
            {
                'type' => 'Refrigeration',
                'case_type' => 'Display Case',
                'cooling_capacity_per_length' => 734.0,
                'length' => 7.32,
                'evaporator_fan_pwr_per_length' => 55.0,
                'lighting_per_length' => 33.0,
                'lighting_sch_name' => 'SchoolSecondary BLDG_LIGHT_SCH',
                'defrost_pwr_per_length' => 0.0,
                'restocking_sch_name' => 'SchoolSecondary Kitchen_ZN_1_FLR_1_Case:1_WALKINFREEZER_WalkInStockingSched',
                'cop' => 3.0,
                'cop_f_of_t_curve_name' => 'RACK2_RackCOPfTCurve',
                'condenser_fan_pwr' => 750.0,
                'condenser_fan_pwr_curve_name' => 'RACK1_RackCondFanCurve2',
                'space_names' =>
                    [
                        'Kitchen_ZN_1_FLR_1'
                    ]
            }
        ]
    end

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    model.getSpaces.each do |space|
      if space.name.get.to_s == 'Mech_ZN_1_FLR_1'
        model.add_elevator(template,
                           space,
                           prototype_input['number_of_elevators'],
                           prototype_input['elevator_type'],
                           prototype_input['elevator_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           prototype_input['elevator_fan_schedule'],
                           building_type)
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end
module SmallHotel
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil

    case template
      when 'DOE Ref Pre-1980'
        space_type_map = {
            'Corridor' => ['CorridorFlr1', 'CorridorFlr2', 'CorridorFlr3', 'CorridorFlr4'],
            'Elec/MechRoom' => ['ElevatorCoreFlr1'],
            'ElevatorCore' => ['ElevatorCoreFlr2', 'ElevatorCoreFlr3', 'ElevatorCoreFlr4'],
            'StaffLounge' => ['EmployeeLoungeFlr1'],
            'Exercise' => ['ExerciseCenterFlr1'],
            'GuestLounge' => ['FrontLoungeFlr1'],
            'Office' => ['FrontOfficeFlr1'],
            'Stair' => ['FrontStairsFlr1', 'FrontStairsFlr2', 'FrontStairsFlr3', 'FrontStairsFlr4', 'RearStairsFlr1', 'RearStairsFlr2', 'RearStairsFlr3', 'RearStairsFlr4'],
            'Storage' => ['FrontStorageFlr1', 'FrontStorageFlr2', 'FrontStorageFlr3', 'FrontStorageFlr4', 'RearStorageFlr1', 'RearStorageFlr2', 'RearStorageFlr3', 'RearStorageFlr4'],
            'GuestRoom' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'GuestRoom201', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom215_218', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom309_312', 'GuestRoom313', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom319', 'GuestRoom320_323', 'GuestRoom324', 'GuestRoom401', 'GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom409_412', 'GuestRoom413', 'GuestRoom414', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424'],
            'Laundry' => ['LaundryRoomFlr1'],
            'Mechanical' => ['MechanicalRoomFlr1'],
            'Meeting' => ['MeetingRoomFlr1'],
            'PublicRestroom' => ['RestroomFlr1'],
            'Attic' => ['Attic']
        }
      when 'DOE Ref 1980-2004'
        space_type_map = {
            'Corridor' => ['CorridorFlr1', 'CorridorFlr2', 'CorridorFlr3', 'CorridorFlr4'],
            # 'ElevatorCore' => ['ElevatorCoreFlr1','ElevatorCoreFlr2','ElevatorCoreFlr3','ElevatorCoreFlr4'],  #TODO put elevators into Mechanical type temperarily
            'Elec/MechRoom' => ['ElevatorCoreFlr1'],
            'ElevatorCore' => ['ElevatorCoreFlr2', 'ElevatorCoreFlr3', 'ElevatorCoreFlr4'],
            'StaffLounge' => ['EmployeeLoungeFlr1'],
            'Exercise' => ['ExerciseCenterFlr1'],
            'GuestLounge' => ['FrontLoungeFlr1'],
            'Office' => ['FrontOfficeFlr1'],
            'Stair' => ['FrontStairsFlr1', 'FrontStairsFlr2', 'FrontStairsFlr3', 'FrontStairsFlr4', 'RearStairsFlr1', 'RearStairsFlr2', 'RearStairsFlr3', 'RearStairsFlr4'],
            'Storage' => ['FrontStorageFlr1', 'FrontStorageFlr2', 'FrontStorageFlr3', 'FrontStorageFlr4', 'RearStorageFlr1', 'RearStorageFlr2', 'RearStorageFlr3', 'RearStorageFlr4'],
            'GuestRoom' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'GuestRoom201', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom215_218', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom309_312', 'GuestRoom313', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom319', 'GuestRoom320_323', 'GuestRoom324', 'GuestRoom401', 'GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom409_412', 'GuestRoom413', 'GuestRoom414', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424'],
            'Laundry' => ['LaundryRoomFlr1'],
            'Mechanical' => ['MechanicalRoomFlr1'],
            'Meeting' => ['MeetingRoomFlr1'],
            'PublicRestroom' => ['RestroomFlr1'],
            'Attic' => ['Attic']
        }
      when '90.1-2010', '90.1-2007', '90.1-2004', '90.1-2013'
        space_type_map = {
            'Corridor' => ['CorridorFlr1', 'CorridorFlr2', 'CorridorFlr3'],
            'Corridor4' => ['CorridorFlr4'],
            'Elec/MechRoom' => ['ElevatorCoreFlr1'],
            'ElevatorCore' => ['ElevatorCoreFlr2', 'ElevatorCoreFlr3'],
            'ElevatorCore4' => ['ElevatorCoreFlr4'],
            'StaffLounge' => ['EmployeeLoungeFlr1'],
            'Exercise' => ['ExerciseCenterFlr1'],
            'GuestLounge' => ['FrontLoungeFlr1'],
            'Office' => ['FrontOfficeFlr1'],
            'Stair' => ['FrontStairsFlr1', 'FrontStairsFlr2', 'FrontStairsFlr3', 'RearStairsFlr1', 'RearStairsFlr2', 'RearStairsFlr3'],
            'Stair4' => ['FrontStairsFlr4', 'RearStairsFlr4'],
            'Storage' => ['FrontStorageFlr1', 'FrontStorageFlr2', 'FrontStorageFlr3', 'RearStorageFlr1', 'RearStorageFlr2', 'RearStorageFlr3'],
            'Storage4Front' => ['FrontStorageFlr4'],
            'Storage4Rear' => ['RearStorageFlr4'],
            'GuestRoom123Occ' => ['GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'GuestRoom309_312', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom320_323'],
            'GuestRoom123Vac' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom201', 'GuestRoom215_218', 'GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom313', 'GuestRoom319', 'GuestRoom324'],
            'GuestRoom4Occ' => ['GuestRoom401', 'GuestRoom409_412', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424'],
            'GuestRoom4Vac' => ['GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom413', 'GuestRoom414'],
            'Laundry' => ['LaundryRoomFlr1'],
            'Mechanical' => ['MechanicalRoomFlr1'],
            'Meeting' => ['MeetingRoomFlr1'],
            'PublicRestroom' => ['RestroomFlr1'],
            # 'Attic' => ['Attic']

        }
      when 'NECB 2011'
        sch = 'F'
        space_type_map = {
            "Corr. >= 2.4m wide-sch-#{sch}" => ['CorridorFlr1', 'CorridorFlr2', 'CorridorFlr3', 'CorridorFlr4'],
            'Lobby - elevator' => ['ElevatorCoreFlr1', 'ElevatorCoreFlr2', 'ElevatorCoreFlr3', 'ElevatorCoreFlr4'],
            'Lounge/recreation' => ['EmployeeLoungeFlr1'],
            'Gym - fitness' => ['ExerciseCenterFlr1'],
            'Hotel/Motel - lobby' => ['FrontLoungeFlr1'],
            'Office - enclosed' => ['FrontOfficeFlr1'],
            "Stairway-sch-#{sch}" => ['FrontStairsFlr1', 'FrontStairsFlr2', 'FrontStairsFlr3', 'FrontStairsFlr4', 'RearStairsFlr1', 'RearStairsFlr2', 'RearStairsFlr3', 'RearStairsFlr4'],
            'Storage area' => ['FrontStorageFlr1', 'FrontStorageFlr2', 'FrontStorageFlr3', 'FrontStorageFlr4', 'LaundryRoomFlr1', 'RearStorageFlr1', 'RearStorageFlr2', 'RearStorageFlr3', 'RearStorageFlr4'],
            'Hway lodging - rooms' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'GuestRoom201', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom215_218', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom309_312', 'GuestRoom313', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom319', 'GuestRoom320_323', 'GuestRoom324', 'GuestRoom401', 'GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom409_412', 'GuestRoom413', 'GuestRoom414', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424'],
            "Electrical/Mechanical-sch-#{sch}" => ['MechanicalRoomFlr1', 'MeetingRoomFlr1'],
            "Washroom-sch-#{sch}" => ['RestroomFlr1']
        }

    end

    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = nil

    case template
      when 'DOE Ref Pre-1980'
        system_to_space_map = [
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom101'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom102'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom103'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom104'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom105'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom201'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom202_205'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom206_208'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom209_212'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom213'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom214'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom215_218'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom219'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom220_223'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom224'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom301'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom302_305'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom306_308'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom309_312'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom313'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom314'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom315_318'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom319'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom320_323'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom324'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom401'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom402_405'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom406_408'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom409_412'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom413'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom414'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom415_418'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom419'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom420_423'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom424'] },
            { 'type' => 'PTAC',
              'space_names' => ['CorridorFlr1'] },
            { 'type' => 'PTAC',
              'space_names' => ['CorridorFlr2'] },
            { 'type' => 'PTAC',
              'space_names' => ['CorridorFlr3'] },
            { 'type' => 'PTAC',
              'space_names' => ['CorridorFlr4'] },
            { 'type' => 'PTAC',
              'space_names' => ['EmployeeLoungeFlr1'] },
            { 'type' => 'PTAC',
              'space_names' => ['ExerciseCenterFlr1'] },
            { 'type' => 'PTAC',
              'space_names' => ['FrontLoungeFlr1'] },
            { 'type' => 'PTAC',
              'space_names' => ['FrontOfficeFlr1'] },
            { 'type' => 'PTAC',
              'space_names' => ['LaundryRoomFlr1'] },
            { 'type' => 'PTAC',
              'space_names' => ['MechanicalRoomFlr1'] },
            { 'type' => 'PTAC',
              'space_names' => ['MeetingRoomFlr1'] },
            { 'type' => 'PTAC',
              'space_names' => ['RestroomFlr1'] },

            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr4'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr4'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStorageFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStorageFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStorageFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStorageFlr4'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStorageFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStorageFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStorageFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStorageFlr4'] }
        ]
      when 'DOE Ref 1980-2004'
        system_to_space_map = [
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom101'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom102'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom103'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom104'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom105'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom201'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom202_205'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom206_208'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom209_212'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom213'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom214'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom215_218'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom219'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom220_223'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom224'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom301'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom302_305'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom306_308'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom309_312'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom313'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom314'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom315_318'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom319'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom320_323'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom324'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom401'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom402_405'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom406_408'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom409_412'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom413'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom414'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom415_418'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom419'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom420_423'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom424'] },

            { 'type' => 'PSZ-AC',
              'space_names' => ['CorridorFlr1'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['CorridorFlr2'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['CorridorFlr3'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['CorridorFlr4'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['EmployeeLoungeFlr1'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['ExerciseCenterFlr1'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['FrontLoungeFlr1'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['FrontOfficeFlr1'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['LaundryRoomFlr1'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['MechanicalRoomFlr1'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['MeetingRoomFlr1'] },
            { 'type' => 'PSZ-AC',
              'space_names' => ['RestroomFlr1'] },

            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr4'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr4'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStorageFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStorageFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStorageFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStorageFlr4'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStorageFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStorageFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStorageFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStorageFlr4'] }
        ]
      when '90.1-2010', '90.1-2007', '90.1-2004', '90.1-2013'
        system_to_space_map = [
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom101'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom102'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom103'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom104'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom105'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom201'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom202_205'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom206_208'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom209_212'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom213'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom214'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom215_218'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom219'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom220_223'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom224'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom301'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom302_305'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom306_308'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom309_312'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom313'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom314'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom315_318'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom319'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom320_323'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom324'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom401'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom402_405'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom406_408'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom409_412'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom413'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom414'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom415_418'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom419'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom420_423'] },
            { 'type' => 'PTAC',
              'space_names' => ['GuestRoom424'] },
            { 'type' => 'PTAC',
              'space_names' => ['CorridorFlr1'] },
            { 'type' => 'PTAC',
              'space_names' => ['CorridorFlr2'] },
            { 'type' => 'PTAC',
              'space_names' => ['CorridorFlr3'] },
            { 'type' => 'PTAC',
              'space_names' => ['CorridorFlr4'] },

            { 'type' => 'SAC',
              'space_names' => ['ExerciseCenterFlr1', 'EmployeeLoungeFlr1', 'RestroomFlr1'] },
            { 'type' => 'SAC',
              'space_names' => ['FrontLoungeFlr1'] },
            { 'type' => 'SAC',
              'space_names' => ['FrontOfficeFlr1'] },
            { 'type' => 'SAC',
              'space_names' => ['MeetingRoomFlr1'] },

            { 'type' => 'UnitHeater',
              'space_names' => ['MechanicalRoomFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['FrontStairsFlr4'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr1'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr2'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr3'] },
            { 'type' => 'UnitHeater',
              'space_names' => ['RearStairsFlr4'] }
        ]
    end

    return system_to_space_map
  end

  def self.define_building_story_map(building_type, template, climate_zone)
    building_story_map = nil

    building_story_map = {
        'BuildingStory1' => ['GuestRoom101', 'GuestRoom102', 'GuestRoom103', 'GuestRoom104', 'GuestRoom105', 'CorridorFlr1', 'ElevatorCoreFlr1', 'EmployeeLoungeFlr1', 'ExerciseCenterFlr1', 'FrontLoungeFlr1', 'FrontOfficeFlr1', 'FrontStairsFlr1', 'RearStairsFlr1', 'FrontStorageFlr1', 'RearStorageFlr1', 'LaundryRoomFlr1', 'MechanicalRoomFlr1', 'MeetingRoomFlr1', 'RestroomFlr1'],
        'BuildingStory2' => ['GuestRoom201', 'GuestRoom202_205', 'GuestRoom206_208', 'GuestRoom209_212', 'GuestRoom213', 'GuestRoom214', 'GuestRoom215_218', 'GuestRoom219', 'GuestRoom220_223', 'GuestRoom224', 'CorridorFlr2', 'FrontStairsFlr2', 'RearStairsFlr2', 'FrontStorageFlr2', 'RearStorageFlr2', 'ElevatorCoreFlr2'],
        'BuildingStory3' => ['GuestRoom301', 'GuestRoom302_305', 'GuestRoom306_308', 'GuestRoom309_312', 'GuestRoom313', 'GuestRoom314', 'GuestRoom315_318', 'GuestRoom319', 'GuestRoom320_323', 'GuestRoom324', 'CorridorFlr3', 'FrontStairsFlr3', 'RearStairsFlr3', 'FrontStorageFlr3', 'RearStorageFlr3', 'ElevatorCoreFlr3'],
        'BuildingStory4' => ['GuestRoom401', 'GuestRoom402_405', 'GuestRoom406_408', 'GuestRoom409_412', 'GuestRoom413', 'GuestRoom414', 'GuestRoom415_418', 'GuestRoom419', 'GuestRoom420_423', 'GuestRoom424', 'CorridorFlr4', 'FrontStairsFlr4', 'RearStairsFlr4', 'FrontStorageFlr4', 'RearStorageFlr4', 'ElevatorCoreFlr4']
    }

    # attic only applies to the two DOE vintages.
    if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'
      building_story_map['AtticStory'] = ['Attic']
    end
    return building_story_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started building type specific adjustments')

    # add extra infiltration for corridor1 door
    corridor_space = model.getSpaceByName('CorridorFlr1')
    corridor_space = corridor_space.get
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      infiltration_corridor = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infiltration_corridor.setName('Corridor1 door Infiltration')
      infiltration_per_zone = 0
      infiltration_per_zone = if template == '90.1-2010' || template == '90.1-2007'
                                0.591821538
                              else
                                0.91557718
                              end
      infiltration_corridor.setDesignFlowRate(infiltration_per_zone)
      infiltration_corridor.setSchedule(model.add_schedule('HotelSmall INFIL_Door_Opening_SCH'))
      infiltration_corridor.setSpace(corridor_space)
    end

    # hardsize corridor1. put in standards in the future  #TODO
    unless template == 'DOE Ref 1980-2004' || template == 'DOE Ref Pre-1980'
      model.getZoneHVACPackagedTerminalAirConditioners.sort.each do |ptac|
        zone = ptac.thermalZone.get
        if zone.spaces.include?(corridor_space)
          ptac.setSupplyAirFlowRateDuringCoolingOperation(0.13)
          ptac.setSupplyAirFlowRateDuringHeatingOperation(0.13)
          ptac.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(0.13)
          ccoil = ptac.coolingCoil
          if ccoil.to_CoilCoolingDXSingleSpeed.is_initialized
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedTotalCoolingCapacity(2638) # Unit: W
            ccoil.to_CoilCoolingDXSingleSpeed.get.setRatedAirFlowRate(0.13)
          end
        end
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished building type specific adjustments')

    return true
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end
module SmallOffice
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil

    space_type_map = case template
                       when 'NECB 2011'
                         # dom = ?
                         {
                             '- undefined -' => ['Attic'],
                             'Office - enclosed' => ['Core_ZN', 'Perimeter_ZN_1', 'Perimeter_ZN_2', 'Perimeter_ZN_3', 'Perimeter_ZN_4']
                         }
                       else
                         {
                             'WholeBuilding - Sm Office' => ['Perimeter_ZN_1', 'Perimeter_ZN_2', 'Perimeter_ZN_3', 'Perimeter_ZN_4', 'Core_ZN'],
                             'Attic' => ['Attic']
                         }
                     end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    system_to_space_map = [
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC-2',
            'space_names' =>
                [
                    'Perimeter_ZN_1'
                ]
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC-3',
            'space_names' =>
                [
                    'Perimeter_ZN_2'
                ]
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC-4',
            'space_names' =>
                [
                    'Perimeter_ZN_3'
                ]
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC-5',
            'space_names' =>
                [
                    'Perimeter_ZN_4'
                ]
        },
        {
            'type' => 'PSZ-AC',
            'name' => 'PSZ-AC-1',
            'space_names' =>
                [
                    'Core_ZN'
                ]
        }
    ]

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end
end
module Warehouse
  def self.define_space_type_map(building_type, template, climate_zone)
    space_type_map = nil

    space_type_map = case template

                       when 'NECB 2011'
                         # dom =A
                         {
                             'Warehouse - med/blk' => ['Zone3 Bulk Storage'],
                             'Warehouse - fine' => ['Zone2 Fine Storage'],
                             'Office - enclosed' => ['Zone1 Office']
                         }
                       else
                         {
                             'Bulk' => ['Zone3 Bulk Storage'],
                             'Fine' => ['Zone2 Fine Storage'],
                             'Office' => ['Zone1 Office']
                         }
                     end
    return space_type_map
  end

  def self.define_hvac_system_map(building_type, template, climate_zone)
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'name' => 'HVAC_1',
                'space_names' => ['Zone1 Office']
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'HVAC_2',
                'space_names' => ['Zone2 Fine Storage']
            },
            {
                'type' => 'UnitHeater',
                'name' => 'HVAC_3',
                'space_names' => ['Zone3 Bulk Storage']
            },
            {
                'type' => 'Zone Ventilation',
                'name' => 'Bulk Storage Zone Ventilation - Intake',
                'availability_sch_name' => 'Warehouse MinOA_Sched',
                'flow_rate' => 0.00025, # in m^3/s-m^2
                'ventilation_type' => 'Intake',
                'space_names' => ['Zone3 Bulk Storage']
            }
        ]
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
        system_to_space_map = [
            {
                'type' => 'PSZ-AC',
                'name' => 'HVAC_1',
                'space_names' => ['Zone1 Office']
            },
            {
                'type' => 'PSZ-AC',
                'name' => 'HVAC_2',
                'space_names' => ['Zone2 Fine Storage']
            },
            {
                'type' => 'UnitHeater',
                'name' => 'HVAC_3',
                'space_names' => ['Zone3 Bulk Storage']
            },
            {
                'type' => 'Zone Ventilation',
                'name' => 'Bulk Storage Zone Ventilation - Exhaust',
                'availability_sch_name' => 'Always On',
                'flow_rate' => OpenStudio.convert(80_008.9191, 'cfm', 'm^3/s').get,
                'ventilation_type' => 'Exhaust',
                'space_names' => ['Zone3 Bulk Storage']
            },
            {
                'type' => 'Zone Ventilation',
                'name' => 'Bulk Storage Zone Ventilation - Natural',
                'availability_sch_name' => 'Always On',
                'flow_rate' => OpenStudio.convert(2000, 'cfm', 'm^3/s').get,
                'ventilation_type' => 'Natural',
                'space_names' => ['Zone3 Bulk Storage']
            }
        ]
    end

    return system_to_space_map
  end

  def self.custom_hvac_tweaks(building_type, template, climate_zone, prototype_input, model)
    return true
  end

  def self.update_waterheater_loss_coefficient(template, model)
    case template
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NECB 2011'
        model.getWaterHeaterMixeds.sort.each do |water_heater|
          water_heater.setOffCycleLossCoefficienttoAmbientTemperature(0.798542707)
          water_heater.setOnCycleLossCoefficienttoAmbientTemperature(0.798542707)
        end
    end
  end

  def self.custom_swh_tweaks(building_type, template, climate_zone, prototype_input, model)
    PrototypeBuilding::Warehouse.update_waterheater_loss_coefficient(template, model)

    return true
  end
end




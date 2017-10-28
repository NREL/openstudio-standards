class StandardsModel

  def model_create_prototype_model(building_type, climate_zone, epw_file, sizing_run_dir = Dir.pwd, debug = false)
    model = OpenStudio::Model::Model.new()

    puts "model_create_prototype_model, model.class = #{model.class}"
    # model = model # TODO refactor: pass in model instead
    osm_file_increment = 0
    # There are no reference models for HighriseApartment at vintages Pre-1980 and 1980-2004, nor for NECB 2011. This is a quick check.
    if building_type == 'HighriseApartment'
      if instvartemplate == 'DOE Ref Pre-1980' || instvartemplate == 'DOE Ref 1980-2004'
        OpenStudio.logFree(OpenStudio::Error, 'Not available', "DOE Reference models for #{building_type} at @@template #{} are not available, the measure is disabled for this specific type.")
        return false
        #elsif @@template == 'NECB 2011'
        #  OpenStudio.logFree(OpenStudio::Error, 'Not available', "Reference model for #{building_type} at @@template #{@@template} is not available, the measure is disabled for this specific type.")
        #  return false
      end
    end

    lookup_building_type = model_get_lookup_name(model, building_type)

    # Retrieve the Prototype Inputs from JSON
    search_criteria = {
        'template' => instvartemplate,
        'building_type' => building_type
    }

    puts "instvartemplate is #{instvartemplate}"
    prototype_input = model_find_object(model, $os_standards['prototype_inputs'], search_criteria, nil)

    if prototype_input.nil?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find prototype inputs for #{search_criteria}, cannot create model.")
      return false
    end

    case instvartemplate
      when 'NECB 2011'

        debug_incremental_changes = false
        model_load_building_type_methods(model, building_type)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_load_building_type_methods.osm") if debug_incremental_changes

        # Ensure that surfaces are intersected properly.
        model_load_geometry(model, building_type)

        model.getSpaces.each { |space1| model.getSpaces.each { |space2| space1.intersectSurfaces(space2) } }
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_load_geometry.osm")  if debug_incremental_changes

        model.add_design_days_and_weather_file(climate_zone, epw_file)
        model.add_ground_temperatures(building_type, climate_zone, instvartemplate)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_add_design_days_and_weather_file.osm")  if debug_incremental_changes
        # puts weatherFile.get.path.get.to_s
        if model.weatherFile.empty? or model.weatherFile.get.path.empty? or not File.exists?(model.weatherFile.get.path.get.to_s)
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Model', "Weatherfile is not defined.")
          raise()
        end

        model.getBuilding.setName("#{}-#{building_type}-#{climate_zone}-#{epw_file} created: #{Time.new}")
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_set_name.osm")  if debug_incremental_changes

        space_type_map = model_define_space_type_map(model, building_type, instvartemplate, climate_zone)
        File.open("#{sizing_run_dir}/space_type_map.json", 'w') {|f| f.write(JSON.pretty_generate(space_type_map)) }

        model_assign_space_type_stubs(model, 'Space Function', space_type_map) # TO DO: add support for defining NECB 2011 archetype by building type (versus space function)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_assign_space_type_stubs.osm")  if debug_incremental_changes

        model_add_loads(model)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_add_loads.osm")  if debug_incremental_changes

        model_apply_infiltration_standard(model)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_apply_infiltration.osm")  if debug_incremental_changes

        model_modify_surface_convection_algorithm(model)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_modify_surface_convection_algorithm.osm")  if debug_incremental_changes

        model_add_constructions(model, building_type, climate_zone)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_add_constructions.osm")  if debug_incremental_changes

        # Modify Constructions to NECB reference levels
        model_apply_prm_construction_types(model)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_add_constructions.osm")  if debug_incremental_changes

        # Reduce the WWR and SRR, if necessary
        model_apply_prm_baseline_window_to_wall_ratio(model,nil)
        model_apply_prm_baseline_skylight_to_roof_ratio(model)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_add_fdwr_srr_rules.osm")  if debug_incremental_changes

        model_create_thermal_zones(model, building_type, climate_zone)
        # For some building types, stories are defined explicitly
        if building_type == 'SmallHotel' && instvartemplate != 'NECB 2011'
          model.getBuildingStorys.each { |item| item.remove }
          building_story_map = PrototypeBuilding::SmallHotel::define_building_story_map(building_type, instvartemplate, climate_zone)
          model_assign_building_story(model, building_type, climate_zone, building_story_map)
        end
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_create_thermal_zones.osm")  if debug_incremental_changes



        return false if model.runSizingRun("#{sizing_run_dir}/SR0") == false
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_sizing_run_0.osm")  if debug_incremental_changes

        model_add_hvac(model, building_type, instvartemplate, climate_zone, prototype_input, epw_file)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_add_hvac.osm")  if debug_incremental_changes

        osm_file_increment += 1
        model_add_swh(model, building_type, instvartemplate, climate_zone, prototype_input, epw_file)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_swh.osm")  if debug_incremental_changes

        model_apply_sizing_parameters(model, building_type)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_apply_sizing_paramaters.osm")  if debug_incremental_changes

        model.yearDescription.get.setDayofWeekforStartDay('Sunday')
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_setDayofWeekforStartDay.osm")  if debug_incremental_changes

        #set a larger tolerance for unmet hours from default 0.2 to 1.0C
        model.getOutputControlReportingTolerances.setToleranceforTimeHeatingSetpointNotMet(1.0)
        model.getOutputControlReportingTolerances.setToleranceforTimeCoolingSetpointNotMet(1.0)
        osm_file_increment += 1
        BTAP::FileIO::save_osm(model,"#{sizing_run_dir}/post_#{osm_file_increment}_setTolerances.osm")  if debug_incremental_changes

      else
        #optionally  determine the climate zone from the epw and stat files.
        if climate_zone == 'NECB HDD Method'
          climate_zone = BTAP::Environment::WeatherFile.new(epw_file).a169_2006_climate_zone()
        else
          #this is required to be blank otherwise it may cause side effects.
          epw_file = ""
        end
        model_load_building_type_methods(model, building_type)
        model_load_geometry(model, building_type)
        model.getBuilding.setName("#{}-#{building_type}-#{climate_zone} created: #{Time.new}")
        space_type_map = model_define_space_type_map(model, building_type, instvartemplate, climate_zone)
        model_assign_space_type_stubs(model, lookup_building_type, space_type_map)
        model_add_loads(model)
        model_apply_infiltration_standard(model)
        model_modify_infiltration_coefficients(model, building_type, climate_zone)
        model_modify_surface_convection_algorithm(model)
        model_add_constructions(model, building_type, climate_zone)
        model_create_thermal_zones(model, building_type, climate_zone)
        model_add_hvac(model, building_type, instvartemplate, climate_zone, prototype_input, epw_file)
        model_custom_hvac_tweaks(model, building_type, instvartemplate, climate_zone, prototype_input)
        model_add_swh(model, building_type, instvartemplate, climate_zone, prototype_input, epw_file)
        model_custom_swh_tweaks(model, building_type, instvartemplate, climate_zone, prototype_input)
        model_add_exterior_lights(model, building_type, climate_zone, prototype_input)
        model_add_occupancy_sensors(model, building_type, climate_zone)
        model.add_design_days_and_weather_file(climate_zone, epw_file)
        model.add_ground_temperatures(building_type, climate_zone, instvartemplate)

        model_apply_sizing_parameters(model, building_type)
        model.yearDescription.get.setDayofWeekforStartDay('Sunday')

    end
    # set climate zone and building type
    model.getBuilding.setStandardsBuildingType(building_type)
    if climate_zone.include? 'ASHRAE 169-2006-'
      model.getClimateZones.setClimateZone('ASHRAE', climate_zone.gsub('ASHRAE 169-2006-', ''))
    end

    # For some building types, stories are defined explicitly
    if building_type == 'SmallHotel'
      model.getBuildingStorys.each { |item| item.remove }
      building_story_map = PrototypeBuilding::SmallHotel.define_building_story_map(building_type, instvartemplate, climate_zone)
      model_assign_building_story(model, building_type, climate_zone, building_story_map)
    end

    # Assign building stories to spaces in the building
    # where stories are not yet assigned.
    model_assign_spaces_to_stories(model) 

    # Perform a sizing model_run(model) 
    if model.runSizingRun("#{sizing_run_dir}/SR1") == false
      return false
    end

    # If there are any multizone systems, reset damper positions
    # to achieve a 60% ventilation effectiveness minimum for the system
    # following the ventilation rate procedure from 62.1
    model_apply_multizone_vav_outdoor_air_sizing(model)

    # This is needed for NECB 2011 as a workaround for sizing the reheat boxes
    if instvartemplate == 'NECB 2011'
      model.getAirTerminalSingleDuctVAVReheats.each { |iobj| air_terminal_single_duct_vav_reheat_set_heating_cap(iobj)  }
    end

    # Apply the prototype HVAC assumptions
    # which include sizing the fan pressure rises based
    # on the flow rate of the system.
    model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)

    # for 90.1-2010 Outpatient, AHU2 set minimum outdoor air flow rate as 0
    # AHU1 doesn't have economizer
    if building_type == 'Outpatient'
      PrototypeBuilding::Outpatient.modify_oa_controller(instvartemplate, model)
      # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
      PrototypeBuilding::Outpatient.reset_or_room_vav_minimum_damper(prototype_input, instvartemplate, model)
    end

    if building_type == 'Hospital'
      PrototypeBuilding::Hospital.modify_hospital_oa_controller(instvartemplate, model)
    end

    # Apply the HVAC efficiency standard
    model_apply_hvac_efficiency_standard(model, climate_zone)

    # Fix EMS references.
    # Temporary workaround for OS issue #2598
    model_temp_fix_ems_references(model) 

    # Add daylighting controls per standard
    # only four zones in large hotel have daylighting controls
    # todo: YXC to merge to the main function
    if building_type == 'LargeHotel'
      PrototypeBuilding::LargeHotel.large_hotel_add_daylighting_controls(instvartemplate, model)
    elsif building_type == 'Hospital'
      PrototypeBuilding::Hospital.hospital_add_daylighting_controls(instvartemplate, model)
    else
      model_add_daylighting_controls(model)
    end

    if building_type == 'QuickServiceRestaurant'
      PrototypeBuilding::QuickServiceRestaurant.update_exhaust_fan_efficiency(instvartemplate, model)
    elsif building_type == 'FullServiceRestaurant'
      PrototypeBuilding::FullServiceRestaurant.update_exhaust_fan_efficiency(instvartemplate, model)
    elsif building_type == 'Outpatient'
      PrototypeBuilding::Outpatient.update_exhaust_fan_efficiency(instvartemplate, model)
    elsif building_type == 'SuperMarket'
      PrototypeBuilding::SuperMarket.update_exhaust_fan_efficiency(instvartemplate, model)
    end

    if building_type == 'HighriseApartment'
      PrototypeBuilding::HighriseApartment.update_fan_efficiency(model)
    end

    # Add output variables for debugging
    if debug
      model_request_timeseries_outputs(model) 
    end

    # Finished
    model_status = 'final'
    model.save(OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.osm"), true)

    return model
  end

  # Get the name of the building type used in lookups
  #
  # @param building_type [String] the building type
  # @return [String] returns the lookup name as a string
  # @todo Unify the lookup names and eliminate this method
  def model_get_lookup_name(model, building_type)
    lookup_name = building_type

    case building_type
      when 'SmallOffice'
        lookup_name = 'Office'
      when 'MediumOffice'
        lookup_name = 'Office'
      when 'LargeOffice'
        lookup_name = 'Office'
      when 'LargeOfficeDetail'
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
  # @param climate_zone [String] the climate zone
  # @return [Bool] returns true if successful, false if not
  def model_load_building_type_methods(model, building_type)
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
      when 'LargeOfficeDetail'
        building_methods = 'Prototype.large_office_detail'
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
      when 'SuperMarket'
        building_methods = 'Prototype.supermarket'
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Building Type = #{building_type} not recognized")
        return false
    end

    # require_relative "../buildings/#{building_methods}"

    return true
  end

  # Loads a geometry-only .osm as a starting point.
  #
  # @param building_type [String] the building type
  # @param climate_zone [String] the climate zone
  # @return [Bool] returns true if successful, false if not
  def model_load_geometry(model, building_type)
    OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Started adding geometry')

    # Determine which geometry file to use
    # based on building_type and template
    # NECB 2011 geometry is not explicitly defined; for NECB 2011 template, latest ASHRAE 90.1 geometry file is assigned (implicitly)

    building_type_to_geometry_json = "#{@@data_folder}/geometry/archetypes/#{building_type}.json"
    # puts "\n#{building_type_to_geometry_json}\nEXIST: #{File.exists?(building_type_to_geometry_json)}\n"
    begin
      building_type_to_geometry = JSON.parse(File.read(building_type_to_geometry_json))
    rescue JSON::ParserError => e
      puts "THE CONTENTS OF THE JSON FILE AT #{building_type_to_geometry_json} IS NOT VALID"
      raise e
    end

    if building_type_to_geometry.has_key?(building_type)
      if building_type_to_geometry[building_type]['geometry'].has_key?(instvartemplate)
        #puts building_type_to_geometry[building_type]['geometry'][@@template]
        geometry_file = building_type_to_geometry[building_type]['geometry'][instvartemplate]
      else
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model.define_space_type_map', "Template = [#{building_type}] was not found for Building Type = [#{building_type}] at #{building_type_to_geometry_json}.")
        return false
      end
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model.define_space_type_map', "Building Type = #{building_type} was not found at #{building_type_to_geometry_json}")
      return false
    end
    # Load the geometry .osm
    geom_file = "#{@@data_folder}/geometry/#{geometry_file}"
    geom_model_path = OpenStudio::Path.new(geom_file.to_s)
    #Upgrade version if required.
    version_translator = OpenStudio::OSVersion::VersionTranslator.new
    geom_model = version_translator.loadModel(geom_model_path).get
    model.addObjects( geom_model.toIdfFile.objects )
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding geometry')
    #ensure that model is intersected correctly.
    model.getSpaces.each {|space1| model.getSpaces.each {|space2| space1.intersectSurfaces(space2)}}
    return true
    OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', 'Finished adding geometry')
  end

  # Replaces all objects in the current model
  # with the objects in the .osm.  Typically used to
  # load a model as a starting point.
  #
  # @param rel_path_to_osm [String] the path to an .osm file, relative to this file
  # @return [Bool] returns true if successful, false if not
  def model_replace_model(model, rel_path_to_osm)

    # Take the existing model and remove all the objects
    # (this is cheesy), but need to keep the same memory block
    handles = OpenStudio::UUIDVector.new
    model.objects.each { |objects| handles << objects.handle }
    model.removeObjects(handles)

    model = nil
    if File.dirname(__FILE__)[0] == ':'
      # running from embedded location

      # Load geometry from the saved geometry.osm
      geom_model_string = load_resource_relative(rel_path_to_osm)
      puts geom_model_string
      # version translate from string
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = version_translator.loadModelFromString(geom_model_string)

    else
      abs_path = File.join(File.dirname(__FILE__), rel_path_to_osm)

      # version translate from string
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      model = version_translator.loadModel(abs_path)
      raise()
    end

    if model.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Version translation failed for #{rel_path_to_osm}")
      return false
    end
    model = model.get

    # Add the objects from the geometry model to the working model
    model.addObjects(model.toIdfFile.objects)

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
  def model_assign_space_type_stubs(model, building_type, space_type_map)
    space_type_map.each do |space_type_name, space_names|
      # Create a new space type
      stub_space_type = OpenStudio::Model::SpaceType.new(model)
      stub_space_type.setStandardsBuildingType(building_type)
      stub_space_type.setStandardsSpaceType(space_type_name)
      stub_space_type.setName("#{building_type} #{space_type_name}")
      space_type_apply_rendering_color(stub_space_type)

      stub_space_type_occsens = nil
      occsensSpaceTypeCreated = false # Flag to determine need for another space type
      occsensSpaceTypeCount = 0

      space_names.each do |space_name|
        space = model.getSpaceByName(space_name)
        next if space.empty?
        space = space.get

        occsensSpaceTypeUsed = false

        if instvartemplate == "NECB 2011"
          # Check if space type for this space matches NECB 2011 specific space type
          # for occupancy sensor that is area dependent. Note: space.floorArea in m2.
          space_type_name_occsens = space_type_name + " - occsens"
          if((space_type_name=='Storage area' && space.floorArea < 100) ||
              (space_type_name=='Storage area - refrigerated' && space.floorArea < 100) ||
              (space_type_name=='Hospital - medical supply' && space.floorArea < 100) ||
              (space_type_name=='Office - enclosed' && space.floorArea < 25))
            # If there is only one space assigned to this space type, then reassign this stub
            # to the @@template duplicate with appendage " - occsens", otherwise create a new stub
            # for this space. Required to use reduced LPD by NECB 2011 0.9 factor.
            occsensSpaceTypeUsed = true
            if !occsensSpaceTypeCreated
              # create a new space type just once for space_type_name appended with " - occsens"
              stub_space_type_occsens = OpenStudio::Model::SpaceType.new(model)
              stub_space_type_occsens.setStandardsBuildingType(building_type)
              stub_space_type_occsens.setStandardsSpaceType(space_type_name_occsens)
              stub_space_type_occsens.setName("#{building_type} #{space_type_name_occsens}")
              space_type_apply_rendering_color(stub_space_type_occsens)
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

  def model_add_full_space_type_libs(model)
    space_type_properties_list = model_find_objects(model, $os_standards['space_types'], '' => 'NECB 2011')
    space_type_properties_list.each do |space_type_property|
      stub_space_type = OpenStudio::Model::SpaceType.new(model)
      stub_space_type.setStandardsBuildingType(space_type_property['building_type'])
      stub_space_type.setStandardsSpaceType(space_type_property['space_type'])
      stub_space_type.setName("#{}-#{space_type_property['building_type']}-#{space_type_property['space_type']}")
      space_type_apply_rendering_color(stub_space_type)
    end
    model_add_loads(model)
  end

  def model_assign_building_story(model, building_type, climate_zone, building_story_map)
    building_story_map.each do |building_story_name, space_names|
      stub_building_story = OpenStudio::Model::BuildingStory.new(model)
      stub_building_story.setName(building_story_name)

      space_names.each do |space_name|
        space = model.getSpaceByName(space_name)
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
  # @param climate_zone [String] the name of the climate zone the building is in
  # @return [Bool] returns true if successful, false if not

  def model_add_loads(model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying space types (loads)')

    # Loop through all the space types currently in the model,
    # which are placeholders, and give them appropriate loads and schedules
    model.getSpaceTypes.sort.each do |space_type|
      # Rendering color
      space_type_apply_rendering_color(space_type)

      # Loads
      space_type_apply_internal_loads(space_type, true, true, true, true, true, true)

      # Schedules
      space_type_apply_internal_load_schedules(space_type, true, true, true, true, true, true, true)
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
  # @param climate_zone [String] the name of the climate zone the building is in
  # @return [Bool] returns true if successful, false if not
  def model_add_constructions(model, building_type, climate_zone)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying constructions')
    is_residential = 'No' # default is nonresidential for building level

    # The constructions lookup table uses a slightly different list of
    # building types.
    lookup_building_type = model_get_lookup_name(model, building_type)
    # TODO this is a workaround.  Need to synchronize the building type names
    # across different parts of the code, including splitting of Office types
    case building_type
      when 'SmallOffice', 'MediumOffice', 'LargeOffice'
        lookup_building_type = building_type
      else
        lookup_building_type = model_get_lookup_name(model, building_type)
    end

    # Assign construction to adiabatic construction
    # Assign a material to all internal mass objects
    cp02_carpet_pad = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
    cp02_carpet_pad.setName('CP02 CARPET PAD')
    cp02_carpet_pad.setRoughness('VeryRough')
    cp02_carpet_pad.setThermalResistance(0.21648)
    cp02_carpet_pad.setThermalAbsorptance(0.9)
    cp02_carpet_pad.setSolarAbsorptance(0.7)
    cp02_carpet_pad.setVisibleAbsorptance(0.8)

    normalweight_concrete_floor = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    normalweight_concrete_floor.setName('100mm Normalweight concrete floor')
    normalweight_concrete_floor.setRoughness('MediumSmooth')
    normalweight_concrete_floor.setThickness(0.1016)
    normalweight_concrete_floor.setConductivity(2.31)
    normalweight_concrete_floor.setDensity(2322)
    normalweight_concrete_floor.setSpecificHeat(832)

    nonres_floor_insulation = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
    nonres_floor_insulation.setName('Nonres_Floor_Insulation')
    nonres_floor_insulation.setRoughness('MediumSmooth')
    nonres_floor_insulation.setThermalResistance(2.88291975297193)
    nonres_floor_insulation.setThermalAbsorptance(0.9)
    nonres_floor_insulation.setSolarAbsorptance(0.7)
    nonres_floor_insulation.setVisibleAbsorptance(0.7)

    floor_adiabatic_construction = OpenStudio::Model::Construction.new(model)
    floor_adiabatic_construction.setName('Floor Adiabatic construction')
    floor_layers = OpenStudio::Model::MaterialVector.new
    floor_layers << cp02_carpet_pad
    floor_layers << normalweight_concrete_floor
    floor_layers << nonres_floor_insulation
    floor_adiabatic_construction.setLayers(floor_layers)

    g01_13mm_gypsum_board = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    g01_13mm_gypsum_board.setName('G01 13mm gypsum board')
    g01_13mm_gypsum_board.setRoughness('Smooth')
    g01_13mm_gypsum_board.setThickness(0.0127)
    g01_13mm_gypsum_board.setConductivity(0.1600)
    g01_13mm_gypsum_board.setDensity(800)
    g01_13mm_gypsum_board.setSpecificHeat(1090)
    g01_13mm_gypsum_board.setThermalAbsorptance(0.9)
    g01_13mm_gypsum_board.setSolarAbsorptance(0.7)
    g01_13mm_gypsum_board.setVisibleAbsorptance(0.5)

    wall_adiabatic_construction = OpenStudio::Model::Construction.new(model)
    wall_adiabatic_construction.setName('Wall Adiabatic construction')
    wall_layers = OpenStudio::Model::MaterialVector.new
    wall_layers << g01_13mm_gypsum_board
    wall_layers << g01_13mm_gypsum_board
    wall_adiabatic_construction.setLayers(wall_layers)

    m10_200mm_concrete_block_basement_wall = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    m10_200mm_concrete_block_basement_wall.setName('M10 200mm concrete block basement wall')
    m10_200mm_concrete_block_basement_wall.setRoughness('MediumRough')
    m10_200mm_concrete_block_basement_wall.setThickness(0.2032)
    m10_200mm_concrete_block_basement_wall.setConductivity(1.326)
    m10_200mm_concrete_block_basement_wall.setDensity(1842)
    m10_200mm_concrete_block_basement_wall.setSpecificHeat(912)

    basement_wall_construction = OpenStudio::Model::Construction.new(model)
    basement_wall_construction.setName('Basement Wall construction')
    basement_wall_layers = OpenStudio::Model::MaterialVector.new
    basement_wall_layers << m10_200mm_concrete_block_basement_wall
    basement_wall_construction.setLayers(basement_wall_layers)

    basement_floor_construction = OpenStudio::Model::Construction.new(model)
    basement_floor_construction.setName('Basement Floor construction')
    basement_floor_layers = OpenStudio::Model::MaterialVector.new
    basement_floor_layers << m10_200mm_concrete_block_basement_wall
    basement_floor_layers << cp02_carpet_pad
    basement_floor_construction.setLayers(basement_floor_layers)

    model.getSurfaces.sort.each do |surface|
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
    spc_type = nil
    spc_type = "WholeBuilding" if instvartemplate == 'NECB 2011'
    bldg_def_const_set = model_add_construction_set(model, climate_zone, lookup_building_type, spc_type, is_residential)
    
    if bldg_def_const_set.is_initialized
      model.getBuilding.setDefaultConstructionSet(bldg_def_const_set.get)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not create default construction set for the building.')
      return false
    end

    # Make a construction set for each space type, if one is specified
    model.getSpaceTypes.sort.each do |space_type|
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
      spc_type_const_set = model_add_construction_set(model, climate_zone, stds_building_type, stds_spc_type, is_residential)
      if spc_type_const_set.is_initialized
        space_type.setDefaultConstructionSet(spc_type_const_set.get)
      end
    end

    # Add construction from story level, especially for the case when there are residential and nonresidential construction in the same building
    if lookup_building_type == 'SmallHotel' && instvartemplate != 'NECB 2011'
      model.getBuildingStorys.sort.each do |story|
        next if story.name.get == 'AtticStory'
        # puts "story = #{story.name}"
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
          data = model_find_object(model, $os_standards['space_types'], 'template' => instvartemplate, 'building_type' => lookup_building_type, 'space_type' => space_type_name)
          exterior_spaces_area += space.floorArea
          story_exterior_residential_area += space.floorArea if data['is_residential'] == 'Yes' # "Yes" is residential, "No" or nil is nonresidential
        end
        is_residential = 'Yes' if story_exterior_residential_area / exterior_spaces_area >= 0.5
        next if is_residential == 'No'

        # if the story is identified as residential, assign residential construction set to the spaces on this story.
        building_story_const_set = model_add_construction_set(model, climate_zone, lookup_building_type, nil, is_residential)
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
    material = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    material.setName('Std Wood 6inch')
    material.setRoughness('MediumSmooth')
    material.setThickness(0.15)
    material.setConductivity(0.12)
    material.setDensity(540)
    material.setSpecificHeat(1210)
    material.setThermalAbsorptance(0.9)
    material.setSolarAbsorptance(0.7)
    material.setVisibleAbsorptance(0.7)
    construction = OpenStudio::Model::Construction.new(model)
    construction.setName('InteriorFurnishings')
    layers = OpenStudio::Model::MaterialVector.new
    layers << material
    construction.setLayers(layers)

    # Assign the internal mass construction to existing internal mass objects
    model.getSpaces.sort.each do |space|
      internal_masses = space.internalMass
      internal_masses.each do |internal_mass|
        internal_mass.internalMassDefinition.setConstruction(construction)
      end
    end

    # get all the space types that are conditioned

    # not required for NECB 2011
    unless instvartemplate == 'NECB 2011'
      conditioned_space_names = model_find_conditioned_space_names(model, building_type, climate_zone)
    end

    # add internal mass
    # not required for NECB 2011
    unless (instvartemplate == 'NECB 2011') ||
        ((building_type == 'SmallHotel') &&
            (instvartemplate == '90.1-2004' || instvartemplate == '90.1-2007' || instvartemplate == '90.1-2010' || instvartemplate == '90.1-2013' || instvartemplate == 'NREL ZNE Ready 2017'))
      internal_mass_def = OpenStudio::Model::InternalMassDefinition.new(model)
      internal_mass_def.setSurfaceAreaperSpaceFloorArea(2.0)
      internal_mass_def.setConstruction(construction)
      conditioned_space_names.each do |conditioned_space_name|
        space = model.getSpaceByName(conditioned_space_name)
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
  def model_find_conditioned_space_names(model, building_type, climate_zone)
    system_to_space_map = model_define_hvac_system_map(model, building_type, instvartemplate, climate_zone)
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
  def model_create_thermal_zones(model, building_type, climate_zone)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started creating thermal zones')

    # Remove any Thermal zones assigned
    model.getThermalZones.each(&:remove)

    # This map define the multipliers for spaces with multipliers not equals to 1
    case building_type
      when 'LargeHotel'
        space_multiplier_map = PrototypeBuilding::LargeHotel.define_space_multiplier
      when 'MidriseApartment'
        space_multiplier_map = PrototypeBuilding::MidriseApartment.define_space_multiplier
      when 'LargeOffice'
        space_multiplier_map = PrototypeBuilding::LargeOffice.define_space_multiplier
      when 'LargeOfficeDetail'
        space_multiplier_map = PrototypeBuilding::LargeOfficeDetail.define_space_multiplier
      when 'Hospital'
        space_multiplier_map = PrototypeBuilding::Hospital.define_space_multiplier
      else
        space_multiplier_map = {}
    end


    # Create a thermal zone for each space in the self
    model.getSpaces.sort.each do |space|
      zone = OpenStudio::Model::ThermalZone.new(model)
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
      thermostat = model.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        thermostat_clone = thermostat.get.clone(model).to_ThermostatSetpointDualSetpoint.get
        zone.setThermostatSetpointDualSetpoint(thermostat_clone)
        if instvartemplate == 'NECB 2011'
          #Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
          ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
          ideal_loads.addToThermalZone(zone)
        end
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished creating thermal zones')
  end

  # Loop through thermal zones and model_run(model)  thermal_zone.add_exhaust
  # If kitchen_makeup is "None" then exhaust will be modeled in every kitchen zone without makeup air
  # If kitchen_makeup is "Adjacent" then exhaust will be modeled in every kitchen zone. Makeup air will be provided when there as an adjacent dining,cafe, or cafeteria zone of the same buidling type.
  # If kitchen_makeup is "Largest Zone" then exhaust will only be modeled in the largest kitchen zone, but the flow rate will be based on the kitchen area for all zones. Makeup air will be modeled in the largest dining,cafe, or cafeteria zone of the same building type.
  #
  # @param kitchen_makeup [String] Valid choices are
  # @return [Hash] Hash of newly made exhaust fan objects along with secondary exhaust and zone mixing objects
  def model_add_exhaust(model,kitchen_makeup = "Adjacent") # kitchen_makeup options are (None, Largest Zone, Adjacent)

    zone_exhaust_fans = {}

    # apply use specified kitchen_makup logic
    if not ["Adjacent","Largest Zone"].include?(kitchen_makeup)

      if not kitchen_makeup == "None"
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "#{kitchen_makeup} is an unexpected value for kitchen_makup arg, will use None.")
      end

      # loop through thermal zones
      model.getThermalZones.sort.each do |thermal_zone|
        zone_exhaust_hash = thermal_zone_add_exhaust(thermal_zone)

        # populate zone_exhaust_fans
        zone_exhaust_fans.merge!(zone_exhaust_hash)
      end

    else # common code for Adjacent and Largest Zone

      # populate standard_space_types_with_makup_air
      standard_space_types_with_makup_air = {}
      standard_space_types_with_makup_air[["FullServiceRestaurant","Kitchen"]] = ["FullServiceRestaurant","Dining"]
      standard_space_types_with_makup_air[["QuickServiceRestaurant","Kitchen"]] = ["QuickServiceRestaurant","Dining"]
      standard_space_types_with_makup_air[["Hospital","Kitchen"]] = ["Hospital","Dining"]
      standard_space_types_with_makup_air[["SecondarySchool","Kitchen"]] = ["SecondarySchool","Cafeteria"]
      standard_space_types_with_makup_air[["PrimarySchool","Kitchen"]] = ["PrimarySchool","Cafeteria"]
      standard_space_types_with_makup_air[["LargeHotel","Kitchen"]] = ["LargeHotel","Cafe"]

      # gather information on zones organized by standards building type and space type. zone may be in this multiple times if it has multiple space types
      zones_by_standards = {}

      model.getThermalZones.sort.each do |thermal_zone|

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
            space_type_hash[space_type][:standards_array] =[space_type.standardsBuildingType.get,space_type.standardsSpaceType.get]
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

        zones_applied = [] # add thermal zones to this ones they have had thermal_zone.add_exhaust model_run(model)  on it

        # loop through standard_space_types_with_makup_air
        standard_space_types_with_makup_air.each do |makeup_target,makeup_source|

          # hash to manage lookups
          markup_target_effective_floor_area = {}
          markup_source_effective_floor_area = {}

          if zones_by_standards.has_key?(makeup_target)

            # process zones of each makeup_target
            zones_by_standards[makeup_target].each do |thermal_zone,space_type_hash|
              effective_floor_area = 0.0
              space_type_hash.each do |space_type,hash|
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
              zones_by_standards[makeup_source].each do |thermal_zone,space_type_hash|
                effective_floor_area = 0.0
                space_type_hash.each do |space_type,hash|
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
            zone_exhaust_hash = thermal_zone_add_exhaust(largest_target_zone,exhaust_makeup_inputs)
            zones_applied << largest_target_zone
            zone_exhaust_fans.merge!(zone_exhaust_hash)

          end

        end

        # add exhaust to zones that did not contain space types with standard_space_types_with_makup_air
        zones_by_standards.each do |standards_array,zones_hash|
          next if standard_space_types_with_makup_air.has_key?(standards_array)

          # loop through zones adding exhaust
          zones_hash.each do |thermal_zone,space_type_hash|
            next if zones_applied.include?(thermal_zone)

            # add exhaust
            zone_exhaust_hash = thermal_zone_add_exhaust(thermal_zone)
            zones_applied << thermal_zone
            zone_exhaust_fans.merge!(zone_exhaust_hash)
          end

        end


      else #kitchen_makeup == "Adjacent"

        zones_applied = [] # add thermal zones to this ones they have had thermal_zone.add_exhaust model_run(model)  on it

        standard_space_types_with_makup_air.each do |makeup_target,makeup_source|
          if zones_by_standards.has_key?(makeup_target)
            # process zones of each makeup_target
            zones_by_standards[makeup_target].each do |thermal_zone,space_type_hash|

              # get adjacent zones
              adjacent_zones = thermal_zone_get_adjacent_zones_with_shared_wall_areas(thermal_zone) 

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
                  zone_exhaust_hash = thermal_zone_add_exhaust(thermal_zone,exhaust_makeup_inputs)
                  zones_applied << thermal_zone
                  zone_exhaust_fans.merge!(zone_exhaust_hash)
                end

              end

              if first_adjacent_makeup_source.nil?

                # issue warning that makeup air wont be made but still make exhaust
                OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Model has zone with #{makeup_target} but no adjacent zone with #{makeup_source}. Exhaust will be added, but no makeup air.")

                # add exhaust
                zone_exhaust_hash = thermal_zone_add_exhaust(thermal_zone)
                zones_applied << thermal_zone
                zone_exhaust_fans.merge!(zone_exhaust_hash)

              end

            end

          end
        end

        # add exhaust for rest of zones
        model.getThermalZones.sort.each do |thermal_zone|
          next if zones_applied.include?(thermal_zone)

          # add exhaust
          zone_exhaust_hash = thermal_zone_add_exhaust(thermal_zone)
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
  def model_add_occupancy_sensors(model, building_type, climate_zone)
    # Only add occupancy sensors for 90.1-2010
    case instvartemplate
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
        return true
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Occupancy Sensors')

    space_type_reduction_map = {
        'SecondarySchool' => { 'Classroom' => 0.32, 'Restroom' => 0.34, 'Office' => 0.22 },
        'PrimarySchool' => { 'Classroom' => 0.32, 'Restroom' => 0.34, 'Office' => 0.22 }
    }

    # Loop through all the space types and reduce lighting operation schedule fractions as-specified
    model.getSpaceTypes.sort.each do |space_type|
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
        new_lights_sch = lights_sch.clone(model).to_ScheduleRuleset.get
        new_lights_sch.setName("#{lights_sch_name} OccSensor Reduction")
        reduced_lights_schs[lights_sch_name] = new_lights_sch

        # Reduce default day schedule
        model_multiply_schedule(model, new_lights_sch.defaultDaySchedule, red_multiplier, 0.25)

        # Reduce all other rule schedules
        new_lights_sch.scheduleRules.each do |sch_rule|
          model_multiply_schedule(model, sch_rule.daySchedule, red_multiplier, 0.25)
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
  end # add occupancy sensors

  # Adds exterior lights to the building, as specified
  # in OpenStudio_Standards_prototype_inputs
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  # @todo translate w/linear foot of facade, door, parking, etc
  #   into lookup table and implement that way instead of hard-coding as
  #   inputs in the spreadsheet.
  def model_add_exterior_lights(model, building_type, climate_zone, prototype_input)
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
      occ_sens_ext_lts_def = OpenStudio::Model::ExteriorLightsDefinition.new(model)
      occ_sens_ext_lts_def.setName("#{occ_sens_ext_lts_name} Def")
      occ_sens_ext_lts_def.setDesignLevel(occ_sens_ext_lts_power)
      occ_sens_ext_lts_sch = model_add_schedule(model, occ_sens_ext_lts_sch_name)
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
      nondimming_ext_lts_def = OpenStudio::Model::ExteriorLightsDefinition.new(model)
      nondimming_ext_lts_def.setName("#{nondimming_ext_lts_name} Def")
      nondimming_ext_lts_def.setDesignLevel(nondimming_ext_lts_power)
      nondimming_ext_lts_sch = model_add_schedule(model, nondimming_ext_lts_sch_name)
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
      fuel_ext_def = OpenStudio::Model::ExteriorLightsDefinition.new(model)
      fuel_ext_def.setName("#{fuel_ext_name} Def")
      fuel_ext_def.setDesignLevel(fuel_ext_power)
      fuel_ext_sch = model_add_schedule(model, fuel_ext_sch_name)
      fuel_ext_lts = OpenStudio::Model::ExteriorLights.new(fuel_ext_def, fuel_ext_sch)
      fuel_ext_lts.setName(fuel_ext_name.to_s)
      fuel_ext_lts.setControlOption('ScheduleNameOnly')
    end

    unless prototype_input['exterior_fuel_equipment2_power'].nil?
      fuel_ext_power = prototype_input['exterior_fuel_equipment2_power']
      fuel_ext_sch_name = prototype_input['exterior_fuel_equipment2_schedule']
      fuel_ext_name = 'Fuel equipment 2'
      fuel_ext_def = OpenStudio::Model::ExteriorLightsDefinition.new(model)
      fuel_ext_def.setName("#{fuel_ext_name} Def")
      fuel_ext_def.setDesignLevel(fuel_ext_power)
      fuel_ext_sch = model_add_schedule(model, fuel_ext_sch_name)
      fuel_ext_lts = OpenStudio::Model::ExteriorLights.new(fuel_ext_def, fuel_ext_sch)
      fuel_ext_lts.setName(fuel_ext_name.to_s)
      fuel_ext_lts.setControlOption('ScheduleNameOnly')
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding exterior lights')

    return true
  end # add exterior lights

  # Changes the infiltration coefficients for the prototype vintages.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  # @todo Consistency - make prototype and reference vintages consistent
  def model_modify_infiltration_coefficients(model, building_type, climate_zone)
    # Select the terrain type, which
    # impacts wind speed, and in turn infiltration
    terrain = 'City'
    case instvartemplate
      when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013', 'NREL ZNE Ready 2017'
        case building_type
          when 'Warehouse'
            terrain = 'Urban'
          when 'SmallHotel'
            terrain = 'Suburbs'
        end
    end
    # Set the terrain type
    model.getSite.setTerrain(terrain)

    # modify the infiltration coefficients
    case instvartemplate
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        # TODO make this consistent with newer prototypes
        const_coeff = 1.0
        temp_coeff = 0.0
        velo_coeff = 0.0
        velo_sq_coeff = 0.0
      else
        # Includes a wind-velocity-based term
        const_coeff = 0.0
        temp_coeff = 0.0
        velo_coeff = 0.224
        velo_sq_coeff = 0.0
    end

    model.getSpaceInfiltrationDesignFlowRates.sort.each do |infiltration|
      infiltration.setConstantTermCoefficient(const_coeff)
      infiltration.setTemperatureTermCoefficient(temp_coeff)
      infiltration.setVelocityTermCoefficient(velo_coeff)
      infiltration.setVelocitySquaredTermCoefficient(velo_sq_coeff)
    end
  end

  # Sets the inside and outside convection algorithms for different vintages
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  # @todo Consistency - make prototype and reference vintages consistent
  def model_modify_surface_convection_algorithm(model)
    inside = model.getInsideSurfaceConvectionAlgorithm
    outside = model.getOutsideSurfaceConvectionAlgorithm

    case instvartemplate
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        inside.setAlgorithm('TARP')
        outside.setAlgorithm('DOE-2')
      else
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
  def model_apply_sizing_parameters(model, building_type)
    # Default unless otherwise specified
    clg = 1.2
    htg = 1.2
    case instvartemplate
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
          when 'Hospital', 'LargeHotel', 'MediumOffice', 'LargeOffice', 'LargeOfficeDetail','Outpatient', 'PrimarySchool'
            clg = 1.0
            htg = 1.0
        end
      when 'NECB 2011'
        clg = 1.3
        htg = 1.3
      else
        # Use the sizing factors from 90.1 PRM
        clg = 1.15
        htg = 1.25
    end

    sizing_params = model.getSizingParameters
    sizing_params.setHeatingSizingFactor(htg)
    sizing_params.setCoolingSizingFactor(clg)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Set sizing factors to #{htg} for heating and #{clg} for cooling.")
  end

  def model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying prototype HVAC assumptions.')

    ##### Apply equipment efficiencies

    # Fans
    # Pressure Rise
    model.getFanConstantVolumes.sort.each { |obj| fan_constant_volume_apply_prototype_fan_pressure_rise(obj, building_type, instvartemplate, climate_zone) }
    model.getFanVariableVolumes.sort.each { |obj| fan_variable_volume_apply_prototype_fan_pressure_rise(obj, building_type, instvartemplate, climate_zone) }
    model.getFanOnOffs.sort.each { |obj| fan_on_off_apply_prototype_fan_pressure_rise(obj, building_type, instvartemplate, climate_zone) }
    model.getFanZoneExhausts.sort.each { |obj| fan_zone_exhaust_apply_prototype_fan_pressure_rise(obj) }

    # Motor Efficiency
    model.getFanConstantVolumes.sort.each { |obj| prototype_fan_apply_prototype_fan_efficiency(obj, instvartemplate) }
    model.getFanVariableVolumes.sort.each { |obj| prototype_fan_apply_prototype_fan_efficiency(obj, instvartemplate) }
    model.getFanOnOffs.sort.each { |obj| prototype_fan_apply_prototype_fan_efficiency(obj, instvartemplate) }
    model.getFanZoneExhausts.sort.each { |obj| prototype_fan_apply_prototype_fan_efficiency(obj, instvartemplate) }

    ##### Add Economizers

    if instvartemplate != 'NECB 2011'
      # Create an economizer maximum OA fraction of 70%
      # to reflect damper leakage per PNNL
      econ_max_70_pct_oa_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      econ_max_70_pct_oa_sch.setName('Economizer Max OA Fraction 70 pct')
      econ_max_70_pct_oa_sch.defaultDaySchedule.setName('Economizer Max OA Fraction 70 pct Default')
      econ_max_70_pct_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.7)
    else
      # NECB 2011 prescribes ability to provide 100% OA (5.2.2.7-5.2.2.9)
      econ_max_100_pct_oa_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      econ_max_100_pct_oa_sch.setName('Economizer Max OA Fraction 100 pct')
      econ_max_100_pct_oa_sch.defaultDaySchedule.setName('Economizer Max OA Fraction 100 pct Default')
      econ_max_100_pct_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1.0)
    end

    # Check each airloop
    model.getAirLoopHVACs.sort.each do |air_loop|
      if air_loop_hvac_economizer_required?(air_loop, climate_zone) == true
        # If an economizer is required, determine the economizer type
        # in the prototype buildings, which depends on climate zone.
        economizer_type = nil
        case instvartemplate
          when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
            economizer_type = 'DifferentialDryBulb'
          when '90.1-2010', '90.1-2013', 'NREL ZNE Ready 2017'
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
        if instvartemplate != 'NECB 2011'
          # oa_control.setMaximumFractionofOutdoorAirSchedule(econ_max_70_pct_oa_sch)
        end

        # Check that the economizer type set by the prototypes
        # is not prohibited by code.  If it is, change to no economizer.
        unless air_loop_hvac_economizer_type_allowable?(air_loop, climate_zone)
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.Model', "#{air_loop.name} is required to have an economizer, but the type chosen, #{economizer_type} is prohibited by code for #{}, climate zone #{climate_zone}.  Economizer type will be switched to No Economizer.")
          oa_control.setEconomizerControlType('NoEconomizer')
        end

      end
    end

    # TODO: What is the logic behind hard-sizing
    # hot water coil convergence tolerances?
    model.getControllerWaterCoils.sort.each { |obj| controller_water_coil_set_convergence_limits(obj) }
    
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying prototype HVAC assumptions.')
  end

  def model_add_debugging_variables(model, type)
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
      output_var = OpenStudio::Model::OutputVariable.new(var_name, model)
      output_var.setReportingFrequency(reporting_frequency)
    end
  end

  def model_run(model, run_dir = "#{Dir.pwd}/Run")
    # If the model_run(model)  directory is not specified
    # model_run(model)  in the current working directory

    # Make the directory if it doesn't exist
    unless Dir.exist?(run_dir)
      Dir.mkdir(run_dir)
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Started simulation in '#{run_dir}'")

    # Change the simulation to only model_run(model)  the weather file
    # and not model_run(model)  the sizing day simulations
    sim_control = model.getSimulationControl
    sim_control.setRunSimulationforSizingPeriods(false)
    sim_control.setRunSimulationforWeatherFileRunPeriods(true)

    # Save the model to energyplus idf
    idf_name = 'in.idf'
    osm_name = 'in.osm'
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(model)
    idf_path = OpenStudio::Path.new("#{run_dir}/#{idf_name}")
    osm_path = OpenStudio::Path.new("#{run_dir}/#{osm_name}")
    idf.save(idf_path, true)
    save(osm_path, true)

    # Set up the sizing simulation
    # Find the weather file
    epw_path = nil
    if model.weatherFile.is_initialized
      epw_path = model.weatherFile.get.path
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
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', 'Running sizing model_run(model)  with RunManager.')

      # Find EnergyPlus
      ep_dir = OpenStudio.getEnergyPlusDirectory
      ep_path = OpenStudio.getEnergyPlusExecutable
      ep_tool = OpenStudio::Runmanager::ToolInfo.new(ep_path)
      idd_path = OpenStudio::Path.new(ep_dir.to_s + '/Energy+.idd')
      output_path = OpenStudio::Path.new("#{run_dir}/")

      # Make a run manager and queue up the sizing model_run(model) 
      run_manager_db_path = OpenStudio::Path.new("#{run_dir}/run.db")
      run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_db_path, true, false, false, false)
      job = OpenStudio::Runmanager::JobFactory.createEnergyPlusJob(ep_tool,
                                                                   idd_path,
                                                                   idf_path,
                                                                   epw_path,
                                                                   output_path)

      run_manager.enqueue(job, true)

      # Start the sizing model_run(model)  and wait for it to finish.
      while run_manager.workPending
        sleep 1
        OpenStudio::Application.instance.processEvents
      end

      sql_path = OpenStudio::Path.new("#{run_dir}/Energyplus/eplusout.sql")

      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Finished sizing model_run(model)  in #{(Time.new - start_time).round}sec.")

    else # Use the openstudio-workflow gem
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', 'Running sizing model_run(model)  with openstudio-workflow gem.')

      # Copy the weather file to this directory
      FileUtils.copy(epw_path.to_s, run_dir)

      # Run the simulation
      sim = OpenStudio::Workflow.run_energyplus('Local', run_dir)
      final_state = model_run(sim) 

      if final_state == :finished
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Finished sizing model_run(model)  in #{(Time.new - start_time).round}sec.")
      end

      sql_path = OpenStudio::Path.new("#{run_dir}/run/eplusout.sql")

    end

    # Load the sql file created by the sizing model_run(model) 
    sql_path = OpenStudio::Path.new("#{run_dir}/Energyplus/eplusout.sql")
    if OpenStudio.exists(sql_path)
      sql = OpenStudio::SqlFile.new(sql_path)
      # Check to make sure the sql file is readable,
      # which won't be true if EnergyPlus crashed during simulation.
      unless sql.connectionOpen
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The model_run(model)  failed.  Look at the eplusout.err file in #{File.dirname(sql_path.to_s)} to see the cause.")
        return false
      end
      # Attach the sql file from the model_run(model)  to the sizing model
      model.setSqlFile(sql)
    else
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Results for the sizing model_run(model)  couldn't be found here: #{sql_path}.")
      return false
    end

    # Check that the model_run(model)  finished without severe errors
    error_query = "SELECT ErrorMessage
        FROM Errors
        WHERE ErrorType='1'"

    errs = model.sqlFile.get.execAndReturnVectorOfString(error_query)
    if errs.is_initialized
      errs = errs.get
      unless errs.empty?
        errs = errs.get
        OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "The model_run(model)  failed with the following severe errors: #{errs.join('\n')}.")
        return false
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Finished simulation in '#{run_dir}'")

    return true
  end

  def model_request_timeseries_outputs(model)
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
      output_var = OpenStudio::Model::OutputVariable.new(var, model)
      output_var.setReportingFrequency(freq)
    end
  end

  def model_clear_and_set_example_constructions(model)
    # Define Materials
    name = 'opaque material'
    thickness = 0.012700
    conductivity = 0.160000
    opaque_mat = BTAP::Resources::Envelope::Materials::Opaque.create_opaque_material(model, name, thickness, conductivity)

    name = 'insulation material'
    thickness = 0.050000
    conductivity = 0.043000
    insulation_mat = BTAP::Resources::Envelope::Materials::Opaque.create_opaque_material(model, name, thickness, conductivity)

    name = 'simple glazing test'
    shgc = 0.250000
    ufactor = 3.236460
    thickness = 0.003000
    visible_transmittance = 0.160000
    simple_glazing_mat = BTAP::Resources::Envelope::Materials::Fenestration.create_simple_glazing(model, name, shgc, ufactor, thickness, visible_transmittance)

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

    standard_glazing_mat = BTAP::Resources::Envelope::Materials::Fenestration.create_standard_glazing(model,
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
    ext_wall                            = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionExtWall',                    [opaque_mat, insulation_mat], insulation_mat)
    ext_roof                            = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionExtRoof',                    [opaque_mat, insulation_mat], insulation_mat)
    ext_floor                           = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionExtFloor',                   [opaque_mat, insulation_mat], insulation_mat)
    grnd_wall                           = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionGrndWall',                   [opaque_mat, insulation_mat], insulation_mat)
    grnd_roof                           = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionGrndRoof',                   [opaque_mat, insulation_mat], insulation_mat)
    grnd_floor                          = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionGrndFloor',                  [opaque_mat, insulation_mat], insulation_mat)
    int_wall                            = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionIntWall',                    [opaque_mat, insulation_mat], insulation_mat)
    int_roof                            = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionIntRoof',                    [opaque_mat, insulation_mat], insulation_mat)
    int_floor                           = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionIntFloor',                   [opaque_mat, insulation_mat], insulation_mat)
    # # Subsurfaces
    fixed_window                        = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionFixed',                [simple_glazing_mat])
    operable_window                     = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionOperable',             [simple_glazing_mat])
    glass_door                          = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionDoor',                 [standard_glazing_mat])
    door                                = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionDoor',                       [opaque_mat, insulation_mat], insulation_mat)
    overhead_door                       = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionOverheadDoor',               [opaque_mat, insulation_mat], insulation_mat)
    skylt                               = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionSkylight',             [standard_glazing_mat])
    daylt_dome                          = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionDomeConstruction',     [standard_glazing_mat])
    daylt_diffuser                      = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionDiffuserConstruction', [standard_glazing_mat])

    # Define Construction Sets
    # # Surface
    exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_surface_constructions(model, 'ExteriorSet', ext_wall, ext_roof, ext_floor)
    interior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_surface_constructions(model, 'InteriorSet', int_wall, int_roof, int_floor)
    ground_construction_set   = BTAP::Resources::Envelope::ConstructionSets.create_default_surface_constructions(model, 'GroundSet', grnd_wall, grnd_roof, grnd_floor)

    # # Subsurface
    subsurface_exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_subsurface_construction_set(model, fixed_window, operable_window, door, glass_door, overhead_door, skylt, daylt_dome, daylt_diffuser)
    subsurface_interior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_subsurface_construction_set(model, fixed_window, operable_window, door, glass_door, overhead_door, skylt, daylt_dome, daylt_diffuser)

    # Define default construction sets.
    name = 'Construction Set 1'
    default_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_construction_set(model, name, exterior_construction_set, interior_construction_set, ground_construction_set, subsurface_exterior_construction_set, subsurface_interior_construction_set)

    # Assign default to the model.
    model.getBuilding.setDefaultConstructionSet(default_construction_set)

    return default_construction_set
  end

  # Split all zones in the model into groups that are big enough
  # to justify their own HVAC system type.  Similar to the logic from
  # 90.1 Appendix G, but without regard to the fuel type of the
  # existing HVAC system (because the model may not have one).
  #
  # @param min_area_m2[Double] the minimum area required to justify
  # a different system type.
  # @return [Array<Hash>] an array of hashes of area information,
  # with keys area_ft2, type, stories, and zones (an array of zones)
  def model_group_zones_by_type(model, min_area_m2=20_000)
    min_area_ft2 = OpenStudio.convert(min_area_m2, 'm^2', 'ft^2').get

    # Get occupancy type, fuel type, and area information for all zones,
    # excluding unconditioned zones.
    # Occupancy types are:
    # Residential
    # NonResidential
    # Use 90.1-2010 so that retail and publicassembly are not split out
    zones = model_zones_with_occ_and_fuel_type(model, '90.1-2010', nil)

    # Ensure that there is at least one conditioned zone
    if zones.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.Model', "The building does not appear to have any conditioned zones. Make sure zones have thermostat with appropriate heating and cooling setpoint schedules.")
      return []
    end

    # Group the zones by occupancy type
    type_to_area = Hash.new { 0.0 }
    zones_grouped_by_occ = zones.group_by { |z| z['occ'] }

    # Determine the dominant occupancy type by area
    zones_grouped_by_occ.each do |occ_type, zns|
      zns.each do |zn|
        type_to_area[occ_type] += zn['area']
      end
    end
    dom_occ = type_to_area.sort_by { |k, v| v }.reverse[0][0]

    # Get the dominant occupancy type group
    dom_occ_group = zones_grouped_by_occ[dom_occ]

    # Check the non-dominant occupancy type groups to see if they
    # are big enough to trigger the occupancy exception.
    # If they are, leave the group standing alone.
    # If they are not, add the zones in that group
    # back to the dominant occupancy type group.
    occ_groups = []
    zones_grouped_by_occ.each do |occ_type, zns|
      # Skip the dominant occupancy type
      next if occ_type == dom_occ

      # Add up the floor area of the group
      area_m2 = 0
      zns.each do |zn|
        area_m2 += zn['area']
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get

      # If the non-dominant group is big enough, preserve that group.
      if area_ft2 > min_area_ft2
        occ_groups << [occ_type, zns]
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The portion of the building with an occupancy type of #{occ_type} is bigger than the minimum area of #{min_area_ft2.round} ft2.  It will be assigned a separate HVAC system type.")
        # Otherwise, add the zones back to the dominant group.
      else
        dom_occ_group += zns
      end

    end
    # Add the dominant occupancy group to the list
    occ_groups << [dom_occ, dom_occ_group]

    # Calculate the area for each of the final groups
    # and replace the zone hashes with an array of zone objects
    final_groups = []
    occ_groups.each do |occ_type, zns|
      # Sum the area and put all zones into an array
      area_m2 = 0.0
      gp_zns = []
      zns.each do |zn|
        area_m2 += zn['area']
        gp_zns << zn['zone']
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get

      # Determine the number of stories this group spans
      num_stories = model_num_stories_spanned(model, gp_zns)

      # Create a hash representing this group
      group = {}
      group['area_ft2'] = area_ft2
      group['type'] = occ_type
      group['stories'] = num_stories
      group['zones'] = gp_zns
      final_groups << group

      # Report out the final grouping
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Final system type group: occ = #{group['type']}, area = #{group['area_ft2'].round} ft2, num stories = #{group['stories']}, zones:")
      group['zones'].sort.each_slice(5) do |zone_list|
        zone_names = []
        zone_list.each do |zone|
          zone_names << zone.name.get.to_s
        end
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "--- #{zone_names.join(', ')}")
      end

    end

    return final_groups
  end

  private

  # Method to multiply the values in a day schedule by a specified value
  # but only when the existing value is higher than a specified lower limit.
  # This limit prevents occupancy sensors from affecting unoccupied hours.
  def model_multiply_schedule(model, day_sch, multiplier, limit)
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
  end # end reduce schedule
end









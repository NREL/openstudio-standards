Standard.class_eval do
  # @!group Model

  def model_create_prototype_model(climate_zone, epw_file, sizing_run_dir = Dir.pwd, debug = false, measure_model = nil)
    building_type = @instvarbuilding_type
    raise 'no building_type!' if @instvarbuilding_type.nil?
    model = nil
    # There are no reference models for HighriseApartment and data centers at vintages Pre-1980 and 1980-2004,
    # nor for NECB2011. This is a quick check.
    case @instvarbuilding_type
    when 'HighriseApartment','SmallDataCenterLowITE','SmallDataCenterHighITE','LargeDataCenterLowITE','LargeDataCenterHighITE','Laboratory'
      if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'
        OpenStudio.logFree(OpenStudio::Error, 'Not available', "DOE Reference models for #{@instvarbuilding_type} at   are not available, the measure is disabled for this specific type.")
        return false
      end
    else
      # do nothing
    end
    # optionally  determine the climate zone from the epw and stat files.
    if climate_zone == 'NECB HDD Method'
      climate_zone = BTAP::Environment::WeatherFile.new(epw_file).a169_2006_climate_zone
    else
      # this is required to be blank otherwise it may cause side effects.
      epw_file = ''
    end
    model = load_geometry_osm(@geometry_file)
    model_custom_geometry_tweaks(building_type, climate_zone, @prototype_input, model)
    model.getThermostatSetpointDualSetpoints(&:remove)
    model.getBuilding.setName(self.class.to_s)
    # save new basefile to new geometry folder as class name.
    model.getBuilding.setName("-#{@instvarbuilding_type}-#{climate_zone} created: #{Time.new}")
    model_add_loads(model)
    model_apply_infiltration_standard(model)
    model_modify_infiltration_coefficients(model, @instvarbuilding_type, climate_zone)
    model_modify_surface_convection_algorithm(model)
    model_create_thermal_zones(model, @space_multiplier_map)
    model_add_design_days_and_weather_file(model, climate_zone, epw_file)
    model_add_hvac(model, @instvarbuilding_type, climate_zone, @prototype_input, epw_file)
    model_add_constructions(model, @instvarbuilding_type, climate_zone)
    model_custom_hvac_tweaks(building_type, climate_zone, @prototype_input, model)
    model_add_internal_mass(model, @instvarbuilding_type)
    model_add_swh(model, @instvarbuilding_type, climate_zone, @prototype_input, epw_file)
    model_add_exterior_lights(model, @instvarbuilding_type, climate_zone, @prototype_input)
    model_add_occupancy_sensors(model, @instvarbuilding_type, climate_zone)
    model_add_daylight_savings(model)
    model_add_daylight_savings(model)
    model_add_ground_temperatures(model, @instvarbuilding_type, climate_zone)
    model_apply_sizing_parameters(model, @instvarbuilding_type)
    model.yearDescription.get.setDayofWeekforStartDay('Sunday')
    model.getBuilding.setStandardsBuildingType(building_type)
    model_set_climate_zone(model, climate_zone)
    # Perform a sizing model_run(model)
    return false if model_run_sizing_run(model, "#{sizing_run_dir}/SR1") == false
    # If there are any multizone systems, reset damper positions
    # to achieve a 60% ventilation effectiveness minimum for the system
    # following the ventilation rate procedure from 62.1
    model_apply_multizone_vav_outdoor_air_sizing(model)
    # Apply the prototype HVAC assumptions
    # which include sizing the fan pressure rises based
    # on the flow rate of the system.
    model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # custom economizer controls
    # For 90.1-2010 Outpatient, AHU1 doesn't have economizer and AHU2 set minimum outdoor air flow rate as 0
    model_modify_oa_controller(model)
    # For operating room 1&2 in 2010 and 2013, VAV minimum air flow is set by schedule
    model_reset_or_room_vav_minimum_damper(@prototype_input, model)
    # Apply the HVAC efficiency standard
    model_apply_hvac_efficiency_standard(model, climate_zone)
    # Apply prototype changes that supersede the HVAC efficiency standard
    model_apply_prototype_hvac_efficiency_adjustments(model)
    model_custom_swh_tweaks(model, @instvarbuilding_type, climate_zone, @prototype_input)
    # Fix EMS references.
    # Temporary workaround for OS issue #2598
    model_temp_fix_ems_references(model)
    # Add daylighting controls per standard
    # only four zones in large hotel have daylighting controls
    # todo: YXC to merge to the main function
    model_add_daylighting_controls(model)
    model_custom_daylighting_tweaks(building_type, climate_zone, @prototype_input, model)
    model_update_exhaust_fan_efficiency(model)
    model_update_fan_efficiency(model)
    # rename air loop and plant loop nodes for readability
    rename_air_loop_nodes(model)
    rename_plant_loop_nodes(model)
    # remove unused objects
    model_remove_unused_resource_objects(model)
    # Add output variables for debugging
    model_request_timeseries_outputs(model) if debug
    # If measure model is passed, then replace measure model with new model created here.
    if measure_model.nil?
      return model
    else
      model_replace_model(measure_model, model)
      return measure_model
    end
  end

  # Replaces the contents of 'model_to_replace' with the contents of 'new_model.'
  # This method can be used when the memory location of model_to_replace needs
  # to be preserved, for example, when a measure is passed.
  def model_replace_model(model_to_replace, new_model, runner = nil)
    # remove existing objects from model
    handles = OpenStudio::UUIDVector.new
    model_to_replace.objects.each do |obj|
      handles << obj.handle
    end
    model_to_replace.removeObjects(handles)

    # put contents of new_model into model_to_replace
    model_to_replace.addObjects(new_model.toIdfFile.objects)
    BTAP::runner_register("Info", "Model name is now #{model_to_replace.building.get.name}.", runner)
  end

  # Replaces all objects in the current model
  # with the objects in the .osm.  Typically used to
  # load a model as a starting point.
  #
  # @param rel_path_to_osm [String] the path to an .osm file, relative to this file
  # @return [Bool] returns true if successful, false if not
  def model_replace_model_from_osm(model, rel_path_to_osm)
    # Take the existing model and remove all the objects
    # (this is cheesy), but need to keep the same memory block
    handles = OpenStudio::UUIDVector.new
    model.objects.each {|objects| handles << objects.handle}
    model.removeObjects(handles)
    model = nil
    if File.dirname(__FILE__)[0] == ':'
      # running from embedded location

      # Load geometry from the saved geometry.osm
      geom_model_string = load_resource_relative(rel_path_to_osm)
      puts geom_model_string
      # version translate from string
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      geom_model = version_translator.loadModelFromString(geom_model_string)

    else
      abs_path = File.join(File.dirname(__FILE__), rel_path_to_osm)

      # version translate from string
      version_translator = OpenStudio::OSVersion::VersionTranslator.new
      geom_model = version_translator.loadModel(abs_path)
      raise
    end

    if geom_model.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', "Version translation failed for #{rel_path_to_osm}")
      return false
    end
    geom_model = geom_model.get

    # Add the objects from the geometry model to the working model
    model.addObjects(geom_model.toIdfFile.objects)
    return true
  end

  # Read the space type to space map from the model
  # instead of relying on an externally-defined mapping.
  def get_space_type_maps_from_model(model)
    # Do all spaces have Spacetypes?
    # @todo is this necessary?
    # all_spaces_have_space_types = true
    # Do all spacetypes have StandardSpaceTypes
    all_space_types_have_standard_space_types = true
    space_type_map = {}
    model.getSpaces.each do |space|
      if space.spaceType.empty?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Space #{space.name} does not have a Space Type assigned.")
      else
        if space.spaceType.get.standardsSpaceType.empty?
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "SpaceType #{space.spaceType.get.name} does not have a standardsSpaceType assigned.")
          all_space_types_have_standard_space_types = false
        else
          space_type_map[space.spaceType.get.standardsSpaceType.get.to_s] = [] if space_type_map[space.spaceType.get.standardsSpaceType.get.to_s].nil?
          space_type_map[space.spaceType.get.standardsSpaceType.get.to_s] << space.name.get
        end
      end
    end
    if all_space_types_have_standard_space_types
      return space_type_map
    end
    return nil
  end

  def model_add_full_space_type_libs(model)
    space_type_properties_list = standards_lookup_table_many(table_name: 'space_types')
    space_type_properties_list.each do |space_type_property|
      stub_space_type = OpenStudio::Model::SpaceType.new(model)
      stub_space_type.setStandardsBuildingType(space_type_property['building_type'])
      stub_space_type.setStandardsSpaceType(space_type_property['space_type'])
      stub_space_type.setName("-#{space_type_property['building_type']}-#{space_type_property['space_type']}")
      space_type_apply_rendering_color(stub_space_type)
    end
    model_add_loads(model)
  end

  def model_assign_building_story(model, building_story_map = nil)
    if building_story_map.nil? || building_story_map.empty?

      model_assign_spaces_to_stories(model)
      return true
    end
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

  # Checks to see if the an adiabatic floor construction has been constructed in an OpenStudio model.
  # If so, it returns it. If not, it constructs an adiabatic floor construction, adds it to the model,
  # and then returns it.
  # @return [OpenStudio::Model::Construction]
  def model_get_adiabatic_floor_construction(model)
    adiabatic_construction_name = 'Floor Adiabatic construction'

    # Check if adiabatic floor construction already exists in the model
    adiabatic_construct_exists = model.getConstructionByName(adiabatic_construction_name).is_initialized

    # Check to see if adiabatic construction has been constructed. If so, return it. Else, construct it.
    return model.getConstructionByName(adiabatic_construction_name).get if adiabatic_construct_exists

    # Assign construction to adiabatic construction
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
    normalweight_concrete_floor.setThermalConductivity(2.31)
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
    floor_adiabatic_construction.setName(adiabatic_construction_name)
    floor_layers = OpenStudio::Model::MaterialVector.new
    floor_layers << cp02_carpet_pad
    floor_layers << normalweight_concrete_floor
    floor_layers << nonres_floor_insulation
    floor_adiabatic_construction.setLayers(floor_layers)

    return floor_adiabatic_construction


  end

  # Checks to see if the an adiabatic wall construction has been constructed in an OpenStudio model.
  # If so, it returns it. If not, it constructs an adiabatic wall construction, adds it to the model,
  # and then returns it.
  # @return [OpenStudio::Model::Construction]
  def model_get_adiabatic_wall_construction(model)
    adiabatic_construction_name = 'Wall Adiabatic construction'

    # Check if adiabatic wall construction already exists in the model
    adiabatic_construct_exists = model.getConstructionByName(adiabatic_construction_name).is_initialized

    # Check to see if adiabatic construction has been constructed. If so, return it. Else, construct it.
    return model.getConstructionByName(adiabatic_construction_name).get if adiabatic_construct_exists

    g01_13mm_gypsum_board = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    g01_13mm_gypsum_board.setName('G01 13mm gypsum board')
    g01_13mm_gypsum_board.setRoughness('Smooth')
    g01_13mm_gypsum_board.setThickness(0.0127)
    g01_13mm_gypsum_board.setThermalConductivity(0.1600)
    g01_13mm_gypsum_board.setDensity(800)
    g01_13mm_gypsum_board.setSpecificHeat(1090)
    g01_13mm_gypsum_board.setThermalAbsorptance(0.9)
    g01_13mm_gypsum_board.setSolarAbsorptance(0.7)
    g01_13mm_gypsum_board.setVisibleAbsorptance(0.5)

    wall_adiabatic_construction = OpenStudio::Model::Construction.new(model)
    wall_adiabatic_construction.setName(adiabatic_construction_name)
    wall_layers = OpenStudio::Model::MaterialVector.new
    wall_layers << g01_13mm_gypsum_board
    wall_layers << g01_13mm_gypsum_board
    wall_adiabatic_construction.setLayers(wall_layers)

    return wall_adiabatic_construction


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

    # The constructions lookup table uses a slightly different list of building types.
    @lookup_building_type = model_get_lookup_name(building_type)
    # TODO: this is a workaround.  Need to synchronize the building type names
    # across different parts of the code, including splitting of Office types
    case building_type
      when 'SmallOffice', 'MediumOffice', 'LargeOffice', 'SmallOfficeDetailed', 'MediumOfficeDetailed', 'LargeOfficeDetailed'
        new_lookup_building_type = building_type
      else
        new_lookup_building_type = model_get_lookup_name(building_type)
    end

    # Construct adiabatic constructions
    floor_adiabatic_construction = model_get_adiabatic_floor_construction(model)
    wall_adiabatic_construction = model_get_adiabatic_wall_construction(model)

    cp02_carpet_pad = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
    cp02_carpet_pad.setName('CP02 CARPET PAD')
    cp02_carpet_pad.setRoughness('VeryRough')
    cp02_carpet_pad.setThermalResistance(0.21648)
    cp02_carpet_pad.setThermalAbsorptance(0.9)
    cp02_carpet_pad.setSolarAbsorptance(0.7)
    cp02_carpet_pad.setVisibleAbsorptance(0.8)

    m10_200mm_concrete_block_basement_wall = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    m10_200mm_concrete_block_basement_wall.setName('M10 200mm concrete block basement wall')
    m10_200mm_concrete_block_basement_wall.setRoughness('MediumRough')
    m10_200mm_concrete_block_basement_wall.setThickness(0.2032)
    m10_200mm_concrete_block_basement_wall.setThermalConductivity(1.326)
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

    # Constructs all relevant ground FC factor method constructions
    model_set_below_grade_wall_constructions(model, @lookup_building_type, climate_zone)
    model_set_floor_constructions(model, @lookup_building_type, climate_zone)

    # Set all remaining wall and floor constructions
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
    spc_type = 'WholeBuilding' if template == 'NECB2011'
    bldg_def_const_set = model_add_construction_set(model, climate_zone, new_lookup_building_type, spc_type, is_residential)

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

      # If the standards space type is Attic the building type should be blank.
      if stds_spc_type == 'Attic'
        stds_building_type = ''
      end

      # Attempt to make a construction set for this space type and assign it if it can be created.
      spc_type_const_set = model_add_construction_set(model, climate_zone, stds_building_type, stds_spc_type, is_residential)
      if spc_type_const_set.is_initialized
        space_type.setDefaultConstructionSet(spc_type_const_set.get)
      end
    end

    # Add construction from story level, especially for the case when there are residential and nonresidential construction in the same building
    if new_lookup_building_type == 'SmallHotel' && template != 'NECB2011'
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
          data = standards_lookup_table_first(table_name: 'space_types', search_criteria: {'template' => template,
                                                                                           'building_type' => new_lookup_building_type,
                                                                                           'space_type' => space_type_name})
          exterior_spaces_area += space.floorArea
          story_exterior_residential_area += space.floorArea if data['is_residential'] == 'Yes' # "Yes" is residential, "No" or nil is nonresidential
        end
        is_residential = 'Yes' if story_exterior_residential_area / exterior_spaces_area >= 0.5
        next if is_residential == 'No'

        # if the story is identified as residential, assign residential construction set to the spaces on this story.
        building_story_const_set = model_add_construction_set(model, climate_zone, new_lookup_building_type, nil, is_residential)
        if building_story_const_set.is_initialized
          story.spaces.each do |space|
            space.setDefaultConstructionSet(building_story_const_set.get)
          end
        end
      end
      # Standards: For whole buildings or floors where 50% or more of the spaces adjacent to exterior walls are used primarily for living and sleeping quarters
    end

    # loop through ceiling surfaces and assign the plenum acoustical tile construction if the adjacent surface is a plenum floor
    model.getSurfaces.each do |surface|
      next unless surface.surfaceType == 'RoofCeiling' && surface.outsideBoundaryCondition == 'Surface'
      adj_surface = surface.adjacentSurface.get
      adj_space = adj_surface.space.get
      if adj_space.spaceType.is_initialized && adj_space.spaceType.get.standardsSpaceType.is_initialized
        adj_std_space_type = adj_space.spaceType.get.standardsSpaceType.get
        if adj_std_space_type.downcase == 'plenum'
          plenum_construction = adj_surface.construction
          if plenum_construction.is_initialized
            plenum_construction = plenum_construction.get
            surface.setConstruction(plenum_construction)
          end
        end
      end
    end

    # Make skylights have the same construction as fixed windows
    # sub_surface = self.getBuilding.defaultConstructionSet.get.defaultExteriorSubSurfaceConstructions.get
    # window_construction = sub_surface.fixedWindowConstruction.get
    # sub_surface.setSkylightConstruction(window_construction)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying constructions')

    return true
  end

  # Creates and sets below grade wall constructions for 90.1 prototype building models. These utilize
  # CFactorUndergroundWallConstruction and require some additional parameters when compared to Construction
  # @param model[OpenStudio::Model::Model] OpenStudio Model
  # @param climate_zone [string] climate zone as described for prototype models. C-Factor is based on this parameter
  # @param building_type [string] the type of building
  # @return [void]
  def model_set_below_grade_wall_constructions(model, building_type, climate_zone)

    # Find ground contact wall building category
    construction_set_data = model_get_construction_set(building_type)
    building_type_category = construction_set_data['exterior_wall_building_category']

    wall_construction_properties = model_get_construction_properties(model, 'GroundContactWall', 'Mass', building_type_category, climate_zone)

    # If no construction properties are found at all, return and allow code to use default constructions
    return if wall_construction_properties.nil?

    c_factor_ip = wall_construction_properties['assembly_maximum_c_factor']

    # If no c-factor is found in construction properties, return and allow code to use defaults
    return if c_factor_ip.nil?

    # convert to SI
    c_factor_si = c_factor_ip * OpenStudio.convert(1.0, 'Btu/ft^2*h*R', 'W/m^2*K').get

    # iterate through spaces and set any necessary CFactorUndergroundWallConstructions
    model.getSpaces.each do |space|

      # Get height of the first below grade wall in this space. Will return nil if none are found.
      below_grade_wall_height = model_get_space_below_grade_wall_height(space)
      next if below_grade_wall_height.nil?

      c_factor_wall_name = "Basement Wall C-Factor #{c_factor_si.round(2)} Height #{below_grade_wall_height.round(2)}"

      # Check if the wall construction has been constructed already. If so, look it up in the model
      if model.getCFactorUndergroundWallConstructionByName(c_factor_wall_name).is_initialized
        basement_wall_construction = model.getCFactorUndergroundWallConstructionByName(c_factor_wall_name).get
      else
        # Create CFactorUndergroundWallConstruction objects
        basement_wall_construction = OpenStudio::Model::CFactorUndergroundWallConstruction.new(model)
        basement_wall_construction.setCFactor(c_factor_si)
        basement_wall_construction.setName(c_factor_wall_name)
        basement_wall_construction.setHeight(below_grade_wall_height)
      end

      # Set surface construction for walls adjacent to ground (i.e. basement walls)
      space.surfaces.each do |surface|
        if surface.surfaceType == 'Wall' && surface.outsideBoundaryCondition == 'OtherSideCoefficients'
          surface.setConstruction(basement_wall_construction)
          surface.setOutsideBoundaryCondition('GroundFCfactorMethod')
        end
      end
    end
  end

  # Finds heights of the first below grade walls and returns them as a numeric. Used when defining C Factor walls.
  # Returns nil if the space is above grade.
  # @param space [OpenStudio::Model::Space] space to determine below grade wall height
  # @return [Numeric, nil]
  def model_get_space_below_grade_wall_height(space)

    # find height of first below-grade wall adjacent to the ground
    space.surfaces.each do |surface|
      next unless surface.surfaceType == 'Wall'

      boundary_condition = surface.outsideBoundaryCondition
      next unless boundary_condition == 'OtherSideCoefficients' || boundary_condition == 'Ground'

      # calculate wall height as difference of maximum and minimum z values, assuming square, vertical walls
      z_values = []
      surface.vertices.each do |vertex|
        z_values << vertex.z
      end
      surface_height = z_values.max - z_values.min
      return surface_height
    end

    return nil
  end

  # Searches a model for spaces adjacent to ground. If the slab's perimeter is adjacent to ground, the length is
  # calculated. Used for F-Factor floors that require additional parameters.
  # @param model [OpenStudio Model] OpenStudio model being modified
  # @param building_type [string] the type of building
  # @param climate_zone [string] climate zone as described for prototype models. F-Factor is based on this parameter
  def model_set_floor_constructions(model, building_type, climate_zone)

    #Find ground contact wall building category
    construction_set_data = model_get_construction_set(building_type)
    building_type_category = construction_set_data['ground_contact_floor_building_category']

    # Find Floor F factor
    floor_construction_properties = model_get_construction_properties(model, 'GroundContactFloor', 'Unheated', building_type_category, climate_zone)

    #If no construction properties are found at all, return and allow code to use default constructions
    return if floor_construction_properties.nil?

    f_factor_ip = floor_construction_properties['assembly_maximum_f_factor']

    #If no f-factor is found in construction properties, return and allow code to use defaults
    return if f_factor_ip.nil?

    f_factor_si = f_factor_ip * OpenStudio.convert(1.0, 'Btu/ft*h*R', 'W/m*K').get

    # iterate through spaces and set FFactorGroundFloorConstruction to surfaces if applicable
    model.getSpaces.each do |space|
      # Find this space's exposed floor area and perimeter. NOTE: this assumes only only floor per space.
      perimeter, area = model_get_f_floor_geometry(space)
      next if area == 0 # skip floors not adjacent to ground

      # Record combination of perimeter and area. Each unique combination requires a FFactorGroundFloorConstruction.
      # NOTE: periods '.' were causing issues and were therefore removed. Caused E+ error with duplicate names despite
      #       being different.
      f_floor_const_name = "Foundation F #{f_factor_si.round(2)} Perim #{perimeter.round(2)} Area #{area.round(2)}".gsub('.', '')

      # Check if the floor construction has been constructed already. If so, look it up in the model
      if model.getFFactorGroundFloorConstructionByName(f_floor_const_name).is_initialized
        f_floor_construction = model.getFFactorGroundFloorConstructionByName(f_floor_const_name).get
      else
        f_floor_construction = OpenStudio::Model::FFactorGroundFloorConstruction.new(model)
        f_floor_construction.setName(f_floor_const_name)
        f_floor_construction.setFFactor(f_factor_si)
        f_floor_construction.setArea(area)
        f_floor_construction.setPerimeterExposed(perimeter)
      end

      # Set surface construction for floors adjacent to ground
      space.surfaces.each do |surface|
        if surface.surfaceType == 'Floor' && surface.outsideBoundaryCondition == 'Ground'
          surface.setConstruction(f_floor_construction)
          surface.setOutsideBoundaryCondition('GroundFCfactorMethod')
        end
      end
    end
  end

  # This function returns the space's ground perimeter and area. Assumes only one floor per space!
  # @param space[OpenStudio::Model::Space]
  # @return [Numeric, Numeric]
  def model_get_f_floor_geometry(space)

    perimeter = 0

    floors = []

    # Find space's floors
    space.surfaces.each do |surface|
      if surface.surfaceType == 'Floor' && surface.outsideBoundaryCondition == 'Ground'
        floors << surface
      end
    end

    # Raise a warning for any space with more than 1 ground contact floor surface.
    if floors.length > 1
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Space: #{space.name.to_s} has more than one ground contact floor. FFactorGroundFloorConstruction constructions in this space may be incorrect")
    elsif floors.empty? #If this space has no ground contact floors, return 0
      return 0, 0
    end

    floor = floors[0]

    # cycle through surfaces in space
    space.surfaces.each do |surface|

      # find perimeter of floor by finding intersecting outdoor walls and measuring the intersection
      if surface.surfaceType == 'Wall' && surface.outsideBoundaryCondition == 'Outdoors'

        perimeter += model_calculate_wall_and_floor_intersection(surface, floor)
      end
    end

    # Get floor area
    area = floor.netArea

    return perimeter, area
  end

  # This function returns the length of intersection between a wall and floor sharing space. Primarily used for
  # FFactorGroundFloorConstruction exposed perimeter calculations.
  # NOTE: this calculation has a few assumptions:
  # - Floors are flat. This means they have a constant z-axis value.
  # - If a wall shares an edge with a floor, it's assumed that edge intersects with only this floor.
  # - The wall and floor share a common space. This space is assumed to only have one floor!
  # @param wall[OpenStudio::Model::Surface] wall surface being compared to the floor of interest
  # @param floor[OpenStudio::Model::Surface] floor occupying same space as wall. Edges checked for interesections with wall
  # @return [Numeric] returns the intersection/overlap length of the wall and floor of interest
  def model_calculate_wall_and_floor_intersection(wall, floor)

    # Used for determining if two points are 'equal' if within this length
    tolerance = 0.0001

    # Get floor and wall edges
    wall_edge_array = model_get_surface_edges(wall)
    floor_edge_array = model_get_surface_edges(floor)

    # Floor assumed flat and constant in x-y plane (i.e. a single z value)
    floor_z_value = floor_edge_array[0][0].z

    # Iterate through wall edges
    wall_edge_array.each do |wall_edge|

      wall_edge_p1 = wall_edge[0]
      wall_edge_p2 = wall_edge[1]

      # If points representing the wall surface edge have different z-coordinates, this edge is not parallel to the
      # floor and can be skipped

      if tolerance <= (wall_edge_p1.z - wall_edge_p2.z).abs
        next
      end

      # If wall edge is parallel to the floor, ensure it's on the same x-y plane as the floor.
      if tolerance <= (wall_edge_p1.z - floor_z_value).abs
        next
      end

      # If the edge is parallel with the floor and in the same x-y plane as the floor, assume an intersection the
      # length of the wall edge
      edge_vector = OpenStudio::Vector3d.new(wall_edge_p1-wall_edge_p2)
      return(edge_vector.length)

    end

    # If no edges intersected, return 0
    return 0

  end

  # Returns an array of OpenStudio::Point3D pairs of an OpenStudio::Model::Surface's edges. Used to calculate surface
  # intersections.
  # @param surface[OpenStudio::Model::Surface] - surface whose edges are being returned
  # @return [Array<Array(OpenStudio::Point3D, OpenStudio::Point3D)>] - array of pair of points describing the line segment of an edge
  def model_get_surface_edges(surface)

    vertices = surface.vertices
    n_vertices = vertices.length

    # Create edge hash that keeps track of all edges in surface. An edge is defined here as an array of length 2
    # containing two OpenStudio::Point3Ds that define the line segment representing a surface edge.
    edge_array = [] # format edge_array[i] = [OpenStudio::Point3D, OpenStudio::Point3D]

    # Iterate through each vertex in the surface and construct an edge for it
    for edge_counter in 0..n_vertices - 1

      # If not the last vertex in surface
      if edge_counter < n_vertices-1
        edge_array << [vertices[edge_counter], vertices[edge_counter + 1]]
      else # Make index adjustments for final index in vertices array
        edge_array << [vertices[edge_counter], vertices[0]]
      end
    end

    return edge_array
  end

  # Adds internal mass objects and constructions based on the building type
  #
  # @param building_type [String] the type of building
  # @return [Bool] returns true if successful, false if not
  def model_add_internal_mass(model, building_type)

    # Assign a material to all internal mass objects
    material = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    material.setName('Std Wood 6inch')
    material.setRoughness('MediumSmooth')
    material.setThickness(0.15)
    material.setThermalConductivity(0.12)
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
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Set internal mass construction for internal mass '#{internal_mass.name}' in space '#{space.name}'.")
      end
    end

    # add internal mass
    # not required for NECB2011
    unless (template == 'NECB2011') ||
           (building_type.include?('DataCenter')) ||
           ((building_type == 'SmallHotel') &&
            (template == '90.1-2004' || template == '90.1-2007' || template == '90.1-2010' || template == '90.1-2013' || template == 'NREL ZNE Ready 2017'))
      internal_mass_def = OpenStudio::Model::InternalMassDefinition.new(model)
      internal_mass_def.setSurfaceAreaperSpaceFloorArea(2.0)
      internal_mass_def.setConstruction(construction)
      model.getSpaces.each do |space|
        # only add internal mass objects to conditioned spaces
        next unless space_cooled?(space)
        next unless space_heated?(space)
        internal_mass = OpenStudio::Model::InternalMass.new(internal_mass_def)
        internal_mass.setName("#{space.name} Mass")
        internal_mass.setSpace(space)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Added internal mass '#{internal_mass.name}' to space '#{space.name}'.")
      end
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding internal mass')

    return true
  end

  # Creates thermal zones to contain each space, as defined for each building in the
  # system_to_space_map inside the Prototype.building_name
  # e.g. (Prototype.secondary_school.rb) file.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not
  def model_create_thermal_zones(model, space_multiplier_map = nil)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started creating thermal zones')

    # Retrieve zone multipliers if non assigned via the space_multiplier_map
    if space_multiplier_map.nil?
      space_multiplier_map = {}
      model.getSpaces.each do |spc|
        space_multiplier_map.store(spc.name.to_s, spc.thermalZone.get.multiplier.to_int)
      end
    end

    # Remove any Thermal zones assigned
    model.getThermalZones.each(&:remove)

    # Create a thermal zone for each space in the self
    model.getSpaces.sort.each do |space|
      zone = OpenStudio::Model::ThermalZone.new(model)
      zone.setName("#{space.name} ZN")
      unless space_multiplier_map[space.name.to_s].nil? || (space_multiplier_map[space.name.to_s] == 1)
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
        if template == 'NECB2011'
          # Set Ideal loads to thermal zone for sizing for NECB needs. We need this for sizing.
          ideal_loads = OpenStudio::Model::ZoneHVACIdealLoadsAirSystem.new(model)
          ideal_loads.addToThermalZone(zone)
        end
     end
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished creating thermal zones')
 end

  # Loop through thermal zones and model_run(model)  thermal_zone.add_exhaust
  # If kitchen_makeup is "None" then exhaust will be modeled in every kitchen zone without makeup air
  # If kitchen_makeup is "Adjacent" then exhaust will be modeled in every kitchen zone. Makeup air will be provided when there as an adjacent dining,cafe, or cafeteria zone of the same building type.
  # If kitchen_makeup is "Largest Zone" then exhaust will only be modeled in the largest kitchen zone, but the flow rate will be based on the kitchen area for all zones. Makeup air will be modeled in the largest dining,cafe, or cafeteria zone of the same building type.
  #
  # @param kitchen_makeup [String] Valid choices are
  # @return [Hash] Hash of newly made exhaust fan objects along with secondary exhaust and zone mixing objects
  def model_add_exhaust(model, kitchen_makeup = 'Adjacent') # kitchen_makeup options are (None, Largest Zone, Adjacent)
    zone_exhaust_fans = {}

    # apply use specified kitchen_makup logic
    if !['Adjacent', 'Largest Zone'].include?(kitchen_makeup)

      if kitchen_makeup != 'None'
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
      standard_space_types_with_makup_air[['FullServiceRestaurant', 'Kitchen']] = ['FullServiceRestaurant', 'Dining']
      standard_space_types_with_makup_air[['QuickServiceRestaurant', 'Kitchen']] = ['QuickServiceRestaurant', 'Dining']
      standard_space_types_with_makup_air[['Hospital', 'Kitchen']] = ['Hospital', 'Dining']
      standard_space_types_with_makup_air[['SecondarySchool', 'Kitchen']] = ['SecondarySchool', 'Cafeteria']
      standard_space_types_with_makup_air[['PrimarySchool', 'Kitchen']] = ['PrimarySchool', 'Cafeteria']
      standard_space_types_with_makup_air[['LargeHotel', 'Kitchen']] = ['LargeHotel', 'Cafe']

      # gather information on zones organized by standards building type and space type. zone may be in this multiple times if it has multiple space types
      zones_by_standards = {}

      model.getThermalZones.sort.each do |thermal_zone|
        # get space type ratio for spaces in zone
        space_type_hash = {} # key is  space type,  value hash with floor area, standards building type, standards space type, and array of adjacent zones
        thermal_zone.spaces.each do |space|
          next unless space.spaceType.is_initialized
          next unless space.partofTotalFloorArea
          space_type = space.spaceType.get
          next unless space_type.standardsBuildingType.is_initialized
          next unless space_type.standardsSpaceType.is_initialized

          # add entry in hash for space_type_standardsif it doesn't already exist
          unless space_type_hash.key?(space_type)
            space_type_hash[space_type] = {}
            space_type_hash[space_type][:effective_floor_area] = 0.0
            space_type_hash[space_type][:standards_array] = [space_type.standardsBuildingType.get, space_type.standardsSpaceType.get]
            if kitchen_makeup == 'Adjacent'
              space_type_hash[space_type][:adjacent_zones] = []
            end
          end

          # populate floor area
          space_type_hash[space_type][:effective_floor_area] += space.floorArea * space.multiplier

          # TODO: - populate adjacent zones (need to add methods to space and zone for this)
          if kitchen_makeup == 'Adjacent'
            space_type_hash[space_type][:adjacent_zones] << nil
          end

          # populate zones_by_standards
          unless zones_by_standards.key?(space_type_hash[space_type][:standards_array])
            zones_by_standards[space_type_hash[space_type][:standards_array]] = {}
          end
          zones_by_standards[space_type_hash[space_type][:standards_array]][thermal_zone] = space_type_hash
        end
      end

      if kitchen_makeup == 'Largest Zone'

        zones_applied = [] # add thermal zones to this ones they have had thermal_zone.add_exhaust model_run(model)  on it

        # loop through standard_space_types_with_makup_air
        standard_space_types_with_makup_air.each do |makeup_target, makeup_source|
          # hash to manage lookups
          markup_target_effective_floor_area = {}
          markup_source_effective_floor_area = {}

          if zones_by_standards.key?(makeup_target)

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
            if zones_by_standards.key?(makeup_source)

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

            OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Largest #{makeup_target} is #{largest_target_zone.name} which will provide exhaust for #{target_effective_floor_area} m^2")
            OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', "Largest #{makeup_source} is #{largest_source_zone.name} which will provide makeup air for #{makeup_target}")

            # add in extra arguments for makeup air
            exhaust_makeup_inputs = {}
            exhaust_makeup_inputs[makeup_target] = {} # for now only one makeup target per zone, but method could have multiple
            exhaust_makeup_inputs[makeup_target][:target_effective_floor_area] = target_effective_floor_area
            exhaust_makeup_inputs[makeup_target][:source_zone] = largest_source_zone

            # add exhaust
            next if zones_applied.include?(largest_target_zone) # would only hit this if zone has two space types each requesting makeup air
            zone_exhaust_hash = thermal_zone_add_exhaust(largest_target_zone, exhaust_makeup_inputs)
            zones_applied << largest_target_zone
            zone_exhaust_fans.merge!(zone_exhaust_hash)

          end
        end

        # add exhaust to zones that did not contain space types with standard_space_types_with_makup_air
        zones_by_standards.each do |standards_array, zones_hash|
          next if standard_space_types_with_makup_air.key?(standards_array)

          # loop through zones adding exhaust
          zones_hash.each do |thermal_zone, space_type_hash|
            next if zones_applied.include?(thermal_zone)

            # add exhaust
            zone_exhaust_hash = thermal_zone_add_exhaust(thermal_zone)
            zones_applied << thermal_zone
            zone_exhaust_fans.merge!(zone_exhaust_hash)
          end
        end

      else # kitchen_makeup == "Adjacent"

        zones_applied = [] # add thermal zones to this ones they have had thermal_zone.add_exhaust model_run(model)  on it

        standard_space_types_with_makup_air.each do |makeup_target, makeup_source|
          if zones_by_standards.key?(makeup_target)
            # process zones of each makeup_target
            zones_by_standards[makeup_target].each do |thermal_zone, space_type_hash|
              # get adjacent zones
              adjacent_zones = thermal_zone_get_adjacent_zones_with_shared_wall_areas(thermal_zone)

              # find adjacent zones matching key and value from standard_space_types_with_makup_air
              first_adjacent_makeup_source = nil
              adjacent_zones.each do |adjacent_zone|
                next unless first_adjacent_makeup_source.nil?

                if zones_by_standards.key?(makeup_source) && zones_by_standards[makeup_source].key?(adjacent_zone)
                  first_adjacent_makeup_source = adjacent_zone

                  # TODO: - add in extra arguments for makeup air
                  exhaust_makeup_inputs = {}
                  exhaust_makeup_inputs[makeup_target] = {} # for now only one makeup target per zone, but method could have multiple
                  exhaust_makeup_inputs[makeup_target][:source_zone] = first_adjacent_makeup_source

                  # add exhaust
                  zone_exhaust_hash = thermal_zone_add_exhaust(thermal_zone, exhaust_makeup_inputs)
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

    # Fuel Equipment being used to model external elevators
    unless prototype_input['exterior_fuel_equipment1_power'].nil?
      fuel_ext_power = prototype_input['exterior_fuel_equipment1_power']
      fuel_ext_sch_name = prototype_input['exterior_fuel_equipment1_schedule']
      fuel_ext_name = 'Fuel equipment 1'
      fuel_ext_def = OpenStudio::Model::ExteriorFuelEquipmentDefinition.new(model)
      fuel_ext_def.setName("#{fuel_ext_name} Def")
      fuel_ext_def.setDesignLevel(fuel_ext_power)
      fuel_ext_sch = model_add_schedule(model, fuel_ext_sch_name)
      fuel_ext_lts = OpenStudio::Model::ExteriorFuelEquipment.new(fuel_ext_def, fuel_ext_sch)
      fuel_ext_lts.setFuelType('Electricity')
      fuel_ext_lts.setName(fuel_ext_name.to_s)
    end

    unless prototype_input['exterior_fuel_equipment2_power'].nil?
      fuel_ext_power = prototype_input['exterior_fuel_equipment2_power']
      fuel_ext_sch_name = prototype_input['exterior_fuel_equipment2_schedule']
      fuel_ext_name = 'Fuel equipment 2'
      fuel_ext_def = OpenStudio::Model::ExteriorFuelEquipmentDefinition.new(model)
      fuel_ext_def.setName("#{fuel_ext_name} Def")
      fuel_ext_def.setDesignLevel(fuel_ext_power)
      fuel_ext_sch = model_add_schedule(model, fuel_ext_sch_name)
      fuel_ext_lts = OpenStudio::Model::ExteriorFuelEquipment.new(fuel_ext_def, fuel_ext_sch)
      fuel_ext_lts.setFuelType('Electricity')
      fuel_ext_lts.setName(fuel_ext_name.to_s)
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
  def model_modify_infiltration_coefficients(model, building_type, climate_zone)
    # Select the terrain type, which
    # impacts wind speed, and in turn infiltration
    terrain = 'City'
    case template
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
    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        # TODO: make this consistent with newer prototypes
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

    case template
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        inside.setAlgorithm('TARP')
        outside.setAlgorithm('DOE-2')
      else
        inside.setAlgorithm('TARP')
        outside.setAlgorithm('TARP')
    end
  end

  # Set up daylight savings
  #
  def model_add_daylight_savings(model)

    start_date  = '2nd Sunday in March'
    end_date = '1st Sunday in November'

    runperiodctrl_daylgtsaving = model.getRunPeriodControlDaylightSavingTime
    runperiodctrl_daylgtsaving.setStartDate(start_date)
    runperiodctrl_daylgtsaving.setEndDate(end_date)

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Set Daylight Saving Start Date to #{start_date} and end date to #{end_date}.")
  end

  # Adds holidays to the model.
  # @todo enable holidays once supported inside OpenStudio schedules
  def model_add_holidays(model)
    newyear = OpenStudio::Model::RunPeriodControlSpecialDays.new('1/1', model)
    newyear.setName('New Years')
    newyear.setSpecialDayType('Holiday')

    fourth = OpenStudio::NthDayOfWeekInMonth.new(4)
    thurs = OpenStudio::DayOfWeek.new('Thursday')
    nov = OpenStudio::MonthOfYear.new('November')
    thanksgiving = OpenStudio::Model::RunPeriodControlSpecialDays.new(fourth, thurs, nov, model)
    thanksgiving.setName('Thanksgiving')
    thanksgiving.setSpecialDayType('Holiday')

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Added holidays: New Years, Thanksgiving.")
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
        # exit if is one of the 90.1 templates as their sizing paramters are explicitly specified in geometry osms
        return
      when 'CBES Pre-1978', 'CBES T24 1978', 'CBES T24 1992', 'CBES T24 2001', 'CBES T24 2005', 'CBES T24 2008'
        case building_type
          when 'Hospital', 'LargeHotel', 'MediumOffice', 'LargeOffice', 'MediumOfficeDetailed','LargeOfficeDetailed', 'Outpatient', 'PrimarySchool'
            clg = 1.0
            htg = 1.0
        end
      when 'NECB2011'
        raise('do not use this method for NECB')
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

    model.getFanConstantVolumes.sort.each {|obj| fan_constant_volume_apply_prototype_fan_pressure_rise(obj)}
    model.getFanVariableVolumes.sort.each {|obj| fan_variable_volume_apply_prototype_fan_pressure_rise(obj)}
    model.getFanOnOffs.sort.each {|obj| fan_on_off_apply_prototype_fan_pressure_rise(obj)}
    model.getFanZoneExhausts.sort.each {|obj| fan_zone_exhaust_apply_prototype_fan_pressure_rise(obj)}

    # Motor Efficiency
    model.getFanConstantVolumes.sort.each {|obj| prototype_fan_apply_prototype_fan_efficiency(obj)}
    model.getFanVariableVolumes.sort.each {|obj| prototype_fan_apply_prototype_fan_efficiency(obj)}
    model.getFanOnOffs.sort.each {|obj| prototype_fan_apply_prototype_fan_efficiency(obj)}
    model.getFanZoneExhausts.sort.each {|obj| prototype_fan_apply_prototype_fan_efficiency(obj)}

    # Gas Heating Coil
    model.getCoilHeatingGass.sort.each {|obj| coil_heating_gas_apply_prototype_efficiency(obj)}

    ##### Add Economizers
    apply_economizers(climate_zone, model)

    # TODO: What is the logic behind hard-sizing
    # hot water coil convergence tolerances?
    model.getControllerWaterCoils.sort.each {|obj| controller_water_coil_set_convergence_limits(obj)}

    # adjust defrost curve limits for coil heating dx single speed
    model.getCoilHeatingDXSingleSpeeds.sort.each {|obj| coil_heating_dx_single_speed_apply_defrost_eir_curve_limits(obj)}

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying prototype HVAC assumptions.')
  end

  # Applies the Prototype Building assumptions that contradict/supersede
  # the given standard.
  #
  # @param model [OpenStudio::Model::Model] the model
  def model_apply_prototype_hvac_efficiency_adjustments(model)

    # ERVs
    # Applies the DOE Prototype Building assumption that ERVs use
    # enthalpy wheels and therefore exceed the minimum effectiveness specified by 90.1
    model.getHeatExchangerAirToAirSensibleAndLatents.each {|obj| heat_exchanger_air_to_air_sensible_and_latent_apply_prototype_efficiency(obj)}

    return true
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
    if use_runmanager
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
    ext_wall = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionExtWall', [opaque_mat, insulation_mat], insulation_mat)
    ext_roof = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionExtRoof', [opaque_mat, insulation_mat], insulation_mat)
    ext_floor = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionExtFloor', [opaque_mat, insulation_mat], insulation_mat)
    grnd_wall = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionGrndWall', [opaque_mat, insulation_mat], insulation_mat)
    grnd_roof = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionGrndRoof', [opaque_mat, insulation_mat], insulation_mat)
    grnd_floor = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionGrndFloor', [opaque_mat, insulation_mat], insulation_mat)
    int_wall = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionIntWall', [opaque_mat, insulation_mat], insulation_mat)
    int_roof = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionIntRoof', [opaque_mat, insulation_mat], insulation_mat)
    int_floor = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionIntFloor', [opaque_mat, insulation_mat], insulation_mat)
    # # Subsurfaces
    fixed_window = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionFixed', [simple_glazing_mat])
    operable_window = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionOperable', [simple_glazing_mat])
    glass_door = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionDoor', [standard_glazing_mat])
    door = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionDoor', [opaque_mat, insulation_mat], insulation_mat)
    overhead_door = BTAP::Resources::Envelope::Constructions.create_construction(model, 'OpaqueConstructionOverheadDoor', [opaque_mat, insulation_mat], insulation_mat)
    skylt = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionSkylight', [standard_glazing_mat])
    daylt_dome = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionDomeConstruction', [standard_glazing_mat])
    daylt_diffuser = BTAP::Resources::Envelope::Constructions.create_construction(model, 'FenestrationConstructionDiffuserConstruction', [standard_glazing_mat])

    # Define Construction Sets
    # # Surface
    exterior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_surface_constructions(model, 'ExteriorSet', ext_wall, ext_roof, ext_floor)
    interior_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_surface_constructions(model, 'InteriorSet', int_wall, int_roof, int_floor)
    ground_construction_set = BTAP::Resources::Envelope::ConstructionSets.create_default_surface_constructions(model, 'GroundSet', grnd_wall, grnd_roof, grnd_floor)

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

  # Return the dominant standards building type
  def model_get_standards_building_type(model)

    # determine areas of each building type
    building_type_areas = {}
    model.getSpaces.each do |space|
      # ignore space if not part of total area
      next unless space.partofTotalFloorArea
      if space.spaceType.is_initialized
        space_type = space.spaceType.get
        if space_type.standardsBuildingType.is_initialized
          building_type = space_type.standardsBuildingType.get
          if building_type_areas[building_type].nil?
            building_type_areas[building_type] = space.floorArea
          else
            building_type_areas[building_type] += space.floorArea
          end
        end
      end
    end

    # return largest building type area
    building_type = building_type_areas.key(building_type_areas.values.max)

    if building_type.nil?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Model has no dominant standards building type.")
    else
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.prototype.Model', "#{building_type} is the dominant standards building type.")
    end

    return building_type
  end

  # Split all zones in the model into groups that are big enough to justify their own HVAC system type.
  # Similar to the logic from 90.1 Appendix G, but without regard to the fuel type of the existing HVAC system (because the model may not have one).
  #
  # @param min_area_m2[Double] the minimum area required to justify a different system type, default 20,000 ft^2
  # @return [Array<Hash>] an array of hashes of area information, with keys area_ft2, type, stories, and zones (an array of zones)
  def model_group_zones_by_type(model, min_area_m2 = 1858.0608)
    min_area_ft2 = OpenStudio.convert(min_area_m2, 'm^2', 'ft^2').get

    # Get occupancy type, fuel type, and area information for all zones, excluding unconditioned zones.
    # Occupancy types are:
    # Residential
    # NonResidential
    # Use 90.1-2010 so that retail and publicassembly are not split out
    zones = model_zones_with_occ_and_fuel_type(model, nil)

    # Ensure that there is at least one conditioned zone
    if zones.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.Model', 'The building does not appear to have any conditioned zones. Make sure zones have thermostat with appropriate heating and cooling setpoint schedules.')
      return []
    end

    # Group the zones by occupancy type
    type_to_area = Hash.new {0.0}
    zones_grouped_by_occ = zones.group_by {|z| z['occ']}

    # Determine the dominant occupancy type by area
    zones_grouped_by_occ.each do |occ_type, zns|
      zns.each do |zn|
        type_to_area[occ_type] += zn['area']
      end
    end
    dom_occ = type_to_area.sort_by {|k, v| v}.reverse[0][0]

    # Get the dominant occupancy type group
    dom_occ_group = zones_grouped_by_occ[dom_occ]

    # Check the non-dominant occupancy type groups to see if they are big enough to trigger the occupancy exception.
    # If they are, leave the group standing alone.
    # If they are not, add the zones in that group back to the dominant occupancy type group.
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

  # Split all zones in the model into groups that are big enough to justify their own HVAC system type.
  # Similar to the logic from 90.1 Appendix G, but without regard to the fuel type of the existing HVAC system (because the model may not have one).
  #
  # @param min_area_m2[Double] the minimum area required to justify a different system type, default 20,000 ft^2
  # @return [Array<Hash>] an array of hashes of area information, with keys area_ft2, type, stories, and zones (an array of zones)
  def model_group_zones_by_building_type(model, min_area_m2 = 1858.0608)
    min_area_ft2 = OpenStudio.convert(min_area_m2, 'm^2', 'ft^2').get

    # Get occupancy type, building type, fuel type, and area information for all zones, excluding unconditioned zones
    zones = model_zones_with_occ_and_fuel_type(model, nil)

    # Ensure that there is at least one conditioned zone
    if zones.size.zero?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.prototype.Model', 'The building does not appear to have any conditioned zones. Make sure zones have thermostat with appropriate heating and cooling setpoint schedules.')
      return []
    end

    # Group the zones by building type
    type_to_area = Hash.new {0.0}
    zones_grouped_by_bldg_type = zones.group_by {|z| z['bldg_type']}

    # Determine the dominant building type by area
    zones_grouped_by_bldg_type.each do |bldg_type, zns|
      zns.each do |zn|
        type_to_area[bldg_type] += zn['area']
      end
    end
    dom_bldg_type = type_to_area.sort_by {|k, v| v}.reverse[0][0]

    # Get the dominant building type group
    dom_bldg_type_group = zones_grouped_by_bldg_type[dom_bldg_type]

    # Check the non-dominant building type groups to see if they are big enough to trigger the building exception.
    # If they are, leave the group standing alone.
    # If they are not, add the zones in that group back to the dominant building type group.
    bldg_type_groups = []
    zones_grouped_by_bldg_type.each do |bldg_type, zns|
      # Skip the dominant building type
      next if bldg_type == dom_bldg_type

      # Add up the floor area of the group
      area_m2 = 0
      zns.each do |zn|
        area_m2 += zn['area']
      end
      area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get

      # If the non-dominant group is big enough, preserve that group.
      if area_ft2 > min_area_ft2
        bldg_type_groups << [bldg_type, zns]
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The portion of the building with a building type of #{bldg_type} is bigger than the minimum area of #{min_area_ft2.round} ft2.  It will be assigned a separate HVAC system type.")
        # Otherwise, add the zones back to the dominant group.
      else
        dom_bldg_type_group += zns
      end
    end
    # Add the dominant building type group to the list
    bldg_type_groups << [dom_bldg_type, dom_bldg_type_group]

    # Calculate the area for each of the final groups
    # and replace the zone hashes with an array of zone objects
    final_groups = []
    bldg_type_groups.each do |bldg_type, zns|
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
      group['type'] = bldg_type
      group['stories'] = num_stories
      group['zones'] = gp_zns
      final_groups << group

      # Report out the final grouping
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Final system type group: bldg_type = #{group['type']}, area = #{group['area_ft2'].round} ft2, num stories = #{group['stories']}, zones:")
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
  end

  # end reduce schedule

  # Determine the prototypical economizer type for the model.
  # Defaults to the pre-90.1-2010 assumption of DifferentialDryBulb.
  #
  # @param model [OpenStudio::Model::Model] the model
  # @param climate_zone [String] the climate zone
  # @return [String] the economizer type.  Possible values are:
  # 'NoEconomizer'
  # 'FixedDryBulb'
  # 'FixedEnthalpy'
  # 'DifferentialDryBulb'
  # 'DifferentialEnthalpy'
  # 'FixedDewPointAndDryBulb'
  # 'ElectronicEnthalpy'
  # 'DifferentialDryBulbAndEnthalpy'
  def model_economizer_type(model, climate_zone)
    economizer_type = 'DifferentialDryBulb'
    return economizer_type
  end

  def apply_economizers(climate_zone, model)
    # Create an economizer maximum OA fraction of 70%
    # to reflect damper leakage per PNNL
    econ_max_70_pct_oa_sch = OpenStudio::Model::ScheduleRuleset.new(model)
    econ_max_70_pct_oa_sch.setName('Economizer Max OA Fraction 70 pct')
    econ_max_70_pct_oa_sch.defaultDaySchedule.setName('Economizer Max OA Fraction 70 pct Default')
    econ_max_70_pct_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0.7)

    # Check each airloop
    model.getAirLoopHVACs.sort.each do |air_loop|
      economizer_required = false

      if air_loop_hvac_humidifier_count(air_loop) > 0
        # If airloop includes it is assumed that exception c to 90.1-2004 Section 6.5.1 applies
        # This exception exist through 90.1-2013, see Section 6.5.1.3
        economizer_required = false
      elsif @instvarbuilding_type == 'LargeOffice' &&
            air_loop.name.to_s.downcase.include?('datacenter') &&
            air_loop.name.to_s.downcase.include?('basement') &&
            !(template == '90.1-2004' || template == '90.1-2007')
        # System serving the data center in the basement of the large
        # office is assumed to be always large enough to require an
        # economizer when economizer requirement is based on equipment
        # size.
        #
        # No economizer modeled for 90.1-2004 and 2007:
        # Specific economizer requirements for computer rooms were
        # introduced in 90.1-2010. Before that, although not explicitly
        # specified, economizer requirements were aimed at comfort
        # cooling, not computer room cooling (as per input from the MSC).

        # Get the size threshold requirement
        search_criteria = {
          'template' => template,
          'climate_zone' => climate_zone,
          'data_center' => true
        }
        econ_limits = model_find_object(standards_data['economizers'], search_criteria)
        minimum_capacity_btu_per_hr = econ_limits['capacity_limit']
        economizer_required = minimum_capacity_btu_per_hr.nil? ? false : true
      elsif @instvarbuilding_type == 'LargeOffice' && air_loop_hvac_include_wshp?(air_loop)
        # WSHP serving the IT closets are assumed to always be too
        # small to require an economizer
        economizer_required = false
      elsif air_loop_hvac_economizer_required?(air_loop, climate_zone)
        economizer_required = true
      end

      if economizer_required
        # If an economizer is required, determine the economizer type
        # in the prototype buildings, which depends on climate zone.
        economizer_type = model_economizer_type(model, climate_zone)

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
        # oa_control.setMaximumFractionofOutdoorAirSchedule(econ_max_70_pct_oa_sch)

        # Check that the economizer type set by the prototypes
        # is not prohibited by code.  If it is, change to no economizer.
        unless air_loop_hvac_economizer_type_allowable?(air_loop, climate_zone)
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.prototype.Model', "#{air_loop.name} is required to have an economizer, but the type chosen, #{economizer_type} is prohibited by code for climate zone #{climate_zone}. Economizer type will be switched to No Economizer.")
          oa_control.setEconomizerControlType('NoEconomizer')
        end

      end
    end
  end

end

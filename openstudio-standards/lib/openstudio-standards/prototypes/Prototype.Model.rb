
# open the class to add methods to size all HVAC equipment
class OpenStudio::Model::Model

  # Let the model store and access its own template and climate zone
  attr_accessor :template
  attr_accessor :climate_zone
 
  # Creates a DOE prototype building model and replaces
  # the current model with this model.
  #
  # @param building_type [String] the building type
  # @param building_vintage [String] the building vintage
  # @param climate_zone [String] the climate zone  
  # @param debug [Boolean] If true, will report out more detailed debugging output
  # @return [Bool] returns true if successful, false if not
  # @example Create a Small Office, 90.1-2010, in ASHRAE Climate Zone 5A (Chicago)
  #   model.create_prototype_building('SmallOffice', '90.1-2010', 'ASHRAE 169-2006-5A')
  def create_prototype_building(building_type, building_vintage, climate_zone, sizing_run_dir = Dir.pwd, debug = false)  

    self.load_openstudio_standards_json
    lookup_building_type = self.get_lookup_name(building_type)
    
    # Assign the standards to the model
    self.template = building_vintage
    self.climate_zone = climate_zone    
    
    # Retrieve the Prototype Inputs from JSON
    search_criteria = {
      'template' => building_vintage,
      'building_type' => building_type
    }
    prototype_input = self.find_object(self.standards['prototype_inputs'], search_criteria)
    if prototype_input.nil?
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Could not find prototype inputs for #{search_criteria}, cannot create model.")
      return false
    end

    self.load_building_type_methods(building_type, building_vintage, climate_zone)
    self.load_geometry(building_type, building_vintage, climate_zone)
    self.getBuilding.setName("#{building_vintage}-#{building_type}-#{climate_zone} created: #{Time.new}")
    space_type_map = self.define_space_type_map(building_type, building_vintage, climate_zone)
    self.assign_space_type_stubs(lookup_building_type, space_type_map)
    self.add_loads(building_vintage, climate_zone)
    self.modify_infiltration_coefficients(building_type, building_vintage, climate_zone)
    self.modify_surface_convection_algorithm(building_vintage)
    self.add_constructions(lookup_building_type, building_vintage, climate_zone)
    self.create_thermal_zones(building_type,building_vintage, climate_zone)
    self.add_hvac(building_type, building_vintage, climate_zone, prototype_input, self.standards)
    self.add_swh(building_type, building_vintage, climate_zone, prototype_input, self.standards, space_type_map)
    self.add_exterior_lights(building_type, building_vintage, climate_zone, prototype_input)
    self.add_occupancy_sensors(building_type, building_vintage, climate_zone)
    self.add_design_days_and_weather_file(self.standards, building_type, building_vintage, climate_zone)
    self.set_sizing_parameters(building_type, building_vintage)
    self.yearDescription.get.setDayofWeekforStartDay('Sunday')

    # Perform a sizing run
    if self.runSizingRun("#{sizing_run_dir}/SizingRun1") == false
      return false
    end

    # If there are any multizone systems, set damper positions
    # and perform a second sizing run
    has_multizone_systems = false
    self.getAirLoopHVACs.sort.each do |air_loop|
      if air_loop.is_multizone_vav_system
        self.apply_multizone_vav_outdoor_air_sizing
        if self.runSizingRun("#{sizing_run_dir}/SizingRun2") == false
          return false
        end
        break
      end
    end

    # Apply the prototype HVAC assumptions
    # which include sizing the fan pressure rises based
    # on the flow rate of the system.
    self.applyPrototypeHVACAssumptions(building_type, building_vintage, climate_zone)
    
    # Apply the HVAC efficiency standard
    self.applyHVACEfficiencyStandard
    
    # Add daylighting controls per standard
    # only four zones in large hotel have daylighting controls
    # todo: YXC to merge to the main function
    if building_type != "LargeHotel"
      self.addDaylightingControls
    else
      self.add_daylighting_controls(building_vintage)
    end

    if building_type == "QuickServiceRestaurant" || building_type == "FullServiceRestaurant"
      self.update_exhaust_fan_efficiency(building_vintage)
    end
   
    # Add output variables for debugging
    if debug
      self.request_timeseries_outputs
    end
    
    # Finished
    model_status = 'final'
    self.save(OpenStudio::Path.new("#{sizing_run_dir}/#{model_status}.osm"), true)

    return true    

  end
 
  # Get the name of the building type used in lookups
  #
  # @param building_type [String] the building type
  #   a .osm file in the /resources directory
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
    end

    return lookup_name

  end 
 
 
  # Loads the library of methods specific to this building type
  #
  # @param building_type [String] the building type
  # @param building_vintage [String] the building vintage
  # @param climate_zone [String] the climate zone
  # @return [Bool] returns true if successful, false if not 
  def load_building_type_methods(building_type, building_vintage, climate_zone)
    
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
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model',"Building Type = #{building_type} not recognized")
      return false
    end
    
    lib_dir = File.expand_path( '../../..',File.dirname(__FILE__))
    require "#{lib_dir}/lib/openstudio-standards/prototypes/#{building_methods}"
    
    return true

  end 
 
  # Loads a geometry-only .osm as a starting point.
  #
  # @param building_type [String] the building type
  # @param building_vintage [String] the building vintage
  # @param climate_zone [String] the climate zone  
  # @return [Bool] returns true if successful, false if not
  def load_geometry(building_type, building_vintage, climate_zone)
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started adding geometry')    
    
    # Determine which geometry file to use
    # based on building_type and template
    case building_type
    when 'SecondarySchool'
      if building_vintage == 'DOE Ref Pre-1980' || building_vintage == 'DOE Ref 1980-2004'
        geometry_file = 'Geometry.secondary_school_pre_1980_to_2004.osm'
      else
        geometry_file = 'Geometry.secondary_school.osm'
      end      
    when 'PrimarySchool'
      if building_vintage == 'DOE Ref Pre-1980' || building_vintage == 'DOE Ref 1980-2004'
        geometry_file = 'Geometry.primary_school_pre_1980_to_2004.osm'
      else
        geometry_file = 'Geometry.primary_school.osm'
      end 
    when 'SmallOffice'
      if building_vintage == 'DOE Ref Pre-1980'
        geometry_file = 'Geometry.small_office_pre_1980.osm'
      else
        geometry_file = 'Geometry.small_office.osm'
      end
      alt_search_name = 'Office'
    when 'MediumOffice'
      geometry_file = 'Geometry.medium_office.osm'
      alt_search_name = 'Office'
    when 'LargeOffice'
      alt_search_name = 'Office'
      case building_vintage
      when 'DOE Ref Pre-1980','DOE Ref 1980-2004','DOE Ref 2004'
        geometry_file = 'Geometry.large_office.osm'
      else
        geometry_file = 'Geometry.large_office_2010.osm'
      end
    when 'SmallHotel'
      case building_vintage
      when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
        geometry_file = 'Geometry.small_hotel_doe.osm'
      when '90.1-2004'
        geometry_file = 'Geometry.small_hotel_pnnl2004.osm'
      when '90.1-2007'
        geometry_file = 'Geometry.small_hotel_pnnl2007.osm'
      when '90.1-2010'
        geometry_file = 'Geometry.small_hotel_pnnl2010.osm'
      when '90.1-2013'
        geometry_file = 'Geometry.small_hotel_pnnl2013.osm'
      end
    when 'LargeHotel'
      case building_vintage
      when 'DOE Ref Pre-1980','DOE Ref 1980-2004','DOE Ref 2004'
        geometry_file = 'Geometry.large_hotel.doe.osm'
      when '90.1-2007','90.1-2004'
        geometry_file = 'Geometry.large_hotel.2004_2007.osm'
      when '90.1-2010'
        geometry_file = 'Geometry.large_hotel.2010.osm'
      else
        geometry_file = 'Geometry.large_hotel.2013.osm'
      end
    when 'Warehouse'
      geometry_file = 'Geometry.warehouse.osm'
    when 'RetailStandalone'
      case building_vintage
      when 'DOE Ref Pre-1980','DOE Ref 1980-2004','DOE Ref 2004'
        geometry_file = 'Geometry.retail_standalone.pre1980_post1980.osm'
      when '90.1-2004','90.1-2007'
        geometry_file = 'Geometry.retail_standalone.2004_2007.osm'
      else #'90.1-2010', '90.1-2013'
        geometry_file = 'Geometry.retail_standalone.2010_2013.osm'
      end
      alt_search_name = 'Retail'
    when 'RetailStripmall'
      geometry_file = 'Geometry.retail_stripmall.osm'
      alt_search_name = 'StripMall'
    when 'QuickServiceRestaurant'
      case building_vintage
      when 'DOE Ref Pre-1980'
        geometry_file = 'Geometry.quick_service_restaurant_pre1980.osm'
      when 'DOE Ref 1980-2004','90.1-2010','90.1-2007','90.1-2004','90.1-2013'
        geometry_file = 'Geometry.quick_service_restaurant_allothers.osm'
      end
    when 'FullServiceRestaurant'
      case building_vintage
      when 'DOE Ref Pre-1980'
        geometry_file = 'Geometry.full_service_restaurant_pre1980.osm'
      when 'DOE Ref 1980-2004','90.1-2010','90.1-2007','90.1-2004','90.1-2013'
        geometry_file = 'Geometry.full_service_restaurant_allothers.osm'
      end
    when 'Hospital'
      geometry_file = 'Geometry.hospital.osm'
    when 'Outpatient'
      geometry_file = 'Geometry.outpatient.osm'
    when 'MidriseApartment'
      geometry_file = 'Geometry.mid_rise_apartment.osm'
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model',"Building Type = #{building_type} not recognized")
      return false
    end
    
    # Load the geometry .osm
    top_dir = File.expand_path( '../../..',File.dirname(__FILE__))
    geom_dir = "#{top_dir}/data/geometry"
    self.replace_model("#{geom_dir}/#{geometry_file}")
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding geometry')    
    
    return true
    
  end 
 
  # Replaces all objects in the current model
  # with the objects in the .osm.  Typically used to
  # load a model as a starting point.
  #
  # @param path_to_osm [String] the path to a .osm file.
  # @return [Bool] returns true if successful, false if not 
  def replace_model(path_to_osm)
    
    # Take the existing model and remove all the objects 
    # (this is cheesy), but need to keep the same memory block
    handles = OpenStudio::UUIDVector.new
    self.objects.each {|o| handles << o.handle}
    self.removeObjects(handles)

    # Load geometry from the saved geometry.osm
    geom_model = safe_load_model(path_to_osm)

    # Add the objects from the geometry model to the working model
    self.addObjects(geom_model.toIdfFile.objects)

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
  def assign_space_type_stubs(building_type, space_type_map)

    space_type_map.each do |space_type_name, space_names|
      # Create a new space type
      stub_space_type = OpenStudio::Model::SpaceType.new(self)
      stub_space_type.setStandardsBuildingType(building_type)
      stub_space_type.setStandardsSpaceType(space_type_name)
        
      space_names.each do |space_name|
        space = self.getSpaceByName(space_name)
        next if space.empty?
        space = space.get
        space.setSpaceType(stub_space_type)

        #OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Setting #{space.name} to #{building_type}.#{space_type_name}")
      end
    end

    return true
  end

  def assign_building_story(building_type, building_vintage, climate_zone, building_story_map)
    building_story_map.each do |building_story_name, space_names|
      stub_building_story = OpenStudio::Model::BuildingStory.new(self)
      stub_building_story.setName(building_story_name)
      
      space_names.each do |space_name|
        space = self.getSpaceByName(space_name)
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
  # @param building_vintage [String] the template/standard to draw data from
  # @param climate_zone [String] the name of the climate zone the building is in
  # @return [Bool] returns true if successful, false if not  

  def add_loads(building_vintage, climate_zone)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying space types (loads)')

    # Loop through all the space types currently in the model,
    # which are placeholders, and generate actual space types for them.
    self.getSpaceTypes.each do |stub_space_type|

      # Get the standard building type
      # from the stub
      # puts "stub_space_type = #{stub_space_type}"
      
      stds_building_type = nil
      if stub_space_type.standardsBuildingType.is_initialized
        stds_building_type = stub_space_type.standardsBuildingType.get
      else
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Space type called '#{stub_space_type.name}' has no standards building type.")
        return false
      end
      #puts "stds_building_type = #{stds_building_type}"
      
      # Get the standards space type
      # from the stub
      stds_spc_type = nil
      if stub_space_type.standardsSpaceType.is_initialized
        stds_spc_type = stub_space_type.standardsSpaceType.get
      else
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Space type called '#{stub_space_type.name}' has no standards space type.")
        return false
      end
      # puts "stds_spc_type = #{stds_spc_type}"
      new_space_type = self.add_space_type(building_vintage, 'ClimateZone 1-8', stds_building_type, stds_spc_type)

      # Apply the new space type to the building      
      stub_space_type.spaces.each do |space|
        space.setSpaceType(new_space_type)
        #OpenStudio::logFree(OpenStudio::Info, "openstudio.prototype.Model", "Setting #{space.name} to #{new_space_type.name.get}")
      end
        
      # Remove the stub space type
      stub_space_type.remove

    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying space types (loads)')
    
    return true

  end

  # Adds code-minimum constructions based on the building type
  # as defined in the OpenStudio_Standards_construction_sets.json file.
  # Where there is a separate construction set specified for the 
  # individual space type, this construction set will be created and applied
  # to this space type, overriding the whole-building construction set.
  #
  # @param building_type [String] the type of building
  # @param building_vintage [String] the template/standard to draw data from
  # @param climate_zone [String] the name of the climate zone the building is in
  # @return [Bool] returns true if successful, false if not   
  def add_constructions(building_type, building_vintage, climate_zone)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying constructions')
    is_residential = "No"  #default is nonresidential for building level

    # Assign construction to adiabatic construction
    # Assign a material to all internal mass objects
    cp02_carpet_pad = OpenStudio::Model::MasslessOpaqueMaterial.new(self)
    cp02_carpet_pad.setName('CP02 CARPET PAD')
    cp02_carpet_pad.setRoughness("VeryRough")
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
    nonres_floor_insulation.setRoughness("MediumSmooth")
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

    m10_200mm_concrete_block_basement_wall= OpenStudio::Model::StandardOpaqueMaterial.new(self)
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

    self.getSurfaces.each do |surface|
      if surface.outsideBoundaryCondition.to_s == "Adiabatic"
        if surface.surfaceType.to_s == "Wall"
          surface.setConstruction(wall_adiabatic_construction)
        else
          surface.setConstruction(floor_adiabatic_construction)
        end
      elsif  surface.outsideBoundaryCondition.to_s == "OtherSideCoefficients"
        # Ground
        if surface.surfaceType.to_s == "Wall"
          surface.setOutsideBoundaryCondition("Ground")
          surface.setConstruction(basement_wall_construction)
        else
          surface.setOutsideBoundaryCondition("Ground")
          surface.setConstruction(basement_floor_construction)
        end
      end
    end

    # Make the default construction set for the building
    bldg_def_const_set = self.add_construction_set(building_vintage, climate_zone, building_type, nil, is_residential)

    if bldg_def_const_set.is_initialized
      self.getBuilding.setDefaultConstructionSet(bldg_def_const_set.get)
    else
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Could not create default construction set for the building.')
      return false
    end
    
    # Make a construction set for each space type, if one is specified
    self.getSpaceTypes.each do |space_type|
    
      # Get the standards building type
      stds_building_type = nil
      if space_type.standardsBuildingType.is_initialized
        stds_building_type = space_type.standardsBuildingType.get
      else
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Space type called '#{space_type.name}' has no standards building type.")
      end
      
      # Get the standards space type
      stds_spc_type = nil
      if space_type.standardsSpaceType.is_initialized
        stds_spc_type = space_type.standardsSpaceType.get
      else
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Space type called '#{space_type.name}' has no standards space type.")
      end    
    
      # If the standards space type is Attic,
      # the building type should be blank.
      if stds_spc_type == 'Attic'
        stds_building_type = ''
      end

      # Attempt to make a construction set for this space type
      # and assign it if it can be created.
      spc_type_const_set = self.add_construction_set(building_vintage, climate_zone, stds_building_type, stds_spc_type, is_residential)
      if spc_type_const_set.is_initialized
        space_type.setDefaultConstructionSet(spc_type_const_set.get)
      end
    
    end
    
    # Add construction from story level, especially for the case when there are residential and nonresidential construction in the same building
    if building_type == 'SmallHotel'
      self.getBuildingStorys.each do |story|
        next if story.name.get == 'AtticStory'
        puts "story = #{story.name}"
        is_residential = "No"  #default for building story level
        exterior_spaces_area = 0
        story_exterior_residential_area = 0
        
        # calculate the propotion of residential area in exterior spaces, see if this story is residential or not
        story::spaces.each do |space|
          next if space.exteriorWallArea == 0
          space_type = space.spaceType.get
          if space_type.standardsSpaceType.is_initialized
            space_type_name = space_type.standardsSpaceType.get
          end
          data = self.find_object(self.standards['space_types'], {'template'=>building_vintage, 'building_type'=>building_type, 'space_type'=>space_type_name})
          exterior_spaces_area += space.floorArea
          story_exterior_residential_area += space.floorArea if data['is_residential'] == "Yes"   # "Yes" is residential, "No" or nil is nonresidential
        end
        is_residential = "Yes" if story_exterior_residential_area/exterior_spaces_area >= 0.5
        next if is_residential == "No"
        
        # if the story is identified as residential, assign residential construction set to the spaces on this story.
        building_story_const_set = self.add_construction_set(building_vintage, climate_zone, building_type, nil, is_residential)
        if building_story_const_set.is_initialized
          story::spaces.each do |space|
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
    self.getSpaces.each do |space|
      internal_masses = space.internalMass
      internal_masses.each do |internal_mass|
        internal_mass.internalMassDefinition.setConstruction(construction)
      end
    end

    # get all the space types that are conditioned
    conditioned_space_names = find_conditioned_space_names(building_type, building_vintage, climate_zone)
    
    # add internal mass
    unless (building_type == 'SmallHotel') &&
        (building_vintage == '90.1-2004' or building_vintage == '90.1-2007' or building_vintage == '90.1-2010' or building_vintage == '90.1-2013')
      internal_mass_def = OpenStudio::Model::InternalMassDefinition.new(self)
      internal_mass_def.setSurfaceAreaperSpaceFloorArea(2.0)
      internal_mass_def.setConstruction(construction)
      conditioned_space_names.each do |conditioned_space_name|
        space = self.getSpaceByName(conditioned_space_name)
        if space.is_initialized
          space = space.get
          internal_mass = OpenStudio::Model::InternalMass.new(internal_mass_def)
          internal_mass.setName("#{space.name} Mass")  
          internal_mass.setSpace(space)
        end
      end
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying constructions')
    
    return true

  end  
  
  # Get the list of all conditioned spaces, as defined for each building in the
  # system_to_space_map inside the Prototype.building_name
  # e.g. (Prototype.secondary_school.rb) file.
  #
  # @param (see #add_constructions)
  # @return [Array<String>] returns an array of space names as strings   
  def find_conditioned_space_names(building_type, building_vintage, climate_zone)
    system_to_space_map = define_hvac_system_map(building_type, building_vintage, climate_zone)
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
  def create_thermal_zones(building_type,building_vintage, climate_zone)

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started creating thermal zones')

    # This map define the multipliers for spaces with multipliers not equals to 1
    case building_type
    when 'LargeHotel', 'MidriseApartment'
      space_multiplier_map = self.define_space_multiplier
    else
      space_multiplier_map ={}
    end

    # Create a thermal zone for each space in the self
    self.getSpaces.each do |space|
      zone = OpenStudio::Model::ThermalZone.new(self)
      zone.setName("#{space.name} ZN")
      if space_multiplier_map[space.name.to_s] != nil
        zone.setMultiplier(space_multiplier_map[space.name.to_s])
      end
      space.setThermalZone(zone)
      
      # Skip thermostat for spaces with no space type
      next if space.spaceType.empty?
      
      # Add a thermostat
      space_type_name = space.spaceType.get.name.get
      thermostat_name = space_type_name + ' Thermostat'
      thermostat = self.getThermostatSetpointDualSetpointByName(thermostat_name)
      if thermostat.empty?
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Thermostat #{thermostat_name} not found for space name: #{space.name}")
      else
        zone.setThermostatSetpointDualSetpoint(thermostat.get)
      end
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished creating thermal zones')
    
    return true

  end

  # Adds occupancy sensors to certain space types per
  # the PNNL documentation.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not   
  # @todo genericize and move this method to Standards.Space 
  def add_occupancy_sensors(building_type, building_vintage, climate_zone)
   
    # Only add occupancy sensors for 90.1-2010
    return true unless building_vintage == '90.1-2010'
   
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started Adding Occupancy Sensors')

    space_type_reduction_map = {
      'SecondarySchool' => {'Classroom' => 0.32}
    }
    
    # Loop through all the space types and reduce lighting operation schedule fractions as-specified
    self.getSpaceTypes.each do |space_type|
      # Skip space types with no standards building type
      next if space_type.standardsBuildingType.empty?
      stds_bldg_type = space_type.standardsBuildingType.get
      
      # Skip space types with no standards space type
      next if space_type.standardsSpaceType.empty?
      stds_spc_type = space_type.standardsSpaceType.get
      
      # Skip building types and space types that aren't listed in the hash
      next unless space_type_reduction_map.has_key?(stds_bldg_type)
      next unless space_type_reduction_map[stds_bldg_type].has_key?(stds_spc_type)
      
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

        # Method to multiply the values in a day schedule by a specified value
        def multiply_schedule(day_sch, multiplier)       
          # Record the original times and values
          times = day_sch.times
          values = day_sch.values
          
          # Remove the original times and values
          day_sch.clearValues
          
          # Create new values by using the multiplier on the original values
          new_values = []
          for i in 0..(values.length - 1)
            new_values << values[i] * multiplier
          end
          
          # Add the revised time/value pairs to the schedule
          for i in 0..(new_values.length - 1)
            day_sch.addValue(times[i], new_values[i])
          end
        end #end reduce schedule

        # Reduce default day schedule
        multiply_schedule(new_lights_sch.defaultDaySchedule, red_multiplier)
        
        # Reduce all other rule schedules
        new_lights_sch.scheduleRules.each do |sch_rule|
          multiply_schedule(sch_rule.daySchedule, red_multiplier)
        end
         
      end #end of lights_sch_names.uniq.each do

      # Loop through all lights instances, replacing old lights
      # schedules with the reduced schedules.
      space_type.lights.each do |light|
        # Skip lights that don't have a schedule
        next if light.schedule.empty?
        old_lights_sch_name = light.schedule.get.name.to_s
        if reduced_lights_schs[old_lights_sch_name]
          light.setSchedule(reduced_lights_schs[old_lights_sch_name])
          OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Occupancy sensor reduction added to '#{light.name}'")
        end
      end
    
    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished Adding Occupancy Sensors')
    
    return true
    
  end #add occupancy sensors

  # Adds exterior lights to the building, as specified
  # in OpenStudio_Standards_prototype_inputs
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not   
  # @todo translate w/linear foot of facade, door, parking, etc
  #   into lookup table and implement that way instead of hard-coding as
  #   inputs in the spreadsheet.   
  def add_exterior_lights(building_type, building_vintage, climate_zone, prototype_input)
    # TODO Standards - translate w/linear foot of facade, door, parking, etc
    # into lookup table and implement that way instead of hard-coding as
    # inputs in the spreadsheet.
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started adding exterior lights')

    # Occupancy Sensing Exterior Lights
    # which reduce to 70% power when no one is around.
    unless prototype_input['occ_sensing_exterior_lighting_power'].nil?
      occ_sens_ext_lts_power = prototype_input['occ_sensing_exterior_lighting_power']
      occ_sens_ext_lts_sch_name = prototype_input['occ_sensing_exterior_lighting_schedule']
      occ_sens_ext_lts_name = 'Occ Sensing Exterior Lights'
      occ_sens_ext_lts_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      occ_sens_ext_lts_def.setName("#{occ_sens_ext_lts_name} Def")
      occ_sens_ext_lts_def.setDesignLevel(occ_sens_ext_lts_power)
      occ_sens_ext_lts_sch = self.add_schedule(occ_sens_ext_lts_sch_name)
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
      nondimming_ext_lts_sch = self.add_schedule(nondimming_ext_lts_sch_name)
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
      fuel_ext_sch = self.add_schedule(fuel_ext_sch_name)
      fuel_ext_lts = OpenStudio::Model::ExteriorLights.new(fuel_ext_def, fuel_ext_sch)
      fuel_ext_lts.setName("#{fuel_ext_name}")
      fuel_ext_lts.setControlOption('ScheduleNameOnly')
    end

    unless prototype_input['exterior_fuel_equipment2_power'].nil?
      fuel_ext_power = prototype_input['exterior_fuel_equipment2_power']
      fuel_ext_sch_name = prototype_input['exterior_fuel_equipment2_schedule']
      fuel_ext_name = 'Fuel equipment 2'
      fuel_ext_def = OpenStudio::Model::ExteriorLightsDefinition.new(self)
      fuel_ext_def.setName("#{fuel_ext_name} Def")
      fuel_ext_def.setDesignLevel(fuel_ext_power)
      fuel_ext_sch = self.add_schedule(fuel_ext_sch_name)
      fuel_ext_lts = OpenStudio::Model::ExteriorLights.new(fuel_ext_def, fuel_ext_sch)
      fuel_ext_lts.setName("#{fuel_ext_name}")
      fuel_ext_lts.setControlOption('ScheduleNameOnly')
    end

    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished adding exterior lights')
    
    return true
  end #add exterior lights  
  
  # Changes the infiltration coefficients for the prototype vintages.
  #
  # @param (see #add_constructions)
  # @return [Bool] returns true if successful, false if not   
  # @todo Consistency - make prototype and reference vintages consistent
  # @todo Add 90.1-2013?
  def modify_infiltration_coefficients(building_type, building_vintage, climate_zone)
  
    # modify the infiltration coefficients for 90.1-2004, 90.1-2007, 90.1-2010, 90.1-2013
    return true unless building_vintage == '90.1-2004' or building_vintage == '90.1-2007' or building_vintage == '90.1-2010' or building_vintage == '90.1-2013' 
  
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
    self.getSpaceInfiltrationDesignFlowRates.each do |infiltration|
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
  def modify_surface_convection_algorithm(building_vintage)
  
    inside = self.getInsideSurfaceConvectionAlgorithm
    outside = self.getOutsideSurfaceConvectionAlgorithm
  
    case building_vintage
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      inside.setAlgorithm('TARP')
      outside.setAlgorithm('DOE-2')     
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
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
  def set_sizing_parameters(building_type, building_vintage)
    
    # Default unless otherwise specified
    clg = 1.2
    htg = 1.2
    case building_vintage
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      case building_type
      when 'PrimarySchool', 'SecondarySchool'
        clg = 1.5
        htg = 1.5
      when 'LargeHotel'
        clg = 1.33
        htg = 1.33
      end
    when '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
      case building_type
      when 'Hospital', 'LargeHotel', 'MediumOffice', 'LargeOffice', 'OutPatientHealthCare', 'PrimarySchool'
        clg = 1.0
        htg = 1.0
      end
    end 
  
    sizing_params = self.getSizingParameters
    sizing_params.setHeatingSizingFactor(htg)
    sizing_params.setCoolingSizingFactor(clg) 
  
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.prototype.Model', "Set sizing factors to #{htg} for heating and #{clg} for cooling.")
  
  end
  
  def applyPrototypeHVACAssumptions(building_type, building_vintage, climate_zone)
    
    # Load the helper libraries for getting the autosized
    # values for each type of model object.
    require_relative 'Prototype.FanConstantVolume'
    require_relative 'Prototype.FanVariableVolume'
    require_relative 'Prototype.FanOnOff'
    require_relative 'Prototype.FanZoneExhaust'
    require_relative 'Prototype.HeatExchangerAirToAirSensibleAndLatent'
    require_relative 'Prototype.ControllerWaterCoil'
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying prototype HVAC assumptions.')
    
    ##### Apply equipment efficiencies
    
    # Fans
    self.getFanConstantVolumes.sort.each {|obj| obj.setPrototypeFanPressureRise(building_vintage)}
    self.getFanVariableVolumes.sort.each {|obj| obj.setPrototypeFanPressureRise(building_type, building_vintage, climate_zone)}
    self.getFanOnOffs.sort.each {|obj| obj.setPrototypeFanPressureRise}
    self.getFanZoneExhausts.sort.each {|obj| obj.setPrototypeFanPressureRise}

    ##### Add Economizers
    
    if (building_vintage != 'NECB 2011') then
      # Create an economizer maximum OA fraction of 70%
      # to reflect damper leakage per PNNL        
      econ_max_70_pct_oa_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      econ_max_70_pct_oa_sch.setName("Economizer Max OA Fraction 70 pct")
      econ_max_70_pct_oa_sch.defaultDaySchedule.setName("Economizer Max OA Fraction 70 pct Default")
      econ_max_70_pct_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 0.7)   
    else
      # NECB 2011 prescribes ability to provide 100% OA (5.2.2.7-5.2.2.9)  
      econ_max_100_pct_oa_sch = OpenStudio::Model::ScheduleRuleset.new(self)
      econ_max_100_pct_oa_sch.setName("Economizer Max OA Fraction 100 pct")
      econ_max_100_pct_oa_sch.defaultDaySchedule.setName("Economizer Max OA Fraction 100 pct Default")
      econ_max_100_pct_oa_sch.defaultDaySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 1.0)         
    end  
    
    # Check each airloop
    self.getAirLoopHVACs.each do |air_loop|
      if air_loop.is_economizer_required(self.template, self.climate_zone) == true
        # If an economizer is required, determine the economizer type
        # in the prototype buildings, which depends on climate zone.
        economizer_type = nil
        case building_vintage
        when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
          economizer_type = 'FixedDryBulb'
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
          OpenStudio::logFree(OpenStudio::Error, "openstudio.prototype.Model", "#{air_loop.name} is required to have an economizer, but it has no OA system.")
          next
        end
        oa_control = oa_sys.getControllerOutdoorAir
        oa_control.setEconomizerControlType(economizer_type)
        if (building_vintage != 'NECB 2011') then
          oa_control.setMaximumFractionofOutdoorAirSchedule(econ_max_70_pct_oa_sch)
        else
          #oa_control.setMaximumFractionofOutdoorAirSchedule(econ_max_100_pct_oa_sch)     
        end  
        
       
        
              
      end
    end

    # TODO What is the logic behind hard-sizing
    # hot water coil convergence tolerances?
    self.getControllerWaterCoils.sort.each {|obj| obj.set_convergence_limits}
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying prototype HVAC assumptions.')
    
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
      var_names << ['Water Heater Water Volume Flow Rate','timestep']
      var_names << ['Water Use Equipment Hot Water Volume Flow Rate','timestep']
      var_names << ['Water Use Equipment Cold Water Volume Flow Rate','timestep']
      var_names << ['Water Use Equipment Hot Water Temperature','timestep']
      var_names << ['Water Use Equipment Cold Water Temperature','timestep']
      var_names << ['Water Use Equipment Mains Water Volume','timestep']
      var_names << ['Water Use Equipment Target Water Temperature','timestep']
      var_names << ['Water Use Equipment Mixed Water Temperature','timestep']
      var_names << ['Water Heater Tank Temperature','timestep']
      var_names << ['Water Heater Use Side Mass Flow Rate','timestep']
      var_names << ['Water Heater Heating Rate','timestep']
      var_names << ['Water Heater Water Volume Flow Rate','timestep']
      var_names << ['Water Heater Water Volume','timestep']
    end
  
    var_names.each do |var_name, reporting_frequency|
      outputVariable = OpenStudio::Model::OutputVariable.new(var_name,self)
      outputVariable.setReportingFrequency(reporting_frequency)
    end
  
  
  end

  def run(run_dir = "#{Dir.pwd}/Run")
    
    # If the run directory is not specified
    # run in the current working directory
    
    # Make the directory if it doesn't exist
    if !Dir.exists?(run_dir)
      Dir.mkdir(run_dir)
    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Started simulation in '#{run_dir}'")
    
    # Change the simulation to only run the weather file
    # and not run the sizing day simulations
    sim_control = self.getSimulationControl
    sim_control.setRunSimulationforSizingPeriods(false)
    sim_control.setRunSimulationforWeatherFileRunPeriods(true)
    
    # Save the model to energyplus idf
    idf_name = 'in.idf'
    osm_name = 'in.osm'
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(self)
    idf_path = OpenStudio::Path.new("#{run_dir}/#{idf_name}")
    osm_path = OpenStudio::Path.new("#{run_dir}/#{osm_name}")
    idf.save(idf_path,true)
    self.save(osm_path,true)
    
    # Set up the sizing simulation
    # Find the weather file
    epw_path = nil
    if self.weatherFile.is_initialized
      epw_path = self.weatherFile.get.path
      if epw_path.is_initialized
        if File.exist?(epw_path.get.to_s)
          epw_path = epw_path.get
        else
          # If this is an always-run Measure, need to check a different path
          alt_weath_path = File.expand_path(File.join(File.dirname(__FILE__), "../../../resources"))
          alt_epw_path = File.expand_path(File.join(alt_weath_path, epw_path.get.to_s))
          if File.exist?(alt_epw_path)
            epw_path = OpenStudio::Path.new(alt_epw_path)
          else
            OpenStudio::logFree(OpenStudio::Error, "openstudio.prototype.Model", "Model has been assigned a weather file, but the file is not in the specified location of '#{epw_path.get}'.")
            return false
          end
        end
      else
        OpenStudio::logFree(OpenStudio::Error, "openstudio.prototype.Model", "Model has a weather file assigned, but the weather file path has been deleted.")
        return false
      end
    else
      OpenStudio::logFree(OpenStudio::Error, "openstudio.prototype.Model", "Model has not been assigned a weather file.")
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
      OpenStudio::logFree(OpenStudio::Info, "openstudio.prototype.Model", "Running sizing run with RunManager.")

      # Find EnergyPlus
      ep_dir = OpenStudio.getEnergyPlusDirectory
      ep_path = OpenStudio.getEnergyPlusExecutable
      ep_tool = OpenStudio::Runmanager::ToolInfo.new(ep_path)
      idd_path = OpenStudio::Path.new(ep_dir.to_s + "/Energy+.idd")
      output_path = OpenStudio::Path.new("#{run_dir}/")
      
      # Make a run manager and queue up the sizing run
      run_manager_db_path = OpenStudio::Path.new("#{run_dir}/run.db")
      run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_db_path, true, false, false, false)
      job = OpenStudio::Runmanager::JobFactory::createEnergyPlusJob(ep_tool,
        idd_path,
        idf_path,
        epw_path,
        output_path)
      
      run_manager.enqueue(job, true)

      # Start the sizing run and wait for it to finish.
      while run_manager.workPending
        sleep 1
        OpenStudio::Application::instance.processEvents
      end
        
      sql_path = OpenStudio::Path.new("#{run_dir}/Energyplus/eplusout.sql")
      
      OpenStudio::logFree(OpenStudio::Info, "openstudio.prototype.Model", "Finished sizing run in #{(Time.new - start_time).round}sec.")
      
    else # Use the openstudio-workflow gem
      OpenStudio::logFree(OpenStudio::Info, "openstudio.prototype.Model", "Running sizing run with openstudio-workflow gem.")
      
      # Copy the weather file to this directory
      FileUtils.copy(epw_path.to_s, run_dir)

      # Run the simulation
      sim = OpenStudio::Workflow.run_energyplus('Local', run_dir)
      final_state = sim.run

      if final_state == :finished
        OpenStudio::logFree(OpenStudio::Info, "openstudio.prototype.Model", "Finished sizing run in #{(Time.new - start_time).round}sec.")
      end
    
      sql_path = OpenStudio::Path.new("#{run_dir}/run/eplusout.sql")
    
    end
    
    # Load the sql file created by the sizing run
    sql_path = OpenStudio::Path.new("#{run_dir}/Energyplus/eplusout.sql")
    if OpenStudio::exists(sql_path)
      sql = OpenStudio::SqlFile.new(sql_path)
      # Check to make sure the sql file is readable,
      # which won't be true if EnergyPlus crashed during simulation.
      if !sql.connectionOpen
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed.  Look at the eplusout.err file in #{File.dirname(sql_path.to_s)} to see the cause.")
        return false
      end
      # Attach the sql file from the run to the sizing model
      self.setSqlFile(sql)
    else 
      OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Results for the sizing run couldn't be found here: #{sql_path}.")
      return false
    end

    # Check that the run finished without severe errors
    error_query = "SELECT ErrorMessage 
        FROM Errors 
        WHERE ErrorType='1'"

    errs = self.sqlFile.get.execAndReturnVectorOfString(error_query)
    if errs.is_initialized
      errs = errs.get
      if errs.size > 0
        errs = errs.get
        OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "The run failed with the following severe errors: #{errs.join('\n')}.")
        return false
      end
    end
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Finished simulation in '#{run_dir}'")
    
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
    vars << ['Zone Thermostat Air Temperature', 'detailed']
    vars << ['Zone Thermostat Heating Setpoint Temperature', 'detailed']
    vars << ['Zone Thermostat Cooling Setpoint Temperature', 'detailed']
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
  
    vars << ['Air System Outdoor Air Economizer Status','timestep']
    vars << ['Air System Outdoor Air Heat Recovery Bypass Status','timestep']
    vars << ['Air System Outdoor Air High Humidity Control Status','timestep']
    vars << ['Air System Outdoor Air Flow Fraction','timestep']
    vars << ['Air System Outdoor Air Minimum Flow Fraction','timestep']
    vars << ['Air System Outdoor Air Mass Flow Rate','timestep']
    vars << ['Air System Mixed Air Mass Flow Rate','timestep']
  
    vars << ['Heating Coil Gas Rate','timestep']
    vars << ['Boiler Part Load Ratio','timestep']
    vars << ['Boiler Gas Rate','timestep']
    vars << ['Fan Electric Power','timestep']
    
    vars.each do |var, freq|  
      outputVariable = OpenStudio::Model::OutputVariable.new(var, self)
      outputVariable.setReportingFrequency(freq)
    end
    
  end  

end

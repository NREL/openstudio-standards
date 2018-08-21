class NECB2011
  # Reduces the WWR to the values specified by the NECB
  # NECB 3.2.1.4
  def apply_standard_window_to_wall_ratio(model)
    # Loop through all spaces in the model, and
    # per the PNNL PRM Reference Manual, find the areas
    # of each space conditioning category (res, nonres, semi-heated)
    # separately.  Include space multipliers.
    nr_wall_m2 = 0.001 # Avoids divide by zero errors later
    nr_wind_m2 = 0
    res_wall_m2 = 0.001
    res_wind_m2 = 0
    sh_wall_m2 = 0.001
    sh_wind_m2 = 0
    total_wall_m2 = 0.001
    total_subsurface_m2 = 0.0
    # Store the space conditioning category for later use
    space_cats = {}
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      wall_area_m2 = 0
      wind_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType.casecmp('wall').zero?
        # This wall's gross area (including window area)
        wall_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          wind_area_m2 += ss.netArea * space.multiplier
        end
      end

      # Determine the space category
      # zTODO This should really use the heating/cooling loads
      # from the proposed building.  However, in an attempt
      # to avoid another sizing run just for this purpose,
      # conditioned status is based on heating/cooling
      # setpoints.  If heated-only, will be assumed Semiheated.
      # The full-bore method is on the next line in case needed.
      # cat = thermal_zone_conditioning_category(space, template, climate_zone)
      cooled = space_cooled?(space)
      heated = space_heated?(space)
      cat = 'Unconditioned'
      # Unconditioned
      if !heated && !cooled
        cat = 'Unconditioned'
        # Heated-Only
      elsif heated && !cooled
        cat = 'Semiheated'
        # Heated and Cooled
      else
        res = thermal_zone_residential?(space.thermalZone.get)
        cat = if res
                'ResConditioned'
              else
                'NonResConditioned'
              end
      end
      space_cats[space] = cat
      # NECB2011 keep track of totals for NECB regardless of conditioned or not.
      total_wall_m2 += wall_area_m2
      total_subsurface_m2 += wind_area_m2 # this contains doors as well.

      # Add to the correct category
      case cat
        when 'Unconditioned'
          next # Skip unconditioned spaces
        when 'NonResConditioned'
          nr_wall_m2 += wall_area_m2
          nr_wind_m2 += wind_area_m2
        when 'ResConditioned'
          res_wall_m2 += wall_area_m2
          res_wind_m2 += wind_area_m2
        when 'Semiheated'
          sh_wall_m2 += wall_area_m2
          sh_wind_m2 += wind_area_m2
      end
    end

    # Calculate the WWR of each category
    wwr_nr = ((nr_wind_m2 / nr_wall_m2) * 100.0).round(1)
    wwr_res = ((res_wind_m2 / res_wall_m2) * 100).round(1)
    wwr_sh = ((sh_wind_m2 / sh_wall_m2) * 100).round(1)
    fdwr = ((total_subsurface_m2 / total_wall_m2) * 100).round(1) # used by NECB2011

    # Convert to IP and report
    nr_wind_ft2 = OpenStudio.convert(nr_wind_m2, 'm^2', 'ft^2').get
    nr_wall_ft2 = OpenStudio.convert(nr_wall_m2, 'm^2', 'ft^2').get

    res_wind_ft2 = OpenStudio.convert(res_wind_m2, 'm^2', 'ft^2').get
    res_wall_ft2 = OpenStudio.convert(res_wall_m2, 'm^2', 'ft^2').get

    sh_wind_ft2 = OpenStudio.convert(sh_wind_m2, 'm^2', 'ft^2').get
    sh_wall_ft2 = OpenStudio.convert(sh_wall_m2, 'm^2', 'ft^2').get

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR NonRes = #{wwr_nr.round}%; window = #{nr_wind_ft2.round} ft2, wall = #{nr_wall_ft2.round} ft2.")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR Res = #{wwr_res.round}%; window = #{res_wind_ft2.round} ft2, wall = #{res_wall_ft2.round} ft2.")
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "WWR Semiheated = #{wwr_sh.round}%; window = #{sh_wind_ft2.round} ft2, wall = #{sh_wall_ft2.round} ft2.")

    # WWR limit
    wwr_lim = 40.0

    # Check against WWR limit
    red_nr = wwr_nr > wwr_lim
    red_res = wwr_res > wwr_lim
    red_sh = wwr_sh > wwr_lim

    # NECB FDWR limit
    hdd = self.get_necb_hdd18(model)
    fdwr_lim = (max_fwdr(hdd) * 100.0).round(1)
    # puts "Current FDWR is #{fdwr}, must be less than #{fdwr_lim}."
    # puts "Current subsurf area is #{total_subsurface_m2} and gross surface area is #{total_wall_m2}"
    # Stop here unless windows / doors need reducing
    return true unless fdwr > fdwr_lim
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Reducing the size of all windows (by raising sill height) to reduce window area down to the limit of #{wwr_lim.round}%.")
    # Determine the factors by which to reduce the window / door area
    mult = fdwr_lim / fdwr
    # Reduce the window area if any of the categories necessary
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'Wall'
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          # Reduce the size of the window
          red = 1.0 - mult
          sub_surface_reduce_area_by_percent_by_raising_sill(ss, red)
        end
      end
    end
    return true
  end

  # Reduces the SRR to the values specified by the PRM. SRR reduction
  # will be done by shrinking vertices toward the centroid.
  #
  def apply_standard_skylight_to_roof_ratio(model)
    # Loop through all spaces in the model, and
    # per the PNNL PRM Reference Manual, find the areas
    # of each space conditioning category (res, nonres, semi-heated)
    # separately.  Include space multipliers.
    nr_wall_m2 = 0.001 # Avoids divide by zero errors later
    nr_sky_m2 = 0
    res_wall_m2 = 0.001
    res_sky_m2 = 0
    sh_wall_m2 = 0.001
    sh_sky_m2 = 0
    total_roof_m2 = 0.001
    total_subsurface_m2 = 0
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      wall_area_m2 = 0
      sky_area_m2 = 0
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'
        # This wall's gross area (including skylight area)
        wall_area_m2 += surface.grossArea * space.multiplier
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          sky_area_m2 += ss.netArea * space.multiplier
        end
      end

      # Determine the space category
      cat = 'NonRes'
      if space_residential?(space)
        cat = 'Res'
      end
      # if space.is_semiheated
      # cat = 'Semiheated'
      # end

      # Add to the correct category
      case cat
        when 'NonRes'
          nr_wall_m2 += wall_area_m2
          nr_sky_m2 += sky_area_m2
        when 'Res'
          res_wall_m2 += wall_area_m2
          res_sky_m2 += sky_area_m2
        when 'Semiheated'
          sh_wall_m2 += wall_area_m2
          sh_sky_m2 += sky_area_m2
      end
      total_roof_m2 += wall_area_m2
      total_subsurface_m2 += sky_area_m2
    end

    # Calculate the SRR of each category
    srr_nr = ((nr_sky_m2 / nr_wall_m2) * 100).round(1)
    srr_res = ((res_sky_m2 / res_wall_m2) * 100).round(1)
    srr_sh = ((sh_sky_m2 / sh_wall_m2) * 100).round(1)
    srr = ((total_subsurface_m2 / total_roof_m2) * 100.0).round(1)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "The skylight to roof ratios (SRRs) are: NonRes: #{srr_nr.round}%, Res: #{srr_res.round}%.")

    # SRR limit
    srr_lim = self.get_standards_constant('skylight_to_roof_ratio_max_value') * 100.0
    # Check against SRR limit
    red_nr = srr_nr > srr_lim
    red_res = srr_res > srr_lim
    red_sh = srr_sh > srr_lim

    # Stop here unless windows need reducing
    return true unless srr > srr_lim
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Model', "Reducing the size of all windows (by raising sill height) to reduce window area down to the limit of #{srr_lim.round}%.")
    # Determine the factors by which to reduce the window / door area
    mult = srr_lim / srr

    # Reduce the subsurface areas
    model.getSpaces.sort.each do |space|
      # Loop through all surfaces in this space
      space.surfaces.sort.each do |surface|
        # Skip non-outdoor surfaces
        next unless surface.outsideBoundaryCondition == 'Outdoors'
        # Skip non-walls
        next unless surface.surfaceType == 'RoofCeiling'
        # Subsurfaces in this surface
        surface.subSurfaces.sort.each do |ss|
          # Reduce the size of the subsurface
          red = 1.0 - mult
          sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, red)
        end
      end
    end

    return true
  end

  # @author phylroy.lopez@nrcan.gc.ca
  # @param hdd [Float]
  # @return [Double] a constant float
  def max_fwdr(hdd)
    #get formula from json database.
    return eval(self.get_standards_formula('fdwr_formula'))
  end

  # Go through the default construction sets and hard-assigned
  # constructions. Clone the existing constructions and set their
  # intended surface type and standards construction type per
  # the PRM.  For some standards, this will involve making
  # modifications.  For others, it will not.
  #
  # 90.1-2007, 90.1-2010, 90.1-2013
  # @return [Bool] returns true if successful, false if not

  def apply_standard_construction_properties(model,
                                             runner = nil,
                                             scale_wall = 1.0,
                                             scale_floor = 1.0,
                                             scale_roof = 1.0,
                                             scale_ground_wall = 1.0,
                                             scale_ground_floor = 1.0,
                                             scale_ground_roof = 1.0,
                                             scale_door = 1.0,
                                             scale_window = 1.0)

    model.getDefaultConstructionSets.sort.each do |set|
      set_construction_set_to_necb!(model,
                                    set,
                                    runner,
                                    scale_wall,
                                    scale_floor,
                                    scale_roof,
                                    scale_ground_wall,
                                    scale_ground_floor,
                                    scale_ground_roof,
                                    scale_door,
                                    scale_window)
    end
    # sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    model.getPlanarSurfaces.sort.each(&:resetConstruction)
    # if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope.assign_interior_surface_construction_to_adiabatic_surfaces(model, nil)
  end

  # this will create a copy and convert all construction sets to NECB reference conductances.
  # @author phylroy.lopez@nrcan.gc.ca
  # @param model [OpenStudio::model::Model] A model object
  # @param default_surface_construction_set [String]
  # @return [Boolean] returns true if sucessful, false if not
  def set_construction_set_to_necb!(model, default_surface_construction_set,
                                    runner = nil,
                                    scale_wall = 1.0,
                                    scale_floor = 1.0,
                                    scale_roof = 1.0,
                                    scale_ground_wall = 1.0,
                                    scale_ground_floor = 1.0,
                                    scale_ground_roof = 1.0,
                                    scale_door = 1.0,
                                    scale_window = 1.0)
    BTAP.runner_register('Info', 'set_construction_set_to_necb!', runner)
    if model.weatherFile.empty? || model.weatherFile.get.path.empty? || !File.exist?(model.weatherFile.get.path.get.to_s)

      BTAP.runner_register('Error', 'Weather file is not defined. Please ensure the weather file is defined and exists.', runner)
      return false
    end

    #Note:hdd needs to be defined for eval to work on table eval below.
    hdd = self.get_necb_hdd18(model)

    old_name = default_surface_construction_set.name.get.to_s
    new_name = "#{old_name} at hdd = #{hdd}"

    # convert conductance values to rsi values. (Note: we should really be only using conductances in)
    wall_rsi = 1.0 / (scale_wall * eval(self.get_standards_table('surface_thermal_transmittance', {'boundary_condition' => 'Outdoors', 'surface' => 'Wall'})[0]['formula']))
    floor_rsi = 1.0 / (scale_floor * eval(self.get_standards_table('surface_thermal_transmittance', {'boundary_condition' => 'Outdoors', 'surface' => 'Floor'})[0]['formula']))
    roof_rsi = 1.0 / (scale_roof * eval(self.get_standards_table('surface_thermal_transmittance', {'boundary_condition' => 'Outdoors', 'surface' => 'RoofCeiling'})[0]['formula']))
    ground_wall_rsi = 1.0 / (scale_ground_wall * eval(self.get_standards_table('surface_thermal_transmittance', {'boundary_condition' => 'Ground', 'surface' => 'Wall'})[0]['formula']))
    ground_floor_rsi = 1.0 / (scale_ground_floor * eval(self.get_standards_table('surface_thermal_transmittance', {'boundary_condition' => 'Ground', 'surface' => 'Floor'})[0]['formula']))
    ground_roof_rsi = 1.0 / (scale_ground_roof * eval(self.get_standards_table('surface_thermal_transmittance', {'boundary_condition' => 'Ground', 'surface' => 'RoofCeiling'})[0]['formula']))
    door_rsi = 1.0 / (scale_door * eval(self.get_standards_table('surface_thermal_transmittance', {'boundary_condition' => 'Outdoors', 'surface' => 'Door'})[0]['formula']))
    window_rsi = 1.0 / (scale_window * eval(self.get_standards_table('surface_thermal_transmittance', {'boundary_condition' => 'Outdoors', 'surface' => 'Window'})[0]['formula']))
    BTAP::Resources::Envelope::ConstructionSets.customize_default_surface_construction_set_rsi!(model, new_name, default_surface_construction_set,
                                                                                                wall_rsi, floor_rsi, roof_rsi,
                                                                                                ground_wall_rsi, ground_floor_rsi, ground_roof_rsi,
                                                                                                window_rsi, nil, nil,
                                                                                                window_rsi, nil, nil,
                                                                                                door_rsi,
                                                                                                door_rsi, nil, nil,
                                                                                                door_rsi,
                                                                                                window_rsi, nil, nil,
                                                                                                window_rsi, nil, nil,
                                                                                                window_rsi, nil, nil)
    BTAP.runner_register('Info', 'set_construction_set_to_necb! was sucessful.', runner)
    return true
  end

  # Set all external surface conductances to NECB values.
  # @author phylroy.lopez@nrcan.gc.ca
  # @param surface [String]
  # @param hdd [Float]
  # @param is_radiant [Boolian]
  # @param scaling_factor [Float]
  # @return [String] surface as RSI
  def set_necb_external_surface_conductance(surface, hdd, is_radiant = false, scaling_factor = 1.0)
    conductance_value = 0

    if surface.outsideBoundaryCondition.casecmp('outdoors').zero?

      case surface.surfaceType.downcase
        when 'wall'
          conductance_value = @standards_data['conductances']['Wall'].find {|i| i['hdd'] > hdd}['thermal_transmittance'] * scaling_factor
        when 'floor'
          conductance_value = @standards_data['conductances']['Floor'].find {|i| i['hdd'] > hdd}['thermal_transmittance'] * scaling_factor
        when 'roofceiling'
          conductance_value = @standards_data['conductances']['Roof'].find {|i| i['hdd'] > hdd}['thermal_transmittance'] * scaling_factor
      end
      if is_radiant
        conductance_value *= 0.80
      end
      return BTAP::Geometry::Surfaces.set_surfaces_construction_conductance([surface], conductance_value)
    end

    if surface.outsideBoundaryCondition.downcase =~ /ground/
      case surface.surfaceType.downcase
        when 'wall'
          conductance_value = @standards_data['conductances']['GroundWall'].find {|i| i['hdd'] > hdd}['thermal_transmittance'] * scaling_factor
        when 'floor'
          conductance_value = @standards_data['conductances']['GroundFloor'].find {|i| i['hdd'] > hdd}['thermal_transmittance'] * scaling_factor
        when 'roofceiling'
          conductance_value = @standards_data['conductances']['GroundRoof'].find {|i| i['hdd'] > hdd}['thermal_transmittance'] * scaling_factor
      end
      if is_radiant
        conductance_value *= 0.80
      end
      return BTAP::Geometry::Surfaces.set_surfaces_construction_conductance([surface], conductance_value)
    end
  end

  # Set all external subsurfaces (doors, windows, skylights) to NECB values.
  # @author phylroy.lopez@nrcan.gc.ca
  # @param subsurface [String]
  # @param hdd [Float]
  def set_necb_external_subsurface_conductance(subsurface, hdd)
    conductance_value = 0

    if subsurface.outsideBoundaryCondition.downcase.match('outdoors')
      case subsurface.subSurfaceType.downcase
        when /window/
          conductance_value = @standards_data['conductances']['Window'].find {|i| i['hdd'] > hdd}['thermal_transmittance'] * scaling_factor
        when /door/
          conductance_value = @standards_data['conductances']['Door'].find {|i| i['hdd'] > hdd}['thermal_transmittance'] * scaling_factor
      end
      subsurface.setRSI(1 / conductance_value)
    end
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
  def model_add_constructions(model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Started applying constructions')

    # Assign construction to adiabatic construction
    # Assign a material to all internal mass objects
    assign_contruction_to_adiabatic_surfaces(model)
    # The constructions lookup table uses a slightly different list of
    # building types.
    apply_building_default_constructionset(model)
    # Make a construction set for each space type, if one is specified
    #apply_default_constructionsets_to_spacetypes(climate_zone, model)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Model', 'Finished applying constructions')
    return true
  end

  def apply_building_default_constructionset(model)

    bldg_def_const_set = model_add_construction_set_from_osm(model: model)
    model.getBuilding.setDefaultConstructionSet(bldg_def_const_set)

  end

  def apply_default_constructionsets_to_spacetypes(climate_zone, model)
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
      spc_type_const_set = model_add_construction_set_from_osm(model: model)
      if spc_type_const_set.is_initialized
        space_type.setDefaultConstructionSet(spc_type_const_set.get)
      end
    end
  end


  def model_add_construction_set_from_osm(model: ,
                                          construction_set_name:'BTAP-Mass',
                                          osm_path: File.absolute_path(File.join(__FILE__, '..', '..','common/construction_defaults.osm')))
    # load resources model
    construction_library = BTAP::FileIO::load_osm(osm_path)

    if not construction_library.getDefaultConstructionSetByName(construction_set_name.to_s).is_initialized
      runner.registerError('Did not find the expected construction in library.')
      return false
    end
    selected_construction_set = construction_library.getDefaultConstructionSetByName(construction_set_name.to_s).get
    new_construction_set = selected_construction_set.clone(model).to_DefaultConstructionSet.get
    return new_construction_set
  end



  def assign_contruction_to_adiabatic_surfaces(model)
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
  end

  def scale_model_geometry(model, x_scale, y_scale, z_scale)
    # Identity matrix for setting space origins
    m = OpenStudio::Matrix.new(4, 4, 0)

    m[0, 0] = 1.0/x_scale
    m[1, 1] = 1.0/y_scale
    m[2, 2] = 1.0/z_scale
    m[3, 3] = 1.0
    t = OpenStudio::Transformation.new(m)
    model.getPlanarSurfaceGroups().each do |planar_surface|
      planar_surface.changeTransformation(t)
    end
    return model
  end

end

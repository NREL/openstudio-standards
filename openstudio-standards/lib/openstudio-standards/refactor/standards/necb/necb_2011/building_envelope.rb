class NECB_2011_Model

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
      # TODO This should really use the heating/cooling loads
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
        res = thermal_zone_residential?(space.thermalZone.get())
        cat = if res
                'ResConditioned'
              else
                'NonResConditioned'
              end
      end
      space_cats[space] = cat
      # NECB 2011 keep track of totals for NECB regardless of conditioned or not.
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
    fdwr = ((total_subsurface_m2 / total_wall_m2) * 100).round(1) # used by NECB 2011

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
    red_nr = wwr_nr > wwr_lim ? true : false
    red_res = wwr_res > wwr_lim ? true : false
    red_sh = wwr_sh > wwr_lim ? true : false

    # NECB FDWR limit
    hdd = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get).hdd18
    fdwr_lim = (max_fwdr(hdd) * 100.0).round(1)
    #puts "Current FDWR is #{fdwr}, must be less than #{fdwr_lim}."
    #puts "Current subsurf area is #{total_subsurface_m2} and gross surface area is #{total_wall_m2}"
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
    srr_lim = @standards_data["skylight_to_roof_ratio"] * 100.0

    # Check against SRR limit
    red_nr = srr_nr > srr_lim ? true : false
    red_res = srr_res > srr_lim ? true : false
    red_sh = srr_sh > srr_lim ? true : false

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

  #@author phylroy.lopez@nrcan.gc.ca
  #@param hdd [Float]
  #@return [Double] a constant float
  def max_fwdr(hdd)
    #NECB 3.2.1.4
    if hdd < 4000
      return 0.40
    elsif hdd >= 4000 and hdd <=7000
      return (2000-0.2 * hdd)/3000
    elsif hdd >7000
      return 0.20
    end
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
      self.set_construction_set_to_necb!(model,
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
    #sets all surfaces to use default constructions sets except adiabatic, where it does a hard assignment of the interior wall construction type.
    model.getPlanarSurfaces.sort.each {|item| item.resetConstruction}
    #if the default construction set is defined..try to assign the interior wall to the adiabatic surfaces
    BTAP::Resources::Envelope::assign_interior_surface_construction_to_adiabatic_surfaces(model, nil)
  end



  # this will create a copy and convert all construction sets to NECB reference conductances.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param model [OpenStudio::model::Model] A model object
  #@param default_surface_construction_set [String]
  #@return [Boolean] returns true if sucessful, false if not
  def set_construction_set_to_necb!(model, default_surface_construction_set,
                                    runner = nil,
                                    scale_wall = 1.0,
                                    scale_floor = 1.0,
                                    scale_roof = 1.0,
                                    scale_ground_wall = 1.0,
                                    scale_ground_floor = 1.0,
                                    scale_ground_roof = 1.0,
                                    scale_door = 1.0,
                                    scale_window = 1.0
  )
    BTAP::runner_register("Info", "set_construction_set_to_necb!", runner)
    if model.weatherFile.empty? or model.weatherFile.get.path.empty? or not File.exists?(model.weatherFile.get.path.get.to_s)

      BTAP::runner_register("Error", "Weather file is not defined. Please ensure the weather file is defined and exists.", runner)
      return false
    end
    hdd = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get).hdd18

    old_name = default_surface_construction_set.name.get.to_s



    new_name = "#{old_name} at hdd = #{hdd}"
    @standards_data["conductances"]
    #convert conductance values to rsi values. (Note: we should really be only using conductances in)
    wall_rsi = 1.0 / (scale_wall * @standards_data["conductances"].find {|i| i["surface"] == 'wall' and i["hdd"] > hdd}["thermal_transmittance"])
    floor_rsi = 1.0 / (scale_floor * @standards_data["conductances"].find {|i| i["surface"] == 'floor' and i["hdd"] > hdd}["thermal_transmittance"])
    roof_rsi = 1.0 / (scale_roof * @standards_data["conductances"].find {|i| i["surface"] == 'roof' and i["hdd"] > hdd}["thermal_transmittance"])
    ground_wall_rsi = 1.0 / (scale_ground_wall * @standards_data["conductances"].find {|i| i["surface"] == 'ground_wall' and i["hdd"] > hdd}["thermal_transmittance"])
    ground_floor_rsi = 1.0 / (scale_ground_floor * @standards_data["conductances"].find {|i| i["surface"] == 'ground_floor' and i["hdd"] > hdd}["thermal_transmittance"])
    ground_roof_rsi = 1.0 / (scale_ground_roof * @standards_data["conductances"].find {|i| i["surface"] == 'ground_roof' and i["hdd"] > hdd}["thermal_transmittance"])
    door_rsi = 1.0 / (scale_door * @standards_data["conductances"].find {|i| i["surface"] == 'door' and i["hdd"] > hdd}["thermal_transmittance"])
    window_rsi = 1.0 / (scale_window * @standards_data["conductances"].find {|i| i["surface"] == 'window' and i["hdd"] > hdd}["thermal_transmittance"])
    BTAP::Resources::Envelope::ConstructionSets::customize_default_surface_construction_set_rsi!(model, new_name, default_surface_construction_set,
                                                                                                 wall_rsi, floor_rsi, roof_rsi,
                                                                                                  ground_wall_rsi, ground_floor_rsi, ground_roof_rsi,
                                                                                                 window_rsi, nil, nil,
                                                                                                 window_rsi, nil, nil,
                                                                                                 door_rsi,
                                                                                                 door_rsi, nil, nil,
                                                                                                 door_rsi,
                                                                                                 window_rsi, nil, nil,
                                                                                                 window_rsi, nil, nil,
                                                                                                 window_rsi, nil, nil
    )
    BTAP::runner_register("Info", "set_construction_set_to_necb! was sucessful.", runner)
    return true
  end

  #Set all external surface conductances to NECB values.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param surface [String]
  #@param hdd [Float]
  #@param is_radiant [Boolian]
  #@param scaling_factor [Float]
  #@return [String] surface as RSI
  def set_necb_external_surface_conductance(surface, hdd, is_radiant = false, scaling_factor = 1.0)
    conductance_value = 0


    if surface.outsideBoundaryCondition.downcase == "outdoors"

      case surface.surfaceType.downcase
        when "wall"
          conductance_value = @standards_data["conductances"]["Wall"].find {|i| i["hdd"] > hdd}["thermal_transmittance"] * scaling_factor
        when "floor"
          conductance_value = @standards_data["conductances"]["Floor"].find {|i| i["hdd"] > hdd}["thermal_transmittance"] * scaling_factor
        when "roofceiling"
          conductance_value = @standards_data["conductances"]["Roof"].find {|i| i["hdd"] > hdd}["thermal_transmittance"] * scaling_factor
      end
      if (is_radiant)
        conductance_value = conductance_value * 0.80
      end
      return BTAP::Geometry::Surfaces::set_surfaces_construction_conductance([surface], conductance_value)
    end


    if surface.outsideBoundaryCondition.downcase.match(/ground/)
      case surface.surfaceType.downcase
        when "wall"
          conductance_value = @standards_data["conductances"]["GroundWall"].find {|i| i["hdd"] > hdd}["thermal_transmittance"] * scaling_factor
        when "floor"
          conductance_value = @standards_data["conductances"]["GroundFloor"].find {|i| i["hdd"] > hdd}["thermal_transmittance"] * scaling_factor
        when "roofceiling"
          conductance_value = @standards_data["conductances"]["GroundRoof"].find {|i| i["hdd"] > hdd}["thermal_transmittance"] * scaling_factor
      end
      if (is_radiant)
        conductance_value = conductance_value * 0.80
      end
      return BTAP::Geometry::Surfaces::set_surfaces_construction_conductance([surface], conductance_value)

    end
  end

  #Set all external subsurfaces (doors, windows, skylights) to NECB values.
  #@author phylroy.lopez@nrcan.gc.ca
  #@param subsurface [String]
  #@param hdd [Float]
  def set_necb_external_subsurface_conductance(subsurface, hdd)
    conductance_value = 0

    if subsurface.outsideBoundaryCondition.downcase.match("outdoors")
      case subsurface.subSurfaceType.downcase
        when /window/
          conductance_value = @standards_data["conductances"]["Window"].find {|i| i["hdd"] > hdd}["thermal_transmittance"] * scaling_factor
        when /door/
          conductance_value = @standards_data["conductances"]["Door"].find {|i| i["hdd"] > hdd}["thermal_transmittance"] * scaling_factor
      end
      subsurface.setRSI(1/conductance_value)
    end
  end
end
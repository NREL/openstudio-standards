class Standard
  # @!group Surface

  # Determine the component infiltration rate for this surface
  #
  # @param surface [OpenStudio::Model::Surface] surface object
  # @param type [String] choices are 'baseline' and 'advanced'
  # @return [Double] infiltration rate in cubic meters per second, m^3/s
  # @todo handle floors over unconditioned spaces
  def surface_component_infiltration_rate(surface, type)
    comp_infil_rate_m3_per_s = 0.0

    # Define the envelope component infiltration rates
    component_infil_rates_cfm_per_ft2 = {
      'baseline' => {
        'roof' => 0.12,
        'exterior_wall' => 0.12,
        'below_grade_wall' => 0.12,
        'floor_over_unconditioned' => 0.12,
        'slab_on_grade' => 0.12
      },
      'advanced' => {
        'roof' => 0.04,
        'exterior_wall' => 0.04,
        'below_grade_wall' => 0.04,
        'floor_over_unconditioned' => 0.04,
        'slab_on_grade' => 0.04
      }
    }

    boundary_condition = surface.outsideBoundaryCondition
    # Skip non-outdoor surfaces
    return comp_infil_rate_m3_per_s unless outsideBoundaryCondition == 'Outdoors' || surface.outsideBoundaryCondition == 'Ground'

    # Per area infiltration rate for this surface
    surface_type = surface.surfaceType
    infil_rate_cfm_per_ft2 = nil
    case boundary_condition
    when 'Outdoors'
      case surface_type
      when 'RoofCeiling'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['roof']
      when 'Wall'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['exterior_wall']
      end
    when 'Ground'
      case surface_type
      when 'Wall'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['below_grade_wall']
      when 'Floor'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['slab_on_grade']
      end
    when 'TODO Surface'
      case surface_type
      when 'Floor'
        infil_rate_cfm_per_ft2 = component_infil_rates_cfm_per_ft2[type]['floor_over_unconditioned']
      end
    end
    if infil_rate_cfm_per_ft2.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Surface', "For #{surface.name}, could not determine surface type for infiltration, will not be included in calculation.")
      return comp_infil_rate_m3_per_s
    end

    # Area of the surface
    area_m2 = surface.netArea
    area_ft2 = OpenStudio.convert(area_m2, 'm^2', 'ft^2').get

    # Rate for this surface
    comp_infil_rate_cfm = area_ft2 * infil_rate_cfm_per_ft2

    comp_infil_rate_m3_per_s = OpenStudio.convert(comp_infil_rate_cfm, 'cfm', 'm^3/s').get

    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.Standards.Model", "...#{self.name}, infil = #{comp_infil_rate_cfm.round(2)} cfm @ rate = #{infil_rate_cfm_per_ft2} cfm/ft2, area = #{area_ft2.round} ft2.")

    return comp_infil_rate_m3_per_s
  end

  # Start of method meant to help implement NECB2015 8.4.4.5.(5).
  # The method starts by finding exterior surfaces which help enclose conditioned spaces.
  # It then removes the subsurfaces.
  # Though not implemented yet it was supposed to then put a window centered in the surface with a sill
  # height and window height defined passed via sill_heght_m and window_height_m
  # (0.9 m, and 1.8 m respectively for NECB2015).
  # The width of the window was to be set so that the fdwr matched whatever code said (passed by fdwr).
  # @author Chris Kirney
  # @note 2018-05-17 not complete-do not call.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param sill_height_m [Double] sill height in meters
  # @param window_height_m [Double] window height in meters
  # @param fdwr [Double] fdwr
  # @return [Bool] returns true if successful, false if not
  def surface_replace_existing_subsurfaces_with_centered_subsurface(model, sill_height_m, window_height_m, fdwr)
    vertical_surfaces = find_exposed_conditioned_vertical_surfaces(model)
    vertical_surfaces.each do |vertical_surface|
      vertical_surface.subSurfaces.sort.each do |vertical_subsurface|
        # Need to fix this so that error show up in right place
        if vertical_subsurface.nil?
          puts 'Surface does not exist'
        else
          vertical_subsurface.remove
        end
      end
      # corner_coords = vertical_surface.vertices
      code_window_area = fdwr * vertical_surface.grossArea
      code_window_width = code_window_area / window_height_m
      min_z = 0
      vertical_surface.vertices.each_with_index do |vertex, index|
        if index == 0
          min_z = vertex.z
        elsif vertex.z < min_z
          min_z = vertex.z
        end
      end
      surface_centroid = vertical_surface.centroid
      surface_normal = vertical_surface.outwardNormal
    end
    return true
  end

  # This method searches through a model a returns vertical exterior surfaces which help
  # enclose a conditioned space.  It distinguishes between walls adjacent to plenums and wall adjacent to other
  # conditioned spaces (as attics in OpenStudio are considered plenums and conditioned spaces though many would
  # not agree).  It returns a hash of the total exposed wall area adjacent to conditioned spaces (including plenums), the
  # total exposed plenum wall area, the total exposed non-plenum area (adjacent to conditioned spaces), the exposed
  # plenum walls and the exposed non-plenum walls (adjacent to conditioned spaces).
  # @author Chris Kirney
  # @note 2018-09-12
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @param max_angle [Double] maximum angle to consider surface
  # @param min_angle [Double] minimum angle to consider surface
  # @return [Hash] hash of exposed surface information
  def find_exposed_conditioned_vertical_surfaces(model, max_angle: 91, min_angle: 89)
    exposed_surfaces = []
    plenum_surfaces = []
    exp_plenum_area = 0
    total_exp_area = 0
    exp_nonplenum_area = 0
    sub_surfaces_info = []
    sub_surface_area = 0
    # Sort through each space
    model.getSpaces.sort.each do |space|
      # Is the space heated or cooled?
      cooled = space_cooled?(space)
      heated = space_heated?(space)
      # Assume conditioned means the space is heated, cooled, or both.
      if heated || cooled
        # If the space is conditioned then go through each surface and determine if it a vertial exterior wall.
        space.surfaces.sort.each do |surface|
          # I define an exterior wall as one that is called a wall and that has a boundary contion of Outdoors.
          # Note that this will not include foundation walls.
          next unless surface.surfaceType == 'Wall'
          next unless surface.outsideBoundaryCondition == 'Outdoors'

          # Determine if the wall is vertical which I define as being between 89 and 91 degrees from horizontal.
          tilt_radian = surface.tilt
          tilt_degrees = OpenStudio.convert(tilt_radian, 'rad', 'deg').get
          sub_surface_info = []
          if tilt_degrees <= max_angle && tilt_degrees >= min_angle
            # If the wall is vertical determine if it is adjacent to a plenum.  If yes include it in the array of
            # plenum walls and add it to the plenum wall area counter (accounting for space multipliers).
            if space_plenum?(space)
              plenum_surfaces << surface
              exp_plenum_area += surface.grossArea * space.multiplier
            else
              # If not a plenum then include it in the array of non-plenum walls and add it to the non-plenum area
              # counter (accounting for space multipliers).
              exposed_surfaces << surface
              exp_nonplenum_area += surface.grossArea * space.multiplier
              surface.subSurfaces.sort.each do |sub_surface|
                sub_surface_area += sub_surface.grossArea.to_f * space.multiplier
                sub_surface_info << {
                  'subsurface_name' => sub_surface.nameString,
                  'subsurface_type' => sub_surface.subSurfaceType,
                  'gross_area_m2' => sub_surface.grossArea.to_f,
                  'construction_name' => sub_surface.construction.get.nameString
                }
              end
              unless sub_surface_info.empty?
                sub_surfaces_info << {
                  'surface_name' => surface.nameString,
                  'subsurfaces' => sub_surface_info
                }
              end
            end
            # Regardless of if the wall is adjacent to a plenum or not add it to the exposed wall area adjacent to
            # conditioned spaces (accounting for space multipliers).
            total_exp_area += surface.grossArea * space.multiplier
          end
        end
      end
    end
    fdwr = 999
    unless exp_nonplenum_area < 0.1
      fdwr = sub_surface_area / exp_nonplenum_area
    end
    # Add everything into a hash and return that hash to whomever called the method.
    exp_surf_info = {
      'total_exp_wall_area_m2' => total_exp_area,
      'exp_plenum_wall_area_m2' => exp_plenum_area,
      'exp_nonplenum_wall_area_m2' => exp_nonplenum_area,
      'exp_plenum_walls' => plenum_surfaces,
      'exp_nonplenum_walls' => exposed_surfaces,
      'fdwr' => fdwr,
      'sub_surfaces' => sub_surfaces_info
    }
    return exp_surf_info
  end

  # This method is similar to the 'find_exposed_conditioned_vertical_surfaces' above only it is for roofs.  Again, it
  # distinguishes between plenum and non plenum roof area but collects and returns both.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Hash] hash of exposed roof information
  def find_exposed_conditioned_roof_surfaces(model)
    exposed_surfaces = []
    plenum_surfaces = []
    exp_plenum_area = 0
    total_exp_area = 0
    exp_nonplenum_area = 0
    sub_surfaces_info = []
    sub_surface_area = 0
    # Sort through each space and determine if it conditioned.  Conditioned meaning it is either heated, cooled, or both.
    model.getSpaces.sort.each do |space|
      cooled = space_cooled?(space)
      heated = space_heated?(space)
      # If the space is conditioned sort through the surfaces looking for outdoor roofs.
      if heated || cooled
        space.surfaces.sort.each do |surface|
          # Assume a roof is of type 'RoofCeiling' and has an 'Outdoors' boundary condition.
          next unless surface.surfaceType == 'RoofCeiling'
          next unless surface.outsideBoundaryCondition == 'Outdoors'

          # Determine if the roof is adjacent to a plenum.
          sub_surface_info = []
          if space_plenum?(space)
            # If the roof is adjacent to a plenum add it to the plenum roof array and the plenum roof area counter
            # (accounting for space multipliers).
            plenum_surfaces << surface
            exp_plenum_area += surface.grossArea * space.multiplier
          else
            # If the roof is not adjacent to a plenum add it to the non-plenum roof array and the non-plenum roof area
            # counter (accounting for space multipliers).
            exposed_surfaces << surface
            exp_nonplenum_area += surface.grossArea * space.multiplier
            surface.subSurfaces.sort.each do |sub_surface|
              sub_surface_area += sub_surface.grossArea.to_f * space.multiplier
              sub_surface_info << {
                'subsurface_name' => sub_surface.nameString,
                'subsurface_type' => sub_surface.subSurfaceType,
                'gross_area_m2' => sub_surface.grossArea.to_f,
                'construction_name' => sub_surface.construction.get.nameString
              }
            end
            unless sub_surface_info.empty?
              sub_surfaces_info << {
                'surface_name' => surface.nameString,
                'subsurfaces' => sub_surface_info
              }
            end
          end
          # Regardless of if the roof is adjacent to a plenum or not add it to the total roof area counter (accounting
          # for space multipliers).
          total_exp_area += surface.grossArea * space.multiplier
        end
      end
    end
    srr = 999
    unless exp_nonplenum_area < 0.1
      srr = sub_surface_area / exp_nonplenum_area
    end
    # Put the information into a hash and return it to whomever called this method.
    exp_surf_info = {
      'total_exp_roof_area_m2' => total_exp_area,
      'exp_plenum_roof_area_m2' => exp_plenum_area,
      'exp_nonplenum_roof_area_m2' => exp_nonplenum_area,
      'exp_plenum_roofs' => plenum_surfaces,
      'exp_nonplenum_roofs' => exposed_surfaces,
      'srr' => srr,
      'sub_surfaces' => sub_surfaces_info
    }
    return exp_surf_info
  end

  # This method finds the centroid of the highest roof(s).  It cycles through each space and finds which surfaces are
  # described as roofceiling whose outside boundary condition is outdoors.  Of those surfaces that do it looks for the
  # highest one(s) and finds the centroid of those.
  #
  # @param model [OpenStudio::Model::Model] OpenStudio model object
  # @return [Hash] It returns the following hash:
  #   roof_cent = {
  #     top_spaces:  array of spaces which contain the highest roofs,
  #     roof_centroid:  global x, y, and z coords of the centroid of the highest roof surfaces,
  #     roof_area:  area of the highst roof surfaces}
  #   Each element of the top_spaces is a hash containing the following:
  #     top_space = {
  #       space:  OpenStudio space containing the surface,
  #       x:  global x coord of the centroid of roof surface(s),
  #       y:  global y coord of the centroid of roof surface(s),
  #       z:  global z coord of the centroid of roof surface(s),
  #       area_m2:  area of the roof surface(s)}
  def find_highest_roof_centre(model)
    # Initialize some variables
    tol = 6
    max_height = -1000000000000000
    top_spaces = []
    spaces_info = []
    roof_centroid = [0, 0, 0]
    # Go through each space looking for outdoor roofs
    model.getSpaces.sort.each do |space|
      outdoor_roof = false
      space_max = -1000000000000000
      max_surf = nil
      space_surfaces = space.surfaces
      # Go through each surface in the space.  If it is an outdoor roofceiling then continue.  Otherwise go to the next
      # space.
      space_surfaces.each do |surface|
        outdoor_roof = true if surface.surfaceType.to_s.upcase == 'ROOFCEILING' && surface.outsideBoundaryCondition.to_s.upcase == 'OUTDOORS'
        # Is this surface the highest roof on this space?
        if surface.centroid.z.to_f.round(tol) > space_max
          space_max = surface.centroid.z.to_f.round(tol)
          max_surf = surface
        end
      end
      # If no outdoor roofceiling go to the next space.
      next if outdoor_roof == false

      z_origin = space.zOrigin.to_f
      ceiling_centroid = [0, 0, 0]

      # Go through the surfaces and look for ones that are the highest.  Any that are the highest get added to the
      # centroid calculation.
      space_surfaces.each do |sp_surface|
        if max_surf.centroid.z.to_f.round(tol) == sp_surface.centroid.z.to_f.round(tol)
          ceiling_centroid[0] += sp_surface.centroid.x.to_f * sp_surface.grossArea.to_f
          ceiling_centroid[1] += sp_surface.centroid.y.to_f * sp_surface.grossArea.to_f
          ceiling_centroid[2] += sp_surface.grossArea.to_f
        end
      end

      # Calculate the centroid of the highest surface/surfaces for this space.
      ceiling_centroid[0] /= ceiling_centroid[2]
      ceiling_centroid[1] /= ceiling_centroid[2]

      # Put the info into an array containing hashes of spaces with outdoor roofceilings
      spaces_info << {
        space: space,
        x: ceiling_centroid[0] + space.xOrigin.to_f,
        y: ceiling_centroid[1] + space.yOrigin.to_f,
        z: max_surf.centroid.z.to_f + z_origin,
        area_m2: ceiling_centroid[2]
      }
      # This is to determine which are the global highest outdoor roofceilings
      if max_height.round(tol) < (max_surf.centroid.z.to_f + z_origin).round(tol)
        max_height = (max_surf.centroid.z.to_f + z_origin).round(tol)
      end
    end
    # Go through the roofceilings and find the highest one(s) and calculate the centroid.
    spaces_info.each do |space_info|
      # If the outdoor roofceiling is one of the highest ones add it to an array of hashes and get the info needed to
      # calculate the centroid
      if space_info[:z].to_f.round(tol) == max_height.round(tol)
        top_spaces << space_info
        roof_centroid[0] += space_info[:x] * space_info[:area_m2]
        roof_centroid[1] += space_info[:y] * space_info[:area_m2]
        roof_centroid[2] += space_info[:area_m2]
      end
    end
    # calculate the centroid of the highest outdoor roofceiling(s) and add the info to a hash to return to whomever
    # called this method.
    roof_centroid[0] /= roof_centroid[2]
    roof_centroid[1] /= roof_centroid[2]
    roof_cent = {
      top_spaces: top_spaces,
      roof_centroid: [roof_centroid[0], roof_centroid[1], max_height],
      roof_area: roof_centroid[2]
    }
    return roof_cent
  end

  # Returns the surface and subsurface UA product
  #
  # @param [OpenStudio::Model::Surface] OpenStudio model surface object
  #
  # @retrun [Double] UA product in W/K
  def surface_subsurface_ua(surface)
    # Compute the surface UA product
    if surface.outsideBoundaryCondition.to_s == 'GroundFCfactorMethod' && surface.construction.is_initialized
      cons = surface.construction.get
      fc_obj_type = cons.iddObjectType.valueName.to_s
      case fc_obj_type
        when 'OS_Construction_FfactorGroundFloor'
          cons = surface.construction.get.to_FFactorGroundFloorConstruction.get
          ffac = cons.fFactor
          area = cons.area
          peri = cons.perimeterExposed
          ua = ffac * peri * surface.netArea / area
        when 'OS_Construction_CfactorUndergroundWall'
          cons = surface.construction.get.to_CFactorUndergroundWallConstruction.get
          cfac = cons.cFactor
          heig = cons.height

          # From 90.1-2019 Section A.9.4.1: Interior vertical surfaces (SI units)
          r_inside_film = 0.1197548
          r_outside_film = 0.0

          # EnergyPlus Engineering Manual equation 3.195
          r_soil = 0.0607 + 0.3479 * heig

          r_eff = 1 / cfac + r_soil
          u_eff = 1 / (r_eff + r_inside_film + r_outside_film)

          ua = u_eff * surface.netArea
      end
    else
      ua = surface.uFactor.get * surface.netArea
    end

    surface.subSurfaces.sort.each do |subsurface|
      if subsurface.construction.get.to_Construction.get.layers[0].to_Material.get.to_SimpleGlazing.empty?
        # the uFactor() method does not work for complex glazing inputs
        # For this case the U-Factor is retrieved from previous sizing run
        u_factor = construction_calculated_fenestration_u_factor_w_frame(subsurface.construction.get)
      else
        # replace with direct query: u_factor = subsurface.uFactor.get
        glass_u_factor_query = "SELECT Value
                  FROM tabulardatawithstrings
                  WHERE ReportName='EnvelopeSummary'
                  AND ReportForString='Entire Facility'
                  AND TableName='Exterior Fenestration'
                  AND ColumnName='Glass U-Factor'
                  AND RowName='#{subsurface.name.get.upcase}'"
        sql = surface.model.sqlFile.get

        glass_u_factor_w_per_m2_k = sql.execAndReturnFirstDouble(glass_u_factor_query)
        u_factor = glass_u_factor_w_per_m2_k.is_initialized ? glass_u_factor_w_per_m2_k.get : 0.0
      end
      # u_factor = subsurface.uFactor.is_initialized ? (subsurface.uFactor.get) : (construction_calculated_fenestration_u_factor_w_frame(subsurface.construction.get))
      ua += u_factor * subsurface.netArea
    end

    return ua
  end

  # Calculate a surface's absolute azimuth
  # source: https://github.com/NREL/openstudio-extension-gem/blob/e354355054b83ffc26e3b69befa20d6baf5ef242/lib/openstudio/extension/core/os_lib_geometry.rb#L913
  #
  # @param surface [OpenStudio::Model::Surface] surface object
  # @return [Double] surface absolute azimuth
  def surface_absolute_azimuth(surface)
    # Get associated space
    space = surface.space.get

    # Get model object
    model = surface.model

    # Calculate azimuth
    surface_azimuth_rel_space = OpenStudio.convert(surface.azimuth, 'rad', 'deg').get
    space_dir_rel_north = space.directionofRelativeNorth
    building_dir_rel_north = model.getBuilding.northAxis
    surface_abs_azimuth = surface_azimuth_rel_space + space_dir_rel_north + building_dir_rel_north
    surface_abs_azimuth -= 360.0 until surface_abs_azimuth < 360.0

    return surface_abs_azimuth
  end

  # Determine a surface absolute cardinal direction
  #
  # @param surface [OpenStudio::Model::Surface] surface object
  # @return [String] surface absolute cardinal direction
  def surface_cardinal_direction(surface)
    # Get the surface's absolute azimuth
    surface_abs_azimuth = surface_absolute_azimuth(surface)

    # Determine the surface's cardinal direction
    if surface_abs_azimuth >= 0 && surface_abs_azimuth <= 45
      return 'N'
    elsif surface_abs_azimuth > 315 && surface_abs_azimuth <= 360
      return 'N'
    elsif surface_abs_azimuth > 45 && surface_abs_azimuth <= 135
      return 'E'
    elsif surface_abs_azimuth > 135 && surface_abs_azimuth <= 225
      return 'S'
    elsif surface_abs_azimuth > 225 && surface_abs_azimuth <= 315
      return 'W'
    end
  end

  # Calculate the wwr of a surface
  #
  # @param surface [OpenStudio::Model::Surface]
  # @return [Float] window to wall ratio of a surface
  def surface_get_wwr_of_a_surface(surface)
    surface_area = surface.grossArea
    surface_fene_area = 0.0
    surface.subSurfaces.sort.each do |ss|
      next unless ss.subSurfaceType == 'FixedWindow' || ss.subSurfaceType == 'OperableWindow' || ss.subSurfaceType == 'GlassDoor'

      surface_fene_area += ss.netArea
    end
    return surface_fene_area / surface_area
  end

  # Adjust the fenestration area to the values specified by the reduction value in a surface
  #
  # @param surface [OpenStudio::Model:Surface] openstudio surface object
  # @param reduction [Float] ratio of adjustments
  # @param model [OpenStudio::Model::Model] openstudio model
  # @return [Bool] return true if successful, false if not
  def surface_adjust_fenestration_in_a_surface(surface, reduction, model)
    # Subsurfaces in this surface
    # Default case only handles reduction
    if reduction < 1.0
      surface.subSurfaces.sort.each do |ss|
        next unless ss.subSurfaceType == 'FixedWindow' || ss.subSurfaceType == 'OperableWindow' || ss.subSurfaceType == 'GlassDoor'

        if sub_surface_vertical_rectangle?(ss)
          sub_surface_reduce_area_by_percent_by_raising_sill(ss, reduction)
        else
          sub_surface_reduce_area_by_percent_by_shrinking_toward_centroid(ss, reduction)
        end
      end
    end
    return true
  end

  # Calculate the door ratio of a surface
  #
  # @param surface [OpenStudio::Model::Surface]
  # @return [Float] window to wall ratio of a surface
  def surface_get_door_ratio_of_a_surface(surface)
    surface_area = surface.grossArea
    surface_door_area = 0.0
    surface.subSurfaces.sort.each do |ss|
      next unless ss.subSurfaceType == 'Door'

      surface_door_area += ss.netArea
    end
    return surface_door_area / surface_area
  end
end

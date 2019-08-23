class Standard
  # @!group Space

  # Returns values for the different types of daylighted areas in the space.
  # Definitions for each type of area follow the respective template.
  # @note This method is super complicated because of all the polygon/geometry math required.
  #   and therefore may not return perfect results.  However, it works well in most tested
  #   situations.  When it fails, it will log warnings/errors for users to see.
  #
  # @param draw_daylight_areas_for_debugging [Bool] If this argument is set to true,
  #   daylight areas will be added to the model as surfaces for visual debugging.
  #   Yellow = toplighted area, Red = primary sidelighted area,
  #   Blue = secondary sidelighted area, Light Blue = floor
  # @return [Hash] returns a hash of resulting areas (m^2).
  #   Hash keys are: 'toplighted_area', 'primary_sidelighted_area',
  #   'secondary_sidelighted_area', 'total_window_area', 'total_skylight_area'
  # @todo add a list of valid choices for template argument
  # TODO stop skipping non-vertical walls
  def space_daylighted_areas(space, draw_daylight_areas_for_debugging = false)
    ### Begin the actual daylight area calculations ###

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, calculating daylighted areas.")

    result = { 'toplighted_area' => 0.0,
               'primary_sidelighted_area' => 0.0,
               'secondary_sidelighted_area' => 0.0,
               'total_window_area' => 0.0,
               'total_skylight_area' => 0.0 }

    total_window_area = 0
    total_skylight_area = 0

    # Make rendering colors to help debug visually
    if draw_daylight_areas_for_debugging
      # Yellow
      toplit_construction = OpenStudio::Model::Construction.new(space.model)
      toplit_color = OpenStudio::Model::RenderingColor.new(space.model)
      toplit_color.setRenderingRedValue(255)
      toplit_color.setRenderingGreenValue(255)
      toplit_color.setRenderingBlueValue(0)
      toplit_construction.setRenderingColor(toplit_color)

      # Red
      pri_sidelit_construction = OpenStudio::Model::Construction.new(space.model)
      pri_sidelit_color = OpenStudio::Model::RenderingColor.new(space.model)
      pri_sidelit_color.setRenderingRedValue(255)
      pri_sidelit_color.setRenderingGreenValue(0)
      pri_sidelit_color.setRenderingBlueValue(0)
      pri_sidelit_construction.setRenderingColor(pri_sidelit_color)

      # Blue
      sec_sidelit_construction = OpenStudio::Model::Construction.new(space.model)
      sec_sidelit_color = OpenStudio::Model::RenderingColor.new(space.model)
      sec_sidelit_color.setRenderingRedValue(0)
      sec_sidelit_color.setRenderingGreenValue(0)
      sec_sidelit_color.setRenderingBlueValue(255)
      sec_sidelit_construction.setRenderingColor(sec_sidelit_color)

      # Light Blue
      flr_construction = OpenStudio::Model::Construction.new(space.model)
      flr_color = OpenStudio::Model::RenderingColor.new(space.model)
      flr_color.setRenderingRedValue(0)
      flr_color.setRenderingGreenValue(255)
      flr_color.setRenderingBlueValue(255)
      flr_construction.setRenderingColor(flr_color)
    end

    # Move the polygon up slightly for viewability in sketchup
    up_translation_flr = OpenStudio.createTranslation(OpenStudio::Vector3d.new(0, 0, 0.05))
    up_translation_top = OpenStudio.createTranslation(OpenStudio::Vector3d.new(0, 0, 0.1))
    up_translation_pri = OpenStudio.createTranslation(OpenStudio::Vector3d.new(0, 0, 0.1))
    up_translation_sec = OpenStudio.createTranslation(OpenStudio::Vector3d.new(0, 0, 0.1))

    # Get the space's surface group's transformation
    @space_transformation = space.transformation

    # Record a floor in the space for later use
    floor_surface = nil

    # Record all floor polygons
    floor_polygons = []
    floor_z = 0.0
    space.surfaces.sort.each do |surface|
      if surface.surfaceType == 'Floor'
        floor_surface = surface
        floor_z = surface.vertices[0].z
        # floor_polygons << surface.vertices
        # Hard-set the z for the floor to zero
        new_floor_polygon = []
        surface.vertices.each do |vertex|
          new_floor_polygon << OpenStudio::Point3d.new(vertex.x, vertex.y, 0.0)
        end
        floor_polygons << new_floor_polygon
      end
    end

    # Make sure there is one floor surface
    if floor_surface.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Could not find a floor in space #{space.name}, cannot determine daylighted areas.")
      return result
    end

    # Make a set of vertices representing each subsurfaces sidelighteding area
    # and fold them all down onto the floor of the self.
    toplit_polygons = []
    pri_sidelit_polygons = []
    sec_sidelit_polygons = []
    space.surfaces.sort.each do |surface|
      if surface.outsideBoundaryCondition == 'Outdoors' && surface.surfaceType == 'Wall'

        # TODO: stop skipping non-vertical walls
        surface_normal = surface.outwardNormal
        surface_normal_z = surface_normal.z
        unless surface_normal_z.abs < 0.001
          unless surface.subSurfaces.empty?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Cannot currently handle non-vertical walls; skipping windows on #{surface.name} in #{space.name}.")
            next
          end
        end

        surface.subSurfaces.sort.each do |sub_surface|
          next unless sub_surface.outsideBoundaryCondition == 'Outdoors' && (sub_surface.subSurfaceType == 'FixedWindow' || sub_surface.subSurfaceType == 'OperableWindow' || sub_surface.subSurfaceType == 'GlassDoor')

          # OpenStudio::logFree(OpenStudio::Debug, "openstudio.model.Space", "***#{sub_surface.name}***"
          total_window_area += sub_surface.netArea

          # Find the head height and sill height of the window
          vertex_heights_above_floor = []
          sub_surface.vertices.each do |vertex|
            vertex_on_floorplane = floor_surface.plane.project(vertex)
            vertex_heights_above_floor << (vertex - vertex_on_floorplane).length
          end
          sill_height_m = vertex_heights_above_floor.min
          head_height_m = vertex_heights_above_floor.max
          # OpenStudio::logFree(OpenStudio::Debug, "openstudio.model.Space", "head height = #{head_height_m.round(2)}m, sill height = #{sill_height_m.round(2)}m")

          # Find the width of the window
          rot_origin = nil
          unless sub_surface.vertices.size == 4
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "A sub-surface in space #{space.name} has other than 4 vertices; this sub-surface will not be included in the daylighted area calculation.")
            next
          end
          prev_vertex_on_floorplane = nil
          max_window_width_m = 0
          sub_surface.vertices.each do |vertex|
            vertex_on_floorplane = floor_surface.plane.project(vertex)
            unless prev_vertex_on_floorplane
              prev_vertex_on_floorplane = vertex_on_floorplane
              next
            end
            width_m = (prev_vertex_on_floorplane - vertex_on_floorplane).length
            if width_m > max_window_width_m
              max_window_width_m = width_m
              rot_origin = vertex_on_floorplane
            end
          end

          # Determine the extra width to add to the sidelighted area
          extra_width_m = 0
          width_method = space_daylighted_area_window_width(space)
          if width_method == 'proportional'
            extra_width_m = head_height_m / 2
          elsif width_method == 'fixed'
            extra_width_m = OpenStudio.convert(2, 'ft', 'm').get
          end
          # OpenStudio::logFree(OpenStudio::Debug, "openstudio.model.Space", "Adding #{extra_width_m.round(2)}m to the width for the sidelighted area.")

          # Align the vertices with face coordinate system
          face_transform = OpenStudio::Transformation.alignFace(sub_surface.vertices)
          aligned_vertices = face_transform.inverse * sub_surface.vertices

          # Find the min and max x values
          min_x_val = 99_999
          max_x_val = -99_999
          aligned_vertices.each do |vertex|
            # Min x value
            if vertex.x < min_x_val
              min_x_val = vertex.x
            end
            # Max x value
            if vertex.x > max_x_val
              max_x_val = vertex.x
            end
          end
          # OpenStudio::logFree(OpenStudio::Debug, "openstudio.model.Space", "min_x_val = #{min_x_val.round(2)}, max_x_val = #{max_x_val.round(2)}")

          # Create polygons that are adjusted
          # to expand from the window shape to the sidelighteded areas.
          pri_sidelit_sub_polygon = []
          sec_sidelit_sub_polygon = []
          aligned_vertices.each do |vertex|
            # Primary sidelighted area
            # Move the x vertices outward by the specified amount.
            if (vertex.x - min_x_val).abs < 0.01
              new_x = vertex.x - extra_width_m
            elsif (vertex.x - max_x_val).abs < 0.01
              new_x = vertex.x + extra_width_m
            else
              new_x = 99.9
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "A window in space #{space.name} is non-rectangular; this sub-surface will not be included in the primary daylighted area calculation. #{vertex.x} != #{min_x_val} or #{max_x_val}")
            end

            # Zero-out the y for the bottom edge because the
            # sidelighteding area extends down to the floor.
            new_y = if vertex.y.zero?
                      vertex.y - sill_height_m
                    else
                      vertex.y
                    end

            # Set z = 0 so that intersection works.
            new_z = 0.0

            # Make the new vertex
            new_vertex = OpenStudio::Point3d.new(new_x, new_y, new_z)
            pri_sidelit_sub_polygon << new_vertex
            # OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Space", "#{vertex.x.round(2)}, #{vertex.y.round(2)}, #{vertex.z.round(2)} ==> #{new_vertex.x.round(2)}, #{new_vertex.y.round(2)}, #{new_vertex.z.round(2)}")

            # Secondary sidelighted area
            # Move the x vertices outward by the specified amount.
            if (vertex.x - min_x_val).abs < 0.01
              new_x = vertex.x - extra_width_m
            elsif (vertex.x - max_x_val).abs < 0.01
              new_x = vertex.x + extra_width_m
            else
              new_x = 99.9
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "A window in space #{space.name} is non-rectangular; this sub-surface will not be included in the secondary daylighted area calculation.")
            end

            # Add the head height of the window to all points
            # sidelighteding area extends down to the floor.
            new_y = if vertex.y.zero?
                      vertex.y - sill_height_m + head_height_m
                    else
                      vertex.y + head_height_m
                    end

            # Set z = 0 so that intersection works.
            new_z = 0.0

            # Make the new vertex
            new_vertex = OpenStudio::Point3d.new(new_x, new_y, new_z)
            sec_sidelit_sub_polygon << new_vertex
          end

          # Realign the vertices with space coordinate system
          pri_sidelit_sub_polygon = face_transform * pri_sidelit_sub_polygon
          sec_sidelit_sub_polygon = face_transform * sec_sidelit_sub_polygon

          # Rotate the sidelighteded areas down onto the floor
          down_vector = OpenStudio::Vector3d.new(0, 0, -1)
          outward_normal_vector = sub_surface.outwardNormal
          rot_vector = down_vector.cross(outward_normal_vector)
          ninety_deg_in_rad = OpenStudio.degToRad(90) # TODO: change
          new_rotation = OpenStudio.createRotation(rot_origin, rot_vector, ninety_deg_in_rad)
          pri_sidelit_sub_polygon = new_rotation * pri_sidelit_sub_polygon
          sec_sidelit_sub_polygon = new_rotation * sec_sidelit_sub_polygon

          # Put the polygon vertices into counterclockwise order
          pri_sidelit_sub_polygon = pri_sidelit_sub_polygon.reverse
          sec_sidelit_sub_polygon = sec_sidelit_sub_polygon.reverse

          # Add these polygons to the list
          pri_sidelit_polygons << pri_sidelit_sub_polygon
          sec_sidelit_polygons << sec_sidelit_sub_polygon
        end # Next subsurface
      elsif surface.outsideBoundaryCondition == 'Outdoors' && surface.surfaceType == 'RoofCeiling'

        # TODO: stop skipping non-horizontal roofs
        surface_normal = surface.outwardNormal
        straight_upward = OpenStudio::Vector3d.new(0, 0, 1)
        unless surface_normal.to_s == straight_upward.to_s
          unless surface.subSurfaces.empty?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Cannot currently handle non-horizontal roofs; skipping skylights on #{surface.name} in #{space.name}.")
            OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---Surface #{surface.name} has outward normal of #{surface_normal.to_s.gsub(/\[|\]/, '|')}; up is #{straight_upward.to_s.gsub(/\[|\]/, '|')}.")
            next
          end
        end

        surface.subSurfaces.sort.each do |sub_surface|
          next unless sub_surface.outsideBoundaryCondition == 'Outdoors' && sub_surface.subSurfaceType == 'Skylight'

          # OpenStudio::logFree(OpenStudio::Debug, "openstudio.model.Space", "***#{sub_surface.name}***")
          total_skylight_area += sub_surface.netArea

          # Project the skylight onto the floor plane
          polygon_on_floor = []
          vertex_heights_above_floor = []
          sub_surface.vertices.each do |vertex|
            vertex_on_floorplane = floor_surface.plane.project(vertex)
            vertex_heights_above_floor << (vertex - vertex_on_floorplane).length
            polygon_on_floor << vertex_on_floorplane
          end

          # Determine the ceiling height.
          # Assumes skylight is flush with ceiling.
          ceiling_height_m = vertex_heights_above_floor.max

          # Align the vertices with face coordinate system
          face_transform = OpenStudio::Transformation.alignFace(polygon_on_floor)
          aligned_vertices = face_transform.inverse * polygon_on_floor

          # Find the min and max x and y values
          min_x_val = 99_999
          max_x_val = -99_999
          min_y_val = 99_999
          max_y_val = -99_999
          aligned_vertices.each do |vertex|
            # Min x value
            if vertex.x < min_x_val
              min_x_val = vertex.x
            end
            # Max x value
            if vertex.x > max_x_val
              max_x_val = vertex.x
            end
            # Min y value
            if vertex.y < min_y_val
              min_y_val = vertex.y
            end
            # Max y value
            if vertex.y > max_x_val
              max_y_val = vertex.y
            end
          end

          # Figure out how much to expand the window
          additional_extent_m = 0.7 * ceiling_height_m

          # Create polygons that are adjusted
          # to expand from the window shape to the sidelighteded areas.
          toplit_sub_polygon = []
          aligned_vertices.each do |vertex|
            # Move the x vertices outward by the specified amount.
            if vertex.x == min_x_val
              new_x = vertex.x - additional_extent_m
            elsif vertex.x == max_x_val
              new_x = vertex.x + additional_extent_m
            else
              new_x = 99.9
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "A skylight in space #{space.name} is non-rectangular; this sub-surface will not be included in the daylighted area calculation.")
            end

            # Move the y vertices outward by the specified amount.
            if vertex.y == min_y_val
              new_y = vertex.y - additional_extent_m
            elsif vertex.y == max_y_val
              new_y = vertex.y + additional_extent_m
            else
              new_y = 99.9
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "A skylight in space #{space.name} is non-rectangular; this sub-surface will not be included in the daylighted area calculation.")
            end

            # Set z = 0 so that intersection works.
            new_z = 0.0

            # Make the new vertex
            new_vertex = OpenStudio::Point3d.new(new_x, new_y, new_z)
            toplit_sub_polygon << new_vertex
          end

          # Realign the vertices with space coordinate system
          toplit_sub_polygon = face_transform * toplit_sub_polygon

          # Put the polygon vertices into counterclockwise order
          toplit_sub_polygon = toplit_sub_polygon.reverse

          # Add these polygons to the list
          toplit_polygons << toplit_sub_polygon
        end # Next subsurface

      end # End if outdoor wall or roofceiling
    end # Next surface

    # Set z=0 for all the polygons so that intersection will work
    toplit_polygons = space_polygons_set_z(space, toplit_polygons, 0.0)
    pri_sidelit_polygons = space_polygons_set_z(space, pri_sidelit_polygons, 0.0)
    sec_sidelit_polygons = space_polygons_set_z(space, sec_sidelit_polygons, 0.0)

    # Check the initial polygons
    space_check_z_zero(space, floor_polygons, 'floor_polygons')
    space_check_z_zero(space, toplit_polygons, 'toplit_polygons')
    space_check_z_zero(space, pri_sidelit_polygons, 'pri_sidelit_polygons')
    space_check_z_zero(space, sec_sidelit_polygons, 'sec_sidelit_polygons')

    # Join, then subtract
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '***Joining polygons***')

    # Join toplighted polygons into a single set
    combined_toplit_polygons = space_join_polygons(space, toplit_polygons, 0.01, 'toplit_polygons')

    # Join primary sidelighted polygons into a single set
    combined_pri_sidelit_polygons = space_join_polygons(space, pri_sidelit_polygons, 0.01, 'pri_sidelit_polygons')

    # Join secondary sidelighted polygons into a single set
    combined_sec_sidelit_polygons = space_join_polygons(space, sec_sidelit_polygons, 0.01, 'sec_sidelit_polygons')

    # Join floor polygons into a single set
    combined_floor_polygons = space_join_polygons(space, floor_polygons, 0.01, 'floor_polygons')

    # Check the joined polygons
    space_check_z_zero(space, combined_floor_polygons, 'combined_floor_polygons')
    space_check_z_zero(space, combined_toplit_polygons, 'combined_toplit_polygons')
    space_check_z_zero(space, combined_pri_sidelit_polygons, 'combined_pri_sidelit_polygons')
    space_check_z_zero(space, combined_sec_sidelit_polygons, 'combined_sec_sidelit_polygons')

    # Make a new surface for each of the resulting polygons to visually inspect it
    # OpenStudio::logFree(OpenStudio::Debug, "openstudio.model.Space", "***Making Surfaces to view in SketchUp***")

    # combined_toplit_polygons.each do |polygon|
    # dummy_space = OpenStudio::Model::Space.new(model)
    # polygon = up_translation_top * polygon
    # daylt_surf = OpenStudio::Model::Surface.new(polygon, model)
    # daylt_surf.setConstruction(toplit_construction)
    # daylt_surf.setSpace(dummy_space)
    # daylt_surf.setName("Top")
    # end

    # combined_pri_sidelit_polygons.each do |polygon|
    # dummy_space = OpenStudio::Model::Space.new(model)
    # polygon = up_translation_pri * polygon
    # daylt_surf = OpenStudio::Model::Surface.new(polygon, model)
    # daylt_surf.setConstruction(pri_sidelit_construction)
    # daylt_surf.setSpace(dummy_space)
    # daylt_surf.setName("Pri")
    # end

    # combined_sec_sidelit_polygons.each do |polygon|
    # dummy_space = OpenStudio::Model::Space.new(model)
    # polygon = up_translation_sec * polygon
    # daylt_surf = OpenStudio::Model::Surface.new(polygon, model)
    # daylt_surf.setConstruction(sec_sidelit_construction)
    # daylt_surf.setSpace(dummy_space)
    # daylt_surf.setName("Sec")
    # end

    # combined_floor_polygons.each do |polygon|
    # dummy_space = OpenStudio::Model::Space.new(model)
    # polygon = up_translation_flr * polygon
    # daylt_surf = OpenStudio::Model::Surface.new(polygon, model)
    # daylt_surf.setConstruction(flr_construction)
    # daylt_surf.setSpace(dummy_space)
    # daylt_surf.setName("Flr")
    # end

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '***Subtracting overlapping areas***')

    # Subtract lower-priority daylighting areas from higher priority ones
    pri_minus_top_polygons = space_a_polygons_minus_b_polygons(space, combined_pri_sidelit_polygons, combined_toplit_polygons, 'combined_pri_sidelit_polygons', 'combined_toplit_polygons')

    sec_minus_top_polygons = space_a_polygons_minus_b_polygons(space, combined_sec_sidelit_polygons, combined_toplit_polygons, 'combined_sec_sidelit_polygons', 'combined_toplit_polygons')

    sec_minus_top_minus_pri_polygons = space_a_polygons_minus_b_polygons(space, sec_minus_top_polygons, combined_pri_sidelit_polygons, 'sec_minus_top_polygons', 'combined_pri_sidelit_polygons')

    # Check the subtracted polygons
    space_check_z_zero(space, pri_minus_top_polygons, 'pri_minus_top_polygons')
    space_check_z_zero(space, sec_minus_top_polygons, 'sec_minus_top_polygons')
    space_check_z_zero(space, sec_minus_top_minus_pri_polygons, 'sec_minus_top_minus_pri_polygons')

    # Make a new surface for each of the resulting polygons to visually inspect it.
    # First reset the z so the surfaces show up on the correct plane.
    if draw_daylight_areas_for_debugging

      combined_toplit_polygons_at_floor = space_polygons_set_z(space, combined_toplit_polygons, floor_z)
      pri_minus_top_polygons_at_floor = space_polygons_set_z(space, pri_minus_top_polygons, floor_z)
      sec_minus_top_minus_pri_polygons_at_floor = space_polygons_set_z(space, sec_minus_top_minus_pri_polygons, floor_z)
      combined_floor_polygons_at_floor = space_polygons_set_z(space, combined_floor_polygons, floor_z)

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '***Making Surfaces to view in SketchUp***')
      dummy_space = OpenStudio::Model::Space.new(space.model)

      combined_toplit_polygons_at_floor.each do |polygon|
        polygon = up_translation_top * polygon
        polygon = @space_transformation * polygon
        daylt_surf = OpenStudio::Model::Surface.new(polygon, space.model)
        daylt_surf.setConstruction(toplit_construction)
        daylt_surf.setSpace(dummy_space)
        daylt_surf.setName('Top')
      end

      pri_minus_top_polygons_at_floor.each do |polygon|
        polygon = up_translation_pri * polygon
        polygon = @space_transformation * polygon
        daylt_surf = OpenStudio::Model::Surface.new(polygon, space.model)
        daylt_surf.setConstruction(pri_sidelit_construction)
        daylt_surf.setSpace(dummy_space)
        daylt_surf.setName('Pri')
      end

      sec_minus_top_minus_pri_polygons_at_floor.each do |polygon|
        polygon = up_translation_sec * polygon
        polygon = @space_transformation * polygon
        daylt_surf = OpenStudio::Model::Surface.new(polygon, space.model)
        daylt_surf.setConstruction(sec_sidelit_construction)
        daylt_surf.setSpace(dummy_space)
        daylt_surf.setName('Sec')
      end

      combined_floor_polygons_at_floor.each do |polygon|
        polygon = up_translation_flr * polygon
        polygon = @space_transformation * polygon
        daylt_surf = OpenStudio::Model::Surface.new(polygon, space.model)
        daylt_surf.setConstruction(flr_construction)
        daylt_surf.setSpace(dummy_space)
        daylt_surf.setName('Flr')
      end
    end

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '***Calculating Daylighted Areas***')

    # Get the total floor area
    total_floor_area_m2 = space_total_area_of_polygons(space, combined_floor_polygons)
    total_floor_area_ft2 = OpenStudio.convert(total_floor_area_m2, 'm^2', 'ft^2').get
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "total_floor_area_ft2 = #{total_floor_area_ft2.round(1)}")

    # Toplighted area
    toplighted_area_m2 = space_area_a_polygons_overlap_b_polygons(space, combined_toplit_polygons, combined_floor_polygons, 'combined_toplit_polygons', 'combined_floor_polygons')

    # Primary sidelighted area
    primary_sidelighted_area_m2 = space_area_a_polygons_overlap_b_polygons(space, pri_minus_top_polygons, combined_floor_polygons, 'pri_minus_top_polygons', 'combined_floor_polygons')

    # Secondary sidelighted area
    secondary_sidelighted_area_m2 = space_area_a_polygons_overlap_b_polygons(space, sec_minus_top_minus_pri_polygons, combined_floor_polygons, 'sec_minus_top_minus_pri_polygons', 'combined_floor_polygons')

    # Convert to IP for displaying
    toplighted_area_ft2 = OpenStudio.convert(toplighted_area_m2, 'm^2', 'ft^2').get
    primary_sidelighted_area_ft2 = OpenStudio.convert(primary_sidelighted_area_m2, 'm^2', 'ft^2').get
    secondary_sidelighted_area_ft2 = OpenStudio.convert(secondary_sidelighted_area_m2, 'm^2', 'ft^2').get

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "toplighted_area_ft2 = #{toplighted_area_ft2.round(1)}")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "primary_sidelighted_area_ft2 = #{primary_sidelighted_area_ft2.round(1)}")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "secondary_sidelighted_area_ft2 = #{secondary_sidelighted_area_ft2.round(1)}")

    result['toplighted_area'] = toplighted_area_m2
    result['primary_sidelighted_area'] = primary_sidelighted_area_m2
    result['secondary_sidelighted_area'] = secondary_sidelighted_area_m2
    result['total_window_area'] = total_window_area
    result['total_skylight_area'] = total_skylight_area

    return result
  end

  # Determines the method used to extend the daylighted area horizontally
  # next to a window.  If the method is 'fixed', 2 ft is added to the
  # width of each window.  If the method is 'proportional', a distance
  # equal to half of the head height of the window is added.  If the method is 'none',
  # no additional width is added.
  # Default is none.
  #
  # @return [String] returns 'fixed' or 'proportional'
  def space_daylighted_area_window_width(space)
    method = 'none'
    return method
  end

  # Returns the sidelighting effective aperture
  # space_sidelighting_effective_aperture(space)  = E(window area * window VT) / primary_sidelighted_area
  #
  # @param primary_sidelighted_area [Double] the primary sidelighted area (m^2) of the space
  # @return [Double] the unitless sidelighting effective aperture metric
  def space_sidelighting_effective_aperture(space, primary_sidelighted_area)
    # space_sidelighting_effective_aperture(space)  = E(window area * window VT) / primary_sidelighted_area
    sidelighting_effective_aperture = 9999

    num_sub_surfaces = 0

    # Loop through all windows and add up area * VT
    sum_window_area_times_vt = 0
    construction_name_to_vt_map = {}
    space.surfaces.sort.each do |surface|
      next unless surface.outsideBoundaryCondition == 'Outdoors' && surface.surfaceType == 'Wall'
      surface.subSurfaces.sort.each do |sub_surface|
        next unless sub_surface.outsideBoundaryCondition == 'Outdoors' && (sub_surface.subSurfaceType == 'FixedWindow' || sub_surface.subSurfaceType == 'OperableWindow' || sub_surface.subSurfaceType == 'GlassDoor')

        num_sub_surfaces += 1

        # Get the area
        area_m2 = sub_surface.netArea

        # Get the window construction name
        construction_name = nil
        construction = sub_surface.construction
        if construction.is_initialized
          construction_name = construction.get.name.get.upcase
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "For #{space.name}, could not determine construction for #{sub_surface.name}, will not be included in  space_sidelighting_effective_aperture(space)  calculation.")
          next
        end

        # Store VT for this construction in map if not already looked up
        if construction_name_to_vt_map[construction_name].nil?

          sql = space.model.sqlFile

          if sql.is_initialized
            sql = sql.get

            row_query = "SELECT RowName
                        FROM tabulardatawithstrings
                        WHERE ReportName='EnvelopeSummary'
                        AND ReportForString='Entire Facility'
                        AND TableName='Exterior Fenestration'
                        AND Value='#{construction_name.upcase}'"

            row_id = sql.execAndReturnFirstString(row_query)

            if row_id.is_initialized
              row_id = row_id.get
            else
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "VT row ID not found for construction: #{construction_name}, #{sub_surface.name} will not be included in  space_sidelighting_effective_aperture(space)  calculation.")
              row_id = 9999
            end

            vt_query = "SELECT Value
                        FROM tabulardatawithstrings
                        WHERE ReportName='EnvelopeSummary'
                        AND ReportForString='Entire Facility'
                        AND TableName='Exterior Fenestration'
                        AND ColumnName='Glass Visible Transmittance'
                        AND RowName='#{row_id}'"

            vt = sql.execAndReturnFirstDouble(vt_query)

            vt = if vt.is_initialized
                   vt.get
                 end

            # Record the VT
            construction_name_to_vt_map[construction_name] = vt

          else
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.standards.Space', 'Model has no sql file containing results, cannot lookup data.')
          end

        end

        # Get the VT from the map
        vt = construction_name_to_vt_map[construction_name]
        if vt.nil?
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "For #{space.name}, could not determine VLT for #{construction_name}, will not be included in sidelighting effective aperture caluclation.")
          vt = 0
        end

        sum_window_area_times_vt += area_m2 * vt
      end
    end

    # Calculate the effective aperture
    if sum_window_area_times_vt.zero?
      sidelighting_effective_aperture = 9999
      if num_sub_surfaces > 0
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} has no windows where VLT could be determined, sidelighting effective aperture will be higher than it should.")
      end
    else
      sidelighting_effective_aperture = sum_window_area_times_vt / primary_sidelighted_area
    end

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Space', "For #{space.name} sidelighting effective aperture = #{sidelighting_effective_aperture.round(4)}.")

    return sidelighting_effective_aperture
  end

  # Returns the skylight effective aperture
  # space_skylight_effective_aperture(space)  = E(0.85 * skylight area * skylight VT * WF) / toplighted_area
  #
  # @param toplighted_area [Double] the toplighted area (m^2) of the space
  # @return [Double] the unitless skylight effective aperture metric
  def space_skylight_effective_aperture(space, toplighted_area)
    # space_skylight_effective_aperture(space)  = E(0.85 * skylight area * skylight VT * WF) / toplighted_area
    skylight_effective_aperture = 0.0

    num_sub_surfaces = 0

    # Assume that well factor (WF) is 0.9 (all wells are less than 2 feet deep)
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', 'Assuming that all skylight wells are less than 2 feet deep to calculate skylight effective aperture.')
    wf = 0.9

    # Loop through all windows and add up area * VT
    sum_85pct_times_skylight_area_times_vt_times_wf = 0
    construction_name_to_vt_map = {}
    space.surfaces.sort.each do |surface|
      next unless surface.outsideBoundaryCondition == 'Outdoors' && surface.surfaceType == 'RoofCeiling'
      surface.subSurfaces.sort.each do |sub_surface|
        next unless sub_surface.outsideBoundaryCondition == 'Outdoors' && sub_surface.subSurfaceType == 'Skylight'

        num_sub_surfaces += 1

        # Get the area
        area_m2 = sub_surface.netArea

        # Get the window construction name
        construction_name = nil
        construction = sub_surface.construction
        if construction.is_initialized
          construction_name = construction.get.name.get.upcase
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "For #{space.name}, ")
          next
        end

        # Store VT for this construction in map if not already looked up
        if construction_name_to_vt_map[construction_name].nil?

          sql = space.model.sqlFile

          if sql.is_initialized
            sql = sql.get

            row_query = "SELECT RowName
                        FROM tabulardatawithstrings
                        WHERE ReportName='EnvelopeSummary'
                        AND ReportForString='Entire Facility'
                        AND TableName='Exterior Fenestration'
                        AND Value='#{construction_name}'"

            row_id = sql.execAndReturnFirstString(row_query)

            if row_id.is_initialized
              row_id = row_id.get
            else
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Model', "Data not found for query: #{row_query}")
              next
            end

            vt_query = "SELECT Value
                        FROM tabulardatawithstrings
                        WHERE ReportName='EnvelopeSummary'
                        AND ReportForString='Entire Facility'
                        AND TableName='Exterior Fenestration'
                        AND ColumnName='Glass Visible Transmittance'
                        AND RowName='#{row_id}'"

            vt = sql.execAndReturnFirstDouble(vt_query)

            vt = if vt.is_initialized
                   vt.get
                 end

            # Record the VT
            construction_name_to_vt_map[construction_name] = vt

          else
            OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has no sql file containing results, cannot lookup data.')
          end

        end

        # Get the VT from the map
        vt = construction_name_to_vt_map[construction_name]
        if vt.nil?
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "For #{space.name}, could not determine VLT for #{construction_name}, will not be included in skylight effective aperture caluclation.")
          vt = 0
        end

        sum_85pct_times_skylight_area_times_vt_times_wf += 0.85 * area_m2 * vt * wf
      end
    end

    # Calculate the effective aperture
    if sum_85pct_times_skylight_area_times_vt_times_wf.zero?
      skylight_effective_aperture = 9999
      if num_sub_surfaces > 0
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} has no skylights where VLT could be determined, skylight effective aperture will be higher than it should.")
      end
    else
      skylight_effective_aperture = sum_85pct_times_skylight_area_times_vt_times_wf / toplighted_area
    end

    OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Space', "#{space.name} skylight effective aperture = #{skylight_effective_aperture}.")

    return skylight_effective_aperture
  end

  # Adds daylighting controls (sidelighting and toplighting) per the template
  # @note This method is super complicated because of all the polygon/geometry math required.
  #   and therefore may not return perfect results.  However, it works well in most tested
  #   situations.  When it fails, it will log warnings/errors for users to see.
  #
  # @param remove_existing_controls [Bool] if true, will remove existing controls then add new ones
  # @param draw_daylight_areas_for_debugging [Bool] If this argument is set to true,
  #   daylight areas will be added to the model as surfaces for visual debugging.
  #   Yellow = toplighted area, Red = primary sidelighted area,
  #   Blue = secondary sidelighted area, Light Blue = floor
  # @return [Hash] returns a hash of resulting areas (m^2).
  #   Hash keys are: 'toplighted_area', 'primary_sidelighted_area',
  #   'secondary_sidelighted_area', 'total_window_area', 'total_skylight_area'
  # @todo add a list of valid choices for template argument
  # @todo add exception for retail spaces
  # @todo add exception 2 for skylights with VT < 0.4
  # @todo add exception 3 for CZ 8 where lighting < 200W
  # @todo stop skipping non-vertical walls
  # @todo stop skipping non-horizontal roofs
  # @todo Determine the illuminance setpoint for the controls based on space type
  # @todo rotate sensor to face window (only needed for glare calcs)
  def space_add_daylighting_controls(space, remove_existing_controls, draw_daylight_areas_for_debugging = false)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "******For #{space.name}, adding daylight controls.")

    # Check for existing daylighting controls
    # and remove if specified in the input
    existing_daylighting_controls = space.daylightingControls
    unless existing_daylighting_controls.empty?
      if remove_existing_controls
        existing_daylighting_controls.each(&:remove)
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "For #{space.name}, removed #{existing_daylighting_controls.size} existing daylight controls before adding new controls.")
      else
        OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "For #{space.name}, daylight controls were already present, no additional controls added.")
        return false
      end
    end

    # Skip this space if it has no exterior windows or skylights
    ext_fen_area_m2 = 0
    space.surfaces.each do |surface|
      next unless surface.outsideBoundaryCondition == 'Outdoors'
      surface.subSurfaces.each do |sub_surface|
        next unless sub_surface.subSurfaceType == 'FixedWindow' || sub_surface.subSurfaceType == 'OperableWindow' || sub_surface.subSurfaceType == 'Skylight' || sub_surface.subSurfaceType == 'GlassDoor'
        ext_fen_area_m2 += sub_surface.netArea
      end
    end
    if ext_fen_area_m2.zero?
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "For #{space.name}, daylighting control not applicable because no exterior fenestration is present.")
      return false
    end

    areas = nil

    # Get the area of the space
    space_area_m2 = space.floorArea

    # Get the LPD of the space
    space_lpd_w_per_m2 = space.lightingPowerPerFloorArea

    # Get the daylighting areas
    areas = space_daylighted_areas(space, draw_daylight_areas_for_debugging)

    # Determine the type of daylighting controls required
    req_top_ctrl, req_pri_ctrl, req_sec_ctrl = space_daylighting_control_required?(space, areas)

    # Stop here if no controls are required
    if !req_top_ctrl && !req_pri_ctrl && !req_sec_ctrl
      return false
    end

    # Output the daylight control requirements
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, toplighting control required = #{req_top_ctrl}")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, primary sidelighting control required = #{req_pri_ctrl}")
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, secondary sidelighting control required = #{req_sec_ctrl}")

    # Stop here if no lighting controls are required.
    # Do not put daylighting control points into the space.
    if !req_top_ctrl && !req_pri_ctrl && !req_sec_ctrl
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, no daylighting control is required.")
      return false
    end

    # Record a floor in the space for later use
    floor_surface = nil
    space.surfaces.sort.each do |surface|
      if surface.surfaceType == 'Floor'
        floor_surface = surface
        break
      end
    end

    # Find all exterior windows/skylights in the space and record their azimuths and areas
    windows = {}
    skylights = {}
    space.surfaces.sort.each do |surface|
      next unless surface.outsideBoundaryCondition == 'Outdoors' && (surface.surfaceType == 'Wall' || surface.surfaceType == 'RoofCeiling')

      # Skip non-vertical walls and non-horizontal roofs
      straight_upward = OpenStudio::Vector3d.new(0, 0, 1)
      surface_normal = surface.outwardNormal
      if surface.surfaceType == 'Wall'
        # TODO: stop skipping non-vertical walls
        unless surface_normal.z.abs < 0.001
          unless surface.subSurfaces.empty?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Cannot currently handle non-vertical walls; skipping windows on #{surface.name} in #{space.name} for daylight sensor positioning.")
            next
          end
        end
      elsif surface.surfaceType == 'RoofCeiling'
        # TODO: stop skipping non-horizontal roofs
        unless surface_normal.to_s == straight_upward.to_s
          unless surface.subSurfaces.empty?
            OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Cannot currently handle non-horizontal roofs; skipping skylights on #{surface.name} in #{space.name} for daylight sensor positioning.")
            OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---Surface #{surface.name} has outward normal of #{surface_normal.to_s.gsub(/\[|\]/, '|')}; up is #{straight_upward.to_s.gsub(/\[|\]/, '|')}.")
            next
          end
        end
      end

      # Find the azimuth of the facade
      facade = nil
      group = surface.planarSurfaceGroup
      if group.is_initialized
        group = group.get
        site_transformation = group.buildingTransformation
        site_vertices = site_transformation * surface.vertices
        site_outward_normal = OpenStudio.getOutwardNormal(site_vertices)
        if site_outward_normal.empty?
          OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Space', "Could not compute outward normal for #{surface.name.get}")
          next
        end
        site_outward_normal = site_outward_normal.get
        north = OpenStudio::Vector3d.new(0.0, 1.0, 0.0)
        azimuth = if site_outward_normal.x < 0.0
                    360.0 - OpenStudio.radToDeg(OpenStudio.getAngle(site_outward_normal, north))
                  else
                    OpenStudio.radToDeg(OpenStudio.getAngle(site_outward_normal, north))
                  end
      else
        # The surface is not in a group; should not hit, since
        # called from Space.surfaces
        next
      end

      # TODO: modify to work for buildings in the southern hemisphere?
      if azimuth >= 315.0 || azimuth < 45.0
        facade = '4-North'
      elsif azimuth >= 45.0 && azimuth < 135.0
        facade = '3-East'
      elsif azimuth >= 135.0 && azimuth < 225.0
        facade = '1-South'
      elsif azimuth >= 225.0 && azimuth < 315.0
        facade = '2-West'
      end

      # Label the facade as "Up" if it is a skylight
      if surface_normal.to_s == straight_upward.to_s
        facade = '0-Up'
      end

      # Loop through all subsurfaces and
      surface.subSurfaces.sort.each do |sub_surface|
        next unless sub_surface.outsideBoundaryCondition == 'Outdoors' && (sub_surface.subSurfaceType == 'FixedWindow' || sub_surface.subSurfaceType == 'OperableWindow' || sub_surface.subSurfaceType == 'Skylight')

        # Find the area
        net_area_m2 = sub_surface.netArea

        # Find the head height and sill height of the window
        vertex_heights_above_floor = []
        sub_surface.vertices.each do |vertex|
          vertex_on_floorplane = floor_surface.plane.project(vertex)
          vertex_heights_above_floor << (vertex - vertex_on_floorplane).length
        end
        head_height_m = vertex_heights_above_floor.max
        # OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Space", "---head height = #{head_height_m}m, sill height = #{sill_height_m}m")

        # Log the window properties to use when creating daylight sensors
        properties = { facade: facade, area_m2: net_area_m2, handle: sub_surface.handle, head_height_m: head_height_m, name: sub_surface.name.get.to_s }
        if facade == '0-Up'
          skylights[sub_surface] = properties
        else
          windows[sub_surface] = properties
        end
      end # next sub-surface
    end # next surface

    # Determine the illuminance setpoint for the controls based on space type
    daylight_stpt_lux = 375

    # find the specific space_type properties
    space_type = space.spaceType
    if space_type.empty?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "Space #{space_type} is an unknown space type, assuming #{daylight_stpt_lux} Lux daylight setpoint")
    else
      space_type = space_type.get
      standards_building_type = if space_type.standardsBuildingType.is_initialized
                                  space_type.standardsBuildingType.get
                                end
      standards_space_type = if space_type.standardsSpaceType.is_initialized
                               space_type.standardsSpaceType.get
                             end

      # use the building type (standards_building_type) and space type (standards_space_type)
      # as well as template to locate the space type data
      search_criteria = {
        'template' => template,
        'building_type' => standards_building_type,
        'space_type' => standards_space_type
      }

      data = model_find_object(standards_data['space_types'], search_criteria)
      if data.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "No data available for #{space_type.name}: #{standards_space_type} of #{standards_building_type} at #{template}, assuming a #{daylight_stpt_lux} Lux daylight setpoint!")
      else
        # Read the illuminance setpoint value
        # If 'na', daylighting is not appropriate for this space type for some reason
        daylight_stpt_lux = data['target_illuminance_setpoint']
        if daylight_stpt_lux == 'na'
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Space', "For #{space.name}: daylighting is not appropriate for #{template} #{standards_building_type} #{standards_space_type}.")
          return true
        end
        # If a setpoint is specified, use that.  Otherwise use a default.
        daylight_stpt_lux = daylight_stpt_lux.to_f
        if daylight_stpt_lux.zero?
          daylight_stpt_lux = 375
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Space', "For #{space.name}: no specific illuminance setpoint defined for #{template} #{standards_building_type} #{standards_space_type}, assuming #{daylight_stpt_lux} Lux.")
        else
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Space', "For #{space.name}: illuminance setpoint = #{daylight_stpt_lux} Lux")
        end
        # for the office prototypes where core and perimeter zoning is used,
        # there are additional assumptions about how much of the daylit area can be used.
        if standards_building_type == 'Office' && standards_space_type.include?('WholeBuilding')
          psa_nongeo_frac = data['psa_nongeometry_fraction'].to_f
          ssa_nongeo_frac = data['ssa_nongeometry_fraction'].to_f
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Space', "For #{space.name}: assuming only #{(psa_nongeo_frac * 100).round}% of the primary sidelit area is daylightable based on typical design practice.")
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Space', "For #{space.name}: assuming only #{(ssa_nongeo_frac * 100).round}% of the secondary sidelit area is daylightable based on typical design practice.")
        end
      end
    end

    # Get the zone that the space is in
    zone = space.thermalZone
    if zone.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Space', "Space #{space.name} has no thermal zone")
    else
      zone = zone.get
    end

    # Sort by priority; first by facade, then by area,
    # then by name to ensure deterministic in case identical in other ways
    sorted_windows = windows.sort_by { |_window, vals| [vals[:facade], vals[:area], vals[:name]] }
    sorted_skylights = skylights.sort_by { |_skylight, vals| [vals[:facade], vals[:area], vals[:name]] }

    # Report out the sorted skylights for debugging
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, Skylights:")
    sorted_skylights.each do |sky, p|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---#{sky.name} #{p[:facade]}, area = #{p[:area_m2].round(2)} m^2")
    end

    # Report out the sorted windows for debugging
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, Windows:")
    sorted_windows.each do |win, p|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---#{win.name} #{p[:facade]}, area = #{p[:area_m2].round(2)} m^2")
    end

    # Determine the sensor fractions and the attached windows
    sensor_1_frac, sensor_2_frac, sensor_1_window, sensor_2_window = space_daylighting_fractions_and_windows(space,
                                                                                                             areas,
                                                                                                             sorted_windows,
                                                                                                             sorted_skylights,
                                                                                                             req_top_ctrl,
                                                                                                             req_pri_ctrl,
                                                                                                             req_sec_ctrl)

    # Further adjust the sensor controlled fraction for the three
    # office prototypes based on assumptions about geometry that is not explicitly
    # defined in the model.
    if standards_building_type == 'Office' && standards_space_type.include?('WholeBuilding')
      sensor_1_frac *= psa_nongeo_frac unless psa_nongeo_frac.nil?
      sensor_2_frac *= ssa_nongeo_frac unless ssa_nongeo_frac.nil?
    end

    # Place the sensors and set control fractions
    # get the zone that the space is in
    zone = space.thermalZone
    if zone.empty?
      OpenStudio.logFree(OpenStudio::Error, 'openstudio.model.Space', "Space #{space.name}, cannot determine daylighted areas.")
      return false
    else
      zone = space.thermalZone.get
    end

    # Ensure that total controlled fraction
    # is never set above 1 (100%)
    sensor_1_frac = sensor_1_frac.round(3)
    sensor_2_frac = sensor_2_frac.round(3)
    if sensor_1_frac >= 1.0
      sensor_1_frac = 1.0 - 0.001
    end
    if sensor_1_frac + sensor_2_frac >= 1.0
      # Lower sensor_2_frac so that the total
      # is just slightly lower than 1.0
      sensor_2_frac = 1.0 - sensor_1_frac - 0.001
    end

    # Sensors
    if sensor_1_frac > 0.0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "For #{space.name}: sensor 1 controls #{(sensor_1_frac * 100).round}% of the zone lighting.")
    end
    if sensor_2_frac > 0.0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "For #{space.name}: sensor 2 controls #{(sensor_2_frac * 100).round}% of the zone lighting.")
    end

    # First sensor
    if sensor_1_window
      # OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Space", "For #{self.name}, calculating daylighted areas.")
      # runner.registerInfo("Daylight sensor 1 inside of #{sensor_1_frac.name}")
      sensor_1 = OpenStudio::Model::DaylightingControl.new(space.model)
      sensor_1.setName("#{space.name} Daylt Sensor 1")
      sensor_1.setSpace(space)
      sensor_1.setIlluminanceSetpoint(daylight_stpt_lux)
      sensor_1.setLightingControlType('Stepped')
      sensor_1.setNumberofSteppedControlSteps(3) # all sensors 3-step per design
      sensor_1.setMinimumInputPowerFractionforContinuousDimmingControl(0.3)
      sensor_1.setMinimumLightOutputFractionforContinuousDimmingControl(0.2)
      sensor_1.setProbabilityLightingwillbeResetWhenNeededinManualSteppedControl(1.0)
      sensor_1.setMaximumAllowableDiscomfortGlareIndex(22.0)

      # Place sensor depending on skylight or window
      sensor_vertex = nil
      if sensor_1_window[1][:facade] == '0-Up'
        sub_surface = sensor_1_window[0]
        outward_normal = sub_surface.outwardNormal
        centroid = OpenStudio.getCentroid(sub_surface.vertices).get
        ht_above_flr = OpenStudio.convert(2.5, 'ft', 'm').get
        outward_normal.setLength(sensor_1_window[1][:head_height_m] - ht_above_flr)
        sensor_vertex = centroid + outward_normal.reverseVector
      else
        sub_surface = sensor_1_window[0]
        window_outward_normal = sub_surface.outwardNormal
        window_centroid = OpenStudio.getCentroid(sub_surface.vertices).get
        window_outward_normal.setLength(sensor_1_window[1][:head_height_m] * 0.66)
        vertex = window_centroid + window_outward_normal.reverseVector
        vertex_on_floorplane = floor_surface.plane.project(vertex)
        floor_outward_normal = floor_surface.outwardNormal
        floor_outward_normal.setLength(OpenStudio.convert(2.5, 'ft', 'm').get)
        sensor_vertex = vertex_on_floorplane + floor_outward_normal.reverseVector
      end
      sensor_1.setPosition(sensor_vertex)

      # TODO: rotate sensor to face window (only needed for glare calcs)
      zone.setPrimaryDaylightingControl(sensor_1)
      zone.setFractionofZoneControlledbyPrimaryDaylightingControl(sensor_1_frac)
    end

    # Second sensor
    if sensor_2_window
      # OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Space", "For #{self.name}, calculating daylighted areas.")
      # runner.registerInfo("Daylight sensor 2 inside of #{sensor_2_frac.name}")
      sensor_2 = OpenStudio::Model::DaylightingControl.new(space.model)
      sensor_2.setName("#{space.name} Daylt Sensor 2")
      sensor_2.setSpace(space)
      sensor_2.setIlluminanceSetpoint(daylight_stpt_lux)
      sensor_2.setLightingControlType('Stepped')
      sensor_2.setNumberofSteppedControlSteps(3) # all sensors 3-step per design
      sensor_2.setMinimumInputPowerFractionforContinuousDimmingControl(0.3)
      sensor_2.setMinimumLightOutputFractionforContinuousDimmingControl(0.2)
      sensor_2.setProbabilityLightingwillbeResetWhenNeededinManualSteppedControl(1.0)
      sensor_2.setMaximumAllowableDiscomfortGlareIndex(22.0)

      # Place sensor depending on skylight or window
      sensor_vertex = nil
      if sensor_2_window[1][:facade] == '0-Up'
        sub_surface = sensor_2_window[0]
        outward_normal = sub_surface.outwardNormal
        centroid = OpenStudio.getCentroid(sub_surface.vertices).get
        ht_above_flr = OpenStudio.convert(2.5, 'ft', 'm').get
        outward_normal.setLength(sensor_2_window[1][:head_height_m] - ht_above_flr)
        sensor_vertex = centroid + outward_normal.reverseVector
      else
        sub_surface = sensor_2_window[0]
        window_outward_normal = sub_surface.outwardNormal
        window_centroid = OpenStudio.getCentroid(sub_surface.vertices).get
        window_outward_normal.setLength(sensor_2_window[1][:head_height_m] * 1.33)
        vertex = window_centroid + window_outward_normal.reverseVector
        vertex_on_floorplane = floor_surface.plane.project(vertex)
        floor_outward_normal = floor_surface.outwardNormal
        floor_outward_normal.setLength(OpenStudio.convert(2.5, 'ft', 'm').get)
        sensor_vertex = vertex_on_floorplane + floor_outward_normal.reverseVector
      end
      sensor_2.setPosition(sensor_vertex)

      # TODO: rotate sensor to face window (only needed for glare calcs)
      zone.setSecondaryDaylightingControl(sensor_2)
      zone.setFractionofZoneControlledbySecondaryDaylightingControl(sensor_2_frac)
    end

    return true
  end

  # Determine if the space requires daylighting controls for
  # toplighting, primary sidelighting, and secondary sidelighting.
  # Defaults to false for all types.
  #
  # @param space [OpenStudio::Model::Space] the space in question
  # @param areas [Hash] a hash of daylighted areas
  # @return [Array<Bool>] req_top_ctrl, req_pri_ctrl, req_sec_ctrl
  def space_daylighting_control_required?(space, areas)
    req_top_ctrl = false
    req_pri_ctrl = false
    req_sec_ctrl = false

    return [req_top_ctrl, req_pri_ctrl, req_sec_ctrl]
  end

  # Determine the fraction controlled by each sensor and which
  # window each sensor should go near.
  #
  # @param space [OpenStudio::Model::Space] the space with the daylighting
  # @param sorted_windows [Hash] a hash of windows, sorted by priority
  # @param sorted_skylights [Hash] a hash of skylights, sorted by priority
  def space_daylighting_fractions_and_windows(space,
                                              areas,
                                              sorted_windows,
                                              sorted_skylights,
                                              req_top_ctrl,
                                              req_pri_ctrl,
                                              req_sec_ctrl)
    sensor_1_frac = 0.0
    sensor_2_frac = 0.0
    sensor_1_window = nil
    sensor_2_window = nil

    return [sensor_1_frac, sensor_2_frac, sensor_1_window, sensor_2_window]
  end

  # Set the infiltration rate for this space to include
  # the impact of air leakage requirements in the standard.
  #
  # @return [Double] true if successful, false if not
  # @todo handle doors and vestibules
  def space_apply_infiltration_rate(space)
    # data center keeps positive pressure all the time, so no infiltration
    if space.spaceType.is_initialized && space.spaceType.get.standardsSpaceType.is_initialized
      std_space_type = space.spaceType.get.standardsSpaceType.get
      if std_space_type.downcase.include?('data center') || std_space_type.downcase.include?('datacenter')
        return true
      end

      if space.spaceType.get.standardsBuildingType.is_initialized
        std_bldg_type = space.spaceType.get.standardsBuildingType.get
        if std_bldg_type.downcase.include?('datacenter') && std_space_type.downcase.include?('computerroom')
          return true
        end
      end
    end

    # Determine the total building baseline infiltration rate in cfm per ft2 of exterior above grade wall area at 75 Pa
    # exterior above grade envelope area includes any surface with boundary condition 'Outdoors' in OpenStudio/EnergyPlus
    basic_infil_rate_cfm_per_ft2 = space_infiltration_rate_75_pa(space)

    # Do nothing if no infiltration
    return true if basic_infil_rate_cfm_per_ft2.zero?

    # Conversion factor
    # 1 m^3/s*m^2 = 196.85 cfm/ft2
    conv_fact = 196.85

    # Adjust the infiltration rate to the average pressure for the prototype buildings.
    adj_infil_rate_cfm_per_ft2 = adjust_infiltration_to_prototype_building_conditions(basic_infil_rate_cfm_per_ft2)
    adj_infil_rate_m3_per_s_per_m2 = adj_infil_rate_cfm_per_ft2 / conv_fact
    # Get the exterior wall area
    exterior_wall_and_window_area_m2 = space_exterior_wall_and_window_area(space)

    # Don't create an object if there is no exterior wall area
    if exterior_wall_and_window_area_m2 <= 0.0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.Model', "For #{space.name}, no exterior wall area was found, no infiltration will be added.")
      return true
    end
    OpenStudio.logFree(OpenStudio::Info, 'openstudio.Standards.Model', "For #{space.name}, set infiltration rate to #{adj_infil_rate_cfm_per_ft2.round(3)} cfm/ft2 exterior wall area (aka #{basic_infil_rate_cfm_per_ft2} cfm/ft2 @75Pa).")

    # Calculate the total infiltration, assuming
    # that it only occurs through exterior walls
    tot_infil_m3_per_s = adj_infil_rate_m3_per_s_per_m2 * exterior_wall_and_window_area_m2

    # Now spread the total infiltration rate over all
    # exterior surface areas (for the E+ input field)
    all_ext_infil_m3_per_s_per_m2 = tot_infil_m3_per_s / space.exteriorArea

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Space', "For #{space.name}, adj infil = #{all_ext_infil_m3_per_s_per_m2.round(8)} m^3/s*m^2.")

    # Get any infiltration schedule already assigned to this space or its space type
    # If not, the always on schedule will be applied.
    infil_sch = nil
    unless space.spaceInfiltrationDesignFlowRates.empty?
      old_infil = space.spaceInfiltrationDesignFlowRates[0]
      if old_infil.schedule.is_initialized
        infil_sch = old_infil.schedule.get
      end
    end

    if infil_sch.nil? && space.spaceType.is_initialized
      space_type = space.spaceType.get
      unless space_type.spaceInfiltrationDesignFlowRates.empty?
        old_infil = space_type.spaceInfiltrationDesignFlowRates[0]
        if old_infil.schedule.is_initialized
          infil_sch = old_infil.schedule.get
        end
      end
    end

    if infil_sch.nil?
      infil_sch = space.model.alwaysOnDiscreteSchedule
    end

    # Create an infiltration rate object for this space
    infiltration = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(space.model)
    infiltration.setName("#{space.name} Infiltration")
    # infiltration.setFlowperExteriorWallArea(adj_infil_rate_m3_per_s_per_m2)
    infiltration.setFlowperExteriorSurfaceArea(all_ext_infil_m3_per_s_per_m2.round(13))
    infiltration.setSchedule(infil_sch)
    infiltration.setConstantTermCoefficient(0.0)
    infiltration.setTemperatureTermCoefficient 0.0
    infiltration.setVelocityTermCoefficient(0.224)
    infiltration.setVelocitySquaredTermCoefficient(0.0)

    infiltration.setSpace(space)

    return true
  end

  # Baseline infiltration rate
  #
  # @return [Double] the baseline infiltration rate, in cfm/ft^2 exterior above grade wall area at 75 Pa
  def space_infiltration_rate_75_pa(space)
    basic_infil_rate_cfm_per_ft2 = 1.8
    return basic_infil_rate_cfm_per_ft2
  end

  # Calculate the area of the exterior walls,
  # including the area of the windows on these walls.
  #
  # @return [Double] area in m^2
  def space_exterior_wall_and_window_area(space)
    area_m2 = 0.0

    # Loop through all surfaces in this space
    space.surfaces.sort.each do |surface|
      # Skip non-outdoor surfaces
      next unless surface.outsideBoundaryCondition == 'Outdoors'
      # Skip non-walls
      next unless surface.surfaceType == 'Wall'
      # This surface
      area_m2 += surface.netArea
      # Subsurfaces in this surface
      surface.subSurfaces.sort.each do |subsurface|
        area_m2 += subsurface.netArea
      end
    end

    return area_m2
  end

  # Calculate the area of the exterior walls,
  # including the area of the windows on these walls.
  #
  # @return [Double] area in m^2
  def space_exterior_wall_and_roof_and_subsurface_area(space)
    area_m2 = 0.0

    # Loop through all surfaces in this space
    space.surfaces.sort.each do |surface|
      # Skip non-outdoor surfaces
      next unless surface.outsideBoundaryCondition == 'Outdoors'
      # Skip non-walls
      next unless surface.surfaceType == 'Wall' || surface.surfaceType == 'RoofCeiling'
      # This surface
      area_m2 += surface.netArea
      # Subsurfaces in this surface
      surface.subSurfaces.sort.each do |subsurface|
        area_m2 += subsurface.netArea
      end
    end

    return area_m2
  end

  # Determine if the space is a plenum.
  # Assume it is a plenum if it is a supply
  # or return plenum for an AirLoop,
  # if it is not part of the total floor area,
  # or if the space type name contains the
  # word plenum.
  #
  # return [Bool] returns true if plenum, false if not
  def space_plenum?(space)
    plenum_status = false

    # Check if it is designated
    # as not part of the building
    # floor area.  This method internally
    # also checks to see if the space's zone
    # is a supply or return plenum
    unless space.partofTotalFloorArea
      plenum_status = true
      return plenum_status
    end

    # TODO: - update to check if it has internal loads

    # Check if the space type name
    # contains the word plenum.
    space_type = space.spaceType
    if space_type.is_initialized
      space_type = space_type.get
      if space_type.name.get.to_s.downcase.include?('plenum')
        plenum_status = true
        return plenum_status
      end
      if space_type.standardsSpaceType.is_initialized
        if space_type.standardsSpaceType.get.downcase.include?('plenum')
          plenum_status = true
          return plenum_status
        end
      end
    end

    return plenum_status
  end

  # Determine if the space is residential based on the
  # space type properties for the space.
  # For spaces with no space type, assume nonresidential.
  # For spaces that are plenums, base the decision on the space
  # type of the space below the largest floor in the plenum.
  #
  # return [Bool] true if residential, false if nonresidential
  def space_residential?(space)
    is_res = false

    space_to_check = space

    # If this space is a plenum, check the space type
    # of the space below the largest floor in the space
    if space_plenum?(space)
      # Find the largest floor
      largest_floor_area = 0.0
      largest_surface = nil
      space.surfaces.each do |surface|
        next unless surface.surfaceType == 'Floor' && surface.outsideBoundaryCondition == 'Surface'
        if surface.grossArea > largest_floor_area
          largest_floor_area = surface.grossArea
          largest_surface = surface
        end
      end
      if largest_surface.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} is a plenum, but could not find a floor with a space below it to determine if plenum should be  res or nonres.  Assuming nonresidential.")
        return is_res
      end
      # Get the space on the other side of this floor
      if largest_surface.adjacentSurface.is_initialized
        adj_surface = largest_surface.adjacentSurface.get
        if adj_surface.space.is_initialized
          space_to_check = adj_surface.space.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} is a plenum, but could not find a space attached to the largest floor's adjacent surface #{adj_surface.name} to determine if plenum should be res or nonres.  Assuming nonresidential.")
          return is_res
        end
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "#{space.name} is a plenum, but could not find a floor with a space below it to determine if plenum should be  res or nonres.  Assuming nonresidential.")
        return is_res
      end
    end

    space_type = space_to_check.spaceType
    if space_type.is_initialized
      space_type = space_type.get
      # Get the space type data
      space_type_properties = space_type_get_standards_data(space_type)
      if space_type_properties.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "Could not find space type properties for #{space_to_check.name}, assuming nonresidential.")
        is_res = false
      else
        is_res = space_type_properties['is_residential'] == 'Yes'
      end
    else
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.Space', "Could not find a space type for #{space_to_check.name}, assuming nonresidential.")
      is_res = false
    end

    return is_res
  end

  # Determines whether the space is conditioned per 90.1,
  # which is based on heating and cooling loads.
  #
  # @param climate_zone [String] climate zone
  # @return [String] NonResConditioned, ResConditioned, Semiheated, Unconditioned
  # @todo add logic to detect indirectly-conditioned spaces
  def space_conditioning_category(space, climate_zone)
    # Get the zone this space is inside
    zone = space.thermalZone

    # Assume unconditioned if not assigned to a zone
    if zone.empty?
      return 'Unconditioned'
    end

    # Get the category from the zone
    cond_cat = zone.get.conditioning_category(climate_zone)

    return cond_cat
  end

  # Determines heating status.  If the space's
  # zone has a thermostat with a maximum heating
  # setpoint above 5C (41F), counts as heated.
  #
  # @author Andrew Parker, Julien Marrec
  # @return [Bool] true if heated, false if not
  def space_heated?(space)
    # Get the zone this space is inside
    zone = space.thermalZone

    # Assume unheated if not assigned to a zone
    if zone.empty?
      return false
    end

    # Get the category from the zone
    htd = thermal_zone_heated?(zone.get)

    return htd
  end

  # Determines cooling status.  If the space's
  # zone has a thermostat with a minimum cooling
  # setpoint above 33C (91F), counts as cooled.
  #
  # @author Andrew Parker, Julien Marrec
  # @return [Bool] true if cooled, false if not
  def space_cooled?(space)
    # Get the zone this space is inside
    zone = space.thermalZone

    # Assume uncooled if not assigned to a zone
    if zone.empty?
      return false
    end

    # Get the category from the zone
    cld = thermal_zone_cooled?(zone.get)

    return cld
  end

  # Determine the design internal load (W) for
  # this space without space multipliers.
  # This include People, Lights, Electric Equipment,
  # and Gas Equipment.  It assumes 100% of the wattage
  # is converted to heat, and that the design peak
  # schedule value is 1 (100%).
  #
  # @return [Double] the design internal load, in W
  def space_design_internal_load(space)
    load_w = 0.0

    # People
    space.people.each do |people|
      w_per_person = 125 # Initial assumption
      act_sch = people.activityLevelSchedule
      if act_sch.is_initialized
        if act_sch.get.to_ScheduleRuleset.is_initialized
          act_sch = act_sch.get.to_ScheduleRuleset.get
          w_per_person = schedule_ruleset_annual_min_max_value(act_sch)['max']
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "#{space.name} people activity schedule is not a Schedule:Ruleset.  Assuming #{w_per_person}W/person.")
        end
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "#{space.name} people activity schedule not found.  Assuming #{w_per_person}W/person.")
      end

      num_ppl = people.getNumberOfPeople(space.floorArea)

      ppl_w = num_ppl * w_per_person

      load_w += ppl_w
    end

    # Lights
    load_w += space.lightingPower

    # Electric Equipment
    load_w += space.electricEquipmentPower

    # Gas Equipment
    load_w += space.gasEquipmentPower

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "#{space.name} has #{load_w.round}W of design internal loads.")

    return load_w
  end

  # will return a sorted array of array of spaces and connected area (Descending)
  def space_get_adjacent_spaces_with_shared_wall_areas(space, same_floor = true)
    same_floor_spaces = []
    spaces = []
    space.surfaces.each do |surface|
      adj_surface = surface.adjacentSurface
      unless adj_surface.empty?
        space.model.getSpaces.sort.each do |other_space|
          next if other_space == space
          other_space.surfaces.each do |surf|
            if surf == adj_surface.get
              spaces << other_space
            end
          end
        end
      end
    end
    # If looking for only spaces adjacent on the same floor.
    if same_floor == true
      raise "Cannot get adjacent spaces of space #{space.name} since space not set to BuildingStory" if space.buildingStory.empty?
      spaces.each do |other_space|
        raise "One or more adjecent spaces to space #{space.name} is not assigned to a BuildingStory. Ensure all spaces are assigned." if space.buildingStory.empty?
        if other_space.buildingStory.get == space.buildingStory.get
          same_floor_spaces << other_space
        end
      end
      spaces = same_floor_spaces
    end

    # now sort by areas.
    area_index = []
    array_hash = {}
    return nil if spaces.size.zero?
    # iterate through each surface in the space
    space.surfaces.each do |surface|
      # get the adjacent surface in another space.
      adj_surface = surface.adjacentSurface
      unless adj_surface.empty?
        # go through each of the adjeacent spaces to find the matching  surface/space.
        spaces.each_with_index do |other_space, index|
          next if other_space == space
          other_space.surfaces.each do |surf|
            if surf == adj_surface.get
              # initialize array index to zero for first time so += will work.
              area_index[index] = 0 if area_index[index].nil?
              area_index[index] += surf.grossArea
              array_hash[other_space] = area_index[index]
            end
          end
        end
      end
    end
    sorted_spaces = array_hash.sort_by { |_key, value| value }.reverse
    return sorted_spaces
  end

  # Find the space that has the most wall area touching this space.
  def space_get_adjacent_space_with_most_shared_wall_area(space, same_floor = true)
    return get_adjacent_spaces_with_touching_area(same_floor)[0][0]
  end

  # todo - add related related to space_hours_of_operation like set_space_hours_of_operation and shift_and_expand_space_hours_of_operation
  # todo - ideally these could take in a date range, array of dates and or days of week. Hold off until need is a bit more defined.

  # If the model has an hours of operation schedule set in default schedule set for building that looks valid it will
  # report hours of operation. Won't be a single set of values, will be a collection of rules
  # note Building, space, and spaceType can get hours of operation from schedule set, but not buildingStory
  #
  # @author David Goldwasser
  # @param space [Space] takes space
  # @return [Hash] start and end of hours of operation, stat date, end date, bool for each day of the week
  def space_hours_of_operation(space)

    default_sch_type = OpenStudio::Model::DefaultScheduleType.new('HoursofOperationSchedule')
    hours_of_operation = space.getDefaultSchedule(default_sch_type)
    if !hours_of_operation.is_initialized
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Hours of Operation Schedule is not set for #{space.name}.")
      return nil
    end
    hours_of_operation = hours_of_operation.get
    if !hours_of_operation.to_ScheduleRuleset.is_initialized
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Hours of Operation Schedule #{hours_of_operation.name} is not a ScheduleRuleset.")
      return nil
    end
    hours_of_operation = hours_of_operation.to_ScheduleRuleset.get
    profiles = {}

    # get indices for current schedule
    year_description = hours_of_operation.model.yearDescription.get
    year = year_description.assumedYear
    year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
    year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
    indices_vector = hours_of_operation.getActiveRuleIndices(year_start_date, year_end_date)

    # add default profile to hash
    hoo_start = nil
    hoo_end = nil
    unexpected_val = false
    times = hours_of_operation.defaultDaySchedule.times
    values = hours_of_operation.defaultDaySchedule.values
    times.each_with_index do |time,i|
      if values[i] == 0 && hoo_start.nil?
        hoo_start = time.totalHours
      elsif values[i] == 1 && hoo_end.nil?
        hoo_end = time.totalHours
      elsif values[i] != 1 && values[i] != 0
        unexpected_val = true
      end
    end

    # address schedule that is always on or always off (start and end can not both be nil unless unexpected value was found)
    if !hoo_start.nil? && hoo_end.nil?
      hoo_end = hoo_start
    elsif !hoo_end.nil? && hoo_start.nil?
      hoo_start = hoo_end
    end

    # some validation
    if times.size > 3 || unexpected_val || hoo_start.nil? || hoo_end.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "#{hours_of_operation.name} does not look like a valid hours of operation schedule for parametric schedule generation.")
      return nil
    end

    # hours of operation start and finish
    rule_hash = {}
    rule_hash[:hoo_start] = hoo_start
    rule_hash[:hoo_end] = hoo_end
    hoo_hours = nil
    if hoo_start == hoo_end
      if values.uniq == [1]
        hoo_hours = 24
      else
        hoo_hours = 0
      end
    elsif hoo_end > hoo_start
      hoo_hours = hoo_end - hoo_start
    elsif hoo_start > hoo_end
      hoo_hours = hoo_end + 24 - hoo_start
    end
    rule_hash[:hoo_hours] = hoo_hours
    days_used = []
    indices_vector.each_with_index do |profile_index,i|
      if profile_index == -1 then days_used << i+1 end
    end
    rule_hash[:days_used] = days_used
    profiles[-1] = rule_hash

    hours_of_operation.scheduleRules.reverse.each do |rule|
      # may not need date and days of week, will likely refer to specific date and get rule when applying parametricformula
      rule_hash = {}

      hoo_start = nil
      hoo_end = nil
      unexpected_val = false
      times = rule.daySchedule.times
      values = rule.daySchedule.values
      times.each_with_index do |time,i|
        if values[i] == 0 && hoo_start.nil?
          hoo_start = time.totalHours
        elsif values[i] == 1  && hoo_end.nil?
          hoo_end = time.totalHours
        elsif values[i] != 1 && values[i] != 0
          unexpected_val = true
        end
      end

      # address schedule that is always on or always off (start and end can not both be nil unless unexpected value was found)
      if !hoo_start.nil? && hoo_end.nil?
        hoo_end = hoo_start
      elsif !hoo_end.nil? && hoo_start.nil?
        hoo_start = hoo_end
      end

      # some validation
      if times.size > 3 || unexpected_val || hoo_start.nil? || hoo_end.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "#{hours_of_operation.name} does not look like a valid hours of operation schedule for parametric schedule generation.")
        return nil
      end

      # hours of operation start and finish
      rule_hash[:hoo_start] = hoo_start
      rule_hash[:hoo_end] = hoo_end
      hoo_hours = nil
      if hoo_start == hoo_end
        if values.uniq == [1]
          hoo_hours = 24
        else
          hoo_hours = 0
        end
      elsif hoo_end > hoo_start
        hoo_hours = hoo_end - hoo_start
      elsif hoo_start > hoo_end
        hoo_hours = hoo_end + 24 - hoo_start
      end
      rule_hash[:hoo_hours] = hoo_hours
      days_used = []
      indices_vector.each_with_index do |profile_index,i|
        if profile_index == rule.ruleIndex then days_used << i+1 end
      end
      rule_hash[:days_used] = days_used

=begin
      # todo - delete rule details below unless end up needing to use them
      if rule.startDate.is_initialized
        date = rule.startDate.get
        rule_hash[:start_date] = "#{date.monthOfYear.value}/#{date.dayOfMonth}"
      else
        rule_hash[:start_date] = nil
      end
      if rule.endDate.is_initialized
        date = rule.endDate.get
        rule_hash[:end_date] = "#{date.monthOfYear.value}/#{date.dayOfMonth}"
      else
        rule_hash[:end_date] = nil
      end
      rule_hash[:mon] = rule.applyMonday
      rule_hash[:tue] = rule.applyTuesday
      rule_hash[:wed] = rule.applyWednesday
      rule_hash[:thu] = rule.applyThursday
      rule_hash[:fri] = rule.applyFriday
      rule_hash[:sat] = rule.applySaturday
      rule_hash[:sun] = rule.applySunday
=end

      # update hash
      profiles[rule.ruleIndex] = rule_hash

    end

    return profiles
  end

  # If the model has an hours of operation schedule set in default schedule set for building that looks valid it will
  # report hours of operation. Won't be a single set of values, will be a collection of rules
  # this will call space_hours_of_operation on each space in array
  # loop through all days of year to make as many rules as ncessary
  # expand hours of operation. When hours of operation do not overlap for two spaces, add logic to remove all but largest gap
  #
  # @author David Goldwasser
  # @param space [Spaces] takes array of spaces
  # @return [Hash] start and end of hours of operation, stat date, end date, bool for each day of the week
  def spaces_hours_of_operation(spaces)
    hours_of_operation_array = []
    space_names = []
    spaces.each do |space|
      space_names << space.name.to_s
      hoo_hash = space_hours_of_operation(space)
      if !hoo_hash.nil?
        # OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Space', "For #{space.name}, hours of operation hash = #{hoo_hash}.")
        hours_of_operation_array << hoo_hash
      end
    end

    # todo - replace this with logic to get combined hours of operation for collection of spaces.
    # each hours_of_operation_array is hash with key for each profile.
    # each profile has hash with keys for hoo_start, hoo_end, hoo_hours, days_used
    # my goal is to compare profiles and days used across all profiles to create new entries as necessary
    # then for all days I need to extend hours of operation addressing any situations where multile occupancy gaps occur
    #
    # loop through all 365/366 days

    # OpenStudio.logFree(OpenStudio::Debug, 'openstudio.standards.Space', "Evaluating hours of operation for #{space_names.join(',')}: #{hours_of_operation_array}")

    # todo - what is this getting max of, it isn't longest hours of operation, is it the most profiles?
    hours_of_operation = hours_of_operation_array.max_by { |i| hours_of_operation_array.count(i) }

    return hours_of_operation

  end

  private

  # A series of private methods to modify polygons.  Most are
  # wrappers of native OpenStudio methods, but with
  # workarounds for known issues or limitations.

  # Check the z coordinates of a polygon
  # @api private
  def space_check_z_zero(space, polygons, name)
    fails = []
    errs = 0
    polygons.each do |polygon|
      # OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Space", "Checking z=0: #{name} => #{polygon.to_s.gsub(/\[|\]/,'|')}.")
      polygon.each do |vertex|
        # clsss << vertex.class
        unless vertex.z == 0.0
          errs += 1
          fails << vertex.z
        end
      end
    end
    # OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Space", "Checking z=0: #{name} => #{clsss.uniq.to_s.gsub(/\[|\]/,'|')}.")
    if errs > 0
      OpenStudio.logFree(OpenStudio::Info, 'openstudio.model.Space', "***FAIL*** #{space.name} z=0 failed for #{errs} vertices in #{name}; #{fails.join(', ')}.")
    end
  end

  # A method to convert an array of arrays to
  # an array of OpenStudio::Point3ds.
  # @api private
  def space_ruby_polygons_to_point3d_z_zero(space, ruby_polygons)
    # Convert the final polygons back to OpenStudio
    os_polygons = []
    ruby_polygons.each do |ruby_polygon|
      os_polygon = []
      ruby_polygon.each do |vertex|
        vertex = OpenStudio::Point3d.new(vertex[0], vertex[1], 0.0) # Set z to hard-zero instead of vertex[2]
        os_polygon << vertex
      end
      os_polygons << os_polygon
    end

    return os_polygons
  end

  # A method to zero-out the z vertex of an array of polygons
  # @api private
  def space_polygons_set_z(space, polygons, new_z)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "### #{polygons}")

    # Convert the final polygons back to OpenStudio
    new_polygons = []
    polygons.each do |polygon|
      new_polygon = []
      polygon.each do |vertex|
        new_vertex = OpenStudio::Point3d.new(vertex.x, vertex.y, new_z) # Set z to hard-zero instead of vertex[2]
        new_polygon << new_vertex
      end
      new_polygons << new_polygon
    end

    return new_polygons
  end

  # A method to returns the number of duplicate vertices in a polygon.
  # TODO does not actually wor
  # @api private
  def space_find_duplicate_vertices(space, ruby_polygon, tol = 0.001)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '***')
    duplicates = []

    combos = ruby_polygon.combination(2).to_a
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "########{combos.size}")
    combos.each do |i, j|
      i_vertex = OpenStudio::Point3d.new(i[0], i[1], i[2])
      j_vertex = OpenStudio::Point3d.new(j[0], j[1], j[2])

      distance = OpenStudio.getDistance(i_vertex, j_vertex)
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "------- #{i} to #{j} = #{distance}")
      if distance < tol
        duplicates << i
      end
    end

    return duplicates
  end

  # Subtracts one array of polygons from the next,
  # returning an array of resulting polygons.
  # @api private
  def space_a_polygons_minus_b_polygons(space, a_polygons, b_polygons, a_name, b_name)
    final_polygons_ruby = []

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "#{a_polygons.size} #{a_name} minus #{b_polygons.size} #{b_name}")

    # Don't try to subtract anything if either set is empty
    if a_polygons.size.zero?
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---#{a_name} - #{b_name}: #{a_name} contains no polygons.")
      return space_polygons_set_z(space, a_polygons, 0.0)
    elsif b_polygons.size.zero?
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---#{a_name} - #{b_name}: #{b_name} contains no polygons.")
      return space_polygons_set_z(space, a_polygons, 0.0)
    end

    # Loop through all a polygons, and for each one,
    # subtract all the b polygons.
    a_polygons.each do |a_polygon|
      # Translate the polygon to plain arrays
      a_polygon_ruby = []
      a_polygon.each do |vertex|
        a_polygon_ruby << [vertex.x, vertex.y, vertex.z]
      end

      # TODO: Skip really small polygons
      # reduced_b_polygons = []
      # b_polygons.each do |b_polygon|
      # next
      # end

      # Perform the subtraction
      a_minus_b_polygons = OpenStudio.subtract(a_polygon, b_polygons, 0.01)

      # Translate the resulting polygons to plain ruby arrays
      a_minus_b_polygons_ruby = []
      num_small_polygons = 0
      a_minus_b_polygons.each do |a_minus_b_polygon|
        # Drop any super small or zero-vertex polygons resulting from the subtraction
        area = OpenStudio.getArea(a_minus_b_polygon)
        if area.is_initialized
          if area.get < 0.5 # 5 square feet
            num_small_polygons += 1
            next
          end
        else
          num_small_polygons += 1
          next
        end

        # Translate polygon to ruby array
        a_minus_b_polygon_ruby = []
        a_minus_b_polygon.each do |vertex|
          a_minus_b_polygon_ruby << [vertex.x, vertex.y, vertex.z]
        end

        a_minus_b_polygons_ruby << a_minus_b_polygon_ruby
      end

      if num_small_polygons > 0
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---Dropped #{num_small_polygons} small or invalid polygons resulting from subtraction.")
      end

      # Remove duplicate polygons
      unique_a_minus_b_polygons_ruby = a_minus_b_polygons_ruby.uniq

      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---Remove duplicates: #{a_minus_b_polygons_ruby.size} ==> #{unique_a_minus_b_polygons_ruby.size}")

      # TODO: bug workaround?
      # If the result includes the a polygon, the a polygon
      # was unchanged; only include that polgon and throw away the other junk?/bug? polygons.
      # If the result does not include the a polygon, the a polygon was
      # split into multiple pieces.  Keep all those pieces.
      if unique_a_minus_b_polygons_ruby.include?(a_polygon_ruby)
        if unique_a_minus_b_polygons_ruby.size == 1
          final_polygons_ruby.concat([a_polygon_ruby])
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '---includes only original polygon, keeping that one')
        else
          # Remove the original polygon
          unique_a_minus_b_polygons_ruby.delete(a_polygon_ruby)
          final_polygons_ruby.concat(unique_a_minus_b_polygons_ruby)
          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '---includes the original and others; keeping all other polygons')
        end
      else
        final_polygons_ruby.concat(unique_a_minus_b_polygons_ruby)
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '---does not include original, keeping all resulting polygons')
      end
    end

    # Remove duplicate polygons again
    unique_final_polygons_ruby = final_polygons_ruby.uniq

    # TODO: remove this workaround
    # Split any polygons that are joined by a line into two separate
    # polygons.  Do this by finding duplicate
    # unique_final_polygons_ruby.each do |unique_final_polygon_ruby|
    # next if unique_final_polygon_ruby.size == 4 # Don't check 4-sided polygons
    # dupes = space_find_duplicate_vertices(space, unique_final_polygon_ruby)
    # if dupes.size > 0
    # OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Space", "---Two polygons attached by line = #{unique_final_polygon_ruby.to_s.gsub(/\[|\]/,'|')}")
    # end
    # end

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---Remove final duplicates: #{final_polygons_ruby.size} ==> #{unique_final_polygons_ruby.size}")

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---#{a_name} minus #{b_name} = #{unique_final_polygons_ruby.size} polygons.")

    # Convert the final polygons back to OpenStudio
    unique_final_polygons = space_ruby_polygons_to_point3d_z_zero(space, unique_final_polygons_ruby)

    return unique_final_polygons
  end

  # Wrapper to catch errors in joinAll method
  # [utilities.geometry.joinAll] <1> Expected polygons to join together
  # @api private
  def space_join_polygons(space, polygons, tol, name)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "Joining #{name} from #{space.name}")

    combined_polygons = []

    # Don't try to combine an empty array of polygons
    if polygons.size.zero?
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---#{name} contains no polygons, not combining.")
      return combined_polygons
    end

    # Open a log
    msg_log = OpenStudio::StringStreamLogSink.new
    msg_log.setLogLevel(OpenStudio::Info)

    # Combine the polygons
    combined_polygons = OpenStudio.joinAll(polygons, 0.01)

    # Count logged errors
    join_errs = 0
    inner_loop_errs = 0
    msg_log.logMessages.each do |msg|
      if /utilities.geometry/ =~ msg.logChannel
        if msg.logMessage.include?('Expected polygons to join together')
          join_errs += 1
        elsif msg.logMessage.include?('Union has inner loops')
          inner_loop_errs += 1
        end
      end
    end

    # Disable the log sink to prevent memory hogging
    msg_log.disable

    # TODO: remove this workaround, which is tried if there
    # are any join errors.  This handles the case of polygons
    # that make an inner loop, the most common case being
    # when all 4 sides of a space have windows.
    # If an error occurs, attempt to join n-1 polygons,
    # then subtract the
    if join_errs > 0 || inner_loop_errs > 0

      # Open a log
      msg_log_2 = OpenStudio::StringStreamLogSink.new
      msg_log_2.setLogLevel(OpenStudio::Info)

      first_polygon = polygons.first
      polygons = polygons.drop(1)

      combined_polygons_2 = OpenStudio.joinAll(polygons, 0.01)

      join_errs_2 = 0
      inner_loop_errs_2 = 0
      msg_log_2.logMessages.each do |msg|
        if /utilities.geometry/ =~ msg.logChannel
          if msg.logMessage.include?('Expected polygons to join together')
            join_errs_2 += 1
          elsif msg.logMessage.include?('Union has inner loops')
            inner_loop_errs_2 += 1
          end
        end
      end

      # Disable the log sink to prevent memory hogging
      msg_log_2.disable

      if join_errs_2 > 0 || inner_loop_errs_2 > 0
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, the workaround for joining polygons failed.")
      else

        # First polygon minus the already combined polygons
        first_polygon_minus_combined = space_a_polygons_minus_b_polygons(space, [first_polygon], combined_polygons_2, 'first_polygon', 'combined_polygons_2')

        # Add the result back
        combined_polygons_2 += first_polygon_minus_combined
        combined_polygons = combined_polygons_2
        join_errs = 0
        inner_loop_errs = 0

      end
    end

    # Report logged errors to user
    if join_errs > 0
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, #{join_errs} of #{polygons.size} #{space.name} were not joined properly due to limitations of the geometry calculation methods.  The resulting daylighted areas will be smaller than they should be.")
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "For #{space.name}, the #{name.gsub('_polygons', '')} daylight area calculations hit limitations.  Double-check and possibly correct the fraction of lights controlled by each daylight sensor.")
    end
    if inner_loop_errs > 0
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "For #{space.name}, #{inner_loop_errs} of #{polygons.size} #{space.name} were not joined properly becasue the joined polygons have an internal hole.  The resulting daylighted areas will be smaller than they should be.")
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "For #{space.name}, the #{name.gsub('_polygons', '')} daylight area calculations hit limitations.  Double-check and possibly correct the fraction of lights controlled by each daylight sensor.")
    end

    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---Joined #{polygons.size} #{space.name} into #{combined_polygons.size} polygons.")

    return combined_polygons
  end

  # Gets the total area of a series of polygons
  # @api private
  def space_total_area_of_polygons(space, polygons)
    total_area_m2 = 0
    polygons.each do |polygon|
      area_m2 = OpenStudio.getArea(polygon)
      if area_m2.is_initialized
        total_area_m2 += area_m2.get
      else
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Could not get area for a polygon in #{space.name}, daylighted area calculation will not be accurate.")
      end
    end

    return total_area_m2
  end

  # Returns an array of resulting polygons.
  # Assumes that a_polygons don't overlap one another, and that b_polygons don't overlap one another
  # @api private
  def space_area_a_polygons_overlap_b_polygons(space, a_polygons, b_polygons, a_name, b_name)
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "#{a_polygons.size} #{a_name} overlaps #{b_polygons.size} #{b_name}")

    overlap_area = 0

    # Don't try anything if either set is empty
    if a_polygons.size.zero?
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---#{a_name} overlaps #{b_name}: #{a_name} contains no polygons.")
      return overlap_area
    elsif b_polygons.size.zero?
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "---#{a_name} overlaps #{b_name}: #{b_name} contains no polygons.")
      return overlap_area
    end

    # Loop through each base surface
    b_polygons.each do |b_polygon|
      # OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Space", "---b polygon = #{b_polygon_ruby.to_s.gsub(/\[|\]/,'|')}")

      # Loop through each overlap surface and determine if it overlaps this base surface
      a_polygons.each do |a_polygon|
        # OpenStudio::logFree(OpenStudio::Info, "openstudio.model.Space", "------a polygon = #{a_polygon_ruby.to_s.gsub(/\[|\]/,'|')}")

        # If the entire a polygon is within the b polygon, count 100% of the area
        # as overlapping and remove a polygon from the list
        if OpenStudio.within(a_polygon, b_polygon, 0.01)

          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '---------a overlaps b ENTIRELY.')

          area = OpenStudio.getArea(a_polygon)
          if area.is_initialized
            overlap_area += area.get
            next
          else
            OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "Could not determine the area of #{a_polygon.to_s.gsub(/\[|\]/, '|')} in #{a_name}; #{a_name} overlaps #{b_name}.")
          end

          # If part of a polygon overlaps b polygon, determine the
          # original area of polygon b, subtract polygon a from b,
          # then add the difference in area to the total.
        elsif OpenStudio.intersects(a_polygon, b_polygon, 0.01)

          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '---------a overlaps b PARTIALLY.')

          # Get the initial area
          area_initial = 0
          area = OpenStudio.getArea(b_polygon)
          if area.is_initialized
            area_initial = area.get
          else
            OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "Could not determine the area of #{a_polygon.to_s.gsub(/\[|\]/, '|')} in #{a_name}; #{a_name} overlaps #{b_name}.")
          end

          # Perform the subtraction
          b_minus_a_polygons = OpenStudio.subtract(b_polygon, [a_polygon], 0.01)

          # Get the final area
          area_final = 0
          b_minus_a_polygons.each do |polygon|
            # Skip polygons that have no vertices
            # resulting from the subtraction.
            if polygon.size.zero?
              OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', "Zero-vertex polygon resulting from #{b_polygon.to_s.gsub(/\[|\]/, '|')} minus #{a_polygon.to_s.gsub(/\[|\]/, '|')}.")
              next
            end
            # Find the area of real polygons
            area = OpenStudio.getArea(polygon)
            if area.is_initialized
              area_final += area.get
            else
              OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Could not determine the area of #{polygon.to_s.gsub(/\[|\]/, '|')} in #{a_name}; #{a_name} overlaps #{b_name}.")
            end
          end

          # Add the diference to the total
          overlap_area += (area_initial - area_final)

          # There is no overlap
        else

          OpenStudio.logFree(OpenStudio::Debug, 'openstudio.model.Space', '---------a does not overlaps b at all.')

        end
      end
    end

    return overlap_area
  end
end

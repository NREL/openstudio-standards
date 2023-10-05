# Methods to get information about model geometry
# Many of these methods may be moved to core OpenStudio
module OpenstudioStandards
  module Geometry
    # @!group Information

    # calculate aspect ratio from area and perimeter
    #
    # @param area [Double] area
    # @param perimeter [Double] perimeter
    # @return [Double] aspect ratio
    def self.aspect_ratio(area, perimeter)
      length = 0.25 * (perimeter + Math.sqrt(perimeter**2 - 16 * area))
      width = 0.25 * (perimeter - Math.sqrt(perimeter**2 - 16 * area))
      aspect_ratio = length / width

      return aspect_ratio
    end

    # @!endgroup Information

    # @!group Information:Surfaces

    # return an array of z values for surfaces passed in. The values will be relative to the parent origin.
    #
    # @param surfaces [Array<OpenStudio::Model::Surface>] array of Surface objects
    # @return [Array<Double>] array of z values in meters
    def self.surfaces_get_z_values(surfaces)
      z_values = []

      # loop over all surfaces
      surfaces.each do |surface|
        # get the existing vertices
        vertices = surface.vertices
        vertices.each do |vertex|
          # push z value to array
          z_values << vertex.z
        end
      end

      return z_values
    end

    # Check if a point is contained on any surface in an array of surfaces
    #
    # @param surfaces [Array<OpenStudio::Model::Surface>] array of Surface objects
    # @param point [OpenStudio::Point3d] Point3d object
    # @return [Boolean] true if on a surface in surface array, false if not
    def self.surfaces_contain_point?(surfaces, point)
      on_surface = false

      surfaces.each do |surface|
        # Check if sensor is on floor plane (I need to loop through all floors)
        plane = surface.plane
        point_on_plane = plane.project(point)

        face_transform = OpenStudio::Transformation.alignFace(surface.vertices)
        face_vertices = face_transform * surface.vertices
        face_point_on_plane = face_transform * point_on_plane

        if OpenStudio.pointInPolygon(face_point_on_plane, face_vertices.reverse, 0.01)
          # initial_sensor location lands in this surface's polygon
          on_surface = true
        end
      end

      return on_surface
    end

    # @!endgroup Information:Surfaces

    # @!group Information:Space

    # @!endgroup Information:Space

    # @!group Information:Spaces

    # Get the total floor area of selected spaces
    #
    # @param spaces [Array<OpenStudio::Model::Space>] array of Space objects
    # @param multiplier [Boolean] account for space multiplier, defaults to true
    # @return [Double] total floor area of spaces in square meters
    def self.spaces_get_floor_area(spaces, multiplier: true)
      total_area = 0.0
      spaces.each do |space|
        space_multiplier = multiplier ? space.multiplier : 1.0
        total_area += space.floorArea * space_multiplier
      end
      return total_area
    end

    # Get the total exterior area of selected spaces
    #
    # @param spaces [Array<OpenStudio::Model::Space>] array of Space objects
    # @param multiplier [Boolean] account for space multiplier, defaults to true
    # @return [Double] total exterior area of spaces in square meters
    def self.spaces_get_exterior_area(spaces, multiplier: true)
      total_area = 0.0
      spaces.each do |space|
        space_multiplier = multiplier ? space.multiplier : 1.0
        total_area += space.exteriorArea * space_multiplier
      end
      return total_area
    end

    # Get the total exterior wall area of selected spaces
    #
    # @param spaces [Array<OpenStudio::Model::Space>] array of Space objects
    # @param multiplier [Boolean] account for space multiplier, defaults to true
    # @return [Double] total exterior wall area of spaces in square meters
    def self.spaces_get_exterior_wall_area(spaces, multiplier: true)
      total_area = 0.0
      spaces.each do |space|
        space_multiplier = multiplier ? space.multiplier : 1.0
        total_area += space.exteriorWallArea * space_multiplier
      end
      return total_area
    end

    # @!endgroup Information:Spaces

    # @!group Information:Story

    # Calculate the story exterior wall perimeter. Selected story should have above grade walls. If not perimeter may return zero.
    #
    # @param story [OpenStudio::Model::BuildingStory]
    # @param multiplier_adjustment [Double] Adjust the calculated perimeter to account for zone multipliers. The value represents the story_multiplier which reduces the adjustment by that factor over the full zone multiplier.
    # @param exterior_boundary_conditions [Array<String>] Array of strings of exterior boundary conditions.
    #   Defaults to ['Outdoors', 'Ground'].
    # @param bounding_box [OpenStudio::BoundingBox] bounding box to determine which spaces are included
    # @todo this doesn't catch walls that are split that sit above floor surfaces that are not (e.g. main corridoor in secondary school model)
    # @todo also odd with multi-height spaces
    def self.story_get_exterior_wall_perimeter(story,
                                               multiplier_adjustment: nil,
                                               exterior_boundary_conditions: ['Outdoors', 'Ground'],
                                               bounding_box: nil)
      perimeter = 0
      party_walls = []
      story.spaces.each do |space|
        # counter to use later
        edge_hash = {}
        edge_counter = 0
        space.surfaces.each do |surface|
          # get vertices
          vertex_hash = {}
          vertex_counter = 0
          surface.vertices.each do |vertex|
            vertex_counter += 1
            vertex_hash[vertex_counter] = [vertex.x, vertex.y, vertex.z]
          end
          # make edges
          counter = 0
          vertex_hash.each do |k, v|
            edge_counter += 1
            counter += 1
            if vertex_hash.size != counter
              edge_hash[edge_counter] = [v, vertex_hash[counter + 1], surface, surface.outsideBoundaryCondition, surface.surfaceType]
            else # different code for wrap around vertex
              edge_hash[edge_counter] = [v, vertex_hash[1], surface, surface.outsideBoundaryCondition, surface.surfaceType]
            end
          end
        end

        # check edges for matches (need opposite vertices and proper boundary conditions)
        edge_hash.each do |k1, v1|
          # apply to any floor boundary condition. This supports used in floors above basements
          next if v1[4] != 'Floor'

          edge_hash.each do |k2, v2|
            test_boundary_cond = false
            next if !exterior_boundary_conditions.include?(v2[3]) # method arg takes multiple conditions
            next if v2[4] != 'Wall'

            # see if edges have same geometry

            # found cases where the two lines below removed edges and resulted in lower than actual perimeter. Added new code with tolerance.
            # next if not v1[0] == v2[1] # next if not same geometry reversed
            # next if not v1[1] == v2[0]

            # these are three item array's add in tollerance for each array entry
            tolerance = 0.0001
            test_a = true
            test_b = true
            3.times.each do |i|
              if (v1[0][i] - v2[1][i]).abs > tolerance
                test_a = false
              end
              if (v1[1][i] - v2[0][i]).abs > tolerance
                test_b = false
              end
            end

            next if test_a != true
            next if test_b != true

            # edge_bounding_box = OpenStudio::BoundingBox.new
            # edge_bounding_box.addPoints(space.transformation() * v2[2].vertices)
            # if not edge_bounding_box.intersects(bounding_box) doesn't seem to work reliably, writing custom code to check

            point_one = OpenStudio::Point3d.new(v2[0][0], v2[0][1], v2[0][2])
            point_one = (space.transformation * point_one)
            point_two = OpenStudio::Point3d.new(v2[1][0], v2[1][1], v2[1][2])
            point_two = (space.transformation * point_two)

            if !bounding_box.nil? && (v2[3] == 'Adiabatic')

              on_bounding_box = false
              if ((bounding_box.minX.to_f - point_one.x).abs < tolerance) && ((bounding_box.minX.to_f - point_two.x).abs < tolerance)
                on_bounding_box = true
              elsif ((bounding_box.maxX.to_f - point_one.x).abs < tolerance) && ((bounding_box.maxX.to_f - point_two.x).abs < tolerance)
                on_bounding_box = true
              elsif ((bounding_box.minY.to_f - point_one.y).abs < tolerance) && ((bounding_box.minY.to_f - point_two.y).abs < tolerance)
                on_bounding_box = true
              elsif ((bounding_box.maxY.to_f - point_one.y).abs < tolerance) && ((bounding_box.maxY.to_f - point_two.y).abs < tolerance)
                on_bounding_box = true
              end

              # if not edge_bounding_box.intersects(bounding_box) doesn't seem to work reliably, writing custom code to check
              # todo - this is basic check for adiabatic party walls and won't catch all situations. Can be made more robust in the future
              if on_bounding_box == true
                length = OpenStudio::Vector3d.new(point_one - point_two).length
                party_walls << v2[2]
                length_ip_display = OpenStudio.convert(length, 'm', 'ft').get.round(2)
                OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Geometry.Create', " * #{v2[2].name} has an adiabatic boundary condition and sits in plane with the building bounding box. Adding #{length_ip_display} (ft) to perimeter length of #{story.name} for this surface, assuming it is a party wall.")
              elsif space.multiplier == 1
                length = OpenStudio::Vector3d.new(point_one - point_two).length
                party_walls << v2[2]
                length_ip_display = OpenStudio.convert(length, 'm', 'ft').get.round(2)
                OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.Geometry.Create', " * #{v2[2].name} has an adiabatic boundary condition and is in a zone with a multiplier of 1. Adding #{length_ip_display} (ft) to perimeter length of #{story.name} for this surface, assuming it is a party wall.")
              else
                length = 0
              end

            else
              length = OpenStudio::Vector3d.new(point_one - point_two).length
            end

            if multiplier_adjustment.nil?
              perimeter += length
            else
              # adjust for multiplier
              non_story_multiplier = space.multiplier / multiplier_adjustment.to_f
              perimeter += length * non_story_multiplier
            end
          end
        end
      end

      return { perimeter: perimeter, party_walls: party_walls }
    end

    # @!endgroup Information:Story

    # @!group Information:Model

    # Returns the window to wall ratio
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param spaces [Array<OpenStudio::Model::Space>] optional array of Space objects.
    #   If provided, the return will report for only those spaces.
    # @return [Double] window to wall ratio
    def self.model_get_exterior_window_to_wall_ratio(model, spaces: [])
      # counters
      total_gross_ext_wall_area = 0
      total_ext_window_area = 0

      if spaces.empty?
        spaces = model.getSpaces
      end

      spaces.each do |space|
        # get surface area adjusting for zone multiplier
        zone = space.thermalZone
        if !zone.empty?
          zone_multiplier = zone.get.multiplier
          if zone_multiplier > 1
          end
        else
          zone_multiplier = 1 # space is not in a thermal zone
        end

        space.surfaces.each do |s|
          next if s.surfaceType != 'Wall'
          next if s.outsideBoundaryCondition != 'Outdoors'

          surface_gross_area = s.grossArea * zone_multiplier

          # loop through sub surfaces and add area including multiplier
          ext_window_area = 0
          s.subSurfaces.each do |sub_surface|
            ext_window_area += sub_surface.grossArea * sub_surface.multiplier * zone_multiplier
          end

          total_gross_ext_wall_area += surface_gross_area
          total_ext_window_area += ext_window_area
        end
      end

      if total_gross_ext_wall_area > 0
        result = total_ext_window_area / total_gross_ext_wall_area
      else
        result = 0.0
      end

      return result
    end

    # Returns the wall area and window area by orientation
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @param spaces [Array<OpenStudio::Model::Space>] optional array of Space objects.
    #   If provided, the return will report for only those spaces.
    # @return [Hash] Hash of wall area in square meters and window to wall ratio for each orientation
    def self.model_get_exterior_window_and_wall_area_by_orientation(model, spaces: [])
      # counters
      total_gross_ext_wall_area_north = 0.0
      total_gross_ext_wall_area_south = 0.0
      total_gross_ext_wall_area_east = 0.0
      total_gross_ext_wall_area_west = 0.0
      total_ext_window_area_north = 0.0
      total_ext_window_area_south = 0.0
      total_ext_window_area_east = 0.0
      total_ext_window_area_west = 0.0

      if spaces.empty?
        spaces = model.getSpaces
      end

      spaces.each do |space|
        # get surface area adjusting for zone multiplier
        zone = space.thermalZone
        if !zone.empty?
          zone_multiplier = zone.get.multiplier
          if zone_multiplier > 1
          end
        else
          zone_multiplier = 1 # space is not in a thermal zone
        end

        space.surfaces.each do |s|
          next if s.surfaceType != 'Wall'
          next if s.outsideBoundaryCondition != 'Outdoors'

          surface_gross_area = s.grossArea * zone_multiplier

          # loop through sub surfaces and add area including multiplier
          ext_window_area = 0
          s.subSurfaces.each do |sub_surface|
            ext_window_area += sub_surface.grossArea * sub_surface.multiplier * zone_multiplier
          end

          absolute_azimuth = OpenStudio.convert(s.azimuth, 'rad', 'deg').get + s.space.get.directionofRelativeNorth + model.getBuilding.northAxis
          absolute_azimuth -= 360.0 until absolute_azimuth < 360.0

          # add to exterior wall counter if north or south
          if (absolute_azimuth >= 45.0) && (absolute_azimuth < 125.0)
            # east exterior walls
            total_gross_ext_wall_area_east += surface_gross_area
            total_ext_window_area_east += ext_window_area
          elsif (absolute_azimuth >= 125.0) && (absolute_azimuth < 225.0)
            # south exterior walls
            total_gross_ext_wall_area_south += surface_gross_area
            total_ext_window_area_south += ext_window_area
          elsif (absolute_azimuth >= 225.0) && (absolute_azimuth < 315.0)
            # west exterior walls
            total_gross_ext_wall_area_west += surface_gross_area
            total_ext_window_area_west += ext_window_area
          else
            # north exterior walls
            total_gross_ext_wall_area_north += surface_gross_area
            total_ext_window_area_north += ext_window_area
          end
        end
      end

      result = { 'north_wall' => total_gross_ext_wall_area_north,
                 'north_window' => total_ext_window_area_north,
                 'south_wall' => total_gross_ext_wall_area_south,
                 'south_window' => total_ext_window_area_south,
                 'east_wall' => total_gross_ext_wall_area_east,
                 'east_window' => total_ext_window_area_east,
                 'west_wall' => total_gross_ext_wall_area_west,
                 'west_window' => total_ext_window_area_west }
      return result
    end

    # Calculates the exterior perimeter length, checking checks for edges shared by a ground exposed floor and exterior exposed wall.
    #
    # @param model [OpenStudio::Model::Model] OpenStudio model object
    # @return [Double] perimeter length in meters
    # @todo this doesn't catch walls that are split that sit above floor surfaces that are not (e.g. main corridoor in secondary school model)
    # @todo also odd with multi-height spaces
    def self.model_get_perimeter_length(model)
      perimeter = 0.0
      model.getSpaces.sort.each do |space|
        # counter to use later
        edge_hash = {}
        edge_counter = 0
        space.surfaces.sort.each do |surface|
          # get vertices
          vertex_hash = {}
          vertex_counter = 0
          surface.vertices.each do |vertex|
            vertex_counter += 1
            vertex_hash[vertex_counter] = [vertex.x, vertex.y, vertex.z]
          end
          # make edges
          counter = 0
          vertex_hash.each do |k, v|
            edge_counter += 1
            counter += 1
            if vertex_hash.size != counter
              edge_hash[edge_counter] = [v, vertex_hash[counter + 1], surface, surface.outsideBoundaryCondition, surface.surfaceType]
            else # different code for wrap around vertex
              edge_hash[edge_counter] = [v, vertex_hash[1], surface, surface.outsideBoundaryCondition, surface.surfaceType]
            end
          end
        end

        # check edges for matches (need opposite vertices and proper boundary conditions)
        edge_hash.each do |k1, v1|
          next if v1[3] != 'Ground' # skip if not ground exposed floor
          next if v1[4] != 'Floor'

          edge_hash.each do |k2, v2|
            next if v2[3] != 'Outdoors' # skip if not exterior exposed wall (todo - update to handle basement)
            next if v2[4] != 'Wall'

            # see if edges have same geometry
            # found cases where the two lines below removed edges and resulted in lower than actual perimeter. Added new code with tolerance.
            # next if not v1[0] == v2[1] # next if not same geometry reversed
            # next if not v1[1] == v2[0]

            # these are three item array's add in tollerance for each array entry
            tolerance = 0.0001
            test_a = true
            test_b = true
            3.times.each do |i|
              if (v1[0][i] - v2[1][i]).abs > tolerance
                test_a = false
              end
              if (v1[1][i] - v2[0][i]).abs > tolerance
                test_b = false
              end
            end

            next if test_a != true
            next if test_b != true

            point_one = OpenStudio::Point3d.new(v1[0][0], v1[0][1], v1[0][2])
            point_two = OpenStudio::Point3d.new(v1[1][0], v1[1][1], v1[1][2])
            length = OpenStudio::Vector3d.new(point_one - point_two).length
            perimeter += length
          end
        end
      end

      return perimeter
    end

    # @!endgroup Information:Model
  end
end

require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'

class YourTestName_Test < Minitest::Test

  def test_what_are_you_testing()

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_daylight_sensor')
    @expected_results_file = File.join(__dir__, '../expected_results/daylighting_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/daylighting_test_results.json')
    @sizing_run_dir = File.join(@output_folder, 'sizing_folder')

    # Initial test condition
    @test_passed = true

    #Range of test options.
    @templates = [
        'NECB2011',
        'NECB2015',
        'NECB2017'
    ]
    @building_types = [
        # 'FullServiceRestaurant',
        # 'HighriseApartment',
        'Hospital',
        # 'LargeHotel',
        'LargeOffice',
        # 'MediumOffice',
        # 'MidriseApartment',
        'Outpatient',
        # 'PrimarySchool',
        # 'QuickServiceRestaurant',
        # 'RetailStandalone',
        # 'SecondarySchool',
        # 'SmallHotel',
        'Warehouse'
    ]
    @epw_files = ['CAN_AB_Banff.CS.711220_CWEC2016.epw']
    @primary_heating_fuels = ['DefaultFuel']
    @dcv_types = ['No DCV']
    @lighting_types = ['NECB_Default'] #LED  #NECB_Default

    # Test results storage array.
    @test_results_array = []

    @templates.sort.each do |template|
      @epw_files.sort.each do |epw_file|
        @building_types.sort.each do |building_type|
          @primary_heating_fuels.sort.each do |primary_heating_fuel|
            @dcv_types.sort.each do |dcv_type|
              @lighting_types.sort.each do |lighting_type|

                result = {}
                result['template'] = template
                result['epw_file'] = epw_file
                result['building_type'] = building_type
                result['primary_heating_fuel'] = primary_heating_fuel
                result['dcv_type'] = dcv_type

                # make an empty model
                model = OpenStudio::Model::Model.new
                #set up basic model.
                standard = Standard.build(template)

                #loads osm geometry and spactypes from library.
                model = standard.load_building_type_from_library(building_type: building_type)

                # this runs the step in the model. You can remove steps after what'FullServiceRestaurant', you want to test if you wish to make the test run faster.
                standard.apply_weather_data(model: model, epw_file: epw_file)
                standard.apply_loads(model: model, lights_type: lighting_type, lights_scale: 1.0)
                standard.apply_envelope(model: model)
                standard.apply_fdwr_srr_daylighting(model: model)
                standard.model_add_daylighting_controls(model)

                # # comment out for regular tests
                # BTAP::FileIO.save_osm(model, File.join(@output_folder,"#{template}-#{building_type}-daylighting-sensor-control.osm"))
                # puts File.join(@output_folder,"#{template}-#{building_type}-daylighting-sensor-control.osm")

                ##### gather daylighting sensor controls once this measure is applied to the model

                ##### Find spaces with exterior fenestration including fixed window, operable window, and skylight.
                daylight_spaces = []
                model.getSpaces.sort.each do |space|
                  space.surfaces.sort.each do |surface|
                    surface.subSurfaces.sort.each do |subsurface|
                      if subsurface.outsideBoundaryCondition == "Outdoors" &&
                          (subsurface.subSurfaceType == "FixedWindow" ||
                              subsurface.subSurfaceType == "OperableWindow" ||
                              subsurface.subSurfaceType == "Skylight")
                        daylight_spaces << space
                      end #subsurface.outsideBoundaryCondition == "Outdoors" && (subsurface.subSurfaceType == "FixedWindow" || "OperableWindow")
                    end #surface.subSurfaces.each do |subsurface|
                  end #space.surfaces.each do |surface|
                end #model.getSpaces.each do |space|

                ##### Remove duplicate spaces from the "daylight_spaces" array, as a daylighted space may have various fenestration types.
                daylight_spaces = daylight_spaces.uniq

                ##### Create hashes for "Primary Sidelighted Areas", "Sidelighting Effective Aperture", "Daylighted Area Under Skylights",
                ##### and "Skylight Effective Aperture" for the whole model.
                ##### Each of these hashes will be used later in this function (i.e. model_add_daylighting_controls)
                ##### to provide a dictionary of daylighted space names and the associated value (i.e. daylighted area or effective aperture).
                primary_sidelighted_area_hash = {}
                sidelighting_effective_aperture_hash = {}
                daylighted_area_under_skylights_hash = {}
                skylight_effective_aperture_hash = {}

                ##### Calculate "Primary Sidelighted Areas" AND "Sidelighting Effective Aperture" as per NECB2011. #TODO: consider removing overlapped sidelighted area
                daylight_spaces.sort.each do |daylight_space|
                  primary_sidelighted_area = 0.0
                  area_weighted_vt_handle = 0.0
                  area_weighted_vt = 0.0
                  window_area_sum = 0.0

                  ##### Calculate floor area of the daylight_space and get floor vertices of the daylight_space (to be used for the calculation of daylight_space depth)
                  floor_surface = nil
                  floor_area = []
                  floor_vertices = []
                  daylight_space.surfaces.sort.each do |surface|
                    if surface.surfaceType == "Floor"
                      floor_surface = surface
                      floor_area << surface.netArea
                      floor_vertices << surface.vertices
                    end
                  end

                  ##### Loop through the surfaces of each daylight_space to calculate primary_sidelighted_area and
                  ##### area-weighted visible transmittance and window_area_sum which are used to calculate sidelighting_effective_aperture
                  daylight_space.surfaces.sort.each do |surface|

                    ##### Get the vertices of each exterior wall of the daylight_space on the floor
                    ##### (these vertices will be used to calculate daylight_space depth in relation to the exterior wall, and
                    ##### the distance of the window to vertical walls on each side of the window)
                    if surface.outsideBoundaryCondition == "Outdoors" && surface.surfaceType == "Wall"
                      wall_vertices_x_on_floor = []
                      wall_vertices_y_on_floor = []
                      surface_z_min = [surface.vertices[0].z, surface.vertices[1].z, surface.vertices[2].z, surface.vertices[3].z].min
                      surface.vertices.each do |vertex|
                        if vertex.z == surface_z_min && surface_z_min == floor_vertices[0][0].z
                          wall_vertices_x_on_floor << vertex.x
                          wall_vertices_y_on_floor << vertex.y
                        end
                      end
                    end

                    if surface.outsideBoundaryCondition == "Outdoors" && surface.surfaceType == "Wall" && surface_z_min == floor_vertices[0][0].z

                      ##### Calculate the daylight_space depth in relation to the considered exterior wall.
                      ##### To calculate daylight_space depth, first get the floor vertices which are on the opposite side of the considered exterior wall.
                      floor_vertices_x_wall_opposite = []
                      floor_vertices_y_wall_opposite = []
                      floor_vertices[0].each do |floor_vertex|
                        if (floor_vertex.x != wall_vertices_x_on_floor[0] && floor_vertex.y != wall_vertices_y_on_floor[0]) || (floor_vertex.x != wall_vertices_x_on_floor[1] && floor_vertex.y != wall_vertices_y_on_floor[1])
                          floor_vertices_x_wall_opposite << floor_vertex.x
                          floor_vertices_y_wall_opposite << floor_vertex.y
                        end
                      end

                      ##### To calculate daylight_space depth, second calculate floor length on both sides: (1) exterior wall side, (2) on the opposite side of the exterior wall
                      floor_width_wall_side = Math.sqrt((wall_vertices_x_on_floor[0] - wall_vertices_x_on_floor[1]) ** 2 + (wall_vertices_y_on_floor[0] - wall_vertices_y_on_floor[1]) ** 2)
                      floor_width_wall_opposite = Math.sqrt((floor_vertices_x_wall_opposite[0] - floor_vertices_x_wall_opposite[1]) ** 2 + (floor_vertices_y_wall_opposite[0] - floor_vertices_y_wall_opposite[1]) ** 2)

                      ##### Now, daylight_space depth can be calculated using the floor area and two lengths of the floor (note that these two lengths are in parallel to each other).
                      daylight_space_depth = 2 * floor_area[0] / (floor_width_wall_side + floor_width_wall_opposite)

                      ##### Loop through the windows (including fixed and operable ones) to get window specification (width, height, area, visible transmittance (VT)), and area-weighted VT
                      surface.subSurfaces.sort.each do |subsurface|
                        if subsurface.subSurfaceType == "FixedWindow" || subsurface.subSurfaceType == "OperableWindow"
                          window_vt = subsurface.visibleTransmittance
                          window_vt = window_vt.get
                          window_area = subsurface.netArea
                          window_area_sum += window_area
                          area_weighted_vt_handle += window_area * window_vt
                          window_vertices = subsurface.vertices
                          if window_vertices[0].z.round(2) == window_vertices[1].z.round(2)
                            window_width = Math.sqrt((window_vertices[0].x - window_vertices[1].x) ** 2.0 + (window_vertices[0].y - window_vertices[1].y) ** 2.0)
                          else
                            window_width = Math.sqrt((window_vertices[1].x - window_vertices[2].x) ** 2.0 + (window_vertices[1].y - window_vertices[2].y) ** 2.0)
                          end
                          window_head_height = [window_vertices[0].z, window_vertices[1].z, window_vertices[2].z, window_vertices[3].z].max.round(2)
                          primary_sidelighted_area_depth = [window_head_height, daylight_space_depth].min #as per NECB2011: 4.2.2.9.

                          ##### Calculate the  distance of the window to vertical walls on each side of the window (this is used to determine the sidelighted area's width).
                          window_vertices_on_floor = []
                          window_vertices.each do |vertex|
                            window_vertices_on_floor << floor_surface.plane.project(vertex)
                          end
                          window_wall_distance_side1 = [Math.sqrt((wall_vertices_x_on_floor[0] - window_vertices_on_floor[0].x) ** 2.0 + (wall_vertices_y_on_floor[0] - window_vertices_on_floor[0].y) ** 2.0),
                                                        Math.sqrt((wall_vertices_x_on_floor[0] - window_vertices_on_floor[2].x) ** 2.0 + (wall_vertices_y_on_floor[0] - window_vertices_on_floor[2].y) ** 2.0),
                                                        0.6].min # 0.6 m as per NECB2011: 4.2.2.9.
                          window_wall_distance_side2 = [Math.sqrt((wall_vertices_x_on_floor[1] - window_vertices_on_floor[0].x) ** 2.0 + (wall_vertices_y_on_floor[1] - window_vertices_on_floor[0].y) ** 2.0),
                                                        Math.sqrt((wall_vertices_x_on_floor[1] - window_vertices_on_floor[2].x) ** 2.0 + (wall_vertices_y_on_floor[1] - window_vertices_on_floor[2].y) ** 2.0),
                                                        0.6].min # 0.6 m as per NECB2011: 4.2.2.9.
                          primary_sidelighted_area_width = window_wall_distance_side1 + window_width + window_wall_distance_side2
                          primary_sidelighted_area = primary_sidelighted_area + primary_sidelighted_area_depth * primary_sidelighted_area_width
                        end #if subsurface.subSurfaceType == "FixedWindow" || subsurface.subSurfaceType == "OperableWindow"
                      end #surface.subSurfaces.each do |subsurface|
                    end #if surface.outsideBoundaryCondition == "Outdoors" && surface.surfaceType == "Wall" && surface_z_min == floor_vertices[0][0].z
                  end #daylight_space.surfaces.each do |surface|

                  primary_sidelighted_area_hash[daylight_space.name.to_s] = primary_sidelighted_area

                  ##### Calculate area-weighted VT of glazing (this is used to calculate sidelighting effective aperture; see NECB2011: 4.2.2.10.).
                  area_weighted_vt = area_weighted_vt_handle / window_area_sum
                  sidelighting_effective_aperture_hash[daylight_space.name.to_s] = window_area_sum * area_weighted_vt / primary_sidelighted_area

                end #daylight_spaces.each do |daylight_space|


                ##### Calculate "Daylighted Area Under Skylights" AND "Skylight Effective Aperture"
                daylight_spaces.sort.each do |daylight_space|
                  skylight_area = 0.0
                  skylight_area_weighted_vt_handle = 0.0
                  skylight_area_weighted_vt = 0.0
                  skylight_area_sum = 0.0

                  ##### Loop through the surfaces of each daylight_space to calculate daylighted_area_under_skylights and skylight_effective_aperture for each daylight_space
                  daylight_space.surfaces.sort.each do |surface|
                    ##### Get roof vertices
                    if surface.outsideBoundaryCondition == "Outdoors" && surface.surfaceType == "RoofCeiling"
                      roof_vertices = surface.vertices
                    end

                    ##### Loop through each subsurafce to calculate daylighted_area_under_skylights and skylight_effective_aperture for each daylight_space
                    surface.subSurfaces.sort.each do |subsurface|
                      if subsurface.subSurfaceType == "Skylight"
                        skylight_vt = subsurface.visibleTransmittance
                        skylight_vt = skylight_vt.get
                        skylight_area = subsurface.netArea
                        skylight_area_sum += skylight_area
                        skylight_area_weighted_vt_handle += skylight_area * skylight_vt

                        ##### Get skylight vertices
                        skylight_vertices = subsurface.vertices

                        ##### Calculate skylight width and height
                        skylight_width = Math.sqrt((skylight_vertices[0].x - skylight_vertices[1].x) ** 2.0 + (skylight_vertices[0].y - skylight_vertices[1].y) ** 2.0)
                        skylight_length = Math.sqrt((skylight_vertices[0].x - skylight_vertices[3].x) ** 2.0 + (skylight_vertices[0].y - skylight_vertices[3].y) ** 2.0)

                        ##### Get ceiling height assuming the skylight is flush with the ceiling
                        ceiling_height = skylight_vertices[0].z

                        ##### Calculate roof lengths
                        ##### (Note: used OpenStudio BCL measure called "assign_ashrae_9012010_daylighting_controls" with some changes/correcctions)
                        roof_length_0 = Math.sqrt((roof_vertices[0].x - roof_vertices[1].x) ** 2.0 + (roof_vertices[0].y - roof_vertices[1].y) ** 2.0)
                        roof_length_1 = Math.sqrt((roof_vertices[1].x - roof_vertices[2].x) ** 2.0 + (roof_vertices[1].y - roof_vertices[2].y) ** 2.0)
                        roof_length_2 = Math.sqrt((roof_vertices[2].x - roof_vertices[3].x) ** 2.0 + (roof_vertices[2].y - roof_vertices[3].y) ** 2.0)
                        roof_length_3 = Math.sqrt((roof_vertices[3].x - roof_vertices[0].x) ** 2.0 + (roof_vertices[3].y - roof_vertices[0].y) ** 2.0)

                        ##### Find the skylight point that is the closest one to roof_vertex_0
                        ##### (Note: used OpenStudio BCL measure called "assign_ashrae_9012010_daylighting_controls" with some changes/correcctions)
                        roof_vertex_0_skylight_vertex_0 = Math.sqrt((roof_vertices[0].x - skylight_vertices[0].x) ** 2.0 + (roof_vertices[0].y - skylight_vertices[0].y) ** 2.0)
                        roof_vertex_0_skylight_vertex_1 = Math.sqrt((roof_vertices[0].x - skylight_vertices[1].x) ** 2.0 + (roof_vertices[0].y - skylight_vertices[1].y) ** 2.0)
                        roof_vertex_0_skylight_vertex_2 = Math.sqrt((roof_vertices[0].x - skylight_vertices[2].x) ** 2.0 + (roof_vertices[0].y - skylight_vertices[2].y) ** 2.0)
                        roof_vertex_0_skylight_vertex_3 = Math.sqrt((roof_vertices[0].x - skylight_vertices[3].x) ** 2.0 + (roof_vertices[0].y - skylight_vertices[3].y) ** 2.0)
                        roof_vertex_0_closest_distance = [roof_vertex_0_skylight_vertex_0, roof_vertex_0_skylight_vertex_1, roof_vertex_0_skylight_vertex_2, roof_vertex_0_skylight_vertex_3].min
                        if roof_vertex_0_closest_distance == roof_vertex_0_skylight_vertex_0
                          roof_vertex_0_closest_point = skylight_vertices[0]
                        elsif roof_vertex_0_closest_distance == roof_vertex_0_skylight_vertex_1
                          roof_vertex_0_closest_point = skylight_vertices[1]
                        elsif roof_vertex_0_closest_distance == roof_vertex_0_skylight_vertex_2
                          roof_vertex_0_closest_point = skylight_vertices[2]
                        elsif roof_vertex_0_closest_distance == roof_vertex_0_skylight_vertex_3
                          roof_vertex_0_closest_point = skylight_vertices[3]
                        end

                        ##### Find the skylight point that is the closest one to roof_vertex_2
                        ##### (Note: used OpenStudio BCL measure called "assign_ashrae_9012010_daylighting_controls" with some changes/correcctions)
                        roof_vertex_2_skylight_vertex_0 = Math.sqrt((roof_vertices[2].x - skylight_vertices[0].x) ** 2.0 + (roof_vertices[2].y - skylight_vertices[0].y) ** 2.0)
                        roof_vertex_2_skylight_vertex_1 = Math.sqrt((roof_vertices[2].x - skylight_vertices[1].x) ** 2.0 + (roof_vertices[2].y - skylight_vertices[1].y) ** 2.0)
                        roof_vertex_2_skylight_vertex_2 = Math.sqrt((roof_vertices[2].x - skylight_vertices[2].x) ** 2.0 + (roof_vertices[2].y - skylight_vertices[2].y) ** 2.0)
                        roof_vertex_2_skylight_vertex_3 = Math.sqrt((roof_vertices[2].x - skylight_vertices[3].x) ** 2.0 + (roof_vertices[2].y - skylight_vertices[3].y) ** 2.0)
                        roof_vertex_2_closest_distance = [roof_vertex_2_skylight_vertex_0, roof_vertex_2_skylight_vertex_1, roof_vertex_2_skylight_vertex_2, roof_vertex_2_skylight_vertex_3].min
                        if roof_vertex_2_closest_distance == roof_vertex_2_skylight_vertex_0
                          roof_vertex_2_closest_point = skylight_vertices[0]
                        elsif roof_vertex_2_closest_distance == roof_vertex_2_skylight_vertex_1
                          roof_vertex_2_closest_point = skylight_vertices[1]
                        elsif roof_vertex_2_closest_distance == roof_vertex_2_skylight_vertex_2
                          roof_vertex_2_closest_point = skylight_vertices[2]
                        elsif roof_vertex_2_closest_distance == roof_vertex_2_skylight_vertex_3
                          roof_vertex_2_closest_point = skylight_vertices[3]
                        end

                        ##### Calculate the vertical distance from the closest skylight points (projection onto the roof) to the wall (projection onto the roof) for roof_vertex_0 and roof_vertex_2
                        ##### (Note: used OpenStudio BCL measure called "assign_ashrae_9012010_daylighting_controls" with some changes/correcctions)
                        ##### For the calculation of each vertical distance: (1) first the area of the triangle is calculated knowing the cooridantes of its three corners;
                        ##### (2) the vertical distance (i.e. triangle height) is calculated knowing the triangle area and the associated roof length.
                        rv_0_triangle_0_area = 0.5 * (((roof_vertex_0_closest_point.x - roof_vertices[1].x) * (roof_vertex_0_closest_point.y - roof_vertices[0].y)) -
                            ((roof_vertex_0_closest_point.x - roof_vertices[0].x) * (roof_vertex_0_closest_point.y - roof_vertices[1].y))).abs
                        rv_0_distance_0 = (2.0 * rv_0_triangle_0_area) / roof_length_0
                        rv_0_triangle_3_area = 0.5 * (((roof_vertex_0_closest_point.x - roof_vertices[3].x) * (roof_vertex_0_closest_point.y - roof_vertices[0].y)) -
                            ((roof_vertex_0_closest_point.x - roof_vertices[0].x) * (roof_vertex_0_closest_point.y - roof_vertices[3].y))).abs
                        rv_0_distance_3 = (2.0 * rv_0_triangle_3_area) / roof_length_3

                        rv_2_triangle_1_area = 0.5 * (((roof_vertex_2_closest_point.x - roof_vertices[1].x) * (roof_vertex_2_closest_point.y - roof_vertices[2].y)) -
                            ((roof_vertex_2_closest_point.x - roof_vertices[2].x) * (roof_vertex_2_closest_point.y - roof_vertices[1].y))).abs
                        rv_2_distance_1 = (2.0 * rv_2_triangle_1_area) / roof_length_1
                        rv_2_triangle_2_area = 0.5 * (((roof_vertex_2_closest_point.x - roof_vertices[3].x) * (roof_vertex_2_closest_point.y - roof_vertices[2].y)) -
                            ((roof_vertex_2_closest_point.x - roof_vertices[2].x) * (roof_vertex_2_closest_point.y - roof_vertices[3].y))).abs
                        rv_2_distance_2 = (2.0 * rv_2_triangle_2_area) / roof_length_2

                        ##### Set the vertical distances from the closest skylight points (projection onto the roof) to the wall (projection onto the roof) for roof_vertex_0 and roof_vertex_2
                        distance_1 = rv_0_distance_0
                        distance_2 = rv_0_distance_3
                        distance_3 = rv_2_distance_1
                        distance_4 = rv_2_distance_2

                        ##### Calculate the width and length of the daylighted area under the skylight as per NECB2011: 4.2.2.5.
                        ##### Note: In the below loops, if any exterior walls has window(s), the width and length of the daylighted area under the skylight are re-calculated as per NECB2011: 4.2.2.5.
                        daylighted_under_skylight_width = skylight_width + [0.7 * ceiling_height, distance_1].min + [0.7 * ceiling_height, distance_4].min
                        daylighted_under_skylight_length = skylight_length + [0.7 * ceiling_height, distance_2].min + [0.7 * ceiling_height, distance_3].min

                        ##### As noted above, the width and length of the daylighted area under the skylight are re-calculated (as per NECB2011: 4.2.2.5.), if any exterior walls has window(s).
                        ##### To this end, the window_head_height should be calculated, as below:
                        daylight_space.surfaces.sort.each do |surface|
                          if surface.outsideBoundaryCondition == "Outdoors" && surface.surfaceType == "Wall"
                            wall_vertices_on_floor_x = []
                            wall_vertices_on_floor_y = []
                            wall_vertices = surface.vertices
                            if wall_vertices[0].z == wall_vertices[1].z
                              wall_vertices_on_floor_x << wall_vertices[0].x
                              wall_vertices_on_floor_x << wall_vertices[1].x
                              wall_vertices_on_floor_y << wall_vertices[0].y
                              wall_vertices_on_floor_y << wall_vertices[1].y
                            elsif wall_vertices[0].z == wall_vertices[3].z
                              wall_vertices_on_floor_x << wall_vertices[0].x
                              wall_vertices_on_floor_x << wall_vertices[3].x
                              wall_vertices_on_floor_y << wall_vertices[0].y
                              wall_vertices_on_floor_y << wall_vertices[3].y
                            end
                            window_vertices = subsurface.vertices
                            window_head_height = [window_vertices[0].z, window_vertices[1].z, window_vertices[2].z, window_vertices[3].z].max.round(2)

                            ##### Calculate the exterior wall length (on the floor)
                            exterior_wall_length = Math.sqrt((wall_vertices_on_floor_x[0] - wall_vertices_on_floor_x[1]) ** 2.0 + (wall_vertices_on_floor_y[0] - wall_vertices_on_floor_y[1]) ** 2.0)

                            ##### Calculate the vertical distance of skylight_vertices[0] projection onto the roof/floor to the exterior wall
                            skylight_vertex_0_triangle_area = 0.5 * (((wall_vertices_on_floor_x[0] - wall_vertices_on_floor_x[1]) * (wall_vertices_on_floor_y[0] - skylight_vertices[0].y)) -
                                ((wall_vertices_on_floor_x[0] - skylight_vertices[0].x) * (wall_vertices_on_floor_y[0] - wall_vertices_on_floor_y[1]))).abs
                            skylight_vertex_0_distance = (2.0 * skylight_vertex_0_triangle_area) / exterior_wall_length

                            ##### Calculate the vertical distance of skylight_vertices[1] projection onto the roof/floor to the exterior wall
                            skylight_vertex_1_triangle_area = 0.5 * (((wall_vertices_on_floor_x[0] - wall_vertices_on_floor_x[1]) * (wall_vertices_on_floor_y[0] - skylight_vertices[1].y)) -
                                ((wall_vertices_on_floor_x[0] - skylight_vertices[1].x) * (wall_vertices_on_floor_y[0] - wall_vertices_on_floor_y[1]))).abs
                            skylight_vertex_1_distance = (2.0 * skylight_vertex_1_triangle_area) / exterior_wall_length

                            ##### Calculate the vertical distance of skylight_vertices[3] projection onto the roof/floor to the exterior wall
                            skylight_vertex_3_triangle_area = 0.5 * (((wall_vertices_on_floor_x[0] - wall_vertices_on_floor_x[1]) * (wall_vertices_on_floor_y[0] - skylight_vertices[3].y)) -
                                ((wall_vertices_on_floor_x[0] - skylight_vertices[3].x) * (wall_vertices_on_floor_y[0] - wall_vertices_on_floor_y[1]))).abs
                            skylight_vertex_3_distance = (2.0 * skylight_vertex_3_triangle_area) / exterior_wall_length

                            ##### Loop through the subsurfaces that has exterior windows to re-calculate the width and length of the daylighted area under the skylight
                            surface.subSurfaces.sort.each do |subsurface|
                              if subsurface.subSurfaceType == "FixedWindow" || subsurface.subSurfaceType == "OperableWindow"

                                if skylight_vertex_0_distance == skylight_vertex_1_distance #skylight_01 is in parellel to the exterior wall
                                  if skylight_vertex_0_distance.round(2) == distance_2.round(2)
                                    daylighted_under_skylight_length = skylight_length + [0.7 * ceiling_height, distance_2, distance_2 - window_head_height].min + [0.7 * ceiling_height, distance_3].min
                                  elsif skylight_vertex_0_distance.round(2) == distance_3.round(2)
                                    daylighted_under_skylight_length = skylight_length + [0.7 * ceiling_height, distance_2].min + [0.7 * ceiling_height, distance_3, distance_3 - window_head_height].min
                                  end
                                elsif skylight_vertex_0_distance == skylight_vertex_3_distance #skylight_03 is in parellel to the exterior wall
                                  if skylight_vertex_0_distance.round(2) == distance_1.round(2)
                                    daylighted_under_skylight_width = skylight_width + [0.7 * ceiling_height, distance_1, distance_1 - window_head_height].min + [0.7 * ceiling_height, distance_4].min
                                  elsif skylight_vertex_0_distance.round(2) == distance_4.round(2)
                                    daylighted_under_skylight_width = skylight_width + [0.7 * ceiling_height, distance_1].min + [0.7 * ceiling_height, distance_4, distance_4 - window_head_height].min
                                  end
                                end #if skylight_vertex_0_distance == skylight_vertex_1_distance

                              end #if subsurface.subSurfaceType == "FixedWindow" || subsurface.subSurfaceType == "OperableWindow"
                            end #surface.subSurfaces.each do |subsurface|
                          end #if surface.outsideBoundaryCondition == "Outdoors" && surface.surfaceType == "Wall"
                        end #daylight_space.surfaces.each do |surface|

                        skylight_area_weighted_vt = skylight_area_weighted_vt_handle / skylight_area_sum
                        daylighted_area_under_skylights_hash[daylight_space.name.to_s] = daylighted_under_skylight_length * daylighted_under_skylight_width

                        ##### Calculate skylight_effective_aperture as per NECB2011: 4.2.2.7.
                        ##### Note that it was assumed that the skylight is flush with the ceiling. Therefore, area-weighted average well factor (WF) was set to 0.9 in the below Equation.
                        skylight_effective_aperture_hash[daylight_space.name.to_s] = 0.85 * skylight_area_sum * skylight_area_weighted_vt * 0.9 / (daylighted_under_skylight_length * daylighted_under_skylight_width)

                      end #if subsurface.subSurfaceType == "Skylight"
                    end #surface.subSurfaces.each do |subsurface|
                  end #daylight_space.surfaces.each do |surface|

                end #daylight_spaces.each do |daylight_space|


                ##### Find office spaces >= 25m2 among daylight_spaces
                offices_larger_25m2 = []
                daylight_spaces.sort.each do |daylight_space|
                  office_area = nil
                  daylight_space.surfaces.sort.each do |surface|
                    if surface.surfaceType == "Floor"
                      office_area = surface.netArea
                    end
                  end
                  if daylight_space.spaceType.get.standardsSpaceType.get.to_s == "Office - enclosed" && office_area >= 25.0
                    offices_larger_25m2 << daylight_space.name.to_s
                  end
                end

                ##### find daylight_spaces which do not need daylight sensor controls based on the primary_sidelighted_area as per NECB2011: 4.2.2.8.
                ##### Note: Office spaces >= 25m2 are excluded (i.e. they should have daylighting controls even if their primary_sidelighted_area <= 100m2), as per NECB2011: 4.2.2.2.
                daylight_spaces_exception = []
                primary_sidelighted_area_hash.sort.each do |key_daylight_space_name, value_primary_sidelighted_area|
                  if value_primary_sidelighted_area <= 100.0 && [key_daylight_space_name].any? {|word| offices_larger_25m2.include?(word)} == false
                    daylight_spaces_exception << key_daylight_space_name
                  end
                end

                ##### find daylight_spaces which do not need daylight sensor controls based on the sidelighting_effective_aperture as per NECB2011: 4.2.2.8.
                ##### Note: Office spaces >= 25m2 are excluded (i.e. they should have daylighting controls even if their sidelighting_effective_aperture <= 10%), as per NECB2011: 4.2.2.2.
                sidelighting_effective_aperture_hash.sort.each do |key_daylight_space_name, value_sidelighting_effective_aperture|
                  if value_sidelighting_effective_aperture <= 0.1 && [key_daylight_space_name].any? {|word| offices_larger_25m2.include?(word)} == false
                    daylight_spaces_exception << key_daylight_space_name
                  end
                end

                ##### find daylight_spaces which do not need daylight sensor controls based on the daylighted_area_under_skylights as per NECB2011: 4.2.2.4.
                ##### Note: Office spaces >= 25m2 are excluded (i.e. they should have daylighting controls even if their daylighted_area_under_skylights <= 400m2), as per NECB2011: 4.2.2.2.
                daylighted_area_under_skylights_hash.sort.each do |key_daylight_space_name, value_daylighted_area_under_skylights|
                  if value_daylighted_area_under_skylights <= 400.0 && [key_daylight_space_name].any? {|word| offices_larger_25m2.include?(word)} == false
                    daylight_spaces_exception << key_daylight_space_name
                  end
                end

                ##### find daylight_spaces which do not need daylight sensor controls based on the skylight_effective_aperture criterion as per NECB2011: 4.2.2.4.
                ##### Note: Office spaces >= 25m2 are excluded (i.e. they should have daylighting controls even if their skylight_effective_aperture <= 0.6%), as per NECB2011: 4.2.2.2.
                skylight_effective_aperture_hash.sort.each do |key_daylight_space_name, value_skylight_effective_aperture|
                  if value_skylight_effective_aperture <= 0.006 && [key_daylight_space_name].any? {|word| offices_larger_25m2.include?(word)} == false
                    daylight_spaces_exception << key_daylight_space_name
                  end
                end

                ##### Loop through the daylight_spaces and exclude the daylight_spaces that do not meet the criteria (see above) as per NECB2011: 4.2.2.4. and 4.2.2.8.
                daylight_spaces_exception.sort.each do |daylight_space_exception|
                  daylight_spaces.sort.each do |daylight_space|
                    if daylight_space.name.to_s == daylight_space_exception
                      daylight_spaces.delete(daylight_space)
                    end
                  end
                end

                ##### Gather daylighting sensors specifications in the model for the daylight_spaces that should have daylighting sensor
                daylight_spaces.sort.each do |daylight_space|
                  ##### 1. Calculate number of floors of each daylight_space
                  ##### 2. Find the lowest z among all floors of each daylight_space
                  ##### 3. Find lowest floors of each daylight_space (these floors are at the same level)
                  ##### 4. Calculate 'daylight_space_area' as sum of area of all the lowest floors of each daylight_space, and gather the vertices of all the lowest floors of each daylight_space
                  ##### 5. Find min and max of x and y among vertices of all the lowest floors of each daylight_space (these vertices are required for boundingBox to find the location of daylighting sensor(s))

                  ##### Calculate number of floors of daylight_space
                  floor_vertices = []
                  number_floor = 0
                  daylight_space.surfaces.sort.each do |surface|
                    if surface.surfaceType == 'Floor'
                      floor_vertices << surface.vertices
                      number_floor += 1
                    end
                  end

                  ##### Loop through all floors of daylight_space, and find the lowest z among all floors of daylight_space
                  lowest_floor_z = []
                  highest_floor_z = []
                  for i in 0..number_floor - 1
                    if i == 0
                      lowest_floor_z = floor_vertices[i][0].z
                      highest_floor_z = floor_vertices[i][0].z
                    else
                      if lowest_floor_z > floor_vertices[i][0].z
                        lowest_floor_z = floor_vertices[i][0].z
                      else
                        lowest_floor_z = lowest_floor_z
                      end
                      if highest_floor_z < floor_vertices[i][0].z
                        highest_floor_z = floor_vertices[i][0].z
                      else
                        highest_floor_z = highest_floor_z
                      end
                    end
                  end

                  ##### Loop through all floors of daylight_space, and calculate the sum of area of all the lowest floors of daylight_space,
                  ##### and gather the vertices of all the lowest floors of daylight_space
                  daylight_space_area = 0
                  lowest_floors_vertices = []
                  floor_vertices = []
                  daylight_space.surfaces.sort.each do |surface|
                    if surface.surfaceType == 'Floor'
                      floor_vertices = surface.vertices
                      if floor_vertices[0].z == lowest_floor_z
                        lowest_floors_vertices << floor_vertices
                        daylight_space_area = daylight_space_area + surface.netArea
                      end
                    end
                  end

                  ##### Get the thermal zone of daylight_space (this is used later to assign daylighting sensor)
                  zone = daylight_space.thermalZone
                  if !zone.empty?
                    zone = daylight_space.thermalZone.get

                    zone_daylighting_control_primary = zone.primaryDaylightingControl.get
                    primary_daylighting_control_fraction_of_zone_controlled = zone.fractionofZoneControlledbyPrimaryDaylightingControl()
                    primary_daylighting_control_illuminance_setpoint = zone_daylighting_control_primary.illuminanceSetpoint()
                    primary_daylighting_control_lighting_control_type = zone_daylighting_control_primary.lightingControlType()
                    primary_daylighting_control_number_of_stepped_control_steps = zone_daylighting_control_primary.numberofSteppedControlSteps()
                    primary_daylighting_x_pos = zone_daylighting_control_primary.positionXCoordinate()
                    primary_daylighting_y_pos = zone_daylighting_control_primary.positionYCoordinate()
                    primary_daylighting_z_pos = zone_daylighting_control_primary.positionZCoordinate()

                    ##### Gather results from this iteration and store it into the test_result_array.
                    result["#{daylight_space.name.to_s} - area"] = daylight_space_area
                    result["#{daylight_space.name.to_s} - primary_daylighting_control_fraction_of_zone_controlled"] = primary_daylighting_control_fraction_of_zone_controlled
                    result["#{daylight_space.name.to_s} - primary_daylighting_control_illuminance_setpoint"] = primary_daylighting_control_illuminance_setpoint
                    result["#{daylight_space.name.to_s} - primary_daylighting_control_lighting_control_type"] = primary_daylighting_control_lighting_control_type
                    result["#{daylight_space.name.to_s} - primary_daylighting_control_number_of_stepped_control_steps"] = primary_daylighting_control_number_of_stepped_control_steps
                    result["#{daylight_space.name.to_s} - primary_daylighting_x_pos"] = primary_daylighting_x_pos
                    result["#{daylight_space.name.to_s} - primary_daylighting_y_pos"] = primary_daylighting_y_pos
                    result["#{daylight_space.name.to_s} - primary_daylighting_z_pos"] = primary_daylighting_z_pos

                  end #!zone.empty?

                end #daylight_spaces.each do |daylight_space|

                #then store result into the array that contains all the scenario results.
                @test_results_array << result

              end #@lighting_types.sort.each do |lighting_type|
            end #@dcv_types.sort.each do |dcv_type|
          end #@primary_heating_fuels.sort.each do |primary_heating_fuel|
        end #@building_types.sort.each do |building_type|
      end #@epw_files.sort.each do |epw_file|
    end #@templates.sort.each do |template|


    # Save test results to file.
    File.open(@test_results_file, 'w') {|f| f.write(JSON.pretty_generate(@test_results_array))}

    # Compare results
    compare_message = ''
    # Check if expected file exists.
    if File.exist?(@expected_results_file)
      # Load expected results from file.
      @expected_results = JSON.parse(File.read(@expected_results_file))
      if @expected_results.size == @test_results_array.size
        # Iterate through each test result.
        @expected_results.each_with_index do |expected, row|
          # Compare if row /hash is exactly the same.
          if expected != @test_results_array[row]
            #if not set test flag to false
            @test_passed = false
            compare_message << "\nERROR: This row was different expected/result\n"
            compare_message << "EXPECTED:#{expected.to_s}\n"
            compare_message << "TEST:    #{@test_results_array[row].to_s}\n\n"
          end
        end
      else
        assert(false, "#{@expected_results_file} # of rows do not match the #{@test_results_array}..cannot compare")
      end
    else
      assert(false, "#{@expected_results_file} does not exist..cannot compare")
    end
    puts compare_message
    assert(@test_passed, "Error: This test failed to produce the same result as in the #{@expected_results_file}\n")
  end

end

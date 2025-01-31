require_relative '../../helpers/minitest_helper'

class TestGeometryCreateShape < Minitest::Test
  def setup
    @geo = OpenstudioStandards::Geometry
  end

  def test_create_shape_rectangle
    # test over a range of input geometry and check that floor areas and boundary conditions sucessfully set
    [25, 50, 100].each do |length|
      [20, 40, 80, 200].each do |width|
        [1, 3, 5].each do |storys|
          [0, 1, 3].each do |underground_storys|
            case_description = "length(#{length}), width(#{width}), storys(#{storys}), underground_storys(#{underground_storys})"

            # create geometry
            model = OpenStudio::Model::Model.new
            @geo.create_shape_rectangle(model,
                                        length = length,
                                        width = width,
                                        above_ground_storys = storys,
                                        under_ground_storys = underground_storys,
                                        floor_to_floor_height = 3.8,
                                        plenum_height = 1.0,
                                        perimeter_zone_depth = 1.0,
                                        initial_height = 0.0)

            # check that the floor area matches
            correct_floor_area = (length * width * (storys + underground_storys)).round(2)
            model_floor_area = model.getBuilding.floorArea.to_f.round(2)
            assert_in_delta(correct_floor_area, model_floor_area, 0.1, "For case (#{case_description}), floor area #{model_floor_area} does not match expected floor area #{correct_floor_area}.")

            # check exterior walls and boundary conditions
            model_ext_walls = model.getBuilding.exteriorWalls
            correct_number_of_ext_walls = 4 * storys
            assert_equal(correct_number_of_ext_walls, model_ext_walls.count, "For case (#{case_description}), number of exterior walls #{model_ext_walls.count} does not match expected number of exterior walls #{correct_number_of_ext_walls}.")

            ext_wall_area = 0.0
            model_ext_walls.each do |wall|
              assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, 'Expected wall boundary condition')
              ext_wall_area += wall.netArea
            end
            ext_wall_area = ext_wall_area.round(2)
            correct_ext_wall_area = (3.8 * (length + width) * 2 * storys).round(2)
            assert_in_delta(correct_ext_wall_area, ext_wall_area, 0.1, "For case (#{case_description}), exterior wall area #{ext_wall_area} does not match expected exterior wall area #{correct_ext_wall_area}.")

            # check roofs and boundary conditions
            roofs = model.getBuilding.roofs
            number_of_roofs = 5
            assert_equal(number_of_roofs, roofs.count, "For case (#{case_description}), number of roof surfaces #{roofs.count} does not match expected number of roof surfaces #{number_of_roofs}.")
            roof_area = 0.0
            roofs.each do |roof|
              assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, 'Expected roof boundary condition')
              roof_area += roof.netArea
            end
            roof_area = roof_area.round(2)
            correct_roof_area = (length * width).round(2)
            assert_in_delta(correct_roof_area, roof_area, 0.1, "For case (#{case_description}), roof area #{roof_area} does not match expected roof area #{correct_roof_area}.")

            # total exterior area
            model_ext_area = model.getBuilding.exteriorSurfaceArea.to_f.round(2)
            correct_ext_area = (correct_ext_wall_area + correct_roof_area).to_f.round(2)
            assert_in_delta(correct_ext_area, model_ext_area, 0.1, "For case (#{case_description}), exterior area #{model_ext_area} does not match expected exterior area #{correct_ext_area}.")

            # ground connections
            ground_area = 0.0
            model.getBuilding.spaces.each do |space|
              space.surfaces.each do |surface|
                ground_area += surface.netArea if surface.outsideBoundaryCondition == 'Ground'
              end
            end
            ground_area = ground_area.round(2)
            correct_ground_area = (length * width + 3.8 * (length + width) * 2 * underground_storys).round(2)
            assert_in_delta(correct_ground_area, ground_area, 0.1, "For case (#{case_description}), ground area #{ground_area} does not match expected ground area #{correct_ground_area}.")
          end
        end
      end
    end
  end

  def test_create_shape_aspect_ratio
    # test over a range of input geometry and check that floor areas and boundary conditions sucessfully set
    [0.1, 0.25, 0.5, 0.75].each do |aspect_ratio|
      [200, 500, 1000].each do |floor_area|
        [0, 90, 180].each do |rotation|
          [1, 3, 5].each do |storys|
            case_description = "aspect_ratio(#{aspect_ratio}), floor_area(#{floor_area}), storys(#{storys})"

            # create geometry
            model = OpenStudio::Model::Model.new
            @geo.create_shape_aspect_ratio(model,
                                           aspect_ratio = aspect_ratio,
                                           floor_area = floor_area,
                                           rotation = rotation,
                                           num_floors = storys,
                                           floor_to_floor_height = 3.8,
                                           plenum_height = 1.0,
                                           perimeter_zone_depth = 0.5)

            # check that the floor area matches
            correct_floor_area = floor_area.round(2)
            model_floor_area = model.getBuilding.floorArea.to_f.round(2)
            assert_in_delta(correct_floor_area, model_floor_area, 0.1, "For case (#{case_description}), floor area #{model_floor_area} does not match expected floor area #{correct_floor_area}.")

            # check exterior walls and boundary conditions
            model_ext_walls = model.getBuilding.exteriorWalls
            correct_number_of_ext_walls = 4 * storys
            assert_equal(correct_number_of_ext_walls, model_ext_walls.count, "For case (#{case_description}), number of exterior walls #{model_ext_walls.count} does not match expected number of exterior walls #{correct_number_of_ext_walls}.")

            ext_wall_area = 0.0
            model_ext_walls.each do |wall|
              assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, 'Expected wall boundary condition')
              ext_wall_area += wall.netArea
            end
            ext_wall_area = ext_wall_area.round(2)
            length = Math.sqrt((floor_area / (num_floors * 1.0)) / aspect_ratio)
            width = Math.sqrt((floor_area / (num_floors * 1.0)) * aspect_ratio)
            correct_ext_wall_area = (3.8 * (length + width) * 2 * storys).round(2)
            assert_in_delta(correct_ext_wall_area, ext_wall_area, 0.1, "For case (#{case_description}), exterior wall area #{ext_wall_area} does not match expected exterior wall area #{correct_ext_wall_area}.")

            # check roofs and boundary conditions
            roofs = model.getBuilding.roofs
            number_of_roofs = 5
            assert_equal(number_of_roofs, roofs.count, "For case (#{case_description}), number of roof surfaces #{roofs.count} does not match expected number of roof surfaces #{number_of_roofs}.")
            roof_area = 0.0
            roofs.each do |roof|
              assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, 'Expected roof boundary condition')
              roof_area += roof.netArea
            end
            roof_area = roof_area.round(2)
            correct_roof_area = (length * width).round(2)
            assert_in_delta(correct_roof_area, roof_area, 0.1, "For case (#{case_description}), roof area #{roof_area} does not match expected roof area #{correct_roof_area}.")

            # total exterior area
            model_ext_area = model.getBuilding.exteriorSurfaceArea.to_f.round(2)
            correct_ext_area = (correct_ext_wall_area + correct_roof_area).to_f.round(2)
            assert_in_delta(correct_ext_area, model_ext_area, 0.1, "For case (#{case_description}), exterior area #{model_ext_area} does not match expected exterior area #{correct_ext_area}.")

            # ground connections
            ground_area = 0.0
            model.getBuilding.spaces.each do |space|
              space.surfaces.each do |surface|
                ground_area += surface.netArea if surface.outsideBoundaryCondition == 'Ground'
              end
            end
            ground_area = ground_area.round(2)
            correct_ground_area =(floor_area / (num_floors * 1.0)).round(2)
            assert_in_delta(correct_ground_area, ground_area, 0.1, "For case (#{case_description}), ground area #{ground_area} does not match expected ground area #{correct_ground_area}.")
          end
        end
      end
    end
  end

  def test_create_shape_courtyard
    # test over a range of input geometry and check that floor areas and boundary conditions sucessfully set
    [25, 50, 100].each do |length|
      [20, 40, 80, 200].each do |width|
        [1, 3, 5].each do |storys|
          case_description = "length(#{length}), width(#{width}), storys(#{storys})"

          # create geometry
          model = OpenStudio::Model::Model.new
          @geo.create_shape_courtyard(model,
                                      length = length,
                                      width = width,
                                      courtyard_length = length / 3.0,
                                      courtyard_width = width / 3.0,
                                      num_floors = storys,
                                      floor_to_floor_height = 3.8,
                                      plenum_height = 1.0,
                                      perimeter_zone_depth = 1.0)

          # check that the floor area matches
          correct_floor_area = (length * width * storys * 8.0 / 9.0).round(2)
          model_floor_area = model.getBuilding.floorArea.to_f.round(2)
          assert_in_delta(correct_floor_area, model_floor_area, 0.1, "For case (#{case_description}), floor area #{model_floor_area} does not match expected floor area #{correct_floor_area}.")

          # check exterior walls and boundary conditions
          model_ext_walls = model.getBuilding.exteriorWalls
          correct_number_of_ext_walls = 8 * storys
          assert_equal(correct_number_of_ext_walls, model_ext_walls.count, "For case (#{case_description}), number of exterior walls #{model_ext_walls.count} does not match expected number of exterior walls #{correct_number_of_ext_walls}.")

          ext_wall_area = 0.0
          model_ext_walls.each do |wall|
            assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, 'Expected wall boundary condition')
            ext_wall_area += wall.netArea
          end
          ext_wall_area = ext_wall_area.round(2)
          correct_ext_wall_area = (3.8 * ((length + width) * 8.0 / 3.0) * storys).round(2)
          assert_in_delta(correct_ext_wall_area, ext_wall_area, 0.1, "For case (#{case_description}), exterior wall area #{ext_wall_area} does not match expected exterior wall area #{correct_ext_wall_area}.")

          # check roofs and boundary conditions
          roofs = model.getBuilding.roofs
          number_of_roofs = 12
          assert_equal(number_of_roofs, roofs.count, "For case (#{case_description}), number of roof surfaces #{roofs.count} does not match expected number of roof surfaces #{number_of_roofs}.")
          roof_area = 0.0
          roofs.each do |roof|
            assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, 'Expected roof boundary condition')
            roof_area += roof.netArea
          end
          roof_area = roof_area.round(2)
          correct_roof_area = (length * width * 8.0 / 9.0).round(2)
          assert_in_delta(correct_roof_area, roof_area, 0.1, "For case (#{case_description}), roof area #{roof_area} does not match expected roof area #{correct_roof_area}.")

          # total exterior area
          model_ext_area = model.getBuilding.exteriorSurfaceArea.to_f.round(2)
          correct_ext_area = (correct_ext_wall_area + correct_roof_area).to_f.round(2)
          assert_in_delta(correct_ext_area, model_ext_area, 0.1, "For case (#{case_description}), exterior area #{model_ext_area} does not match expected exterior area #{correct_ext_area}.")

          # ground connections
          ground_area = 0.0
          model.getBuilding.spaces.each do |space|
            space.surfaces.each do |surface|
              ground_area += surface.netArea if surface.outsideBoundaryCondition == 'Ground'
            end
          end
          ground_area = ground_area.round(2)
          correct_ground_area = (length * width * 8.0 / 9.0).round(2)
          assert_in_delta(correct_ground_area, ground_area, 0.1, "For case (#{case_description}), ground area #{ground_area} does not match expected ground area #{correct_ground_area}.")
        end
      end
    end
  end

  def test_create_shape_h
    # test over a range of input geometry and check that floor areas and boundary conditions sucessfully set
    [25, 50, 100].each do |length|
      [20, 40, 80, 200].each do |width|
        [1, 3, 5].each do |storys|
          case_description = "length(#{length}), width(#{width}), storys(#{storys})"

          # create geometry
          model = OpenStudio::Model::Model.new
          @geo.create_shape_h(model,
                              length = length,
                              left_width = width,
                              center_width = width / 3.0,
                              right_width = width,
                              left_end_length = length / 3.0,
                              right_end_length = length / 3.0,
                              left_upper_end_offset = width / 3.0,
                              right_upper_end_offset = width / 3.0,
                              num_floors = storys,
                              floor_to_floor_height = 3.8,
                              plenum_height = 1,
                              perimeter_zone_depth = 1.0)

          # check that the floor area matches
          correct_floor_area = (length * width * 7.0 / 9.0 *(storys.to_f)).round(2)
          model_floor_area = model.getBuilding.floorArea.to_f.round(2)
          assert_in_delta(correct_floor_area, model_floor_area, 0.1, "For case (#{case_description}), floor area #{model_floor_area} does not match expected floor area #{correct_floor_area}.")

          # check exterior walls and boundary conditions
          model_ext_walls = model.getBuilding.exteriorWalls
          correct_number_of_ext_walls = 12 * storys
          assert_equal(correct_number_of_ext_walls, model_ext_walls.count, "For case (#{case_description}), number of exterior walls #{model_ext_walls.count} does not match expected number of exterior walls #{correct_number_of_ext_walls}.")

          ext_wall_area = 0.0
          model_ext_walls.each do |wall|
            assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, 'Expected wall boundary condition')
            ext_wall_area += wall.netArea
          end
          ext_wall_area = ext_wall_area.round(2)
          correct_ext_wall_area = (3.8 * ((10.0/3.0 * width) + (2 * length)) * storys).round(2)
          assert_in_delta(correct_ext_wall_area, ext_wall_area, 0.1, "For case (#{case_description}), exterior wall area #{ext_wall_area} does not match expected exterior wall area #{correct_ext_wall_area}.")

          # check roofs and boundary conditions
          roofs = model.getBuilding.roofs
          number_of_roofs = 15
          assert_equal(number_of_roofs, roofs.count, "For case (#{case_description}), number of roof surfaces #{roofs.count} does not match expected number of roof surfaces #{number_of_roofs}.")
          roof_area = 0.0
          roofs.each do |roof|
            assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, 'Expected roof boundary condition')
            roof_area += roof.netArea
          end
          roof_area = roof_area.round(2)
          correct_roof_area = (length * width * 7.0 / 9.0).round(2)
          assert_in_delta(correct_roof_area, roof_area, 0.1, "For case (#{case_description}), roof area #{roof_area} does not match expected roof area #{correct_roof_area}.")

          # total exterior area
          model_ext_area = model.getBuilding.exteriorSurfaceArea.to_f.round(2)
          correct_ext_area = (correct_ext_wall_area + correct_roof_area).to_f.round(2)
          assert_in_delta(correct_ext_area, model_ext_area, 0.1, "For case (#{case_description}), exterior area #{model_ext_area} does not match expected exterior area #{correct_ext_area}.")

          # ground connections
          ground_area = 0.0
          model.getBuilding.spaces.each do |space|
            space.surfaces.each do |surface|
              ground_area += surface.netArea if surface.outsideBoundaryCondition == 'Ground'
            end
          end
          ground_area = ground_area.round(2)
          correct_ground_area = (length * width * 7.0 / 9.0).round(2)
          assert_in_delta(correct_ground_area, ground_area, 0.1, "For case (#{case_description}), ground area #{ground_area} does not match expected ground area #{correct_ground_area}.")
        end
      end
    end
  end

  def test_create_shape_l
    # test over a range of input geometry and check that floor areas and boundary conditions sucessfully set
    [25, 50, 100].each do |length|
      [20, 40, 80, 200].each do |width|
        [1, 3, 5].each do |storys|
          case_description = "length(#{length}), width(#{width}), storys(#{storys})"

          # create geometry
          model = OpenStudio::Model::Model.new
          @geo.create_shape_l(model,
                              length = length,
                              width = width,
                              lower_end_width = width / 3.0,
                              upper_end_length = length / 3.0,
                              num_floors = storys,
                              floor_to_floor_height = 3.8,
                              plenum_height = 1.0,
                              perimeter_zone_depth = 1.0)

          # check that the floor area matches
          correct_floor_area = (length * width * storys * 5.0 / 9.0).round(2)
          model_floor_area = model.getBuilding.floorArea.to_f.round(2)
          assert_in_delta(correct_floor_area, model_floor_area, 0.1, "For case (#{case_description}), floor area #{model_floor_area} does not match expected floor area #{correct_floor_area}.")

          # check exterior walls and boundary conditions
          model_ext_walls = model.getBuilding.exteriorWalls
          correct_number_of_ext_walls = 6 * storys
          assert_equal(correct_number_of_ext_walls, model_ext_walls.count, "For case (#{case_description}), number of exterior walls #{model_ext_walls.count} does not match expected number of exterior walls #{correct_number_of_ext_walls}.")

          ext_wall_area = 0.0
          model_ext_walls.each do |wall|
            assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, 'Expected wall boundary condition')
            ext_wall_area += wall.netArea
          end
          ext_wall_area = ext_wall_area.round(2)
          correct_ext_wall_area = (3.8 * (length + width) * 2 * storys).round(2)
          assert_in_delta(correct_ext_wall_area, ext_wall_area, 0.1, "For case (#{case_description}), exterior wall area #{ext_wall_area} does not match expected exterior wall area #{correct_ext_wall_area}.")

          # check roofs and boundary conditions
          roofs = model.getBuilding.roofs
          number_of_roofs = 8
          assert_equal(number_of_roofs, roofs.count, "For case (#{case_description}), number of roof surfaces #{roofs.count} does not match expected number of roof surfaces #{number_of_roofs}.")
          roof_area = 0.0
          roofs.each do |roof|
            assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, 'Expected roof boundary condition')
            roof_area += roof.netArea
          end
          roof_area = roof_area.round(2)
          correct_roof_area = (length * width * 5.0 / 9.0).round(2)
          assert_in_delta(correct_roof_area, roof_area, 0.1, "For case (#{case_description}), roof area #{roof_area} does not match expected roof area #{correct_roof_area}.")

          # total exterior area
          model_ext_area = model.getBuilding.exteriorSurfaceArea.to_f.round(2)
          correct_ext_area = (correct_ext_wall_area + correct_roof_area).to_f.round(2)
          assert_in_delta(correct_ext_area, model_ext_area, 0.1, "For case (#{case_description}), exterior area #{model_ext_area} does not match expected exterior area #{correct_ext_area}.")

          # ground connections
          ground_area = 0.0
          model.getBuilding.spaces.each do |space|
            space.surfaces.each do |surface|
              ground_area += surface.netArea if surface.outsideBoundaryCondition == 'Ground'
            end
          end
          ground_area = ground_area.round(2)
          correct_ground_area = (length * width * 5.0 / 9.0).round(2)
          assert_in_delta(correct_ground_area, ground_area, 0.1, "For case (#{case_description}), ground area #{ground_area} does not match expected ground area #{correct_ground_area}.")
        end
      end
    end
  end

  def test_create_shape_t
    # test over a range of input geometry and check that floor areas and boundary conditions sucessfully set
    [25, 50, 100].each do |length|
      [20, 40, 80, 200].each do |width|
        [1, 3, 5].each do |storys|
          case_description = "length(#{length}), width(#{width}), storys(#{storys})"

          # create geometry
          model = OpenStudio::Model::Model.new
          @geo.create_shape_t(model,
                              length = length,
                              width = width,
                              upper_end_width = width / 3.0,
                              lower_end_length = length / 3.0,
                              left_end_offset = 10.0,
                              num_floors = storys,
                              floor_to_floor_height = 3.8,
                              plenum_height = 1.0,
                              perimeter_zone_depth = 1.0)

          # check that the floor area matches
          correct_floor_area = (length * width * storys * 5.0 / 9.0).round(2)
          model_floor_area = model.getBuilding.floorArea.to_f.round(2)
          assert_in_delta(correct_floor_area, model_floor_area, 0.1, "For case (#{case_description}), floor area #{model_floor_area} does not match expected floor area #{correct_floor_area}.")

          # check exterior walls and boundary conditions
          model_ext_walls = model.getBuilding.exteriorWalls
          correct_number_of_ext_walls = 8 * storys
          assert_equal(correct_number_of_ext_walls, model_ext_walls.count, "For case (#{case_description}), number of exterior walls #{model_ext_walls.count} does not match expected number of exterior walls #{correct_number_of_ext_walls}.")

          ext_wall_area = 0.0
          model_ext_walls.each do |wall|
            assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, 'Expected wall boundary condition')
            ext_wall_area += wall.netArea
          end
          ext_wall_area = ext_wall_area.round(2)
          correct_ext_wall_area = (3.8 * (length + width) * 2 * storys).round(2)
          assert_in_delta(correct_ext_wall_area, ext_wall_area, 0.1, "For case (#{case_description}), exterior wall area #{ext_wall_area} does not match expected exterior wall area #{correct_ext_wall_area}.")

          # check roofs and boundary conditions
          roofs = model.getBuilding.roofs
          number_of_roofs = 10
          assert_equal(number_of_roofs, roofs.count, "For case (#{case_description}), number of roof surfaces #{roofs.count} does not match expected number of roof surfaces #{number_of_roofs}.")
          roof_area = 0.0
          roofs.each do |roof|
            assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, 'Expected roof boundary condition')
            roof_area += roof.netArea
          end
          roof_area = roof_area.round(2)
          correct_roof_area = (length * width * 5.0 / 9.0).round(2)
          assert_in_delta(correct_roof_area, roof_area, 0.1, "For case (#{case_description}), roof area #{roof_area} does not match expected roof area #{correct_roof_area}.")

          # total exterior area
          model_ext_area = model.getBuilding.exteriorSurfaceArea.to_f.round(2)
          correct_ext_area = (correct_ext_wall_area + correct_roof_area).to_f.round(2)
          assert_in_delta(correct_ext_area, model_ext_area, 0.1, "For case (#{case_description}), exterior area #{model_ext_area} does not match expected exterior area #{correct_ext_area}.")

          # ground connections
          ground_area = 0.0
          model.getBuilding.spaces.each do |space|
            space.surfaces.each do |surface|
              ground_area += surface.netArea if surface.outsideBoundaryCondition == 'Ground'
            end
          end
          ground_area = ground_area.round(2)
          correct_ground_area = (length * width * 5.0 / 9.0).round(2)
          assert_in_delta(correct_ground_area, ground_area, 0.1, "For case (#{case_description}), ground area #{ground_area} does not match expected ground area #{correct_ground_area}.")
        end
      end
    end
  end

  def test_create_shape_u
    # test over a range of input geometry and check that floor areas and boundary conditions sucessfully set
    [25, 50, 100].each do |length|
      [20, 40, 80, 200].each do |width|
        [1, 3, 5].each do |storys|
          case_description = "length(#{length}), width(#{width}), storys(#{storys})"

          # create geometry
          model = OpenStudio::Model::Model.new
          @geo.create_shape_u(model,
                              length = length,
                              left_width = width,
                              right_width = width,
                              left_end_length = length / 3.0,
                              right_end_length = length / 3.0,
                              left_end_offset = width*(2.0/3.0),
                              num_floors = storys,
                              floor_to_floor_height = 3.8,
                              plenum_height = 1.0,
                              perimeter_zone_depth = 1.0)

          # check that the floor area matches
          correct_floor_area = (length * width * storys * 7.0 / 9.0).round(2)
          model_floor_area = model.getBuilding.floorArea.to_f.round(2)
          assert_in_delta(correct_floor_area, model_floor_area, 0.1, "For case (#{case_description}), floor area #{model_floor_area} does not match expected floor area #{correct_floor_area}.")

          # check exterior walls and boundary conditions
          model_ext_walls = model.getBuilding.exteriorWalls
          correct_number_of_ext_walls = 8 * storys
          assert_equal(correct_number_of_ext_walls, model_ext_walls.count, "For case (#{case_description}), number of exterior walls #{model_ext_walls.count} does not match expected number of exterior walls #{correct_number_of_ext_walls}.")

          ext_wall_area = 0.0
          model_ext_walls.each do |wall|
            assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, 'Expected wall boundary condition')
            ext_wall_area += wall.netArea
          end
          ext_wall_area = ext_wall_area.round(2)
          correct_ext_wall_area = (3.8 * ((10.0/3.0 * width) + (2 * length)) * storys).round(2)
          assert_in_delta(correct_ext_wall_area, ext_wall_area, 0.1, "For case (#{case_description}), exterior wall area #{ext_wall_area} does not match expected exterior wall area #{correct_ext_wall_area}.")

          # check roofs and boundary conditions
          roofs = model.getBuilding.roofs
          number_of_roofs = 11
          assert_equal(number_of_roofs, roofs.count, "For case (#{case_description}), number of roof surfaces #{roofs.count} does not match expected number of roof surfaces #{number_of_roofs}.")
          roof_area = 0.0
          roofs.each do |roof|
            assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, 'Expected roof boundary condition')
            roof_area += roof.netArea
          end
          roof_area = roof_area.round(2)
          correct_roof_area = (length * width * 7.0 / 9.0).round(2)
          assert_in_delta(correct_roof_area, roof_area, 0.1, "For case (#{case_description}), roof area #{roof_area} does not match expected roof area #{correct_roof_area}.")

          # total exterior area
          model_ext_area = model.getBuilding.exteriorSurfaceArea.to_f.round(2)
          correct_ext_area = (correct_ext_wall_area + correct_roof_area).to_f.round(2)
          assert_in_delta(correct_ext_area, model_ext_area, 0.1, "For case (#{case_description}), exterior area #{model_ext_area} does not match expected exterior area #{correct_ext_area}.")

          # ground connections
          ground_area = 0.0
          model.getBuilding.spaces.each do |space|
            space.surfaces.each do |surface|
              ground_area += surface.netArea if surface.outsideBoundaryCondition == 'Ground'
            end
          end
          ground_area = ground_area.round(2)
          correct_ground_area = (length * width * 7.0 / 9.0).round(2)
          assert_in_delta(correct_ground_area, ground_area, 0.1, "For case (#{case_description}), ground area #{ground_area} does not match expected ground area #{correct_ground_area}.")
        end
      end
    end
  end
end

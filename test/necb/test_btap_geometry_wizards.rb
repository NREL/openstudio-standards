require_relative '../helpers/minitest_helper'

#Test Geometry Wizards
class TestBTAPGeometryWizards < MiniTest::Test

  # Loop through a range of geometry options and check floor areas and boundary conditions sucessfully set

  def test_geometry_rectangle
    [25, 100].each do |length|
      [20, 80].each do |width|
        [1, 5].each do |storys|
          [0, 1, 3].each do |underground_storys|

            caseDescription = "length(#{length}), width(#{width}), storys(#{storys}), underground_storys(#{underground_storys})"

            # Create a new model object.
            model = OpenStudio::Model::Model.new

            # Create a rectangular model
            BTAP::Geometry::Wizards::create_shape_rectangle(model,
                                                            length = length,
                                                            width = width,
                                                            above_ground_storys = storys,
                                                            under_ground_storys = underground_storys,
                                                            floor_to_floor_height = 3.8,
                                                            plenum_height = 1.0,
                                                            perimeter_zone_depth = 4.57,
                                                            initial_height = 0.0)

            # Dump model
            BTAP::FileIO::save_osm(model, File.join(File.dirname(__FILE__), "../local_test_output", "test_rectangle.osm"))

            # Test the model is correctly defined.
            # Floor area.
            correct_floor_area = (length * width * (storys + underground_storys)).round(1)
            msg = "floor area for case: #{caseDescription}"
            assert_in_delta(correct_floor_area, model.getBuilding.floorArea.to_f.round(1), 0.1, msg)

            # Get the exterior walls and check boundary conditions and areas.
            extWalls = model.getBuilding.exteriorWalls
            number_of_ext_walls = 4 * storys
            msg = "number of above grade exterior walls for case: #{caseDescription}"
            assert_equal(number_of_ext_walls, extWalls.count, msg)

            ext_wall_area = 0.0
            extWalls.each do |wall|
              msg = "wall boundary condition for case: #{caseDescription}"
              assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, msg)
              ext_wall_area += wall.netArea
            end
            correct_ext_wall_area = (3.8 * (length + width) * 2 * storys).round(1)
            msg = "total exterior wall area for case: #{caseDescription}"
            assert_in_delta(correct_ext_wall_area, ext_wall_area.round(1), 0.1, msg)

            # Get the roof surfaces and check boundary conditions and areas.
            roofs = model.getBuilding.roofs
            number_of_roofs = 5
            msg = "number of roof surfaces for case: #{caseDescription}"
            assert_equal(number_of_roofs, roofs.count, msg)
            roof_area = 0.0
            roofs.each do |roof|
              msg = "roof boundary condition for case: #{caseDescription}"
              assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, msg)
              roof_area += roof.netArea
            end
            correct_roof_area = (length * width).round(1)
            msg = "total roof area for case: #{caseDescription}"
            assert_in_delta(correct_roof_area, roof_area.round(1), 0.1, msg)

            # Total exterior area.
            msg = "total exterior surface area for case: #{caseDescription}"
            assert_in_delta((correct_ext_wall_area + correct_roof_area).to_f.round(2), model.getBuilding.exteriorSurfaceArea.to_f.round(2), 0.1, msg)

            # Ground connections
            ground_area = 0.0
            model.getBuilding.spaces.each do |space|
              space.surfaces.each do |surface|
                ground_area += surface.netArea if surface.outsideBoundaryCondition == "Ground"
              end
            end
            correct_ground_area = (length * width + 3.8 * (length + width) * 2 * underground_storys).round(1)
            msg = "total ground area for case: #{caseDescription}"
            assert_in_delta(correct_ground_area, ground_area.round(1), 0.1, msg)

          end
        end
      end
    end
  end

  def test_geometry_courtyard
    [50, 100].each do |length|
      [200, 80].each do |width|
        [1, 5].each do |storys|

          # Create a new model object.
          model = OpenStudio::Model::Model.new

          caseDescription = "length(#{length}), width(#{width}), storys(#{storys})"

          # Create a courtyard model
          BTAP::Geometry::Wizards::create_shape_courtyard(model,
                                                          length = length,
                                                          width = width,
                                                          courtyard_length = length / 3.0,
                                                          courtyard_width = width / 3.0,
                                                          above_ground_storys = storys,
                                                          floor_to_floor_height = 3.8,
                                                          plenum_height = 1.0,
                                                          perimeter_zone_depth = 1.0)

          # Dump model
          BTAP::FileIO::save_osm(model, File.join(File.dirname(__FILE__), "../local_test_output", "test_courtyard.osm"))

          # Test the model is correctly defined.
          # Floor area.
          correct_floor_area = (length * width * storys * 8.0 / 9.0).round(1)
          msg = "floor area for case: #{caseDescription}"
          assert_in_delta(correct_floor_area, model.getBuilding.floorArea.to_f.round(1), 0.1, 'floor area')

          # Get the exterior walls and check boundary conditions and areas.
          extWalls = model.getBuilding.exteriorWalls
          number_of_ext_walls = 8 * storys
          msg = "number of above grade exterior walls for case: #{caseDescription}"
          assert_equal(number_of_ext_walls, extWalls.count, 'number of exterior walls')

          ext_wall_area = 0.0
          extWalls.each do |wall|
            msg = "wall boundary condition for case: #{caseDescription}"
            assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, 'wall boundary condition')
            ext_wall_area += wall.netArea
          end
          correct_ext_wall_area = (3.8 * ((length + width) * 8.0 / 3.0) * storys).round(1)
          msg = "total exterior wall area for case: #{caseDescription}"
          assert_in_delta(correct_ext_wall_area, ext_wall_area.round(1), 0.1, 'total exterior wall area')

          # Get the roof surfaces and check boundary conditions and areas.
          roofs = model.getBuilding.roofs
          number_of_roofs = 12
          msg = "number of roof surfaces for case: #{caseDescription}"
          assert_equal(number_of_roofs, roofs.count, 'number of roof surfaces')
          roof_area = 0.0
          roofs.each do |roof|
            msg = "roof boundary condition for case: #{caseDescription}"
            assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, 'roof boundary condition')
            roof_area += roof.netArea
          end
          correct_roof_area = (length * width * 8.0 / 9.0).round(1)
          msg = "total roof area for case: #{caseDescription}"
          assert_in_delta(correct_roof_area, roof_area.round(1), 0.1, 'total roof area')

          # Total exterior area.
          msg = "total exterior surface area for case: #{caseDescription}"
          assert_in_delta((correct_ext_wall_area + correct_roof_area).to_f.round(2), model.getBuilding.exteriorSurfaceArea.to_f.round(2), 0.1, msg)

          # Ground connections
          ground_area = 0.0
          model.getBuilding.spaces.each do |space|
            space.surfaces.each do |surface|
              ground_area += surface.netArea if surface.outsideBoundaryCondition == "Ground"
            end
          end
          correct_ground_area = (length * width * 8.0 / 9.0).round(1)
          msg = "total ground area for case: #{caseDescription}"
          assert_in_delta(correct_ground_area, ground_area.round(1), 0.1, 'total ground area')

        end
      end
    end
  end

  # Test the L shape
  def test_geometry_Lshape
    [50, 100].each do |length|
      [200, 80].each do |width|
        [1, 5].each do |storys|

          # Create a new model object.
          model = OpenStudio::Model::Model.new

          caseDescription = "length(#{length}), width(#{width}), storys(#{storys})"

          # Create a L shape model
          BTAP::Geometry::Wizards::create_shape_l(model,
                                                  length = length,
                                                  width = width,
                                                  lower_end_width = width / 3.0,
                                                  upper_end_length = length / 3.0,
                                                  num_floors = storys,
                                                  floor_to_floor_height = 3.8,
                                                  plenum_height = 1.0,
                                                  perimeter_zone_depth = 4.57)
          # Dump model
          BTAP::FileIO::save_osm(model, File.join(File.dirname(__FILE__), "../local_test_output", "Lshape.osm"))

          # Test the model is correctly defined.
          # Floor area.
          correct_floor_area = (length * width * storys * 5.0 / 9.0).round(1)
          msg = "floor area for case: #{caseDescription}"
          assert_in_delta(correct_floor_area, model.getBuilding.floorArea.to_f.round(1), 0.1, 'floor area')

          # Get the exterior walls and check boundary conditions and areas.
          extWalls = model.getBuilding.exteriorWalls
          number_of_ext_walls = 6 * storys
          msg = "number of above grade exterior walls for case: #{caseDescription}"
          assert_equal(number_of_ext_walls, extWalls.count, 'number of exterior walls')
          ext_wall_area = 0.0
          extWalls.each do |wall|
            msg = "wall boundary condition for case: #{caseDescription}"
            assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, 'wall boundary condition')
            ext_wall_area += wall.netArea
          end
          correct_ext_wall_area = (3.8 * (length + width) * 2 * storys).round(1)
          msg = "total exterior wall area for case: #{caseDescription}"
          assert_in_delta(correct_ext_wall_area, ext_wall_area.round(1), 0.1, 'total exterior wall area (1)')
          assert_in_delta(correct_ext_wall_area, model.getBuilding.exteriorWallArea.to_f.round(1), 0.1, 'total exterior wall area (2)')

          # Get the roof surfaces and check boundary conditions and areas.
          roofs = model.getBuilding.roofs
          number_of_roofs = 8
          msg = "number of roof surfaces for case: #{caseDescription}"
          assert_equal(number_of_roofs, roofs.count, 'number of roof surfaces')
          roof_area = 0.0
          roofs.each do |roof|
            msg = "roof boundary condition for case: #{caseDescription}"
            assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, 'roof boundary condition')
            roof_area += roof.netArea
          end
          correct_roof_area = (length * width * 5.0 / 9.0).round(1)
          msg = "total roof area for case: #{caseDescription}"
          assert_in_delta(correct_roof_area, roof_area.round(1), 0.1, 'total roof area')
          assert_in_delta(correct_ext_wall_area + correct_roof_area, model.getBuilding.exteriorSurfaceArea.to_f.round(1), 0.1, 'total exterior surface area')

          # Total exterior area.
          msg = "total exterior surface area for case: #{caseDescription}"
          assert_in_delta((correct_ext_wall_area + correct_roof_area).to_f.round(2), model.getBuilding.exteriorSurfaceArea.to_f.round(2), 0.1, msg)

          # Ground connections
          ground_area = 0.0
          model.getBuilding.spaces.each do |space|
            space.surfaces.each do |surface|
              ground_area += surface.netArea if surface.outsideBoundaryCondition == "Ground"
            end
          end
          correct_ground_area = (length * width * 5.0 / 9.0).round(1)
          msg = "total ground area for case: #{caseDescription}"
          assert_in_delta(correct_ground_area, ground_area.round(1), 0.1, 'total ground area')

        end
      end
    end
  end

  # Loop through a range of geometry options and check floor areas and boundary conditions sucessfully set
  def test_geometry_Tshape
    [25, 100].each do |length|
      [20, 80].each do |width|
        [1, 5].each do |storys|

            caseDescription = "length(#{length}), width(#{width}), storys(#{storys})"

            # Create a new model object.
            model = OpenStudio::Model::Model.new

            # Create a Tshape model
            BTAP::Geometry::Wizards::create_shape_t(model,
                                                    length = length,
                                                    width = width,
                                                    upper_end_width = width / 3.0,
                                                    lower_end_length = length / 3.0,
                                                    left_end_offset = 10.0,
                                                    num_floors = storys,
                                                    floor_to_floor_height = 3.8,
                                                    plenum_height = 1.0,
                                                    perimeter_zone_depth = 1.0)


            # Dump model
            BTAP::FileIO::save_osm(model, File.join(File.dirname(__FILE__), "../local_test_output", "Tshape.osm"))

            # Test the model is correctly defined.
            # Floor area.
            correct_floor_area = (length * width * 5.0 / 9.0 * (storys)).round(1)
            msg = "floor area for case: #{caseDescription}"
            assert_in_delta(correct_floor_area, model.getBuilding.floorArea.to_f.round(1), 0.1, msg)

            # Get the exterior walls and check boundary conditions and areas.
            extWalls = model.getBuilding.exteriorWalls
            number_of_ext_walls = 8 * storys
            msg = "number of above grade exterior walls for case: #{caseDescription}"
            assert_equal(number_of_ext_walls, extWalls.count, msg)

            ext_wall_area = 0.0
            extWalls.each do |wall|
              msg = "wall boundary condition for case: #{caseDescription}"
              assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, msg)
              ext_wall_area += wall.netArea
            end
            correct_ext_wall_area = (3.8 * (length + width) * 2 * storys).round(1)
            msg = "total exterior wall area for case: #{caseDescription}"
            assert_in_delta(correct_ext_wall_area, ext_wall_area.round(1), 0.1, msg)

            # Get the roof surfaces and check boundary conditions and areas.
            roofs = model.getBuilding.roofs
            number_of_roofs = 10
            msg = "number of roof surfaces for case: #{caseDescription}"
            assert_equal(number_of_roofs, roofs.count, msg)
            roof_area = 0.0
            roofs.each do |roof|
              msg = "roof boundary condition for case: #{caseDescription}"
              assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, msg)
              roof_area += roof.netArea
            end
            correct_roof_area = (length * width * 5.0 / 9.0).round(1)
            msg = "total roof area for case: #{caseDescription}"
            assert_in_delta(correct_roof_area, roof_area.round(1), 0.1, msg)

            # Total exterior area.
            msg = "total exterior surface area for case: #{caseDescription}"
            assert_in_delta((correct_ext_wall_area + correct_roof_area).to_f.round(2), model.getBuilding.exteriorSurfaceArea.to_f.round(2), 0.1, msg)

            # Ground connections
            ground_area = 0.0
            model.getBuilding.spaces.each do |space|
              space.surfaces.each do |surface|
                ground_area += surface.netArea if surface.outsideBoundaryCondition == "Ground"
              end
            end
            correct_ground_area = (length * width * 5.0 / 9.0).round(1)
            msg = "total ground area for case: #{caseDescription}"
            assert_in_delta(correct_ground_area, ground_area.round(1), 0.1, msg)

          end
        end
      end
     end

  # Loop through a range of geometry options and check floor areas and boundary conditions sucessfully set
  def test_geometry_Hshape
    [25, 100].each do |length|
      [20, 80].each do |width|
        [1, 5].each do |storys|

          caseDescription = "length(#{length}), width(#{width}), storys(#{storys})"

          # Create a new model object.
          model = OpenStudio::Model::Model.new

          # Create a H-shape model
          BTAP::Geometry::Wizards::create_shape_h(model,
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
                                                  perimeter_zone_depth = 0.2)

          # Dump model
          BTAP::FileIO::save_osm(model, File.join(File.dirname(__FILE__), "../local_test_output", "Hshape.osm"))

          # Test the model is correctly defined.
          # Floor area.
          correct_floor_area = (length * width * 7.0 / 9.0 *(storys.to_f)).round(1)
          msg = "floor area for case: #{caseDescription}"
          assert_in_delta(correct_floor_area, model.getBuilding.floorArea.to_f.round(1), 0.1, msg)

          # Get the exterior walls and check boundary conditions and areas.
          extWalls = model.getBuilding.exteriorWalls
          number_of_ext_walls = 12 * storys
          msg = "number of above grade exterior walls for case: #{caseDescription}"
          assert_equal(number_of_ext_walls, extWalls.count, msg)

          ext_wall_area = 0.0
          extWalls.each do |wall|
            msg = "wall boundary condition for case: #{caseDescription}"
            assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, msg)
            ext_wall_area += wall.netArea
          end
          correct_ext_wall_area = (3.8 * ((10.0/3.0 * width) + (2 * length)) * storys).round(1)
          msg = "total exterior wall area for case: #{caseDescription}"
          assert_in_delta(correct_ext_wall_area, ext_wall_area.round(1), 0.1, msg)

          # Get the roof surfaces and check boundary conditions and areas.
          roofs = model.getBuilding.roofs
          number_of_roofs = 15
          msg = "number of roof surfaces for case: #{caseDescription}"
          assert_equal(number_of_roofs, roofs.count, msg)
          roof_area = 0.0
          roofs.each do |roof|
            msg = "roof boundary condition for case: #{caseDescription}"
            assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, msg)
            roof_area += roof.netArea
          end
          correct_roof_area = (length * width * 7.0 / 9.0).round(1)
          msg = "total roof area for case: #{caseDescription}"
          assert_in_delta(correct_roof_area, roof_area.round(1), 0.1, msg)

          # Total exterior area.
          msg = "total exterior surface area for case: #{caseDescription}"
          assert_in_delta((correct_ext_wall_area + correct_roof_area).to_f.round(2), model.getBuilding.exteriorSurfaceArea.to_f.round(2), 0.1, msg)

          # Ground connections
          ground_area = 0.0
          model.getBuilding.spaces.each do |space|
            space.surfaces.each do |surface|
              ground_area += surface.netArea if surface.outsideBoundaryCondition == "Ground"
            end
          end
          correct_ground_area = (length * width * 7.0 / 9.0).round(1)
          msg = "total ground area for case: #{caseDescription}"
          assert_in_delta(correct_ground_area, ground_area.round(1), 0.1, msg)

        end
      end
    end
  end


  # Loop through a range of geometry options and check floor areas and boundary conditions sucessfully set
  def test_geometry_Ushape
    [25, 100].each do |length|
      [20, 80].each do |width|
        [1, 5].each do |storys|

          caseDescription = "length(#{length}), width(#{width}), storys(#{storys})"

          # Create a new model object.
          model = OpenStudio::Model::Model.new

          # Create a U-shape model
          BTAP::Geometry::Wizards::create_shape_u(model,
                                                  length = length,
                                                  left_width = width,
                                                  right_width = width,
                                                  left_end_length = length / 3.0,
                                                  right_end_length = length / 3.0,
                                                  left_end_offset = width*(2.0/3.0),
                                                  num_floors = storys,
                                                  floor_to_floor_height = 3.8,
                                                  plenum_height = 1.0,
                                                  perimeter_zone_depth = 0.2)


          # Dump model
          BTAP::FileIO::save_osm(model, File.join(File.dirname(__FILE__), "../local_test_output", "test_Ushape.osm"))

          # Test the model is correctly defined.
          # Floor area.
          correct_floor_area = (length * width * 7.0 / 9.0 * (storys)).round(1)
          msg = "floor area for case: #{caseDescription}"
          assert_in_delta(correct_floor_area.to_f.round(1), model.getBuilding.floorArea.to_f.round(1), 0.1, msg)

          # Get the exterior walls and check boundary conditions and areas.
          extWalls = model.getBuilding.exteriorWalls
          number_of_ext_walls = 8 * storys
          msg = "number of above grade exterior walls for case: #{caseDescription}"
          assert_equal(number_of_ext_walls, extWalls.count, msg)

          ext_wall_area = 0.0
          extWalls.each do |wall|
            msg = "wall boundary condition for case: #{caseDescription}"
            assert_equal('Outdoors', wall.outsideBoundaryCondition.to_s, msg)
            ext_wall_area += wall.netArea
          end
          correct_ext_wall_area = (3.8 * ((10.0/3.0 * width) + (2 * length)) * storys).round(1)
          msg = "total exterior wall area for case: #{caseDescription}"
          assert_in_delta(correct_ext_wall_area, ext_wall_area.round(1), 0.1, msg)

          # Get the roof surfaces and check boundary conditions and areas.
          roofs = model.getBuilding.roofs
          number_of_roofs = 11
          msg = "number of roof surfaces for case: #{caseDescription}"
          assert_equal(number_of_roofs, roofs.count, msg)
          roof_area = 0.0
          roofs.each do |roof|
            msg = "roof boundary condition for case: #{caseDescription}"
            assert_equal('Outdoors', roof.outsideBoundaryCondition.to_s, msg)
            roof_area += roof.netArea
          end
          correct_roof_area = (length * width * 7.0 / 9.0).round(1)
          msg = "total roof area for case: #{caseDescription} : #{length} , #{length * width * 7.9/ 9.0}"
          assert_in_delta(correct_roof_area, roof_area.round(1), 0.1, msg)

          # Total exterior area.
          msg = "total exterior surface area for case: #{caseDescription}"
          assert_in_delta((correct_ext_wall_area + correct_roof_area).to_f.round(2), model.getBuilding.exteriorSurfaceArea.to_f.round(2), 0.1, msg)

          # Ground connections
          ground_area = 0.0
          model.getBuilding.spaces.each do |space|
            space.surfaces.each do |surface|
              ground_area += surface.netArea if surface.outsideBoundaryCondition == "Ground"
            end
          end
          correct_ground_area = (length * width* 7.0 / 9.0).round(1)
          msg = "total ground area for case: #{caseDescription}"
          assert_in_delta(correct_ground_area, ground_area.round(1), 0.1, msg)

        end
      end
    end
  end

end


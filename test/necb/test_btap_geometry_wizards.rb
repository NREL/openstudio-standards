require_relative '../helpers/minitest_helper'

#Test Geometry Wizards
class TestBTAPGeometryWizards < MiniTest::Test

  # Loop through a range of geometry options and check floor areas and boundary conditions sucessfully set
  def test_geometry_rectangle
    for length in [25, 100] do
      for width in [20, 80] do
        for storys in [1, 15] do
      
          # Create a new model object.
          model = OpenStudio::Model::Model.new

          # Create a rectangular model
          BTAP::Geometry::Wizards::create_shape_rectangle(model, 
            length = length, 
            width = width, 
            above_ground_storys = storys, 
            under_ground_storys = 0, 
            floor_to_floor_height = 3.8, 
            plenum_height = 1.0, 
            perimeter_zone_depth = 4.57, 
            initial_height = 0.0)
        
          correct_floor_area = length*width*storys
          assert_in_epsilon(correct_floor_area, model.getBuilding.floorArea.to_f.round(1), 0.1, 'floor area')
    
    
        end
      end
    end
  end
  
  
  def test_geometry_courtyard
    for length in [50, 100] do
      for width in [200, 80] do
        for storys in [1, 5] do
      
          # Create a new model object.
          model = OpenStudio::Model::Model.new
    
          # Create a courtyard model
          BTAP::Geometry::Wizards::create_shape_courtyard(model, 
            length = length, 
            width = width, 
            courtyard_length = length/3, 
            courtyard_width = width/3, 
            above_ground_storys = storys, 
            floor_to_floor_height = 3.8, 
            plenum_height = 1.0, 
            perimeter_zone_depth = 4.57)
        
          correct_floor_area = length*width*storys*8/9
          assert_in_epsilon(correct_floor_area, model.getBuilding.floorArea.to_f.round(1), 0.1, 'floor area')
    
        end
      end
    end
  end
end

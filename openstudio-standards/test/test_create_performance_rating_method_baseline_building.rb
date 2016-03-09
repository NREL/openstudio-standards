require_relative 'minitest_helper'
require_relative 'create_performance_rating_method_helper'

class CreatePerformanceRatingMethodBaselineBuildingTest < Minitest::Test

  def test_901_2013_sec_school
  
    # Create the baseline model
    model = create_baseline_model('SecondarySchool-DOE Ref Pre-1980-ASHRAE 169-2006-2A', '90.1-2013', 'ASHRAE 169-2006-2A', 'SecondarySchool', false)
  
    # Conditions expected to be true in the baseline model
    
    # Lighting power densities
    
    # Classroom LPD should be 1.24 W/ft2
    space = model.getSpaceByName("Corner_Class_1_Pod_1_ZN_1_FLR_1").get
    lpd_w_per_m2 = space.lightingPowerPerFloorArea
    lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
    #               (expected, actual, tolerance, message to show if it fails) 
    assert_in_delta(1.24, lpd_w_per_ft2, 0.01, "Classroom LPD is wrong.")
    
    # Example of a failing assertion
    # Gym LPD should be 1.24 W/ft2
    space = model.getSpaceByName("Gym_ZN_1_FLR_1").get
    lpd_w_per_m2 = space.lightingPowerPerFloorArea
    lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
    assert_in_delta(1.24, lpd_w_per_ft2, 0.01, "Gymnasium LPD is wrong.")    
    
  end

end
require_relative 'minitest_helper'
require_relative 'create_ecbc_baseline_helper'

class BaselineECBCTest < Minitest::Test

  # Create a baseline model for bldg_1
  def test_lpd_bldg1

    model = create_ecbc_baseline_model('bldg_1', 'ECBC 2007', 'ECBC Warm and Humid', 'MediumOffice', nil, false, true)
   
    # Assertions about the baseline model go here
	
	# Open Office - Lobby LPD should be 1.3 W/ft2
  
    space = model.getSpaceByName("Lobby 1").get
    lpd_w_per_m2 = space.lightingPowerPerFloorArea
    lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
    assert_in_delta(1.3, lpd_w_per_ft2, 0.01, "Open Office Lobby LPD is wrong.") #The measure did this correctly

  end 
  
 end



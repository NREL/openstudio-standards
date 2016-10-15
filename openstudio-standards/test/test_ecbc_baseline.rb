require_relative 'minitest_helper'
require_relative 'create_ecbc_baseline_helper'

class BaselineECBCTest < Minitest::Test

  # Create a baseline model for bldg_1
  def test_lpd_bldg1

    model = create_ecbc_baseline_model('bldg_1', 'ECBC 2007', 'ECBC Warm and Humid', 'MediumOffice', nil, false, true)
   
    # Assertions about the baseline model go here

  end 

end

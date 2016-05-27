require_relative 'minitest_helper'
require_relative 'create_performance_rating_method_helper'

class CreatePerformanceRatingMethodBaselineBuildingTest < Minitest::Test

  def dont_test_901_2013_sec_school
  
    # Create the baseline model
    model, errs = create_baseline_model('SecondarySchool-DOE Ref Pre-1980-ASHRAE 169-2006-2A', '90.1-2013', 'ASHRAE 169-2006-2A', 'SecondarySchool', 'Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

    # Conditions expected to be true in the baseline model
    
    # Lighting power densities
    
    # Classroom LPD should be 1.24 W/ft2
    space = model.getSpaceByName("Corner_Class_1_Pod_1_ZN_1_FLR_1").get
    lpd_w_per_m2 = space.lightingPowerPerFloorArea
    lpd_w_per_ft2 = OpenStudio.convert(lpd_w_per_m2,'W/m^2','W/ft^2').get
    #               (expected, actual, tolerance, message to show if it fails) 
    assert_in_delta(1.24, lpd_w_per_ft2, 0.01, "Classroom LPD is wrong.")
      
  end

  def dont_test_bldg_1_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_1', '90.1-2013', 'ASHRAE 169-2006-5B', 'SecondarySchool','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end  
  
  def dont_test_bldg_2_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_2', '90.1-2013', 'ASHRAE 169-2006-5B', 'SecondarySchool','Xcel Energy CO EDA', false)
 
    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end

  def dont_test_bldg_3_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_3', '90.1-2013', 'ASHRAE 169-2006-5B', 'SecondarySchool','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")
    
  end  
  
  def dont_test_bldg_4_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_4', '90.1-2013', 'ASHRAE 169-2006-5B', 'SecondarySchool','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end  
  
  def dont_test_bldg_5_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_5', '90.1-2013', 'ASHRAE 169-2006-5B', 'SecondarySchool','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end  
  
  def dont_test_bldg_6_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_6', '90.1-2013', 'ASHRAE 169-2006-5B', 'SecondarySchool','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end  
  
  def dont_test_bldg_7_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_7', '90.1-2013', 'ASHRAE 169-2006-5B', 'SecondarySchool','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")
    
  end  
  
  def dont_test_bldg_8_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_8', '90.1-2013', 'ASHRAE 169-2006-5B', 'SecondarySchool','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end  
  
  def dont_test_bldg_9_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_9', '90.1-2013', 'ASHRAE 169-2006-5B', 'MidriseApartment','Xcel Energy CO EDA', false)
 
    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end

  def dont_test_bldg_10_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_10', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")
    
  end  
  
  def dont_test_bldg_11_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_11', '90.1-2013', 'ASHRAE 169-2006-5B', 'LargeOffice','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end  
  
  def test_bldg_12_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_12', '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end  
  
  def dont_test_bldg_13_901_2013
  
    # Create the baseline model
    model, errs = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'Warehouse','Xcel Energy CO EDA', false)

    # Assert no errors
    assert(errs.size == 0, "Model created, but had Errors: #{errs.join(',')}")

  end
  
end
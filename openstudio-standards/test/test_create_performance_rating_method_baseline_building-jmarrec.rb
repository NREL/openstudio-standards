require_relative 'minitest_helper'
require_relative 'create_performance_rating_method_helper'

class CreatePerformanceRatingMethodBaselineBuildingTest < Minitest::Test

  def test_jmarrec_model

    # Create the baseline model
    model = create_baseline_model('jmarrec', '90.1-2007', 'ASHRAE 169-2006-4A', 'MidriseApartment', false)
  
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


  def test_performance_rating_method_baseline_system_groups

    # Make a directory to save the resulting models
    test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exists?(test_dir)
      Dir.mkdir(test_dir)
    end

    model_name = 'jmarrec'
    standard = '90.1-2007'

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/performance_rating_method/#{model_name}.osm")
    model = translator.loadModel(path)
    assert(model.is_initialized, "Could not load test model '#{model_name}.osm' from test_models/performance_rating_method.  Check name for typos.")
    model = model.get

    model.performance_rating_method_baseline_system_groups(standard)
    assert_in_delta(1.24, lpd_w_per_ft2, 0.01, "Gymnasium LPD is wrong.")


  end

end
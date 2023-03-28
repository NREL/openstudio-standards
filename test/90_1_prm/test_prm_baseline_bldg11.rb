require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013TestBldg11 < Minitest::Test

  include Baseline9012013

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_11_shw
 
    test_model_name = 'bldg_11'
    building_type = 'LargeOffice'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_shw(base_model, prop_model,building_type)
 
  end  
  
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def dont_dont_test_bldg_11_baseline_sys
 
    test_model_name = 'bldg_11'
    building_type = 'LargeOffice'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_baseline_system_type(base_model, prop_model, building_type, climate_zone)
 
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_11_num_boilers
 
    test_model_name = 'bldg_11'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'LargeOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_boilers(base_model, prop_model) 
 
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_11_num_chillers
 
    test_model_name = 'bldg_11'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'LargeOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_chillers(base_model, prop_model) 
 
  end
 
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_11_plant_controls
 
    test_model_name = 'bldg_11'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'LargeOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_plant_controls(base_model, prop_model) 
 
  end


end

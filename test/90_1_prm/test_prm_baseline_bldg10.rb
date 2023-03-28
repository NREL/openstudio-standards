require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013TestBldg10 < Minitest::Test

  include Baseline9012013
  
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_shw

    test_model_name = 'bldg_10'
    building_type = 'MediumOffice'
    climate_zone = 'ASHRAE 169-2006-5B'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', climate_zone, building_type,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_shw(base_model, prop_model,building_type) 
    
  end  

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_purchased_energy

    test_model_name = 'bldg_10'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice' ,'Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_purchased_energy(base_model, prop_model) 
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_num_boilers
 
    test_model_name = 'bldg_10'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_boilers(base_model, prop_model) 
 
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_num_chillers
 
    test_model_name = 'bldg_10'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_num_chillers(base_model, prop_model) 
 
  end
 
  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_10_plant_controls
 
    test_model_name = 'bldg_10'

    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'MediumOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)
    
    check_plant_controls(base_model, prop_model)
 
  end 

end

require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013TestBldg13 < Minitest::Test

  include Baseline9012013

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_economizer

    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_economizers(base_model)
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_sat_delta

    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_sat_delta(base_model)
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_sat_reset
  
    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_sat_reset(base_model)
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_min_vav_setpoints

    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_min_vav_setpoints(base_model)
    
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_coil_efficiencies

    base_model = create_baseline_model('bldg_13', '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    check_coil_efficiencies(base_model)
  
  end

  # @author Matt Steen, Eric Ringold, Ambient Energy
  def test_bldg_13_ventilation_rates

    test_model_name = 'bldg_13'
    
    base_model = create_baseline_model(test_model_name, '90.1-2013', 'ASHRAE 169-2006-5B', 'SmallOffice','Xcel Energy CO EDA', false, true)
    prop_model = load_test_model(test_model_name)

    check_ventilation_rates(base_model, prop_model)    
  
  end 

end

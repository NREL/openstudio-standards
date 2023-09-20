require_relative '../helpers/minitest_helper'
require_relative 'create_performance_rating_method_helper'
require_relative 'baseline_901_2013_helper'

class Baseline9012013Test < Minitest::Test

  include Baseline9012013

  
 
  
   def test_midrise_prm

    base_model = create_baseline_model('MidRiseApt_2010_5A', '90.1-2013', 'ASHRAE 169-2013--5A', 'MidriseApartment', false, true)

  end
  

end

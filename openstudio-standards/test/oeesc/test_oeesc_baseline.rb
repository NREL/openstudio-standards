require_relative '../minitest_helper'
require_relative 'create_performance_rating_method_helper'

class OEESCBaselineTest < Minitest::Test

  def test_basic_creation

    model = create_baseline_model('bldg_1', 'OEESC 2014', 'ASHRAE 169-2006-5B', 'MediumOffice', nil, false, true)

    assert(model.getSpaces.size > 0, 'model has no spaces')

  end  

end

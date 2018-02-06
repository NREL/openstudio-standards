require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative './regression_helper'

class TestNECBSmallOffice < Minitest::Test
  def test_regression()
    result, msg = create_model_and_regression_test('SmallOffice',
                                                   'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw',
                                                   'NECB 2011'
    )
    assert(result, msg)
  end
end


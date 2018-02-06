require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative './regression_helper'

class TestNECBLargeHotel < Minitest::Test
  create_model_and_regression_test('LargeHotel',
                                   ['CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'],
                                   ['NECB 2011']
  )
end

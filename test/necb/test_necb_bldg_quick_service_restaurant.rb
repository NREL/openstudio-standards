require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative './regression_helper'

class TestNECBQuickServiceRestaurant < NECBRegressionHelper
  def setup()
    super()
    @building_type = 'QuickServiceRestaurant'
  end
end



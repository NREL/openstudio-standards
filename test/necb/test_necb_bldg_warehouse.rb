require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative './regression_helper'

class TestNECBWarehouse < NECBRegressionHelper
  def setup()
    super()
    @building_type = 'Warehouse'
  end
end






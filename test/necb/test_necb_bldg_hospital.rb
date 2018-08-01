require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative './regression_helper'

class TestNECBHospital < NECBRegressionHelper
  def setup()
    super()
    @building_type = 'Hospital'
  end
  def test_necb_2011_Hospital_regression_natural_gas()
    result, msg = create_model_and_regression_test(@building_type,
                                                   @gas_location,
                                                   'NECB2011'
    )
    assert(result, msg)
  end
  def test_necb_2011_Hospital_regression_electric()
    result, msg = create_model_and_regression_test(@building_type,
                                                   @electric_location,
                                                   'NECB2011'
    )
    assert(result, msg)
  end

  def test_necb_2015_Hospital_regression_natural_gas()
    result, msg = create_model_and_regression_test(@building_type,
                                                   @gas_location,
                                                   'NECB2015'
    )
    assert(result, msg)
  end
  def test_necb_2015_Hospital_regression_electric()
    result, msg = create_model_and_regression_test(@building_type,
                                                   @electric_location,
                                                   'NECB2015'
    )
    assert(result, msg)
  end
end


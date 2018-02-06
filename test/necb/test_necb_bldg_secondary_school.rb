require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative './regression_helper'

class TestNECBSecondarySchool < Minitest::Test

  def setup()
    @building_type = 'SecondarySchool'
    @gas_location = 'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'
    @electric_location = 'CAN_QC_Kuujjuaq.AP.719060_CWEC2016.epw'
  end

  def test_regression_natural_gas()
    result, msg = create_model_and_regression_test(@building_type,
                                                   @gas_location,
                                                   'NECB 2011'
    )
    assert(result, msg)
  end

  def test_regression_electric()
    result, msg = create_model_and_regression_test(@building_type,
                                                   @electric_location,
                                                   'NECB 2011'
    )
    assert(result, msg)
  end
end


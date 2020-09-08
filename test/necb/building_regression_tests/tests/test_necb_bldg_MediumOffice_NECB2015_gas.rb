require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/compare_models_helper'
require_relative '../resources/regression_helper'

class Test_MediumOffice_NECB2015_gas < NECBRegressionHelper
  def setup()
    super()
  end
  def test_NECB2015_MediumOffice_regression_gas()
    result, diff = create_model_and_regression_test(building_type: 'MediumOffice',epw_file: @gas_location,template: 'NECB2015')
    if result == false
      puts "JSON terse listing of diff-errors."
      puts diff
      puts "Pretty listing of diff-errors for readability."
      puts JSON.pretty_generate( diff )
      puts "You can find the saved json diff file here test/necb/regression_models/MediumOffice-NECB2015-#\{@gas_location\%>.epw_diffs.json"
      puts "outputing errors here. "
      puts diff["diffs-errors"] if result == false
    end
    assert(result, diff)
  end
end
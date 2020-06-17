require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/compare_models_helper'
require_relative '../resources/regression_helper'

class Test_SecondarySchool_BTAP1980TO2010_NaturalGas < NECBRegressionHelper
  def setup()
    super()
  end
  def test_BTAP1980TO2010_SecondarySchool_regression_NaturalGas()
    result, diff = create_model_and_regression_test(building_type: 'SecondarySchool',primary_heating_fuel: 'NaturalGas', epw_file:  'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw',template: 'BTAP1980TO2010', run_simulation: @run_simulation)
    if result == false
      puts "JSON terse listing of diff-errors."
      puts diff
      puts "Pretty listing of diff-errors for readability."
      puts JSON.pretty_generate( diff )
      puts "You can find the saved json diff file here test/necb/regression_models/SecondarySchool-BTAP1980TO2010-#\{@NaturalGas_location\%>.epw_diffs.json"
      puts "outputing errors here. "
      puts diff["diffs-errors"] if result == false
    end
    assert(result, diff)
  end
end
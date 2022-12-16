require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/compare_models_helper'
require_relative '../resources/regression_helper' 

class Test_EdgeCaseGeometry_NECB2011_Electricity_iteration13 < NECBRegressionHelper 

  def setup()
    super()
  end

  def test_NECB2011_EdgeCaseGeometry_regression_Electricity_iteration13()
    result, diff = create_iterative_model_and_regression_test(building_type: 'EdgeCaseGeometry',
                                                              primary_heating_fuel: Electricity,
                                                              epw_file:  'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw',
                                                              template: NECB2011,
                                                              run_simulation: true,
                                                              iteration: 13
    )
  if result == false
    puts "JSON terse listing of diff-errors."
    puts diff
    puts "Pretty listing of diff-errors for readability."
    puts JSON.pretty_generate( diff )
    puts "You can find the saved json diff file under the /expected_results folder.
    puts "outputing errors here. "
    puts diff["diffs-errors"] if result == false
  end
  assert(result, diff)  end
end
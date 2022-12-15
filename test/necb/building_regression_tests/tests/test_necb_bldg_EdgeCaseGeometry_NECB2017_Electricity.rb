require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/compare_models_helper'
require_relative '../resources/regression_helper'

class Test_EdgeCaseGeometry_NECB2017_Electricity < NECBRegressionHelper

  def setup
    super()
  end

  # Use this code to test a single iteration
  test_single_iteration = false
  single_iteration = nil

  primary_heating_fuel = "Electricity"
  template = "NECB2017"

  ## There are 22 [0 to 21] iterations in the NECB2017 test set
  (0..21).each do |iteration|
    if test_single_iteration
      unless iteration == single_iteration
        next
      end
    end

    define_method("test_#{template}_EdgeCaseGeometry_regression_#{primary_heating_fuel}_iteration#{iteration}") do
      # begin
      result, diff = create_iterative_model_and_regression_test(building_type: 'EdgeCaseGeometry',
                                                                primary_heating_fuel: primary_heating_fuel,
                                                                epw_file:  'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw',
                                                                template: template,
                                                                run_simulation: true,
                                                                iteration: iteration
      )
      if result == false
        puts "JSON terse listing of diff-errors."
        puts diff
        puts "Pretty listing of diff-errors for readability."
        puts JSON.pretty_generate( diff )
        puts "You can find the saved json diff file here test/necb/regression_models/FullServiceRestaurant-BTAP1980TO2010-Electricity_CAN_AB_Calgary.Intl.AP.718770_CWEC2016_diffs.json"
        puts "outputing errors here. "
        puts diff["diffs-errors"] if result == false
      end
      assert(result, diff)
    end
  end

end
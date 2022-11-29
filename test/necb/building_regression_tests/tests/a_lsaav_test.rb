# require 'minitest/autorun'
# require 'json'
require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/compare_models_helper'
require_relative '../resources/regression_helper'

class A_Lsaav_Test < NECBRegressionHelper
  iterations = []
  def setup
    # Do nothing
    # Setup JSON
    super()
  end

  def test_a_lsaav(run_single_iteration = 9)
    # Loop through every test set
    begin
      for iteration in 0..15 do

        unless run_single_iteration.nil?
          unless iteration == run_single_iteration
            next
          end
        end

        result, diff = create_iterative_model_and_regression_test(building_type: 'EdgeCaseGeometry',
                                                                  primary_heating_fuel: 'Electricity',
                                                                  epw_file:  'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw',
                                                                  template: 'NECB2011',
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
    rescue => exception
      # Log error/exception and then keep going.
      puts("There was an error with iteration #{iteration}")
    end
  end
end

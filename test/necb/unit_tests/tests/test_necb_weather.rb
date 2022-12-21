require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

#This test verifies that we can read in the weatherfile data from all the
# epw/stat files.
class NECB_Weather_Tests < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Tests to ensure that the NECB default schedules are being defined correctly.
  # This is not for compliance, but for archetype development. This will compare
  # to values in an excel/csv file stored in the weather folder.
  # NECB2011 8.4.2.3
  # @return [Bool] true if successful.
  def test_weather_reading()
    #todo Must deal with ground temperatures..They are currently not correct for NECB.
    test_results = File.join(@test_results_folder,'weather_test_results.json')
    expected_results = File.join(@expected_results_folder,'weather_expected_results.json')
    weather_file_folder = File.join(@root_folder,'data','weather')
    puts weather_file_folder
    BTAP::Environment::create_climate_json_file(
        weather_file_folder,
        test_results
    )
 
    # Check if test results match expected.
    msg = "Weather output does not match what is expected in test"
    file_compare(expected_results_file: expected_results, test_results_file: test_results, msg: msg)
  end
end
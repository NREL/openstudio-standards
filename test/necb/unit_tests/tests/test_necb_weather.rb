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
  # @return [Boolean] true if successful.
  def test_weather_reading()
    #todo Must deal with ground temperatures..They are currently not correct for NECB.
    test_results = File.join(@test_results_folder,'weather_test_results.json')
    expected_results = File.join(@expected_results_folder,'weather_expected_results.json')
    expected_results_download = File.join(@expected_results_folder,'weather_expected_results_download.json')


    weather_file_folder = File.join(@root_folder,'data','weather')
    puts weather_file_folder
    
    BTAP::Environment::create_climate_json_file(
        weather_file_folder,
        test_results
    )

    # If the test_necb_weather_file_download.rb test is run before this test then this test will read additional weather
    # files changing the test result output file and causing this test to fail.  Adding two sets of test results.  One
    # that include the download test results and another that does not include the download test results.
    # This is not good as it relies on another test. WOuld be good to decouple and use the standard file_compare method in the helper.
    test = FileUtils.compare_file(expected_results, test_results)
    if test
      assert(test, "Weather output from test does not match what is expected. Compare #{expected_results} with #{test_results}")
    else
      test = FileUtils.compare_file(expected_results_download, test_results)
      assert(test, "Weather output from test does not match what is expected from downloaded file. Compare #{expected_results_download} with #{test_results}")
    end
  end
end
require_relative '../../../helpers/minitest_helper'


#This test verifies that we can read in the weatherfile data from all the
# epw/stat files.
class NECB_Weather_Tests < Minitest::Test

  def setup()
    @file_folder = __dir__
    @test_folder = File.join(@file_folder, '..')
    @root_folder = File.join(@test_folder, '../../../')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = "#{@test_folder}/output/"
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

    test = FileUtils.compare_file(expected_results, test_results)

    assert( test ,
            "Weather output from test does not match what is expected. Compare #{File.join(File.dirname(__FILE__),'data','weather_expected_results.json')} with #{File.join(File.dirname(__FILE__),'data','weather_test_results.json')}"
    )
  end
end
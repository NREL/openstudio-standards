require_relative '../helpers/minitest_helper'


#This test verifies that we can read in the weatherfile data from all the 
# epw/stat files.
class WeatherTests < Minitest::Test
  # Tests to ensure that the NECB default schedules are being defined correctly.
  # This is not for compliance, but for archetype development. This will compare
  # to values in an excel/csv file stored in the weather folder.
  # NECB 2011 8.4.2.3 
  # @return [Bool] true if successful. 
  def test_weather_reading()
    #todo Must deal with ground temperatures..They are currently not correct for NECB.
    BTAP::Environment::create_climate_index_file(
      File.join(File.dirname(__FILE__),'../../','data','weather'), 
      File.join(File.dirname(__FILE__),'data','weather_test_results.csv') 
    )
    
    test = FileUtils.compare_file(
        File.join(File.dirname(__FILE__),'data','weather_expected_results.csv'), 
        File.join(File.dirname(__FILE__),'data','weather_test_results.csv') )
      
    assert( test ,
        "Weather output from test does not match what is expected. Compare #{File.join(File.dirname(__FILE__),'data','weather_expected_results.csv')} with #{File.join(File.dirname(__FILE__),'data','weather_test_results.csv')}"
    )
  end
end

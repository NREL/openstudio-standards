require_relative 'minitest_helper'


#This test verifies that we can read in the weatherfile data from all the 
# epw/stat files.
class WeatherTests < Minitest::Test
  # Tests to ensure that the NECB default schedules are being defined correctly.
  # This is not for compliance, but for archetype development. This will compare
  # to values in an excel/csv file stored in the weather folder.
  # NECB 2011 8.4.2.3 
  # @return [Bool] true if successful. 
  def test_weather_reading()
    BTAP::Environment::create_climate_index_file(
      File.join(File.dirname(__FILE__),'..','data','weather'), 
      File.join(File.dirname(__FILE__),'weather_test.csv') 
    )
    assert ( 
      FileUtils.compare_file(File.join(File.dirname(__FILE__),'..','data','weather','weather_info.csv'), 
        File.join(File.dirname(__FILE__),'weather_test.csv'))
    )
  end
end

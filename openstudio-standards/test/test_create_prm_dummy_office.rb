require_relative 'minitest_helper'
require_relative 'create_performance_rating_method_helper'

class CreatePerformanceRatingMethodBaselineBuildingTest < Minitest::Test


  def test_dummy_office_building


    model = create_baseline_model('dummy_office_building', '90.1-2007', 'ASHRAE 169-2006-4A', 'MediumOffice', false)

    model.getPlantLoops.each do |loop|

      total_rated_w_per_gpm = loop.total_rated_w_per_gpm

      loop_type = loop.sizingPlant.loopType

      case loop_type
        when 'Cooling'
          assert_in_delta(22, total_rated_w_per_gpm, 0.1, "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM when 22 W/GPM was expected")
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM (22 W/GPM expected)")
        when 'Heating'
          assert_in_delta(19, total_rated_w_per_gpm, 0.1, "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM when 19 W/GPM was expected")
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM (19 W/GPM expected)")
        when 'Condenser'
          assert_in_delta(19, total_rated_w_per_gpm, 0.1, "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM when 19 W/GPM was expected")
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "'#{loop.name}' of type '#{loop_type}' has a pump power of #{total_rated_w_per_gpm.round(2)} W/GPM (19 W/GPM expected)")
        else
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.standards.Model', "Loop #{loop.name} has a type of '#{loop_type}' that isn't recognized/handled!")
      end

    end


    sql = model.sqlFile

    if sql.is_initialized
      sql = sql.get

      # Check unmet hours
      unmet_query = "SELECT Value FROM TabularDataWithStrings WHERE
    ReportName='AnnualBuildingUtilityPerformanceSummary' AND
    TableName='Comfort and Setpoint Not Met Summary' AND
    RowName='%{row_name}'"
      unmet_heating_hours = sql.execAndReturnFirstDouble(unmet_query % {:row_name => 'Time Setpoint Not Met During Occupied Heating'}).get
      unmet_cooling_hours = sql.execAndReturnFirstDouble(unmet_query % {:row_name => 'Time Setpoint Not Met During Occupied Cooling'}).get


      puts "Unmet heating hours: #{unmet_heating_hours}"
      puts "Unmet cooling hours: #{unmet_cooling_hours}"

      assert(unmet_heating_hours<300,"Unmet heating hours are above 300: #{unmet_heating_hours}")
      assert(unmet_cooling_hours<300,"Unmet cooling hours are above 300: #{unmet_cooling_hours}")

    end
  end

end
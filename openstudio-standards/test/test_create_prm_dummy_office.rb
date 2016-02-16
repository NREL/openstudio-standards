require_relative 'minitest_helper'
require_relative 'create_performance_rating_method_helper'

class CreatePerformanceRatingMethodBaselineBuildingTest < Minitest::Test


  def test_dummy_office_building

    model_name = 'dummy_office_building'
    standard = '90.1-2007'
    climate_zone = 'ASHRAE 169-2006-4A'
    model = create_baseline_model(model_name, standard, climate_zone, 'MediumOffice', false)

    # Do another sizing run just to check that the final values are actually correct
    # I realized when testing the pump power that it was fine per the previous sizing run, but the code was actually changing the values again, leading to wrong pumping power
    test_dir = "#{File.dirname(__FILE__)}/output"
    sizing_run_dir = "#{test_dir}/#{model_name}-#{standard}-#{climate_zone}"

    # Run sizing run with the HVAC equipment
    if model.runSizingRun("#{sizing_run_dir}/SizingRunFinalCheckOnly") == false
      return false
    end


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


    # Output fan rated w per cfm for each fan
    model.output_fan_report("#{sizing_run_dir}/fan_report.csv")

    sql = model.sqlFile

    if sql.is_initialized
      sql = sql.get

      unmet_heating_hours = sql.hoursHeatingSetpointNotMet.get
      unmet_cooling_hours = sql.hoursCoolingSetpointNotMet.get


      puts "Unmet heating hours: #{unmet_heating_hours}"
      puts "Unmet cooling hours: #{unmet_cooling_hours}"

      assert(unmet_heating_hours<300,"Unmet heating hours are above 300: #{unmet_heating_hours}")
      assert(unmet_cooling_hours<300,"Unmet cooling hours are above 300: #{unmet_cooling_hours}")

    end



  end

end
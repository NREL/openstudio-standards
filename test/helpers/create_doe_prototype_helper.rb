#require "#{File.dirname(__FILE__)}/btap"
require_relative 'compare_models_helper'



# Add a "dig" method to Hash to check if deeply nested elements exist
# From: http://stackoverflow.com/questions/1820451/ruby-style-how-to-check-whether-a-nested-hash-element-exists
class Hash
  def dig(*path)
    path.inject(self) do |location, key|
      location.respond_to?(:keys) ? location[key] : nil
    end
  end
end

# Create a base class for testing doe prototype buildings
class CreateDOEPrototypeBuildingTest < Minitest::Test
  attr_accessor :current_model

  def setup
    # Make a directory to save the resulting models
    @test_dir =  File.expand_path("#{__dir__}/../doe_prototype/output")
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end
    # Make a file to store the model energy comparisons
    @results_csv_file = "#{@test_dir}/prototype_buildings_results.csv"
    # Add a header row on file creation
    if !File.exist?(@results_csv_file)
      File.open(@results_csv_file, 'a') do |file|
        file.puts 'building_type,template,climate_zone,fuel_type,end_use,legacy_val,osm_val,percent_error,difference'
      end
    end
    # Make a file to store the model comparisons
    @compare_models_file = "#{@test_dir}/prototype_buildings_compare.log"
    # Add a header row on file creation
    if !File.exist?(@compare_models_file)
      File.open(@compare_models_file, 'a') do |file|
        file.puts 'Prototype Building Comparison Log'
      end
    end
    # Make a file that combines all the run logs
    @combined_results_log = "#{@test_dir}/prototype_buildings_run.log"
    if !File.exist?(@combined_results_log)
      File.open(@combined_results_log, 'a') do |file|
        file.puts "Started @ #{Time.new}"
      end
    end

  end

  # Dynamically create a test for each building type/template/climate zone
  # so that if one combo fails the others still run
  def CreateDOEPrototypeBuildingTest.create_run_model_tests(building_types,
      templates,
      climate_zones,
      epw_files,
      create_models = true,
      run_models = false,
      compare_results = false,
      debug = false,
      run_type = 'annual',
      compare_results_object_by_object = false)

    building_types.each do |building_type|
      templates.each do |template|
        climate_zones.each do |climate_zone|
          #need logic to go through weather files only for Canada's NECB2011. It will ignore the ASHRAE climate zone.
          if climate_zone == 'NECB HDD Method'
            epw_files.each do |epw_file|
              create_building(building_type, template, climate_zone, epw_file, create_models, run_models, compare_results, debug, run_type, compare_results_object_by_object)
            end
          else
            #otherwise it will go as normal with the american method and wipe the epw_file variable.
            epw_file = ""
            create_building(building_type, template, climate_zone, epw_file, create_models, run_models, compare_results, debug, run_type, compare_results_object_by_object)
          end
        end
      end
    end
  end

  def CreateDOEPrototypeBuildingTest.create_building(building_type,
      template,
      climate_zone,
      epw_file,
      create_models = true,
      run_models = false,
      compare_results = false,
      debug = false,
      run_type = 'annual',
      compare_results_object_by_object = false,
      test_name_prefix = '')

    method_name = nil
    case template
    when 'NECB2011'
      method_name = "test_#{test_name_prefix}#{building_type}-#{template}-#{climate_zone}-#{File.basename(epw_file.to_s,'.epw')}".gsub(' ','_').gsub('.','_')
    else
      method_name = "test_#{test_name_prefix}#{building_type}-#{template}-#{climate_zone}".gsub(' ','_')
    end


    define_method(method_name) do
      # Start time
      start_time = Time.new

      # Reset the log for this test
      reset_log

      # Paths for this test run

      model_name = nil
      case template
      when 'NECB2011'
        model_name = "#{building_type}-#{template}-#{climate_zone}-#{epw_file}"
      else
        model_name = "#{building_type}-#{template}-#{climate_zone}"
      end

      run_dir = "#{@test_dir}/#{test_name_prefix}#{model_name}"
      if !Dir.exists?(run_dir)
        Dir.mkdir(run_dir)
      end

      full_sim_dir = if run_type == 'dd-only'
                       "#{run_dir}/DsnDayRun"
                     else
                       "#{run_dir}/AnnualRun"
                     end
      idf_path_string = "#{run_dir}/#{model_name}.idf"
      idf_path = OpenStudio::Path.new(idf_path_string)
      osm_path_string = "#{run_dir}/#{model_name}.osm"
      osm_path = OpenStudio::Path.new(osm_path_string)
      sql_path_string = "#{full_sim_dir}/run/eplusout.sql"
      sql_path = OpenStudio::Path.new(sql_path_string)
      truth_osm_path_string = File.expand_path("#{__dir__}/../doe_prototype/regression_models/#{model_name}_expected_result.osm")

      model = nil

      # Make a standard
      prototype_creator = Standard.build("#{template}_#{building_type}")

      # Create the model, if requested
      if create_models
        model = prototype_creator.model_create_prototype_model(climate_zone, epw_file, run_dir)
        @current_model = model
        if model.is_a?(FalseClass)
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Model for #{template}_#{building_type} was not created successfully.")
        else
          output_variable_array =
              [
                  "Facility Total Electric Demand Power",
                  "Water Heater Gas Rate",
                  "Plant Supply Side Heating Demand Rate",
                  "Heating Coil Gas Rate",
                  "Cooling Coil Electric Power",
                  "Boiler Gas Rate",
                  "Heating Coil Air Heating Rate",
                  "Heating Coil Electric Power",
                  "Cooling Coil Total Cooling Rate",
                  "Water Heater Heating Rate",
                  "Zone Air Temperature",
                  "Water Heater Electric Power",
                  "Chiller Electric Power",
                  "Chiller Electric Energy",
                  "Cooling Tower Heat Transfer Rate",
                  "Cooling Tower Fan Electric Power",
                  "Cooling Tower Fan Electric Energy"
              ]
          BTAP::Reports::set_output_variables(model,"Hourly", output_variable_array)
          # BTAP::Reports::set_output_variables(model,"Hourly", output_variable_array)

          if run_type == 'dd-only'
            # Get summer and winter design days days/month
            sim_ctrl = model.getSimulationControl
            sim_ctrl.setRunSimulationforSizingPeriods(true)
            sim_ctrl.setRunSimulationforWeatherFileRunPeriods(false)
          end

          # Save the model
          model.save(osm_path, true)

          # Convert the model to energyplus idf
          forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
          idf = forward_translator.translateModel(model)
          idf.save(idf_path,true)
        end
      end

      # Run the simulation, if requested
      if run_models
        # Delete previous run directories if they exist
        FileUtils.rm_rf(full_sim_dir)

        # Load the model from disk if not already in memory
        if model.nil?
          model = prototype_creator.safe_load_model(osm_path_string)
        end

        if run_type == 'dd-only'
          # Get summer and winter design days days/month
          sim_ctrl = model.getSimulationControl
          sim_ctrl.setRunSimulationforSizingPeriods(true)
          sim_ctrl.setRunSimulationforWeatherFileRunPeriods(false)

          # Remove all meters
          model.getOutputMeters.each(&:remove)

          # EnergyPlus I/O Reference Manual, Table 5.3
          end_uses = ['InteriorLights', 'ExteriorLights', 'InteriorEquipment', 'ExteriorEquipment', 'Fans', 'Pumps', 'Heating', 'Cooling', 'HeatRejection', 'Humidifier', 'HeatRecovery', 'DHW', 'Cogeneration', 'Refrigeration', 'WaterSystems']

          # EnergyPLus I/O Reference Manual, Table 5.1
          fuels = ['Electricity', 'Gas', 'Gasoline', 'Diesel', 'Coal', 'FuelOil#1', 'FuelOil#2', 'Propane', 'OtherFuel1', 'OtherFuel2', 'Water', 'Steam', 'DistrictCooling', 'DistrictHeating', 'ElectricityPurchased', 'ElectricitySurplusSold', 'ElectricityNet']

          # Creating individual meters
          meters = end_uses.product fuels
          meters.each do |end_use, fuel|
            mtr = OpenStudio::Model::OutputMeter.new(model)
            mtr.setName(end_use + ":" + fuel)
            mtr.setReportingFrequency("Monthly")
          end

          prototype_creator.model_run_simulation_and_log_errors(model, full_sim_dir)
        else
          # Run the annual simulation
          prototype_creator.model_run_simulation_and_log_errors(model, full_sim_dir)
        end

      end

      # Compare simulation results, if requested
      result_diffs = []
      if compare_results
        # Load the model and sql file from disk if not already in memory
        if model.nil?
          model = prototype_creator.safe_load_model(osm_path_string)
          sql_file = OpenStudio::SqlFile.new(sql_path)
          model.setSqlFile(sql_file)
        end

        acceptable_error_percentage = 0.001
        rounding_tolerance = 3

        # Get the legacy simulation results
        legacy_values = prototype_creator.model_legacy_results_by_end_use_and_fuel_type(model, climate_zone, building_type, run_type)
        if legacy_values.nil?
          result_diffs << "Could not find legacy simulation results for #{building_type} #{template} #{climate_zone}, cannot compare results."
        else
          # Store the comparisons for viewing
          results_comparison = []
          results_comparison << ['Building Type', 'Template', 'Climate Zone', 'Fuel Type', 'End Use', 'Legacy Value', 'Current Value', 'Percent Error', 'Difference']

          # Get the current simulation results
          if run_type == 'dd-only'
            current_values = prototype_creator.model_dd_results_by_end_use_and_fuel_type(model)
          else
            current_values = prototype_creator.model_results_by_end_use_and_fuel_type(model)
          end

          # Get the osm values for all fuel type/end use pairs
          # and compare to the legacy simulation results
          total_legacy_energy = 0.0
          total_current_energy = 0.0
          total_legacy_water = 0.0
          total_current_water = 0.0
          current_values.each_key do |end_use_fuel_type|
            end_use = end_use_fuel_type.split('|')[0]
            fuel_type = end_use_fuel_type.split('|')[1]

            legacy_val = legacy_values["#{end_use}|#{fuel_type}"]
            current_val = current_values["#{end_use}|#{fuel_type}"]

            # round to nearest decimal place per the rounding tolerance
            legacy_val = legacy_val.round(rounding_tolerance)
            current_val = current_val.round(rounding_tolerance)

            # Add the energy to the total
            if fuel_type == 'Water'
              total_legacy_water += legacy_val
              total_current_water += current_val
            else
              total_legacy_energy += legacy_val
              total_current_energy += current_val
            end

            # Calculate the error and check if less than acceptable_error_percentage
            percent_error = nil
            add_to_results_comparison = true
            if current_val > 0 && legacy_val > 0
              # If both
              percent_error = ((current_val - legacy_val)/legacy_val) * 100
              if percent_error.abs > acceptable_error_percentage
                result_diffs << "#{building_type}-#{template}-#{climate_zone}-#{fuel_type}-#{end_use} Error = #{percent_error.round(4)}% (#{current_val}, #{legacy_val})"
              end
            elsif current_val > 0 && legacy_val.abs < 1e-6
              # The current model has a fuel/end use that the legacy model does not
              percent_error = 1000
              result_diffs << "#{building_type}-#{template}-#{climate_zone}-#{fuel_type}-#{end_use} Error = current model has extra fuel/end use that legacy model does not (#{current_val})"
            elsif current_val.abs < 1e-6 && legacy_val > 0
              # The current model has a fuel/end use that the legacy model does not
              percent_error = 1000
              result_diffs << "#{building_type}-#{template}-#{climate_zone}-#{fuel_type}-#{end_use} Error = current model is missing a fuel/end use that legacy model has (#{legacy_val})"
            else
              # Both current model and legacy model are == 0 for this fuel/end use, no error
              percent_error = 0
              add_to_results_comparison = false
            end

            if add_to_results_comparison
              results_comparison << [building_type, template, climate_zone, fuel_type, end_use, legacy_val.round(4), current_val.round(4), percent_error.round(4), (legacy_val-current_val).abs.round(4)]
            end
          end

          # Calculate the overall energy error
          total_energy_percent_error = nil
          if total_current_energy > 0 && total_legacy_energy > 0
            # If both
            total_energy_percent_error = ((total_current_energy - total_legacy_energy)/total_legacy_energy) * 100
            if total_energy_percent_error.abs > acceptable_error_percentage
              result_diffs << "#{building_type}-#{template}-#{climate_zone} *** Total Energy Error = #{total_energy_percent_error.round(2)}% ***"
            end
          elsif total_current_energy > 0 && total_legacy_energy == 0
            # The osm has a fuel/end use that the legacy idf does not
            total_energy_percent_error = 1000
            result_diffs << "#{building_type}-#{template}-#{climate_zone} *** Total Energy Error = osm has extra fuel/end use that legacy idf does not (#{total_current_energy})"
          elsif total_current_energy == 0 && total_legacy_energy > 0
            # The osm has a fuel/end use that the legacy idf does not
            total_energy_percent_error = 1000
            result_diffs << "#{building_type}-#{template}-#{climate_zone} *** Total Energy Error = osm is missing a fuel/end use that legacy idf has (#{total_legacy_energy})"
          else
            # Both osm and legacy are == 0 for, no error
            total_energy_percent_error = 0
            result_diffs << "#{building_type}-#{template}-#{climate_zone} *** Total Energy Error = both idf and osm don't use any energy."
          end

          results_comparison << [building_type, template, climate_zone, 'Total Energy', 'Total', total_legacy_energy.round(2), total_current_energy.round(2), total_energy_percent_error.round(2), (total_legacy_energy-total_current_energy).abs.round(2)]
        end

        # Write the results diffs to a file
        if results_comparison.size > 0
          diff_file_path = "#{run_dir}/compare_results.csv"
          CSV.open(diff_file_path, 'w') do |file|
            results_comparison.each do |line|
              file << line
            end
          end
        end
      end

      # Compare model object by object to regression model results, if requested
      model_diffs = []
      if compare_results_object_by_object
        # Load the model from disk if not already in memory
        if model.nil?
          model = prototype_creator.safe_load_model(osm_path_string)
        end

        # Load the truth model from disk and compare to the newly-created model
        if File.exist?(truth_osm_path_string)
          truth_model = prototype_creator.safe_load_model(truth_osm_path_string)
          # Remove unused resources to make comparison cleaner
          prototype_creator.model_remove_unused_resource_objects(truth_model)
          prototype_creator.model_remove_unused_resource_objects(model)
          model_diffs = compare_osm_files(truth_model, model)
        else
          model_diffs << "ERROR: could not find regression model at #{truth_osm_path_string}, did not compare models."
        end

        # Write the model diffs to a file
        if model_diffs.size > 0
          diff_file_path = "#{run_dir}/compare_models.log"
          File.open(diff_file_path, 'w') do |file|
            model_diffs.each do |diff|
              file.puts diff
            end
          end
        end
      end

      # Calculate run time
      run_time = Time.new - start_time

      # Report out errors
      log_file_path = "#{run_dir}/openstudio-standards.log"
      messages = log_messages_to_file(log_file_path, debug)
      errors = get_logs(OpenStudio::Error)

      # Copy errors to combined log file
      File.open(@combined_results_log, 'a') do |file|
        file.puts "\n"
        file.puts "************************************************************************"
        file.puts "*** #{model_name}, Time: #{run_time.round} sec ***"
        messages.each do |message|
          file.puts message
        end
      end

      # Copy comparison log to file
      if compare_results_object_by_object
        if model_diffs.size > 0
          File.open(@compare_models_file, 'a') do |file|
            file.puts "\n"
            file.puts "************************************************************************"
            file.puts "*** #{model_name}, Time: #{run_time.round} sec ***"
            model_diffs.each do |diff|
              file.puts diff
            end
          end
          puts model_diffs
        end
      end

      # Copy energy result difference to file
      if compare_results
        if result_diffs.size > 0
          CSV.open(@results_csv_file, 'a') do |file|
            results_comparison.drop(1).each do |line|
              file << line
            end
          end
          puts result_diffs
        end
      end

      # Assert if there were any errors
      assert(errors.size == 0, errors.reverse.join("\n"))

      # Assert if there were any differences in results
      assert(result_diffs.size == 0, result_diffs.join("\n"))

      # Assert if there were any differences in the models
      assert(model_diffs.size == 0, model_diffs.join("\n"))
    end
  end
end

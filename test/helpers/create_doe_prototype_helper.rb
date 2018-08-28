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
    @test_dir = "#{Dir.pwd}/output"
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end
    # Make a file to store the model comparisons
    @results_csv_file = "#{@test_dir}/prototype_buildings_results.csv"
    # Add a header row on file creation
    if !File.exist?(@results_csv_file)
      File.open(@results_csv_file, 'a') do |file|
        file.puts "building_type,template,climate_zone,fuel_type,end_use,legacy_val,osm_val,percent_error,difference,absolute_percent_error"
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
      run_models = true,
      compare_results = true,
      debug = false)

    building_types.each do |building_type|
      templates.each do |template|
        climate_zones.each do |climate_zone|
          #need logic to go through weather files only for Canada's NECB2011. It will ignore the ASHRAE climate zone.
          if climate_zone == 'NECB HDD Method'
            epw_files.each do |epw_file|
              create_building(building_type, template, climate_zone, epw_file, create_models, run_models, compare_results, debug )
            end 
          else
            #otherwise it will go as normal with the american method and wipe the epw_file variable. 
            epw_file = ""
            create_building(building_type, template, climate_zone, epw_file, create_models, run_models, compare_results, debug )
          end
        end
      end
    end
  end

  def CreateDOEPrototypeBuildingTest.create_building(building_type, 
      template, 
      climate_zone, 
      epw_file,
      create_models,
      run_models,
      compare_results,
      debug )

    method_name = nil
    case template
    when 'NECB2011'

      method_name = "test_#{building_type}-#{template}-#{climate_zone}-#{File.basename(epw_file.to_s,'.epw')}".gsub(' ','_').gsub('.','_')

    else
      method_name = "test_#{building_type}-#{template}-#{climate_zone}".gsub(' ','_')
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


      run_dir = "#{@test_dir}/#{model_name}"
      if !Dir.exists?(run_dir)
        Dir.mkdir(run_dir)
      end
      full_sim_dir = "#{run_dir}/AnnualRun"
      idf_path_string = "#{run_dir}/#{model_name}.idf"
      idf_path = OpenStudio::Path.new(idf_path_string)            
      osm_path_string = "#{run_dir}/#{model_name}.osm"
      osm_path = OpenStudio::Path.new(osm_path_string)
      sql_path_string = "#{full_sim_dir}/run/eplusout.sql"
      sql_path = OpenStudio::Path.new(sql_path_string)
      truth_osm_path_string = "#{Dir.pwd}/regression_models/#{model_name}.osm"
      truth_osm_path = OpenStudio::Path.new(truth_osm_path_string)

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
          # BTAP::Reports::set_output_variables(model,"Hourly", output_variable_array)

          # Save the model
          model.save(osm_path, true)

          # Convert the model to energyplus idf
          forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
          idf = forward_translator.translateModel(model)
          idf.save(idf_path,true)
        end
      end

      # TO DO: call add_output routine (btap)

      # Run the simulation, if requested
      if run_models

        # Delete previous run directories if they exist
        FileUtils.rm_rf(full_sim_dir)

        # Load the model from disk if not already in memory
        if model.nil?
          model = prototype_creator.safe_load_model(osm_path_string)
        end

        # Run the annual simulation
        prototype_creator.model_run_simulation_and_log_errors(model, full_sim_dir)

      end           

      # Compare the model and model results, if requested
      model_diffs = []
      result_diffs = []
      if compare_results

        # Load the model and sql file from disk if not already in memory
        if model.nil?
          model = prototype_creator.safe_load_model(osm_path_string)
          sql_file = OpenStudio::SqlFile.new(sql_path)
          model.setSqlFile(sql_file)
        end

        ### Compare simulation results ###

        acceptable_error_percentage = 0.0

        # Get the legacy simulation results
        legacy_values = prototype_creator.model_legacy_results_by_end_use_and_fuel_type(model, climate_zone, building_type)
        if legacy_values.nil?
          result_diffs << "Could not find legacy simulation results for #{building_type} #{template} #{climate_zone}, cannot compare results."
        else
          # Store the comparisons for viewing
          results_comparison = []
          results_comparison << ['Building Type', 'Template', 'Climate Zone', 'Fuel Type', 'End Use', 'Legacy Value', 'Current Value', 'Percent Error', 'Difference']

          # Get the current simulation results
          current_values = prototype_creator.model_results_by_end_use_and_fuel_type(model)

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
                result_diffs << "#{building_type}-#{template}-#{climate_zone}-#{fuel_type}-#{end_use} Error = #{percent_error.round}% (#{current_val}, #{legacy_val})"
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
              results_comparison << [building_type, template, climate_zone, fuel_type, end_use, legacy_val.round(2), current_val.round(2), percent_error.round(2), (legacy_val-current_val).abs.round(2)]
            end
          end

          # Calculate the overall energy error
          total_energy_percent_error = nil
          if total_current_energy > 0 && total_legacy_energy > 0
            # If both
            total_energy_percent_error = ((total_current_energy - total_legacy_energy)/total_legacy_energy) * 100
            result_diffs << "#{building_type}-#{template}-#{climate_zone} *** Total Energy Error = #{total_energy_percent_error.round}% ***"
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
          CSV.open(diff_file_path, 'w') do |csv|
            results_comparison.each do |d|
              csv << d
            end
          end
        end

        ### Compare models object by object ###

        # Load the model from disk if not already in memory
        if model.nil?
          model = prototype_creator.safe_load_model(osm_path_string)
        end

        # Load the truth model from disk and compare to the newly-created model
        if File.exist?(truth_osm_path_string)
          truth_model = prototype_creator.safe_load_model(truth_osm_path_string)
          # Remove unused resources to make comparison cleaner
          prototype_creator.model_remove_unused_resource_objects(truth_model)
          model_diffs = compare_osm_files(truth_model, model)
        else
          model_diffs << "ERROR: could not find regression model at #{truth_osm_path_string}, did not compare models."
        end

        # Write the model diffs to a file
        if model_diffs.size > 0
          diff_file_path = "#{run_dir}/compare_models.log"
          File.open(diff_file_path, 'w') do |file|
            model_diffs.each do |d|
              file.puts d
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
        file.puts "*** #{model_name}, Time: #{run_time.round} sec ***"
        messages.each do |message|
          file.puts message
        end
      end

      # Assert if there were any errors
      assert(errors.size == 0, errors.reverse.join("\n"))

    end
  end


  # create more detailed csv for results comparison (from previous codes)
  def CreateDOEPrototypeBuildingTest.compare_test_results(bldg_types, vintages, climate_zones, file_ext="")

    #### Compare results against legacy idf results      
    acceptable_error_percentage = 10 # Max 5% error for any end use/fuel type combo
    failures = []

    # Load the legacy idf results JSON file into a ruby hash
    temp = File.read("#{Dir.pwd}/legacy_idf_results.json")
    legacy_idf_results = JSON.parse(temp)    

    # List of all fuel types
    fuel_types = ['Electricity', 'Natural Gas', 'Additional Fuel', 'District Cooling', 'District Heating', 'Water']

    # List of all end uses
    end_uses = ['Heating', 'Cooling', 'Interior Lighting', 'Exterior Lighting', 'Interior Equipment', 'Exterior Equipment', 'Fans', 'Pumps', 'Heat Rejection','Humidification', 'Heat Recovery', 'Water Systems', 'Refrigeration', 'Generators']

    # Create a hash of hashes to store all the results from each file
    all_results_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

    # Create a hash of hashes to store the results from each file
    results_total_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

    # Loop through all of the given combinations
    bldg_types.sort.each do |building_type|
      vintages.sort.each do |building_vintage|
        climate_zones.sort.each do |climate_zone|

          #puts "**********#{building_type}-#{building_vintage}-#{climate_zone}******************"
          # Open the sql file, skipping if not found
          model_name = "#{building_type}-#{building_vintage}-#{climate_zone}"
          sql_path_string = "#{Dir.pwd}/output/#{model_name}/AnnualRun/EnergyPlus/eplusout.sql"
          sql_path = OpenStudio::Path.new(sql_path_string)
          sql = nil
          if OpenStudio.exists(sql_path)
            #puts "Found SQL file."
            sql = OpenStudio::SqlFile.new(sql_path)
          else
            failures << "****Error - #{model_name} - Could not find sql file"
            puts "**********no sql here #{sql_path}******************"
            next
          end

          # Create a hash of hashes to store the results from each file
          results_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

          # Get the osm values for all fuel type/end use pairs
          # and compare to the legacy idf results
          total_legacy_energy_val = 0
          total_osm_energy_val = 0
          total_legacy_water_val = 0
          total_osm_water_val = 0
          fuel_types.each do |fuel_type|
            end_uses.each do |end_use|
              next if end_use == 'Exterior Equipment'
              # Get the legacy results number
              legacy_val = legacy_idf_results.dig(building_type, building_vintage, climate_zone, fuel_type, end_use)
              # Combine the exterior lighting and exterior equipment
              if end_use == 'Exterior Lighting'
                legacy_exterior_equipment = legacy_idf_results.dig(building_type, building_vintage, climate_zone, fuel_type, 'Exterior Equipment')
                unless legacy_exterior_equipment.nil?
                  legacy_val += legacy_exterior_equipment
                end
              end

              #legacy_val = legacy_idf_results[building_type][building_vintage][climate_zone][fuel_type][end_use]
              if legacy_val.nil?
                failures << "Error - #{model_name} - #{fuel_type} #{end_use} legacy idf value not found"
                next
              end

              # Add the energy to the total
              if fuel_type == 'Water'
                total_legacy_water_val += legacy_val
              else
                total_legacy_energy_val += legacy_val
              end

              # Select the correct units based on fuel type
              units = 'GJ'
              if fuel_type == 'Water'
                units = 'm3'
              end

              # End use breakdown query
              energy_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='AnnualBuildingUtilityPerformanceSummary') AND (ReportForString='Entire Facility') AND (TableName='End Uses') AND (ColumnName='#{fuel_type}') AND (RowName = '#{end_use}') AND (Units='#{units}')"

              # Get the end use value
              osm_val = sql.execAndReturnFirstDouble(energy_query)
              if osm_val.is_initialized
                osm_val = osm_val.get
              else
                failures << "Error - #{model_name} - No sql value found for #{fuel_type}-#{end_use} via #{energy_query}"
                osm_val = 0
              end

              # Combine the exterior lighting and exterior equipment
              if end_use == 'Exterior Lighting'
                # End use breakdown query
                energy_query = "SELECT Value FROM TabularDataWithStrings WHERE (ReportName='AnnualBuildingUtilityPerformanceSummary') AND (ReportForString='Entire Facility') AND (TableName='End Uses') AND (ColumnName='#{fuel_type}') AND (RowName = 'Exterior Equipment') AND (Units='#{units}')"

                # Get the end use value
                osm_val_2 = sql.execAndReturnFirstDouble(energy_query)
                if osm_val_2.is_initialized
                  osm_val_2 = osm_val_2.get
                else
                  failures << "Error - #{model_name} - No sql value found for #{fuel_type}-Exterior Equipment via #{energy_query}"
                  osm_val_2 = 0
                end
                osm_val += osm_val_2
              end

              # Add the energy to the total
              if fuel_type == 'Water'
                total_osm_water_val += osm_val
              else
                total_osm_energy_val += osm_val
              end

              # Calculate the error and check if less than
              # acceptable_error_percentage
              percent_error = nil
              add_to_all_results = true
              if osm_val > 0 && legacy_val > 0
                # If both
                percent_error = ((osm_val - legacy_val)/legacy_val) * 100
                if percent_error.abs > acceptable_error_percentage
                  failures << "#{building_type}-#{building_vintage}-#{climate_zone}-#{fuel_type}-#{end_use} Error = #{percent_error.round}% (#{osm_val}, #{legacy_val})"
                end
              elsif osm_val > 0 && legacy_val.abs < 1e-6
                # The osm has a fuel/end use that the legacy idf does not
                percent_error = 1000
                failures << "#{building_type}-#{building_vintage}-#{climate_zone}-#{fuel_type}-#{end_use} Error = osm has extra fuel/end use that legacy idf does not (#{osm_val})"
              elsif osm_val.abs < 1e-6 && legacy_val > 0
                # The osm has a fuel/end use that the legacy idf does not
                percent_error = 1000
                failures << "#{building_type}-#{building_vintage}-#{climate_zone}-#{fuel_type}-#{end_use} Error = osm is missing a fuel/end use that legacy idf has (#{legacy_val})"
              else
                # Both osm and legacy are == 0 for this fuel/end use, no error
                percent_error = 0
                add_to_all_results = false
              end

              results_hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['Legacy Val'] = legacy_val.round(2)
              results_hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['OpenStudio Val'] = osm_val.round(2)
              results_hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['Percent Error'] = percent_error.round(2)
              results_hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['Absolute Error'] = (legacy_val-osm_val).abs.round(2)

              if add_to_all_results
                all_results_hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['Legacy Val'] = legacy_val.round(2)
                all_results_hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['OpenStudio Val'] = osm_val.round(2)
                all_results_hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['Percent Error'] = percent_error.round(2)
                all_results_hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['Absolute Error'] = (legacy_val-osm_val).abs.round(2)
              end

            end # Next end use
          end # Next fuel type

          # Calculate the overall energy error
          total_percent_error = nil
          if total_osm_energy_val > 0 && total_legacy_energy_val > 0
            # If both
            total_percent_error = ((total_osm_energy_val - total_legacy_energy_val)/total_legacy_energy_val) * 100
            failures << "#{building_type}-#{building_vintage}-#{climate_zone} *** Total Energy Error = #{total_percent_error.round}% ***"
          elsif total_osm_energy_val > 0 && total_legacy_energy_val == 0
            # The osm has a fuel/end use that the legacy idf does not
            total_percent_error = 1000
            failures << "#{building_type}-#{building_vintage}-#{climate_zone} *** Total Energy Error = osm has extra fuel/end use that legacy idf does not (#{total_osm_energy_val})"
          elsif total_osm_energy_val == 0 && total_legacy_energy_val > 0
            # The osm has a fuel/end use that the legacy idf does not
            total_percent_error = 1000
            failures << "#{building_type}-#{building_vintage}-#{climate_zone} *** Total Energy Error = osm is missing a fuel/end use that legacy idf has (#{total_legacy_energy_val})"
          else
            # Both osm and legacy are == 0 for, no error
            total_percent_error = 0
            failures << "#{building_type}-#{building_vintage}-#{climate_zone} *** Total Energy Error = both idf and osm don't use any energy."
          end

          results_total_hash[building_type][building_vintage][climate_zone] = total_percent_error

          # Save the results to JSON
          File.open("#{Dir.pwd}/output/#{model_name}/comparison#{file_ext}.json", 'w') do |file|
            file << JSON::pretty_generate(results_hash)
          end
        end
      end
    end

    # Get all the fuel type and end user combination
    all_fuel_end_user_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
    all_results_hash.each_pair do |building_type, value1|
      value1.each_pair do |building_vintage, value2|
        value2.each_pair do |climate_zone, value3|
          value3.each_pair do |fuel_type, value4|# fuel type
            value4.each_pair do |end_use, value5| # end use
              all_fuel_end_user_hash[fuel_type][end_use] = true
            end
          end
        end
      end
    end

    # Fill in the missing value with 0,0,0
    all_results_hash.each_pair do |building_type, value1|
      value1.each_pair do |building_vintage, value2|
        value2.each_pair do |climate_zone, value3|
          all_fuel_end_user_hash.each_pair do |fuel_type, end_users|
            end_users.each_pair do |end_use, value|
              if value3[fuel_type][end_use].empty?
                value3[fuel_type][end_use]['Legacy Val'] = 0
                value3[fuel_type][end_use]['OpenStudio Val'] = 0
                value3[fuel_type][end_use]['Percent Error'] = 0
                value3[fuel_type][end_use]['Absolute Error'] = 0
              end
            end
          end
        end
      end
    end

    fuel_type_names = []
    end_uses_names =[]

    all_fuel_end_user_hash.each_pair do |fuel_type, end_users|
      end_users.each_pair do |end_use, value|
        fuel_type_names.push(fuel_type)
        end_uses_names.push(end_use)
      end
    end

    #######
    # results_total_hash[building_type][building_vintage][climate_zone]
    csv_file_total = File.open("#{Dir.pwd}/output/comparison_total#{file_ext}.csv", 'w')
    # Write the header
    csv_file_total.write("building_type,building_vintage,climate_zone,")
    line2_str =",,,"
    #results_hash=Hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['Legacy Val']
    results_total_hash.values[0].values[0].each_pair do |climate_zone, total_error|
      csv_file_total.write("#{total_error},")
    end
    csv_file_total.write("\n")
    # Save the results to CSV
    results_total_hash.each_pair do |building_type, value1|
      value1.each_pair do |building_vintage, value2|
        value2.each_pair do |climate_zone, value3|
          csv_file_total.write("#{building_type},#{building_vintage},#{climate_zone},#{value3}")
          csv_file_total.write("\n")
        end
      end
    end

    csv_file_total.close 

    # Create a CSV to store the results
    csv_file = File.open("#{Dir.pwd}/output/comparison#{file_ext}.csv", 'w')
    csv_file_simple = File.open("#{Dir.pwd}/output/comparison_simple#{file_ext}.csv", 'w')

    # Write the header
    csv_file.write("building_type,building_vintage,climate_zone,")
    csv_file_simple.write("building type,building vintage,climate zone,fuel type,end use,legacy val,openstudio val,percent error,absolute error\n")
    line2_str =",,,"
    #results_hash=Hash[building_type][building_vintage][climate_zone][fuel_type][end_use]['Legacy Val']
    all_results_hash.values[0].values[0].values[0].each_pair do |fuel_type, end_users|
      end_users.keys.each do |end_user|
        csv_file.write("#{fuel_type}-#{end_user},,,,")
        line2_str+= "Legacy Val,OSM Val,Diff (%),Absolute Diff,"
      end
    end
    csv_file.write("\n")
    csv_file.write(line2_str + "\n")

    # Save the results to CSV
    all_results_hash.each_pair do |building_type, value1|
      value1.each_pair do |building_vintage, value2|
        value2.each_pair do |climate_zone, value3|
          csv_file.write("#{building_type},#{building_vintage},#{climate_zone},")
          for fuel_end_use_index in 0...fuel_type_names.count
            fuel_type = fuel_type_names[fuel_end_use_index]
            end_use = end_uses_names[fuel_end_use_index]
            value5 = value3[fuel_type][end_use]
            csv_file.write("#{value5['Legacy Val']},#{value5['OpenStudio Val']},#{value5['Percent Error']},#{value5['Absolute Error']},")
            # if value5['Percent Error'].abs > 0.1
            unless value5['Legacy Val'].nil?
              csv_file_simple.write("#{building_type},#{building_vintage},#{climate_zone},#{fuel_type},#{end_use},#{value5['Legacy Val']},#{value5['OpenStudio Val']},#{value5['Percent Error']},#{value5['Absolute Error']}\n")
            end
          end
          csv_file.write("\n")
        end
      end
    end

    csv_file.close
    csv_file_simple.close
    #### Return the list of failures
    return failures
  end

end

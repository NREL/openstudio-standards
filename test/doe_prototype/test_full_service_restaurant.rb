require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class TestFullServiceRestaurant < CreateDOEPrototypeBuildingTest
  
  building_types = ['FullServiceRestaurant']
  # templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2004','90.1-2007','90.1-2010','90.1-2013']
  templates = ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010']
   climate_zones = ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']   
  #climate_zones = ['ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A','ASHRAE 169-2006-2B',
                   # 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A',
                   # 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B',
                   # 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-8A'] 
  
  # not used for ASHRAE/DOE archetypes, but required for call
  epw_files = ['USA_FL_Miami.Intl.AP.722020_TMY3.epw']

  create_models = true
  run_models = false
  compare_results = false
  
  debug = false

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
      osm_path_string = "#{run_dir}/final.osm"
      output_path = OpenStudio::Path.new(run_dir)

      model = nil

      # Create the model, if requested
      if create_models
        prototype_creator = Standard.build("#{template}_#{building_type}")
        model = prototype_creator.model_create_prototype_model(climate_zone, epw_file, run_dir)
        @current_model = model
        puts model.class
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

        # Convert the model to energyplus idf
        forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
        idf = forward_translator.translateModel(model)
        idf.save(idf_path,true)

      end

      # TO DO: call add_output routine (btap)



      # Run the simulation, if requested
      if run_models

        # Delete previous run directories if they exist
        FileUtils.rm_rf(full_sim_dir)

        # Load the model from disk if not already in memory
        if model.nil?
          model = standard.safe_load_model(osm_path_string)
          forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
          idf = forward_translator.translateModel(model)
          idf.save(idf_path,true)
        end

        # Run the annual simulation
        standard = Standard.build("#{template}")
        standard.model_run_simulation_and_log_errors(model, full_sim_dir)

      end



      # Compare the results against the legacy idf files if requested
      if compare_results

        acceptable_error_percentage = 0 # Max % error for any end use/fuel type combo

        # Load the legacy idf results JSON file into a ruby hash
        temp = File.read("#{Dir.pwd}/data/legacy_idf_results.json")
        legacy_idf_results = JSON.parse(temp)

        # List of all fuel types
        fuel_types = ['Electricity', 'Natural Gas', 'Additional Fuel', 'District Cooling', 'District Heating', 'Water']

        # List of all end uses
        end_uses = ['Heating', 'Cooling', 'Interior Lighting', 'Exterior Lighting', 'Interior Equipment', 'Exterior Equipment', 'Fans', 'Pumps', 'Heat Rejection','Humidification', 'Heat Recovery', 'Water Systems', 'Refrigeration', 'Generators']

        sql_path_string = "#{@test_dir}/#{model_name}/AnnualRun/EnergyPlus/eplusout.sql"
        sql_path = OpenStudio::Path.new(sql_path_string)
        sql_path_string_2 = "#{@test_dir}/#{model_name}/AnnualRun/run/eplusout.sql"
        sql_path_2 = OpenStudio::Path.new(sql_path_string_2)
        sql = nil
        if OpenStudio.exists(sql_path)
          sql = OpenStudio::SqlFile.new(sql_path)
        elsif OpenStudio.exists(sql_path_2)
          sql = OpenStudio::SqlFile.new(sql_path_2)
        else
          OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "Could not find sql file, could not compare results.")
        end

        # Create a hash of hashes to store the results from each file
        results_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

        # Get the osm values for all fuel type/end use pairs
        # and compare to the legacy idf results
        csv_rows = []
        total_legacy_energy_val = 0
        total_osm_energy_val = 0
        total_legacy_water_val = 0
        total_osm_water_val = 0
        total_cumulative_energy_err = 0
        total_cumulative_water_err = 0
        fuel_types.each do |fuel_type|
          end_uses.each do |end_use|
            next if end_use == 'Exterior Equipment'
            # Get the legacy results number
            legacy_val = legacy_idf_results.dig(building_type, template, climate_zone, fuel_type, end_use)
            # Combine the exterior lighting and exterior equipment
            if end_use == 'Exterior Lighting'
              legacy_exterior_equipment = legacy_idf_results.dig(building_type, template, climate_zone, fuel_type, 'Exterior Equipment')
              unless legacy_exterior_equipment.nil?
                legacy_val += legacy_exterior_equipment
              end
            end

            if legacy_val.nil?
              OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "#{fuel_type} #{end_use} legacy idf value not found")
              legacy_val = 0
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
              OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', "No sql value found for #{fuel_type}-#{end_use}")
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
                OpenStudio::logFree(OpenStudio::Warn, 'openstudio.model.Model', "No sql value found for #{fuel_type}-Exterior Equipment.")
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

            # Add the absolute error to the total
            abs_err = (legacy_val-osm_val).abs

            if fuel_type == 'Water'
              total_cumulative_water_err += abs_err
            else
              total_cumulative_energy_err += abs_err
            end

            # Calculate the error and check if less than
            # acceptable_error_percentage
            percent_error = nil
            write_to_file = false
            if osm_val > 0 && legacy_val > 0
              percent_error = ((osm_val - legacy_val)/legacy_val) * 100
              if percent_error.abs >= acceptable_error_percentage
                OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "#{fuel_type}-#{end_use} Error = #{percent_error.round}% (#{osm_val}, #{legacy_val})")
                write_to_file = true
              end
            elsif osm_val > 0 && legacy_val.abs < 1e-6
              # The osm has a fuel/end use that the legacy idf does not
              percent_error = 9999
              OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "#{fuel_type}-#{end_use} Error = osm has extra fuel/end use that legacy idf does not (#{osm_val})")
              write_to_file = true
            elsif osm_val.abs < 1e-6 && legacy_val > 0
              # The osm has a fuel/end use that the legacy idf does not
              percent_error = 9999
              OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "#{fuel_type}-#{end_use} Error = osm is missing a fuel/end use that legacy idf has (#{legacy_val})")
              write_to_file = true
            else
              # Both osm and legacy are == 0 for this fuel/end use, no error
              percent_error = 0
            end

            # ALWAYS OUTPUT THE VALUES
            write_to_file = true
            if write_to_file
              csv_rows << "#{building_type},#{template},#{climate_zone},#{fuel_type},#{end_use},#{legacy_val.round(2)},#{osm_val.round(2)},#{percent_error.round},#{abs_err.round}"
            end

          end # Next end use
        end # Next fuel type

        # Calculate the overall energy error
        total_percent_error = nil
        if total_osm_energy_val > 0 && total_legacy_energy_val > 0
          # If both
          total_percent_error = ((total_osm_energy_val - total_legacy_energy_val)/total_legacy_energy_val) * 100
          OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Total Energy Error = #{total_percent_error.round}%")
        elsif total_osm_energy_val > 0 && total_legacy_energy_val == 0
          # The osm has a fuel/end use that the legacy idf does not
          total_percent_error = 9999
          OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Total Energy Error = osm has extra fuel/end use that legacy idf does not (#{total_osm_energy_val})")
        elsif total_osm_energy_val == 0 && total_legacy_energy_val > 0
          # The osm has a fuel/end use that the legacy idf does not
          total_percent_error = 9999
          OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Total Energy Error = osm is missing a fuel/end use that legacy idf has (#{total_legacy_energy_val})")
        else
          # Both osm and legacy are == 0 for, no error
          total_percent_error = 0
          OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.Model', "Total Energy Error = both idf and osm don't use any energy.")
        end

        tot_abs_energy_err = ((total_osm_energy_val - total_legacy_energy_val)/total_legacy_energy_val) * 100
        tot_cumulative_energy_err = (total_cumulative_energy_err/total_legacy_energy_val) * 100

        if tot_cumulative_energy_err.abs > 20
          OpenStudio::logFree(OpenStudio::Warn, 'openstudio.model.Model', "Total Energy cumulative error = #{tot_cumulative_energy_err.round}%.")
        end

        csv_rows << "#{building_type},#{template},#{climate_zone},Total Energy,Total Energy,#{total_legacy_energy_val.round(2)},#{total_osm_energy_val.round(2)},#{total_percent_error.round},#{tot_abs_energy_err.round},#{tot_cumulative_energy_err.round}"

        # Append the comparison results
        File.open(@results_csv_file, 'a') do |file|
          csv_rows.each do |csv_row|
            file.puts csv_row
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
      assert(errors.size == 0, errors)

    end
  end

  TestFullServiceRestaurant.create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)

  # TestFullServiceRestaurant.compare_test_results(building_types, templates, climate_zones, file_ext="")

     
end

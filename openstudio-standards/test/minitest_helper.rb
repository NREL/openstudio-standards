$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'minitest/autorun'
require 'minitest/reporters'
require 'openstudio'
require 'openstudio-standards'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'json'
require 'fileutils'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new # spec-like progress

class CreateDOEPrototypeBuildingTest < Minitest::Test

  def setup
    # Make a directory to save the resulting models
    @test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end
=begin
    # Find EnergyPlus
    ep_dir = OpenStudio.getEnergyPlusDirectory
    ep_path = OpenStudio.getEnergyPlusExecutable
    @ep_tool = OpenStudio::Runmanager::ToolInfo.new(ep_path)
    @idd_path = OpenStudio::Path.new(ep_dir.to_s + "/Energy+.idd")
    # Make a run manager
    run_manager_db_path = OpenStudio::Path.new("#{@test_dir}/run.db")
    # HACK: workaround for Mac with Qt 5.4, need to address in the future.
    OpenStudio::Application::instance().application(false)
    run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_db_path, true, false, false, false)\\
=end
  end


  # Dynamically create a test for each building type/template/climate zone
  # so that if one combo fails the others still run
  def CreateDOEPrototypeBuildingTest.create_run_model_tests(building_types, 
                                                            templates, 
                                                            climate_zones, 
                                                            create_models = true,
                                                            run_models = true,
                                                            compare_results = true)

    building_types.each do |building_type|
      templates.each do |template|
        climate_zones.each do |climate_zone|

          method_name = "test_#{building_type}-#{template}-#{climate_zone}".gsub(' ','_')
          define_method(method_name) do
            
            # Paths for this test run
            model_name = "#{building_type}-#{template}-#{climate_zone}"
            run_dir = "#{@test_dir}/#{model_name}"
            if !Dir.exists?(run_dir)
              Dir.mkdir(run_dir)
            end
            idf_path_string = "#{run_dir}/#{model_name}.idf"
            idf_path = OpenStudio::Path.new(idf_path_string)            
            osm_path_string = ""
            
            model = nil
            
            # Create the model, if requested
            if create_models
            
              model = OpenStudio::Model::Model.new
              model.create_prototype_building(building_type,template,climate_zone,run_dir)

              # Report out errors in model creation
              # and reset the log for the next test
              log_messages_to_file("#{run_dir}/openstudio-standards.log")
              errors = get_logs(OpenStudio::Error)         
              assert(errors.size == 0, errors)
              reset_log   
      
              # Convert the model to energyplus idf
              forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
              idf = forward_translator.translateModel(model)
              idf.save(idf_path,true)  
            
            end
=begin            
            # Run the simulation, if requested
            if run_models
            
              # Load the model from memory, if not already in memory
              if model.nil?
                model_directory = "#{@test_dir}/#{building_type}-#{template}-#{climate_zone}"
                model_name = "#{building_type}-#{template}-#{climate_zone}"
                puts "****Run Model: #{model_name}****"

                model_path_string = "#{model_directory}/final.osm"
                model_path = OpenStudio::Path.new(model_path_string)
                if OpenStudio::exists(model_path)
                  version_translator = OpenStudio::OSVersion::VersionTranslator.new
                  model = version_translator.loadModel(model_path)
                  if model.empty?
                    errors << "Error - #{model_name} - Version translation failed"
                    return errors
                  else
                    model = model.get
                  end
                else
                  errors << "Error - #{model_name} - #{model_path_string} couldn't be found"
                  return errors
                end

                # Delete the old ModelToIdf and SizingRun1 directories if they exist
                FileUtils.rm_rf("#{model_directory}/ModelToIdf")
                FileUtils.rm_rf("#{model_directory}/SizingRun1")

                # Convert the model to energyplus idf
                forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
                idf = forward_translator.translateModel(model)
                idf_path_string = "#{model_directory}/#{model_name}.idf"
                idf_path = OpenStudio::Path.new(idf_path_string)
                idf.save(idf_path,true)
              end

              # Find the weather file
              epw_path = nil
              if self.weatherFile.is_initialized
                epw_path = self.weatherFile.get.path
                if epw_path.is_initialized
                  if File.exist?(epw_path.get.to_s)
                    epw_path = epw_path.get
                  else
                    # If this is an always-run Measure, need to check a different path
                    alt_weath_path = File.expand_path(File.join(File.dirname(__FILE__), "../../../resources"))
                    alt_epw_path = File.expand_path(File.join(alt_weath_path, epw_path.get.to_s))
                    if File.exist?(alt_epw_path)
                      epw_path = OpenStudio::Path.new(alt_epw_path)
                    else
                      OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "Model has been assigned a weather file, but the file is not in the specified location of '#{epw_path.get}'.")
                      return false
                    end
                  end
                else
                  OpenStudio::logFree(OpenStudio::Error, "openstudio.model.Model", "Model has a weather file assigned, but the weather file path has been deleted.")
                  return false
                end
              else
                OpenStudio::logFree(OpenStudio::Error, 'openstudio.model.Model', 'Model has not been assigned a weather file.')
                return false
              end
            
              # Queue up the simulation
              job = OpenStudio::Runmanager::JobFactory::createEnergyPlusJob(@ep_tool,
                                                                   @idd_path,
                                                                   idf_path,
                                                                   epw_path,
                                                                   output_path)
              run_manager.enqueue(job, true)
            
            
            end
=end            
            
            # Compare the results, if requested

            

            

          end
          
        end
      end
    end  
  
  
  end

end


=begin
class CreateDOEPrototypeBuildingTest < Minitest::Test

  def CreateDOEPrototypeBuildingTest.create_models(building_types, templates, climate_zones, test_dir)

        building_types.each do |method_name|
          puts "defining method #{method_name}"
          metaclass.instance_eval do
            define_method(method_name) do
              return "hooray"
            end
          end
        end
        
        return
  
    

  end
  
end  
  

# Add a "dig" method to Hash to check if deeply nested elements exist
# From: http://stackoverflow.com/questions/1820451/ruby-style-how-to-check-whether-a-nested-hash-element-exists
class Hash
  def dig(*path)
    path.inject(self) do |location, key|
      location.respond_to?(:keys) ? location[key] : nil
    end
  end
end

class CreateDOEPrototypeBuildingTest < Minitest::Test

  def setup
    # Make a directory to save the resulting models
    @test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exists?(@test_dir)
      Dir.mkdir(@test_dir)
    end
  end

  # Create a set of models, return a list of errors
  def create_model(building_type, template, climate_zone)

    model_name = "#{building_type}-#{template}-#{climate_zone}"
    puts "****Create Model: #{model_name}****"
    # Make an empty model
    model = OpenStudio::Model::Model.new

    osm_directory = "#{@test_dir}/#{model_name}"
    if !Dir.exists?(osm_directory)
      Dir.mkdir(osm_directory)
    end

    # Create the model
    model.create_prototype_building(building_type,template,climate_zone,osm_directory)

    # Report out errors
    errors = []
    $OPENSTUDIO_LOG.logMessages.each do |msg|
      if /openstudio.*/.match(msg.logChannel)
        # Skip certain messages that are irrelevant/misleading
        next if msg.logMessage.include?("Skipping layer") || # Annoying/bogus "Skipping layer" warnings
            msg.logChannel.include?("runmanager") || # RunManager messages
            msg.logChannel.include?("setFileExtension") || # .ddy extension unexpected
            msg.logChannel.include?("Translator") || # Forward translator and geometry translator
            msg.logMessage.include?("UseWeatherFile") # 'UseWeatherFile' is not yet a supported option for YearDescription
        # Only fail on the errors
        if msg.logLevel == OpenStudio::Error #|| msg.logLevel == OpenStudio::Warn
          puts "ERROR #{msg.logMessage}"
          errors << "#{model_name} [#{msg.logChannel}] #{msg.logMessage}"
        end
      end
    end          
    
    # Reset the error log for the next run
    reset_log   
    
    # Convert the model to energyplus idf
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(model)
    idf_path_string = "#{osm_directory}/#{model_name}.idf"
    idf_path = OpenStudio::Path.new(idf_path_string)
    idf.save(idf_path,true)
    
    return errors

  end

  # Create a set of models, return a list of errors
  def run_models(bldg_types, vintages, climate_zones)

    # Open a channel to log info/warning/error messages
    msg_log = OpenStudio::StringStreamLogSink.new
    msg_log.setLogLevel(OpenStudio::Info)

    #### Run the specified models
    errors = []

    # Make a run manager and queue up the sizing run
    run_manager_db_path = OpenStudio::Path.new("#{@test_dir}/run.db")
    run_manager = OpenStudio::Runmanager::RunManager.new(run_manager_db_path, true, false, false, false)

    # Configure the run manager with the correct versions of Ruby and E+
    config_opts = OpenStudio::Runmanager::ConfigOptions.new
    config_opts.findTools(false, false, false, false)
    run_manager.setConfigOptions(config_opts)

    # Loop through all of the given combinations
    bldg_types.sort.each do |building_type|
      vintages.sort.each do |template|
        climate_zones.sort.each do |climate_zone|
          # Load the .osm
          model = nil
          model_directory = "#{@test_dir}/#{building_type}-#{template}-#{climate_zone}"
          model_name = "#{building_type}-#{template}-#{climate_zone}"
          puts "****Run Model: #{model_name}****"

          model_path_string = "#{model_directory}/final.osm"
          model_path = OpenStudio::Path.new(model_path_string)
          if OpenStudio::exists(model_path)
            version_translator = OpenStudio::OSVersion::VersionTranslator.new
            model = version_translator.loadModel(model_path)
            if model.empty?
              errors << "Error - #{model_name} - Version translation failed"
              return errors
            else
              model = model.get
            end
          else
            errors << "Error - #{model_name} - #{model_path_string} couldn't be found"
            return errors
          end

          # Delete the old ModelToIdf and SizingRun1 directories if they exist
          FileUtils.rm_rf("#{model_directory}/ModelToIdf")
          FileUtils.rm_rf("#{model_directory}/SizingRun1")

          # Convert the model to energyplus idf
          forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
          idf = forward_translator.translateModel(model)
          idf_path_string = "#{model_directory}/#{model_name}.idf"
          idf_path = OpenStudio::Path.new(idf_path_string)
          idf.save(idf_path,true)

          # Find the weather file
          epw_path = nil
          if model.weatherFile.is_initialized
            epw_path = model.weatherFile.get.path
            if epw_path.is_initialized
              if File.exist?(epw_path.get.to_s)
                epw_path = epw_path.get
              else
                errors << "Error - #{model_name} - Model has not been assigned a weather file."
                return errors
              end
            else
              errors << "Error - #{model_name} - Model has a weather file assigned, but the file is not in the specified location."
              return errors
            end
          else
            errors << "Error - #{model_name} - Model has not been assigned a weather file."
            return errors
          end

          # Set the output path
          output_path = OpenStudio::Path.new("#{model_directory}/")

          # Create a new workflow for the model to go through
          workflow = OpenStudio::Runmanager::Workflow.new
          workflow.addJob(OpenStudio::Runmanager::JobType.new('ModelToIdf'))
          workflow.addJob(OpenStudio::Runmanager::JobType.new('ExpandObjects'))
          workflow.addJob(OpenStudio::Runmanager::JobType.new('EnergyPlusPreProcess'))
          workflow.addJob(OpenStudio::Runmanager::JobType.new('EnergyPlus'))
          workflow.add(config_opts.getTools)
          job = workflow.create(output_path, model_path, epw_path)

          run_manager.enqueue(job, true)

        end
      end
    end

    # Start the runs and wait for them to finish.
    while run_manager.workPending
      sleep 5
      OpenStudio::Application::instance.processEvents
    end

    #### Return the list of errors
    return errors

  end

  # Create a set of models, return a list of errors
  def compare_results(bldg_types, vintages, climate_zones, file_ext="")

    #### Compare results against legacy idf results
    acceptable_error_percentage = 10 # Max 5% error for any end use/fuel type combo
    errors = []

    # Load the legacy idf results JSON file into a ruby hash
    temp = File.read("#{File.dirname(__FILE__)}/legacy_idf_results.json")
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
      vintages.sort.each do |template|
        climate_zones.sort.each do |climate_zone|
          # Open the sql file, skipping if not found
          model_name = "#{building_type}-#{template}-#{climate_zone}"
          puts "****Compare Results: #{model_name}****"
          sql_path_string = "#{@test_dir}/#{model_name}/ModelToIdf/ExpandObjects-0/EnergyPlusPreProcess-0/EnergyPlus-0/eplusout.sql"
          sql_path = OpenStudio::Path.new(sql_path_string)
          sql = nil
          if OpenStudio.exists(sql_path)
            puts "Found SQL file."
            sql = OpenStudio::SqlFile.new(sql_path)
          else
            errors << "****Error - #{model_name} - Could not find sql file"
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
              legacy_val = legacy_idf_results.dig(building_type, template, climate_zone, fuel_type, end_use)
              # Combine the exterior lighting and exterior equipment
              if end_use == 'Exterior Lighting'
                legacy_exterior_equipment = legacy_idf_results.dig(building_type, template, climate_zone, fuel_type, 'Exterior Equipment')
                unless legacy_exterior_equipment.nil?
                  legacy_val += legacy_exterior_equipment
                end
              end

              #legacy_val = legacy_idf_results[building_type][template][climate_zone][fuel_type][end_use]
              if legacy_val.nil?
                errors << "Error - #{model_name} - #{fuel_type} #{end_use} legacy idf value not found"
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
                errors << "Error - #{model_name} - No sql value found for #{fuel_type}-#{end_use} via #{energy_query}"
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
                  errors << "Error - #{model_name} - No sql value found for #{fuel_type}-Exterior Equipment via #{energy_query}"
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
                  errors << "#{building_type}-#{template}-#{climate_zone}-#{fuel_type}-#{end_use} Error = #{percent_error.round}% (#{osm_val}, #{legacy_val})"
                end
              elsif osm_val > 0 && legacy_val.abs < 1e-6
                # The osm has a fuel/end use that the legacy idf does not
                percent_error = 1000
                errors << "#{building_type}-#{template}-#{climate_zone}-#{fuel_type}-#{end_use} Error = osm has extra fuel/end use that legacy idf does not (#{osm_val})"
              elsif osm_val.abs < 1e-6 && legacy_val > 0
                # The osm has a fuel/end use that the legacy idf does not
                percent_error = 1000
                errors << "#{building_type}-#{template}-#{climate_zone}-#{fuel_type}-#{end_use} Error = osm is missing a fuel/end use that legacy idf has (#{legacy_val})"
              else
                # Both osm and legacy are == 0 for this fuel/end use, no error
                percent_error = 0
                add_to_all_results = false
              end

              results_hash[building_type][template][climate_zone][fuel_type][end_use]['Legacy Val'] = legacy_val.round(2)
              results_hash[building_type][template][climate_zone][fuel_type][end_use]['OpenStudio Val'] = osm_val.round(2)
              results_hash[building_type][template][climate_zone][fuel_type][end_use]['Percent Error'] = percent_error.round(2)
              results_hash[building_type][template][climate_zone][fuel_type][end_use]['Absolute Error'] = (legacy_val-osm_val).abs.round(2)

              if add_to_all_results
                all_results_hash[building_type][template][climate_zone][fuel_type][end_use]['Legacy Val'] = legacy_val.round(2)
                all_results_hash[building_type][template][climate_zone][fuel_type][end_use]['OpenStudio Val'] = osm_val.round(2)
                all_results_hash[building_type][template][climate_zone][fuel_type][end_use]['Percent Error'] = percent_error.round(2)
                all_results_hash[building_type][template][climate_zone][fuel_type][end_use]['Absolute Error'] = (legacy_val-osm_val).abs.round(2)
              end

            end # Next end use
          end # Next fuel type

          # Calculate the overall energy error
          total_percent_error = nil
          if total_osm_energy_val > 0 && total_legacy_energy_val > 0
            # If both
            total_percent_error = ((total_osm_energy_val - total_legacy_energy_val)/total_legacy_energy_val) * 100
            errors << "#{building_type}-#{template}-#{climate_zone} *** Total Energy Error = #{total_percent_error.round}% ***"
          elsif total_osm_energy_val > 0 && total_legacy_energy_val == 0
            # The osm has a fuel/end use that the legacy idf does not
            total_percent_error = 1000
            errors << "#{building_type}-#{template}-#{climate_zone} *** Total Energy Error = osm has extra fuel/end use that legacy idf does not (#{total_osm_energy_val})"
          elsif total_osm_energy_val == 0 && total_legacy_energy_val > 0
            # The osm has a fuel/end use that the legacy idf does not
            total_percent_error = 1000
            errors << "#{building_type}-#{template}-#{climate_zone} *** Total Energy Error = osm is missing a fuel/end use that legacy idf has (#{total_legacy_energy_val})"
          else
            # Both osm and legacy are == 0 for, no error
            total_percent_error = 0
            errors << "#{building_type}-#{template}-#{climate_zone} *** Total Energy Error = both idf and osm don't use any energy."
          end

          results_total_hash[building_type][template][climate_zone] = total_percent_error

          # Save the results to JSON
          File.open("#{@test_dir}/#{model_name}/comparison#{file_ext}.json", 'w') do |file|
            file << JSON::pretty_generate(results_hash)
          end
        end
      end
    end

    # Get all the fuel type and end user combination
    all_fuel_end_user_hash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }
    all_results_hash.each_pair do |building_type, value1|
      value1.each_pair do |template, value2|
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
      value1.each_pair do |template, value2|
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
    # results_total_hash[building_type][template][climate_zone]
    csv_file_total = File.open("#{@test_dir}/comparison_total#{file_ext}.csv", 'w')
    # Write the header
    csv_file_total.write("building_type,template,climate_zone,")
    line2_str =",,,"
    #results_hash=Hash[building_type][template][climate_zone][fuel_type][end_use]['Legacy Val']
    if !results_total_hash.values[0].nil?
      results_total_hash.values[0].values[0].each_pair do |climate_zone, total_error|
        csv_file_total.write("#{total_error},")
      end
    end
    csv_file_total.write("\n")
    # Save the results to CSV
    results_total_hash.each_pair do |building_type, value1|
      value1.each_pair do |template, value2|
        value2.each_pair do |climate_zone, value3|
          csv_file_total.write("#{building_type},#{template},#{climate_zone},#{value3}")
          csv_file_total.write("\n")
        end
      end
    end

    csv_file_total.close



    # Create a CSV to store the results
    csv_file = File.open("#{@test_dir}/comparison#{file_ext}.csv", 'w')
    csv_file_simple = File.open("#{@test_dir}/comparison_simple#{file_ext}.csv", 'w')

    # Write the header
    csv_file.write("building_type,template,climate_zone,")
    csv_file_simple.write("building type,building vintage,climate zone,fuel type,end use,legacy val,openstudio val,percent error,absolute error\n")
    line2_str =",,,"
    #results_hash=Hash[building_type][template][climate_zone][fuel_type][end_use]['Legacy Val']
    if !all_results_hash.values[0].nil?
      all_results_hash.values[0].values[0].values[0].each_pair do |fuel_type, end_users|
        end_users.keys.each do |end_user|
          csv_file.write("#{fuel_type}-#{end_user},,,,")
          line2_str+= "Legacy Val,OSM Val,Diff (%),Absolute Diff,"
        end
      end
    end
    csv_file.write("\n")
    csv_file.write(line2_str + "\n")

    # Save the results to CSV
    all_results_hash.each_pair do |building_type, value1|
      value1.each_pair do |template, value2|
        value2.each_pair do |climate_zone, value3|
          csv_file.write("#{building_type},#{template},#{climate_zone},")
          for fuel_end_use_index in 0...fuel_type_names.count
            fuel_type = fuel_type_names[fuel_end_use_index]
            end_use = end_uses_names[fuel_end_use_index]
            value5 = value3[fuel_type][end_use]
            csv_file.write("#{value5['Legacy Val']},#{value5['OpenStudio Val']},#{value5['Percent Error']},#{value5['Absolute Error']},")
            # if value5['Percent Error'].abs > 0.1
            unless value5['Legacy Val'].nil?
              csv_file_simple.write("#{building_type},#{template},#{climate_zone},#{fuel_type},#{end_use},#{value5['Legacy Val']},#{value5['OpenStudio Val']},#{value5['Percent Error']},#{value5['Absolute Error']}\n")
            end
          end
          csv_file.write("\n")
        end
      end
    end

    csv_file.close
    csv_file_simple.close
    #### Return the list of errors
    return errors
  end
end
=end

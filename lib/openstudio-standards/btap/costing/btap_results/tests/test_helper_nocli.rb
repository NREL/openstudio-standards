require '/usr/local/openstudio-3.7.0/Ruby/openstudio'
require 'openstudio-standards'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'optparse'
require 'logger'
require 'minitest/autorun'
begin
  require 'openstudio_measure_tester/test_helper'
rescue LoadError
  puts 'OpenStudio Measure Tester Gem not installed -- will not be able to aggregate and dashboard the results of tests'
end
require_relative '../resources/btap_workflow.rb'
require 'fileutils'
#require 'optparse'

class Btap_results_helper

  def btap_results_regression_test()
    args = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: example.rb [options]"
      opts.on("-b", "--building_type=NAME", "Building Type") do |n|
        args['building_type'] = n
      end

      opts.on("-t", "--template=NAME", "NECB Template(BTAPPRE1980,BTAP1980TO2010,NECB2011, NECB2015, NECB2017, or NECB2020)") do |n|
        args['template'] = n
      end

      opts.on("-f", "--primary_heating_fuel=NAME", "Primary Heating Fuel (NaturalGas,Electricity,FuelOilNo2,HeatPump or DefaultFuel)") do |n|
        args['primary_heating_fuel'] = n
      end

      opts.on("-w", "--epw_file=NAME", "NECB2017-CAN_YT_Whitehorse.Intl.AP.719640_CWEC2016.epw ") do |n|
        args['epw_file'] = n
      end

      opts.on("-k", "--keep_all_results", "Don't delete anything after runs") do |n|
        args['keep_all_results'] = n
      end

      # opts.on("-p", "--postprocess_only", "only if you do not wish to do complete run. This has options to the the os/e+ measures only...or only the reports measures (measures_only|postprocess_only)") do |n|
      #   args['post_process_only'] = n
      # end

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end
    end.parse!

    # set default tolerance
    tolerance = 0.10

    # Arguments passed from command line.
    # BTAPCreatePrototypeBuilding Measure Args.
    building_type = args['building_type']
    template = args['template']
    epw_file = args['epw_file']
    dir_name_fuel = args['primary_heating_fuel']
    primary_heating_fuel = args['primary_heating_fuel']

    if ((template == 'BTAPPRE1980') ||(template == 'BTAP1980TO2010')) && (primary_heating_fuel == 'NaturalGasHPGasBackup')
      raise("HeatPump as fuel type is not valid with templates BTAPPRE1980 and BTAP1980TO2010")
    end
    # CLI args
    # postprocess_only = args['post_process_only']
    keep_all_results = args['keep_all_results']
    puts "tester Helper args pass are:"
    puts args

    #Location of measures folder.
    measures_folder = File.join(__dir__, '../../../measures')
    # Seed files.. in this case dummy files.
    dummy_osm = File.join(__dir__, '..', 'resources', 'dummy.osm')
    dummy_epw = File.join(__dir__, '..', 'resources', 'dummy.epw')
    # Test output folder.
    out_dir = File.join(__dir__, '..', '..', '..', 'costing_output')
    # Model name derived from NECB building, location and template.
    model_name = "#{building_type}-#{template}-#{dir_name_fuel}-#{File.basename(epw_file, '.epw')}"
    # RUn folder for current workflow.
    run_dir = File.join(out_dir, model_name)
    #if !Dir.exists?(run_dir)
    #  Dir.mkdir(run_dir)
    #end

    standard = Standard.build("#{template}")
    #model = standard.load_building_type_from_library(building_type: building_type)
    model = standard.model_create_prototype_model(
      template: template,
      building_type: building_type,
      epw_file: epw_file,
      primary_heating_fuel: primary_heating_fuel,
      sizing_run_dir: run_dir
    )
    standard.model_run_simulation_and_log_errors(model, run_dir)

    # mimic the process of running this measure in OS App or PAT
    model_out_path = "#{run_dir}/final.osm"
    workspace_path = "#{run_dir}/in.idf"
    sql_path = "#{run_dir}/run/eplusout.sql"
    cost_result_json_path = "#{run_dir}/cost_results.json"
    cost_list_json_path = "#{run_dir}/btap_items.json"

    #create osm file to use mimic PAT/OS server called final
    model.save(model_out_path, true)

    # set up runner, this will happen automatically when measure is run in PAT or OpenStudio. Ensure files exist.
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    raise("Could not find osm at this path:#{model_out_path}") unless File.exist?(model_out_path)
    runner.setLastOpenStudioModelPath(OpenStudio::Path.new(model_out_path))
    raise("Could not find idf at this path:#{workspace_path}") unless File.exist?(workspace_path)
    runner.setLastEnergyPlusWorkspacePath(OpenStudio::Path.new(workspace_path))
    raise("Could not find sql at this path:#{sql_path}") unless File.exist?(sql_path)
    runner.setLastEnergyPlusSqlFilePath(OpenStudio::Path.new(sql_path))
    model.save(model_out_path, true)

    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd

    begin
      # create an instance of the measure and runner
      measure = BtapResults.new
      arguments = measure.arguments(model)
      argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)
      expected_args = 16
      raise("The number of arguments #{arguments.size} does not equal the expected number of #{expected_args}") unless arguments.size == expected_args  #TODO: Question: how many args I should set here?

      hourly_data = arguments[0].clone
      raise("Could not set the hourly_data parameter to false") unless hourly_data.setValue("false")
      argument_map['generate_hourly_report'] = hourly_data

      output_diet = arguments[1].clone
      raise("Could not set the output_diet parameter to false") unless output_diet.setValue(false)
      argument_map['output_diet'] = output_diet

      envelope_costing = arguments[2].clone
      raise("Could not set envelope_costing to true") unless envelope_costing.setValue(true)
      argument_map['envelope_costing'] = envelope_costing

      lighting_costing = arguments[3].clone
      raise("Could not set lighting costing to true") unless lighting_costing.setValue(true)
      argument_map['lighting_costing'] = lighting_costing

      boilers_costing = arguments[4].clone
      raise("Could not set boiler costing to true") unless boilers_costing.setValue(true)
      argument_map['boilers_costing'] = boilers_costing

      chillers_costing = arguments[5].clone
      raise("Could not set chiller costing to true") unless chillers_costing.setValue(true)
      argument_map['chillers_costing'] = chillers_costing

      cooling_towers_costing = arguments[6].clone
      raise("Could not set cooling tower costing to true") unless cooling_towers_costing.setValue(true)
      argument_map['cooling_towers_costing'] = cooling_towers_costing

      shw_costing = arguments[7].clone
      raise("Could not set SHW costing to true.") unless shw_costing.setValue(true)
      argument_map['shw_costing'] = shw_costing

      ventilation_costing = arguments[8].clone
      raise("Could not set ventilation costing to true") unless ventilation_costing.setValue(true)
      argument_map['ventilation_costing'] = ventilation_costing

      zone_system_costing = arguments[9].clone
      raise("Could not set zone_system_costing to true") unless zone_system_costing.setValue(true)
      argument_map['zone_system_costing'] = zone_system_costing

      Dir.chdir(run_dir)
      # run the measure
      measure.run(runner, argument_map)
      result = runner.result
      #show_output(result)
      Raise("Costing setup failed") unless result.value.valueName == 'Success'
    ensure
      Dir.chdir(start_dir)
    end

    # Check Cost file exists
    cost_result_json_path = File.join(run_dir, '/cost_results.json')
    raise("Could not find costing json at this path:#{cost_result_json_path}") unless File.exist?(cost_result_json_path)

    # Check Cost results are the same.
    regression_files_folder = "#{File.dirname(__FILE__)}/regression_files"
    expected_result_filename = "#{regression_files_folder}/#{model_name}_expected_result.cost.json"
    test_result_filename = "#{regression_files_folder}/#{model_name}_test_result.cost.json"
    FileUtils.rm(test_result_filename) if File.exists?(test_result_filename)
    puts("Writing test results to #{test_result_filename}")
    FileUtils.cp(cost_result_json_path, test_result_filename)
    if File.exists?(expected_result_filename)
      unless FileUtils.compare_file(cost_result_json_path, expected_result_filename)
        #raise("Regression test for #{model_name} produces differences. Examine expected and test result differences in the #{File.dirname(__FILE__)}/regression_files folder ")
        expected_hash = JSON.parse(File.read(expected_result_filename))
        test_hash = JSON.parse(File.read(test_result_filename))
        error_message = ''
        ["envelope",
         "lighting",
         "heating_and_cooling",
         "shw",
         "ventilation",
         "grand_total"].each do |end_use|
          expected = expected_hash["totals"][end_use]
          test = test_hash["totals"][end_use]
          perc_change = ((test - expected)/ expected) * 100.0
          if perc_change.abs() > tolerance
            error_message << "#{end_use} percent change by #{perc_change}\n"
          end
        end
        if error_message != ''
          raise("Regression test for #{model_name} produces differences. #{error_message}")
        end
      end
  else
    raise("No expected test file...Generating expected file #{expected_result_filename}. Please verify.")
  end

  # Let user know it passed.
  puts "Regression test for #{model_name} passed."

  # Delete all unneeded files unless requested.
  unless keep_all_results
    #These files/folders are required to run the reports measure.
    dont_delete = []
    dont_delete << File.join(run_dir, 'in.osm')
    dont_delete << File.join(run_dir, 'in.osw')
    dont_delete << File.join(run_dir, 'out.osw')
    dont_delete << File.join(run_dir, 'in.idf')
    dont_delete << File.join(run_dir, 'out.idf')
    dont_delete << File.join(run_dir, 'run')
    dont_delete << File.join(run_dir, 'run', 'in.idf')
    dont_delete << File.join(run_dir, 'run', 'eplusout.sql')
    Dir.glob("#{run_dir}/**/*").select { |file| not (dont_delete.include?(file)) }.each { |file| FileUtils.rm_rf(file) }
  end

  #This has to be set to new osm files as a seedfile to work.
  osw_file = OpenStudio::WorkflowJSON.load(OpenStudio::Path.new(File.join(run_dir, 'out.osw'))).get
  osw_file.setSeedFile(File.join(run_dir, 'in.osm'))
  osw_file.saveAs(File.join(run_dir, 'out.osw'))
  return run_dir
end
end
Btap_results_helper.new().btap_results_regression_test()


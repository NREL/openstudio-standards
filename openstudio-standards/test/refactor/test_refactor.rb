require_relative '../helpers/minitest_helper'
require_relative '../helpers/compare_models_helper'
require 'parallel' if Gem::Platform.local.os == 'linux'



class TestRefactorParallel < Minitest::Test

  def self.create_runs_jobs(templates, building_types, climate_zones, epw_files)
    runs = []
    #iterate though all possibilities to test.. for now just these.
    templates.each do |template|
      building_types.each do |building_type|
        climate_zones.each do |climate_zone|
          epw_files.each do |epw_file|
            #set up folders for old and new way of doing things.
            run_name = "#{building_type}-#{template}-#{climate_zone}-#{epw_file}"
            run_dir = "#{Dir.pwd}/output/#{run_name}"
            runs << {
                'template' => template,
                'building_type' => building_type,
                'climate_zone' => climate_zone,
                'epw_file' => epw_file,
                'run_name' => run_name,
                'run_dir' => "#{Dir.pwd}/output/#{run_name}",
                'refactored_run_dir' => "#{run_dir}/refactored/",
                'old_method_run_dir' => "#{run_dir}/old_method/"
            }
          end
        end
      end

    end
    return runs
  end

  def self.create_parallel_tests(runs)
    puts "Running the following #{runs.size} comparisons"
    puts runs
    Parallel.map(runs, in_processes: (Parallel::processor_count)) do |run|
      create_test(run)
    end
  end

  def self.create_serial_tests(runs)
    puts "Running the following #{runs.size} comparisons"
    puts runs
    runs.each do |run|
      create_test(run)
    end
  end

  def self.create_test(run)
    define_method("test_#{run['template']}_#{run['building_type']}_#{run['climate_zone'] }_#{run['epw_file']}") do
      diffs = []
      begin

        FileUtils.mkdir_p(run['refactored_run_dir']) unless Dir.exists?(run['refactored_run_dir'])
        FileUtils.mkdir_p(run['old_method_run_dir']) unless Dir.exists?(run['old_method_run_dir'])
        #new method of create standards model
        prototype_object = StandardsModel.get_standard_model("#{run['template']}_#{run['building_type']}")
        puts "this is a #{prototype_object.class}"
        new_model = prototype_object.model_create_prototype_model(run['climate_zone'], run['epw_file'], run['refactored_run_dir'])
        log_messages_to_file("#{run['refactored_run_dir']}/openstudio_standards.log", debug = false)

        # Reset the log so that only new messages are stored
        reset_log

        #old method of creating a model.
        old_model = OpenStudio::Model::Model.new()
        old_model.create_prototype_building(run['building_type'], run['template'], run['climate_zone'], run['epw_file'], run['old_method_run_dir'])
        log_messages_to_file("#{run['old_method_run_dir']}/openstudio_standards.log", debug = false)

        # Compare the two models.
        puts "Old created is #{old_model.class}"
        puts "Old created is #{new_model.class}"
        diffs = compare_osm_files(old_model, new_model)


      rescue => exception
        # Log error/exception and then keep going.
        error = "#{exception.backtrace.first}: #{exception.message} (#{exception.class})", exception.backtrace.drop(1).map {|s| "\n#{s}"}
        diffs << "#{run['run_name']}: Error \n#{error}"
      end
      #Write out diff or error message
      diff_file = "#{run['old_method_run_dir']}/../differences.json"
      FileUtils.rm(diff_file) if File.exists?(diff_file)
      if diffs.size > 0
        File.write(diff_file, diffs.to_json)
        msg = "There were #{diffs.size} differences/errors in #{run['building_type']} #{run['template']} #{run['climate_zone']} #{run['epw_file']} :\n#{diffs.join("\n")}"
        assert(false, msg)
      end
    end
  end

  ##### Autogenerate Tests for easier

  #####NREL RUNS
  nrel_building_types = [
      "FullServiceRestaurant",
      "Hospital",
      "HighriseApartment",
      "LargeHotel",
      "LargeOffice",
      "MediumOffice",
      "MidriseApartment",
      "Outpatient",
      "PrimarySchool",
      "QuickServiceRestaurant",
      "RetailStandalone",
      "SecondarySchool",
      "SmallHotel",
      "SmallOffice",
      "RetailStripmall",
      "Warehouse"

  ]

  nrel_templates = ['90.1-2010'] # ['DOE Ref Pre-1980']
  nrel_climate_zones = ['ASHRAE 169-2006-1A']
  nrel_epw_files = [nil] # we will need to keep this overloaded to keep arguments consistant.
  nrel_runs = self.create_runs_jobs(nrel_templates, nrel_building_types, nrel_climate_zones, nrel_epw_files)

  ######NRCan runs
  nrcan_building_types = [
      "FullServiceRestaurant",
      "Hospital",
      "HighriseApartment",
      "LargeHotel",
      "LargeOffice",
      "MediumOffice",
      "MidriseApartment",
      "Outpatient",
      "PrimarySchool",
      "QuickServiceRestaurant",
      "RetailStandalone",
      "SecondarySchool",
      "SmallHotel",
      "SmallOffice",
      "RetailStripmall",
      "Warehouse"

  ]
  nrcan_templates = ['NECB 2011']
  nrcan_climate_zones = ['NECB HDD Method']
  nrcan_epw_files = [
      'CAN_BC_Vancouver.718920_CWEC.epw', #  CZ 5 - Gas HDD = 3019
      'CAN_ON_Toronto.716240_CWEC.epw', #CZ 6 - Gas HDD = 4088
      'CAN_PQ_Sherbrooke.716100_CWEC.epw', #CZ 7a - Electric HDD = 5068
      'CAN_YT_Whitehorse.719640_CWEC.epw', #CZ 7b - FuelOil1 HDD = 6946
      'CAN_NU_Resolute.719240_CWEC.epw', # CZ 8  -FuelOil2 HDD = 12570
      'CAN_PQ_Kuujjuarapik.719050_CWEC.epw', # CZ 8  -FuelOil2 HDD = 7986

  ]


  nrcan_runs = create_runs_jobs(nrcan_templates, nrcan_building_types, nrcan_climate_zones, nrcan_epw_files)

  #add runs and run them
  runs = nrcan_runs + nrel_runs
  puts
  case Gem::Platform.local.os
    when 'linux'
      create_parallel_tests(runs)
    else
      create_serial_tests(runs)
  end
end



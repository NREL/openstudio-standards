require_relative '../helpers/minitest_helper'
require_relative '../helpers/compare_models_helper'
require 'zlib'
require 'base64'
require 'digest'
require 'parallel'


class TestRefactorParallel < Minitest::Test


  def parallize_runs(templates, building_types, climate_zones, epw_files)
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

    models_with_differences = []
    processess = (Parallel::processor_count )
    puts "processess #{processess}"
    puts "Running #{runs.size} comparisons"
    Parallel.map(runs, in_processes: processess) do |run|
      diffs = []
      begin

        FileUtils.mkdir_p(run['refactored_run_dir']) unless Dir.exists?(run['refactored_run_dir'])
        FileUtils.mkdir_p(run['old_method_run_dir']) unless Dir.exists?(run['old_method_run_dir'])
        #new method of create standards model
        new_model = StandardsModel.get_standard_model(run['template'])

        # Will eventually use extend here to add building type methods and data.
        # new_model.extend(building_type)

        # Once all template logic and building type logic is removed we will be able to remove the building_type and
        # template arguments and simply call new_model.create_protype_model(climate_zone, epw_file, refactored_run_dir)
        new_model.create_prototype_model(run['building_type'], run['climate_zone'], run['epw_file'], run['refactored_run_dir'])
        log_messages_to_file("#{run['refactored_run_dir']}/openstudio_standards.log", debug = false)

        # Reset the log so that only new messages are stored
        reset_log

        #old method of creating a model.
        old_model = OpenStudio::Model::Model.new()
        old_model.create_prototype_building(run['building_type'], run['template'], run['climate_zone'], run['epw_file'], run['old_method_run_dir'])
        log_messages_to_file("#{run['old_method_run_dir']}/openstudio_standards.log", debug = false)

        # Compare the two models.
        diffs = compare_osm_files(old_model, new_model)


      rescue => exception
        # Log error/exception and then keep going.
        error = "#{exception.backtrace.first}: #{exception.message} (#{exception.class})", exception.backtrace.drop(1).map{|s| "\n#{s}"}
        diffs << "#{run['run_name']}: Error \n#{error}"
      end
      #Write out diff or error message
      diff_file = "#{run['old_method_run_dir']}/../differences.json"
      FileUtils.rm(diff_file) if File.exists?(diff_file)
      File.write(diff_file, diffs.to_json) if diffs.size > 0
    end

    runs.each do |run|
      puts run['run_name']
      diff_file = "#{run['old_method_run_dir']}/../differences.json"
      if File.exists?(diff_file)
        diffs = JSON.parse(File.read(diff_file))
        models_with_differences << "There were #{diffs.size} differences/errors in #{run['building_type']} #{run['template']} #{run['climate_zone']} #{run['epw_file']} :\n#{diffs.join("\n")}"
      end
    end
    # Assert that there are no differences in any models
    assert_equal(0, models_with_differences.size, "There were #{models_with_differences.size} models with differences:\n#{models_with_differences.join("\n")}")
  end

  def test_necb_2011_parallel()

    building_types = [
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
    templates = ['NECB 2011']
    climate_zones = ['NECB HDD Method']
    epw_files = [
        'CAN_BC_Vancouver.718920_CWEC.epw' #, #  CZ 5 - Gas HDD = 3019
    #'CAN_ON_Toronto.716240_CWEC.epw', #CZ 6 - Gas HDD = 4088
    #'CAN_PQ_Sherbrooke.716100_CWEC.epw', #CZ 7a - Electric HDD = 5068
    #'CAN_YT_Whitehorse.719640_CWEC.epw', #CZ 7b - FuelOil1 HDD = 6946
    #'CAN_NU_Resolute.719240_CWEC.epw', # CZ 8  -FuelOil2 HDD = 12570
    #'CAN_PQ_Kuujjuarapik.719050_CWEC.epw', # CZ 8  -FuelOil2 HDD = 7986
    #'CAN_ON_Kingston.716200_CWEC.epw' # This did not run cleanly! Error in 671 of compliance.rb
    ]

    parallize_runs(templates, building_types, climate_zones, epw_files)
  end

  #end function


  def test_nrel
    building_types = [
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

    templates = ['90.1-2010'] # ['DOE Ref Pre-1980']
    climate_zones = ['ASHRAE 169-2006-1A']
    epw_files = [nil] # we will need to keep this overloaded to keep arguments consistant.
    parallize_runs(templates, building_types, climate_zones, epw_files)
  end
end



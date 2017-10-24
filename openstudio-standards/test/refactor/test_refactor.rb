require_relative '../helpers/minitest_helper'
require_relative '../helpers/compare_models_helper'
require 'zlib'
require 'base64'
require 'digest'


class TestRefactor < Minitest::Test


  def test_necb_2011()

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

    models_with_differences = []
    
    #iterate though all possibilities to test.. for now just these.
    templates.each do |template|
      building_types.each do |building_type|
        climate_zones.each do |climate_zone|
          epw_files.each do |epw_file|
            #set up folders for old and new way of doing things.
            run_name = "#{building_type}-#{template}-#{climate_zone}-#{epw_file}"
            run_dir = "#{Dir.pwd}/output/#{run_name}"
            refactored_run_dir = "#{run_dir}/refactored/"
            old_method_run_dir = "#{run_dir}/old_method/"
            FileUtils.mkdir_p(refactored_run_dir) unless Dir.exists?(refactored_run_dir)
            FileUtils.mkdir_p(old_method_run_dir) unless Dir.exists?(old_method_run_dir)
            puts run_dir
            #new method of create standards model
            new_model = StandardsModel.get_standard_model(template)
            
            # Will eventually use extend here to add building type methods and data.
            # new_model.extend(building_type)
            
            # Once all template logic and building type logic is removed we will be able to remove the building_type and
            # template arguments and simply call new_model.create_protype_model(climate_zone, epw_file, refactored_run_dir)
            new_model.create_prototype_model(building_type, climate_zone, epw_file, refactored_run_dir)
            log_messages_to_file("#{refactored_run_dir}/openstudio_standards.log", debug = false)
            
            # Reset the log so that only new messages are stored
            reset_log
            
            #old method of creating a model.
            old_model = OpenStudio::Model::Model.new()
            old_model.create_prototype_building(building_type, template, climate_zone, epw_file, old_method_run_dir)
            log_messages_to_file("#{old_method_run_dir}/openstudio_standards.log", debug = false)
            
            # Compare the two models
            diffs = compare_osm_files(old_model, new_model)
            
            # Log the differences to file
            diff_file = "#{old_method_run_dir}/../differences.log"
            FileUtils.rm(diff_file) if File.exists?(diff_file)
            if diffs.size > 0
              models_with_differences << "There were #{diffs.size} differences in #{building_type} #{template} #{climate_zone} #{epw_file} :\n#{diffs.join("\n")}"
              File.open(diff_file, 'w') do |file|
                diffs.each { |diff| file.puts diff }
              end
            end

          end
        end
      end
    end
    
    # Assert that there are no differences in any models
    assert_equal(0, models_with_differences.size, "There were #{models_with_differences.size} models with differences:\n#{models_with_differences.join("\n")}")
    
  end


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
    
    templates =  ['90.1-2010'] # ['DOE Ref Pre-1980']
    climate_zones = ['ASHRAE 169-2006-1A']
    epw_files = [nil] # we will need to keep this overloaded to keep arguments consistant.

    models_with_differences = []
    
    #iterate though all possibilities to test.. for now just these.
    templates.each do |template|
      building_types.each do |building_type|
        climate_zones.each do |climate_zone|
          epw_files.each do |epw_file|
            #set up folders for old and new way of doing things.
            run_name = "#{building_type}-#{template}-#{climate_zone}-#{epw_file}"
            run_dir = "#{Dir.pwd}/output/#{run_name}"
            refactored_run_dir = "#{run_dir}/refactored/"
            old_method_run_dir = "#{run_dir}/old_method/"
            FileUtils.mkdir_p(refactored_run_dir) unless Dir.exists?(refactored_run_dir)
            FileUtils.mkdir_p(old_method_run_dir) unless Dir.exists?(old_method_run_dir)
            puts run_dir
            #Create the model from the standard/template class.
            new_model = StandardsModel.get_standard_model(template)
            # Will eventually use extend here to add building type methods and data.
            # new_model.extend(building_type)
            # puts new_model.methods.sort
            
            # Once all template logic and building type logic is removed we will be able to remove the building_type and
            # template arguments and simply call new_model.create_protype_model(climate_zone, epw_file, refactored_run_dir)
            new_model.create_prototype_model(building_type, climate_zone, epw_file, refactored_run_dir)
            log_messages_to_file("#{refactored_run_dir}/openstudio_standards.log", debug = false)
            
            # Reset the log so that only new messages are stored
            reset_log
            
            #old method of creating a model.
            old_model = OpenStudio::Model::Model.new()
            old_model.create_prototype_building(building_type, template, climate_zone, epw_file, old_method_run_dir)
            log_messages_to_file("#{old_method_run_dir}/openstudio_standards.log", debug = false)
            
            # Compare the two models
            diffs = compare_osm_files(old_model, new_model)

            # Log the differences to file
            diff_file = "#{old_method_run_dir}../differences.log"
            FileUtils.rm(diff_file) if File.exists?(diff_file)
            if diffs.size > 0
              models_with_differences << "There were #{diffs.size} differences in #{building_type} #{template} #{climate_zone} #{epw_file} :\n#{diffs.join("\n")}"
              File.open(diff_file, 'w') do |file|
                diffs.each { |diff| file.puts diff }
              end
            end

            
          end
        end
      end
    end
    
    # Assert that there are no differences in any models
    assert_equal(0, models_with_differences.size, "There were #{models_with_differences.size} models with differences:\n#{models_with_differences.join("\n")}")
    
  end
end



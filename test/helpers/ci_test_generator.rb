require 'fileutils'

def file_out_dir
  File.absolute_path(File.join(__FILE__,"..","..","ci_test_files"))
end

def doe_dir
  File.absolute_path(File.join(__FILE__,"..","..","doe_prototype"))
end

def cleanup_output_folders
  dirname = File.join(file_out_dir(), 'output')
  if File.directory?(dirname)
    puts "Removing hvac output directory : [#{dirname}]"
    FileUtils.rm_r(dirname)
  end
  necb_out_dirname = File.absolute_path(File.join(__FILE__,"..","..","necb", 'output'))
  if File.directory?(necb_out_dirname)
    puts "Removing necb output directory : [#{necb_out_dirname}]"
    FileUtils.rm_r(necb_out_dirname)
  end
  nrel_out_dirname = File.absolute_path(File.join(__FILE__,"..","..","..", 'output'))
  if File.directory?(nrel_out_dirname)
    puts "Removing nrel output directory : [#{nrel_out_dirname}]"
    FileUtils.rm_r(nrel_out_dirname)
  end
  if File.directory?(file_out_dir())
    puts "Removing and recreating ci_test_files directory : [#{file_out_dir()}]"
    FileUtils.rm_r(file_out_dir())
  end
  FileUtils.mkdir_p(file_out_dir())
end

# copied and modified from https://github.com/rubyworks/facets/blob/master/lib/core/facets/string/snakecase.rb
class String
  def snek
    #gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr('-', '_').
        gsub(/\s/, '_').
        gsub(/__+/, '_').
        gsub(/#+/, '').
        gsub(/\"/, '').
        downcase
  end
end

def generate_ci_bldg_test_files
  templates = ['NECB2011', 'NECB2015']
  building_types = [
      "FullServiceRestaurant",
      "HighriseApartment",
      "Hospital",
      "LargeHotel",
      "LargeOffice",
      "MediumOffice",
      "MidriseApartment",
      "Outpatient",
      "PrimarySchool",
      "QuickServiceRestaurant",
      "RetailStandalone",
      "RetailStripmall",
      "SecondarySchool",
      "SmallHotel",
      "SmallOffice",
      "Warehouse"
  ]
  fuel_types = ['gas', 'electric']
  out_dir = file_out_dir()
  templates.each {|template|
    building_types.each {|building_type|
      fuel_types.each {|fuel_type|
        filename = File.join(out_dir,"test_necb_bldg_#{building_type}_#{template}_#{fuel_type}.rb")
        file_string =%Q{
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../helpers/compare_models_helper'
require_relative '../necb/regression_helper'

class Test_#{building_type}_#{template}_#{fuel_type} < NECBRegressionHelper
  def setup()
    super()
    @building_type = '#{building_type}'
  end
  def test_#{template}_#{building_type}_regression_#{fuel_type}()
    result, msg = create_model_and_regression_test(@building_type,
                                                   @#{fuel_type}_location,
                                                   '#{template}'
    )
    assert(result, msg)
  end
end
}
        File.open(filename, 'w') { |file| file.write(file_string) }
      }
    }
  }
end

def write_file_path_to_ci_tests_txt
  circleci_tests_txt_path = File.absolute_path(File.join(__FILE__, "..", "..", "circleci_tests.txt"))
  #puts circleci_tests_txt_path

  # get the content of circleci_tests.txt file
  files = IO.readlines(circleci_tests_txt_path)
  new_file_content = files.clone

  # remove lines which contains the test_necb_bldg_*.rb
  files.each_with_index {|line, i|
    if  line.include?("necb/test_necb_bldg_") or \
        line.include?("necb/test_necb_hvac") or \
        line.include?("doe_prototype/test_add_hvac_systems") or \
        line.include?("doe_prototype/test_full_service_restaurant.rb") or \
        line.include?("doe_prototype/test_high_rise_apartment.rb") or \
        line.include?("doe_prototype/test_hospital.rb") or \
        line.include?("doe_prototype/test_large_hotel.rb") or \
        line.include?("doe_prototype/test_large_office.rb") or \
        line.include?("doe_prototype/test_medium_office.rb") or \
        line.include?("doe_prototype/test_mid_rise_apartment.rb") or \
        line.include?("doe_prototype/test_outpatient.rb") or \
        line.include?("doe_prototype/test_primary_school.rb") or \
        line.include?("doe_prototype/test_quick_service_restaurant.rb") or \
        line.include?("doe_prototype/test_retail_standalone.rb") or \
        line.include?("doe_prototype/test_secondary_school.rb") or \
        line.include?("doe_prototype/test_small_hotel.rb") or \
        line.include?("doe_prototype/test_small_office.rb") or \
        line.include?("doe_prototype/test_strip_mall.rb") or \
        line.include?("doe_prototype/test_supermarket.rb") or \
        line.include?("doe_prototype/test_warehouse.rb") or \
        line.include?("ci_test_files/") # remove all previously written ci_test_files

      new_file_content = new_file_content - [files[i]]
    end
  }

  # overwrite circleci_tests.txt without the test_necb_bldg_*.rb lines
  File.open(circleci_tests_txt_path, 'w') { |f|
    new_file_content.each {|line|
      f.puts line
    }
  }

  # add the new nrcan files generated by this script to the circleci_tests.txt
  File.open(circleci_tests_txt_path, 'a') { |f|
    files_path = File.expand_path(File.join(__FILE__,"..","..","ci_test_files", "test_necb_*.rb"))
    puts files_path
    Dir[files_path].sort.each {|path|
      f.puts(path.to_s.gsub(/^.+(openstudio-standards\/test\/)/,''))
    }
  }

  # add the new doe files generated by this script to the circleci_tests.txt
  File.open(circleci_tests_txt_path, 'a') { |f|
    files_path = File.expand_path(File.join(__FILE__,"..","..","ci_test_files", "doe_test*.rb"))
    puts files_path
    Dir[files_path].sort.each {|path|
      f.puts(path.to_s.gsub(/^.+(openstudio-standards\/test\/)/,''))
    }
  }
end

def copy_model_files_for_hvac_tests
  out_dir = file_out_dir()
  model_dir = File.join(out_dir, 'models')
  FileUtils.mkpath(model_dir)
  FileUtils.copy_entry( File.absolute_path(File.join(__dir__, "..", "necb", "models")), model_dir)
end

def copy_doe_model_files_for_hvac_tests
  model_dir = File.join(file_out_dir(), 'models')
  FileUtils.mkpath(model_dir)
  FileUtils.copy_entry( File.absolute_path(File.join(doe_dir(), "models")), model_dir)
end

def generate_hvac_sys1_files

  boiler_fueltypes = ["NaturalGas", "Electricity", "FuelOil#2"]
  mau_types = [true, false]
  mau_heating_coil_types = ["Hot Water", "Electric"]
  baseboard_types = ["Hot Water", "Electric"]

  boiler_fueltypes.each {|boiler_fueltype|
    mau_types.each {|mau_type|
      mau_heating_coil_types.each {|mau_heating_coil_type|
        baseboard_types.each {|baseboard_type|
        filename = File.join(file_out_dir(),"test_necb_hvac_system_1-#{boiler_fueltype.snek}-#{mau_type.to_s.snek}-#{mau_heating_coil_type.snek}-#{baseboard_type.snek}.rb")
        puts filename
        file_string = %q{
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


#This will run all the combinations possible with the inputs for each system.  The test will.
#0. Save the baseline file as baseline.osm
#1.	Add the system to the model using the hvac.rb routines and save that step as *.rb
#2.	Run the Standards methods and save that as the *.osm.
#3.	The name of the file will represent the combination used for that system
#4.	Only after all the system files are created the files will then be simulated.
#5.	Annual results will be contained in the Annual_results.csv file and failed simulations will be in the Failted.txt file.
#
#All output is in the test/output folder.
#Set the switch true to run the standards in the test
#PERFORM_STANDARDS = true
#Set to true to run the simulations.
#FULL_SIMULATIONS = true
#
#NOTE: The test will fail on the first error for each system to save time.
#NOTE: You can use Kdiff3 three file to select the baseline, *.hvac.rb, and *.osm
#      file for a three way diff of before sizing, and then standard application.
#NOTE: To focus on a single system type "dont_" in front of the tests you do not want to run.
#       EX: def dont_test_system_1()
# Hopefully this makes is easier to debug the HVAC stuff!


class NECB_HVAC_System_1_Test < MiniTest::Test


  WEATHER_FILE = 'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'
  Vintages = ['NECB2011']


  #System #1 ToDo
  # mua_types = false will fail. (PTAC Issue Kamel Mentioned)
  #Control zone for SZ systems.


  def test_system_1_$(boiler_fueltypes_snake)_$(mau_types_snake)_$(mau_heating_coil_types_snake)_$(baseboard_types_snake)()
    boiler_fueltypes = ["$(boiler_fueltypes)"]
    mau_types = [$(mau_types)]
    mau_heating_coil_types = ["$(mau_heating_coil_types)"]
    baseboard_types = ["$(baseboard_types)"]
    output_folder = "#{File.dirname(__FILE__)}/output/test_necb_system_1"

    name = String.new

    #Create folder
    # FileUtils.rm_rf(output_folder)
    FileUtils::mkdir_p(output_folder)

    #interate through combinations.

    Vintages.each do |vintage|
      standard = Standard.build(vintage)
      boiler_fueltypes.each do |boiler_fueltype|
        baseboard_types.each do |baseboard_type|
          mau_types.each do |mau_type|
            hw_loop = nil
            model = nil
            if mau_type == true
              mau_heating_coil_types.each do |mau_heating_coil_type|
                name = "sys1_Boiler-#{boiler_fueltype}_Mau-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}"
                puts "***************************************#{name}*******************************************************\n"
                model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
                BTAP::Environment::WeatherFile.new(WEATHER_FILE).set_weather_file(model)
                if (baseboard_type == "Hot Water") || (mau_heating_coil_type == "Hot Water")
                  hw_loop = OpenStudio::Model::PlantLoop.new(model)
                  BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, model.alwaysOnDiscreteSchedule)
                end
                BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys1(
                    model,
                    model.getThermalZones,
                    boiler_fueltype,
                    mau_type,
                    mau_heating_coil_type,
                    baseboard_type,
                    hw_loop)
                #Save the model after btap hvac.
                BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
                #run the standards
                result = run_the_measure( model, standard, "#{output_folder}/#{name}/sizing" )
                #Save the model
                BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
                assert_equal(true, result, "Failure in Standards for #{name}")
              end
            else
              name = "sys1_Boiler-#{boiler_fueltype}_Mau-#{mau_type}_MauCoil-None_Baseboard-#{baseboard_type}"
              puts "***************************************#{name}*******************************************************\n"
              model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
              BTAP::Environment::WeatherFile.new(WEATHER_FILE).set_weather_file(model)
              if (baseboard_type == "Hot Water")
                hw_loop = OpenStudio::Model::PlantLoop.new(model)
                BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, model.alwaysOnDiscreteSchedule)
              end
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys1(
                  model,
                  model.getThermalZones,
                  boiler_fueltype,
                  mau_type,
                  "Electric", #value will not be used.
                  baseboard_type,
                  hw_loop)
              #Save the model after btap hvac.
              BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")

              result = run_the_measure(model,standard, "#{output_folder}/#{name}/sizing")

              #Save model after standards
              BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
              assert_equal(true, result, "Failure in Standards for #{name}")

            end
            result = standard.model_run_simulation_and_log_errors(model, "#{output_folder}/#{name}/")
            assert_equal(true, result, "Failure in Standards for #{name}")
          end
        end
      end
    end
  end


  def run_the_measure(model, standard, sizing_dir)
      # Hard-code the building vintage
      building_type = 'FullServiceRestaurant' # Does not use this...
      climate_zone = 'NECB HDD Method'

      if !Dir.exists?(sizing_dir)
        FileUtils.mkdir_p(sizing_dir)
      end
      # Perform a sizing run
      if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
        puts "could not find sizing run #{sizing_dir}/SizingRun1"
        raise("could not find sizing run #{sizing_dir}/SizingRun1")
        return false
      else
        puts "found sizing run #{sizing_dir}/SizingRun1"
      end

      # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
      # need to set prototype assumptions so that HRV added
      standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
      # Apply the HVAC efficiency standard
      standard.model_apply_hvac_efficiency_standard(model, climate_zone)
      #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
      # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
      return true
    end
end}

        file_string['$(boiler_fueltypes)'] = boiler_fueltype
        file_string['$(mau_types)'] = mau_type.to_s
        file_string['$(mau_heating_coil_types)'] = mau_heating_coil_type
        file_string['$(baseboard_types)'] = baseboard_type

        file_string['$(boiler_fueltypes_snake)'] = boiler_fueltype.to_s.snek
        file_string['$(mau_types_snake)'] = mau_type.to_s.snek
        file_string['$(mau_heating_coil_types_snake)'] = mau_heating_coil_type.to_s.snek
        file_string['$(baseboard_types_snake)'] = baseboard_type.to_s.snek

        File.open(filename, 'w') { |file| file.write(file_string) }
        }
      }
    }
  }

end

def generate_hvac_sys2_files
  boiler_fueltypes = ["NaturalGas", "Electricity", "FuelOil#2",]
  chiller_types = ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"]
  mua_cooling_types = ["Hydronic", "DX"]
  boiler_fueltypes.each {|boiler_fueltype|
    chiller_types.each {|chiller_type|
      mua_cooling_types.each {|mua_cooling_type|
        filename = File.join(file_out_dir(),"test_necb_hvac_system_2_#{boiler_fueltype.snek}-#{chiller_type.to_s.snek}-#{mua_cooling_type.snek}.rb")
        puts filename
        file_string = %q{require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


#This will run all the combinations possible with the inputs for each system.  The test will.
#0. Save the baseline file as baseline.osm
#1.	Add the system to the model using the hvac.rb routines and save that step as *.rb
#2.	Run the Standards methods and save that as the *.osm.
#3.	The name of the file will represent the combination used for that system
#4.	Only after all the system files are created the files will then be simulated.
#5.	Annual results will be contained in the Annual_results.csv file and failed simulations will be in the Failted.txt file.
#
#All output is in the test/output folder.
#Set the switch true to run the standards in the test
#PERFORM_STANDARDS = true
#Set to true to run the simulations.
#FULL_SIMULATIONS = true
#
#NOTE: The test will fail on the first error for each system to save time.
#NOTE: You can use Kdiff3 three file to select the baseline, *.hvac.rb, and *.osm
#      file for a three way diff of before sizing, and then standard application.
#NOTE: To focus on a single system type "dont_" in front of the tests you do not want to run.
#       EX: def dont_test_system_1()
# Hopefully this makes is easier to debug the HVAC stuff!


class NECB_HVAC_System_2_Test < MiniTest::Test
  WEATHER_FILE = 'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'
  Vintages = ['NECB2011']


  #System #2
  #Sizing Convergence Errors when mua_cooling_types = DX
  def test_system_2_$(boiler_fueltypes_snake)_$(chiller_types_snake)_$(mua_cooling_types_snake)()

    boiler_fueltypes = ["$(boiler_fueltype)"]
    chiller_types = ["$(chiller_type)"]
    mua_cooling_types = ["$(mua_cooling_type)"]
    output_folder = "#{File.dirname(__FILE__)}/output/test_necb_system_2"

    name = String.new
    #create folders
    # FileUtils.rm_rf(output_folder)
    FileUtils::mkdir_p(output_folder)

    Vintages.each do |vintage|
      standard = Standard.build(vintage)
      boiler_fueltypes.each do |boiler_fueltype|
        chiller_types.each do |chiller_type|
          mua_cooling_types.each do |mua_cooling_type|
            name = "sys2_Boiler-#{boiler_fueltype}_Chiller#-#{chiller_type}_MuACoolingType-#{mua_cooling_type}"
            puts "***************************************#{name}*******************************************************\n"
            model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
            BTAP::Environment::WeatherFile.new(WEATHER_FILE).set_weather_file(model)
            hw_loop = OpenStudio::Model::PlantLoop.new(model)
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, model.alwaysOnDiscreteSchedule)
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(
                model,
                model.getThermalZones,
                boiler_fueltype,
                chiller_type,
                mua_cooling_type,
                hw_loop)
            #Save the model after btap hvac.
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
            result = run_the_measure(model, standard, "#{output_folder}/#{name}/sizing")
            #Save model after standards
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
            assert_equal(true, result, "Failure in Standards for #{name}")
            #Run Sims
            result = standard.model_run_simulation_and_log_errors(model, "#{output_folder}/#{name}/")
            assert_equal(true, result, "Failure in Standards for #{name}")
          end
        end
      end
    end
  end

  def run_the_measure(model, standard, sizing_dir)
    # Hard-code the building vintage
    building_type = 'FullServiceRestaurant' # Does not use this...
    climate_zone = 'NECB HDD Method'

    if !Dir.exists?(sizing_dir)
      FileUtils.mkdir_p(sizing_dir)
    end
    # Perform a sizing run
    if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
      puts "could not find sizing run #{sizing_dir}/SizingRun1"
      raise("could not find sizing run #{sizing_dir}/SizingRun1")
      return false
    else
      puts "found sizing run #{sizing_dir}/SizingRun1"
    end

    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
    # need to set prototype assumptions so that HRV added
    standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # Apply the HVAC efficiency standard
    standard.model_apply_hvac_efficiency_standard(model, climate_zone)
    #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
    return true
  end
end
}
        file_string['$(boiler_fueltype)'] = boiler_fueltype
        file_string['$(chiller_type)'] = chiller_type.to_s
        file_string['$(mua_cooling_type)'] = mua_cooling_type

        file_string['$(boiler_fueltypes_snake)'] = boiler_fueltype.to_s.snek
        file_string['$(chiller_types_snake)'] = chiller_type.to_s.snek
        file_string['$(mua_cooling_types_snake)'] = mua_cooling_type.to_s.snek

        File.open(filename, 'w') { |file| file.write(file_string) }
      }
    }
  }

end

def generate_hvac_sys3_files
  boiler_fueltypes = ["NaturalGas", "Electricity", "FuelOil#2"]
  baseboard_types = ["Hot Water", "Electric"]
  heating_coil_types_sys3 = ["Electric", "Gas", "DX"]

  boiler_fueltypes.each {|boiler_fueltype|
    baseboard_types.each {|baseboard_type|
      heating_coil_types_sys3.each {|heating_coil_type|
        filename = File.join(file_out_dir(),"test_necb_hvac_system_3_#{boiler_fueltype.snek}-#{baseboard_type.to_s.snek}-#{heating_coil_type.snek}.rb")
        puts filename
        file_string = %q{
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


#This will run all the combinations possible with the inputs for each system.  The test will.
#0. Save the baseline file as baseline.osm
#1.	Add the system to the model using the hvac.rb routines and save that step as *.rb
#2.	Run the Standards methods and save that as the *.osm.
#3.	The name of the file will represent the combination used for that system
#4.	Only after all the system files are created the files will then be simulated.
#5.	Annual results will be contained in the Annual_results.csv file and failed simulations will be in the Failted.txt file.
#
#All output is in the test/output folder.
#Set the switch true to run the standards in the test
#PERFORM_STANDARDS = true
#Set to true to run the simulations.
#FULL_SIMULATIONS = true
#
#NOTE: The test will fail on the first error for each system to save time.
#NOTE: You can use Kdiff3 three file to select the baseline, *.hvac.rb, and *.osm
#      file for a three way diff of before sizing, and then standard application.
#NOTE: To focus on a single system type "dont_" in front of the tests you do not want to run.
#       EX: def dont_test_system_1()
# Hopefully this makes is easier to debug the HVAC stuff!


class NECB_HVAC_System_3_Test < MiniTest::Test
  WEATHER_FILE = 'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'
  Vintages = ['NECB2011']


  def test_system_3_$(boiler_fueltypes_snake)_$(baseboard_types_snake)_$(heating_coil_type_snake)()
    boiler_fueltypes = ["$(boiler_fueltype)"]
    baseboard_types = ["$(baseboard_type)"]
    heating_coil_types_sys3 = ["$(heating_coil_type)"]
    output_folder = "#{File.dirname(__FILE__)}/output/test_necb_system_3"

    name = String.new

    # FileUtils.rm_rf(output_folder)
    FileUtils::mkdir_p(output_folder)

    Vintages.each do |vintage|
      standard = Standard.build(vintage)
      boiler_fueltypes.each do |boiler_fueltype|
        baseboard_types.each do |baseboard_type|
          heating_coil_types_sys3.each do |heating_coil_type_sys3|
            name = "sys3_Boiler-#{boiler_fueltype}_HeatingCoilType#-#{heating_coil_type_sys3}_BaseboardType-#{baseboard_type}"
            puts "***************************************#{name}*******************************************************\n"
            model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
            BTAP::Environment::WeatherFile.new(WEATHER_FILE).set_weather_file(model)
            hw_loop = nil
            if (baseboard_type == "Hot Water")
              hw_loop = OpenStudio::Model::PlantLoop.new(model)
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, model.alwaysOnDiscreteSchedule)
            end
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys3(
                model,
                model.getThermalZones,
                boiler_fueltype,
                heating_coil_type_sys3,
                baseboard_type,
                hw_loop)
            #Save the model after btap hvac.
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
            result = run_the_measure(model, standard, "#{output_folder}/#{name}/sizing")
            #Save model after standards
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
            assert_equal(true, result, "Failure in Standards for #{name}")
            #Run Sims
            result = standard.model_run_simulation_and_log_errors(model, "#{output_folder}/#{name}/")
            assert_equal(true, result, "Failure in Standards for #{name}")
          end
        end
      end
    end
  end

  def run_the_measure(model, standard, sizing_dir)
    # Hard-code the building vintage
    building_type = 'FullServiceRestaurant' # Does not use this...
    climate_zone = 'NECB HDD Method'

    if !Dir.exists?(sizing_dir)
      FileUtils.mkdir_p(sizing_dir)
    end
    # Perform a sizing run
    if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
      puts "could not find sizing run #{sizing_dir}/SizingRun1"
      raise("could not find sizing run #{sizing_dir}/SizingRun1")
      return false
    else
      puts "found sizing run #{sizing_dir}/SizingRun1"
    end

    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
    # need to set prototype assumptions so that HRV added
    standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # Apply the HVAC efficiency standard
    standard.model_apply_hvac_efficiency_standard(model, climate_zone)
    #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
    return true
  end
end
}
        file_string['$(boiler_fueltype)'] = boiler_fueltype
        file_string['$(baseboard_type)'] = baseboard_type.to_s
        file_string['$(heating_coil_type)'] = heating_coil_type

        file_string['$(boiler_fueltypes_snake)'] = boiler_fueltype.to_s.snek
        file_string['$(baseboard_types_snake)'] = baseboard_type.to_s.snek
        file_string['$(heating_coil_type_snake)'] = heating_coil_type.to_s.snek

        File.open(filename, 'w') { |file| file.write(file_string) }
      }
    }
  }

end

def generate_hvac_sys4_files
  boiler_fueltypes = ["NaturalGas", "Electricity", "FuelOil#2",]
  baseboard_types = ["Hot Water", "Electric"]
  heating_coil_types_sys4 = ["Electric", "Gas"]

  boiler_fueltypes.each {|boiler_fueltype|
    baseboard_types.each {|baseboard_type|
      heating_coil_types_sys4.each {|heating_coil_type|
        filename = File.join(file_out_dir(),"test_necb_hvac_system_4_#{boiler_fueltype.snek}-#{baseboard_type.to_s.snek}-#{heating_coil_type.snek}.rb")
        puts filename

        file_string = %q{require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


#This will run all the combinations possible with the inputs for each system.  The test will.
#0. Save the baseline file as baseline.osm
#1.	Add the system to the model using the hvac.rb routines and save that step as *.rb
#2.	Run the Standards methods and save that as the *.osm.
#3.	The name of the file will represent the combination used for that system
#4.	Only after all the system files are created the files will then be simulated.
#5.	Annual results will be contained in the Annual_results.csv file and failed simulations will be in the Failted.txt file.
#
#All output is in the test/output folder.
#Set the switch true to run the standards in the test
#PERFORM_STANDARDS = true
#Set to true to run the simulations.
#FULL_SIMULATIONS = true
#
#NOTE: The test will fail on the first error for each system to save time.
#NOTE: You can use Kdiff3 three file to select the baseline, *.hvac.rb, and *.osm
#      file for a three way diff of before sizing, and then standard application.
#NOTE: To focus on a single system type "dont_" in front of the tests you do not want to run.
#       EX: def dont_test_system_1()
# Hopefully this makes is easier to debug the HVAC stuff!


class NECB_HVAC_System_4_Test < MiniTest::Test
  WEATHER_FILE = 'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'
  Vintages = ['NECB2011']


  def test_system_4_$(boiler_fueltypes_snake)_$(baseboard_types_snake)_$(heating_coil_type_snake)()
    boiler_fueltypes = ["$(boiler_fueltype)"]
    baseboard_types = ["$(baseboard_type)"]
    heating_coil_types_sys4 = ["$(heating_coil_type)"]
    output_folder = "#{File.dirname(__FILE__)}/output/test_necb_system_4"

    name = String.new

    # FileUtils.rm_rf(output_folder)
    FileUtils::mkdir_p(output_folder)


    Vintages.each do |vintage|
      standard = Standard.build(vintage)
      boiler_fueltypes.each do |boiler_fueltype|
        baseboard_types.each do |baseboard_type|
          heating_coil_types_sys4.each do |heating_coil|
            name = "sys4_Boiler-#{boiler_fueltype}_HeatingCoilType#-#{heating_coil}_BaseboardType-#{baseboard_type}"
            puts "***************************************#{name}*******************************************************\n"
            model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
            BTAP::Environment::WeatherFile.new(WEATHER_FILE).set_weather_file(model)
            hw_loop = nil
            if (baseboard_type == "Hot Water")
              hw_loop = OpenStudio::Model::PlantLoop.new(model)
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, model.alwaysOnDiscreteSchedule)
            end
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys4(
                model,
                model.getThermalZones,
                boiler_fueltype,
                heating_coil,
                baseboard_type,
                hw_loop)
            #Save the model after btap hvac.
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
            result = run_the_measure(model, standard, "#{output_folder}/#{name}/sizing")
            #Save model after standards
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
            assert_equal(true, result, "Failure in Standards for #{name}")
            result = standard.model_run_simulation_and_log_errors(model, "#{output_folder}/#{name}/")
            assert_equal(true, result, "Failure in Standards for #{name}")
          end
        end
      end
    end
  end


  def run_the_measure(model, standard, sizing_dir)
    # Hard-code the building vintage
    building_type = 'FullServiceRestaurant' # Does not use this...
    climate_zone = 'NECB HDD Method'

    if !Dir.exists?(sizing_dir)
      FileUtils.mkdir_p(sizing_dir)
    end
    # Perform a sizing run
    if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
      puts "could not find sizing run #{sizing_dir}/SizingRun1"
      raise("could not find sizing run #{sizing_dir}/SizingRun1")
      return false
    else
      puts "found sizing run #{sizing_dir}/SizingRun1"
    end

    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
    # need to set prototype assumptions so that HRV added
    standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # Apply the HVAC efficiency standard
    standard.model_apply_hvac_efficiency_standard(model, climate_zone)
    #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
    return true
  end
end
}
        file_string['$(boiler_fueltype)'] = boiler_fueltype
        file_string['$(baseboard_type)'] = baseboard_type.to_s
        file_string['$(heating_coil_type)'] = heating_coil_type

        file_string['$(boiler_fueltypes_snake)'] = boiler_fueltype.to_s.snek
        file_string['$(baseboard_types_snake)'] = baseboard_type.to_s.snek
        file_string['$(heating_coil_type_snake)'] = heating_coil_type.to_s.snek

        File.open(filename, 'w') { |file| file.write(file_string) }
      }
    }
  }

end

def generate_hvac_sys5_files
  boiler_fueltypes = ["NaturalGas", "Electricity", "FuelOil#2",]
  chiller_types = ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"]
  mua_cooling_types = ["DX", "Hydronic"]
  boiler_fueltypes.each {|boiler_fueltype|
    chiller_types.each {|chiller_type|
      mua_cooling_types.each {|mua_cooling_type|
        filename = File.join(file_out_dir(),"test_necb_hvac_system_5_#{boiler_fueltype.snek}-#{chiller_type.to_s.snek}-#{mua_cooling_type.snek}.rb")
        puts filename
        file_string = %q{
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


#This will run all the combinations possible with the inputs for each system.  The test will.
#0. Save the baseline file as baseline.osm
#1.	Add the system to the model using the hvac.rb routines and save that step as *.rb
#2.	Run the Standards methods and save that as the *.osm.
#3.	The name of the file will represent the combination used for that system
#4.	Only after all the system files are created the files will then be simulated.
#5.	Annual results will be contained in the Annual_results.csv file and failed simulations will be in the Failted.txt file.
#
#All output is in the test/output folder.
#Set the switch true to run the standards in the test
#PERFORM_STANDARDS = true
#Set to true to run the simulations.
#FULL_SIMULATIONS = true
#
#NOTE: The test will fail on the first error for each system to save time.
#NOTE: You can use Kdiff3 three file to select the baseline, *.hvac.rb, and *.osm
#      file for a three way diff of before sizing, and then standard application.
#NOTE: To focus on a single system type "dont_" in front of the tests you do not want to run.
#       EX: def dont_test_system_1()
# Hopefully this makes is easier to debug the HVAC stuff!


class NECB_HVAC_System_5_Test < MiniTest::Test
  WEATHER_FILE = 'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'
  Vintages = ['NECB2011']

  #System #1 ToDo
  # mua_types = false will fail. (PTAC Issue Kamel Mentioned)
  #Control zone for SZ systems.


  def test_system_5_$(boiler_fueltypes_snake)_$(chiller_types_snake)_$(mua_cooling_types_snake)()
    boiler_fueltypes = ["$(boiler_fueltype)"]
    chiller_types = ["$(chiller_type)"]
    mua_cooling_types = ["$(mua_cooling_type)"]
    output_folder = "#{File.dirname(__FILE__)}/output/test_necb_system_5"

    name = String.new

    # FileUtils.rm_rf(output_folder)
    FileUtils::mkdir_p(output_folder)

    Vintages.each do |vintage|
      standard = Standard.build(vintage)
      boiler_fueltypes.each do |boiler_fueltype|
        chiller_types.each do |chiller_type|
          mua_cooling_types.each do |mua_cooling_type|
            name = "sys5_Boiler-#{boiler_fueltype}_ChillerType-#{chiller_type}_MuaCoolingType-#{mua_cooling_type}"
            puts "***************************************#{name}*******************************************************\n"
            model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
            BTAP::Environment::WeatherFile.new(WEATHER_FILE).set_weather_file(model)
            hw_loop = OpenStudio::Model::PlantLoop.new(model)
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, model.alwaysOnDiscreteSchedule)
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys5(
                model,
                model.getThermalZones,
                boiler_fueltype,
                chiller_type,
                mua_cooling_type,
                hw_loop)
            #Save the model after btap hvac.
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
            result = run_the_measure(model, standard, "#{output_folder}/#{name}/sizing")
            #Save model after standards
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
            assert_equal(true, result, "Failure in Standards for #{name}")
            result = standard.model_run_simulation_and_log_errors(model, "#{output_folder}/#{name}/")
            assert_equal(true, result, "Failure in Standards for #{name}")
          end
        end
      end
    end
  end


  def run_the_measure(model, standard, sizing_dir)
    # Hard-code the building vintage
    building_type = 'FullServiceRestaurant' # Does not use this...
    climate_zone = 'NECB HDD Method'

    if !Dir.exists?(sizing_dir)
      FileUtils.mkdir_p(sizing_dir)
    end
    # Perform a sizing run
    if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
      puts "could not find sizing run #{sizing_dir}/SizingRun1"
      raise("could not find sizing run #{sizing_dir}/SizingRun1")
      return false
    else
      puts "found sizing run #{sizing_dir}/SizingRun1"
    end

    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
    # need to set prototype assumptions so that HRV added
    standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # Apply the HVAC efficiency standard
    standard.model_apply_hvac_efficiency_standard(model, climate_zone)
    #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
    return true
  end


end
}
        file_string['$(boiler_fueltype)'] = boiler_fueltype
        file_string['$(chiller_type)'] = chiller_type.to_s
        file_string['$(mua_cooling_type)'] = mua_cooling_type

        file_string['$(boiler_fueltypes_snake)'] = boiler_fueltype.to_s.snek
        file_string['$(chiller_types_snake)'] = chiller_type.to_s.snek
        file_string['$(mua_cooling_types_snake)'] = mua_cooling_type.to_s.snek

        File.open(filename, 'w') { |file| file.write(file_string) }
      }
    }
  }

end

def generate_hvac_sys6_files
  boiler_fueltypes = ["NaturalGas", "Electricity", "FuelOil#2",]
  baseboard_types = ["Hot Water", "Electric"]
  chiller_types = ["Scroll"] #,"Centrifugal","Rotary Screw","Reciprocating"] are not working.
  heating_coil_types_sys6 = ["Electric", "Hot Water"]
  fan_types = ["AF_or_BI_rdg_fancurve", "AF_or_BI_inletvanes", "fc_inletvanes", "var_speed_drive"]

  boiler_fueltypes.each {|boiler_fueltype|
    baseboard_types.each {|baseboard_type|
      chiller_types.each {|chiller_type|
        heating_coil_types_sys6.each {|heating_coil_type|
          fan_types.each {|fan_type|
            filename = File.join(file_out_dir(),"test_necb_hvac_system_6_#{boiler_fueltype.snek}-#{baseboard_type.snek}-#{chiller_type.to_s.snek}-#{heating_coil_type.snek}-#{fan_type.to_s.snek}.rb")
            puts filename
            file_string = %q{
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


#This will run all the combinations possible with the inputs for each system.  The test will.
#0. Save the baseline file as baseline.osm
#1.	Add the system to the model using the hvac.rb routines and save that step as *.rb
#2.	Run the Standards methods and save that as the *.osm.
#3.	The name of the file will represent the combination used for that system
#4.	Only after all the system files are created the files will then be simulated.
#5.	Annual results will be contained in the Annual_results.csv file and failed simulations will be in the Failted.txt file.
#
#All output is in the test/output folder.
#Set the switch true to run the standards in the test
#PERFORM_STANDARDS = true
#Set to true to run the simulations.
#FULL_SIMULATIONS = true
#
#NOTE: The test will fail on the first error for each system to save time.
#NOTE: You can use Kdiff3 three file to select the baseline, *.hvac.rb, and *.osm
#      file for a three way diff of before sizing, and then standard application.
#NOTE: To focus on a single system type "dont_" in front of the tests you do not want to run.
#       EX: def dont_test_system_1()
# Hopefully this makes is easier to debug the HVAC stuff!


class NECB_HVAC_System_6_Test < MiniTest::Test
  WEATHER_FILE = 'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'
  Vintages = ['NECB2011']

  def test_system_6_$(boiler_fueltype_snake)_$(baseboard_type_snake)_$(chiller_type_snake)_$(heating_coil_type_snake)_$(fan_type_snake)()
    boiler_fueltypes = ["$(boiler_fueltype)"]
    baseboard_types = ["$(baseboard_type)"]
    chiller_types = ["$(chiller_type)"] #,"Centrifugal","Rotary Screw","Reciprocating"] are not working.
    heating_coil_types_sys6 = ["$(heating_coil_type)"]
    fan_types = ["$(fan_type)"]
    output_folder = "#{File.dirname(__FILE__)}/output/test_necb_system_6"

    name = String.new

    # FileUtils.rm_rf(output_folder)
    FileUtils::mkdir_p(output_folder)

    #save baseline

    Vintages.each do |vintage|
      standard = Standard.build(vintage)
      boiler_fueltypes.each do |boiler_fueltype|
        chiller_types.each do |chiller_type|
          baseboard_types.each do |baseboard_type|
            heating_coil_types_sys6.each do |heating_coil_type|
              fan_types.each do |fan_type|
                name = "sys6_Bo-#{boiler_fueltype}_Ch-#{chiller_type}_BB-#{baseboard_type}_HC-#{heating_coil_type}_Fan-#{fan_type}"
                puts "***************************************#{name}*******************************************************\n"
                model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
                BTAP::Environment::WeatherFile.new(WEATHER_FILE).set_weather_file(model)
                hw_loop = nil
                if (baseboard_type == "Hot Water") || (heating_coil_type == "Hot Water")
                  hw_loop = OpenStudio::Model::PlantLoop.new(model)
                  BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, model.alwaysOnDiscreteSchedule)
                end
                BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys6(
                    model,
                    model.getThermalZones,
                    boiler_fueltype,
                    heating_coil_type,
                    baseboard_type,
                    chiller_type,
                    fan_type,
                    hw_loop)
                #Save the model after btap hvac.
                BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
                result = run_the_measure( model, standard,"#{output_folder}/#{name}/sizing")
                #Save model after standards
                BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
                assert_equal(true, result, "Failure in Standards for #{name}")
                result = standard.model_run_simulation_and_log_errors(model, "#{output_folder}/#{name}/")
                assert_equal(true, result, "Failure in Standards for #{name}")
              end
            end
          end
        end
      end
    end
  end

  def run_the_measure(model, standard, sizing_dir)
    # Hard-code the building vintage
    building_type = 'FullServiceRestaurant' # Does not use this...
    climate_zone = 'NECB HDD Method'

    if !Dir.exists?(sizing_dir)
      FileUtils.mkdir_p(sizing_dir)
    end
    # Perform a sizing run
    if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
      puts "could not find sizing run #{sizing_dir}/SizingRun1"
      raise("could not find sizing run #{sizing_dir}/SizingRun1")
      return false
    else
      puts "found sizing run #{sizing_dir}/SizingRun1"
    end

    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
    # need to set prototype assumptions so that HRV added
    standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # Apply the HVAC efficiency standard
    standard.model_apply_hvac_efficiency_standard(model, climate_zone)
    #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
    return true
  end
end
}
            file_string['$(boiler_fueltype)'] = boiler_fueltype
            file_string['$(baseboard_type)'] = baseboard_type
            file_string['$(chiller_type)'] = chiller_type
            file_string['$(heating_coil_type)'] = heating_coil_type
            file_string['$(fan_type)'] = fan_type

            file_string['$(boiler_fueltype_snake)'] = boiler_fueltype.to_s.snek
            file_string['$(baseboard_type_snake)'] = baseboard_type.to_s.snek
            file_string['$(chiller_type_snake)'] = chiller_type.to_s.snek
            file_string['$(heating_coil_type_snake)'] = heating_coil_type.to_s.snek
            file_string['$(fan_type_snake)'] = fan_type.to_s.snek

            File.open(filename, 'w') { |file| file.write(file_string) }
          }
        }
      }
    }
  }
end

def generate_hvac_sys7_files
  boiler_fueltypes = ["NaturalGas", "Electricity", "FuelOil#2"]
  chiller_types = ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"]
  mua_cooling_types = ["Hydronic", "DX"]
  boiler_fueltypes.each {|boiler_fueltype|
    chiller_types.each {|chiller_type|
      mua_cooling_types.each {|mua_cooling_type|
        filename = File.join(file_out_dir(),"test_necb_hvac_system_7_#{boiler_fueltype.snek}-#{chiller_type.to_s.snek}-#{mua_cooling_type.snek}.rb")
        puts filename
        file_string = %q{
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


#This will run all the combinations possible with the inputs for each system.  The test will.
#0. Save the baseline file as baseline.osm
#1.	Add the system to the model using the hvac.rb routines and save that step as *.rb
#2.	Run the Standards methods and save that as the *.osm.
#3.	The name of the file will represent the combination used for that system
#4.	Only after all the system files are created the files will then be simulated.
#5.	Annual results will be contained in the Annual_results.csv file and failed simulations will be in the Failted.txt file.
#
#All output is in the test/output folder.
#Set the switch true to run the standards in the test
#PERFORM_STANDARDS = true
#Set to true to run the simulations.
#FULL_SIMULATIONS = true
#
#NOTE: The test will fail on the first error for each system to save time.
#NOTE: You can use Kdiff3 three file to select the baseline, *.hvac.rb, and *.osm
#      file for a three way diff of before sizing, and then standard application.
#NOTE: To focus on a single system type "dont_" in front of the tests you do not want to run.
#       EX: def dont_test_system_1()
# Hopefully this makes is easier to debug the HVAC stuff!


class NECB_HVAC_System_7_Test < MiniTest::Test
  WEATHER_FILE = 'CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw'
  Vintages = ['NECB2011']


  #  #Todo
  #  #Sizing Convergence Errors when mua_cooling_types = DX
  def test_system_7_$(boiler_fueltypes_snake)_$(chiller_types_snake)_$(mua_cooling_types_snake)()
    boiler_fueltypes = ["$(boiler_fueltype)"]
    chiller_types = ["$(chiller_type)"]
    mua_cooling_types = ["$(mua_cooling_type)"]
    output_folder = "#{File.dirname(__FILE__)}/output/test_necb_system_7"
    name = String.new

    # FileUtils.rm_rf(output_folder)
    FileUtils::mkdir_p(output_folder)

    Vintages.each do |vintage|
      standard = Standard.build(vintage)
      boiler_fueltypes.each do |boiler_fueltype|
        chiller_types.each do |chiller_type|
          mua_cooling_types.each do |mua_cooling_type|
            name = "sys7_Boiler-#{boiler_fueltype}_ChillerType-#{chiller_type}_MuaCoolingType-#{mua_cooling_type}"
            puts "***************************************#{name}*******************************************************\n"
            model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
            BTAP::Environment::WeatherFile.new(WEATHER_FILE).set_weather_file(model)
            hw_loop = OpenStudio::Model::PlantLoop.new(model)
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, model.alwaysOnDiscreteSchedule)
            BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(
                model,
                model.getThermalZones,
                boiler_fueltype,
                chiller_type,
                mua_cooling_type,
                hw_loop)
            #Save the model after btap hvac.
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
            result = run_the_measure(model, standard, "#{output_folder}/#{name}/sizing")
            #Save model after standards
            BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
            assert_equal(true, result, "Failure in Standards for #{name}")
            result = standard.model_run_simulation_and_log_errors(model, "#{output_folder}/#{name}/")
            assert_equal(true, result, "Failure in Standards for #{name}")
          end
        end
      end
    end
  end

  def run_the_measure(model, standard, sizing_dir)
    # Hard-code the building vintage
    building_type = 'FullServiceRestaurant' # Does not use this...
    climate_zone = 'NECB HDD Method'

    if !Dir.exists?(sizing_dir)
      FileUtils.mkdir_p(sizing_dir)
    end
    # Perform a sizing run
    if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
      puts "could not find sizing run #{sizing_dir}/SizingRun1"
      raise("could not find sizing run #{sizing_dir}/SizingRun1")
      return false
    else
      puts "found sizing run #{sizing_dir}/SizingRun1"
    end

    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
    # need to set prototype assumptions so that HRV added
    standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # Apply the HVAC efficiency standard
    standard.model_apply_hvac_efficiency_standard(model, climate_zone)
    #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
    return true
  end
end
}
        file_string['$(boiler_fueltype)'] = boiler_fueltype
        file_string['$(chiller_type)'] = chiller_type.to_s
        file_string['$(mua_cooling_type)'] = mua_cooling_type

        file_string['$(boiler_fueltypes_snake)'] = boiler_fueltype.to_s.snek
        file_string['$(chiller_types_snake)'] = chiller_type.to_s.snek
        file_string['$(mua_cooling_types_snake)'] = mua_cooling_type.to_s.snek

        File.open(filename, 'w') { |file| file.write(file_string) }
      }
    }
  }

end

def generate_doe_hvac_files

  hvac_systems = [
    ## Forced Air ##

    # Gas, Electric, forced air
    ['PTAC', 'NaturalGas', nil, 'Electricity'],
    ['PSZ-AC', 'NaturalGas', nil, 'Electricity'],
    # ['PVAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity'], # Disable this; failure due to bug in E+ 8.8 w/ VAV terminal min airflow sizing
    ['VAV Reheat', 'NaturalGas', 'NaturalGas', 'Electricity'],

    # Electric, Electric, forced air
    ['PTHP', 'Electricity', nil, 'Electricity'],
    ['PSZ-HP', 'Electricity', nil, 'Electricity'],
    ['PVAV PFP Boxes', 'Electricity', 'Electricity', 'Electricity'],
    ['VAV PFP Boxes', 'Electricity', 'Electricity', 'Electricity'],

    # District Hot Water, Electric, forced air
    ['PTAC', 'DistrictHeating', nil, 'Electricity'],
    # ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity'], # Disable this; failure due to bug in E+ 8.8 w/ VAV terminal min airflow sizing
    ['VAV Reheat', 'DistrictHeating', 'DistrictHeating', 'Electricity'],

    # Ambient Loop, Ambient Loop, forced air
    # ['PVAV Reheat', 'HeatPump', 'HeatPump', 'HeatPump'],
    # ['VAV Reheat', 'HeatPump', 'HeatPump', 'HeatPump'],

    # Gas, District Chilled Water, forced air
    ['PSZ-AC', 'NaturalGas', nil, 'DistrictCooling'],
    ['PVAV Reheat', 'NaturalGas', 'NaturalGas', 'DistrictCooling'],
    ['VAV Reheat', 'NaturalGas', 'NaturalGas', 'DistrictCooling'],

    # Electric, District Chilled Water, forced air
    ['PSZ-AC', 'Electricity', nil, 'DistrictCooling'],
    ['PVAV Reheat', 'Electricity', 'Electricity', 'DistrictCooling'],
    ['VAV Reheat', 'Electricity', 'Electricity', 'DistrictCooling'],

    # District Hot Water, District Chilled Water, forced air
    ['PVAV Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling'],
    ['VAV Reheat', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling'],

    ## Hydronic ##

    # Gas, Electric, hydronic
    ['Fan Coil with DOAS', 'NaturalGas', nil, 'Electricity'],
    ['Water Source Heat Pumps with DOAS', 'NaturalGas', nil, 'Electricity'],
    ['Fan Coil with DOAS', 'NaturalGas', 'NaturalGas', 'Electricity'],

    # Electric, Electric, hydronic
    ['Ground Source Heat Pumps with ERVs', 'Electricity', nil, 'Electricity'],
    ['Ground Source Heat Pumps with DOAS', 'Electricity', nil, 'Electricity'],
    ['Ground Source Heat Pumps with DOAS', 'Electricity', 'Electricity', 'Electricity'],

    # District Hot Water, Electric, hydronic
    ['Fan Coil with DOAS', 'DistrictHeating', nil, 'Electricity'],
    ['Water Source Heat Pumps with DOAS', 'DistrictHeating', 'DistrictHeating', 'Electricity'],
    ['Fan Coil with DOAS', 'DistrictHeating', 'DistrictHeating', 'Electricity'],

    # Ambient Loop, Ambient Loop, hydronic
    ['Water Source Heat Pumps with ERVs', 'HeatPump', nil, 'HeatPump'],
    ['Water Source Heat Pumps with DOAS', 'HeatPump', nil, 'HeatPump'],
    ['Water Source Heat Pumps with DOAS', 'HeatPump', 'HeatPump', 'HeatPump'],

    # Gas, District Chilled Water, hydronic
    ['Fan Coil with DOAS', 'NaturalGas', nil, 'DistrictCooling'],
    ['Fan Coil with DOAS', 'NaturalGas', 'NaturalGas', 'DistrictCooling'],

    # Electric, District Chilled Water, hydronic
    ['Fan Coil with ERVs', 'Electricity', nil, 'DistrictCooling'],
    ['Fan Coil with DOAS', 'Electricity', 'Electricity', 'DistrictCooling'],

    # District Hot Water, District Chilled Water, hydronic
    ['Fan Coil with ERVs', 'DistrictHeating', nil, 'DistrictCooling'],
    ['Fan Coil with DOAS', 'DistrictHeating', nil, 'DistrictCooling'],
    ['Fan Coil with DOAS', 'DistrictHeating', 'DistrictHeating', 'DistrictCooling']
  ]

  hvac_systems.each {|hvac_system|
    # puts hvac_system.inspect
    filename = File.join(file_out_dir(),"doe_test_add_hvac_systems_#{hvac_system[0].snek}-#{hvac_system[1].to_s.snek}-#{hvac_system[2].inspect.snek}-#{hvac_system[3].snek}.rb")
    puts filename
    file_string = %q{
require_relative '../helpers/minitest_helper'

class TestAddHVACSystems < Minitest::Test

  def test_add_hvac_systems_$(0)_$(1)_$(2)_$(3)

    # Make the output directory if it doesn't exist
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir

    # List all the HVAC system types to test
    hvac_systems = [
      $(hvac_system)
    ]

    template = '90.1-2013'
    standard = Standard.build(template)

    # Add each HVAC system to the test model
    # and run a sizing run to ensure it simulates.
    i = 0
    errs = []
    hvac_systems.each do |system_type, main_heat_fuel, zone_heat_fuel, cool_fuel|
      i += 1
      # next if i < 13

      reset_log

      type_desc = "#{system_type} #{main_heat_fuel} #{zone_heat_fuel} #{cool_fuel}"
      puts "running #{type_desc}"

      model_dir = "#{output_dir}/hvac_#{system_type}_#{main_heat_fuel}_#{zone_heat_fuel}_#{cool_fuel}"
      # Load the model if already created
      if File.exist?("#{model_dir}/final.osm")

        model = OpenStudio::Model::Model.new
        sql = standard.safe_load_sql("#{model_dir}/AR/run/eplusout.sql")
        model.setSqlFile(sql)

      # If not created, make and run annual simulation
      else

        # Load the test model
        model = standard.safe_load_model("#{File.dirname(__FILE__)}/models/basic_2_story_office_no_hvac.osm")

        # Assign a weather file
        standard.model_add_design_days_and_weather_file(model, 'ASHRAE 169-2006-7A', '')
        standard.model_add_ground_temperatures(model, 'MediumOffice', 'ASHRAE 169-2006-7A')
        # Add the HVAC
        standard.model_add_hvac_system(model, system_type, main_heat_fuel, zone_heat_fuel, cool_fuel, model.getThermalZones)

        # Save the model
        model.save("#{model_dir}/final.osm", true)

        # Run the sizing run
        annual_run_success = standard.model_run_simulation_and_log_errors(model, "#{model_dir}/AR")

        # Log the errors
        log_messages_to_file("#{model_dir}/openstudio-standards.log", debug=false)

        errs << "For #{type_desc} annual run failed" unless annual_run_success

      end

      # Check the conditioned floor area
      errs << "For #{type_desc} there was no conditioned area." if standard.model_net_conditioned_floor_area(model) == 0

      # Check the unmet hours
      unmet_hrs = standard.model_annual_occupied_unmet_hours(model)
      max_unmet_hrs = 550
      if unmet_hrs
        errs << "For #{type_desc} there were #{unmet_hrs} unmet occupied heating and cooling hours, more than the limit of #{max_unmet_hrs}." if unmet_hrs > max_unmet_hrs
      else
        errs << "For #{type_desc} could not determine unmet hours; simulation may have failed."
      end
    end

    assert(errs.size == 0, errs.join("\n"))

    return true
  end
end
}
    file_string["$(hvac_system)"] = hvac_system.inspect
    file_string["$(0)"] = hvac_system[0].inspect.snek
    file_string["$(1)"] = hvac_system[1].inspect.snek
    file_string["$(2)"] = hvac_system[2].inspect.snek
    file_string["$(3)"] = hvac_system[3].inspect.snek

    File.open(filename, 'w') { |file| file.write(file_string) }
  }

end

def generate_doe_building_test_files
  building_types ={
    'FullServiceRestaurant' =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'HighriseApartment'     =>  {'templates'     => ['90.1-2004','90.1-2007','90.1-2010','90.1-2013'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A']
                                },
    'Hospital'              =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2004','90.1-2007','90.1-2010','90.1-2013'],
                                'climate_zones'  => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'LargeHotel'            =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'LargeOffice'           =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'MediumOffice'          =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'MidriseApartment'      =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'Outpatient'            =>  {'templates'     => ['DOE Ref 1980-2004', 'DOE Ref Pre-1980', '90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'PrimarySchool'         =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004', '90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'QuickServiceRestaurant'=>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'RetailStandalone'      =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'SecondarySchool'       =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004', '90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'SmallHotel'            =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'SmallOffice'           =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'RetailStripmall'       =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'SuperMarket'           =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2004','90.1-2007','90.1-2010','90.1-2013'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                },
    'Warehouse'             =>  {'templates'     => ['DOE Ref Pre-1980','DOE Ref 1980-2004','90.1-2010'],
                                 'climate_zones' => ['ASHRAE 169-2006-2A','ASHRAE 169-2006-3B','ASHRAE 169-2006-4A','ASHRAE 169-2006-5A']
                                }
  }

  building_types.keys.sort.each {|building_type|
    building_types[building_type]['templates'].each {|template|
      building_types[building_type]['climate_zones'].each {|climate_zone|
        filename = File.join(file_out_dir(),"doe_test_bldg_#{building_type.snek}-#{template.snek}-#{climate_zone.to_s.snek}.rb")
        puts filename
        file_string = %q{
require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'



class Test$(building_type) < CreateDOEPrototypeBuildingTest

  building_types = ['$(building_type)']

  templates = ['$(template)']
  climate_zones = ['$(climate_zone)']
  # templates = ['DOE Ref 1980-2004', 'DOE Ref Pre-1980', '90.1-2007', '90.1-2010', '90.1-2013', '90.1-2004']
  # climate_zones = ['ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A','ASHRAE 169-2006-2B',
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

  Test$(building_type).create_run_model_tests(building_types, templates, climate_zones, epw_files, create_models, run_models, compare_results, debug)

  # Test$(building_type).compare_test_results(building_types, templates, climate_zones, file_ext="")

end
}
        file_string.gsub!('$(building_type)',"#{building_type}")
        file_string.gsub!('$(template)',"#{template}")
        file_string.gsub!('$(climate_zone)',"#{climate_zone}")

        File.open(filename, 'w') { |file| file.write(file_string) }
      }
    }
  }

end

cleanup_output_folders()
copy_doe_model_files_for_hvac_tests()
generate_doe_hvac_files()
generate_ci_bldg_test_files()
copy_model_files_for_hvac_tests()
generate_hvac_sys1_files()
generate_hvac_sys2_files()
generate_hvac_sys3_files()
generate_hvac_sys4_files()
# generate_hvac_sys5_files() # known failure
generate_hvac_sys6_files()
generate_hvac_sys7_files()
generate_doe_building_test_files()
write_file_path_to_ci_tests_txt()
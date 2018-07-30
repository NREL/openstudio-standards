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


  def test_system_5()
    boiler_fueltypes = ["NaturalGas", "Electricity", "FuelOil#2"]
    chiller_types = ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"]
    mua_cooling_types = ["DX", "Hydronic"]
    output_folder = "#{File.dirname(__FILE__)}/output/test_necb_system_5"

    name = String.new

    FileUtils.rm_rf(output_folder)
    FileUtils::mkdir_p(output_folder)

    Vintages.each do |vintage|
      standard = Standard.build(vintage)
      boiler_fueltypes.each do |boiler_fueltype|
        chiller_types.each do |chiller_type|
          mua_cooling_types.each do |mua_cooling_type|
            name = "sys5_Boiler~#{boiler_fueltype}_ChillerType~#{chiller_type}_MuaCoolingType~#{mua_cooling_type}"
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

    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
    # need to set prototype assumptions so that HRV added
    standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
    # Apply the HVAC efficiency standard
    standard.model_apply_hvac_efficiency_standard(model, climate_zone)
    #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
    return true
  end


end
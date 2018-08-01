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


class FullHVACTest < MiniTest::Test
  #set to true to run the standards in the test. 
  PERFORM_STANDARDS = true
  #set to true to run the simulations. 
  FULL_SIMULATIONS = true
  
  
    
  #System #1 ToDo
  # mua_types = false will fail. (PTAC Issue Kamel Mentioned) 
  #Control zone for SZ systems. 
  
  def test_system_1()
    name = String.new
    output_folder = "#{File.dirname(__FILE__)}/output/system_1"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    File.open("#{output_folder}/test.log", 'w') do |test_log|  
      #all permutation and combinations. 
      boiler_fueltypes = ["NaturalGas","Electricity","FuelOil#2"]
      mau_types = [true, false]
      mau_heating_coil_types = ["Hot Water", "Electric"]
      baseboard_types = ["Hot Water" , "Electric"]
      model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
      BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
      #save baseline
      BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
      #interate through combinations. 
  
      boiler_fueltypes.each do |boiler_fueltype|
        baseboard_types.each do |baseboard_type|
          mau_types.each do |mau_type|
            if mau_type == true
              mau_heating_coil_types.each do |mau_heating_coil_type|
                name = "sys1_Boiler~#{boiler_fueltype}_Mau~#{mau_type}_MauCoil~#{mau_heating_coil_type}_Baseboard~#{baseboard_type}"
                puts "***************************************#{name}*******************************************************\n"
                model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
                BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
                BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys1(
                  model, 
                  model.getThermalZones, 
                  boiler_fueltype, 
                  mau_type, 
                  mau_heating_coil_type, 
                  baseboard_type)
                #Save the model after btap hvac. 
                BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
                #run the standards
                result = run_the_measure(model,"#{output_folder}/#{name}/sizing")
                #Save the model
                BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
                assert_equal(true, result,"Failure in Standards for #{name}")
              end
            else
              name =  "sys1_Boiler~#{boiler_fueltype}_Mau~#{mau_type}_MauCoil~None_Baseboard~#{baseboard_type}"
              puts "***************************************#{name}*******************************************************\n"
              model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
              BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
                 
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys1(
                model, 
                model.getThermalZones, 
                boiler_fueltype, 
                mau_type, 
                "Electric", #value will not be used.  
                baseboard_type)
              #Save the model after btap hvac. 
              BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
  
              result = run_the_measure(model,"#{output_folder}/#{name}/sizing")
  
              #Save model after standards
              BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
              assert_equal(true, result,"Failure in Standards for #{name}")
  
            end
          end
        end
      end
      self.run_simulations(output_folder)
    end
  end
      
    
  #System #2 
  #Sizing Convergence Errors when mua_cooling_types = DX
  def test_system_2()
    name = String.new
    output_folder = "#{File.dirname(__FILE__)}/output/system_2"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    
    boiler_fueltypes = ["NaturalGas","Electricity","FuelOil#2",]
    chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
    mua_cooling_types = ["Hydronic","DX"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      chiller_types.each do |chiller_type|
        mua_cooling_types.each do |mua_cooling_type|
          name = "sys2_Boiler~#{boiler_fueltype}_Chiller#~#{chiller_type}_MuACoolingType~#{mua_cooling_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
                 
          BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(
            model, 
            model.getThermalZones, 
            boiler_fueltype, 
            chiller_type, 
            mua_cooling_type)
          #Save the model after btap hvac. 
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
          result = run_the_measure(model,"#{output_folder}/#{name}/sizing") 
          #Save model after standards
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result,"Failure in Standards for #{name}")
        end
      end
    end
    self.run_simulations(output_folder)
  end
    
      
  #Runs!
  def test_system_3()
    name = String.new
    output_folder = "#{File.dirname(__FILE__)}/output/system_3"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    boiler_fueltypes = ["NaturalGas","Electricity","FuelOil#2"]
    baseboard_types = ["Hot Water" , "Electric"]
    heating_coil_types_sys3 = ["Electric", "Gas", "DX"]
    
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      baseboard_types.each do |baseboard_type|
        heating_coil_types_sys3.each do |heating_coil_type_sys3|
          name = "sys3_Boiler~#{boiler_fueltype}_HeatingCoilType#~#{heating_coil_type_sys3}_BaseboardType~#{baseboard_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
                 
          BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys3(
            model, 
            model.getThermalZones, 
            boiler_fueltype, 
            heating_coil_type_sys3, 
            baseboard_type)
          #Save the model after btap hvac. 
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
          result = run_the_measure(model,"#{output_folder}/#{name}/sizing") 
          #Save model after standards
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result,"Failure in Standards for #{name}")
    
        end
      end
    end
    self.run_simulations(output_folder)
  end
    
      
  
  def test_system_4()
    name = String.new
    output_folder = "#{File.dirname(__FILE__)}/output/system_4"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    boiler_fueltypes = ["NaturalGas","Electricity","FuelOil#2",]
    baseboard_types = ["Hot Water" , "Electric"]
    heating_coil_types_sys4 = ["Electric", "Gas"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      baseboard_types.each do |baseboard_type|
        heating_coil_types_sys4.each do |heating_coil|
          name = "sys4_Boiler~#{boiler_fueltype}_HeatingCoilType#~#{heating_coil}_BaseboardType~#{baseboard_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
                 
          BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys4(
            model, 
            model.getThermalZones, 
            boiler_fueltype, 
            heating_coil, 
            baseboard_type)
          #Save the model after btap hvac. 
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
          result = run_the_measure(model,"#{output_folder}/#{name}/sizing") 
          #Save model after standards
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result,"Failure in Standards for #{name}")
    
        end
      end
    end
    self.run_simulations(output_folder)
  end
    
      
    
  def test_system_5()
    name = String.new
    output_folder = "#{File.dirname(__FILE__)}/output/system_5"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    boiler_fueltypes = ["NaturalGas","Electricity","FuelOil#2"]
    chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
    mua_cooling_types = ["DX","Hydronic"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      chiller_types.each do |chiller_type|
        mua_cooling_types.each do |mua_cooling_type|
          name = "sys5_Boiler~#{boiler_fueltype}_ChillerType~#{chiller_type}_MuaCoolingType~#{mua_cooling_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
                 
          BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys5(
            model, 
            model.getThermalZones, 
            boiler_fueltype, 
            chiller_type, 
            mua_cooling_type)
          #Save the model after btap hvac. 
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
          result = run_the_measure(model,"#{output_folder}/#{name}/sizing") 
          #Save model after standards
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result,"Failure in Standards for #{name}") 
        end
      end 
    end
    self.run_simulations(output_folder)
  end
    
      
    
    
  
  #  System #6 Todo
  #•	Set_vav_damper_action for NECB was quick fixed..needs to be review if this is appropriate for NECB2011 see git log for
  #         def set_vav_damper_action(template, climate_zone)
  #          damper_action = nil
  #          case template       
  #          when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', 'NECB2011'
  #            damper_action = 'Single Maximum'
  #          when '90.1-2007', '90.1-2010', '90.1-2013'
  #            damper_action = 'Dual Maximum'
  #          end
  #•	Hot water coil logic was added to prevent HW to be used when electric. (Please review if I broke anything) 
  #•	Sizing run error when Chiller type is "Centrifugal","Rotary Screw","Reciprocating"] 

  def test_system_6()
    name = String.new
    output_folder = "#{File.dirname(__FILE__)}/output/system_6"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    boiler_fueltypes = ["NaturalGas","Electricity","FuelOil#2",]
    baseboard_types = ["Hot Water" , "Electric"]
    chiller_types = ["Scroll"]#,"Centrifugal","Rotary Screw","Reciprocating"] are not working. 
    heating_coil_types_sys6 = ["Electric", "Hot Water"]
    fan_types = ["AF_or_BI_rdg_fancurve","AF_or_BI_inletvanes","fc_inletvanes","var_speed_drive"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      chiller_types.each do |chiller_type|
        baseboard_types.each do |baseboard_type|
          heating_coil_types_sys6.each do |heating_coil_type|
            fan_types.each do |fan_type|
              name = "sys6_Bo~#{boiler_fueltype}_Ch~#{chiller_type}_BB~#{baseboard_type}_HC~#{heating_coil_type}_Fan~#{fan_type}"
              puts "***************************************#{name}*******************************************************\n"
              model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
              BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
               
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys6(
                model, 
                model.getThermalZones, 
                boiler_fueltype, 
                heating_coil_type, 
                baseboard_type, 
                chiller_type, 
                fan_type)
              #Save the model after btap hvac. 
              BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
              result = run_the_measure(model,"#{output_folder}/#{name}/sizing") 
              #Save model after standards
              BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
              assert_equal(true, result,"Failure in Standards for #{name}")
            end
          end
        end
      end
    end
    self.run_simulations(output_folder)
  end
    
#  #Todo
#  #Sizing Convergence Errors when mua_cooling_types = DX
  def test_system_7()
    name = String.new
    output_folder = "#{File.dirname(__FILE__)}/output/system_7"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    boiler_fueltypes = ["NaturalGas","Electricity","FuelOil#2"]
    chiller_types = ["Scroll","Centrifugal","Rotary Screw","Reciprocating"]
    mua_cooling_types = ["Hydronic","DX"]
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      chiller_types.each do |chiller_type|
        mua_cooling_types.each do |mua_cooling_type|
          name = "sys7_Boiler~#{boiler_fueltype}_ChillerType~#{chiller_type}_MuaCoolingType~#{mua_cooling_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
                 
          BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys2(
            model, 
            model.getThermalZones, 
            boiler_fueltype, 
            chiller_type, 
            mua_cooling_type)
          #Save the model after btap hvac. 
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
          result = run_the_measure(model,"#{output_folder}/#{name}/sizing") 
          #Save model after standards
          BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result,"Failure in Standards for #{name}")
        end
      end
    end
    self.run_simulations(output_folder)
  end

  def run_simulations(output_folder)
    if FULL_SIMULATIONS == true
      file_array = []
      BTAP::FileIO::get_find_files_from_folder_by_extension(output_folder, ".osm").each do |file|
        #skip any sizing.osm file. 
        unless file.to_s.include?("sizing.osm")
          file_array << file
        end
      end
      BTAP::SimManager::simulate_files(output_folder, file_array)
      BTAP::Reporting::get_all_annual_results_from_runmanger_by_files(output_folder,file_array)
      
      are_there_no_severe_errors = File.zero?("#{output_folder}/failed simulations.txt")
      assert_equal(true, are_there_no_severe_errors,"Simulations had severe errors. Check #{output_folder}/failed simulations.txt ")
    end
  end

  def run_the_measure(model, sizing_dir) 
    if PERFORM_STANDARDS
      # Hard-code the building vintage
      building_vintage = 'NECB2011'
      building_type = 'NECB'
      climate_zone = 'NECB'
      standard = Standard.build(building_vintage)

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
      model.applyPrototypeHVACAssumptions(building_type, building_vintage, climate_zone)
      # Apply the HVAC efficiency standard
      model.applyHVACEfficiencyStandard(building_vintage, climate_zone)
      #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    
      # BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")

      return true
    end 
  end
end

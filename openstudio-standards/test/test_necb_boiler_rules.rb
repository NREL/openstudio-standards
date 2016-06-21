require_relative 'minitest_helper'
require_relative 'create_doe_prototype_helper'
$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)

class HVACEfficienciesTest < MiniTest::Test
  #set to true to run the standards in the test. 
  PERFORM_STANDARDS = true
  #set to true to run the simulations. 
  FULL_SIMULATIONS = false

# Test to validate the boiler thermal efficiency generated against expected values stored in the file:
# 'compliance_boiler_efficiencies_expected_results.csv
  def test_boiler_efficiency()
    name = String.new
    output_folder = "#{File.dirname(__FILE__)}/output/boiler_eff"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    boiler_expected_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_boiler_efficiencies_expected_results.csv')

    # Initialize hashes for storing expected boiler efficiency data from file
    fuel_type_min_cap = Hash.new
    fuel_type_min_cap["Electricity"],fuel_type_min_cap["NaturalGas"],fuel_type_min_cap["FuelOil#2"]=[],[],[]
    fuel_type_max_cap = Hash.new
    fuel_type_max_cap["Electricity"],fuel_type_max_cap["NaturalGas"],fuel_type_max_cap["FuelOil#2"]=[],[],[]
    efficiency_type = Hash.new
    efficiency_type["Electricity"],efficiency_type["NaturalGas"],efficiency_type["FuelOil#2"]=[],[],[]

    # read the file for the expected boiler efficiency values for different fuels and equipment capacity ranges
    CSV.foreach(boiler_expected_result_file, headers:true) do |data|
      fuel_type_min_cap[data['Fuel']] << data["Min Capacity (Btu per hr)"]
      fuel_type_max_cap[data['Fuel']] << data["Max Capacity (Btu per hr)"]
      if(data['Annual Fuel Utilization Efficiency (AFUE)'].to_f > 0.0)
        efficiency_type[data['Fuel']] << 'Annual Fuel Utilization Efficiency (AFUE)'
      elsif(data['Thermal Efficiency'].to_f > 0.0)
        efficiency_type[data['Fuel']] << 'Thermal Efficiency'
      elsif(data['Combustion Efficiency'].to_f > 0.0)
        efficiency_type[data['Fuel']] << 'Combustion Efficiency'
      end
    end
    
    # Use the expected boiler efficiency data to generate suitable equipment capacities for the test to cover all
    # the relevant equipment capacity ranges
    fuel_type_cap = Hash.new
    fuel_type_min_cap.each do |fuel,cap|
      if not fuel_type_cap.has_key? (fuel) then fuel_type_cap[fuel] = [] end
      if(cap.size == 1)
        fuel_type_cap[fuel] << 10000.0
      else
        fuel_type_cap[fuel] << 0.5*(OpenStudio.convert(fuel_type_min_cap[fuel][0].to_f,'Btu/hr','W').to_f+OpenStudio.convert(fuel_type_min_cap[fuel][1].to_f,'Btu/h','W').to_f)
        if(cap.size == 2)
          fuel_type_cap[fuel] << (OpenStudio.convert(fuel_type_min_cap[fuel][1].to_f,'Btu/hr','W').to_f+10000.0)
        else
          fuel_type_cap[fuel] << 0.5*(OpenStudio.convert(fuel_type_min_cap[fuel][1].to_f,'Btu/hr','W').to_f+OpenStudio.convert(fuel_type_min_cap[fuel][2].to_f,'Btu/hr','W').to_f)
          fuel_type_cap[fuel] << (fuel_type_min_cap[fuel][2].to_f+10000.0)
        end
      end
    end
    
    # Generate the osm files for all relevant cases to generate the test data for system 1
    actual_boiler_thermal_eff = Hash.new
    actual_boiler_thermal_eff["Electricity"],actual_boiler_thermal_eff["NaturalGas"],actual_boiler_thermal_eff["FuelOil#2"] = [],[],[]
    boiler_res_file_output_text = "Fuel,Min Capacity (Btu per hr),Max Capacity (Btu per hr),Annual Fuel Utilization Efficiency (AFUE),Thermal Efficiency,Combustion Efficiency\n"
    File.open("#{output_folder}/test.log", 'w') do |test_log|  
      boiler_fueltypes = ["Electricity","NaturalGas","FuelOil#2"]
      mau_types = [true]
      mau_heating_coil_types = ["Hot Water"]
      baseboard_types = ["Hot Water"]
      model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
      BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
      #save baseline
      BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
      boiler_fueltypes.each do |boiler_fueltype|
        baseboard_types.each do |baseboard_type|
          mau_types.each do |mau_type|
            mau_heating_coil_types.each do |mau_heating_coil_type|
              fuel_type_cap[boiler_fueltype].each do |boiler_cap|
                name = "sys1_Boiler~#{boiler_fueltype+'_'+boiler_cap.to_s+'Watts'}_Mau~#{mau_type}_MauCoil~#{mau_heating_coil_type}_Baseboard~#{baseboard_type}"
                puts "***************************************#{name}*******************************************************\n"
                model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
                BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
                BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys1(
                  model, 
                  model.getThermalZones, 
                  boiler_fueltype, 
                  mau_type, 
                  mau_heating_coil_type, 
                  baseboard_type)
                #Save the model after btap hvac. 
                BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
                model.getBoilerHotWaters.each {|iboiler| iboiler.setNominalCapacity(boiler_cap)}
                #run the standards
                result = run_the_measure(model,"#{output_folder}/#{name}/sizing")
                model.getBoilerHotWaters.each do |iboiler|
                  if(iboiler.nominalCapacity.to_f > 1) 
                    actual_boiler_thermal_eff[boiler_fueltype] << iboiler.nominalThermalEfficiency
                    break
                  end
                end
                #Save the model
                BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
                assert_equal(true, result,"Failure in Standards for #{name}")
              end
            end
          end
        end
      end
      
      # Generate table of test boiler efficiencies
      actual_boiler_eff = Hash.new
      actual_boiler_eff["Electricity"],actual_boiler_eff["NaturalGas"],actual_boiler_eff["FuelOil#2"] = [],[],[]
      boiler_fueltypes.each do |ifuel|
        output_line_text = ''
        for int in 0..fuel_type_cap[ifuel].size-1
          output_line_text += "#{ifuel},#{fuel_type_min_cap[ifuel][int]},#{fuel_type_max_cap[ifuel][int]},"
          if(efficiency_type[ifuel][int] == "Annual Fuel Utilization Efficiency (AFUE)") 
            actual_boiler_eff[ifuel][int] = (thermal_eff_to_afue(actual_boiler_thermal_eff[ifuel][int])+0.0001).round(3)
            output_line_text += "#{actual_boiler_eff[ifuel][int]},,\n"
          elsif(efficiency_type[ifuel][int] == "Combustion Efficiency") 
            actual_boiler_eff[ifuel][int] = (thermal_eff_to_comb_eff(actual_boiler_thermal_eff[ifuel][int])+0.0001).round(3)
            output_line_text += ",,#{actual_boiler_eff[ifuel][int]}\n"
          elsif(efficiency_type[ifuel][int] == "Thermal Efficiency")
            actual_boiler_eff[ifuel][int] = (actual_boiler_thermal_eff[ifuel][int]+0.0001).round(3)
            output_line_text += ",#{actual_boiler_eff[ifuel][int]},\n"
          end
        end
        boiler_res_file_output_text += output_line_text
      end

      #Write actual results file
      test_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_boiler_efficiencies_test_results.csv')
      File.open(test_result_file, 'w') {|f| f.write(boiler_res_file_output_text) }
      #Test that the values are correct by doing a file compare.
      expected_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_boiler_efficiencies_expected_results.csv')
      b_result = FileUtils.compare_file(expected_result_file , test_result_file )
      assert( b_result, 
      "Boiler efficiencies test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")  
    end
  end

# Test to validate the number of boilers used and their capacities depending on total heating capacity. 
# NECB 2011 rule for number of boilers is:
# if capacity <= 176 kW ---> one single stage boiler
# if capacity > 176 kW and <= 352 kW ---> 2 boilers of equal capacity
# if capacity > 352 kW ---> one modulating boiler down to 25% of capacity"
  def test_number_of_boilers()    
    output_folder = "#{File.dirname(__FILE__)}/output/num_of_boilers"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    first_cutoff_blr_cap = 176000.0
    second_cutoff_blr_cap = 352000.0
    small = 1.0e-6
    # Generate the osm files for all relevant cases to generate the test data for system 3
    File.open("#{output_folder}/test.log", 'w') do |test_log|  
      boiler_fueltypes = ["NaturalGas"]
      baseboard_types = ["Hot Water"]
      heating_coil_types = ["Electric"]
      test_boiler_cap = [100000.0,200000.0,400000.0]
      model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
      BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
      #save baseline
      BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
      boiler_fueltypes.each do |boiler_fueltype|
        baseboard_types.each do |baseboard_type|
          heating_coil_types.each do |heating_coil_type|
            test_boiler_cap.each do |boiler_cap|
              name = "sys1_Boiler~#{boiler_fueltype+'_'+boiler_cap.to_s+'Watts'}_HeatingCoilType#~#{heating_coil_type}_Baseboard~#{baseboard_type}"
              puts "***************************************#{name}*******************************************************\n"
              model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
              BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
              BTAP::Resources::HVAC::HVACTemplates::NECB2011::assign_zones_sys3(
                model, 
                model.getThermalZones, 
                boiler_fueltype, 
                heating_coil_type, 
                baseboard_type)
              #Save the model after btap hvac. 
              BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.hvacrb")
              model.getBoilerHotWaters.each {|iboiler| iboiler.setNominalCapacity(boiler_cap)}
              #run the standards
              result = run_the_measure(model,"#{output_folder}/#{name}/sizing")
              boilers = model.getBoilerHotWaters
              # check that there are two boilers in the model
              num_of_boilers_is_correct = false
              if(boilers.size == 2) then num_of_boilers_is_correct = true end
              assert(num_of_boilers_is_correct,"Number of boilers is not 2")
              this_is_the_first_cap_range,this_is_the_second_cap_range,this_is_the_third_cap_range = false,false,false
              if(boiler_cap < first_cutoff_blr_cap)
                this_is_the_first_cap_range = true
              elsif(boiler_cap > second_cutoff_blr_cap)
                this_is_the_third_cap_range = true
              else
                this_is_the_second_cap_range = true
              end
              # compare boiler capacities to expected values
              boilers.each do |iboiler|
                if(iboiler.name.to_s.include?("Primary Boiler"))
                  boiler_cap_is_correct = false
                  if(this_is_the_first_cap_range || this_is_the_third_cap_range)
                    cap_diff = (boiler_cap-iboiler.nominalCapacity.to_f).abs
                  elsif(this_is_the_second_cap_range)
                    cap_diff = (0.5*boiler_cap-iboiler.nominalCapacity.to_f).abs
                  end
                  if(cap_diff < small) then boiler_cap_is_correct = true end
                  assert(boiler_cap_is_correct,"Primary boiler capacity is not correct")
                end
                if(iboiler.name.to_s.include?("Secondary Boiler"))
                  boiler_cap_is_correct = false
                  if(this_is_the_first_cap_range || this_is_the_third_cap_range)
                    cap_diff = (iboiler.nominalCapacity.to_f-0.001).abs
                  elsif(this_is_the_second_cap_range)
                    cap_diff = (0.5*boiler_cap-iboiler.nominalCapacity.to_f).abs
                  end
                  if(cap_diff < small) then boiler_cap_is_correct = true end
                  assert(boiler_cap_is_correct,"Secondary boiler capacity is not correct")
                end
              end
              boiler_capacities_are_correct = true
              #Save the model
              BTAP::FileIO::save_osm(model, "#{output_folder}/#{name}.osm")
              assert_equal(true, result,"Failure in Standards for #{name}")
            end
          end
        end
      end
    end
  end

# Test to validate the boiler part load performance curve
  def test_boiler_plf_vs_plr_curve()
    name = String.new
    output_folder = "#{File.dirname(__FILE__)}/output/boiler_plf_vs_plr_curve"
    FileUtils.rm_rf( output_folder )
    FileUtils::mkdir_p( output_folder )
    boiler_expected_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_boiler_plfvsplr_expected_results.csv')
    # Generate the osm files for all relevant cases to generate the test data for system 1
    boiler_res_file_output_text = "Name,Type,coeff1,coeff2,coeff3,coeff4,min_x,max_x\n"
    File.open("#{output_folder}/test.log", 'w') do |test_log|  
      boiler_fueltypes = ["NaturalGas"]
      mau_types = [true]
      mau_heating_coil_types = ["Hot Water"]
      baseboard_types = ["Hot Water"]
      model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
      BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
      #save baseline
      BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
      boiler_fueltypes.each do |boiler_fueltype|
        baseboard_types.each do |baseboard_type|
          mau_types.each do |mau_type|
            mau_heating_coil_types.each do |mau_heating_coil_type|
              name = "sys1_Boiler~#{boiler_fueltype}+_Mau~#{mau_type}_MauCoil~#{mau_heating_coil_type}_Baseboard~#{baseboard_type}"
              puts "***************************************#{name}*******************************************************\n"
              model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
              BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
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
              boilers = model.getBoilerHotWaters
              boiler_curve = boilers[0].normalizedBoilerEfficiencyCurve.get.to_CurveCubic.get
              boiler_res_file_output_text += "BOILER-EFFFPLR-NECB2011,cubic,#{boiler_curve.coefficient1Constant},#{boiler_curve.coefficient2x},#{boiler_curve.coefficient3xPOW2},"+
              "#{boiler_curve.coefficient4xPOW3},#{boiler_curve.minimumValueofx},#{boiler_curve.maximumValueofx}"
            end
          end
        end
      end
      #Write actual results file
      test_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_boiler_plfvsplr_curve_test_results.csv')
      File.open(test_result_file, 'w') {|f| f.write(boiler_res_file_output_text) }
      #Test that the values are correct by doing a file compare.
      expected_result_file = File.join(File.dirname(__FILE__),'regression_files','compliance_boiler_plfvsplr_curve_expected_results.csv')
      b_result = FileUtils.compare_file(expected_result_file , test_result_file )
      assert( b_result, 
      "Boiler plf vs plr curve coeffs test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")  
    end
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
    
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      baseboard_types.each do |baseboard_type|
        heating_coil_types_sys3.each do |heating_coil_type_sys3|
          name = "sys3_Boiler~#{boiler_fueltype}_HeatingCoilType#~#{heating_coil_type_sys3}_BaseboardType~#{baseboard_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
                 
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
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      baseboard_types.each do |baseboard_type|
        heating_coil_types_sys4.each do |heating_coil|
          name = "sys4_Boiler~#{boiler_fueltype}_HeatingCoilType#~#{heating_coil}_BaseboardType~#{baseboard_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
                 
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
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      chiller_types.each do |chiller_type|
        mua_cooling_types.each do |mua_cooling_type|
          name = "sys5_Boiler~#{boiler_fueltype}_ChillerType~#{chiller_type}_MuaCoolingType~#{mua_cooling_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
                 
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
  #•	Set_vav_damper_action for NECB was quick fixed..needs to be review if this is appropriate for NECB 2011 see git log for 
  #         def set_vav_damper_action(template, climate_zone)
  #          damper_action = nil
  #          case template       
  #          when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', 'NECB 2011'
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
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      chiller_types.each do |chiller_type|
        baseboard_types.each do |baseboard_type|
          heating_coil_types_sys6.each do |heating_coil_type|
            fan_types.each do |fan_type|
              name = "sys6_Bo~#{boiler_fueltype}_Ch~#{chiller_type}_BB~#{baseboard_type}_HC~#{heating_coil_type}_Fan~#{fan_type}"
              puts "***************************************#{name}*******************************************************\n"
              model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
              BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
               
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
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
    #save baseline
    BTAP::FileIO::save_osm(model, "#{output_folder}/baseline.osm")
    boiler_fueltypes.each do |boiler_fueltype|
      chiller_types.each do |chiller_type|
        mua_cooling_types.each do |mua_cooling_type|
          name = "sys7_Boiler~#{boiler_fueltype}_ChillerType~#{chiller_type}_MuaCoolingType~#{mua_cooling_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.716240_CWEC.epw").set_weather_file(model)
                 
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
=end

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
      building_vintage = 'NECB 2011'
      building_type = 'NECB'
      climate_zone = 'NECB'
      #building_vintage = '90.1-2013'
   
#      # Load the Openstudio_Standards JSON files
#      model.load_openstudio_standards_json

#      # Assign the standards to the model
#      model.template = building_vintage    
    
      # Make a directory to run the sizing run in

      if !Dir.exists?(sizing_dir)
        FileUtils.mkdir_p(sizing_dir)
      end

      # Perform a sizing run
      if model.runSizingRun("#{sizing_dir}/SizingRun1") == false
        puts "could not find sizing run #{sizing_dir}/SizingRun1"
        raise("could not find sizing run #{sizing_dir}/SizingRun1")
        return false
      else
        puts "found sizing run #{sizing_dir}/SizingRun1"
      
      end
    

      BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
    
      
      # need to set prototype assumptions so that HRV added
      model.applyPrototypeHVACAssumptions(building_type, building_vintage, climate_zone)
      # Apply the HVAC efficiency standard
      model.applyHVACEfficiencyStandard(building_vintage, climate_zone)
      #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    
      BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")

      return true
    end 
  end
end

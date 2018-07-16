require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class NECB2011HVACEfficienciesTests < MiniTest::Test
  # set to true to run the standards in the test.
  PERFORM_STANDARDS = true
  # set to true to run the simulations.
  FULL_SIMULATIONS = false

  # Test to validate the boiler thermal efficiency generated against expected values stored in the file:
  # 'compliance_boiler_efficiencies_expected_results.csv
  def test_NECB2011_boiler_efficiency
    output_folder = "#{File.dirname(__FILE__)}/output/boiler_efficiency"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    standard = Standard.build('NECB2011')

    # Generate the osm files for all relevant cases to generate the test data for system 1
    boiler_fueltypes = ['Electricity', 'NaturalGas', 'FuelOil#2']
    mau_type = true
    mau_heating_coil_type = 'Hot Water'
    baseboard_type = 'Hot Water'
    model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    templates = ['NECB2011','NECB2015']
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    templates.each do |template|
      boiler_expected_result_file = File.join(File.dirname(__FILE__), 'data', "#{template.downcase}_compliance_boiler_efficiencies_expected_results.csv")

      # Initialize hashes for storing expected boiler efficiency data from file
      fuel_type_min_cap = {}
      fuel_type_min_cap['Electricity'] = []
      fuel_type_min_cap['NaturalGas'] = []
      fuel_type_min_cap['FuelOil#2'] = []
      fuel_type_max_cap = {}
      fuel_type_max_cap['Electricity'] = []
      fuel_type_max_cap['NaturalGas'] = []
      fuel_type_max_cap['FuelOil#2'] = []
      efficiency_type = {}
      efficiency_type['Electricity'] = []
      efficiency_type['NaturalGas'] = []
      efficiency_type['FuelOil#2'] = []

      # read the file for the expected boiler efficiency values for different fuels and equipment capacity ranges
      CSV.foreach(boiler_expected_result_file, headers: true) do |data|
        fuel_type_min_cap[data['Fuel']] << data['Min Capacity (Btu per hr)']
        fuel_type_max_cap[data['Fuel']] << data['Max Capacity (Btu per hr)']
        if data['Annual Fuel Utilization Efficiency (AFUE)'].to_f > 0.0
          efficiency_type[data['Fuel']] << 'Annual Fuel Utilization Efficiency (AFUE)'
        elsif data['Thermal Efficiency'].to_f > 0.0
          efficiency_type[data['Fuel']] << 'Thermal Efficiency'
        elsif data['Combustion Efficiency'].to_f > 0.0
          efficiency_type[data['Fuel']] << 'Combustion Efficiency'
        end
      end
	  
      # Use the expected boiler efficiency data to generate suitable equipment capacities for the test to cover all
      # the relevant equipment capacity ranges
      fuel_type_cap = {}
      fuel_type_min_cap.each do |fuel, cap|
        unless fuel_type_cap.key? fuel then fuel_type_cap[fuel] = [] end
        if cap.size == 1
          fuel_type_cap[fuel] << 10000.0
        else
          fuel_type_cap[fuel] << 0.5 * (OpenStudio.convert(fuel_type_min_cap[fuel][0].to_f, 'Btu/hr', 'W').to_f + OpenStudio.convert(fuel_type_min_cap[fuel][1].to_f, 'Btu/h', 'W').to_f)
          if cap.size == 2
            fuel_type_cap[fuel] << (OpenStudio.convert(fuel_type_min_cap[fuel][1].to_f, 'Btu/hr', 'W').to_f + 10000.0)
          else
            fuel_type_cap[fuel] << 0.5 * (OpenStudio.convert(fuel_type_min_cap[fuel][1].to_f, 'Btu/hr', 'W').to_f + OpenStudio.convert(fuel_type_min_cap[fuel][2].to_f, 'Btu/hr', 'W').to_f)
            fuel_type_cap[fuel] << (fuel_type_min_cap[fuel][2].to_f + 10000.0)
          end
        end
      end

      actual_boiler_thermal_eff = {}
      actual_boiler_thermal_eff['Electricity'] = []
      actual_boiler_thermal_eff['NaturalGas'] = []
      actual_boiler_thermal_eff['FuelOil#2'] = []
      boiler_fueltypes.each do |boiler_fueltype|
        fuel_type_cap[boiler_fueltype].each do |boiler_cap|
          name = "#{template}_sys1_Boiler-#{boiler_fueltype}_cap-#{boiler_cap.to_int}W_MAU-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
          BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
          hw_loop = OpenStudio::Model::PlantLoop.new(model)
          always_on = model.alwaysOnDiscreteSchedule	
          BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
          BTAP::Resources::HVAC::HVACTemplates::NECB2011.assign_zones_sys1(
            model,
            model.getThermalZones,
            boiler_fueltype,
            mau_type,
            mau_heating_coil_type,
            baseboard_type,
            hw_loop)
          # Save the model after btap hvac.
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
          model.getBoilerHotWaters.each { |iboiler| iboiler.setNominalCapacity(boiler_cap) }
          # run the standards
          result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
          # Save the model
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result, "test_boiler_efficiency: Failure in Standards for #{name}")
          model.getBoilerHotWaters.each do |iboiler|
            if iboiler.nominalCapacity.to_f > 1
              actual_boiler_thermal_eff[boiler_fueltype] << iboiler.nominalThermalEfficiency
              break
            end
          end
        end
      end

      # Generate table of test boiler efficiencies
      actual_boiler_eff = {}
      actual_boiler_eff['Electricity'] = []
      actual_boiler_eff['NaturalGas'] = []
      actual_boiler_eff['FuelOil#2'] = []
      boiler_res_file_output_text = "Fuel,Min Capacity (Btu per hr),Max Capacity (Btu per hr),Annual Fuel Utilization Efficiency (AFUE),Thermal Efficiency,Combustion Efficiency\n"
      boiler_fueltypes.each do |ifuel|
        output_line_text = ''
        for int in 0..fuel_type_cap[ifuel].size - 1
          output_line_text += "#{ifuel},#{fuel_type_min_cap[ifuel][int]},#{fuel_type_max_cap[ifuel][int]},"
          if efficiency_type[ifuel][int] == 'Annual Fuel Utilization Efficiency (AFUE)'
            actual_boiler_eff[ifuel][int] = (standard.thermal_eff_to_afue(actual_boiler_thermal_eff[ifuel][int]) + 0.0001).round(3)
            output_line_text += "#{actual_boiler_eff[ifuel][int]},,\n"
          elsif efficiency_type[ifuel][int] == 'Combustion Efficiency'
            actual_boiler_eff[ifuel][int] = (standard.thermal_eff_to_comb_eff(actual_boiler_thermal_eff[ifuel][int]) + 0.0001).round(3)
            output_line_text += ",,#{actual_boiler_eff[ifuel][int]}\n"
          elsif efficiency_type[ifuel][int] == 'Thermal Efficiency'
            actual_boiler_eff[ifuel][int] = (actual_boiler_thermal_eff[ifuel][int] + 0.0001).round(3)
            output_line_text += ",#{actual_boiler_eff[ifuel][int]},\n"
          end
        end
        boiler_res_file_output_text += output_line_text
      end
    
      # Write actual results file
      test_result_file = File.join(File.dirname(__FILE__), 'data', "#{template.downcase}_compliance_boiler_efficiencies_test_results.csv")
      File.open(test_result_file, 'w') { |f| f.write(boiler_res_file_output_text) }
      # Test that the values are correct by doing a file compare.
      expected_result_file = File.join(File.dirname(__FILE__), 'data', "#{template.downcase}_compliance_boiler_efficiencies_expected_results.csv")
      b_result = FileUtils.compare_file(expected_result_file, test_result_file)
      assert(b_result,
           "test_boiler_efficiency: Boiler efficiencies test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")
    end
  end

  # Test to validate the number of boilers used and their capacities depending on total heating capacity.
  # NECB2011 rule for number of boilers is:
  # if capacity <= 176 kW ---> one single stage boiler
  # if capacity > 176 kW and <= 352 kW ---> 2 boilers of equal capacity
  # if capacity > 352 kW ---> one modulating boiler down to 25% of capacity"
  def test_NECB2011_number_of_boilers
    output_folder = "#{File.dirname(__FILE__)}/output/num_of_boilers"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    first_cutoff_blr_cap = 176000.0
    second_cutoff_blr_cap = 352000.0
    tol = 1.0e-3
    # Generate the osm files for all relevant cases to generate the test data for system 3
    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    heating_coil_type = 'Electric'
    test_boiler_cap = [100000.0, 200000.0, 400000.0]
    model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    template = 'NECB2011'
    test_boiler_cap.each do |boiler_cap|
      name = "#{template}_sys1_Boiler-#{boiler_fueltype}_boiler_cap-#{boiler_cap}watts_HeatingCoilType#-#{heating_coil_type}_Baseboard-#{baseboard_type}"
      puts "***************************************#{name}*******************************************************\n"
      model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule	
      BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
      BTAP::Resources::HVAC::HVACTemplates::NECB2011.assign_zones_sys3(
        model,
        model.getThermalZones,
        boiler_fueltype,
        heating_coil_type,
        baseboard_type,
        hw_loop)
      # Save the model after btap hvac.
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
      model.getBoilerHotWaters.each { |iboiler| iboiler.setNominalCapacity(boiler_cap) }
      # run the standards
      result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
      # Save the model
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
      assert_equal(true, result, "test_number_of_boilers: Failure in Standards for #{name}")
      boilers = model.getBoilerHotWaters
      # check that there are two boilers in the model
      num_of_boilers_is_correct = false
      if boilers.size == 2 then num_of_boilers_is_correct = true end
      assert(num_of_boilers_is_correct, 'test_number_of_boilers: Number of boilers is not 2')
      this_is_the_first_cap_range = false
      this_is_the_second_cap_range = false
      this_is_the_third_cap_range = false
      if boiler_cap < first_cutoff_blr_cap
        this_is_the_first_cap_range = true
      elsif boiler_cap > second_cutoff_blr_cap
        this_is_the_third_cap_range = true
      else
        this_is_the_second_cap_range = true
      end
      # compare boiler capacities to expected values
      boilers.each do |iboiler|
        if iboiler.name.to_s.include? 'Primary Boiler'
          boiler_cap_is_correct = false
          if this_is_the_first_cap_range || this_is_the_third_cap_range
            cap_diff = (boiler_cap - iboiler.nominalCapacity.to_f).abs / boiler_cap
          elsif this_is_the_second_cap_range
            cap_diff = (0.5 * boiler_cap - iboiler.nominalCapacity.to_f).abs / (0.5 * boiler_cap)
          end
          if cap_diff < tol then boiler_cap_is_correct = true end
          assert(boiler_cap_is_correct, 'test_number_of_boilers: Primary boiler capacity is not correct')
        end
        if iboiler.name.to_s.include? 'Secondary Boiler'
          boiler_cap_is_correct = false
          if this_is_the_first_cap_range || this_is_the_third_cap_range
            cap_diff = (iboiler.nominalCapacity.to_f - 0.001).abs
          elsif this_is_the_second_cap_range
            cap_diff = (0.5 * boiler_cap - iboiler.nominalCapacity.to_f).abs / (0.5 * boiler_cap)
          end
          if cap_diff < tol then boiler_cap_is_correct = true end
          assert(boiler_cap_is_correct, 'test_number_of_boilers: Secondary boiler capacity is not correct')
        end
      end
    end
  end

  # Test to validate the boiler part load performance curve
  def test_NECB2011_boiler_plf_vs_plr_curve
    output_folder = "#{File.dirname(__FILE__)}/output/boiler_plf_vs_plr_curve"
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    # Generate the osm files for all relevant cases to generate the test data for system 1
    boiler_res_file_output_text = "Name,Type,coeff1,coeff2,coeff3,coeff4,min_x,max_x\n"
    boiler_fueltype = 'NaturalGas'
    mau_type = true
    mau_heating_coil_type = 'Hot Water'
    baseboard_type = 'Hot Water'
    template = 'NECB2011'
    model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/5ZoneNoHVAC.osm")
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "#{template}_sys1_Boiler-#{boiler_fueltype}_Mau-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}"
    puts "***************************************#{name}*******************************************************\n"
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule	
    BTAP::Resources::HVAC::HVACTemplates::NECB2011::setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    BTAP::Resources::HVAC::HVACTemplates::NECB2011.assign_zones_sys1(
      model,
      model.getThermalZones,
      boiler_fueltype,
      mau_type,
      mau_heating_coil_type,
      baseboard_type,
      hw_loop)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
    # run the standards
    result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_boiler_plf_vs_plr_curve: Failure in Standards for #{name}")
    boilers = model.getBoilerHotWaters
    boiler_curve = boilers[0].normalizedBoilerEfficiencyCurve.get.to_CurveCubic.get
    boiler_res_file_output_text += "BOILER-EFFFPLR-NECB2011,cubic,#{boiler_curve.coefficient1Constant},#{boiler_curve.coefficient2x},#{boiler_curve.coefficient3xPOW2}," +
    "#{boiler_curve.coefficient4xPOW3},#{boiler_curve.minimumValueofx},#{boiler_curve.maximumValueofx}"

    # Write actual results file
    test_result_file = File.join(File.dirname(__FILE__), 'data', "#{template.downcase}_compliance_boiler_plfvsplr_curve_test_results.csv")
    File.open(test_result_file, 'w') { |f| f.write(boiler_res_file_output_text) }
    # Test that the values are correct by doing a file compare.
    expected_result_file = File.join(File.dirname(__FILE__), 'data', "#{template.downcase}_compliance_boiler_plfvsplr_curve_expected_results.csv")
    b_result = FileUtils.compare_file(expected_result_file, test_result_file)
    assert(b_result,
    "test_boiler_plf_vs_plr_curve: Boiler plf vs plr curve coeffs test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")
  end

  def run_the_measure(model, template, sizing_dir)
    if PERFORM_STANDARDS
      # Hard-code the building vintage
      building_vintage = template
      building_type = 'NECB'
      climate_zone = 'NECB'
      standard = Standard.build(building_vintage)
      
      # Make a directory to run the sizing run in
      unless Dir.exist? sizing_dir
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

      BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/before.osm")

      # need to set prototype assumptions so that HRV added
      standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
      # Apply the HVAC efficiency standard
      standard.model_apply_hvac_efficiency_standard(model, climate_zone)
      # self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}

      BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/after.osm")

      return true
    end
  end
end

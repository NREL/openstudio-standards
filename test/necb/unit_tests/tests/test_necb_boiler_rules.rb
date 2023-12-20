require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Boiler_Tests < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end


  # Test to validate the boiler thermal efficiency generated against expected values.
  #  Makes use of the template design pattern with the work done by the do_ method below (i.e. 'do_' prepended to the current method name)
  def no_test_boiler_efficiency

    # Define test parameters.
    test_parameters = {test_method: __method__,
                       save_intermediate_models: false,
                       mau_type: true, 
                       mau_heating_coil_type: 'Hot Water',
                       baseboard_type: 'Hot Water'}

    # Read expected results. This is used to set the tested cases as the parameters change depending on the
    # fuel type and boiler size.
    file_root = "#{self.class.name}-#{__method__}".downcase
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results_json = JSON.parse(File.read(file_name), {symbolize_names: true})
  
    # Create empty results hash and call the template method that runs the individual test cases.
    test_results = parse_json_and_test(expected_results: expected_results_json, test_pars: test_parameters)

    # Write test results.
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Check if test results match expected.
    msg = "Boiler efficiencies test results do not match what is expected in test"
    file_compare(expected_results_file: expected_results_json, test_results_file: test_results, msg: msg, type: 'json_data')
  end

  # Companion method to test_boiler_efficiency that runs a specific test.
  # test_pars has the initially defined parameters plus where we are in the nexted results hash.
  # test_case has the specific test parameters.
  def do_test_boiler_efficiency(test_pars:, test_case:)

    # Debug.
    #puts JSON.pretty_generate(test_pars)
    #puts JSON.pretty_generate(test_case)

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    output_folder = method_output_folder(test_pars[:test_method])
    save_intermediate_models = test_pars[:save_intermediate_models]
    mau_type = test_pars[:mau_type]
    mau_heating_coil_type = test_pars[:mau_heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    fueltype = test_pars[:FuelType]
    vintage = test_pars[:Vintage]

    # Test specific inputs.
    boiler_cap = test_case[:tested_capacity_kW]
    efficiency_metric = test_case[:efficiency_metric]

    # Define the test name. 
    name = "#{vintage}_sys1_Boiler-#{fueltype}_cap-#{boiler_cap.to_int}kW_MAU-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}"
    name.gsub!(/\s+/, "-")
    puts "***************#{name}***************\n"

    # Wrap test in begin/rescue/ensure.
    begin

      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}/baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard = get_standard(vintage)
      standard.setup_hw_loop_with_components(model, hw_loop, fueltype, always_on)
      standard.add_sys1_unitary_ac_baseboard_heating(model: model,
                                                    zones: model.getThermalZones,
                                                    mau_type: mau_type,
                                                    mau_heating_coil_type: mau_heating_coil_type,
                                                    baseboard_type: baseboard_type,
                                                    hw_loop: hw_loop)
      
      # Set the boiler capacity. Convert from kw to W first!
      model.getBoilerHotWaters.each {|iboiler| iboiler.setNominalCapacity(boiler_cap*1000.0)}

      # Run sizing.
      run_sizing(model: model, template: vintage, test_name: name, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS
    rescue => error
      puts "Something went wrong! #{error.message}"
    end

    # Recover the thermal efficiency set in the measure for checking below.
    test_efficiency_value = 0
    model.getBoilerHotWaters.each do |iboiler|
      if iboiler.nominalCapacity.to_f > 1
        test_efficiency_value = iboiler.nominalThermalEfficiency
        break
      end
    end

    # Convert efficiency depending on the metric being used.
    if efficiency_metric == 'annual fuel utilization efficiency'
      test_efficiency_value = standard.thermal_eff_to_afue(test_efficiency_value)
    elsif efficiency_metric == 'combustion efficiency'
      test_efficiency_value = standard.thermal_eff_to_comb_eff(test_efficiency_value)
    elsif efficiency_metric == 'thermal efficiency'
      test_efficiency_value = test_efficiency_value
    end

    # Add this test case to results and return the hash.
    results = {
      name: name,
      tested_capacity_kW: boiler_cap.signif,
      efficiency_metric: efficiency_metric,
      efficiency_value: test_efficiency_value.signif(3)
    }
  end

  
  # Test to validate the number of boilers used and their capacities depending on total heating capacity.
  # NECB2011 rule for number of boilers is:
  # if capacity <= 176 kW ---> one single stage boiler
  # if capacity > 176 kW and <= 352 kW ---> 2 boilers of equal capacity
  # if capacity > 352 kW ---> one modulating boiler down to 25% of capacity"
  def test_number_of_boilers

    # Define test parameters.
    test_parameters = {test_method: __method__,
                       save_intermediate_models: false,
                       mau_type: true, 
                       boiler_fueltype: 'NaturalGas',
                       heating_coil_type: 'Electric',
                       baseboard_type: 'Hot Water'}


    # Read expected results. This is used to set the tested cases as the parameters change depending on the
    # fuel type and boiler size.
    file_root = "#{self.class.name}-#{__method__}".downcase
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results_json = JSON.parse(File.read(file_name), {symbolize_names: true})
  
    # Create empty results hash and call the template method that runs the individual test cases.
    test_results = parse_json_and_test(expected_results: expected_results_json, test_pars: test_parameters)

    # Write test results.
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Check if test results match expected.
    msg = "Boiler efficiencies test results do not match what is expected in test"
    file_compare(expected_results_file: expected_results_json, test_results_file: test_results, msg: msg, type: 'json_data')

  end
  
  # Companion method to test_number_of_boilers that runs a specific test.
  # test_pars has the initially defined parameters plus where we are in the nexted results hash.
  # test_case has the specific test parameters.
  def do_test_number_of_boilers(test_pars:, test_case:)
    
    # Debug.
    puts JSON.pretty_generate(test_pars)
    puts JSON.pretty_generate(test_case)

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    output_folder = method_output_folder(test_pars[:test_method])
    save_intermediate_models = test_pars[:save_intermediate_models]
    mau_type = test_pars[:mau_type]
    heating_coil_type = test_pars[:mau_heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    boiler_fueltype = test_pars[:FuelType]
    vintage = test_pars[:Vintage]

    # Test specific inputs.
    boiler_cap = test_case[:tested_capacity_kW]

    # What are these?
    first_cutoff_blr_cap = 176000.0
    second_cutoff_blr_cap = 352000.0
    tol = 1.0e-3

    # Define the test name. 
    name = "Sys1_#{boiler_cap.round(0)}W_#{boiler_fueltype}_boiler_HeatingCoilType-#{heating_coil_type}_Baseboard-#{baseboard_type}"
    long_name = "#{vintage}_#{name}"
    name.gsub!(/\s+/, "-")
    puts "*************** #{long_name} ***************\n"

    # Wrap test in begin/rescue/ensure.
    begin
      
      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}/baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard = get_standard(vintage)
      standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
      standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(
          model: model,
          zones: model.getThermalZones,
          heating_coil_type: heating_coil_type,
          baseboard_type: baseboard_type,
          hw_loop: hw_loop,
          new_auto_zoner: false)
      model.getBoilerHotWaters.each {|iboiler| iboiler.setNominalCapacity(boiler_cap)}

      # Run sizing. Is this required?
      run_sizing(model: model, template: vintage, test_name: name, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS
    rescue => error
      puts "Something went wrong! #{error.message}"
    end
    
    # Check that there are two boilers in the model. BTAP sets the second boiler to 0.001 W if the rules say only one boiler required.
    boilers = model.getBoilerHotWaters
    num_of_boilers_is_correct = false
    if boilers.size == 2 then
      num_of_boilers_is_correct = true
    end
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
    primary_boiler_capacity = []
    secondary_boiler_capacity = []
    boilers.each do |iboiler|
      if iboiler.name.to_s.include? 'Primary Boiler'
        primary_boiler_capacity = iboiler.nominalCapacity.to_f
        boiler_cap_is_correct = false
        if this_is_the_first_cap_range || this_is_the_third_cap_range
          cap_diff = (boiler_cap - iboiler.nominalCapacity.to_f).abs / boiler_cap
        elsif this_is_the_second_cap_range
          cap_diff = (0.5 * boiler_cap - iboiler.nominalCapacity.to_f).abs / (0.5 * boiler_cap)
        end
        if cap_diff < tol then
          boiler_cap_is_correct = true
        end
        assert(boiler_cap_is_correct, 'test_number_of_boilers: Primary boiler capacity is not correct')
      end
      if iboiler.name.to_s.include? 'Secondary Boiler'
        secondary_boiler_capacity = iboiler.nominalCapacity.to_f
        boiler_cap_is_correct = false
        if this_is_the_first_cap_range || this_is_the_third_cap_range
          cap_diff = (iboiler.nominalCapacity.to_f - 0.001).abs
        elsif this_is_the_second_cap_range
          cap_diff = (0.5 * boiler_cap - iboiler.nominalCapacity.to_f).abs / (0.5 * boiler_cap)
        end
        if cap_diff < tol then
          boiler_cap_is_correct = true
        end
        assert(boiler_cap_is_correct, 'test_number_of_boilers: Secondary boiler capacity is not correct')
      end
    end
    
    # Add this test case to results.
    results = {
      name: name,
      tested_capacity_kW: (boiler_cap/1000.0).signif, # Still in W
      number_of_boilers: boilers.size,
      primary_boiler_capacity_kW: (primary_boiler_capacity[0]/1000.0).signif, # Still in W
      secondary_boiler_capacity_kW: (secondary_boiler_capacity[0]/1000.0).signif # Still in W
    }
  end

  # Test to validate the boiler part load performance curve
  def no_test_NECB2011_boiler_plf_vs_plr_curve

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 1.
    boiler_res_file_output_text = "Name,Type,coeff1,coeff2,coeff3,coeff4,min_x,max_x\n"
    boiler_fueltype = 'NaturalGas'
    mau_type = true
    mau_heating_coil_type = 'Hot Water'
    baseboard_type = 'Hot Water'

    name = "#{template}_sys1_Boiler-#{boiler_fueltype}_Mau-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}"
    name.gsub!(/\s+/, "-")
    puts "***************#{name}***************\n"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
    standard.add_sys1_unitary_ac_baseboard_heating(model: model,
                                                   zones: model.getThermalZones,
                                                   mau_type: mau_type,
                                                   mau_heating_coil_type: mau_heating_coil_type,
                                                   baseboard_type: baseboard_type,
                                                   hw_loop: hw_loop)

    # Run sizing.
    run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS

    boilers = model.getBoilerHotWaters
    boiler_curve = boilers[0].normalizedBoilerEfficiencyCurve.get.to_CurveCubic.get
    boiler_res_file_output_text += "BOILER-EFFFPLR-NECB2011,cubic,#{boiler_curve.coefficient1Constant},#{boiler_curve.coefficient2x},#{boiler_curve.coefficient3xPOW2}," +
        "#{boiler_curve.coefficient4xPOW3},#{boiler_curve.minimumValueofx},#{boiler_curve.maximumValueofx}"

    # Write test results file.
    test_result_file = File.join( @test_results_folder, "#{template.downcase}_compliance_boiler_plfvsplr_curve_test_results.csv")
    File.open(test_result_file, 'w') {|f| f.write(boiler_res_file_output_text)}

    # Test that the values are correct by doing a file compare.
    expected_result_file = File.join( @expected_results_folder, "#{template.downcase}_compliance_boiler_plfvsplr_curve_expected_results.csv")

    # Check if test results match expected.
    msg = "Boiler plf vs plr curve coeffs test results do not match what is expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end

  # Test to validate the custom boiler thermal efficiencies applied against expected values stored in the file:
  # 'compliance_boiler_custom_efficiencies_expected_results.json
  def test_custom_efficiency

    puts "*****************************************************************************"
    puts "*****************************************************************************"
    loop_hash = {:vintage => @AllTemplates, :ecms => ["a", 'B'], :weather => ["ottawa", "toronto", "vancouver"]}
    make_empty_expected_json(loop_hash)
    puts "*****************************************************************************"
    puts "*****************************************************************************"

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    templates = ['NECB2011', 'BTAPPRE1980']
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 1.
    mau_type = true
    mau_heating_coil_type = 'Hot Water'
    baseboard_type = 'Hot Water'
    test_res = []

    templates.each do |template|
      standard = get_standard(template)
      standard_ecms = get_standard("ECMS")
      boiler_fueltype = 'NaturalGas'
      boiler_cap = 1500000
      standard_ecms.standards_data["tables"]["boiler_eff_ecm"]["table"].each do |cust_eff_test|
        name = "#{template}_sys1_Boiler-#{boiler_fueltype}_cap-#{boiler_cap.to_int}W_MAU-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}_efficiency-#{cust_eff_test["name"].to_s}"
        name.gsub!(/\s+/, "-")
        puts "***************#{name}***************\n"
      
        # Load model and set climate file.
        model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models
        
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
        standard.add_sys1_unitary_ac_baseboard_heating(model: model,
                                                       zones: model.getThermalZones,
                                                       mau_type: mau_type,
                                                       mau_heating_coil_type: mau_heating_coil_type,
                                                       baseboard_type: baseboard_type,
                                                       hw_loop: hw_loop)
        model.getBoilerHotWaters.each {|iboiler| iboiler.setNominalCapacity(boiler_cap)}

        # Run sizing.
        run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS

        # Customize the efficiency.
        standard_ecms.modify_boiler_efficiency(model: model, boiler_eff: cust_eff_test)

        boilers = model.getBoilerHotWaters
        boilers.each do |boiler|
          corr_coeff = []
          eff_curve = nil
          eff_curve_type = boiler.normalizedBoilerEfficiencyCurve.get.iddObjectType.valueName.to_s
          case eff_curve_type
          when "OS_Curve_Bicubic"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveBicubic.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.coefficient4y
            corr_coeff << eff_curve.coefficient5yPOW2
            corr_coeff << eff_curve.coefficient6xTIMESY
            corr_coeff << eff_curve.coefficient7xPOW3
            corr_coeff << eff_curve.coefficient8yPOW3
            corr_coeff << eff_curve.coefficient9xPOW2TIMESY
            corr_coeff << eff_curve.coefficient10xTIMESYPOW2
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
            corr_coeff << eff_curve.minimumValueofy
            corr_coeff << eff_curve.maximumValueofy
          when "OS_Curve_Biquadratic"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveBiquadratic.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.coefficient4y
            corr_coeff << eff_curve.coefficient5yPOW2
            corr_coeff << eff_curve.coefficient6xTIMESY
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
            corr_coeff << eff_curve.minimumValueofy
            corr_coeff << eff_curve.maximumValueofy
          when "OS_Curve_Cubic"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveCubic.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.coefficient4xPOW3
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
          when "OS_Curve_Linear"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveLinear.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
          when "OS_Curve_Quadratic"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveQuadratic.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
          when "OS_Curve_QuadraticLinear"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveQuadraticLinear.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.coefficient4y
            corr_coeff << eff_curve.coefficient5xTIMESY
            corr_coeff << eff_curve.coefficient6xPOW2TIMESY
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
            corr_coeff << eff_curve.minimumValueofy
            corr_coeff << eff_curve.maximumValueofy
          end
          eff_curve_name = eff_curve.name
          boiler_eff = boiler.nominalThermalEfficiency
          test_res << {
              template: template,
              boiler_name: boiler.name,
              boiler_eff: boiler_eff,
              eff_curve_name: eff_curve_name,
              curve_coefficients: corr_coeff
          }
        end
      end
    end

    # Write test results.
    test_result_file = File.join( @test_results_folder, "boiler_efficiency_modification_test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_res))
    expected_result_file = File.join( @test_results_folder, "boiler_efficiency_modification_expected_results.json")

    # Check if test results match expected.
    msg = "Boiler custom efficiencies test results do not match what is expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end

end

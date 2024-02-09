require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Chiller_Test < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # For NECB 2020 testing, for all chiller types except the centrifugal chillers, I don't think we can test the last row of NECB2020 code of capacities more than 2110 kw, as it will be divided into 2 chillers,
  # each chiller will have 1055 kW and that would move it to the upper row of NECB2020 code and COP will be always 5.633 not 6.018 (Mariana)
  # Consequently i've updated the expected results for all chiller types except the centrifugal chillers that are more then 2110 kW (7,200,000 btu/hr) to be 5.633 not 6.018
  def test_NECB_chiller_cop
    logger.info "Starting suite of tests for: #{__method__}"
    
    # Define test parameters that apply to all tests.
    test_parameters = {test_method: __method__,
                       save_intermediate_models: false,
                       boiler_fueltype: 'Electricity',
                       mau_cooling_type: 'Hydronic'}

    # Define test cases. 
    test_cases = Hash.new

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = {:Reference => "NECB 2011 p3 Table 5.2.12.1 which points to CSA-C743-09 (Table 10)"}
    test_cases[:NECB2015] = {:Reference => "NECB 2015 ?"}
    test_cases[:NECB2017] = {:Reference => "NECB 2017 p3 Table 5.2.12.1 which points to CSA-C743-09 (Table 10) and NRCan regs?"}
    test_cases[:NECB2020] = {:Reference => "NECB 2020 p1 Table 5.2.12.1.-K (Path B)"}
    
    # Test cases. Define each case seperately as they have unique kW values to test accross the vintages/chiller types.
    test_cases_hash = {:Vintage => ['NECB2011', 'NECB2020'], 
                       :ChillerType => ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"],
                       :TestCase => ["small"], 
                       :TestPars => {:tested_capacity_kW => 132}}
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = {:Vintage => ['NECB2011', 'NECB2020'], 
                       :ChillerType => ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"],
                       :TestCase => ["medium"], 
                       :TestPars => {:tested_capacity_kW => 396}}
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = {:Vintage => ['NECB2011', 'NECB2020'], 
                       :ChillerType => ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"],
                       :TestCase => ["large"], 
                       :TestPars => {:tested_capacity_kW => 791}}
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = {:Vintage => ['NECB2011', 'NECB2020'], 
                       :ChillerType => ["Scroll", "Centrifugal", "Rotary Screw", "Reciprocating"],
                       :TestCase => ["x-large"], 
                       :TestPars => {:tested_capacity_kW => 1200}}
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    # Create empty results hash and call the template method that runs the individual test cases.
    test_results = do_test_cases(test_cases: test_cases, test_pars: test_parameters)

    # Write test results.
    file_root = "#{self.class.name}-#{__method__}".downcase
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Read expected results. 
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results = JSON.parse(File.read(file_name), {symbolize_names: true})

    # Check if test results match expected.
    msg = "Chiller COP test results do not match what is expected in test"
    file_compare(expected_results_file: expected_results, test_results_file: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_NECB_chiller_cop that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_NECB_chiller_cop (test_pars:, test_case:)

    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    output_folder = method_output_folder(test_pars[:test_method])
    save_intermediate_models = test_pars[:save_intermediate_models]
    mau_cooling_type = test_pars[:mau_cooling_type]
    boiler_fueltype = test_pars[:boiler_fueltype]
    vintage = test_pars[:Vintage]
    chiller_type = test_pars[:ChillerType]

    # Test specific inputs.
    chiller_cap = test_case[:tested_capacity_kW]

    # Define the test name. 
    name = "#{vintage}_sys2_ChillerType-#{chiller_type}_Chiller_cap-#{chiller_cap}kW"
    name.gsub!(/\s+/, "-")
    logger.info "Starting individual test: #{name}"

    # Wrap test in begin/rescue/ensure.
    begin
      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}/baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard = get_standard(vintage)
      standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
      standard.add_sys2_FPFC_sys5_TPFC(model: model,
                                      zones: model.getThermalZones,
                                      chiller_type: chiller_type,
                                      fan_coil_type: 'FPFC',
                                      mau_cooling_type: mau_cooling_type,
                                      hw_loop: hw_loop)
      model.getChillerElectricEIRs.each {|chiller| chiller.setReferenceCapacity(chiller_cap*1000.0)}

      # Run sizing.
      run_sizing(model: model,  template: vintage, test_name: name, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS
    rescue => error
      logger.error "#{__FILE__}::#{__method__} #{error.message}"
    end

    # Recover the COP for checking. 
    results = Hash.new
    chiller_count = 0
    total_capacity = 0.0
    model.getChillerElectricEIRs.each do |chiller|
      next if chiller.referenceCapacity.to_f < 0.1

      # Add this test case to results.
      chiller_count += 1
      chiller_capacity = (chiller.referenceCapacity.to_f)/1000.0
      total_capacity += chiller_capacity
      chillerID = "Chiller-#{chiller_count}"
      results[chillerID.to_sym]= {
        name: chiller.name.to_s,
        tested_capacity_kW: chiller_cap.signif,
        capacity_kW: chiller_capacity.signif,
        capacity_ton: OpenStudio.convert(chiller_capacity, 'kW', 'ton').get.signif,
        capacity_BTUh: OpenStudio.convert(chiller_capacity, 'kW', 'kBtu/hr').get.signif,
        COP_kW_kW: chiller.referenceCOP.to_f.signif,
        COP_kW_ton: OpenStudio.convert((1.0/chiller.referenceCOP.to_f), '1/kW', '1/ton').get.signif
      }
    end

    logger.info "Completed individual test: #{name}"
    return results
  end

  # Test to validate the number of chillers used and their capacities depending on total cooling capacity.
  # NECB2011 rule for number of chillers is:
  # "if capacity <= 2100 kW ---> one chiller
  # if capacity > 2100 kW ---> 2 chillers with half the capacity each"
  def no_test_number_of_chillers
    logger.info "Starting: #{__method__}"

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = {:Reference => "NECB 2011 p3 8.4.4.11.(6)"}

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    save_intermediate_models = false

    first_cutoff_chlr_cap = 2100000.0
    tol = 1.0e-3

    # Generate the osm files for all relevant cases to generate the test data for system 6.
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating']
    heating_coil_type = 'Hot Water'
    fan_type = 'AF_or_BI_rdg_fancurve'
    test_chiller_cap = [1000000.0, 3000000.0]
    
    # Read expected results. This is used to set the tested cases as the parameters change depending on the
    # fuel type and boiler size.
    file_root = "#{self.class.name}-#{__method__}".downcase
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    #expected_results = JSON.parse(File.read(file_name), {symbolize_names: true})
    expected_results = {}

    # Initialize test results hash.
    test_results = {}
    
    # Loop through the templates rather than using those defined in the file (this way we identify if any are missing).
    @AllTemplates.each do |template|
      
      # Create empty entry for the test cases results and copy over the reference.
      template_cases_results = {}
      begin
        template_cases_results[:reference] = expected_results[template.to_sym][:reference]
      rescue NoMethodError => error
        template_cases_results[:reference] = "Reference required"
        test_results[template.to_sym] = template_cases_results
        logger.warn "Adding reference tag to results for #{template} in #{__method__}"
      end

      # Load template/standard.
      standard = get_standard(template)

      chiller_types.each do |chiller_type|

        # Create empty entry this test case results.
        individual_case_results = {}

        # Loop through the individual test cases.
        #test_cases = expected_results[template.to_sym][fueltype.to_sym]
        #next if test_cases.nil?
        #test_cases.each do |key, test_case|

          # Define local variables.
          #case_name = key.to_s
          #fueltype = fueltype.to_s
          #boiler_cap = test_case[:tested_capacity_kW]
          #efficiency_metric = test_case[:efficiency_metric]

        test_chiller_cap.each do |chiller_cap|
          name = "sys6_ChillerType_#{chiller_type}-Chiller_cap-#{chiller_cap}watts"
          name.gsub!(/\s+/, "-")
          puts "***************#{name}***************\n"

          # Wrap test in begin/rescue/ensure.
          begin

            # Load model and set climate file.
            model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
            BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
            BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

            hw_loop = OpenStudio::Model::PlantLoop.new(model)
            always_on = model.alwaysOnDiscreteSchedule
            standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
            standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                                zones: model.getThermalZones,
                                                                                heating_coil_type: heating_coil_type,
                                                                                baseboard_type: baseboard_type,
                                                                                chiller_type: chiller_type,
                                                                                fan_type: fan_type,
                                                                                hw_loop: hw_loop)
            model.getChillerElectricEIRs.each {|ichiller| ichiller.setReferenceCapacity(chiller_cap)}

            # Run the standards.
            run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS
          rescue => error
            logger.error "#{__FILE__}::#{__method__} #{error.message}"
          end

          # Check that there are two chillers in the model.
          chillers = model.getChillerElectricEIRs
          num_of_chillers_is_correct = false
          if chillers.size == 2 then
            num_of_chillers_is_correct = true
          end
          assert(num_of_chillers_is_correct, 'Number of chillers is not 2 in test #{self.class}.')
          this_is_the_first_cap_range = false
          this_is_the_second_cap_range = false
          if chiller_cap < first_cutoff_chlr_cap
            this_is_the_first_cap_range = true
          else
            this_is_the_second_cap_range = true
          end
          
          # Compare chiller capacities to expected values.
          chillers.each do |ichiller|
            if ichiller.name.to_s.include? 'Primary Chiller'
              chiller_cap_is_correct = false
              if this_is_the_first_cap_range
                cap_diff = (chiller_cap - ichiller.referenceCapacity.to_f).abs / chiller_cap
              elsif this_is_the_second_cap_range
                cap_diff = (0.5 * chiller_cap - ichiller.referenceCapacity.to_f).abs / (0.5 * chiller_cap)
              end
              if cap_diff < tol then
                chiller_cap_is_correct = true
              end
              assert(chiller_cap_is_correct, 'Primary chiller capacity is not correct in test #{self.class}.')
            end
            if ichiller.name.to_s.include? 'Secondary Chiller'
              chiller_cap_is_correct = false
              if this_is_the_first_cap_range
                cap_diff = (ichiller.referenceCapacity.to_f - 0.001).abs
              elsif this_is_the_second_cap_range
                cap_diff = (0.5 * chiller_cap - ichiller.referenceCapacity.to_f).abs / (0.5 * chiller_cap)
              end
              if cap_diff < tol then
                chiller_cap_is_correct = true
              end
              assert(chiller_cap_is_correct, 'Secondary chiller capacity is not correct in test #{self.class}.')
            end
          end
          
        #rescue NoMethodError => error
        #  test_results[template.to_sym][fueltype.to_sym] = {}
        #  puts "Probably triggered by the template not existing in the expected results set. Continue and report at end.\n#{error.message}"
          #end
          # Add this test case to results.
          case_name = "case_#{(chiller_cap/1000.0).signif}kW"
          template_cases_results[case_name.to_sym] = {
            name: name,
            tested_capacity_kW: (chiller_cap/1000.0).signif, # Still in W
            number_of_chillers: chillers.size,
            primary_chiller_capacity_kW: (primary_chiller_capacity/1000.0).signif, # Still in W
            secondary_chiller_capacity_kW: (secondary_chiller_capacity/1000.0).signif # Still in W
          }
        end

        # Add results for this template to the results hash.
        cases_results = {}
        cases_results[:cases] = template_cases_results
        test_results[template.to_sym] = cases_results
      end
    end

    # Write test results.
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Check if test results match expected.
    msg = "Number of chillers and capacity test results do not match what is expected in test"
    file_compare(expected_results_file: expected_results, test_results_file: test_results, msg: msg, type: 'json_data')
    logger.info "Finished: #{__method__}"
  end

  # Test to validate the chiller performance curves.
  def no_test_chiller_curves
    logger.info "Starting: #{__method__}"

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = {:Reference => "NECB 2011 p3 Table 8.4.4.22.C"}

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = false

    expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_chiller_curves_expected_results.csv")

    chiller_curve_names = {}
    chiller_curve_names['Scroll'] = []
    chiller_curve_names['Reciprocating'] = []
    chiller_curve_names['Rotary Screw'] = []
    chiller_curve_names['Centrifugal'] = []
    CSV.foreach(expected_result_file, headers: true) do |data|
      chiller_curve_names[data['Chiller Type']] << data['Curve Name']
    end

    # Generate the osm files for all relevant cases to generate the test data for system 5.
    chiller_res_file_output_text = "Chiller Type,Curve Name,Curve Type,coeff1,coeff2,coeff3,coeff4,coeff5,coeff6,min_x,max_x,min_y,max_y\n"
    boiler_fueltype = 'NaturalGas'
    chiller_types = ['Scroll', 'Reciprocating', 'Rotary Screw', 'Centrifugal']
    mua_cooling_type = 'Hydronic'
    
    chiller_types.each do |chiller_type|
      name = "sys5_ChillerType_#{chiller_type}"
      name.gsub!(/\s+/, "-")
      puts "***************#{name}***************\n"

      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
      standard.add_sys2_FPFC_sys5_TPFC(model: model,
                                       zones: model.getThermalZones,
                                       chiller_type: chiller_type,
                                       fan_coil_type: 'FPFC',
                                       mau_cooling_type: mua_cooling_type,
                                       hw_loop: hw_loop)
      
      # Run sizing.
      run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS

      chillers = model.getChillerElectricEIRs
      chiller_cap_ft_curve = chillers[0].coolingCapacityFunctionOfTemperature.to_CurveBiquadratic.get
      chiller_res_file_output_text +=
        "#{chiller_type},#{chiller_curve_names[chiller_type][0]},biquadratic,#{'%.5E' % chiller_cap_ft_curve.coefficient1Constant},#{'%.5E' % chiller_cap_ft_curve.coefficient2x}," +
          "#{'%.5E' % chiller_cap_ft_curve.coefficient3xPOW2},#{'%.5E' % chiller_cap_ft_curve.coefficient4y},#{'%.5E' % chiller_cap_ft_curve.coefficient5yPOW2}," +
          "#{'%.5E' % chiller_cap_ft_curve.coefficient6xTIMESY},#{'%.5E' % chiller_cap_ft_curve.minimumValueofx},#{'%.5E' % chiller_cap_ft_curve.maximumValueofx}," +
          "#{'%.5E' % chiller_cap_ft_curve.minimumValueofy},#{'%.5E' % chiller_cap_ft_curve.maximumValueofy}\n"
      chiller_eir_ft_curve = chillers[0].electricInputToCoolingOutputRatioFunctionOfTemperature.to_CurveBiquadratic.get
      chiller_res_file_output_text +=
        "#{chiller_type},#{chiller_curve_names[chiller_type][1]},biquadratic,#{'%.5E' % chiller_eir_ft_curve.coefficient1Constant},#{'%.5E' % chiller_eir_ft_curve.coefficient2x}," +
          "#{'%.5E' % chiller_eir_ft_curve.coefficient3xPOW2},#{'%.5E' % chiller_eir_ft_curve.coefficient4y},#{'%.5E' % chiller_eir_ft_curve.coefficient5yPOW2}," +
          "#{'%.5E' % chiller_eir_ft_curve.coefficient6xTIMESY},#{'%.5E' % chiller_eir_ft_curve.minimumValueofx},#{'%.5E' % chiller_eir_ft_curve.maximumValueofx}," +
          "#{'%.5E' % chiller_eir_ft_curve.minimumValueofy},#{'%.5E' % chiller_eir_ft_curve.maximumValueofy}\n"
      chiller_eir_plr_curve = chillers[0].electricInputToCoolingOutputRatioFunctionOfPLR.to_CurveQuadratic.get
      chiller_res_file_output_text +=
        "#{chiller_type},#{chiller_curve_names[chiller_type][2]},quadratic,#{'%.5E' % chiller_eir_plr_curve.coefficient1Constant},#{'%.5E' % chiller_eir_plr_curve.coefficient2x}," +
          "#{'%.5E' % chiller_eir_plr_curve.coefficient3xPOW2},#{'%.5E' % chiller_eir_plr_curve.minimumValueofx},#{'%.5E' % chiller_eir_plr_curve.maximumValueofx}\n"
    end

    # Write actual results file.
    test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_chiller_curves_test_results.csv")
    File.open(test_result_file, 'w') {|f| f.write(chiller_res_file_output_text.chomp)}

    # Check if test results match expected.
    msg = "Chiller performance curve coeffs test results do not match expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end
  logger.info "Finished: #{__method__}"
end

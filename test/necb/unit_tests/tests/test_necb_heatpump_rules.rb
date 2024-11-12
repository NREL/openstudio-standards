require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_HVAC_Heat_Pump_Tests < Minitest::Test
  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate the heating efficiency generated against expected values stored in the file:
  # 'compliance_heatpump_efficiencies_expected_results.csv
  def test_heatpump_efficiency
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all tests.
    test_parameters = {
      test_method: __method__,
      save_intermediate_models: true,
      heating_coil_type: 'DX',
      baseboard_type: 'Hot Water'
    }

    # Define test cases.
    test_cases = {}
    # Define references (per vintage in this case).
    test_cases[:NECB2011] = { :Reference => "NECB 2011 p3:Table 5.2.12.1." }
    test_cases[:NECB2015] = { :Reference => "NECB 2015 p1:Table 5.2.12.1." }
    test_cases[:NECB2017] = { :Reference => "NECB 2017 p2:Table 5.2.12.1." }
    test_cases[:NECB2020] = { :Reference => "NECB 2020 p1:Table 5.2.12.1.-A" }

    # Test cases. Three cases for NG and FuelOil, one for Electric.
    # Results and name are tbd here as they will be calculated in the test.

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-1"],
                        :TestPars => { :test_capacity_kW => 9.5 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-2"],
                        :TestPars => { :test_capacity_kW => 29.5 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-3"],
                        :TestPars => { :test_capacity_kW => 55.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-4"],
                        :TestPars => { :test_capacity_kW => 146.5 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-5"],
                        :TestPars => { :test_capacity_kW => 233 } }
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
    expected_results = JSON.parse(File.read(file_name), { symbolize_names: true })
    # Check if test results match expected.
    msg = "Heat pump efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_heatpump_efficiency that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_heatpump_efficiency(test_pars:, test_case:)

    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    heating_coil_type = test_pars[:heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    fueltype = test_pars[:FuelType]
    vintage = test_pars[:Vintage]
    standard = get_standard(vintage)
    # Test specific inputs.
    cap = test_case[:test_capacity_kW]
    # Define the test name.
    name = "#{vintage}_sys3_HtgDXCoilCap_#{fueltype}_cap-#{cap.to_int}kW__Baseboard-#{baseboard_type}"
    name_short = "#{vintage}_sys3_HtgDXCoilCap_cap-#{cap.to_int}kW"

    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"
    actual_heatpump_cop = []

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model, hw_loop, fueltype, always_on)
    standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                zones: model.getThermalZones,
                                                                                                heating_coil_type: heating_coil_type,
                                                                                                baseboard_type: baseboard_type,
                                                                                                hw_loop: hw_loop,
                                                                                                new_auto_zoner: false)

=begin
      dx_htg_coils = model.getCoilHeatingDXSingleSpeeds
      dx_htg_coils.each do |coil|
        coil.setRatedTotalHeatingCapacity(cap * 1000)
        flow_rate = cap * 1000 * 5.0e-5
        coil.setRatedAirFlowRate(flow_rate)
      end
=end

    dx_clg_coils = model.getCoilCoolingDXSingleSpeeds
    dx_clg_coils.each do |coil|
      coil.setRatedTotalCoolingCapacity(cap * 1000)
      flow_rate = cap * 1000 * 5.0e-5
      coil.setRatedAirFlowRate(flow_rate)
    end

    # Wrap test in begin/rescue/ensure.
    begin
      # Run sizing.
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS
      actual_heatpump_cop = model.getCoilHeatingDXSingleSpeeds[0].ratedCOP.to_f

      dx_htg_coils = model.getCoilHeatingDXSingleSpeeds
      dx_htg_coils.each do |coil|
        cap_h = coil.ratedTotalHeatingCapacity
        puts "Rated Total Heating Capacity: #{cap_h}"
        puts "coil #{coil}"
      end

      capacity_btu_per_hr = OpenStudio.convert(cap.to_f, 'kW', 'Btu/hr').get
      actual_heatpump_copH = actual_heatpump_cop / (1.48E-7 * capacity_btu_per_hr + 1.062)
      # https://github.com/NREL/openstudio-standards/blob/971514ee0a64262a9c81788fd85fc60d8dd69980/lib/openstudio-standards/prototypes/common/objects/Prototype.utilities.rb#L379C7-L379C58
      results = {
        test_capacity_kW: cap.signif,
        test_capacity_btu_per_hr: capacity_btu_per_hr.signif,
        actual_heatpump_cop: actual_heatpump_cop.round(2),
        actual_heatpump_copH: actual_heatpump_copH.round(2)
      }

    rescue => error
      logger.error "#{__FILE__}::#{__method__} #{error.message}"
    end

    # Add this test case to results and return the hash.

    logger.info "Completed individual test: #{name}"
    return results
  end

  # Test to validate the heat pump performance curves
  def test_heatpump_curves
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all tests.
    test_parameters = {
      test_method: __method__,
      save_intermediate_models: true,
      heating_coil_type: 'DX',
      baseboard_type: 'Hot Water'
    }

    # Define test cases.
    test_cases = {}

    # Test cases. Three cases for NG and FuelOil, one for Electric.
    # Results and name are tbd here as they will be calculated in the test.

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-1"],
                        :TestPars => { :curve_name => "tbd" } }
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
    expected_results = JSON.parse(File.read(file_name), { symbolize_names: true })
    # Check if test results match expected.
    msg = "Heat pump efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  def do_test_heatpump_curves(test_pars:, test_case:)
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    heating_coil_type = test_pars[:heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    fueltype = test_pars[:FuelType]
    vintage = test_pars[:Vintage]
    standard = get_standard(vintage)
    # Define the test name.
    name = "#{vintage}_sys3_HtgDXCoilCap_#{fueltype}_kW_Baseboard-#{baseboard_type}"
    name_short = "#{vintage}_sys3_HtgDXCoilCap"

    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"
    actual_heatpump_cop = []

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model, hw_loop, fueltype, always_on)
    standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                zones: model.getThermalZones,
                                                                                                heating_coil_type: heating_coil_type,
                                                                                                baseboard_type: baseboard_type,
                                                                                                hw_loop: hw_loop,
                                                                                                new_auto_zoner: false)

    run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS

    dx_units = model.getCoilHeatingDXSingleSpeeds
    results = {}

    dx_units.each do |dx_unit|
      results[dx_unit.name.get] = {}

      # Define the curves and their types inline, using curve names as keys
      curves = [
        { curve: dx_unit.totalHeatingCapacityFunctionofTemperatureCurve.to_CurveCubic.get, type: 'cubic' },
        { curve: dx_unit.energyInputRatioFunctionofTemperatureCurve.to_CurveCubic.get, type: 'cubic' },
        { curve: dx_unit.totalHeatingCapacityFunctionofFlowFractionCurve.to_CurveCubic.get, type: 'cubic' },
        { curve: dx_unit.energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get, type: 'quadratic' },
        { curve: dx_unit.partLoadFractionCorrelationCurve.to_CurveCubic.get, type: 'cubic' }
      ]

      # Populate the result hash using curve names as keys
      curves.each do |curve_detail|
        curve = curve_detail[:curve]
        curve_name = curve.name.get
        results[dx_unit.name.get][curve_name] = {
          curve_type: curve_detail[:type],
          coefficient1Constant: sprintf('%.5E', curve.coefficient1Constant),
          coefficient2x: sprintf('%.5E', curve.coefficient2x),
          coefficient3xPOW2: sprintf('%.5E', curve.coefficient3xPOW2),
          minimumValueofx: sprintf('%.5E', curve.minimumValueofx),
          maximumValueofx: sprintf('%.5E', curve.maximumValueofx)
        }
        # Conditionally add `coefficient4xPOW3` if it exists (only for cubic curves)
        results[dx_unit.name.get][curve_name][:coefficient4xPOW3] = sprintf('%.5E', curve.coefficient4xPOW3) if curve.respond_to?(:coefficient4xPOW3)
      end
    end

    # Sort results hash
    results = results.sort.to_h
    return results
  end
end
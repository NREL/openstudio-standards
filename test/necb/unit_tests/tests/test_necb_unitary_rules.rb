require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_HVAC_Unitary_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  def test_unitary_efficiency
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all tests.
    test_parameters = {
      test_method: __method__,
      save_intermediate_models: true,
      mau_type: true,
      speeds: 'single',
      baseboard_type: 'Hot Water',
      fuelType: 'NaturalGas'
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
                        :unitary_heating_types => ['Electric Resistance', 'All Other'],
                        :TestCase => ["case-1"],
                        :TestPars => { :test_capacity_kW => 9.5 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :unitary_heating_types => ['Electric Resistance', 'All Other'],
                        :TestCase => ["case-2"],
                        :TestPars => { :test_capacity_kW => 29.5 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :unitary_heating_types => ['Electric Resistance', 'All Other'],
                        :TestCase => ["case-3"],
                        :TestPars => { :test_capacity_kW => 55.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :unitary_heating_types => ['Electric Resistance', 'All Other'],
                        :TestCase => ["case-4"],
                        :TestPars => { :test_capacity_kW => 146.5 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :unitary_heating_types => ['Electric Resistance', 'All Other'],
                        :TestCase => ["case-5"],
                        :TestPars => { :test_capacity_kW => 253 } }
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
    msg = "Unitary efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_unitary_efficiency that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_unitary_efficiency(test_pars:, test_case:)

    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"
    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    speed = test_pars[:speeds]
    baseboard_type = test_pars[:baseboard_type]
    fueltype = test_pars[:fuelType]
    heating_type = test_pars[:unitary_heating_types]
    # Test specific inputs.
    cap = test_case[:test_capacity_kW]
    vintage = test_pars[:Vintage]
    standard = get_standard(vintage)
    # Define the test name.
    name = "#{vintage}_sys3_MauHtgCoilType-#{heating_type}_Speed-#{speed}_cap-#{cap.to_int}kW"
    name_short = "#{vintage}_#{heating_type}_cap-#{cap.to_int}kW"
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"

    # Wrap test in begin/rescue/ensure.
    begin

      if heating_type == 'Electric Resistance'
        heating_coil_type = 'Electric'
      elsif heating_type == 'All Other'
        heating_coil_type = 'Gas'
      end
      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model, hw_loop, fueltype, always_on)
      case speed
      when 'single'
        standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                    zones: model.getThermalZones,
                                                                                                    heating_coil_type: heating_coil_type,
                                                                                                    baseboard_type: baseboard_type,
                                                                                                    hw_loop: hw_loop,
                                                                                                    new_auto_zoner: false)
        model.getCoilCoolingDXSingleSpeeds.each do |dxcoil|
          dxcoil.setRatedTotalCoolingCapacity(cap * 1000)
          flow_rate = cap * 1000 * 5.0e-5
          dxcoil.setRatedAirFlowRate(flow_rate)
        end
      when 'multi'
        standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed(model: model,
                                                                                                   zones: model.getThermalZones,
                                                                                                   heating_coil_type: heating_coil_type,
                                                                                                   baseboard_type: baseboard_type,
                                                                                                   hw_loop: hw_loop,
                                                                                                   new_auto_zoner: false)
      end

      # Save the model after btap hvac.
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")

      # Run the measure.
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS

    rescue => error
      logger.error "#{__FILE__}::#{__method__} #{error.message}"
    end
    results = {}
    dx_units = model.getCoilCoolingDXSingleSpeeds
    dx_units.each do |dx_unit|
      dx_unit_name = dx_unit.name.get
      cop = dx_unit.ratedCOP.to_f
      seer = standard.cop_to_seer_cooling_with_fan(cop.to_f)
      eer = standard.cop_to_eer(cop.to_f)
      # Add this test case to results and return the hash.
      results[dx_unit_name] = {
        speed: speed,
        tested_capacity_kW: cap.round(2),
        cop: cop.round(2),
        seer: seer.round(2),
        eer: eer.round(2)
      }
    end
    logger.info "Completed individual test: #{name}"
    results = results.sort.to_h

    return results
  end

  # Test to validate the unitary performance curves
  def test_unitary_curves
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all tests.
    test_parameters = {
      test_method: __method__,
      save_intermediate_models: true,
      chiller_type: 'Scroll',
      mau_cooling_type: 'DX'
    }

    # Define test cases.
    test_cases = {}

    # Test cases. Three cases for NG and FuelOil, one for Electric.
    # Results and name are tbd here as they will be calculated in the test.

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["NaturalGas"],
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
    msg = "Unitary efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  def do_test_unitary_curves(test_pars:, test_case:)
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    chiller_type = test_pars[:chiller_type]
    mau_cooling_type = test_pars[:mau_cooling_type]
    fueltype = test_pars[:FuelType]
    vintage = test_pars[:Vintage]
    standard = get_standard(vintage)
    # Define the test name.
    name = "#{vintage}_sys2_CoolingType_#{fueltype}_kW_chiller_type-#{chiller_type}_#{mau_cooling_type}"
    name_short = "#{vintage.downcase}_sys2_CoolingType-#{chiller_type}_#{mau_cooling_type}"

    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
    weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
    OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model, hw_loop, fueltype, always_on)

    standard.add_sys2_FPFC_sys5_TPFC(model: model,
                                     zones: model.getThermalZones,
                                     chiller_type: chiller_type,
                                     fan_coil_type: 'FPFC',
                                     mau_cooling_type: mau_cooling_type,
                                     hw_loop: hw_loop)

    run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS

    dx_units = model.getCoilCoolingDXSingleSpeeds
    results = {}

    dx_units.each do |dx_unit|
      dx_unit_name = dx_unit.name.get
      results[dx_unit_name] ||= {} # Initialize hash for dx_unit_name

      # Define the curves and their types inline
      curves = [
        { curve: dx_unit.totalCoolingCapacityFunctionOfTemperatureCurve.to_CurveBiquadratic.get, type: 'biquadratic' },
        { curve: dx_unit.energyInputRatioFunctionOfTemperatureCurve.to_CurveBiquadratic.get, type: 'biquadratic' },
        { curve: dx_unit.totalCoolingCapacityFunctionOfFlowFractionCurve.to_CurveQuadratic.get, type: 'quadratic' },
        { curve: dx_unit.energyInputRatioFunctionOfFlowFractionCurve.to_CurveQuadratic.get, type: 'quadratic' },
        { curve: dx_unit.partLoadFractionCorrelationCurve.to_CurveCubic.get, type: 'cubic' }
      ]

      curves.each do |curve_detail|
        curve = curve_detail[:curve]
        next unless curve # Skip if the curve is nil

        curve_name = curve.name.get
        results[dx_unit_name][curve_name] ||= {} # Initialize hash for curve_name

        # Add mandatory attributes
        results[dx_unit_name][curve_name] = {
          curve_type: curve_detail[:type],
          coefficient1Constant: sprintf('%.5E', curve.coefficient1Constant),
          coefficient2x: sprintf('%.5E', curve.coefficient2x),
          coefficient3xPOW2: sprintf('%.5E', curve.coefficient3xPOW2),
          minimumValueofx: sprintf('%.5E', curve.minimumValueofx),
          maximumValueofx: sprintf('%.5E', curve.maximumValueofx)
        }

        # Define a mapping of optional attributes
        attributes = {
          coefficient4y: :coefficient4y,
          coefficient5yPOW2: :coefficient5yPOW2,
          coefficient6xTIMESY: :coefficient6xTIMESY,
          minimumValueofy: :minimumValueofy,
          maximumValueofy: :maximumValueofy
        }

        # Conditionally add optional attributes if the methods exist
        attributes.each do |key, method|
          if curve.respond_to?(method)
            results[dx_unit_name][curve_name][key] = sprintf('%.5E', curve.send(method))
          end
        end
      end
    end

    # Sort results hash
    results = results.sort.to_h
    return results
  end
end

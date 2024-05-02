require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_HVAC_HRV_Tests < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate the hrv efficiency and requirements.
  # Makes use of the template design pattern with the work done by the do_* method below (i.e. 'do_' prepended to the current method name)
  def test_hrv_efficiency
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all tests.
    test_parameters = { test_method: __method__,
                        save_intermediate_models: true,
                        fueltype: 'Electricity',
                        heating_coil_type: 'DX',
                        baseboard_type: 'Hot Water' }
    # Define test cases.
    test_cases = {}
    # Define references (per vintage in this case).
    test_cases[:NECB2011] = { :Reference => "NECB 2011 p3 5.2.10.1." }
    test_cases[:NECB2015] = { :Reference => "NECB 2015 p1 5.2.10.1.(1)" }
    test_cases[:NECB2017] = { :Reference => "NECB 2017 p2 5.2.10.1.(1), Table 5.2.10.1.-B" }
    test_cases[:NECB2020] = { :Reference => "NECB 2020 p1 5.2.10.1.(1), Table 5.2.10.1.-B" }

    # For compliance with NECB 2011 and NECB 2015, HRV is mandated when exhaust heat exceeds 150 kW.
    test_cases_hash = { :Vintage => ["NECB2011", "NECB2015"],
                        :TestCase => ["NO-HRV-Required"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.25,
                                       :flow => 10.0,
                                       :weather_file_name => "CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    # A multiplier of 80 is applied to simulate cases where exhaust heat surpasses the 150 kW threshold.
    test_cases_hash = { :Vintage => ["NECB2011", "NECB2015"],
                        :TestCase => ["HRV-Required"],
                        :TestPars => { :multiplier_factor => 80.0,
                                       :oaf => 0.25,
                                       :flow => 10.0,
                                       :weather_file_name => "CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    # In compliance with NECB 2017 and NECB 2020 standards, HRV is mandated when the Heating Degree Days (HDD) surpass 3000;
    # Otherwise, its necessity hinges on airflow thresholds. Subsequent test cases will encompass various air flow ranges.
    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 5"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.25,
                                       :flow => 10.0,
                                       :weather_file_name => "CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 4 - OAF 0.15 F 10 - Not required"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.15,
                                       :flow => 10.0,
                                       :weather_file_name => "CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 4 - OAF 0.25 F 10"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.25,
                                       :flow => 10.0,
                                       :weather_file_name => "CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 4 - OAF 0.35 F 5"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.35,
                                       :flow => 5.0,
                                       :weather_file_name => "CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 4 - OAF 0.45 F 3"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.45,
                                       :flow => 3.0,
                                       :weather_file_name => "CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 4 - OAF 0.55 F 2"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.55,
                                       :flow => 2.0,
                                       :weather_file_name => "CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 4 - OAF 0.65 F 1.6"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.65,
                                       :flow => 1.6,
                                       :weather_file_name => "CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 4 - OAF 0.75 F 1"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.75,
                                       :flow => 1.0,
                                       :weather_file_name => "CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 4 - OAF 0.55 F 1.4 - Not required"],
                        :TestPars => { :multiplier_factor => 1.0,
                                       :oaf => 0.55,
                                       :flow => 1.4,
                                       :weather_file_name => "CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw" } }
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
    msg = "HRV efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_hrv_efficiency that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_hrv_efficiency(test_pars:, test_case:)
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    fueltype = test_pars[:fueltype]
    baseboard_type = test_pars[:baseboard_type]
    heating_coil_type = test_pars[:heating_coil_type]
    vintage = test_pars[:Vintage]
    weather_file_name = test_case[:weather_file_name]
    # Extract the city name from the weather file name
    city = weather_file_name.split('_')[2]
    city = city.split('.')[0]
    multiplier_factor = test_case[:multiplier_factor]
    oaf = test_case[:oaf]
    flow = test_case[:flow]
    name = "#{vintage}_multiplier_factor_#{multiplier_factor}_#{oaf}_#{flow}_#{city}_hrv"
    name_short = "#{vintage}_#{multiplier_factor}_#{oaf}_#{flow}_#{city}_hrv"
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"
    # Wrap test in begin/rescue/ensure.
    begin
      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
      # Create a WeatherFile object with the specified weather file name
      weather_file = BTAP::Environment::WeatherFile.new(weather_file_name)
      # Set the weather file for the model
      weather_file.set_weather_file(model)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models
      standard = get_standard(vintage)

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model, hw_loop, fueltype, always_on)
      standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                  zones: model.getThermalZones,
                                                                                                  heating_coil_type: heating_coil_type,
                                                                                                  baseboard_type: baseboard_type,
                                                                                                  hw_loop: hw_loop,
                                                                                                  new_auto_zoner: false)

      systems = model.getAirLoopHVACs
      for isys in 0..0
        zones = systems[isys].thermalZones
        zones.each do |izone|
          spaces = izone.spaces
          spaces.each do |ispace|
            oa_objs = ispace.designSpecificationOutdoorAir.get
            oa_flow_p_person = oa_objs.outdoorAirFlowperPerson
            oa_objs.setOutdoorAirFlowperPerson(multiplier_factor * oa_flow_p_person) # l/s
          end
        end
      end

      # Test the compliance with OA requirements outlined in NECB 2017 Table 5.2.10.1.-B for the Airflow Rate Thresholds
      air_loops_hvac = model.getAirLoopHVACs
      air_loops_hvac.each do |air_loop_hvac|
        if vintage == "NECB2017" || vintage == "NECB2020"
          designSupplyAirFlowRate = flow / oaf
          air_loop_hvac.setDesignSupplyAirFlowRate(designSupplyAirFlowRate)
          oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
          controller_oa = oa_system.getControllerOutdoorAir
          controller_oa.setMinimumOutdoorAirFlowRate(flow)
          # Had to increase the MaximumOutdoorAirFlowRate, otherwise E+ would fail by :
          # "maximum outdoor air flow rate < minimum outdoor air flow rate"
          controller_oa.setMaximumOutdoorAirFlowRate(flow * 1.2)
        end
      end

      # Run sizing.
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS
    rescue => error
      logger.error "#{__FILE__}::#{__method__} #{error.message}"
    end

    # Extract the results for checking.
    results = Hash.new

    # Calculate the min_oa_flow_m3_per_s and the dsn_flow_m3_per_s
    air_loops_hvac = model.getAirLoopHVACs

    # Sort air loops by name
    sorted_air_loops_hvac = air_loops_hvac.sort_by { |air_loop_hvac| air_loop_hvac.name.get }
    sorted_air_loops_hvac.each do |air_loop_hvac|
      has_hrv = false
      exhaust_heat_content_kW = standard.calculate_exhaust_heat(air_loop_hvac)

      air_loop_hvac_name = air_loop_hvac.name.get
=begin
      # Not sure if we need this, it only retrieves the flow and OAF values that we set earlier in the test?
      if vintage == "NECB2017" || vintage == "NECB2020"
        oa_system = nil
        controller_oa = nil
        #Get the minimum OA flow rate
        min_oa_flow_m3_per_s = nil
        #Get the AHU design supply air flow rate
        dsn_flow_m3_per_s = nil
        if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
          oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
          controller_oa = oa_system.getControllerOutdoorAir
          min_oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
          dsn_flow_m3_per_s = air_loop_hvac.designSupplyAirFlowRate.get
        else
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not applicable because it has no OA intake.")
          return false
        end
        flow = min_oa_flow_m3_per_s
        oaf = min_oa_flow_m3_per_s / dsn_flow_m3_per_s
      end
=end

      hdd = BTAP::Environment::WeatherFile.new(air_loop_hvac.model.weatherFile.get.path.get).hdd18
      has_hrv = standard.air_loop_hvac_energy_recovery_ventilator_required?(air_loop_hvac, 'NECB')
      flow_L_per_s = OpenStudio.convert(flow, 'm^3/s', 'L/s').get
      flow_ft3_per_min = OpenStudio.convert(flow, 'm^3/s', 'ft^3/min').get
      # Add this test case to results and return the hash.
      results[air_loop_hvac_name] = {
        vintage: vintage,
        city: city,
        multiplier_factor: multiplier_factor,
        exhaust_heat_content_kW: exhaust_heat_content_kW.signif(3),
        oaf: oaf.signif(3),
        flow_m3_per_s: flow.signif(3),
        flow_L_per_s: flow_L_per_s.signif(3),
        flow_ft3_per_min: flow_ft3_per_min.signif(3),
        hdd: hdd,
        has_hrv: has_hrv
      }

      if has_hrv
        hrv_objs = model.getHeatExchangerAirToAirSensibleAndLatents.first
        # Check all effectiveness values
        latentEffectivenessat100CoolingAirFlow = hrv_objs.latentEffectivenessat100CoolingAirFlow
        latentEffectivenessat100HeatingAirFlow = hrv_objs.latentEffectivenessat100HeatingAirFlow
        latentEffectivenessat75CoolingAirFlow = hrv_objs.latentEffectivenessat75CoolingAirFlow
        latentEffectivenessat75HeatingAirFlow = hrv_objs.latentEffectivenessat75HeatingAirFlow
        sensibleEffectivenessat100CoolingAirFlow = hrv_objs.sensibleEffectivenessat100CoolingAirFlow
        sensibleEffectivenessat100HeatingAirFlow = hrv_objs.sensibleEffectivenessat100HeatingAirFlow
        sensibleEffectivenessat75CoolingAirFlow = hrv_objs.sensibleEffectivenessat75CoolingAirFlow
        sensibleEffectivenessat75HeatingAirFlow = hrv_objs.sensibleEffectivenessat75HeatingAirFlow

        results[air_loop_hvac_name][:latent_effectiveness_100_cooling] = latentEffectivenessat100CoolingAirFlow
        results[air_loop_hvac_name][:latent_effectiveness_100_heating] = latentEffectivenessat100HeatingAirFlow
        results[air_loop_hvac_name][:latent_effectiveness_75_cooling] = latentEffectivenessat75CoolingAirFlow
        results[air_loop_hvac_name][:latent_effectiveness_75_heating] = latentEffectivenessat75HeatingAirFlow
        results[air_loop_hvac_name][:sensible_effectiveness_100_cooling] = sensibleEffectivenessat100CoolingAirFlow
        results[air_loop_hvac_name][:sensible_effectiveness_100_heating] = sensibleEffectivenessat100HeatingAirFlow
        results[air_loop_hvac_name][:sensible_effectiveness_75_cooling] = sensibleEffectivenessat75CoolingAirFlow
        results[air_loop_hvac_name][:sensible_effectiveness_75_heating] = sensibleEffectivenessat75HeatingAirFlow
      end
      logger.info "Completed individual test: #{name}"
    end
    return results
  end
end


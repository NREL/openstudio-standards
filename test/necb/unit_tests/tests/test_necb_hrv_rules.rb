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

    # Test cases. Two cases for NG and one for Electric.
    # Results and name are tbd here as they will be calculated in the test.
    # Define a multiplier factor to increase default outdoor air flow rate
    # multiplier_factor = 35.0

    test_cases_hash = { :Vintage => ["NECB2011", "NECB2015"],
                        :TestCase => ["NO-HRV-Required"],
                        :TestPars => { :multiplier_factor => 1.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2011", "NECB2015"],
                        :TestCase => ["HRV-Required"],
                        :TestPars => { :multiplier_factor => 150.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    # Define test cases.
    test_cases = {}
    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 4"],
                        :TestPars => { :weather_file_name => "CAN_BC_Victoria.Intl.AP.717990_CWEC2016.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => ["NECB2017", "NECB2020"],
                        :TestCase => ["Climate zone 5"],
                        :TestPars => { :weather_file_name => "CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw" } }
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
    # expected_results = JSON.parse(File.read(file_name), { symbolize_names: true })
    # Check if test results match expected.
    msg = "hrv efficiencies test results do not match what is expected in test"
    # compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
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
    puts " ccc  vintage #{vintage}"
    if vintage == "NECB2011" || vintage == "NECB2015"
      multiplier_factor = test_case[:multiplier_factor]
      name = "#{vintage}_multiplier_factor_#{multiplier_factor}_hrv"
      name_short = "#{vintage}_#{multiplier_factor}_hrv"
      output_folder = method_output_folder("#{test_name}/#{name_short}")
      logger.info "Starting individual test: #{name}"
      # Wrap test in begin/rescue/ensure.
      begin
        # Load model and set climate file.
        model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
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
              # oa_flow_p_person = oa_objs.outdoorAirFlowperPerson
              # oa_objs.setOutdoorAirFlowperPerson(30.0*oa_flow_p_person) #l/s

              # Set outdoor air flow rate per floor area to ensure some systems require an HRV.
              # Multiplying it by 35 increases the default value to trigger HRV requirement for certain systems.
              # Using flow per floor area instead of per person, as it's multiplied by space area to sum up OA for all spaces in each zone.
              oa_objs.setOutdoorAirFlowperFloorArea(multiplier_factor * 0.0003048)
            end
          end
        end
        # Run sizing.
        run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS
      rescue => error
        logger.error "#{__FILE__}::#{__method__} #{error.message}"
      end

      # Extract the results for checking.
      results = Hash.new

      # Code for the calculation of exhaust heat content is copied from the NECB2011 standard (hvac_systems.rb).
      air_loops_hvac = model.getAirLoopHVACs
      air_loops_hvac.each do |air_loop_hvac|
        air_loop_hvac_name = air_loop_hvac.name.get
        hrv_present = false
        sum_zone_oa = 0.0
        sum_zone_oa_times_heat_design_t = 0.0
        exhaust_heat_content_kW = 0.0
        # get all zones in the model

        zones = air_loop_hvac.thermalZones
        # zone loop
        exhaust_heat_content_kW = 0.0
        zones.each do |zone|
          # get design heat temperature for each zone; this is equivalent to design exhaust temperature
          heat_design_t = 21.0
          zone_thermostat = zone.thermostat.get
          if zone_thermostat.to_ThermostatSetpointDualSetpoint.is_initialized
            dual_thermostat = zone_thermostat.to_ThermostatSetpointDualSetpoint.get
            if dual_thermostat.heatingSetpointTemperatureSchedule.is_initialized
              htg_temp_sch = dual_thermostat.heatingSetpointTemperatureSchedule.get
              htg_temp_sch_ruleset = htg_temp_sch.to_ScheduleRuleset.get
              winter_dd_sch = htg_temp_sch_ruleset.winterDesignDaySchedule
              heat_design_t = winter_dd_sch.values.max
              puts " heat_design_t #{heat_design_t}"
            end
          end
          # initialize counter
          zone_oa = 0.0
          # outdoor defined at space level; get OA flow for all spaces within zone
          spaces = zone.spaces
          # space loop
          spaces.each do |space|
            unless space.designSpecificationOutdoorAir.empty? # if empty, don't do anything
              outdoor_air = space.designSpecificationOutdoorAir.get
              # in bTAP, outdoor air specified as outdoor air per
              oa_flow_per_floor_area = outdoor_air.outdoorAirFlowperFloorArea
              oa_flow = oa_flow_per_floor_area * space.floorArea * zone.multiplier # oa flow for the space
              zone_oa += oa_flow # add up oa flow for all spaces to get zone air flow
            end
            # space loop
          end
          sum_zone_oa += zone_oa # sum of all zone oa flows to get system oa flow
          sum_zone_oa_times_heat_design_t += (zone_oa * heat_design_t) # calculated to get oa flow weighted average of design exhaust temperature
          # zone loop
        end
        # Calculate average exhaust temperature (oa flow weighted average)
        avg_exhaust_temp = sum_zone_oa_times_heat_design_t / sum_zone_oa
        # Get January winter design temperature
        # get model weather file name
        weather_file = BTAP::Environment::WeatherFile.new(air_loop_hvac.model.weatherFile.get.path.get)
        outdoor_temp = weather_file.heating_design_info[1]

        # Calculate exhaust heat content
        # exhaust_heat_content_kW = 0.0
        exhaust_heat_content_kW = 0.00123 * sum_zone_oa * 1000.0 * (avg_exhaust_temp - outdoor_temp)
        # ##################################################################################
        puts ".... vintage #{vintage}"
        has_hrv = standard.air_loop_hvac_energy_recovery_ventilator_required?(air_loop_hvac, 'NECB')

        # Add this test case to results and return the hash.
        results[air_loop_hvac_name] = {
          vintage: vintage,
          multiplier_factor: multiplier_factor,
          exhaust_heat_content_kW: exhaust_heat_content_kW.signif(3),
          has_hrv: has_hrv
        }
        if has_hrv
          # assert has_hrv, "HRV is required but not present"
          hrv_objs = model.getHeatExchangerAirToAirSensibleAndLatents.first
          # Check if all effectiveness values
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

    elsif vintage == "NECB2017" || vintage == "NECB2020"
      # Test specific inputs.
      weather_file_name = test_case[:weather_file_name]
      # Extract the city name from the weather file name
      city_name = weather_file_name.split('_')[2]
      city_name = city_name.split('.')[0]
      name = "#{vintage}city_name#{city_name}_hrv"
      name_short = "#{vintage}_#{city_name}_hrv"
      output_folder = method_output_folder("#{test_name}/#{name_short}")
      logger.info "Starting individual test: #{name}"
      # Wrap test in begin/rescue/ensure.
      begin
        # Load model and set climate file.
        model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
        # BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)

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

        # Run sizing.
        run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS
      rescue => error
        logger.error "#{__FILE__}::#{__method__} #{error.message}"
      end

      # Extract the results for checking.
      results = Hash.new
      air_loops_hvac = model.getAirLoopHVACs
      air_loops_hvac.each do |air_loop_hvac|
        air_loop_hvac_name = air_loop_hvac.name.get
        climate_zone = 'NECB HDD Method'
        oa_system = nil
        controller_oa = nil
        if air_loop_hvac.airLoopHVACOutdoorAirSystem.is_initialized
          oa_system = air_loop_hvac.airLoopHVACOutdoorAirSystem.get
          controller_oa = oa_system.getControllerOutdoorAir
        else
          OpenStudio.logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name}, ERV not applicable because it has no OA intake.")
          return false
        end

        # Get the AHU design supply air flow rate
        dsn_flow_m3_per_s = nil
        if air_loop_hvac.designSupplyAirFlowRate.is_initialized
          dsn_flow_m3_per_s = air_loop_hvac.designSupplyAirFlowRate.get
        elsif air_loop_hvac.autosizedDesignSupplyAirFlowRate.is_initialized
          dsn_flow_m3_per_s = air_loop_hvac.autosizedDesignSupplyAirFlowRate.get
        else
         OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{air_loop_hvac.name} design supply air flow rate is not available, cannot apply efficiency standard.")
          return false
        end

        # Get the minimum OA flow rate
        min_oa_flow_m3_per_s = nil
        if controller_oa.minimumOutdoorAirFlowRate.is_initialized
          min_oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
        elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
          min_oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{controller_oa.name}: minimum OA flow rate is not available, cannot apply efficiency standard.")
          return false
        end
        flow = min_oa_flow_m3_per_s
        oaf = min_oa_flow_m3_per_s / dsn_flow_m3_per_s

        has_hrv = standard.air_loop_hvac_energy_recovery_ventilator_required?(air_loop_hvac, climate_zone)
        results[air_loop_hvac_name] = {
          city_name: city_name,
          flow: flow.signif(3),
          oaf: oaf.signif(3),
          has_hrv: has_hrv
        }
        if has_hrv
          # assert has_hrv, "HRV is required but not present"
          hrv_objs = model.getHeatExchangerAirToAirSensibleAndLatents.first
          # Check if all effectiveness values
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
end


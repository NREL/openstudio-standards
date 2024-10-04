require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)
require 'parallel'
require 'time'

class NECB_HVAC_water_heater_Tests < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  def logger
    NecbHelper.logger
  end

  # Test to validate the eff of water_heaters
  def test_eff_of_water_heaters
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters.
    test_parameters = { test_method: __method__,
                        save_intermediate_models: true,
                        baseboard_type: 'Hot Water',
                        heating_coil_type: 'DX' }

    # Define test cases. 
    test_cases = Hash.new

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = { :Reference => "NECB 2011 Table 6.2.2.1." }
    test_cases[:NECB2015] = { :Reference => "NECB 2015 Table 6.2.2.1." }
    test_cases[:NECB2017] = { :Reference => "NECB 2017 Table 6.2.2.1." }
    test_cases[:NECB2020] = { :Reference => "NECB 2020 Table 6.2.2.1." }

    # Test cases. Three cases for NG and FuelOil, one for Electric.
    # Results and name are tbd here as they will be calculated in the test.
    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-1"],
                        :TestPars => { :tested_capacity_kW => 10.0,
                                       :tested_volume_L => 200.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-2"],
                        :TestPars => { :tested_capacity_kW => 10.0,
                                       :tested_volume_L => 300.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-3"],
                        :TestPars => { :tested_capacity_kW => 20.0,
                                       :tested_volume_L => 300.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-4"],
                        :TestPars => { :tested_capacity_kW => 20.0,
                                       :tested_volume_L => 500.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["NaturalGas"],
                        :TestCase => ["case-5"],
                        :TestPars => { :tested_capacity_kW => 10.0,
                                       :tested_volume_L => 100.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["NaturalGas"],
                        :TestCase => ["case-6"],
                        :TestPars => { :tested_capacity_kW => 25.0,
                                       :tested_volume_L => 300.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    test_cases_hash = { :Vintage => @AllTemplates,
                        :FuelType => ["NaturalGas"],
                        :TestCase => ["case-7"],
                        :TestPars => { :tested_capacity_kW => 125.0,
                                       :tested_volume_L => 300.0 } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    # Read expected results. This is used to set the tested cases as the parameters change depending on the
    # fuel type and water_heater size.
    file_root = "#{self.class.name}-#{__method__}".downcase
    # file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    # expected_results = JSON.parse(File.read(file_name), { symbolize_names: true })
    # Create empty results hash and call the template method that runs the individual test cases.
    test_results = do_test_cases(test_cases: test_cases, test_pars: test_parameters)

    # Write test results.
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Check if test results match expected.
    msg = "Water_heater efficiencies test results do not match what is expected in test"
    # compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')

    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_number_of_water_heaters that runs a specific test. Called by do_test_cases in necb_helper.rb.

  def do_test_eff_of_water_heaters(test_pars:, test_case:)
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    heating_coil_type = test_pars[:heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    water_heater_fueltype = test_pars[:FuelType]
    vintage = test_pars[:Vintage]

    # Test specific inputs.
    icap = test_case[:tested_capacity_kW]
    ivol = test_case[:tested_volume_L]
    # Define the test name. 
    name = "#{vintage}_cap_#{icap.round(0)}kW_#{water_heater_fueltype}_vol_#{ivol.round(0)}L"
    name_short = "#{vintage}_#{icap.round(0)}kW_#{water_heater_fueltype}_#{ivol.round(0)}L"
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"
    standard = get_standard(vintage)

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    # add SWH loop.
    prototype_input = {}
    prototype_input['main_water_heater_volume'] = ivol / 1000.0
    prototype_input['main_service_water_temperature'] = 60.0
    prototype_input['main_service_water_pump_head'] = 1.0
    prototype_input['main_service_water_pump_motor_efficiency'] = 0.7
    prototype_input['main_water_heater_capacity'] = icap * 1000.0
    prototype_input['main_water_heater_fuel'] = water_heater_fueltype
    prototype_input['main_service_water_parasitic_fuel_consumption_rate'] = 1.0
    standard.model_add_swh_loop(model,
                                'Main Service Water Loop',
                                nil,
                                prototype_input['main_service_water_temperature'],
                                prototype_input['main_service_water_pump_head'],
                                prototype_input['main_service_water_pump_motor_efficiency'],
                                prototype_input['main_water_heater_capacity'],
                                prototype_input['main_water_heater_volume'],
                                prototype_input['main_water_heater_fuel'],
                                prototype_input['main_service_water_parasitic_fuel_consumption_rate'])

    # Add hvac system.
    if water_heater_fueltype == "NaturalGas" && vintage == "NECB2020"
      results = {}
      # Test space types - SWH demand depends on space type + space area.
      test_spacetypes = ["Office enclosed <= 25 m2", "Health care facility operating room", "Museum general exhibition area", "Retail facility mall concourse"]
      #, "Warehouse storage area medium to bulky palletized items", "Transportation facility baggage/carousel area","Conference/Meeting/Multi-purpose room", "Audience seating area permanent - gymnasium", "Computer/Server room-sch-C", "Gymnasium/Fitness centre playing area"]

      test_spacetypes.each do |test_spacetype|
        name_sp = test_spacetype.to_s.downcase
        # Remove spaces and special characters.
        name_sp = name_sp.gsub(" ", "-").gsub("<=", "").gsub("/", "-")
        output_folder = method_output_folder("#{test_name}/#{name}/#{name_sp}")

        # Load model and set climate file.
        model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC5Storeys.osm"))
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
        BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm") if save_intermediate_models

        # Set spacetype.
        model.getSpaces.each do |space|
          st = OpenStudio::Model::SpaceType.new(model)
          st.setStandardsBuildingType("Space Function")
          st.setStandardsSpaceType(test_spacetype)
          st.setName("#{"Space Function"} #{test_spacetype}")
          space.setSpaceType(st)
        end

        # Add SWH loop.
        standard.model_add_swh(model: model, swh_fueltype: 'DefaultFuel', shw_scale: 1.0)
        # Add HVAC system.
        boiler_fueltype = 'NaturalGas'
        baseboard_type = 'Hot Water'
        heating_coil_type = 'DX'
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
        standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                    zones: model.getThermalZones,
                                                                                                    heating_coil_type: heating_coil_type,
                                                                                                    baseboard_type: baseboard_type,
                                                                                                    hw_loop: hw_loop,
                                                                                                    new_auto_zoner: false)

        run_sizing(model: model, template: vintage, test_name: name_sp, output_dir: output_folder, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS

        # Calc FHR
        fhr_L_per_hr = standard.calculate_total_peak_flow_rate(model: model, shw_scale: 'NECB_Default')
        # Convert to L/hr.
        fhr_L_per_hr = fhr_L_per_hr * 3600000.0

        # Get standard water tank efficiency and standby losses.
        shw_units = model.getWaterHeaterMixeds
        icap = (shw_units[0].heaterMaximumCapacity.get.to_f) / 1000.0 # kW
        ivol = (shw_units[0].tankVolume.get.to_f) * 1000.0 # Litres

        actual_shw_tank_eff = shw_units[0].heaterThermalEfficiency.to_f
        actual_offcycle_ua = shw_units[0].offCycleLossCoefficienttoAmbientTemperature.to_f
        actual_oncycle_ua = shw_units[0].onCycleLossCoefficienttoAmbientTemperature.to_f

        # Add this test case to results and return the hash.
        results[name_sp] = {
          space_type: name_sp,
          water_heater_name: shw_units[0].name,
          capacity_kW: icap.signif(3),
          volume_L: ivol.signif(3),
          first_hour_rating_L_per_hr: fhr_L_per_hr.signif(3),
          offcycle_standby_loss: actual_offcycle_ua.signif(3),
          oncycle_standby_loss: actual_oncycle_ua.signif(3),
          shw_tank_eff: actual_shw_tank_eff.signif(3)
        }
        puts "results #{results}"
      end
    else
      baseboard_type = 'Hot Water'
      heating_coil_type = 'DX'
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model, hw_loop, water_heater_fueltype, always_on)
      standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                  zones: model.getThermalZones,
                                                                                                  heating_coil_type: heating_coil_type,
                                                                                                  baseboard_type: baseboard_type,
                                                                                                  hw_loop: hw_loop,
                                                                                                  new_auto_zoner: false)

      # Set volume and capacity of water tank.
      shw_units = model.getWaterHeaterMixeds
      shw_units[0].setHeaterMaximumCapacity(1000.0 * icap)
      shw_units[0].setTankVolume(ivol / 1000.0)

      # Run sizing.
      run_sizing(model: model, template: vintage, test_name: name, output_dir: output_folder, save_model_versions: save_intermediate_models) if PERFORM_STANDARDS

      # Get standard water tank efficiency and standby losses.
      actual_shw_tank_eff = shw_units[0].heaterThermalEfficiency.to_f
      actual_offcycle_ua = shw_units[0].offCycleLossCoefficienttoAmbientTemperature.to_f
      actual_oncycle_ua = shw_units[0].onCycleLossCoefficienttoAmbientTemperature.to_f

      results = Hash.new

      # Add this test case to results and return the hash.
      results = {
        water_heater_name: shw_units[0].name,
        capacity_kW: icap.signif(3),
        volume_L: ivol.signif(3),
        offcycle_standby_loss: actual_offcycle_ua.signif(3),
        oncycle_standby_loss: actual_oncycle_ua.signif(3),
        shw_tank_eff: actual_shw_tank_eff.signif(3)
      }
    end

    logger.info "Completed individual test: #{name}"
    return results
  end

end


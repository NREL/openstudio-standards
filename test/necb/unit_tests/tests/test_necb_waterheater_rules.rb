require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_SHW_Additional_Tests < MiniTest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate part-load performance curve of gas fired shw heater
  def test_NECB2011_shw_curves

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template="NECB2011"
    standard = get_standard(template)

    shw_expected_result_file = File.join(@expected_results_folder, 'compliance_shw_curves_expected_results.csv')
    shw_curve_names = []
    CSV.foreach(shw_expected_result_file, headers: true) do |data|
      shw_curve_names << data['Curve Name']
    end
 
    # Generate the osm files for all relevant cases to generate the test data
    shw_res_file_output_text = "Curve Name,Curve Type,coeff1,coeff2,coeff3,coeff4,min_x,max_x\n"
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "shw"
    puts "***************************************#{name}*******************************************************\n"
    # add shw loop
    prototype_input = {}
    prototype_input['main_water_heater_volume'] = 100.0
    prototype_input['main_service_water_temperature'] = 60.0
    prototype_input['main_service_water_pump_head'] = 1.0
    prototype_input['main_service_water_pump_motor_efficiency'] = 0.7
    prototype_input['main_water_heater_capacity'] = 100000.0
    prototype_input['main_water_heater_fuel'] = 'NaturalGas'
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
    # add hvac system
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    heating_coil_type = 'DX'
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
    standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                zones: model.getThermalZones,
                                                                                                heating_coil_type: heating_coil_type,
                                                                                                baseboard_type: baseboard_type,
                                                                                                hw_loop: hw_loop,
                                                                                                new_auto_zoner: false)

            # Run the measure.
            run_the_measure(model: model, test_name: name) if PERFORM_STANDARDS

    # extract standards generated part-load performance curve
    shw_units = model.getWaterHeaterMixeds
    shw_plfvsplr_curve = shw_units[0].partLoadFactorCurve.get
    shw_res_file_output_text +=
        "#{shw_curve_names[0]},cubic,#{'%.5E' % shw_plfvsplr_curve.coefficient1Constant},#{'%.5E' % shw_plfvsplr_curve.coefficient2x}," +
        "#{'%.5E' % shw_plfvsplr_curve.coefficient3xPOW2},#{'%.5E' % shw_plfvsplr_curve.coefficient4xPOW3},#{'%.5E' % shw_plfvsplr_curve.minimumValueofx}," +
        "#{'%.5E' % shw_plfvsplr_curve.maximumValueofx}\n"
    # Write actual results file
    test_result_file = File.join(@test_results_folder, 'compliance_shw_curves_test_results.csv')
    File.open(test_result_file, 'w') { |f| f.write(shw_res_file_output_text.chomp) }
    # Test that the values are correct by doing a file compare.
    expected_result_file = File.join(@expected_results_folder, 'compliance_shw_curves_expected_results.csv')

    # Check if test results match expected.
    msg = "SHW performance curve coeffs test results do not match expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end

  # Test to validate efficiency and standby losses of electric shw heater
  def test_NECB2011_shw_elec_efficiency_standby_losses

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template="NECB2011"
    standard = get_standard(template)
 
    # test tank capacities and volumes (liters)
    test_caps = [10.0,20.0]
    test_vols = [200.0,300.0]
    # Generate the osm files for all relevant cases to generate the test data
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    test_caps.each do |icap|
      test_vols.each do |ivol|
        name = "shw_cap~#{icap}kW~vol~#{ivol}liters"
        puts "***************************************#{name}*******************************************************\n"
        model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
        # add shw loop
        prototype_input = {}
        prototype_input['main_water_heater_volume'] = 100.0
        prototype_input['main_service_water_temperature'] = 60.0
        prototype_input['main_service_water_pump_head'] = 1.0
        prototype_input['main_service_water_pump_motor_efficiency'] = 0.7
        prototype_input['main_water_heater_capacity'] = 100000.0
        prototype_input['main_water_heater_fuel'] = 'Electricity'
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
        # add hvac system
        boiler_fueltype = 'Electricity'
        baseboard_type = 'Hot Water'
        heating_coil_type = 'DX'
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
        standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                    zones: model.getThermalZones,
                                                                                                    heating_coil_type: heating_coil_type,
                                                                                                    baseboard_type: baseboard_type,
                                                                                                    hw_loop: hw_loop,
                                                                                                    new_auto_zoner: false)
        # set volume and capacity of water tank
        shw_units = model.getWaterHeaterMixeds
        shw_units[0].setHeaterMaximumCapacity(1000.0*icap)
        shw_units[0].setTankVolume(ivol/1000.0)

            # Run the measure.
            run_the_measure(model: model, test_name: name) if PERFORM_STANDARDS
        # get standard water tank efficiency and standby losses
        actual_shw_tank_eff = shw_units[0].heaterThermalEfficiency.to_f
        shw_units = model.getWaterHeaterMixeds
        actual_shw_tank_vol = shw_units[0].tankVolume.to_f
        actual_offcycle_ua = shw_units[0].offCycleLossCoefficienttoAmbientTemperature.to_f
        actual_oncycle_ua = shw_units[0].onCycleLossCoefficienttoAmbientTemperature.to_f
        vol_gal = OpenStudio.convert(ivol/1000.0, 'm^3', 'gal').get
        if icap < 12.0
          expected_eff = 1.0
          if ivol < 270.0
            ua_w = 40 + 0.2 * ivol
          else
            ua_w = 0.472 * ivol - 33.5
          end   
          ua_btu_p_hr = OpenStudio.convert(ua_w, 'W', 'Btu/hr').get
        else
          expected_eff = 1.0
          ua_btu_p_hr = 20 + (35 * Math.sqrt(vol_gal))
        end
        ua_btu_p_hr_p_f = ua_btu_p_hr/70.0
        expected_ua_w_p_k = OpenStudio.convert(ua_btu_p_hr_p_f, 'Btu/hr*R', 'W/K').get
        tol = 1.0e-5
        rel_diff = (actual_shw_tank_eff-expected_eff).abs/expected_eff
        value_is_correct = true
        if rel_diff > tol then value_is_correct = false end
        assert(value_is_correct,"SHW efficiency test results do not match expected results!")
        rel_diff = (actual_offcycle_ua-expected_ua_w_p_k).abs/expected_ua_w_p_k
        value_is_correct = true
        if rel_diff > tol then value_is_correct = false end
        assert(value_is_correct,"SHW off cycle standby loss test results do not match expected results!")
        rel_diff = (actual_oncycle_ua-expected_ua_w_p_k).abs/expected_ua_w_p_k
        value_is_correct = true
        if rel_diff > tol then value_is_correct = false end
        assert(value_is_correct,"SHW on cycle standby loss test results do not match expected results!")
      end
    end
  end
  
end

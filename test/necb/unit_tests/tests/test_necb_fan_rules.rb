require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Fan_Rules_Tests < MiniTest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate variable volume fan performance curves and pressure rise
  def test_NECB2011_vav_fan_rules

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = "NECB2011"
    standard = get_standard(template)

    vavfan_expected_result_file = File.join(@expected_results_folder, 'compliance_vavfan_curves_expected_results.csv')
    vavfan_curve_names = []
    CSV.foreach(vavfan_expected_result_file, headers: true) do |data|
      vavfan_curve_names << data['Curve Name']
    end
    # Generate the osm files for all relevant cases to generate the test data for system 6
    vavfan_res_file_output_text = "Curve Name,Curve Type,coeff1,coeff2,coeff3,coeff4,min_x,max_x\n"
    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    chiller_type = 'Scroll'
    heating_coil_type = 'Electric'
    vavfan_type = 'AF_or_BI_rdg_fancurve'
    vavfan_caps = [5000.0, 10000.0, 30000.0]
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    fan_index = 1
    tol = 1.0e-3
    vavfan_caps.each do |cap|
      name = "sys6_vavfancap~#{cap}watts"
      puts "***************************************#{name}*******************************************************\n"
      model = BTAP::FileIO::load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
      standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                                   zones: model.getThermalZones,
                                                                                   heating_coil_type: heating_coil_type,
                                                                                   baseboard_type: baseboard_type,
                                                                                   chiller_type: chiller_type,
                                                                                   fan_type: vavfan_type,
                                                                                   hw_loop: hw_loop)
      # Save the model after btap hvac.
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
      vavfans = model.getFanVariableVolumes
      vavfans.each do |ifan|
        if ifan.name.to_s.include?('Supply')
          deltaP = 1000.0 # necb pressure rise for supply vav fans
        elsif ifan.name.to_s.include?('Return')
          deltaP = 250.0 # necb pressure rise for return vav fans
        end
        fan_eff = 0.65 # assumed fan mechanical efficiency
        flow_rate = cap * fan_eff / deltaP
        ifan.setMaximumFlowRate(flow_rate)
      end

            # Run the measure.
            run_the_measure(model: model, test_name: name) if PERFORM_STANDARDS

      vavfans = model.getFanVariableVolumes
      vavfans.each do |ifan|
        deltaP = ifan.pressureRise
        if ifan.name.to_s.include?('Supply')
          necb_deltaP = 1000.0 # necb pressure rise for supply vav fans
          necb_tot_eff = 0.55 # necb total fan efficiency for supply vav fans
        elsif ifan.name.to_s.include?('Return')
          necb_deltaP = 250.0 # necb pressure rise for return vav fans
          necb_tot_eff = 0.30 # necb total fan efficiency for return vav fans
        end
        diff = (deltaP - necb_deltaP).abs / necb_deltaP
        deltaP_set_properly = true
        if diff > tol then
          deltaP_set_properly = false
        end
        assert(deltaP_set_properly, "test_vavfan_rules: Variable fan pressure rise does not match necb requirement #{name}")
        tot_eff = ifan.fanEfficiency
        diff = (tot_eff - necb_tot_eff).abs / necb_tot_eff
        tot_eff_set_properly = true
        if diff > tol then
          tot_eff_set_properly = false
        end
        assert(tot_eff_set_properly, "test_vavfan_rules: Variable fan total efficiency does not match necb requirement #{name}")
      end
      # check enthalpy economizer
      airloops = model.getAirLoopHVACs
      airloops.each do |iloop|
        oa_sys = iloop.airLoopHVACOutdoorAirSystem.get
        oa_ctl = oa_sys.getControllerOutdoorAir
        econ_is_diff_enthalpy = true
        if oa_ctl.getEconomizerControlType.to_s != 'DifferentialEnthalpy' then
          econ_is_diff_enthalpy = false
        end
        assert(econ_is_diff_enthalpy, "test_vavfan_rules: Economizer control does not match necb requirement #{name}")
      end
      vav_fans = model.getFanVariableVolumes
      vavfan_res_file_output_text +=
          "#{vavfan_curve_names[fan_index - 1]},cubic,#{'%.5E' % vav_fans[0].fanPowerCoefficient1},#{'%.5E' % vav_fans[0].fanPowerCoefficient2}," +
              "#{'%.5E' % vav_fans[0].fanPowerCoefficient3},#{'%.5E' % vav_fans[0].fanPowerCoefficient4},#{'%.5E' % vav_fans[0].fanPowerMinimumFlowFraction},1.00000E+00\n"
      fan_index += 1
    end

    # Write actual results file
    test_result_file = File.join(@test_results_folder, 'compliance_vavfan_curves_test_results.csv')
    File.open(test_result_file, 'w') {|f| f.write(vavfan_res_file_output_text.chomp)}
    # Test that the values are correct by doing a file compare.
    expected_result_file = File.join(@expected_results_folder, 'compliance_vavfan_curves_expected_results.csv')

    # Check if test results match expected.
    msg = "Variable volume fan performance curve coeffs test results do not match what is expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end

  # Test to validate constant volume fan pressure rise and total efficiency
  def test_NECB2011_const_vol_fan_rules

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = "NECB2011"
    standard = get_standard(template)

    boiler_fueltype = 'NaturalGas'
    mau_type = true
    mau_heating_coil_type = 'Hot Water'
    baseboard_type = 'Hot Water'
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = 'sys1'
    puts "***************************************#{name}*******************************************************\n"
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
    standard.add_sys1_unitary_ac_baseboard_heating(model: model,
                                                            zones: model.getThermalZones,
                                                            mau_type: mau_type,
                                                            mau_heating_coil_type: mau_heating_coil_type,
                                                            baseboard_type: baseboard_type,
                                                            hw_loop: hw_loop)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")

            # Run the measure.
            run_the_measure(model: model, test_name: name) if PERFORM_STANDARDS

    fans = model.getFanConstantVolumes
    tol = 1.0e-3
    fans.each do |ifan|
      deltaP = ifan.pressureRise
      necb_deltaP = 640.0
      diff = (deltaP - necb_deltaP).abs / necb_deltaP
      deltaP_set_properly = true
      if diff > tol then
        deltaP_set_properly = false
      end
      assert(deltaP_set_properly, "test_const_vol_fan_rules: Fan pressure rise does not match necb requirement #{name}")
      necb_tot_eff = 0.4
      tot_eff = ifan.fanEfficiency
      diff = (tot_eff - necb_tot_eff).abs / necb_tot_eff
      tot_eff_set_properly = true
      if diff > tol then
        tot_eff_set_properly = false
      end
      assert(tot_eff_set_properly, "test_const_vol_fan_rules: Fan total efficiency does not match necb requirement #{name}")
    end
    airloops = model.getAirLoopHVACs
    airloops.each do |iloop|
      oa_sys = iloop.airLoopHVACOutdoorAirSystem.get
      oa_ctl = oa_sys.getControllerOutdoorAir
      econ_is_diff_enthalpy = true
      if oa_ctl.getEconomizerControlType.to_s != 'NoEconomizer' && oa_ctl.getEconomizerControlType.to_s != 'DifferentialEnthalpy' then
        econ_is_diff_enthalpy = false
      end
      assert(econ_is_diff_enthalpy, "test_vavfan_rules: Economizer control does not match necb requirement #{name}")
    end
  end

end

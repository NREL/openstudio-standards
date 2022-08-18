require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'

class NECB_HVAC_Heat_Pump_Tests < MiniTest::Test
  # set to true to run the standards in the test.
  PERFORM_STANDARDS = true
  # set to true to run the simulations.
  FULL_SIMULATIONS = false

  def setup()
    @file_folder = __dir__
    @test_folder = File.join(@file_folder, '..')
    @root_folder = File.join(@test_folder, '..')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = "#{@test_folder}/output/"
  end

  # Test to validate the heating efficiency generated against expected values stored in the file:
  # 'compliance_heatpump_efficiencies_expected_results.csv
  def test_heatpump_efficiency
    output_folder = File.join(@top_output_folder, __method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)

    #templates = ['NECB2011', 'NECB2015', 'NECB2020', 'BTAPPRE1980']
    templates = ['NECB2020']
    templates.each do |template|
      heatpump_expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_heatpump_efficiencies_expected_results.csv")
      standard = Standard.build(template)

      # Initialize hashes for storing expected heat pump efficiency data from file
      min_caps = []
      max_caps = []
      #efficiency_type = []

      # read the file for the expected unitary efficiency values for different heating types and equipment capacity ranges
      num_cap_intv = 0
      CSV.foreach(heatpump_expected_result_file, headers: true) do |data|
        min_caps << data['Min Capacity (kW)']
        max_caps << data['Max Capacity (kW)']

        num_cap_intv += 1
      end
      # Use the expected heat pump efficiency data to generate suitable equipment capacities for the test to cover all
      # the relevant equipment capacity ranges
      test_caps = []
      for i in 0..num_cap_intv - 2
        test_caps << 0.5 * ((min_caps[i]).to_f + (min_caps[i + 1]).to_f)
      end
      test_caps << (min_caps[num_cap_intv - 1].to_f + 10.0)

      # Generate the osm files for all relevant cases to generate the test data for system 3
      actual_heatpump_cop = []
      heatpump_res_file_output_text = "Min Capacity (kW),Max Capacity (kW),Test Capacity (kW),COP (no fan),COP-H\n"
      boiler_fueltype = 'Electricity'
      baseboard_type = 'Hot Water'
      heating_coil_type = 'DX'
      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      # save baseline
      BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
      test_caps.each do |cap|
        name = "#{template}_sys3_HtgDXCoilCap~#{cap}kW"
        puts "***************************************#{name}*******************************************************\n"
        model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
        standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                    zones: model.getThermalZones,
                                                                                                    heating_coil_type: heating_coil_type,
                                                                                                    baseboard_type: baseboard_type,
                                                                                                    hw_loop: hw_loop,
                                                                                                    new_auto_zoner: false)
        # Save the model after btap hvac.
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")

        dx_clg_coils = model.getCoilCoolingDXSingleSpeeds
        dx_clg_coils.each do |coil|
          coil.setRatedTotalCoolingCapacity(cap * 1000)
          flow_rate = cap * 1000 * 5.0e-5
          coil.setRatedAirFlowRate(flow_rate)
        end

        # run the standards
        result = self.run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
        actual_heatpump_cop << model.getCoilHeatingDXSingleSpeeds[0].ratedCOP.to_f
        # Save the model
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
        assert_equal(true, result, "test_heatpump_efficiency: Failure in Standards for #{name}")
      end

      # Generate table of test heat pump heating efficiencies
      output_line_text = ''
      for i in 0..num_cap_intv - 1
        # Convert from  COP  to COP_H for heat pump heating coils
        # COP from code is converted to remove fan heat gain following ASHRAE 90.1:2013 section 11.5.2.c
        # As the OpenStudio model has the COP (no fan), so it's converted back in the unit test to compare it to the code
        capacity_btu_per_hr = OpenStudio.convert(test_caps[i].to_f, 'kW', 'Btu/hr').get
        actual_heatpump_copH = actual_heatpump_cop[i] / (1.48E-7 * capacity_btu_per_hr + 1.062)
        output_line_text += "#{min_caps[i]},#{max_caps[i]},#{test_caps[i]},#{actual_heatpump_cop[i].round(1)},#{actual_heatpump_copH.round(1)}\n"
      end
      heatpump_res_file_output_text += output_line_text

      # Write actual results file
      test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_heatpump_efficiencies_test_results.csv")
      File.open(test_result_file, 'w') { |f| f.write(heatpump_res_file_output_text.chomp) }
      # Test that the values are correct by doing a file compare.
      expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_heatpump_efficiencies_expected_results.csv")
      b_result = FileUtils.compare_file(expected_result_file, test_result_file)
      assert(b_result,
             "test_heatpump_efficiency: Heat pump efficiency test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")

    end

  end

  # Test to validate the heat pump performance curves
  def test_heatpump_curves
    output_folder = File.join(@top_output_folder, __method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    template = 'NECB2011'
    standard = Standard.build(template)

    heatpump_expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_heatpump_curves_expected_results.csv")
    heatpump_curve_names = []
    CSV.foreach(heatpump_expected_result_file, headers: true) do |data|
      heatpump_curve_names << data['Curve Name']
    end
    # Generate the osm files for all relevant cases to generate the test data for system 3
    heatpump_res_file_output_text = "Curve Name,Curve Type,coeff1,coeff2,coeff3,coeff4,coeff5,coeff6,min_x,max_x\n"
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    heating_coil_type = 'DX'
    model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    name = "sys3"
    puts "***************************************#{name}*******************************************************\n"
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
    standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                zones: model.getThermalZones,
                                                                                                heating_coil_type: heating_coil_type,
                                                                                                baseboard_type: baseboard_type,
                                                                                                hw_loop: hw_loop,
                                                                                                new_auto_zoner: false)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
    # run the standards
    result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_heatpump_curves: Failure in Standards for #{name}")
    dx_units = model.getCoilHeatingDXSingleSpeeds
    heatpump_cap_ft_curve = dx_units[0].totalHeatingCapacityFunctionofTemperatureCurve.to_CurveCubic.get
    heatpump_res_file_output_text +=
      "#{heatpump_curve_names[0]},cubic,#{'%.5E' % heatpump_cap_ft_curve.coefficient1Constant},#{'%.5E' % heatpump_cap_ft_curve.coefficient2x}," +
        "#{'%.5E' % heatpump_cap_ft_curve.coefficient3xPOW2},#{'%.5E' % heatpump_cap_ft_curve.coefficient4xPOW3},#{'%.5E' % heatpump_cap_ft_curve.minimumValueofx}," +
        "#{'%.5E' % heatpump_cap_ft_curve.maximumValueofx}\n"
    heatpump_eir_ft_curve = dx_units[0].energyInputRatioFunctionofTemperatureCurve.to_CurveCubic.get
    heatpump_res_file_output_text +=
      "#{heatpump_curve_names[1]},cubic,#{'%.5E' % heatpump_eir_ft_curve.coefficient1Constant},#{'%.5E' % heatpump_eir_ft_curve.coefficient2x}," +
        "#{'%.5E' % heatpump_eir_ft_curve.coefficient3xPOW2},#{'%.5E' % heatpump_eir_ft_curve.coefficient4xPOW3},#{'%.5E' % heatpump_eir_ft_curve.minimumValueofx}," +
        "#{'%.5E' % heatpump_eir_ft_curve.maximumValueofx}\n"
    heatpump_cap_flow_curve = dx_units[0].totalHeatingCapacityFunctionofFlowFractionCurve.to_CurveCubic.get
    heatpump_res_file_output_text +=
      "#{heatpump_curve_names[2]},cubic,#{'%.5E' % heatpump_cap_flow_curve.coefficient1Constant},#{'%.5E' % heatpump_cap_flow_curve.coefficient2x}," +
        "#{'%.5E' % heatpump_cap_flow_curve.coefficient3xPOW2},#{'%.5E' % heatpump_cap_flow_curve.coefficient4xPOW3},#{'%.5E' % heatpump_cap_flow_curve.minimumValueofx}," +
        "#{'%.5E' % heatpump_cap_flow_curve.maximumValueofx}\n"
    heatpump_eir_flow_curve = dx_units[0].energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get
    heatpump_res_file_output_text +=
      "#{heatpump_curve_names[3]},quadratic,#{'%.5E' % heatpump_eir_flow_curve.coefficient1Constant},#{'%.5E' % heatpump_eir_flow_curve.coefficient2x}," +
        "#{'%.5E' % heatpump_eir_flow_curve.coefficient3xPOW2},#{'%.5E' % heatpump_eir_flow_curve.minimumValueofx},#{'%.5E' % heatpump_eir_flow_curve.maximumValueofx}\n"
    heatpump_plfvsplr__curve = dx_units[0].partLoadFractionCorrelationCurve.to_CurveCubic.get
    heatpump_res_file_output_text +=
      "#{heatpump_curve_names[4]},cubic,#{'%.5E' % heatpump_plfvsplr__curve.coefficient1Constant},#{'%.5E' % heatpump_plfvsplr__curve.coefficient2x}," +
        "#{'%.5E' % heatpump_plfvsplr__curve.coefficient3xPOW2},#{'%.5E' % heatpump_plfvsplr__curve.coefficient4xPOW3}," +
        "#{'%.5E' % heatpump_plfvsplr__curve.minimumValueofx},#{'%.5E' % heatpump_plfvsplr__curve.maximumValueofx}\n"

    # Write actual results file
    test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_heatpump_curves_test_results.csv")
    File.open(test_result_file, 'w') { |f| f.write(heatpump_res_file_output_text.chomp) }
    # Test that the values are correct by doing a file compare.
    expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_heatpump_curves_expected_results.csv")
    b_result = FileUtils.compare_file(expected_result_file, test_result_file)
    assert(b_result,
           "Heat pump performance curve coeffs test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")
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

      # BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/before.osm")

      # need to set prototype assumptions so that HRV added
      standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
      # Apply the HVAC efficiency standard
      standard.model_apply_hvac_efficiency_standard(model, climate_zone)

      # Find the minimum COP and rename with efficiency rating
      #cop = coil_heating_dx_single_speed_standard_minimum_cop(coil_heating_dx_single_speed, true)
      # BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/after.osm")

      return true
    end
  end
end

require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'


class NECB_HVAC_Tests < MiniTest::Test
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

  # Test to validate the cooling efficiency generated against expected values stored in the file:
  # 'compliance_unitary_efficiencies_expected_results.csv
  def test_NECB2011_unitary_efficiency
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)

    # Generate the osm files for all relevant cases to generate the test data for system 3
    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    unitary_heating_types = ['Electric Resistance', 'All Other']
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    templates = ['NECB2011', 'NECB2015', 'BTAPPRE1980'] #list of templates
    num_cap_intv = {'NECB2011' => 4, 'NECB2015' => 5, 'BTAPPRE1980' => 4}
    templates.each do |template|
      unitary_expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_unitary_efficiencies_expected_results.csv")
      standard = Standard.build(template)
      unitary_res_file_output_text = "Heating Type,Min Capacity (Btu per hr),Max Capacity (Btu per hr),Seasonal Energy Efficiency Ratio (SEER),Energy Efficiency Ratio (EER)\n"
      # Initialize hashes for storing expected unitary efficiency data from file
      heating_type_min_cap = {}
      heating_type_min_cap['Electric Resistance'] = []
      heating_type_min_cap['All Other'] = []
      heating_type_max_cap = {}
      heating_type_max_cap['Electric Resistance'] = []
      heating_type_max_cap['All Other'] = []
      efficiency_type = {}
      efficiency_type['Electric Resistance'] = []
      efficiency_type['All Other'] = []

      # read the file for the expected unitary efficiency values for different heating types and equipment capacity ranges
      CSV.foreach(unitary_expected_result_file, headers: true) do |data|
        heating_type_min_cap[data['Heating Type']] << data['Min Capacity (Btu per hr)']
        heating_type_max_cap[data['Heating Type']] << data['Max Capacity (Btu per hr)']
        if data['Seasonal Energy Efficiency Ratio (SEER)'].to_f > 0.0
          efficiency_type[data['Heating Type']] << 'Seasonal Energy Efficiency Ratio (SEER)'
        elsif data['Energy Efficiency Ratio (EER)'].to_f > 0.0
          efficiency_type[data['Heating Type']] << 'Energy Efficiency Ratio (EER)'
        end
      end

      # Use the expected unitary efficiency data to generate suitable equipment capacities for the test to cover all
      # the relevant equipment capacity ranges
      heating_type_cap = {}
      heating_type_min_cap.each do |heating_type, cap|
        unless heating_type_cap.key? heating_type then
          heating_type_cap[heating_type] = []
        end
        for i in 0..num_cap_intv[template] - 2
          heating_type_cap[heating_type] << 0.5 * (OpenStudio.convert(heating_type_min_cap[heating_type][i].to_f, 'Btu/hr', 'W').to_f + OpenStudio.convert(heating_type_min_cap[heating_type][i + 1].to_f, 'Btu/h', 'W').to_f)
        end
        heating_type_cap[heating_type] << (heating_type_min_cap[heating_type][num_cap_intv[template] - 1].to_f + 10000.0)
      end

      actual_unitary_cop = {}
      actual_unitary_cop['Electric Resistance'] = []
      actual_unitary_cop['All Other'] = []
      unitary_heating_types.each do |heating_type|
        if heating_type == 'Electric Resistance'
          heating_coil_type = 'Electric'
        elsif heating_type == 'All Other'
          heating_coil_type = 'Gas'
        end
        heating_type_cap[heating_type].each do |unitary_cap|
          name = "#{template}_sys3_MuaHtgCoilType~#{heating_coil_type}_UnitaryCap~#{unitary_cap}watts"
          puts "***************************************#{name}*******************************************************\n"
          model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
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
          model.getCoilCoolingDXSingleSpeeds.each do |dxcoil|
            dxcoil.setRatedTotalCoolingCapacity(unitary_cap)
            flow_rate = unitary_cap * 5.0e-5
            dxcoil.setRatedAirFlowRate(flow_rate)
          end
          # run the standards
          result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
          actual_unitary_cop[heating_type] << model.getCoilCoolingDXSingleSpeeds[0].ratedCOP.to_f
          # Save the model
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result, "test_unitary_efficiency: Failure in Standards for #{name}")
        end
      end

      # Generate table of test unitary efficiencies
      actual_unitary_eff = {}
      actual_unitary_eff['Electric Resistance'] = []
      actual_unitary_eff['All Other'] = []
      unitary_heating_types.each do |heating_type|
        output_line_text = ''
        for int in 0..heating_type_cap[heating_type].size - 1
          output_line_text += "#{heating_type},#{heating_type_min_cap[heating_type][int]},#{heating_type_max_cap[heating_type][int]},"
          if efficiency_type[heating_type][int] == 'Seasonal Energy Efficiency Ratio (SEER)'
            actual_unitary_eff[heating_type][int] = (standard.cop_to_seer(actual_unitary_cop[heating_type][int].to_f) + 0.001).round(2)
            output_line_text += "#{actual_unitary_eff[heating_type][int]},\n"
          elsif efficiency_type[heating_type][int] == 'Energy Efficiency Ratio (EER)'
            actual_unitary_eff[heating_type][int] = (standard.cop_to_eer(actual_unitary_cop[heating_type][int].to_f, heating_type_cap[heating_type][int]) + 0.001).round(2)
            output_line_text += ",#{actual_unitary_eff[heating_type][int]}\n"
          end
        end
        unitary_res_file_output_text += output_line_text
      end

      # Write actual results file
      test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_unitary_efficiencies_test_results.csv")
      File.open(test_result_file, 'w') {|f| f.write(unitary_res_file_output_text.chomp)}
      # Test that the values are correct by doing a file compare.
      expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_unitary_efficiencies_expected_results.csv")
      b_result = FileUtils.compare_file(expected_result_file, test_result_file)
      assert(b_result,
             "test_unitary_efficiency: Unitary efficiency test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")
    end
  end

  # Test to validate the unitary performance curves
  def test_NECB2011_unitary_curves
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    template = 'NECB2011'
    standard = Standard.build(template)

    unitary_expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_unitary_curves_expected_results.csv")
    unitary_curve_names = []
    CSV.foreach(unitary_expected_result_file, headers: true) do |data|
      unitary_curve_names << data['Curve Name']
    end
    # Generate the osm files for all relevant cases to generate the test data for system 2
    unitary_res_file_output_text = "Curve Name,Curve Type,coeff1,coeff2,coeff3,coeff4,coeff5,coeff6,min_x,max_x,min_y,max_y\n"
    boiler_fueltype = 'NaturalGas'
    chiller_type = 'Scroll'
    mua_cooling_type = 'DX'
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    template = 'NECB2011'
    name = "#{template.downcase}_sys2_CoolingType~#{mua_cooling_type}"
    puts "***************************************#{name}*******************************************************\n"
    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
    standard.add_sys2_FPFC_sys5_TPFC(model: model,
                                     zones: model.getThermalZones,
                                     chiller_type: chiller_type,
                                     fan_coil_type: 'FPFC',
                                     mau_cooling_type: mua_cooling_type,
                                     hw_loop: hw_loop)
    # Save the model after btap hvac.
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
    # run the standards
    result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_unitary_curves: Failure in Standards for #{name}")
    dx_units = model.getCoilCoolingDXSingleSpeeds
    unitary_cap_ft_curve = dx_units[0].totalCoolingCapacityFunctionOfTemperatureCurve.to_CurveBiquadratic.get
    unitary_res_file_output_text +=
        "#{unitary_curve_names[0]},biquadratic,#{'%.5E' % unitary_cap_ft_curve.coefficient1Constant},#{'%.5E' % unitary_cap_ft_curve.coefficient2x}," +
            "#{'%.5E' % unitary_cap_ft_curve.coefficient3xPOW2},#{'%.5E' % unitary_cap_ft_curve.coefficient4y},#{'%.5E' % unitary_cap_ft_curve.coefficient5yPOW2}," +
            "#{'%.5E' % unitary_cap_ft_curve.coefficient6xTIMESY},#{'%.5E' % unitary_cap_ft_curve.minimumValueofx},#{'%.5E' % unitary_cap_ft_curve.maximumValueofx}," +
            "#{'%.5E' % unitary_cap_ft_curve.minimumValueofy},#{'%.5E' % unitary_cap_ft_curve.maximumValueofy}\n"
    unitary_eir_ft_curve = dx_units[0].energyInputRatioFunctionOfTemperatureCurve.to_CurveBiquadratic.get
    unitary_res_file_output_text +=
        "#{unitary_curve_names[1]},biquadratic,#{'%.5E' % unitary_eir_ft_curve.coefficient1Constant},#{'%.5E' % unitary_eir_ft_curve.coefficient2x}," +
            "#{'%.5E' % unitary_eir_ft_curve.coefficient3xPOW2},#{'%.5E' % unitary_eir_ft_curve.coefficient4y},#{'%.5E' % unitary_eir_ft_curve.coefficient5yPOW2}," +
            "#{'%.5E' % unitary_eir_ft_curve.coefficient6xTIMESY},#{'%.5E' % unitary_eir_ft_curve.minimumValueofx},#{'%.5E' % unitary_eir_ft_curve.maximumValueofx}," +
            "#{'%.5E' % unitary_eir_ft_curve.minimumValueofy},#{'%.5E' % unitary_eir_ft_curve.maximumValueofy}\n"
    unitary_cap_flow_curve = dx_units[0].totalCoolingCapacityFunctionOfFlowFractionCurve.to_CurveQuadratic.get
    unitary_res_file_output_text +=
        "#{unitary_curve_names[2]},quadratic,#{'%.5E' % unitary_cap_flow_curve.coefficient1Constant},#{'%.5E' % unitary_cap_flow_curve.coefficient2x}," +
            "#{'%.5E' % unitary_cap_flow_curve.coefficient3xPOW2},#{'%.5E' % unitary_cap_flow_curve.minimumValueofx},#{'%.5E' % unitary_cap_flow_curve.maximumValueofx}\n"
    unitary_eir_flow_curve = dx_units[0].energyInputRatioFunctionOfFlowFractionCurve.to_CurveQuadratic.get
    unitary_res_file_output_text +=
        "#{unitary_curve_names[3]},quadratic,#{'%.5E' % unitary_eir_flow_curve.coefficient1Constant},#{'%.5E' % unitary_eir_flow_curve.coefficient2x}," +
            "#{'%.5E' % unitary_eir_flow_curve.coefficient3xPOW2},#{'%.5E' % unitary_eir_flow_curve.minimumValueofx},#{'%.5E' % unitary_eir_flow_curve.maximumValueofx}\n"
    unitary_plfvsplr__curve = dx_units[0].partLoadFractionCorrelationCurve.to_CurveCubic.get
    unitary_res_file_output_text +=
        "#{unitary_curve_names[4]},cubic,#{'%.5E' % unitary_plfvsplr__curve.coefficient1Constant},#{'%.5E' % unitary_plfvsplr__curve.coefficient2x}," +
            "#{'%.5E' % unitary_plfvsplr__curve.coefficient3xPOW2},#{'%.5E' % unitary_plfvsplr__curve.coefficient4xPOW3}," +
            "#{'%.5E' % unitary_plfvsplr__curve.minimumValueofx},#{'%.5E' % unitary_plfvsplr__curve.maximumValueofx}\n"

    # Write actual results file
    test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_unitary_curves_test_results.csv")
    File.open(test_result_file, 'w') {|f| f.write(unitary_res_file_output_text.chomp)}
    # Test that the values are correct by doing a file compare.
    expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_unitary_curves_expected_results.csv")
    b_result = FileUtils.compare_file(expected_result_file, test_result_file)
    assert(b_result,
           "Unitary performance curve coeffs test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")
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

      BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/before.osm")

      # need to set prototype assumptions so that HRV added
      standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)
      # Apply the HVAC efficiency standard
      standard.model_apply_hvac_efficiency_standard(model, climate_zone)
      # self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}

      BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/after.osm")

      return true
    end
  end
end

require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'


class ECM_HS14_CGSHP_FanCoils_Tests < MiniTest::Test
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

  # Test to validate the unitary performance curves for water to water heat pumps
  def test_ecm_hs14_cgshp_curves
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    template = 'NECB2017'
    standard = Standard.build(template)
    expected_result_file = File.join(@expected_results_folder, "ecm_hs14_cgshp_fancoils_curves_expected_results.csv")
    curve_names = []
    CSV.foreach(expected_result_file, headers: true) do |data|
      curve_names << data['Curve Name']
    end
    # Generate the osm files for all relevant cases to generate the test data for system 2
    res_file_output_text = "Curve Name,Curve Type,coeff1,coeff2,coeff3,coeff4,coeff5,min_w,max_w,min_x,max_x,min_y,max_y,min_z,max_z,min_output,max_output\n"
    # Generate osm file
    epw_file = 'CAN_QC_Montreal-Trudeau.Intl.AP.716270_CWEC2016.epw'
    model =standard.model_create_prototype_model(building_type: 'QuickServiceRestaurant',
                                          epw_file: epw_file,
                                          template: 'NECB2017',
                                          sizing_run_dir: output_folder,
                                          ecm_system_name: 'hs14_cgshp_fancoils')
    wshpc_units = model.getHeatPumpWaterToWaterEquationFitHeatings
    cap_curve = wshpc_units[0].heatingCapacityCurve.to_CurveQuadLinear.get
    res_file_output_text +=
        "#{curve_names[0]},quadlinear,#{'%.5E' % cap_curve.coefficient1Constant},#{'%.5E' % cap_curve.coefficient2w},#{'%.5E' % cap_curve.coefficient3x}," + 
        "#{'%.5E' % cap_curve.coefficient4y},#{'%.5E' % cap_curve.coefficient5z},#{'%.5E' % cap_curve.minimumValueofw},#{'%.5E' % cap_curve.maximumValueofw}," + 
        "#{'%.5E' % cap_curve.minimumValueofx},#{'%.5E' % cap_curve.maximumValueofx},#{'%.5E' % cap_curve.minimumValueofy},#{'%.5E' % cap_curve.maximumValueofy}," +
        "#{'%.5E' % cap_curve.minimumValueofz},#{'%.5E' % cap_curve.maximumValueofz},#{'%.5E' % cap_curve.minimumCurveOutput},#{'%.5E' % cap_curve.maximumCurveOutput}\n"

    power_curve = wshpc_units[0].heatingCompressorPowerCurve.to_CurveQuadLinear.get
    res_file_output_text +=
        "#{curve_names[1]},quadlinear,#{'%.5E' % power_curve.coefficient1Constant},#{'%.5E' % power_curve.coefficient2w},#{'%.5E' % power_curve.coefficient3x}," +
        "#{'%.5E' % power_curve.coefficient4y},#{'%.5E' % power_curve.coefficient5z},#{'%.5E' % power_curve.minimumValueofw},#{'%.5E' % power_curve.maximumValueofw}," +
        "#{'%.5E' % power_curve.minimumValueofx},#{'%.5E' % power_curve.maximumValueofx},#{'%.5E' % power_curve.minimumValueofy},#{'%.5E' % power_curve.maximumValueofy}," +
        "#{'%.5E' % power_curve.minimumValueofz},#{'%.5E' % power_curve.maximumValueofz},#{'%.5E' % power_curve.minimumCurveOutput},#{'%.5E' % power_curve.maximumCurveOutput}\n"

    # Write actual results file
    test_result_file = File.join(@test_results_folder, "ecm_hs14_cgshp_fancoils_curves_test_results.csv")
    File.open(test_result_file, 'w') {|f| f.write(res_file_output_text)}
    # Test that the values are correct by doing a file compare.
    b_result = FileUtils.compare_file(expected_result_file, test_result_file)
    assert(b_result,
           "Heat Pump cooling performance curve coeffs test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")
  end

end

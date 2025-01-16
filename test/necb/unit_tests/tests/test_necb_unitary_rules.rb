require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Unitary_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate the cooling efficiency generated against expected values stored in the file:
  # 'compliance_unitary_efficiencies_expected_results.csv.
  def test_unitary_efficiency

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 3.
    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    unitary_heating_types = ['Electric Resistance', 'All Other']
    templates = ['NECB2011', 'NECB2015', 'NECB2020', 'BTAPPRE1980'] # list of templates
    num_cap_intv = {'NECB2011' => 4, 'NECB2015' => 5, 'NECB2020' => 5, 'BTAPPRE1980' => 4}  # number of capacity or outdoor air flow intervals for each template
    speeds = ['single','multi']
    outdoor_air_per_flr_area = {'NECB2011' => [0.001,0.004,0.016,0.064],
                                'NECB2015' => [0.001,0.002,0.006,0.016,0.064],
                                'NECB2020' => [0.001,0.002,0.006,0.016,0.064],
                                'BTAPPRE1980' => [0.001,0.004,0.016,0.064]}  # outdoor air flow in m3/s per flow area

    templates.each do |template|
      unitary_expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_unitary_efficiencies_expected_results.csv")
      standard = get_standard(template)
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
      # This approach is used for 'single' speed runs. For multi speed the outdoor air lists are used instead.
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
      speeds.each do |speed|
        actual_unitary_cop = {}
        actual_unitary_cop['Electric Resistance'] = []
        actual_unitary_cop['All Other'] = []
        unitary_heating_types.each do |heating_type|
          if heating_type == 'Electric Resistance'
            heating_coil_type = 'Electric'
          elsif heating_type == 'All Other'
            heating_coil_type = 'Gas'
          end
          index = 0
          heating_type_cap[heating_type].each do |unitary_cap|
            # For single speed the capacity used in the name is the exact capacity of the dx coil in the model
            # For multi speed the capacity of the coil (with name including Speed 1) is different from the capacity 
            # 'unitary_cap' used in the name, but it is in the same efficiency capacity interval as 'unitary_cap'.
            name = "#{template}_sys3_MuaHtgCoilType-#{heating_coil_type}_Speed-#{speed}_UnitaryCap-#{unitary_cap}watts"
            name.gsub!(/\s+/, "-")
            puts "***************#{name}***************\n"

            # Load model and set climate file.
            model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
            weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
            OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
            BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

            hw_loop = OpenStudio::Model::PlantLoop.new(model)
            always_on = model.alwaysOnDiscreteSchedule
            standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, boiler_fueltype, always_on)
            case speed
            when 'single'
              # For single speed use the capacity 'unitary_cap' directly to set the capacity of the dx coils
              standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                      zones: model.getThermalZones,
                                                                                                      heating_coil_type: heating_coil_type,
                                                                                                      baseboard_type: baseboard_type,
                                                                                                      hw_loop: hw_loop,
                                                                                                      new_auto_zoner: false)
              model.getCoilCoolingDXSingleSpeeds.each do |dxcoil|
                dxcoil.setRatedTotalCoolingCapacity(unitary_cap)
                flow_rate = unitary_cap * 5.0e-5
                dxcoil.setRatedAirFlowRate(flow_rate)
              end
            when 'multi'
              # For multi speed use the outdoor air values (m3/s/m2) to set the outdoor air requirement of the airloops.
              # Using the outdoor air flow rate for the the same list index as the capacity 'unitary_cap' generates a 
              # capacity for the dx coil (with the name that includes 'Speed 1') that's in the desired effiency capacity 
              # interval as the capacity 'unitary_cap' of the loop.  
              standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed(model: model,
                                                                                                          zones: model.getThermalZones,
                                                                                                          heating_coil_type: heating_coil_type,
                                                                                                          baseboard_type: baseboard_type,
                                                                                                          hw_loop: hw_loop,
                                                                                                          new_auto_zoner: false)
              model.getDesignSpecificationOutdoorAirs.sort.each do |oa_sp|
                oa_sp.setOutdoorAirFlowperFloorArea(outdoor_air_per_flr_area[template][index])
              end
            end

            # Save the model after btap hvac.
            BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")

            # Run the measure.
            run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

            case speed
            when 'single'
              actual_unitary_cop[heating_type] << model.getCoilCoolingDXSingleSpeeds[0].ratedCOP.to_f
            when 'multi'
              # In this case the dx coil with the name including 'Speed 1' is the one with appropriate capacity for this test
              dx_unit = model.getCoilCoolingDXMultiSpeeds.select {|unit| unit.name.to_s.include? 'Speed 1'}[0]
              actual_unitary_cop[heating_type] << dx_unit.stages.last.grossRatedCoolingCOP.to_f
            end

            index += 1
          end
        end

        # Generate table of test unitary efficiencies.
        actual_unitary_eff = {}
        actual_unitary_eff['Electric Resistance'] = []
        actual_unitary_eff['All Other'] = []
        unitary_heating_types.each do |heating_type|
          output_line_text = ''
          for int in 0..heating_type_cap[heating_type].size - 1
            output_line_text += "#{heating_type},#{heating_type_min_cap[heating_type][int]},#{heating_type_max_cap[heating_type][int]},"
            if efficiency_type[heating_type][int] == 'Seasonal Energy Efficiency Ratio (SEER)'
              actual_unitary_eff[heating_type][int] = (standard.cop_no_fan_to_seer(actual_unitary_cop[heating_type][int].to_f) + 0.001).round(2)
              output_line_text += "#{actual_unitary_eff[heating_type][int]},\n"
            elsif efficiency_type[heating_type][int] == 'Energy Efficiency Ratio (EER)'
              actual_unitary_eff[heating_type][int] = (standard.cop_no_fan_to_eer(actual_unitary_cop[heating_type][int].to_f) + 0.001).round(2)
              output_line_text += ",#{actual_unitary_eff[heating_type][int]}\n"
            end
          end
          unitary_res_file_output_text += output_line_text
        end

        # Write test results file.
        test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_unitary_efficiencies_test_results.csv")
        File.open(test_result_file, 'w') {|f| f.write(unitary_res_file_output_text.chomp)}

        # Test that the values are correct by doing a file compare.
        expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_unitary_efficiencies_expected_results.csv")

        # Check if test results match expected.
        msg = "Unitary efficiency test results do not match what is expected in test"
        file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
      end
    end
  end

  # Test to validate the unitary performance curves
  def test_NECB2011_unitary_curves

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template='NECB2011'
    standard = get_standard(template)
    save_intermediate_models = false

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

    name = "#{template.downcase}_sys2_CoolingType-#{mua_cooling_type}"
    name.gsub!(/\s+/, "-")
    puts "***************#{name}***************\n"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
    weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
    OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, boiler_fueltype, always_on)
    standard.add_sys2_FPFC_sys5_TPFC(model: model,
                                     zones: model.getThermalZones,
                                     chiller_type: chiller_type,
                                     fan_coil_type: 'FPFC',
                                     mau_cooling_type: mua_cooling_type,
                                     hw_loop: hw_loop)

    # Run sizing.
    run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

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

    # Write test results file.
    test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_unitary_curves_test_results.csv")
    File.open(test_result_file, 'w') {|f| f.write(unitary_res_file_output_text.chomp)}

    # Test that the values are correct by doing a file compare.
    expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_unitary_curves_expected_results.csv")

    # Check if test results match expected.
    msg = "Unitary performance curve coeffs test results do not match what is expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end

end

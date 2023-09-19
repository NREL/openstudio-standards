require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_HVAC_Chiller_Test < MiniTest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate the chiller COP generated against expected values stored in the file:
  # 'compliance_chiller_cop_expected_results.csv
  def test_chiller_cop

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)

    expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_chiller_cop_expected_results.csv")

    # Initialize hashes for storing expected chiller cop data from file.
    chiller_type_min_cap = {}
    chiller_type_min_cap['Rotary Screw'] = []
    chiller_type_min_cap['Reciprocating'] = []
    chiller_type_min_cap['Scroll'] = []
    chiller_type_min_cap['Centrifugal'] = []
    chiller_type_max_cap = {}
    chiller_type_max_cap['Rotary Screw'] = []
    chiller_type_max_cap['Reciprocating'] = []
    chiller_type_max_cap['Scroll'] = []
    chiller_type_max_cap['Centrifugal'] = []

    # Read the file for the cutoff min and max capacities for various chiller types.
    CSV.foreach(expected_result_file, headers: true) do |data|
      chiller_type_min_cap[data['Type']] << data['Min Capacity (Btu per hr)']
      chiller_type_max_cap[data['Type']] << data['Max Capacity (Btu per hr)']
    end

    # Use the expected chiller cop data to generate suitable equipment capacities for the test to cover all
    # the relevant equipment capacity ranges.
    # This implementation assumed a max of 3 capacity intervals for chillers where in reality only one range is needed
    # for NECB2011.
    chiller_type_cap = {}
    chiller_type_cap['Rotary Screw'] = []
    chiller_type_cap['Reciprocating'] = []
    chiller_type_cap['Scroll'] = []
    chiller_type_cap['Centrifugal'] = []
    chiller_type_min_cap.each do |type, min_caps|
      if min_caps.size == 1
        chiller_type_cap[type] << 10000.0
      else
        chiller_type_cap[type] << 0.5 * (OpenStudio.convert(chiller_type_min_cap[type][0].to_f, 'Btu/hr', 'W').to_f + OpenStudio.convert(chiller_type_min_cap[type][1].to_f, 'Btu/h', 'W').to_f)
        if min_caps.size == 2
          chiller_type_cap[type] << (OpenStudio.convert(chiller_type_min_cap[type][1].to_f, 'Btu/hr', 'W').to_f + 10000.0)
        else
          chiller_type_cap[type] << 0.5 * (OpenStudio.convert(chiller_type_min_cap[type][1].to_f, 'Btu/hr', 'W').to_f + OpenStudio.convert(chiller_type_min_cap[type][2].to_f, 'Btu/hr', 'W').to_f)
          if min_caps.size == 3
            chiller_type_cap[type] << (OpenStudio.convert(chiller_type_min_cap[type][2].to_f, 'Btu/hr', 'W').to_f + 10000.0)
          else
            chiller_type_cap[type] << 0.5 * (OpenStudio.convert(chiller_type_min_cap[type][2].to_f, 'Btu/hr', 'W').to_f + OpenStudio.convert(chiller_type_min_cap[type][3].to_f, 'Btu/hr', 'W').to_f)
            chiller_type_cap[type] << (OpenStudio.convert(chiller_type_min_cap[type][3].to_f, 'Btu/hr', 'W').to_f + 10000.0)
          end
        end
      end
    end

    # Generate the osm files for all relevant cases to generate the test data for system 2.
    actual_chiller_cop = {}
    actual_chiller_cop['Rotary Screw'] = []
    actual_chiller_cop['Reciprocating'] = []
    actual_chiller_cop['Scroll'] = []
    actual_chiller_cop['Centrifugal'] = []
    chiller_res_file_output_text = "Type,Min Capacity (Btu per hr),Max Capacity (Btu per hr),COP\n"
    boiler_fueltype = 'Electricity'
    chiller_types = ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating']
    mua_cooling_type = 'Hydronic'
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    
    # Save baseline.
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    chiller_types.each do |chiller_type|
      chiller_type_cap[chiller_type].each do |chiller_cap|
        name = "sys2_ChillerType~#{chiller_type}_Chiller_cap~#{chiller_cap}watts"
        puts "***************#{name}***************\n"
        model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
        BTAP::Environment::WeatherFile.new("CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw").set_weather_file(model)
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
        model.getChillerElectricEIRs.each {|ichiller| ichiller.setReferenceCapacity(chiller_cap)}
        
        # Run the standards.
        run_the_measure(model: model, test_name: name, template: template) if PERFORM_STANDARDS

        model.getChillerElectricEIRs.each do |ichiller|
          if ichiller.referenceCapacity.to_f > 1
            actual_chiller_cop[chiller_type] << ichiller.referenceCOP.round(3)
            break
          end
        end
      end

      # Write actual results file.
      #test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_chiller_cop_test_results.csv")
      #File.open(test_result_file, 'w') { |f| f.write(chiller_res_file_output_text.chomp) }
      
      # Test that the values are correct by doing a file compare.
      #expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_chiller_cop_expected_results.csv")

      # Check if test results match expected.
      #msg = "Chiller COP test results do not match expected in test"
      #file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
    end

    # Generate table of test chiller cop.
    chiller_types.each do |type|
      for int in 0..chiller_type_cap[type].size - 1
        output_line_text = "#{type},#{chiller_type_min_cap[type][int]},#{chiller_type_max_cap[type][int]},#{actual_chiller_cop[type][int]}\n"
        chiller_res_file_output_text += output_line_text
      end
    end

    # Write actual results file.
    test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_chiller_cop_test_results.csv")
    File.open(test_result_file, 'w') {|f| f.write(chiller_res_file_output_text.chomp)}

    # Check if test results match expected.
    msg = "Chiller COP test results do not match what is expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end

  # Test to validate the number of chillers used and their capacities depending on total cooling capacity. 
  # NECB2011 rule for number of chillers is:
  # "if capacity <= 2100 kW ---> one chiller
  # if capacity > 2100 kW ---> 2 chillers with half the capacity each"
  def test_number_of_chillers

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)

    first_cutoff_chlr_cap = 2100000.0
    tol = 1.0e-3

    # Generate the osm files for all relevant cases to generate the test data for system 6.
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating']
    heating_coil_type = 'Hot Water'
    fan_type = 'AF_or_BI_rdg_fancurve'
    test_chiller_cap = [1000000.0, 3000000.0]
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    
    # Save baseline.
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    chiller_types.each do |chiller_type|
      test_chiller_cap.each do |chiller_cap|
        name = "sys6_ChillerType_#{chiller_type}~Chiller_cap~#{chiller_cap}watts"
        puts "***************#{name}***************\n"
        model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
        standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                            zones: model.getThermalZones,
                                                                            heating_coil_type: heating_coil_type,
                                                                            baseboard_type: baseboard_type,
                                                                            chiller_type: chiller_type,
                                                                            fan_type: fan_type,
                                                                            hw_loop: hw_loop)
        
        # Save the model after btap hvac.
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
        model.getChillerElectricEIRs.each {|ichiller| ichiller.setReferenceCapacity(chiller_cap)}

        # Run the standards.
        run_the_measure(model: model, test_name: name, template: template) if PERFORM_STANDARDS

        chillers = model.getChillerElectricEIRs
        
        # Check that there are two chillers in the model.
        num_of_chillers_is_correct = false
        if chillers.size == 2 then
          num_of_chillers_is_correct = true
        end
        assert(num_of_chillers_is_correct, 'Number of chillers is not 2 in test #{self.class}.')
        this_is_the_first_cap_range = false
        this_is_the_second_cap_range = false
        if chiller_cap < first_cutoff_chlr_cap
          this_is_the_first_cap_range = true
        else
          this_is_the_second_cap_range = true
        end
        
        # Compare chiller capacities to expected values.
        chillers.each do |ichiller|
          if ichiller.name.to_s.include? 'Primary Chiller'
            chiller_cap_is_correct = false
            if this_is_the_first_cap_range
              cap_diff = (chiller_cap - ichiller.referenceCapacity.to_f).abs / chiller_cap
            elsif this_is_the_second_cap_range
              cap_diff = (0.5 * chiller_cap - ichiller.referenceCapacity.to_f).abs / (0.5 * chiller_cap)
            end
            if cap_diff < tol then
              chiller_cap_is_correct = true
            end
            assert(chiller_cap_is_correct, 'Primary chiller capacity is not correct in test #{self.class}.')
          end
          if ichiller.name.to_s.include? 'Secondary Chiller'
            chiller_cap_is_correct = false
            if this_is_the_first_cap_range
              cap_diff = (ichiller.referenceCapacity.to_f - 0.001).abs
            elsif this_is_the_second_cap_range
              cap_diff = (0.5 * chiller_cap - ichiller.referenceCapacity.to_f).abs / (0.5 * chiller_cap)
            end
            if cap_diff < tol then
              chiller_cap_is_correct = true
            end
            assert(chiller_cap_is_correct, 'Secondary chiller capacity is not correct in test #{self.class}.')
          end
        end
      end
    end
  end

  # Test to validate the chiller performance curves
  def test_chiller_curves
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)

    expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_chiller_curves_expected_results.csv")
    chiller_curve_names = {}
    chiller_curve_names['Scroll'] = []
    chiller_curve_names['Reciprocating'] = []
    chiller_curve_names['Rotary Screw'] = []
    chiller_curve_names['Centrifugal'] = []
    CSV.foreach(expected_result_file, headers: true) do |data|
      chiller_curve_names[data['Chiller Type']] << data['Curve Name']
    end
    # Generate the osm files for all relevant cases to generate the test data for system 5
    chiller_res_file_output_text = "Chiller Type,Curve Name,Curve Type,coeff1,coeff2,coeff3,coeff4,coeff5,coeff6,min_x,max_x,min_y,max_y\n"
    boiler_fueltype = 'NaturalGas'
    chiller_types = ['Scroll', 'Reciprocating', 'Rotary Screw', 'Centrifugal']
    mua_cooling_type = 'Hydronic'
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
    chiller_types.each do |chiller_type|
      name = "sys5_ChillerType_#{chiller_type}"
      puts "***************#{name}***************\n"
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
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

      # Run the standards.
      run_the_measure(model: model, test_name: name, template: template) if PERFORM_STANDARDS

      chillers = model.getChillerElectricEIRs
      chiller_cap_ft_curve = chillers[0].coolingCapacityFunctionOfTemperature
      chiller_res_file_output_text +=
          "#{chiller_type},#{chiller_curve_names[chiller_type][0]},biquadratic,#{'%.5E' % chiller_cap_ft_curve.coefficient1Constant},#{'%.5E' % chiller_cap_ft_curve.coefficient2x}," +
              "#{'%.5E' % chiller_cap_ft_curve.coefficient3xPOW2},#{'%.5E' % chiller_cap_ft_curve.coefficient4y},#{'%.5E' % chiller_cap_ft_curve.coefficient5yPOW2}," +
              "#{'%.5E' % chiller_cap_ft_curve.coefficient6xTIMESY},#{'%.5E' % chiller_cap_ft_curve.minimumValueofx},#{'%.5E' % chiller_cap_ft_curve.maximumValueofx}," +
              "#{'%.5E' % chiller_cap_ft_curve.minimumValueofy},#{'%.5E' % chiller_cap_ft_curve.maximumValueofy}\n"
      chiller_eir_ft_curve = chillers[0].electricInputToCoolingOutputRatioFunctionOfTemperature
      chiller_res_file_output_text +=
          "#{chiller_type},#{chiller_curve_names[chiller_type][1]},biquadratic,#{'%.5E' % chiller_eir_ft_curve.coefficient1Constant},#{'%.5E' % chiller_eir_ft_curve.coefficient2x}," +
              "#{'%.5E' % chiller_eir_ft_curve.coefficient3xPOW2},#{'%.5E' % chiller_eir_ft_curve.coefficient4y},#{'%.5E' % chiller_eir_ft_curve.coefficient5yPOW2}," +
              "#{'%.5E' % chiller_eir_ft_curve.coefficient6xTIMESY},#{'%.5E' % chiller_eir_ft_curve.minimumValueofx},#{'%.5E' % chiller_eir_ft_curve.maximumValueofx}," +
              "#{'%.5E' % chiller_eir_ft_curve.minimumValueofy},#{'%.5E' % chiller_eir_ft_curve.maximumValueofy}\n"
      chiller_eir_plr_curve = chillers[0].electricInputToCoolingOutputRatioFunctionOfPLR
      chiller_res_file_output_text +=
          "#{chiller_type},#{chiller_curve_names[chiller_type][2]},quadratic,#{'%.5E' % chiller_eir_plr_curve.coefficient1Constant},#{'%.5E' % chiller_eir_plr_curve.coefficient2x}," +
              "#{'%.5E' % chiller_eir_plr_curve.coefficient3xPOW2},#{'%.5E' % chiller_eir_plr_curve.minimumValueofx},#{'%.5E' % chiller_eir_plr_curve.maximumValueofx}\n"
    end

    # Write actual results file.
    test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_chiller_curves_test_results.csv")
    File.open(test_result_file, 'w') {|f| f.write(chiller_res_file_output_text.chomp)}

    # Check if test results match expected.
    msg = "Chiller performance curve coeffs test results do not match expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end
end

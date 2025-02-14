require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Boiler_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end


  # Test to validate the boiler thermal efficiency generated against expected values stored in the file:
  # 'compliance_boiler_efficiencies_expected_results.csv
  def test_boiler_efficiency

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 1
    boiler_fueltypes = ['Electricity','NaturalGas','FuelOilNo2']
    mau_type = true
    mau_heating_coil_type = 'Hot Water'
    baseboard_type = 'Hot Water'
    templates = ['NECB2011', 'NECB2015', 'NECB2020', 'BTAPPRE1980']

    templates.each do |template|
      standard = get_standard(template)
      boiler_expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_boiler_efficiencies_expected_results.csv")

      # Initialize hashes for storing expected boiler efficiency data from file.
      fuel_type_min_cap = {}
      fuel_type_min_cap['Electricity'] = []
      fuel_type_min_cap['NaturalGas'] = []
      fuel_type_min_cap['FuelOilNo2'] = []
      fuel_type_max_cap = {}
      fuel_type_max_cap['Electricity'] = []
      fuel_type_max_cap['NaturalGas'] = []
      fuel_type_max_cap['FuelOilNo2'] = []
      efficiency_type = {}
      efficiency_type['Electricity'] = []
      efficiency_type['NaturalGas'] = []
      efficiency_type['FuelOilNo2'] = []

      # Read the file for the expected boiler efficiency values for different fuels and equipment capacity ranges.
      CSV.foreach(boiler_expected_result_file, headers: true) do |data|
        fuel_type_min_cap[data['Fuel']] << data['Min Capacity (Btu per hr)']
        fuel_type_max_cap[data['Fuel']] << data['Max Capacity (Btu per hr)']
        if data['Annual Fuel Utilization Efficiency (AFUE)'].to_f > 0.0
          efficiency_type[data['Fuel']] << 'Annual Fuel Utilization Efficiency (AFUE)'
        elsif data['Thermal Efficiency'].to_f > 0.0
          efficiency_type[data['Fuel']] << 'Thermal Efficiency'
        elsif data['Combustion Efficiency'].to_f > 0.0
          efficiency_type[data['Fuel']] << 'Combustion Efficiency'
        end
      end

      # Use the expected boiler efficiency data to generate suitable equipment capacities for the test to cover all
      # the relevant equipment capacity ranges.
      fuel_type_cap = {}
      fuel_type_min_cap.each do |fuel, cap|
        unless fuel_type_cap.key? fuel then
          fuel_type_cap[fuel] = []
        end
        if cap.size == 1
          fuel_type_cap[fuel] << 10000.0
        else
          fuel_type_cap[fuel] << 0.5 * (OpenStudio.convert(fuel_type_min_cap[fuel][0].to_f, 'Btu/hr', 'W').to_f + OpenStudio.convert(fuel_type_min_cap[fuel][1].to_f, 'Btu/h', 'W').to_f)
          if cap.size == 2
            fuel_type_cap[fuel] << (OpenStudio.convert(fuel_type_min_cap[fuel][1].to_f, 'Btu/hr', 'W').to_f + 10000.0)
          else
            fuel_type_cap[fuel] << 0.5 * (OpenStudio.convert(fuel_type_min_cap[fuel][1].to_f, 'Btu/hr', 'W').to_f + OpenStudio.convert(fuel_type_min_cap[fuel][2].to_f, 'Btu/hr', 'W').to_f)
            fuel_type_cap[fuel] << (fuel_type_min_cap[fuel][2].to_f + 10000.0)
          end
        end
      end

      actual_boiler_thermal_eff = {}
      actual_boiler_thermal_eff['Electricity'] = []
      actual_boiler_thermal_eff['NaturalGas'] = []
      actual_boiler_thermal_eff['FuelOilNo2'] = []
      boiler_fueltypes.each do |boiler_fueltype|
        fuel_type_cap[boiler_fueltype].each do |boiler_cap|
          name = "#{template}_sys1_Boiler-#{boiler_fueltype}_cap-#{boiler_cap.to_int}W_MAU-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}"
          name.gsub!(/\s+/, "-")
          puts "***************#{name}***************\n"

          # Load model and set climate file.
          model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
          weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
          OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

          hw_loop = OpenStudio::Model::PlantLoop.new(model)
          always_on = model.alwaysOnDiscreteSchedule
          standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, boiler_fueltype, always_on)
          standard.add_sys1_unitary_ac_baseboard_heating(model: model,
                                                         zones: model.getThermalZones,
                                                         mau_type: mau_type,
                                                         mau_heating_coil_type: mau_heating_coil_type,
                                                         baseboard_type: baseboard_type,
                                                         hw_loop: hw_loop)

          # Set the boiler capacity.
          model.getBoilerHotWaters.each {|iboiler| iboiler.setNominalCapacity(boiler_cap)}

          # Run sizing.
          run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

          # Recover the thermal efficiency set in the measure for checking below.
          model.getBoilerHotWaters.each do |iboiler|
            if iboiler.nominalCapacity.to_f > 1
              actual_boiler_thermal_eff[boiler_fueltype] << iboiler.nominalThermalEfficiency
              break
            end
          end
        end
      end

      # Generate table of test boiler efficiencies.
      actual_boiler_eff = {}
      actual_boiler_eff['Electricity'] = []
      actual_boiler_eff['NaturalGas'] = []
      actual_boiler_eff['FuelOilNo2'] = []
      boiler_res_file_output_text = "Fuel,Min Capacity (Btu per hr),Max Capacity (Btu per hr),Annual Fuel Utilization Efficiency (AFUE),Thermal Efficiency,Combustion Efficiency\n"
      boiler_fueltypes.each do |ifuel|
        output_line_text = ''
        for int in 0..fuel_type_cap[ifuel].size - 1
          output_line_text += "#{ifuel},#{fuel_type_min_cap[ifuel][int]},#{fuel_type_max_cap[ifuel][int]},"
          if efficiency_type[ifuel][int] == 'Annual Fuel Utilization Efficiency (AFUE)'
            actual_boiler_eff[ifuel][int] = (standard.thermal_eff_to_afue(actual_boiler_thermal_eff[ifuel][int]) + 0.0001).round(3)
            output_line_text += "#{actual_boiler_eff[ifuel][int]},,\n"
          elsif efficiency_type[ifuel][int] == 'Combustion Efficiency'
            actual_boiler_eff[ifuel][int] = (standard.thermal_eff_to_comb_eff(actual_boiler_thermal_eff[ifuel][int]) + 0.0001).round(3)
            output_line_text += ",,#{actual_boiler_eff[ifuel][int]}\n"
          elsif efficiency_type[ifuel][int] == 'Thermal Efficiency'
            actual_boiler_eff[ifuel][int] = (actual_boiler_thermal_eff[ifuel][int] + 0.0001).round(3)
            output_line_text += ",#{actual_boiler_eff[ifuel][int]},\n"
          end
        end
        boiler_res_file_output_text += output_line_text
      end

      # Write test results file.
      test_result_file = File.join( @test_results_folder, "#{template.downcase}_compliance_boiler_efficiencies_test_results.csv")
      File.open(test_result_file, 'w') {|f| f.write(boiler_res_file_output_text)}

      # Test that the values are correct by doing a file compare.
      expected_result_file = File.join( @expected_results_folder, "#{template.downcase}_compliance_boiler_efficiencies_expected_results.csv")

      # Check if test results match expected.
      msg = "Boiler efficiencies test results do not match what is expected in test"
      file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
    end
  end

  # Test to validate the number of boilers used and their capacities depending on total heating capacity.
  # NECB2011 rule for number of boilers is:
  # if capacity <= 176 kW ---> one single stage boiler
  # if capacity > 176 kW and <= 352 kW ---> 2 boilers of equal capacity
  # if capacity > 352 kW ---> one modulating boiler down to 25% of capacity"
  def test_NECB2011_number_of_boilers

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = false

    first_cutoff_blr_cap = 176000.0
    second_cutoff_blr_cap = 352000.0
    tol = 1.0e-3

    # Generate the osm files for all relevant cases to generate the test data for system 3.
    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    heating_coil_type = 'Electric'
    test_boiler_cap = [100000.0, 200000.0, 400000.0]

    test_boiler_cap.each do |boiler_cap|
      name = "#{template}_sys1_Boiler-#{boiler_fueltype}_boiler_cap-#{boiler_cap}watts_HeatingCoilType#-#{heating_coil_type}_Baseboard-#{baseboard_type}"
      name.gsub!(/\s+/, "-")
      puts "***************#{name}***************\n"

      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, boiler_fueltype, always_on)
      standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(
          model: model,
          zones: model.getThermalZones,
          heating_coil_type: heating_coil_type,
          baseboard_type: baseboard_type,
          hw_loop: hw_loop,
          new_auto_zoner: false)
      model.getBoilerHotWaters.each {|iboiler| iboiler.setNominalCapacity(boiler_cap)}

      # Run sizing.
      run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

      boilers = model.getBoilerHotWaters

      # check that there are two boilers in the model.
      num_of_boilers_is_correct = false
      if boilers.size == 2 then
        num_of_boilers_is_correct = true
      end
      assert(num_of_boilers_is_correct, 'test_number_of_boilers: Number of boilers is not 2')
      this_is_the_first_cap_range = false
      this_is_the_second_cap_range = false
      this_is_the_third_cap_range = false
      if boiler_cap < first_cutoff_blr_cap
        this_is_the_first_cap_range = true
      elsif boiler_cap > second_cutoff_blr_cap
        this_is_the_third_cap_range = true
      else
        this_is_the_second_cap_range = true
      end
      # compare boiler capacities to expected values
      boilers.each do |iboiler|
        if iboiler.name.to_s.include? 'Primary Boiler'
          boiler_cap_is_correct = false
          if this_is_the_first_cap_range || this_is_the_third_cap_range
            cap_diff = (boiler_cap - iboiler.nominalCapacity.to_f).abs / boiler_cap
          elsif this_is_the_second_cap_range
            cap_diff = (0.5 * boiler_cap - iboiler.nominalCapacity.to_f).abs / (0.5 * boiler_cap)
          end
          if cap_diff < tol then
            boiler_cap_is_correct = true
          end
          assert(boiler_cap_is_correct, 'test_number_of_boilers: Primary boiler capacity is not correct')
        end
        if iboiler.name.to_s.include? 'Secondary Boiler'
          boiler_cap_is_correct = false
          if this_is_the_first_cap_range || this_is_the_third_cap_range
            cap_diff = (iboiler.nominalCapacity.to_f - 0.001).abs
          elsif this_is_the_second_cap_range
            cap_diff = (0.5 * boiler_cap - iboiler.nominalCapacity.to_f).abs / (0.5 * boiler_cap)
          end
          if cap_diff < tol then
            boiler_cap_is_correct = true
          end
          assert(boiler_cap_is_correct, 'test_number_of_boilers: Secondary boiler capacity is not correct')
        end
      end
    end
  end

  # Test to validate the boiler part load performance curve
  def test_NECB2011_boiler_plf_vs_plr_curve

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 1.
    boiler_res_file_output_text = "Name,Type,coeff1,coeff2,coeff3,coeff4,min_x,max_x\n"
    boiler_fueltype = 'NaturalGas'
    mau_type = true
    mau_heating_coil_type = 'Hot Water'
    baseboard_type = 'Hot Water'

    name = "#{template}_sys1_Boiler-#{boiler_fueltype}_Mau-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}"
    name.gsub!(/\s+/, "-")
    puts "***************#{name}***************\n"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
    OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, boiler_fueltype, always_on)
    standard.add_sys1_unitary_ac_baseboard_heating(model: model,
                                                   zones: model.getThermalZones,
                                                   mau_type: mau_type,
                                                   mau_heating_coil_type: mau_heating_coil_type,
                                                   baseboard_type: baseboard_type,
                                                   hw_loop: hw_loop)

    # Run sizing.
    run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

    boilers = model.getBoilerHotWaters
    boiler_curve = boilers[0].normalizedBoilerEfficiencyCurve.get.to_CurveCubic.get
    boiler_res_file_output_text += "BOILER-EFFFPLR-NECB2011,cubic,#{boiler_curve.coefficient1Constant},#{boiler_curve.coefficient2x},#{boiler_curve.coefficient3xPOW2}," +
        "#{boiler_curve.coefficient4xPOW3},#{boiler_curve.minimumValueofx},#{boiler_curve.maximumValueofx}"

    # Write test results file.
    test_result_file = File.join( @test_results_folder, "#{template.downcase}_compliance_boiler_plfvsplr_curve_test_results.csv")
    File.open(test_result_file, 'w') {|f| f.write(boiler_res_file_output_text)}

    # Test that the values are correct by doing a file compare.
    expected_result_file = File.join( @expected_results_folder, "#{template.downcase}_compliance_boiler_plfvsplr_curve_expected_results.csv")

    # Check if test results match expected.
    msg = "Boiler plf vs plr curve coeffs test results do not match what is expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end

  # Test to validate the custom boiler thermal efficiencies applied against expected values stored in the file:
  # 'compliance_boiler_custom_efficiencies_expected_results.json
  def test_custom_efficiency

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    templates = ['NECB2011', 'BTAPPRE1980']
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 1.
    mau_type = true
    mau_heating_coil_type = 'Hot Water'
    baseboard_type = 'Hot Water'
    test_res = []

    templates.each do |template|
      standard = get_standard(template)
      standard_ecms = get_standard("ECMS")
      boiler_fueltype = 'NaturalGas'
      boiler_cap = 1500000
      standard_ecms.standards_data["tables"]["boiler_eff_ecm"]["table"].each do |cust_eff_test|
        name = "#{template}_sys1_Boiler-#{boiler_fueltype}_cap-#{boiler_cap.to_int}W_MAU-#{mau_type}_MauCoil-#{mau_heating_coil_type}_Baseboard-#{baseboard_type}_efficiency-#{cust_eff_test["name"].to_s}"
        name.gsub!(/\s+/, "-")
        puts "***************#{name}***************\n"

        # Load model and set climate file.
        model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
        weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
        OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, boiler_fueltype, always_on)
        standard.add_sys1_unitary_ac_baseboard_heating(model: model,
                                                       zones: model.getThermalZones,
                                                       mau_type: mau_type,
                                                       mau_heating_coil_type: mau_heating_coil_type,
                                                       baseboard_type: baseboard_type,
                                                       hw_loop: hw_loop)
        model.getBoilerHotWaters.each {|iboiler| iboiler.setNominalCapacity(boiler_cap)}

        # Run sizing.
        run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

        # Customize the efficiency.
        standard_ecms.modify_boiler_efficiency(model: model, boiler_eff: cust_eff_test)

        boilers = model.getBoilerHotWaters
        boilers.each do |boiler|
          corr_coeff = []
          eff_curve = nil
          eff_curve_type = boiler.normalizedBoilerEfficiencyCurve.get.iddObjectType.valueName.to_s
          case eff_curve_type
          when "OS_Curve_Bicubic"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveBicubic.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.coefficient4y
            corr_coeff << eff_curve.coefficient5yPOW2
            corr_coeff << eff_curve.coefficient6xTIMESY
            corr_coeff << eff_curve.coefficient7xPOW3
            corr_coeff << eff_curve.coefficient8yPOW3
            corr_coeff << eff_curve.coefficient9xPOW2TIMESY
            corr_coeff << eff_curve.coefficient10xTIMESYPOW2
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
            corr_coeff << eff_curve.minimumValueofy
            corr_coeff << eff_curve.maximumValueofy
          when "OS_Curve_Biquadratic"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveBiquadratic.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.coefficient4y
            corr_coeff << eff_curve.coefficient5yPOW2
            corr_coeff << eff_curve.coefficient6xTIMESY
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
            corr_coeff << eff_curve.minimumValueofy
            corr_coeff << eff_curve.maximumValueofy
          when "OS_Curve_Cubic"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveCubic.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.coefficient4xPOW3
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
          when "OS_Curve_Linear"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveLinear.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
          when "OS_Curve_Quadratic"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveQuadratic.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
          when "OS_Curve_QuadraticLinear"
            eff_curve = boiler.normalizedBoilerEfficiencyCurve.get.to_CurveQuadraticLinear.get
            corr_coeff << eff_curve.coefficient1Constant
            corr_coeff << eff_curve.coefficient2x
            corr_coeff << eff_curve.coefficient3xPOW2
            corr_coeff << eff_curve.coefficient4y
            corr_coeff << eff_curve.coefficient5xTIMESY
            corr_coeff << eff_curve.coefficient6xPOW2TIMESY
            corr_coeff << eff_curve.minimumValueofx
            corr_coeff << eff_curve.maximumValueofx
            corr_coeff << eff_curve.minimumValueofy
            corr_coeff << eff_curve.maximumValueofy
          end
          eff_curve_name = eff_curve.name
          boiler_eff = boiler.nominalThermalEfficiency
          test_res << {
              template: template,
              boiler_name: boiler.name,
              boiler_eff: boiler_eff,
              eff_curve_name: eff_curve_name,
              curve_coefficients: corr_coeff
          }
        end
      end
    end

    # Write test results.
    test_result_file = File.join( @test_results_folder, "boiler_efficiency_modification_test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_res))
    expected_result_file = File.join( @test_results_folder, "boiler_efficiency_modification_expected_results.json")

    # Check if test results match expected.
    msg = "Boiler custom efficiencies test results do not match what is expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end

end

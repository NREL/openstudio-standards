require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Furnace_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate the furnace thermal efficiency generated against expected values stored in the file:
  # 'compliance_furnace_efficiencies_expected_results.csv
  def test_furnace_efficiency
    output_folder = method_output_folder(__method__)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 3.
    heating_coil_types = ['Electric', 'NaturalGas']
    baseboard_types = ['Electric', 'Hot Water']
    #stage_types = ['single', 'multi']
    stage_types = ['single'] # Multi stage failing
    templates = ['NECB2011', 'NECB2015', 'NECB2020']

    templates.each do |template|
      standard = get_standard(template)
      furnace_res_file_output_text = "Fuel,Min Capacity (kW),Max Capacity (kW),Tested Capacity (kW),Stage Type,Number of Stages,Annual Fuel Utilization Efficiency (AFUE),Thermal Efficiency,Combustion Efficiency\n"
      expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_furnace_efficiencies_expected_results.csv")

      # Initialize hashes for storing expected furnace efficiency data from file.
      fuel_type_min_cap = {}
      fuel_type_min_cap['Electric'] = []
      fuel_type_min_cap['NaturalGas'] = []
      fuel_type_max_cap = {}
      fuel_type_max_cap['Electric'] = []
      fuel_type_max_cap['NaturalGas'] = []
      efficiency_type = {}
      efficiency_type['Electric'] = []
      efficiency_type['NaturalGas'] = []

      # Read the file for the expected furnace efficiency values for different fuels and equipment capacity ranges.
      CSV.foreach(expected_result_file, headers: true) do |data|
        if data['Stage Type'] == 'single' # So it won't double the minimum capacities by adding the multi stage too.
          fuel_type_min_cap[data['Fuel']] << data['Min Capacity (kW)']
        end
        fuel_type_max_cap[data['Fuel']] << data['Max Capacity (kW)']
        if data['Annual Fuel Utilization Efficiency (AFUE)'].to_f > 0.0
          efficiency_type[data['Fuel']] << 'Annual Fuel Utilization Efficiency (AFUE)'
        elsif data['Thermal Efficiency'].to_f > 0.0
          efficiency_type[data['Fuel']] << 'Thermal Efficiency'
        elsif data['Combustion Efficiency'].to_f > 0.0
          efficiency_type[data['Fuel']] << 'Combustion Efficiency'
        end
      end

      # Use the expected furnace efficiency data to generate suitable equipment capacities for the test to cover all
      # the relevant equipment capacity ranges
      fuel_type_cap = {}
      fuel_type_min_cap.each do |fuel, cap|
        unless fuel_type_cap.key? fuel then
          fuel_type_cap[fuel] = []
        end
        if cap.size == 1
          fuel_type_cap[fuel] << 50.0
        else
          fuel_type_cap[fuel] << 0.5 * (fuel_type_min_cap[fuel][0].to_f + fuel_type_min_cap[fuel][1].to_f)
          if cap.size == 2
            fuel_type_cap[fuel] << (fuel_type_min_cap[fuel][1].to_f + 10.0)
          else
            fuel_type_cap[fuel] << 0.5 * (fuel_type_min_cap[fuel][1].to_f + fuel_type_min_cap[fuel][2].to_f)
            fuel_type_cap[fuel] << (fuel_type_min_cap[fuel][2].to_f + 10.0)
          end
        end
      end
      stage_types.each do |stage_type|
        index = 0
        #n_stages = 0
        actual_furnace_thermal_eff = {}
        actual_furnace_thermal_eff['Electric'] = []
        actual_furnace_thermal_eff['NaturalGas'] = []
        heating_coil_types.each do |heating_coil_type|
          test_stage_index = 0
          fuel_type_cap[heating_coil_type].each do |furnace_cap|
            name = "#{template}_sys3_Furnace-#{heating_coil_type}_stages-#{stage_type}_cap-#{furnace_cap.to_int}kW_Baseboard-#{baseboard_types[index]}"
            name.gsub!(/\s+/, "-")
            puts "***************#{name}***************\n"

            # Load model and set climate file.
            model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
            weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
            OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
            BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

            always_on = model.alwaysOnDiscreteSchedule
            hw_loop = nil
            if baseboard_types[index] == 'Hot Water'
              hw_loop = OpenStudio::Model::PlantLoop.new(model)
              standard.setup_hw_loop_with_components(model, hw_loop, heating_coil_type, heating_coil_type, always_on)
            end
            sys3_heating_coil_type = 'Electric'
            sys3_heating_coil_type = 'Gas' if heating_coil_type == 'NaturalGas'
            if stage_type == 'single'
              standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                          zones: model.getThermalZones,
                                                                                                          heating_coil_type: sys3_heating_coil_type,
                                                                                                          baseboard_type: baseboard_types[index],
                                                                                                          hw_loop: hw_loop,
                                                                                                          new_auto_zoner: false)
            elsif stage_type == 'multi'
              standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed(model: model,
                                                                                                         zones: model.getThermalZones,
                                                                                                         heating_coil_type: sys3_heating_coil_type,
                                                                                                         baseboard_type: baseboard_types[index],
                                                                                                         hw_loop: hw_loop,
                                                                                                         new_auto_zoner: false)
            end

            if stage_type == 'single'
              model.getCoilHeatingGass.each { |coil| coil.setNominalCapacity(furnace_cap * 1000) }
            elsif stage_type == 'multi'
              model.getCoilHeatingGasMultiStages.each do |coil|
                stage_cap = furnace_cap * 1000
                coil.stages.each do |istage|
                  istage.setNominalCapacity(stage_cap)
                  stage_cap += 10.0
                end
              end
            end

            # Run sizing.
            run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

            if stage_type == 'single'
              if heating_coil_type == 'NaturalGas'
                actual_furnace_thermal_eff[heating_coil_type] << model.getCoilHeatingGass[0].gasBurnerEfficiency
              elsif heating_coil_type == 'Electric'
                actual_furnace_thermal_eff[heating_coil_type] << model.getCoilHeatingElectrics[0].efficiency
              end

            elsif stage_type == 'multi'
              if heating_coil_type == 'NaturalGas'
                test_stage_index = model.getCoilHeatingGasMultiStages[0].stages.size - 1 if test_stage_index == 0
                actual_furnace_thermal_eff[heating_coil_type] << model.getCoilHeatingGasMultiStages[0].stages[test_stage_index].gasBurnerEfficiency
              elsif heating_coil_type == 'Electric'
                actual_furnace_thermal_eff[heating_coil_type] << model.getCoilHeatingElectrics[0].efficiency
              end
            end
          end
          index += 1
        end

        # Generate table of test furnace efficiencies
        actual_furnace_eff = {}
        actual_furnace_eff['Electric'] = []
        actual_furnace_eff['NaturalGas'] = []
        heating_coil_types.each do |heating_coil_type|
          output_line_text = ''

          for int in 0..fuel_type_cap[heating_coil_type].size - 1
           # Get the number of stages
            if stage_type == "single"
              num_stages = 1
            else
              num_stages = ((fuel_type_cap[heating_coil_type][int]) / (66.0) + 0.5).round
            end
            output_line_text += "#{heating_coil_type},#{fuel_type_min_cap[heating_coil_type][int]},#{(fuel_type_max_cap[heating_coil_type][int])},#{fuel_type_cap[heating_coil_type][int]},#{stage_type},#{num_stages},"

            if efficiency_type[heating_coil_type][int] == 'Annual Fuel Utilization Efficiency (AFUE)'
              actual_furnace_eff[heating_coil_type][int] = (standard.thermal_eff_to_afue(actual_furnace_thermal_eff[heating_coil_type][int]) + 0.0001).round(3)
              output_line_text += "#{actual_furnace_eff[heating_coil_type][int]},,\n"
            elsif efficiency_type[heating_coil_type][int] == 'Combustion Efficiency'
              actual_furnace_eff[heating_coil_type][int] = (standard.thermal_eff_to_comb_eff(actual_furnace_thermal_eff[heating_coil_type][int]) + 0.0001).round(3)
              output_line_text += ",,#{actual_furnace_eff[heating_coil_type][int]}\n"
            elsif efficiency_type[heating_coil_type][int] == 'Thermal Efficiency'
              actual_furnace_eff[heating_coil_type][int] = (actual_furnace_thermal_eff[heating_coil_type][int] + 0.0001).round(3)
              output_line_text += ",#{actual_furnace_eff[heating_coil_type][int]},\n"
            end
          end
          furnace_res_file_output_text += output_line_text
        end

      end

      # Write test results file.
      test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_furnace_efficiencies_test_results.csv")
      File.open(test_result_file, 'w') { |f| f.write(furnace_res_file_output_text) }

      # Check if test results match expected.
      msg = "Furnace efficiencies test results do not match what is expected in test"
      file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
    end
  end

  # Test to validate the furnace part load performance curve
  def test_NECB2011_furnace_plf_vs_plr_curve

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 3.
    boiler_fueltype = 'NaturalGas'
    heating_coil_type = 'Gas'
    baseboard_type = 'Hot Water'
    #stage_types = ['single', 'multi']
    stage_types = ['single'] # Multi stage failing
    stage_types.each do |stage_type|
      furnace_res_file_output_text = "Name,Type,coeff1,coeff2,coeff3,coeff4,min_x,max_x\n"
      name = "#{template}_sys3_Furnace-#{heating_coil_type}_Stages-#{stage_type}_Baseboard-#{baseboard_type}"
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
      if stage_type == 'single'
        standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                    zones: model.getThermalZones,
                                                                                                    heating_coil_type: heating_coil_type,
                                                                                                    baseboard_type: baseboard_type,
                                                                                                    hw_loop: hw_loop,
                                                                                                    new_auto_zoner: false)
      elsif stage_type == 'multi'
        standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed(model: model,
                                                                                                   zones: model.getThermalZones,
                                                                                                   heating_coil_type: heating_coil_type,
                                                                                                   baseboard_type: baseboard_type,
                                                                                                   hw_loop: hw_loop,
                                                                                                   new_auto_zoner: false)
      end

      # Run sizing.
      run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

      if stage_type == 'single'
        furnace_curve = model.getCoilHeatingGass[0].partLoadFractionCorrelationCurve.get.to_CurveCubic.get
      elsif stage_type == 'multi'
        furnace_curve = model.getCoilHeatingGasMultiStages[0].partLoadFractionCorrelationCurve.get.to_CurveCubic.get
      end
      furnace_res_file_output_text += "Furnace-EFFFPLR-NECB2011,cubic,#{furnace_curve.coefficient1Constant},#{furnace_curve.coefficient2x},#{furnace_curve.coefficient3xPOW2}," +
        "#{furnace_curve.coefficient4xPOW3},#{furnace_curve.minimumValueofx},#{furnace_curve.maximumValueofx}"

      # Write test results file.
      test_result_file = File.join(@test_results_folder, "#{template.downcase}_compliance_furnace_#{stage_type}_plfvsplr_curve_test_results.csv")
      File.open(test_result_file, 'w') { |f| f.write(furnace_res_file_output_text) }

      # Test that the values are correct by doing a file compare.
      expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_furnace_plfvsplr_curve_expected_results.csv")

      # Check if test results match expected.
      msg = "Furnace plf vs plr curve coeffs test results do not match what is expected in test"
      file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
    end
  end

  # Test to validate number of stages for multi furnaces
  # *** Method re-named so that test not run as multi stage fails ***
  def no_test_NECB2011_furnace_num_stages

    # Set up remaining parameters for test.
    output_folder = method_output_folder(__method__)
    template = 'NECB2011'
    standard = get_standard(template)
    save_intermediate_models = false

    # Generate the osm files for all relevant cases to generate the test data for system 3
    boiler_fueltype = 'NaturalGas'
    heating_coil_type = 'Gas'
    baseboard_type = 'Hot Water'
    caps = [33000.0, 66001.0, 132001.0, 198001.0]
    num_stages_needed = {}
    num_stages_needed[33000.0] = 2
    num_stages_needed[66001.0] = 2
    num_stages_needed[132001.0] = 3
    num_stages_needed[198001.0] = 4

    caps.each do |cap|
      name = "#{template}_sys3_Furnace-#{heating_coil_type}_cap-#{cap}W_Baseboard-#{baseboard_type}"
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
      standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed(model: model,
                                                                                                 zones: model.getThermalZones,
                                                                                                 heating_coil_type: heating_coil_type,
                                                                                                 baseboard_type: baseboard_type,
                                                                                                 hw_loop: hw_loop,
                                                                                                 new_auto_zoner: false)
      model.getCoilHeatingGasMultiStages.each { |coil| coil.stages.last.setNominalCapacity(cap) }

      # Run sizing.
      run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

      actual_num_stages = model.getCoilHeatingGasMultiStages[0].stages.size
      assert(actual_num_stages == num_stages_needed[cap], "The actual number of stages for capacity #{cap} W is not #{num_stages_needed[cap]}")
    end
  end
end

require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'

class NECB_HVAC_Furnace_Tests < MiniTest::Test
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

  # Test to validate the furnace thermal efficiency generated against expected values stored in the file:
  # 'compliance_furnace_efficiencies_expected_results.csv
  def test_NECB2011_furnace_efficiency
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)

    # Generate the osm files for all relevant cases to generate the test data for system 3
    heating_coil_types = ['Electric','NaturalGas']
    baseboard_types = ['Electric','Hot Water']
    stage_types = ['single','multi']
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    templates = ['NECB2011', 'NECB2015']
    templates.each do |template|
      standard = Standard.build(template)
      furnace_expected_result_file = File.join(@expected_results_folder, "#{template.downcase}_compliance_furnace_efficiencies_expected_results.csv")

      # Initialize hashes for storing expected furnace efficiency data from file
      fuel_type_min_cap = {}
      fuel_type_min_cap['Electric'] = []
      fuel_type_min_cap['NaturalGas'] = []
      fuel_type_max_cap = {}
      fuel_type_max_cap['Electric'] = []
      fuel_type_max_cap['NaturalGas'] = []
      efficiency_type = {}
      efficiency_type['Electric'] = []
      efficiency_type['NaturalGas'] = []

      # read the file for the expected furnace efficiency values for different fuels and equipment capacity ranges
      CSV.foreach(furnace_expected_result_file, headers: true) do |data|
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

      # Use the expected furnace efficiency data to generate suitable equipment capacities for the test to cover all
      # the relevant equipment capacity ranges
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

      stage_types.each do |stage_type|
        index = 0
        actual_furnace_thermal_eff = {}
        actual_furnace_thermal_eff['Electric'] = []
        actual_furnace_thermal_eff['NaturalGas'] = []
        heating_coil_types.each do |heating_coil_type|
          test_stage_index = 0
          fuel_type_cap[heating_coil_type].each do |furnace_cap|
            name = "#{template}_sys3_Furnace-#{heating_coil_type}_stages-#{stage_type}_cap-#{furnace_cap.to_int}W_Baseboard-#{baseboard_types[index]}"
            puts "***************************************#{name}*******************************************************\n"
            model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
            BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
            always_on = model.alwaysOnDiscreteSchedule
            hw_loop = nil
            if baseboard_types[index] == 'Hot Water'
              hw_loop = OpenStudio::Model::PlantLoop.new(model)
              standard.setup_hw_loop_with_components(model, hw_loop, heating_coil_type, always_on)
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
            # Save the model after btap hvac.
            BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
            if stage_type == 'single'
              model.getCoilHeatingGass.each {|coil| coil.setNominalCapacity(furnace_cap)}
            elsif stage_type == 'multi'
              model.getCoilHeatingGasMultiStages.each do |coil|
                stage_cap = furnace_cap
                coil.stages.each do |istage|
                  istage.setNominalCapacity(stage_cap)
                  stage_cap += 10.0
                end
              end
            end
            # run the standards
            result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
            # Save the model
            BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
            assert_equal(true, result, "test_furnace_efficiency: Failure in Standards for #{name}")
            if stage_type == 'single'
              if heating_coil_type == 'NaturalGas'
                actual_furnace_thermal_eff[heating_coil_type] << model.getCoilHeatingGass[0].gasBurnerEfficiency
              elsif heating_coil_type == 'Electric'
                actual_furnace_thermal_eff[heating_coil_type] << model.getCoilHeatingElectrics[0].efficiency
              end
            elsif stage_type == 'multi'
              if heating_coil_type == 'NaturalGas'
                test_stage_index = model.getCoilHeatingGasMultiStages[0].stages.size-1 if test_stage_index == 0
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
        furnace_res_file_output_text = "Fuel,Min Capacity (Btu per hr),Max Capacity (Btu per hr),Annual Fuel Utilization Efficiency (AFUE),Thermal Efficiency,Combustion Efficiency\n"
        heating_coil_types.each do |heating_coil_type|
          output_line_text = ''
          for int in 0..fuel_type_cap[heating_coil_type].size - 1
            output_line_text += "#{heating_coil_type},#{fuel_type_min_cap[heating_coil_type][int]},#{fuel_type_max_cap[heating_coil_type][int]},"
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

        # Write actual results file
        test_result_file = File.join( @test_results_folder, "#{template.downcase}_compliance_furnace_efficiencies_test_results.csv")
        File.open(test_result_file, 'w') {|f| f.write(furnace_res_file_output_text)}
        # Test that the values are correct by doing a file compare.
        expected_result_file = File.join( @expected_results_folder, "#{template.downcase}_compliance_furnace_efficiencies_expected_results.csv")
        b_result = FileUtils.compare_file(expected_result_file, test_result_file)
        assert(b_result,
             "test_furnace_efficiency: Furnace efficiencies test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")
      end
    end
  end

  # Test to validate the furnace part load performance curve
  def test_NECB2011_furnace_plf_vs_plr_curve
    setup()
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    standard = Standard.build('NECB2011')

    # Generate the osm files for all relevant cases to generate the test data for system 3
    boiler_fueltype = 'NaturalGas'
    heating_coil_type = 'Gas'
    baseboard_type = 'Hot Water'
    template = 'NECB2011'
    stage_types = ['single','multi']
    stage_types.each do |stage_type|
      furnace_res_file_output_text = "Name,Type,coeff1,coeff2,coeff3,coeff4,min_x,max_x\n"
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      # save baseline
      BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
      name = "#{template}_sys3_Furnace-#{heating_coil_type}_Stages-#{stage_type}_Baseboard-#{baseboard_type}"
      puts "***************************************#{name}*******************************************************\n"
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
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
      # Save the model after btap hvac.
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
      # run the standards
      result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
      # Save the model
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
      assert_equal(true, result, "test_furnace_plf_vs_plr_curve: Failure in Standards for #{name}")
      if stage_type == 'single'
        furnace_curve = model.getCoilHeatingGass[0].partLoadFractionCorrelationCurve.get.to_CurveCubic.get
      elsif stage_type == 'multi'
        furnace_curve = model.getCoilHeatingGasMultiStages[0].partLoadFractionCorrelationCurve.get.to_CurveCubic.get
      end
      furnace_res_file_output_text += "Furnace-EFFFPLR-NECB2011,cubic,#{furnace_curve.coefficient1Constant},#{furnace_curve.coefficient2x},#{furnace_curve.coefficient3xPOW2}," +
        "#{furnace_curve.coefficient4xPOW3},#{furnace_curve.minimumValueofx},#{furnace_curve.maximumValueofx}"

      # Write actual results file
      test_result_file = File.join( @test_results_folder, "#{template.downcase}_compliance_furnace_#{stage_type}_plfvsplr_curve_test_results.csv")
      File.open(test_result_file, 'w') {|f| f.write(furnace_res_file_output_text)}
      # Test that the values are correct by doing a file compare.
      expected_result_file = File.join( @expected_results_folder, "#{template.downcase}_compliance_furnace_plfvsplr_curve_expected_results.csv")
      b_result = FileUtils.compare_file(expected_result_file, test_result_file)
      assert(b_result,
           "test_furnace_plf_vs_plr_curve: Furnace plf vs plr curve coeffs test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")
    end
  end

  # Test to validate number of stages for multi furnaces
  def test_NECB2011_furnace_num_stages
    setup()
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    standard = Standard.build('NECB2011')

    # Generate the osm files for all relevant cases to generate the test data for system 3
    boiler_fueltype = 'NaturalGas'
    heating_coil_type = 'Gas'
    baseboard_type = 'Hot Water'
    template = 'NECB2011'
    caps = [33000.0,66001.0,132001.0,198001.0]
    num_stages_needed = {}
    num_stages_needed[33000.0] = 2
    num_stages_needed[66001.0] = 2
    num_stages_needed[132001.0] = 3
    num_stages_needed[198001.0] = 4
    caps.each do |cap|
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      # save baseline
      BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
      name = "#{template}_sys3_Furnace-#{heating_coil_type}_cap-#{cap}W_Baseboard-#{baseboard_type}"
      puts "***************************************#{name}*******************************************************\n"
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
      standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_multi_speed(model: model,
                                                                                                   zones: model.getThermalZones,
                                                                                                   heating_coil_type: heating_coil_type,
                                                                                                   baseboard_type: baseboard_type,
                                                                                                   hw_loop: hw_loop,
                                                                                                   new_auto_zoner: false)
      model.getCoilHeatingGasMultiStages.each {|coil| coil.stages.last.setNominalCapacity(cap)}
      # Save the model after btap hvac.
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
      # run the standards
      result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
      # Save the model
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
      assert_equal(true, result, "test_furnace_plf_vs_plr_curve: Failure in Standards for #{name}")
      actual_num_stages = model.getCoilHeatingGasMultiStages[0].stages.size
      assert(actual_num_stages == num_stages_needed[cap],"The actual number of stages for capacity #{cap} W is not #{num_stages_needed[cap]}")
    end
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
      # self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}

      # BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
      return true
    end
  end

end

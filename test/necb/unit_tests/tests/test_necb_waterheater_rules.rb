require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'


class NECB_SHW_Additional_Tests < MiniTest::Test
  # set to true to run the standards in the test.
  PERFORM_STANDARDS = true
  # set to true to run the simulations.
  FULL_SIMULATIONS = false

  def setup()
    @file_folder = __dir__
    @test_folder = File.join(@file_folder, '..')
    @root_folder = File.join(@test_folder, '../../../')
    @resources_folder = File.join(@test_folder, 'resources')
    @expected_results_folder = File.join(@test_folder, 'expected_results')
    @test_results_folder = @expected_results_folder
    @top_output_folder = "#{@test_folder}/output/"
  end


  # Test to validate part-load performance curve of gas fired shw heater (NECB 2011)
  def test_NECB2011_shw_curves
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    shw_expected_result_file = File.join(@expected_results_folder, 'compliance_shw_curves_expected_results.csv')
    shw_curve_names = []
    CSV.foreach(shw_expected_result_file, headers: true) do |data|
      shw_curve_names << data['Curve Name']
    end
    standard = Standard.build('NECB2011')
 
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
    # run the standards
    result = run_the_measure(model, "#{output_folder}/#{name}/sizing","NECB2011")
    # Save the model
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
    assert_equal(true, result, "test_shw_curves: Failure in Standards for #{name}")
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
    b_result = FileUtils.compare_file(expected_result_file, test_result_file)
    assert(b_result,
    "SHW performance curve coeffs test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}")
  end

  # Test to validate efficiency and standby losses of electric shw heater (NECB 2011)
  def test_NECB2011_shw_elec_efficiency_standby_losses
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    standard = Standard.build('NECB2011')
 
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
        # run the standards
        result = run_the_measure(model, "#{output_folder}/#{name}/sizing","NECB2011")
        # Save the model
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
        assert_equal(true, result, "test_shw_curves: Failure in Standards for #{name}")
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

   # Test to validate efficiency and standby losses of electric shw heater (NECB 2020)
   def test_NECB2020_shw_elec_efficiency_standby_losses
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    standard = Standard.build('NECB2020')
 
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
        # run the standards
        result = run_the_measure(model, "#{output_folder}/#{name}/sizing","NECB2020")
        # Save the model
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
        assert_equal(true, result, "test_shw_curves: Failure in Standards for #{name}")
        # get standard water tank efficiency and standby losses
        actual_shw_tank_eff = shw_units[0].heaterThermalEfficiency.to_f
        shw_units = model.getWaterHeaterMixeds
        actual_shw_tank_vol = shw_units[0].tankVolume.to_f
        actual_offcycle_ua = shw_units[0].offCycleLossCoefficienttoAmbientTemperature.to_f
        actual_oncycle_ua = shw_units[0].onCycleLossCoefficienttoAmbientTemperature.to_f
        vol_gal = OpenStudio.convert(ivol/1000.0, 'm^3', 'gal').get
        if icap < 12.0
          expected_eff = 1.0
          if ivol <= 270.0
            ua_w = 40 + 0.2 * ivol
          else
            ua_w = 0.472 * ivol - 33.5
          end   
          ua_btu_p_hr = OpenStudio.convert(ua_w, 'W', 'Btu/hr').get
        else
          expected_eff = 1.0
          ua_w = 0.3 + 102.2/ivol
          ua_btu_p_hr = OpenStudio.convert(ua_w, 'W', 'Btu/hr').get
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

  # Test to validate efficiency and standby losses of GAS shw heater (NECB 2022)
  def test_NECB2020_shw_gas_efficiency_standby_losses
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    standard = Standard.build('NECB2020')
 
    # test space types - SHW demand depends on space type + space area
    test_spacetypes = ["Office enclosed <= 25 m2", "Health care facility operating room", "Museum general exhibition area", "Conference/Meeting/Multi-purpose room", \
    "Warehouse storage area medium to bulky palletized items", "Transportation facility baggage/carousel area", "Audience seating area permanent - gymnasium",\
    "Computer/Server room-sch-C", "Gymnasium/Fitness centre playing area", "Retail facility mall concourse"]
    # Generate the osm files for all relevant cases to generate the test data
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC5Storeys.osm"))
    BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
    # save baseline
    BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")
   
    test_spacetypes.each do |test_spacetype|
      name = "shw_for_#{test_spacetype}"
      puts "***************************************#{name}*******************************************************\n"
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC5Storeys.osm"))
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      #Set spacetype
      model.getSpaces.each do |space|
        st = OpenStudio::Model::SpaceType.new(model)
        st.setStandardsBuildingType("Space Function")
        st.setStandardsSpaceType(test_spacetype)
        st.setName("#{"Space Function"} #{test_spacetype}")
        space.setSpaceType(st)
      end
      # add shw loop
      prototype_input = {}
      prototype_input['main_water_heater_volume'] = 100.0
      prototype_input['main_service_water_temperature'] = 60.0
      prototype_input['main_service_water_pump_head'] = 1.0
      prototype_input['main_service_water_pump_motor_efficiency'] = 0.7
      prototype_input['main_water_heater_capacity'] = 100000.0
      prototype_input['main_water_heater_fuel'] = 'NaturalGas'
      prototype_input['main_service_water_parasitic_fuel_consumption_rate'] = 1.0
      standard.model_add_swh(model: model, swh_fueltype: 'DefaultFuel', shw_scale: 1.0)
      # add hvac system
      boiler_fueltype = 'NaturalGas'
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

      # run the standards
      result = run_the_measure(model, "#{output_folder}/#{name}/sizing", "NECB2020")
      # Save the model
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
      assert_equal(true, result, "test_shw_curves: Failure in Standards for #{name}")
      # get standard water tank efficiency and standby losses
      shw_units = model.getWaterHeaterMixeds
      puts "shw_units[0] #{shw_units[0]}"
      icap = (shw_units[0].heaterMaximumCapacity.get.to_f)/1000.0 # kW
      puts "icap #{icap} kW"
      ivol = (shw_units[0].tankVolume.get.to_f)*1000.0 # Litres
      puts "ivol #{ivol} L"
      actual_shw_tank_eff = shw_units[0].heaterThermalEfficiency.to_f
      actual_shw_tank_vol = shw_units[0].tankVolume.to_f
      actual_offcycle_ua = shw_units[0].offCycleLossCoefficienttoAmbientTemperature.to_f
      actual_oncycle_ua = shw_units[0].onCycleLossCoefficienttoAmbientTemperature.to_f
      vol_gal = OpenStudio.convert(ivol/1000.0, 'm^3', 'gal').get

      # Complete local calculation of efficiency and losses (using SI units)
        # 1. calc FHR
        # 2a. Set water heater thermal efficiency (burner efficiency), calc UEF, then UA (skin loss) OR
        # 2b. Calc SL, then UA (skin loss), followed by water heater thermal efficiency (burner efficiency)
      
      # Calc FHR
      tank_param = standard.auto_size_shw_capacity(model:model, shw_scale: 'NECB_Default')
      fhr_L_per_hr = (tank_param['loop_peak_flow_rate_SI']) * 3600000
      puts "Calculate UA   ========================================== "
      puts "fhr_L_per_hr #{fhr_L_per_hr} L/hr"
      puts "icap #{icap} kW"
      puts "ivol #{ivol} L; (=#{vol_gal} gal)"
      # select UA and burner efficiency estimation method based on tank volume and heating capacity

      if icap <= 22 and ivol >= 76 and ivol < 208
        uef = 1
        volume_drawn_m3 = 0
        if fhr_L_per_hr < 68
          uef = 0.3456 - 0.00053 * ivol
          volume_drawn_m3 = 0.038 
        elsif fhr_L_per_hr >= 68 and fhr_L_per_hr < 193
          uef = 0.5982 - 0.0005 * ivol
          volume_drawn_m3 = 0.144
        elsif fhr_L_per_hr >= 193 and fhr_L_per_hr < 284
          uef = 0.6483 - 0.00045 * ivol
          volume_drawn_m3 = 0.208
        elsif fhr_L_per_hr >= 284
          uef = 0.6920 - 0.00034 * ivol
          volume_drawn_m3 = 0.318
        end
        water_heater_eff = 0.82
        puts "icap <= 22 and ivol >= 76 and ivol < 208"
        puts "uef #{uef}"
        puts "water_heater_eff #{water_heater_eff}"
        volume_drawn_gal = OpenStudio.convert(volume_drawn_m3, 'm^3', 'gal').get
        puts "volume_drawn_m3 #{volume_drawn_m3}, (= #{volume_drawn_gal} gal)"
        q_load_j = (volume_drawn_m3)*994.6482*4179.53*(51.66667-14.44444) # 33.06C water properties used
        q_load_btu = OpenStudio.convert(q_load_j, 'J', 'Btu').get
        puts "q_load_j #{q_load_j} J, (=#{q_load_btu} BTU)"
        re = water_heater_eff + q_load_j*(uef - water_heater_eff)/(24*3600*icap*1000*uef)
        puts "re #{re}"
        ua_w_per_k = (water_heater_eff-re)*icap*1000/(51.66667-19.7222)
        puts "ua_w_per_k 22kw #{ua_w_per_k}"
        


      elsif icap <= 22 and ivol >= 208 and ivol < 380
        uef = 1
        volume_drawn_m3 = 0
        if fhr_L_per_hr < 68
          uef = 0.647 - 0.00016 * ivol
          puts "ivol #{ivol}"
          puts "ivol #{ivol.class}"
          puts "00016ivol#{0.00016 * ivol}"
          puts "uef #{uef}"
          volume_drawn_m3 = 0.038
        elsif fhr_L_per_hr >= 68 and fhr_L_per_hr < 193
          uef = 0.7689 - 0.00013 * ivol
          volume_drawn_m3 = 0.144
        elsif fhr_L_per_hr >= 193 and fhr_L_per_hr < 284
          uef = 0.7987 - 0.00011 * ivol
          volume_drawn_m3 = 0.208
        elsif fhr_L_per_hr >= 284
          uef = 0.8072 - 0.00008 * ivol
          volume_drawn_m3 = 0.318
        end
        water_heater_eff = 0.82
        puts "icap <= 22 and ivol >= 208 and ivol < 380"
        puts "uef #{uef}"
        puts "water_heater_eff #{water_heater_eff}"
        volume_drawn_gal = OpenStudio.convert(volume_drawn_m3, 'm^3', 'gal').get
        puts "volume_drawn_m3 #{volume_drawn_m3}, (= #{volume_drawn_gal} gal)"
        q_load_j = (volume_drawn_m3)*994.6482*4179.53*(51.66667-14.44444) # 33.06C water properties used
        q_load_btu = OpenStudio.convert(q_load_j, 'J', 'Btu').get
        puts "q_load_j #{q_load_j} J, (=#{q_load_btu} BTU)"
        re = water_heater_eff + q_load_j*(uef - water_heater_eff)/(24*3600*icap*1000*uef)
        puts "re #{re}"
        ua_w_per_k = (water_heater_eff-re)*icap*1000/(51.66667-19.7222)
        puts "ua_w_per_k 22kw #{ua_w_per_k}"

      elsif icap > 22 and icap <= 30.5 and ivol <= 454
        uef = 1
        volume_drawn_m3 = 0
        if fhr_L_per_hr < 68
          volume_drawn_m3 = 0.038
        elsif fhr_L_per_hr >= 68 and fhr_L_per_hr < 193
          volume_drawn_m3 = 0.144
        elsif fhr_L_per_hr >= 193 and fhr_L_per_hr < 284
          volume_drawn_m3 = 0.208
        elsif fhr_L_per_hr >= 284
          volume_drawn_m3 = 0.318
        end
        uef = 0.8107 - 0.00021 * ivol
        water_heater_eff = 0.82
        puts "icap > 22 and icap <= 30.5 and ivol <= 454"
        puts "uef #{uef}"
        puts "water_heater_eff #{water_heater_eff}"
        volume_drawn_gal = OpenStudio.convert(volume_drawn_m3, 'm^3', 'gal').get
        puts "volume_drawn_m3 #{volume_drawn_m3}, (= #{volume_drawn_gal} gal)"
        q_load_j = volume_drawn_m3*994.6482*4179.53*(51.66667-14.44444) # 33.06C water properties used
        q_load_btu = OpenStudio.convert(q_load_j, 'J', 'Btu').get
        puts "q_load_j #{q_load_j} J, (=#{q_load_btu} BTU)"
        re = water_heater_eff + q_load_j*(uef - water_heater_eff)/(24*3600*icap*1000*uef)
        puts "re #{re}"
        ua_w_per_k = (water_heater_eff-re)*icap*1000/(51.66667-19.72222)
        puts "ua_w_per_k #{ua_w_per_k}"
      else
        # 
        puts "case ELSE"
        et = 0.9
        sl_w = 0.84*(1.25*icap+16.57*(ivol**0.5))
        sl_btu_per_hr = OpenStudio.convert(sl_w, 'W', 'Btu/hr').get
        ua_btu_per_hr_per_F = sl_btu_per_hr*et/70
        puts "sl_w #{sl_w} W, (=#{sl_btu_per_hr} BTU/hr)"
        puts "ua_btu_per_hr_per_F #{ua_btu_per_hr_per_F} BTU/hr/F"
        icap_btu_per_hr = OpenStudio.convert(icap, 'kW', 'Btu/hr').get
        water_heater_eff = (ua_btu_per_hr_per_F*70 + icap_btu_per_hr*et)/icap_btu_per_hr
        puts "water_heater_eff #{water_heater_eff}"
        ua_w_per_k = OpenStudio.convert(ua_btu_per_hr_per_F, 'Btu/hr*R', 'W/K').get
        puts "ua_w_per_k else #{ua_w_per_k}"
      end

      # Check accuracy of parameters
      rel_tol = 5.0e-3 # 0.5% tolerance is enough given - CSA P.3 - 15 sensor accuracy (e.g. water temp: +/- 0.1C, volume: +/- 2% of total volume,)
      abs_tol = 0.2

      rel_diff = (actual_shw_tank_eff-water_heater_eff).abs/water_heater_eff
      abs_diff = (actual_shw_tank_eff-water_heater_eff).abs
      puts "actual_shw_tank_eff #{actual_shw_tank_eff}"
      puts "water_heater_eff #{water_heater_eff}"
      value_is_correct = true
      if rel_diff > rel_tol and abs_diff > abs_tol then value_is_correct = false end
      assert(value_is_correct,"SHW efficiency test results (#{water_heater_eff}) do not match expected results (#{actual_shw_tank_eff})!")


      rel_diff = (actual_offcycle_ua-ua_w_per_k).abs/ua_w_per_k
      abs_diff = (actual_offcycle_ua-ua_w_per_k).abs
      puts "actual_offcycle_ua #{actual_offcycle_ua}"
      puts "ua_w_per_k #{ua_w_per_k}"
      value_is_correct = true
      if rel_diff > rel_tol and abs_diff > abs_tol then value_is_correct = false end
      assert(value_is_correct,"SHW off cycle standby loss test results (#{ua_w_per_k}) do not match expected results (#{actual_offcycle_ua})!")


      rel_diff = (actual_oncycle_ua-ua_w_per_k).abs/ua_w_per_k
      abs_diff = (actual_oncycle_ua-ua_w_per_k).abs
      puts "actual_oncycle_ua #{actual_oncycle_ua}"
      puts "ua_w_per_k #{ua_w_per_k}"
      value_is_correct = true
      if rel_diff > rel_tol and abs_diff > abs_tol then value_is_correct = false end
      assert(value_is_correct,"SHW on cycle standby loss test results (#{ua_w_per_k})do not match expected results (#{actual_oncycle_ua})!")
    
    end
  end

  
  def run_simulations(output_folder)
    if FULL_SIMULATIONS == true
      file_array = []
      BTAP::FileIO.get_find_files_from_folder_by_extension(output_folder, '.osm').each do |file|
        # skip any sizing.osm file.
        unless file.to_s.include? 'sizing.osm'
          file_array << file
        end
      end
      BTAP::SimManager.simulate_files(output_folder, file_array)
      BTAP::Reporting.get_all_annual_results_from_runmanger_by_files(output_folder, file_array)

      are_there_no_severe_errors = File.zero?("#{output_folder}/failed simulations.txt")
      assert_equal(true, are_there_no_severe_errors, "Simulations had severe errors. Check #{output_folder}/failed simulations.txt")
    end
  end

  def run_the_measure(model, sizing_dir, building_vintage)
    if PERFORM_STANDARDS
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

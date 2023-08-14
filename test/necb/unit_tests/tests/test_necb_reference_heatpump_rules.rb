require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'

class NECB_HVAC_Heat_Pump_Tests < Minitest::Test
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

#Tests to confirm heat pump rules from NECB 8.4.4.13

  # Check if rated heating capacity of the HP is 50% of cooling capacity at -8.3C
  # NOTE: The DXCOOL-NECB2011-REF-CAPFT curve has a temperature limit of 13C, standards
  # will "extrapolate", unless the capacity curve at -8.3C yields a negative factor.
  # Thus, there 2 possible capacities and the test will pass if either value is used.
  def test_ref_heatpump_heating_capacity
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)
    # Test all systems and templates, to ensure future editions and additional systems follow this rule
    templates = ['NECB2011', 'NECB2015', 'NECB2017']
    sys_numbers = ['sys1', 'sys3', 'sys4', 'sys6']
    necb_reference_hp_supp_fuels = ['NaturalGas', 'Electricity', 'FuelOilNo2']
    templates.each do |template|
      sys_numbers.each do |sys_number|
        necb_reference_hp_supp_fuels.each do |necb_reference_hp_supp_fuel|
          name = "ref_heatpump_heating_capacity_#{template}_#{sys_number}"
          standard = Standard.build(template)

          # Set standard to use reference hp rules.
          necb_reference_hp = true

          # Set up model.
          model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))

          # Set up hvac system parameters and components.
          boiler_fueltype = 'Electricity'
          baseboard_type = 'Hot Water'
          heating_coil_type = 'DX'
          hw_loop = OpenStudio::Model::PlantLoop.new(model)
          always_on = model.alwaysOnDiscreteSchedule
          BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)

          # Save baseline model.
          BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")

          # Set up hvac system.
          standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
          if sys_number == 'sys1'
            standard.add_sys1_unitary_ac_baseboard_heating_single_speed(model: model,
                necb_reference_hp: necb_reference_hp,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                mau_type: true,
                mau_heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop)
          elsif sys_number == 'sys3'
            standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                necb_reference_hp: necb_reference_hp,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop,
                new_auto_zoner: false)
          elsif sys_number == 'sys4'
            standard.add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
                necb_reference_hp: necb_reference_hp,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop)
          elsif sys_number == 'sys6'
            standard.add_sys6_multi_zone_reference_hp_with_baseboard_heating(model: model,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop)
          end

          # Save the model after btap hvac.
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")

          # Set cooling capacity
          dx_clg_coils = model.getCoilCoolingDXSingleSpeeds
          cap = 25000
          dx_clg_coils.each do |coil|
            coil.setRatedTotalCoolingCapacity(cap)
            flow_rate = cap * 5.0e-5
            coil.setRatedAirFlowRate(flow_rate)
          end

          # Run the standards.
          result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")

          # Save the model.
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result, "test_ref_heatpump_heating_capacity: Failure in Standards for #{name}")

          # Non-sys6 uses AirLoopHVACUnitaryHeatPumpAirToAirs
          unless sys_number == 'sys6'
            model.getAirLoopHVACUnitaryHeatPumpAirToAirs.each do |heatpump|

              # Get heat pump coils.
              htg_coil = heatpump.heatingCoil.to_CoilHeatingDXSingleSpeed.get
              clg_coil = heatpump.coolingCoil.to_CoilCoolingDXSingleSpeed.get

              indoor_wb = 19.4 # rated indoor wb
              outdoor_db = -8.3 # outdoor db
              clg_coil_rated_cap = clg_coil.ratedTotalCoolingCapacity.get # rated capacity W
              htg_coil_rated_cap = htg_coil.ratedTotalHeatingCapacity.get

              # Get cooling capacity temperature factor at curve limits (NECB limits should be 13C > -8.3C).
              cooling_cap_f_temp_curve = clg_coil.totalCoolingCapacityFunctionOfTemperatureCurve
              cooling_cap_f_temp_factor_min_y = cooling_cap_f_temp_curve.evaluate(indoor_wb,outdoor_db)
              htg_coil_rated_cap_min_y = clg_coil_rated_cap*cooling_cap_f_temp_factor_min_y*0.5

              # Get cooling capacity temperature factor at -8.3C, without curve limits (actual capacity based on curve factor output at -8.3C).
              cooling_cap_f_temp_factor_neg_eight_point_three =
              cooling_curve_expected_result_file = File.join(@expected_results_folder, "necb2011_reference_heatpump_cooling_curves_expected_results.csv")
              capftemp_coeff = []
              CSV.foreach(cooling_curve_expected_result_file) do |data|
                if data[0] == "DXCOOL-NECB2011-REF-CAPFT"
                  capftemp_coeff = data
                end
              end

              cooling_cap_f_temp_factor_neg_eight_point_three = ('%.8f'% capftemp_coeff[2]).to_f + ('%.8f' % capftemp_coeff[3]).to_f*indoor_wb + ('%.8f' % capftemp_coeff[4]).to_f*indoor_wb*indoor_wb \
              + ('%.8f' % capftemp_coeff[5]).to_f*outdoor_db\
              + ('%.8f' % capftemp_coeff[6]).to_f*outdoor_db*outdoor_db\
              + ('%.8f' % capftemp_coeff[7]).to_f*indoor_wb*outdoor_db
              htg_coil_rated_cap_neg_eight_point_three = clg_coil_rated_cap*cooling_cap_f_temp_factor_neg_eight_point_three*0.5

              # Compare the model heating coil's rated capacity to the computed values (should equal either one).
              htg_cap_test_neg_eight_point_three = (htg_coil_rated_cap > htg_coil_rated_cap_neg_eight_point_three - 0.1) &&
              (htg_coil_rated_cap < htg_coil_rated_cap_neg_eight_point_three + 0.1)

              htg_cap_test_min_y = (htg_coil_rated_cap > htg_coil_rated_cap_min_y - 0.1) && (htg_coil_rated_cap < htg_coil_rated_cap_min_y + 0.1)
              assert(htg_cap_test_neg_eight_point_three || htg_cap_test_min_y,
              "test_ref_heatpump_heating_capacity: The rated reference heat pump heating capacity, #{htg_coil_rated_cap},
              isn't 50% of the rated cooling capacity (#{clg_coil_rated_cap}) at -8.3C in #{name} ")
            end
          else

            # sys6 and sys1 uses contain dx coils directly within air loops.
            model.getAirLoopHVACs.each do |airloop|

              # Get heat pump coils.
              found_dx_htg = false
              found_dx_clg = false
              htg_coil = ""
              clg_coil = ""
              airloop.supplyComponents.each do |supply_component|
                if supply_component.to_CoilHeatingDXSingleSpeed.is_initialized
                  found_dx_htg = true
                  htg_coil = supply_component.to_CoilHeatingDXSingleSpeed.get
                elsif supply_component.to_CoilCoolingDXSingleSpeed.is_initialized
                  found_dx_clg = true
                  clg_coil = supply_component.to_CoilCoolingDXSingleSpeed.get
                end

              end
              #check if both DX coils exist
              assert(found_dx_htg, "test_ref_heatpump_heating_capacity: Could not find CoilHeatingDXSingleSpeed for #{name}")
              assert(found_dx_clg, "test_ref_heatpump_heating_capacity: Could not find CoilCoolingDXSingleSpeed for #{name}")
              #get model rated capacities (W)
              indoor_wb = 19.4 # rated indoor wb
              outdoor_db = -8.3 # outdoor db
              clg_coil_rated_cap = clg_coil.ratedTotalCoolingCapacity.get
              htg_coil_rated_cap = htg_coil.ratedTotalHeatingCapacity.get
              #get cooling capacity temperature factor at curve limits (NECB limits should be 13C > -8.3C)
              cooling_cap_f_temp_curve = clg_coil.totalCoolingCapacityFunctionOfTemperatureCurve
              cooling_cap_f_temp_factor_min_y = cooling_cap_f_temp_curve.evaluate(indoor_wb,outdoor_db)
              htg_coil_rated_cap_min_y = clg_coil_rated_cap*cooling_cap_f_temp_factor_min_y*0.5
              #get cooling capacity temperature factor at -8.3C, without curve limits (actual capacity based on curve factor output at -8.3C)
              cooling_cap_f_temp_factor_neg_eight_point_three =
              cooling_curve_expected_result_file = File.join(@expected_results_folder, "necb2011_reference_heatpump_cooling_curves_expected_results.csv")
              capftemp_coeff = []
              CSV.foreach(cooling_curve_expected_result_file) do |data|
                if data[0] == "DXCOOL-NECB2011-REF-CAPFT"
                  capftemp_coeff = data
                  puts "capftemp_coeff #{capftemp_coeff}"
                end
              end

              cooling_cap_f_temp_factor_neg_eight_point_three = ('%.8f'% capftemp_coeff[2]).to_f + ('%.8f' % capftemp_coeff[3]).to_f*indoor_wb + ('%.8f' % capftemp_coeff[4]).to_f*indoor_wb*indoor_wb \
              + ('%.8f' % capftemp_coeff[5]).to_f*outdoor_db\
              + ('%.8f' % capftemp_coeff[6]).to_f*outdoor_db*outdoor_db\
              + ('%.8f' % capftemp_coeff[7]).to_f*indoor_wb*outdoor_db
              htg_coil_rated_cap_neg_eight_point_three = clg_coil_rated_cap*cooling_cap_f_temp_factor_neg_eight_point_three*0.5

              #compare the model heating coil's rated capacity to the computed values (should equal either one)
              htg_cap_test_neg_eight_point_three = (htg_coil_rated_cap > htg_coil_rated_cap_neg_eight_point_three - 0.1) &&
              (htg_coil_rated_cap < htg_coil_rated_cap_neg_eight_point_three + 0.1)

              htg_cap_test_min_y = (htg_coil_rated_cap > htg_coil_rated_cap_min_y - 0.1) && (htg_coil_rated_cap < htg_coil_rated_cap_min_y + 0.1)
              assert(htg_cap_test_neg_eight_point_three || htg_cap_test_min_y,
              "test_ref_heatpump_heating_capacity: The rated reference heat pump heating capacity, #{htg_coil_rated_cap},
              isn't 50% of the rated cooling capacity (#{clg_coil_rated_cap}) at -8.3C in #{name} ")
            end
          end
        end
      end
    end
  end

  # Test heating coil to check if it turns off at <-10C
  def test_ref_heatpump_heating_low_temp
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)

    templates = ['NECB2011', 'NECB2015', 'NECB2017']
    sys_numbers = ['sys1', 'sys3', 'sys4', 'sys6']
    necb_reference_hp_supp_fuels = ['NaturalGas', 'Electricity', 'FuelOilNo2']
    templates.each do |template|
      sys_numbers.each do |sys_number|
        necb_reference_hp_supp_fuels.each do |necb_reference_hp_supp_fuel|
          name = "ref_heatpump_heating_low_temp_#{template}_#{sys_number}"
          standard = Standard.build(template)
          # set standard to use reference hp rules
          necb_reference_hp = true
          #set up model
          model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
          #set up hvac system parameters and components
          boiler_fueltype = 'Electricity'
          baseboard_type = 'Hot Water'
          heating_coil_type = 'DX'
          hw_loop = OpenStudio::Model::PlantLoop.new(model)
          always_on = model.alwaysOnDiscreteSchedule
          BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
          # save baseline
          BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")

          # set up hvac system
          standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
          if sys_number == 'sys1'
            standard.add_sys1_unitary_ac_baseboard_heating_single_speed(model: model,
                necb_reference_hp: necb_reference_hp,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                mau_type: true,
                mau_heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop)
          elsif sys_number == 'sys3'
            standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                necb_reference_hp: necb_reference_hp,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop,
                new_auto_zoner: false)
          elsif sys_number == 'sys4'
            standard.add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
                necb_reference_hp: necb_reference_hp,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop)
          elsif sys_number == 'sys6'
            standard.add_sys6_multi_zone_reference_hp_with_baseboard_heating(model: model,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop)
          end
          # Save the model after btap hvac.
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
          # run the standards
          result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
          # Save the model
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result, "test_ref_heatpump_heating_low_temp: Failure in Standards for #{name}")

          # non-sys6 uses AirLoopHVACUnitaryHeatPumpAirToAirs
          unless sys_number == 'sys6'
            model.getAirLoopHVACUnitaryHeatPumpAirToAirs.each do |heatpump|
              #get heat pump coils
              htg_coil = heatpump.heatingCoil.to_CoilHeatingDXSingleSpeed.get
              assert(htg_coil.minimumOutdoorDryBulbTemperatureforCompressorOperation == -10,
              "test_ref_heatpump_heating_low_temp: The reference heat pump minimum compressor operation temperature isn't set to -10C,
              (it is currently set to #{htg_coil.minimumOutdoorDryBulbTemperatureforCompressorOperation}).")
            end
          else # sys6 and sys1 uses contain dx coils directly within air loops
            model.getAirLoopHVACs.each do |airloop|
              #get heat pump coils
              found_dx_htg = false
              found_dx_clg = false
              htg_coil = ""
              airloop.supplyComponents.each do |supply_component|
                if supply_component.to_CoilHeatingDXSingleSpeed.is_initialized
                  found_dx_htg = true
                  htg_coil = supply_component.to_CoilHeatingDXSingleSpeed.get
                end
              end
              #check if both DX coils exist
              assert(found_dx_htg, "test_ref_heatpump_heating_low_temp: Could not find CoilHeatingDXSingleSpeed for #{name}")
              assert(htg_coil.minimumOutdoorDryBulbTemperatureforCompressorOperation == -10,
              "test_ref_heatpump_heating_low_temp: The reference heat pump minimum compressor operation temperature isn't set to -10C,
              (it is currently set to #{htg_coil.minimumOutdoorDryBulbTemperatureforCompressorOperation}).")
            end
          end
        end
      end
    end
  end

  # Test if curve performance matches NECB curve
  def test_ref_heatpump_curve
    output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
    FileUtils.rm_rf(output_folder)
    FileUtils.mkdir_p(output_folder)

    templates = ['NECB2011', 'NECB2015', 'NECB2017']
    sys_numbers = ['sys1', 'sys3', 'sys4', 'sys6']
    necb_reference_hp_supp_fuels = ['NaturalGas', 'Electricity', 'FuelOilNo2']
    templates.each do |template|
      sys_numbers.each do |sys_number|
        necb_reference_hp_supp_fuels.each do |necb_reference_hp_supp_fuel|
          name = "ref_heatpump_curve_#{template}_#{sys_number}"
          standard = Standard.build(template)
          # set standard to use reference hp rules
          necb_reference_hp = true
          #set up model
          model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
          #set up hvac system parameters and components
          boiler_fueltype = 'Electricity'
          baseboard_type = 'Hot Water'
          heating_coil_type = 'DX'
          hw_loop = OpenStudio::Model::PlantLoop.new(model)
          always_on = model.alwaysOnDiscreteSchedule
          BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
          # save baseline
          BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")

          # set up hvac system
          standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
          if sys_number == 'sys1'
            standard.add_sys1_unitary_ac_baseboard_heating_single_speed(model: model,
                necb_reference_hp: necb_reference_hp,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                mau_type: true,
                mau_heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop)
          elsif sys_number == 'sys3'
            standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                necb_reference_hp: necb_reference_hp,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop,
                new_auto_zoner: false)
          elsif sys_number == 'sys4'
            standard.add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
                necb_reference_hp: necb_reference_hp,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop)
          elsif sys_number == 'sys6'
            standard.add_sys6_multi_zone_reference_hp_with_baseboard_heating(model: model,
                necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
                zones: model.getThermalZones,
                heating_coil_type: heating_coil_type,
                baseboard_type: baseboard_type,
                hw_loop: hw_loop)
          end
          # Save the model after btap hvac.
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
          # run the standards
          result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
          # Save the model
          BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
          assert_equal(true, result, "test_ref_heatpump_curve: Failure in Standards for #{name}")

          #get expected cooling values
          cooling_curve_expected_result_file = File.join(@expected_results_folder, "necb2011_reference_heatpump_cooling_curves_expected_results.csv")
          cool_plf_plr_coeff = []
          cool_capft_coeff = []
          cool_eirft_coeff = []
          cool_capfflow_coeff = []
          cool_eirfflow_coeff = []
          exp_clg_plf_plr_coeff = []
          exp_clg_capft_coeff = []
          exp_clg_eirft_coeff = []
          exp_clg_capfflow_coeff = []
          exp_clg_eirfflow_coeff = []
          CSV.foreach(cooling_curve_expected_result_file) do |data|
            if data[0] == "DXCOOL-NECB2011-REF-COOLPLFFPLR"
              cool_plf_plr_coeff = data
              puts "cool_plf_plr_coeff #{cool_plf_plr_coeff}"
            elsif data[0] == "DXCOOL-NECB2011-REF-CAPFT"
              cool_capft_coeff = data
            elsif data[0] == "DXCOOL-NECB2011-REF-COOLEIRFT"
              cool_eirft_coeff = data
            elsif data[0] == "DXCOOL-NECB2011-REF-CAPFFLOW"
              cool_capfflow_coeff = data
            elsif data[0] == "DXCOOL-NECB2011-REF-COOLEIRFFLOW"
              cool_eirfflow_coeff = data
            end
          end
          #store expected clg coefficients
          exp_clg_plf_plr_coeff << cool_plf_plr_coeff[2].to_f
          exp_clg_plf_plr_coeff << cool_plf_plr_coeff[3].to_f
          exp_clg_plf_plr_coeff << cool_plf_plr_coeff[4].to_f
          exp_clg_plf_plr_coeff << cool_plf_plr_coeff[5].to_f
          exp_clg_capft_coeff << cool_capft_coeff[2].to_f
          exp_clg_capft_coeff << cool_capft_coeff[3].to_f
          exp_clg_capft_coeff << cool_capft_coeff[4].to_f
          exp_clg_capft_coeff << cool_capft_coeff[5].to_f
          exp_clg_capft_coeff << cool_capft_coeff[6].to_f
          exp_clg_capft_coeff << cool_capft_coeff[7].to_f
          exp_clg_eirft_coeff << cool_eirft_coeff[2].to_f
          exp_clg_eirft_coeff << cool_eirft_coeff[3].to_f
          exp_clg_eirft_coeff << cool_eirft_coeff[4].to_f
          exp_clg_eirft_coeff << cool_eirft_coeff[5].to_f
          exp_clg_eirft_coeff << cool_eirft_coeff[6].to_f
          exp_clg_eirft_coeff << cool_eirft_coeff[7].to_f
          exp_clg_capfflow_coeff << cool_capfflow_coeff[2].to_f
          exp_clg_capfflow_coeff << cool_capfflow_coeff[3].to_f
          exp_clg_capfflow_coeff << cool_capfflow_coeff[4].to_f
          exp_clg_eirfflow_coeff << cool_eirfflow_coeff[2].to_f
          exp_clg_eirfflow_coeff << cool_eirfflow_coeff[3].to_f
          exp_clg_eirfflow_coeff << cool_eirfflow_coeff[4].to_f


          #get expected heating values
          heating_curve_expected_result_file = File.join(@expected_results_folder, "necb2011_reference_heatpump_heating_curves_expected_results.csv")
          heat_plf_plr_coeff = []
          heat_capft_coeff = []
          heat_eirft_coeff = []
          heat_capfflow_coeff = []
          heat_eirfflow_coeff = []
          exp_htg_plf_plr_coeff = []
          exp_htg_capft_coeff = []
          exp_htg_eirft_coeff = []
          exp_htg_capfflow_coeff = []
          exp_htg_eirfflow_coeff = []
          CSV.foreach(heating_curve_expected_result_file) do |data|
            if data[0] == "DXHEAT-NECB2011-REF-PLFFPLR"
              heat_plf_plr_coeff = data
              puts "heat_plf_plr_coeff #{heat_plf_plr_coeff}"
            elsif data[0] == "DXHEAT-NECB2011-REF-CAPFT"
              heat_capft_coeff = data
            elsif data[0] == "DXHEAT-NECB2011-REF-EIRFT"
              heat_eirft_coeff = data
            elsif data[0] == "DXHEAT-NECB2011-REF-CAPFFLOW"
              heat_capfflow_coeff = data
            elsif data[0] == "DXHEAT-NECB2011-REF-EIRFFLOW"
              heat_eirfflow_coeff = data
            end
          end
          # store expected htg coefficients
          exp_htg_plf_plr_coeff << heat_plf_plr_coeff[2].to_f
          exp_htg_plf_plr_coeff << heat_plf_plr_coeff[3].to_f
          exp_htg_plf_plr_coeff << heat_plf_plr_coeff[4].to_f
          exp_htg_plf_plr_coeff << heat_plf_plr_coeff[5].to_f
          exp_htg_capft_coeff << heat_capft_coeff[2].to_f
          exp_htg_capft_coeff << heat_capft_coeff[3].to_f
          exp_htg_capft_coeff << heat_capft_coeff[4].to_f
          exp_htg_capft_coeff << heat_capft_coeff[5].to_f
          exp_htg_eirft_coeff << heat_eirft_coeff[2].to_f
          exp_htg_eirft_coeff << heat_eirft_coeff[3].to_f
          exp_htg_eirft_coeff << heat_eirft_coeff[4].to_f
          exp_htg_eirft_coeff << heat_eirft_coeff[5].to_f
          exp_htg_capfflow_coeff << heat_capfflow_coeff[2].to_f
          exp_htg_capfflow_coeff << heat_capfflow_coeff[3].to_f
          exp_htg_capfflow_coeff << heat_capfflow_coeff[4].to_f
          exp_htg_capfflow_coeff << heat_capfflow_coeff[5].to_f
          exp_htg_eirfflow_coeff << heat_eirfflow_coeff[2].to_f
          exp_htg_eirfflow_coeff << heat_eirfflow_coeff[3].to_f
          exp_htg_eirfflow_coeff << heat_eirfflow_coeff[4].to_f

          # non-sys6 uses AirLoopHVACUnitaryHeatPumpAirToAirs
          unless sys_number == 'sys6'
            model.getAirLoopHVACUnitaryHeatPumpAirToAirs.each do |heatpump|
              #define local variable to hold coeff
              htg_coil_plf_plr_curve_coeff = []
              htg_coil_capft_curve_coeff = []
              htg_coil_eirft_curve_coeff = []
              htg_coil_capfflow_curve_coeff = []
              htg_coil_eirfflow_curve_coeff = []
              clg_coil_plf_plr_curve_coeff = []
              clg_coil_capft_curve_coeff = []
              clg_coil_eirft_curve_coeff = []
              clg_coil_capfflow_curve_coeff = []
              clg_coil_eirfflow_curve_coeff = []
              #get heat pump coils
              htg_coil = heatpump.heatingCoil.to_CoilHeatingDXSingleSpeed.get
              clg_coil = heatpump.coolingCoil.to_CoilCoolingDXSingleSpeed.get
              # get heating plf_plr curve and its coefficients
              htg_coil_plf_plr_curve = htg_coil.partLoadFractionCorrelationCurve.to_CurveCubic.get
              htg_coil_plf_plr_curve_coeff << htg_coil_plf_plr_curve.coefficient1Constant
              htg_coil_plf_plr_curve_coeff << htg_coil_plf_plr_curve.coefficient2x
              htg_coil_plf_plr_curve_coeff << htg_coil_plf_plr_curve.coefficient3xPOW2
              htg_coil_plf_plr_curve_coeff << htg_coil_plf_plr_curve.coefficient4xPOW3
              assert(exp_htg_plf_plr_coeff == htg_coil_plf_plr_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump heating part load performance does not match with expected values
              expected: #{exp_htg_plf_plr_coeff}
              actual: #{htg_coil_plf_plr_curve_coeff}.")
              # get heating capft curve and its coefficients
              htg_coil_capft_curve = htg_coil.totalHeatingCapacityFunctionofTemperatureCurve.to_CurveCubic.get
              htg_coil_capft_curve_coeff << htg_coil_capft_curve.coefficient1Constant
              htg_coil_capft_curve_coeff << htg_coil_capft_curve.coefficient2x
              htg_coil_capft_curve_coeff << htg_coil_capft_curve.coefficient3xPOW2
              htg_coil_capft_curve_coeff << htg_coil_capft_curve.coefficient4xPOW3
              assert(exp_htg_capft_coeff == htg_coil_capft_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump heating capft performance does not match with expected values
              expected: #{exp_htg_capft_coeff}
              actual: #{htg_coil_capft_curve_coeff}.")
              # get heating eirft curve and its coefficients
              htg_coil_eirft_curve = htg_coil.energyInputRatioFunctionofTemperatureCurve.to_CurveCubic.get
              htg_coil_eirft_curve_coeff << htg_coil_eirft_curve.coefficient1Constant
              htg_coil_eirft_curve_coeff << htg_coil_eirft_curve.coefficient2x
              htg_coil_eirft_curve_coeff << htg_coil_eirft_curve.coefficient3xPOW2
              htg_coil_eirft_curve_coeff << htg_coil_eirft_curve.coefficient4xPOW3
              assert(exp_htg_eirft_coeff == htg_coil_eirft_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump heating eirft performance does not match with expected values
              expected: #{exp_htg_eirft_coeff}
              actual: #{htg_coil_eirft_curve_coeff}.")
              # get heating capfflow curve and its coefficients
              htg_coil_capfflow_curve = htg_coil.totalHeatingCapacityFunctionofFlowFractionCurve.to_CurveCubic.get
              htg_coil_capfflow_curve_coeff << htg_coil_capfflow_curve.coefficient1Constant
              htg_coil_capfflow_curve_coeff << htg_coil_capfflow_curve.coefficient2x
              htg_coil_capfflow_curve_coeff << htg_coil_capfflow_curve.coefficient3xPOW2
              htg_coil_capfflow_curve_coeff << htg_coil_capfflow_curve.coefficient4xPOW3
              assert(exp_htg_capfflow_coeff == htg_coil_capfflow_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump heating capfflow performance does not match with expected values
              expected: #{exp_htg_capfflow_coeff}
              actual: #{htg_coil_capfflow_curve_coeff}.")
              # get heating eirfflow curve and its coefficients
              htg_coil_eirfflow_curve = htg_coil.energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get
              htg_coil_eirfflow_curve_coeff << htg_coil_eirfflow_curve.coefficient1Constant
              htg_coil_eirfflow_curve_coeff << htg_coil_eirfflow_curve.coefficient2x
              htg_coil_eirfflow_curve_coeff << htg_coil_eirfflow_curve.coefficient3xPOW2
              assert(exp_htg_eirfflow_coeff == htg_coil_eirfflow_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump heating eirfflow performance does not match with expected values
              expected: #{exp_htg_eirfflow_coeff}
              actual: #{htg_coil_eirfflow_curve_coeff}.")

              # get cooling plf_plr curve and its coefficients
              clg_coil_plf_plr_curve = clg_coil.partLoadFractionCorrelationCurve.to_CurveCubic.get
              clg_coil_plf_plr_curve_coeff << clg_coil_plf_plr_curve.coefficient1Constant
              clg_coil_plf_plr_curve_coeff << clg_coil_plf_plr_curve.coefficient2x
              clg_coil_plf_plr_curve_coeff << clg_coil_plf_plr_curve.coefficient3xPOW2
              clg_coil_plf_plr_curve_coeff << clg_coil_plf_plr_curve.coefficient4xPOW3
              assert(exp_clg_plf_plr_coeff == clg_coil_plf_plr_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling part load performance does not match with expected values
              expected: #{exp_clg_plf_plr_coeff}
              actual: #{clg_coil_plf_plr_curve_coeff}.")
              # get cooling capft curve and its coefficients
              clg_coil_capft_curve = clg_coil.totalCoolingCapacityFunctionOfTemperatureCurve.to_CurveBiquadratic.get
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient1Constant
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient2x
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient3xPOW2
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient4y
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient5yPOW2
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient6xTIMESY
              assert(exp_clg_capft_coeff == clg_coil_capft_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling capft performance does not match with expected values
              expected: #{exp_clg_capft_coeff}
              actual: #{clg_coil_capft_curve_coeff}.")
              # get cooling eirft curve and its coefficients
              clg_coil_eirft_curve = clg_coil.energyInputRatioFunctionOfTemperatureCurve.to_CurveBiquadratic.get
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient1Constant
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient2x
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient3xPOW2
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient4y
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient5yPOW2
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient6xTIMESY
              assert(exp_clg_eirft_coeff == clg_coil_eirft_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling eirft performance does not match with expected values
              expected: #{exp_clg_eirft_coeff}
              actual: #{clg_coil_eirft_curve_coeff}.")
              # get cooling capfflow curve and its coefficients
              clg_coil_capfflow_curve = clg_coil.totalCoolingCapacityFunctionOfFlowFractionCurve.to_CurveQuadratic.get
              clg_coil_capfflow_curve_coeff << clg_coil_capfflow_curve.coefficient1Constant
              clg_coil_capfflow_curve_coeff << clg_coil_capfflow_curve.coefficient2x
              clg_coil_capfflow_curve_coeff << clg_coil_capfflow_curve.coefficient3xPOW2
              assert(exp_clg_capfflow_coeff == clg_coil_capfflow_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling capfflow performance does not match with expected values
              expected: #{exp_clg_capfflow_coeff}
              actual: #{clg_coil_capfflow_curve_coeff}.")
              # get cooling eirfflow curve and its coefficients
              clg_coil_eirfflow_curve = clg_coil.energyInputRatioFunctionOfFlowFractionCurve.to_CurveQuadratic.get
              clg_coil_eirfflow_curve_coeff << clg_coil_eirfflow_curve.coefficient1Constant
              clg_coil_eirfflow_curve_coeff << clg_coil_eirfflow_curve.coefficient2x
              clg_coil_eirfflow_curve_coeff << clg_coil_eirfflow_curve.coefficient3xPOW2
              assert(exp_clg_eirfflow_coeff == clg_coil_eirfflow_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling eirfflow performance does not match with expected values
              expected: #{exp_clg_eirfflow_coeff}
              actual: #{clg_coil_eirfflow_curve_coeff}.")
            end
          else # sys6 and sys1 uses contain dx coils directly within air loops
            model.getAirLoopHVACs.each do |airloop|
              # define local flags/variables to hold coeff
              found_dx_htg = false
              found_dx_clg = false
              htg_coil = ""
              clg_coil = ""
              htg_coil_plf_plr_curve_coeff = []
              htg_coil_capft_curve_coeff = []
              htg_coil_eirft_curve_coeff = []
              htg_coil_capfflow_curve_coeff = []
              htg_coil_eirfflow_curve_coeff = []
              clg_coil_plf_plr_curve_coeff = []
              clg_coil_capft_curve_coeff = []
              clg_coil_eirft_curve_coeff = []
              clg_coil_capfflow_curve_coeff = []
              clg_coil_eirfflow_curve_coeff = []
              #get heat pump coils
              airloop.supplyComponents.each do |supply_component|
                if supply_component.to_CoilHeatingDXSingleSpeed.is_initialized
                  found_dx_htg = true
                  htg_coil = supply_component.to_CoilHeatingDXSingleSpeed.get
                elsif supply_component.to_CoilCoolingDXSingleSpeed.is_initialized
                  found_dx_clg = true
                  clg_coil = supply_component.to_CoilCoolingDXSingleSpeed.get
                end

              end
              #check if both DX coils exist
              assert(found_dx_htg, "test_ref_heatpump_plr_curve: Could not find CoilHeatingDXSingleSpeed for #{name}")
              assert(found_dx_clg, "test_ref_heatpump_plr_curve: Could not find CoilCoolingDXSingleSpeed for #{name}")

              # get plf_plr curve and its coefficients
              htg_coil_plf_plr_curve = htg_coil.partLoadFractionCorrelationCurve.to_CurveCubic.get
              htg_coil_plf_plr_curve_coeff << htg_coil_plf_plr_curve.coefficient1Constant
              htg_coil_plf_plr_curve_coeff << htg_coil_plf_plr_curve.coefficient2x
              htg_coil_plf_plr_curve_coeff << htg_coil_plf_plr_curve.coefficient3xPOW2
              htg_coil_plf_plr_curve_coeff << htg_coil_plf_plr_curve.coefficient4xPOW3
              assert(exp_htg_plf_plr_coeff == htg_coil_plf_plr_curve_coeff,
              "test_ref_heatpump_plr_curve: The reference heat pump heating part load performance does not match with expected values
              expected: #{exp_htg_plf_plr_coeff}
              actual: #{htg_coil_plf_plr_curve_coeff}.")
              # get heating capft curve and its coefficients
              htg_coil_capft_curve = htg_coil.totalHeatingCapacityFunctionofTemperatureCurve.to_CurveCubic.get
              htg_coil_capft_curve_coeff << htg_coil_capft_curve.coefficient1Constant
              htg_coil_capft_curve_coeff << htg_coil_capft_curve.coefficient2x
              htg_coil_capft_curve_coeff << htg_coil_capft_curve.coefficient3xPOW2
              htg_coil_capft_curve_coeff << htg_coil_capft_curve.coefficient4xPOW3
              assert(exp_htg_capft_coeff == htg_coil_capft_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump heating capft performance does not match with expected values
              expected: #{exp_htg_capft_coeff}
              actual: #{htg_coil_capft_curve_coeff}.")
              # get heating eirft curve and its coefficients
              htg_coil_eirft_curve = htg_coil.energyInputRatioFunctionofTemperatureCurve.to_CurveCubic.get
              htg_coil_eirft_curve_coeff << htg_coil_eirft_curve.coefficient1Constant
              htg_coil_eirft_curve_coeff << htg_coil_eirft_curve.coefficient2x
              htg_coil_eirft_curve_coeff << htg_coil_eirft_curve.coefficient3xPOW2
              htg_coil_eirft_curve_coeff << htg_coil_eirft_curve.coefficient4xPOW3
              assert(exp_htg_eirft_coeff == htg_coil_eirft_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump heating eirft performance does not match with expected values
              expected: #{exp_htg_eirft_coeff}
              actual: #{htg_coil_eirft_curve_coeff}.")
              # get heating capfflow curve and its coefficients
              htg_coil_capfflow_curve = htg_coil.totalHeatingCapacityFunctionofFlowFractionCurve.to_CurveCubic.get
              htg_coil_capfflow_curve_coeff << htg_coil_capfflow_curve.coefficient1Constant
              htg_coil_capfflow_curve_coeff << htg_coil_capfflow_curve.coefficient2x
              htg_coil_capfflow_curve_coeff << htg_coil_capfflow_curve.coefficient3xPOW2
              htg_coil_capfflow_curve_coeff << htg_coil_capfflow_curve.coefficient4xPOW3
              assert(exp_htg_capfflow_coeff == htg_coil_capfflow_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump heating capfflow performance does not match with expected values
              expected: #{exp_htg_capfflow_coeff}
              actual: #{htg_coil_capfflow_curve_coeff}.")
              # get heating eirfflow curve and its coefficients
              htg_coil_eirfflow_curve = htg_coil.energyInputRatioFunctionofFlowFractionCurve.to_CurveQuadratic.get
              htg_coil_eirfflow_curve_coeff << htg_coil_eirfflow_curve.coefficient1Constant
              htg_coil_eirfflow_curve_coeff << htg_coil_eirfflow_curve.coefficient2x
              htg_coil_eirfflow_curve_coeff << htg_coil_eirfflow_curve.coefficient3xPOW2
              assert(exp_htg_eirfflow_coeff == htg_coil_eirfflow_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump heating eirfflow performance does not match with expected values
              expected: #{exp_htg_eirfflow_coeff}
              actual: #{htg_coil_eirfflow_curve_coeff}.")

              # get cooling plf_plr curve and its coefficients
              clg_coil_plf_plr_curve = clg_coil.partLoadFractionCorrelationCurve.to_CurveCubic.get
              clg_coil_plf_plr_curve_coeff << clg_coil_plf_plr_curve.coefficient1Constant
              clg_coil_plf_plr_curve_coeff << clg_coil_plf_plr_curve.coefficient2x
              clg_coil_plf_plr_curve_coeff << clg_coil_plf_plr_curve.coefficient3xPOW2
              clg_coil_plf_plr_curve_coeff << clg_coil_plf_plr_curve.coefficient4xPOW3
              assert(exp_clg_plf_plr_coeff == clg_coil_plf_plr_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling part load performance does not match with expected values
              expected: #{exp_clg_plf_plr_coeff}
              actual: #{clg_coil_plf_plr_curve_coeff}.")
              # get cooling capft curve and its coefficients
              clg_coil_capft_curve = clg_coil.totalCoolingCapacityFunctionOfTemperatureCurve.to_CurveBiquadratic.get
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient1Constant
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient2x
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient3xPOW2
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient4y
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient5yPOW2
              clg_coil_capft_curve_coeff << clg_coil_capft_curve.coefficient6xTIMESY
              assert(exp_clg_capft_coeff == clg_coil_capft_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling capft performance does not match with expected values
              expected: #{exp_clg_capft_coeff}
              actual: #{clg_coil_capft_curve_coeff}.")
              # get cooling eirft curve and its coefficients
              clg_coil_eirft_curve = clg_coil.energyInputRatioFunctionOfTemperatureCurve.to_CurveBiquadratic.get
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient1Constant
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient2x
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient3xPOW2
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient4y
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient5yPOW2
              clg_coil_eirft_curve_coeff << clg_coil_eirft_curve.coefficient6xTIMESY
              assert(exp_clg_eirft_coeff == clg_coil_eirft_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling eirft performance does not match with expected values
              expected: #{exp_clg_eirft_coeff}
              actual: #{clg_coil_eirft_curve_coeff}.")
              # get cooling capfflow curve and its coefficients
              clg_coil_capfflow_curve = clg_coil.totalCoolingCapacityFunctionOfFlowFractionCurve.to_CurveQuadratic.get
              clg_coil_capfflow_curve_coeff << clg_coil_capfflow_curve.coefficient1Constant
              clg_coil_capfflow_curve_coeff << clg_coil_capfflow_curve.coefficient2x
              clg_coil_capfflow_curve_coeff << clg_coil_capfflow_curve.coefficient3xPOW2
              assert(exp_clg_capfflow_coeff == clg_coil_capfflow_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling capfflow performance does not match with expected values
              expected: #{exp_clg_capfflow_coeff}
              actual: #{clg_coil_capfflow_curve_coeff}.")
              # get cooling eirfflow curve and its coefficients
              clg_coil_eirfflow_curve = clg_coil.energyInputRatioFunctionOfFlowFractionCurve.to_CurveQuadratic.get
              clg_coil_eirfflow_curve_coeff << clg_coil_eirfflow_curve.coefficient1Constant
              clg_coil_eirfflow_curve_coeff << clg_coil_eirfflow_curve.coefficient2x
              clg_coil_eirfflow_curve_coeff << clg_coil_eirfflow_curve.coefficient3xPOW2
              assert(exp_clg_eirfflow_coeff == clg_coil_eirfflow_curve_coeff,
              "test_ref_heatpump_curve: The reference heat pump cooling eirfflow performance does not match with expected values
              expected: #{exp_clg_eirfflow_coeff}
              actual: #{clg_coil_eirfflow_curve_coeff}.")
            end
          end
        end
      end
    end
  end


# Test HP cooling set to zone peak load without oversizing
def test_ref_heatpump_sizing_factor
  output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
  FileUtils.rm_rf(output_folder)
  FileUtils.mkdir_p(output_folder)

  templates = ['NECB2011', 'NECB2015', 'NECB2017']
  sys_numbers = ['sys1', 'sys3', 'sys4', 'sys6']
  necb_reference_hp_supp_fuels = ['NaturalGas', 'Electricity', 'FuelOilNo2']
  templates.each do |template|
    sys_numbers.each do |sys_number|
      necb_reference_hp_supp_fuels.each do |necb_reference_hp_supp_fuel|
        name = "test_ref_heatpump_sizing_factor_#{template}_#{sys_number}"
        puts"name#{name}"
        puts "necb_reference_hp_supp_fuel #{necb_reference_hp_supp_fuel}"
        standard = Standard.build(template)
        # set standard to use reference hp rules
        necb_reference_hp = true
        #set up model
        model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
        #set up hvac system parameters and components
        boiler_fueltype = 'Electricity'
        baseboard_type = 'Hot Water'
        heating_coil_type = 'DX'
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
        # save baseline
        BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")

        # set up hvac system
        standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
        if sys_number == 'sys1'
          standard.add_sys1_unitary_ac_baseboard_heating_single_speed(model: model,
              necb_reference_hp: necb_reference_hp,
              necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
              zones: model.getThermalZones,
              mau_type: true,
              mau_heating_coil_type: heating_coil_type,
              baseboard_type: baseboard_type,
              hw_loop: hw_loop)
        elsif sys_number == 'sys3'
          standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
              necb_reference_hp: necb_reference_hp,
              necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
              zones: model.getThermalZones,
              heating_coil_type: heating_coil_type,
              baseboard_type: baseboard_type,
              hw_loop: hw_loop,
              new_auto_zoner: false)
        elsif sys_number == 'sys4'
          standard.add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
              necb_reference_hp: necb_reference_hp,
              necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
              zones: model.getThermalZones,
              heating_coil_type: heating_coil_type,
              baseboard_type: baseboard_type,
              hw_loop: hw_loop)
        elsif sys_number == 'sys6'
          standard.add_sys6_multi_zone_reference_hp_with_baseboard_heating(model: model,
              necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
              zones: model.getThermalZones,
              heating_coil_type: heating_coil_type,
              baseboard_type: baseboard_type,
              hw_loop: hw_loop)
        end
        # Save the model after btap hvac.
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")
        # run the standards
        result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")
        # Save the model
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
        assert_equal(true, result, "test_ref_heatpump_sizing_factor: Failure in Standards for #{name}")

        no_over_sizing = true
        model.getThermalZones.each do |zone|
          unless zone.sizingZone.zoneCoolingSizingFactor.is_initialized and zone.sizingZone.zoneCoolingSizingFactor.get == 1.0
            no_over_sizing = false
          end
        end
        assert(no_over_sizing, "test_ref_heatpump_sizing_factor: The reference heat pump cooling is not sized to peak load
        (e.g. zone.sizingZone.zoneCoolingSizingFactor.get != 1.0). ")
      end
    end
  end
end

# Test for correct supplemental heating
 # Test heating coil to check if it turns off at <-10C
 def test_ref_heatpump_heating_low_temp
  output_folder = File.join(@top_output_folder,__method__.to_s.downcase)
  FileUtils.rm_rf(output_folder)
  FileUtils.mkdir_p(output_folder)

  templates = ['NECB2011', 'NECB2015', 'NECB2017']
  sys_numbers = ['sys1', 'sys3', 'sys4', 'sys6']
  necb_reference_hp_supp_fuels = ['NaturalGas', 'Electricity', 'FuelOilNo2']
  templates.each do |template|
    sys_numbers.each do |sys_number|
      necb_reference_hp_supp_fuels.each do |necb_reference_hp_supp_fuel|
        name = "ref_heatpump_heating_low_temp_#{template}_#{sys_number}"
        standard = Standard.build(template)

        # Set standard to use reference hp rules.
        necb_reference_hp = true

        # Set up model.
        model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))

        # Set up hvac system parameters and components.
        boiler_fueltype = 'Electricity'
        baseboard_type = 'Hot Water'
        heating_coil_type = 'DX'
        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)

        # Save baseline model.
        BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm")

        # Set up hvac system.
        standard.setup_hw_loop_with_components(model, hw_loop, boiler_fueltype, always_on)
        if sys_number == 'sys1'
          standard.add_sys1_unitary_ac_baseboard_heating_single_speed(model: model,
              necb_reference_hp: necb_reference_hp,
              necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
              zones: model.getThermalZones,
              mau_type: true,
              mau_heating_coil_type: heating_coil_type,
              baseboard_type: baseboard_type,
              hw_loop: hw_loop)
        elsif sys_number == 'sys3'
          standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
              necb_reference_hp: necb_reference_hp,
              necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
              zones: model.getThermalZones,
              heating_coil_type: heating_coil_type,
              baseboard_type: baseboard_type,
              hw_loop: hw_loop,
              new_auto_zoner: false)
        elsif sys_number == 'sys4'
          standard.add_sys4_single_zone_make_up_air_unit_with_baseboard_heating(model: model,
              necb_reference_hp: necb_reference_hp,
              necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
              zones: model.getThermalZones,
              heating_coil_type: heating_coil_type,
              baseboard_type: baseboard_type,
              hw_loop: hw_loop)
        elsif sys_number == 'sys6'
          standard.add_sys6_multi_zone_reference_hp_with_baseboard_heating(model: model,
              necb_reference_hp_supp_fuel: necb_reference_hp_supp_fuel,
              zones: model.getThermalZones,
              heating_coil_type: heating_coil_type,
              baseboard_type: baseboard_type,
              hw_loop: hw_loop)
        end

        # Save the model after btap hvac.
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.hvacrb")

        # Run the standards.
        result = run_the_measure(model, template, "#{output_folder}/#{name}/sizing")

        # Save the model.
        BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}.osm")
        assert_equal(true, result, "test_ref_heatpump_heating_low_temp: Failure in Standards for #{name}")

        # non-sys6 uses AirLoopHVACUnitaryHeatPumpAirToAirs
        unless sys_number == 'sys6'
          model.getAirLoopHVACUnitaryHeatPumpAirToAirs.each do |heatpump|

            # Get heat pump coils.
            if necb_reference_hp_supp_fuel == "NaturalGas"
              assert(heatpump.supplementalHeatingCoil.to_CoilHeatingGas.is_initialized, "test_ref_supp_heating_fuel: The reference heat pump supplmental coil is
              set to the wrong type - it should be CoilHeatingGas")
            elsif necb_reference_hp_supp_fuel == "Electricity" or necb_reference_hp_supp_fuel == "FuelOilNo2"
              assert(heatpump.supplementalHeatingCoil.to_CoilHeatingElectric.is_initialized, "test_ref_supp_heating_fuel: The reference heat pump supplmental coil is
              set to the wrong type - it should be CoilHeatingElectric")
            end
          end
        else

          # sys6 and sys1 uses contain dx coils directly within air loops.
          model.getThermalZones.each do |zone|
            air_terminal_rh = zone.airLoopHVACTerminal.get.to_AirTerminalSingleDuctConstantVolumeReheat.get
            if necb_reference_hp_supp_fuel == "NaturalGas"
              assert(air_terminal_rh.reheatCoil.to_CoilHeatingGas.is_initialized, "test_ref_supp_heating_fuel: The reference heat pump supplmental coil is
              set to the wrong type - it should be CoilHeatingGas")
            elsif necb_reference_hp_supp_fuel == "Electricity" or necb_reference_hp_supp_fuel == "FuelOilNo2"
              assert(air_terminal_rh.reheatCoil.to_CoilHeatingElectric.is_initialized, "test_ref_supp_heating_fuel: The reference heat pump supplmental coil is
              set to the wrong type - it should be CoilHeatingElectric")
            end
          end
        end
      end
    end
  end
end

  def run_the_measure(model, template, sizing_dir)
      if PERFORM_STANDARDS

        # Hard-code the building vintage.
        building_vintage = template
        building_type = 'NECB'
        climate_zone = 'NECB'
        standard = Standard.build(building_vintage)

        # Set standard to use reference hp rules.
        necb_reference_hp = true

        # Make a directory to run the sizing run in.
        unless Dir.exist? sizing_dir
          FileUtils.mkdir_p(sizing_dir)
        end

        # Perform a sizing run.
        if standard.model_run_sizing_run(model, "#{sizing_dir}/SizingRun1") == false
          puts "could not find sizing run #{sizing_dir}/SizingRun1"
          raise("could not find sizing run #{sizing_dir}/SizingRun1")
          return false
        else
          puts "found sizing run #{sizing_dir}/SizingRun1"
        end

        # BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/before.osm")

        # Need to set prototype assumptions so that HRV added.
        standard.model_apply_prototype_hvac_assumptions(model, building_type, climate_zone)

        # Apply the HVAC efficiency standard.
        standard.model_apply_hvac_efficiency_standard(model, climate_zone, necb_ref_hp: necb_reference_hp)
        #standard.model_apply_hvac_efficiency_standard(model, climate_zone)
        # self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}

        # BTAP::FileIO.save_osm(model, "#{File.dirname(__FILE__)}/after.osm")

        return true
      end
  end
end

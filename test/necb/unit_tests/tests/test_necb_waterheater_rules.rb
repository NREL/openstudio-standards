require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_WaterHeater_Rules < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate part-load performance curve of gas fired service water heater.
  def no_test_swh_curves
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters.
    test_parameters = {TestMethod: __method__,
                       SaveIntermediateModels: true,
                       fuel_type: 'Electricity',
                       heating_coil_type: 'DX',
                       baseboard_type: 'Hot Water'}

    # Define test cases. 
    test_cases = Hash.new

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = {Reference: 'NECB 2011 xxx'}
    
    # Results and name are tbd here as they will be calculated in the test.
    test_cases_hash = {vintage: ['NECB2011'], #@AllTemplates, 
                       TestCase: ['Case 1'], 
                       TestPars: {swh_volume_L: 100.0,
                                  swh_temperature_degC: 60.0,
                                  swh_pump_head: 1.0,
                                  swh_pump_motor_efficiency: 0.7,
                                  swh_capacity_kW: 100.0,
                                  swh_fuel: 'NaturalGas',
                                  swh_parasitic_fuel_consumption_rate: 1.0}
                      }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    
    # Set the expected results filename.
    file_root = "#{self.class.name}-#{__method__}".downcase
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results = JSON.parse(File.read(file_name), {symbolize_names: true})
  
    # Create empty results hash and call the template method that runs the individual test cases.
    test_results = do_test_cases(test_cases: test_cases, test_pars: test_parameters)

    # Write test results.
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Check if test results match expected.
    msg = "Boiler efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')

    logger.info "Finished suite of tests for: #{__method__}"
  end
  
  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_swh_curves that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_swh_curves(test_pars:, test_case:)
    
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:TestMethod]
    save_intermediate_models = test_pars[:SaveIntermediateModels]
    heating_coil_type = test_pars[:heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    fuel_type = test_pars[:fuel_type]
    vintage = test_pars[:vintage]

    # Test specific inputs.
    swh_volume_L = test_case[:swh_volume_L].to_f
    swh_temperature_degC = test_case[:swh_temperature_degC].to_f
    swh_pump_head = test_case[:swh_pump_head].to_f
    swh_pump_motor_efficiency = test_case[:swh_pump_motor_efficiency].to_f
    swh_capacity_kW = test_case[:swh_capacity_kW].to_f
    swh_fuel = test_case[:swh_fuel]
    swh_parasitic_fuel_consumption_rate = test_case[:swh_parasitic_fuel_consumption_rate].to_f

    # Define the test name. 
    name = "#{vintage}-swh_#{swh_capacity_kW.round(0)}kW-swh_fuel_#{swh_fuel}"
    name_short = "#{vintage}-swh_#{swh_capacity_kW.round(0)}kW-#{swh_fuel}"
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"
    results = Hash.new

    # Wrap test in begin/rescue/ensure.
    begin

      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

      # Add SWH loop.
      standard = get_standard(vintage)
      standard.model_add_swh_loop(model,
                        'Main Service Water Loop',
                        nil,
                        swh_temperature_degC,
                        swh_pump_head,
                        swh_pump_motor_efficiency,
                        (swh_capacity_kW*1000.0),
                        (swh_volume_L/1000.0),
                        swh_fuel,
                        swh_parasitic_fuel_consumption_rate)

      # Add hvac system.
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model,hw_loop, fuel_type, always_on)
      standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                  zones: model.getThermalZones,
                                                                                                  heating_coil_type: heating_coil_type,
                                                                                                  baseboard_type: baseboard_type,
                                                                                                  hw_loop: hw_loop,
                                                                                                  new_auto_zoner: false)

      # Run sizing. 
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS
    rescue => error
      msg = "#{__FILE__}::#{__method__} #{error.message}"
      logger.error(msg)
      return {ERROR: msg}
    end

    # Extract standards generated part-load performance curve.
    shw_units = model.getWaterHeaterMixeds
    shw_plfvsplr_curve = shw_units[0].partLoadFactorCurve.get
    results = get_curve_info(shw_plfvsplr_curve)
    
    logger.info "Completed individual test: #{name}"
    return results
  end

  # Test to validate efficiency and standby losses of service water heater.
  def no_test_swh_eff_standby_losses
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters.
    test_parameters = {TestMethod: __method__,
                       SaveIntermediateModels: true,
                       fuel_type: 'Electricity',
                       heating_coil_type: 'DX',
                       baseboard_type: 'Hot Water'}

    # Define test cases. 
    test_cases = Hash.new

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = {Reference: 'NECB 2011 xxx'}
    
    # Results and name are tbd here as they will be calculated in the test.
    test_cases_hash = {vintage: ['NECB2011', 'NECB2020'], #@AllTemplates, 
                       swh_capacity_kW: [10.0, 20.0, 30.0, 40.0],
                       swh_volume_L: [200.0, 300.0, 500.0],
                       swh_fuel: ['Electricity', 'NaturalGas'],
                       TestCase: ['Case 1'], 
                       TestPars: {swh_temperature_degC: 60.0,
                                  swh_pump_head: 1.0,
                                  swh_pump_motor_efficiency: 0.7,
                                  swh_parasitic_fuel_consumption_rate: 1.0}
                      }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    
    # Set the expected results filename.
    file_root = "#{self.class.name}-#{__method__}".downcase
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results = JSON.parse(File.read(file_name), {symbolize_names: true})
  
    # Create empty results hash and call the template method that runs the individual test cases.
    test_results = do_test_cases(test_cases: test_cases, test_pars: test_parameters)

    # Write test results.
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Check if test results match expected.
    msg = "Boiler efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')

    logger.info "Finished suite of tests for: #{__method__}"
  end
  
  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_swh_eff_standby_losses that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_swh_eff_standby_losses(test_pars:, test_case:)
    
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:TestMethod]
    save_intermediate_models = test_pars[:SaveIntermediateModels]
    heating_coil_type = test_pars[:heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    fuel_type = test_pars[:fuel_type]

    # Varying inputs.
    vintage = test_pars[:vintage]
    swh_capacity_kW = test_pars[:swh_capacity_kW].to_f
    swh_volume_L = test_pars[:swh_volume_L].to_f
    swh_fuel = test_pars[:swh_fuel]

    # Test specific constant inputs.
    swh_temperature_degC = test_case[:swh_temperature_degC].to_f
    swh_pump_head = test_case[:swh_pump_head].to_f
    swh_pump_motor_efficiency = test_case[:swh_pump_motor_efficiency].to_f
    swh_parasitic_fuel_consumption_rate = test_case[:swh_parasitic_fuel_consumption_rate].to_f

    # Define the test name. 
    name = "#{vintage}-swh_#{swh_capacity_kW.round(0)}kW-volume_#{swh_volume_L}L"
    name_short = "#{vintage}-#{swh_capacity_kW.round(0)}kW-#{swh_volume_L}L"
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"
    results = Hash.new

    # Wrap test in begin/rescue/ensure.
    begin
    
      # Create model and remove HVAC and unused objects (add in whats required below).
      standard = get_standard(vintage)
      model = standard.model_create_prototype_model(template: vintage,
                                                    building_type: 'SmallOffice',
                                                    epw_file: 'CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw',
                                                    sizing_run_dir: output_folder,
                                                    primary_heating_fuel: fuel_type)
      standard.remove_all_hvac(model)
      model.purgeUnusedResourceObjects
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models
      
      # Add a service water heater loop.
      standard.model_add_swh_loop(model,
                                  'Main Service Water Loop',
                                  nil,
                                  swh_temperature_degC,
                                  swh_pump_head,
                                  swh_pump_motor_efficiency,
                                  (swh_capacity_kW*1000.0),
                                  (swh_volume_L/1000.0),
                                  swh_fuel,
                                  swh_parasitic_fuel_consumption_rate)

      # Set volume and capacity of water tank.
      swh_units = model.getWaterHeaterMixeds
      swh_units.each do |unit|
        unit.setHeaterMaximumCapacity(swh_capacity_kW*1000.0)
        unit.setTankVolume(swh_volume_L/1000.0)
      end

      # Run sizing. 
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS
    rescue => error
      msg = "#{__FILE__}::#{__method__} #{error.message}"
      logger.error(msg)
      return {ERROR: msg}
    end

    # Extract the results.
    unit_count = 0
    swh_units = model.getWaterHeaterMixeds
    swh_units.each do |unit|
      unit_count += 1
      swh_tank_eff = unit.heaterThermalEfficiency.to_f
      swh_tank_vol = unit.tankVolume.to_f
      swh_tank_cap = unit.heaterMaximumCapacity.to_f
      offcycle_ua = unit.offCycleLossCoefficienttoAmbientTemperature.to_f
      oncycle_ua = unit.onCycleLossCoefficienttoAmbientTemperature.to_f
      unitID = "SWH_unit-#{unit_count}"
      results[unitID.to_sym] = {
        name: unit.name.to_s,
        volume_L: (swh_tank_vol*1000.0).signif(3),
        capacity_kW: (swh_tank_cap/1000.0).signif(3),
        efficiency: swh_tank_eff.signif(3),
        off_cycle_UA_WperK: offcycle_ua.signif(4),
        on_cycle_UA_WperK: oncycle_ua.signif(4)
      }
    end
    
    logger.info "Completed individual test: #{name}"
    return results
  end


  # Test to validate efficiency and standby losses of GAS shw heater (NECB 2020)
  def test_NECB2020_swh_gas_efficiency_standby_losses

    # Set up remaining parameters for test.
    template='NECB2020'
    standard = get_standard(template)
    save_intermediate_models = false

    # Test space types - SWH demand depends on space type + space area.
    test_spacetypes = ["Office enclosed <= 25 m2"] #, "Health care facility operating room", "Museum general exhibition area", "Conference/Meeting/Multi-purpose room", \
    #"Warehouse storage area medium to bulky palletized items", "Transportation facility baggage/carousel area", "Audience seating area permanent - gymnasium",\
    #"Computer/Server room-sch-C", "Gymnasium/Fitness centre playing area", "Retail facility mall concourse"]

    test_spacetypes.each do |test_spacetype|
      name = "shw_for_#{test_spacetype}"
      name.to_s.gsub!(/\s+/, "-")
      puts "***************#{name}***************\n"
      output_folder = method_output_folder("#{__method__}/#{name}")

      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "5ZoneNoHVAC5Storeys.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

      # Set spacetype.
      model.getSpaces.each do |space|
        st = OpenStudio::Model::SpaceType.new(model)
        st.setStandardsBuildingType("Space Function")
        st.setStandardsSpaceType(test_spacetype)
        st.setName("#{"Space Function"} #{test_spacetype}")
        space.setSpaceType(st)
      end

      # Add SWH loop.
      swh_capacity_kW = 20.0
      swh_volume_L = 300.0
      standard.model_add_swh_loop(model,
                        'Main Service Water Loop',
                        nil,
                        60.0,
                        1.0,
                        0.7,
                        (swh_capacity_kW*1000.0),
                        (swh_volume_L/1000.0),
                        'NaturalGas',
                        1.0)

      # Add HVAC system.
      fuel_type = 'NaturalGas'
      baseboard_type = 'Hot Water'
      heating_coil_type = 'DX'
      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model,hw_loop, fuel_type, always_on)
      standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(model: model,
                                                                                                  zones: model.getThermalZones,
                                                                                                  heating_coil_type: heating_coil_type,
                                                                                                  baseboard_type: baseboard_type,
                                                                                                  hw_loop: hw_loop,
                                                                                                  new_auto_zoner: false)

      # Set volume and capacity of water tank.
      swh_units = model.getWaterHeaterMixeds
      swh_units.each do |unit|
        unit.setHeaterMaximumCapacity(swh_capacity_kW*1000.0)
        unit.setTankVolume(swh_volume_L/1000.0)
      end
      # Run sizing.
      run_sizing(model: model, template: template, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS
    
      # Get standard water tank efficiency and standby losses.
      shw_units = model.getWaterHeaterMixeds
      shw_units.each do |unit|
        puts "shw_units #{unit}"
      end
      icap = (shw_units[0].heaterMaximumCapacity.get.to_f)/1000.0 # kW
      puts "icap #{icap} kW"
      ivol = (shw_units[0].tankVolume.get.to_f)*1000.0 # Litres
      puts "ivol #{ivol} L"
      actual_shw_tank_eff = shw_units[0].heaterThermalEfficiency.to_f
      #actual_shw_tank_vol = shw_units[0].tankVolume.to_f
      actual_offcycle_ua = shw_units[0].offCycleLossCoefficienttoAmbientTemperature.to_f
      actual_oncycle_ua = shw_units[0].onCycleLossCoefficienttoAmbientTemperature.to_f
      puts "actual_oncycle_ua #{actual_oncycle_ua}"
      vol_gal = OpenStudio.convert(ivol/1000.0, 'm^3', 'gal').get

      # Complete local calculation of efficiency and losses (using SI units)
        # 1. calc FHR
        # 2a. Set water heater thermal efficiency (burner efficiency), calc UEF, then UA (skin loss) OR
        # 2b. Calc SL, then UA (skin loss), followed by water heater thermal efficiency (burner efficiency)

      # Calc FHR.
      tank_param = standard.auto_size_shw_capacity(model:model, shw_scale: 'NECB_Default')
      fhr_L_per_hr = (tank_param['loop_peak_flow_rate_SI']) * 3600000
      puts "Calculate UA   ========================================== "
      shw_units = model.getWaterHeaterMixeds
      actual_oncycle_ua = shw_units[0].onCycleLossCoefficienttoAmbientTemperature.to_f
      puts "actual_oncycle_ua #{actual_oncycle_ua}"
      puts "fhr_L_per_hr #{fhr_L_per_hr} L/hr"
      puts "icap #{icap} kW"
      puts "ivol #{ivol} L; (=#{vol_gal} gal)"

      # Select UA and burner efficiency estimation method based on tank volume and heating capacity.
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

      # Check accuracy of parameters.
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

end

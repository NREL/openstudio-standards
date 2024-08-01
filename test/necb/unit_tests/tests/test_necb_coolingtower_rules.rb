require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Cooling_Tower_Tests < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate NECB2011 rules for cooling tower:
  # "if capacity <= 1750 kW ---> one cell
  # if capacity > 1750 kW ---> number of cells = capacity/1750 rounded up"
  # power = 0.015 x capacity in kW
  def test_number_of_coolingtowers
    logger.info "Starting suite of tests for: #{__method__}"

    # Define static test parameters.
    test_parameters = {test_method: __method__,
                       save_intermediate_models: true,
                       boiler_fueltype: 'Electricity',
                       heating_coil_type: 'Hot Water',
                       baseboard_type: 'Hot Water',
                       fan_type: 'AF_or_BI_rdg_fancurve'}

    # Define test cases. 
    test_cases = Hash.new

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = {:Reference => "NECB 2011 p3 xxx"}
    
    # Test cases. Three cases for NG and FuelOil, one for Electric.
    # Results and name are tbd here as they will be calculated in the test.
    test_cases_hash = {:Vintage => ["NECB2011"], 
                       :chiller_types => ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating'],
                       :TestCase => ["Single"], 
                       :TestPars => {:tested_capacity_kW => 1500}}
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = {:Vintage => ["NECB2011"], 
                       :chiller_types => ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating'],
                       :TestCase => ["Twin"], 
                       :TestPars => {:tested_capacity_kW => 2500}}
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    # Create empty results hash and call the template method that runs the individual test cases.
    test_results = do_test_cases(test_cases: test_cases, test_pars: test_parameters)

    # Write test results.
    file_root = "#{self.class.name}-#{__method__}".downcase
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Read expected results. 
    file_root = "#{self.class.name}-#{__method__}".downcase
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results = JSON.parse(File.read(file_name), {symbolize_names: true})
  
    # Check if test results match expected.
    msg = "Numbrer of cooling towers do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')

    logger.info "Finished suite of tests for: #{__method__}"
  end
  
  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_number_of_coolingtowers that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_number_of_coolingtowers(test_pars:, test_case:)
    
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    mau_type = test_pars[:mau_type]
    heating_coil_type = test_pars[:heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    boiler_fueltype = test_pars[:FuelType]
    vintage = test_pars[:Vintage]

    # Test specific inputs.
    total_boiler_cap = test_case[:tested_capacity_kW]

    # Set up remaining parameters for test.
    template = "NECB2011"
    standard = get_standard(template)
    save_intermediate_models = false
    

    first_cutoff_twr_cap = 1750000.0
    tol = 1.0e-3
    # Generate the osm files for all relevant cases to generate the test data for system 6
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating']
    fan_type = 'AF_or_BI_rdg_fancurve'
    test_chiller_cap = [1000000.0, 4000000.0]
    clgtowerFanPowerFr = 0.015
    designInletTwb = 24.0
    designApproachTemperature = 5.0
    chiller_types.each do |chiller_type|
      test_chiller_cap.each do |chiller_cap|
        name = "sys6_#{template}_ChillerType_#{chiller_type}-#{chiller_cap}watts"
        name_short = "#{chiller_type}_sys6"
        output_folder = method_output_folder("#{test_name}/#{name_short}")
        logger.info "Started individual test: #{name}"

        # Load model and set climate file.
        model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
        BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
        BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm") if save_intermediate_models

        hw_loop = OpenStudio::Model::PlantLoop.new(model)
        always_on = model.alwaysOnDiscreteSchedule
        standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
        standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                            zones: model.getThermalZones,
                                                                            heating_coil_type: heating_coil_type,
                                                                            baseboard_type: baseboard_type,
                                                                            chiller_type: chiller_type,
                                                                            fan_type: fan_type,
                                                                            hw_loop: hw_loop)
        # Save the model after btap hvac.
        BTAP::FileIO.save_osm(model, "#{output_folder}/hvacrb")
        model.getChillerElectricEIRs.each { |ichiller| ichiller.setReferenceCapacity(chiller_cap) }

        # Run the measure.
        run_sizing(model: model, template: template, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS

        necb2011_refCOP = 5.0
        model.getChillerElectricEIRs.each do |ichiller|
          if ichiller.name.to_s.include? 'Primary' then necb2011_refCOP = ichiller.referenceCOP end
        end
        tower_cap = chiller_cap * (1.0 + 1.0/necb2011_refCOP)
        this_is_the_first_cap_range = false
        this_is_the_second_cap_range = false
        if tower_cap < first_cutoff_twr_cap
          this_is_the_first_cap_range = true
        else
          this_is_the_second_cap_range = true
        end
        
        # Compare tower number of cells to expected value.
        tower = model.getCoolingTowerSingleSpeeds[0]
        num_of_cells_is_correct = false
        if this_is_the_first_cap_range
          necb2011_num_cells = 1
        elsif this_is_the_second_cap_range
          necb2011_num_cells = (tower_cap/first_cutoff_twr_cap + 0.5).round
        end
        if tower.numberofCells == necb2011_num_cells then num_of_cells_is_correct = true end
        assert(num_of_cells_is_correct, "Tower number of cells is not correct based on #{template}")
        
        # Compare the fan power to expected value.
        fan_power = clgtowerFanPowerFr * tower_cap
        tower_fan_power_is_correct = false
        rel_diff = (fan_power - tower.fanPoweratDesignAirFlowRate.to_f).abs/fan_power
        if rel_diff < tol then tower_fan_power_is_correct = true end
        assert(tower_fan_power_is_correct, "Tower fan power is not correct based on #{template}")
        
        # Compare design inlet wetbulb to expected value.
        tower_Twb_is_correct = false
        rel_diff = (tower.designInletAirWetBulbTemperature.to_f - designInletTwb).abs/designInletTwb
        if rel_diff < tol then tower_Twb_is_correct = true end
        assert(tower_Twb_is_correct, "Tower inlet wet-bulb is not correct based on #{template}")
        
        # Compare design approach temperature to expected value.
        tower_appT_is_correct = false
        rel_diff = (tower.designApproachTemperature.to_f - designApproachTemperature).abs/designApproachTemperature
        if rel_diff < tol then tower_appT_is_correct = true end
        assert(tower_appT_is_correct, "Tower approach temperature is not correct based on #{template}")
      end
    end
  end

  # NECB2015 rules for cooling tower.
  # power = 0.013 x capacity in kW.
  def test_coolingtower_power

    # General inputs.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]

    # Set up remaining parameters for test.
    template = 'NECB2015'
    standard = get_standard(template)

    # Generate the osm files for all relevant cases to generate the test data for system 6.
    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_types = ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating']
    heating_coil_type = 'Hot Water'
    fan_type = 'AF_or_BI_rdg_fancurve'
    chiller_cap = 1000000.0
    clgtowerFanPowerFr = 0.013

    chiller_types.each do |chiller_type|
      name = "sys6_#{template}_ChillerType_#{chiller_type}-#{chiller_cap}watts"
      name_short = "#{chiller_type}_sys6"
      output_folder = method_output_folder("#{test_name}/#{name_short}")
      logger.info "Started individual test: #{name}"

      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      BTAP::Environment::WeatherFile.new('CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw').set_weather_file(model)
      BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
      standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                          zones: model.getThermalZones,
                                                                          heating_coil_type: heating_coil_type,
                                                                          baseboard_type: baseboard_type,
                                                                          chiller_type: chiller_type,
                                                                          fan_type: fan_type,
                                                                          hw_loop: hw_loop)
      model.getChillerElectricEIRs.each { |ichiller| ichiller.setReferenceCapacity(chiller_cap) }

      # Run sizing.
      run_sizing(model: model, template: template, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS

      refCOP = 5.0
      model.getChillerElectricEIRs.each do |ichiller|
        if ichiller.name.to_s.include? 'Primary' then refCOP = ichiller.referenceCOP end
      end
      tower_cap = chiller_cap * (1.0 + 1.0/refCOP)
      
      # Compare the fan power to expected value.
      tol = 1.0e-3
      fan_power = clgtowerFanPowerFr * tower_cap
      tower_fan_power_is_correct = false
      tower = model.getCoolingTowerSingleSpeeds[0]
      rel_diff = (fan_power - tower.fanPoweratDesignAirFlowRate.to_f).abs/fan_power
      if rel_diff < tol then tower_fan_power_is_correct = true end
      assert(tower_fan_power_is_correct, "Tower fan power is not correct based on #{template}")
    end
  end

end

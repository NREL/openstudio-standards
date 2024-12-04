require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_HVAC_Cooling_Tower_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate NECB2011 rules for cooling tower:
  # "if capacity <= 1750 kW ---> one cell
  # if capacity > 1750 kW ---> number of cells = capacity/1750 rounded up"
  # power = 0.015 x capacity in kW
  def test_coolingtowers
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
    test_cases[:NECB2015] = {:Reference => "NECB 2015 p3 xxx"}
    
    # Test cases. Three cases for NG and FuelOil, one for Electric.
    # Results and name are tbd here as they will be calculated in the test.
    test_cases_hash = {:Vintage => ["NECB2011"], 
                       :chiller_types => ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating'],
                       :TestCase => ["Single"], 
                       :TestPars => {:tested_capacity_kW => 1000,
                                     :clgtowerFanPowerFr => 0.015,
                                     :designInletTwb => 24.0,
                                     :designApproachT => 5.0}}
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = {:Vintage => ["NECB2011"], 
                       :chiller_types => ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating'],
                       :TestCase => ["Twin"], 
                       :TestPars => {:tested_capacity_kW => 4000,
                                     :clgtowerFanPowerFr => 0.015,
                                     :designInletTwb => 24.0,
                                     :designApproachT => 5.0}}
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = {:Vintage => ["NECB2015"], 
                       :chiller_types => ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating'],
                       :TestCase => ["Single"], 
                       :TestPars => {:tested_capacity_kW => 1000,
                                     :clgtowerFanPowerFr => 0.013,
                                     :designInletTwb => 24.0,
                                     :designApproachT => 5.0}}
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_cases_hash = {:Vintage => ["NECB2015"], 
                       :chiller_types => ['Scroll', 'Centrifugal', 'Rotary Screw', 'Reciprocating'],
                       :TestCase => ["Twin"], 
                       :TestPars => {:tested_capacity_kW => 4000,
                                     :clgtowerFanPowerFr => 0.013,
                                     :designInletTwb => 24.0,
                                     :designApproachT => 5.0}}
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
  def do_test_coolingtowers(test_pars:, test_case:)
    
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    heating_coil_type = test_pars[:heating_coil_type]
    baseboard_type = test_pars[:baseboard_type]
    boiler_fueltype = test_pars[:boiler_fueltype]
    fan_type = test_pars[:fan_type]
    vintage = test_pars[:Vintage]
    chiller_type = test_pars[:chiller_types]

    # Test specific inputs.
    chiller_cap = test_case[:tested_capacity_kW]
    clgtowerFanPowerFr = test_case[:clgtowerFanPowerFr]
    designInletTwb = test_case[:designInletTwb]
    designApproachTemperature = test_case[:designApproachT]
    
    # Define the test name. 
    name = "sys6_#{vintage}_ChillerType_#{chiller_type}-#{chiller_cap}kW"
    name_short = "#{chiller_type}_sys6"
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"
    results = Hash.new

    # Wrap test in begin/rescue/ensure.
    begin

      #test_chiller_cap = [1 000 000.0, 4 000 000.0]

      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

      hw_loop = OpenStudio::Model::PlantLoop.new(model)
      always_on = model.alwaysOnDiscreteSchedule
      standard = get_standard(vintage)
      standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, always_on)
      standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(model: model,
                                                                          zones: model.getThermalZones,
                                                                          heating_coil_type: heating_coil_type,
                                                                          baseboard_type: baseboard_type,
                                                                          chiller_type: chiller_type,
                                                                          fan_type: fan_type,
                                                                          hw_loop: hw_loop)

      # Set the chiller capacity, remember to convert to W.
      model.getChillerElectricEIRs.each { |ichiller| ichiller.setReferenceCapacity(chiller_cap*1000.0) }

      # Run the measure.
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS
    rescue => error
      msg = "#{__FILE__}::#{__method__} #{error.message}"
      logger.error(msg)
      return {ERROR: msg}
    end
    
    # Calculate the tower capacity.
    refCOP = 5.0
    model.getChillerElectricEIRs.each do |ichiller|
      if ichiller.name.to_s.include? 'Primary' then refCOP = ichiller.referenceCOP end
    end
    tower_cap = chiller_cap * (1.0 + 1.0/refCOP)
    fan_power = clgtowerFanPowerFr * tower_cap
    
    # Get the tower(s) and calculate output metrics.
    tower_results = Hash.new
    model.getCoolingTowerSingleSpeeds.each do |tower|
      tower_Twb = tower.designInletAirWetBulbTemperature.to_f
      tower_appT = tower.designApproachTemperature.to_f

    # Add this test case to results and return the hash.
      tower_results[tower.name.to_s.to_sym] = {
        tower_capacity_kW: tower_cap.signif,
        number_of_cells: tower.numberofCells,
        fan_power: fan_power.signif(3),
        design_inlet_Twb_degC: tower_Twb.signif(3),
        design_approach_T_degC: tower_appT.signif(3)
      }
    end
    results = {
      name: name,
      tested_capacity_kW: chiller_cap.signif,
      reference_COP: refCOP.signif(3),
      tower_results: tower_results    
    }

    logger.info "Completed individual test: #{name}"
    return results
  end

end

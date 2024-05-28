require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

class NECB_HVAC_Ventilation_Tests < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate the ventilation requirements.
  # Makes use of the template design pattern with the work done by the do_* method below (i.e. 'do_' prepended to the current method name)

  def test_ventilation
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all tests.
    test_parameters = { test_method: __method__,
                        save_intermediate_models: true,
                        fueltype: 'Electricity' }
    # Define test cases.
    test_cases = {}

    test_cases_hash = {
      :Vintage => @AllTemplates,
      :BuildingType => @AllBuildings,
      :TestCase => ["Case1"],
      :TestPars => { :oaf => "tbd" }
    }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)

    # Create empty results hash and call the template method that runs the individual test cases.
    test_results = do_test_cases(test_cases: test_cases, test_pars: test_parameters)

    # Write test results.
    file_root = "#{self.class.name}-#{__method__}".downcase
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))
    # Read expected results.
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results = JSON.parse(File.read(file_name), { symbolize_names: true })
    # Check if test results match expected.
    msg = "Ventilation test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_ventilation that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_ventilation(test_pars:, test_case:)
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"
    # Define local variables. These are extracted from the supplied hashes.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    fueltype = test_pars[:fueltype]
    vintage = test_pars[:Vintage]
    building_type = test_pars[:BuildingType]
    name = "#{vintage}_building_type_#{building_type}_ventilation"
    name_short = "#{vintage}_#{building_type}_ventilation"
    output_folder = method_output_folder("#{test_name}/#{name_short}/")
    logger.info "Starting individual test: #{name}"
	
	# Create a directory to save a text file listing all the failed cases
    failed_model_dir = File.join(@top_output_folder, test_name.to_s)
    Dir.mkdir(failed_model_dir) unless Dir.exist?(failed_model_dir)
    # Wrap test in begin/rescue/ensure.
    begin
      epw_file = "CAN_ON_Toronto.Pearson.Intl.AP.716240_CWEC2016.epw"
      standard = get_standard(vintage)
      model = standard.model_create_prototype_model(template: vintage,
                                                    building_type: building_type,
                                                    epw_file: epw_file,
                                                    primary_heating_fuel: fueltype,
                                                    sizing_run_dir: output_folder)
													
    rescue StandardError => error
     # Create a txt file to indicate the buildings with failed model creation.
      File.open(File.join(failed_model_dir, 'model_creation_failed.txt'), 'a') do |file|
        file.write("Model creation failed for #{vintage} #{building_type}\n")
      end
      logger.error "#{__FILE__}::#{__method__} #{error.message}"
      return {}
    end

    # Extract the results for checking.
    results = Hash.new
    air_loops_hvac = model.getAirLoopHVACs
    air_loops_hvac.each do |air_loop_hvac|
      zones = air_loop_hvac.thermalZones
      zones.each do |zone|
        zone_name = zone.name.get
        query = "SELECT Value FROM tabulardatawithstrings WHERE ReportName='Standard62.1Summary' and TableName='Zone Ventilation Parameters' and RowName= '#{zone_name.to_s.upcase}' and ColumnName= 'Breathing Zone Outdoor Airflow - Vbz'"
        rate = model.sqlFile.get.execAndReturnFirstDouble(query)
        vbz_rate = rate.to_f
        spaces = zone.spaces
        spaces.each do |space|
          space_type = space.spaceType.get
          outdoor_air = space_type.designSpecificationOutdoorAir.get
          # Initialize variables
          oa_flow_per_floor_area = 0.0
          oa_flow_per_person = 0.0

          # Assign values conditionally
          oa_flow_per_floor_area = outdoor_air.outdoorAirFlowperFloorArea if outdoor_air.outdoorAirFlowperFloorArea > 0.0
          oa_flow_in_ft3_per_min_per_ft2 = OpenStudio.convert(oa_flow_per_floor_area, 'm^3/s*m^2', 'ft^3/min*ft^2').get

          oa_flow_per_person = outdoor_air.outdoorAirFlowperPerson if outdoor_air.outdoorAirFlowperPerson > 0.0
          oa_flow_in_ft3_per_min_per_person = OpenStudio.convert(oa_flow_per_person, 'm^3/s*person', 'ft^3/min*person').get

          zone_area = zone.floorArea
          zone_num_people = zone.numberOfPeople
          calculated_ventilation_rate = (zone_num_people * oa_flow_per_person + zone_area * oa_flow_per_floor_area) * zone.multiplier
          calculated_ventilation_rate_ft3_per_min = OpenStudio.convert(calculated_ventilation_rate, 'm^3/s', 'ft^3/min').get

          # For debugging check if the difference is within the tolerance of 0.1 cfm.
          File.open(File.join(failed_model_dir, 'ventilation_rate_error.txt'), 'a') { |file| file.write("Ventilation rate error for #{zone_name} calculated_ventilation_rate: #{calculated_ventilation_rate.signif(3)} vbz_rate: #{vbz_rate.signif(3)}") } if (calculated_ventilation_rate.signif(3) - vbz_rate.signif(3)).abs > 0.1
         
          # Add this test case to results and return the hash.
          results[zone_name] = {
            zone_area_m2: zone_area.signif(3),
            zone_num_people: zone_num_people.signif(3),
            oa_flow_in_ft3_per_min_per_person: oa_flow_in_ft3_per_min_per_person.signif(3),
            oa_flow_in_ft3_per_min_per_ft2: oa_flow_in_ft3_per_min_per_ft2.signif(3),
            calculated_ventilation_rate_ft3_per_min: calculated_ventilation_rate_ft3_per_min.signif(3),
            calculated_ventilation_rate_m3_per_s: calculated_ventilation_rate.signif(3),
            sql_vbz_rate_m3_per_s: vbz_rate.signif(3)
          }
        end
      end
    end
    logger.info "Completed individual test: #{name}"
    return results
  end
end
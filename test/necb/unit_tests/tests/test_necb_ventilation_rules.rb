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
      :SpaceType => @SpaceTypes,
      :TestCase => ["ZoneResults"],
      :TestPars => {  } # :oaf => "tbd"
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
    space_type = test_pars[:SpaceType]

    name = "#{vintage}_building_type_#{space_type}_ventilation"
    name_short = "#{vintage}_#{space_type}"
    output_folder = method_output_folder("#{test_name}/#{name_short}/")
    logger.info "Starting individual test: #{name}"
    results = Array.new
	
    # (1) load 5 zone model
    # (2) loop through space types in the model and change them to the desired space type
    # (3) call standard.model_add_loads(model, 'NECB_Default', 1.0) (or call standard.apply_loads(model: model))
    # (4) check ventilation

    # Wrap test in begin/rescue/ensure.
    begin
      # Create model and set climate file.
      # Load model and set climate file.
      model = BTAP::FileIO.load_osm(File.join(@resources_folder, "fsr.osm"))
      weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
      OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
      BTAP::FileIO.save_osm(model, "#{output_folder}/baseline.osm") if save_intermediate_models

      # Create a new space type and assign it to the spaces in the model.
      test_spacetype = OpenStudio::Model::SpaceType.new(model)
      test_spacetype.setStandardsBuildingType('Space Function')
      test_spacetype.setStandardsSpaceType(space_type)
      test_spacetype.setName("Space Function #{space_type}") # NRCan use setNameProtected in the water heating test.
      logger.info "Looping through spaces:"
      model.getSpaces.each do |space|
        logger.info "  Space: #{space.name}"
        space.setSpaceType(test_spacetype)
        logger.info "  New spacetype: #{test_spacetype}"
      end

      # Map space type name to match current vintage. 
      standard = get_standard(vintage)
      standard.validate_and_upate_space_types(model)

      # Recover the vintage and set the ventilation rate
      #standard.apply_loads(model: model) # 
      standard.model_add_loads(model, 'NECB_Default', 1.0)
      
      # Run the standards as we need a result file for the analysis.
      run_sizing(model: model, template: vintage, save_model_versions: save_intermediate_models, output_dir: output_folder) if PERFORM_STANDARDS

    rescue StandardError => error
      msg = "Model creation failed for #{vintage} #{space_type}\n#{__FILE__}::#{__method__} #{error.message}"
      logger.error(msg)
      return [ERROR: msg]
    end

    # Extract the results for checking.
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

          # Initialize variables.
          oa_flow_per_floor_area = 0.0
          oa_flow_per_person = 0.0
          if space_type.designSpecificationOutdoorAir.is_initialized then 
            outdoor_air = space_type.designSpecificationOutdoorAir.get
            oa_flow_per_floor_area = outdoor_air.outdoorAirFlowperFloorArea if outdoor_air.outdoorAirFlowperFloorArea > 0.0
            oa_flow_per_person = outdoor_air.outdoorAirFlowperPerson if outdoor_air.outdoorAirFlowperPerson > 0.0
          end
          
          # Convert values so we have both common units in the output.
          oa_flow_in_ft3_per_min_per_ft2 = OpenStudio.convert(oa_flow_per_floor_area, 'm^3/s*m^2', 'ft^3/min*ft^2').get
          oa_flow_in_ft3_per_min_per_person = OpenStudio.convert(oa_flow_per_person, 'm^3/s*person', 'ft^3/min*person').get

          # Recover zone variables.
          zone_area = zone.floorArea
          zone_area_ft2 = OpenStudio.convert(zone_area, 'm^2', 'ft^2').get
          zone_num_people = zone.numberOfPeople

          # Calculate expected ventilation rate.
          calculated_ventilation_rate = (zone_num_people * oa_flow_per_person + zone_area * oa_flow_per_floor_area) * zone.multiplier
          calculated_ventilation_rate_ft3_per_min = OpenStudio.convert(calculated_ventilation_rate, 'm^3/s', 'ft^3/min').get
          
          # Add this test case to results and return the array.
          results << {
            zone_name: zone_name,
            space_type_name: space_type.name,
            std_oa_flow_per_floor_area: oa_flow_per_floor_area.signif(3),
            std_oa_flow_per_person: oa_flow_per_person.signif(3),
            zone_area_m2: zone_area.signif(3),
            zone_area_ft2: zone_area_ft2.signif(3),
            zone_num_people: zone_num_people.signif(3),
            NECB_occ_density_per_1000ft2: (1000.0/(zone_area_ft2/zone_num_people)).signif(3),
            NECB_occ_density_m2_per_occupant: (OpenStudio.convert((zone_area_ft2/zone_num_people), 'ft^2', 'm^2')).get.signif(2),
            oa_flow_cfm_per_person: oa_flow_in_ft3_per_min_per_person.signif(3),
            oa_flow_cfm_per_ft2: oa_flow_in_ft3_per_min_per_ft2.signif(3),
            calculated_ventilation_rate_cfm: calculated_ventilation_rate_ft3_per_min.signif(3),
            calculated_ventilation_rate_m3_per_s: calculated_ventilation_rate.signif(3),
            sql_vbz_rate_m3_per_s: vbz_rate.signif(3)
          }
        end
      end
    end
    logger.info "Completed individual test: #{name}"

	  # Sort results hash by name (the diff algorithm does not work well for arrays of hashes)
    return results.sort_by {|e| e[:zone_name]}
  end
end

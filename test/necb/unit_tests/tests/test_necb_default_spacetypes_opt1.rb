require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

# This class will perform tests that are Spacetype dependant, Test model will be created
# to specifically test aspects of the NECB2011 code that are Spacetype dependant.
class NECB_Default_SpaceTypes_Tests < Minitest::Test
  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Tests to ensure that the NECB default schedules are being defined correctly.
  # This is not for compliance, but for archetype development.
  # @return [Boolean] true if successful.
  def test_schedule_type_defaults
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters that apply to all tests.
    test_parameters = {
      test_method: __method__,
      save_intermediate_models: true
    }

    # Define test cases.
    test_cases = {}

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = { :Reference => "NECB 2011 p3 Table 5.2.12.1" }

    # Test cases. Three cases for NG and FuelOil, one for Electric.
    # Results and name are tbd here as they will be calculated in the test.
    test_cases_hash = { :Vintage => @AllTemplates,
                        :SpaceType => @AllSpaceTypes,
                        :FuelType => ["Electricity"],
                        :TestCase => ["case-1"],
                        :TestPars => { :name => "tbd" }
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
    msg = "Schedule type defaults test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')
    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_boiler_efficiency that runs a specific test. Called by do_test_cases in necb_helper.rb.
  def do_test_schedule_type_defaults(test_pars:, test_case:)

    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"

    # Define local variables. These are extracted from the supplied hashes.
    # General inputs.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    fueltype = test_pars[:FuelType]
    vintage = test_pars[:Vintage]
    space_type = test_pars[:SpaceType]
    standard = get_standard(vintage)

    # Define the test name.
    name = "#{vintage}"
    name_short = "#{vintage}"
    results = {}
    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"
    puts "Starting individual test: #{name}"
    # Wrap test in begin/rescue/ensure.
    begin
      # Create new model for testing.
      model = OpenStudio::Model::Model.new
      # Create only above ground geometry (Used for infiltration tests)
      length = 100.0; width = 100.0; num_above_ground_floors = 1; num_under_ground_floors = 0; floor_to_floor_height = 3.8; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = 10.0
      BTAP::Geometry::Wizards::create_shape_rectangle(model, length, width, num_above_ground_floors, num_under_ground_floors, floor_to_floor_height, plenum_height, perimeter_zone_depth, initial_height)

      # Find the mapped space type.
      mapped_space_type = ""
      space_type_map = standard.standards_lookup_table_many(table_name: 'space_type_upgrade_map').detect do |row|
        if row["NECB2011_space_type"] == space_type
          mapped_space_type = row[vintage + "_space_type"]
        end
      end
      space_type = mapped_space_type

      # Define search criteria.
      search_criteria = {
        "template" => vintage,
        "space_type" => mapped_space_type
      }

      # Lookup space type properties.
      standards_table = standard.standards_data['space_types']
      standard.model_find_objects(standards_table, search_criteria).each do |space_type_properties|
        # Create a space type.
        st = OpenStudio::Model::SpaceType.new(model)
        st.setStandardsBuildingType(space_type_properties['building_type'])
        st.setStandardsSpaceType(space_type_properties['space_type'])
        st.setName("#{vintage}-#{space_type_properties['building_type']}-#{space_type_properties['space_type']}")
        standard.space_type_apply_rendering_color(st)
        standard.model_add_loads(model, 'NECB_Default', 1.0)

        # Set all spaces to spacetype.
        model.getSpaces.each do |space|
          space.setSpaceType(st)
        end

        # Add Infiltration rates to the space objects themselves.
        standard.model_apply_infiltration_standard(model)

        # Get handle for space.
        space = model.getSpaces[0]
        space_area = space.floorArea # m2

        # Lights.
        total_lpd = []
        lpd_sched = []
        occSensLPDfactor = 1.0
        if vintage == "NECB2011"
          # NECB2011 space types that require a reduction in the LPD to account for
          # the requirement of an occupancy sensor (8.4.4.6(3) and 4.2.2.2(2))
          reduceLPDSpaces = ["Classroom/lecture/training", "Conf./meet./multi-purpose", "Lounge/recreation",
                             "Conf./meet./multi-purpose", "Washroom-sch-A",
                             "Washroom-sch-B", "Washroom-sch-C", "Washroom-sch-D", "Washroom-sch-E", "Washroom-sch-F", "Washroom-sch-G",
                             "Washroom-sch-H", "Washroom-sch-I", "Dress./fitt. - performance arts", "Locker room", "Retail - dressing/fitting"]
          space_type_name = st.standardsSpaceType.get
          if reduceLPDSpaces.include?(space_type_name)
            occSensLPDfactor = 0.9
          elsif ((space_type_name == 'Storage area' && space_area < 100) ||
            (space_type_name == 'Storage area - refrigerated' && space_area < 100) ||
            (space_type_name == 'Office - enclosed' && space_area < 25))
            # Do nothing! In this case, we use the duplicate space type name appended with " - occsens"!
          end
        end

        st.lights.each { |light| total_lpd << light.powerPerFloorArea.get * occSensLPDfactor; lpd_sched << light.schedule.get.name }
        # Add a default value if total_lpd is empty
        if total_lpd.empty?
          total_lpd << 0.0
          lpd_sched << "NA" 
        end
        # Replace nil values in total_lpd
        total_lpd.each_with_index do |lpd_value, index|
          if lpd_value.nil?
            total_lpd[index] = 0.0
            lpd_sched[index] = "NA"
          end
        end

        # People / Occupancy.
        total_occ_dens = []
        occ_sched = []
        st.people.each { |people_def| total_occ_dens << people_def.peoplePerFloorArea.get; occ_sched << people_def.numberofPeopleSchedule.get.name }

        # Equipment - Gas.
        gas_equip_power = []
        gas_equip_sched = []
        st.gasEquipment.each { |gas_equip| gas_equip_power << gas_equip.powerPerFloorArea.get; gas_equip_sched << gas_equip.schedule.get.name }
        # Add a default value if gas_equip_power is empty
        if gas_equip_power.empty?
          gas_equip_power << 0.0
          gas_equip_sched << "NA" 
        end
        # Replace nil values in gas_equip_power
        gas_equip_power.each_with_index do |power_value, index|
          if power_value.nil?
            gas_equip_power[index] = 0.0
            gas_equip_sched[index] = "NA"
          end
        end

        # Equipment - Electric.
        elec_equip_power = []
        elec_equip_sched = []
        st.electricEquipment.each { |elec_equip| elec_equip_power << elec_equip.powerPerFloorArea.get; elec_equip_sched << elec_equip.schedule.get.name }
        # Add a default value if elec_equip_power is empty
        if elec_equip_power.empty?
          elec_equip_power << 0.0
          elec_equip_sched << "NA"
        end

        # Replace nil values in elec_equip_power
        elec_equip_power.each_with_index do |power_value, index|
          if power_value.nil?
            elec_equip_power[index] = 0.0
            elec_equip_sched[index] = "NA"
          end
        end

        # Equipment - Steam.
        steam_equip_power = []
        steam_equip_sched = []
        st.steamEquipment.each { |steam_equip| steam_equip_power << steam_equip.powerPerFloorArea.get; steam_equip_sched << steam_equip.schedule.get.name }
        # Check all values in the steam_equip_power array
        # Add a default value if steam_equip_power is empty
        if steam_equip_power.empty?
          steam_equip_power << 0.0
          steam_equip_sched << "NA"
        end
        steam_equip_power.each_with_index do |power_value, index|
          if power_value.nil?
            steam_equip_power[index] = 0.0
            steam_equip_sched[index] = "NA"
          end
        end

        # Equipment - Hot Water (not SWH is below).
        hw_equip_power = []
        hw_equip_sched = []
        st.hotWaterEquipment.each { |equip| hw_equip_power << equip.powerPerFloorArea.get; hw_equip_sched << equip.schedule.get.name }
        # Add a default value if hw_equip_power is empty
        if hw_equip_power.empty?
          hw_equip_power << 0.0
          hw_equip_sched << "NA" 
        end
        # Replace nil values in hw_equip_power
        hw_equip_power.each_with_index do |power_value, index|
          if power_value.nil?
            hw_equip_power[index] = 0.0
            hw_equip_sched[index] = "NA"
          end
        end

        # Equipment - Other.
        other_equip_power = []
        other_equip_sched = []
        st.otherEquipment.each { |equip| other_equip_power << equip.powerPerFloorArea.get; other_equip_sched << equip.schedule.get.name }

        # Equipment - SWH.
        swh_loop = OpenStudio::Model::PlantLoop.new(model)
        swh_peak_flow_per_area = []
        swh_heating_target_temperature = []
        swh_schedule = ""
        area_per_occ = total_occ_dens.map { |val| val.nil? ? 0.0 : 1 / val.to_f }
        water_fixture = standard.model_add_swh_end_uses_by_space(model, swh_loop, space)

        if water_fixture.nil?
          swh_watts_per_person = Array.new(total_occ_dens.size, 0.0)
          swh_fraction_schedule = Array.new(total_occ_dens.size, 0.0)
          swh_target_temperature_schedule = Array.new(total_occ_dens.size, "NA")
        else
          swh_fraction_schedule = Array.new(total_occ_dens.size) { water_fixture.flowRateFractionSchedule.get.name }
          swh_peak_flow = water_fixture.waterUseEquipmentDefinition.peakFlowRate # m3/s
          swh_peak_flow_per_area = Array.new(total_occ_dens.size) { swh_peak_flow / space_area } # m3/s/m2

          swh_watts_per_person = swh_peak_flow_per_area.map.with_index do |flow_per_area, i|
            flow_per_area * 1000 * (4.19 * 44.4) * 1000 * area_per_occ[i]
          end

          swh_target_temperature_schedule = Array.new(total_occ_dens.size) do
            water_fixture.waterUseEquipmentDefinition.targetTemperatureSchedule.get.to_ScheduleRuleset.get.defaultDaySchedule.values.map { |val| val.to_f.round(1) }
          end
        end

        # Check all values in the total_occ_dens array
        total_occ_dens.each_with_index do |occ_value, index|
          if occ_value.nil?
            total_occ_dens[index] = 0.0
            occ_sched[index] = "NA"
          else
            total_occ_dens[index] = 1 / occ_value.to_f
          end
        end

        # Outdoor Air / Ventilation.
        dsoa = st.designSpecificationOutdoorAir.get
        outdoor_air_method = dsoa.outdoorAirMethod
        outdoor_air_flow_per_floor_area_m_per_s = dsoa.outdoorAirFlowperFloorArea.signif(2)
        dsoa_outdoor_air_flow_per_person = dsoa.outdoorAirFlowperPerson.signif(2)
        dsoa_outdoor_air_flow_rate_m_per_s = dsoa.outdoorAirFlowRate.signif(2)
        dsoa_outdoor_air_flow_air_changes_per_hour = dsoa.outdoorAirFlowAirChangesperHour.signif(2)
        if dsoa.outdoorAirFlowRateFractionSchedule.empty?
          dsoa_outdoorAirFlowRateFractionSchedule = "NA"
        else
          dsoa_outdoorAirFlowRateFractionSchedule = dsoa.outdoorAirFlowRateFractionSchedule.get.name
        end
        # Add this test case to results and return the hash.
        results[space_type_name] = {
          standards_space_type: st.standardsSpaceType.get,
          standards_building_type: st.standardsBuildingType.get,
          total_lpd: total_lpd.map { |lpd| lpd.signif(3) },
          lpd_schedule_name: lpd_sched,
          total_occ_dens_m2_per_person: total_occ_dens.map { |dens| dens.signif(3) },
          occupancy_schedule_name: occ_sched,
          gas_equip_power: gas_equip_power.map { |power| power.signif(3) },
          gas_equip_schedule_name: gas_equip_sched,
          elec_equip_power_W_per_m2: elec_equip_power.map { |power| power.signif(3) },
          elec_equip_schedule_name: elec_equip_sched,
          steam_equip_power: steam_equip_power.map { |power| power.signif(3) },
          steam_equip_schedule_name: steam_equip_sched,
          hw_equip_power: hw_equip_power.map { |power| power.signif(3) },
          hw_equip_schedule_name: hw_equip_sched,
          swh_watts_per_person: swh_watts_per_person.map { |power| power.signif(3) },
          swh_fraction_schedule: swh_fraction_schedule,
          swh_target_temperature_schedule: swh_target_temperature_schedule,
          outdoor_air_method: outdoor_air_method,
          outdoor_air_flow_per_floor_area_m_per_s: outdoor_air_flow_per_floor_area_m_per_s,
          dsoa_outdoor_air_flow_per_person: dsoa_outdoor_air_flow_per_person,
          dsoa_outdoor_air_flow_rate_m_per_s: dsoa_outdoor_air_flow_rate_m_per_s,
          dsoa_outdoor_air_flow_air_changes_per_hour: dsoa_outdoor_air_flow_air_changes_per_hour,
          dsoa_outdoor_air_flow_rate_fraction_schedule: dsoa_outdoorAirFlowRateFractionSchedule
        }

      end
    rescue => error
      logger.error "#{__FILE__}::#{__method__} #{error.message}"
    end
    logger.info "Completed individual test: #{name}"
    results = results.sort.to_h
    return results
  end

end


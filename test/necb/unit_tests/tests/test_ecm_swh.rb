require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)
require 'parallel'
require 'time'

# This class will perform tests to ensure that the NECB SHW tank and pump are being sized correctly and that the water
# use equipment are being defined correctly.  Test takes all space types defined in the appropriate NECB spacetypes.json
# file and applies them to the outpatient.osm file (actually, it just changes the name of the space types in the
# outpatient.osm file).
class ECM_SWH_Tests < Minitest::Test

  # Set to true to run the standards in the test.
  PERFORM_STANDARDS = true

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Test to validate the eff of water_heaters
  def test_add_swh_test_output_info
    logger.info "Starting suite of tests for: #{__method__}"

    # Define test parameters.
    test_parameters = { test_method: __method__,
                        save_intermediate_models: true,
                        baseboard_type: 'Hot Water',
                        heating_coil_type: 'DX' }

    # Define test cases.
    test_cases = Hash.new

    # Define references (per vintage in this case).
    test_cases[:NECB2011] = { :Reference => "NECB 2011 Table 6.2.2.1." }
    test_cases[:NECB2015] = { :Reference => "NECB 2015 Table 6.2.2.1." }
    test_cases[:NECB2017] = { :Reference => "NECB 2017 Table 6.2.2.1." }
    test_cases[:NECB2020] = { :Reference => "NECB 2020 Table 6.2.2.1." }

    # Test cases. Three cases for NG and FuelOil, one for Electric.
    # Results and name are tbd here as they will be calculated in the test.
    test_cases_hash = { :Vintage => ["NECB2011", "BTAPPRE1980", "BTAP1980TO2010"],
                        :FuelType => ["NaturalGas"],
                        :shw_ecms => ["NECB_Default", "Natural Gas Power Vent with Electric Ignition"],
                        :TestCase => ["AB_Calgary"],
                        :TestPars => { :epw_file => "CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_results = do_test_cases(test_cases: test_cases, test_pars: test_parameters)

    test_cases_hash = { :Vintage => ["NECB2011", "BTAPPRE1980", "BTAP1980TO2010"],
                        :FuelType => ["NaturalGas"],
                        :shw_ecms => ["NECB_Default", "Natural Gas Power Vent with Electric Ignition"],
                        :TestCase => ["NT_Yellowknife"],
                        :TestPars => { :epw_file => "CAN_NT_Yellowknife.AP.719360_CWEC2020.epw" } }
    new_test_cases = make_test_cases_json(test_cases_hash)
    merge_test_cases!(test_cases, new_test_cases)
    test_results = do_test_cases(test_cases: test_cases, test_pars: test_parameters)

    # Write test results.
    file_root = "#{self.class.name}-#{__method__}".downcase
    test_result_file = File.join(@test_results_folder, "#{file_root}-test_results.json")
    File.write(test_result_file, JSON.pretty_generate(test_results))

    # Read expected results.
    file_name = File.join(@expected_results_folder, "#{file_root}-expected_results.json")
    expected_results = JSON.parse(File.read(file_name), { symbolize_names: true })
    # Check if test results match expected.
    msg = "Water heater efficiencies test results do not match what is expected in test"
    compare_results(expected_results: expected_results, test_results: test_results, msg: msg, type: 'json_data')

    logger.info "Finished suite of tests for: #{__method__}"
  end

  # @param test_pars [Hash] has the static parameters.
  # @param test_case [Hash] has the specific test parameters.
  # @return results of this case.
  # @note Companion method to test_number_of_water_heaters that runs a specific test. Called by do_test_cases in necb_helper.rb.

  def do_test_add_swh_test_output_info(test_pars:, test_case:)
    # Debug.
    logger.debug "test_pars: #{JSON.pretty_generate(test_pars)}"
    logger.debug "test_case: #{JSON.pretty_generate(test_case)}"
    # Define local variables. These are extracted from the supplied hashes.
    test_name = test_pars[:test_method]
    save_intermediate_models = test_pars[:save_intermediate_models]
    vintage = test_pars[:Vintage]
    fueltype = test_pars[:FuelType]
    shw_ecm = test_pars[:shw_ecms]
    epw_file = test_case[:epw_file]
    epw_file_name = epw_file.split(".")[0]
    # Define the test name.
    name = "#{vintage}_#{fueltype}_#{epw_file_name}"
    name_short = "#{vintage}_#{fueltype}_#{epw_file_name}"

    output_folder = method_output_folder("#{test_name}/#{name_short}")
    logger.info "Starting individual test: #{name}"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder, "NECB2011Outpatient.osm"))
    # Set the weather file.

    BTAP::Environment::WeatherFile.new(epw_file).set_weather_file(model)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models
    # Get spacetypes from JSON.  I say I use all of the spacetypes but really it is only those with a
    # "buliding_type" of "Space Function".
    standard = get_standard(vintage)

    search_criteria = {
      "template" => vintage,
      "building_type" => "Space Function"
    }
    standards_table = standard.standards_data['space_types']
    space_type_data = standard.model_find_objects(standards_table, search_criteria)
    # Get the space types in the model.
    space_types = model.getSpaceTypes
    # Determine the total number of space types retrieved from the JSON file.
    space_type_data_size = space_type_data.size
    space_type_names = []
    index = 0
    break_time = false
    # Go through each space type in the model and change its name to that of the next space type in the JSON file.
    space_types.sort.each do |space_type|
      space_type.setNameProtected("Space Function" + " " + space_type_data[index]["space_type"])
      space_type_names << space_type.name
      # If you still have space types left in the JSON file go to the next one.  If not, start at the beginning
      # again and when you finish renaming the space types in the osm file go to the next weather location or
      # version of NECB (or stop when you are done).
      if index >= (space_type_data_size - 1)
        index = 0
        break_time = true
      else
        index += 1
      end
    end

    # apply swh to the renamed space types (model_add_swh only looks at the name of the space type not what is
    # actually in it).
    standard.model_add_swh(model: model, swh_fueltype: fueltype, shw_scale: 'NECB_Default')
    # Apply the water heater mixed efficiencies
    model.getWaterHeaterMixeds.sort.each { |obj| standard.water_heater_mixed_apply_efficiency(obj) }

    # get shw efficiency measure data from ECMS class shw_set.json
    ecm_standard = get_standard("ECMS")
    shw_measures = ecm_standard.standards_data['tables']['shw_eff_ecm']['table']

    # Apply measure info if gas.
    # Apply_shw_ecm = false
    model.getWaterHeaterMixeds.sort.each do |waterheater_test|
      if waterheater_test.heaterFuelType == "NaturalGas"
        shw_measure = shw_measures.select { |shw_measure_info| shw_measure_info["name"] == shw_ecm }[0]
        ecm_standard.modify_shw_efficiency(model: model, shw_eff: shw_measure)
      end
    end
    # Go through the model and check what tank, pump, and water use connections were added.
    plantloops = model.getPlantLoops

    # Before doing anything check if any plant loops are present.  If it is continue, otherwise skip to the next
    # set of space types.
    results = {}
    unless plantloops.empty?
      # Start with the demand components (water use connections).
      demand_comps = plantloops[0].demandComponents
      water_conns = []
      demand_equip_info = []
      # Get all the water use connections and add them to an array.
      demand_comps.sort.each do |demand_comp|
        if demand_comp.iddObjectType.valueName.to_s == "OS_WaterUse_Connections"
          water_conns << demand_comp.to_WaterUseConnections.get
        end
      end

      # Go through the water use connections and get the flow rate and schedule information.
      water_conns.sort.each do |water_conn|
        day_scheds = []
        water_equip = water_conn.waterUseEquipment
        next if water_equip.empty? # Skip if no water use equipment

        flow_rate_fract_sched = water_equip[0].flowRateFractionSchedule
        if flow_rate_fract_sched.is_initialized
          sched = flow_rate_fract_sched.get.to_ScheduleRuleset
          if sched.is_initialized
            sched.get.scheduleRules.sort.each do |sched_rule|
              day_sched = {
                "day_sched_name" => sched_rule.daySchedule.name.to_s,
                "times" => sched_rule.daySchedule.times,
                "values" => sched_rule.daySchedule.values
              }
              day_scheds << day_sched
            end
          end
        end
        # Handle flow rate truncation
        water_equip_def = water_equip[0].waterUseEquipmentDefinition
        digit_exponent = 10 ** 7
        last_digit_check = water_equip_def.peakFlowRate * digit_exponent
        digit_exponent = 10 ** 6 if last_digit_check >= 10

        exponent_mult = (10 ** 12) * digit_exponent
        last_digit_check = (water_equip_def.peakFlowRate * exponent_mult).to_i
        water_flow_out = last_digit_check.to_f / exponent_mult

        # Put the water use equipment data in a hash
        equip_info = {
          "equip_name" => water_equip[0].name.to_s,
          "flow_rate_m3_per_s" => water_flow_out,
          "day_schedules" => day_scheds
        }
        demand_equip_info << equip_info
      end

      # Collect supply component information
      pumps = []
      water_heaters = []

      plantloops[0].supplyComponents.sort.each do |supplycomp|
        case supplycomp.iddObjectType.valueName.to_s
        when 'OS_Pump_ConstantSpeed'
          pumps << supplycomp.to_PumpConstantSpeed.get
        when 'OS_WaterHeater_Mixed'
          water_heaters << supplycomp.to_WaterHeaterMixed.get
        end
      end

      # Build supply equipment info
      if water_heaters.any? && pumps.any?
        water_heater = water_heaters[0]
        pump = pumps[0]

        part_load_curve_name = water_heater.partLoadFactorCurve.is_initialized ? water_heater.partLoadFactorCurve.get.name.to_s : "none"

        supply_equip_info = {
          "water_heater_fuel_type" => water_heater.heaterFuelType.to_s,
          "water_heater_vol_m3" => water_heater.tankVolume,
          "water_heater_capacity_w" => water_heater.heaterMaximumCapacity,
          "water_heater_efficiency" => water_heater.heaterThermalEfficiency,
          "water_heater_part_load_curve_name" => part_load_curve_name,
          "pump_head_Pa" => pump.ratedPumpHead.to_f.round(8),
          "pump_motor_eff" => pump.motorEfficiency
        }
        # Build result hash
        results = {
          "template" => vintage,
          "water_heater_name" => water_heater.name.to_s,
          "space_types" => space_type_names,
          "supply_equipment" => supply_equip_info,
          "demand_equipment" => demand_equip_info
        }
      end

      logger.info "Completed individual test: #{name}"
      return results
    end
  end
end
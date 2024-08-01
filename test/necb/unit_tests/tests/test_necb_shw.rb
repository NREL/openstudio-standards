require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

# This class will perform tests to ensure that the NECB SHW tank and pump are being sized correctly and that the water
# use equipment are being defined correctly.  Test takes all space types defined in the appropriate NECB spacetypes.json
# file and applies them to the outpatient.osm file (actually, it just changes the name of the space types in the
# outpatient.osm file).
class NECB_SHW_tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

  # Additional constant ranges.
  Epw_files = ['CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw', 'CAN_NT_Yellowknife.AP.719360_CWEC2020.epw']

  # @return [Boolean] true if successful.
  def test_shw_test()
    output_array = []

    #get shw efficiency measure data from ECMS class shw_set.json
    ecm_standard = get_standard("ECMS")
    shw_measures = ecm_standard.standards_data['tables']['shw_eff_ecm']['table']
    shw_ecms = ["NECB_Default", "Natural Gas Power Vent with Electric Ignition"]

    #Iterate through NECB2011 and NECB2015 as well as weather locations heated by gas and electricity.
    @Templates.sort.each do |template|
      Epw_files.sort.each do |epw_file|

        index = 0
        break_time = false
        # There are many more spacetypes in the spacetypes.json file than in Outpatient.osm.  The test takes the first
        # however many spacetypes can fit in Outpatient.osm from the spacetypes.json file and then applies them.  I
        # think it is 20 for NECB2011 and 18 for NECB2015.  It then runs the model_add_swh method from the NECB2011
        # standards class and gets information for the shw tank, pump, and water use equipment from the resulting model.
        # It then repeats the process until all spacetypes in the spacetypes.json file have been applied and testing
        # on the Outpatient file.
        while break_time == false do
          model = nil
          standard = nil
          # Open the Outpatient model.
          model = BTAP::FileIO.load_osm(File.join(@resources_folder, "NECB2011Outpatient.osm"))
          # Set the weather file
          weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path(epw_file)
          OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
          # Get spacetypes from JSON.  I say I use all of the spacetypes but really it is only those with a
          # "buliding_type" of "Space Function".
          standard = get_standard(template)

          search_criteria = {
              "template" => template,
              "building_type" => "Space Function"
          }
          standards_table = standard.standards_data['space_types']
          space_type_data = standard.model_find_objects(standards_table, search_criteria)
          # Get the space types in the model.
          space_types = model.getSpaceTypes
          # Determine the total number of space types retrieved from the JSON file.
          space_type_data_size = space_type_data.size
          space_type_names = []
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
          standard.model_add_swh(model: model, shw_fueltype: 'DefaultFuel', shw_scale: 'NECB_Default')
		  #Apply the water heater mixed efficiencies
		  model.getWaterHeaterMixeds.sort.each { |obj| standard.water_heater_mixed_apply_efficiency(obj) }

          # Apply measure info if gas.
          #apply_shw_ecm = false
          model.getWaterHeaterMixeds.sort.each do |waterheater_test|
            if waterheater_test.heaterFuelType == "NaturalGas"
              shw_ecms.each do |shw_ecm|
                shw_measure = shw_measures.select{|shw_measure_info| shw_measure_info["name"] == shw_ecm}[0]
                ecm_standard.modify_shw_efficiency(model: model, shw_eff: shw_measure)
                add_shw_test_output_info(model: model, output_array: output_array, template: template, epw_file: epw_file, space_type_names: space_type_names)
              end
            else
              add_shw_test_output_info(model: model, output_array: output_array, template: template, epw_file: epw_file, space_type_names: space_type_names)
            end
          end

          # Collect shw loop info to add to output
          #add_shw_test_output_info(model: model, output_array: output_array, template: template, epw_file: epw_file, space_type_names: space_type_names)
        end
      end #loop to the next epw_file
    end #loop to the next Template
    #Write test report file.
    test_result_file = File.join(@test_results_folder,'shw_test_results.json')
    File.open(test_result_file, 'w') {|f| f.write(JSON.pretty_generate(output_array)) }

    #Test that the values are correct by doing a file compare.
    expected_result_file = File.join(@expected_results_folder,'shw_expected_results.json')

    # Check if test results match expected.
    msg = "SHW test results do not match what is expected in test"
    file_compare(expected_results_file: expected_result_file, test_results_file: test_result_file, msg: msg)
  end

  def add_shw_test_output_info(model:, output_array:, template:, epw_file:, space_type_names:)
    # Go through the model and check what tank, pump, and water use connections were added.
    plantloops = model.getPlantLoops

    # Before doing anything check if any plant loops are present.  If it is continue, otherwise skip to the next
    # set of space types.

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
        flow_rate_fract_sched = water_equip[0].flowRateFractionSchedule.get.to_ScheduleRuleset.get
        flow_rate_fract_sched.scheduleRules.sort.each do |sched_rule|
          day_sched = {
              "day_sched_name" => sched_rule.daySchedule.name,
              "times" => sched_rule.daySchedule.times,
              "values" => sched_rule.daySchedule.values
          }
          day_scheds << day_sched
        end
        # The next bit of code truncates the flow rate because sometimes the last digit will change depending on
        # the vagaries of Ruby, the processor, whatever and cause the test to fail when really it should have
        # passed.  Thinking about this more I made it way too complicated.  I could have just truncated the result
        # but decided to keep the same number of (non-zero) significant digits regardless of if the result was
        # scaled by 10E-6 or 10E-7 the two common ones).  Hence the next few lines of code where I check if the flow
        # rate is 10E-6 or 10E-7, keep the result to 12 digits, then convert it back to the right flow rate.

        water_equip_def = water_equip[0].waterUseEquipmentDefinition
        digit_exponent = 10**7
        last_digit_check = water_equip_def.peakFlowRate*digit_exponent
        if last_digit_check >= 10
          digit_exponent = 10**6
        end
        exponent_mult =(10**12)*digit_exponent
        last_digit_check = (water_equip_def.peakFlowRate*exponent_mult).to_i
        water_flow_out = last_digit_check.to_f/exponent_mult
        # Put the water use equipment name, flow rate, and schedule in a hash
        equip_info = {
            "equip_name" => water_equip[0].name,
            "flow_rate_m3_per_s" => water_flow_out,
            "day_schedules" => day_scheds
        }
        # Add the above hash containing info for all of the water use equipment defined in the model.
        demand_equip_info << equip_info
      end
      pumps = []
      water_heaters = []
      # Next get the supply component information.
      supply_comps = plantloops[0].supplyComponents
      # Go through each of the supply components and get either the pumps or the water heaters.
      supply_comps.sort.each do |supplycomp|
        case supplycomp.iddObjectType.valueName.to_s
        when 'OS_Pump_ConstantSpeed'
          pumps << supplycomp.to_PumpConstantSpeed.get
        when 'OS_WaterHeater_Mixed'
          water_heaters << supplycomp.to_WaterHeaterMixed.get
        end
      end
      # Add the water heater tank volume and capacity and the pump head and moter efficiency to a hash.  Although
      # I collect all of the pumps and water heaters in the plant loop above here I assume there is only one of
      # each in the model.  I really should check, but I don't.
      # Adding water heater efficiency and part load curve (if one is applied).
      part_load_curve_name = "none"
      if water_heaters[0].partLoadFactorCurve.is_initialized
        part_load_curve_name = water_heaters[0].partLoadFactorCurve.get.name.to_s
      end
      supply_equip_info = {
          "water_heater_fuel_type" => water_heaters[0].heaterFuelType,
          "water_heater_vol_m3" => water_heaters[0].tankVolume,
          "water_heater_capacity_w" => water_heaters[0].heaterMaximumCapacity,
          "water_heater_efficiency" => water_heaters[0].heaterThermalEfficiency,
          "water_heater_part_load_curve_name" => part_load_curve_name,
          "pump_head_Pa" => pumps[0].ratedPumpHead.to_f.round(8),
          "pump_motor_eff" => pumps[0].motorEfficiency
      }
      # make hash containing the template applied, weather file used, water heater name, space types applied (or
      # I should say renamed), the supply equipment info (from the supply_equip_info hash) and demand equipment info
      # (from the demand_equip_info array defined above).
      set_output = {
          "template" => template,
          "epw_file" => epw_file,
          "water_heater_name" => water_heaters[0].name,
          "space_types" => space_type_names,
          "suppy_equipment" => supply_equip_info,
          "demand_equipment" => demand_equip_info
      }
      # Add this hash to an array containing the same info for all of the sets of space types applied to the model.
      output_array << set_output
    end
  end
end
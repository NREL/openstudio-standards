require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


# This class will perform tests that are Spacetype dependant, Test model will be created
# to specifically test aspects of the NECB2011 code that are Spacetype dependant. 
class SHW_test < Minitest::Test
  #Standards
  # Templates = ['NECB2011', 'NECB2015']
  Templates = ['NECB2011', 'NECB2015']
  Epw_files = ['CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw', 'CAN_QC_Kuujjuaq.AP.719060_CWEC2016.epw']

    
  # Tests to ensure that the NECB default schedules are being defined correctly.
  # This is not for compliance, but for archetype development. 
  # @return [Bool] true if successful. 
  def test_shw_test()
    output_array = []
    climate_zone = 'none'
    #Iterate through all spacetypes/buildingtypes. 
    Templates.sort.each do |template|
      Epw_files.sort.each do |epw_file|
        index = 0
        break_time = false
        while break_time == false do
          model = nil
          standard = nil
          model = BTAP::FileIO.load_osm("#{File.dirname(__FILE__)}/models/#{template}Outpatient.osm")
          BTAP::Environment::WeatherFile.new(epw_file).set_weather_file(model)
          #Get spacetypes from JSON.
          standard = Standard.build(template)

          search_criteria = {
              "template" => template,
              "building_type" => "Space Function"
          }
          space_type_data = standard.model_find_objects(standard.standards_data["space_types"], search_criteria)
          space_types = model.getSpaceTypes
          space_type_data_size = space_type_data.size
          space_type_names = []
          space_types.sort.each do |space_type|
            space_type.setNameProtected("Space Function" + " " + space_type_data[index]["space_type"])
            space_type_names << space_type.name
            if index >= (space_type_data_size - 1)
              index = 0
              break_time = true
            else
              index += 1
            end
          end
          standard.model_add_swh(model)
          plantloops = model.getPlantLoops
          demand_comps = plantloops[0].demandComponents
          water_conns = []
          demand_equip_info = []
          demand_comps.sort.each do |demand_comp|
            if demand_comp.iddObjectType.valueName.to_s == "OS_WaterUse_Connections"
              water_conns << demand_comp.to_WaterUseConnections.get
            end
          end
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
            water_equip_def = water_equip[0].waterUseEquipmentDefinition
            digit_exponent = 10**7
            last_digit_check = water_equip_def.peakFlowRate*digit_exponent
            if last_digit_check >= 10
              digit_exponent = 10**6
            end
            exponent_mult =(10**12)*digit_exponent
            last_digit_check = (water_equip_def.peakFlowRate*exponent_mult).to_i
            water_flow_out = last_digit_check.to_f/exponent_mult
            check_val = water_equip_def.peakFlowRate
            equip_info = {
                "equip_name" => water_equip[0].name,
                "flow_rate_m3_per_s" => water_flow_out,
                "day_schedules" => day_scheds
            }
            demand_equip_info << equip_info
          end
          pumps = []
          water_heaters = []
          supply_comps = plantloops[0].supplyComponents
          supply_comps.sort.each do |supplycomp|
            case supplycomp.iddObjectType.valueName.to_s
              when 'OS_Pump_ConstantSpeed'
                pumps << supplycomp.to_PumpConstantSpeed.get
              when 'OS_WaterHeater_Mixed'
                water_heaters << supplycomp.to_WaterHeaterMixed.get
            end
          end
          supply_equip_info = {
              "water_heater_vol_m3" => water_heaters[0].tankVolume,
              "water_heater_capacity_w" => water_heaters[0].heaterMaximumCapacity,
              "pump_head_Pa" => pumps[0].ratedPumpHead,
              "pump_motor_eff" => pumps[0].motorEfficiency
          }
          set_output = {
              "template" => template,
              "epw_file" => epw_file,
              "water_heater_name" => water_heaters[0].name,
              "space_types" => space_type_names,
              "suppy_equipment" => supply_equip_info,
              "demand_equipment" => demand_equip_info
          }
          output_array << set_output
        end
      end #loop epw_file
    end #loop Template
    #Write test report file. 
    test_result_file = File.join(File.dirname(__FILE__),'data','shw_test_results.json')
    File.open(test_result_file, 'w') {|f| f.write(JSON.pretty_generate(output_array)) }

    #Test that the values are correct by doing a file compare.
    expected_result_file = File.join(File.dirname(__FILE__),'data','shw_expected_results.json')
    b_result = FileUtils.compare_file(expected_result_file , test_result_file )
    assert( b_result, 
      "shw test results do not match expected results! Compare/diff the output with the stored values here #{expected_result_file} and #{test_result_file}"
    )
  end
end
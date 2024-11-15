require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)


class NECB_Airloop_Sizing_Parameters_Tests < Minitest::Test

  def setup()
    define_folders(__dir__)
    define_std_ranges
  end

begin
  # Test to validate sizing rules for air loop
  def test_airloop_sizing_rules_vav

    # Set up remaining parameters for test.
    output_folder = method_output_folder
    template="NECB2011"
    standard = get_standard(template)
    save_intermediate_models = false

    boiler_fueltype = 'Electricity'
    baseboard_type = 'Hot Water'
    chiller_type = 'Reciprocating'
    heating_coil_type = 'Electric'
    vavfan_type = 'AF_or_BI_rdg_fancurve'

    tol = 1.0e-3
    name = 'sys6'
    name.gsub!(/\s+/, "-")
    puts "***************#{name}***************\n"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
    OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, boiler_fueltype, always_on)
    standard.add_sys6_multi_zone_built_up_system_with_baseboard_heating(
      model: model,
      zones: model.getThermalZones,
      heating_coil_type: heating_coil_type,
      baseboard_type: baseboard_type,
      chiller_type: chiller_type,
      fan_type: vavfan_type,
      hw_loop: hw_loop)

    # Run sizing.
    run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

    airloops = model.getAirLoopHVACs
    airloops.each do |iloop|
      thermal_zones = iloop.thermalZones
      tot_floor_area = 0.0
      thermal_zones.each do |izone|
        sizing_zone = izone.sizingZone
        # check sizing factors
        heating_sizing_factor = sizing_zone.zoneHeatingSizingFactor
        cooling_sizing_factor = sizing_zone.zoneCoolingSizingFactor
        necb_heating_sizing_factor = 1.3
        necb_cooling_sizing_factor = 1.1
        diff = (heating_sizing_factor.to_f - necb_heating_sizing_factor).abs / necb_heating_sizing_factor
        heating_sizing_factor_set_correctly = true
        if diff > tol then heating_sizing_factor_set_correctly = false end
        assert(heating_sizing_factor_set_correctly, "test_airloop_sizing_rules_vav: Heating sizing factor does not match necb requirement #{name}")
        diff = (cooling_sizing_factor.to_f - necb_cooling_sizing_factor).abs / necb_cooling_sizing_factor
        cooling_sizing_factor_set_correctly = true
        if diff > tol then cooling_sizing_factor_set_correctly = false end
        assert(cooling_sizing_factor_set_correctly, "test_airloop_sizing_rules_vav: Cooling sizing factor does not match necb requirement #{name}")
        # check supply temperature diffs and method
        necb_design_supply_temp_input_method = 'TemperatureDifference'
        design_clg_supply_temp_input_method = sizing_zone.zoneCoolingDesignSupplyAirTemperatureInputMethod.to_s
        assert(necb_design_supply_temp_input_method==design_clg_supply_temp_input_method, "test_airloop_sizing_rules: Cooling design supply air temp input method does not match necb requirement")
        design_htg_supply_temp_input_method = sizing_zone.zoneHeatingDesignSupplyAirTemperatureInputMethod.to_s
        assert(necb_design_supply_temp_input_method==design_htg_supply_temp_input_method, "test_airloop_sizing_rules: Heating design supply air temp input method does not match necb")
        heating_sizing_temp_diff = sizing_zone.zoneHeatingDesignSupplyAirTemperatureDifference
        cooling_sizing_temp_diff = sizing_zone.zoneCoolingDesignSupplyAirTemperatureDifference
        necb_heating_sizing_temp_diff = 21.0
        necb_cooling_sizing_temp_diff = 11.0
        diff = (heating_sizing_temp_diff.to_f - necb_heating_sizing_temp_diff).abs / necb_heating_sizing_temp_diff
        heating_sizing_temp_diff_set_correctly = true
        if diff > tol then heating_sizing_temp_diff_set_correctly = false end
        assert(heating_sizing_temp_diff_set_correctly, "test_airloop_sizing_rules_vav: Heating sizing supply temperature difference does not match necb requirement #{name}")
        diff = (heating_sizing_temp_diff.to_f - necb_heating_sizing_temp_diff).abs / necb_heating_sizing_temp_diff
        cooling_sizing_temp_diff_set_correctly = true
        if diff > tol then cooling_sizing_temp_diff_set_correctly = false end
        assert(cooling_sizing_temp_diff_set_correctly, "test_airloop_sizing_rules_vav: Cooling sizing supply temperature difference does not match necb requirement #{name}")
        tot_floor_area += izone.floorArea
      end
      #necb_min_flow_rate = 0.002 * tot_floor_area
      #demand_comps = iloop.demandComponents
      #tot_min_flow_rate = 0.0
      #demand_comps.each do |icomp|
        #if icomp.to_AirTerminalSingleDuctVAVReheat.is_initialized
          #vav_box = icomp.to_AirTerminalSingleDuctVAVReheat.get
          #tot_min_flow_rate += vav_box.fixedMinimumAirFlowRate
        #end
      #end
      #diff = (tot_min_flow_rate - necb_min_flow_rate).abs / necb_min_flow_rate
      #min_flow_rate_set_correctly = true
      #if diff > tol then min_flow_rate_set_correctly = false end
      #assert(min_flow_rate_set_correctly, "test_airloop_sizing_rules_vav: Minimum vav box flow rate does not match necb requirement #{name}")
    end
  end
end

begin
  # Test to validate sizing rules for air loop
  def test_airloop_sizing_rules_heatpump

    # Set up remaining parameters for test.
    output_folder = method_output_folder
    template="NECB2011"
    standard = get_standard(template)
    save_intermediate_models = false

    boiler_fueltype = 'NaturalGas'
    baseboard_type = 'Hot Water'
    heating_coil_type = 'DX'

    tol = 1.0e-3
    name = 'sys3'
    name.gsub!(/\s+/, "-")
    puts "***************#{name}***************\n"

    # Load model and set climate file.
    model = BTAP::FileIO.load_osm(File.join(@resources_folder,"5ZoneNoHVAC.osm"))
    weather_file_path = OpenstudioStandards::Weather.get_standards_weather_file_path('CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw')
    OpenstudioStandards::Weather.model_set_building_location(model, weather_file_path: weather_file_path)
    BTAP::FileIO.save_osm(model, "#{output_folder}/#{name}-baseline.osm") if save_intermediate_models

    hw_loop = OpenStudio::Model::PlantLoop.new(model)
    always_on = model.alwaysOnDiscreteSchedule
    standard.setup_hw_loop_with_components(model,hw_loop, boiler_fueltype, boiler_fueltype, always_on)
    standard.add_sys3and8_single_zone_packaged_rooftop_unit_with_baseboard_heating_single_speed(
      model: model,
      zones: model.getThermalZones,
      heating_coil_type: heating_coil_type,
      baseboard_type: baseboard_type,
      hw_loop: hw_loop,
      new_auto_zoner: false)

    # Run sizing.
    run_sizing(model: model, template: template, test_name: name, save_model_versions: save_intermediate_models)

    airloops = model.getAirLoopHVACs
    airloops.each do |iloop|
      thermal_zones = iloop.thermalZones
      tot_floor_area = 0.0
      thermal_zones.each do |izone|
        sizing_zone = izone.sizingZone
        # check sizing factors
        heating_sizing_factor = sizing_zone.zoneHeatingSizingFactor
        cooling_sizing_factor = sizing_zone.zoneCoolingSizingFactor
        necb_heating_sizing_factor = 1.3
        necb_cooling_sizing_factor = 1.0
        diff = (heating_sizing_factor.to_f - necb_heating_sizing_factor).abs / necb_heating_sizing_factor
        heating_sizing_factor_set_correctly = true
        if diff > tol then heating_sizing_factor_set_correctly = false end
        assert(heating_sizing_factor_set_correctly, "test_airloop_sizing_rules_heatpump: Heating sizing factor does not match necb requirement #{name} got #{heating_sizing_factor} expected #{necb_heating_sizing_factor}")
        diff = (cooling_sizing_factor.to_f - necb_cooling_sizing_factor).abs / necb_cooling_sizing_factor
        cooling_sizing_factor_set_correctly = true
        if diff > tol then cooling_sizing_factor_set_correctly = false end
        assert(cooling_sizing_factor_set_correctly, "test_airloop_sizing_rules_heatpump: Cooling sizing factor does not match necb requirement #{name} got #{cooling_sizing_factor} expected #{necb_cooling_sizing_factor}")
        # check supply temperatures
        heating_sizing_temp_diff = sizing_zone.zoneHeatingDesignSupplyAirTemperatureDifference
        cooling_sizing_temp_diff = sizing_zone.zoneCoolingDesignSupplyAirTemperatureDifference
        necb_heating_sizing_temp_diff = 21.0
        necb_cooling_sizing_temp_diff = 11.0
        diff = (heating_sizing_temp_diff.to_f - necb_heating_sizing_temp_diff).abs / necb_heating_sizing_temp_diff
        heating_sizing_temp_diff_set_correctly = true
        if diff > tol then heating_sizing_temp_diff_set_correctly = false end
        assert(heating_sizing_temp_diff_set_correctly, "test_airloop_sizing_rules_heatpump: Heating sizing supply temperature difference does not match necb requirement #{name}")

        diff = (heating_sizing_temp_diff.to_f - necb_heating_sizing_temp_diff).abs / necb_heating_sizing_temp_diff
        cooling_sizing_temp_diff_set_correctly = true
        if diff > tol then cooling_sizing_temp_diff_set_correctly = false end
        assert(cooling_sizing_temp_diff_set_correctly, "test_airloop_sizing_rules_heatpump: Cooling sizing supply temperature difference does not match necb requirement #{name}")
        tot_floor_area += izone.floorArea
      end
    end
  end
end

end

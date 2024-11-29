require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

# *** Needs a re-write to use std paths etc ***

class NECB_DCV_Tests < Minitest::Test

  def test_dcv()

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_dcv')
    @expected_results_file = File.join(__dir__, '../expected_results/dcv_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/dcv_test_results.json')
    @sizing_run_dir = File.join(@output_folder, 'sizing_folder')

    # Intial test condition
    @test_passed = true

    #Range of test options.
    @templates = [
      'NECB2011',
      'NECB2015',
      'NECB2017'
    ]
    @building_types = [     #test for 'FullServiceRestaurant' and 'Hospital'
        'FullServiceRestaurant',
        # 'HighriseApartment',
        # 'Hospital',
        # 'LargeHotel',
        'LargeOffice',
        # 'MediumOffice',
        # 'MidriseApartment',
        # 'Outpatient',
        # 'PrimarySchool',
        # 'QuickServiceRestaurant',
        # 'RetailStandalone',
        # 'SecondarySchool',
        # 'SmallHotel',
        # 'Warehouse'
    ]
    @epw_files = ['CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw']
    @primary_heating_fuels = ['NaturalGas']
    @dcv_types = ['Occupancy_based_DCV', 'CO2_based_DCV'] #['No_DCV'] #['NECB_Default']
    @lighting_types = ['NECB_Default'] #LED  #NECB_Default

    # Test results storage array.
    @test_results_array = []

    @templates.sort.each do |template|
      @epw_files.sort.each do |epw_file|
        @building_types.sort.each do |building_type|
          @primary_heating_fuels.sort.each do |primary_heating_fuel|
            @dcv_types.sort.each do |dcv_type|
              @lighting_types.sort.each do |lighting_type|

                result = {}
                result['template'] = template
                result['epw_file'] = epw_file
                result['building_type'] = building_type
                result['primary_heating_fuel'] = primary_heating_fuel
                result['dcv_type'] = dcv_type

                # make an empty model
                model = OpenStudio::Model::Model.new
                #set up basic model.
                standard = Standard.build(template)

                #loads osm geometry and spactypes from library.
                model = standard.load_building_type_from_library(building_type: building_type)

                # this runs the step in the model.
                standard.model_apply_standard(model: model,
                                              epw_file: epw_file,
                                              sizing_run_dir: @sizing_run_dir,
                                              primary_heating_fuel: primary_heating_fuel,
                                              dcv_type: dcv_type, # Four options: (1) 'NECB_Default', (2) 'No_DCV', (3) 'Occupancy_based_DCV' , (4) 'CO2_based_DCV'
                                              lights_type: nil, # Two options: (1) 'NECB_Default', (2) 'LED'
                                              lights_scale: nil,
                                              daylighting_type: nil, # Two options: (1) 'NECB_Default', (2) 'add_daylighting_controls'
                                              ecm_system_name: nil,
                                              ecm_system_zones_map_option: nil, # (1) 'NECB_Default' (2) 'one_sys_per_floor' (3) 'one_sys_per_bldg'
                                              erv_package: nil,
                                              boiler_eff: nil,
                                              unitary_cop: nil,
                                              furnace_eff: nil,
                                              shw_eff: nil,
                                              ext_wall_cond: nil,
                                              ext_floor_cond: nil,
                                              ext_roof_cond: nil,
                                              ground_wall_cond: nil,
                                              ground_floor_cond: nil,
                                              ground_roof_cond: nil,
                                              door_construction_cond: nil,
                                              fixed_window_cond: nil,
                                              glass_door_cond: nil,
                                              overhead_door_cond: nil,
                                              skylight_cond: nil,
                                              glass_door_solar_trans: nil,
                                              fixed_wind_solar_trans: nil,
                                              skylight_solar_trans: nil,
                                              rotation_degrees: nil,
                                              fdwr_set: nil,
                                              srr_set: nil,
                                              nv_type: nil, # Two options: (1) nil/none/false/'NECB_Default', (2) 'add_nv'
                                              nv_opening_fraction: nil, # options: (1) nil/none/false (2) 'NECB_Default' (i.e. 0.1), (3) opening fraction of windows, which can be a float number between 0.0 and 1.0
                                              nv_temp_out_min: nil, # options: (1) nil/none/false(2) 'NECB_Default' (i.e. 13.0 based on inputs from Michel Tardif re a real school in QC), (3) minimum outdoor air temperature (in Celsius) below which natural ventilation is shut down
                                              nv_delta_temp_in_out: nil, # options: (1) nil/none/false (2) 'NECB_Default' (i.e. 1.0 based on inputs from Michel Tardif re a real school in QC), (3) temperature difference (in Celsius) between the indoor and outdoor air temperatures below which ventilation is shut down
                                              scale_x: nil,
                                              scale_y: nil,
                                              scale_z: nil,
                                              pv_ground_type: nil, # Two options: (1) nil/none/false/'NECB_Default', (2) 'add_pv_ground'
                                              pv_ground_total_area_pv_panels_m2: nil, # Options: (1) nil/none/false, (2) 'NECB_Default' (i.e. building footprint), (3) area value (e.g. 50)
                                              pv_ground_tilt_angle: nil, # Options: (1) nil/none/false, (2) 'NECB_Default' (i.e. latitude), (3) tilt angle value (e.g. 20)
                                              pv_ground_azimuth_angle: nil, # Options: (1) nil/none/false, (2) 'NECB_Default' (i.e. south), (3) azimuth angle value (e.g. 90)
                                              pv_ground_module_description: nil, # Options: (1) nil/none/false, (2) 'NECB_Default' (i.e. Standard), (3) other options ('Standard', 'Premium', ThinFilm')
                                              occupancy_loads_scale: nil,
                                              electrical_loads_scale: nil,
                                              oa_scale: nil,
                                              infiltration_scale: nil,
                                              chiller_type: nil, # Options: (1) 'NECB_Default'/nil/'none'/false (i.e. do nothing), (2) e.g. 'VSD'
                                              output_variables: nil,
                                              shw_scale: nil,  # Options: (1) 'NECB_Default'/nil/'none'/false (i.e. do nothing), (2) a float number larger than 0.0
                                              output_meters: nil,
                                              airloop_economizer_type: nil, # (1) 'NECB_Default'/nil/' (2) 'DifferentialEnthalpy' (3) 'DifferentialTemperature'
                                              baseline_system_zones_map_option: nil  # Three options: (1) 'NECB_Default'/'none'/nil (i.e. 'one_sys_per_bldg'), (2) 'one_sys_per_dwelling_unit', (3) 'one_sys_per_bldg'
                )

                # # comment out for regular tests
                # BTAP::FileIO.save_osm(model, File.join(@output_folder,"#{template}-#{building_type}-#{dcv_type}.osm"))
                # puts File.join(@output_folder,"#{template}-#{building_type}-#{dcv_type}.osm")

                ##### Get info about contaminant type to be simulated (i.e. Carbon Dioxide Concentration, Outdoor Carbon Dioxide Schedule)
                zone_air_contaminant_balance = model.getZoneAirContaminantBalance()
                carbonDioxideConcentration_status = zone_air_contaminant_balance.carbonDioxideConcentration()

                ##### Gather information about outdoor_co2_schedule
                outdoor_co2_schedule = zone_air_contaminant_balance.outdoorCarbonDioxideSchedule.get
                outdoor_co2_schedule_name = outdoor_co2_schedule.name()
                result["outdoor_co2_schedule_name"] = outdoor_co2_schedule_name.to_s
                # result["outdoor_co2_schedule_through_date"] = outdoor_co2_schedule.getString(3).to_s
                # result["outdoor_co2_schedule_for_alldays"] = outdoor_co2_schedule.getString(4).to_s
                # result["outdoor_co2_schedule_for_alldays_time"] = outdoor_co2_schedule.getString(5).to_s
                result["outdoor_co2_schedule_for_alldays_ppm"] = outdoor_co2_schedule.getString(6).to_s
                # puts outdoor_co2_schedule_name
                # puts outdoor_co2_schedule.getString(6)
                # result["outdoor_co2_schedule_name"]
                # result["outdoor_co2_schedule_for_alldays_ppm"]
                # puts result
                # @test_results_array << result
                # puts @test_results_array
                # raise('check outdoor_co2_schedule_name')

                ##### Set CO2 controller in each space (required for CO2-based DCV)
                model.getSpaces.sort.each do |space|
                  zone = space.thermalZone
                  if !zone.empty?
                    zone = space.thermalZone.get
                  end
                  zone_control_co2 = zone.zoneControlContaminantController.get

                  ##### Gather names of indoor_co2_availability_schedule and indoor_co2_setpoint_schedule
                  zone_control_co2_indoor_co2_availability_schedule = zone_control_co2.carbonDioxideControlAvailabilitySchedule.get
                  zone_control_co2_indoor_co2_availability_schedule_name = zone_control_co2_indoor_co2_availability_schedule.name()
                  zone_control_co2_indoor_co2_setpoint_schedule = zone_control_co2.carbonDioxideSetpointSchedule.get
                  zone_control_co2_indoor_co2_setpoint_schedule_name = zone_control_co2_indoor_co2_setpoint_schedule.name()

                  ##### Gather information about indoor_co2_availability_schedule
                  result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_name"] = zone_control_co2_indoor_co2_availability_schedule_name.to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_through_date"] = zone_control_co2_indoor_co2_availability_schedule.getString(3).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_weekdays"] = zone_control_co2_indoor_co2_availability_schedule.getString(4).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_weekdays_time_1"] = zone_control_co2_indoor_co2_availability_schedule.getString(5).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_weekdays_fraction_1"] = zone_control_co2_indoor_co2_availability_schedule.getString(6).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_weekdays_time_2"] = zone_control_co2_indoor_co2_availability_schedule.getString(7).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_weekdays_fraction_2"] = zone_control_co2_indoor_co2_availability_schedule.getString(8).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_weekdays_time_3"] = zone_control_co2_indoor_co2_availability_schedule.getString(9).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_weekdays_fraction_3"] = zone_control_co2_indoor_co2_availability_schedule.getString(10).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_saturday"] = zone_control_co2_indoor_co2_availability_schedule.getString(11).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_saturday_time_1"] = zone_control_co2_indoor_co2_availability_schedule.getString(12).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_saturday_fraction_1"] = zone_control_co2_indoor_co2_availability_schedule.getString(13).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_saturday_time_2"] = zone_control_co2_indoor_co2_availability_schedule.getString(14).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_saturday_fraction_2"] = zone_control_co2_indoor_co2_availability_schedule.getString(15).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_saturday_time_3"] = zone_control_co2_indoor_co2_availability_schedule.getString(16).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_saturday_fraction_3"] = zone_control_co2_indoor_co2_availability_schedule.getString(17).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_otherdays"] = zone_control_co2_indoor_co2_availability_schedule.getString(18).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_otherdays_time_1"] = zone_control_co2_indoor_co2_availability_schedule.getString(19).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_availability_schedule_for_otherdays_fraction_1"] = zone_control_co2_indoor_co2_availability_schedule.getString(20).to_s

                  ##### Gather information about indoor_co2_setpoint_schedule
                  result["#{space.name.to_s} - zone_control_co2_indoor_co2_setpoint_schedule_name"] = zone_control_co2_indoor_co2_setpoint_schedule_name.to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_setpoint_schedule_through_date"] = zone_control_co2_indoor_co2_setpoint_schedule.getString(3).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_setpoint_schedule_for_alldays"] = zone_control_co2_indoor_co2_setpoint_schedule.getString(4).to_s
                  # result["#{space.name.to_s} - zone_control_co2_indoor_co2_setpoint_schedule_for_alldays_time"] = zone_control_co2_indoor_co2_setpoint_schedule.getString(5).to_s
                  result["#{space.name.to_s} - zone_control_co2_indoor_co2_setpoint_schedule_for_alldays_ppm"] = zone_control_co2_indoor_co2_setpoint_schedule.getString(6).to_s
                end
                ##### Loop through AirLoopHVACs
                model.getAirLoopHVACs.sort.each do |air_loop|
                  ##### Loop through AirLoopHVAC's supply nodes to:
                  ##### (1) Find its AirLoopHVAC:OutdoorAirSystem using the supply node;
                  ##### (2) Find Controller:OutdoorAir using AirLoopHVAC:OutdoorAirSystem;
                  ##### (3) Get "Controller Mechanical Ventilation" from Controller:OutdoorAir.
                  air_loop.supplyComponents.sort.each do |supply_component|
                    ##### Find AirLoopHVAC:OutdoorAirSystem of AirLoopHVAC using the supply node.
                    hvac_component = supply_component.to_AirLoopHVACOutdoorAirSystem

                    if !hvac_component.empty?
                      ##### Find Controller:OutdoorAir using AirLoopHVAC:OutdoorAirSystem.
                      hvac_component = hvac_component.get
                      hvac_component_name = hvac_component.name()
                      controller_outdoorair = hvac_component.getControllerOutdoorAir
                      controller_outdoorair_name = controller_outdoorair.name()
                      result["#{hvac_component_name} - controller_outdoorair_name"] = controller_outdoorair_name.to_s

                      ##### Get "Controller Mechanical Ventilation" from Controller:OutdoorAir.
                      controller_mechanical_ventilation = controller_outdoorair.controllerMechanicalVentilation
                      controller_mechanical_ventilation_name = controller_mechanical_ventilation.name()
                      result["#{controller_outdoorair_name} - controller_mechanical_ventilation_name"] = controller_mechanical_ventilation_name.to_s

                      ##### Check if "Demand Controlled Ventilation" is "Yes" in Controller:MechanicalVentilation depending on dcv_type.
                      controller_mechanical_ventilation_demand_controlled_ventilation_status = controller_mechanical_ventilation.demandControlledVentilation
                      result["#{controller_mechanical_ventilation_name} - controller_mechanical_ventilation_demand_controlled_ventilation_status"] = controller_mechanical_ventilation_demand_controlled_ventilation_status.to_s

                      controller_mechanical_ventilation_system_outdoor_air_method = controller_mechanical_ventilation.systemOutdoorAirMethod()
                      result["#{controller_mechanical_ventilation_name} - controller_mechanical_ventilation_system_outdoor_air_method"] = controller_mechanical_ventilation_system_outdoor_air_method.to_s

                    end #if !hvac_component.empty?

                  end #air_loop.supplyComponents.each do |supply_component|
                end #model.getAirLoopHVACs.each do |air_loop|

                #then store results into the array that contains all the scenario results.
                @test_results_array << result

              end #@lighting_types.sort.each do |lighting_type|
            end
          end
        end
      end
    end
    # puts @test_results_array

    # Save test results to file.
    File.open(@test_results_file, 'w') {|f| f.write(JSON.pretty_generate(@test_results_array))}

    # Compare results
    compare_message = ''
    # Check if expected file exists.
    if File.exist?(@expected_results_file)
      # Load expected results from file.
      @expected_results = JSON.parse(File.read(@expected_results_file))
      if @expected_results.size == @test_results_array.size
        # Iterate through each test result.
        @expected_results.each_with_index do |expected, row|
          # Compare if row /hash is exactly the same.
          if expected != @test_results_array[row]
            #if not set test flag to false
            @test_passed = false
            compare_message << "\nERROR: This row was different expected/result\n"
            compare_message << "EXPECTED:#{expected.to_s}\n"
            compare_message << "TEST:    #{@test_results_array[row].to_s}\n\n"
          end
        end
      else
        assert(false, "#{@expected_results_file} # of rows do not match the #{@test_results_array}..cannot compare")
      end
    else
      assert(false, "#{@expected_results_file} does not exist..cannot compare")
    end
    puts compare_message
    assert(@test_passed, "Error: This test failed to produce the same result as in the #{@expected_results_file}\n")
  end

end

require_relative '../../../helpers/minitest_helper'
#require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

# *** This test needs a significant re-write to make use of standard naming and paths ***

class NECB_nv_Tests < Minitest::Test

  def test_nv()
    # Create ECM object.
    ecm = ECMS.new

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_nv')
    @expected_results_file = File.join(__dir__, '../expected_results/nv_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/nv_test_results.json')
    @sizing_run_dir = File.join(@output_folder, 'sizing_folder')

    # Initial test condition
    @test_passed = true

    #Range of test options.
    @templates = [
        # 'NECB2011',
        # 'NECB2015',
        'NECB2017'
    ]
    @building_types = [
        'FullServiceRestaurant',
    # 'HighriseApartment',
    'Hospital',
    # 'LargeHotel',
    # 'LargeOffice', #
    # 'MediumOffice',
    # 'MidriseApartment',
    # 'Outpatient', #
    # 'PrimarySchool',
    # 'QuickServiceRestaurant',
    # 'RetailStandalone',
    # 'SecondarySchool',
    # 'SmallHotel',
    # 'Warehouse' #
    ]
    @epw_files = ['CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw']
    @primary_heating_fuels = ['NaturalGas']
    @nv_types = ['add_nv']

    nv_opening_fraction = 'NECB_Default'
    nv_temp_out_min = 'NECB_Default'
    nv_delta_temp_in_out = 'NECB_Default'

    # Test results storage array.
    @test_results_array = []

    @templates.sort.each do |template|
      @epw_files.sort.each do |epw_file|
        @building_types.sort.each do |building_type|
          @primary_heating_fuels.sort.each do |primary_heating_fuel|
            @nv_types.sort.each do |nv_type|

              result = {}
              result['template'] = template
              result['epw_file'] = epw_file
              result['building_type'] = building_type
              result['primary_heating_fuel'] = primary_heating_fuel
              result['nv_type'] = nv_type

              # make an empty model
              model = OpenStudio::Model::Model.new
              #set up basic model.
              standard = Standard.build(template)

              #loads osm geometry and spactypes from library.
              model = standard.load_building_type_from_library(building_type: building_type)

              # this runs the steps in the model.
              standard.model_apply_standard(model: model,
                                            epw_file: epw_file,
                                            sizing_run_dir: @sizing_run_dir,
                                            primary_heating_fuel: primary_heating_fuel,
                                            dcv_type: nil, # Four options: (1) 'NECB_Default', (2) 'No_DCV', (3) 'Occupancy_based_DCV' , (4) 'CO2_based_DCV'
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
                                            nv_type: 'add_nv', # Two options: (1) nil/none/false/'NECB_Default', (2) 'add_nv'
                                            nv_opening_fraction: 'NECB_Default', # options: (1) nil/none/false (2) 'NECB_Default' (i.e. 0.1), (3) opening fraction of windows, which can be a float number between 0.0 and 1.0
                                            nv_temp_out_min: 'NECB_Default', # options: (1) nil/none/false(2) 'NECB_Default' (i.e. 13.0 based on inputs from Michel Tardif re a real school in QC), (3) minimum outdoor air temperature (in Celsius) below which natural ventilation is shut down
                                            nv_delta_temp_in_out: 'NECB_Default', # options: (1) nil/none/false (2) 'NECB_Default' (i.e. 1.0 based on inputs from Michel Tardif re a real school in QC), (3) temperature difference (in Celsius) between the indoor and outdoor air temperatures below which ventilation is shut down
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
              # BTAP::FileIO.save_osm(model, File.join(@output_folder,"#{template}-#{building_type}-nv-#{nv_type}.osm"))
              # puts File.join(@output_folder,"#{template}-#{building_type}-nv-#{nv_type}.osm")

              ##### Gather information about ZoneVentilationDesignFlowRate & ZoneVentilationWindandStackOpenArea
              model.getHVACComponents.sort.each do |hvac_component|
                # puts hvac_component
                if hvac_component.to_ZoneHVACComponent.is_initialized
                  zn_hvac_component = hvac_component.to_ZoneHVACComponent.get
                  # puts zn_hvac_component

                  ### Gather information about ZoneVentilationDesignFlowRate
                  if zn_hvac_component.to_ZoneVentilationDesignFlowRate.is_initialized
                    zn_vent_design_flow_rate = zn_hvac_component.to_ZoneVentilationDesignFlowRate.get
                    zn_vent_design_flow_rate_name = zn_vent_design_flow_rate.name.to_s

                    thermal_zone = zn_hvac_component.thermalZone.get

                    thermal_zone.spaces.sort.each do |space|
                      result["#{space.name.to_s} - #{zn_vent_design_flow_rate_name} - DesignFlowRateCalculationMethod"] = zn_vent_design_flow_rate.designFlowRateCalculationMethod
                      result["#{space.name.to_s} - #{zn_vent_design_flow_rate_name} - FlowRateperPerson"] = zn_vent_design_flow_rate.flowRateperPerson
                      result["#{space.name.to_s} - #{zn_vent_design_flow_rate_name} - FlowRateperFloorArea"] = zn_vent_design_flow_rate.flowRateperZoneFloorArea
                      result["#{space.name.to_s} - #{zn_vent_design_flow_rate_name} - VentilationType"] = zn_vent_design_flow_rate.ventilationType
                      result["#{space.name.to_s} - #{zn_vent_design_flow_rate_name} - MinimumIndoorTemperatureSchedule"] = zn_vent_design_flow_rate.minimumIndoorTemperatureSchedule.get.name.to_s
                      result["#{space.name.to_s} - #{zn_vent_design_flow_rate_name} - MaximumIndoorTemperatureSchedule"] = zn_vent_design_flow_rate.maximumIndoorTemperatureSchedule.get.name.to_s
                      result["#{space.name.to_s} - #{zn_vent_design_flow_rate_name} - MinimumOutdoorTemperature"] = zn_vent_design_flow_rate.minimumOutdoorTemperature
                      result["#{space.name.to_s} - #{zn_vent_design_flow_rate_name} - MaximumOutdoorTemperature"] = zn_vent_design_flow_rate.maximumOutdoorTemperature
                      result["#{space.name.to_s} - #{zn_vent_design_flow_rate_name} - DeltaTemperature"] = zn_vent_design_flow_rate.deltaTemperature
                    end

                  end

                  ### Gather information about ZoneVentilationWindandStackOpenArea
                  if zn_hvac_component.to_ZoneVentilationWindandStackOpenArea.is_initialized
                    zn_vent_wind_and_stack = zn_hvac_component.to_ZoneVentilationWindandStackOpenArea.get
                    zn_vent_wind_and_stack_name = zn_vent_wind_and_stack.name.to_s

                    thermal_zone = zn_hvac_component.thermalZone.get

                    thermal_zone.spaces.sort.each do |space|
                      result["#{space.name.to_s} - #{zn_vent_wind_and_stack_name} - OpeningArea"] = zn_vent_wind_and_stack.openingArea
                      result["#{space.name.to_s} - #{zn_vent_wind_and_stack_name} - OpeningAreaFractionSchedule"] = zn_vent_wind_and_stack.openingAreaFractionSchedule.name.to_s
                      result["#{space.name.to_s} - #{zn_vent_wind_and_stack_name} - EffectiveAngle"] = zn_vent_wind_and_stack.effectiveAngle
                      result["#{space.name.to_s} - #{zn_vent_wind_and_stack_name} - MinimumIndoorTemperatureSchedule"] = zn_vent_wind_and_stack.minimumIndoorTemperatureSchedule.get.name.to_s
                      result["#{space.name.to_s} - #{zn_vent_wind_and_stack_name} - MaximumIndoorTemperatureSchedule"] = zn_vent_wind_and_stack.maximumIndoorTemperatureSchedule.get.name.to_s
                      result["#{space.name.to_s} - #{zn_vent_wind_and_stack_name} - MinimumOutdoorTemperature"] = zn_vent_wind_and_stack.minimumOutdoorTemperature
                      result["#{space.name.to_s} - #{zn_vent_wind_and_stack_name} - MaximumOutdoorTemperature"] = zn_vent_wind_and_stack.maximumOutdoorTemperature
                      result["#{space.name.to_s} - #{zn_vent_wind_and_stack_name} - DeltaTemperature"] = zn_vent_wind_and_stack.deltaTemperature
                    end

                  end

                end #if hvac_component.to_ZoneHVACComponent.is_initialized
              end #model.getHVACComponents.sort.each do |hvac_component|

              ### Gather information about AvailabilityManagerHybridVentilation
              model.getSpaces.sort.each do |space|
                thermal_zone = space.thermalZone
                if thermal_zone.is_initialized
                  thermal_zone = space.thermalZone.get
                  thermal_zone.airLoopHVACs.sort.each do |air_loop|
                    air_loop.availabilityManagers.sort.each do |avail_mgr|
                      if avail_mgr.to_AvailabilityManagerHybridVentilation.is_initialized
                        avail_mgr_hybr_vent = avail_mgr.to_AvailabilityManagerHybridVentilation.get
                        result["#{space.name.to_s} - #{avail_mgr_hybr_vent.name.to_s} - MinimumOutdoorTemperature"] = avail_mgr_hybr_vent.minimumOutdoorTemperature
                        result["#{space.name.to_s} - #{avail_mgr_hybr_vent.name.to_s} - MaximumOutdoorTemperature"] = avail_mgr_hybr_vent.maximumOutdoorTemperature
                      end
                    end
                  end
                end
              end

              # puts JSON.pretty_generate(result)

              ##### then store results into the array that contains all the scenario results.
              @test_results_array << result
            end
          end
        end
      end
    end
    # puts @test_results_array

    # Save test results to file.
    File.open(@test_results_file, 'w') { |f| f.write(JSON.pretty_generate(@test_results_array)) }

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

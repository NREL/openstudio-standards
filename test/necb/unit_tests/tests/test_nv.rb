require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'

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
        'NECB2011',
        'NECB2015',
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
    @epw_files = ['CAN_AB_Banff.CS.711220_CWEC2016.epw']
    @primary_heating_fuels = ['DefaultFuel']
    @nv_types = [true]

    nv_opening_fraction = 'NECB_Default'
    nv_Tout_min = 'NECB_Default'
    nv_Delta_Tin_Tout = 'NECB_Default'

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
              standard.apply_weather_data(model: model, epw_file: epw_file)
              standard.apply_loads(model: model, lights_type: 'NECB_Default', lights_scale: 1.0)
              standard.apply_envelope(model: model,
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
                             skylight_solar_trans: nil)
              standard.apply_fdwr_srr_daylighting(model: model,
                                         fdwr_set: -1.0,
                                         srr_set: -1.0)
              standard.apply_auto_zoning(model: model,
                                sizing_run_dir: Dir.pwd,
                                lights_type: 'NECB_Default',
                                lights_scale: 1.0)
              standard.apply_systems_and_efficiencies(model: model,
                                                      primary_heating_fuel: primary_heating_fuel,
                                                      sizing_run_dir: Dir.pwd,
                                                      dcv_type: 'NECB_Default',
                                                      ecm_system_name: 'NECB_Default',
                                                      erv_package: 'NECB_Default',
                                                      boiler_eff: nil,
                                                      unitary_cop: nil,
                                                      furnace_eff: nil,
                                                      shw_eff: nil,
                                                      daylighting_type: 'NECB_Default',
                                                      nv_type: nv_type,
                                                      nv_opening_fraction: nv_opening_fraction,
                                                      nv_Tout_min: nv_Tout_min,
                                                      nv_Delta_Tin_Tout:nv_Delta_Tin_Tout,
                                                      pv_ground_type: nil,
                                                      pv_ground_total_area_pv_panels_m2: nil,
                                                      pv_ground_tilt_angle: nil,
                                                      pv_ground_azimuth_angle: nil,
                                                      pv_ground_module_description: nil
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

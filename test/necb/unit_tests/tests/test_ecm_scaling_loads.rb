require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'

class NECB_scaling_loads_Tests < Minitest::Test

  def test_scaling_loads()

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_scaling_loads')
    @expected_results_file = File.join(__dir__, '../expected_results/scaling_loads_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/scaling_loads_test_results.json')
    @sizing_run_dir = File.join(@output_folder, 'sizing_folder')

    # Initial test condition
    @test_passed = true

    #Range of test options.
    @templates = [
        'NECB2011',
    # 'NECB2015',
    # 'NECB2017'
    ]
    @building_types = [
        'FullServiceRestaurant',
        # 'HighriseApartment',
        # 'Hospital'#,
        # 'LargeHotel',
        # 'LargeOffice',
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
    @epw_files = [
        'CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw'
    ]
    @primary_heating_fuels = ['DefaultFuel']

    @loads_scales = [
        0.0,
        0.5
    ]

    # Test results storage array.
    @test_results_array = []

    @templates.sort.each do |template|
      @epw_files.sort.each do |epw_file|
        @building_types.sort.each do |building_type|
          @primary_heating_fuels.sort.each do |primary_heating_fuel|
            @loads_scales.sort.each do |loads_scale|
              result = {}
              result['template'] = template
              result['epw_file'] = epw_file
              result['building_type'] = building_type
              result['primary_heating_fuel'] = primary_heating_fuel

              # make an empty model
              model = OpenStudio::Model::Model.new
              #set up basic model.
              standard = Standard.build(template)

              #loads osm geometry and spactypes from library.
              model = standard.load_building_type_from_library(building_type: building_type)

              # this runs the steps in the model.
              standard.apply_weather_data(model: model, epw_file: epw_file)
              standard.apply_loads(model: model,
                                   lights_type: 'NECB_Default',
                                   lights_scale: 1.0,
                                   occupancy_loads_scale: loads_scale,
                                   electrical_loads_scale: loads_scale,
                                   oa_scale: loads_scale)
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
                                      skylight_solar_trans: nil,
                                      infiltration_scale: loads_scale)
              standard.apply_fdwr_srr_daylighting(model: model,
                                                  fdwr_set: -1.0,
                                                  srr_set: -1.0)
              standard.apply_auto_zoning(model: model,
                                         sizing_run_dir: @sizing_run_dir,
                                         lights_type: 'NECB_Default',
                                         lights_scale: 1.0)
              standard.apply_systems_and_efficiencies(model: model,
                                                      primary_heating_fuel: primary_heating_fuel,
                                                      sizing_run_dir: @sizing_run_dir,
                                                      dcv_type: 'NECB_Default',
                                                      ecm_system_name: 'NECB_Default',
                                                      erv_package: 'NECB_Default',
                                                      boiler_eff: nil,
                                                      unitary_cop: nil,
                                                      furnace_eff: nil,
                                                      shw_eff: nil,
                                                      daylighting_type: 'NECB_Default',
                                                      pv_ground_type: nil,
                                                      pv_ground_total_area_pv_panels_m2: nil,
                                                      pv_ground_tilt_angle: nil,
                                                      pv_ground_azimuth_angle: nil,
                                                      pv_ground_module_description: nil,
                                                      chiller_type: nil,
                                                      shw_scale: loads_scale
              )

              # # comment out for regular tests
              # BTAP::FileIO.save_osm(model, File.join(@output_folder,"#{template}-#{building_type}-loads_scale-#{loads_scale}.osm"))
              # puts File.join(@output_folder,"#{template}-#{building_type}-loads_scale-#{loads_scale}.osm")

              result["loads_scale"] = loads_scale.to_f

              ##### Gather info of occupancy_loads_scale in the model
              model.getPeoples.sort.each do |item|
                result["#{item.name.to_s} - multiplier"] = item.multiplier.to_f
              end

              ##### Gather info of electrical_loads_scale in the model
              model.getElectricEquipments.sort.each do |item|
                result["#{item.name.to_s} - multiplier"] = item.multiplier.to_f
              end

              ##### Gather info of oa_scale in the model
              model.getDesignSpecificationOutdoorAirs.sort.each do |item|
                result["#{item.name.to_s} - outdoorAirFlowperPerson"] = item.outdoorAirFlowperPerson.to_f
                result["#{item.name.to_s} - outdoorAirFlowperFloorArea"] = item.outdoorAirFlowperFloorArea.to_f
                result["#{item.name.to_s} - outdoorAirFlowRate"] = item.outdoorAirFlowRate.to_f
                result["#{item.name.to_s} - outdoorAirFlowAirChangesperHour"] = item.outdoorAirFlowAirChangesperHour.to_f
              end

              ##### Gather info of infiltration_scale in the model
              model.getSpaceInfiltrationDesignFlowRates.sort.each do |item|
                result["#{item.name.to_s} - designFlowRate"] = item.designFlowRate.to_f
                result["#{item.name.to_s} - flowperSpaceFloorArea"] = item.flowperSpaceFloorArea.to_f
                result["#{item.name.to_s} - flowperExteriorSurfaceArea"] = item.flowperExteriorSurfaceArea.to_f
                result["#{item.name.to_s} - airChangesperHour"] = item.airChangesperHour.to_f
              end

              ##### Gather info of shw_scale in the model
              model.getWaterUseEquipmentDefinitions.sort.each do |item|
                result["#{item.name.to_s} - peakFlowRate"] = item.peakFlowRate.to_f
              end
              model.getWaterHeaterMixeds.sort.each do |item|
                result["#{item.name.to_s} - tankVolume"] = item.tankVolume.to_f
              end

              # puts JSON.pretty_generate(result)

              ##### then store results into the array that contains all the scenario results.
              @test_results_array << result

            end #@loads_scales.sort.each do |loads_scale|
          end #@primary_heating_fuels.sort.each do |primary_heating_fuel|
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

  end #def test_scaling_loads()

end
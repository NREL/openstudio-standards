require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'

class NECB_PVground_Tests < Minitest::Test

  def test_pv_ground()
    # Create ECM object.
    ecm = ECMS.new

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_pv_ground')
    @expected_results_file = File.join(__dir__, '../expected_results/pv_ground_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/pv_ground_test_results.json')
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
    @epw_files = ['CAN_AB_Banff.CS.711220_CWEC2016.epw']
    @primary_heating_fuels = ['DefaultFuel']
    @pv_ground_types = [true]  #true, false

    pv_ground_total_area_pv_panels_m2 = 'NECB_Default'
    pv_ground_tilt_angle = 'NECB_Default'
    pv_ground_azimuth_angle = 'NECB_Default'
    pv_ground_module_description = 'NECB_Default'

    # Test results storage array.
    @test_results_array = []

    @templates.sort.each do |template|
      @epw_files.sort.each do |epw_file|
        @building_types.sort.each do |building_type|
          @primary_heating_fuels.sort.each do |primary_heating_fuel|
            @pv_ground_types.sort.each do |pv_ground_type|

              result = {}
              result['template'] = template
              result['epw_file'] = epw_file
              result['building_type'] = building_type
              result['primary_heating_fuel'] = primary_heating_fuel
              result['pv_ground_type'] = pv_ground_type

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
                                             pv_ground_type: pv_ground_type,
                                             pv_ground_total_area_pv_panels_m2: pv_ground_total_area_pv_panels_m2,
                                             pv_ground_tilt_angle: pv_ground_tilt_angle,
                                             pv_ground_azimuth_angle: pv_ground_azimuth_angle,
                                             pv_ground_module_description: pv_ground_module_description
              )

              # # comment out for regular tests
              # BTAP::FileIO.save_osm(model, File.join(@output_folder,"#{template}-#{building_type}-pv_ground-#{pv_ground_type}.osm"))
              # puts File.join(@output_folder,"#{template}-#{building_type}-pv_ground-#{pv_ground_type}.osm")

              ##### Gather generators data
              model.getGeneratorPVWattss.sort.each do |generator_PVWatt|
                dc_system_capacity = generator_PVWatt.dcSystemCapacity()
                module_type = generator_PVWatt.moduleType()
                array_type = generator_PVWatt.arrayType()
                tilt_angle = generator_PVWatt.tiltAngle()
                azimuth_angle = generator_PVWatt.azimuthAngle()
                result["#{generator_PVWatt.name.to_s} - dc_system_capacity"] = dc_system_capacity.to_s
                result["#{generator_PVWatt.name.to_s} - module_type"] = module_type
                result["#{generator_PVWatt.name.to_s} - array_type"] = array_type
                result["#{generator_PVWatt.name.to_s} - tilt_angle"] = tilt_angle.to_s
                result["#{generator_PVWatt.name.to_s} - azimuth_angle"] = azimuth_angle.to_s
              end

              ##### Gather inverters data
              model.getElectricLoadCenterInverterPVWattss.sort.each do |inverter_PVWatt|
                inverter_dc_to_as_size_ratio = inverter_PVWatt.dcToACSizeRatio()
                inverter_inverter_efficiency = inverter_PVWatt.inverterEfficiency()
                result["#{inverter_PVWatt.name.to_s} - dc_to_as_size_ratio"] = inverter_dc_to_as_size_ratio.to_s
                result["#{inverter_PVWatt.name.to_s} - inverter_efficiency"] = inverter_inverter_efficiency.to_s
              end

              ##### Gather distribution systems and set relevant parameters
              model.getElectricLoadCenterDistributions.sort.each  do |elc_distribution|
                elc_distribution_inverter_name = elc_distribution.inverter.get.name.to_s
                elc_distribution_generator_operation_scheme_type = elc_distribution.generatorOperationSchemeType()
                result["#{elc_distribution.name.to_s} - inverter_name"] = elc_distribution_inverter_name
                result["#{elc_distribution.name.to_s} - generator_operation_scheme_type"] = elc_distribution_generator_operation_scheme_type
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

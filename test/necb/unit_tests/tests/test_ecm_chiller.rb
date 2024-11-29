require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

# *** Needs a re-write to use std paths etc ***

class NECB_VSDchiller_Tests < Minitest::Test

  def test_vsd_chiller()
    # Create ECM object.
    ecm = ECMS.new

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_vsd_chiller')
    @expected_results_file = File.join(__dir__, '../expected_results/vsd_chiller_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/vsd_chiller_test_results.json')
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
        # 'FullServiceRestaurant',
        # 'HighriseApartment',
        # 'Hospital'#,
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
    @epw_files = [
        'CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw',
        # 'CAN_BC_Vancouver.Intl.AP.718920_CWEC2020.epw'
    ]
    @primary_heating_fuels = ['NaturalGas']

    @chiller_types = ['VSD']

    @chiller_caps = [
        471200.0,
        742000.0,
        896700.0,
        1090100.0,
        1350400.0,
        1723100.0,
        2233000.0
    ]

    # Test results storage array.
    @test_results_array = []

    @templates.sort.each do |template|
      @epw_files.sort.each do |epw_file|
        @building_types.sort.each do |building_type|
          @primary_heating_fuels.sort.each do |primary_heating_fuel|
            @chiller_types.sort.each do |chiller_type|
              @chiller_caps.sort.each do |chiller_cap|
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

                # # this runs the steps in the model.
                ##### Here, do not implement VSD chiller. This is because in the next step,
                ##### capacity of existing chillers are replaced with mid of min and max capacity of 'chiller_set'
                ##### to avoid hard coding for chiller's capacity (as per Kamel Haddad's comment)
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

                ##### Replace capacity of existing chiller with mid of min and max capacity of 'chiller_set'
                model.getChillerElectricEIRs.sort.each do |mod_chiller|
                  ref_capacity_w = mod_chiller.referenceCapacity
                  ref_capacity_w = ref_capacity_w.to_f
                  if ref_capacity_w > 0.0011
                    chiller_cap_dummy = chiller_cap - 100000.0
                    chiller_set, chiller_min_cap, chiller_max_cap = ecm.find_chiller_set(chiller_type: chiller_type, ref_capacity_w: chiller_cap_dummy)
                    if chiller_cap < @chiller_caps[@chiller_caps.length()-1]
                      chiller_mid_cap = 0.5 * (chiller_min_cap + chiller_max_cap)
                    else
                      chiller_mid_cap = 0.5 * (chiller_min_cap + chiller_min_cap + 100000.0)
                    end
                    mod_chiller.setReferenceCapacity(chiller_mid_cap)
                  end
                end

                ##### Now, implement the VSD chiller measure in the model
                model.getChillerElectricEIRs.sort.each do |mod_chiller|
                  ref_capacity_w = mod_chiller.referenceCapacity
                  ref_capacity_w = ref_capacity_w.to_f

                  ##### Look for a chiller set in chiller_set.json (with a capacity close to that of the existing chiller)
                  chiller_set, chiller_min_cap, chiller_max_cap = ecm.find_chiller_set(chiller_type: chiller_type, ref_capacity_w: ref_capacity_w)

                  ##### No need to replace any chillers with capacity = 0.001 W as per Kamel Haddad's comment
                  if ref_capacity_w > 0.0011
                    ecm.reset_chiller_efficiency(model: model, component: mod_chiller.to_ChillerElectricEIR.get, cop: chiller_set)
                  end
                end

                # # comment out for regular tests
                # BTAP::FileIO.save_osm(model, File.join(@output_folder,"#{template}-#{building_type}-vsd_chiller-#{true}.osm"))
                # puts File.join(@output_folder,"#{template}-#{building_type}-vsd_chiller-#{true}.osm")

                ##### Gather info of VSD chillers in the model
                model.getChillerElectricEIRs.sort.each do |mod_chiller|
                  ref_capacity_w = mod_chiller.referenceCapacity
                  ref_capacity_w = ref_capacity_w.to_f
                  if ref_capacity_w > 0.0011
                    result["#{mod_chiller.name.to_s} - capacity"] = mod_chiller.referenceCapacity.to_f
                    result["#{mod_chiller.name.to_s} - COP"] = mod_chiller.referenceCOP
                    result["#{mod_chiller.name.to_s} - CAPFT_curve"] = mod_chiller.coolingCapacityFunctionOfTemperature.name.to_s
                    result["#{mod_chiller.name.to_s} - EIRFT_curve"] = mod_chiller.electricInputToCoolingOutputRatioFunctionOfTemperature.name.to_s
                    result["#{mod_chiller.name.to_s} - EITFPLR_curve"] = mod_chiller.electricInputToCoolingOutputRatioFunctionOfPLR.name.to_s
                  end
                end

                # puts JSON.pretty_generate(result)

                ##### then store results into the array that contains all the scenario results.
                @test_results_array << result

              end #@chiller_caps.sort.each do |chiller_cap|
            end #@chiller_types.sort.each do |chiller_type|
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

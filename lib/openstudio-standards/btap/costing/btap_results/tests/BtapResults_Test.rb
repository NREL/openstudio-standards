#require '/usr/local/openstudio-2.8.1/Ruby/openstudio'
require 'openstudio-standards'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'optparse'
begin
  require 'openstudio_measure_tester/test_helper'
rescue LoadError
  puts 'OpenStudio Measure Tester Gem not installed -- will not be able to aggregate and dashboard the results of tests'
end
require 'fileutils'
require 'minitest/unit'
require 'optparse'


class BTAPResults_Test < Minitest::Test


  def test_qaqc()

    # check if there are any command line arguments, if there are run those
    input_args = ARGV

    #building_type = 'Outpatient'
    building_type = 'LargeHotel'
    #building_type = 'FullServiceRestaurant'
    #building_type = 'Warehouse'
    #building_type = 'LargeOffice'
    #building_type = 'MediumOffice'
    #building_type = 'MidriseApartment'
    #building_type = 'SmallOffice'
    #building_type = 'HighriseApartment'
    #building_type = 'LowriseApartment'

    #epw_file = "CAN_BC_Vancouver.Intl.AP.718920_CWEC2020.epw"
    #epw_file = "CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw"
    #epw_file = "CAN_AB_Edmonton.Intl.AP.711230_CWEC2020.epw"
    #epw_file = "CAN_AB_Fort.Mcmurray.AP.716890_CWEC2020.epw"
    #epw_file = "CAN_NS_Halifax.Dockyard.713280_CWEC2020.epw"
    #epw_file = "CAN_QC_Montreal.Intl.AP.716270_CWEC2020.epw"
    #epw_file = "CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw"
    epw_file = "CAN_NT_Yellowknife.AP.719360_CWEC2020.epw"

    #template = 'BTAPPRE1980'
    #template = 'BTAP1980TO2010'
    #template = 'NECB2011'
    #template = 'NECB2015'
    #template = 'NECB2017'
    template = 'NECB2020'

    # primary_heating_fuel = 'DefaultFuel'
    # primary_heating_fuel = 'NaturalGas'
    # primary_heating_fuel = 'Electricity'
    primary_heating_fuel = 'FuelOilNo2' # Replaced DefaultFuel by FuelOilNo2 as the primary_heating_fuels can be only NaturalGas or Electricity or FuelOilNo2 (see 'fuel_type_sets.json' of openstudio-standards)

    #dcv_type = 'NECB_Default'
    dcv_type = nil
    #dcv_type = 'Occupancy_based_DCV'
    #dcv_type = 'CO2_based_DCV'

    daylighting_type = nil
    #daylighting_type = 'add_daylighting_controls'

    lights_type = nil
    #lights_type = 'LED'

    #lights_scale = 1.0
    lights_scale = nil

    ecm_system_name = nil
    #ecm_system_name = 'HS09_CCASHP_Baseboard'
    #@ecm_system_name = 'HS08_CCASHP_VRF'
    #ecm_system_name = 'Remove_AirLoops_Add_Zone_Baseboards'
    #ecm_system_name = 'HS11_ASHP_PTHP'
    #ecm_system_name = 'HS12_ASHP_Baseboard'
    #ecm_system_name = 'HS13_ASHP_VRF'

    erv_package = nil
    #erv_package = 'Rotary-NREL-NZE'
    #erv_package = 'Rotary-NREL-NZE_All_'
    #erv_package = 'Plate-NREL-NZE-EXISTING'
    #erv_package = 'Plate-NREL-NZE-ALL'
    #erv_package = 'Rotary-Minimum-Eff-Existing'
    #erv_package = 'Plate-Existing'

    boiler_eff = nil
    #boiler_eff = 'NECB 88% Efficient Condensing Boiler'
    #boiler_eff = 'Viessmann Vitocrossal 300 CT3-17 96.2% Efficient Condensing Gas Boiler'

    furnace_eff = nil
    #furnace_eff = 'NECB 85% Efficient Condensing Gas Furnace'
    #furnace_eff = 'NECB 91% Efficient Condensing Gas Furnace'

    #aka adv_dx_units
    unitary_cop = nil
    #unitary_cop = 'Carrier WeatherExpert'

    shw_eff = nil
    #shw_eff = 'Natural Gas Power Vent with Electric Ignition'
    #shw_eff = 'Natural Gas Direct Vent with Electric Ignition'

    chiller_type = nil
    #chiller_type = 'VSD'

    airloop_economizer_type = nil
    #airloop_economizer_type = 'DifferentialEnthalpy'

    nv_delta_temp_in_out = nil
    nv_opening_fraction = nil
    nv_temp_out_min = nil
    nv_type = nil
    #nv_type = 'add_nv'

    oa_scale = nil

    occupancy_loads_scale = nil

    ext_wall_cond = nil
    #ext_wall_cond = 0.210

    ext_floor_cond = nil
    #ext_floor_cond = 0.183

    ext_roof_cond = nil
    #ext_roof_cond = 0.227

    ground_wall_cond = nil
    ground_floor_cond = nil
    ground_roof_cond = nil

    door_construction_cond = nil
    #door_construction_cond = 1.6

    fixed_window_cond = nil
    #fixed_window_cond = 1.6

    fixed_window_solar_trans = nil
    #fixed_window_solar_trans = 0.5

    glass_door_cond = nil
    #glass_door_cond = 2.2

    overhead_door_cond = nil
    #overhead_door_cond = 1.6

    skylight_cond = nil
    #skylight_cond = 1.6

    glass_door_solar_trans = nil

    skylight_solar_trans = nil
    #skylight_solar_trans = 0.95

    infiltration_scale = nil

    fdwr_set = nil
    #fdwr_set = 0.8

    srr_set = nil

    rotation_degrees = nil
    #rotation_degrees = 45

    scale_x = nil
    #scale_x = 1.0

    scale_y = nil
    #scale_y = 1.0

    scale_z = nil
    #scale_z = 1.0

    electrical_loads_scale = nil

    shw_scale = nil

    pv_ground_type = nil
    pv_ground_total_area_pv_panels_m2 = nil
    pv_ground_tilt_angle = nil
    pv_ground_azimuth_angle = nil
    pv_ground_module_description = nil

    ecm_system_zones_map_option = nil

    # baseline_system_zones_map_option = 'one_sys_per_dwelling_unit' # same as nil, 'NECB_Default', 'none'
    baseline_system_zones_map_option = 'one_sys_per_bldg'

    # If you want openstudio-standards to make an osm for you set use_existing_osm to 'true'
    use_existing_osm = false
    # If you to use an osm other than those used for regression tests set 'custom_file' to the file name
    #custom_file = 'LargeHotel-NECB2017-CAN_AB_Edmonton.Intl.AP.711230_CWEC2016_expected_result.osm'
    #custom_file = 'FullServiceRestaurant-NECB2015-CAN_AB_Calgary.Intl.AP.718770_CWEC2016_expected_result_test.osm'
    #custom_file = 'LargeHotel-NECB2017-CAN_AB_Calgary.Intl.AP.718770_CWEC2016_expected_result_HP_mod.osm'
    #custom_file = 'LargeHotel-NECB2017-CAN_QC_Kuujjuaq.AP.719060_CWEC2016_expected_result_HP_mod.osm'
    custom_file = nil
    # Change this folder to where the custom file is (starting from btap_costing/)
    @test_fold = "/os_standards_reg_tests/"

    # If you already ran the simulation and have the results set the location of the results folder here
    # (starting from btap_costing/).  Do not add starting and ending '/'.  Set to nil if you have not already run a
    # simulation.
    #@test_output = "testdir_QC"
    @test_output = nil

    if use_existing_osm == true && custom_file.nil? && input_args.empty?
      if epw_file == "CAN_AB_Calgary.Intl.AP.718770_CWEC2016.epw" || epw_file == "CAN_QC_Kuujjuaq.AP.719060_CWEC2016.epw"
        @test_file = building_type + '-' + template + '-' + epw_file[0..-5] + '_expected_result.osm'
        puts ' '
        puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
        puts "Testing with existing test file: #{@test_file}"
        puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
        puts ' '
      else
        puts ' '
        puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
        puts 'You have selected to use an OpenStudio-standards NECB regression test file but have selected an incorrect weather file.  Will now generate osm via OpenStudio-standards.'
        puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
        puts ' '
      end
    elsif use_existing_osm == true && input_args.empty? && @test_output.nil? && !custom_file.nil?
      @test_file = custom_file
      puts ' '
      puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
      puts "Testing with existing custom test file: #{@test_file}"
      puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
      puts ' '
    elsif use_existing_osm == true && input_args.empty? && !@test_output.nil? && !custom_file.nil?
      @test_file = custom_file
      puts ' '
      puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
      puts "Testing with existing results in folder: #{@test_output}"
      puts "Testing with existing file: #{@test_file}"
      puts "In folder: #{@test_fold}"
      puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
      puts ' '
    end
    # Set 'autozone' to false if you do not want openstudio to run with the auto thermal zoning feature enabled.
    autozone = true

    unless input_args.empty?
      if ((input_args.length / 3).to_i) * 3 < input_args.length
        puts " "
        puts "Incorrect number of arguments, running default buildings:"
        puts building_type
        puts " "
        puts "With default weather files:"
        puts epw_file
        puts " "
        puts "With default templates"
        puts template
        puts " "
      else
        (0..(input_args.length - 1)).step(3) do |index|
          building_type = input_args[index]
          epw_file = input_args[index + 1]
          template = input_args[index + 2]
        end
      end
    end

    create_model_simulate_and_qaqc_regression_test(epw_file: epw_file,
                                                   template: template,
                                                   building_type: building_type,
                                                   primary_heating_fuel: primary_heating_fuel,
                                                   dcv_type: dcv_type,
                                                   daylighting_type: daylighting_type,
                                                   lights_type: lights_type,
                                                   lights_scale: lights_scale,
                                                   ecm_system_name: ecm_system_name,
                                                   erv_package: erv_package,
                                                   boiler_eff: boiler_eff,
                                                   furnace_eff: furnace_eff,
                                                   unitary_cop: unitary_cop,
                                                   shw_eff: shw_eff,
                                                   chiller_type: chiller_type,
                                                   airloop_economizer_type: airloop_economizer_type,
                                                   ext_wall_cond: ext_wall_cond,
                                                   ext_floor_cond: ext_floor_cond,
                                                   ext_roof_cond: ext_roof_cond,
                                                   ground_wall_cond: ground_wall_cond,
                                                   ground_floor_cond: ground_floor_cond,
                                                   ground_roof_cond: ground_roof_cond,
                                                   door_construction_cond: door_construction_cond,
                                                   fixed_window_cond: fixed_window_cond,
                                                   fixed_window_solar_trans: fixed_window_solar_trans,
                                                   glass_door_cond: glass_door_cond,
                                                   overhead_door_cond: overhead_door_cond,
                                                   oa_scale: oa_scale,
                                                   occupancy_loads_scale: occupancy_loads_scale,
                                                   skylight_cond: skylight_cond,
                                                   glass_door_solar_trans: glass_door_solar_trans,
                                                   skylight_solar_trans: skylight_solar_trans,
                                                   infiltration_scale: infiltration_scale,
                                                   fdwr_set: fdwr_set,
                                                   srr_set: srr_set,
                                                   rotation_degrees: rotation_degrees,
                                                   scale_x: scale_x,
                                                   scale_y: scale_y,
                                                   scale_z: scale_z,
                                                   electrical_loads_scale: electrical_loads_scale,
                                                   nv_delta_temp_in_out: nv_delta_temp_in_out,
                                                   nv_opening_fraction: nv_opening_fraction,
                                                   nv_temp_out_min:nv_temp_out_min,
                                                   nv_type: nv_type,
                                                   pv_ground_type: pv_ground_type,
                                                   pv_ground_total_area_pv_panels_m2: pv_ground_total_area_pv_panels_m2,
                                                   pv_ground_tilt_angle: pv_ground_tilt_angle,
                                                   pv_ground_azimuth_angle: pv_ground_azimuth_angle,
                                                   pv_ground_module_description: pv_ground_module_description,
                                                   ecm_system_zones_map_option: ecm_system_zones_map_option,
                                                   shw_scale: shw_scale,
                                                   baseline_system_zones_map_option: baseline_system_zones_map_option)


  end


  def create_model_simulate_and_qaqc_regression_test(epw_file:,
                                                     template:,
                                                     building_type:,
                                                     primary_heating_fuel: 'DefaultFuel',
                                                     dcv_type: 'NECB_Default',
                                                     daylighting_type: 'NECB_Default',
                                                     lights_type: 'NECB_Default',
                                                     lights_scale: 1.0,
                                                     ecm_system_name: 'NECB_Default',
                                                     erv_package: 'NECB_Default',
                                                     boiler_eff: 'NECB_Default',
                                                     furnace_eff: 'NECB_Default',
                                                     unitary_cop: 'NECB_Default',
                                                     shw_eff: 'NECB_Default',
                                                     chiller_type: 'NECB_Default',
                                                     airloop_economizer_type: 'NECB_Default',
                                                     ext_wall_cond: nil,
                                                     ext_floor_cond: nil,
                                                     ext_roof_cond: nil,
                                                     ground_wall_cond: nil,
                                                     ground_floor_cond: nil,
                                                     ground_roof_cond: nil,
                                                     door_construction_cond: nil,
                                                     fixed_window_cond: nil,
                                                     fixed_window_solar_trans: nil,
                                                     glass_door_cond: nil,
                                                     overhead_door_cond: nil,
                                                     skylight_cond: nil,
                                                     glass_door_solar_trans: nil,
                                                     skylight_solar_trans: nil,
                                                     infiltration_scale: nil,
                                                     fdwr_set: nil,
                                                     srr_set: nil,
                                                     rotation_degrees: nil,
                                                     scale_x: nil,
                                                     scale_y: nil,
                                                     scale_z: nil,
                                                     electrical_loads_scale: nil,
                                                     nv_delta_temp_in_out: 'NECB_Default',
                                                     nv_opening_fraction: 'NECB_Default',
                                                     nv_temp_out_min: 'NECB_Default',
                                                     nv_type: 'NECB_Default',
                                                     oa_scale: 'NECB_Default',
                                                     occupancy_loads_scale: 'NECB_Default',
                                                     pv_ground_type: nil,
                                                     pv_ground_total_area_pv_panels_m2: nil,
                                                     pv_ground_tilt_angle: nil,
                                                     pv_ground_azimuth_angle: nil,
                                                     pv_ground_module_description: nil,
                                                     ecm_system_zones_map_option: nil,
                                                     shw_scale: nil,
                                                     baseline_system_zones_map_option:)

    test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exists?(test_dir)
      Dir.mkdir(test_dir)
    end

    standard = Standard.build("#{template}")

    if @test_file.nil?
      # model_name = "#{building_type}-#{template}-#{File.basename(epw_file, '.epw')}"
      model_name = "#{building_type}-#{template}-DefaultFuel-#{File.basename(epw_file, '.epw')}"  #NOTE: "primary_heating_fuel" has been set to "DefaultFuel" instead of 'FuelOilNo2' and its associated "model_name" has been changed in a way to use an expected result file that already exits on github.
      puts model_name
      run_dir = "#{test_dir}/#{model_name}"
      if !Dir.exists?(run_dir)
        Dir.mkdir(run_dir)
      end
      #create standard model
      model = standard.load_building_type_from_library(building_type: building_type)
      standard.model_apply_standard(
        model: model,
        epw_file: epw_file,
        sizing_run_dir: run_dir,
        primary_heating_fuel: primary_heating_fuel,
        dcv_type: dcv_type,
        lights_type: lights_type,
        lights_scale: lights_scale,
        daylighting_type: daylighting_type,
        ecm_system_name: ecm_system_name,
        ecm_system_zones_map_option: ecm_system_zones_map_option,
        erv_package: erv_package,
        boiler_eff: boiler_eff,
        unitary_cop: unitary_cop,
        furnace_eff: furnace_eff,
        shw_eff: shw_eff,
        ext_wall_cond: ext_wall_cond,
        ext_floor_cond: ext_floor_cond,
        ext_roof_cond: ext_roof_cond,
        ground_wall_cond: ground_wall_cond,
        ground_floor_cond: ground_floor_cond,
        ground_roof_cond: ground_roof_cond,
        door_construction_cond: door_construction_cond,
        fixed_window_cond: fixed_window_cond,
        glass_door_cond: glass_door_cond,
        overhead_door_cond: overhead_door_cond,
        skylight_cond: skylight_cond,
        glass_door_solar_trans: glass_door_solar_trans,
        fixed_wind_solar_trans: fixed_window_solar_trans,
        skylight_solar_trans: skylight_solar_trans,
        rotation_degrees: rotation_degrees,
        fdwr_set: fdwr_set,
        srr_set: srr_set,
        nv_type: nv_type,
        nv_opening_fraction: nv_opening_fraction,
        nv_temp_out_min: nv_temp_out_min,
        nv_delta_temp_in_out: nv_delta_temp_in_out,
        scale_x: scale_x,
        scale_y: scale_y,
        scale_z: scale_z,
        pv_ground_type: pv_ground_type,
        pv_ground_total_area_pv_panels_m2: pv_ground_total_area_pv_panels_m2,
        pv_ground_tilt_angle: pv_ground_tilt_angle,
        pv_ground_azimuth_angle: pv_ground_azimuth_angle,
        pv_ground_module_description: pv_ground_module_description,
        chiller_type: chiller_type,
        occupancy_loads_scale: occupancy_loads_scale,
        electrical_loads_scale: electrical_loads_scale,
        oa_scale: oa_scale,
        infiltration_scale: infiltration_scale,
        output_variables: nil,
        shw_scale: shw_scale,
        output_meters: nil,
        airloop_economizer_type: airloop_economizer_type,
        baseline_system_zones_map_option: baseline_system_zones_map_option)
    elsif !@test_output.nil?
      model_name = @test_file
      top_dir_element = /btap_costing/ =~ File.expand_path(File.dirname( __FILE__))
      top_dir_name = File.expand_path(File.dirname(__FILE__))[0..(top_dir_element - 1)]
      run_dir = top_dir_name + 'btap_costing/' + @test_output
      in_file = top_dir_name + 'btap_costing' + @test_fold + @test_file
      model = BTAP::FileIO.load_osm(in_file)
      BTAP::Environment::WeatherFile.new(epw_file).set_weather_file(model)
    else
      model_name = @test_file
      run_dir = "#{test_dir}/#{model_name[0..-5]}"
      if !Dir.exists?(run_dir)
        Dir.mkdir(run_dir)
      end
      top_dir_element = /btap_costing/ =~ File.expand_path(File.dirname( __FILE__))
      top_dir_name = File.expand_path(File.dirname(__FILE__))[0..(top_dir_element - 1)]
      in_file = top_dir_name + 'btap_costing' + @test_fold + @test_file
      model = BTAP::FileIO.load_osm(in_file)
      BTAP::Environment::WeatherFile.new(epw_file).set_weather_file(model)
    end

    if @test_output.nil?
      #run model
      standard.model_run_simulation_and_log_errors(model, run_dir)
    end

    # mimic the process of running this measure in OS App or PAT
    model_out_path = "#{run_dir}/final.osm"
    cost_result_json_path = "#{run_dir}/cost_results.json"
    cost_list_json_path = "#{run_dir}/btap_items.json"

    #create osm file to use mimic PAT/OS server called final
    model.save(model_out_path, true)

    costing = BTAPCosting.new()
    costing.load_database()

    cost_result, _ = costing.cost_audit_all(model: model,
                                         prototype_creator: standard,
                                         template_type: template
    )

    File.open(cost_result_json_path, 'w') {|f| f.write(JSON.pretty_generate(cost_result, :allow_nan => true))}

    assert(File.exist?(cost_result_json_path), "Could not find costing json at this path:#{cost_result_json_path}")
    regression_files_folder = "#{File.dirname(__FILE__)}/regression_files"
    expected_result_filename = "#{regression_files_folder}/#{model_name}_expected_result.cost.json"
    test_result_filename = "#{regression_files_folder}/#{model_name}_test_result.cost.json"
    FileUtils.rm(test_result_filename) if File.exists?(test_result_filename)
    if File.exists?(expected_result_filename)
      unless FileUtils.compare_file(cost_result_json_path, expected_result_filename)
        FileUtils.cp(cost_result_json_path, test_result_filename)
        assert(false, "Regression test for #{model_name} produces differences. Examine expected and test result differences in the #{File.dirname(__FILE__)}/regression_files folder ")
      end
    else
      puts "No expected test file...Generating expected file #{expected_result_filename}. Please verify."
      FileUtils.cp(cost_result_json_path, expected_result_filename)
    end
    puts "Regression test for #{model_name} passed."

    # Do comparison of direct btap_costing results and those derived from the itemized cost list
    # Check if an itemized cost list file exists.  If it exists, do the comparison.  If not, Ignore the comparison.
    if File.exist?(cost_list_json_path)
      # Get the itemized cost list file.
      costList = JSON.parse(File.read(cost_list_json_path))
      # Cost the building based on the itemized cost list.
      btapCosting = BTAPCosting.new()
      cost_list_output = btapCosting.cost_list_items(btap_items: costList)
      # Get the detailed btap_costing result file:
      cost_result = JSON.parse(File.read(cost_result_json_path))
      cost_sum = cost_result['totals']
      # Compare the results and let the user know if there are differences.  Do not fail test if there are.
      puts("")
      puts("Comparing BTAP_Costing results and itemized costing list cost results:")
      puts("Envelope Cost Difference: #{cost_sum['envelope'].to_f - cost_list_output['envelope'].to_f}")
      puts("Lighting Cost Difference: #{cost_sum['lighting'].to_f - cost_list_output['lighting'].to_f}")
      puts("Heating and Cooling Cost Difference: #{cost_sum['heating_and_cooling'].to_f - cost_list_output['heating_and_cooling'].to_f}")
      puts("SHW Cost Difference: #{cost_sum['shw'].to_f - cost_list_output['shw'].to_f}")
      puts("Ventilation Cost Difference: #{cost_sum['ventilation'].to_f - cost_list_output['ventilation'].to_f}")
      cost_sum['renewables'].nil? ? sum_renew = 0.00 : sum_renew = cost_sum['renewables'].to_f
      puts("Renewables Cost Difference: #{sum_renew - cost_list_output['renewables'].to_f}")
      if cost_sum['grand_total'] == cost_list_output['grand_total']
        puts("No difference in costing between BTAP_Costing results and itemized cost list results.")
      else
        puts("Total Cost Difference: #{cost_sum['grand_total'].to_f - cost_list_output['grand_total'].to_f}")
      end
    end
  end
end


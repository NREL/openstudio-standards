require_relative '../../../../../openstudio-standards.rb'
require_relative './BtapResults_test_helper'
require 'minitest/autorun'
require 'optparse'
require 'fileutils'
require 'minitest/unit'
require 'optparse'


class BTAPResults_Test < Minitest::Test


  def test_qaqc()

    # check if there are any command line arguments, if there are run those
    input_args = ARGV

    #building_type = 'Outpatient'
    #building_type = 'LargeHotel'
    # building_type = 'FullServiceRestaurant'
    building_type = 'Warehouse'
    # building_type = 'LargeOffice'
    # building_type = 'MediumOffice'
    #building_type = 'MidriseApartment'

    #epw_file = "CAN_BC_Vancouver.Intl.AP.718920_CWEC2020.epw"
    epw_file = "CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw"
    #epw_file = "CAN_AB_Edmonton.Intl.AP.711230_CWEC2020.epw"
    #epw_file = "CAN_AB_Fort.Mcmurray.AP.716890_CWEC2020.epw"
    #epw_file = "CAN_NS_Halifax.Dockyard.713280_CWEC2020.epw"
    #epw_file = "CAN_QC_Montreal.Intl.AP.716270_CWEC2020.epw"
    #epw_file = "CAN_ON_Toronto.Intl.AP.716240_CWEC2020.epw"
    #epw_file = "CAN_NT_Yellowknife.AP.719360_CWEC2020.epw"

    #template = 'BTAPPRE1980'
    #template = 'BTAP1980TO2010'
    template = 'NECB2011'
    #template = 'NECB2015'
    # template = 'NECB2017'

    # daylighting_type = 'NECB_Default'
    daylighting_type = 'add_daylighting_controls'

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
        @test_file = building_type + '-' + template + '-' + epw_file[0..-5] + '-' + daylighting_type + '_expected_result.osm'
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
                                                   daylighting_type: daylighting_type,
                                                   cached: BTAPResultsHelper.cached)


  end


  def create_model_simulate_and_qaqc_regression_test(epw_file:,
                                                     template:,
                                                     building_type:,
                                                     daylighting_type:,
                                                     cached: true)

    helper = BTAPResultsHelper.new(__FILE__)
    model_name = "#{building_type}-#{template}-#{File.basename(epw_file, '.epw')}-#{daylighting_type}"
    test_dir = "#{File.dirname(__FILE__)}/output"
    run_dir = "#{test_dir}/#{model_name}"
    if !Dir.exist?(test_dir)
      Dir.mkdir(test_dir)
    end

    if !cached
      standard = Standard.build("#{template}")

      if @test_file.nil?
        # model_name = "#{building_type}-#{template}-#{File.basename(epw_file, '.epw')}"
        model_name = "#{building_type}-#{template}-#{File.basename(epw_file, '.epw')}-#{daylighting_type}"
        run_dir = "#{test_dir}/#{model_name}"
        if !Dir.exist?(run_dir)
          Dir.mkdir(run_dir)
        end
        #create standard model
        model = standard.load_building_type_from_library(building_type: building_type)
        standard.model_apply_standard(
          model: model,
          epw_file: epw_file,
          sizing_run_dir: run_dir,
          primary_heating_fuel: 'FuelOilNo2',
          dcv_type: nil,
          lights_type: nil,
          lights_scale: nil,
          daylighting_type: daylighting_type,
          ecm_system_name: nil,
          ecm_system_zones_map_option: nil,
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
          nv_type: nil,
          nv_opening_fraction: nil,
          nv_temp_out_min: nil,
          nv_delta_temp_in_out: nil,
          scale_x: nil,
          scale_y: nil,
          scale_z: nil,
          pv_ground_type: nil,
          pv_ground_total_area_pv_panels_m2: nil,
          pv_ground_tilt_angle: nil,
          pv_ground_azimuth_angle: nil,
          pv_ground_module_description: nil,
          chiller_type: nil,
          occupancy_loads_scale: nil,
          electrical_loads_scale: nil,
          oa_scale: nil,
          infiltration_scale: nil,
          output_variables: nil,
          shw_scale: nil,
          output_meters: nil,
          airloop_economizer_type: nil,
          baseline_system_zones_map_option: nil)

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
        if !Dir.exist?(run_dir)
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

      model_out_path = "#{run_dir}/final.osm"
      sql_path = "#{run_dir}/run/eplusout.sql"
      #create osm file to use mimic PAT/OS server called final
      model.save(model_out_path, true)
      helper.cache_osm_and_sql(model_path: model_out_path, sql_path: sql_path)
      post_analysis = BTAPDatapointAnalysis.new(
        model: model, 
        output_folder: run_dir, 
        template: template,
        standard: standard,
        qaqc: nil)
    else
      # Run the test with cached attributes
      post_analysis = helper.get_analysis(output_folder: run_dir, template: template)
    end

    cost_result = post_analysis.run_costing
    cost_result["openstudio-version"] = OpenstudioStandards::VERSION
    cost_result_json_path = "#{run_dir}/cost_results.json"
    cost_list_json_path = "#{run_dir}/btap_items.json"

    File.open(cost_result_json_path, 'w') {|f| f.write(JSON.pretty_generate(cost_result, :allow_nan => true))}

    assert(File.exist?(cost_result_json_path), "Could not find costing json at this path:#{cost_result_json_path}")
    regression_files_folder = "#{File.dirname(__FILE__)}/regression_files"
    expected_result_filename = "#{regression_files_folder}/#{model_name}_expected_result.cost.json"
    test_result_filename = "#{regression_files_folder}/#{model_name}_test_result.cost.json"
    FileUtils.rm(test_result_filename) if File.exist?(test_result_filename)
    if File.exist?(expected_result_filename)
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

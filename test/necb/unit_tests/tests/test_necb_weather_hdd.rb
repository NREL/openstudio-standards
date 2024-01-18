require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'
require_relative '../../../helpers/necb_helper'
include(NecbHelper)

# This test checks that the option to get HDD from the weather file or from an NECB table works properly.

class NECB_Weather_HDD_Tests < Minitest::Test

  def test_necb_weather_hdd()

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_necb_weather_hdd')
    @expected_results_file = File.join(__dir__, '../expected_results/necb_weather_hdd_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/necb_weather_hdd_test_results.json')
    @sizing_run_dir = File.join(@output_folder, 'sizing_folder')

    # Intial test condition
    @test_passed = true

    # Range of test options.
    @templates = [
      'BTAPPRE1980',
      'BTAP1980TO2010',
      'NECB2011',
      'NECB2015',
      'NECB2017',
      'NECB2020'
    ]
    @building_types = [
        'FullServiceRestaurant',
        #'HighriseApartment',
        #'Hospital',
        #'LargeHotel',
        #'LargeOffice',
        #'MediumOffice',
        #'MidriseApartment',
        #'Outpatient',
        #'PrimarySchool',
        #'QuickServiceRestaurant',
        #'RetailStandalone',
        #'SecondarySchool',
        #'SmallHotel',
        #'Warehouse'
    ]
    @epw_files = ['CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw']
    @primary_heating_fuels = ['Electricity']
    @necb_hdds = ['true', 'false', 'NECB_Default']


    # Test results storage array.
    @test_results_array = []

    @templates.sort.each do |template|
      @epw_files.sort.each do |epw_file|
        @building_types.sort.each do |building_type|
          @primary_heating_fuels.sort.each do |primary_heating_fuel|
            @necb_hdds.sort.each do |necb_hdd|
              if necb_hdd == 'true'
                necb_hdd_set = true
              elsif necb_hdd == 'false'
                necb_hdd_set = false
              else
                necb_hdd_set = necb_hdd
              end
              standard = Standard.build(template)
              model  = standard.model_create_prototype_model(
                template:template,
                building_type: building_type,
                epw_file: epw_file,
                sizing_run_dir: @sizing_run_dir,
                primary_heating_fuel: primary_heating_fuel,
                necb_hdd: necb_hdd_set
              )

              # Get the construction set name and use that to see if HDD from NECB or weather file was used
              result = {}
              result['template'] = template
              result['necb_hdd'] = necb_hdd
              result['construction_set_name'] = building_type
              construction_sets = model.getDefaultConstructionSets
              result['construction_set_name'] = construction_sets[0].name.to_s
              @test_results_array << result

            end #@necb_hdds.sort.each do |necb_hdd|
          end #@primary_heating_fuels.sort.each do |primary_heating_fuel|
        end #@building_types.sort.each do |building_type|
      end #@epw_files.sort.each do |epw_file|
    end #@templates.sort.each do |template|


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
    File.delete(@test_results_file)
  end

end

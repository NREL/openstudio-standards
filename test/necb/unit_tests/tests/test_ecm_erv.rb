require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'


#This test will check that the ERVs are added and the assignment from the erv.json library works.

class ECM_ERV_Tests < Minitest::Test

  def test_ecm_erv()

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_ecm_erv')
    @expected_results_file = File.join(__dir__, '../expected_results/ecm_erv_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/ecm_erv_test_results.json')
    @sizing_run_dir = File.join(@output_folder, 'sizing_folder')

    # Intial test condition
    @test_passed = true

    #Range of test options.
    @templates = [
        'NECB2011',
        #'NECB2015',
        #'NECB2017'
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
    @epw_files = ['CAN_AB_Banff.CS.711220_CWEC2016.epw']
    @primary_heating_fuels = ['Electricity']
    @erv_packages = ["NECB_Default","NECB_Default_All","Plate-Existing", 'Plate-All','Rotary-All']


    # Test results storage array.
    @test_results_array = []

    @templates.sort.each do |template|
      @epw_files.sort.each do |epw_file|
        @building_types.sort.each do |building_type|
          @primary_heating_fuels.sort.each do |primary_heating_fuel|
            @erv_packages.sort.each do |erv_package|
              standard = Standard.build(template)
              model  = standard.model_create_prototype_model(template:template,
                                               building_type: building_type,
                                               epw_file: epw_file,
                                               sizing_run_dir: @sizing_run_dir,
                                               primary_heating_fuel: primary_heating_fuel,
                                               erv_package: erv_package
              )

              # Get number of ERVs
              result = {}
              result['building_type'] = building_type
              result['erv_package'] = erv_package

              ervs = model.getHeatExchangerAirToAirSensibleAndLatents
              result['number_of_ervs'] = ervs.length
              if ervs.length >0
                heat_exchanger_air_to_air_sensible_and_latent = ervs[0]
                result['heatExchangerType'] = heat_exchanger_air_to_air_sensible_and_latent.heatExchangerType()
                result['sensibleEffectivenessat100HeatingAirFlow'] = heat_exchanger_air_to_air_sensible_and_latent.sensibleEffectivenessat100HeatingAirFlow()
                result['latentEffectivenessat100HeatingAirFlow'] = heat_exchanger_air_to_air_sensible_and_latent.latentEffectivenessat100HeatingAirFlow()
                result['sensibleEffectivenessat75HeatingAirFlow'] = heat_exchanger_air_to_air_sensible_and_latent.sensibleEffectivenessat75HeatingAirFlow()
                result['latentEffectivenessat75HeatingAirFlow'] = heat_exchanger_air_to_air_sensible_and_latent.latentEffectivenessat75HeatingAirFlow()
                result['sensibleEffectivenessat100CoolingAirFlow'] = heat_exchanger_air_to_air_sensible_and_latent.sensibleEffectivenessat100CoolingAirFlow()
                result['latentEffectivenessat100CoolingAirFlow'] = heat_exchanger_air_to_air_sensible_and_latent.latentEffectivenessat100CoolingAirFlow()
                result['sensibleEffectivenessat75CoolingAirFlow'] = heat_exchanger_air_to_air_sensible_and_latent.sensibleEffectivenessat75CoolingAirFlow()
                result['latentEffectivenessat75CoolingAirFlow'] = heat_exchanger_air_to_air_sensible_and_latent.latentEffectivenessat75CoolingAirFlow()
                result['supplyAirOutletTemperatureControl'] = heat_exchanger_air_to_air_sensible_and_latent.supplyAirOutletTemperatureControl()
                result['frostControlType'] = heat_exchanger_air_to_air_sensible_and_latent.frostControlType()
                result['economizerLockout'] = heat_exchanger_air_to_air_sensible_and_latent.economizerLockout()
                result['thresholdTemperature'] = heat_exchanger_air_to_air_sensible_and_latent.thresholdTemperature()
                result['initialDefrostTimeFraction'] = heat_exchanger_air_to_air_sensible_and_latent.initialDefrostTimeFraction().get
              end
              @test_results_array << result

            end #@erv_package.sort.each do |dcv_type|
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
  end

end

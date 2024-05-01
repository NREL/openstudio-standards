require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'


# Checks if BTAP::Activity instances are correctly deployed within BTAP.
class NECB_Activity_Tests < Minitest::Test
  def test_necb_activities()

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_necb_activities')
    @expected_results_file = File.join(__dir__, '../expected_results/necb_activities_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/necb_activities_test_results.json')
    @sizing_run_dir = File.join(@output_folder, 'sizing_folder')
    @test_results_array = [] # test results storage array

    # Intial test condition.
    @test_passed = true

    # Range of test options.
    @templates = [
      'NECB2011',
    # 'NECB2015',
    # 'NECB2017'
    ]

    @epws            = {}
    @epws['Calgary'] = 'CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw'

    @buildings = [
      # 'FullServiceRestaurant',
      # 'HighriseApartment',
      # 'Hospital',
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
      'Warehouse'
    ]

    @fuels = ['Electricity']

    fdback = []
    fdback << ""
    fdback << "BTAP::Activity Unit Tests"
    fdback << "~~~~ ~~~~ ~~~~ ~~~~"

    @templates.sort.each         do |template |
      @epws.sort.each            do |site, epw|
        @buildings.sort.each     do |building |
          @fuels.sort.each       do |fuel     |
            argh = {}
            cas  = "CASE #{building} | #{site} (#{template})"
            fdback << ""
            fdback << cas

            argh[:template            ] = template
            argh[:epw_file            ] = epw
            argh[:building_type       ] = building
            argh[:primary_heating_fuel] = fuel
            argh[:sizing_run_dir      ] = @sizing_run_dir

            st    = Standard.build(template)
            model = st.model_create_prototype_model(argh)
            fdback << st.activity.template

            if st.activity.activity.empty?
              fdback << "Empty BTAP::Activity 'activity' (TODO)"
            else
              fdback << st.activity.activity
              fdback << st.activity.category
              fdback << st.activity.stdtype
            end

            st.activity.feedback[:logs].each do |log|
            end

            # @todo: More testing ...
          end     # @fuels.sort.each     do |fuel     |
        end       # @buildings.sort.each do |building |
      end         # @epws.sort.each      do |site, epw|
    end           # @templates.sort.each do |template |

    # Temporary.
    fdback.each { |msg| puts msg }

    # Save test results to file.
    # File.open(@test_results_file, 'w') do |f|
    #   f.write(JSON.pretty_generate(@test_results_array))
    # end
  end

end

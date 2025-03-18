require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'


# Checks if BTAP::Activity instances are correctly deployed within BTAP.
class NECB_Activity_Tests < Minitest::Test
  def test_necb_activities()
    # ROUND 1 Testing: BTAP data file matching.
    necb2011_dir = 'lib/openstudio-standards/btap/'


    # ROUND 2 Testing: BTAP runs. BTAP file paths.
    outd = "output/test_necb_activities"
    eres = "../expected_results/necb_activities_expected_results.json"
    tres = "../expected_results/necb_activities_test_results.json"
    sizd = "sizing_folder"

    @output_folder         = File.join(__dir__, outd)
    @expected_results_file = File.join(__dir__, eres)
    @test_results_file     = File.join(__dir__, tres)
    @sizing_run_dir        = File.join(@output_folder, sizd)
    @test_results_array    = []

    # Intial test condition.
    @test_passed = true

    # Range of test options.
    @templates = [
      "NECB2011",
      # "NECB2015",
      # "NECB2017",
      # "NECB2020"
    ]

    @epws = ["CAN_AB_Calgary.Intl.AP.718770_CWEC2020.epw"]

    @buildings = [
      'FullServiceRestaurant',
      'HighriseApartment',
      'Hospital',
      'LargeHotel',
      'LargeOffice',
      'LEEPMidriseApartment',
      'LEEPPointTower',
      'LEEPTownHouse',
      'LEEPMultiTower',
      'LowRiseApartment',
      'MediumOffice',
      'MidriseApartment',
      'Outpatient',
      'PrimarySchool',
      'QuickServiceRestaurant',
      'RetailStandalone',
      'RetailStripMall',
      'SecondarySchool',
      'SmallHotel',
      'SmallOffice',
      'Warehouse'
    ]

    fdback = []
    fdback << ""
    fdback << "BTAP::Activity Unit Tests"
    fdback << "~~~~ ~~~~ ~~~~ ~~~~ ~~~~ "

    @epws.sort.each          do |epw      |
      @buildings.sort.each   do |building |
        @templates.sort.each do |template |
          cas = "CASE #{building} (#{template})"

          st    = Standard.build(template)
          model = st.model_create_prototype_model(template: template,
                                                  epw_file: epw,
                                                  building_type: building,
                                                  sizing_run_dir: @sizing_run_dir)

          a = st.activity

          err_msg = "Empty BTAP::Activity Hash (#{cas})?"
          assert(a.is_a?(BTAP::Activity), err_msg)
          err_msg = "BTAP::Activity activity (#{cas})?"
          assert(a.activity.is_a?(String), err_msg)
          err_msg = "BTAP::Activity category (#{cas})?"
          assert(a.category.is_a?(String), err_msg)
          err_msg = "BTAP::Activity empty activity (#{cas})?"
          assert(!a.activity.empty?, err_msg)
          err_msg = "BTAP::Activity empty category (#{cas})?"
          assert(!a.category.empty?, err_msg)
          err_msg = "BTAP::Activity common activity(#{cas})?"
          assert(a.category.downcase != "common", err_msg)

          fdback << "#{cas} : #{a.activity} (#{a.category})"
          fdback << "... Empty BTAP::Activity (TODO)" if a.activity.empty?

          st.activity.feedback[:logs].each { |log| puts log }

          # @todo: More testing ...
        end                   # |template |
      end                     # |building |
    end                       # |epw      |

    # Temporary.
    fdback.each { |msg| puts msg }

    # Save test results to file.
    # File.open(@test_results_file, 'w') do |f|
    #   f.write(JSON.pretty_generate(@test_results_array))
    # end
  end

end

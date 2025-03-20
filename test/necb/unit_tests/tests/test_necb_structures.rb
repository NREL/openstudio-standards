require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'


# Checks if BTAP::Structure instances are correctly deployed within BTAP.
class NECB_Structure_Tests < Minitest::Test
  def test_necb_structures()
    outd = "output/test_necb_structures"
    eres = "../expected_results/necb_structures_expected_results.json"
    tres = "../expected_results/necb_structures_test_results.json"
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
      # 'FullServiceRestaurant',
      # 'HighriseApartment',
      # 'Hospital',
      # 'LargeHotel',
      # 'LargeOffice',
      # 'LEEPMidriseApartment',
      # 'LEEPPointTower',
      # 'LEEPTownHouse',
      # 'LEEPMultiTower',
      # 'LowRiseApartment',
      # 'MediumOffice',
      # 'MidriseApartment',
      # 'Outpatient',
      # 'PrimarySchool',
      # 'QuickServiceRestaurant',
      # 'RetailStandalone',
      # 'RetailStripMall',
      # 'SecondarySchool',
      # 'SmallHotel',
      # 'SmallOffice',
      'Warehouse'
    ]

    fdback = []
    fdback << ""
    fdback << "BTAP::Structure Unit Tests"
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

          s = st.structure

          err_msg = "BTAP::Structure #{s.class} (#{cas})?"
          assert(s.is_a?(BTAP::Structure), err_msg)

          err_msg = "BTAP::Structure data #{s.data.class} (#{cas})?"
          assert(s.data.is_a?(Hash), err_msg)

          err_msg = "BTAP::Structure category #{s.category.class} (#{cas})?"
          assert(s.category.is_a?(String), err_msg)

          err_msg = "BTAP::Structure structure #{s.structure.class} (#{cas})?"
          assert(s.structure.is_a?(Symbol), err_msg)

          err_msg = "BTAP::Structure missing categories (#{cas})?"
          assert(s.data.key?(:category), err_msg)

          err_msg = "BTAP::Structure missing structures (#{cas})?"
          assert(s.data.key?(:structure), err_msg)

          unless s.data[:category].include?(s.category)
            fdback << "BTAP::Structure invalid category #{s.category} (#{cas})!"
            @test_passed = false
          end

          unless s.data[:structure].include?(s.structure)
            fdback << "BTAP::Structure invalid structure #{s.structure} (#{cas})!"
            @test_passed = false
          end

          fdback << "#{cas} : #{s.category} (#{s.structure})" if @test_passed

          s.feedback[:logs].each { |log| puts log }
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

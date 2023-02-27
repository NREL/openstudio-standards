require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'
require 'json'


#This test will check that TBD is correctly deployed within BTAP.
class NECB_TBD_Tests < Minitest::Test
  def test_necb_tbd()

    # File paths.
    @output_folder = File.join(__dir__, 'output/test_necb_tbd')
    @expected_results_file = File.join(__dir__, '../expected_results/necb_tbd_expected_results.json')
    @test_results_file = File.join(__dir__, '../expected_results/necb_tbd_test_results.json')
    @sizing_run_dir = File.join(@output_folder, 'sizing_folder')
    @test_results_array = [] # test results storage array

    # Intial test condition.
    @test_passed = true

    #Range of test options.
    # @templates = [
    #   'NECB2011',
    #   'NECB2015',
    #   'NECB2017'
    # ]

    @templates = ['NECB2011']

    @epws = ['CAN_AB_Banff.CS.711220_CWEC2016.epw']

    @buildings = [
      'FullServiceRestaurant',
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
    # 'Warehouse'
    ]

    @fuels = ['Electricity']

    # Optional PSI factor sets (e.g. optional for pre-NECB2017 templates). If
    # :none, neither TBD 'uprating' nor 'derating' calculations (and subsequent
    # modifications to generated OpenStudio models) are carried out. If instead
    # set to :uprate, psi factor sets are determined iteratively, see:
    #
    #   lib/openstudio-standards/btap/bridging.rb
    #
    # Otherwise, :bad vs :good PSI factor sets refer to costed BTAP details.
    @options = ['none', 'bad', 'good', 'uprate']
    # @options = ['uprate']

    fdback = []
    fdback << ""
    fdback << "BTAP/TBD Unit Tests"
    fdback << "~~~~ ~~~~ ~~~~ ~~~~"

    @templates.sort.each       do |template|
      @epws.sort.each          do |epw     |
        @buildings.sort.each   do |building|
          @fuels.sort.each     do |fuel    |
            @options.sort.each do |option  |
              cas = "CASE #{option} | #{building} (#{template})"
              fdback << ""
              fdback << cas
              st = Standard.build(template)
              model = st.model_create_prototype_model(template:template,
                                                      epw_file: epw,
                                                      building_type: building,
                                                      primary_heating_fuel: fuel,
                                                      tbd_option: option,
                                                      sizing_run_dir: @sizing_run_dir)

              if option == 'none'
                err_msg = "BTAP/TBD: Initialized ('#{cas}')?"
                assert(st.tbd.nil?, err_msg)

                model.getSurfaces.each do |surface|
                  id      = surface.nameString
                  lc      = surface.construction
                  err_msg = "BTAP/TBD: #{id} construction (#{cas})?"
                  assert(lc.is_initialized, err_msg)
                  boundary = surface.outsideBoundaryCondition.downcase
                  next unless boundary == "outdoors"

                  lc      = lc.get.to_LayeredConstruction
                  err_msg = "BTAP/TBD: #{id} layered construction (#{cas})?"
                  assert(lc.is_initialized, err_msg)
                  name    = lc.get.nameString.downcase
                  derated = name.include?(" c tbd")
                  err_msg = "BTAP/TBD processes enabled (#{cas})?"
                  assert(derated == false, err_msg)
                end

                fdback << "BTAP/TBD processes skipped"
              else
                err_msg = "BTAP/TBD: Uninitialized (#{cas})?"
                assert(st.tbd.is_a?(BTAP::Bridging), err_msg)
                err_msg = "BTAP/TBD: Missing model Hash (#{cas})?"
                assert(st.tbd.model.is_a?(Hash), err_msg)
                err_msg = "BTAP/TBD: Missing feedback Hash (#{cas})?"
                assert(st.tbd.feedback.is_a?(Hash), err_msg)
                err_msg = "BTAP/TBD: Missing feedback logs (#{cas})?"
                assert(st.tbd.feedback.key?(:logs), err_msg)
                err_msg = "BTAP/TBD: Invalid feedback logs (#{cas})?"
                assert(st.tbd.feedback[:logs].is_a?(Array), err_msg)
                err_msg = "BTAP/TBD: Missing tally Hash (#{cas})?"
                assert(st.tbd.tally.is_a?(Hash), err_msg)
                err_msg = "BTAP/TBD: Missing model 'comply' key (#{cas})?"
                assert(st.tbd.model.key?(:comply), err_msg)

                err_msg = "BTAP/TBD: Missing TBD 'surfaces' (#{cas})?"
                assert(st.tbd.model.key?(:surfaces), err_msg)
                err_msg = "BTAP/TBD: TBD 'surfaces' Hash (#{cas})?"
                assert(st.tbd.model[:surfaces].is_a?(Hash), err_msg)
                err_msg = "BTAP/TBD: Empty TBD 'surfaces' (#{cas})?"
                assert(st.tbd.model[:surfaces].empty? == false, err_msg)
                surfaces = st.tbd.model[:surfaces]

                # Regardless of whether BTAP/TBD were successful or not in
                # uprating the building constructions (i.e. option == 'uprate'),
                # deratable surfaces should have been derated nonetheless.
                model.getSurfaces.each do |surface|
                  id = surface.nameString
                  err_msg = "BTAP/TBD: Mismatched #{id} surfaces (#{cas})?"
                  assert(surfaces.key?(id), err_msg)
                  next unless surfaces[id].key?(:deratable)
                  next unless surfaces[id].key?(:type     )
                  next unless surfaces[id].key?(:heatloss )
                  next unless surfaces[id][:deratable]
                  next unless surfaces[id][:heatloss ].abs > TBD::TOL

                  lc      = surface.construction
                  err_msg = "BTAP/TBD: #{id} construction (#{cas})?"
                  assert(lc.is_initialized, err_msg)
                  lc      = lc.get.to_LayeredConstruction
                  err_msg = "BTAP/TBD: #{id} layered construction (#{cas})?"
                  assert(lc.is_initialized, err_msg)
                  nom     = lc.get.nameString.downcase
                  err_msg = "Failed TBD processes (#{cas})?"
                  assert(nom.include?(" c tbd"), err_msg)
                end

                st.tbd.feedback[:logs].each do |log|
                  next if log.include?("(OSut::scheduleCompactMinMax)")
                  next if log.include?("TBD-identified non-FATAL error(s):")

                  fdback << log

                  # NOTE: BTAP/TBD feedback logs are simple strings. Look up
                  # st.tbd.tally Hash to extract quantities for costing.
                end
              end
            end # @options.each        do |option |
          end   # @fuels.sort.each     do |fuel    |
        end     # @buildings.sort.each do |building|
      end       # @epws.sort.each      do |epw     |
    end         # @templates.sort.each do |template|

    # Temporary.
    fdback.each { |msg| puts msg }

    # Save test results to file.
    # File.open(@test_results_file, 'w') do |f|
    #   f.write(JSON.pretty_generate(@test_results_array))
    # end
  end

end
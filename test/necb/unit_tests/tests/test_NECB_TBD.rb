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

    # Intial test condition.
    @test_passed = true

    #Range of test options.
    @templates = [
      'NECB2011',
      'NECB2015',
      'NECB2017'
    ]

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

    @derating = [true]

    @uprating = [true]

    @test_results_array = [] # test results storage array

    @templates.sort.each     do |template|
      @epws.sort.each        do |epw     |
        @buildings.sort.each do |building|
          @fuels.sort.each   do |fuel    |
            @derating.each   do |derate  |
              @uprating.each do |uprate  |
                st = Standard.build(template)
                model = st.model_create_prototype_model(template:template,
                                             building_type: building,
                                             derate: derate,
                                             uprate: uprate,
                                             epw_file: epw,
                                             sizing_run_dir: @sizing_run_dir,
                                             primary_heating_fuel: fuel)

                puts "TBD ---"

                model.getSurfaces.each do |surface|
                  id = surface.nameString
                  conditions = surface.outsideBoundaryCondition.downcase
                  next unless conditions == "outdoors"
                  lc = surface.construction
                  puts "WHAT THE? #{id}?"   if lc.empty?
                  next                      if lc.empty?

                  lc = lc.get.to_LayeredConstruction
                  puts "WHAT NOW? #{id}?"   if lc.empty?
                  next                      if lc.empty?

                  lc  = lc.get
                  nom = lc.nameString

                  if surface.isConstructionDefaulted
                    next if id.downcase.include?("roof")   # unconditioned attic
                    next if derate == false

                    puts "Hmm ... #{nom} vs #{id}?"        # shouldn't happen ...
                  else
                    puts "#{nom}: unique to #{id} surface"
                    next if nom.downcase.include?("c tbd")

                    puts "Hmmm ... #{nom} vs #{id}?"
                  end
                end

                puts "TBD --"

              end # @uprating.each do |uprate|
            end   # @derating.each do       |derate  |
          end     # @fuels.sort.each do     |fuel    |
        end       # @buildings.sort.each do |building|
      end         # @epws.sort.each do      |epw     |
    end           # @templates.sort.each do |template|


    # Save test results to file.
    File.open(@test_results_file, 'w') do |f|
      f.write(JSON.pretty_generate(@test_results_array))
    end
  end

end

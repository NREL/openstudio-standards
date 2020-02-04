require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'


class TestAddFFactorFloor < CreateDOEPrototypeBuildingTest

  def test_set_90_1_floor_constructions

    #Define paths to OSMs that have been prepared with no basement wall constructions defined
    wd = File.expand_path('models/')
    small_office_osm = wd + '/SmallOffice_FFactor_Test.osm'
    retail_stand_alone_osm = wd + '/RetailStandAlone_FFactor_Test.osm'

    #Mapping of ASHRAE 90.1 standards + climate zones to their respective assembly F-Factor parameters
    cases = {
        # Format: [CZ, template, OSM path]                          => [F-factor (SI), Area (m2), Perimeter (m)]
        ['ASHRAE 169-2013-1A', '90.1-2004', small_office_osm]       => [1.26363, 113.45, 27.69],
        ['ASHRAE 169-2013-2A', '90.1-2007', small_office_osm]       => [1.26363, 113.45, 27.69],
        ['ASHRAE 169-2013-3A', '90.1-2010', small_office_osm]       => [1.26363, 113.45, 27.69],
        ['ASHRAE 169-2013-3B', '90.1-2004', small_office_osm]       => [1.26363, 113.45, 27.69],
        ['ASHRAE 169-2013-4A', '90.1-2013', small_office_osm]       => [0.90012, 113.45, 27.69],
        ['ASHRAE 169-2013-5A', '90.1-2007', retail_stand_alone_osm] => [1.26363, 379.89, 68.27],
        ['ASHRAE 169-2013-6A', '90.1-2013', retail_stand_alone_osm] => [0.88281, 379.89, 68.27],
        ['ASHRAE 169-2013-7A', '90.1-2013', retail_stand_alone_osm] => [0.88281, 379.89, 68.27],
        ['ASHRAE 169-2013-8A', '90.1-2004', retail_stand_alone_osm] => [0.93474, 379.89, 68.27]
    }

    cases.each do |input_parameters, expected_parameters|

      #Parse the parameter inputs for this case
      climate_zone = input_parameters[0]
      template = input_parameters[1]
      osm_path = input_parameters[2]

      #Parse expected F-Factor construction parameters
      standard_f_factor = expected_parameters[0]
      standard_area = expected_parameters[1]
      standard_perimeter = expected_parameters[2]

      #load the example OSM ready for f-factor constructions
      translator = OpenStudio::OSVersion::VersionTranslator.new
      ospath = OpenStudio::Path.new(osm_path)
      model = translator.loadModel(ospath).get

      #build the Standard object
      standard = Standard.build(template)

      #Set f-factor constructions
      standard.set_90_1_floor_constructions(model, climate_zone)

      #parse the modified model for the F-Factor constructions
      expected_name = "Foundation F #{f_factor.round(2).to_s} Perim #{perimeter.round(2).to_s} Area #{area.round(2).to_s}".gsub('.','')
      f_factor_construction = model.getFFactorGroundFloorConstructionByName(expected_name)

      #Ensure that the f_factor
      assert(f_factor_construction.is_initialized, "F-Factor construction ''#{expected_name}'' exists in model: #{f_factor_construction.is_initialized}")
      #puts "F-Factor construction ''#{expected_name}'' exists in model: #{f_factor_construction.is_initialized}"

      f_factor_construction = f_factor_construction.get

      generated_f_factor = f_factor_construction.getFFactor.value.round(5)
      generated_area = f_factor_construction.area.round(2)
      generated_perimeter = f_factor_construction.perimeterExposed.round(2)

      asserts = {
          'F_Factor' => [generated_f_factor, standard_f_factor],
          'Area' => [generated_area, standard_area],
          'Perimeter' => [generated_perimeter, standard_perimeter]
      }
      asserts.each do |assert_key, assert_content|
        assert(assert_content[0].to_s.to_f == assert_content[1].to_s.to_f, "#{climate_zone} #{template} - #{assert_key} - #{assert_content[0]}:#{assert_content[1]}")
        #puts "#{climate_zone} #{template} - #{assert_key} - Generated = #{assert_content[0]}:  Expected = #{assert_content[1]}"
      end
    end

  end #END: test_set_90_1_floor_constructions

end

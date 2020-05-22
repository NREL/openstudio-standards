require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'
require_relative '../../lib/openstudio-standards/btap/btap'

class TestAddCFactorWall < CreateDOEPrototypeBuildingTest


  def test_model_set_below_grade_wall_constructions

    #Define paths to OSMs that have been prepared with no basement wall constructions defined
    hospital_osm_path = "#{File.dirname(__FILE__)}/models/Hospital_CFactor_Test.osm"
    large_hotel_osm_path = "#{File.dirname(__FILE__)}/models/LargeHotel_CFactor_Test.osm"

    #Mapping of ASHRAE 90.1 standards + climate zones to their respective assembly C-Factors
    cases = {
        # Format: [CZ, template, OSM path] = C-factor (SI)
        ['ASHRAE 169-2013-1A', '90.1-2004', hospital_osm_path, 'Hospital'] => 6.47,
        ['ASHRAE 169-2013-2A', '90.1-2007', hospital_osm_path, 'Hospital'] => 6.47,
        ['ASHRAE 169-2013-3A', '90.1-2010', hospital_osm_path, 'Hospital'] => 6.47,
        ['ASHRAE 169-2013-3B', '90.1-2004', hospital_osm_path, 'Hospital'] => 6.47,
        ['ASHRAE 169-2013-4A', '90.1-2013', hospital_osm_path, 'Hospital'] => 0.68,
        ['ASHRAE 169-2013-5A', '90.1-2007', large_hotel_osm_path, 'LargeHotel'] => 0.68,
        ['ASHRAE 169-2013-6A', '90.1-2013', large_hotel_osm_path, 'LargeHotel'] => 0.52,
        ['ASHRAE 169-2013-7A', '90.1-2013', large_hotel_osm_path, 'LargeHotel'] => 0.36,
        ['ASHRAE 169-2013-8A', '90.1-2007', large_hotel_osm_path, 'LargeHotel'] => 0.68
    }

    #Below grade wall height of both Large Hotel and Hospital is the same at 2.439 meters
    basement_wall_height = 2.439 #meters

    cases.each do |parameters, c_factor_standard|

      #Parse the parameters for this case
      climate_zone = parameters[0]
      template = parameters[1]
      osm_path = parameters[2]
      building_type = parameters[3]

      #load the example OSM ready for c-factor constructions
      model = BTAP::FileIO::load_osm(osm_path)

      #build the Standard object
      standard = Standard.build(template)

      #Set c-factor constructions
      standard.model_set_below_grade_wall_constructions(model, building_type, climate_zone)

      #parse the modified model for the C-Factor constructions (it should be the only CFactor construction)
      c_factor_construction = model.getCFactorUndergroundWallConstructions[0]

      c_factor_height =  c_factor_construction.height.round(3)
      c_factor_generated = c_factor_construction.getCFactor.value.round(2)


      asserts = {
          'Height' => [c_factor_height, basement_wall_height],
          'C_Factor' => [c_factor_generated, c_factor_standard]
      }
      asserts.each do |assert_key, assert_content|

        #puts "#{climate_zone} #{template} - #{assert_key} - Generated = #{assert_content[0]}:  Expected = #{assert_content[1]}"
        assert(assert_content[0].to_s.to_f == assert_content[1].to_s.to_f, "#{climate_zone} #{template} - #{assert_key} - #{assert_content[0]}:#{assert_content[1]}")
      end
    end

  end

end

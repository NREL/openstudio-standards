# *********************************************************************
# *  Copyright (c) 2008-2015, Natural Resources Canada
# *  All rights reserved.
# *
# *  This library is free software; you can redistribute it and/or
# *  modify it under the terms of the GNU Lesser General Public
# *  License as published by the Free Software Foundation; either
# *  version 2.1 of the License, or (at your option) any later version.
# *
# *  This library is distributed in the hope that it will be useful,
# *  but WITHOUT ANY WARRANTY; without even the implied warranty of
# *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# *  Lesser General Public License for more details.
# *
# *  You should have received a copy of the GNU Lesser General Public
# *  License along with this library; if not, write to the Free Software
# *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
# **********************************************************************/

$LOAD_PATH.unshift File.expand_path('../../../../openstudio-standards/lib', __FILE__)
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ApplyNECBRules_test < MiniTest::Test
  def apply_measure(filename) 

    # create an instance of the measure, a runner and load a model.
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/#{filename}")
    measure = ApplyNECBRules.new
    runner = OpenStudio::Ruleset::OSRunner.new
    output_folder = "#{File.dirname(__FILE__)}/output/"

    #set weather file. 
    [
      "CAN_BC_Vancouver.718920_CWEC.epw", #climate 5
      "CAN_ON_Toronto.716240_CWEC.epw", #climate 6
      "CAN_AB_Calgary.718770_CWEC.epw", #climate 7a
      "CAN_YT_Whitehorse.719640_CWEC.epw", #climate 7b
      "CAN_NU_Resolute.719240_CWEC.epw"    #climate zone 8
    ].each do |weatherfile|
      weather =  BTAP::Environment::WeatherFile.new(weatherfile)
      weather.set_weather_file( model, runner)

      #Add default Construction.
      construction_file = "#{File.dirname(__FILE__)}/BTAP_Construction_Library.osm"
      construction_set = BTAP::Resources::Envelope::ConstructionSets::get_construction_set_from_library( construction_file, "DND-Metal")
      #Set Construction Set.
      unless model.building.get.setDefaultConstructionSet( construction_set.clone( model ).to_DefaultConstructionSet.get )
        BTAP::runner_register("Error","Could not set Default Construction #{@construction_set_name} ", runner)
        return false
      end
    
     
      #Set up arguments in order. 
      argument_values_array = 
        [
      ]
      #run the measure with the arguments.
      measure.set_user_arguments_and_apply(model,argument_values_array,runner)
      file_path = "#{output_folder}/#{weather.location_name}/#{filename}"
      BTAP::FileIO::save_osm(model, file_path)
      BTAP::runner_register("INFO", "OSM file converted to NECB 2011 rules #{file_path}", runner)
    
      #return condition of measure.
      assert_equal("Success", runner.result.value.valueName)
    end
  end   
  

  def test_FullServiceRestaurant 
    apply_measure("FullServiceRestaurant.osm") 
  end
  def test_Hospital 
    apply_measure("Hospital.osm") 
  end
  def test_LargeHotel 
    apply_measure("LargeHotel.osm") 
  end
  def test_LargeOffice 
    apply_measure("LargeOffice.osm") 
  end
  def test_MediumOffice 
    apply_measure("MediumOffice.osm") 
  end
  def test_MidriseApartment 
    apply_measure("MidriseApartment.osm") 
  end
  def test_OutPatient 
    apply_measure("OutPatient.osm") 
  end
  def test_PrimarySchool 
    apply_measure("PrimarySchool.osm") 
  end
  def test_QuickServiceRestaurant 
    apply_measure("QuickServiceRestaurant.osm") 
  end
  def test_SecondarySchool 
    apply_measure("SecondarySchool.osm") 
  end
  def test_SmallHotel 
    apply_measure("SmallHotel.osm") 
  end
  def test_SmallOffice 
    apply_measure("SmallOffice.osm") 
  end
  def test_StandaloneRetail 
    apply_measure("Stand-aloneRetail.osm") 
  end
  def test_StripMall 
    apply_measure("StripMall.osm") 
  end
  def test_SuperMarket 
    apply_measure("SuperMarket.osm") 
  end
  def test_Warehouse 
    apply_measure("Warehouse.osm") 
  end


end

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


require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ApplyNECBRules_test < MiniTest::Unit::TestCase
  def apply_measure(filename) 

    # create an instance of the measure, a runner and load a model.
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/#{filename}")
    measure = ApplyNECBRules.new
    runner = OpenStudio::Ruleset::OSRunner.new
    output_folder = "#{File.dirname(__FILE__)}/output/"

    #set weather file. 
    weatherfile = "#{File.dirname(__FILE__)}/CAN_AB_Calgary.718770_CWEC.epw"
    BTAP::Environment::WeatherFile.new(weatherfile).set_weather_file( model, runner)

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
    file_path = "#{output_folder}/#{filename}"
    BTAP::FileIO::save_osm(model, file_path)
    BTAP::runner_register("INFO", "OSM file converted to NECB 2011 rules #{file_path}", runner)
    
    #return condition of measure.
    assert_equal("Success", runner.result.value.valueName)
  end   
  

  def testFullServiceRestaurant 
    apply_measure("FullServiceRestaurant.osm") 
  end
  def testHospital 
    apply_measure("Hospital.osm") 
  end
  def testLargeHotel 
    apply_measure("LargeHotel.osm") 
  end
  def testLargeOffice 
    apply_measure("LargeOffice.osm") 
  end
  def testMediumOffice 
    apply_measure("MediumOffice.osm") 
  end
  def testMidriseApartment 
    apply_measure("MidriseApartment.osm") 
  end
  def testOutPatient 
    apply_measure("OutPatient.osm") 
  end
  def testPrimarySchool 
    apply_measure("PrimarySchool.osm") 
  end
  def testQuickServiceRestaurant 
    apply_measure("QuickServiceRestaurant.osm") 
  end
  def testSecondarySchool 
    apply_measure("SecondarySchool.osm") 
  end
  def testSmallHotel 
    apply_measure("SmallHotel.osm") 
  end
  def testSmallOffice 
    apply_measure("SmallOffice.osm") 
  end
  def testStandaloneRetail 
    apply_measure("Stand-aloneRetail.osm") 
  end
  def testStripMall 
    apply_measure("StripMall.osm") 
  end
  def testSuperMarket 
    apply_measure("SuperMarket.osm") 
  end
  def testWarehouse 
    apply_measure("Warehouse.osm") 
  end


end

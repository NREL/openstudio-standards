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

class ConvertDOEReferenceToNECBOSM_test < MiniTest::Unit::TestCase
  def apply_measure(filename) 

    # create an instance of the measure, a runner and load a model.
    model = OpenStudio::Model::Model.new
    measure = ConvertDOEReferenceToNECBOSM.new
    runner = OpenStudio::Ruleset::OSRunner.new
    output_folder = "#{File.dirname(__FILE__)}/output/"

    #Set up arguments in order. 
    argument_values_array = 
      [
      ["idf_file_path",   "#{File.dirname(__FILE__)}/../#{filename}"      ]
    ]
    #run the measure with the arguments.
    measure.set_user_arguments_and_apply(model,argument_values_array,runner)
    file_path = "#{output_folder}/#{File.basename(filename, ".idf")}.osm"
    BTAP::FileIO::save_osm(model, file_path)
    BTAP::runner_register("INFO", "IDF file converted to OSM #{file_path}", runner)
    
    #return condition of measure.
    assert_equal("Success", runner.result.value.valueName)
    
  end


  def test_FullServiceRestaurant 
    apply_measure("FullServiceRestaurant.idf") 
  end
  def test_Hospital 
    apply_measure("Hospital.idf") 
  end
  def test_LargeHotel 
    apply_measure("LargeHotel.idf") 
  end
  def test_LargeOffice 
    apply_measure("LargeOffice.idf") 
  end
  def test_MediumOffice 
    apply_measure("MediumOffice.idf") 
  end
  def test_MidriseApartment 
    apply_measure("MidriseApartment.idf") 
  end
  def test_OutPatient 
    apply_measure("OutPatient.idf") 
  end
  def test_PrimarySchool 
    apply_measure("PrimarySchool.idf") 
  end
  def test_QuickServiceRestaurant 
    apply_measure("QuickServiceRestaurant.idf") 
  end
  def test_SecondarySchool 
    apply_measure("SecondarySchool.idf") 
  end
  def test_SmallHotel 
    apply_measure("SmallHotel.idf") 
  end
  def test_SmallOffice 
    apply_measure("SmallOffice.idf") 
  end
  def test_StandaloneRetail 
    apply_measure("Stand-aloneRetail.idf") 
  end
  def test_StripMall 
    apply_measure("StripMall.idf") 
  end
  def test_SuperMarket 
    apply_measure("SuperMarket.idf") 
  end
  def test_Warehouse 
    apply_measure("Warehouse.idf") 
  end

  
end

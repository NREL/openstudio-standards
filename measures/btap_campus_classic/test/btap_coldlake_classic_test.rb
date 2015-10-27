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

class ColdLakeClassic_test < MiniTest::Unit::TestCase
  def test_construction_assignment()   
    # create an instance of the measure, a runner and load a model.
    model = BTAP::FileIO::load_osm("#{File.dirname(__FILE__)}/5ZoneNoHVAC.osm")
    measure = ColdLakeClassic.new
    runner = OpenStudio::Ruleset::OSRunner.new
    #Set up arguments in order. 
    argument_values_array = nil
    #run the measure with the arguments.
    measure.set_user_arguments_and_apply(model,argument_values_array,runner)
    #return condition of measure.
    assert_equal("Success", runner.result.value.valueName)
  end   
end
 

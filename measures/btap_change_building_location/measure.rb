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

# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide
require 'fileutils'
require "date"
release_mode = false
folder = "#{File.dirname(__FILE__)}/../../../../lib/btap/lib/"

if release_mode == true
  #Copy BTAP files to measure from lib folder. Use this to create independant measure. 
  Dir.glob("#{folder}/**/*rb").each do |file|
    FileUtils.cp(file, File.dirname(__FILE__))
  end
  require "#{File.dirname(__FILE__)}/btap.rb"
else
  #For only when using git hub development environment.
  require "#{File.dirname(__FILE__)}/../../../../lib/btap/lib/btap.rb"
end



#see the URL below for information on how to write OpenStudio measures
# TODO: Remove this link and replace with the wiki
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html



class ChangeBuildingLocation < BTAP::Measures::OSMeasures::BTAPModelUserScript

  attr_reader :weather_directory

  def initialize
    super
    self.file = "#{__FILE__}"
    # Hard code the weather directory for now. This assumes that you are running
    # the analysis on the OpenStudio distributed analysis server
    @weather_directory = File.expand_path(File.join(File.dirname(__FILE__), "../../weather"))
  end

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    'ChangeBuildingLocation'
  end

  #define the arguments that the user will input
  def arguments(model)
    #list of arguments as they will appear in the interface. They are available in the run command as
    @argument_array_of_arrays = [
      [    "variable_name",          "type",          "required",  "model_dependant", "display_name",                 "default_value",  "min_value",  "max_value",  "string_choice_array",  	"os_object_type"	],
      [    "weather_file_name",      "STRING",        true,        false,             "Weather File Name",                nil,               nil,          nil,           nil,  	         nil					],
      #Default set for server weather folder.
      [    "weather_directory",      "STRING",        true,        false,             "Weather Directory",               "../../weather",               nil,          nil,          nil,	                       nil					]
            
    ]
    #set up arguments. 
    args = OpenStudio::Ruleset::OSArgumentVector.new
    self.argument_setter(args)
    return args
  end

  # Define what happens when the measure is run
  def measure_code(model,runner)
    ################ Start Measure code here ################################
    # Argument will be passed as instance variable. So if your argument was height, your can access it using @height. 

    # report initial condition
    site = model.getSite
    initial_design_days = model.getDesignDays
    if site.weatherFile.is_initialized
      weather = site.weatherFile.get
      runner.registerInitialCondition("The initial weather file path was '#{weather.path.get}' and the model had #{initial_design_days.size} design days.")
    else
      runner.registerInitialCondition("The initial weather file has not been set and the model had #{initial_design_days.size} design days.")
    end


    #Check form weather directory Weather File
    unless (Pathname.new @weather_directory).absolute?
      @weather_directory = File.expand_path(File.join(File.dirname(__FILE__), @weather_directory))
    end
    weather_file = File.join(@weather_directory, @weather_file_name)
    if File.exists?(weather_file) and @weather_file_name.downcase.include? ".epw"
      BTAP::runner_register("Info", "The epw weather file #{weather_file} was found!", runner)
    else
      BTAP::runner_register("Error","'#{weather_file}' does not exist or is not an .epw file.", runner)
      return false
    end

    begin
      weather = BTAP::Environment::WeatherFile.new(weather_file)
      #Set Weather file to model.
      weather.set_weather_file(model)
      #Store information about this run in the runner for output. This will be in the csv and R dumps.
      runner.registerValue( 'city',weather.city )
      runner.registerValue( 'state_province_region ',weather.state_province_region )
      runner.registerValue( 'country',weather.country )
      runner.registerValue( 'hdd18',weather.hdd18 )
      runner.registerValue( 'cdd18',weather.cdd18 )
      runner.registerValue( 'necb_climate_zone',BTAP::Compliance::NECB2011::get_climate_zone_name(weather.hdd18).to_s)
      runner.registerFinalCondition( "Model ended with weatherfile of #{model.getSite.weatherFile.get.path.get}" )
    rescue
      BTAP::runner_register("Error","'#{weather_file}' could not be loaded into model.", runner)

      return false
    end
    BTAP::runner_register("FinalCondition","Weather file set to #{weather_file}",runner)
    return true
  end
  

  
end

# This allows the measure to be use by the application
ChangeBuildingLocation.new.registerWithApplication
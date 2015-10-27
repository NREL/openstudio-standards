
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

# start the measure
class SetDefaultConstructionSet < BTAP::Measures::OSMeasures::BTAPModelUserScript

  attr_reader :lib_directory

  def initialize
    super
    self.file = "#{__FILE__}"
    # Hard code to the weather directory for now. This assumes that you are running
    # the analysis on the OpenStudio distributed analysis server
    @lib_directory = File.expand_path(File.join(File.dirname(__FILE__), "../../lib/btap/resources/constructions"))
  end
  
  # human readable name
  def name
    return "Set Default Construction Set"
  end

  # human readable description
  def description
    return "Loads and Set the a default construction library from an osm file. "
  end

  # human readable description of modeling approach
  def modeler_description
    return "Loads and Set the a default construction library from an osm file.  "
  end

  # define the arguments that the user will input
  def arguments(model)
    #list of arguments as they will appear in the interface. They are available in the run command as
    @argument_array_of_arrays = [
      [    "variable_name",              "type",          "required",  "model_dependant", "display_name",                 "default_value",  "min_value",  "max_value",  "string_choice_array",  	"os_object_type"	],
      [    "lib_file_name",              "STRING",        true,        false,             "Lib File Name",                nil,               nil,          nil,           nil,  	         nil					],
      [    "construction_set_name",      "STRING",        true,        false,             "Construction Set Name",        nil,               nil,          nil,           nil,  	         nil					],
      
      #Default set for server weather folder.
      [    "lib_directory",      "STRING",        true,        false,             "Lib Directory",               "../../lib/btap/resources/constructions",               nil,          nil,          nil,	                       nil					]
            
    ]
    #set up arguments. 
    args = OpenStudio::Ruleset::OSArgumentVector.new
    self.argument_setter(args)
    return args
  end

  # define what happens when the measure is run
  def measure_code(model,runner)
    ################ Start Measure code here ################################
    
    #Check weather directory Weather File
    unless (Pathname.new @lib_directory).absolute?
      @lib_directory = File.expand_path(File.join(File.dirname(__FILE__), @lib_directory))
    end
    lib_file = File.join(@lib_directory, @lib_file_name)
    if File.exists?(lib_file) and @lib_file_name.downcase.include? ".osm"
      BTAP::runner_register("Info","#{@lib_file_name} Found!.", runner)
    else
      BTAP::runner_register("Error","#{lib_file} does not exist or is not an .osm file.", runner)
      return false
    end
         
    #load model and test.
    construction_set = BTAP::Resources::Envelope::ConstructionSets::get_construction_set_from_library( lib_file, @construction_set_name )
    #Set Construction Set.
    unless model.building.get.setDefaultConstructionSet( construction_set.clone( model ).to_DefaultConstructionSet.get )
      BTAP::runner_register("Error","Could not set Default Construction #{@construction_set_name} ", runner)
      return false
    end
    BTAP::runner_register("FinalCondition","Default Construction set to #{@construction_set_name} from #{lib_file}",runner)
    ##########################################################################
    return true
  end
end

# register the measure to be used by the application
SetDefaultConstructionSet.new.registerWithApplication

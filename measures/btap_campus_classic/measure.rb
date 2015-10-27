
#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

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





#start the measure
class ColdLakeClassic < BTAP::Measures::OSMeasures::BTAPModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ColdLakeVintageMaker"
  end



  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end #end the arguments method


  def measure_code(model,runner)
    measure_folder = "#{File.dirname(__FILE__)}/"
    baseline_spreadsheet = "#{File.dirname(__FILE__)}/baseline.csv"
    #Note: place output folder locally to run faster! (e.g. your C drive)
    output_folder = "#{File.dirname(__FILE__)}/output"
    create_models = true
    simulate_models = true
    create_annual_outputs = true
    create_hourly_outputs = true
    #This creates the measures object and collects all the csv information for the
    # measure_id variant.
    csv_measures = BTAP::Measures::CSV_OS_Measures.new(
      baseline_spreadsheet,
      measure_folder#script root folder where all the csv relative paths are used.
    )
    csv_measures.create_cold_lake_vintages(output_folder) unless create_models == false
    BTAP::SimManager::simulate_all_files_in_folder(output_folder) unless simulate_models == false
    BTAP::Reporting::get_all_annual_results_from_runmanger(output_folder) unless create_annual_outputs == false
    #convert eso to csv then create terminus file.
    BTAP::FileIO::convert_all_eso_to_csv(output_folder, output_folder).each {|csvfile| BTAP::FileIO::terminus_hourly_output(csvfile)} unless create_hourly_outputs == false

  end
  
end #end the measure
#this allows the measure to be use by the application
ColdLakeClassic.new.registerWithApplication
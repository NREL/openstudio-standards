
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
class ApplyNECBRules < BTAP::Measures::OSMeasures::BTAPModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ApplyNECBRules"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end #end the arguments method


  def measure_code(model,runner)
    #get OSM files in measure
    BTAP::runner_register("INFO", "Apply NECB 2011 rules", runner)

    #determine weather file. 
    if model.weatherFile.empty? or model.weatherFile.get.path.empty?
      BTAP::runner_register("ERROR", "Weather file has not been assigned. You must assign a Canadian Weather file.", runner)
      return false
    elsif not File.exists?(model.weatherFile.get.path.get.to_s)
      BTAP::runner_register("ERROR", "Weather file #{model.weatherFile.get.path.get} does not exist. Assign a valid weather file location.", runner)
      return false
    else
      weather = BTAP::Environment::WeatherFile.new(model.weatherFile.get.path.get)
      BTAP::runner_register("INFO", "Weather Path found. #{model.weatherFile.get.path.get}",runner)

      BTAP::runner_register("INFO", "Location set to #{weather.location_name}.", runner)
    end
    
    #Get default fuel types. 
    found_defaults = false
    boiler_fueltype = nil
    mau_type= nil
    mau_heating_coil_type = nil
    baseboard_type= nil
    chiller_type = nil
    mua_cooling_type = nil
    heating_coil_type_sys3 = nil
    heating_coil_type_sys4and6 = nil
    fan_type = nil
          
    regional_fuel_type_defaults = "#{File.dirname(__FILE__)}/regional_fuel_type_defaults.csv"
    CSV.foreach(regional_fuel_type_defaults, headers:true) do |default_fuel_info|

      if weather.energy_plus_location_name.to_s.strip == default_fuel_info["Location"].to_s.strip
        boiler_fueltype = default_fuel_info["boiler_fueltype"].strip
        mau_type = default_fuel_info["mau_type"].strip.to_bool
        mau_heating_coil_type = default_fuel_info["mau_heating_coil_type"].strip
        baseboard_type = default_fuel_info["baseboard_type"].strip
        chiller_type = default_fuel_info["chiller_type"].strip
        mua_cooling_type = default_fuel_info["mau_cooling_type"].strip
        heating_coil_type_sys3 = default_fuel_info["heating_coil_type_sys_3"].strip
        heating_coil_type_sys4and6 = default_fuel_info["heating_coil_type_sys4and6"].strip
        fan_type = default_fuel_info["fan_type"].strip
        found_defaults = true
      end

    end
    unless found_defaults == true
      BTAP::runner_register("ERROR", "Could not find location #{weather.energy_plus_location_name} in #{regional_fuel_type_defaults}", runner) 
      return false
    end
    
    
    
    #--ENVELOPE
    #set NECB u-values to construction. 
    BTAP::runner_register("INFO", "Applying NECB U-Values for #{weather.location_name}", runner)
    BTAP::Compliance::NECB2011::set_all_construction_sets_to_necb!(model, runner) 
        
    #Set FWDR
    BTAP::runner_register("INFO", "Applying NECB FDWR values for #{weather.location_name}", runner)
    BTAP::Compliance::NECB2011::set_necb_fwdr( model, true, runner)
        
    # Set Surface if they are out of wack.
    BTAP::Geometry::match_surfaces(model)
    
    #--HVAC
    BTAP::runner_register("INFO", "Applying NECB HVAC", runner)
    use_ideal_air_loads = false
    BTAP::Compliance::NECB2011::necb_autozone_and_autosystem(model,runner) #default args for now...ideal air system = false. 

  end

end #end the measure
#this allows the measure to be use by the application
ApplyNECBRules.new.registerWithApplication
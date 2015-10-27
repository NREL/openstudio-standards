
# Start the measure
class CanadianAddUnitaryAndApplyStandard < OpenStudio::Ruleset::ModelUserScript
  
  require 'openstudio-standards'
  
  # Define the name of the Measure.
  def name
    return "Canadian Add Unitary and Apply Standard"
  end

  # Human readable description
  def description
    return "Adds a unitary system to each zone in the model, runs a sizing run, and applies the standard."
  end

  # Human readable description of modeling approach
  def modeler_description
    return ""
  end

  # Define the arguments that the user will input.
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end

  # Define what happens when the measure is run.
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    
    # Use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Hard-code the building vintage
    building_vintage = 'NECB 2011'
    building_type = 'NECB'
    climate_zone = 'NECB'
    #building_vintage = '90.1-2013'   

    # Turn debugging output on/off
    @debug = false    
    
    # Open a channel to log info/warning/error messages
    @msg_log = OpenStudio::StringStreamLogSink.new
    if @debug
      @msg_log.setLogLevel(OpenStudio::Debug)
    else
      @msg_log.setLogLevel(OpenStudio::Info)
    end
    @start_time = Time.new
    @runner = runner
   
    # Load the Openstudio_Standards JSON files
    model.load_openstudio_standards_json
    
    # Assign the standards to the model
    model.template = building_vintage    
    
    # Make a directory to run the sizing run in
    sizing_dir = "#{Dir.pwd}/sizing"
    if !Dir.exists?(sizing_dir)
      Dir.mkdir(sizing_dir)
    end

    # Perform a sizing run
    if model.runSizingRun("#{sizing_dir}/SizingRun1") == false
      log_msgs
      puts "could not find sizing run #{sizing_dir}/SizingRun1"
      return false
    else
      puts "found sizing run #{sizing_dir}/SizingRun1"
    end

    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/before.osm")
    
    # need to set prototype assumptions so that HRV added
    model.applyPrototypeHVACAssumptions(building_type, building_vintage, climate_zone)
    # Apply the HVAC efficiency standard
    model.applyHVACEfficiencyStandard
    #self.getCoilCoolingDXSingleSpeeds.sort.each {|obj| obj.setStandardEfficiencyAndCurves(self.template, self.standards)}
    
    BTAP::FileIO::save_osm(model, "#{File.dirname(__FILE__)}/after.osm")
    
    log_msgs
    return true

  end #end the run method

  # Get all the log messages and put into output
  # for users to see.
  def log_msgs
    @msg_log.logMessages.each do |msg|
      # DLM: you can filter on log channel here for now
      if /openstudio.*/.match(msg.logChannel) #/openstudio\.model\..*/
        # Skip certain messages that are irrelevant/misleading
        next if msg.logMessage.include?("Skipping layer") || # Annoying/bogus "Skipping layer" warnings
        msg.logChannel.include?("runmanager") || # RunManager messages
        msg.logChannel.include?("setFileExtension") || # .ddy extension unexpected
        msg.logChannel.include?("Translator") || # Forward translator and geometry translator
        msg.logMessage.include?("UseWeatherFile") # 'UseWeatherFile' is not yet a supported option for YearDescription
            
        # Report the message in the correct way
        if msg.logLevel == OpenStudio::Info
          @runner.registerInfo(msg.logMessage)
        elsif msg.logLevel == OpenStudio::Warn
          @runner.registerWarning("[#{msg.logChannel}] #{msg.logMessage}")
        elsif msg.logLevel == OpenStudio::Error
          @runner.registerError("[#{msg.logChannel}] #{msg.logMessage}")
        elsif msg.logLevel == OpenStudio::Debug && @debug
          @runner.registerInfo("DEBUG - #{msg.logMessage}")
        end
      end
    end
    @runner.registerInfo("Total Time = #{(Time.new - @start_time).round}sec.")
  end

end #end the measure



#this allows the measure to be use by the application
CanadianAddUnitaryAndApplyStandard.new.registerWithApplication

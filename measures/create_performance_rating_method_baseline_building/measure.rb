
# Start the measure
class CreatePerformanceRatingMethodBaselineBuilding < OpenStudio::Ruleset::ModelUserScript
  
  require 'openstudio-standards'
  
  # Define the name of the Measure.
  def name
    return 'Create Performance Rating Method Baseline Building'
  end

  # Human readable description
  def description
    return 'Creates the Performance Rating Method baseline building.  For 90.1, this is the Appendix G aka LEED Baseline.  For India ECBC, this is the Appendix D Baseline.  Note: for 90.1, this model CANNOT be used for code compliance; it is not the same as the Energy Cost Budget baseline.'
  end

  # Human readable description of modeling approach
  def modeler_description
    return ''
  end

  # Define the arguments that the user will input.
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # Make an argument for the standard
    standard_chs = OpenStudio::StringVector.new
    #standard_chs << '90.1-2004'
    standard_chs << '90.1-2007'
    standard_chs << '90.1-2010'
    standard_chs << '90.1-2013'
    standard_chs << 'India ECBC 2007'
    standard = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('standard', standard_chs, true)
    standard.setDisplayName('Standard')
    standard.setDefaultValue('90.1-2013')
    args << standard    
    
    # Make an argument for the building type
    building_type_chs = OpenStudio::StringVector.new
    building_type_chs << 'MidriseApartment'
    building_type_chs << 'SecondarySchool'
    building_type_chs << 'PrimarySchool'
    building_type_chs << 'SmallOffice'
    building_type_chs << 'MediumOffice'
    #building_type_chs << 'LargeOffice'
    building_type_chs << 'SmallHotel'
    building_type_chs << 'LargeHotel'
    #building_type_chs << 'Warehouse'
    building_type_chs << 'RetailStandalone'
    building_type_chs << 'RetailStripmall'
    building_type_chs << 'QuickServiceRestaurant'
    building_type_chs << 'FullServiceRestaurant'
    #building_type_chs << 'Hospital'
    #building_type_chs << 'Outpatient'
    building_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('building_type', building_type_chs, true)
    building_type.setDisplayName('Building Type.')
    building_type.setDefaultValue('SmallOffice')
    args << building_type

    # Make an argument for the climate zone
    climate_zone_chs = OpenStudio::StringVector.new
    climate_zone_chs << 'ASHRAE 169-2006-1A'
    climate_zone_chs << 'ASHRAE 169-2006-2A'
    climate_zone_chs << 'ASHRAE 169-2006-2B'
    climate_zone_chs << 'ASHRAE 169-2006-3A'
    climate_zone_chs << 'ASHRAE 169-2006-3B'
    climate_zone_chs << 'ASHRAE 169-2006-3C'
    climate_zone_chs << 'ASHRAE 169-2006-4A'
    climate_zone_chs << 'ASHRAE 169-2006-4B'
    climate_zone_chs << 'ASHRAE 169-2006-4C'
    climate_zone_chs << 'ASHRAE 169-2006-5A'
    climate_zone_chs << 'ASHRAE 169-2006-5B'
    climate_zone_chs << 'ASHRAE 169-2006-6A'
    climate_zone_chs << 'ASHRAE 169-2006-6B'
    climate_zone_chs << 'ASHRAE 169-2006-7A'
    climate_zone_chs << 'ASHRAE 169-2006-8A'
    climate_zone_chs << 'India ECBC Composite'
    climate_zone_chs << 'India ECBC Hot and Dry'
    climate_zone_chs << 'India ECBC Warm and Humid'
    climate_zone_chs << 'India ECBC Moderate'
    climate_zone_chs << 'India ECBC Cold'
    climate_zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('climate_zone', climate_zone_chs, true)
    climate_zone.setDisplayName('Climate Zone.')
    climate_zone.setDefaultValue('ASHRAE 169-2006-2A')
    args << climate_zone   

    # Make an argument for enabling debug messages
    debug = OpenStudio::Ruleset::OSArgument::makeBoolArgument('debug', true)
    debug.setDisplayName('Show debug messages?')
    debug.setDefaultValue(false)
    args << debug

    return args
  end

  # Define what happens when the measure is run.
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Assign the user inputs to variables that can be accessed across the measure
    building_type = runner.getStringArgumentValue('building_type',user_arguments)
    standard = runner.getStringArgumentValue('standard',user_arguments)
    climate_zone = runner.getStringArgumentValue('climate_zone',user_arguments)
    debug = runner.getBoolArgumentValue('debug',user_arguments) 
    
    # Open a channel to log info/warning/error messages
    @msg_log = OpenStudio::StringStreamLogSink.new
    if debug
      @msg_log.setLogLevel(OpenStudio::Debug)
    else
      @msg_log.setLogLevel(OpenStudio::Info)
    end
    @start_time = Time.new
    @runner = runner

    # Make a directory to save the resulting models for debugging
    build_dir = "#{Dir.pwd}/output"
    if !Dir.exists?(build_dir)
      Dir.mkdir(build_dir)
    end

    osm_directory = "#{build_dir}/#{building_type}-#{standard}-#{climate_zone}"
    if !Dir.exists?(osm_directory)
      Dir.mkdir(osm_directory)
    end

    model.create_performance_rating_method_baseline_building(building_type,standard,climate_zone,osm_directory,debug)
    
    log_msgs(debug)
    return true

  end #end the run method

  # Get all the log messages and put into output
  # for users to see.
  def log_msgs(debug)
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
        elsif msg.logLevel == OpenStudio::Debug && debug
          @runner.registerInfo("DEBUG - #{msg.logMessage}")
        end
      end
    end
    @runner.registerInfo("Total Time = #{(Time.new - @start_time).round}sec.")
  end

end #end the measure

#this allows the measure to be use by the application
CreatePerformanceRatingMethodBaselineBuilding.new.registerWithApplication

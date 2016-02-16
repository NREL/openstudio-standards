
def create_baseline_model(model_name, standard, climate_zone, building_type, debug)

  # Make a directory to save the resulting models
  test_dir = "#{File.dirname(__FILE__)}/output"
  if !Dir.exists?(test_dir)
    Dir.mkdir(test_dir)
  end

  # Load the test model
  translator = OpenStudio::OSVersion::VersionTranslator.new
  path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/test_models/performance_rating_method/#{model_name}.osm")
  model = translator.loadModel(path)
  assert(model.is_initialized, "Could not load test model '#{model_name}.osm' from test_models/performance_rating_method.  Check name for typos.")
  model = model.get

  # Check if there's a need to set the weather
  # 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B',
  # 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C',
  # 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B', 'ASHRAE 169-2006-5C', 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A',
  # 'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B'
  if model.weatherFile.empty?
    epw_name = nil
    base_rel_path = '../../data/weather/'
    case climate_zone
      when 'ASHRAE 169-2006-2A'
        epw_name = 'USA_TX_Houston-Bush.Intercontinental.AP.722430_TMY3.epw'
      when 'ASHRAE 169-2006-4A'
        epw_name = 'USA_MD_Baltimore-Washington.Intl.AP.724060_TMY3.epw'
      else
        puts "No Weather file set, and CANNOT locate #{climate_zone}"
        return false
    end
    if epw_name.nil?
      puts "No Weather file set, and CANNOT locate #{climate_zone}"
    else
      rel_path = base_rel_path + epw_name
      weather_file =  File.expand_path(rel_path, __FILE__)
      weather = BTAP::Environment::WeatherFile.new(weather_file)
      #Set Weather file to model.
      success = weather.set_weather_file(model)
      if success
        puts "Set Weather file to '#{weather_file}'"
      else
        puts "Failed to set the weather file"
        return false
      end
    end
  end


  # Create a directory for the test result
  osm_directory = "#{test_dir}/#{model_name}-#{standard}-#{climate_zone}"
  if !Dir.exists?(osm_directory)
    Dir.mkdir(osm_directory)
  end

  # Open a channel to log info/warning/error messages
  msg_log = OpenStudio::StringStreamLogSink.new
  if debug
    msg_log.setLogLevel(OpenStudio::Debug)
  else
    msg_log.setLogLevel(OpenStudio::Info)
  end

  # Create the baseline model from the
  # supplied proposed test model
  model.create_performance_rating_method_baseline_building(building_type,standard,climate_zone,osm_directory,debug = false)

  # Show the output messages
  msg_log.logMessages.each do |msg|
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
        puts(msg.logMessage)
      elsif msg.logLevel == OpenStudio::Warn
        puts("WARNING - [#{msg.logChannel}] #{msg.logMessage}")
      elsif msg.logLevel == OpenStudio::Error
        puts("ERROR - [#{msg.logChannel}] #{msg.logMessage}")
      elsif msg.logLevel == OpenStudio::Debug && debug
        puts("DEBUG - #{msg.logMessage}")
      end
    end
  end

  # Save the test model
  model.save(OpenStudio::Path.new("#{osm_directory}/#{model_name}_baseline.osm"), true)


  return model

end
  
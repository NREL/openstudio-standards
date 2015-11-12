
# Open a log for the library
$OPENSTUDIO_LOG = OpenStudio::StringStreamLogSink.new
if @debug
  $OPENSTUDIO_LOG.setLogLevel(OpenStudio::Debug)
else
  $OPENSTUDIO_LOG.setLogLevel(OpenStudio::Info)
end

# Log the info, warning, and error messages to a runner.
# runner @param [Runner] The Measure runner to add the messages to
# @return [Runner] The same Measure runner, with messages from the openstudio-standards library added
def log_messages_to_runner(runner)

  $OPENSTUDIO_LOG.logMessages.each do |msg|
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
        runner.registerInfo(msg.logMessage)
      elsif msg.logLevel == OpenStudio::Warn
        runner.registerWarning("[#{msg.logChannel}] #{msg.logMessage}")
      elsif msg.logLevel == OpenStudio::Error
        runner.registerError("[#{msg.logChannel}] #{msg.logMessage}")
      elsif msg.logLevel == OpenStudio::Debug && @debug
        runner.registerInfo("DEBUG - #{msg.logMessage}")
      end
    end
  end
 
end

# Log the info, warning, and error messages to a runner.
# runner @param [Runner] The Measure runner to add the messages to
# @return [Runner] The same Measure runner, with messages from the openstudio-standards library added
def log_messages_to_file(file_path, debug = false)

  File.open(file_path, 'w') do |file|  
  
    $OPENSTUDIO_LOG.logMessages.each do |msg|
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
          file.puts("INFO  #{msg.logMessage}")
        elsif msg.logLevel == OpenStudio::Warn
          file.puts("WARN  [#{msg.logChannel}] #{msg.logMessage}")
        elsif msg.logLevel == OpenStudio::Error
          file.puts("ERROR [#{msg.logChannel}] #{msg.logMessage}")
        elsif msg.logLevel == OpenStudio::Debug && debug
          file.puts("DEBUG  #{msg.logMessage}")
        end
      end
    end
    
  end
  
 
end

# Get an array of all messages of a given type in the log
def get_logs(log_type = OpenStudio::Error)

  errors = []

  $OPENSTUDIO_LOG.logMessages.each do |msg|
    if /openstudio.*/.match(msg.logChannel)
      # Skip certain messages that are irrelevant/misleading
      next if msg.logMessage.include?("Skipping layer") || # Annoying/bogus "Skipping layer" warnings
          msg.logChannel.include?("runmanager") || # RunManager messages
          msg.logChannel.include?("setFileExtension") || # .ddy extension unexpected
          msg.logChannel.include?("Translator") || # Forward translator and geometry translator
          msg.logMessage.include?("UseWeatherFile") # 'UseWeatherFile' is not yet a supported option for YearDescription
      # Only fail on the errors
      if msg.logLevel == log_type
        errors << "[#{msg.logChannel}] #{msg.logMessage}"
      end
    end
  end 

  return errors
  
end

def reset_log

  $OPENSTUDIO_LOG.resetStringStream

end


# Open a log for the library
$OPENSTUDIO_LOG = OpenStudio::StringStreamLogSink.new # rubocop:disable Style/GlobalVars
$OPENSTUDIO_LOG.setLogLevel(OpenStudio::Debug) # rubocop:disable Style/GlobalVars

# Log the info, warning, and error messages to a runner.
# runner @param [Runner] The Measure runner to add the messages to
# debug @param [Boolean] If true, include the debug messages in the log
# @return [Runner] The same Measure runner, with messages from the openstudio-standards library added
def log_messages_to_runner(runner, debug = false)
  $OPENSTUDIO_LOG.logMessages.each do |msg| # rubocop:disable Style/GlobalVars
    # DLM: you can filter on log channel here for now
    if /openstudio.*/ =~ msg.logChannel # /openstudio\.model\..*/
      # Skip certain messages that are irrelevant/misleading
      next if msg.logMessage.include?('UseWeatherFile') || # 'UseWeatherFile' is not yet a supported option for YearDescription
              msg.logMessage.include?('Skipping layer') || # Annoying/bogus "Skipping layer" warnings
              msg.logChannel.include?('runmanager') || # RunManager messages
              msg.logChannel.include?('setFileExtension') || # .ddy extension unexpected
              msg.logChannel.include?('Translator') || # Forward translator and geometry translator
              msg.logMessage.include?('Successive data points') || # Successive data points (2004-Jan-31 to 2001-Feb-01, ending on line 753) are greater than 1 day apart in EPW file
              msg.logMessage.include?('has multiple parents') || # Bogus errors about curves having multiple parents
              msg.logMessage.include?('does not have an Output') || # Warning from EMS translation
              msg.logMessage.include?('Prior to OpenStudio 2.6.2, this field was returning a double, it now returns an Optional double') # Warning about OS API change

      # Report the message in the correct way
      if msg.logLevel == OpenStudio::Info
        runner.registerInfo(msg.logMessage)
      elsif msg.logLevel == OpenStudio::Warn
        runner.registerWarning("[#{msg.logChannel}] #{msg.logMessage}")
      elsif msg.logLevel == OpenStudio::Error
        runner.registerError("[#{msg.logChannel}] #{msg.logMessage}")
      elsif msg.logLevel == OpenStudio::Debug && debug
        runner.registerInfo("DEBUG - #{msg.logMessage}")
      end
    end
  end
end

# Log the info, warning, and error messages to a file.
# runner @param [file_path] The path to the log file
# debug @param [Boolean] If true, include the debug messages in the log
# @return [Array<String>] The array of messages, which can be used elsewhere.
def log_messages_to_file(file_path, debug = false)
  messages = []

  File.open(file_path, 'w') do |file|
    $OPENSTUDIO_LOG.logMessages.each do |msg| # rubocop:disable Style/GlobalVars
      # DLM: you can filter on log channel here for now
      if /openstudio.*/ =~ msg.logChannel # /openstudio\.model\..*/
        # Skip certain messages that are irrelevant/misleading
        next if msg.logMessage.include?('UseWeatherFile') || # 'UseWeatherFile' is not yet a supported option for YearDescription
                msg.logMessage.include?('Skipping layer') || # Annoying/bogus "Skipping layer" warnings
                msg.logChannel.include?('runmanager') || # RunManager messages
                msg.logChannel.include?('setFileExtension') || # .ddy extension unexpected
                msg.logChannel.include?('Translator') || # Forward translator and geometry translator
                msg.logMessage.include?('Successive data points') || # Successive data points (2004-Jan-31 to 2001-Feb-01, ending on line 753) are greater than 1 day apart in EPW file
                msg.logMessage.include?('has multiple parents') || # Bogus errors about curves having multiple parents
                msg.logMessage.include?('does not have an Output') || # Warning from EMS translation
                msg.logMessage.include?('Prior to OpenStudio 2.6.2, this field was returning a double, it now returns an Optional double') # Warning about OS API change

        # Report the message in the correct way
        if msg.logLevel == OpenStudio::Info
          s = "INFO  #{msg.logMessage}"
          file.puts(s)
          messages << s
        elsif msg.logLevel == OpenStudio::Warn
          s = "WARN  #{msg.logMessage}"
          file.puts(s)
          messages << s
        elsif msg.logLevel == OpenStudio::Error
          s = "ERROR #{msg.logMessage}"
          file.puts(s)
          messages << s
        elsif msg.logLevel == OpenStudio::Debug && debug
          s = "DEBUG #{msg.logMessage}"
          file.puts(s)
          messages << s
        end
      end
    end
  end

  return messages
end

# Get an array of all messages of a given type in the log
def get_logs(log_type = OpenStudio::Error)
  errors = []

  $OPENSTUDIO_LOG.logMessages.each do |msg| # rubocop:disable Style/GlobalVars
    if /openstudio.*/ =~ msg.logChannel
      # Skip certain messages that are irrelevant/misleading
      next if msg.logMessage.include?('UseWeatherFile') || # 'UseWeatherFile' is not yet a supported option for YearDescription
              msg.logMessage.include?('Skipping layer') || # Annoying/bogus "Skipping layer" warnings
              msg.logChannel.include?('runmanager') || # RunManager messages
              msg.logChannel.include?('setFileExtension') || # .ddy extension unexpected
              msg.logChannel.include?('Translator') || # Forward translator and geometry translator
              msg.logMessage.include?('Successive data points') || # Successive data points (2004-Jan-31 to 2001-Feb-01, ending on line 753) are greater than 1 day apart in EPW file
              msg.logMessage.include?('has multiple parents') || # Bogus errors about curves having multiple parents
              msg.logMessage.include?('does not have an Output') || # Warning from EMS translation
              msg.logMessage.include?('Prior to OpenStudio 2.6.2, this field was returning a double, it now returns an Optional double') # Warning about OS API change
      # Only fail on the errors
      if msg.logLevel == log_type
        errors << "[#{msg.logChannel}] #{msg.logMessage}"
      end
    end
  end

  return errors
end

def reset_log
  $OPENSTUDIO_LOG.resetStringStream # rubocop:disable Style/GlobalVars
end

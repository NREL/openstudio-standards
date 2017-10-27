require 'openstudio'
require 'json'

refactor_standards_dir = '../standards'

# Revise the calls to model to get the model from the object in question
Dir.glob("#{refactor_standards_dir}/**/*.rb").each do |file_path|
  file_name = File.basename(file_path)
  next if file_name == 'standards_model.rb'
  
  puts ''
  puts file_name

  lines = File.readlines(file_path)

  new_lines = []
  lines.each do |line|
    new_line = 'UNDEFINED'
    if line.include?('# Reopen the OpenStudio class to add methods to apply standards to this object') 
      next # Remove inaccurate headers
    elsif line.include?('# @param template') 
      next # Remove template argument from documentation
    elsif line.include?('# @param standards [Hash] the OpenStudio_Standards spreadsheet in hash format')
      next # Remove standards hash argument from documentation
    elsif line.include?('# @param @@template [String]')  
      next # Remove @@template as an argument
    else
      new_lines << line
    end
  end
  
  # Write the revised file
  File.open("#{file_path}", 'w') do |file|
    new_lines.each do |line|
      file.puts(line)
    end
  end

end

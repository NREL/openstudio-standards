require 'openstudio'
require 'json'

refactor_standards_dir = '../standards'

files_with_template_switches = []
# Revise the calls to model to get the model from the object in question
Dir.glob("#{refactor_standards_dir}/*.rb").each do |file_path|
  file_name = File.basename(file_path)
  next if file_name == 'standards_model.rb'
  # puts ''
  # puts file_name
  lines = File.readlines(file_path)
  
  template_switches = []
  methods_with_switches = []
  current_method_name = 'UNDEFINED'
  lines.each_with_index do |line, line_num|
    # Update the name of the current method
    m = line.match(/def (\w*)/) # This line is a method definition
    current_method_name = m[1] if m
    
    # Find all switch statements
    if line.strip[0] == '#' # Skip comment lines
      next
    elsif line.include?('NECB 2011')
      methods_with_switches << "    #{current_method_name}"
      template_switches << "        #{line_num}: #{line}"
    end
  end
  
  methods_with_switches = methods_with_switches.uniq
  if template_switches.size > 0
    files_with_template_switches << "#{file_name} has #{template_switches.size} in:\n#{methods_with_switches.join("\n")}\n#{template_switches.join("\n")}"
  end
  
end

files_with_template_switches.each do |f|
  puts ''
  puts f
end
require 'openstudio'
require 'json'

refactor_standards_dir = '../standards'

templates = [
  'DOE Ref Pre-1980',
  'DOE Ref 1980-2004',
  '90.1-2004',
  '90.1-2007',
  '90.1-2010',
  '90.1-2013'
]

files_with_template_switches = {}
# Revise the calls to model to get the model from the object in question
Dir.glob("#{refactor_standards_dir}/**/*.rb").each do |file_path|
  file_name = File.basename(file_path)
  next if file_name == 'standards_model.rb'
  lines = File.readlines(file_path)
  
  methods_and_switches = {}
  current_method_name = 'UNDEFINED'
  lines.each_with_index do |line, line_num|
    # Update the name of the current method
    m = line.match(/def (\w*)/) # This line is a method definition
    current_method_name = m[1] if m
    # Initialze the counter for this method if not already done
    methods_and_switches[current_method_name] = [] if methods_and_switches[current_method_name].nil?
    
    # Find all switch statements
    next if line.strip[0] == '#' # Skip comment lines
    templates.each do |template|
      if line.include?("'#{template}'")
        methods_and_switches[current_method_name] << "#{line_num + 1}: #{line}"
        break # only report a line once
      end
    end
  end
  files_with_template_switches[file_name] = methods_and_switches
end

files_with_template_switches.each do |file_name, methods|
  total_changes = 0
  methods.each { |method_name, lines| total_changes += lines.size }
  next if total_changes.zero?
  puts file_name
  methods.each do |method_name, lines|
    puts "    #{method_name}"
    lines.each do |line|
      puts "        #{line}"
    end
  end
end

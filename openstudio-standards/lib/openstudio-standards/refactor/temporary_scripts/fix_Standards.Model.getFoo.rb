require 'openstudio'
require 'json'

refactor_standards_dir = '../standards/**'

def class_name(lines)
  name = 'TODO_CLASS_NAME'
  lines.each do |line|
    m = line.match(/def (\w|\?)*\((\w*)/) 
    if m
      name = m[2]
      break
    end
  end
  return name.strip
end

# Store the mapping of old to new methods
old_to_new_method_names = {}
old_to_new_method_counts = {}

# Revise the method names
Dir.glob("#{refactor_standards_dir}/*.rb").each do |file_path|
  file_name = File.basename(file_path)
  
  # Skip the utilties file
  next if file_name == 'ashrae_90_1.rb'
  next if file_name == 'doe_ref_pre_1980.rb'
  next if file_name == 'doe_ref_pre_1980_2004.rb'
  next if file_name == 'ashrae90_1_2004.rb'
  next if file_name == 'ashrae90_1_2007.rb'
  next if file_name == 'ashrae90_1_2010.rb'
  next if file_name == 'ashrae90_1_2013.rb'
  next if file_name == 'nrel_zne_ready_2017.rb'
  next if file_name == 'necb_2011.rb'
  next if file_name == 'standards_model.rb'
  
  lines = File.readlines(file_path)
  c_name = class_name(lines)
  c_name = OpenStudio.toUnderscoreCase(c_name)
  next if c_name == 'todo_class_name'
  puts "#{file_name} => #{c_name}"

  new_lines = []
  lines.each do |line|
    if line.strip[0] == '#' # Skip comment lines
      new_lines << line
      next
    elsif line.match(/OpenStudio.logFree/) # Skip log message lines
      new_lines << line
      next
    elsif line.match(/\s([a-z]+[A-Z]+\w*)/) # Fix up openstudio methods
      m = line.match(/(.*)\s([a-z]+[A-Z]+\w*)(.*)/)
      before = m[1]
      os_method_name = m[2]
      after = m[3]
      new_line = "#{before} #{c_name}.#{os_method_name}#{after}"
      new_lines << new_line
      puts "#{line} => #{new_line}"
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

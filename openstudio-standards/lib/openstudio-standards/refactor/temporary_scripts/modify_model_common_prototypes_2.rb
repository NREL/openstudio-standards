require 'openstudio'
require 'json'

refactor_standards_dir = '../prototypes/common/objects**'

def class_name(lines)
  name = 'TODO_CLASS_NAME'
  lines.each do |line|
    m = line.match(/class OpenStudio::Model::(\w*)/) 
    if m
      name = m[1]
      break
    end
    m2 = line.match(/module (\w*)/)
    if m2
      name = m2[1]
      break
    end
  end
  if name == 'TODO_CLASS_NAME'
    return 'model'
  end
  return name
end

# Store the mapping of old to new methods
old_to_new_method_names = {}
old_to_new_method_counts = {}

# Revise the method names
Dir.glob("#{refactor_standards_dir}/*.rb").each do |file_path|
  file_name = File.basename(file_path)
  
  # Skip the utilties file
  next if file_name == 'Prototype.utilities.rb'
  
  lines = File.readlines(file_path)
  c_name = class_name(lines)
  c_name = OpenStudio.toUnderscoreCase(c_name)
  # puts c_name

  new_lines = []
  lines.each do |line|
    # Skip methods already edited
    if line.include?('def model_')
      new_lines << line
      next
    end
    # Edit new methods
    if line.match(/class OpenStudio::Model::(\w*)/)
      new_lines << 'class StandardsModel < OpenStudio::Model::Model'
    elsif line.match(/\sdef (\w*)/) # This line is a method definition
      new_line = 'UNDEFINED'
      old_method_name = 'TODO_OLD_METHOD_NAME'
      new_method_name = 'TODO_NEW_METHOD_NAME'
      if line.match(/def ((\w|\?)*)(\()(.*)/) # Has arguments
        m = line.match(/def ((\w|\?)*)(\()(.*)/)
        old_method_name = m[1]
        args = m[4]
        new_method_name = "#{c_name}_#{old_method_name}"
        new_line = "  def #{new_method_name}(#{c_name}, #{args}"
      elsif line.match(/def ((\w|\?)*)/) # No arguments
        m = line.match(/def ((\w|\?)*)/)
        old_method_name = m[1]
        new_method_name = "#{c_name}_#{old_method_name}"
        new_line = "  def #{new_method_name}(#{c_name})" 
      end
      new_lines << new_line
      old_to_new_method_names[old_method_name] = [c_name, new_method_name]
      # puts "#{line} => #{new_line}"
      if old_to_new_method_counts[old_method_name]
        old_to_new_method_counts[old_method_name] << c_name
      else
        old_to_new_method_counts[old_method_name] = [c_name]
      end
    elsif line.strip[0] == '#' # Skip comment lines
      new_lines << line
      next
    elsif line.include?('#{name}')
      new_line = line.gsub('#{name}', '#{' + c_name + '.name}')
      new_lines << new_line
      puts "#{line} => #{new_line}"
    elsif line.include?('self')
      new_line = line.gsub('self', c_name)
      new_lines << new_line
      puts "#{line} => #{new_line}"
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

  # puts ''
  
  # Write the revised file
  File.open("#{file_path}", 'w') do |file|
    new_lines.each do |line|
      file.puts(line)
    end
  end
  
end

# Limit to just duplicates
dupes = {}
old_to_new_method_counts.each do |old_method, class_users|
  next if class_users.size == 1
  dupes[old_method] = class_users
end

# Store the old to new mapping
File.open('prototype_objects_method_mapping.json', 'w') do |file|
  file.puts(JSON.pretty_generate(old_to_new_method_names))
end

# Store the duplicate old method names
File.open('prototype_objects_method_mapping_duplicates.json', 'w') do |file|
  file.puts(JSON.pretty_generate(dupes))
end

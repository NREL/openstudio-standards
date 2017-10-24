require 'openstudio'
require 'json'

refactor_standards_dir = '../standards/ashrae_90_1/**'

def class_name(lines)
  return 
end

# Store the mapping of old to new methods
old_to_new_method_names = {}
old_to_new_method_counts = {}

# Revise the method names
Dir.glob("#{refactor_standards_dir}/*.rb").each do |file_path|
  file_name = File.basename(file_path)
  puts file_name
  
  lines = File.readlines(file_path)
  c_name = 'model'

  new_lines = []
  lines.each do |line|
    if line.match(/\sdef (\w*)/) # This line is a method definition
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
      if old_to_new_method_counts[old_method_name]
        old_to_new_method_counts[old_method_name] << c_name
      else
        old_to_new_method_counts[old_method_name] = [c_name]
      end
      
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

# Limit to just duplicates
dupes = {}
old_to_new_method_counts.each do |old_method, class_users|
  next if class_users.size == 1
  dupes[old_method] = class_users
end

# Store the old to new mapping
File.open('prototype_model_method_mapping.json', 'w') do |file|
  file.puts(JSON.pretty_generate(old_to_new_method_names))
end

# Store the duplicate old method names
File.open('prototype_model_old_method_duplicates.json', 'w') do |file|
  file.puts(JSON.pretty_generate(dupes))
end

# Combine the standards.model methods with the prototype.model methods
temp = File.read("standards_method_mapping.json")
standards_method_mapping = JSON.parse(temp)
old_to_new_method_names = old_to_new_method_names.merge(standards_method_mapping)

# Go through the revised files again and replace usages of the old methods
# with usages of the new methods
Dir.glob("#{refactor_standards_dir}/*.rb").each do |file_path|
  file_name = File.basename(file_path)
  puts file_name
  
  lines = File.readlines(file_path)

  new_lines = []
  lines.each do |line|
    if line.match(/def (\w*)/)
      new_lines << line
      next # Skip method definitions
    else
      # Check for the presence of all the old methods
      new_line = line
      old_to_new_method_names.each do |k, v|
        old_method_name = k
        c_name = v[0]
        new_method_name = v[1]
        next if old_method_name == ''
        m = line.match(/#{Regexp.quote(old_method_name)}(\(|\s)/)
        next unless m
          m2 = line.match(/(.*)\s#{Regexp.quote(old_method_name)}(.*)/) # Called on self (implied)
          m3 = line.match(/(.*)\s(\w*)\.#{Regexp.quote(old_method_name)}(.*)/) # Called on an object
          if m2 # Called on self (implied)
            before = m2[1]
            after = m2[2]
            if after[0] == '('
              new_line = "#{before} #{new_method_name}(#{c_name}, #{after[1..-1]}"
            else
              new_line = "#{before} #{new_method_name}(#{c_name}) #{after}"
            end
          elsif m3 # Called on an object
            before = m3[1]
            var = m3[2]
            after = m3[3]
            if after[0] == '('
              new_line = "#{before} #{new_method_name}(#{var}, #{after[1..-1]}"
            else
              new_line = "#{before} #{new_method_name}(#{var}) #{after}"
            end
          else
        end
      end
      new_lines << new_line

    end
  end
  
  # Write the revised file
  File.open("#{file_path}", 'w') do |file|
    new_lines.each do |line|
      file.puts(line)
    end
  end
  
end







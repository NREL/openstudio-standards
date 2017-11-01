require 'json'

temp = File.read('prototype_objects_method_mapping.json')
old_to_new_method_names = JSON.parse(temp)

refactor_standards_dir = '../standards/**'

# Go through the revised files again and replace usages of the old methods
# with usages of the new methods
Dir.glob("#{refactor_standards_dir}/*.rb").each do |file_path|
  file_name = File.basename(file_path)
  puts file_name

  # Skip the utilties file
  next if file_name == 'Prototype.utilities.rb'
  
  lines = File.readlines(file_path)

  new_lines = []
  lines.each do |line|
    if line.strip[0] == '#' # Skip comment lines
      new_lines << line
      next
    elsif line.match(/OpenStudio.logFree/) # Skip log message lines
      new_lines << line
      next
    elsif line.match(/(.*)(model_)(.*)/) # Skip lines with model_ methods
      new_lines << line
      next
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

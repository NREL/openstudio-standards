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
    if line.strip[0] == '#' # Skip comment lines
      new_lines << line
      next
    elsif line.include?('register_standard') # Skip register line in class files
      new_lines << line
      next
    elsif line.include?('#{template}')
      new_line = line.gsub('#{template}', '#{instvartemplate}') # Use instvartemplate in messages
      new_lines << new_line
      puts "#{line} => #{new_line}"
    elsif line.include?('template ==')
      new_line = line.gsub('template ==', 'instvartemplate ==') # Use instvartemplate in if statements
      new_lines << new_line
      puts "#{line} => #{new_line}"  
    elsif line.include?("'template' => template")
      new_line = line.gsub("'template' => template", "'template' => instvartemplate") # Use instvartemplate in search criteria
      new_lines << new_line
      puts "#{line} => #{new_line}"
    elsif line.include?("'template' => instvartemplate") # Skip already modified lines
      new_lines << line
      next
    elsif line.match(/(.*)\((.*)@@template(.*)\)(.*)/) # Remove from method calls and definitions
      m = line.match(/(.*)\((.*)@@template(.*)\)(.*)/)
      before_p = m[1]
      before = m[2]
      after = m[3]
      after_p = m[4]
      new_line = "#{before_p}(#{before}#{after})#{after_p}"
      new_line = new_line.gsub(', ,',',')
      new_line = new_line.gsub(', )',')')
      new_line = new_line.gsub('(,','(')
      new_line = new_line.gsub(",  = 'ASHRAE 90.1-2007'",'')
      new_lines << new_line
      puts "#{line} => #{new_line}"       
    elsif line.match(/(.*)\((.*)template(.*)\)(.*)/) # Remove from method calls and definitions
      m = line.match(/(.*)\((.*)template(.*)\)(.*)/)
      before_p = m[1]
      before = m[2]
      after = m[3]
      after_p = m[4]
      new_line = "#{before_p}(#{before}#{after})#{after_p}"
      new_line = new_line.gsub(', ,',',')
      new_line = new_line.gsub(', )',')')
      new_line = new_line.gsub('(,','(')
      new_line = new_line.gsub(",  = 'ASHRAE 90.1-2007'",'')
      new_lines << new_line
      puts "#{line} => #{new_line}"           
    elsif line.include?('template') # Replace calls with class variable instvartemplate
      new_line = line.gsub('template', 'instvartemplate')
      new_line = new_line.gsub("'instvartemplate'", "'template'")
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

require 'openstudio'
require 'json'

refactor_standards_dir = '../'

# Revise the calls to model to get the model from the object in question
Dir.glob("#{refactor_standards_dir}/**/*.rb").each do |file_path|
  file_name = File.basename(file_path)
  next if file_name == 'modify_model_common_prototypes_2.rb'
  next if file_name == 'modify_standards_files.rb'
  next if file_name == 'dont_inherit_from_model.rb'
  
  puts ''
  puts file_name

  lines = File.readlines(file_path)

  new_lines = []
  lines.each do |line|
    if line.include?('class StandardsModel < OpenStudio::Model::Model')
      new_lines << line.gsub('class StandardsModel < OpenStudio::Model::Model', 'class StandardsModel')
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

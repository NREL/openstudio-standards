require 'fileutils'

output_folder = "#{File.dirname(__FILE__)}/../expected/"
input_folder = "#{File.dirname(__FILE__)}/../output_osm/"
puts output_folder
puts input_folder

if Dir.exist?(input_folder)
  Dir.glob(input_folder + '*').sort.each do |f|
    file_name = File.basename(f)
    output_file_path = File.join(output_folder, file_name)
    FileUtils.cp(f, output_file_path)
  end
else
  puts "No test results found. Aborting."
end
#Dir.glob(folder_path + "/*test_result.osm").sort.each do |f|
#  new_file = f.gsub("test_result.osm","expected_result.osm")
#  FileUtils.cp(f,new_file )
#  puts "created new #{new_file}"
#end

#Dir.glob(folder_path + "/*test_result_qaqc.json").sort.each do |f|
#  new_file = f.gsub("test_result_qaqc.json","expected_result_qaqc.json")
#  FileUtils.cp(f,new_file )
#  puts "created new #{new_file}"
#end
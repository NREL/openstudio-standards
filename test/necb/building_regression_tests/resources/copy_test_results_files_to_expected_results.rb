require 'fileutils'

folder_path = "#{File.dirname(__FILE__)}/../expected_results/"
puts folder_path
Dir.glob(folder_path + "/*test_result.osm").sort.each do |f|
  new_file = f.gsub("test_result.osm","expected_result.osm")
  FileUtils.cp(f,new_file )
  puts "created new #{new_file}"
end

Dir.glob(folder_path + "/*test_result_qaqc.json").sort.each do |f|
  new_file = f.gsub("test_result_qaqc.json","expected_result_qaqc.json")
  FileUtils.cp(f,new_file )
  puts "created new #{new_file}"
end
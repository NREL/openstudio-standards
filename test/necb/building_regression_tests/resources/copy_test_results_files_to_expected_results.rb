require 'fileutils'

folder_path = File.dirname(__FILE__)
Dir.glob(folder_path + "/*test_result.osm").sort.each do |f|
  new_file = f.gsub("test_result.osm","expected_result.osm")
  FileUtils.cp(f,new_file )
  puts "created new #{new_file}"
end
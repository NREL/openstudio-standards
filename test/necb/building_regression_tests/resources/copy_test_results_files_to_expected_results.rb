require 'fileutils'

num_new_files = 0
folder_path = File.expand_path("#{__dir__}/../expected_results")
Dir.glob(folder_path + "/*test_result.osm").sort.each do |f|
  new_file = f.gsub("test_result.osm","expected_result.osm")
  FileUtils.cp(f,new_file )
  puts "created new #{new_file}"
  num_new_files += 1
end
puts "Created #{num_new_files} new files"
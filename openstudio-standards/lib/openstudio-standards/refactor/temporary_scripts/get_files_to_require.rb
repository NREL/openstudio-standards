
# Find the files to require
files_to_require = []
Dir.glob("../prototypes/**/*.rb").each do |file_path|
  # Don't load temp scripts
  next if file_path.include?('temporary_scripts')
  files_to_require << file_path
end

puts files_to_require.sort
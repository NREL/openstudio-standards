require 'find'
require 'parallel'
failures = ""
success = ""
files = Find.find(".").grep(/\/test_necb.*rb/).sort
files.sort!
 Parallel.each(files) do |file|

  t1 = Time.now
  # begin
     puts "#{file} \n"
    output = `ruby #{file}`
  # rescue
    # failures << file
  # end
  t2 = Time.now
   time = t2 - t1
   puts "#{file},[#{time}]s\n"
  # success << "#{file},[#{time}]s \n"
  # File.open('time.txt', 'a') { |f| f.write(success) }
 end


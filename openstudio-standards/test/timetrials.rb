require 'find'
failures = ""
success = ""
Find.find(".").grep(/\/test.*rb/).each do |file|
  t1 = Time.now
  begin
    puts file
    system("ruby", file)
  rescue
    failures << file
  end
t2 = Time.now
time = t2 - t1
success << "file - #{file} - time - #{time} "
end
File.open("./TimeTrial", 'w') { |file| file.write(success) }
puts failures

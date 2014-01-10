# Nicholas Long

#IMPORTANT:  for json use double quotes for individual arguments and single quotes to wrap the whole thing (json does not like single quotes)
#command line arguments syntax (json):  '{"test_argument1": "Hot Tub", "test_argument2":2}'

#"{\"search_str\": \"80005\"}"

require 'rubygems'
require 'pathname'
require 'json'
require "#{Pathname.new(__FILE__) + '../lib/OpenEI'}"
require "#{Pathname.new(__FILE__) + '../lib/OpenEIRate'}"
require "#{Pathname.new(__FILE__) + '../lib/OnDemandBase'}"

odg = OnDemandBase.new(ARGV)

if odg.args.has_key? "search_str"
  search_str = odg.args["search_str"]

  #Get Script Arguments (always a json string to be parsed by the script)
  open_ei = OpenEI.new(search_str, nil, odg.debug?)

  if odg.debug?
    puts "OUT: #{open_ei.to_json}"
  end

  #if odg.passthru?
  #  puts open_ei.to_json
  #else
    # write openstudio/energyplus objects
    f = File.open('./outputs.json', 'w')
    f.write(open_ei.to_json)
    f.close
  #end

  if odg.debug?
    puts "---------------DEBUG------------------------"
    open_ei.rate_names.each do |rate_name|
      #puts rate_name
    end

    open_ei.debug_urls.each do |dbg|
      puts dbg.inspect
    end
  end

else
  search_str = ""
  odg.invalidate
end

puts odg.finalize


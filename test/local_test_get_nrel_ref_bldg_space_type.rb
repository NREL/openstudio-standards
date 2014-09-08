# perform a local test of get_nrel_ref_bldg_space_type.rb using the same syntax that the server expects

# gem install json or gem install json_pure (pure ruby version has fewer dependencies)
require 'rubygems'
require 'json'

# this is where you put the key:value pairs that the function is expecting
args_hash = { 'NREL_reference_building_vintage' => 'ASHRAE_189.1-2009',
              'Climate_zone' => 'ClimateZone 1-3',
              'NREL_reference_building_primary_space_type' => 'SuperMarket',
              'NREL_reference_building_secondary_space_type' => 'Deli/Bakery',
              'ondemand_uid' => 'uid',
              'ondemand_vid' => 'vid',
              'apikey' => 'authkey'
            }

# call the system command to execute the ruby script with the appropriate inputs
output = `ruby '#{Dir.pwd}/get_nrel_ref_bldg_space_type.rb' '#{args_hash.to_json}'`
puts output

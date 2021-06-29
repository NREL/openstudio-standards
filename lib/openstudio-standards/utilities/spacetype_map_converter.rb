require 'json'
map = []
File.open('../../../lib/openstudio-standards/standards/necb/NECB2015/data/space_type_upgrade_map.csv').each do |line|
  necb2011_building_type, necb2011_space_type, necb2015_building_type, necb2015_space_type = line.split(',')
  next if necb2011_building_type.nil? || (necb2011_building_type.strip == '')

  map << { 'NECB2011_building_type' => necb2011_building_type.strip,
           'NECB2011_space_type' => necb2011_space_type.strip,
           'NECB2015_building_type' => necb2015_building_type.strip,
           'NECB2015_space_type' => necb2015_space_type.strip,
           'NECB2017_building_type' => necb2015_building_type.strip,
           'NECB2017_space_type' => necb2015_space_type.strip }
end

puts JSON.pretty_generate(map)

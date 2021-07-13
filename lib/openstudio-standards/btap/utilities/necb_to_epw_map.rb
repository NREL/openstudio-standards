require 'json'

def distance(loc1, loc2)
  rad_per_deg = Math::PI / 180 # PI / 180
  rkm = 6371 # Earth radius in kilometers
  rm = rkm * 1000 # Radius in meters

  dlat_rad = (loc2[0] - loc1[0]) * rad_per_deg # Delta, converted to rad
  dlon_rad = (loc2[1] - loc1[1]) * rad_per_deg

  lat1_rad, lon1_rad = loc1.map { |i| i * rad_per_deg }
  lat2_rad, lon2_rad = loc2.map { |i| i * rad_per_deg }

  a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  rm * c # Delta in meters
end

array_of_hashes = []
necb_data_file_path = "#{File.dirname(__FILE__)}/../standards/necb/NECB2011/data/necb_2015_table_c1.json"
epw_data_file_path = "#{File.dirname(__FILE__)}/../standards/necb/NECB2011/data/epw_data.json"
JSON.parse(File.read(epw_data_file_path)).each do |epw|
  epw['necb_tbl_c_city'] = nil
  epw['necb_tbl_c_prov'] = nil
  min_distance = 100000000000000.0
  necb_closest = nil
  JSON.parse(File.read(necb_data_file_path))['necb_2015_table_c1']['table'].each do |necb|
    next if necb['lat_long'].nil?

    d = distance([epw['latitude'].to_f, epw['longitude']], necb['lat_long'])
    if min_distance > d
      min_distance = d
      necb_closest = necb
    end
  end
  array_of_hashes << { 'epw_file' => epw['file'],
                       'necb_location' => "#{necb_closest['city']},#{necb_closest['province']}",
                       'hdd_difference' => (epw['hdd18'].to_f - necb_closest['degree_days_below_18_c'].to_f),
                       'distance_km' => format('%.2f', (min_distance / 1000.0)),
                       'hdd18' => necb_closest['degree_days_below_18_c'] }
end
File.write("#{File.dirname(__FILE__)}/../standards/necb/NECB2011/data/epw_file_to_necb_hdd_map.json", JSON.pretty_generate(array_of_hashes))

# Load NECB Table c
# Create new EPW to NECB Map
# iterate thourgh EPW files.
# Iterate THrough NECB Locations
# Update distance if distance is less than stored distance.
# End NECB iteration
# End EPW Iteration

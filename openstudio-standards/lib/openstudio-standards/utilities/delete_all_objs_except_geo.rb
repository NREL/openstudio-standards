require 'openstudio'
require_relative '../../openstudio-standards/btap/btap'
require_relative '../../openstudio-standards/btap/fileio'

puts "\nenter osm file name (without file extension):\n"
osm_infile_name = gets.chomp
osm_outfile_name = "#{osm_infile_name}"+'_updated.osm'

model = BTAP::FileIO.safe_load_model("#{osm_infile_name}.osm")

model.getWeatherFile.remove
model.getDesignDays.each {|iobj| iobj.remove}
model.getSchedules.each {|iobj| iobj.remove}
model.getDefaultScheduleSets.each {|iobj| iobj.remove}
model.getDefaultConstructionSets.each {|iobj| iobj.remove}
model.getLayeredConstructions.each {|iobj| iobj.remove}
model.getSpaceLoadDefinitions.each {|iobj| iobj.remove}
model.getSpaceTypes.each {|iobj| iobj.remove}
model.getBuildingStorys.each {|iobj| iobj.remove}
model.getShadingSurfaceGroups.each {|iobj| iobj.remove}
model.getExteriorLightss.each {|iobj| iobj.remove}
model.getThermalZones.each {|iobj| iobj.remove}
model.getLoops.each {|iobj| iobj.remove}

osm_path = OpenStudio::Path.new("#{osm_outfile_name}")
model.save(osm_path, true)

puts "Spaces list:"
model.getSpaces.each do |space|
  puts space.name.get
end
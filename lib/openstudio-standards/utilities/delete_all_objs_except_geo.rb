require 'openstudio'
require_relative '../../openstudio-standards/btap/btap'
require_relative '../../openstudio-standards/btap/fileio'

puts "\nenter osm file name (without file extension):\n"
osm_infile_name = gets.chomp
osm_outfile_name = "#{osm_infile_name}_updated.osm"

model = BTAP::FileIO.safe_load_model("#{osm_infile_name}.osm")

model.getWeatherFile.remove
model.getDesignDays.each(&:remove)
model.getSchedules.each(&:remove)
model.getDefaultScheduleSets.each(&:remove)
model.getDefaultConstructionSets.each(&:remove)
model.getLayeredConstructions.each(&:remove)
model.getSpaceLoadDefinitions.each(&:remove)
model.getSpaceTypes.each(&:remove)
# model.getBuildingStorys.each {|iobj| iobj.remove}
model.getShadingSurfaceGroups.each(&:remove)
model.getExteriorLightss.each(&:remove)
model.getThermalZones.each(&:remove)
model.getLoops.each(&:remove)

osm_path = OpenStudio::Path.new(osm_outfile_name.to_s)
model.save(osm_path, true)

puts 'Spaces list:'
model.getSpaces.each do |space|
  puts space.name.get
end

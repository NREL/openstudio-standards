require 'openstudio'
require_relative '../../openstudio-standards/btap/btap'
require_relative '../../openstudio-standards/btap/fileio'

puts "\nenter osm file name (without file extension):\n"
# osm_infile_name = gets.chomp
osm_infile_name = "NECB2011Hospital"
osm_outfile_name = osm_infile_name.to_s + '_updated.osm'

model = BTAP::FileIO.safe_load_model("#{osm_infile_name}.osm")

spaces =  model.getSpaces()

spaces.each {|space|
	surfaces = space.surfaces()
	surfaces.each_with_index{ |surface, index|
		name = "#{space.nameString}-#{index}-#{surface.surfaceType()}"
		puts name
		surface.setName(name)
	}
	
}


osm_path = OpenStudio::Path.new(osm_outfile_name.to_s)
model.save(osm_path, true)


require 'openstudio'
require_relative '../../openstudio-standards/btap/btap'
require_relative '../../openstudio-standards/btap/fileio'

puts "\nenter osm file name (without file extension):\n"
osm_infile_name = gets.chomp
osm_outfile_name = osm_infile_name.to_s + '_updated.osm'

model = BTAP::FileIO.safe_load_model("#{osm_infile_name}.osm")

surfaces =  model.getSurfaces()

surfaces.each {|surface|
	# rem_surf = ['Surface 14', 'Surface 16', 'Surface 75', 'Surface 46']
	#if rem_surf.include?(surface.name.to_s)
	#	surface.remove()
	#	next
	#end
	vertex_hash = []
	surface.vertices.each_with_index{ |vertex,index|
		old = vertex
		vertex_hash << OpenStudio::Point3d.new( sprintf('%.4f', old.x).to_f , sprintf('%.4f', old.y).to_f , sprintf('%.4f', old.z).to_f )
		# sprintf('%.4f', old.x.round(4))
		# puts new_vertex
	}
	#puts vertex_hash.join()
	surface.setVertices(vertex_hash)
	#puts "\n\n\n\n"
}


osm_path = OpenStudio::Path.new(osm_outfile_name.to_s)
model.save(osm_path, true)


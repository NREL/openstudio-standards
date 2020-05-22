require 'openstudio'

translator = OpenStudio::OSVersion::VersionTranslator.new
ospath_in = OpenStudio::Path.new('./NECB2011Hospital_4.osm')
ospath_out = OpenStudio::Path.new('./NECB2011Hospital_4_updated.osm')
model = translator.loadModel(ospath_in)
model = model.get

spaces = model.getSpaces
converted = []
# loop through space
spaces.each{|space|
	# check for multiplier
	if space.multiplier > 1
    puts space.name
		surfaces = space.surfaces
		# get surfaces of a space
		surfaces.each{|surface|
			puts "\t#{surface.name}\n\t\t#{surface.outsideBoundaryCondition}"
			# convert all surfaces except outdoors BC, and make it adabatic. if that 
			# surface has an adjacent surface, then also convert it to adiabatic
			if surface.outsideBoundaryCondition.to_s == "Surface"
				if !surface.adjacentSurface.nil?
					adj_surface = surface.adjacentSurface.get
					adj_surface.setOutsideBoundaryCondition('Adiabatic')
					converted << adj_surface.name
				end
				surface.setOutsideBoundaryCondition('Adiabatic')
				converted << surface.name
			# if the surface is already not adiabatic or outdoors, set the BC to adiabatic
			elsif surface.outsideBoundaryCondition.to_s != "Outdoors" and  surface.outsideBoundaryCondition.to_s != "Adiabatic"
				surface.setOutsideBoundaryCondition('Adiabatic')
				converted << surface.name
			end
		}
	end
}

# ASSUMING THAT ALL ADIABATIC SURFACES ARE NOT SUPPOSED TO BE EXPOSED TO THE WIND AND SUN
# set adiabatic surface's sun and wind exposure to none
model.getSurfaces.each{|surface|
  if surface.outsideBoundaryCondition.to_s == "Adiabatic"
	surface.setWindExposure("NoWind")
	surface.setSunExposure("NoSun")
	converted << "#{surface.name} -- NoSun NoWind"
  end
}

puts "\n\n"
puts converted
puts converted.length

model.save(ospath_out, true)

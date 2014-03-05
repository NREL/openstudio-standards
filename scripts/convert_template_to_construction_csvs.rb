require 'openstudio'

template_path = OpenStudio::Path.new(ARGV[0])

vt = OpenStudio::OSVersion::VersionTranslator.new
model = vt.loadModel(template_path).get

# Name, Material Type, Thickness (in), Conductivity (Btu*in/hr*ft^2*F), Resistance (hr*ft^2*F/Btu), Density (lb/ft^3), Specific Heat (Btu/lbm*F), Thermal Absorptance,	Solar Absorptance, Visible Absorptance, U-Factor (Btu/hr*ft^2*F), Optical Data Type, Thickness (in)2,	Solar Transmittance At Normal Incidence, Front Side Solar Reflectance At Normal Incidence, Back Side Solar Relectance At Normal Incidence, Visible Transmittance At Normal Incidence, Front Side Visible Reflectance At Normal Incidence, Back Side Visible Relectance At Normal Incidence, Infrared Transmittance At Normal Incidence, Front Side Infrared Hemispherical Emissivity, Back Side Infrared Hemispherical Emissivity, Window Conductivity (Btu/ft*hr*F), Dirt Correction Factor For Solar And Visible Transmittance,	Solar Diffusing

material_rows = []
model.getMaterials.each do |material|
  puts material.name
end

model.getConstructions.each do |construction|

end
require 'openstudio'

require 'csv'

template_path = OpenStudio::Path.new(ARGV[0])

class SpreadSheetMaterial
  attr_accessor :name, :material_type, :thickness, :conductivity, :resistance, :density, :specific_heat, :thermal_absorptance, :solar_absorptance, :visible_absorptance, :gas_type, :u_factor, :solar_heat_gain_coefficient, :visible_transmittance, :optical_data_type, :solar_transmittance_at_normal_incidence, :front_side_solar_reflectance_at_normal_incidence, :back_side_solar_reflectance_at_normal_incidence, :visible_transmittance_at_normal_incidence, :front_side_visible_reflectance_at_normal_incidence, :back_side_visible_reflectance_at_normal_incidence, :infrared_transmittance_at_normal_incidence, :front_side_infrared_hemispherical_emissivity, :back_side_infrared_hemispherical_emissivity, :dirt_correction_factor_for_solar_and_visible_transmittance, :solar_diffusing

  def getOptional(optional)
    if optional.empty?
      return nil
    end
    return optional.get
  end
  
  def initialize(model_object)
    @model_object = nil
    if not model_object.to_StandardOpaqueMaterial.empty?
      @model_object = model_object.to_StandardOpaqueMaterial.get
      @name = @model_object.name
      @material_type = "StandardOpaqueMaterial"
      @thickness = OpenStudio::convert(@model_object.thickness, "m", "in").get
      @conductivity = OpenStudio::convert(@model_object.conductivity, "W/m*K", "Btu*in/hr*ft^2*R").get
      @resistance = 1.0/@conductivity
      @density = OpenStudio::convert(@model_object.density, "kg/m^3", "lb/ft^3").get
      @specific_heat = OpenStudio::convert(@model_object.specificHeat, "J/kg*K", "Btu/lb*R").get
      @thermal_absorptance = @model_object.thermalAbsorptance
      @solar_absorptance = @model_object.solarAbsorptance
      @visible_absorptance = @model_object.visibleAbsorptance
      
    elsif not model_object.to_MasslessOpaqueMaterial.empty?
      @model_object = model_object.to_MasslessOpaqueMaterial.get
      @name = @model_object.name
      @material_type = "MasslessOpaqueMaterial"
      @conductivity = OpenStudio::convert(@model_object.conductivity, "W/m*K", "Btu*in/hr*ft^2*R").get
      @resistance = 1.0/@conductivity
      @density = OpenStudio::convert(@model_object.density, "kg/m^3", "lb/ft^3").get
      @specific_heat = OpenStudio::convert(@model_object.specificHeat, "J/kg*K", "Btu/lb*R").get
      @thermal_absorptance = @model_object.thermalAbsorptance
      @solar_absorptance = @model_object.solarAbsorptance
      @visible_absorptance = @model_object.visibleAbsorptance
      
    elsif not model_object.to_AirGap.empty?
      @model_object = model_object.to_AirGap.get
      @name = @model_object.name
      @material_type = "AirGap"
      @resistance = OpenStudio::convert(@model_object.thermalResistance, "m*K/W", "hr*ft^2*R/Btu*in").get
      @conductivity = 1.0/@resistance
      
    elsif not model_object.to_Gas.empty?
      @model_object = model_object.to_Gas.get
      @name = @model_object.name
      @material_type = "AirGap"
      @thickness = OpenStudio::convert(@model_object.thickness, "m", "in").get
      @gas_type = @model_object.gasType
      
    elsif not model_object.to_SimpleGlazing .empty?
      @model_object = model_object.to_SimpleGlazing .get
      @name = @model_object.name
      @material_type = "SimpleGlazing"
      @u_factor = OpenStudio::convert(@model_object.uFactor, "W/m^2*K", "Btu/hr*ft^2*R").get 
      @solar_heat_gain_coefficient = @model_object.solarHeatGainCoefficient
      @visible_transmittance = getOptional(@model_object.visibleTransmittance)

    elsif not model_object.to_StandardGlazing .empty?
      @model_object = model_object.to_StandardGlazing .get
      @name = @model_object.name
      @material_type = "StandardGlazing"
      @optical_data_type = @model_object.opticalDataType
      @thickness = OpenStudio::convert(@model_object.thickness, "m", "in").get 
      @solar_transmittance_at_normal_incidence = getOptional(@model_object.solarTransmittanceatNormalIncidence)
      @front_side_solar_reflectance_at_normal_incidence = getOptional(@model_object.frontSideSolarReflectanceatNormalIncidence)
      @back_side_solar_reflectance_at_normal_incidence = getOptional(@model_object.backSideSolarReflectanceatNormalIncidence)
      @visible_transmittance_at_normal_incidence = getOptional(@model_object.visibleTransmittanceatNormalIncidence)
      @front_side_visible_reflectance_at_normal_incidence = getOptional(@model_object.frontSideVisibleReflectanceatNormalIncidence)
      @back_side_visible_reflectance_at_normal_incidence = getOptional(@model_object.backSideVisibleReflectanceatNormalIncidence)
      @infrared_transmittance_at_normal_incidence = @model_object.infraredTransmittanceatNormalIncidence
      @front_side_infrared_hemispherical_emissivity = @model_object.frontSideInfraredHemisphericalEmissivity
      @back_side_infrared_hemispherical_emissivity = @model_object.backSideInfraredHemisphericalEmissivity
      @conductivity = OpenStudio::convert(@model_object.conductivity, "W/m*K", "Btu*in/hr*ft^2*R").get
      @dirt_correction_factor_for_solar_and_visible_transmittance = @model_object.dirtCorrectionFactorforSolarandVisibleTransmittance
      @solar_diffusing = @model_object.solarDiffusing
      
    else
      puts "Unknown material #{model_object.name}"
    end
  end
  
  def to_row
    return [@name, @material_type, @thickness, @conductivity, @resistance, @density, @specific_heat, @thermal_absorptance, @solar_absorptance, @visible_absorptance, @gas_type, @u_factor, @solar_heat_gain_coefficient, @visible_transmittance, @optical_data_type, @solar_transmittance_at_normal_incidence, @front_side_solar_reflectance_at_normal_incidence, @back_side_solar_reflectance_at_normal_incidence, @visible_transmittance_at_normal_incidence, @front_side_visible_reflectance_at_normal_incidence, @back_side_visible_reflectance_at_normal_incidence, @infrared_transmittance_at_normal_incidence, @front_side_infrared_hemispherical_emissivity, @back_side_infrared_hemispherical_emissivity, @dirt_correction_factor_for_solar_and_visible_transmittance, @solar_diffusing]
  end

end

class SpreadSheetConstruction
  attr_accessor :name, :intended_surface_type, :standards_construction_type, :material_1, :material_2, :material_3, :material_4, :material_5, :material_6
  
  def getMaterialName(materials, index)
    material = materials[index]
    if material.nil?
      return nil
    end
    return material.name.get
  end
  
  def initialize(model_object)
    @model_object = model_object.to_Construction.get
    materials = @model_object.layers
    if materials.size > 6
      puts "Construction #{@model_object.name} has too many layers"
    end
    
    @name = @model_object.name
    @intended_surface_type = nil
    @standards_construction_type = nil
    @material_1 = getMaterialName(materials, 0)
    @material_2 = getMaterialName(materials, 1)
    @material_3 = getMaterialName(materials, 2)
    @material_4 = getMaterialName(materials, 3)
    @material_5 = getMaterialName(materials, 4)
    @material_6 = getMaterialName(materials, 5)
  end
  
  def to_row
    return [@name, @intended_surface_type, @standards_construction_type, @material_1, @material_2, @material_3, @material_4, @material_5, @material_6]
  end

end

class SpreadSheetConstructionSet
  attr_accessor :name, :template, :building_type, :space_type, :climate_zone, :construction_standard, :exterior_wall, :exterior_floor, :exterior_roof, :interior_wall, :interior_floor, :interior_ceiling, :ground_contact_wall, :ground_contact_floor, :ground_contact_ceiling, :exterior_fixed_window, :exterior_operable_window, :exterior_door, :exterior_glass_door, :exterior_overhead_door, :exterior_skylight, :tubular_daylight_dome, :tubular_daylight_diffuser, :interior_fixed_window, :interior_operable_window, :interior_door, :space_shading, :building_shading, :site_shading, :interior_partition
  
  def getMaterialName(material)
    if material.empty?
      return nil
    end
    return material.get.name.get
  end
  
  def initialize(model_object)
    @model_object = model_object.to_DefaultConstructionSet.get    
    @name = @model_object.name
    @template = nil
    @building_type = nil
    @space_type = nil
    @climate_zone = nil
    @construction_standard = nil
    
    defaultExteriorSurfaceConstructions = @model_object.defaultExteriorSurfaceConstructions
    if not defaultExteriorSurfaceConstructions.empty?
      defaultExteriorSurfaceConstructions = defaultExteriorSurfaceConstructions.get
      @exterior_wall = getMaterialName(defaultExteriorSurfaceConstructions.wallConstruction)
      @exterior_floor = getMaterialName(defaultExteriorSurfaceConstructions.floorConstruction)
      @exterior_roof = getMaterialName(defaultExteriorSurfaceConstructions.roofCeilingConstruction)
    end
    
    defaultInteriorSurfaceConstructions = @model_object.defaultInteriorSurfaceConstructions
    if not defaultInteriorSurfaceConstructions.empty?
      defaultInteriorSurfaceConstructions = defaultInteriorSurfaceConstructions.get
      @interior_wall = getMaterialName(defaultInteriorSurfaceConstructions.wallConstruction)
      @interior_floor = getMaterialName(defaultInteriorSurfaceConstructions.floorConstruction)
      @interior_ceiling = getMaterialName(defaultInteriorSurfaceConstructions.roofCeilingConstruction)
    end
    
    defaultGroundContactSurfaceConstructions = @model_object.defaultGroundContactSurfaceConstructions
    if not defaultGroundContactSurfaceConstructions.empty?
      defaultGroundContactSurfaceConstructions = defaultGroundContactSurfaceConstructions.get
      @ground_contact_wall = getMaterialName(defaultGroundContactSurfaceConstructions.wallConstruction)
      @ground_contact_floor = getMaterialName(defaultGroundContactSurfaceConstructions.floorConstruction)
      @ground_contact_ceiling = getMaterialName(defaultGroundContactSurfaceConstructions.roofCeilingConstruction)
    end
    
    defaultExteriorSubSurfaceConstructions = @model_object.defaultExteriorSubSurfaceConstructions
    if not defaultExteriorSubSurfaceConstructions.empty?
      defaultExteriorSubSurfaceConstructions = defaultExteriorSubSurfaceConstructions.get
      @exterior_fixed_window = getMaterialName(defaultExteriorSubSurfaceConstructions.fixedWindowConstruction)
      @exterior_operable_window = getMaterialName(defaultExteriorSubSurfaceConstructions.operableWindowConstruction)
      @exterior_door = getMaterialName(defaultExteriorSubSurfaceConstructions.doorConstruction)
      @exterior_glass_door = getMaterialName(defaultExteriorSubSurfaceConstructions.glassDoorConstruction)
      @exterior_overhead_door = getMaterialName(defaultExteriorSubSurfaceConstructions.overheadDoorConstruction)
      @exterior_skylight = getMaterialName(defaultExteriorSubSurfaceConstructions.skylightConstruction)
      @tubular_daylight_dome = getMaterialName(defaultExteriorSubSurfaceConstructions.tubularDaylightDomeConstruction)
      @tubular_daylight_diffuser = getMaterialName(defaultExteriorSubSurfaceConstructions.tubularDaylightDiffuserConstruction)
    end
    
    
    defaultInteriorSubSurfaceConstructions = @model_object.defaultInteriorSubSurfaceConstructions
    if not defaultInteriorSubSurfaceConstructions.empty?
      defaultInteriorSubSurfaceConstructions = defaultInteriorSubSurfaceConstructions.get
      @interior_fixed_window = getMaterialName(defaultInteriorSubSurfaceConstructions.fixedWindowConstruction)
      @interior_operable_window = getMaterialName(defaultInteriorSubSurfaceConstructions.operableWindowConstruction)
      @interior_door = getMaterialName(defaultInteriorSubSurfaceConstructions.doorConstruction)
    end

    @space_shading = getMaterialName(@model_object.spaceShadingConstruction)
    @building_shading = getMaterialName(@model_object.buildingShadingConstruction)
    @site_shading = getMaterialName(@model_object.siteShadingConstruction)
    @interior_partition = getMaterialName(@model_object.interiorPartitionConstruction)

  end
  
  def to_row
    return [@name, @template, @building_type, @space_type, @climate_zone, @construction_standard, @exterior_wall, @exterior_floor, @exterior_roof, @interior_wall, @interior_floor, @interior_ceiling, @ground_contact_wall, @ground_contact_floor, @ground_contact_ceiling, @exterior_fixed_window, @exterior_operable_window, @exterior_door, @exterior_glass_door, @exterior_overhead_door, @exterior_skylight, @tubular_daylight_dome, @tubular_daylight_diffuser, @interior_fixed_window, @interior_operable_window, @interior_door, @space_shading, @building_shading, @site_shading, @interior_partition]
  end

end

def getTemplateAndSpaceTypeName(template)
  if match_data = /InsulAttic(.*)/.match(template)
    return [match_data[1].strip, "Attic"]
  end
  return [template, nil]
end

def getClimateZoneNames(climateZone)
  result = []
  result << climateZone.strip
  return result
end

def getBuildingTypeName(buildingType)
  return buildingType.strip
end

def makeSpreadSheetConstructionSets(model_object)
  result = []
  name = model_object.name.get
  
  if match_data = /(.*) ClimateZone (.*) \((.*)\).*ConstSet/.match(name)
    temp = getTemplateAndSpaceTypeName(match_data[1])
    template = temp[0]
    space_type = temp[1]
    climate_zones = getClimateZoneNames(match_data[2])
    building_type = getBuildingTypeName(match_data[3])
    
    climate_zones.each do |climate_zone|
      spreadsheet_construction_set = SpreadSheetConstructionSet.new(model_object)
      spreadsheet_construction_set.name = name
      spreadsheet_construction_set.template = template
      spreadsheet_construction_set.space_type = space_type
      spreadsheet_construction_set.building_type = building_type
      spreadsheet_construction_set.climate_zone = climate_zone
      result << spreadsheet_construction_set
    end
  else
    puts "no match '#{name}'"
    result << SpreadSheetConstructionSet.new(model_object)
  end
  return result
end


vt = OpenStudio::OSVersion::VersionTranslator.new
model = vt.loadModel(template_path).get

spreadsheet_materials = []
model.getMaterials.each do |material|
  spreadsheet_material = SpreadSheetMaterial.new(material)
  spreadsheet_materials << spreadsheet_material
end
CSV.open("./Materials.csv", "w") do |csv|
  spreadsheet_materials.each do |spreadsheet_material|
    csv << spreadsheet_material.to_row
  end
end

spreadsheet_constructions = []
model.getConstructions.each do |construction|
  spreadsheet_construction = SpreadSheetConstruction.new(construction)
  spreadsheet_constructions << spreadsheet_construction
end
CSV.open("./Constructions.csv", "w") do |csv|
  spreadsheet_constructions.each do |spreadsheet_construction|
    csv << spreadsheet_construction.to_row
  end
end

spreadsheet_construction_sets = []
model.getDefaultConstructionSets.each do |constructionSet|
  temp = makeSpreadSheetConstructionSets(constructionSet)
  temp.each do |spreadsheet_construction_set|
    spreadsheet_construction_sets << spreadsheet_construction_set
  end
end
CSV.open("./ConstructionSets.csv", "w") do |csv|
  spreadsheet_construction_sets.each do |spreadsheet_construction_set|
    csv << spreadsheet_construction_set.to_row
  end
end
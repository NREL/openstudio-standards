require 'openstudio'

require 'csv'

template_path = OpenStudio::Path.new(ARGV[0])

### MATERIALS ###
class MaterialNameParser
  def initialize(name)
    @name = name
  end
  
  def name 
    return @name
  end
end

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
      name_parser = MaterialNameParser.new(@model_object.name.get)
      @name = name_parser.name
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
      name_parser = MaterialNameParser.new(@model_object.name.get)
      @name = name_parser.name
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
      name_parser = MaterialNameParser.new(@model_object.name.get)
      @name = name_parser.name
      @material_type = "AirGap"
      @resistance = OpenStudio::convert(@model_object.thermalResistance, "m*K/W", "hr*ft^2*R/Btu*in").get
      @conductivity = 1.0/@resistance
      
    elsif not model_object.to_Gas.empty?
      @model_object = model_object.to_Gas.get
      name_parser = MaterialNameParser.new(@model_object.name.get)
      @name = name_parser.name
      @material_type = "AirGap"
      @thickness = OpenStudio::convert(@model_object.thickness, "m", "in").get
      @gas_type = @model_object.gasType
      
    elsif not model_object.to_SimpleGlazing .empty?
      @model_object = model_object.to_SimpleGlazing .get
      name_parser = MaterialNameParser.new(@model_object.name.get)
      @name = name_parser.name
      @material_type = "SimpleGlazing"
      @u_factor = OpenStudio::convert(@model_object.uFactor, "W/m^2*K", "Btu/hr*ft^2*R").get 
      @solar_heat_gain_coefficient = @model_object.solarHeatGainCoefficient
      @visible_transmittance = getOptional(@model_object.visibleTransmittance)

    elsif not model_object.to_StandardGlazing .empty?
      @model_object = model_object.to_StandardGlazing .get
      name_parser = MaterialNameParser.new(@model_object.name.get)
      @name = name_parser.name
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
      @resistance = 1.0/@conductivity
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

### CONSTRUCTIONS ###
class ConstructionNameParser
  def initialize(name)
    @name = name
  end
  
  def name 
    return @name
  end
  
  def intended_surface_type
    result = nil
    
    # check for attic first, some are name "ExtRoof AtticFloor"
    if /AtticFloor/.match(@name)
      result = "AtticFloor"
    elsif /AtticRoof/.match(@name)
      result = "AtticRoof"      
    elsif /ExtRoof/.match(@name)
      result = "ExteriorRoof"
    elsif /ExtWall/.match(@name)
      result = "ExteriorWall"
    elsif /ExtSlab/.match(@name)
      result = "ExteriorFloor"      
    elsif /ExtWindow/.match(@name)
      result = "ExteriorWindow"
    elsif /Exterior Door/.match(@name)
      result = "ExteriorDoor"      
    elsif /Interior Partition/.match(@name)
      result = "InteriorPartition"      
    elsif /Interior Wall/.match(@name)
      result = "InteriorWall"      
    elsif /Interior Ceiling/.match(@name)
      result = "InteriorRoof"    
    elsif /Interior Floor/.match(@name)
      result = "InteriorFloor"    
    elsif /Interior Window/.match(@name)
      result = "InteriorWindow"        
    elsif /Interior Door/.match(@name)
      result = "InteriorDoor"           
    else
      puts "Can't parse intended_surface_type from '#{@name}'"
    end
    return result
  end

  def standards_construction_type
    result = nil
    
    # check for attic first, some are name "ExtRoof AtticFloor"
    if /AtticFloor/.match(@name)
      result = "WoodFramed" # Right?
    elsif /AtticRoof/.match(@name)
      result = "WoodFramed" # Right?      
    elsif /Mass/.match(@name)
      result = "Mass"
    elsif /SteelFrame/.match(@name)
      result = "SteelFramed"      
    elsif /WoodFrame/.match(@name)
      result = "WoodFramed"         
    elsif /Metal/.match(@name)
      result = "Metal"     
    elsif /IEAD/.match(@name)
      result = "IEAD"     
    elsif /ExtWindow/.match(@name)
      result = nil # View or Daylight?  
    elsif /Exterior Door/.match(@name)
      result = nil # Swinging, NonSwinging, RollUp, Sliding?      
    elsif /ExtSlab/.match(@name)
      result = nil # Heated or Unheated?     
    elsif /Interior Partition/.match(@name)
      result = nil  
    elsif /Interior Wall/.match(@name)
      result = nil        
    elsif /Interior Floor/.match(@name)
      result = nil  
    elsif /Interior Ceiling/.match(@name)
      result = nil       
    elsif /Interior Window/.match(@name)
      result = nil              
    elsif /Interior Door/.match(@name)
      result = nil 
    else
      puts "Can't parse standards_construction_type from '#{@name}'"
    end
    
    return result
  end
  
end

class SpreadSheetConstruction
  attr_accessor :name, :intended_surface_type, :standards_construction_type, :material_1, :material_2, :material_3, :material_4, :material_5, :material_6
  
  def getMaterialName(materials, index)
    material = materials[index]
    if material.nil?
      return nil
    end
    name_parser = MaterialNameParser.new(material.name.get)
    return name_parser.name
  end
  
  def initialize(model_object)
    @model_object = model_object.to_Construction.get
    name_parser = ConstructionNameParser.new(@model_object.name.get)
    
    materials = @model_object.layers
    if materials.size > 6
      puts "Construction #{@model_object.name} has too many layers"
    end
    
    @name = name_parser.name
    @intended_surface_type = name_parser.intended_surface_type
    @standards_construction_type = name_parser.standards_construction_type
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

### CONSTRUCTION SETS ###
class ConstructionSetNameParser
  attr_reader :name, :template, :space_type, :climate_zone_set, :building_type
  
  def initialize(name)
  
    @name = name
    if match_data = /(.*) ClimateZone (.*) \((.*)\).*ConstSet/.match(name)
    
      if match_data2 = /InsulAttic(.*)/.match(match_data[1])
        @template = match_data2[1].strip
        @space_type = "Attic"
      else
        @template = match_data[1].strip
        @space_type = nil
      end

      @climate_zone_set = match_data[2].strip
      @building_type = match_data[3].strip

    else
      puts "Unable to parse name '#{name}'"
    end
  end
  
  def name 
    return @name
  end
  
  def template 
    result = @template
    
    if "ASHRAE 189.1-2009" == @template
      result = "ASHRAE 189.1-2009"  # Right?  
    elsif "ASHRAE 90.1-1999" == @template
      result = "NREL_1999"  # Right? 
    elsif "ASHRAE 90.1-2001" == @template
      result = "NREL_2001"  # Right?
    elsif "ASHRAE 90.1-2004" == @template
      result = "NREL_2004"  # Right?          
    elsif "ASHRAE 90.1-2007" == @template
      result = "NREL_2007"  # Right?
    elsif "CBECS Before-1980" == @template
      result = "CBECS_Before-1980"  # Right?
    elsif "CBECS 1980-2004" == @template
      result = "CBECS_1980-2004"  # Right?         
    else
      puts "Unable to parse template from '#{@template}'"
    end
    return result     
  end
  
  def space_type 
    if @space_type.nil?
      return nil
    end
    
    result = @space_type
    if /Attic/.match(@space_type)
      result = "Attic"  
    else
      puts "Unable to parse space_type from '#{@space_type}'"
    end
    return result 
    
    return @space_type
  end
  
  def climate_zone_set 
    result = @climate_zone_set

    if "1" == @climate_zone_set
      result = "ClimateZone 1"   
    elsif "2" == @climate_zone_set
      result = "ClimateZone 2"  
    elsif "2a" == @climate_zone_set
      result = "ClimateZone 2a"      
    elsif "2b" == @climate_zone_set
      result = "ClimateZone 2b"        
    elsif "3" == @climate_zone_set
      result = "ClimateZone 3"  
    elsif "3a" == @climate_zone_set
      result = "ClimateZone 3a"          
    elsif "3b" == @climate_zone_set
      result = "ClimateZone 3b"     
    elsif "3b LAS" == @climate_zone_set
      result = "ClimateZone 3b"    # Right?      
    elsif "3b LAX" == @climate_zone_set
      result = "ClimateZone 3b"    # Right?    
    elsif "3c" == @climate_zone_set
      result = "ClimateZone 3c"            
    elsif "4" == @climate_zone_set
      result = "ClimateZone 4"  
    elsif "4a" == @climate_zone_set
      result = "ClimateZone 4a"  
    elsif "4b" == @climate_zone_set
      result = "ClimateZone 4b"  
    elsif "4c" == @climate_zone_set
      result = "ClimateZone 4c"        
    elsif "5" == @climate_zone_set
      result = "ClimateZone 5" 
    elsif "5a" == @climate_zone_set
      result = "ClimateZone 5a"        
    elsif "5b" == @climate_zone_set
      result = "ClimateZone 5b"        
    elsif "6" == @climate_zone_set
      result = "ClimateZone 6"  
    elsif "6a" == @climate_zone_set
      result = "ClimateZone 6a"      
    elsif "6b" == @climate_zone_set
      result = "ClimateZone 6b" 
    elsif "7" == @climate_zone_set
      result = "ClimateZone 7"  
    elsif "8" == @climate_zone_set
      result = "ClimateZone 8"  
    elsif "1-2" == @climate_zone_set
      result = "ClimateZone 1-2"   
    elsif "1-3" == @climate_zone_set
      result = "ClimateZone 1-3"       
    elsif "1-3b" == @climate_zone_set
      result = "ClimateZone 1-3b"   
    elsif "1-5" == @climate_zone_set
      result = "ClimateZone 1-5"    
    elsif "1-8" == @climate_zone_set
      result = "ClimateZone 1-8"         
    elsif "3a-3b" == @climate_zone_set
      result = "ClimateZone 3a-b"  
    elsif "4-5" == @climate_zone_set
      result = "ClimateZone 4-5"        
    elsif "5-6" == @climate_zone_set
      result = "ClimateZone 5-6"       
    elsif "6-8" == @climate_zone_set
      result = "ClimateZone 6-8"   
    elsif "7-8" == @climate_zone_set
      result = "ClimateZone 7-8"         
    else
      puts "Unable to parse climate_zone_set from '#{@climate_zone_set}'"
    end

    return result      
  end

  def building_type 
  
    result = @building_type
    if /smoff/.match(@building_type)
      result = "SmallOffice"
    elsif /mdoff/.match(@building_type) 
      result = "MediumOffice"
    elsif /lgoff/.match(@building_type)
      result = "LargeOffice"
    elsif /s htl/.match(@building_type)
      result = "SmallHotel"
    elsif /l htl/.match(@building_type)
      result = "LargeHotel"      
    elsif /out pat/.match(@building_type)
      result = "Outpatient"
    elsif /p scho/.match(@building_type)
      result = "PrimarySchool"     
    elsif /s scho/.match(@building_type)
      result = "SecondarySchool"      
    elsif /smarket/.match(@building_type)
      result = "SuperMarket"      
    elsif /fsr/.match(@building_type)
      result = "FullServiceRestaurant"  
    elsif /qsr/.match(@building_type)
      result = "QuickServiceRestaurant"   
    elsif /m apt/.match(@building_type)
      result = "Mid-riseApartment"        
    elsif /warehse/.match(@building_type)
      result = "Warehouse"        
    elsif /hosp/.match(@building_type)
      result = "Hospital"         
    elsif /retail/.match(@building_type)
      result = "Retail"    
    elsif /stmall/.match(@building_type)
      result = "StripMall"    
    elsif /generic/.match(@building_type)
      result = nil # Right?     
    else
      puts "Unable to parse space_type from '#{@building_type}' in '#{@name}'"
    end
    return result
  end  
  
  def construction_standard 
    result = @template
    
    if "ASHRAE 189.1-2009" == @template
      result = "ASHRAE 189.1-2009"  
    elsif "ASHRAE 90.1-1999" == @template
      result = "ASHRAE 90.1-1999"    
    elsif "ASHRAE 90.1-2001" == @template
      result = "ASHRAE 90.1-2001"            
    elsif "ASHRAE 90.1-2004" == @template
      result = "ASHRAE 90.1-2004"            
    elsif "ASHRAE 90.1-2007" == @template
      result = "ASHRAE 90.1-2007"        
    elsif "CBECS Before-1980" == @template
      result = nil         # Right?
    elsif "CBECS 1980-2004" == @template
      result = nil       # Right?        
    else
      puts "Unable to parse construction_standard from '#{@template}'"
    end
    return result   
  end  
  
end

class SpreadSheetConstructionSet
  attr_accessor :name, :template, :building_type, :space_type, :climate_zone, :construction_standard, :exterior_wall, :exterior_floor, :exterior_roof, :interior_wall, :interior_floor, :interior_ceiling, :ground_contact_wall, :ground_contact_floor, :ground_contact_ceiling, :exterior_fixed_window, :exterior_operable_window, :exterior_door, :exterior_glass_door, :exterior_overhead_door, :exterior_skylight, :tubular_daylight_dome, :tubular_daylight_diffuser, :interior_fixed_window, :interior_operable_window, :interior_door, :space_shading, :building_shading, :site_shading, :interior_partition
  
  def getConstructionName(construction)
    if construction.empty?
      return nil
    end
    name_parser = ConstructionNameParser.new(construction.name.get)
    return name_parser.name
  end
  
  def initialize(model_object)
    @model_object = model_object.to_DefaultConstructionSet.get   
    name_parser = ConstructionSetNameParser.new(@model_object.name.get)
    @name = name_parser.name
    @template = name_parser.template
    @building_type = name_parser.building_type
    @space_type = name_parser.space_type
    @climate_zone_set = name_parser.climate_zone_set
    @construction_standard = name_parser.construction_standard
    
    defaultExteriorSurfaceConstructions = @model_object.defaultExteriorSurfaceConstructions
    if not defaultExteriorSurfaceConstructions.empty?
      defaultExteriorSurfaceConstructions = defaultExteriorSurfaceConstructions.get
      @exterior_wall = getConstructionName(defaultExteriorSurfaceConstructions.wallConstruction)
      @exterior_floor = getConstructionName(defaultExteriorSurfaceConstructions.floorConstruction)
      @exterior_roof = getConstructionName(defaultExteriorSurfaceConstructions.roofCeilingConstruction)
    end
    
    defaultInteriorSurfaceConstructions = @model_object.defaultInteriorSurfaceConstructions
    if not defaultInteriorSurfaceConstructions.empty?
      defaultInteriorSurfaceConstructions = defaultInteriorSurfaceConstructions.get
      @interior_wall = getConstructionName(defaultInteriorSurfaceConstructions.wallConstruction)
      @interior_floor = getConstructionName(defaultInteriorSurfaceConstructions.floorConstruction)
      @interior_ceiling = getConstructionName(defaultInteriorSurfaceConstructions.roofCeilingConstruction)
    end
    
    defaultGroundContactSurfaceConstructions = @model_object.defaultGroundContactSurfaceConstructions
    if not defaultGroundContactSurfaceConstructions.empty?
      defaultGroundContactSurfaceConstructions = defaultGroundContactSurfaceConstructions.get
      @ground_contact_wall = getConstructionName(defaultGroundContactSurfaceConstructions.wallConstruction)
      @ground_contact_floor = getConstructionName(defaultGroundContactSurfaceConstructions.floorConstruction)
      @ground_contact_ceiling = getConstructionName(defaultGroundContactSurfaceConstructions.roofCeilingConstruction)
    end
    
    defaultExteriorSubSurfaceConstructions = @model_object.defaultExteriorSubSurfaceConstructions
    if not defaultExteriorSubSurfaceConstructions.empty?
      defaultExteriorSubSurfaceConstructions = defaultExteriorSubSurfaceConstructions.get
      @exterior_fixed_window = getConstructionName(defaultExteriorSubSurfaceConstructions.fixedWindowConstruction)
      @exterior_operable_window = getConstructionName(defaultExteriorSubSurfaceConstructions.operableWindowConstruction)
      @exterior_door = getConstructionName(defaultExteriorSubSurfaceConstructions.doorConstruction)
      @exterior_glass_door = getConstructionName(defaultExteriorSubSurfaceConstructions.glassDoorConstruction)
      @exterior_overhead_door = getConstructionName(defaultExteriorSubSurfaceConstructions.overheadDoorConstruction)
      @exterior_skylight = getConstructionName(defaultExteriorSubSurfaceConstructions.skylightConstruction)
      @tubular_daylight_dome = getConstructionName(defaultExteriorSubSurfaceConstructions.tubularDaylightDomeConstruction)
      @tubular_daylight_diffuser = getConstructionName(defaultExteriorSubSurfaceConstructions.tubularDaylightDiffuserConstruction)
    end
    
    defaultInteriorSubSurfaceConstructions = @model_object.defaultInteriorSubSurfaceConstructions
    if not defaultInteriorSubSurfaceConstructions.empty?
      defaultInteriorSubSurfaceConstructions = defaultInteriorSubSurfaceConstructions.get
      @interior_fixed_window = getConstructionName(defaultInteriorSubSurfaceConstructions.fixedWindowConstruction)
      @interior_operable_window = getConstructionName(defaultInteriorSubSurfaceConstructions.operableWindowConstruction)
      @interior_door = getConstructionName(defaultInteriorSubSurfaceConstructions.doorConstruction)
    end

    @space_shading = getConstructionName(@model_object.spaceShadingConstruction)
    @building_shading = getConstructionName(@model_object.buildingShadingConstruction)
    @site_shading = getConstructionName(@model_object.siteShadingConstruction)
    @interior_partition = getConstructionName(@model_object.interiorPartitionConstruction)

  end
  
  def to_row
    return [@name, @template, @building_type, @space_type, @climate_zone_set, @construction_standard, @exterior_wall, @exterior_floor, @exterior_roof, @interior_wall, @interior_floor, @interior_ceiling, @ground_contact_wall, @ground_contact_floor, @ground_contact_ceiling, @exterior_fixed_window, @exterior_operable_window, @exterior_door, @exterior_glass_door, @exterior_overhead_door, @exterior_skylight, @tubular_daylight_dome, @tubular_daylight_diffuser, @interior_fixed_window, @interior_operable_window, @interior_door, @space_shading, @building_shading, @site_shading, @interior_partition]
  end

end

### DO THE WORK ###

vt = OpenStudio::OSVersion::VersionTranslator.new
model = vt.loadModel(template_path).get

# materials
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

# constructions
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

# construction sets
spreadsheet_construction_sets = []
model.getDefaultConstructionSets.each do |constructionSet|
  spreadsheet_construction_set = SpreadSheetConstructionSet.new(constructionSet)
  spreadsheet_construction_sets << spreadsheet_construction_set
end
CSV.open("./ConstructionSets.csv", "w") do |csv|
  spreadsheet_construction_sets.each do |spreadsheet_construction_set|
    csv << spreadsheet_construction_set.to_row
  end
end
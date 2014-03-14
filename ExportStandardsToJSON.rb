#this script reads the OpenStudio_space_types_and_standards.xlsx spreadsheet
#and creates a JSON file containing all the information on the SpaceTypes tab

require 'rubygems'
require 'json'
require 'openstudio'
require 'win32ole'

def getNumRows(worksheet, column, begin_row)
  # find number of rows
  max_row = 12000
  end_row = begin_row
  data = worksheet.range("#{column}#{begin_row}:#{column}#{max_row}")['Value']
  data.each do |row|
    if row[0].nil?
      end_row -= 1
      break
    end
    end_row += 1
  end
  return end_row
end

# read the Templates tab and put into a Hash
def getTemplatesHash(workbook)
  # compound key for this sheet is [template]

  #specify worksheet
  worksheet = workbook.worksheets("Templates")
  begin_column = "A"
  end_column = "B"
  begin_row = 4
  end_row = getNumRows(worksheet, begin_column, begin_row)
  
  #specify data range
  data = worksheet.range("#{begin_column}#{begin_row}:#{end_column}#{end_row}")['Value']

  #define the columns where the data live in the spreadsheet
  #basic information
  template_col = 0
  notes_col = 1
  
  #create a nested hash to store all the data
  templates = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  #loop through all the templates and put them into a nested hash
  data.each do |row|
    template = row[template_col].strip
    templates[template]["notes"] = row[notes_col]
  end
  
  return templates
end

# read the Standards tab and put into a Hash
def getStandardsHash(workbook)
  # compound key for this sheet is [standard]

  #specify worksheet
  worksheet = workbook.worksheets("Standards")
  begin_column = "A"
  end_column = "A"
  begin_row = 4
  end_row = getNumRows(worksheet, begin_column, begin_row)
  
  #specify data range
  data = worksheet.range("#{begin_column}#{begin_row}:#{end_column}#{end_row}")['Value']

  #define the columns where the data live in the spreadsheet
  #basic information
  standard_col = 0

  #create a nested hash to store all the data
  standards = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  #loop through all the templates and put them into a nested hash
  data.each do |row|
    standard = row[standard_col].strip
    standards[standard]
  end
  
  return standards
end

# read the ClimateZones tab and put into a Hash
def getClimateZonesHash(workbook)
  # compound key for this sheet is [climate_zone]

  #specify worksheet
  worksheet = workbook.worksheets("ClimateZones")
  begin_column = "A"
  end_column = "D"
  begin_row = 4
  end_row = getNumRows(worksheet, begin_column, begin_row)
  
  #specify data range
  data = worksheet.range("#{begin_column}#{begin_row}:#{end_column}#{end_row}")['Value']

  #define the columns where the data live in the spreadsheet
  #basic information
  climate_zone_col = 0
  standard_col = 1
  representative_city_col = 2
  bcl_weather_component_id_col = 3

  #create a nested hash to store all the data
  climate_zones = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  #loop through all the templates and put them into a nested hash
  data.each do |row|
    climate_zone = row[climate_zone_col].strip
    climate_zones[climate_zone]["standard"] = row[standard_col]
    climate_zones[climate_zone]["representative_city"] = row[representative_city_col]
    climate_zones[climate_zone]["bcl_weather_component_id"] = row[bcl_weather_component_id_col]
  end
  
  return climate_zones
end


# read the ClimateZoneSets tab and put into a Hash
def getClimateZoneSetsHash(workbook)
  # compound key for this sheet is [climate_zone_set]

  #specify worksheet
  worksheet = workbook.worksheets("ClimateZoneSets")
  begin_column = "A"
  end_column = "AZ"
  begin_row = 4
  end_row = getNumRows(worksheet, begin_column, begin_row)
  
  #specify data range
  data = worksheet.range("#{begin_column}#{begin_row}:#{end_column}#{end_row}")['Value']

  #define the columns where the data live in the spreadsheet
  #basic information
  climate_zone_set_col = 0
  climate_zone_col = 1

  #create a nested hash to store all the data
  climate_zone_sets = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  #loop through all the templates and put them into a nested hash
  data.each do |row|
    climate_zone_set = row[climate_zone_set_col].strip
    climate_zones = []
    
    climate_zone_col = 1
    while climate_zone = row[climate_zone_col]
      climate_zones << climate_zone
      climate_zone_col += 1
    end
    climate_zone_sets[climate_zone_set]["climate_zones"] = climate_zones
  end
  
  return climate_zone_sets
end

# read the SpaceTypes tab and put into a Hash
def getSpaceTypesHash(workbook)
  # compound key for this sheet is [template][climate_zone_set][building_type][space_type]

  #specify worksheet
  worksheet = workbook.worksheets("SpaceTypes")
  begin_column = "C"
  end_column = "AZ"
  begin_row = 6
  end_row = getNumRows(worksheet, begin_column, begin_row)
  
  #specify data range
  data = worksheet.range("#{begin_column}#{begin_row}:#{end_column}#{end_row}")['Value']

  #define the columns where the data live in the spreadsheet
  #basic information
  template_col = 0
  climate_col = 1
  building_type_col = 2
  space_type_col = 3

  #RGB color
  rgb_col = 4

  #lighting
  lighting_standard_col = 5
  lighting_pri_spc_type_col = 6
  lighting_sec_spc_type_col = 7
  lighting_w_per_area_col = 11
  lighting_w_per_person_col = 12
  lighting_w_per_linear_col = 13
  lighting_sch_col = 17

  #ventilation
  ventilation_standard_col = 18
  ventilation_pri_spc_type_col = 19
  ventilation_sec_spc_type_col = 20  
  ventilation_per_area_col = 22
  ventilation_per_person_col = 23
  ventilation_ach_col = 24
  #ventilation_sch_col = 25 #TODO: David where did this col go?

  #occupancy
  occupancy_per_area_col = 25
  occupancy_sch_col = 26
  occupancy_activity_sch_col = 27

  #infiltration
  infiltration_per_area_ext_col = 28
  infiltration_sch_col = 29

  #gas equipment
  gas_equip_per_area_col = 30
  # TODO: read fraction fields
  gas_equip_sch_col = 34

  #electric equipment
  elec_equip_per_area_col = 35
  # TODO: read fraction fields
  elec_equip_sch_col = 39
  
  #thermostats
  heating_setpoint_sch_col = 40
  cooling_setpoint_sch_col = 41
  
  #TODO: read service hot water
  
  #create a nested hash to store all the data
  space_types = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  #loop through all the ref bldg space types and put them into a nested hash
  data.each do |row|
    template = row[template_col].strip
    climate = row[climate_col].strip
    building_type = row[building_type_col].strip
    space_type = row[space_type_col].strip

    #RGB color
    space_types[template][climate][building_type][space_type]["rgb"] = row[rgb_col]
    
    #lighting
    space_types[template][climate][building_type][space_type]["lighting_standard"] = row[lighting_standard_col]
    space_types[template][climate][building_type][space_type]["lighting_pri_spc_type"] = row[lighting_pri_spc_type_col]
    space_types[template][climate][building_type][space_type]["lighting_sec_spc_type"] = row[lighting_sec_spc_type_col]
    space_types[template][climate][building_type][space_type]["lighting_w_per_area"] = row[lighting_w_per_area_col]
    space_types[template][climate][building_type][space_type]["lighting_w_per_person"] = row[lighting_w_per_person_col]
    space_types[template][climate][building_type][space_type]["lighting_sch"] = row[lighting_sch_col]
    
    #ventilation
    space_types[template][climate][building_type][space_type]["ventilation_standard"] = row[ventilation_standard_col]
    space_types[template][climate][building_type][space_type]["ventilation_pri_spc_type"] = row[ventilation_pri_spc_type_col]
    space_types[template][climate][building_type][space_type]["ventilation_sec_spc_type"] = row[ventilation_sec_spc_type_col] 
    space_types[template][climate][building_type][space_type]["ventilation_per_area"] = row[ventilation_per_area_col]
    space_types[template][climate][building_type][space_type]["ventilation_per_person"] = row[ventilation_per_person_col]
    space_types[template][climate][building_type][space_type]["ventilation_ach"] = row[ventilation_ach_col]
    #space_types[template][climate][building_type][space_type]["ventilation_sch"] = row[ventilation_sch_col]
    
    #occupancy
    space_types[template][climate][building_type][space_type]["occupancy_per_area"] = row[occupancy_per_area_col]
    space_types[template][climate][building_type][space_type]["occupancy_sch"] = row[occupancy_sch_col]
    space_types[template][climate][building_type][space_type]["occupancy_activity_sch"] = row[occupancy_activity_sch_col]
    
    #infiltration
    space_types[template][climate][building_type][space_type]["infiltration_per_area_ext"] = row[infiltration_per_area_ext_col]
    space_types[template][climate][building_type][space_type]["infiltration_sch"] = row[infiltration_sch_col]

    #gas equipment
    space_types[template][climate][building_type][space_type]["gas_equip_per_area"] = row[gas_equip_per_area_col]
    space_types[template][climate][building_type][space_type]["gas_equip_sch"] = row[gas_equip_sch_col]
	
    #electric equipment
    space_types[template][climate][building_type][space_type]["elec_equip_per_area"] = row[elec_equip_per_area_col]
    space_types[template][climate][building_type][space_type]["elec_equip_sch"] = row[elec_equip_sch_col]
  
    #thermostats
    space_types[template][climate][building_type][space_type]["heating_setpoint_sch"] = row[heating_setpoint_sch_col]
    space_types[template][climate][building_type][space_type]["cooling_setpoint_sch"] = row[cooling_setpoint_sch_col]
  
  end
  
  return space_types
end

# read the ConstructionSets tab and put into a Hash
def getConstructionSetsHash(workbook)
  # compound key for this sheet is [template][building_type][space_type][climate_zone_set]
  # building_type may be null to indicate all building types
  # space_type may be null to indicate all space types

  #specify worksheet
  worksheet = workbook.worksheets("ConstructionSets")
  begin_column = "A"
  end_column = "AB"
  begin_row = 5
  end_row = getNumRows(worksheet, begin_column, begin_row)
  
  #specify data range
  data = worksheet.range("#{begin_column}#{begin_row}:#{end_column}#{end_row}")['Value']

  #define the columns where the data live in the spreadsheet
  #basic information
  template_col = 0
  building_type_col = 1
  space_type_col = 2 
  climate_col = 3

  #exterior surfaces
  exterior_wall_col = 4
  exterior_floor_col = 5
  exterior_roof_col = 6
  
  #interior surfaces
  interior_wall_col = 7
  interior_floor_col = 8
  interior_ceiling_col = 9
  
  #ground_contact surfaces
  ground_contact_wall_col = 10
  ground_contact_floor_col = 11
  ground_contact_ceiling_col = 12
  
  #exterior sub surfaces
  exterior_fixed_window_col = 13
  exterior_operable_window_col = 14
  exterior_door_col = 15
  exterior_glass_door_col = 16
  exterior_overhead_door_col = 17
  exterior_skylight_col = 18
  tubular_daylight_dome_col = 19
  tubular_daylight_diffuser_col = 20
  
  #interior sub surfaces
  interior_fixed_window_col = 21
  interior_operable_window_col = 22
  interior_door_col = 23
  
  #other
  space_shading_col = 24
  building_shading_col = 25
  site_shading_col = 26
  interior_partition_col = 27
  
  #create a nested hash to store all the data
  construction_sets = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  #loop through all the ref bldg space types and put them into a nested hash
  data.each do |row|
    template = row[template_col].strip
    building_type = row[building_type_col]
    building_type = building_type.strip if not building_type.nil?
    space_type = row[space_type_col]
    space_type = space_type.strip if not space_type.nil?
    climate = row[climate_col].strip

    #exterior surfaces
    construction_sets[template][building_type][space_type][climate]["exterior_wall"] = row[exterior_wall_col]
    construction_sets[template][building_type][space_type][climate]["exterior_floor"] = row[exterior_floor_col]
    construction_sets[template][building_type][space_type][climate]["exterior_roof"] = row[exterior_roof_col]
    
    #interior surfaces
    construction_sets[template][building_type][space_type][climate]["interior_wall"] = row[interior_wall_col]
    construction_sets[template][building_type][space_type][climate]["interior_floor"] = row[interior_floor_col]
    construction_sets[template][building_type][space_type][climate]["interior_ceiling"] = row[interior_ceiling_col]
    
    #ground_contact surfaces
    construction_sets[template][building_type][space_type][climate]["ground_contact_wall"] = row[ground_contact_wall_col]
    construction_sets[template][building_type][space_type][climate]["ground_contact_floor"] = row[ground_contact_floor_col]
    construction_sets[template][building_type][space_type][climate]["ground_contact_ceiling"] = row[ground_contact_ceiling_col]    
    
    #exterior sub surfaces
    construction_sets[template][building_type][space_type][climate]["exterior_fixed_window"] = row[exterior_fixed_window_col]
    construction_sets[template][building_type][space_type][climate]["exterior_operable_window"] = row[exterior_operable_window_col]
    construction_sets[template][building_type][space_type][climate]["exterior_door"] = row[exterior_door_col]    
    construction_sets[template][building_type][space_type][climate]["exterior_glass_door"] = row[exterior_glass_door_col]
    construction_sets[template][building_type][space_type][climate]["exterior_overhead_door"] = row[exterior_overhead_door_col]
    construction_sets[template][building_type][space_type][climate]["exterior_skylight"] = row[exterior_skylight_col]    
    construction_sets[template][building_type][space_type][climate]["tubular_daylight_dome"] = row[tubular_daylight_dome_col]
    construction_sets[template][building_type][space_type][climate]["tubular_daylight_diffuser"] = row[tubular_daylight_diffuser_col]    
    
    #interior sub surfaces
    construction_sets[template][building_type][space_type][climate]["interior_fixed_window"] = row[interior_fixed_window_col]
    construction_sets[template][building_type][space_type][climate]["interior_operable_window"] = row[interior_operable_window_col]
    construction_sets[template][building_type][space_type][climate]["interior_door"] = row[interior_door_col]       
    
    #other
    construction_sets[template][building_type][space_type][climate]["space_shading"] = row[space_shading_col]
    construction_sets[template][building_type][space_type][climate]["building_shading"] = row[building_shading_col]
    construction_sets[template][building_type][space_type][climate]["site_shading"] = row[site_shading_col]    
    construction_sets[template][building_type][space_type][climate]["interior_partition"] = row[interior_partition_col]
  
  end
  
  return construction_sets
end

# read the Constructions tab and put into a Hash
def getConstructionsHash(workbook)
  # compound key for this sheet is [construction]

  #specify worksheet
  worksheet = workbook.worksheets("Constructions")
  begin_column = "A"
  end_column = "Z"
  begin_row = 5
  end_row = getNumRows(worksheet, begin_column, begin_row)
  
  #specify data range
  data = worksheet.range("#{begin_column}#{begin_row}:#{end_column}#{end_row}")['Value']

  #define the columns where the data live in the spreadsheet
  #basic information
  construction_col = 0
  construction_standard_col = 1
  climate_zone_set_col = 2
  intended_surface_type_col = 3
  standards_construction_type_col = 4
  material_col = 5

  #create a nested hash to store all the data
  constructions = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  #loop through all the templates and put them into a nested hash
  data.each do |row|
    construction = row[construction_col].strip
    
    constructions[construction]["construction_standard"] = row[construction_standard_col]
    constructions[construction]["climate_zone_set"] = row[climate_zone_set_col]
    constructions[construction]["intended_surface_type"] = row[intended_surface_type_col]
    constructions[construction]["standards_construction_type"] = row[standards_construction_type_col]
    
    materials = []
    material_col = 5
    while material = row[material_col]
      materials << material
      material_col += 1
    end
    constructions[construction]["materials"] = materials
  end
  
  return constructions
end

# read the Materials tab and put into a Hash
def getMaterialsHash(workbook)
  # compound key for this sheet is [material]

  #specify worksheet
  worksheet = workbook.worksheets("Materials")
  begin_column = "A"
  end_column = "Z"
  begin_row = 5
  end_row = getNumRows(worksheet, begin_column, begin_row)
  
  #specify data range
  data = worksheet.range("#{begin_column}#{begin_row}:#{end_column}#{end_row}")['Value']

  #define the columns where the data live in the spreadsheet
  material_col = 0
  material_type_col = 1
  thickness_col = 2 # in
  conductivity_col = 3 # Btu*in/hr*ft^2*F	R
  resistance_col = 4 # hr*ft^2*F/Btu	
  density_col = 5 # lb/ft^3	
  specific_heat_col = 6 # Btu/lbm*F
	thermal_absorptance_col = 7
	solar_absorptance_col = 8
	visible_absorptance_col = 9
	gas_type_col = 10	
  u_factor_col = 11 # Btu/hr*ft^2*F	
  solar_heat_gain_coefficient_col	= 12
  visible_transmittance_col = 13	
  optical_data_type_col = 14
	solar_transmittance_at_normal_incidence_col = 15	
  front_side_solar_reflectance_at_normal_incidence_col = 16	
  back_side_solar_relectance_at_normal_incidence_col = 17	
  visible_transmittance_at_normal_incidence_col = 18
	front_side_visible_reflectance_at_normal_incidence_col = 19	
  back_side_visible_relectance_at_normal_incidence_col = 20	
  infrared_transmittance_at_normal_incidence_col = 21	
  front_side_infrared_hemispherical_emissivity_col = 22	
  back_side_infrared_hemispherical_emissivity_col = 23	
  dirt_correction_factor_for_solar_and_visible_transmittance_col = 24	
  solar_diffusing_col = 25
  
  #create a nested hash to store all the data
  materials = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  #loop through all the ref bldg space types and put them into a nested hash
  data.each do |row|
    material = row[material_col].strip

    #exterior surfaces
    materials[material]["material_type"] = row[material_type_col]
    materials[material]["thickness"] = row[thickness_col]
    materials[material]["conductivity"] = row[conductivity_col]
    materials[material]["resistance"] = row[resistance_col]
    materials[material]["density"] = row[density_col]
    materials[material]["specific_heat"] = row[specific_heat_col]
    materials[material]["thermal_absorptance"] = row[thermal_absorptance_col]
    materials[material]["solar_absorptance"] = row[solar_absorptance_col]
    materials[material]["visible_absorptance"] = row[visible_absorptance_col]
    materials[material]["gas_type"] = row[gas_type_col]
    materials[material]["u_factor"] = row[u_factor_col]
    materials[material]["solar_heat_gain_coefficient"] = row[solar_heat_gain_coefficient_col]
    materials[material]["visible_transmittance"] = row[visible_transmittance_col]
    materials[material]["optical_data_type"] = row[optical_data_type_col]
    materials[material]["solar_transmittance_at_normal_incidence"] = row[solar_transmittance_at_normal_incidence_col]
    materials[material]["front_side_solar_reflectance_at_normal_incidence"] = row[front_side_solar_reflectance_at_normal_incidence_col]
    materials[material]["back_side_solar_relectance_at_normal_incidence"] = row[back_side_solar_relectance_at_normal_incidence_col]
    materials[material]["visible_transmittance_at_normal_incidence"] = row[visible_transmittance_at_normal_incidence_col]
    materials[material]["front_side_visible_reflectance_at_normal_incidence"] = row[front_side_visible_reflectance_at_normal_incidence_col]
    materials[material]["back_side_visible_relectance_at_normal_incidence"] = row[back_side_visible_relectance_at_normal_incidence_col]
    materials[material]["infrared_transmittance_at_normal_incidence"] = row[infrared_transmittance_at_normal_incidence_col]
    materials[material]["front_side_infrared_hemispherical_emissivity"] = row[front_side_infrared_hemispherical_emissivity_col]
    materials[material]["back_side_infrared_hemispherical_emissivity"] = row[back_side_infrared_hemispherical_emissivity_col]
    materials[material]["dirt_correction_factor_for_solar_and_visible_transmittance"] = row[dirt_correction_factor_for_solar_and_visible_transmittance_col]
    materials[material]["solar_diffusing"] = row[solar_diffusing_col]

  end
  
  return materials
end

#load in the space types
#path to the space types xl file
xlsx_path = "#{Dir.pwd}/OpenStudio_Standards.xlsx"
#enable Excel
xl = WIN32OLE::new('Excel.Application')
#open workbook
wb = xl.workbooks.open(xlsx_path)

begin

  standards = Hash.new
  standards["templates"] = getTemplatesHash(wb)
  standards["standards"] = getStandardsHash(wb)
  standards["climate_zones"] = getClimateZonesHash(wb)
  standards["climate_zone_sets"] = getClimateZoneSetsHash(wb)
  standards["space_types"] = getSpaceTypesHash(wb)
  standards["construction_sets"] = getConstructionSetsHash(wb)
  standards["constructions"] = getConstructionsHash(wb)
  standards["materials"] = getMaterialsHash(wb)
  
  # TODO: create any other views that would be useful

  #write the space types hash to a JSON file
  File.open("#{Dir.pwd}/OpenStudio_Standards.json", 'w') do |file|
    file << standards.to_json
  end
  puts "Successfully generated OpenStudio_Standards.json"

ensure

  #close workbook
  wb.Close(1)
  #quit Excel
  xl.Quit

end









  
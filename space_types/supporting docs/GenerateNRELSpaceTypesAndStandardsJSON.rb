#this script reads the space_types_and_standards.xlsx spreadsheet and creates a JSON
#file containing all the nrel ref bldg space types (on ref_bldg_space_types tab)

require 'rubygems'
require 'json'
require 'openstudio'
require 'win32ole'
require 'csv'

#setup paths
Dir.chdir("..")
$root_path = "#{Dir.pwd}/"

#load in the space types
  #path to the space types xl file
  xlsx_path = "#{$root_path}supporting docs/space_types_and_standards.xlsx"
  #enable Excel
  xl = WIN32OLE::new('Excel.Application')
  #open workbook
  wb = xl.workbooks.open(xlsx_path)
  #specify worksheet
  ws = wb.worksheets("ref_bldg_space_types")
  #specify data range
  data = ws.range('C5:BF566')['Value']
  #close workbook
  wb.Close(1)
  #quit Excel
  xl.Quit

#define the columns where the data live in the spreadsheet
  #basic information
  standard_col = 0
  climate_col = 1
  ref_bldg_primary_space_type_col = 2
  ref_bldg_secondary_space_type_col = 3
  
  #lighting
  lighting_standard_col = 11
  lighting_pri_spc_type_col = 12
  lighting_sec_spc_type_col = 13
  lighting_w_per_area_col = 22
  lighting_w_per_person_col = 23
  lighting_w_per_linear_col = 24
  lighting_sch_col = 25
  
  #ventilation
  ventilation_standard_col = 26
  ventilation_pri_spc_type_col = 27
  ventilation_sec_spc_type_col = 28  
  ventilation_per_area_col = 37
  ventilation_per_person_col = 38
  ventilation_ach_col = 39
  ventilation_sch_col = 40

  #occupancy
  occupancy_per_area_col = 42
  occupancy_sch_col = 43
  occupancy_activity_sch_col = 44

  #infiltration
  infiltration_per_area_ext_col = 46
  infiltration_sch_col = 47
  
  #gas equipment
  gas_equip_per_area_col = 49
  gas_equip_sch_col = 50
  
  #electric equipment
  elec_equip_per_area_col = 52
  elec_equip_sch_col = 53
  
 

#create a nested hash to store all the data
 $nrel_spc_types = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

#loop through all the ref bldg space types and put them into a nested hash
  data.each do |ref_bldg_space_type|
    std = ref_bldg_space_type[standard_col].strip
    clim = ref_bldg_space_type[climate_col].strip
    ref_bldg_pri_spc_type = ref_bldg_space_type[ref_bldg_primary_space_type_col].strip
    ref_bldg_sec_spc_type = ref_bldg_space_type[ref_bldg_secondary_space_type_col].strip

    #lighting
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_standard"] = ref_bldg_space_type[lighting_standard_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_pri_spc_type"] = ref_bldg_space_type[lighting_pri_spc_type_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_sec_spc_type"] = ref_bldg_space_type[lighting_sec_spc_type_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_w_per_area"] = ref_bldg_space_type[lighting_w_per_area_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_w_per_person"] = ref_bldg_space_type[lighting_w_per_person_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["lighting_sch"] = ref_bldg_space_type[lighting_sch_col]
    
    #ventilation
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_standard"] = ref_bldg_space_type[ventilation_standard_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_pri_spc_type"] = ref_bldg_space_type[ventilation_pri_spc_type_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_sec_spc_type"] = ref_bldg_space_type[ventilation_sec_spc_type_col] 
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_per_area"] = ref_bldg_space_type[ventilation_per_area_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_per_person"] = ref_bldg_space_type[ventilation_per_person_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_ach"] = ref_bldg_space_type[ventilation_ach_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["ventilation_sch"] = ref_bldg_space_type[ventilation_sch_col]
    
    #occupancy
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["occupancy_per_area"] = ref_bldg_space_type[occupancy_per_area_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["occupancy_sch"] = ref_bldg_space_type[occupancy_sch_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["occupancy_activity_sch"] = ref_bldg_space_type[occupancy_activity_sch_col]
    
    #infiltration
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["infiltration_per_area_ext"] = ref_bldg_space_type[infiltration_per_area_ext_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["infiltration_sch"] = ref_bldg_space_type[infiltration_sch_col]

    #gas equipment
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["gas_equip_per_area"] = ref_bldg_space_type[gas_equip_per_area_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["gas_equip_sch"] = ref_bldg_space_type[gas_equip_sch_col]
	
    #electric equipment
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["elec_equip_per_area"] = ref_bldg_space_type[elec_equip_per_area_col]
    $nrel_spc_types[std][clim][ref_bldg_pri_spc_type][ref_bldg_sec_spc_type]["elec_equip_sch"] = ref_bldg_space_type[elec_equip_sch_col]
	
	
        
  end

#write the space types hash to a JSON file to be used by the detailed_space_type on-demand generator
File.open('detailed_space_type/lib/nrel_ref_bldg_space_types.json', 'w') do |file|
  file << $nrel_spc_types.to_json
end
puts "Successfully generated nrel_ref_bldg_space_types.json for detailed_space_type/lib"

#write the space types hash to a JSON file to be used by the nrel_ref_bldg_space_type on-demand generator
File.open('nrel_ref_bldg_space_type/lib/nrel_ref_bldg_space_types.json', 'w') do |file|
  file << $nrel_spc_types.to_json
end
puts "Successfully generated nrel_ref_bldg_space_types.json for nrel_ref_bldg_space_type/lib"

#write the space types hash to a JSON file to be used by the generator of the NREL space types templates
File.open('nrel_ref_bldg_templates/lib/nrel_ref_bldg_space_types.json', 'w') do |file|
  file << $nrel_spc_types.to_json
end
puts "Successfully generated nrel_ref_bldg_space_types.json for nrel_ref_bldg_templates/lib"






  
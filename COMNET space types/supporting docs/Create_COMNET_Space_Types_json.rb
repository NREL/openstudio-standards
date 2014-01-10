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
  classification_col = 0
  space_type_col = 1
  
  #lighting
  lighting_w_per_area_2001_col = 2
  lighting_w_per_area_2007_col = 3
  
  #plug loads
  plug_loads_per_area_2005_acm_col = 4
  plug_loads_per_area_comnet_col = 5
  plug_loads_c_coeff_col = 6
  plug_loads_pdmisc_coeff_col = 7
  plug_loads_d_coeff_col = 8

  #occupancy
  area_per_occ_2005_acm_col = 9
  area_per_occ_comnet_col = 10
  sens_heat_gain_per_occ_col = 11
  lat_heat_gain_per_occ_col = 12
  
  #ventilation  
  ventilation_per_area_2005_acm_col = 13
  ventilation_per_area_comnet_col = 14

  #service water heating
  load_per_occ_2005_acm_col = 15
  load_per_occ_per_day_comnet_col = 16
  
  #process gas equipment
  gas_equip_per_area_col = 17
  
  #process refrigeration equipment
  ref_equip_per_area_col = 18
  
  #schedules
  
 

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






  
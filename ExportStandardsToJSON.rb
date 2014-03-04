#this script reads the OpenStudio_space_types_and_standards.xlsx spreadsheet
#and creates a JSON file containing all the information on the SpaceTypes tab

require 'rubygems'
require 'json'
require 'openstudio'
require 'win32ole'

#load in the space types
#path to the space types xl file
xlsx_path = "#{Dir.pwd}/OpenStudio_space_types_and_standards.xlsx"
#enable Excel
xl = WIN32OLE::new('Excel.Application')
#open workbook
wb = xl.workbooks.open(xlsx_path)
#specify worksheet
ws = wb.worksheets("SpaceTypes")
#specify data range
data = ws.range('C5:BF636')['Value']
#close workbook
wb.Close(1)
#quit Excel
xl.Quit

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
ventilation_sch_col = 25 #TODO David where did this col go?

#occupancy
occupancy_per_area_col = 25
occupancy_sch_col = 26
occupancy_activity_sch_col = 27

#infiltration
infiltration_per_area_ext_col = 28
infiltration_sch_col = 29

#gas equipment
gas_equip_per_area_col = 30
gas_equip_sch_col = 34

#electric equipment
elec_equip_per_area_col = 35
elec_equip_sch_col = 39
  
#create a nested hash to store all the data
space_types = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

#loop through all the ref bldg space types and put them into a nested hash
  data.each do |space_type_data_row|
    template = space_type_data_row[template_col].strip
    clim = space_type_data_row[climate_col].strip
    building_type = space_type_data_row[building_type_col].strip
    space_type = space_type_data_row[space_type_col].strip

    #RGB color
    space_types[template][clim][building_type][space_type]["rgb"] = space_type_data_row[rgb_col]
    
    #lighting
    space_types[template][clim][building_type][space_type]["lighting_standard"] = space_type_data_row[lighting_standard_col]
    space_types[template][clim][building_type][space_type]["lighting_pri_spc_type"] = space_type_data_row[lighting_pri_spc_type_col]
    space_types[template][clim][building_type][space_type]["lighting_sec_spc_type"] = space_type_data_row[lighting_sec_spc_type_col]
    space_types[template][clim][building_type][space_type]["lighting_w_per_area"] = space_type_data_row[lighting_w_per_area_col]
    space_types[template][clim][building_type][space_type]["lighting_w_per_person"] = space_type_data_row[lighting_w_per_person_col]
    space_types[template][clim][building_type][space_type]["lighting_sch"] = space_type_data_row[lighting_sch_col]
    
    #ventilation
    space_types[template][clim][building_type][space_type]["ventilation_standard"] = space_type_data_row[ventilation_standard_col]
    space_types[template][clim][building_type][space_type]["ventilation_pri_spc_type"] = space_type_data_row[ventilation_pri_spc_type_col]
    space_types[template][clim][building_type][space_type]["ventilation_sec_spc_type"] = space_type_data_row[ventilation_sec_spc_type_col] 
    space_types[template][clim][building_type][space_type]["ventilation_per_area"] = space_type_data_row[ventilation_per_area_col]
    space_types[template][clim][building_type][space_type]["ventilation_per_person"] = space_type_data_row[ventilation_per_person_col]
    space_types[template][clim][building_type][space_type]["ventilation_ach"] = space_type_data_row[ventilation_ach_col]
    #space_types[template][clim][building_type][space_type]["ventilation_sch"] = space_type_data_row[ventilation_sch_col]
    
    #occupancy
    space_types[template][clim][building_type][space_type]["occupancy_per_area"] = space_type_data_row[occupancy_per_area_col]
    space_types[template][clim][building_type][space_type]["occupancy_sch"] = space_type_data_row[occupancy_sch_col]
    space_types[template][clim][building_type][space_type]["occupancy_activity_sch"] = space_type_data_row[occupancy_activity_sch_col]
    
    #infiltration
    space_types[template][clim][building_type][space_type]["infiltration_per_area_ext"] = space_type_data_row[infiltration_per_area_ext_col]
    space_types[template][clim][building_type][space_type]["infiltration_sch"] = space_type_data_row[infiltration_sch_col]

    #gas equipment
    space_types[template][clim][building_type][space_type]["gas_equip_per_area"] = space_type_data_row[gas_equip_per_area_col]
    space_types[template][clim][building_type][space_type]["gas_equip_sch"] = space_type_data_row[gas_equip_sch_col]
	
    #electric equipment
    space_types[template][clim][building_type][space_type]["elec_equip_per_area"] = space_type_data_row[elec_equip_per_area_col]
    space_types[template][clim][building_type][space_type]["elec_equip_sch"] = space_type_data_row[elec_equip_sch_col]
	      
  end

#write the space types hash to a JSON file
File.open("#{Dir.pwd}/OpenStudio_space_types_and_standards.json", 'w') do |file|
  file << space_types.to_json
end
puts "Successfully generated OpenStudio_space_types_and_standards.json"








  
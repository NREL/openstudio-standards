#this script reads the space_types_and_standards.xlsx spreadsheet and creates a JSON
#file containing all the Interior Lighting standards values (on InteriorLighting tab)

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
  ws = wb.worksheets("InteriorLighting")
  #specify data range
  data = ws.range('B4:E684')['Value']
  #close workbook
  wb.Close(1)
  #quit Excel
  xl.Quit

#define the columns where the data live in the spreadsheet
  #basic information
  lighting_std_col = 0
  lighting_std_pri_spc_type_col = 1
  lighting_std_sec_spc_type_col = 2
  
  #lighting
  lighting_per_area_col = 3

#create a nested hash to store all the data
$lighting_std_spc_types = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

#loop through all the lightingupancy standard space types and put them into a nested hash
  data.each do |lighting_std_space_type|
    lighting_std = lighting_std_space_type[lighting_std_col].strip
    lighting_std_pri_spc_type = lighting_std_space_type[lighting_std_pri_spc_type_col].strip
    lighting_std_sec_spc_type = lighting_std_space_type[lighting_std_sec_spc_type_col].strip

    #lighting
    $lighting_std_spc_types[lighting_std][lighting_std_pri_spc_type][lighting_std_sec_spc_type]["lighting_std"] = lighting_std_space_type[lighting_std_col].strip
    $lighting_std_spc_types[lighting_std][lighting_std_pri_spc_type][lighting_std_sec_spc_type]["lighting_std_pri_spc_type"] = lighting_std_space_type[lighting_std_pri_spc_type_col].strip
    $lighting_std_spc_types[lighting_std][lighting_std_pri_spc_type][lighting_std_sec_spc_type]["lighting_std_sec_spc_type"] = lighting_std_space_type[lighting_std_sec_spc_type_col].strip
    $lighting_std_spc_types[lighting_std][lighting_std_pri_spc_type][lighting_std_sec_spc_type]["lighting_per_area"] = lighting_std_space_type[lighting_per_area_col]
    
  end

#write the space types hash to a JSON file
File.open('detailed_space_type/lib/lighting_std_space_types.json', 'w') do |file|
  file << $lighting_std_spc_types.to_json
end
puts "Successfully generated lighting_std_space_types.json for detailed_space_type/lib"









  
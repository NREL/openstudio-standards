#this script reads the space_types_and_standards.xlsx spreadsheet and creates a JSON
#file containing all the Occupancy standards values (on Occupancy tab)

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
  ws = wb.worksheets("Occupancy")
  #specify data range
  data = ws.range('B4:E280')['Value']
  #close workbook
  wb.Close(1)
  #quit Excel
  xl.Quit

#define the columns where the data live in the spreadsheet
  #basic information
  occ_std_col = 0
  occ_std_pri_spc_type_col = 1
  occ_std_sec_spc_type_col = 2
  
  #occupancy
  occ_per_area_col = 3
  occ_notes_col = 4

#create a nested hash to store all the data
$occ_std_spc_types = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

#loop through all the occupancy standard space types and put them into a nested hash
  data.each do |occ_std_space_type|
    occ_std = occ_std_space_type[occ_std_col].strip
    occ_std_pri_spc_type = occ_std_space_type[occ_std_pri_spc_type_col].strip
    occ_std_sec_spc_type = occ_std_space_type[occ_std_sec_spc_type_col].strip

    #occupancy
    $occ_std_spc_types[occ_std][occ_std_pri_spc_type][occ_std_sec_spc_type]["occ_std"] = occ_std_space_type[occ_std_col].strip
    $occ_std_spc_types[occ_std][occ_std_pri_spc_type][occ_std_sec_spc_type]["occ_std_pri_spc_type"] = occ_std_space_type[occ_std_pri_spc_type_col].strip
    $occ_std_spc_types[occ_std][occ_std_pri_spc_type][occ_std_sec_spc_type]["occ_std_sec_spc_type"] = occ_std_space_type[occ_std_sec_spc_type_col].strip 
    $occ_std_spc_types[occ_std][occ_std_pri_spc_type][occ_std_sec_spc_type]["occ_per_area"] = occ_std_space_type[occ_per_area_col]
    $occ_std_spc_types[occ_std][occ_std_pri_spc_type][occ_std_sec_spc_type]["occ_notes"] = occ_std_space_type[occ_notes_col]
    
  end

#write the space types hash to a JSON file
File.open('detailed_space_type/lib/occ_std_space_types.json', 'w') do |file|
  file << $occ_std_spc_types.to_json
end
puts "Successfully generated occ_std_space_types.json for detailed_space_type/lib"









  
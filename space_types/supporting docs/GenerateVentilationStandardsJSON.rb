#this script reads the space_types_and_standards.xlsx spreadsheet and creates a JSON
#file containing all the Ventilation standards values (on Ventilation tab)

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
  ws = wb.worksheets("Ventilation")
  #specify data range
  data = ws.range('B4:H299')['Value']
  #close workbook
  wb.Close(1)
  #quit Excel
  xl.Quit

#define the columns where the data live in the spreadsheet
  #basic information
  vent_std_col = 0
  vent_std_pri_spc_type_col = 1
  vent_std_sec_spc_type_col = 2
  
  #ventilation
  vent_per_person_col = 3
  vent_per_area_col = 4
  vent_ach_col = 5
  vent_notes_col = 6

#create a nested hash to store all the data
$vent_std_spc_types = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

#loop through all the ventilation standard space types and put them into a nested hash
  data.each do |vent_std_space_type|
    vent_std = vent_std_space_type[vent_std_col].strip
    vent_std_pri_spc_type = vent_std_space_type[vent_std_pri_spc_type_col].strip
    vent_std_sec_spc_type = vent_std_space_type[vent_std_sec_spc_type_col].strip

    #ventilation
    $vent_std_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_std"] = vent_std_space_type[vent_std_col].strip
    $vent_std_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_std_pri_spc_type"] = vent_std_space_type[vent_std_pri_spc_type_col].strip
    $vent_std_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_std_sec_spc_type"] = vent_std_space_type[vent_std_sec_spc_type_col].strip  
    $vent_std_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_per_person"] = vent_std_space_type[vent_per_person_col]
    $vent_std_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_per_area"] = vent_std_space_type[vent_per_area_col]
    $vent_std_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_ach"] = vent_std_space_type[vent_ach_col]
    $vent_std_spc_types[vent_std][vent_std_pri_spc_type][vent_std_sec_spc_type]["vent_notes"] = vent_std_space_type[vent_notes_col]
    
  end

#write the space types hash to a JSON file
File.open('detailed_space_type/lib/vent_std_space_types.json', 'w') do |file|
  file << $vent_std_spc_types.to_json
end
puts "Successfully generated vent_std_space_types.json for detailed_space_type/lib"









  
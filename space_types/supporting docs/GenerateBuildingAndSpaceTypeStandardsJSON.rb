#this script reads the space_types_and_standards.xlsx spreadsheet and creates a JSON
#file containing all the primary building types and associated secondary space types

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

#create a nested hash to store all the data
nrel_spc_types = Hash.new

#loop through all the ref bldg space types and put them into a nested hash
data.each do |ref_bldg_space_type|
  std = ref_bldg_space_type[standard_col].strip
  clim = ref_bldg_space_type[climate_col].strip
  ref_bldg_pri_spc_type = ref_bldg_space_type[ref_bldg_primary_space_type_col].strip
  ref_bldg_sec_spc_type = ref_bldg_space_type[ref_bldg_secondary_space_type_col].strip

  if nrel_spc_types[ref_bldg_pri_spc_type].nil?
    nrel_spc_types[ref_bldg_pri_spc_type] = []
  end
  
  if not nrel_spc_types[ref_bldg_pri_spc_type].include?(ref_bldg_sec_spc_type)
    nrel_spc_types[ref_bldg_pri_spc_type] << ref_bldg_sec_spc_type
  end
  
end

#write the space types hash to a JSON file to be used by OpenStudio
File.open('openstudio_export/lib/nrel_space_types.json', 'w') do |file|
file << nrel_spc_types.to_json
end
puts "Successfully generated nrel_ref_bldg_space_types.json for openstudio_export/lib"







  
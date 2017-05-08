require 'rubygems'
require 'json'
require 'roo'
require 'rest-client'

costing = {}
# Path to the xlsx file
xlsx_path = "#{File.dirname(__FILE__)}/costing.xlsx"
# Open workbook
workbook = Roo::Spreadsheet.open(xlsx_path, )


#constructions data.
sheet = CSV.parse(workbook.sheet('constructions').to_csv, 
                           {  headers:           true,
                             converters:        :numeric,
                             header_converters: :symbol })
constructions = []
costing[:constructions] = constructions
sheet.each_with_index do |row,index|
  unless row[:construction_id].nil? or row[:construction_id].to_s.strip == ""
    construction = {}
	#headers 
    [:construction_id, :surface_type, :type_code, :zone, :rsi].each { |header| construction[header] = row[header] }
    construction[:materials] = []
    construction[:materials]  << row[:material_id]
    counter = index
    loop do
      counter += 1
      nextrow = sheet[counter]
      #Break if new construction is detected or EOF.
      break if  nextrow.nil? or not nextrow[:construction_id].nil? or not nextrow[:construction_id].to_s.strip == ""
      construction[:materials] << nextrow[:material_id]
    end 
    constructions << construction
  end
end
#Materials
string = 
sheet = CSV.parse(workbook.sheet('materials').to_csv,
							{  headers:           true,
                             converters:        :numeric,
                             header_converters: :symbol })
materials = []
costing[:materials] = materials
sheet.each_with_index do |row|
  unless row[:material_id].nil? or row[:material_id].to_s.strip == ""
    material= {}
    headers = [:material_id,
               :source,
               :id,
               :component,
               :unit,
               :material_mult, 
               :labour_mult,
               :material_cost_per_sqft,
               :labour_cost_per_sqft,
               :component_comment, 
               :material_comment , 
               :labour_comment]
    headers.each do |header|
      material[header] = row[header]
    end
    materials << material
  end
end
File.open("costing.json","w") do |f|
  f.write(JSON.pretty_generate(costing))
end

def get_rsmeans_imp_opn_unit_costs( unit_id, location_id='ca-on-ottawa', release_id='2016-an' )
  auth = JSON.parse(File.read("#{Dir.home}/rs_means_auth.json"))
  path = "https://dataapi-sb.gordian.com/v1/costdata/unit/catalogs/cnc-mf-imp-opn-#{release_id}-#{location_id}/costlines/#{unit_id}"
  return RestClient.get( path ,auth) 
end



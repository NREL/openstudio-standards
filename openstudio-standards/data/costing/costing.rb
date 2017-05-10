require 'rubygems'
require 'json'
require 'roo'
require 'rest-client'
require 'openssl'
# Method to obtain the unit costs from the New Construtions library via the RS-means API.
# You will need to place your secret hash into a file named rs_means_auth in your home folder as ruby sees it.
# Your hash will need to be updated as your swagger session expires (within an hour) otherwise you will get a
# 401 not authorized error. 
def get_rsmeans_costs( rs_type, rs_catalog_id, rs_id )
  auth = File.read("#{Dir.home}/rs_means_auth").strip
  auth = { :Authorization => "bearer #{auth}"}
  path = "https://dataapi-sb.gordian.com/v1/costdata/#{rs_type.downcase.strip}/catalogs/#{rs_catalog_id.strip}/costlines/#{rs_id.strip}"
  return JSON.parse(RestClient.get( path ,auth).body) 
end

#Hash to contain public costing information.
costing = {}

# Path to the xlsx file
xlsx_path = "#{File.dirname(__FILE__)}/btap-costing-envelope.xlsx"

# Open workbook
workbook = Roo::Spreadsheet.open(xlsx_path)

#Add array to keep btap contructions. 
constructions = []

#Add above array to costing hash. 
costing[:constructions] = constructions

#Load Constructions data sheet from workbook and convert to a csv object. 
sheet = CSV.parse(workbook.sheet('constructions').to_csv, 
                  {  headers:           true,
                     header_converters: :symbol })

#Iterate through each row in the constructions sheet.  
sheet.each_with_index do |row,index|
  #Skip if row is empty or nil. 
  unless row[:construction_id].nil? or row[:construction_id].to_s.strip == ""
    
    #Create hash to contain contruction information. 
    construction = {}
    
    #Create array of headers that are used in sheet.  
    headers = [
      :construction_id, 
      :surface_type, 
      :type_code, 
      :zone, 
      :rsi,
      :description,
      :material_id,
    ]

    #Iterate through each header and assign to contruction hash
    headers.each { |header| construction[header] = row[header] }
    #Create an array of materials to contain material ids
    construction[:materials] = []
    construction[:materials]  << row[:material_id]
    #This loads in nested material id until a new construction, or EOF
    #is detected. 
    counter = index
    loop do
      counter += 1
      nextrow = sheet[counter]
      #Break if new construction is detected or EOF.
      break if  nextrow.nil? or not nextrow[:construction_id].nil? or not nextrow[:construction_id].to_s.strip == ""
      #Push material into materials array. 
      construction[:materials] << nextrow[:material_id]
    end 
    #push construction into contstructions array
    constructions << construction
  end
end

#Create btap materials array
materials = []

#Add materials to costing hash. 
costing[:materials] = materials

#Load materials sheet into and convert to csv object. 
sheet = CSV.parse(workbook.sheet('materials').to_csv,
                  {  headers:           true,
                     header_converters: :symbol })
#Iterate though materials sheet. 
sheet.each_with_index do |row|
  #Skip if empty or nil. 
  unless row[:material_id].nil? or row[:material_id].to_s.strip == ""
    #create hash to store material info
    material= {}
    #Array of headers present in materials sheet. 
    headers = [:material_id,
               :source,
               :type,
               :catalog_id,
               :id,
               :component,
               :unit,
               :material_mult, 
               :labour_mult,
               :comment] 
    # for each item store data into materials array. 
    headers.each do |header|
      #store material info into hash
      material[header] = row[header]
    end
    #store material into array
    materials << material
  end
end

#Create secret envelope costing data. 
# Find all unique rs means assemblies and units
#Create array to store rsmeans data. 
rs_means_info = Array.new

# Find all unique rs means assemblies and units
rs_means_unique_ids = materials.map {|material| {:type => material[:type],:catalog_id => material[:catalog_id],:id => material[:id]} if material[:source]='rs-means'}.compact.uniq.sort_by { |k| k[:id] }
#Iterate through all rs_means items. 
rs_means_unique_ids.each do |material|
  puts "processing #{material[:id]}"
  #perform api call to get costing hash from RS-means and  store into array. 
  rs_means_info <<  get_rsmeans_costs( material[:type], material[:catalog_id], material[:id] )
end

#Write public cost information to a json file. This will be used by the standards and measures. To create
#create the openstudio construction names and costing objects. 
File.open("btap-costing-envelope-public.json","w") do |f|
  f.write(JSON.pretty_generate(costing))
end

#Write secret cost information to a json file. We should think of 
# encrypting this file using the openssl gem to make the rs-means data
# super safe.
File.open("btap-costing-envelope-private.json","w") do |f|
  f.write(JSON.pretty_generate(rs_means_info))
end


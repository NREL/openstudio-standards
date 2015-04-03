require 'openstudio'

require 'csv'

require_relative 'construction_writer_libs'

template_path = OpenStudio::Path.new(ARGV[0])

### DO THE WORK ###

vt = OpenStudio::OSVersion::VersionTranslator.new
model = vt.loadModel(template_path).get

# materials
spreadsheet_materials = []
model.getMaterials.each do |material|
  spreadsheet_material = SpreadSheetMaterial.new(material)
  spreadsheet_materials << spreadsheet_material
end

CSV.open('./materials.csv', 'w') do |csv|
  spreadsheet_materials.each do |spreadsheet_material|
    csv << spreadsheet_material.to_row
  end
end

# constructions
spreadsheet_constructions = []
model.getConstructions.each do |construction|
  spreadsheet_construction = SpreadSheetConstruction.new(construction)
  spreadsheet_constructions << spreadsheet_construction
end
CSV.open('./constructions.csv', 'w') do |csv|
  spreadsheet_constructions.each do |spreadsheet_construction|
    csv << spreadsheet_construction.to_row
  end
end

# construction sets
spreadsheet_construction_sets = []
model.getDefaultConstructionSets.each do |construction_set|
  spreadsheet_construction_set = SpreadSheetConstructionSet.new(construction_set)
  spreadsheet_construction_sets << spreadsheet_construction_set
end
CSV.open('./construction_sets.csv', 'w') do |csv|
  spreadsheet_construction_sets.each do |spreadsheet_construction_set|
    csv << spreadsheet_construction_set.to_row
  end
end

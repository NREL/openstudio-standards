cbecc_checkout = 'E:/cbecc/'

require 'rubygems'
require 'rubyXL'
require 'csv'
require_relative 'construction_writer_libs'

spreadsheet_materials = []

# read in regular materials
Material = Struct.new(:material_category, :name, :thickness, :resistance, :conductivity, :density, :specific_heat, :roughness)
materials_csv = cbecc_checkout + 'RulesetDev/Rulesets/CEC 2013 Nonres/Rules/Tables/MaterialData.csv'
standard = 'CEC Title24-2013'
File.open(materials_csv, 'r') do |file|
  # header
  6.times {file.readline}
  
  # data 
  while !file.eof?
    line = file.readline
    parts = line.split(',')
    material = Material.new(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7])
    
    next if material.name.nil? || material.name.empty?
    
    material.roughness = nil if material.roughness == "NA"
    
    material.thickness = material.thickness.to_f
    material.resistance = material.resistance.to_f
    material.conductivity = 12*material.conductivity.to_f # (BTU/h-ft-F) -> (Btu*in/hr*ft^2*F)
    material.density = material.density.to_f
    material.specific_heat = material.specific_heat.to_f

    # sanity check
    calculated_resistance = material.thickness/material.conductivity
    diff = (material.resistance - calculated_resistance).abs
    if (diff > 0.05*material.resistance)
      puts "Resistance values do not match for material '#{material.name}', calculated is #{calculated_resistance}, entered is #{material.resistance}, diff is #{diff}"
    end
    
    spreadsheet_material = SpreadSheetMaterial.new
    spreadsheet_material.material_standard = standard
    spreadsheet_material.material_type = 'StandardOpaqueMaterial'
    spreadsheet_material.material_category = material.material_category
    spreadsheet_material.name = material.name
    spreadsheet_material.thickness = material.thickness
    spreadsheet_material.resistance = material.resistance
    spreadsheet_material.conductivity = material.conductivity
    spreadsheet_material.density = material.density
    spreadsheet_material.specific_heat = material.specific_heat
    spreadsheet_material.roughness = material.roughness
    spreadsheet_materials << spreadsheet_material
  end
end

# DLM: do we need to read in framing materials?  I don't see these being used in any example files.

spreadsheet_constructions = []

# read in constructions
Construction = Struct.new(:name, :compatible_surf_type, :spec_mthd, :mat_ref,
                          :ext_roughness, :ext_sol_abs, :ext_thrml_abs, :ext_vis_abs, :int_sol_abs, :int_thrml_abs, :int_vis_abs,
                          :crrc_initial_refl, :crrc_aged_refl, :crrc_initial_emittance, :crrc_aged_emittance, :crrc_initial_sri, :crrc_aged_sri)
construction_lib = cbecc_checkout + 'RulesetDev/Rulesets/CEC 2013 Nonres/Rules/Library/Library_BaseConstructions.rule'
standard = 'CEC Title24-2013'
construction = nil
materials = nil
File.open(construction_lib, 'r').readlines.each do |line|

  #ConsAssm   "SteepResWoodFramingAndOtherRoofU034"
  #   CompatibleSurfType = "Roof"
  #   ExtRoughness = "MediumRough"
  #   ExtSolAbs = 0.37
  #   ExtThrmlAbs = 0.85
  #   ExtVisAbs = 0.85
  #   IntSolAbs = 0.7
  #   IntThrmlAbs = 0.9
  #   IntVisAbs = 0.8
  #   CRRCInitialRefl = 0.63
  #   CRRCAgedRefl = 0.63
  #   CRRCInitialEmittance = 0.85
  #   CRRCAgedEmittance = 0.85
  #   CRRCInitialSRI = 75
  #   CRRCAgedSRI = 75
  #   SpecMthd = "Layers"
  #   MatRef = ( "Metal Standing Seam - 1/16 in.",
  #              "Compliance Insulation R28.63" )
  #  ..

  if data = /ConsAssm\s+"(.*)"/.match(line)
    construction = Construction.new
    construction.name = data[1]
  elsif data = /CompatibleSurfType = "(.*)"/.match(line)
    construction.compatible_surf_type = data[1]
  elsif data = /SpecMthd = "(.*)"/.match(line)
    construction.spec_mthd = data[1]
    if construction.spec_mthd == "Layers"
      materials = []    
    end
  elsif materials && data = /MatRef = "(.*)"/.match(line)
    materials << data[1]     
  elsif materials && data = /"(.*)"/.match(line)
    materials << data[1]          
  elsif /^  \.\./.match(line)
    if construction

      puts "construction = '#{construction}'"

      # DLM: may need more mapping
      intended_surface_type = construction.compatible_surf_type
      if intended_surface_type == "Roof"
        intended_surface_type = "ExteriorRoof" 
      end
      
      # DLM: the CEC constructions specify exterior and interior absorbtances as well as crrc parameters
      # we put absorbtances on material layers and don't have a place for crrc parameters 
      # ignore for now
      
      if construction.spec_mthd == "Layers" # DLM: todo handle FFactor and CFactor constructions
        spreadsheet_construction = SpreadSheetConstruction.new
        spreadsheet_construction.construction_standard = standard
        spreadsheet_construction.climate_zone_set = nil # DLM: how to get this?
        spreadsheet_construction.name = construction.name
        spreadsheet_construction.intended_surface_type = intended_surface_type
        spreadsheet_construction.standards_construction_type = nil # DLM: how to get this? name matching?
        if materials
          spreadsheet_construction.material_1 = materials.size >= 1 ? materials[0] : nil
          spreadsheet_construction.material_2 = materials.size >= 2 ? materials[1] : nil
          spreadsheet_construction.material_3 = materials.size >= 3 ? materials[2] : nil
          spreadsheet_construction.material_4 = materials.size >= 4 ? materials[3] : nil
          spreadsheet_construction.material_5 = materials.size >= 5 ? materials[4] : nil
          spreadsheet_construction.material_6 = materials.size >= 6 ? materials[5] : nil
        end
        spreadsheet_constructions << spreadsheet_construction
      end
    end
    
    construction = nil
    materials = nil 
  end
end

# write materials
CSV.open('./Materials.csv', 'w') do |csv|
  spreadsheet_materials.each do |spreadsheet_material|
    csv << spreadsheet_material.to_row
  end
end

# write constructions
CSV.open('./Constructions.csv', 'w') do |csv|
  spreadsheet_constructions.each do |spreadsheet_construction|
    csv << spreadsheet_construction.to_row
  end
end
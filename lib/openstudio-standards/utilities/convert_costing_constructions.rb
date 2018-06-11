=begin
require_relative '../../../test/helpers/minitest_helper'
require_relative '../../../test/helpers/create_doe_prototype_helper'

costing_array = ["template",
                 "building_type",
                 "space_type",
                 "min_stories",
                 "max_stories",
                 "spandrel",
                 "ExteriorWall",
                 "ExteriorFloor",
                 "ExteriorRoof",
                 "Interior Walls",
                 "Interior Floors",
                 "Interior Ceilings",
                 "GroundContactWall",
                 "GroundContactFloor",
                 "GroundContactRoof",
                 "ExteriorFixedWindow",
                 "ExteriorOperableWindow",
                 "ExteriorDoor",
                 "ExteriorGlassDoor",
                 "ExteriorOverheadDoor",
                 "Exterior Skylight Standards Construction Type",
                 "ExteriorTubularDaylightDome",
                 "ExteriorTubularDaylightDiffuser",
                 "Interior Fixed Windows",
                 "Interior Operable Windows",
                 "Interior Doors",
                 "Space Shading",
                 "Building Shading",
                 "Site Shading",
                 "Interior Partitions",
                 "Notes"
]


set_array = ["template",
             "building_type",
             "space_type",
             "min_stories",
             "max_stories",
             "spandrel",
             "exterior_wall_standards_construction_type",
             "exterior_floor_standards_construction_type",
             "exterior_roof_standards_construction_type",
             "interior_walls",
             "interior_floors",
             "interior_ceilings",
             "ground_contact_wall_standards_construction_type",
             "ground_contact_floor_standards_construction_type",
             "ground_contact_ceiling_standards_construction_type",
             "exterior_fixed_window_standards_construction_type",
             "exterior_operable_window_standards_construction_type",
             "exterior_door_standards_construction_type",
             "exterior_glass_doors",
             "exterior_overhead_door_standards_construction_type",
             "exterior_skylight_standards_construction_type",
             "tubular_daylight_domes",
             "tubular_daylight_diffusers",
             "interior_fixed_windows",
             "interior_operable_windows",
             "interior_doors",
             "space_shading",
             "building_shading",
             "site_shading",
             "interior_partitions",
             "notes"]



extra = ["exterior_wall_building_category",
         "exterior_floor_building_category",
         "exterior_roof_building_category",
         "ground_contact_wall_building_category",
         "ground_contact_floor_building_category",
         "ground_contact_ceiling_building_category",
         "exterior_fixed_window_building_category",
         "exterior_operable_window_building_category",
         "exterior_door_building_category",
         "exterior_overhead_door_building_category",
         "exterior_skylight_building_category"]

unique_constructions = []
costing = BTAPCosting.instance
costing.load_data_from_excel()
sets = []
costing.costing_database['raw']['construction_sets'].each do |set|



  new_set = {}
  (0..(costing_array.size-1)).each do |index|
    new_set[set_array[index]] = set[costing_array[index]]
    unique_constructions << set[costing_array[index]] unless ( unique_constructions.include?(set[costing_array[index]]) or set[costing_array[index]].nil?)
  end
  extra.each do |extra|
    new_set[extra] = "Nonresidential"
  end
  sets << new_set

end
File.write("/home/osdev/space_type_standard_construction_sets.json",JSON.pretty_generate(sets))
File.write("/home/osdev/standard_constructions.json",JSON.pretty_generate(unique_constructions.sort))=end

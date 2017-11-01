#tyson's code attempt 1 below

#load the


require_relative '../../../test/helpers/minitest_helper'
require 'json'

array = []
geometry_folder_path = "#{File.dirname(__FILE__)}/../../../data/geometry/"
geometry_json_path = "#{File.dirname(__FILE__)}/../../../data/geometry/archetypes/geometry.json"

geometry_json =JSON.parse('
    {
            "FullServiceRestaurant": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "HighriseApartment": {
                "above_ground_floors": 10,
                "below_ground_floors": 0
            },
            "LargeHotel": {
                "above_ground_floors": 6,
                "below_ground_floors": 1
            },
            "LargeOffice": {
                "above_ground_floors": 12,
                "below_ground_floors": 1
            },
            "MediumOffice": {
                "above_ground_floors": 3,
                "below_ground_floors": 0
            },
            "MidriseApartment": {
                "above_ground_floors": 4,
                "below_ground_floors": 0
            },
            "Outpatient": {
                "above_ground_floors": 3,
                "below_ground_floors": 0
            },
            "PrimarySchool": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "QuickServiceRestaurant": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "RetailStandalone": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "RetailStripmall": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "SecondarySchool": {
                "above_ground_floors": 2,
                "below_ground_floors": 0
            },
            "SmallOffice": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "Warehouse": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "Hospital": {
                "above_ground_floors": 5,
                "below_ground_floors": 1
            },
            "SmallHotel": {
                "above_ground_floors": 4,
                "below_ground_floors": 0
            }
}
'
)


# this reads in the json file.
data_hash = JSON.parse(File.read("#{File.dirname(__FILE__)}/../refactor/prototypes/common/data/prototype_database.json"))

data_hash.each do |info|




  # Use this to load the osm file into a model object.
  full_path = geometry_folder_path + info["geometry"]
  model=BTAP::FileIO::load_osm(full_path)
=begin

  # This will add the OS:Building information to the model.
  total_floors =  geometry_json[info["building_type"]]["above_ground_floors"].to_i + geometry_json[info["building_type"]]["below_ground_floors"].to_i
  above_ground_floors =  geometry_json[info["building_type"]]["below_ground_floors"].to_i
  model.building().get.setStandardsBuildingType(info["building_type"])
  model.building().get.setStandardsNumberOfStories(total_floors)
  model.building().get.setStandardsNumberOfAboveGroundStories(above_ground_floors)

  model.getThermalZones.sort.each {|zone| zone.remove}
  #skips if there are no multipliers.
  if not info["space_multiplier_map"].nil?
    info["space_multiplier_map"].sort.each do |space_name, multiplier|
      space_name = space_name.to_s
      multiplier = multiplier.to_i
      # after that is done you should have a model object.
      thermal_zone = OpenStudio::Model::ThermalZone.new(model)
      # Create a more informative space name.
      thermal_zone.setName("TZ-#{space_name}")
      # Add zone mulitplier if required.
      thermal_zone.setMultiplier(multiplier)

      # get the space in the model.
      puts info["class_name"]
      puts space_name
      space = model.getSpaceByName(space_name).get
      #associates the thermal to the space.
      space.setThermalZone(thermal_zone)
    end
  end
  if not info["building_story_map"].nil?
    model.getBuildingStorys.sort.each {|story| story.remove}
    info["building_story_map"].each do |building_story_name, space_names|
      building_story = OpenStudio::Model::BuildingStory.new(model)
      building_story.setName(building_story_name)
      space_names.each do |space_name|
        space = model.getSpaceByName(space_name)
        next if space.empty?
        space = space.get
        space.setBuildingStory(building_story)
      end
    end
  end
=end

  BTAP::FileIO::save_osm(model, full_path)
end


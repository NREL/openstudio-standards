# tyson's code attempt 1 below

# load the

require_relative '../../../test/helpers/minitest_helper'
require 'json'

array = []
geometry_folder_path = "#{File.dirname(__FILE__)}/../../../data/geometry/"
geometry_json_path = "#{File.dirname(__FILE__)}/../../../data/geometry/archetypes/geometry.json"

geometry_json = JSON.parse('
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
			"LargeOfficeDetailed": {
                "above_ground_floors": 12,
                "below_ground_floors": 1
            },
            "MediumOfficeDetailed": {
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
            },
            "SmallDataCenterLowITE": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "SmallDataCenterHighITE": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "LargeDataCenterLowITE": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            },
            "LargeDataCenterHighITE": {
                "above_ground_floors": 1,
                "below_ground_floors": 0
            }
}
')

# this reads in the json file.
data_hash = JSON.parse(File.read("#{File.dirname(__FILE__)}/../refactor/prototypes/common/data/prototype_database.json"))

data_hash.each do |info|
  info.delete('geometry')
  #   if info['template'] == 'NECB2011'
  #     puts "fudsfadfas"
  #     info.delete("system_to_space_map")
  #
  #     puts info["system_to_space_map"]
  #   end
  #   info.delete("space_type_map")

  #   File.delete("#{geometry_folder_path}/#{info["class_name"]}.hvac_map.json") if File.exist?("#{geometry_folder_path}/#{info["class_name"]}.hvac_map.json")
  #   unless info["system_to_space_map"].nil?
  #     File.write("#{geometry_folder_path}/#{info["class_name"]}.hvac_map.json", JSON.pretty_generate(info["system_to_space_map"]))
  #     info["system_to_space_map"] = "#{info["class_name"]}.hvac_map.json"
  #   end
end
data_hash = File.write("#{File.dirname(__FILE__)}/../refactor/prototypes/common/data/prototype_database.json", JSON.pretty_generate(data_hash))

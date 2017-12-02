require_relative '../helpers/minitest_helper'
require 'json'


#Create a array of hashes to store building data...just in case..may not need it.
building_types = [
    {'name' => "FullServiceRestaurant"},
    {'name' => "Hospital"},
    {'name' => "HighriseApartment"},
    {'name' => "LargeHotel"},
    {'name' => "LargeOffice"},
    {'name' => "MediumOffice"},
    {'name' => "MidriseApartment"},
    {'name' => "Outpatient"},
    {'name' => "PrimarySchool"},
    {'name' => "QuickServiceRestaurant"},
    {'name' => "RetailStandalone"},
    {'name' => "SecondarySchool"},
    {'name' => "SmallHotel"},
    {'name' => "SmallOffice"},
    {'name' => "RetailStripmall"},
    {'name' => "Warehouse"}
]


#Array to store output of each osm file.
results = []
osm_files = Dir.glob("#{File.dirname(__FILE__)}/../../data/**/*.osm")

osm_files.each do |osm_file|
  #Load the osm file into a model object.
  model = BTAP::FileIO::load_osm(osm_file)

  #get the building sub object from the model.
  os_building = model.building().get


  #create hash data from the building object.
  results << {
      'filename' => osm_file,
      'name' => os_building.name(),
      'standardsBuildingType' => os_building.standardsBuildingType(),
      'standardsNumberOfStories' => os_building.standardsNumberOfStories(),
      'standardsNumberOfAboveGroundStories' => os_building.standardsNumberOfAboveGroundStories(),
      'nominalFloortoCeilingHeight' => os_building.nominalFloortoCeilingHeight()
  }


end
#print the results to screen in a pretty way.
pretty_output =  JSON.pretty_generate(results)
File.write("#{File.dirname(__FILE__)}/../../data/geometry/output.json", pretty_output)


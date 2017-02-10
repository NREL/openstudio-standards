require_relative '../helpers/minitest_helper'

class TestFindSpaceTypeStandardsData < Minitest::Test

  def test_find_space_type_standards_data_valid_standards_7

    # for now this just runs for single building type and climate zone, but could sweep across larger selection
    building_types = ['RetailStandalone']
    climate_zones = ['7'] # short version of climate zone is what is used in GUI

    # make an empty model
    model = OpenStudio::Model::Model.new

    # set climate zone and building type
    model.getBuilding.setStandardsBuildingType(building_types.first)
    model.getClimateZones.setClimateZone("ASHRAE",climate_zones.first)

    # get climate zone
    data = model.get_building_climate_zone_and_building_type(remap_office = true)
    building_type = data[:building_type]
    climate_zone = data[:climate_zone]

    # check that it returns the correct value
    assert(building_type = "RetailStandalone")
    assert(climate_zone = "7A")

  end

end

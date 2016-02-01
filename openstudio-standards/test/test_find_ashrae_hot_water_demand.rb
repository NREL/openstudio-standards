require_relative 'minitest_helper'

class TestFindSpaceTypeStandardsData < Minitest::Test

  def test_find_ashrae_hot_water_demand

    # for now this just runs for single building type and climate zone, but could sweep across larger selection
    standard_building_type = 'LargeHotel'

    # make an empty model
    model = OpenStudio::Model::Model.new

    # set building type
    model.getBuilding.setStandardsBuildingType(standard_building_type)

    # lookup hot water recommendations
    hot_water_recommendations = model.find_ashrae_hot_water_demand
    #puts hot_water_recommendations
    avg_hot_water = nil
    hot_water_recommendations.each do |hash|
      next if not hash[:block] == 60.0
      avg_hot_water = hash[:avg_day_unit]
    end

    # check recommendation
    assert(avg_hot_water == 14.0)

  end

end

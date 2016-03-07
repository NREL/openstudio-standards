require_relative 'minitest_helper'

class TestFindSpaceTypeStandardsData < Minitest::Test

  def test_find_ashrae_hot_water_demand

    # make an empty model
    model = OpenStudio::Model::Model.new

    # set building type
    model.getBuilding.setStandardsBuildingType("LargeHotel")

    # lookup hot water recommendations
    hot_water_recommendations = model.find_ashrae_hot_water_demand
    #puts hot_water_recommendations
    avg_hot_water_hotel = nil
    hot_water_recommendations.each do |hash|
      next if not hash[:block] == 60.0
      avg_hot_water_hotel = hash[:avg_day_unit]
    end

    # set building type
    model.getBuilding.setStandardsBuildingType("Office")

    # lookup hot water recommendations
    hot_water_recommendations = model.find_ashrae_hot_water_demand
    puts hot_water_recommendations
    avg_hot_water_office = nil
    hot_water_recommendations.each do |hash|
      avg_hot_water_office = hash[:avg_day_unit]
    end

    # check recommendation
    assert(avg_hot_water_hotel == 14.0)
    assert(avg_hot_water_office == 1.0)

  end

end

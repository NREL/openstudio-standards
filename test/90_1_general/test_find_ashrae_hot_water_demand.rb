require_relative '../helpers/minitest_helper'

class TestFindASHRAEHotWaterDemand < Minitest::Test

  def test_find_ashrae_hot_water_demand

    # make an empty model
    model = OpenStudio::Model::Model.new

    # set building type
    model.getBuilding.setStandardsBuildingType("LargeHotel")

    template = '90.1-2010'
    standard = StandardsModel.get_standard_model(template)
    
    # lookup hot water recommendations
    hot_water_recommendations = standard.model_find_ashrae_hot_water_demand(model) 
    #puts hot_water_recommendations
    avg_hot_water_hotel = nil
    hot_water_recommendations.each do |hash|
      next if not hash[:block] == 60.0
      avg_hot_water_hotel = hash[:avg_day_unit]
    end

    # set building type
    model.getBuilding.setStandardsBuildingType("Office")

    # lookup hot water recommendations
    hot_water_recommendations = standard.model_find_ashrae_hot_water_demand(model) 
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

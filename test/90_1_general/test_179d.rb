require_relative '../helpers/minitest_helper'

class ACM179dASHRAE9012007Test < Minitest::Test

  def setup
    @template = '179D 90.1-2007'
    @standard = Standard.build(@template)

    model = OpenStudio::Model::exampleModel
    model.getSpaceTypes.map(&:remove)

    spaces = model.getSpaces.sort_by(&:nameString)

    wh_bulk = OpenStudio::Model::SpaceType.new(model)
    wh_bulk.setStandardsBuildingType('Warehouse')
    wh_bulk.setStandardsSpaceType('Bulk')
    spaces[0].setSpaceType(wh_bulk)
    spaces[1].setSpaceType(wh_bulk)

    wh_office = OpenStudio::Model::SpaceType.new(model)
    wh_office.setStandardsBuildingType('Warehouse')
    wh_office.setStandardsSpaceType('Office')
    spaces[2].setSpaceType(wh_bulk)

    retail_pt_sale = OpenStudio::Model::SpaceType.new(model)
    retail_pt_sale.setStandardsBuildingType('Retail')
    retail_pt_sale.setStandardsSpaceType('Point_of_Sale')
    spaces[3].setSpaceType(retail_pt_sale)
    @model = model
  end

  def test_model_get_primary_building_type
    assert_equal('Warehouse', @standard.model_get_primary_building_type(@model))

    # Avoid the memoization by calling the static method instead
    # Space Type area method is prefered
    @model.getBuilding.setStandardsBuildingType("Office")
    assert_equal('Warehouse', ACM179dASHRAE9012007.__model_get_primary_building_type(@model))

    # When Space Type area not found, use building
    @model.getSpaceTypes.each(&:resetStandardsBuildingType)
    assert_equal('Office', ACM179dASHRAE9012007.__model_get_primary_building_type(@model))

    # When neither: it throws
    @model.getBuilding.resetStandardsBuildingType
    assert_raises(RuntimeError, 'No Primary Building Type found') { ACM179dASHRAE9012007.__model_get_primary_building_type(@model) }
  end

end

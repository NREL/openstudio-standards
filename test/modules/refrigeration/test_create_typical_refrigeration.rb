require_relative '../../helpers/minitest_helper'

class TestRefrigerationCreateTypicalRefrigeration < Minitest::Test
  def setup
    @geo = OpenstudioStandards::Geometry
    @refrig = OpenstudioStandards::Refrigeration
  end

  def test_typical_refrigeration_equipment_list
    model = OpenStudio::Model::Model.new

    args = {}
    args['total_bldg_floor_area'] = 50000.0
    args['bldg_type_a'] = 'SuperMarket'
    result = @geo.create_bar_from_building_type_ratios(model, args)

    # equipment list
    result = @refrig.typical_refrigeration_equipment_list(model)
  end

  def test_create_typical_refrigeration_supermarket
    model = OpenStudio::Model::Model.new

    args = {}
    args['total_bldg_floor_area'] = 50000.0
    args['bldg_type_a'] = 'SuperMarket'
    result = @geo.create_bar_from_building_type_ratios(model, args)

    # default refrigeration system
    result = @refrig.create_typical_refrigeration(model)
    assert(result)
  end

  def test_create_typical_refrigeration_primary_school
    model = OpenStudio::Model::Model.new

    args = {}
    args['total_bldg_floor_area'] = 50000.0
    args['bldg_type_a'] = 'PrimarySchool'
    result = @geo.create_bar_from_building_type_ratios(model, args)

    # default refrigeration system
    result = @refrig.create_typical_refrigeration(model)
    assert(result)
  end
end

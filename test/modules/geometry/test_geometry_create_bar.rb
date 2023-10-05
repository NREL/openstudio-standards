require_relative '../../helpers/minitest_helper'

class TestGeometryCreateBar < Minitest::Test
  def setup
    @geo = OpenstudioStandards::Geometry
  end

  def test_create_bar_from_space_type_ratios
    model = OpenStudio::Model::Model.new

    args = {
      :space_type_hash_string => 'MediumOffice | Conference => 0.2, PrimarySchool | Corridor => 0.125, PrimarySchool | Classroom => 0.175, Warehouse | Office => 0.5'
    }
    result = @geo.create_bar_from_space_type_ratios(model, args)
    assert(result)
    assert(model.getSpaceTypes.size == 4)
  end

  def test_create_bar_from_building_type_ratios
    model = OpenStudio::Model::Model.new

    args = {
      :bldg_type_a => 'LargeOffice',
      :bldg_type_b => 'Warehouse',
      :bldg_type_c => 'EUn',
      :bldg_type_d => 'RtL',
      :bldg_subtype_a => 'largeoffice_datacenter',
      :bldg_subtype_b => 'warehouse_bulk80',
      :bldg_type_a_fract_bldg_area => 0.3,
      :bldg_type_b_fract_bldg_area => 0.3,
      :bldg_type_c_fract_bldg_area => 0.3,
      :bldg_type_d_fract_bldg_area => 0.1
    }
    result = @geo.create_bar_from_building_type_ratios(model, args)
    assert(result)
  end
end
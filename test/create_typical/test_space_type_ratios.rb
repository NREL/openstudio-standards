require_relative '../helpers/minitest_helper'

class TestCreateTypicalSpaceTypeRatios < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
  end

  def test_get_space_types_from_building_type
    building_type = 'PrimarySchool'
    template = '90.1-2013'
    result = @create.get_space_types_from_building_type(building_type, template)

    building_type = 'MediumOffice'
    template = '90.1-2013'
    result = @create.get_space_types_from_building_type(building_type, template, whole_building = true)

    building_type = 'Casa Bonita'
    template = '90.1-2013'
    result = @create.get_space_types_from_building_type(building_type, template)
    assert(result == false)
  end
end
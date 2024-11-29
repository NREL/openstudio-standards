require_relative '../../helpers/minitest_helper'

class TestCreateTypicalSpaceTypeRatios < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
  end

  def test_get_space_types_from_building_type
    building_type = 'PrimarySchool'
    result = @create.get_space_types_from_building_type(building_type, template: '90.1-2013')
    assert(result)

    building_type = 'MediumOffice'
    result = @create.get_space_types_from_building_type(building_type, template: '90.1-2013', whole_building: true)
    assert(result)

    building_type = 'LargeOffice'
    result = @create.get_space_types_from_building_type(building_type, building_subtype: 'largeoffice_datacenter', template: '90.1-2013', whole_building: true)
    assert(result)

    building_type = 'Warehouse'
    result = @create.get_space_types_from_building_type(building_type, building_subtype: 'warehouse_bulk20', template: '90.1-2013', whole_building: true)
    assert(result)

    building_type = 'Casa Bonita'
    result = @create.get_space_types_from_building_type(building_type, template: '90.1-2013')
    assert(result == false)
  end
end
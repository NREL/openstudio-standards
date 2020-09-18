require_relative '../../../helpers/minitest_helper'
require_relative '../../../helpers/create_doe_prototype_helper'

# This class will perform tests that are HDD driven, A Test model will be created
# that will have all of OpenStudios surface types with different contructions. All
# components are created from scratch to ensure model are up to date and we will
# not run into version issues with the test.
## to specifically test aspects of the NECB2011 code that are HDD dependant.
class NECB_VintageMap_Test < Minitest::Test


  def test_necb2011()
      vintage_mapper('NECB2011')
  end
  def test_necb2015()
    vintage_mapper('NECB2015')
  end
  def test_necb2017()
    vintage_mapper('NECB2017')
  end

  private

  def vintage_mapper(vintage_name)
    vintage = nil
    eval("vintage = #{vintage_name}.new()")
    vintage_space_types = vintage.get_all_spacetype_names.map {|map| map[0] + '-' + map[1]}
    space_type_upgrade_map = vintage.standards_lookup_table_many(table_name: 'space_type_upgrade_map').map {|map| map["#{vintage_name}_building_type"] + '-' + map["#{vintage_name}_space_type"]}.sort.uniq
    assert((space_type_upgrade_map.sort - vintage_space_types.sort).empty?, "Some #{vintage_name} Mapped spacetypes are not contained in the standards #{vintage_name} list \n #{space_type_upgrade_map.sort - vintage_space_types.sort} ")
    assert((vintage_space_types.sort - space_type_upgrade_map.sort).empty?, "Some #{vintage_name} spacetypes are not mapped \n #{vintage_space_types.sort - space_type_upgrade_map.sort}")
  end
end
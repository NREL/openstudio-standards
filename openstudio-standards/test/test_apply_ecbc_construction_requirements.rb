require_relative 'minitest_helper'

class TestFindSpaceTypeStandardsData < Minitest::Test

  def test_apply_ecbc_construction_requirements

    # for now this just runs for single building type and climate zone, but could sweep across larger selection
    template = 'ECBC 2007'
    standard_building_type = 'LargeHotel'
    standard_space_type = 'GuestRoom'
    intended_surface_type = 'ExteriorRoof'
    standards_construction_type = 'Mass'
    test_climate_zone = 'ECBC Warm and Humid'
    operation_type = '24 Hr'
    building_category = 'Nonresidential'

    # make an empty model
    model = OpenStudio::Model::Model.new

    # create space type and set standards info
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setStandardsBuildingType(standard_building_type)
    space_type.setStandardsSpaceType(standard_space_type)

    # set climate zone
    climateZones = model.getClimateZones
    climateZones.setClimateZone("ECBC",test_climate_zone)

    # get climate_zone_set
    # climate_zone = model.get_building_climate_zone_and_building_type['climate_zone']
    # climate_zone_set = model.find_climate_zone_set(climate_zone, template)

    # populate search hash
    search_criteria = {
      'template' => template,
      'climate_zone_set' => test_climate_zone,
      'intended_surface_type' => intended_surface_type,
      'standards_construction_type' => standards_construction_type,
      'operation_type' => operation_type,
      'building_category' => building_category
    }

    # switch to use this but update test in standards and measures to load this outside of the method
    data = model.find_object($os_standards['construction_properties'], search_criteria)

    assert(!data.nil?, "Could not find data for #{search_criteria}")

    # gather specific internal load values for testing
    u_value = data['assembly_maximum_u_value']

    # check various internal loads. This has ip values
    assert_in_delta(u_value.to_f, 0.08)

  end

end

require_relative 'minitest_helper'

class TestFindSpaceTypeStandardsData < Minitest::Test

  def test_apply_ecbc_construction_requirements

    # for now this just runs for single building type and climate zone, but could sweep across larger selection
    template = 'ECBC 2007'
    standard_building_type = 'LargeHotel'
    standard_space_type = 'GuestRoom'
    intended_surface_type = 'ExteriorWall'
    standards_construction_type = 'Mass'
    test_climate_zone = 'ECBC Warm and Humid'

    # make an empty model
    model = OpenStudio::Model::Model.new

    # create space type and set standards info
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setStandardsBuildingType(standard_building_type)
    space_type.setStandardsSpaceType(standard_space_type)

    # set climate zone
    climateZones = model.getClimateZones
    climateZones.setClimateZone("ECBC",test_climate_zone)

    # lookup standards data for space type
    data = space_type.get_construction_properties(template,operation_type,intended_surface_type,standards_construction_type)

    # gather specific internal load values for testing
    u_value = data['assembly_maximum_u_value']

    # check various internal loads. This has ip values
    assert_in_delta(u_value.to_f, 0.077)

  end

end

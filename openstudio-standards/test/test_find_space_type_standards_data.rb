require_relative 'minitest_helper'

class TestFindSpaceTypeStandardsData < Minitest::Test

  def test_find_space_type_standards_data_valid_standards

    # for now this just runs for single building type and climate zone, but could sweep across larger selection
    template = '90.1-2013'
    standard_building_type = 'LargeHotel'
    standard_space_type = 'GuestRoom'

    # make an empty model
    model = OpenStudio::Model::Model.new
    model.load_openstudio_standards_json

    # create space type and set standards info
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setStandardsBuildingType(standard_building_type)
    space_type.setStandardsSpaceType(standard_space_type)

    # lookup standards data for space type
    data = space_type.get_standards_data(template)
    # uncomment to view data for this space type
    #puts data

    # gather specific internal load values for testing
    lighting_per_area = data['lighting_per_area']
    electric_equipment_per_area = data['electric_equipment_per_area']
    gas_equipment_per_area = data['gas_equipment_per_area']
    occupancy_per_area = data['occupancy_per_area']
    ventilation_per_area = data['ventilation_per_area']
    ventilation_per_person = data['ventilation_per_person']
    infiltration_per_exterior_area = data['infiltration_per_exterior_area']
    infiltration_per_exterior_wall_area = data['infiltration_per_exterior_wall_area']
    infiltration_air_changes = data['infiltration_air_changes']

    # check various internal loads. This has ip values
    assert(lighting_per_area == 0.91)
    assert(electric_equipment_per_area == 0.627)
    assert(gas_equipment_per_area == nil)
    assert(occupancy_per_area == 3.57)
    assert(ventilation_per_area == 0.06)
    assert(ventilation_per_person == 5)
    assert(infiltration_per_exterior_area == 0.112)
    assert(infiltration_per_exterior_wall_area == nil)
    assert(infiltration_air_changes == nil)

  end

end

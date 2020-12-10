require_relative '../helpers/minitest_helper'

class TestFindConstructionPropertiesData < Minitest::Test

  def test_find_construction_properties_data

    # for now this just runs for single building type and climate zone, but could sweep across larger selection
	templates = ['90.1-2007', '90.1-2010', '90.1-2013']
    standard_building_type = 'LargeHotel'
    standard_space_type = 'GuestRoom'
    intended_surface_type = 'ExteriorWall'
    standards_construction_type = 'SteelFramed'
    test_climate_zone = '3B'

    standard = Standard.build(template)
    
    # make an empty model
    model = OpenStudio::Model::Model.new

    # create space type and set standards info
    space_type = OpenStudio::Model::SpaceType.new(model)
    space_type.setStandardsBuildingType(standard_building_type)
    space_type.setStandardsSpaceType(standard_space_type)

    # set climate zone
    climateZones = model.getClimateZones
    climateZones.setClimateZone("ASHRAE",test_climate_zone)
	
	
	templates.each do |template|

		# lookup standards data for space type
		data = standard.space_type_get_construction_properties(space_type, intended_surface_type,standards_construction_type)
		if data.nil? then puts "#{space_type}  #{intended_surface_type} #{standards_construction_type} data is nil qaqc measure wont work with this " end

		# gather specific internal load values for testing
		u_value = data['assembly_maximum_u_value']
		
		space_type_const_properties['ExteriorRoof']['u_value']
		space_type_const_properties['ExteriorWall']['u_value']
		space_type_const_properties[intended_surface_type]['u_value']
		space_type_const_properties[intended_surface_type]['shgc']

		# check various internal loads. This has ip values
		assert_in_delta(u_value.to_f, 0.064)
	end

  end

end

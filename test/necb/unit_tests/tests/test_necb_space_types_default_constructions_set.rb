require_relative '../../../helpers/minitest_helper'


# This class will perform tests that are Spacetype dependant, Test model will be created
# to specifically test aspects of the NECB2011 code that are Spacetype dependant.
class NECB2011SpaceTypesDefaultConstructionsTest < Minitest::Test
  Templates = ['NECB2011', 'BTAPPRE1980'] #,'90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013']
  def test_spacetype_construction_sets()
    @model = OpenStudio::Model::Model.new
    #Create only above ground geometry (Used for infiltration tests)
    length = 100.0; width = 100.0; num_above_ground_floors = 1; num_under_ground_floors = 0; floor_to_floor_height = 3.8; plenum_height = 1; perimeter_zone_depth = 4.57; initial_height = 10.0
    BTAP::Geometry::Wizards::create_shape_rectangle(@model, length, width, num_above_ground_floors, num_under_ground_floors, floor_to_floor_height, plenum_height, perimeter_zone_depth, initial_height)
    header_output = ""
    output = ""
    #Iterate through all spacetypes/buildingtypes.
    Templates.each do |template|
      standard = Standard.build(template)
      #Get spacetypes from googledoc.
      search_criteria = {
          "template" => template,
      }
      # lookup space type properties
      standards_table = standard.standards_data['space_types']
      standard.model_find_objects(standards_table, search_criteria).each do |space_type_properties|
        [1, 2, 3, 5].each do |stories|
          header_output = ""
          # Create a space type
          st = OpenStudio::Model::SpaceType.new(@model)
          st.setStandardsBuildingType(space_type_properties['building_type'])
          st.setStandardsSpaceType(space_type_properties['space_type'])
          st.setName("#{template}-#{space_type_properties['building_type']}-#{space_type_properties['space_type']}")
          standard.space_type_apply_rendering_color(st)

          #Set all spaces to spacetype
          @model.getSpaces.each do |space|
            space.setSpaceType(st)
          end
        end
      end
    end
  end
end

require_relative '../../helpers/minitest_helper'

class TestCreateTypicalSpaceTypeBlend < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical

    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    @model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAEPrimarySchool.osm")
  end

  def test_blend_space_types_from_floor_area_ratio
   # loop through space types and add to blend
   space_type_ratio_hash = { 'PrimarySchool Classroom' => 0.9, 'PrimarySchool ComputerRoom' => 0.1 }
   space_types_to_blend_hash = {}
   @model.getSpaceTypes.each do |space_type|
     if space_type_ratio_hash.key?(space_type.name.get)
       # create hash with space type object as key and ratio as has
       floor_area_ratio = space_type_ratio_hash[space_type.name.get]
       space_types_to_blend_hash[space_type] = { floor_area_ratio: floor_area_ratio }
     end
   end

   # run method to create blended space type
   blended_space_type = @create.blend_space_types_from_floor_area_ratio(@model, space_types_to_blend_hash)
   assert(blended_space_type)
  end
end
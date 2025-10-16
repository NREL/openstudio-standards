require_relative '../../helpers/minitest_helper'

class TestInteriorLightingCreate < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
    @int = OpenstudioStandards::InteriorLighting
  end

  def test_create_lights
    model = OpenStudio::Model::Model.new
    space = OpenStudio::Model::Space.new(model)

    @int.create_lights(model,
                       name: 'test lights',
                       lighting_power: 5.0,
                       lighting_power_type: 'Watts/Area',
                       space: space)

    assert_equal(1, model.getLightss.size)
    added_lights = model.getLightss[0]
    assert_equal('test lights', added_lights.name.to_s)
    assert_in_delta(5.0, added_lights.lightsDefinition.wattsperSpaceFloorArea.get, 0.001)
  end

  def test_create_typical_interior_lighting
    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    model = std.safe_load_model("#{__dir__}/../../../data/geometry/ASHRAEPrimarySchool.osm")
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: climate_zone)

    # assign lighting space types
    model.getSpaceTypes.each do |space_type|
      case space_type.standardsSpaceType.get.to_s
      when 'Office'
        lighting_space_type = 'office_enclosed_lighting'
      when 'Lobby'
        lighting_space_type = 'lobby_lighting'
      when 'Gym'
        lighting_space_type = 'playing_area_lighting'
      when 'Mechanical'
        lighting_space_type = 'electrical_mechanical_lighting'
      when 'Cafeteria'
        lighting_space_type = 'dining_cafeteria_fast_food_general_lighting'
      when 'Kitchen'
        lighting_space_type = 'food_preparation_lighting'
      when 'Restroom'
        lighting_space_type = 'restroom_lighting'
      when 'Corridor'
        lighting_space_type = 'corridor_lighting'
      when 'Classroom'
        lighting_space_type = 'classroom_lecture_training_lighting'
      when 'ComputerRoom'
        lighting_space_type = 'workshop_lighting'
      when 'Library'
        lighting_space_type = 'library_reading_area_lighting'
      end
      space_type.additionalProperties.setFeature('lighting_space_type', lighting_space_type)
    end

    result = @int.create_typical_interior_lighting(model, lighting_generation: 'gen4_led')
    assert(11, result.size)
    space_type = model.getSpaceTypeByName('PrimarySchool Cafeteria').get

    space_type_floor_area = space_type.floorArea
    space_type_number_of_people = space_type.getNumberOfPeople(space_type_floor_area)
    ending_space_type_lighting_power = space_type.getLightingPower(space_type_floor_area, space_type_number_of_people)
    puts "space_type_floor_area = #{space_type_floor_area}"
    puts "space_type_number_of_people = #{space_type_number_of_people}"
    puts "ending_space_type_lighting_power = #{ending_space_type_lighting_power}"
  end
end
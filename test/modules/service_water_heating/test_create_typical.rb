require_relative '../../helpers/minitest_helper'

class TestCreateTypicalServiceWaterHeating < Minitest::Test
  def setup
    @swh = OpenstudioStandards::ServiceWaterHeating

    # load model and set up weather file
    template = '90.1-2010'
    @climate_zone = 'ASHRAE 169-2013-2A'
    @std = Standard.build(template)

    # create output directory
    FileUtils.mkdir_p "#{__dir__}/output"
  end

  def test_create_typical_service_water_heating_restaurant
    # set output directory
    output_dir = "#{__dir__}/output/#{__method__}"
    FileUtils.mkdir_p output_dir

    model = @std.safe_load_model("#{File.dirname(__FILE__)}/../../os_stds_methods/models/QuickServiceRestaurant_2A_2010.osm")
    model.save("#{output_dir}/in.osm", true)

    # remove swh loops
    model.getPlantLoops.each(&:remove)

    # default water heater
    created_loops = @swh.create_typical_service_water_heating(model)
    assert(created_loops.size > 1)

    # set output directory
    output_dir = "#{__dir__}/output/#{__method__}"
    FileUtils.mkdir_p output_dir

    model.save("#{output_dir}/out.osm", true)
  end

  def test_create_typical_service_water_heating_school
    # set output directory
    output_dir = "#{__dir__}/output/#{__method__}"
    FileUtils.mkdir_p output_dir

    model = @std.safe_load_model("#{File.dirname(__FILE__)}/../../os_stds_methods/models/test_school.osm")
    model.save("#{output_dir}/in.osm", true)

    # remove swh loops
    model.getPlantLoops.each { |loop| loop.remove unless (loop.name == 'Hot Water Loop') }

    # default water heater
    created_loops = @swh.create_typical_service_water_heating(model)
    assert(created_loops.size > 1)

    model.save("#{output_dir}/out.osm", true)
  end

  def test_create_typical_service_water_heating_apartment_units
    # set output directory
    output_dir = "#{__dir__}/output/#{__method__}"
    FileUtils.mkdir_p output_dir

    model = @std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAEMidriseApartment.osm")
    model.save("#{output_dir}/in.osm", true)

    model.getSpaces.each do |space|
      space.additionalProperties.setFeature('num_units', 1) if space.name.get.include?('Apartment')
      space.additionalProperties.setFeature('num_units', 2) if space.name.get.include?('G N1 Apartment')
    end

    # default water heater
    created_loops = @swh.create_typical_service_water_heating(model)
    assert(created_loops.size > 10)

    space = model.getSpaceByName('G N1 Apartment').get
    water_use_equip_def = space.waterUseEquipment[0].waterUseEquipmentDefinition
    assert(water_use_equip_def.name.get.include?('2 unit(s)'))

    model.save("#{output_dir}/out.osm", true)
  end
end
require_relative '../../helpers/minitest_helper'

class TestExteriorLightingInformation < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
    @ext = OpenstudioStandards::ExteriorLighting
    FileUtils.mkdir_p "#{__dir__}/output"
  end

  def test_model_get_exterior_lighting_areas
    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    model = std.safe_load_model("#{__dir__}/../../../data/geometry/ASHRAEPrimarySchool.osm")
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: climate_zone)

    # set output directory
    output_dir = "#{__dir__}/output/test_model_get_exterior_lighting_areas"
    FileUtils.mkdir_p output_dir

    result = @create.create_typical_building_from_model(model, template,
                                                        climate_zone: climate_zone,
                                                        sizing_run_directory: output_dir)

    areas = @ext.model_get_exterior_lighting_areas(model)
  end

  # add a test for a model with multiple building types
end
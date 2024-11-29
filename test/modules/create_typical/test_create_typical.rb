require_relative '../../helpers/minitest_helper'

class TestCreateTypical < Minitest::Test
  def setup
    @create = OpenstudioStandards::CreateTypical
    FileUtils.mkdir "#{__dir__}/output" unless Dir.exist? "#{__dir__}/output"
  end

  def test_create_typical_building_from_model
    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAEPrimarySchool.osm")
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: climate_zone)

    # set output directory
    output_dir = "#{__dir__}/output/test_create_typical_building_from_model"
    FileUtils.mkdir output_dir unless Dir.exist? output_dir

    # apply create typical
    starting_size = model.getModelObjects.size
    result = @create.create_typical_building_from_model(model, template,
                                                        climate_zone: climate_zone,
                                                        sizing_run_directory: output_dir)
    ending_size = model.getModelObjects.size
    assert(result)
    assert(starting_size < ending_size)
  end

  def test_create_typical_comstock_building_from_model
    # load model and set up weather file
    template = 'ComStock DOE Ref 1980-2004'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAEMediumOffice.osm")
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: climate_zone)

    # set output directory
    output_dir = "#{__dir__}/output/test_create_typical_comstock_building_from_model"
    FileUtils.mkdir output_dir unless Dir.exist? output_dir

    # apply create typical
    starting_size = model.getModelObjects.size
    result = @create.create_typical_building_from_model(model, template,
                                                        climate_zone: climate_zone,
                                                        sizing_run_directory: output_dir)
    ending_size = model.getModelObjects.size
    assert(result)
    assert(starting_size < ending_size)
  end

  def test_create_typical_deer_building_from_model
    # load model and set up weather file
    template = 'DEER Pre-1975'
    climate_zone = 'CEC T24-CEC3'
    std = Standard.build(template)
    model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/DEER_ESe.osm")
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: climate_zone)

    # set output directory
    output_dir = "#{__dir__}/output/test_create_typical_deer_building_from_model"
    FileUtils.mkdir output_dir unless Dir.exist? output_dir

    # apply create typical
    starting_size = model.getModelObjects.size
    result = @create.create_typical_building_from_model(model, template,
                                                        climate_zone: climate_zone,
                                                        sizing_run_directory: output_dir)
    ending_size = model.getModelObjects.size
    assert(result)
    assert(starting_size < ending_size)
  end

  def test_create_space_types_and_constructions
    model = OpenStudio::Model::Model.new
    building_type = 'PrimarySchool'
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    result = @create.create_space_types_and_constructions(model, building_type, template, climate_zone)
    assert(result)
    assert(model.getSpaceTypes.size > 0)
    assert(model.getDefaultConstructionSets.size > 0)
  end

  def test_create_typical_building_from_model_with_hvac_mapping
    # load model and set up weather file
    template = '90.1-2013'
    climate_zone = 'ASHRAE 169-2013-4A'
    std = Standard.build(template)
    model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/ASHRAESmallOffice.osm")
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: climate_zone)

    # Read in HVAC to zone mapping with 4 zones served by PTAC and 1 by a PSZ AC
    hvac_zone_json_path = File.join(File.dirname(__FILE__),'data','hvac_zone_mapping.json')
    hvac_zone_json = File.read(hvac_zone_json_path)
    hvac_mapping_hash = JSON.parse(hvac_zone_json)

    # set output directory
    output_dir = "#{__dir__}/output/test_create_typical_building_from_model_with_hvac_mapping"
    FileUtils.mkdir output_dir unless Dir.exist? output_dir

    # apply create typical with zone mapping
    starting_size = model.getModelObjects.size
    result = @create.create_typical_building_from_model(model, template,
                                                        climate_zone: climate_zone,
                                                        user_hvac_mapping: hvac_mapping_hash,
                                                        sizing_run_directory: output_dir)
    ending_size = model.getModelObjects.size
    ptacs = model.getZoneHVACPackagedTerminalAirConditioners
    psz_ac = model.getAirLoopHVACUnitarySystems

    # Check that JSON specs were applied
    assert(result)
    assert(starting_size < ending_size)
    assert(ptacs.length==4)
    assert(psz_ac.length==1)
  end

  def test_create_typical_ese_op_hrs_overnight
    # load model and set up weather file
    template = 'DEER Pre-1975'
    climate_zone = 'CEC T24-CEC3'
    std = Standard.build(template)
    model = std.safe_load_model("#{File.dirname(__FILE__)}/../../../data/geometry/DEER_ESe.osm")
    OpenstudioStandards::Weather.model_set_building_location(model, climate_zone: climate_zone)

    # set output directory
    output_dir = "#{__dir__}/output/test_create_typical_ese_op_hrs_overnight"
    FileUtils.mkdir output_dir unless Dir.exist? output_dir

    # apply create typical
    starting_size = model.getModelObjects.size
    result = @create.create_typical_building_from_model(model,
                                                        template,
                                                        climate_zone: climate_zone,
                                                        modify_wkdy_op_hrs: true,
                                                        wkdy_op_hrs_start_time: 12.50,
                                                        wkdy_op_hrs_duration: 13.0,
                                                        modify_wknd_op_hrs: true,
                                                        wknd_op_hrs_start_time: 8.00,
                                                        wknd_op_hrs_duration: 6.00,
                                                        sizing_run_directory: output_dir)
    ending_size = model.getModelObjects.size
    assert(result)
    assert(starting_size < ending_size)
  end
end

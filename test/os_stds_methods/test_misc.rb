require_relative '../helpers/minitest_helper'
require_relative '../helpers/create_doe_prototype_helper'

class TestMisc < Minitest::Test
  def create_model(building_type, climate_zone, template)
    # Initialize weather file, necessary but not used
    epw_file = 'USA_FL_Miami.Intl.AP.722020_TMY3.epw'

    # Create output folder if it doesn't already exist
    @test_dir = "#{File.dirname(__FILE__)}/output"
    if !Dir.exist?(@test_dir)
      Dir.mkdir(@test_dir)
    end

    # Define model name and run folder if it doesn't already exist,
    # if it does, remove it and re-create it.
    model_name = "#{building_type}-#{template}-#{climate_zone}"
    run_dir = "#{@test_dir}/#{model_name}"
    if !Dir.exist?(run_dir)
      Dir.mkdir(run_dir)
    else
      FileUtils.rm_rf(run_dir)
      Dir.mkdir(run_dir)
    end

    # Create standard and prototype
    std = Standard.build("#{template}_#{building_type}")
    model = std.model_create_prototype_model(climate_zone, epw_file, run_dir)

    return std, model
  end

  def test_plenum_space_conditioning
    # Create prototype
    std, model = create_model('LargeOffice', 'ASHRAE 169-2013-4A', '90.1-2019')

    # Test return plenum space conditioning
    model.getSpaces.sort.each do |space|
      if space.name.to_s.downcase.include?('plenum')
        assert(std.space_conditioning_category(space) == 'NonResConditioned', 'Wrong plenum space conditioning type.')
      end
    end
  end
end
